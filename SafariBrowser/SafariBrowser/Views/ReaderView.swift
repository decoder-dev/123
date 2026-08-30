import SwiftUI
import WebKit
import SafariBrowserCore

struct ReaderView: View {
    let article: ReaderArticle
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(article.title)
                        .font(.title.bold())
                    if let byline = article.byline, !byline.isEmpty {
                        Text(byline)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let source = article.sourceURL?.host {
                        Text(source)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Divider()
                    ReaderHTMLView(html: wrapHTML(article.contentHTML))
                        .frame(minHeight: 400)
                }
                .padding()
            }
            .navigationTitle("Reader")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func wrapHTML(_ body: String) -> String {
        """
        <!DOCTYPE html><html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        body { font-family: -apple-system, sans-serif; font-size: 18px; line-height: 1.6; padding: 0; margin: 0; color: #1a1a1a; }
        img { max-width: 100%; height: auto; }
        @media (prefers-color-scheme: dark) { body { color: #f0f0f0; } }
        </style></head><body>\(body)</body></html>
        """
    }
}

struct ReaderHTMLView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}
