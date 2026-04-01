import Foundation
import SwiftUI

// MARK: - App Theme Presets

enum AppTheme: String, CaseIterable, Identifiable {
    case indigo = "Indigo"
    case blue = "Azul"
    case purple = "Roxo"
    case pink = "Rosa"
    case red = "Vermelho"
    case orange = "Laranja"
    case green = "Verde"
    case teal = "Azul Piscina"
    case mono = "Monocromatico"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .indigo:  return Color(red: 0.388, green: 0.400, blue: 0.945)   // #6366F1
        case .blue:    return Color(red: 0.231, green: 0.510, blue: 0.965)   // #3B82F6
        case .purple:  return Color(red: 0.576, green: 0.369, blue: 0.933)   // #935EEE
        case .pink:    return Color(red: 0.925, green: 0.282, blue: 0.600)   // #EC4899
        case .red:     return Color(red: 0.937, green: 0.267, blue: 0.267)   // #EF4444
        case .orange:  return Color(red: 0.961, green: 0.522, blue: 0.133)   // #F58522
        case .green:   return Color(red: 0.133, green: 0.773, blue: 0.369)   // #22C55E
        case .teal:    return Color(red: 0.078, green: 0.714, blue: 0.651)   // #14B8A6
        case .mono:    return Color(red: 0.600, green: 0.600, blue: 0.624)   // #99999F
        }
    }

    var hoverColor: Color {
        switch self {
        case .indigo:  return Color(red: 0.506, green: 0.518, blue: 0.957)
        case .blue:    return Color(red: 0.376, green: 0.612, blue: 0.976)
        case .purple:  return Color(red: 0.678, green: 0.494, blue: 0.953)
        case .pink:    return Color(red: 0.945, green: 0.424, blue: 0.694)
        case .red:     return Color(red: 0.957, green: 0.420, blue: 0.420)
        case .orange:  return Color(red: 0.976, green: 0.635, blue: 0.318)
        case .green:   return Color(red: 0.306, green: 0.843, blue: 0.502)
        case .teal:    return Color(red: 0.243, green: 0.800, blue: 0.745)
        case .mono:    return Color(red: 0.700, green: 0.700, blue: 0.720)
        }
    }

    static var current: AppTheme {
        let raw = UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.indigo.rawValue
        return AppTheme(rawValue: raw) ?? .indigo
    }
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

struct SettingsManager {
    static var inferenceMode: InferenceMode {
        let val = UserDefaults.standard.string(forKey: "inferenceMode") ?? InferenceMode.local.rawValue
        return InferenceMode(rawValue: val) ?? .local
    }
    static var selectedProvider: CloudProvider {
        let val = UserDefaults.standard.string(forKey: "selectedProvider") ?? CloudProvider.google.rawValue
        return CloudProvider(rawValue: val) ?? .google
    }
    static var localModelName: String { UserDefaults.standard.string(forKey: "localModelName") ?? "gemma3:4b" }
    static var apiEndpoint: String { UserDefaults.standard.string(forKey: "apiEndpoint") ?? "https://api.openai.com/v1/chat/completions" }
    static var apiModelName: String { UserDefaults.standard.string(forKey: "apiModelName") ?? "gpt-4o-mini" }
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

    // MARK: - Appearance

    static var popoverOpacity: Double {
        get { UserDefaults.standard.object(forKey: "popoverOpacity") as? Double ?? 1.0 }
        set { UserDefaults.standard.set(newValue, forKey: "popoverOpacity") }
    }

    static var popoverWidth: Double {
        get { UserDefaults.standard.object(forKey: "popoverWidth") as? Double ?? 380.0 }
        set { UserDefaults.standard.set(newValue, forKey: "popoverWidth") }
    }

    static var popoverHeight: Double {
        get { UserDefaults.standard.object(forKey: "popoverHeight") as? Double ?? 480.0 }
        set { UserDefaults.standard.set(newValue, forKey: "popoverHeight") }
    }

    static var popoverVibrancy: Bool {
        get { UserDefaults.standard.object(forKey: "popoverVibrancy") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "popoverVibrancy") }
    }

    static var popoverStealthMode: Bool {
        get { UserDefaults.standard.object(forKey: "popoverStealthMode") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "popoverStealthMode") }
    }

    static var popoverStealthHoverOpacity: Double {
        get { UserDefaults.standard.object(forKey: "popoverStealthHoverOpacity") as? Double ?? 0.4 }
        set { UserDefaults.standard.set(newValue, forKey: "popoverStealthHoverOpacity") }
    }
}
