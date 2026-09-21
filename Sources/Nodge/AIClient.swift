import Foundation

enum AIClient {
    private static let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!

    static func reply(to text: String, frontmostApp: String) async throws -> String {
        try await completion(
            system: "You are Nodge, a concise voice assistant on macOS. Answer naturally in the user's language. Keep spoken answers under three short sentences unless the user asks for detail. The frontmost app is \(frontmostApp).",
            user: text
        )
    }

    static func textPayload(for goal: String, frontmostApp: String) async throws -> String {
        let text = try await completion(
            system: "Extract the exact text that should be typed to advance the requested computer task. Return only that text, with no quotation marks, label, explanation, or markdown. If the request does not specify text, return an empty string.",
            user: "Frontmost app: \(frontmostApp)\nTask: \(goal)"
        )
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func completion(system: String, user: String) async throws -> String {
        guard let key = await AppSettings.shared.openRouterKey, !key.isEmpty else {
            throw SettingsError("OpenRouter is not configured")
        }
        let model = await AppSettings.shared.responseModel
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Nodge", forHTTPHeaderField: "X-OpenRouter-Title")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let body = String(data: data, encoding: .utf8) ?? ""
            log("AI response failed: HTTP \(status) \(body.prefix(300))")
            throw SettingsError("The response model is unavailable right now")
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
