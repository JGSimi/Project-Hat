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

    private var filteredQuickModels: [String] {
        if quickModelSearchText.isEmpty { return quickModels }
        return quickModels.filter { $0.localizedCaseInsensitiveContains(quickModelSearchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image("sunglasses-2-svgrepo-com")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Theme.Colors.accentBlue.opacity(0.8))
                Text("Configurações")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary.opacity(0.9))
                Spacer()
            }
            .padding(.horizontal, Theme.Metrics.spacingLarge)
            .padding(.top, 20)
            .padding(.bottom, 16)

            VStack(spacing: 10) {
                // Model Card
                VStack(spacing: 0) {
                    // Mode Picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PROCESSAMENTO")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textMuted)
                            .tracking(0.5)

                        Picker("", selection: $inferenceMode) {
                            ForEach(InferenceMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .colorScheme(.dark)
                    }
                    .padding(14)

                    MaeGradientDivider()

                    // Active Model
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("MODELO ATIVO")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.Colors.textMuted)
                                .tracking(0.5)

                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Theme.Colors.success.opacity(0.9))
                                    .frame(width: 6, height: 6)
                                    .shadow(color: Theme.Colors.success.opacity(0.5), radius: 3)
                                    .maePulse(duration: 2.0)

                                Text(inferenceMode == .local ? localModelName : apiModelName)
                                    .font(Theme.Typography.bodyBold)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            if inferenceMode == .api {
                                Text(selectedProvider.rawValue)
                                    .font(Theme.Typography.micro)
                                    .foregroundStyle(Theme.Colors.accentBlue.opacity(0.8))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.Colors.accentBlue.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                }
                .background(Theme.Colors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.Colors.border, lineWidth: 0.5)
                )
                .maeStaggered(index: 0, baseDelay: 0.06)

                // Provider Quick Switch (only in API mode, only providers with saved keys)
                if inferenceMode == .api {
                    let providersWithKeys = CloudProvider.allCases.filter {
                        !(KeychainManager.shared.loadKey(for: $0) ?? "").isEmpty
                    }

                    if providersWithKeys.count > 1 {
                        VStack(alignment: .leading, spacing: 10) {
                            // Provider chips
                            VStack(alignment: .leading, spacing: 8) {
                                Text("TROCAR PROVEDOR")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.Colors.textMuted)
                                    .tracking(0.5)

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
                                                            ? Color.black
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
                                                                    ? Theme.Colors.accent.opacity(0.5)
                                                                    : Theme.Colors.border,
                                                                lineWidth: 0.5
                                                            )
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }

                            MaeGradientDivider()

                            // Model quick selector
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Text("MODELO")
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Theme.Colors.textMuted)
                                        .tracking(0.5)
                                    if isFetchingQuickModels {
                                        ProgressView()
                                            .controlSize(.mini)
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
                                                                ? Color.black
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
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                                .stroke(
                                                                    apiModelName == model
                                                                        ? Theme.Colors.accent.opacity(0.5)
                                                                        : Theme.Colors.border,
                                                                    lineWidth: 0.5
                                                                )
                                                        )
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
                        .background(Theme.Colors.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Theme.Colors.border, lineWidth: 0.5)
                        )
                        .maeStaggered(index: 1, baseDelay: 0.06)
                        .onAppear { loadQuickModels() }
                    }
                }

                // Token Usage Card
                if globalTotalTokens > 0 {
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("USO DE TOKENS")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.Colors.textMuted)
                                    .tracking(0.5)
                                Spacer()
                                Button {
                                    SettingsManager.resetGlobalTokens()
                                } label: {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(Theme.Colors.textMuted)
                                        .padding(4)
                                        .background(Theme.Colors.surface)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help("Resetar contadores")
                            }

                            // Visual ratio bar
                            GeometryReader { geo in
                                let inputRatio = globalTotalTokens > 0
                                    ? CGFloat(globalInputTokens) / CGFloat(globalTotalTokens)
                                    : 0.5
                                HStack(spacing: 1) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Theme.Colors.accentBlue.opacity(0.7))
                                        .frame(width: max(4, geo.size.width * inputRatio))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Theme.Colors.accentTeal.opacity(0.6))
                                }
                            }
                            .frame(height: 4)
                            .clipShape(RoundedRectangle(cornerRadius: 3))

                            HStack(spacing: 12) {
                                TokenStat(label: "Total", value: formatTokenCount(globalTotalTokens), isPrimary: true)
                                TokenStat(label: "Input", value: formatTokenCount(globalInputTokens), color: Theme.Colors.accentBlue)
                                TokenStat(label: "Output", value: formatTokenCount(globalOutputTokens), color: Theme.Colors.accentTeal)
                                Spacer()
                            }
                        }
                        .padding(14)
                    }
                    .background(Theme.Colors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Theme.Colors.border, lineWidth: 0.5)
                    )
                    .maeStaggered(index: 2, baseDelay: 0.06)
                }

                Spacer(minLength: 0)

                // Action Buttons
                VStack(spacing: 6) {
                    Button {
                        UpdaterController.shared.checkForUpdates()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.Colors.textSecondary)
                            Text("Verificar Atualizações")
                                .font(Theme.Typography.bodySmall)
                                .foregroundStyle(Theme.Colors.textPrimary.opacity(0.9))
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(Theme.Colors.surfaceSecondary.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Theme.Colors.border, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .maePressEffect()
                    .maeStaggered(index: 3, baseDelay: 0.06)

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
                            Text("Configurações Avançadas")
                                .font(Theme.Typography.bodySmall)
                                .foregroundStyle(Theme.Colors.textPrimary.opacity(0.9))
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Theme.Colors.textMuted)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(Theme.Colors.surfaceSecondary.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Theme.Colors.border, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .maePressEffect()
                    .maeStaggered(index: 4, baseDelay: 0.06)
                }
                .padding(.bottom, 14)
            }
            .padding(.horizontal, Theme.Metrics.spacingLarge)
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
        .preferredColorScheme(.dark)
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
