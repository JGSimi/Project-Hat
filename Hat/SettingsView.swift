import SwiftUI

struct SettingsView: View {
    @Binding var isPresented: Bool
    
    @AppStorage("inferenceMode") var inferenceMode: InferenceMode = .local
    @AppStorage("selectedProvider") var selectedProvider: CloudProvider = .google
    @AppStorage("apiModelName") var apiModelName: String = "gpt-5.2"
    @AppStorage("localModelName") var localModelName: String = "gemma3:4b"

    var body: some View {
        VStack(spacing: 0) {
            // Header Minimalista
            HStack {
                Image("sunglasses-2-svgrepo-com")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            VStack(spacing: 12) {
                // Cartão Único Integrado
                VStack(spacing: 0) {
                    // Row de Seleção de Modo
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Processamento")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                            
                            Picker("", selection: $inferenceMode) {
                                ForEach(InferenceMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .colorScheme(.dark) // Forçar tint dark para o picker
                        }
                    }
                    .padding(16)
                    
                    Divider().background(Theme.Colors.border)
                    
                    // Row do Modelo Ativo
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Modelo Ativo")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Theme.Colors.accent)
                                    .frame(width: 8, height: 8)
                                    .shadow(color: Theme.Colors.accent.opacity(0.4), radius: 3)
                                    .maePulse(duration: 2.0)
                                
                                Text(inferenceMode == .local ? localModelName : "\(selectedProvider.rawValue) • \(apiModelName)")
                                    .font(Theme.Typography.bodyBold)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                            }
                        }
                        Spacer()
                    }
                    .padding(16)
                }
                .background(Theme.Colors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusLarge, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Metrics.radiusLarge, style: .continuous)
                        .stroke(Theme.Colors.border, lineWidth: 1)
                )
                .maeStaggered(index: 0, baseDelay: 0.06)
                
                Spacer()
                
                // Botão de Atualização Sleek
                Button {
                    UpdaterController.shared.checkForUpdates()
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(Theme.Typography.bodySmall)
                            .foregroundStyle(Theme.Colors.accent.opacity(0.8))
                            .symbolEffect(.rotate, options: .nonRepeating)
                        Text("Verificar Atualizações")
                            .font(Theme.Typography.bodyBold)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Theme.Colors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusMedium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Metrics.radiusMedium, style: .continuous)
                            .stroke(Theme.Colors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 4)
                .maePressEffect()
                .maeStaggered(index: 1, baseDelay: 0.06)
                
                // Botão Avançado Sleek
                Button {
                    withAnimation {
                        isPresented = false
                    }
                    // Close the MenuBarExtra window
                    NSApp.sendAction(#selector(NSPopover.performClose(_:)), to: nil, from: nil)
                    // Show advanced settings window
                    AdvancedSettingsWindowManager.shared.showWindow()
                } label: {
                    HStack {
                        Image(systemName: "gearshape.fill")
                            .font(Theme.Typography.bodySmall)
                            .symbolEffect(.rotate, options: .nonRepeating)
                        Text("Configurações Avançadas")
                            .font(Theme.Typography.bodyBold)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .symbolEffect(.bounce, options: .nonRepeating)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Theme.Colors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusMedium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Metrics.radiusMedium, style: .continuous)
                            .stroke(Theme.Colors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 12)
                .maePressEffect()
                .maeStaggered(index: 2, baseDelay: 0.06)
            }
            .padding(.horizontal, 20)
        }
        .background(MaePageBackground())
        .overlay(alignment: .topTrailing) {
            MaeIconButton(icon: "xmark.circle.fill", size: 18, color: Theme.Colors.textSecondary, bgColor: .clear, helpText: "Fechar Configurações") {
                withAnimation(Theme.Animation.smooth) {
                    isPresented = false
                }
            }
            .keyboardShortcut(.escape, modifiers: []) // ESC shortcut
            .padding(.top, 12)
            .padding(.trailing, Theme.Metrics.spacingLarge)
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    SettingsView(isPresented: .constant(true))
        .frame(width: 320, height: 350)
}
