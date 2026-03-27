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
    @State private var isInputFocusedForBorder: Bool = false
    @Namespace private var bottomAnchor

    var body: some View {
        VStack(spacing: 0) {
            // Header
            popoverHeader

            MaeDivider()

            // Chat area
            popoverChatArea

            // Input
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

            Text("Hat")
                .font(Theme.Typography.bodyBold)
                .foregroundStyle(Theme.Colors.textPrimary)

            Spacer()

            // Clear chat
            if !viewModel.messages.isEmpty {
                MaeTooltipButton(icon: "trash", helpText: "Limpar") {
                    withAnimation(Theme.Animation.smooth) {
                        viewModel.clearHistory()
                    }
                }
            }

            // Open full window
            MaeTooltipButton(icon: "arrow.up.left.and.arrow.down.right", helpText: "Abrir janela") {
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
        VStack(spacing: 16) {
            Spacer().frame(height: 60)

            ZStack {
                Circle()
                    .fill(Theme.Colors.accentPrimary.opacity(0.06))
                    .frame(width: 48, height: 48)
                Image("hat-svgrepo-com")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundStyle(Theme.Colors.accentPrimary.opacity(0.5))
            }

            VStack(spacing: 4) {
                Text("Pergunte algo")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)

                Text("ou abra a janela completa")
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Colors.textMuted)
            }

            // Quick actions
            HStack(spacing: 8) {
                PopoverQuickAction(icon: "doc.on.clipboard", label: "Clipboard", shortcut: "⌘⇧X") {
                    Task { await viewModel.processarIA() }
                }
                PopoverQuickAction(icon: "camera.viewfinder", label: "Tela", shortcut: "⌘⇧Z") {
                    Task { await viewModel.processarScreen() }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
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

                if viewModel.isProcessing {
                    MaeTypingDots()
                        .frame(width: 24, height: 24)
                        .transition(.maeScaleFade)
                } else {
                    let hasContent = !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    Button {
                        Task { await viewModel.sendManualMessage() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(hasContent ? Theme.Colors.accentPrimary : Theme.Colors.textMuted.opacity(0.25))
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasContent)
                    .keyboardShortcut(.defaultAction)
                    .transition(.maeScaleFade)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.Colors.surface)
        }
    }
}

// MARK: - Quick Action Button

private struct PopoverQuickAction: View {
    let icon: String
    let label: String
    let shortcut: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(isHovered ? Theme.Colors.accentPrimary : Theme.Colors.textSecondary)

                Text(label)
                    .font(Theme.Typography.micro)
                    .foregroundStyle(isHovered ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)

                Text(shortcut)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Theme.Metrics.radiusMedium, style: .continuous)
                    .fill(isHovered ? Theme.Colors.surfaceHover : Theme.Colors.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metrics.radiusMedium, style: .continuous)
                    .stroke(Theme.Colors.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
