//
//  AnalysisWindow.swift
//  Hat
//
//  Created by Joao Simi on 23/02/26.
//

import SwiftUI
import AppKit

@MainActor
class AnalysisWindowManager {
    static let shared = AnalysisWindowManager()
    private var window: NSWindow?

    func showWindow() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = AnalysisView()

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.isMovableByWindowBackground = true
        newWindow.isReleasedWhenClosed = false
        newWindow.center()

        newWindow.contentView = NSHostingView(rootView: contentView)
        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeWindow() {
        window?.close()
        window = nil
    }
}

@MainActor
struct AnalysisView: View {
    @ObservedObject var viewModel: AssistantViewModel
    @State private var followUpText: String = ""
    @State private var showConfirmation = false
    @State private var localImage: NSImage? = nil
    @State private var analysisSpinAngle: Double = 0
    @FocusState private var isFollowUpFocused: Bool

    init(viewModel: AssistantViewModel) {
        self.viewModel = viewModel
    }

    init() {
        self.viewModel = AssistantViewModel.shared
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                HStack(spacing: 0) {
                    // Left Panel: Analysis
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Analise de Tela")
                                    .font(Theme.Typography.heading)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                if viewModel.isAnalyzingScreen {
                                    Text("Processando...")
                                        .font(Theme.Typography.micro)
                                        .foregroundStyle(Theme.Colors.accentPrimary)
                                }
                            }

                            Spacer()

                            if !viewModel.analysisResult.isEmpty && !viewModel.isAnalyzingScreen {
                                HStack(spacing: 8) {
                                    MaeIconButton(
                                        icon: "arrow.trianglehead.2.counterclockwise.rotate.90",
                                        color: Theme.Colors.accent,
                                        bgColor: Theme.Colors.accentSubtle,
                                        helpText: "Nova analise de tela"
                                    ) {
                                        Task { await viewModel.processarScreen() }
                                    }
                                    .maePressEffect()

                                    MaeIconButton(
                                        icon: "bubble.left.and.bubble.right.fill",
                                        color: Theme.Colors.accent,
                                        bgColor: Theme.Colors.accentSubtle,
                                        helpText: "Transferir analise para o chat principal"
                                    ) {
                                        withAnimation(Theme.Animation.smooth) {
                                            showConfirmation = true
                                        }
                                        Task { @MainActor in
                                            try? await Task.sleep(nanoseconds: 800_000_000)
                                            viewModel.continueWithAnalysis(followUp: followUpText.isEmpty ? nil : followUpText)
                                            followUpText = ""
                                            AnalysisWindowManager.shared.closeWindow()
                                            showConfirmation = false
                                        }
                                    }
                                    .maePressEffect()
                                }
                                .background(Theme.Colors.surfaceSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall, style: .continuous).stroke(Theme.Colors.border, lineWidth: 0.5))
                                .transition(.maeScaleFade)
                            }
                        }
                        .padding(.top, 30)
                        .padding(.bottom, 12)
                        .padding(.horizontal, Theme.Metrics.spacingXLarge)

                        // Content
                        if viewModel.isAnalyzingScreen {
                            VStack(spacing: 20) {
                                Spacer()

                                ZStack {
                                    Circle()
                                        .stroke(Theme.Colors.border, lineWidth: 2)
                                        .frame(width: 56, height: 56)
                                    Circle()
                                        .trim(from: 0, to: 0.3)
                                        .stroke(
                                            Theme.Colors.accentPrimary,
                                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                                        )
                                        .frame(width: 56, height: 56)
                                        .rotationEffect(.degrees(analysisSpinAngle))
                                        .onAppear {
                                            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                                                analysisSpinAngle = 360
                                            }
                                        }
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 20, weight: .light))
                                        .foregroundStyle(Theme.Colors.accentPrimary)
                                        .symbolEffect(.pulse.byLayer)
                                }

                                VStack(spacing: 6) {
                                    Text("Analisando...")
                                        .font(Theme.Typography.subheading)
                                        .foregroundStyle(Theme.Colors.textPrimary.opacity(0.8))
                                    Text("Processando captura de tela com IA")
                                        .font(Theme.Typography.caption)
                                        .foregroundStyle(Theme.Colors.textMuted)
                                        .maeStaggered(index: 1, baseDelay: 0.15)
                                }

                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .transition(.maeFadeScale)
                        } else if viewModel.analysisResult.isEmpty {
                            VStack(spacing: 16) {
                                Spacer()

                                ZStack {
                                    Circle()
                                        .fill(Theme.Colors.accentPrimary.opacity(0.04))
                                        .frame(width: 72, height: 72)
                                    Image(systemName: "viewfinder")
                                        .font(.system(size: 28, weight: .ultraLight))
                                        .foregroundStyle(Theme.Colors.accent.opacity(0.3))
                                        .symbolEffect(.breathe.plain)
                                }

                                VStack(spacing: 6) {
                                    Text("Nenhuma analise disponivel")
                                        .font(Theme.Typography.subheading)
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                        .maeStaggered(index: 1, baseDelay: 0.12)

                                    HStack(spacing: 4) {
                                        Text("Pressione")
                                            .font(Theme.Typography.caption)
                                            .foregroundStyle(Theme.Colors.textMuted)
                                        Text("Cmd+Shift+Z")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(Theme.Colors.textSecondary)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Theme.Colors.surfaceSecondary)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                        Text("para capturar")
                                            .font(Theme.Typography.caption)
                                            .foregroundStyle(Theme.Colors.textMuted)
                                    }
                                    .maeStaggered(index: 2, baseDelay: 0.12)
                                }

                                MaeActionButton(label: "Capturar Tela", icon: "camera.viewfinder") {
                                    Task { await viewModel.processarScreen() }
                                }
                                .maeStaggered(index: 3, baseDelay: 0.12)
                                .padding(.top, 8)

                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .maeAppearAnimation(animation: Theme.Animation.smooth)
                        } else {
                            ScrollView {
                                HatMarkdownView(markdown: viewModel.analysisResult)
                                    .font(Theme.Typography.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, Theme.Metrics.spacingXLarge)
                                    .padding(.vertical, Theme.Metrics.spacingLarge)
                            }
                            .background(Theme.Colors.backgroundSecondary)
                            .transition(.maeFadeScale)
                        }

                        // Follow-up input area
                        if !viewModel.analysisResult.isEmpty && !viewModel.isAnalyzingScreen {
                            VStack(spacing: 0) {
                                MaeDivider()

                                HStack(spacing: 10) {
                                    TextField("Perguntar algo sobre a analise...", text: $followUpText, axis: .vertical)
                                        .maeInputStyleOpaque(cornerRadius: Theme.Metrics.radiusSmall)
                                        .lineLimit(1...4)
                                        .focused($isFollowUpFocused)
                                        .onSubmit {
                                            if !followUpText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                                viewModel.continueWithAnalysis(followUp: followUpText)
                                                followUpText = ""
                                                AnalysisWindowManager.shared.closeWindow()
                                            }
                                        }

                                    Button {
                                        viewModel.continueWithAnalysis(followUp: followUpText)
                                        followUpText = ""
                                        AnalysisWindowManager.shared.closeWindow()
                                    } label: {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundStyle(
                                                followUpText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                                ? Theme.Colors.textMuted : Theme.Colors.accent
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .maePressEffect()
                                }
                                .padding(.horizontal, Theme.Metrics.spacingXLarge)
                                .padding(.vertical, Theme.Metrics.spacingDefault)
                            }
                            .transition(.maeSlideUp)
                        }
                    }
                    .frame(width: min(max(380, geo.size.width * 0.45), geo.size.width * 0.55))
                    .background(Theme.Colors.backgroundSecondary)

                    Divider()

                    // Right Panel: Image
                    VStack {
                        if let image = localImage {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding(Theme.Metrics.spacingXLarge)
                                .maeAppearAnimation(animation: Theme.Animation.smooth, scale: 0.96)
                                .accessibilityLabel("Captura de tela atual para analise")
                        } else {
                            VStack(spacing: Theme.Metrics.spacingLarge) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 52, weight: .ultraLight))
                                    .foregroundStyle(Theme.Colors.textMuted)
                                    .symbolEffect(.pulse.byLayer)
                                    .accessibilityHidden(true)
                                Text("Nenhuma captura de tela no momento.")
                                    .font(Theme.Typography.bodyBold)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                            .maeAppearAnimation(animation: Theme.Animation.gentle)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.Colors.background)
                }

                // Confirmation Toast Overlay
                if showConfirmation {
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Theme.Colors.success)
                            Text("Conversa transferida para o chat!")
                                .font(Theme.Typography.bodyBold)
                                .foregroundStyle(Theme.Colors.textPrimary)
                        }
                        .padding(.horizontal, Theme.Metrics.spacingXLarge)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.surface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Theme.Colors.border, lineWidth: 0.5))
                        .maeSoftShadow()
                        .padding(.bottom, 40)
                    }
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom)
                                .combined(with: .scale(scale: 0.85))
                                .combined(with: .opacity),
                            removal: .scale(scale: 0.95)
                                .combined(with: .opacity)
                        )
                    )
                    .zIndex(10)
                }
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .onAppear {
            localImage = viewModel.analysisImage
            if !viewModel.analysisResult.isEmpty {
                isFollowUpFocused = true
            }
        }
        .onChange(of: viewModel.analysisResult) { _, newResult in
            if !newResult.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFollowUpFocused = true
                }
            }
        }
        .onChange(of: viewModel.analysisImage) { _, newImage in
            if let newImage = newImage {
                localImage = newImage
            }
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
