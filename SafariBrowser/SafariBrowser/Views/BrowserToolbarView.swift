import SwiftUI
import SafariBrowserCore
import WebKit

struct BrowserToolbarView: View {
    let webViewPool: WebViewPool?
    @Environment(TabManager.self) private var tabManager
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack {
            Button { goBack() } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!(tabManager.selectedTab?.canGoBack ?? false))

            Button { goForward() } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!(tabManager.selectedTab?.canGoForward ?? false))

            Spacer()

            Button { reload() } label: {
                Image(systemName: tabManager.selectedTab?.isLoading == true ? "xmark" : "arrow.clockwise")
            }

            Button { share() } label: {
                Image(systemName: "square.and.arrow.up")
            }

            Button { addBookmark() } label: {
                Image(systemName: "book")
            }

            Button {
                withAnimation { tabManager.isTabGridVisible.toggle() }
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "square.on.square")
                    Text("\(tabManager.tabs.count)")
                        .font(.system(size: 9, weight: .bold))
                        .padding(3)
                        .background(Color.accentColor, in: Circle())
                        .foregroundStyle(.white)
                        .offset(x: 6, y: -6)
                }
            }
        }
        .font(.body.weight(.medium))
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }

    private func currentWebView() -> WKWebView? {
        guard let pool = webViewPool, let tab = tabManager.selectedTab else { return nil }
        return pool.webView(for: tab)
    }

    private func goBack() { currentWebView()?.goBack() }
    private func goForward() { currentWebView()?.goForward() }

    private func reload() {
        guard let webView = currentWebView() else { return }
        if tabManager.selectedTab?.isLoading == true {
            webView.stopLoading()
        } else {
            webView.reload()
        }
    }

    private func share() {
        guard let url = tabManager.selectedTab?.url else { return }
        // Share sheet triggered via environment in production; placeholder for URL copy
        UIPasteboard.general.url = url
    }

    private func addBookmark() {
        guard let tab = tabManager.selectedTab, let url = tab.url else { return }
        let store = BookmarkStore(modelContext: modelContext)
        store.add(title: tab.displayTitle, url: url)
    }
}
