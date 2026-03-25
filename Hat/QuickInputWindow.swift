//
//  QuickInputWindow.swift
//  Hat
//
//  Created by Joao Simi on 27/02/26.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - NSPanel Subclass (Spotlight-like)

final class QuickInputPanel: NSPanel {

    var onClose: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        super.resignKey()
        close()
    }

    override func close() {
        super.close()
        onClose?()
    }
}

// MARK: - Window Manager

@MainActor
class QuickInputWindowManager {
    static let shared = QuickInputWindowManager()
    private var panel: NSPanel?
    private(set) var isCapturingScreen = false

    func toggleWindow() {
        if panel != nil {
            closeWindow()
        } else {
            AssistantViewModel.shared.pendingAttachments.removeAll()
            openWindow()
        }
    }

    private func openWindow() {
        let newPanel = QuickInputPanel(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 0),
            styleMask: [.borderless, .nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        newPanel.titleVisibility = .hidden
        newPanel.titlebarAppearsTransparent = true
        newPanel.isMovableByWindowBackground = true
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.animationBehavior = .utilityWindow
        newPanel.sharingType = .none

        newPanel.standardWindowButton(.closeButton)?.isHidden = true
        newPanel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        newPanel.standardWindowButton(.zoomButton)?.isHidden = true

        newPanel.contentView = NSHostingView(rootView: QuickInputView().ignoresSafeArea())

        newPanel.onClose = { [weak self] in
            guard let self, !self.isCapturingScreen else { return }
            self.panel = nil
        }

        newPanel.center()
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelFrame = newPanel.frame
            let x = screenFrame.midX - panelFrame.width / 2
            let y = screenFrame.midY + screenFrame.height * 0.15
            newPanel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        self.panel = newPanel
        NSApp.activate(ignoringOtherApps: true)
        newPanel.makeKeyAndOrderFront(nil)
        newPanel.orderFrontRegardless()
    }

    func closeWindow() {
        guard !isCapturingScreen else { return }
        panel?.close()
        panel = nil
    }

    func captureAndReopen() {
        isCapturingScreen = true
        panel?.close()
        panel = nil

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard let self else { return }
            let image = await AssistantViewModel.shared.captureScreen()

            self.isCapturingScreen = false

            if let image {
                let attachment = ChatAttachment(
                    name: "Captura de Tela", data: nil, content: nil, image: image, isImage: true
                )
                AssistantViewModel.shared.pendingAttachments.append(attachment)
            }

            self.openWindow()
        }
    }
}

// MARK: - Quick Input View

@MainActor
struct QuickInputView: View {
    @ObservedObject private var viewModel: AssistantViewModel
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var isFocusedForBorder: Bool = false

    init(viewModel: AssistantViewModel) {
        self.viewModel = viewModel
    }

    init() {
        self.viewModel = AssistantViewModel.shared
    }

    private var hasContent: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !viewModel.pendingAttachments.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.pendingAttachments.isEmpty {
                attachmentsPreview
            }

            inputBar
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusLarge, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Metrics.radiusLarge, style: .continuous).stroke(Theme.Colors.border, lineWidth: 0.5))
        .maeMediumShadow()
        .overlay(
            Group {
                if isFocusedForBorder {
                    RoundedRectangle(cornerRadius: Theme.Metrics.radiusLarge, style: .continuous)
                        .stroke(.clear, lineWidth: 1)
                        .maeGradientBorder(cornerRadius: Theme.Metrics.radiusLarge)
                        .transition(.opacity)
                }
            }
        )
        .animation(Theme.Animation.smooth, value: isFocusedForBorder)
        .frame(width: 680)
        .onAppear {
            isInputFocused = true
            withAnimation(Theme.Animation.gentle.delay(0.3)) {
                isFocusedForBorder = true
            }
        }

    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                actionButtons

                TextField("Pergunte algo à Hat...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .onSubmit {
                        send()
                    }

                if viewModel.isProcessing {
                    MaeTypingDots()
                        .frame(width: 32, height: 32)
                        .transition(.maeScaleFade)
                } else {
                    Button {
                        send()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(hasContent ? Theme.Colors.accent : Theme.Colors.textMuted.opacity(0.4))
                            .symbolEffect(.bounce, options: .nonRepeating)
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasContent)
                    .maePressEffect()
                    .transition(.maeScaleFade)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // Recent prompts + keyboard hints
            if inputText.isEmpty && viewModel.pendingAttachments.isEmpty {
                VStack(spacing: 8) {
                    // Recent prompt suggestions
                    let recentPrompts = Array(
                        viewModel.messages
                            .filter { $0.isUser && !$0.content.isEmpty && $0.content.count < 60 }
                            .suffix(3)
                            .reversed()
                    )
                    if !recentPrompts.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(recentPrompts, id: \.id) { msg in
                                    MaeChip(label: msg.content, isSelected: false) {
                                        inputText = msg.content
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .transition(.maeSlideUp)
                    }

                    HStack(spacing: 12) {
                        keyboardHint(key: "⏎", label: "enviar")
                        keyboardHint(key: "esc", label: "fechar")
                    }
                }
                .padding(.bottom, 10)
                .transition(.maeSlideUp)
            }
        }
    }

    private func keyboardHint(key: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Colors.textMuted.opacity(0.6))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Theme.Colors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(label)
                .font(.system(size: 9, weight: .regular, design: .rounded))
                .foregroundStyle(Theme.Colors.textMuted.opacity(0.4))
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 2) {
            MaeTooltipButton(icon: "plus.circle.fill", size: 18, helpText: "Anexar arquivo") {
                attachFile()
            }

            MaeTooltipButton(
                icon: "camera.viewfinder",
                size: 18,
                helpText: "Capturar tela"
            ) {
                QuickInputWindowManager.shared.captureAndReopen()
            }
        }
        .background(Theme.Colors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.Colors.border, lineWidth: 0.5))
    }

    // MARK: - Attachments Preview

    private var attachmentsPreview: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.pendingAttachments.indices, id: \.self) { index in
                    let attachment = viewModel.pendingAttachments[index]
                    ZStack(alignment: .topTrailing) {
                        if attachment.isImage, let img = attachment.image {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall))
                                .overlay(
                                    attachment.name == "Captura de Tela"
                                    ? RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall)
                                        .stroke(Theme.Colors.accent.opacity(0.4), lineWidth: 1)
                                    : nil
                                )
                                .shadow(radius: 2)
                        } else {
                            VStack(spacing: 4) {
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(Theme.Colors.accent)
                                    .symbolEffect(.bounce, options: .nonRepeating)
                                Text(attachment.name)
                                    .font(.system(size: 9))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .frame(width: 50)
                            }
                            .frame(width: 60, height: 60)
                            .background(Theme.Colors.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall))
                            .shadow(radius: 2)
                        }

                        Button {
                            withAnimation(Theme.Animation.snappy) {
                                let i: Int = index
                                viewModel.pendingAttachments.remove(at: i)
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Theme.Colors.textPrimary, Theme.Colors.background)
                                .symbolEffect(.bounce, options: .nonRepeating)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        .offset(x: 6, y: -6)
                    }
                    .transition(.maeScaleFade)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)
        }
        .transition(.maeSlideUp)
    }

    // MARK: - Actions

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hasContent && !viewModel.isProcessing else { return }

        viewModel.inputText = text

        Task {
            await viewModel.sendManualMessage()
        }

        QuickInputWindowManager.shared.closeWindow()
    }

    private func attachFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.image, UTType.plainText, UTType.pdf, UTType.json, UTType.sourceCode, UTType.data]
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for url in panel.urls {
                Task { @MainActor in
                    if let attachment = await viewModel.attachment(from: url) {
                        withAnimation(Theme.Animation.snappy) {
                            viewModel.pendingAttachments.append(attachment)
                        }
                    }
                }
            }
        }
    }
}
