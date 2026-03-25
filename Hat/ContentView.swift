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
        
        guard let screenImage = await captureScreen() else {
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
    
    func captureScreen() async -> NSImage? {
        // Obsolete in macOS 15.0: CGDisplayCreateImage(CGMainDisplayID())
        // Using screencapture CLI as a robust workaround that also triggers the permission prompt.
        // Runs on a background thread to avoid blocking the main thread during capture.
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("png")
        return await Task.detached(priority: .userInitiated) {
            let task = Process()
            // Use executableURL + run() (modern API) so a launch failure becomes a
            // Swift Error instead of an unhandled NSException that would crash the app.
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            task.arguments = ["-x", tempURL.path] // -x = no sound
            try? task.run()
            task.waitUntilExit()

            let image = NSImage(contentsOf: tempURL)
            try? FileManager.default.removeItem(at: tempURL)
            return image
        }.value
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
    @AppStorage("inferenceMode") private var inferenceMode: InferenceMode = .local
    @AppStorage("apiModelName") private var apiModelName: String = "gpt-5.2"
    @AppStorage("localModelName") private var localModelName: String = "gemma3:4b"
    @FocusState private var isInputFocused: Bool
    @State private var placeholderIndex: Int = 0
    @State private var isInputFocusedForBorder: Bool = false
    @State private var isAtBottom: Bool = true
    private let placeholders = ["Mensagem...", "Resuma este texto...", "Explique como...", "Me ajude com..."]

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
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image("hat-svgrepo-com")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(Theme.Colors.accent.opacity(0.8))

                    MaeTag(
                        label: inferenceMode == .local ? localModelName : apiModelName,
                        icon: inferenceMode == .local ? "desktopcomputer" : "cloud.fill",
                        color: Theme.Colors.textSecondary
                    )

                    Spacer()

                    HStack(spacing: 4) {
                        MaeTooltipButton(icon: "macwindow.badge.plus", helpText: "Análise") {
                            AnalysisWindowManager.shared.showWindow()
                        }
                        MaeTooltipButton(icon: "square.and.arrow.up", helpText: "Exportar conversa") {
                            exportConversation()
                        }
                        .disabled(viewModel.messages.isEmpty)
                        .opacity(viewModel.messages.isEmpty ? 0.35 : 1.0)
                        MaeTooltipButton(icon: "trash", helpText: "Limpar") {
                            withAnimation(Theme.Animation.smooth) { viewModel.clearHistory() }
                        }

                        Rectangle()
                            .fill(Theme.Colors.border)
                            .frame(width: 0.5, height: 16)

                        MaeTooltipButton(icon: "circle.lefthalf.filled", helpText: "Opacidade") {
                            withAnimation(Theme.Animation.smooth) {
                                showOpacitySlider.toggle()
                            }
                        }
                        .popover(isPresented: $showOpacitySlider) {
                            Slider(value: $windowOpacity, in: 0.3...1.0, step: 0.05)
                                .tint(Theme.Colors.accentPrimary)
                                .frame(width: 160)
                                .padding(12)
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

                MaeGradientDivider(tinted: true)
            }
            .background(Theme.Colors.surface)
            .zIndex(1)

            // Chat List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if viewModel.messages.isEmpty {
                            VStack(spacing: 20) {
                                Spacer().frame(height: 40)

                                // Accent glow behind greeting
                                ZStack {
                                    // Subtle radial glow
                                    RadialGradient(
                                        gradient: Gradient(colors: [Theme.Colors.accentPrimary.opacity(0.08), Theme.Colors.accentSecondary.opacity(0.03), .clear]),
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 140
                                    )
                                    .frame(width: 280, height: 280)

                                    VStack(spacing: 16) {
                                        // Icon with gradient ring
                                        ZStack {
                                            Circle()
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [Theme.Colors.gradientStart.opacity(0.15), Theme.Colors.gradientEnd.opacity(0.08)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1.5
                                                )
                                                .frame(width: 64, height: 64)
                                            Circle()
                                                .fill(Theme.Colors.surfaceSecondary)
                                                .frame(width: 56, height: 56)
                                            Image("hat-svgrepo-com")
                                                .renderingMode(.template)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 24, height: 24)
                                                .foregroundStyle(Theme.Colors.accentPrimary.opacity(0.7))
                                        }
                                        .maeFloating(amplitude: 3, duration: 4.0)

                                        VStack(spacing: 4) {
                                            Text(greetingText)
                                                .font(Theme.Typography.headingSerif)
                                                .foregroundStyle(Theme.Colors.textPrimary.opacity(0.9))

                                            Text("Como posso te ajudar?")
                                                .font(Theme.Typography.bodySmall)
                                                .foregroundStyle(Theme.Colors.textMuted)
                                        }
                                    }
                                }

                                // Quick action suggestions
                                VStack(spacing: 6) {
                                    EmptyStateSuggestion(icon: "doc.on.clipboard", label: "Analisar clipboard", shortcut: "⌘⇧X") {
                                        Task { await viewModel.processarIA() }
                                    }

                                    EmptyStateSuggestion(icon: "camera.viewfinder", label: "Analisar tela", shortcut: "⌘⇧Z") {
                                        Task { await viewModel.processarScreen() }
                                    }

                                    EmptyStateSuggestion(icon: "bolt.fill", label: "Entrada rápida", shortcut: "⌘⇧Space") {
                                        QuickInputWindowManager.shared.toggleWindow()
                                    }
                                }
                                .padding(.horizontal, 36)
                            }
                            .frame(maxWidth: .infinity)
                            .maeAppearAnimation(animation: Theme.Animation.expressive)
                        } else {
                            ForEach(viewModel.messages.indices, id: \.self) { index in
                                // Date separator when day changes
                                if index == 0 || !Calendar.current.isDate(viewModel.messages[index].timestamp, inSameDayAs: viewModel.messages[index - 1].timestamp) {
                                    MaeDateSeparator(date: viewModel.messages[index].timestamp)
                                        .transition(.opacity)
                                }
                                let isGrouped = index > 0
                                    && viewModel.messages[index].isUser == viewModel.messages[index - 1].isUser
                                    && Calendar.current.isDate(viewModel.messages[index].timestamp, inSameDayAs: viewModel.messages[index - 1].timestamp)
                                ChatBubble(message: viewModel.messages[index], animationIndex: index, isGrouped: isGrouped)
                                    .id(viewModel.messages[index].id)
                                    .transition(.maePopIn)
                            }
                        }
                        Color.clear.frame(height: 10).id(bottomID)
                    }
                    .padding(.vertical, Theme.Metrics.spacingDefault)
                }
                .scrollContentBackground(.hidden)
                .background(Theme.Colors.background)
                .overlay(alignment: .bottom) {
                    if !isAtBottom && !viewModel.messages.isEmpty {
                        MaeScrollToBottomButton {
                            withAnimation(Theme.Animation.responsive) {
                                proxy.scrollTo(bottomID, anchor: .bottom)
                            }
                        }
                        .padding(.bottom, 8)
                        .transition(.maeScaleFade)
                    }
                }
                .onChange(of: viewModel.messages.count) {
                    withAnimation(Theme.Animation.responsive) {
                        proxy.scrollTo(bottomID, anchor: .bottom)
                        isAtBottom = true
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
                                            .frame(width: 72, height: 72)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .stroke(Theme.Colors.border, lineWidth: 0.5)
                                            )
                                            .maeSoftShadow()
                                    } else {
                                        VStack(spacing: 4) {
                                            Image(systemName: "doc.text.fill")
                                                .font(.system(size: 24))
                                                .foregroundStyle(Theme.Colors.accentPrimary)
                                                .symbolEffect(.bounce, options: .nonRepeating)
                                            Text(attachment.name)
                                                .font(.system(size: 9))
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                                .frame(width: 60)
                                        }
                                        .frame(width: 72, height: 72)
                                        .background(Theme.Colors.surfaceSecondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(Theme.Colors.border, lineWidth: 0.5)
                                        )
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

                HStack(alignment: .bottom, spacing: 8) {
                    MaeTooltipButton(icon: "plus.circle.fill", size: 17, helpText: "Anexar arquivo/imagem") {
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

                    TextField(placeholders[placeholderIndex], text: $viewModel.inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(Theme.Typography.bodySmall)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Theme.Colors.inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(isInputFocusedForBorder ? Theme.Colors.borderFocused : Theme.Colors.border, lineWidth: isInputFocusedForBorder ? 1 : 0.5)
                        )
                        .lineLimit(1...6)
                        .focused($isInputFocused)
                        .onSubmit {
                            Task { await viewModel.sendManualMessage() }
                        }
                        .disabled(viewModel.isProcessing)
                        .onChange(of: isInputFocused) { _, focused in
                            withAnimation(Theme.Animation.quickSnap) { isInputFocusedForBorder = focused }
                        }
                        .onReceive(Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()) { _ in
                            if viewModel.inputText.isEmpty {
                                withAnimation(Theme.Animation.fade) {
                                    placeholderIndex = (placeholderIndex + 1) % placeholders.count
                                }
                            }
                        }

                    if viewModel.isProcessing {
                        MaeTypingDots()
                            .frame(width: 32, height: 32)
                            .transition(.maeScaleFade)
                    } else {
                        let hasContent = !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !viewModel.pendingAttachments.isEmpty
                        Button {
                            Task { await viewModel.sendManualMessage() }
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(hasContent ? Theme.Colors.accentPrimary : Theme.Colors.textMuted.opacity(0.3))
                                .background(Theme.Colors.background.clipShape(Circle()))
                                .frame(width: 32, height: 32)
                                .shadow(color: hasContent ? Theme.Colors.accentPrimary.opacity(0.3) : .clear, radius: 6)
                                .animation(Theme.Animation.quickSnap, value: hasContent)
                        }
                        .buttonStyle(.plain)
                        .disabled(!hasContent)
                        .keyboardShortcut(.defaultAction)
                        .maePressEffect()
                        .transition(.maeScaleFade)
                    }
                }
                .padding(.horizontal, Theme.Metrics.spacingDefault)
                .padding(.vertical, 10)
                .background(Theme.Colors.surface)
            }
            .zIndex(1)
        }

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

    private func exportConversation() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let dateString = formatter.string(from: Date())

        formatter.dateFormat = "HH:mm"

        // Build markdown document
        var lines: [String] = [
            "# Conversa com Hat",
            "**Exportado em:** \(dateString)",
            "",
            "---",
            ""
        ]

        for message in viewModel.messages {
            let time = formatter.string(from: message.timestamp)
            if message.isUser {
                lines.append("**Você** · \(time)")
            } else {
                lines.append("**Hat** · \(time)")
            }
            lines.append("")
            lines.append(message.content)
            lines.append("")
            lines.append("---")
            lines.append("")
        }

        let markdown = lines.joined(separator: "\n")

        let panel = NSSavePanel()
        panel.title = "Exportar conversa"
        panel.nameFieldStringValue = "conversa-hat-\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none).replacingOccurrences(of: "/", with: "-")).md"
        if let mdType = UTType(filenameExtension: "md") {
            panel.allowedContentTypes = [mdType]
        }
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            try? markdown.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Bom dia!"
        case 12..<18: return "Boa tarde!"
        case 18..<23: return "Boa noite!"
        default:      return "Olá!"
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
            HStack(spacing: 0) {
                // Left accent bar
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        LinearGradient(
                            colors: [Theme.Colors.gradientStart.opacity(isHovered ? 0.6 : 0.2), Theme.Colors.gradientEnd.opacity(isHovered ? 0.4 : 0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 2.5)
                    .padding(.vertical, 6)

                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isHovered ? Theme.Colors.accentPrimary : Theme.Colors.accent.opacity(0.6))
                        .frame(width: 20)

                    Text(label)
                        .font(Theme.Typography.bodySmall)
                        .foregroundStyle(isHovered ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)

                    Spacer()

                    Text(shortcut)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textMuted.opacity(isHovered ? 0.8 : 0.45))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.surfaceTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.Colors.border, lineWidth: 0.5))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .background(isHovered ? Theme.Colors.surfaceElevated : .clear)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall, style: .continuous)
                    .stroke(isHovered ? Theme.Colors.border : Color.clear, lineWidth: 0.5)
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
