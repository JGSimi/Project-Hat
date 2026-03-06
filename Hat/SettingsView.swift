import SwiftUI

struct SettingsView: View {
    @Binding var isPresented: Bool
    
    @AppStorage("inferenceMode") var inferenceMode: InferenceMode = .local
    @AppStorage("selectedProvider") var selectedProvider: CloudProvider = .google
    @AppStorage("apiModelName") var apiModelName: String = "gpt-5.2"
    @AppStorage("localModelName") var localModelName: String = "gemma3:4b"

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
                    .maeStaggered(index: 1, baseDelay: 0.06)

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
                    .maeStaggered(index: 2, baseDelay: 0.06)
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
}

#Preview {
    SettingsView(isPresented: .constant(true))
        .frame(width: 320, height: 350)
}
