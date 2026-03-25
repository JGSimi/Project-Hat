import SwiftUI

struct SettingsView: View {
    @Binding var isPresented: Bool
    
    @AppStorage("inferenceMode") var inferenceMode: InferenceMode = .local
    @AppStorage("selectedProvider") var selectedProvider: CloudProvider = .google
    @AppStorage("apiModelName") var apiModelName: String = "gpt-5.2"
    @AppStorage("localModelName") var localModelName: String = "gemma3:4b"
    @AppStorage("globalTotalTokens") var globalTotalTokens: Int = 0
    @AppStorage("globalInputTokens") var globalInputTokens: Int = 0
    @AppStorage("globalOutputTokens") var globalOutputTokens: Int = 0

    @State private var quickModels: [String] = []
    @State private var isFetchingQuickModels = false
    @State private var quickModelTask: Task<Void, Never>? = nil
    @State private var quickModelSearchText = ""
    @State private var tokenBarAppeared = false

    private var filteredQuickModels: [String] {
        if quickModelSearchText.isEmpty { return quickModels }
        return quickModels.filter { $0.localizedCaseInsensitiveContains(quickModelSearchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Panel header
            HStack(spacing: 10) {
                Image("hat-svgrepo-com")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(Theme.Colors.accentOrange.opacity(0.7))
                Text("Configurações")
                    .font(Theme.Typography.heading)
                    .foregroundStyle(Theme.Colors.textPrimary.opacity(0.9))
                Spacer()
            }
            .padding(.horizontal, Theme.Metrics.spacingLarge)
            .padding(.top, 20)
            .padding(.bottom, 4)

            ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                MaeSectionHeader(title: "Modo de Inferência")

                // Mode Picker + Active Model
                VStack(alignment: .leading, spacing: 12) {
                    Picker("", selection: $inferenceMode) {
                        ForEach(InferenceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    HStack(spacing: 6) {
                        MaeTag(
                            label: inferenceMode == .local ? localModelName : apiModelName,
                            icon: inferenceMode == .local ? "desktopcomputer" : "cloud.fill"
                        )
                    }
                }
                .padding(14)
                .maeCleanCard()

                // Provider Quick Switch (only in API mode, only providers with saved keys)
                if inferenceMode == .api {
                    let providersWithKeys = CloudProvider.allCases.filter {
                        !(KeychainManager.shared.loadKey(for: $0) ?? "").isEmpty
                    }

                    if providersWithKeys.count > 1 {
                        VStack(alignment: .leading, spacing: 12) {
                            // Provider chips
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(providersWithKeys) { provider in
                                        Button {
                                            selectedProvider.saveLastModel(apiModelName)
                                            selectedProvider = provider
                                            quickModelSearchText = ""
                                            if let savedModel = provider.loadLastModel() {
                                                apiModelName = savedModel
                                            }
                                            loadQuickModels()
                                        } label: {
                                            Text(provider.shortName)
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundStyle(
                                                    selectedProvider == provider
                                                        ? Theme.Colors.background
                                                        : Theme.Colors.textPrimary.opacity(0.9)
                                                )
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(
                                                    selectedProvider == provider
                                                        ? Theme.Colors.accent
                                                        : Theme.Colors.surfaceSecondary
                                                )
                                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                        .stroke(
                                                            selectedProvider == provider
                                                                ? Theme.Colors.accentOrange.opacity(0.5)
                                                                : Theme.Colors.border,
                                                            lineWidth: 0.5
                                                        )
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            // Model quick selector
                            VStack(alignment: .leading, spacing: 8) {
                                if isFetchingQuickModels {
                                    HStack {
                                        Spacer()
                                        ProgressView().controlSize(.mini)
                                        Spacer()
                                    }
                                }

                                if quickModels.count > 5 {
                                    TextField("Buscar modelo...", text: $quickModelSearchText)
                                        .maeInputStyle(cornerRadius: Theme.Metrics.radiusSmall)
                                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                                        .accessibilityLabel("Filtrar modelos")
                                }

                                if !filteredQuickModels.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            ForEach(filteredQuickModels, id: \.self) { model in
                                                Button {
                                                    apiModelName = model
                                                    selectedProvider.saveLastModel(model)
                                                } label: {
                                                    Text(model)
                                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                                        .foregroundStyle(
                                                            apiModelName == model
                                                                ? Theme.Colors.background
                                                                : Theme.Colors.textPrimary.opacity(0.9)
                                                        )
                                                        .lineLimit(1)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 5)
                                                        .background(
                                                            apiModelName == model
                                                                ? Theme.Colors.accent
                                                                : Theme.Colors.background.opacity(0.6)
                                                        )
                                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                } else if !quickModelSearchText.isEmpty {
                                    Text("Nenhum resultado")
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundStyle(Theme.Colors.textMuted)
                                } else if !isFetchingQuickModels {
                                    Text(apiModelName)
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                }
                            }
                        }
                        .padding(14)
                        .maeCleanCard()
                        .onAppear { loadQuickModels() }
                    }
                }

                // Token Usage
                if globalTotalTokens > 0 {
                    VStack(alignment: .leading, spacing: 10) {
                        MaeSectionHeader(title: "Uso de Tokens")

                        HStack {
                            Text(formatTokenCount(globalTotalTokens) + " tokens")
                                .font(Theme.Typography.captionBold)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Spacer()
                            HStack(spacing: 8) {
                                HStack(spacing: 3) {
                                    Circle().fill(Theme.Colors.accentOrange).frame(width: 5, height: 5)
                                    Text("In: " + formatTokenCount(globalInputTokens))
                                        .font(Theme.Typography.micro)
                                        .foregroundStyle(Theme.Colors.textMuted)
                                }
                                HStack(spacing: 3) {
                                    Circle().fill(Theme.Colors.accentSand).frame(width: 5, height: 5)
                                    Text("Out: " + formatTokenCount(globalOutputTokens))
                                        .font(Theme.Typography.micro)
                                        .foregroundStyle(Theme.Colors.textMuted)
                                }
                            }
                            Button {
                                SettingsManager.resetGlobalTokens()
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(Theme.Colors.textMuted)
                            }
                            .buttonStyle(.plain)
                            .help("Resetar")
                        }

                        let inputRatio = globalTotalTokens > 0
                            ? CGFloat(globalInputTokens) / CGFloat(globalTotalTokens)
                            : 0.5
                        MaeProgressBar(value: tokenBarAppeared ? inputRatio : 0)
                            .onAppear {
                                withAnimation(Theme.Animation.expressive) {
                                    tokenBarAppeared = true
                                }
                            }
                    }
                    .padding(14)
                    .maeCleanCard()
                }

                Spacer(minLength: 0)

                // Action Buttons
                VStack(spacing: 0) {
                    Button {
                        UpdaterController.shared.checkForUpdates()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.Colors.textSecondary)
                            Text("Atualizações")
                                .font(Theme.Typography.bodySmall)
                                .foregroundStyle(Theme.Colors.textPrimary.opacity(0.9))
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .maePressEffect()

                    MaeGradientDivider()

                    Button {
                        withAnimation {
                            isPresented = false
                        }
                        NSApp.sendAction(#selector(NSPopover.performClose(_:)), to: nil, from: nil)
                        AdvancedSettingsWindowManager.shared.showWindow()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.Colors.textSecondary)
                            Text("Avançado")
                                .font(Theme.Typography.bodySmall)
                                .foregroundStyle(Theme.Colors.textPrimary.opacity(0.9))
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Theme.Colors.textMuted)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .maePressEffect()
                }
                .maeCleanCard()
                .padding(.bottom, 14)
            }
            .padding(.horizontal, Theme.Metrics.spacingLarge)
            } // ScrollView
        }
        .background(MaePageBackground())
        .overlay(alignment: .topTrailing) {
            MaeIconButton(icon: "xmark", size: 12, color: Theme.Colors.textMuted, bgColor: .clear, helpText: "Fechar Configurações") {
                withAnimation(Theme.Animation.smooth) {
                    isPresented = false
                }
            }
            .keyboardShortcut(.escape, modifiers: [])
            .padding(.top, 12)
            .padding(.trailing, Theme.Metrics.spacingDefault)
        }

    }

    private func loadQuickModels() {
        quickModelTask?.cancel()
        quickModelTask = Task {
            let apiKey = KeychainManager.shared.loadKey(for: selectedProvider) ?? ""
            guard !apiKey.isEmpty, selectedProvider.modelsEndpoint != nil else {
                quickModels = selectedProvider.availableModels.filter { $0 != "API não disponível" }
                return
            }
            isFetchingQuickModels = true
            defer { isFetchingQuickModels = false }
            do {
                let models = try await ModelFetcher.shared.fetchModels(for: selectedProvider, apiKey: apiKey)
                guard !Task.isCancelled else { return }
                if !models.isEmpty {
                    quickModels = models
                }
            } catch {
                guard !Task.isCancelled else { return }
                quickModels = selectedProvider.availableModels.filter { $0 != "API não disponível" }
            }
        }
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }
}

// MARK: - Token Stat Component
private struct TokenStat: View {
    let label: String
    let value: String
    var isPrimary: Bool = false
    var color: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if let color {
                    Circle().fill(color).frame(width: 5, height: 5)
                }
                Text(label)
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            Text(value)
                .font(.system(size: isPrimary ? 15 : 13, weight: isPrimary ? .semibold : .medium, design: .rounded))
                .foregroundStyle(isPrimary ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
        }
    }
}

#Preview {
    SettingsView(isPresented: .constant(true))
        .frame(width: 320, height: 350)
}
