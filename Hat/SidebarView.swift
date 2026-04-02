//
//  SidebarView.swift
//  Hat
//
//  Created by Claude on 27/03/26.
//

import SwiftUI
import Combine

struct SidebarView: View {
    @ObservedObject var conversationManager: ConversationManager
    @Binding var showSidebar: Bool
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var hoveredConversationId: UUID?
    @State private var conversationToDelete: UUID?
    @State private var settingsHovered = false

    private var filteredGroups: [(group: ConversationManager.ConversationGroup, items: [Conversation])] {
        let groups = conversationManager.groupedConversations
        if debouncedSearchText.isEmpty { return groups }

        return groups.compactMap { group in
            let filtered = group.items.filter {
                $0.title.localizedCaseInsensitiveContains(debouncedSearchText) ||
                $0.preview.localizedCaseInsensitiveContains(debouncedSearchText)
            }
            return filtered.isEmpty ? nil : (group.group, filtered)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top area with padding for traffic lights
            VStack(spacing: 10) {
                // New conversation button
                Button {
                    withAnimation(Theme.Animation.smooth) {
                        _ = conversationManager.createConversation()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .medium))
                        Text("Nova conversa")
                            .font(Theme.Typography.bodySmall)
                    }
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Theme.Colors.glassSurface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall, style: .continuous)
                            .stroke(Theme.Colors.glassBorderSubtle, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .maePressEffect()
                .keyboardShortcut("n", modifiers: .command)
                .accessibilityLabel("Criar nova conversa")
                .accessibilityHint("Atalho: Comando N")

                // Search (show when >10 conversations)
                if conversationManager.conversations.count > 10 {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.Colors.textMuted)
                        TextField("Buscar...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(Theme.Typography.caption)
                            .accessibilityLabel("Buscar conversas")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.glassSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 38) // Space for traffic lights
            .padding(.bottom, 8)

            MaeDivider()

            // Conversation list
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    if filteredGroups.isEmpty {
                        // Empty state with CTA
                        VStack(spacing: 14) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 28, weight: .light))
                                .foregroundStyle(Theme.Colors.textMuted.opacity(0.3))

                            Text("Nenhuma conversa")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textMuted)

                            Button {
                                withAnimation(Theme.Animation.smooth) {
                                    _ = conversationManager.createConversation()
                                }
                            } label: {
                                Text("Criar primeira conversa")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.accentPrimary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Criar primeira conversa")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        ForEach(filteredGroups, id: \.group) { section in
                            // Section header
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Theme.Colors.accentPrimary.opacity(0.4))
                                    .frame(width: 3, height: 3)
                                Text(section.group.rawValue)
                                    .font(Theme.Typography.micro)
                                    .foregroundStyle(Theme.Colors.textMuted)
                                    .textCase(.uppercase)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .padding(.bottom, 4)
                            .accessibilityAddTraits(.isHeader)

                            // Conversation rows
                            ForEach(section.items) { conversation in
                                ConversationRow(
                                    conversation: conversation,
                                    isActive: conversation.id == conversationManager.activeConversationId,
                                    isHovered: hoveredConversationId == conversation.id,
                                    onSelect: {
                                        withAnimation(Theme.Animation.smooth) {
                                            conversationManager.selectConversation(id: conversation.id)
                                        }
                                    },
                                    onDelete: {
                                        conversationToDelete = conversation.id
                                    },
                                    onPin: {
                                        withAnimation(Theme.Animation.smooth) {
                                            conversationManager.togglePin(id: conversation.id)
                                        }
                                    }
                                )
                                .onHover { hovering in
                                    hoveredConversationId = hovering ? conversation.id : nil
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            MaeDivider()

            // Footer
            HStack(spacing: 8) {
                Button {
                    AdvancedSettingsWindowManager.shared.showWindow()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundStyle(settingsHovered ? Theme.Colors.textPrimary : Theme.Colors.textMuted)
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(settingsHovered ? Theme.Colors.glassSurface : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(Theme.Animation.hover) { settingsHovered = hovering }
                }
                .help("Configuracoes avancadas")
                .accessibilityLabel("Configuracoes avancadas")

                Spacer()

                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Colors.textMuted.opacity(0.4))
                    .accessibilityLabel("Versao do app")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background {
            GlassBackground(
                material: .sidebar,
                blendingMode: .withinWindow,
                overlayColor: Theme.Colors.glassSurfaceSecondary,
                cornerRadius: 0,
                borderColor: .clear,
                borderWidth: 0
            )
        }
        .onChange(of: searchText) { _, newValue in
            // Debounce search: wait 300ms before filtering
            let text = newValue
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                if searchText == text {
                    debouncedSearchText = text
                }
            }
        }
        .alert("Apagar conversa?", isPresented: Binding(
            get: { conversationToDelete != nil },
            set: { if !$0 { conversationToDelete = nil } }
        )) {
            Button("Cancelar", role: .cancel) {
                conversationToDelete = nil
            }
            Button("Apagar", role: .destructive) {
                if let id = conversationToDelete {
                    withAnimation(Theme.Animation.smooth) {
                        conversationManager.deleteConversation(id: id)
                    }
                }
                conversationToDelete = nil
            }
        } message: {
            Text("Esta acao nao pode ser desfeita.")
        }
    }
}

// MARK: - Conversation Row

private struct ConversationRow: View {
    let conversation: Conversation
    let isActive: Bool
    let isHovered: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onPin: () -> Void

    private var relativeTime: String {
        let interval = Date().timeIntervalSince(conversation.updatedAt)
        if interval < 60 { return "agora" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM"
        return formatter.string(from: conversation.updatedAt)
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        if conversation.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(Theme.Colors.accentPrimary.opacity(0.6))
                                .accessibilityHidden(true)
                        }
                        Text(conversation.title)
                            .font(isActive ? Theme.Typography.captionBold : Theme.Typography.bodySmall)
                            .foregroundStyle(isActive ? Theme.Colors.textPrimary : Theme.Colors.textPrimary.opacity(0.85))
                            .lineLimit(1)
                    }

                    Text(conversation.preview)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                if isHovered {
                    HStack(spacing: 2) {
                        Button(action: onPin) {
                            Image(systemName: conversation.isPinned ? "pin.slash" : "pin")
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.Colors.textMuted)
                                .frame(width: 20, height: 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(Theme.Colors.glassSurface)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(conversation.isPinned ? "Desafixar conversa" : "Fixar conversa")

                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.Colors.error.opacity(0.7))
                                .frame(width: 20, height: 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(Theme.Colors.error.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Apagar conversa")
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else {
                    Text(relativeTime)
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(Theme.Colors.textMuted.opacity(0.6))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isActive ? Theme.Colors.accentPrimary.opacity(0.12) : (isHovered ? Theme.Colors.glassSurface : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isActive ? Theme.Colors.accentPrimary.opacity(0.25) : Color.clear, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .animation(Theme.Animation.hover, value: isHovered)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(conversation.title). \(conversation.preview)")
        .accessibilityHint(isActive ? "Conversa ativa" : "Toque para selecionar")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

#Preview {
    SidebarView(
        conversationManager: ConversationManager.shared,
        showSidebar: .constant(true)
    )
    .frame(width: 220, height: 650)
}
