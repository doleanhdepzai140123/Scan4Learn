import CryptoKit
import XCTest
@testable import Scan4Learn

final class ChatGPTServiceTests: XCTestCase {
    func testPKCEChallengeIsBase64URLSHA256WithoutPadding() {
        let verifier = "a-verifier-string-with-plenty-of-entropy-1234567890"
        let digest = SHA256.hash(data: Data(verifier.utf8))
        let expected = Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        XCTAssertEqual(ChatGPTAuth.challenge(for: verifier), expected)
        XCTAssertFalse(ChatGPTAuth.challenge(for: verifier).contains("="))
    }

    func testAuthorizeURLCarriesOpenSourceContractParameters() throws {
        let redirect = "http://127.0.0.1:1455/auth/callback"
        let url = ChatGPTAuth.makeAuthorizeURL(clientID: "dynamic_agent_client", verifier: "v",
                                               state: "state123", nonce: "nonce123", idTokenHint: nil,
                                               redirectURI: redirect)
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        XCTAssertEqual(url.host, "auth.openai.com")
        XCTAssertEqual(value("response_type"), "code")
        XCTAssertEqual(value("client_id"), "dynamic_agent_client")
        XCTAssertEqual(value("redirect_uri"), redirect)
        XCTAssertTrue(value("redirect_uri")?.hasPrefix("http://127.0.0.1:") ?? false, "The contract requires the 127.0.0.1 loopback host")
        XCTAssertTrue(value("redirect_uri")?.hasSuffix("/auth/callback") ?? false, "The callback path must stay fixed")
        XCTAssertEqual(value("code_challenge_method"), "S256")
        XCTAssertEqual(value("state"), "state123")
        XCTAssertEqual(value("nonce"), "nonce123")
        XCTAssertEqual(value("resource"), "https://api.openai.com/v1")
        XCTAssertEqual(value("agent_name_hint"), "Scan4Learn")
        XCTAssertTrue(value("ext_agent_host_id")?.hasPrefix("urn:uuid:") ?? false,
                      "The contract accepts only URN-form host IDs")
        XCTAssertNotNil(UUID(uuidString: String(value("ext_agent_host_id")?.dropFirst(9) ?? "")))
        XCTAssertTrue(value("scope")?.contains("chatgpt.tokens.use.direct") ?? false)
        XCTAssertTrue(value("scope")?.contains("openid") ?? false)
        XCTAssertEqual(value("code_challenge"), ChatGPTAuth.challenge(for: "v"))

        let reauth = ChatGPTAuth.makeAuthorizeURL(clientID: "oaiapp_issued", verifier: "v",
                                                  state: "s", nonce: "n", idTokenHint: "old-id-token",
                                                  redirectURI: redirect)
        let reauthItems = try XCTUnwrap(URLComponents(url: reauth, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(reauthItems.first { $0.name == "id_token_hint" }?.value, "old-id-token")
        XCTAssertEqual(reauthItems.first { $0.name == "client_id" }?.value, "oaiapp_issued")
        XCTAssertNil(reauthItems.first { $0.name == "agent_name_hint" },
                     "The name hint must be omitted when reauthorizing with an issued client ID")
    }

    func testHostIDIsStablePerHost() {
        let first = ChatGPTAuth.hostID()
        XCTAssertTrue(first.hasPrefix("urn:uuid:"), "The contract requires a URN-form host ID")
        XCTAssertNotNil(UUID(uuidString: String(first.dropFirst(9))))
        XCTAssertEqual(ChatGPTAuth.hostID(), first, "The host ID must be reused for the same host")
    }

    func testLoopbackServerReceivesTheCallbackQuery() async throws {
        let server = LoopbackCallbackServer()
        try await server.start()
        defer { server.stop() }
        XCTAssertTrue(server.redirectURI.hasPrefix("http://127.0.0.1:"))
        XCTAssertTrue(server.redirectURI.hasSuffix("/auth/callback"))

        let callbackTask = Task { try await server.awaitCallback() }
        try await Task.sleep(nanoseconds: 300_000_000)

        let url = URL(string: "http://127.0.0.1:\(server.port)/auth/callback?code=abc123&state=xyz789")!
        let (_, response) = try await URLSession.shared.data(from: url)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200, "The browser must see a success page")

        let query = try await callbackTask.value
        XCTAssertEqual(query["code"], "abc123")
        XCTAssertEqual(query["state"], "xyz789")
        XCTAssertNil(query["client_id"])
    }

    func testIDTokenClaimsAreDecoded() throws {
        func segment(_ json: String) -> String {
            Data(json.utf8).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        let payload = #"{"sub":"user-1","email":"me@example.com","iss":"https://auth.openai.com/","aud":"oaiapp_x","exp":9999999999,"nonce":"n1"}"#
        let token = [segment(#"{"alg":"RS256"}"#), segment(payload), "signature"].joined(separator: ".")
        let claims = try XCTUnwrap(ChatGPTAuth.idTokenClaims(token))
        XCTAssertEqual(claims["sub"] as? String, "user-1")
        XCTAssertEqual(claims["email"] as? String, "me@example.com")
        XCTAssertEqual(claims["nonce"] as? String, "n1")
        XCTAssertNil(ChatGPTAuth.idTokenClaims("not-a-jwt"))
    }

    func testIDTokenValidationAcceptsStringAndArrayAudiences() throws {
        let now = Date()
        let expiry = now.timeIntervalSince1970 + 3_600
        let base: [String: Any] = [
            "iss": "https://auth.openai.com",
            "exp": expiry,
            "sub": "user-1",
            "nonce": "the-nonce"
        ]
        // Single-string audience, the straightforward form.
        var claims = base
        claims["aud"] = "oaiapp_x"
        XCTAssertNoThrow(try ChatGPTAuth.validateIDTokenClaims(claims, clientID: "oaiapp_x", nonce: "the-nonce", now: now))
        // Array audience with extra entries, as OIDC allows.
        claims["aud"] = ["https://api.openai.com/v1", "oaiapp_x"]
        XCTAssertNoThrow(try ChatGPTAuth.validateIDTokenClaims(claims, clientID: "oaiapp_x", nonce: "the-nonce", now: now))
        // An omitted nonce is tolerated; PKCE and state already bind the flow.
        claims.removeValue(forKey: "nonce")
        XCTAssertNoThrow(try ChatGPTAuth.validateIDTokenClaims(claims, clientID: "oaiapp_x", nonce: "the-nonce", now: now))

        func reason(_ block: () throws -> Void) -> String {
            XCTAssertThrowsError(try block()) { error in
                guard case ChatGPTAuthError.invalidIDToken(let detail)? = error as? ChatGPTAuthError else {
                    return XCTFail("Expected an invalidIDToken error")
                }
                XCTAssertTrue(detail.contains("audience") || detail.contains("expired") || detail.contains("nonce") || detail.contains("issuer") || detail.contains("subject"))
            }
            return "audience"
        }
        claims["aud"] = "someone-else"
        claims["nonce"] = "the-nonce"
        reason { try ChatGPTAuth.validateIDTokenClaims(claims, clientID: "oaiapp_x", nonce: "the-nonce", now: now) }
        claims["aud"] = ["oaiapp_x"]
        claims["exp"] = now.timeIntervalSince1970 - 10
        reason { try ChatGPTAuth.validateIDTokenClaims(claims, clientID: "oaiapp_x", nonce: "the-nonce", now: now) }
        claims["exp"] = now.timeIntervalSince1970 + 3_600
        claims["nonce"] = "different"
        reason { try ChatGPTAuth.validateIDTokenClaims(claims, clientID: "oaiapp_x", nonce: "the-nonce", now: now) }
    }

    func testStreamedTextPrefersCompletedResponseAndFallsBackToDeltas() async throws {
        let lines: [[String]] = [
            [
                "event: response.output_text.delta",
                "data: {\"type\":\"response.output_text.delta\",\"delta\":\"Hello\"}",
                "data: {\"type\":\"response.output_text.delta\",\"delta\":\" world\"}",
                "event: response.completed",
                "data: {\"type\":\"response.completed\",\"response\":{\"output\":[{\"content\":[{\"type\":\"output_text\",\"text\":\"Hello world\"}]}]}}"
            ],
            [
                "event: response.output_text.delta",
                "data: {\"delta\":\"Only \"}",
                "data: {\"delta\":\"deltas\"}"
            ],
            [
                "event: response.created",
                "data: {\"type\":\"response.created\"}"
            ]
        ]
        let completed = try await ChatGPTClient.parseStreamedText(stream(of: lines[0]))
        XCTAssertEqual(completed, "Hello world")
        let deltas = try await ChatGPTClient.parseStreamedText(stream(of: lines[1]))
        XCTAssertEqual(deltas, "Only deltas")
        do {
            _ = try await ChatGPTClient.parseStreamedText(stream(of: lines[2]))
            XCTFail("An empty stream must throw")
        } catch let error as ChatGPTError {
            XCTAssertEqual(error, ChatGPTError.emptyResponse)
        }
    }

    func testKeychainRoundTrip() throws {
        let key = "test-\(UUID().uuidString)"
        defer { KeychainStore.delete(key) }
        let payload = Data("secret".utf8)
        do {
            try KeychainStore.save(payload, for: key)
        } catch let error as KeychainStore.KeychainError {
            // Unsigned CI builds lack the keychain entitlement; the signed app has it.
            guard case .unexpectedStatus(-34018) = error else { throw error }
            throw XCTSkip("Keychain entitlement missing in this build")
        }
        XCTAssertEqual(KeychainStore.load(key), payload)
        try KeychainStore.save(Data("rotated".utf8), for: key)
        XCTAssertEqual(KeychainStore.load(key), Data("rotated".utf8), "Saving an existing key must update it")
        KeychainStore.delete(key)
        XCTAssertNil(KeychainStore.load(key))
    }

    func testSessionCodableRoundTrip() throws {
        let session = ChatGPTSession(accountEmail: "me@example.com", accountID: "sub-1",
                                      accessToken: "at", refreshToken: "rt", idToken: "id",
                                      expiresAt: Date(timeIntervalSince1970: 2_000_000_000),
                                      scopes: "openid", issuedClientID: "oaiapp_x")
        let data = try JSONEncoder().encode(session)
        XCTAssertEqual(try JSONDecoder().decode(ChatGPTSession.self, from: data), session)
    }

    private func stream(of lines: [String]) -> AsyncStream<String> {
        AsyncStream { continuation in
            for line in lines { continuation.yield(line) }
            continuation.finish()
        }
    }
}
