import SwiftUI
import WebKit
import SafariBrowserCore

struct FindInPageBar: View {
    @Binding var query: String
    let webViewPool: WebViewPool?
    @Environment(TabManager.self) private var tabManager
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            TextField("Find in page", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit { findNext() }
                .onChange(of: query) { _, newValue in
                    find(query: newValue)
                }

            Button(action: findPrevious) {
                Image(systemName: "chevron.up")
            }
            Button(action: findNext) {
                Image(systemName: "chevron.down")
            }
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

    private func find(query: String) {
        guard !query.isEmpty else { return }
        webView()?.find(query) { _ in }
    }

    private func findNext() {
        webView()?.find(query) { _ in }
    }

    private func findPrevious() {
        webView()?.find(query, configuration: .init()) { _ in
            // WKFindConfiguration supports backward search on iOS 16+
        }
    }
}
