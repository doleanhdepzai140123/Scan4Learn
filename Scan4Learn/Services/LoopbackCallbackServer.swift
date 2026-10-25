import Foundation
import Network

/// Listens on the device's loopback interface for the OAuth redirect, following
/// the Sign in with ChatGPT open-source contract: http://127.0.0.1:<port>/auth/callback.
/// Only the port may vary between sign-ins; scheme, host and path stay fixed.
final class LoopbackCallbackServer {
    static let path = "/auth/callback"

    private let queue = DispatchQueue(label: "com.scan4learn.personal.authcallback")
    private var listener: NWListener?
    private var pending: CheckedContinuation<[String: String], Error>?
    private var startContinuation: CheckedContinuation<Void, Error>?
    private var deliveredQuery: [String: String]?
    private(set) var port: UInt16 = 0

    /// Fired on an internal queue as soon as a callback request arrives.
    var onCallback: (() -> Void)?

    enum ServerError: Error { case stopped }

    var redirectURI: String { "http://127.0.0.1:\(port)\(Self.path)" }

    /// Binds the loopback listener; resolves once it is ready to accept connections.
    func start() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                self.startContinuation = continuation
                self.bind(attempt: 0)
            }
        }
    }

    /// Resolves with the callback's query parameters once the redirect arrives.
    func awaitCallback() async throws -> [String: String] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                if let delivered = self.deliveredQuery {
                    continuation.resume(returning: delivered)
                } else if self.listener == nil {
                    continuation.resume(throwing: ServerError.stopped)
                } else {
                    self.pending = continuation
                }
            }
        }
    }

    /// The callback query if it already arrived; never waits.
    func peekCallback() -> [String: String]? {
        queue.sync { deliveredQuery }
    }

    func stop() {
        queue.async {
            self.listener?.cancel()
            self.listener = nil
            if let continuation = self.pending {
                self.pending = nil
                continuation.resume(throwing: ServerError.stopped)
            }
        }
    }

    // MARK: - Binding

    private func bind(attempt: Int) {
        // First try an OS-assigned ephemeral port; fall back to random explicit ones.
        let port: NWEndpoint.Port = attempt == 0 ? .any : NWEndpoint.Port(rawValue: UInt16.random(in: 2_000...60_000))!
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: .ipv4(.loopback), port: port)
        do {
            let listener = try NWListener(using: parameters)
            self.listener = listener
            listener.stateUpdateHandler = { [weak self] state in
                self?.handleState(state, listener: listener, attempt: attempt)
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener.start(queue: queue)
        } catch {
            retryOrFail(attempt: attempt, error: error)
        }
    }

    private func handleState(_ state: NWListener.State, listener: NWListener, attempt: Int) {
        switch state {
        case .ready:
            if let bound = listener.port?.rawValue { port = bound }
            resolveStart(nil)
        case .failed(let error):
            listener.cancel()
            if self.listener === listener { self.listener = nil }
            retryOrFail(attempt: attempt, error: error)
        default:
            break
        }
    }

    private func retryOrFail(attempt: Int, error: Error) {
        guard startContinuation != nil else { return }
        if attempt < 5 {
            bind(attempt: attempt + 1)
        } else {
            resolveStart(error)
        }
    }

    private func resolveStart(_ error: Error?) {
        guard let continuation = startContinuation else { return }
        startContinuation = nil
        if let error {
            listener?.cancel()
            listener = nil
            continuation.resume(throwing: error)
        } else {
            continuation.resume()
        }
    }

    // MARK: - HTTP handling

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(connection, buffer: Data())
    }

    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            buffer.append(data ?? Data())
            if buffer.range(of: Data("\r\n\r\n".utf8)) != nil || isComplete || error != nil {
                self.processRequest(buffer, connection: connection)
            } else if buffer.count > 65_536 {
                self.respond(connection, status: "431", message: "")
            } else {
                self.receive(connection, buffer: buffer)
            }
        }
    }

    private func processRequest(_ request: Data, connection: NWConnection) {
        guard let head = String(data: request, encoding: .utf8),
              let requestLine = head.components(separatedBy: "\r\n").first else {
            respond(connection, status: "400", message: "")
            return
        }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" else {
            respond(connection, status: "405", message: "")
            return
        }
        let target = String(parts[1])
        guard target.hasPrefix(Self.path) else {
            respond(connection, status: "404", message: "")
            return
        }
        var query: [String: String] = [:]
        for item in URLComponents(string: "http://127.0.0.1" + target)?.queryItems ?? [] where query[item.name] == nil {
            query[item.name] = item.value ?? ""
        }
        respond(connection, status: "200", message: Self.successPage)
        deliver(query)
    }

    private func deliver(_ query: [String: String]) {
        guard deliveredQuery == nil else { return }
        deliveredQuery = query
        listener?.cancel()
        listener = nil
        if let continuation = pending {
            pending = nil
            continuation.resume(returning: query)
        }
        onCallback?()
    }

    private func respond(_ connection: NWConnection, status: String, message: String) {
        let body = Data(message.utf8)
        let head = "HTTP/1.1 \(status)\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(head.utf8) + body, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private static var successPage: String {
        let message = String(localized: "Sign-in successful! You can close this page and return to Scan4Learn.")
        return """
        <!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Scan4Learn</title></head>
        <body style="font-family:-apple-system,system-ui,sans-serif;background:#0d2620;color:#eef8f0;display:flex;align-items:center;justify-content:center;height:100vh;margin:0">
        <div style="text-align:center"><div style="font-size:52px">&#10003;</div><p style="font-size:18px">\(message)</p></div>
        </body></html>
        """
    }
}
