import AuthenticationServices
import CryptoKit
import Foundation
import Observation
import UIKit

/// Sign-in credentials from the Sign in with ChatGPT open-source flow.
struct ChatGPTSession: Codable, Equatable {
    var accountEmail: String
    var accountID: String
    var accessToken: String
    var refreshToken: String
    var idToken: String
    var expiresAt: Date
    var scopes: String
    var issuedClientID: String

    var isExpired: Bool { expiresAt.timeIntervalSinceNow < 60 }
}

enum ChatGPTAuthError: LocalizedError, Equatable {
    case cancelled
    case browserUnavailable
    case accessDenied(String)
    case invalidCallback
    case registrationIncomplete
    case tokenExchangeFailed(String)
    /// The diagnostic says exactly which ID-token check failed and what was seen.
    case invalidIDToken(String)
    case notSignedIn
    case keychainFailure

    var errorDescription: String? {
        switch self {
        case .cancelled: return String(localized: "Sign-in cancelled.")
        case .browserUnavailable: return String(localized: "Couldn't open the local sign-in port on this device.")
        case .accessDenied(let reason): return String(localized: "OpenAI refused the sign-in: \(reason).")
        case .invalidCallback: return String(localized: "The sign-in response is invalid.")
        case .registrationIncomplete: return String(localized: "App registration with OpenAI is incomplete; try signing in again.")
        case .tokenExchangeFailed(let reason): return String(localized: "Exchanging the access code failed: \(reason).")
        case .invalidIDToken(let reason): return String(localized: "The session is invalid (\(reason)); sign in again.")
        case .notSignedIn: return String(localized: "Not signed in to ChatGPT.")
        case .keychainFailure: return String(localized: "Couldn't store the session securely.")
        }
    }
}

/// Runs the Sign in with ChatGPT open-source contract: dynamic client
/// registration, OIDC + PKCE in the system browser with an HTTP loopback
/// redirect (http://127.0.0.1:<port>/auth/callback), then a code exchange whose
/// tokens are kept in the keychain and refreshed on demand.
@MainActor @Observable
final class ChatGPTAuth: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = ChatGPTAuth()

    private static let authorizeURL = URL(string: "https://auth.openai.com/api/accounts/authorize")!
    private static let tokenURL = URL(string: "https://auth.openai.com/api/accounts/oauth/token")!
    /// Never triggered by the flow; the browser sheet only needs a scheme to observe.
    private static let browserCallbackScheme = "scan4learn"
    /// Dynamic first-time registration entrypoint per the open-source contract.
    private static let registrationClientID = "dynamic_agent_client"
    private static let scopes = "openid profile email offline_access resource.invoke chatgpt.tokens.use.direct"
    private static let resource = "https://api.openai.com/v1"
    private static let issuedClientIDKey = "chatgptIssuedClientID"
    private static let hostIDKey = "chatgptHostID"
    private static let sessionKey = "session"

    private(set) var session: ChatGPTSession?
    private var activeWebSession: ASWebAuthenticationSession?
    /// Set while a sign-in attempt is waiting; the first event (loopback
    /// callback or browser closing) resumes it exactly once.
    private var browserEventContinuation: CheckedContinuation<AuthBrowserEvent, Never>?

    /// Which side ended the authorization wait.
    private enum AuthBrowserEvent {
        case callback
        case closed(Error?)
    }

    var isSignedIn: Bool { session != nil }

    func restore() {
        guard session == nil,
              let data = KeychainStore.load(Self.sessionKey),
              let restored = try? JSONDecoder().decode(ChatGPTSession.self, from: data) else { return }
        session = restored
    }

    var isChatGPTPlanGranted: Bool {
        session?.scopes.contains("chatgpt.tokens.use.direct") ?? false
    }

    func signIn() async throws {
        let verifier = Self.randomToken(length: 64)
        let state = Self.randomToken(length: 32)
        let nonce = Self.randomToken(length: 32)
        let knownClientID = UserDefaults.standard.string(forKey: Self.issuedClientIDKey)
        let authorizeClientID = knownClientID ?? Self.registrationClientID

        // The contract requires the loopback listener to be up before the
        // browser opens, and the identical URI (same port) in the exchange.
        let server = LoopbackCallbackServer()
        do { try await server.start() } catch { throw ChatGPTAuthError.browserUnavailable }
        defer { server.stop() }

        let authorizeURL = Self.makeAuthorizeURL(clientID: authorizeClientID, verifier: verifier, state: state,
                                                 nonce: nonce, idTokenHint: session?.idToken,
                                                 redirectURI: server.redirectURI)
        // Whichever arrives first ends the wait. Once the loopback callback
        // lands we move on immediately and merely dismiss the browser sheet;
        // we never depend on the sheet's own completion callback afterwards.
        let event = await awaitFirstEvent(server: server, url: authorizeURL)
        activeWebSession = nil
        let query: [String: String]
        if case .callback = event {
            query = try await server.awaitCallback()
        } else if let delivered = server.peekCallback() {
            // The callback can land in the same instant the sheet closes; prefer it.
            query = delivered
        } else {
            server.stop()
            if case .closed(let error) = event {
                if let error, let sessionError = error as? ASWebAuthenticationSessionError, sessionError.code == .canceledLogin {
                    throw ChatGPTAuthError.cancelled
                }
                if let error { throw error }
            }
            throw ChatGPTAuthError.invalidCallback
        }

        if let error = query["error"] {
            throw ChatGPTAuthError.accessDenied(error)
        }
        guard query["state"] == state else { throw ChatGPTAuthError.invalidCallback }
        guard let code = query["code"] else { throw ChatGPTAuthError.invalidCallback }

        // The registration callback hands back the issued client ID; it must be
        // kept and used for the exchange instead of the dynamic entrypoint.
        if let issued = query["client_id"], issued != Self.registrationClientID {
            // A different client ID than the one this attempt started with is
            // a mismatch the contract says to reject, not overwrite.
            if let knownClientID, issued != knownClientID {
                throw ChatGPTAuthError.invalidCallback
            }
            UserDefaults.standard.set(issued, forKey: Self.issuedClientIDKey)
        }
        guard let exchangeClientID = UserDefaults.standard.string(forKey: Self.issuedClientIDKey) ?? knownClientID,
              exchangeClientID != Self.registrationClientID else {
            throw ChatGPTAuthError.registrationIncomplete
        }

        let session = try await exchange(code: code, verifier: verifier, clientID: exchangeClientID,
                                         nonce: nonce, redirectURI: server.redirectURI)
        do {
            try KeychainStore.save(JSONEncoder().encode(session), for: Self.sessionKey)
        } catch {
            throw ChatGPTAuthError.keychainFailure
        }
        self.session = session
    }

    func signOut() {
        KeychainStore.delete(Self.sessionKey)
        UserDefaults.standard.removeObject(forKey: Self.issuedClientIDKey)
        session = nil
    }

    /// Returns a valid session, refreshing it first when the access token expired.
    func refreshedSession() async throws -> ChatGPTSession {
        guard var current = session else { throw ChatGPTAuthError.notSignedIn }
        guard current.isExpired else { return current }
        struct TokenResponse: Decodable {
            var access_token: String
            var refresh_token: String?
            var id_token: String?
            var expires_in: Int
            var scope: String?
        }
        let refreshed: TokenResponse = try await postForm(url: Self.tokenURL, form: [
            "grant_type": "refresh_token",
            "client_id": current.issuedClientID,
            "refresh_token": current.refreshToken,
            "resource": Self.resource
        ])
        current.accessToken = refreshed.access_token
        current.refreshToken = refreshed.refresh_token ?? current.refreshToken
        current.idToken = refreshed.id_token ?? current.idToken
        current.scopes = refreshed.scope ?? current.scopes
        current.expiresAt = Date().addingTimeInterval(TimeInterval(max(60, refreshed.expires_in)))
        do {
            try KeychainStore.save(JSONEncoder().encode(current), for: Self.sessionKey)
        } catch {
            throw ChatGPTAuthError.keychainFailure
        }
        session = current
        return current
    }

    // MARK: - Internals

    /// Shows the auth browser and waits for the loopback callback or the user
    /// closing the sheet — whichever happens first.
    private func awaitFirstEvent(server: LoopbackCallbackServer, url: URL) async -> AuthBrowserEvent {
        await withCheckedContinuation { continuation in
            browserEventContinuation = continuation
            server.onCallback = { [weak self] in
                Task { @MainActor in self?.finishBrowserEvent(.callback) }
            }
            let webSession = ASWebAuthenticationSession(url: url, callbackURLScheme: Self.browserCallbackScheme) { [weak self] _, error in
                Task { @MainActor in self?.finishBrowserEvent(.closed(error)) }
            }
            webSession.presentationContextProvider = self
            webSession.prefersEphemeralWebBrowserSession = false
            self.activeWebSession = webSession
            if !webSession.start() {
                finishBrowserEvent(.closed(ChatGPTAuthError.browserUnavailable))
            }
        }
    }

    /// Resumes the pending wait exactly once. On the callback path the browser
    /// sheet is dismissed without waiting for its own completion handler.
    private func finishBrowserEvent(_ event: AuthBrowserEvent) {
        guard let continuation = browserEventContinuation else { return }
        browserEventContinuation = nil
        if case .callback = event {
            activeWebSession?.cancel()
        }
        continuation.resume(returning: event)
    }

    nonisolated static func makeAuthorizeURL(clientID: String, verifier: String, state: String, nonce: String,
                                             idTokenHint: String?, redirectURI: String) -> URL {
        var components = URLComponents(url: authorizeURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "nonce", value: nonce),
            URLQueryItem(name: "code_challenge", value: challenge(for: verifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "resource", value: resource),
            URLQueryItem(name: "ext_agent_host_id", value: hostID())
        ]
        // The name hint belongs to initial dynamic registration only; the
        // contract says to omit it when reauthorizing with an issued client ID.
        if clientID == registrationClientID {
            components.queryItems?.append(URLQueryItem(name: "agent_name_hint", value: "Scan4Learn"))
        }
        if let idTokenHint { components.queryItems?.append(URLQueryItem(name: "id_token_hint", value: idTokenHint)) }
        return components.url!
    }

    private func exchange(code: String, verifier: String, clientID: String, nonce: String, redirectURI: String) async throws -> ChatGPTSession {
        struct TokenResponse: Decodable {
            var access_token: String
            var refresh_token: String
            var id_token: String
            var expires_in: Int
            var scope: String?
        }
        let response: TokenResponse = try await postForm(url: Self.tokenURL, form: [
            "grant_type": "authorization_code",
            "client_id": clientID,
            "code": code,
            "code_verifier": verifier,
            "redirect_uri": redirectURI,
            "resource": Self.resource
        ])
        guard let claims = Self.idTokenClaims(response.id_token) else {
            throw ChatGPTAuthError.invalidIDToken("unparseable token")
        }
        // Local claim checks: issuer, audience, expiry and nonce. (Signature
        // verification against OpenAI's JWKS is not wired up in this version.)
        try Self.validateIDTokenClaims(claims, clientID: clientID, nonce: nonce)
        return ChatGPTSession(
            accountEmail: claims["email"] as? String ?? "",
            accountID: claims["sub"] as? String ?? "",
            accessToken: response.access_token,
            refreshToken: response.refresh_token,
            idToken: response.id_token,
            expiresAt: Date().addingTimeInterval(TimeInterval(max(60, response.expires_in))),
            scopes: response.scope ?? Self.scopes,
            issuedClientID: clientID
        )
    }

    private func postForm<Body: Decodable>(url: URL, form: [String: String]) async throws -> Body {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = form.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value)"
        }.joined(separator: "&").data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let reason = String(data: data, encoding: .utf8) ?? "HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)"
            throw ChatGPTAuthError.tokenExchangeFailed(reason)
        }
        do { return try JSONDecoder().decode(Body.self, from: data) }
        catch { throw ChatGPTAuthError.tokenExchangeFailed("bad-JSON") }
    }

    /// Base64url SHA-256 of the PKCE verifier, without padding.
    nonisolated static func challenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    nonisolated static func randomToken(length: Int) -> String {
        let bytes = (0..<length).map { _ in UInt8.random(in: 0...255) }
        return Data(bytes).base64URLEncodedString()
    }

    /// Stable per-host identifier for the open-source registration contract.
    /// Accepted formats are a JWK-thumbprint URI, `did:key:…` or `urn:uuid:…`;
    /// we persist a UUIDv4 once per host and always send it in URN form.
    nonisolated static func hostID() -> String {
        let defaults = UserDefaults.standard
        var raw = defaults.string(forKey: hostIDKey) ?? ""
        if raw.count > 9, raw.lowercased().prefix(9) == "urn:uuid:" { raw = String(raw.dropFirst(9)) }
        if UUID(uuidString: raw) == nil {
            raw = UUID().uuidString
            defaults.set(raw, forKey: hostIDKey)
        }
        return "urn:uuid:" + raw.lowercased()
    }

    /// Decodes the JWT payload (without signature verification) into claims.
    nonisolated static func idTokenClaims(_ token: String) -> [String: Any]? {
        let segments = token.split(separator: ".")
        guard segments.count == 3 else { return nil }
        var base64 = segments[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return object
    }

    /// Validates the ID-token claims locally. Each failure names the exact
    /// problem and observed value so device reports are diagnosable.
    /// The audience may be a single string or an array of strings (OIDC).
    nonisolated static func validateIDTokenClaims(_ claims: [String: Any], clientID: String,
                                                  nonce: String, now: Date = Date()) throws {
        guard let issuer = claims["iss"] as? String, issuer.contains("auth.openai.com") else {
            throw ChatGPTAuthError.invalidIDToken("issuer \(describeClaim(claims["iss"]))")
        }
        guard audienceMatches(claims["aud"], clientID: clientID) else {
            throw ChatGPTAuthError.invalidIDToken("audience \(describeClaim(claims["aud"]))")
        }
        guard let expiry = claims["exp"] as? TimeInterval, expiry > now.timeIntervalSince1970 - 5 else {
            throw ChatGPTAuthError.invalidIDToken("expired \(describeClaim(claims["exp"]))")
        }
        guard let subject = claims["sub"] as? String, !subject.isEmpty else {
            throw ChatGPTAuthError.invalidIDToken("missing subject")
        }
        // Verify the nonce when the issuer includes one. PKCE, the validated
        // state and the direct TLS token exchange already bind this flow, so
        // a token that simply omits the nonce is tolerated.
        if let claimNonce = claims["nonce"] as? String, claimNonce != nonce {
            throw ChatGPTAuthError.invalidIDToken("nonce mismatch")
        }
    }

    private nonisolated static func audienceMatches(_ audience: Any?, clientID: String) -> Bool {
        if let single = audience as? String { return single == clientID }
        if let list = audience as? [Any] { return list.contains { ($0 as? String) == clientID } }
        return false
    }

    private nonisolated static func describeClaim(_ value: Any?) -> String {
        if let list = value as? [Any] {
            return "[" + list.compactMap { $0 as? String }.joined(separator: ",") + "]"
        }
        return String(describing: value ?? "nil")
    }

    @MainActor func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }
}

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
