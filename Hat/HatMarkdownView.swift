import SwiftUI
import MarkdownUI

// MARK: - Code Block Copy Button View

private struct CodeBlockView: View {
    let code: String
    let language: String?
    let label: MarkdownUI.CodeBlockConfiguration.Label

    @State private var showCopied = false
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Header bar with language label and copy button
            HStack {
                if let language, !language.isEmpty {
                    Text(language.lowercased())
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.Colors.textMuted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 150, alignment: .leading)
                }

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    withAnimation(Theme.Animation.snappy) { showCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(Theme.Animation.smooth) { showCopied = false }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: .medium))
                        if showCopied {
                            Text("Copiado!")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .foregroundStyle(showCopied ? Theme.Colors.success : Theme.Colors.textMuted)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(isHovered ? Theme.Colors.surfaceElevated : Theme.Colors.surfaceSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(Theme.Colors.border, lineWidth: 0.5)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showCopied ? "Codigo copiado" : "Copiar codigo")
                .onHover { hovering in
                    withAnimation(Theme.Animation.hover) { isHovered = hovering }
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 28)

            // Divider between header and code
            Rectangle()
                .fill(Theme.Colors.border)
                .frame(height: 0.5)

            // Code content
            label
                .markdownTextStyle {
                    FontFamily(.custom("SFMono-Regular"))
                    FontSize(12)
                    ForegroundColor(Theme.Colors.textPrimary)
                }
                .padding(12)
        }
        .background(Theme.Colors.surfaceTertiary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall, style: .continuous)
                .stroke(Theme.Colors.border, lineWidth: 0.5)
        )
    }
}

// MARK: - Custom Hat Markdown Theme

extension MarkdownUI.Theme {
    static let hat = MarkdownUI.Theme()
        .text {
            ForegroundColor(Theme.Colors.textPrimary)
            FontSize(13)
        }
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(20)
                    ForegroundColor(Theme.Colors.textPrimary)
                }
                .markdownMargin(top: 16, bottom: 8)
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(17)
                    ForegroundColor(Theme.Colors.textPrimary)
                }
                .markdownMargin(top: 14, bottom: 6)
        }
        .heading3 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(15)
                    ForegroundColor(Theme.Colors.textPrimary)
                }
                .markdownMargin(top: 12, bottom: 4)
        }
        .code {
            FontFamily(.custom("SFMono-Regular"))
            FontSize(12)
            ForegroundColor(Theme.Colors.textPrimary)
            BackgroundColor(Theme.Colors.surfaceTertiary)
        }
        .codeBlock { configuration in
            CodeBlockView(
                code: configuration.content,
                language: configuration.language,
                label: configuration.label
            )
            .markdownMargin(top: 8, bottom: 8)
        }
        .blockquote { configuration in
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Theme.Colors.accentPrimary.opacity(0.4))
                    .frame(width: 2.5)
                configuration.label
                    .markdownTextStyle {
                        ForegroundColor(Theme.Colors.textSecondary)
                        FontSize(13)
                    }
                    .padding(.leading, 12)
            }
            .markdownMargin(top: 8, bottom: 8)
        }
        .link {
            ForegroundColor(Theme.Colors.accentPrimary)
        }
        .strong {
            FontWeight(.semibold)
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: 2, bottom: 2)
        }
        .thematicBreak {
            Divider()
                .overlay(Theme.Colors.border)
                .markdownMargin(top: 12, bottom: 12)
        }
        .table { configuration in
            configuration.label
                .markdownMargin(top: 8, bottom: 8)
        }
        .tableCell { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(12)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
        }
}

struct HatMarkdownView: View {
    let markdown: String

    private var trimmedMarkdown: String {
        markdown.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        if trimmedMarkdown.isEmpty {
            EmptyView()
        } else {
            Markdown(markdown)
                .markdownTheme(.hat)
                .tint(Theme.Colors.accentPrimary)
                .textSelection(.enabled)
        }
    }
}
