import SwiftUI

struct ChatBubble: View {
    let message: ChatMessage
    var animationIndex: Int = 0
    @State private var isHovered = false
    @State private var showCopied = false

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: message.timestamp)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isUser { Spacer(minLength: 50) }

            // Assistant accent bar + avatar
            if !message.isUser {
                VStack(spacing: 0) {
                    Image("hat-svgrepo-com")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(Theme.Colors.accent.opacity(0.5))
                        .padding(6)
                        .background(Theme.Colors.surfaceSecondary)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Theme.Colors.border, lineWidth: 0.5))
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Theme.Colors.accentBlue.opacity(0.25))
                        .frame(width: 2)
                        .padding(.top, 4)
                }
                .padding(.top, 2)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                // Screen analysis badge
                if message.source == .screenAnalysis && message.isUser {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 10))
                            .symbolEffect(.pulse)
                        Text("Análise de Tela")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Theme.Colors.accentBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .glassEffect(.regular.tint(Theme.Colors.accentBlue.opacity(0.12)), in: Capsule())
                }

                // Attachments
                if let attachments = message.attachments {
                    ForEach(attachments) { attachment in
                        if attachment.isImage, let img = attachment.image {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Theme.Colors.border, lineWidth: 0.5)
                                )
                                .maeSoftShadow()
                        } else if !attachment.isImage {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.Colors.accentBlue.opacity(0.8))
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
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Theme.Colors.border, lineWidth: 0.5)
                            )
                            .maeSoftShadow()
                    }
                }

                // Message content
                if !message.content.isEmpty {
                    ZStack(alignment: message.isUser ? .bottomTrailing : .bottomTrailing) {
                        if message.isUser {
                            Text(.init(message.content))
                                .font(Theme.Typography.bodySmall)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .textSelection(.enabled)
                                .glassEffect(.regular.tint(Theme.Colors.accentBlue.opacity(0.10)),
                                             in: UnevenRoundedRectangle(
                                                topLeadingRadius: 16,
                                                bottomLeadingRadius: 16,
                                                bottomTrailingRadius: 6,
                                                topTrailingRadius: 16,
                                                style: .continuous
                                             ))
                        } else {
                            HatMarkdownView(markdown: message.content)
                                .font(Theme.Typography.bodySmall)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Theme.Colors.surface)
                                }
                                .clipShape(
                                    UnevenRoundedRectangle(
                                        topLeadingRadius: 6,
                                        bottomLeadingRadius: 16,
                                        bottomTrailingRadius: 16,
                                        topTrailingRadius: 16,
                                        style: .continuous
                                    )
                                )
                                .overlay(
                                    UnevenRoundedRectangle(
                                        topLeadingRadius: 6,
                                        bottomLeadingRadius: 16,
                                        bottomTrailingRadius: 16,
                                        topTrailingRadius: 16,
                                        style: .continuous
                                    )
                                    .stroke(Theme.Colors.border, lineWidth: 0.5)
                                )
                                .maeSoftShadow()
                        }

                        // Copy button on hover
                        if isHovered && !message.content.isEmpty {
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(message.content, forType: .string)
                                withAnimation(Theme.Animation.snappy) { showCopied = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation(Theme.Animation.smooth) { showCopied = false }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 10, weight: .medium))
                                    if showCopied {
                                        Text("Copiado")
                                            .font(.system(size: 9, weight: .medium, design: .rounded))
                                    }
                                }
                                .foregroundStyle(showCopied ? Theme.Colors.success : Theme.Colors.textSecondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .offset(x: message.isUser ? -8 : -8, y: -8)
                            .transition(.maeScaleFade)
                        }
                    }
                }

                // Timestamp row
                HStack(spacing: 4) {
                    Text(timeString)
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundStyle(Theme.Colors.textMuted.opacity(isHovered ? 0.8 : 0.5))
                }
                .padding(.horizontal, 4)
                .animation(Theme.Animation.hover, value: isHovered)
            }

            if !message.isUser { Spacer(minLength: 50) }
        }
        .padding(.horizontal, Theme.Metrics.spacingDefault)
        .padding(.vertical, 4)
        .onHover { hovering in
            withAnimation(Theme.Animation.hover) { isHovered = hovering }
        }
        .maeStaggered(index: animationIndex, baseDelay: 0.05)
    }
}
