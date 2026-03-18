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
                    .markdownTheme(.basic)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .tint(Theme.Colors.accent)
                    .textSelection(.enabled)
            }
        }
    }
}
