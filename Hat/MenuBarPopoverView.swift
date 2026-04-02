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
    @State private var isHovering = false
    @Namespace private var bottomAnchor
    @AppStorage("inferenceMode") private var inferenceMode: InferenceMode = .local
    @AppStorage("apiModelName") private var apiModelName: String = "gpt-5.2"
    @AppStorage("localModelName") private var localModelName: String = "gemma3:4b"
    @AppStorage("popoverOpacity") private var popoverOpacity: Double = 1.0
    @AppStorage("popoverWidth") private var popoverWidth: Double = 380.0
    @AppStorage("popoverHeight") private var popoverHeight: Double = 480.0
    @AppStorage("popoverVibrancy") private var popoverVibrancy: Bool = false
    @AppStorage("popoverStealthMode") private var popoverStealthMode: Bool = false
    @AppStorage("popoverStealthHoverOpacity") private var stealthHoverOpacity: Double = 0.4

    /// Stealth: 2% idle, user-defined on hover (default 40%)
    private var stealthOpacity: Double { isHovering ? stealthHoverOpacity : 0.02 }

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
            ZStack {
                VisualEffectView(
                    material: popoverStealthMode ? .underWindowBackground : .hudWindow,
                    blendingMode: .behindWindow
                )
                Theme.Colors.background
                    .opacity(popoverStealthMode ? (isHovering ? stealthHoverOpacity : 0.0) : 0.6)
            }
        }
        // Stealth mode: monochrome + near-invisible until hover
        .saturation(popoverStealthMode ? (isHovering ? 0.3 : 0.0) : 1.0)
        .opacity(popoverStealthMode ? stealthOpacity : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
            // Only reconfigure window in stealth mode (avoid per-frame work)
            if popoverStealthMode {
                configureWindowTransparency()
            }
        }
        // Opening animation
        .scaleEffect(isVisible ? 1.0 : 0.92)
        .opacity(isVisible ? (popoverStealthMode ? stealthOpacity : 1.0) : 0)
        .onAppear {
            isInputFocused = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                configureWindowTransparency()
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                isVisible = true
            }
        }
        .onDisappear {
            isVisible = false
            isHovering = false
        }
        .onChange(of: popoverVibrancy) { _, _ in
            configureWindowTransparency()
        }
        .onChange(of: popoverOpacity) { _, _ in
            configureWindowTransparency()
        }
        .onChange(of: popoverStealthMode) { _, _ in
            configureWindowTransparency()
        }
    }

    /// Configures the popover panel transparency
    private func configureWindowTransparency() {
        // Find our panel — it's the MenuBarPopoverPanel instance
        guard let window = NSApp.windows.first(where: { $0 is MenuBarPopoverPanel }) else { return }

        // Glass is always on — window must always be transparent
        window.isOpaque = false
        window.backgroundColor = .clear

        if popoverStealthMode {
            window.alphaValue = isHovering ? CGFloat(stealthHoverOpacity) : 0.02
        } else {
            window.alphaValue = 1.0
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

            MaeTooltipButton(icon: "xmark", helpText: "Fechar popover") {
                MenuBarPopoverManager.shared.closePopover()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                Theme.Colors.glassSurfaceElevated
                    .opacity(popoverStealthMode ? (isHovering ? stealthHoverOpacity : 0.0) : 1.0)
            }
        }
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
            .maeGlow(color: Theme.Colors.accentPrimary, radius: 10, opacity: 0.3)
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

            // Attachment preview
            if !viewModel.pendingAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(viewModel.pendingAttachments) { attachment in
                            ZStack(alignment: .topTrailing) {
                                if attachment.isImage, let img = attachment.image {
                                    Image(nsImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 44, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .stroke(Theme.Colors.border, lineWidth: 0.5)
                                        )
                                }

                                Button {
                                    withAnimation(Theme.Animation.snappy) {
                                        viewModel.pendingAttachments.removeAll { $0.id == attachment.id }
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Theme.Colors.textPrimary, Theme.Colors.background)
                                }
                                .buttonStyle(.plain)
                                .offset(x: 4, y: -4)
                            }
                            .transition(.maeScaleFade)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                Button {
                    Task {
                        // Hide popover briefly so it doesn't appear in the screenshot
                        let panel = NSApp.windows.first(where: { $0 is MenuBarPopoverPanel })
                        panel?.orderOut(nil)

                        // Small delay for the panel to hide
                        try? await Task.sleep(nanoseconds: 200_000_000)

                        if let screenshot = await viewModel.captureScreen() {
                            let attachment = ChatAttachment(
                                name: "Captura de Tela",
                                data: nil,
                                content: nil,
                                image: screenshot,
                                isImage: true
                            )
                            viewModel.pendingAttachments.append(attachment)
                        }

                        // Show popover again
                        panel?.makeKeyAndOrderFront(nil)
                    }
                } label: {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Colors.textMuted)
                }
                .buttonStyle(.plain)
                .help("Capturar tela")
                .accessibilityLabel("Capturar tela")
                .disabled(viewModel.isProcessing)

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
                            .maeGlow(color: hasContent ? Theme.Colors.accentPrimary : .clear)
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
            .background {
                ZStack {
                    VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                    Theme.Colors.glassSurfaceSecondary
                        .opacity(popoverStealthMode ? (isHovering ? stealthHoverOpacity : 0.0) : 1.0)
                }
            }
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

