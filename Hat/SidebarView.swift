//
//  SidebarView.swift
//  Hat
//
//  Created by Claude on 27/03/26.
//

import SwiftUI

struct SidebarView: View {
    @ObservedObject var conversationManager: ConversationManager
    @Binding var showSidebar: Bool
    @State private var searchText = ""
    @State private var hoveredConversationId: UUID?

    private var filteredGroups: [(group: ConversationManager.ConversationGroup, items: [Conversation])] {
        let groups = conversationManager.groupedConversations
        if searchText.isEmpty { return groups }

        return groups.compactMap { group in
            let filtered = group.items.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.preview.localizedCaseInsensitiveContains(searchText)
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
                        conversationManager.createConversation()
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
                    .background(Theme.Colors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall, style: .continuous)
                            .stroke(Theme.Colors.border, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .maePressEffect()
                .keyboardShortcut("n", modifiers: .command)

                // Search (show when >10 conversations)
                if conversationManager.conversations.count > 10 {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.Colors.textMuted)
                        TextField("Buscar...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(Theme.Typography.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.inputBackground)
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
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 24))
                                .foregroundStyle(Theme.Colors.textMuted.opacity(0.4))
                            Text("Nenhuma conversa")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        ForEach(filteredGroups, id: \.group) { section in
                            // Section header
                            HStack {
                                Text(section.group.rawValue)
                                    .font(Theme.Typography.micro)
                                    .foregroundStyle(Theme.Colors.textMuted)
                                    .textCase(.uppercase)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .padding(.bottom, 4)

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
                                        withAnimation(Theme.Animation.smooth) {
                                            conversationManager.deleteConversation(id: conversation.id)
                                        }
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
                        .foregroundStyle(Theme.Colors.textMuted)
                }
                .buttonStyle(.plain)
                .help("Configuracoes avancadas")

                Spacer()

                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Colors.textMuted.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Color(Theme.Colors.surface).opacity(0.5))
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
                        }
                        Text(conversation.title)
                            .font(Theme.Typography.bodySmall)
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
                        }
                        .buttonStyle(.plain)

                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.Colors.error.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.opacity)
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
                    .fill(isActive ? Theme.Colors.accentPrimary.opacity(0.08) : (isHovered ? Theme.Colors.surfaceHover : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isActive ? Theme.Colors.accentPrimary.opacity(0.15) : Color.clear, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .animation(Theme.Animation.hover, value: isHovered)
    }
}

#Preview {
    SidebarView(
        conversationManager: ConversationManager.shared,
        showSidebar: .constant(true)
    )
    .frame(width: 220, height: 650)
}
