//
//  ConversationManager.swift
//  Hat
//
//  Created by Claude on 27/03/26.
//

import Foundation
import Combine

// MARK: - Models

struct SavedMessage: Identifiable, Codable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
    let source: String // "chat" or "screenAnalysis"

    init(id: UUID = UUID(), content: String, isUser: Bool, timestamp: Date = Date(), source: String = "chat") {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.source = source
    }
}

struct Conversation: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [SavedMessage]
    var isPinned: Bool
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String = "Nova conversa", messages: [SavedMessage] = [], isPinned: Bool = false) {
        self.id = id
        self.title = title
        self.messages = messages
        self.isPinned = isPinned
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Auto-generate title from first user message
    var autoTitle: String {
        if let firstUserMessage = messages.first(where: { $0.isUser }) {
            let text = firstUserMessage.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.count > 40 {
                return String(text.prefix(40)) + "..."
            }
            return text.isEmpty ? "Nova conversa" : text
        }
        return title
    }

    /// Preview text from last message
    var preview: String {
        guard let last = messages.last else { return "Sem mensagens" }
        let text = last.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count > 60 {
            return String(text.prefix(60)) + "..."
        }
        return text.isEmpty ? "..." : text
    }
}

// MARK: - Conversation Manager

@MainActor
class ConversationManager: ObservableObject {
    static let shared = ConversationManager()

    @Published var conversations: [Conversation] = []
    @Published var activeConversationId: UUID?

    private let maxConversations = 50
    private let maxMessagesPerConversation = 200

    private var storageDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Hat/conversations")
    }

    private init() {
        ensureDirectoryExists()
        loadConversations()
        pruneOldConversations()
    }

    // MARK: - Active Conversation

    var activeConversation: Conversation? {
        guard let id = activeConversationId else { return nil }
        return conversations.first { $0.id == id }
    }

    // MARK: - CRUD

    @discardableResult
    func createConversation() -> Conversation {
        let conversation = Conversation()
        conversations.insert(conversation, at: 0)
        activeConversationId = conversation.id
        saveIndex()
        pruneOldConversations()
        return conversation
    }

    func selectConversation(id: UUID) {
        activeConversationId = id
    }

    func deleteConversation(id: UUID) {
        conversations.removeAll { $0.id == id }
        // Remove file
        let fileURL = storageDirectory.appendingPathComponent("\(id.uuidString).json")
        try? FileManager.default.removeItem(at: fileURL)

        if activeConversationId == id {
            activeConversationId = conversations.first?.id
        }
        saveIndex()
    }

    func renameConversation(id: UUID, title: String) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].title = title
        saveConversation(conversations[index])
        saveIndex()
    }

    func togglePin(id: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].isPinned.toggle()
        saveConversation(conversations[index])
        saveIndex()
    }

    // MARK: - Messages

    func addMessage(content: String, isUser: Bool, source: MessageSource = .chat) {
        // Create conversation if none active
        if activeConversationId == nil {
            createConversation()
        }

        guard let index = conversations.firstIndex(where: { $0.id == activeConversationId }) else { return }

        let savedMessage = SavedMessage(
            content: content,
            isUser: isUser,
            source: source == .screenAnalysis ? "screenAnalysis" : "chat"
        )

        conversations[index].messages.append(savedMessage)
        conversations[index].updatedAt = Date()

        // Auto-title from first user message
        if isUser && conversations[index].messages.filter({ $0.isUser }).count == 1 {
            conversations[index].title = conversations[index].autoTitle
        }

        // Trim messages if over limit
        if conversations[index].messages.count > maxMessagesPerConversation {
            conversations[index].messages = Array(conversations[index].messages.suffix(maxMessagesPerConversation))
        }

        // Move to top of list (most recent)
        let conversation = conversations.remove(at: index)
        conversations.insert(conversation, at: 0)

        saveConversation(conversations[0])
        saveIndex()
    }

    func clearActiveConversation() {
        guard let id = activeConversationId,
              let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].messages.removeAll()
        conversations[index].updatedAt = Date()
        saveConversation(conversations[index])
        saveIndex()
    }

    // MARK: - Grouping

    enum ConversationGroup: String, CaseIterable {
        case pinned = "Fixadas"
        case today = "Hoje"
        case yesterday = "Ontem"
        case lastWeek = "Ultima semana"
        case older = "Mais antigo"
    }

    var groupedConversations: [(group: ConversationGroup, items: [Conversation])] {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        let startOfLastWeek = calendar.date(byAdding: .day, value: -7, to: startOfToday)!

        var pinned: [Conversation] = []
        var today: [Conversation] = []
        var yesterday: [Conversation] = []
        var lastWeek: [Conversation] = []
        var older: [Conversation] = []

        for conversation in conversations {
            if conversation.isPinned {
                pinned.append(conversation)
            } else if conversation.updatedAt >= startOfToday {
                today.append(conversation)
            } else if conversation.updatedAt >= startOfYesterday {
                yesterday.append(conversation)
            } else if conversation.updatedAt >= startOfLastWeek {
                lastWeek.append(conversation)
            } else {
                older.append(conversation)
            }
        }

        var result: [(group: ConversationGroup, items: [Conversation])] = []
        if !pinned.isEmpty { result.append((.pinned, pinned)) }
        if !today.isEmpty { result.append((.today, today)) }
        if !yesterday.isEmpty { result.append((.yesterday, yesterday)) }
        if !lastWeek.isEmpty { result.append((.lastWeek, lastWeek)) }
        if !older.isEmpty { result.append((.older, older)) }
        return result
    }

    // MARK: - Persistence

    private func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
    }

    private func saveConversation(_ conversation: Conversation) {
        let fileURL = storageDirectory.appendingPathComponent("\(conversation.id.uuidString).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(conversation) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func loadConversation(id: UUID) -> Conversation? {
        let fileURL = storageDirectory.appendingPathComponent("\(id.uuidString).json")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Conversation.self, from: data)
    }

    private func saveIndex() {
        let indexURL = storageDirectory.appendingPathComponent("index.json")
        let entries = conversations.map { IndexEntry(id: $0.id, title: $0.title, isPinned: $0.isPinned, createdAt: $0.createdAt, updatedAt: $0.updatedAt) }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(entries) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }

    private func loadConversations() {
        let indexURL = storageDirectory.appendingPathComponent("index.json")
        guard let data = try? Data(contentsOf: indexURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let entries = try? decoder.decode([IndexEntry].self, from: data) else { return }

        conversations = entries.compactMap { entry in
            loadConversation(id: entry.id)
        }
    }

    func pruneOldConversations() {
        let unpinned = conversations.filter { !$0.isPinned }
        if unpinned.count > maxConversations {
            let toRemove = unpinned.suffix(unpinned.count - maxConversations)
            for conversation in toRemove {
                deleteConversation(id: conversation.id)
            }
        }
    }
}

// MARK: - Index Entry (lightweight metadata)

private struct IndexEntry: Codable {
    let id: UUID
    let title: String
    let isPinned: Bool
    let createdAt: Date
    let updatedAt: Date
}
