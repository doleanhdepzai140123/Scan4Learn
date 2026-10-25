import Foundation
import Observation

struct ChatModel: Codable, Identifiable, Equatable {
    var slug: String
    var displayName: String
    var id: String { slug }
}

enum ChatGPTError: LocalizedError, Equatable {
    case notSignedIn
    case noModels
    case requestFailed(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return String(localized: "Not signed in to ChatGPT.")
        case .noModels: return String(localized: "Couldn't load the model list.")
        case .requestFailed(let reason): return String(localized: "The ChatGPT request failed: \(reason).")
        case .emptyResponse: return String(localized: "ChatGPT returned no content.")
        }
    }
}

/// Calls the Responses API with the signed-in ChatGPT plan, resolving a
/// Thinking and a standard model from the live model list.
@MainActor @Observable
final class ChatGPTClient {
    static let shared = ChatGPTClient()

    private let auth: ChatGPTAuth
    private(set) var models: [ChatModel] = []

    init(auth: ChatGPTAuth = .shared) {
        self.auth = auth
    }

    /// Fetches the visible model list and returns the slugs chosen for each mode.
    @discardableResult
    func resolveModels() async throws -> (thinking: String?, standard: String?) {
        let session = try await auth.refreshedSession()
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        request.timeoutInterval = 30
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.check(response: response, data: data)
        let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
        let visible = decoded.models.filter { $0.visibility == "list" }
        models = visible.map { ChatModel(slug: $0.slug, displayName: $0.displayName) }
        let thinking = visible.first { $0.slug.isThinkingModel || $0.displayName.isThinkingModel }?.slug
        let standard = visible.first { !($0.slug.isThinkingModel || $0.displayName.isThinkingModel) }?.slug
        return (thinking, standard)
    }

    /// Runs a prompt through the Responses API in the chosen mode.
    func complete(prompt: String, thinking: Bool) async throws -> String {
        let session = try await auth.refreshedSession()
        let resolved = try await resolveModels()
        let model = thinking ? (resolved.thinking ?? resolved.standard) : (resolved.standard ?? resolved.thinking)
        guard let model else { throw ChatGPTError.noModels }
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.makeTextRequestBody(prompt: prompt, model: model)
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        try Self.check(response: response, data: nil)
        return try await Self.parseStreamedText(bytes.lines)
    }

    /// Builds the plain-text Responses request: store false, stream true.
    nonisolated static func makeTextRequestBody(prompt: String, model: String) throws -> Data {
        let body: [String: Any] = [
            "model": model,
            "input": [["role": "user", "content": prompt]],
            "store": false,
            "stream": true
        ]
        return try JSONSerialization.data(withJSONObject: body)
    }

    // MARK: - Internals

    private nonisolated static func check(response: URLResponse, data: Data?) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let reason = data.flatMap { String(data: $0, encoding: .utf8) } ?? "HTTP \(http.statusCode)"
            throw ChatGPTError.requestFailed(String(reason.prefix(200)))
        }
    }

    /// Parses the SSE stream: prefers the final response object, falls back to
    /// accumulated output-text deltas.
    nonisolated static func parseStreamedText<Lines: AsyncSequence>(_ lines: Lines) async throws -> String where Lines.Element == String {
        var deltas: [String] = []
        var completed: String?
        for try await line in lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            guard let data = payload.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            if let delta = object["delta"] as? String { deltas.append(delta) }
            if let response = object["response"] as? [String: Any],
               let output = response["output"] as? [[String: Any]] {
                completed = output.compactMap { item in
                    ((item["content"] as? [[String: Any]]) ?? []).compactMap { $0["text"] as? String }.joined()
                }.joined()
            }
        }
        if let completed, !completed.isEmpty { return completed }
        let joined = deltas.joined()
        guard !joined.isEmpty else { throw ChatGPTError.emptyResponse }
        return joined
    }
}

private extension String {
    var isThinkingModel: Bool {
        lowercased().contains("thinking") || lowercased().contains("reasoning")
    }
}

private struct ModelsResponse: Decodable {
    struct Entry: Decodable {
        var slug: String
        var displayName: String
        var visibility: String?

        enum CodingKeys: String, CodingKey {
            case slug
            case displayName = "display_name"
            case visibility
        }
    }
    var models: [Entry]
}
