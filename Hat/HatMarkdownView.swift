import SwiftUI
import MarkdownUI

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
                    .markdownTheme(.hatGlass)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .tint(Theme.Colors.accentBlue)
                    .textSelection(.enabled)
            }
        }
    }
}

// MARK: - Glassmorphism Markdown Theme
extension MarkdownUI.Theme {
    static let hatGlass = MarkdownUI.Theme.basic
        .codeBlock { configuration in
            configuration.label
                .markdownTextStyle {
                    FontFamilyVariant(.monospaced)
                    FontSize(.em(0.88))
                }
                .padding(12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.88))
            BackgroundColor(Color(red: 1, green: 1, blue: 1, opacity: 0.08))
        }
}
