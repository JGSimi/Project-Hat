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
    let id: UUID
    let content: String
    var images: [NSImage]? = nil
    var attachments: [ChatAttachment]? = nil
    let isUser: Bool
    let source: MessageSource
    let timestamp: Date
    var isStreaming: Bool = false

    init(content: String, images: [NSImage]? = nil, attachments: [ChatAttachment]? = nil, isUser: Bool, source: MessageSource = .chat) {
        self.id = UUID()
        self.content = content
        self.images = images
        self.attachments = attachments
        self.isUser = isUser
        self.source = source
        self.timestamp = Date()
    }

    /// Creates a message with a specific ID (used to update streaming messages in-place)
    init(id: UUID, content: String, images: [NSImage]? = nil, isUser: Bool, isStreaming: Bool = false, source: MessageSource = .chat) {
        self.id = id
        self.content = content
        self.images = images
        self.attachments = nil
        self.isUser = isUser
        self.source = source
        self.timestamp = Date()
        self.isStreaming = isStreaming
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
    @Published var attachedImages: [NSImage] = []
    @Published var pendingAttachments: [ChatAttachment] = []

    @Published var isAnalyzingScreen = false
    @Published var analysisResult: String = ""
    @Published var analysisImage: NSImage? = nil

    @Published var conversationInputTokens: Int = 0
    @Published var conversationOutputTokens: Int = 0
    var conversationTotalTokens: Int { conversationInputTokens + conversationOutputTokens }

    @Published var isStreaming = false
    @Published var streamingText: String = ""
    private var streamingTask: Task<Void, Never>?

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

    func processarScreen() async {
        guard !isAnalyzingScreen else { return }

        NSApp.activate(ignoringOtherApps: true)

        guard let screenImage = await captureScreen() else {
            print("Failed to capture screen")
            return
        }

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

    func continueWithAnalysis(followUp: String? = nil) {
        guard !analysisResult.isEmpty else { return }

        let prompt = "Análise de Tela"

        let userMsg = ChatMessage(content: prompt, images: analysisImage != nil ? [analysisImage!] : nil, attachments: nil, isUser: true, source: .screenAnalysis)
        let assistantMsg = ChatMessage(content: analysisResult, images: nil, attachments: nil, isUser: false, source: .screenAnalysis)

        messages.append(userMsg)
        messages.append(assistantMsg)

        if let followUp = followUp, !followUp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Task {
                await executeRequest(prompt: followUp, rawImages: nil, attachments: nil)
            }
        }

        analysisResult = ""
        analysisImage = nil
    }

    func captureScreen() async -> NSImage? {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("png")
        return await Task.detached(priority: .userInitiated) {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            task.arguments = ["-x", tempURL.path]
            try? task.run()
            task.waitUntilExit()

            let image = NSImage(contentsOf: tempURL)
            try? FileManager.default.removeItem(at: tempURL)
            return image
        }.value
    }

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

        let systemPrompt = SettingsManager.systemPrompt
        let base64Images = rawImages?.compactMap { $0.resizedAndCompressedBase64() }

        let history = messages.map { msg in
            ConversationTurn(role: msg.isUser ? "user" : "assistant", textContent: msg.content)
        }

        let userMsg = ChatMessage(content: prompt, images: rawImages, attachments: attachments, isUser: true)
        messages.append(userMsg)

        // Add placeholder streaming message
        var placeholderMsg = ChatMessage(content: "", images: nil, isUser: false)
        placeholderMsg.isStreaming = true
        let placeholderID = placeholderMsg.id
        messages.append(placeholderMsg)

        isStreaming = true
        streamingText = ""

        let task = Task {
            var accumulatedText = ""
            var finalTokenUsage: TokenUsage?
            // Cache the placeholder index for O(1) updates instead of O(n) firstIndex on every chunk
            let placeholderIndex = messages.firstIndex(where: { $0.id == placeholderID })

            do {
                let stream = AIAPIService.shared.executeStreamingRequest(
                    prompt: prompt,
                    images: base64Images,
                    history: history,
                    systemPrompt: systemPrompt
                )

                for try await chunk in stream {
                    try Task.checkCancellation()
                    accumulatedText += chunk.text
                    streamingText = accumulatedText

                    // Update the placeholder message content in-place using cached index
                    if let idx = placeholderIndex {
                        messages[idx] = ChatMessage(id: placeholderID, content: accumulatedText, images: nil, isUser: false, isStreaming: true)
                    }

                    if let usage = chunk.tokenUsage {
                        finalTokenUsage = usage
                    }
                }

                if let usage = finalTokenUsage {
                    conversationInputTokens += usage.inputTokens
                    conversationOutputTokens += usage.outputTokens
                    SettingsManager.addGlobalTokens(input: usage.inputTokens, output: usage.outputTokens)
                }

                // Finalize: ensure the message has the full text
                let finalText = accumulatedText.trimmingCharacters(in: .whitespacesAndNewlines)
                if let idx = placeholderIndex {
                    messages[idx] = ChatMessage(id: placeholderID, content: finalText, images: nil, isUser: false)
                }

                if !finalText.isEmpty {
                    pasteboard.clearContents()
                    pasteboard.copyString(finalText, forType: .string)
                }

                if SettingsManager.playNotifications {
                    await sendNotification(text: finalText)
                    NSSound(named: "Glass")?.play()
                }

            } catch is CancellationError {
                // User stopped — keep partial text
                let partial = accumulatedText.trimmingCharacters(in: .whitespacesAndNewlines)
                if partial.isEmpty {
                    messages.removeAll { $0.id == placeholderID }
                } else if let idx = placeholderIndex {
                    messages[idx] = ChatMessage(id: placeholderID, content: partial, images: nil, isUser: false)
                }
            } catch {
                let partial = accumulatedText.trimmingCharacters(in: .whitespacesAndNewlines)
                let errorSuffix = "\n\n⚠ Resposta interrompida: \(error.localizedDescription)"
                let finalContent = partial.isEmpty ? "Erro: \(error.localizedDescription)" : partial + errorSuffix
                if let idx = placeholderIndex {
                    messages[idx] = ChatMessage(id: placeholderID, content: finalContent, images: nil, isUser: false)
                }
                print("Error processing AI: \(error)")
            }

            isStreaming = false
            streamingText = ""
            isProcessing = false
        }
        streamingTask = task
    }

    func cancelStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
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
struct WindowAccessor: NSViewRepresentable {
    var onChange: (NSWindow?) -> Void

    final class Coordinator {
        var configuredWindow: NSWindow?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
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

// MARK: - ContentView (Chat Panel)

@MainActor
struct ContentView: View {
    @ObservedObject private var viewModel: AssistantViewModel
    @ObservedObject var conversationManager: ConversationManager
    @Binding var showSidebar: Bool
    @Namespace private var bottomID
    @AppStorage("inferenceMode") private var inferenceMode: InferenceMode = .local
    @AppStorage("apiModelName") private var apiModelName: String = "gpt-5.2"
    @AppStorage("localModelName") private var localModelName: String = "gemma3:4b"
    @FocusState private var isInputFocused: Bool
    @State private var isInputFocusedForBorder: Bool = false
    @State private var isAtBottom: Bool = true

    init(showSidebar: Binding<Bool>, conversationManager: ConversationManager) {
        self._showSidebar = showSidebar
        self.conversationManager = conversationManager
        self.viewModel = AssistantViewModel.shared
    }

    init(viewModel: AssistantViewModel) {
        self._showSidebar = .constant(true)
        self.conversationManager = ConversationManager.shared
        self.viewModel = viewModel
    }

    init() {
        self._showSidebar = .constant(true)
        self.conversationManager = ConversationManager.shared
        self.viewModel = AssistantViewModel.shared
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Header
            headerView

            // MARK: Chat Area
            chatListView

            // MARK: Floating Input
            floatingInputView
        }
        .background(Theme.Colors.background)
        .onAppear {
            isInputFocused = true
        }
        .onDrop(of: [.image, .fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
            return true
        }
        .onChange(of: viewModel.messages.count) { _, _ in
            // Only save user messages here; assistant messages are saved when streaming ends
            if let lastMessage = viewModel.messages.last, lastMessage.isUser {
                conversationManager.addMessage(
                    content: lastMessage.content,
                    isUser: true,
                    source: lastMessage.source
                )
            }
        }
        .onChange(of: viewModel.isStreaming) { _, isStreaming in
            // Save the completed assistant message only when streaming finishes
            if !isStreaming, let lastMessage = viewModel.messages.last, !lastMessage.isUser, !lastMessage.content.isEmpty {
                conversationManager.addMessage(
                    content: lastMessage.content,
                    isUser: false,
                    source: lastMessage.source
                )
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // Toggle sidebar
                MaeTooltipButton(icon: "sidebar.left", helpText: "Sidebar") {
                    withAnimation(Theme.Animation.smooth) {
                        showSidebar.toggle()
                    }
                }
                .keyboardShortcut("s", modifiers: .command)

                MaeTag(
                    label: inferenceMode == .local ? localModelName : apiModelName,
                    icon: inferenceMode == .local ? "desktopcomputer" : "cloud.fill",
                    color: Theme.Colors.textSecondary
                )

                Spacer()

                // Action buttons
                HStack(spacing: 2) {
                    MaeTooltipButton(icon: "macwindow.badge.plus", helpText: "Analisar tela") {
                        AnalysisWindowManager.shared.showWindow()
                    }

                    MaeTooltipButton(icon: "trash", helpText: "Limpar") {
                        withAnimation(Theme.Animation.smooth) {
                            viewModel.clearHistory()
                            conversationManager.clearActiveConversation()
                        }
                    }

                    MaeTooltipButton(icon: "gearshape", helpText: "Configuracoes") {
                        AdvancedSettingsWindowManager.shared.showWindow()
                    }
                }
            }
            .padding(.horizontal, Theme.Metrics.spacingLarge)
            .padding(.top, showSidebar ? 10 : 38)
            .padding(.bottom, 10)

            MaeDivider()
        }
        .background(Theme.Colors.surface)
        .zIndex(1)
    }

    // MARK: - Chat List

    private var chatListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if viewModel.messages.isEmpty {
                        emptyStateView
                    } else {
                        // Centered chat content
                        ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                            if index == 0 || !Calendar.current.isDate(message.timestamp, inSameDayAs: viewModel.messages[index - 1].timestamp) {
                                MaeDateSeparator(date: message.timestamp)
                                    .frame(maxWidth: 680)
                                    .frame(maxWidth: .infinity)
                                    .transition(.opacity)
                            }
                            let isGrouped = index > 0
                                && message.isUser == viewModel.messages[index - 1].isUser
                                && Calendar.current.isDate(message.timestamp, inSameDayAs: viewModel.messages[index - 1].timestamp)
                            ChatBubble(message: message, animationIndex: index, isGrouped: isGrouped)
                                .frame(maxWidth: 680)
                                .frame(maxWidth: .infinity)
                                .id(message.id)
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
                        withAnimation(Theme.Animation.smooth) {
                            proxy.scrollTo(bottomID, anchor: .bottom)
                        }
                    }
                    .padding(.bottom, 8)
                    .transition(.maeScaleFade)
                }
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(Theme.Animation.smooth) {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                    isAtBottom = true
                }
            }
            .onChange(of: viewModel.streamingText) { _, _ in
                if isAtBottom {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Logo + Greeting
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Theme.Colors.accentPrimary.opacity(0.15), lineWidth: 1.5)
                        .frame(width: 64, height: 64)
                    Image("hat-svgrepo-com")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .foregroundStyle(Theme.Colors.accentPrimary.opacity(0.7))
                }

                VStack(spacing: 6) {
                    Text(greetingText)
                        .font(Theme.Typography.largeTitle)
                        .foregroundStyle(Theme.Colors.textPrimary.opacity(0.9))

                    Text("Como posso te ajudar?")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textMuted)
                }
            }

            // Shortcut hints
            HStack(spacing: 16) {
                shortcutHint("⌘⇧X", "Clipboard")
                shortcutHint("⌘⇧Z", "Tela")
                shortcutHint("⌘⇧Space", "Rapida")
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .maeAppearAnimation(animation: Theme.Animation.smooth)
    }

    private func shortcutHint(_ shortcut: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(shortcut)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.Colors.textMuted.opacity(0.6))
            Text(label)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(Theme.Colors.textMuted.opacity(0.5))
        }
    }

    // MARK: - Floating Input

    private var floatingInputView: some View {
        VStack(spacing: 6) {
            // Floating input card
            VStack(spacing: 0) {
                // Attachments inside the input card
                if !viewModel.pendingAttachments.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.pendingAttachments.indices, id: \.self) { index in
                                let attachment = viewModel.pendingAttachments[index]
                                ZStack(alignment: .topTrailing) {
                                    if attachment.isImage, let img = attachment.image {
                                        Image(nsImage: img)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 56, height: 56)
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .stroke(Theme.Colors.border, lineWidth: 0.5)
                                            )
                                    } else {
                                        VStack(spacing: 3) {
                                            Image(systemName: "doc.text.fill")
                                                .font(.system(size: 16))
                                                .foregroundStyle(Theme.Colors.accentPrimary.opacity(0.7))
                                            Text(attachment.name)
                                                .font(.system(size: 8))
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                                .frame(width: 46)
                                        }
                                        .frame(width: 56, height: 56)
                                        .background(Theme.Colors.surfaceSecondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .stroke(Theme.Colors.border, lineWidth: 0.5)
                                        )
                                    }

                                    Button {
                                        withAnimation(Theme.Animation.snappy) {
                                            viewModel.pendingAttachments.removeAll { $0.id == attachment.id }
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(Theme.Colors.textPrimary, Theme.Colors.background)
                                            .frame(width: 20, height: 20)
                                    }
                                    .buttonStyle(.plain)
                                    .offset(x: 4, y: -4)
                                }
                                .transition(.maeScaleFade)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 10)
                        .padding(.bottom, 4)
                    }
                    .transition(.maeSlideUp)
                }

                // Input row
                HStack(alignment: .bottom, spacing: 8) {
                    MaeTooltipButton(icon: "plus.circle.fill", size: 16, helpText: "Anexar arquivo/imagem") {
                        openFilePicker()
                    }

                    TextField("Mensagem...", text: $viewModel.inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(Theme.Typography.bodySmall)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1...6)
                        .focused($isInputFocused)
                        .onSubmit {
                            Task { await viewModel.sendManualMessage() }
                        }
                        .disabled(viewModel.isProcessing)
                        .accessibilityLabel("Campo de mensagem")
                        .accessibilityHint("Comando Enter para enviar")

                    if viewModel.isStreaming {
                        Button {
                            viewModel.cancelStreaming()
                        } label: {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Theme.Colors.accentPrimary)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        .maePressEffect()
                        .transition(.maeScaleFade)
                        .accessibilityLabel("Parar geração")
                    } else if viewModel.isProcessing {
                        MaeTypingDots()
                            .frame(width: 28, height: 28)
                            .transition(.maeScaleFade)
                            .accessibilityLabel("Processando resposta")
                    } else {
                        let hasContent = !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !viewModel.pendingAttachments.isEmpty
                        Button {
                            Task { await viewModel.sendManualMessage() }
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(hasContent ? Theme.Colors.accentPrimary : Theme.Colors.textMuted.opacity(0.25))
                                .frame(width: 28, height: 28)
                                .animation(Theme.Animation.quickSnap, value: hasContent)
                        }
                        .buttonStyle(.plain)
                        .disabled(!hasContent)
                        .keyboardShortcut(.defaultAction)
                        .maePressEffect()
                        .transition(.maeScaleFade)
                        .accessibilityLabel("Enviar mensagem")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isInputFocusedForBorder ? Theme.Colors.borderFocused : Theme.Colors.border, lineWidth: isInputFocusedForBorder ? 1 : 0.5)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
            .frame(maxWidth: 680)
            .onChange(of: isInputFocused) { _, focused in
                withAnimation(Theme.Animation.quickSnap) { isInputFocusedForBorder = focused }
            }

            // Hint text
            Text("⌘+Enter para enviar · Arraste arquivos para anexar")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(Theme.Colors.textMuted.opacity(0.4))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.image, UTType.plainText, UTType.pdf, UTType.json, UTType.sourceCode, UTType.data]
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for url in panel.urls {
                Task {
                    if let attachment = await viewModel.attachment(from: url) {
                        viewModel.pendingAttachments.append(attachment)
                    }
                }
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
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
                            }
                        }
                    }
                }
            }
        }
    }

    nonisolated private static func resolveDroppedFileURL(_ item: NSSecureCoding?) -> URL? {
        if let url = item as? URL { return url }
        if let data = item as? Data {
            if let url = NSURL(absoluteURLWithDataRepresentation: data, relativeTo: nil) as URL? { return url }
            if let urlString = String(data: data, encoding: .utf8) { return URL(string: urlString) }
        }
        if let urlString = item as? String { return URL(string: urlString) }
        return nil
    }

    private func exportConversation() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let dateString = formatter.string(from: Date())
        formatter.dateFormat = "HH:mm"

        var lines: [String] = [
            "# Conversa com Hat",
            "**Exportado em:** \(dateString)",
            "", "---", ""
        ]

        for message in viewModel.messages {
            let time = formatter.string(from: message.timestamp)
            lines.append(message.isUser ? "**Voce** · \(time)" : "**Hat** · \(time)")
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
        if let mdType = UTType(filenameExtension: "md") { panel.allowedContentTypes = [mdType] }
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            try? markdown.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Bom dia"
        case 12..<18: return "Boa tarde"
        case 18..<23: return "Boa noite"
        default:      return "Ola"
        }
    }
}


#Preview {
    ContentView()
}
