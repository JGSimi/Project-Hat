import SwiftUI
import MarkdownUI

// MARK: - Custom Hat Markdown Theme

private typealias AppTheme = Theme

extension MarkdownUI.Theme {
    static let hat = MarkdownUI.Theme()
        .text {
            ForegroundColor(AppTheme.Colors.textPrimary)
            FontSize(13)
        }
        .strong {
            FontWeight(.semibold)
        }
        .emphasis {
            FontStyle(.italic)
        }
        .link {
            ForegroundColor(AppTheme.Colors.accentOrange)
            UnderlineStyle(.single)
        }
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(20)
                    FontWeight(.bold)
                    ForegroundColor(AppTheme.Colors.textPrimary)
                }
                .markdownMargin(top: 16, bottom: 8)
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(17)
                    FontWeight(.semibold)
                    ForegroundColor(AppTheme.Colors.textPrimary)
                }
                .markdownMargin(top: 14, bottom: 6)
        }
        .heading3 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(15)
                    FontWeight(.semibold)
                    ForegroundColor(AppTheme.Colors.textPrimary)
                }
                .markdownMargin(top: 12, bottom: 4)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(12)
            ForegroundColor(AppTheme.Colors.accentOrange)
            BackgroundColor(AppTheme.Colors.surfaceSecondary)
        }
        .codeBlock { configuration in
            ScrollView(.horizontal, showsIndicators: false) {
                configuration.label
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(12)
                        ForegroundColor(AppTheme.Colors.textPrimary)
                    }
            }
            .padding(12)
            .background(AppTheme.Colors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.radiusSmall, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Metrics.radiusSmall, style: .continuous)
                    .stroke(AppTheme.Colors.border, lineWidth: 0.5)
            )
            .markdownMargin(top: 8, bottom: 8)
        }
        .blockquote { configuration in
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppTheme.Colors.accentOrange.opacity(0.5))
                    .frame(width: 3)
                configuration.label
                    .markdownTextStyle {
                        ForegroundColor(AppTheme.Colors.textSecondary)
                        FontStyle(.italic)
                    }
                    .padding(.leading, 10)
            }
            .markdownMargin(top: 6, bottom: 6)
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: 2, bottom: 2)
        }
        .paragraph { configuration in
            configuration.label
                .markdownMargin(top: 4, bottom: 4)
        }
        .thematicBreak {
            Divider()
                .overlay(AppTheme.Colors.border)
                .markdownMargin(top: 12, bottom: 12)
        }
}

// MARK: - View

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
                    .tint(AppTheme.Colors.accentOrange)
                    .textSelection(.enabled)
            }
        }
    }
}
