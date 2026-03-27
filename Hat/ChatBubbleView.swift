import SwiftUI

struct ChatBubble: View {
    let message: ChatMessage
    var animationIndex: Int = 0
    var isGrouped: Bool = false
    @State private var isHovered = false
    @State private var showCopied = false

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: message.timestamp)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.isUser { Spacer(minLength: 60) }

            // Assistant avatar
            if !message.isUser {
                if isGrouped {
                    Color.clear.frame(width: 30, height: 30)
                } else {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.surfaceSecondary)
                            .frame(width: 30, height: 30)
                        Image("hat-svgrepo-com")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(Theme.Colors.accentPrimary.opacity(0.7))
                    }
                    .padding(.top, 2)
                    .accessibilityHidden(true)
                }
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                // Screen analysis badge
                if message.source == .screenAnalysis && message.isUser {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 10))
                            .symbolEffect(.pulse)
                        Text("Analise de Tela")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(Theme.Colors.accentPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background { (Theme.Colors.accentPrimary.opacity(0.08) as Color) }
                    .clipShape(Capsule())
                }

                // Attachments
                if let attachments = message.attachments {
                    ForEach(attachments) { attachment in
                        if attachment.isImage, let img = attachment.image {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Theme.Colors.border, lineWidth: 0.5)
                                )
                        } else if !attachment.isImage {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.Colors.accentPrimary.opacity(0.7))
                                Text(attachment.name)
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.Colors.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall, style: .continuous)
                                    .stroke(Theme.Colors.border, lineWidth: 0.5)
                            )
                        }
                    }
                }

                // Backward compatibility for images
                if message.attachments == nil, let images = message.images {
                    ForEach(images.indices, id: \.self) { index in
                        Image(nsImage: images[index])
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Theme.Colors.border, lineWidth: 0.5)
                            )
                    }
                }

                // Message content
                if !message.content.isEmpty {
                    VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                        if message.isUser {
                            // User: subtle accent bubble
                            Text(.init(message.content))
                                .font(Theme.Typography.bodySmall)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .textSelection(.enabled)
                                .background { (Theme.Colors.accentPrimary.opacity(0.08) as Color) }
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Theme.Colors.accentPrimary.opacity(0.1), lineWidth: 0.5)
                                )
                        } else {
                            // AI: no bubble, direct markdown text (Claude.ai style)
                            HatMarkdownView(markdown: message.content)
                                .font(Theme.Typography.bodySmall)
                                .padding(.vertical, 4)
                        }

                        // Copy button + timestamp — appear on hover
                        if isHovered && !message.content.isEmpty {
                            HStack(spacing: 6) {
                                Text(timeString)
                                    .font(.system(size: 9, weight: .regular))
                                    .foregroundStyle(Theme.Colors.textMuted.opacity(0.6))

                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(message.content, forType: .string)
                                    withAnimation(Theme.Animation.snappy) { showCopied = true }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        withAnimation(Theme.Animation.smooth) { showCopied = false }
                                    }
                                } label: {
                                    HStack(spacing: 3) {
                                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                            .font(.system(size: 9, weight: .medium))
                                        if showCopied {
                                            Text("Copiado")
                                                .font(.system(size: 9, weight: .medium))
                                        }
                                    }
                                    .foregroundStyle(showCopied ? Theme.Colors.success : Theme.Colors.textMuted)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Theme.Colors.surfaceSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(Theme.Colors.border, lineWidth: 0.5))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(showCopied ? "Copiado" : "Copiar mensagem")
                            }
                            .transition(.opacity.combined(with: .offset(y: 2)))
                        }
                    }
                }
            }

            if !message.isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, Theme.Metrics.spacingDefault)
        .padding(.vertical, isGrouped ? 3 : 8)
        .onHover { hovering in
            withAnimation(Theme.Animation.hover) { isHovered = hovering }
        }
        .maeStaggered(index: animationIndex, baseDelay: 0.05)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.isUser ? "Voce" : "Hat"): \(message.content)")
    }
}
