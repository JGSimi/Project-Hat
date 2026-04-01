//
//  MenuBarPopoverView.swift
//  Hat
//
//  Compact menu bar chat popover — quick access to Hat AI.
//

import SwiftUI
import Combine

struct MenuBarPopoverView: View {
    @ObservedObject private var viewModel = AssistantViewModel.shared
    @FocusState private var isInputFocused: Bool
    @State private var sendHovered = false
    @State private var isVisible = false
    @Namespace private var bottomAnchor
    @AppStorage("inferenceMode") private var inferenceMode: InferenceMode = .local
    @AppStorage("apiModelName") private var apiModelName: String = "gpt-5.2"
    @AppStorage("localModelName") private var localModelName: String = "gemma3:4b"
    @AppStorage("popoverOpacity") private var popoverOpacity: Double = 1.0
    @AppStorage("popoverWidth") private var popoverWidth: Double = 380.0
    @AppStorage("popoverHeight") private var popoverHeight: Double = 480.0
    @AppStorage("popoverVibrancy") private var popoverVibrancy: Bool = false

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Bom dia"
        case 12..<18: return "Boa tarde"
        case 18..<23: return "Boa noite"
        default:      return "Ola"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            popoverHeader
            MaeDivider()
            popoverChatArea
            popoverInput
        }
        .frame(width: CGFloat(popoverWidth), height: CGFloat(popoverHeight))
        .background {
            Group {
                if popoverVibrancy {
                    VisualEffectView(
                        material: .hudWindow,
                        blendingMode: .behindWindow
                    )
                    .overlay(Theme.Colors.background.opacity(popoverOpacity))
                } else {
                    Theme.Colors.background
                }
            }
        }
        // Opening animation
        .scaleEffect(isVisible ? 1.0 : 0.92)
        .opacity(isVisible ? 1.0 : 0)
        .onAppear {
            isInputFocused = true
            // Configure the window for transparency
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                configureWindowTransparency()
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                isVisible = true
            }
        }
        .onDisappear {
            isVisible = false
        }
        .onChange(of: popoverVibrancy) { _, _ in
            configureWindowTransparency()
        }
        .onChange(of: popoverOpacity) { _, _ in
            configureWindowTransparency()
        }
    }

    /// Finds the MenuBarExtra NSWindow and configures transparency
    private func configureWindowTransparency() {
        // MenuBarExtra windows are NSPanel instances managed by the system
        // We find them by looking at all app windows
        for window in NSApp.windows {
            guard let contentView = window.contentView,
                  String(describing: type(of: contentView)).contains("Hosting") else { continue }
            // Skip main window and other known windows
            if window.title == "Hat" { continue }
            if window.styleMask.contains(.resizable) { continue }

            window.isOpaque = !popoverVibrancy
            window.backgroundColor = popoverVibrancy ? .clear : NSColor(Theme.Colors.background)
            break
        }
    }

    // MARK: - Header

    private var popoverHeader: some View {
        HStack(spacing: 8) {
            Image("hat-svgrepo-com")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(Theme.Colors.accentPrimary.opacity(0.6))
                .accessibilityHidden(true)

            Text(greetingText)
                .font(Theme.Typography.bodyBold)
                .foregroundStyle(Theme.Colors.textPrimary)
                .maeStaggered(index: 0, baseDelay: 0.08)

            MaeTag(
                label: inferenceMode == .local ? localModelName : apiModelName,
                icon: inferenceMode == .local ? "desktopcomputer" : "cloud.fill",
                color: Theme.Colors.textSecondary
            )
            .maeStaggered(index: 1, baseDelay: 0.08)

            Spacer()

            if !viewModel.messages.isEmpty {
                MaeTooltipButton(icon: "trash", helpText: "Limpar conversa") {
                    withAnimation(Theme.Animation.smooth) {
                        viewModel.clearHistory()
                    }
                }
                .transition(.maeScaleFade)
            }

            MaeTooltipButton(icon: "arrow.up.left.and.arrow.down.right", helpText: "Abrir janela completa") {
                MainWindowManager.shared.showWindow()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(popoverVibrancy ? Theme.Colors.surface.opacity(max(popoverOpacity, 0.15)) : Theme.Colors.surface)
    }

    // MARK: - Chat Area

    private var popoverChatArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if viewModel.messages.isEmpty {
                        popoverEmptyState
                    } else {
                        ForEach(viewModel.messages.indices, id: \.self) { index in
                            let isGrouped = index > 0
                                && viewModel.messages[index].isUser == viewModel.messages[index - 1].isUser
                            ChatBubble(
                                message: viewModel.messages[index],
                                animationIndex: index,
                                isGrouped: isGrouped
                            )
                            .id(viewModel.messages[index].id)
                            .transition(.maeBlurIn)
                        }
                    }
                    Color.clear.frame(height: 6).id(bottomAnchor)
                }
                .padding(.vertical, 8)
            }
            .scrollContentBackground(.hidden)
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(Theme.Animation.smooth) {
                    proxy.scrollTo(bottomAnchor, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Empty State

    private var popoverEmptyState: some View {
        VStack(spacing: 14) {
            Spacer()

            // Hat icon
            ZStack {
                Circle()
                    .stroke(Theme.Colors.accentPrimary.opacity(0.15), lineWidth: 1)
                    .frame(width: 48, height: 48)
                Image("hat-svgrepo-com")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundStyle(Theme.Colors.accentPrimary.opacity(0.7))
            }
            .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text(greetingText)
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary.opacity(0.9))

                Text("Como posso ajudar?")
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            .accessibilityElement(children: .combine)

            // Shortcut hints
            HStack(spacing: 12) {
                Text("⌘⇧X Clipboard")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.Colors.textMuted.opacity(0.5))
                Text("⌘⇧Z Tela")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.Colors.textMuted.opacity(0.5))
            }

            Spacer()
        }
        .transition(.maeIrisIn)
        .maeAppearAnimation(animation: Theme.Animation.smooth)
    }

    // MARK: - Input

    private var popoverInput: some View {
        VStack(spacing: 0) {
            MaeDivider()

            HStack(alignment: .bottom, spacing: 8) {
                TextField("Mensagem...", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .onSubmit {
                        Task { await viewModel.sendManualMessage() }
                    }
                    .disabled(viewModel.isProcessing)
                    .accessibilityLabel("Campo de mensagem")
                    .accessibilityHint("Enter para enviar")

                if viewModel.isStreaming {
                    Button {
                        viewModel.cancelStreaming()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.Colors.accentPrimary)
                    }
                    .buttonStyle(.plain)
                    .transition(.maeScaleFade)
                    .accessibilityLabel("Parar geração")
                } else if viewModel.isProcessing {
                    MaeTypingDots()
                        .frame(width: 24, height: 24)
                        .transition(.maeScaleFade)
                        .accessibilityLabel("Processando resposta")
                } else {
                    let hasContent = !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    Button {
                        Task { await viewModel.sendManualMessage() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(hasContent ? Theme.Colors.accentPrimary : Theme.Colors.textMuted.opacity(0.25))
                            .scaleEffect(sendHovered && hasContent ? 1.1 : 1.0)
                            .animation(Theme.Animation.quickSnap, value: sendHovered)
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasContent)
                    .keyboardShortcut(.defaultAction)
                    .onHover { sendHovered = $0 }
                    .transition(.maeScaleFade)
                    .accessibilityLabel("Enviar mensagem")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(popoverVibrancy ? Theme.Colors.surfaceSecondary.opacity(max(popoverOpacity, 0.15)) : Theme.Colors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.Colors.border, lineWidth: 0.5)
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }
}

