import Foundation

// MARK: - Shared Constants
enum APIConstants {
    static let localHistoryMaxChars = 16_000
    static let cloudHistoryMaxChars = 100_000
    static let requestTimeoutSeconds: TimeInterval = 120
    static let defaultMaxTokens = 4096
    static let defaultTemperature = 0.0
    static let ollamaEndpoint = "http://localhost:11434/api/chat"
    static let jpegCompressionFactor: CGFloat = 0.7
    static let screenCaptureMaxDimension: CGFloat = 1024
    static let defaultAPIModelName = "gpt-4o-mini"
    static let defaultLocalModelName = "gemma3:4b"
}

enum InferenceMode: String, CaseIterable, Identifiable {
    case local = "Modelos Locais (Ollama)"
    case api = "API na Nuvem (Google, OpenAI, etc)"
    
    var id: String { self.rawValue }
}

enum CloudProvider: String, CaseIterable, Identifiable {
    case google = "Google Gemini"
    case openai = "OpenAI ChatGPT"
    case anthropic = "Anthropic Claude"
    case inception = "Inception Mercury"
    case openrouter = "OpenRouter"
    case custom = "Personalizado (Outros)"

    var id: String { self.rawValue }

    var defaultEndpoint: String {
        switch self {
        case .google:
            return "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
        case .openai:
            return "https://api.openai.com/v1/chat/completions"
        case .anthropic:
            return "https://api.anthropic.com/v1/messages" // Note: Anthropics format is different natively, but proxy endpoints exist. The user requested Anthropic so we add it conceptually.
        case .inception:
            return "https://api.inceptionlabs.ai/v1/chat/completions"
        case .openrouter:
            return "https://openrouter.ai/api/v1/chat/completions"
        case .custom:
            return ""
        }
    }

    var modelsEndpoint: String? {
        switch self {
        case .google:
            return "https://generativelanguage.googleapis.com/v1beta/openai/models"
        case .openai:
            return "https://api.openai.com/v1/models"
        case .anthropic:
            return "https://api.anthropic.com/v1/models"
        case .inception:
            return "https://api.inceptionlabs.ai/v1/models"
        case .openrouter:
            return "https://openrouter.ai/api/v1/models"
        case .custom:
            return nil
        }
    }

    var shortName: String {
        switch self {
        case .google:    return "Gemini"
        case .openai:    return "OpenAI"
        case .anthropic: return "Claude"
        case .inception:  return "Mercury"
        case .openrouter: return "OpenRouter"
        case .custom:     return "Custom"
        }
    }

    var keychainAccount: String {
        switch self {
        case .google:    return "apiKey_google"
        case .openai:    return "apiKey_openai"
        case .anthropic: return "apiKey_anthropic"
        case .inception:  return "apiKey_inception"
        case .openrouter: return "apiKey_openrouter"
        case .custom:     return "apiKey_custom"
        }
    }

    var lastModelKey: String {
        return "lastModel_\(keychainAccount)"
    }

    func saveLastModel(_ model: String) {
        UserDefaults.standard.set(model, forKey: lastModelKey)
    }

    func loadLastModel() -> String? {
        UserDefaults.standard.string(forKey: lastModelKey)
    }

    var availableModels: [String] {
        switch self {
        case .google:
            return ["API não disponível"]
        case .openai:
            return ["API não disponível"]
        case .anthropic:
            return ["API não disponível"]
        case .inception:
            return ["mercury-2"]
        case .openrouter:
            return ["API não disponível"]
        case .custom:
            return ["API não disponível"]
        }
    }
}

// MARK: - Auth Header Helper
extension CloudProvider {
    func applyAuthHeaders(to request: inout URLRequest, apiKey: String) {
        guard !apiKey.isEmpty else { return }
        switch self {
        case .google, .openai, .inception, .openrouter, .custom:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        case .anthropic:
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        }
    }
}

struct SettingsManager {
    static var inferenceMode: InferenceMode {
        let val = UserDefaults.standard.string(forKey: "inferenceMode") ?? InferenceMode.local.rawValue
        return InferenceMode(rawValue: val) ?? .local
    }
    static var selectedProvider: CloudProvider {
        let val = UserDefaults.standard.string(forKey: "selectedProvider") ?? CloudProvider.google.rawValue
        return CloudProvider(rawValue: val) ?? .google
    }
    static var localModelName: String { UserDefaults.standard.string(forKey: "localModelName") ?? APIConstants.defaultLocalModelName }
    static var apiEndpoint: String { UserDefaults.standard.string(forKey: "apiEndpoint") ?? "https://api.openai.com/v1/chat/completions" }
    static var apiModelName: String { UserDefaults.standard.string(forKey: "apiModelName") ?? APIConstants.defaultAPIModelName }
    static var apiKey: String { KeychainManager.shared.loadKey(for: selectedProvider) ?? "" }
    static var systemPrompt: String { UserDefaults.standard.string(forKey: "systemPrompt") ?? "Resposta direta. Pergunta: " }
    static var playNotifications: Bool { UserDefaults.standard.object(forKey: "playNotifications") as? Bool ?? true }

    static var globalTotalTokens: Int {
        get { UserDefaults.standard.integer(forKey: "globalTotalTokens") }
        set { UserDefaults.standard.set(newValue, forKey: "globalTotalTokens") }
    }

    static var globalInputTokens: Int {
        get { UserDefaults.standard.integer(forKey: "globalInputTokens") }
        set { UserDefaults.standard.set(newValue, forKey: "globalInputTokens") }
    }

    static var globalOutputTokens: Int {
        get { UserDefaults.standard.integer(forKey: "globalOutputTokens") }
        set { UserDefaults.standard.set(newValue, forKey: "globalOutputTokens") }
    }

    static func addGlobalTokens(input: Int, output: Int) {
        globalInputTokens += input
        globalOutputTokens += output
        globalTotalTokens += (input + output)
    }

    static func resetGlobalTokens() {
        globalTotalTokens = 0
        globalInputTokens = 0
        globalOutputTokens = 0
    }
}
