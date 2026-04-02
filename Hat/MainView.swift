//
//  MainView.swift
//  Hat
//
//  Created by Claude on 27/03/26.
//

import SwiftUI
import Combine

struct MainView: View {
    @StateObject private var conversationManager = ConversationManager.shared
    @State private var showSidebar = true

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            if showSidebar {
                SidebarView(
                    conversationManager: conversationManager,
                    showSidebar: $showSidebar
                )
                .frame(width: 220)
                .transition(.move(edge: .leading).combined(with: .opacity))

                // Subtle divider
                Rectangle()
                    .fill(Theme.Colors.glassBorder)
                    .frame(width: 0.5)
            }

            // Chat panel
            ContentView(
                showSidebar: $showSidebar,
                conversationManager: conversationManager
            )
            .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
        }
        .background { MaePageBackground() }
        .animation(Theme.Animation.smooth, value: showSidebar)
    }
}

#Preview {
    MainView()
        .frame(width: 820, height: 650)
}
