import Foundation

class AIAPIService {
    static let shared = AIAPIService()
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Truncates history to fit within an approximate token budget.
    /// Keeps the most recent messages, dropping oldest first.
    private func truncateHistory(_ history: [ConversationTurn], maxChars: Int) -> [ConversationTurn] {
        var totalChars = 0
        var result: [ConversationTurn] = []

        for turn in history.reversed() {
            let turnChars = turn.textContent.count
            if totalChars + turnChars > maxChars {
                break
            }
            totalChars += turnChars
            result.insert(turn, at: 0)
        }
        return result
    }

    func executeRequest(prompt: String, images: [String]?, history: [ConversationTurn], systemPrompt: String) async throws -> AIResponse {
        let inferenceMode = SettingsManager.inferenceMode
        if inferenceMode == .local {
            return try await executeLocalRequest(prompt: prompt, images: images, history: history, systemPrompt: systemPrompt)
        } else {
            return try await executeAPIRequest(prompt: prompt, images: images, history: history, systemPrompt: systemPrompt)
        }
    }

    private func executeLocalRequest(prompt: String, images: [String]?, history: [ConversationTurn], systemPrompt: String) async throws -> AIResponse {
        let trimmedHistory = truncateHistory(history, maxChars: 16_000)

        var messages: [OllamaChatMessage] = []

        // System message
        let trimmedSystem = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSystem.isEmpty {
            messages.append(OllamaChatMessage(role: "system", content: trimmedSystem))
        }

        // History (text only, no images)
        for turn in trimmedHistory {
            messages.append(OllamaChatMessage(role: turn.role, content: turn.textContent))
        }

        // Current user message (with images)
        messages.append(OllamaChatMessage(role: "user", content: prompt, images: images))

        let payload = OllamaChatRequest(
            model: SettingsManager.localModelName,
            messages: messages,
            stream: false,
            options: ["temperature": 0.0]
        )

        guard let url = URL(string: "http://localhost:11434/api/chat") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)
        request.timeoutInterval = 120

        let (data, response) = try await session.data(for: request)
        if let httpRes = response as? HTTPURLResponse, !(200...299).contains(httpRes.statusCode) {
            let errorStr = String(data: data, encoding: .utf8) ?? "Unknown HTTP ERROR"
            throw NSError(domain: "AssistantLocalAPIError", code: httpRes.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Local API Error: \(errorStr)"])
        }
        let result = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
        return AIResponse(
            text: result.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
            tokenUsage: result.tokenUsage
        )
    }

    private func executeAPIRequest(prompt: String, images: [String]?, history: [ConversationTurn], systemPrompt: String) async throws -> AIResponse {
        let trimmedHistory = truncateHistory(history, maxChars: 100_000)

        guard let url = URL(string: SettingsManager.apiEndpoint),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              url.host != nil else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let apiKey = SettingsManager.apiKey
        let isAnthropic = SettingsManager.selectedProvider == .anthropic

        if !apiKey.isEmpty {
            switch SettingsManager.selectedProvider {
            case .google, .openai, .inception, .openrouter, .custom:
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            case .anthropic:
                request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            }
        }

        if isAnthropic {
            // Build Anthropic messages array with history
            var anthropicMessages: [AnthropicMessage] = []

            for turn in trimmedHistory {
                let content = [AnthropicContent(type: "text", text: turn.textContent, source: nil)]
                anthropicMessages.append(AnthropicMessage(role: turn.role, content: content))
            }

            // Current user message (with images)
            var currentContent: [AnthropicContent] = [AnthropicContent(type: "text", text: prompt, source: nil)]
            if let images = images {
                for img in images {
                    currentContent.append(AnthropicContent(
                        type: "image",
                        text: nil,
                        source: AnthropicImageSource(type: "base64", media_type: "image/jpeg", data: img)
                    ))
                }
            }
            anthropicMessages.append(AnthropicMessage(role: "user", content: currentContent))

            // Use the proper system field
            let trimmedSystem = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            let systemText = trimmedSystem.isEmpty ? nil : trimmedSystem

            let payload = AnthropicRequest(
                model: SettingsManager.apiModelName,
                max_tokens: 4096,
                system: systemText,
                messages: anthropicMessages,
                temperature: 0.0
            )

            request.httpBody = try JSONEncoder().encode(payload)

            let (data, response) = try await session.data(for: request)
            if let httpRes = response as? HTTPURLResponse, !(200...299).contains(httpRes.statusCode) {
                let errorStr = String(data: data, encoding: .utf8) ?? "Unknown HTTP ERROR"
                throw NSError(domain: "AssistantAPIError", code: httpRes.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorStr)"])
            }

            let result = try JSONDecoder().decode(AnthropicResponse.self, from: data)
            if let firstText = result.content.first(where: { $0.type == "text" }) {
                return AIResponse(
                    text: firstText.text.trimmingCharacters(in: .whitespacesAndNewlines),
                    tokenUsage: result.tokenUsage
                )
            } else {
                throw NSError(domain: "AssistantError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No response from API."])
            }
        } else {
            // OpenAI / Google / Custom
            var apiMessages: [APIMessage] = []

            // System message
            let trimmedSystem = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedSystem.isEmpty {
                apiMessages.append(APIMessage(role: "system", content: trimmedSystem))
            }

            // History (text only)
            for turn in trimmedHistory {
                apiMessages.append(APIMessage(role: turn.role, content: turn.textContent))
            }

            // Current user message (with images)
            var content: [MessageContent] = [.text(prompt)]
            if let images = images {
                for img in images {
                    content.append(.image(base64: img))
                }
            }
            apiMessages.append(APIMessage(role: "user", content: content))

            let modelName = SettingsManager.apiModelName
            let isOModel = modelName.hasPrefix("o1") || modelName.hasPrefix("o3")

            let payload = APIRequest(
                model: modelName,
                messages: apiMessages,
                temperature: isOModel ? nil : 0.0,
                max_tokens: 4096,
                stream: false
            )

            request.httpBody = try JSONEncoder().encode(payload)

            let (data, response) = try await session.data(for: request)
            if let httpRes = response as? HTTPURLResponse, !(200...299).contains(httpRes.statusCode) {
                let errorStr = String(data: data, encoding: .utf8) ?? "Unknown HTTP ERROR"
                throw NSError(domain: "AssistantAPIError", code: httpRes.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorStr)"])
            }

            let result = try JSONDecoder().decode(APIResponse.self, from: data)

            if let firstChoice = result.choices.first {
                return AIResponse(
                    text: firstChoice.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
                    tokenUsage: result.tokenUsage
                )
            } else {
                throw NSError(domain: "AssistantError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No response from API."])
            }
        }
    }
}
