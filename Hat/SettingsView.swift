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

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image("sunglasses-2-svgrepo-com")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Theme.Colors.accent.opacity(0.7))
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
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MODELO ATIVO")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.Colors.textMuted)
                                .tracking(0.5)

                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.green.opacity(0.8))
                                    .frame(width: 6, height: 6)
                                    .shadow(color: Color.green.opacity(0.4), radius: 3)
                                    .maePulse(duration: 2.0)

                                Text(inferenceMode == .local ? localModelName : "\(selectedProvider.rawValue) · \(apiModelName)")
                                    .font(Theme.Typography.bodyBold)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
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

                                if !quickModels.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            ForEach(quickModels, id: \.self) { model in
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
                        VStack(alignment: .leading, spacing: 8) {
                            Text("USO DE TOKENS")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.Colors.textMuted)
                                .tracking(0.5)

                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Total")
                                        .font(.system(size: 9, weight: .medium, design: .rounded))
                                        .foregroundStyle(Theme.Colors.textMuted)
                                    Text(formatTokenCount(globalTotalTokens))
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Input")
                                        .font(.system(size: 9, weight: .medium, design: .rounded))
                                        .foregroundStyle(Theme.Colors.textMuted)
                                    Text(formatTokenCount(globalInputTokens))
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Output")
                                        .font(.system(size: 9, weight: .medium, design: .rounded))
                                        .foregroundStyle(Theme.Colors.textMuted)
                                    Text(formatTokenCount(globalOutputTokens))
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                }
                                Spacer()
                                Button {
                                    SettingsManager.resetGlobalTokens()
                                } label: {
                                    Text("Resetar")
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundStyle(Theme.Colors.textMuted)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Theme.Colors.surfaceSecondary.opacity(0.5))
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                                .buttonStyle(.plain)
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

#Preview {
    SettingsView(isPresented: .constant(true))
        .frame(width: 320, height: 350)
}
