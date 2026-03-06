import SwiftUI

struct ChatBubble: View {
    let message: ChatMessage
    var animationIndex: Int = 0

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: message.timestamp)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isUser { Spacer(minLength: 40) }

            // Assistant avatar
            if !message.isUser {
                Image("hat-svgrepo-com")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(Theme.Colors.accent.opacity(0.5))
                    .padding(6)
                    .background(Theme.Colors.surfaceSecondary)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Theme.Colors.border, lineWidth: 0.5)
                    )
                    .padding(.top, 2)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                if message.source == .screenAnalysis && message.isUser {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 10))
                            .symbolEffect(.pulse)
                        Text("Análise de Tela")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Theme.Colors.accent.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.Colors.accentSubtle.opacity(0.6))
                    .clipShape(Capsule())
                }

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
                                    .foregroundStyle(Theme.Colors.accent.opacity(0.7))
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

                // Fallback for backward compatibility when only images are present.
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

                if !message.content.isEmpty {
                    if message.isUser {
                        Text(.init(message.content))
                            .font(Theme.Typography.bodySmall)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .maeGlassBackground(cornerRadius: 14)
                            .maeSoftShadow()
                            .textSelection(.enabled)
                    } else {
                        HatMarkdownView(markdown: message.content)
                            .font(Theme.Typography.bodySmall)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .maeSurfaceBackground(cornerRadius: 14)
                            .maeSoftShadow()
                    }
                }

                // Timestamp
                Text(timeString)
                    .font(.system(size: 9, weight: .regular, design: .rounded))
                    .foregroundStyle(Theme.Colors.textMuted.opacity(0.6))
                    .padding(.horizontal, 4)
            }

            if !message.isUser { Spacer(minLength: 40) }
        }
        .padding(.horizontal, Theme.Metrics.spacingDefault)
        .padding(.vertical, 3)
        .maeStaggered(index: animationIndex, baseDelay: 0.05)
    }
}
