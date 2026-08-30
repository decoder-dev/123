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
        HStack(spacing: 12) {
            TextField("Find in page", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit { findNext() }
                .onChange(of: query) { _, newValue in
                    find(query: newValue, backwards: false)
                }

            if matchCount > 0 {
                Text("\(matchCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Button(action: findPrevious) {
                Image(systemName: "chevron.up")
            }
            .accessibilityLabel("Previous match")

            Button(action: findNext) {
                Image(systemName: "chevron.down")
            }
            .accessibilityLabel("Next match")

            Button {
                isVisible = false
                query = ""
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("Close find bar")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .onAppear { isFocused = true }
    }

    private func webView() -> WKWebView? {
        guard let pool = webViewPool, let tab = tabManager.selectedTab else { return nil }
        return pool.webView(for: tab)
    }

    private func find(query: String, backwards: Bool) {
        guard !query.isEmpty, let webView = webView() else { return }
        let config = WKFindConfiguration()
        config.backwards = backwards
        webView.find(query, configuration: config) { result in
            Task { @MainActor in
                matchCount = result.matchFound ? max(1, matchCount) : 0
            }
        }
    }

    private func findNext() {
        find(query: query, backwards: false)
    }

    private func findPrevious() {
        find(query: query, backwards: true)
    }
}
