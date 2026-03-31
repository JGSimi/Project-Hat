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

    // MARK: - Streaming

    func executeStreamingRequest(prompt: String, images: [String]?, history: [ConversationTurn], systemPrompt: String) -> AsyncThrowingStream<StreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let inferenceMode = SettingsManager.inferenceMode
                    if inferenceMode == .local {
                        try await self.streamLocalRequest(prompt: prompt, images: images, history: history, systemPrompt: systemPrompt, continuation: continuation)
                    } else {
                        try await self.streamAPIRequest(prompt: prompt, images: images, history: history, systemPrompt: systemPrompt, continuation: continuation)
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func streamLocalRequest(prompt: String, images: [String]?, history: [ConversationTurn], systemPrompt: String, continuation: AsyncThrowingStream<StreamChunk, Error>.Continuation) async throws {
        let trimmedHistory = truncateHistory(history, maxChars: 16_000)

        var messages: [OllamaChatMessage] = []
        let trimmedSystem = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSystem.isEmpty {
            messages.append(OllamaChatMessage(role: "system", content: trimmedSystem))
        }
        for turn in trimmedHistory {
            messages.append(OllamaChatMessage(role: turn.role, content: turn.textContent))
        }
        messages.append(OllamaChatMessage(role: "user", content: prompt, images: images))

        let payload = OllamaChatRequest(
            model: SettingsManager.localModelName,
            messages: messages,
            stream: true,
            options: ["temperature": 0.0]
        )

        guard let url = URL(string: "http://localhost:11434/api/chat") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)
        request.timeoutInterval = 120

        let (bytes, response) = try await session.bytes(for: request)
        if let httpRes = response as? HTTPURLResponse, !(200...299).contains(httpRes.statusCode) {
            throw NSError(domain: "AssistantLocalAPIError", code: httpRes.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Local API Error: HTTP \(httpRes.statusCode)"])
        }

        let decoder = JSONDecoder()
        for try await line in bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { continue }

            let chunk = try decoder.decode(OllamaChatResponse.self, from: data)
            let isDone = chunk.eval_count != nil
            continuation.yield(StreamChunk(
                text: chunk.message.content,
                tokenUsage: isDone ? chunk.tokenUsage : nil,
                isFinished: isDone
            ))
            if isDone { break }
        }
        continuation.finish()
    }

    private func streamAPIRequest(prompt: String, images: [String]?, history: [ConversationTurn], systemPrompt: String, continuation: AsyncThrowingStream<StreamChunk, Error>.Continuation) async throws {
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
            try await streamAnthropicRequest(request: &request, prompt: prompt, images: images, history: trimmedHistory, systemPrompt: systemPrompt, continuation: continuation)
        } else {
            try await streamOpenAIRequest(request: &request, prompt: prompt, images: images, history: trimmedHistory, systemPrompt: systemPrompt, continuation: continuation)
        }
    }

    private func streamOpenAIRequest(request: inout URLRequest, prompt: String, images: [String]?, history: [ConversationTurn], systemPrompt: String, continuation: AsyncThrowingStream<StreamChunk, Error>.Continuation) async throws {
        var apiMessages: [APIMessage] = []
        let trimmedSystem = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSystem.isEmpty {
            apiMessages.append(APIMessage(role: "system", content: trimmedSystem))
        }
        for turn in history {
            apiMessages.append(APIMessage(role: turn.role, content: turn.textContent))
        }
        var content: [MessageContent] = [.text(prompt)]
        if let images = images {
            for img in images { content.append(.image(base64: img)) }
        }
        apiMessages.append(APIMessage(role: "user", content: content))

        let modelName = SettingsManager.apiModelName
        let isOModel = modelName.hasPrefix("o1") || modelName.hasPrefix("o3")

        let payload = APIRequest(
            model: modelName,
            messages: apiMessages,
            temperature: isOModel ? nil : 0.0,
            max_tokens: 4096,
            stream: true
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (bytes, response) = try await session.bytes(for: request)
        if let httpRes = response as? HTTPURLResponse, !(200...299).contains(httpRes.statusCode) {
            // Read error body from the stream
            var errorData = Data()
            for try await byte in bytes { errorData.append(byte) }
            let errorStr = String(data: errorData, encoding: .utf8) ?? "HTTP \(httpRes.statusCode)"
            throw NSError(domain: "AssistantAPIError", code: httpRes.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorStr)"])
        }

        let decoder = JSONDecoder()
        for try await line in bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("data: ") else { continue }
            let jsonStr = String(trimmed.dropFirst(6))
            if jsonStr == "[DONE]" {
                continuation.yield(StreamChunk(text: "", tokenUsage: nil, isFinished: true))
                break
            }
            guard let data = jsonStr.data(using: .utf8) else { continue }
            guard let delta = try? decoder.decode(APIStreamDelta.self, from: data) else { continue }

            if let text = delta.choices?.first?.delta?.content, !text.isEmpty {
                continuation.yield(StreamChunk(text: text, tokenUsage: nil, isFinished: false))
            }
            if let usage = delta.usage, let input = usage.prompt_tokens, let output = usage.completion_tokens {
                continuation.yield(StreamChunk(text: "", tokenUsage: TokenUsage(inputTokens: input, outputTokens: output), isFinished: false))
            }
        }
        continuation.finish()
    }

    private func streamAnthropicRequest(request: inout URLRequest, prompt: String, images: [String]?, history: [ConversationTurn], systemPrompt: String, continuation: AsyncThrowingStream<StreamChunk, Error>.Continuation) async throws {
        var anthropicMessages: [AnthropicMessage] = []
        for turn in history {
            let content = [AnthropicContent(type: "text", text: turn.textContent, source: nil)]
            anthropicMessages.append(AnthropicMessage(role: turn.role, content: content))
        }
        var currentContent: [AnthropicContent] = [AnthropicContent(type: "text", text: prompt, source: nil)]
        if let images = images {
            for img in images {
                currentContent.append(AnthropicContent(
                    type: "image", text: nil,
                    source: AnthropicImageSource(type: "base64", media_type: "image/jpeg", data: img)
                ))
            }
        }
        anthropicMessages.append(AnthropicMessage(role: "user", content: currentContent))

        let trimmedSystem = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = AnthropicStreamRequest(
            model: SettingsManager.apiModelName,
            max_tokens: 4096,
            system: trimmedSystem.isEmpty ? nil : trimmedSystem,
            messages: anthropicMessages,
            temperature: 0.0,
            stream: true
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (bytes, response) = try await session.bytes(for: request)
        if let httpRes = response as? HTTPURLResponse, !(200...299).contains(httpRes.statusCode) {
            var errorData = Data()
            for try await byte in bytes { errorData.append(byte) }
            let errorStr = String(data: errorData, encoding: .utf8) ?? "HTTP \(httpRes.statusCode)"
            throw NSError(domain: "AssistantAPIError", code: httpRes.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorStr)"])
        }

        let decoder = JSONDecoder()
        var finalUsage: TokenUsage?
        for try await line in bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("data: ") else { continue }
            let jsonStr = String(trimmed.dropFirst(6))
            guard let data = jsonStr.data(using: .utf8) else { continue }
            guard let event = try? decoder.decode(AnthropicStreamEvent.self, from: data) else { continue }

            switch event.type {
            case "content_block_delta":
                if let text = event.delta?.text, !text.isEmpty {
                    continuation.yield(StreamChunk(text: text, tokenUsage: nil, isFinished: false))
                }
            case "message_delta":
                if let usage = event.usage, let input = usage.input_tokens, let output = usage.output_tokens {
                    finalUsage = TokenUsage(inputTokens: input, outputTokens: output)
                }
            case "message_stop":
                continuation.yield(StreamChunk(text: "", tokenUsage: finalUsage, isFinished: true))
            default:
                break
            }
        }
        continuation.finish()
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
