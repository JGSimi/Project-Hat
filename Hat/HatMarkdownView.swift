import SwiftUI
import MarkdownUI

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
            FontFamily(.custom("SFMono-Regular", defaultFamilyName: .monospaced))
            FontSize(12)
            ForegroundColor(Theme.Colors.textPrimary)
            BackgroundColor(Theme.Colors.surfaceTertiary)
        }
        .codeBlock { configuration in
            configuration.label
                .markdownTextStyle {
                    FontFamily(.custom("SFMono-Regular", defaultFamilyName: .monospaced))
                    FontSize(12)
                    ForegroundColor(Theme.Colors.textPrimary)
                }
                .padding(12)
                .background(Theme.Colors.surfaceTertiary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall, style: .continuous)
                        .stroke(Theme.Colors.border, lineWidth: 0.5)
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
        Group {
            if trimmedMarkdown.isEmpty {
                Text("")
            } else {
                Markdown(markdown)
                    .markdownTheme(.hat)
                    .tint(Theme.Colors.accentPrimary)
                    .textSelection(.enabled)
            }
        }
    }
}
