//
//  ContentView.swift
//  Hat
//
//  Created by Joao Simi on 19/02/26.
//

import SwiftUI
import AppKit
import UserNotifications
import Combine
import KeyboardShortcuts
import UniformTypeIdentifiers
import PDFKit

// MARK: - Shortcut Name definition
extension KeyboardShortcuts.Name {
    static let processClipboard = Self("processClipboard", default: .init(.x, modifiers: [.command, .shift]))
    static let processScreen = Self("processScreen", default: .init(.z, modifiers: [.command, .shift]))
    static let quickInput = Self("quickInput", default: .init(.space, modifiers: [.command, .shift]))
}



// MARK: - Models
enum MessageSource {
    case chat
    case screenAnalysis
}

struct ChatAttachment: Identifiable {
    let id = UUID()
    let name: String
    let data: Data?
    let content: String?
    let image: NSImage?
    let isImage: Bool
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    var images: [NSImage]? = nil
    var attachments: [ChatAttachment]? = nil
    let isUser: Bool
    let source: MessageSource
    let timestamp = Date()
    
    init(content: String, images: [NSImage]? = nil, attachments: [ChatAttachment]? = nil, isUser: Bool, source: MessageSource = .chat) {
        self.content = content
        self.images = images
        self.attachments = attachments
        self.isUser = isUser
        self.source = source
    }
}

// MARK: - Protocols for Testing
protocol PasteboardClient {
    func string(forType type: NSPasteboard.PasteboardType) -> String?
    func data(forType type: NSPasteboard.PasteboardType) -> Data?
    @discardableResult func clearContents() -> Int
    @discardableResult func copyString(_ string: String, forType type: NSPasteboard.PasteboardType) -> Bool
    func readObjects(forClasses classArray: [AnyClass], options searchOptions: [NSPasteboard.ReadingOptionKey: Any]?) -> [Any]?
}

extension NSPasteboard: PasteboardClient {
    @discardableResult
    func copyString(_ string: String, forType type: NSPasteboard.PasteboardType) -> Bool {
        self.declareTypes([type], owner: nil)
        return self.setString(string, forType: type)
    }
}

// MARK: - NSImage Extension
extension NSImage {
    func resizedAndCompressedBase64(maxDimension: CGFloat = 1024) -> String? {
        guard let tiffData = self.tiffRepresentation,
              let imageSource = CGImageSourceCreateWithData(tiffData as CFData, nil) else {
            return nil
        }
        
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }
        
        let newImage = NSImage(cgImage: cgImage, size: .zero)
        guard let compressedTiff = newImage.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: compressedTiff),
              let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
            return nil
        }
        
        return jpegData.base64EncodedString()
    }
}

// MARK: - ViewModel
@MainActor
class AssistantViewModel: ObservableObject {
    static let shared = AssistantViewModel()
    
    @Published var isProcessing = false
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var attachedImages: [NSImage] = [] // Deprecated logic soon
    @Published var pendingAttachments: [ChatAttachment] = []
    
    // Análise de Tela - Novas Propriedades
    @Published var isAnalyzingScreen = false
    @Published var analysisResult: String = ""
    @Published var analysisImage: NSImage? = nil

    // Token Counters - Conversa atual
    @Published var conversationInputTokens: Int = 0
    @Published var conversationOutputTokens: Int = 0
    var conversationTotalTokens: Int { conversationInputTokens + conversationOutputTokens }
    
    private let pasteboard: PasteboardClient

    init(pasteboard: PasteboardClient = NSPasteboard.general) {
        self.pasteboard = pasteboard
    }

    func attachment(from url: URL) async -> ChatAttachment? {
        await Task.detached(priority: .userInitiated) {
            Self.attachmentSync(from: url)
        }.value
    }

    nonisolated private static func attachmentSync(from url: URL) -> ChatAttachment? {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }

        let type = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType
        let image = NSImage(contentsOf: url)

        if type?.conforms(to: .image) == true || image != nil {
            if let image {
                return ChatAttachment(name: url.lastPathComponent, data: nil, content: nil, image: image, isImage: true)
            }
        }

        if type?.conforms(to: .pdf) == true || url.pathExtension.lowercased() == "pdf" {
            let pdfText = extractPDFText(from: url)
            let normalized = pdfText.trimmingCharacters(in: .whitespacesAndNewlines)
            let content = normalized.isEmpty
                ? "[PDF anexado: \(url.lastPathComponent)]\nNão foi possível extrair texto pesquisável deste PDF."
                : pdfText
            return ChatAttachment(name: url.lastPathComponent, data: nil, content: content, image: nil, isImage: false)
        }

        if let textContent = extractTextFileContent(from: url) {
            return ChatAttachment(name: url.lastPathComponent, data: nil, content: textContent, image: nil, isImage: false)
        }

        if let data = try? Data(contentsOf: url) {
            let content = "[Arquivo binário anexado: \(url.lastPathComponent)]\nO conteúdo não é texto e não pôde ser extraído automaticamente."
            return ChatAttachment(name: url.lastPathComponent, data: data, content: content, image: nil, isImage: false)
        }

        return nil
    }

    nonisolated private static func extractPDFText(from url: URL) -> String {
        guard let document = PDFDocument(url: url), document.pageCount > 0 else { return "" }
        return document.string ?? ""
    }

    nonisolated private static func extractTextFileContent(from url: URL) -> String? {
        if let utf8 = try? String(contentsOf: url, encoding: .utf8) {
            let trimmed = utf8.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return utf8 }
        }

        guard let data = try? Data(contentsOf: url) else { return nil }
        let encodings: [String.Encoding] = [.utf16, .unicode, .isoLatin1, .windowsCP1252, .ascii]
        for encoding in encodings {
            if let decoded = String(data: data, encoding: encoding) {
                let trimmed = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return decoded }
            }
        }
        return nil
    }
    
    /// Chamado pelo atalho global (Processa Clipboard)
    func processarIA() async {
        guard !isProcessing else { return }
        
        var textoClipboard = pasteboard.string(forType: .string) ?? ""
        var copiedImage: NSImage? = nil
        
        if let objects = pasteboard.readObjects(forClasses: [NSImage.self], options: nil),
           let image = objects.first as? NSImage {
            copiedImage = image
        }
        
        if copiedImage != nil {
            let lowercased = textoClipboard.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if lowercased.hasPrefix("data:image/") ||
               lowercased.hasPrefix("http://") ||
               lowercased.hasPrefix("https://") ||
               lowercased.hasPrefix("file://") {
                textoClipboard = ""
            }
        }

        guard !textoClipboard.isEmpty || copiedImage != nil else { return }

        await executeRequest(prompt: textoClipboard, rawImages: copiedImage != nil ? [copiedImage!] : nil, attachments: nil)
    }

    /// Chamado pelo atalho global (Intelligent Screen Analysis)
    func processarScreen() async {
        guard !isAnalyzingScreen else { return }
        
        // Ativar o app e trazer para frente
        NSApp.activate(ignoringOtherApps: true)
        
        guard let screenImage = captureScreen() else {
            print("Failed to capture screen")
            return
        }

        // Abrir a nova janela de análise
        AnalysisWindowManager.shared.showWindow()
        self.analysisImage = screenImage
        self.analysisResult = ""
        self.isAnalyzingScreen = true

        let defaultPrompt = "Analise o que está na minha tela e me ajude de forma proativa. Não me pergunte o que fazer, apenas forneça a análise ou ajuda diretamente com base no contexto (por exemplo, se for um currículo, dê dicas; se for código, analise bugs, etc). Por favor, use formatação Markdown em sua resposta para garantir uma boa legibilidade."
        
        await executeSilentRequest(prompt: defaultPrompt, rawImages: [screenImage])
    }
    
    private func executeSilentRequest(prompt: String, rawImages: [NSImage]?) async {
        defer {
            self.isAnalyzingScreen = false
        }

        let systemPrompt = SettingsManager.systemPrompt
        let base64Images = rawImages?.compactMap { $0.resizedAndCompressedBase64() }

        do {
            let aiResponse = try await AIAPIService.shared.executeRequest(
                prompt: prompt,
                images: base64Images,
                history: [],
                systemPrompt: systemPrompt
            )

            self.analysisResult = aiResponse.text

            // Acumula tokens apenas no contador global (análise de tela é fora do chat)
            if let usage = aiResponse.tokenUsage {
                SettingsManager.addGlobalTokens(input: usage.inputTokens, output: usage.outputTokens)
            }

            if SettingsManager.playNotifications {
                await sendNotification(text: "Análise de tela concluída!")
                NSSound(named: "Glass")?.play()
            }

        } catch {
            self.analysisResult = "Erro: \(error.localizedDescription)"
            print("Error processing AI: \(error)")
        }
    }

    /// Transfere a análise atual para o chat principal
    func continueWithAnalysis(followUp: String? = nil) {
        guard !analysisResult.isEmpty else { return }
        
        let prompt = "📸 Análise de Tela"
        
        let userMsg = ChatMessage(content: prompt, images: analysisImage != nil ? [analysisImage!] : nil, attachments: nil, isUser: true, source: .screenAnalysis)
        let assistantMsg = ChatMessage(content: analysisResult, images: nil, attachments: nil, isUser: false, source: .screenAnalysis)
        
        messages.append(userMsg)
        messages.append(assistantMsg)
        
        // Se houver follow-up, enviar como nova mensagem
        if let followUp = followUp, !followUp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Task {
                await executeRequest(prompt: followUp, rawImages: nil, attachments: nil)
            }
        }
        
        // Limpa a análise atual após transferir
        analysisResult = ""
        analysisImage = nil
    }
    
    func captureScreen() -> NSImage? {
        // Obsolete in macOS 15.0: CGDisplayCreateImage(CGMainDisplayID())
        // Using screencapture CLI as a robust workaround that also triggers the permission prompt
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("png")
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-x", tempURL.path] // -x = no sound
        task.launch()
        task.waitUntilExit()
        
        let image = NSImage(contentsOf: tempURL)
        try? FileManager.default.removeItem(at: tempURL)
        return image
    }

    /// Chamado pela interface via TextField
    func sendManualMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachmentsToProcess = pendingAttachments
        
        guard !isProcessing && (!text.isEmpty || !attachmentsToProcess.isEmpty) else { return }
        
        inputText = ""
        pendingAttachments.removeAll()
        attachedImages.removeAll()
        
        var finalPrompt = text
        var extractedImages: [NSImage] = []
        
        for attachment in attachmentsToProcess {
            if attachment.isImage, let img = attachment.image {
                extractedImages.append(img)
            } else if let content = attachment.content {
                finalPrompt += "\n\n[Arquivo: \(attachment.name)]\n\(content)"
            }
        }
        
        await executeRequest(prompt: finalPrompt, rawImages: extractedImages.isEmpty ? nil : extractedImages, attachments: attachmentsToProcess.isEmpty ? nil : attachmentsToProcess)
    }

    private func executeRequest(prompt: String, rawImages: [NSImage]?, attachments: [ChatAttachment]?) async {
        isProcessing = true
        defer { isProcessing = false }

        let systemPrompt = SettingsManager.systemPrompt

        // Convert to Base64 for processing but store the raw `NSImage` locally
        let base64Images = rawImages?.compactMap { $0.resizedAndCompressedBase64() }

        // Build history from all existing messages BEFORE appending current user message
        let history = messages.map { msg in
            ConversationTurn(role: msg.isUser ? "user" : "assistant", textContent: msg.content)
        }

        // Adiciona a pergunta ao histórico
        let userMsg = ChatMessage(content: prompt, images: rawImages, attachments: attachments, isUser: true)
        messages.append(userMsg)

        do {
            let aiResponse = try await AIAPIService.shared.executeRequest(
                prompt: prompt,
                images: base64Images,
                history: history,
                systemPrompt: systemPrompt
            )

            let finalResponse = aiResponse.text

            // Acumula tokens
            if let usage = aiResponse.tokenUsage {
                conversationInputTokens += usage.inputTokens
                conversationOutputTokens += usage.outputTokens
                SettingsManager.addGlobalTokens(input: usage.inputTokens, output: usage.outputTokens)
            }

            // Adiciona a resposta ao histórico
            let assistantMsg = ChatMessage(content: finalResponse, images: nil, isUser: false)
            messages.append(assistantMsg)

            // Update Clipboard and Notify
            pasteboard.clearContents()
            pasteboard.copyString(finalResponse, forType: .string)

            if SettingsManager.playNotifications {
                await sendNotification(text: finalResponse)
                NSSound(named: "Glass")?.play()
            }

        } catch {
            let errorMsg = ChatMessage(content: "Erro: \(error.localizedDescription)", images: nil, isUser: false)
            messages.append(errorMsg)
            print("Error processing AI: \(error)")
        }
    }
    
    private func sendNotification(text: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Hat"
        content.body = text
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        _ = try? await UNUserNotificationCenter.current().add(request)
    }

    func clearHistory() {
        messages.removeAll()
        conversationInputTokens = 0
        conversationOutputTokens = 0
    }
}

// MARK: - Window Accessor
/// Captures the hosting NSWindow reference from SwiftUI.
struct WindowAccessor: NSViewRepresentable {
    var onChange: (NSWindow?) -> Void

    final class Coordinator {
        var configuredWindow: NSWindow?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // Use viewDidMoveToWindow via KVO-like approach: observe once view is in window hierarchy
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            configureIfNeeded(window: window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            configureIfNeeded(window: window, coordinator: context.coordinator)
        }
    }

    private func configureIfNeeded(window: NSWindow, coordinator: Coordinator) {
        guard coordinator.configuredWindow !== window else { return }
        coordinator.configuredWindow = window
        onChange(window)
    }
}

@MainActor
struct ContentView: View {
    @ObservedObject private var viewModel: AssistantViewModel
    @Namespace private var bottomID
    @State private var showSettings = false
    @State private var showOpacitySlider = false
    @State private var hostWindow: NSWindow?
    @AppStorage("windowOpacity") private var windowOpacity: Double = 1.0
    @AppStorage("globalTotalTokens") private var globalTotalTokens: Int = 0
    @FocusState private var isInputFocused: Bool

    init(viewModel: AssistantViewModel) {
        self.viewModel = viewModel
    }

    init() {
        self.viewModel = AssistantViewModel.shared
    }

    var body: some View {
        ZStack {
            chatView
                .opacity(showSettings ? 0.0 : 1.0)
                .offset(x: showSettings ? -30 : 0)
                .blur(radius: showSettings ? 3 : 0)
                .scaleEffect(showSettings ? 0.97 : 1.0)
                .animation(Theme.Animation.responsive, value: showSettings)
                .zIndex(1)

            if showSettings {
                SettingsView(isPresented: $showSettings)
                    .transition(.maeSlideIn)
                    .zIndex(2)
            }
        }
        .frame(width: 450, height: 650)
        .background(WindowAccessor { window in
            guard let window = window else { return }
            if self.hostWindow !== window {
                self.hostWindow = window
                window.alphaValue = windowOpacity
            }
        })
        .maeAppearAnimation(animation: Theme.Animation.expressive, scale: 0.92)
        .onAppear {
            isInputFocused = true
            hostWindow?.alphaValue = windowOpacity
        }
        .onChange(of: windowOpacity) { _, newValue in
            hostWindow?.alphaValue = newValue
        }
        .onChange(of: showSettings) { _, newValue in
            if !newValue {
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    isInputFocused = true
                }
            }
        }
    }

    private var chatView: some View {
        VStack(spacing: 0) {
            // ... (keeping previous header content)
            // Header
            HStack(spacing: 10) {
                Image("hat-svgrepo-com")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Theme.Colors.accent.opacity(0.8))

                Text("Hat")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary.opacity(0.9))

                if globalTotalTokens > 0 {
                    Text("·")
                        .foregroundStyle(Theme.Colors.textMuted)
                    Text(formatTokenCount(globalTotalTokens) + " tokens")
                        .font(Theme.Typography.micro)
                        .foregroundStyle(Theme.Colors.textMuted.opacity(0.7))
                        .help("Total de tokens usados no app")
                }

                Spacer()

                HStack(spacing: 2) {
                    MaeTooltipButton(icon: "macwindow.badge.plus", helpText: "Abrir Janela de Análise") {
                        AnalysisWindowManager.shared.showWindow()
                    }
                    MaeTooltipButton(icon: "trash", helpText: "Limpar histórico") {
                        withAnimation { viewModel.clearHistory() }
                    }
                    MaeTooltipButton(icon: "circle.lefthalf.filled", helpText: "Opacidade") {
                        withAnimation(Theme.Animation.smooth) {
                            showOpacitySlider.toggle()
                        }
                    }
                    .popover(isPresented: $showOpacitySlider) {
                        VStack(spacing: 8) {
                            Text("Opacidade")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                            Slider(value: $windowOpacity, in: 0.3...1.0, step: 0.05)
                                .frame(width: 160)
                        }
                        .padding(12)
                        .frame(width: 200)
                    }
                    MaeTooltipButton(icon: "gearshape", helpText: "Configurações") {
                        withAnimation(Theme.Animation.smooth) {
                            showSettings = true
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Metrics.spacingLarge)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .overlay(MaeGradientDivider(), alignment: .bottom)
            .zIndex(1)

            // Chat List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if viewModel.messages.isEmpty {
                            VStack(spacing: 20) {
                                Spacer().frame(height: 30)

                                // Icon with accent glow ring
                                ZStack {
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: [Theme.Colors.gradientStart.opacity(0.06), .clear],
                                                center: .center,
                                                startRadius: 10,
                                                endRadius: 50
                                            )
                                        )
                                        .frame(width: 90, height: 90)
                                    Circle()
                                        .fill(Theme.Colors.surfaceSecondary)
                                        .frame(width: 60, height: 60)
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [Theme.Colors.gradientStart.opacity(0.3), Theme.Colors.gradientEnd.opacity(0.15)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                        )
                                    Image("sunglasses-2-svgrepo-com")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 26, height: 26)
                                        .foregroundStyle(Theme.Colors.accent.opacity(0.6))
                                }
                                .maeFloating(amplitude: 3, duration: 4.5)

                                VStack(spacing: 6) {
                                    Text(greetingText)
                                        .font(Theme.Typography.heading)
                                        .foregroundStyle(Theme.Colors.textPrimary.opacity(0.85))
                                        .maeStaggered(index: 1, baseDelay: 0.12)
                                    Text("Pergunte qualquer coisa ou use os atalhos abaixo.")
                                        .font(Theme.Typography.caption)
                                        .foregroundStyle(Theme.Colors.textMuted.opacity(0.7))
                                        .maeStaggered(index: 2, baseDelay: 0.12)
                                }

                                // Quick action suggestions
                                VStack(spacing: 6) {
                                    EmptyStateSuggestion(icon: "doc.on.clipboard", label: "Analisar clipboard", shortcut: "⌘⇧X") {
                                        Task { await viewModel.processarIA() }
                                    }
                                    .maeStaggered(index: 3, baseDelay: 0.10)

                                    EmptyStateSuggestion(icon: "camera.viewfinder", label: "Analisar tela", shortcut: "⌘⇧Z") {
                                        Task { await viewModel.processarScreen() }
                                    }
                                    .maeStaggered(index: 4, baseDelay: 0.10)

                                    EmptyStateSuggestion(icon: "bolt.fill", label: "Entrada rápida", shortcut: "⌘⇧Space") {
                                        QuickInputWindowManager.shared.toggleWindow()
                                    }
                                    .maeStaggered(index: 5, baseDelay: 0.10)
                                }
                                .padding(.horizontal, 36)
                                .padding(.top, 6)
                            }
                            .frame(maxWidth: .infinity)
                            .maeAppearAnimation(animation: Theme.Animation.expressive)
                        } else {
                            ForEach(viewModel.messages.indices, id: \.self) { index in
                                ChatBubble(message: viewModel.messages[index], animationIndex: index)
                                    .id(viewModel.messages[index].id)
                                    .transition(.maePopIn)
                            }
                        }
                        Color.clear.frame(height: 10).id(bottomID)
                    }
                    .padding(.vertical, Theme.Metrics.spacingDefault)
                }
                .scrollContentBackground(.hidden)
                .background(Theme.Colors.background.opacity(0.5))
                .background(.ultraThinMaterial)
                .onChange(of: viewModel.messages.count) {
                    withAnimation(Theme.Animation.responsive) {
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
            }

            // Footer / Input Area
            VStack(spacing: 0) {
                // Attached Images and Files Preview
                if !viewModel.pendingAttachments.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.pendingAttachments.indices, id: \.self) { index in
                                let attachment = viewModel.pendingAttachments[index]
                                ZStack(alignment: .topTrailing) {
                                    if attachment.isImage, let img = attachment.image {
                                        Image(nsImage: img)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 60, height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall))
                                            .shadow(radius: 2)
                                    } else {
                                        VStack(spacing: 4) {
                                            Image(systemName: "doc.text.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(Theme.Colors.accent)
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
                                            viewModel.pendingAttachments.removeAll { $0.id == attachment.id }
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
                                .maeStaggered(index: index, baseDelay: 0.06)
                            }
                        }
                        .padding(.horizontal, Theme.Metrics.spacingDefault)
                        .padding(.top, 10)
                        .padding(.bottom, 6)
                    }
                    .transition(.maeSlideUp)
                }

                MaeGradientDivider()

                if viewModel.conversationTotalTokens > 0 {
                    HStack(spacing: 5) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Theme.Colors.accentBlue.opacity(0.5))
                        Text("\(formatTokenCount(viewModel.conversationTotalTokens)) tokens")
                            .font(Theme.Typography.micro)
                            .foregroundStyle(Theme.Colors.textMuted.opacity(0.6))
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 3)
                    .transition(.maeSlideUp)
                }

                HStack(alignment: .bottom, spacing: 8) {
                    MaeTooltipButton(icon: "plus.circle.fill", size: 16, helpText: "Anexar arquivo/imagem") {
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [UTType.image, UTType.plainText, UTType.pdf, UTType.json, UTType.sourceCode, UTType.data]
                        panel.allowsMultipleSelection = true
                        if panel.runModal() == .OK {
                            for url in panel.urls {
                                Task {
                                    if let attachment = await viewModel.attachment(from: url) {
                                        viewModel.pendingAttachments.append(attachment)
                                    } else {
                                        print("Erro ao ler arquivo selecionado: \(url.lastPathComponent)")
                                    }
                                }
                            }
                        }
                    }

                    TextField("Mensagem...", text: $viewModel.inputText, axis: .vertical)
                        .maeInputStyle(cornerRadius: 18)
                        .lineLimit(1...6)
                        .focused($isInputFocused)
                        .onSubmit {
                            Task { await viewModel.sendManualMessage() }
                        }
                        .disabled(viewModel.isProcessing)

                    if viewModel.isProcessing {
                        MaeTypingDots()
                            .frame(width: 30, height: 30)
                            .transition(.maeScaleFade)
                    } else {
                        Button {
                            Task { await viewModel.sendManualMessage() }
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(
                                    (viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.pendingAttachments.isEmpty)
                                    ? Theme.Colors.textMuted.opacity(0.4)
                                    : Theme.Colors.accent
                                )
                                .background(Theme.Colors.background.clipShape(Circle()))
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.pendingAttachments.isEmpty)
                        .keyboardShortcut(.defaultAction)
                        .maePressEffect()
                        .transition(.maeScaleFade)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial)
            }
            .zIndex(1)
        }
        .preferredColorScheme(.dark)
        .onDrop(of: [.image, .fileURL], isTargeted: nil) { providers in
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { (item, error) in
                        if let url = item as? URL, let image = NSImage(contentsOf: url) {
                            Task { @MainActor in
                                let attachment = ChatAttachment(name: url.lastPathComponent, data: nil, content: nil, image: image, isImage: true)
                                self.viewModel.pendingAttachments.append(attachment)
                            }
                        } else if let data = item as? Data, let image = NSImage(data: data) {
                            Task { @MainActor in
                                let attachment = ChatAttachment(name: "Imagem", data: nil, content: nil, image: image, isImage: true)
                                self.viewModel.pendingAttachments.append(attachment)
                            }
                        }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                        if let url = Self.resolveDroppedFileURL(item) {
                            Task { @MainActor in
                                if let attachment = await self.viewModel.attachment(from: url) {
                                    self.viewModel.pendingAttachments.append(attachment)
                                } else {
                                    print("Erro ao ler arquivo do drop: \(url.lastPathComponent)")
                                }
                            }
                        }
                    }
                }
            }
            return true
        }
    }

    nonisolated private static func resolveDroppedFileURL(_ item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }
        if let data = item as? Data {
            if let url = NSURL(absoluteURLWithDataRepresentation: data, relativeTo: nil) as URL? {
                return url
            }
            if let urlString = String(data: data, encoding: .utf8) {
                return URL(string: urlString)
            }
        }
        if let urlString = item as? String {
            return URL(string: urlString)
        }
        return nil
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Bom dia! Como posso ajudar?"
        case 12..<18: return "Boa tarde! Como posso ajudar?"
        case 18..<23: return "Boa noite! Como posso ajudar?"
        default:      return "Como posso ajudar?"
        }
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }
}

// MARK: - Empty State Suggestion Button
struct EmptyStateSuggestion: View {
    let icon: String
    let label: String
    let shortcut: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isHovered ? Theme.Colors.accentBlue : Theme.Colors.accent.opacity(0.6))
                    .frame(width: 20)
                    .animation(Theme.Animation.hover, value: isHovered)

                Text(label)
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(isHovered ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                    .animation(Theme.Animation.hover, value: isHovered)

                Spacer()

                Text(shortcut)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                isHovered
                    ? Theme.Colors.surfaceElevated.opacity(0.8)
                    : Theme.Colors.surfaceSecondary.opacity(0.6)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall, style: .continuous)
                    .stroke(
                        isHovered ? Theme.Colors.borderHighlight : Theme.Colors.border,
                        lineWidth: 0.5
                    )
            )
            .animation(Theme.Animation.hover, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
        .maePressEffect()
    }
}

#Preview {
    ContentView()
}
