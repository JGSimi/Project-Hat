import SwiftUI
import KeyboardShortcuts
import ServiceManagement

// MARK: - Advanced Settings Window Manager

class AdvancedSettingsWindowManager: NSObject, NSWindowDelegate {
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
        newWindow.delegate = self
        newWindow.center()

        newWindow.contentView = NSHostingView(rootView: contentView)
        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        window?.contentView = nil
        window = nil
    }
}

// MARK: - Settings Tabs

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "Geral"
    case appearance = "Aparencia"
    case models = "Modelos & IA"
    case prompt = "Comportamento"
    case shortcuts = "Atalhos"

    var id: String { self.rawValue }

    var icon: String {
        switch self {
        case .general:    return "slider.horizontal.3"
        case .appearance: return "paintbrush.fill"
        case .models:     return "cpu.fill"
        case .prompt:     return "text.bubble.fill"
        case .shortcuts:  return "command"
        }
    }
}

// MARK: - Advanced Settings View

struct AdvancedSettingsView: View {
    @State private var selectedTab: SettingsTab? = .general

    @AppStorage("inferenceMode") var inferenceMode: InferenceMode = .local
    @AppStorage("selectedProvider") var selectedProvider: CloudProvider = .google
    @AppStorage("systemPrompt") var systemPrompt: String = "Responda APENAS com a letra e o texto da alternativa. Sem introducoes. Pergunta: "
    @AppStorage("localModelName") var localModelName: String = "gemma3:4b"
    @AppStorage("apiEndpoint") var apiEndpoint: String = "https://api.openai.com/v1/chat/completions"
    @AppStorage("apiModelName") var apiModelName: String = "gpt-4o-mini"
    @AppStorage("playNotifications") var playNotifications: Bool = true
    @AppStorage("popoverOpacity") var popoverOpacity: Double = 1.0
    @AppStorage("popoverWidth") var popoverWidth: Double = 380.0
    @AppStorage("popoverHeight") var popoverHeight: Double = 480.0
    @AppStorage("popoverVibrancy") var popoverVibrancy: Bool = false
    @AppStorage("popoverStealthMode") var popoverStealthMode: Bool = false
    @AppStorage("popoverStealthHoverOpacity") var stealthHoverOpacity: Double = 0.4
    @AppStorage("appTheme") var appTheme: String = AppTheme.indigo.rawValue

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
                        .frame(width: 16, height: 16)
                        .foregroundStyle(Theme.Colors.accentPrimary.opacity(0.6))
                    Text("Configuracoes")
                        .font(Theme.Typography.heading)
                        .foregroundStyle(Theme.Colors.textPrimary.opacity(0.9))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 16)

                MaeDivider()
                    .padding(.horizontal, 12)

                List(selection: $selectedTab) {
                    ForEach(SettingsTab.allCases) { tab in
                        NavigationLink(value: tab) {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(selectedTab == tab
                                            ? Theme.Colors.accentPrimary.opacity(0.1)
                                            : Color.clear
                                        )
                                        .frame(width: 28, height: 28)
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(selectedTab == tab ? Theme.Colors.accentPrimary : Theme.Colors.textSecondary)
                                        .symbolEffect(.bounce, value: selectedTab == tab)
                                }
                                Text(tab.rawValue)
                                    .font(Theme.Typography.bodySmall)
                                    .foregroundStyle(selectedTab == tab ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
                .scrollContentBackground(.hidden)

                // Version footer
                HStack(spacing: 5) {
                    Image("hat-svgrepo-com")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 10, height: 10)
                        .foregroundStyle(Theme.Colors.textMuted.opacity(0.35))
                    Text("Hat v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                        .font(Theme.Typography.micro)
                        .foregroundStyle(Theme.Colors.textMuted.opacity(0.35))
                }
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
                        case .general:    generalSettings.maeStaggered(index: 0)
                        case .appearance: appearanceSettings.maeStaggered(index: 0)
                        case .models:     modelSettings.maeStaggered(index: 0)
                        case .prompt:     promptSettings.maeStaggered(index: 0)
                        case .shortcuts:  shortcutSettings.maeStaggered(index: 0)
                        case .none:
                            Text("Selecione uma categoria")
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                    .frame(maxWidth: 600, alignment: .leading)
                }
                .id(selectedTab)
            }
            .animation(Theme.Animation.smooth, value: selectedTab)
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
            MaeSectionHeader(title: "Sistema & Notificacoes")

            GroupBox {
                VStack(spacing: 0) {
                    HStack {
                        MaeActionRow(title: "Inicio Automatico", subtitle: "Abrir a Hat junto com o Mac", icon: "macwindow", iconColor: Theme.Colors.accentPrimary)
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
                        MaeActionRow(title: "Sons e Alertas", subtitle: "Tocar som quando a resposta terminar", icon: "bell.fill", iconColor: Theme.Colors.accentPrimary)
                        Toggle("", isOn: $playNotifications)
                            .toggleStyle(.switch)
                    }
                    .padding(Theme.Metrics.spacingLarge)

                    MaeDivider()

                    Button {
                        WelcomeWindowManager.shared.showWindow()
                    } label: {
                        HStack {
                            MaeActionRow(title: "Tela de Boas Vindas", subtitle: "Rever apresentacao do aplicativo", icon: "hand.wave.fill", iconColor: Theme.Colors.accentPrimary)
                            Image(systemName: "chevron.right")
                                .font(Theme.Typography.bodySmall)
                                .foregroundStyle(Theme.Colors.textMuted)
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
                            MaeActionRow(title: "Atualizacoes", subtitle: "Buscar nova versao da Hat", icon: "arrow.triangle.2.circlepath", iconColor: Theme.Colors.accentPrimary)
                            Image(systemName: "chevron.right")
                                .font(Theme.Typography.bodySmall)
                                .foregroundStyle(Theme.Colors.textMuted)
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

    // MARK: - Appearance

    private var selectedTheme: AppTheme {
        AppTheme(rawValue: appTheme) ?? .indigo
    }

    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Theme section
            MaeSectionHeader(title: "Tema")

            GroupBox {
                VStack(spacing: 12) {
                    // Theme color grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                        ForEach(AppTheme.allCases) { theme in
                            Button {
                                withAnimation(Theme.Animation.smooth) {
                                    appTheme = theme.rawValue
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    Circle()
                                        .fill(theme.color)
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                        .overlay {
                                            if selectedTheme == theme {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        .shadow(color: theme.color.opacity(selectedTheme == theme ? 0.4 : 0), radius: 6)

                                    Text(theme.rawValue)
                                        .font(.system(size: 9, weight: selectedTheme == theme ? .semibold : .regular))
                                        .foregroundStyle(selectedTheme == theme ? Theme.Colors.textPrimary : Theme.Colors.textMuted)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(Theme.Metrics.spacingLarge)
            }
            .groupBoxStyle(MaeCardStyle())

            Spacer().frame(height: 24)

            // Stealth mode section
            MaeSectionHeader(title: "Modo Discreto")

            GroupBox {
                VStack(spacing: 0) {
                    HStack {
                        MaeActionRow(title: "Modo Discreto", subtitle: "Monocromatico e quase invisivel (2%)", icon: "eye.slash.fill", iconColor: Theme.Colors.warning)
                        Toggle("", isOn: $popoverStealthMode)
                            .toggleStyle(.switch)
                    }
                    .padding(Theme.Metrics.spacingLarge)

                    if popoverStealthMode {
                        MaeDivider()

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                MaeActionRow(title: "Visibilidade ao Hover", subtitle: "Opacidade ao passar o mouse", icon: "eye.fill", iconColor: Theme.Colors.textSecondary)
                                Text("\(Int(stealthHoverOpacity * 100))%")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.textMuted)
                                    .frame(width: 36, alignment: .trailing)
                            }
                            Slider(value: $stealthHoverOpacity, in: 0.2...0.8, step: 0.05)
                                .tint(Theme.Colors.warning)
                        }
                        .padding(Theme.Metrics.spacingLarge)
                        .transition(.maeSlideUp)

                        MaeDivider()

                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.Colors.textMuted)
                            Text("Visual monocromatico com 2% de visibilidade. Ao passar o mouse, aparece com a opacidade configurada acima.")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textMuted)
                        }
                        .padding(Theme.Metrics.spacingLarge)
                        .transition(.maeSlideUp)
                    }
                }
            }
            .groupBoxStyle(MaeCardStyle())
            .animation(Theme.Animation.smooth, value: popoverStealthMode)

            Spacer().frame(height: 24)

            // Transparency section
            MaeSectionHeader(title: "Transparencia")

            GroupBox {
                VStack(spacing: 0) {
                    HStack {
                        MaeActionRow(title: "Fundo Vibrante", subtitle: "Ativar efeito de transparencia e desfoque", icon: "drop.halffull", iconColor: Theme.Colors.accentPrimary)
                        Toggle("", isOn: $popoverVibrancy)
                            .toggleStyle(.switch)
                    }
                    .padding(Theme.Metrics.spacingLarge)

                    if popoverVibrancy {
                        MaeDivider()

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                MaeActionRow(title: "Opacidade", subtitle: "Controle a transparencia do fundo", icon: "circle.lefthalf.filled", iconColor: Theme.Colors.textSecondary)
                                Text("\(Int(popoverOpacity * 100))%")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.textMuted)
                                    .frame(width: 36, alignment: .trailing)
                            }
                            Slider(value: $popoverOpacity, in: 0.3...1.0, step: 0.05)
                                .tint(Theme.Colors.accentPrimary)
                        }
                        .padding(Theme.Metrics.spacingLarge)
                        .transition(.maeSlideUp)
                    }
                }
            }
            .groupBoxStyle(MaeCardStyle())
            .animation(Theme.Animation.smooth, value: popoverVibrancy)

            Spacer().frame(height: 24)

            // Size section
            MaeSectionHeader(title: "Tamanho do Popover")

            GroupBox {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            MaeActionRow(title: "Largura", subtitle: nil, icon: "arrow.left.and.right", iconColor: Theme.Colors.textSecondary)
                            Text("\(Int(popoverWidth))px")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textMuted)
                                .frame(width: 48, alignment: .trailing)
                        }
                        Slider(value: $popoverWidth, in: 320...600, step: 10)
                            .tint(Theme.Colors.accentPrimary)
                    }
                    .padding(Theme.Metrics.spacingLarge)

                    MaeDivider()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            MaeActionRow(title: "Altura", subtitle: nil, icon: "arrow.up.and.down", iconColor: Theme.Colors.textSecondary)
                            Text("\(Int(popoverHeight))px")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textMuted)
                                .frame(width: 48, alignment: .trailing)
                        }
                        Slider(value: $popoverHeight, in: 360...720, step: 10)
                            .tint(Theme.Colors.accentPrimary)
                    }
                    .padding(Theme.Metrics.spacingLarge)

                    MaeDivider()

                    Button {
                        withAnimation(Theme.Animation.smooth) {
                            popoverWidth = 380
                            popoverHeight = 480
                        }
                    } label: {
                        HStack {
                            MaeActionRow(title: "Restaurar Padrao", subtitle: "Voltar para 380 x 480", icon: "arrow.counterclockwise", iconColor: Theme.Colors.textSecondary)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(Theme.Metrics.spacingLarge)
                    .disabled(popoverWidth == 380 && popoverHeight == 480)
                    .opacity(popoverWidth == 380 && popoverHeight == 480 ? 0.5 : 1.0)
                }
            }
            .groupBoxStyle(MaeCardStyle())
        }
    }

    // MARK: - Models

    private var modelSettings: some View {
        VStack(alignment: .leading, spacing: 20) {

            VStack(alignment: .leading, spacing: 0) {
                MaeSectionHeader(title: "Modo de Inferencia")

                GroupBox {
                    Picker("", selection: $inferenceMode) {
                        ForEach(InferenceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                    .padding(Theme.Metrics.spacingLarge)
                    .accessibilityLabel("Modo de Inferencia")
                }
                .groupBoxStyle(MaeCardStyle())
            }

            if inferenceMode == .local {
                VStack(alignment: .leading, spacing: 0) {
                    MaeSectionHeader(title: "Ollama (Local)")

                    GroupBox {
                        VStack(spacing: 0) {
                            HStack {
                                MaeActionRow(title: "Nome do Modelo", subtitle: "Deve estar baixado no Ollama", icon: "desktopcomputer", iconColor: Theme.Colors.accentPrimary)
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
                                MaeActionRow(title: "Provedor", icon: "cloud.fill", iconColor: Theme.Colors.accentPrimary)
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
                                    MaeActionRow(title: "Modelo", icon: "server.rack", iconColor: Theme.Colors.accentPrimary)

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
                                MaeActionRow(title: "Chave de API (Autenticacao)", icon: "key.fill", iconColor: Theme.Colors.accentPrimary)

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
                        .stroke(Theme.Colors.border, lineWidth: 0.5)
                )
        }
    }

    // MARK: - Shortcuts

    private var shortcutSettings: some View {
        VStack(alignment: .leading, spacing: 0) {
            MaeSectionHeader(title: "Acoes Globais")

            GroupBox {
                VStack(spacing: 0) {
                    HStack {
                        MaeActionRow(title: "Analisar Clipboard", subtitle: "Manda o texto copiado para a IA", icon: "doc.on.clipboard", iconColor: Theme.Colors.accentPrimary)
                        Spacer()
                        KeyboardShortcuts.Recorder(for: .processClipboard)
                    }
                    .padding(Theme.Metrics.spacingLarge)

                    MaeDivider()

                    HStack {
                        MaeActionRow(title: "Analisar Tela", subtitle: "Tira print continuo e analisa a tela", icon: "viewfinder", iconColor: Theme.Colors.accentPrimary)
                        Spacer()
                        KeyboardShortcuts.Recorder(for: .processScreen)
                    }
                    .padding(Theme.Metrics.spacingLarge)

                    MaeDivider()

                    HStack {
                        MaeActionRow(title: "Input Rapido", subtitle: "Abre overlay para perguntar sem abrir o chat", icon: "text.cursor", iconColor: Theme.Colors.accentPrimary)
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
