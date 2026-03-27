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
    @Namespace private var bottomAnchor
    @AppStorage("inferenceMode") private var inferenceMode: InferenceMode = .local
    @AppStorage("apiModelName") private var apiModelName: String = "gpt-5.2"
    @AppStorage("localModelName") private var localModelName: String = "gemma3:4b"

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
        .frame(width: 380, height: 480)
        .background(Theme.Colors.background)
        .onAppear { isInputFocused = true }
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
        .background(Theme.Colors.surface)
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
                            .transition(.maePopIn)
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
        VStack(spacing: 20) {
            Spacer().frame(height: 40)

            // Floating hat icon
            ZStack {
                Circle()
                    .fill(Theme.Colors.accentPrimary.opacity(0.06))
                    .frame(width: 56, height: 56)
                Circle()
                    .fill(Theme.Colors.accentPrimary.opacity(0.03))
                    .frame(width: 72, height: 72)
                Image("hat-svgrepo-com")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(Theme.Colors.accentPrimary.opacity(0.6))
            }
            .maeFloating()
            .maeStaggered(index: 0, baseDelay: 0.10)
            .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(greetingText)
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary.opacity(0.9))
                    .maeStaggered(index: 1, baseDelay: 0.10)

                Text("Chat rapido pelo menu bar")
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.Colors.textMuted)
                    .maeStaggered(index: 2, baseDelay: 0.10)
            }
            .accessibilityElement(children: .combine)

            // Quick actions
            HStack(spacing: 10) {
                PopoverQuickAction(
                    icon: "doc.on.clipboard",
                    label: "Analisar clipboard",
                    shortcut: "⌘⇧X",
                    index: 3
                ) {
                    Task { await viewModel.processarIA() }
                }
                PopoverQuickAction(
                    icon: "camera.viewfinder",
                    label: "Analisar tela",
                    shortcut: "⌘⇧Z",
                    index: 4
                ) {
                    Task { await viewModel.processarScreen() }
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
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

                if viewModel.isProcessing {
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
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.Colors.surfaceSecondary)

            // Hint
            Text("Enter para enviar")
                .font(.system(size: 9, weight: .regular))
                .foregroundStyle(Theme.Colors.textMuted.opacity(0.35))
                .padding(.vertical, 4)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Quick Action Button

private struct PopoverQuickAction: View {
    let icon: String
    let label: String
    let shortcut: String
    var index: Int = 0
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isHovered ? Theme.Colors.accentPrimary.opacity(0.1) : Theme.Colors.surfaceTertiary)
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(isHovered ? Theme.Colors.accentPrimary : Theme.Colors.textSecondary)
                }

                VStack(spacing: 2) {
                    Text(label)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(isHovered ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)

                    Text(shortcut)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.Colors.textMuted.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Metrics.radiusMedium, style: .continuous)
                    .fill(isHovered ? Theme.Colors.surfaceHover : Theme.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metrics.radiusMedium, style: .continuous)
                    .stroke(isHovered ? Theme.Colors.borderHighlight : Theme.Colors.border, lineWidth: 0.5)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(Theme.Animation.hover) { isHovered = hovering }
        }
        .maeStaggered(index: index, baseDelay: 0.10)
        .accessibilityLabel(label)
        .accessibilityHint("Atalho: \(shortcut)")
    }
}
