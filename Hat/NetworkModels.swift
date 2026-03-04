import Foundation

// MARK: - Conversation History (shared across providers)
struct ConversationTurn {
    let role: String        // "user" or "assistant"
    let textContent: String
}

// MARK: - Ollama Models (legacy single-turn)
struct OllamaRequest: Codable {
    let model: String
    let prompt: String
    let stream: Bool
    let images: [String]?
    let options: [String: Double]
}

struct OllamaResponse: Decodable {
    let response: String
}

// MARK: - Ollama Chat Models (multi-turn)
struct OllamaChatRequest: Codable {
    let model: String
    let messages: [OllamaChatMessage]
    let stream: Bool
    let options: [String: Double]
}

struct OllamaChatMessage: Codable {
    let role: String
    let content: String
    let images: [String]?

    init(role: String, content: String, images: [String]? = nil) {
        self.role = role
        self.content = content
        self.images = images
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        try container.encode(content, forKey: .content)
        if let images = images, !images.isEmpty {
            try container.encode(images, forKey: .images)
        }
    }

    enum CodingKeys: String, CodingKey {
        case role, content, images
    }
}

struct OllamaChatResponse: Decodable {
    let message: OllamaChatResponseMessage
}

struct OllamaChatResponseMessage: Decodable {
    let role: String
    let content: String
}

// MARK: - API Models (OpenAI Compatible)
struct APIRequest: Codable {
    let model: String
    let messages: [APIMessage]
    let temperature: Double?
    let max_tokens: Int?
    let stream: Bool
}

struct APIMessage: Codable {
    let role: String
    let textContent: String?
    let arrayContent: [MessageContent]?
    
    init(role: String, content: String) {
        self.role = role
        self.textContent = content
        self.arrayContent = nil
    }
    
    init(role: String, content: [MessageContent]) {
        self.role = role
        self.textContent = nil
        self.arrayContent = content
    }
    
    enum CodingKeys: String, CodingKey {
        case role, content
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        if let textContent = textContent {
            try container.encode(textContent, forKey: .content)
        } else if let arrayContent = arrayContent {
            try container.encode(arrayContent, forKey: .content)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.role = try container.decode(String.self, forKey: .role)
        if let text = try? container.decode(String.self, forKey: .content) {
            self.textContent = text
            self.arrayContent = nil
        } else if let array = try? container.decode([MessageContent].self, forKey: .content) {
            self.arrayContent = array
            self.textContent = nil
        } else {
            self.textContent = nil
            self.arrayContent = nil
        }
    }
}

struct MessageContent: Codable {
    let type: String
    let text: String?
    let image_url: ImageURL?
    
    struct ImageURL: Codable {
        let url: String
    }
    
    static func text(_ text: String) -> MessageContent {
        return MessageContent(type: "text", text: text, image_url: nil)
    }
    
    static func image(base64: String) -> MessageContent {
        return MessageContent(type: "image_url", text: nil, image_url: ImageURL(url: "data:image/png;base64,\(base64)"))
    }
}

struct APIResponse: Decodable {
    let choices: [Choice]
    
    struct Choice: Decodable {
        let message: ResponseMessage
    }
    
    struct ResponseMessage: Decodable {
        let content: String
    }
}

// MARK: - Anthropic Models
struct AnthropicRequest: Codable {
    let model: String
    let max_tokens: Int
    let system: String?
    let messages: [AnthropicMessage]
    let temperature: Double
}

struct AnthropicMessage: Codable {
    let role: String
    let content: [AnthropicContent]
}

struct AnthropicContent: Codable {
    let type: String
    let text: String?
    let source: AnthropicImageSource?
}

struct AnthropicImageSource: Codable {
    let type: String
    let media_type: String
    let data: String
}

struct AnthropicResponse: Decodable {
    let content: [AnthropicResponseContent]
    
    struct AnthropicResponseContent: Decodable {
        let type: String
        let text: String
    }
}

// MARK: - API Model Fetching
struct APIModelListResponse: Decodable {
    let data: [APIModelItem]
}

struct APIModelItem: Decodable, Identifiable {
    let id: String
}
