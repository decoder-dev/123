import SwiftUI
import WebKit
import SafariBrowserCore

struct FindInPageBar: View {
    @Binding var query: String
    @Binding var isVisible: Bool
    let webViewPool: WebViewPool?
    @Environment(TabManager.self) private var tabManager
    @FocusState private var isFocused: Bool
    @State private var matchCount = 0

    var body: some View {
        HStack(spacing: BrowserSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrowserTheme.muted)

            TextField("Find in page", text: $query)
                .font(.subheadline)
                .focused($isFocused)
                .onSubmit { findNext() }
                .onChange(of: query) { _, newValue in
                    updateMatchCount(for: newValue)
                    find(query: newValue, backwards: false)
                }

            if matchCount > 0 {
                Text("\(matchCount)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(BrowserTheme.muted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(BrowserTheme.card.opacity(0.8), in: Capsule())
            }

            Button(action: findPrevious) {
                Image(systemName: "chevron.up")
                    .frame(width: 32, height: 32)
            }
            .browserPressable()
            .accessibilityLabel("Previous match")

            Button(action: findNext) {
                Image(systemName: "chevron.down")
                    .frame(width: 32, height: 32)
            }
            .browserPressable()
            .accessibilityLabel("Next match")

            Button(action: close) {
                Image(systemName: "xmark")
                    .frame(width: 32, height: 32)
            }
            .browserPressable()
            .accessibilityLabel("Close find bar")
        }
        .foregroundStyle(BrowserTheme.ink)
        .padding(.horizontal, BrowserSpacing.lg)
        .padding(.vertical, BrowserSpacing.sm)
        .browserGlass(radius: BrowserRadius.compact, style: .thin)
        .onAppear { isFocused = true }
        .onChange(of: isVisible) { _, visible in
            if !visible { clearHighlights() }
        }
    }

    private func webView() -> WKWebView? {
        guard let pool = webViewPool, let tab = tabManager.selectedTab else { return nil }
        return pool.webView(for: tab)
    }

    private func close() {
        clearHighlights()
        query = ""
        matchCount = 0
        isVisible = false
    }

    private func clearHighlights() {
        webView()?.find("", configuration: WKFindConfiguration()) { _ in }
    }

    private func updateMatchCount(for query: String) {
        guard !query.isEmpty, let webView = webView() else {
            matchCount = 0
            return
        }
        let escaped = query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let script = """
        (function(q) {
            if (!q) return 0;
            var text = document.body ? document.body.innerText : '';
            var re = new RegExp(q.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&'), 'gi');
            return (text.match(re) || []).length;
        })('\(escaped)');
        """
        webView.evaluateJavaScript(script) { result, _ in
            Task { @MainActor in
                matchCount = (result as? Int) ?? 0
            }
        }
    }

    private func find(query: String, backwards: Bool) {
        guard !query.isEmpty, let webView = webView() else { return }
        let config = WKFindConfiguration()
        config.backwards = backwards
        webView.find(query, configuration: config) { _ in }
    }

    private func findNext() {
        find(query: query, backwards: false)
    }

    private func findPrevious() {
        find(query: query, backwards: true)
    }
}
