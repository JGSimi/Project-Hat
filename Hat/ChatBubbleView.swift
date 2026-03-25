import SwiftUI

struct ChatBubble: View {
    let message: ChatMessage
    var animationIndex: Int = 0
    var isGrouped: Bool = false  // consecutive messages from same sender
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

            // Assistant avatar — hidden when grouped
            if !message.isUser {
                if isGrouped {
                    Color.clear.frame(width: 28, height: 28)
                } else {
                    ZStack {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Theme.Colors.gradientStart.opacity(0.2), Theme.Colors.gradientEnd.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                            .frame(width: 30, height: 30)
                        Image("hat-svgrepo-com")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundStyle(Theme.Colors.accentOrange.opacity(0.75))
                            .padding(5)
                            .background(Theme.Colors.surfaceSecondary)
                            .clipShape(Circle())
                    }
                    .padding(.top, 2)
                }
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
                    .foregroundStyle(Theme.Colors.accentOrange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.Colors.accentOrange.opacity(0.1))
                    .clipShape(Capsule())
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
                                    .foregroundStyle(Theme.Colors.accentOrange.opacity(0.8))
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
                    VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                        if message.isUser {
                            Text(.init(message.content))
                                .font(Theme.Typography.bodySmall)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .textSelection(.enabled)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Theme.Colors.accentOrange.opacity(0.07),
                                            Theme.Colors.accentSand.opacity(0.04)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18, bottomTrailingRadius: 8, topTrailingRadius: 18, style: .continuous))
                                .overlay(
                                    UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18, bottomTrailingRadius: 8, topTrailingRadius: 18, style: .continuous)
                                        .stroke(Theme.Colors.accentOrange.opacity(0.08), lineWidth: 0.5)
                                )
                        } else {
                            HatMarkdownView(markdown: message.content)
                                .font(Theme.Typography.bodySmall)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Theme.Colors.surface)
                                )
                                .clipShape(
                                    UnevenRoundedRectangle(
                                        topLeadingRadius: 8,
                                        bottomLeadingRadius: 18,
                                        bottomTrailingRadius: 18,
                                        topTrailingRadius: 18,
                                        style: .continuous
                                    )
                                )
                                .overlay(
                                    UnevenRoundedRectangle(
                                        topLeadingRadius: 8,
                                        bottomLeadingRadius: 18,
                                        bottomTrailingRadius: 18,
                                        topTrailingRadius: 18,
                                        style: .continuous
                                    )
                                    .stroke(Theme.Colors.border, lineWidth: 0.5)
                                )
                                .maeSoftShadow()
                        }

                        // Copy button + timestamp — appear on hover
                        if isHovered && !message.content.isEmpty {
                            HStack(spacing: 6) {
                                // Timestamp
                                Text(timeString)
                                    .font(.system(size: 9, weight: .regular, design: .rounded))
                                    .foregroundStyle(Theme.Colors.textMuted.opacity(0.6))

                                // Copy button
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
                                                .font(.system(size: 9, weight: .medium, design: .rounded))
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
                            }
                            .transition(.opacity.combined(with: .offset(y: 2)))
                        }
                    }
                }
            }

            if !message.isUser { Spacer(minLength: 50) }
        }
        .padding(.horizontal, Theme.Metrics.spacingDefault)
        .padding(.vertical, isGrouped ? 2 : 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovered ? Theme.Colors.accentOrange.opacity(0.015) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(Theme.Animation.hover) { isHovered = hovering }
        }
        .maeStaggered(index: animationIndex, baseDelay: 0.05)
    }
}
