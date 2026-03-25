import SwiftUI
import KeyboardShortcuts
import ServiceManagement

// MARK: - Advanced Settings Window Manager

class AdvancedSettingsWindowManager {
    static let shared = AdvancedSettingsWindowManager()
    private var window: NSWindow?

    func showWindow() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = AdvancedSettingsView()
        
        let windowRect = NSRect(x: 0, y: 0, width: 700, height: 500)
        let newWindow = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.isMovableByWindowBackground = true
        newWindow.isReleasedWhenClosed = false
        newWindow.center()
        
        newWindow.contentView = NSHostingView(rootView: contentView)
        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Settings Tabs

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "Geral"
    case models = "Modelos & IA"
    case prompt = "Comportamento"
    case shortcuts = "Atalhos"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .general:   return "slider.horizontal.3"
        case .models:    return "cpu.fill"
        case .prompt:    return "text.bubble.fill"
        case .shortcuts: return "command"
        }
    }
}

// MARK: - Advanced Settings View

struct AdvancedSettingsView: View {
    @State private var selectedTab: SettingsTab? = .general
    
    @AppStorage("inferenceMode") var inferenceMode: InferenceMode = .local
    @AppStorage("selectedProvider") var selectedProvider: CloudProvider = .google
    @AppStorage("systemPrompt") var systemPrompt: String = "Responda APENAS com a letra e o texto da alternativa. Sem introduções. Pergunta: "
    @AppStorage("localModelName") var localModelName: String = "gemma3:4b"
    @AppStorage("apiEndpoint") var apiEndpoint: String = "https://api.openai.com/v1/chat/completions"
    @AppStorage("apiModelName") var apiModelName: String = "gpt-4o-mini"
    @AppStorage("playNotifications") var playNotifications: Bool = true
    
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @State private var apiKey: String = KeychainManager.shared.loadKey(for: SettingsManager.selectedProvider) ?? ""
    @State private var fetchedModels: [String] = []
    @State private var isFetchingModels: Bool = false
    @State private var apiKeyTask: Task<Void, Never>? = nil
    @State private var fetchModelsTask: Task<Void, Never>? = nil
    @State private var modelSearchText = ""

    private var filteredDisplayModels: [String] {
        let source = !fetchedModels.isEmpty ? fetchedModels : selectedProvider.availableModels
        if modelSearchText.isEmpty { return source }
        return source.filter { $0.localizedCaseInsensitiveContains(modelSearchText) }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Sidebar header
                HStack(spacing: 10) {
                    Image("hat-svgrepo-com")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(Theme.Colors.accent.opacity(0.7))
                    Text("Configurações")
                        .font(Theme.Typography.heading)
                        .foregroundStyle(Theme.Colors.textPrimary.opacity(0.9))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 16)

                List(selection: $selectedTab) {
                    ForEach(SettingsTab.allCases) { tab in
                        NavigationLink(value: tab) {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(selectedTab == tab ? Theme.Colors.accentOrange.opacity(0.15) : .clear)
                                        .frame(width: 28, height: 28)
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(selectedTab == tab ? Theme.Colors.accentOrange : Theme.Colors.textSecondary)
                                        .symbolEffect(.bounce, value: selectedTab == tab)
                                }
                                Text(tab.rawValue)
                                    .font(Theme.Typography.bodySmall)
                                    .foregroundStyle(selectedTab == tab ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .scrollContentBackground(.hidden)

                // Version footer
                Text("Hat v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Colors.textMuted.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 12)
            }
            .background(Theme.Colors.background)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 250)
            
        } detail: {
            ZStack {
                Theme.Colors.backgroundSecondary.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Metrics.spacingXLarge) {
                        
                        Text(selectedTab?.rawValue ?? "")
                            .font(Theme.Typography.title)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .padding(.top, 40)
                            .padding(.bottom, 8)
                        
                        switch selectedTab {
                        case .general:   generalSettings.maeStaggered(index: 0)
                        case .models:    modelSettings.maeStaggered(index: 0)
                        case .prompt:    promptSettings.maeStaggered(index: 0)
                        case .shortcuts: shortcutSettings.maeStaggered(index: 0)
                        case .none:
                            Text("Selecione uma categoria")
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                    .frame(maxWidth: 600, alignment: .leading)
                }
                .id(selectedTab)  // Force re-render for animation
            }
            .animation(Theme.Animation.responsive, value: selectedTab)
            .task {
                await reloadModels()
            }
            .onDisappear {
                apiKeyTask?.cancel()
                fetchModelsTask?.cancel()
            }
        }
    }
    
    // MARK: - General
    
    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 0) {
            MaeSectionHeader(title: "Sistema & Notificações")
            
            GroupBox {
                VStack(spacing: 0) {
                    HStack {
                        MaeActionRow(title: "Início Automático", subtitle: "Abrir a Hat junto com o Mac", icon: "macwindow", iconColor: Theme.Colors.accentOrange)
                        Toggle("", isOn: $launchAtLogin)
                            .toggleStyle(.switch)
                    }
                    .padding(Theme.Metrics.spacingLarge)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue { try SMAppService.mainApp.register() }
                            else { try SMAppService.mainApp.unregister() }
                        } catch {
                            print("Failed to change launchAtLogin state: \(error.localizedDescription)")
                            launchAtLogin = !newValue
                        }
                    }
                    
                    MaeDivider()
                    
                    HStack {
                        MaeActionRow(title: "Sons e Alertas", subtitle: "Tocar som quando a resposta terminar", icon: "bell.fill", iconColor: Theme.Colors.accentOrange)
                        Toggle("", isOn: $playNotifications)
                            .toggleStyle(.switch)
                    }
                    .padding(Theme.Metrics.spacingLarge)
                    
                    MaeDivider()
                    
                    Button {
                        WelcomeWindowManager.shared.showWindow()
                    } label: {
                        HStack {
                            MaeActionRow(title: "Tela de Boas Vindas", subtitle: "Rever apresentação do aplicativo", icon: "hand.wave.fill", iconColor: Theme.Colors.accentOrange)
                            Image(systemName: "chevron.right")
                                .font(Theme.Typography.bodySmall)
                                .foregroundStyle(Theme.Colors.textMuted)
                                .symbolEffect(.bounce, options: .nonRepeating)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(Theme.Metrics.spacingLarge)
                    
                    MaeDivider()
                    
                    Button {
                        UpdaterController.shared.checkForUpdates()
                    } label: {
                        HStack {
                            MaeActionRow(title: "Atualizações", subtitle: "Buscar nova versão da Hat", icon: "arrow.triangle.2.circlepath", iconColor: Theme.Colors.accentOrange)
                            Image(systemName: "chevron.right")
                                .font(Theme.Typography.bodySmall)
                                .foregroundStyle(Theme.Colors.textMuted)
                                .symbolEffect(.bounce, options: .nonRepeating)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(Theme.Metrics.spacingLarge)
                }
            }
            .groupBoxStyle(MaeCardStyle())
        }
    }
    
    // MARK: - Models
    
    private var modelSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            VStack(alignment: .leading, spacing: 0) {
                MaeSectionHeader(title: "Modo de Inferência")
                
                GroupBox {
                    Picker("", selection: $inferenceMode) {
                        ForEach(InferenceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                    .padding(Theme.Metrics.spacingLarge)
                    .accessibilityLabel("Modo de Inferência")
                }
                .groupBoxStyle(MaeCardStyle())
            }
            
            if inferenceMode == .local {
                VStack(alignment: .leading, spacing: 0) {
                    MaeSectionHeader(title: "Ollama (Local)")
                    
                    GroupBox {
                        VStack(spacing: 0) {
                            HStack {
                                MaeActionRow(title: "Nome do Modelo", subtitle: "Deve estar baixado no Ollama", icon: "desktopcomputer", iconColor: Theme.Colors.accentOrange)
                                Spacer()
                                TextField("ex: gemma3:4b", text: $localModelName)
                                    .maeInputStyle(cornerRadius: Theme.Metrics.radiusSmall)
                                    .frame(width: 150)
                                    .accessibilityLabel("Nome do Modelo Ollama")
                            }
                            .padding(Theme.Metrics.spacingLarge)
                        }
                    }
                    .groupBoxStyle(MaeCardStyle())
                }
                
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    MaeSectionHeader(title: "Cloud API")
                    
                    GroupBox {
                        VStack(spacing: 0) {
                            HStack {
                                MaeActionRow(title: "Provedor", icon: "cloud.fill", iconColor: Theme.Colors.accentOrange)
                                Spacer()
                                Picker("", selection: $selectedProvider) {
                                    ForEach(CloudProvider.allCases) { provider in
                                        Text(provider.rawValue).tag(provider)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 160)
                                .accessibilityLabel("Provedor Cloud")
                            }
                            .padding(Theme.Metrics.spacingLarge)
                            .onChange(of: selectedProvider) { oldValue, newValue in
                                oldValue.saveLastModel(apiModelName)
                                apiKey = KeychainManager.shared.loadKey(for: newValue) ?? ""
                                fetchModelsTask?.cancel()
                                fetchModelsTask = Task {
                                    try? await Task.sleep(nanoseconds: 300_000_000)
                                    guard !Task.isCancelled else { return }
                                    apiEndpoint = newValue.defaultEndpoint
                                    fetchedModels = []
                                    modelSearchText = ""
                                    if let savedModel = newValue.loadLastModel() {
                                        apiModelName = savedModel
                                    } else if let firstModel = newValue.availableModels.first {
                                        apiModelName = firstModel
                                    }
                                    await reloadModels()
                                }
                            }
                            
                            MaeDivider()
                            
                            if selectedProvider == .custom {
                                VStack(spacing: 12) {
                                    HStack {
                                        Text("URL Custom:")
                                            .foregroundStyle(Theme.Colors.textPrimary)
                                            .font(Theme.Typography.bodySmall)
                                        TextField("URL", text: $apiEndpoint)
                                            .maeInputStyle(cornerRadius: Theme.Metrics.radiusSmall)
                                            .accessibilityLabel("URL da API Customizada")
                                    }
                                    HStack {
                                        Text("Modelo:")
                                            .foregroundStyle(Theme.Colors.textPrimary)
                                            .font(Theme.Typography.bodySmall)
                                        TextField("Nome do Modelo", text: $apiModelName)
                                            .maeInputStyle(cornerRadius: Theme.Metrics.radiusSmall)
                                            .accessibilityLabel("Nome do Modelo Customizado")
                                    }
                                }
                                .padding(Theme.Metrics.spacingLarge)
                                
                            } else {
                                HStack {
                                    MaeActionRow(title: "Modelo", icon: "server.rack", iconColor: Theme.Colors.accentOrange)
                                    
                                    if isFetchingModels {
                                        ProgressView().controlSize(.small).padding(.trailing, 8)
                                    }
                                    
                                    Picker("", selection: $apiModelName) {
                                        ForEach(filteredDisplayModels, id: \.self) { model in
                                            Text(model).tag(model)
                                        }
                                    }
                                    .labelsHidden()
                                    .frame(width: 160)
                                    .accessibilityLabel("Modelo Cloud")
                                    .onChange(of: apiModelName) { _, newModel in
                                        selectedProvider.saveLastModel(newModel)
                                    }
                                }
                                .padding(Theme.Metrics.spacingLarge)

                                if (!fetchedModels.isEmpty ? fetchedModels : selectedProvider.availableModels).count > 5 {
                                    HStack {
                                        Spacer()
                                        TextField("Filtrar modelos...", text: $modelSearchText)
                                            .maeInputStyle(cornerRadius: Theme.Metrics.radiusSmall)
                                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                                            .frame(width: 160)
                                            .accessibilityLabel("Filtrar modelos")
                                    }
                                    .padding(.horizontal, Theme.Metrics.spacingLarge)
                                    .padding(.bottom, Theme.Metrics.spacingDefault)
                                }
                            }
                            
                            MaeDivider()
                            
                            VStack(alignment: .leading, spacing: 12) {
                                MaeActionRow(title: "Chave de API (Autenticação)", icon: "key.fill", iconColor: Theme.Colors.accentOrange)
                                
                                SecureField("Cole sua API Key...", text: $apiKey)
                                    .maeInputStyle(cornerRadius: Theme.Metrics.radiusSmall)
                                    .accessibilityLabel("Chave de API")
                                    .onChange(of: apiKey) { _, newValue in
                                        apiKeyTask?.cancel()
                                        apiKeyTask = Task {
                                            try? await Task.sleep(nanoseconds: 500_000_000)
                                            guard !Task.isCancelled else { return }
                                            KeychainManager.shared.saveKey(newValue, for: selectedProvider)
                                            await reloadModels()
                                        }
                                    }
                            }
                            .padding(Theme.Metrics.spacingLarge)
                        }
                    }
                    .groupBoxStyle(MaeCardStyle())
                }
            }
        }
    }
    
    // MARK: - Prompt
    
    private var promptSettings: some View {
        VStack(alignment: .leading, spacing: 0) {
            MaeSectionHeader(title: "System Prompt")
            
            Text("Defina a personalidade e regras de resposta da IA.")
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(.bottom, 12)
            
            TextEditor(text: $systemPrompt)
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(12)
                .frame(minHeight: 180)
                .scrollContentBackground(.hidden)
                .background(Theme.Colors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Metrics.radiusMedium)
                        .stroke(Theme.Colors.border, lineWidth: 1)
                )
        }
    }
    
    // MARK: - Shortcuts
    
    private var shortcutSettings: some View {
        VStack(alignment: .leading, spacing: 0) {
            MaeSectionHeader(title: "Ações Globais")
            
            GroupBox {
                VStack(spacing: 0) {
                    HStack {
                        MaeActionRow(title: "Analisar Clipboard", subtitle: "Manda o texto copiado para a IA", icon: "doc.on.clipboard", iconColor: Theme.Colors.accentOrange)
                        Spacer()
                        KeyboardShortcuts.Recorder(for: .processClipboard)
                    }
                    .padding(Theme.Metrics.spacingLarge)
                    
                    MaeDivider()
                    
                    HStack {
                        MaeActionRow(title: "Analisar Tela", subtitle: "Tira print contínuo e analisa a tela", icon: "viewfinder", iconColor: Theme.Colors.accentOrange)
                        Spacer()
                        KeyboardShortcuts.Recorder(for: .processScreen)
                    }
                    .padding(Theme.Metrics.spacingLarge)
                    
                    MaeDivider()
                    
                    HStack {
                        MaeActionRow(title: "Input Rápido", subtitle: "Abre overlay para perguntar sem abrir o chat", icon: "text.cursor", iconColor: Theme.Colors.accentOrange)
                        Spacer()
                        KeyboardShortcuts.Recorder(for: .quickInput)
                    }
                    .padding(Theme.Metrics.spacingLarge)
                }
            }
            .groupBoxStyle(MaeCardStyle())
        }
    }
    
    // MARK: - Helpers
    
    private func reloadModels() async {
        guard selectedProvider.modelsEndpoint != nil, !apiKey.isEmpty else { return }
        isFetchingModels = true
        defer { isFetchingModels = false }
        
        do {
            let models = try await ModelFetcher.shared.fetchModels(for: selectedProvider, apiKey: apiKey)
            guard !Task.isCancelled else { return }
            if !models.isEmpty {
                fetchedModels = models
                if !models.contains(apiModelName), let first = models.first {
                    apiModelName = first
                }
            }
        } catch {
            print("Failed to fetch dynamically: \(error)")
        }
    }
}
