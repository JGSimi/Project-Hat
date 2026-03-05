import SwiftUI

struct ChatBubble: View {
    let message: ChatMessage
    var animationIndex: Int = 0

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 24) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                if message.source == .screenAnalysis && message.isUser {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.viewfinder")
                            .font(Theme.Typography.caption)
                            .symbolEffect(.pulse)
                        Text("Análise de Tela")
                            .font(Theme.Typography.caption)
                    }
                    .foregroundStyle(Theme.Colors.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Theme.Colors.accentSubtle)
                    .clipShape(Capsule())
                }

                if let attachments = message.attachments {
                    ForEach(attachments) { attachment in
                        if attachment.isImage, let img = attachment.image {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 250)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusMedium, style: .continuous))
                                .maeMediumShadow()
                        } else if !attachment.isImage {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text.fill")
                                    .foregroundStyle(Theme.Colors.accent)
                                    .symbolEffect(.bounce, options: .nonRepeating)
                                Text(attachment.name)
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.Colors.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall))
                            .maeSoftShadow()
                        }
                    }
                }

                // Fallback for backward compatibility when only images are present.
                if message.attachments == nil, let images = message.images {
                    ForEach(images.indices, id: \.self) { index in
                        Image(nsImage: images[index])
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 250)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusMedium, style: .continuous))
                            .maeMediumShadow()
                    }
                }

                if !message.content.isEmpty {
                    if message.isUser {
                        Text(.init(message.content))
                            .font(Theme.Typography.bodySmall)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .maeGlassBackground(cornerRadius: Theme.Metrics.radiusMedium)
                            .maeSoftShadow()
                            .textSelection(.enabled)
                    } else {
                        HatMarkdownView(markdown: message.content)
                            .font(Theme.Typography.bodySmall)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .maeSurfaceBackground(cornerRadius: Theme.Metrics.radiusMedium)
                            .maeSoftShadow()
                    }
                }
            }
            .maeHover()

            if !message.isUser { Spacer(minLength: 24) }
        }
        .padding(.horizontal, Theme.Metrics.spacingDefault)
        .padding(.vertical, 4)
        .maeStaggered(index: animationIndex, baseDelay: 0.05)
    }
}
