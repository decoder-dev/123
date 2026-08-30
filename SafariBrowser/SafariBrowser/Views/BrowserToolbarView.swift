import SwiftUI
import SafariBrowserCore
import WebKit

struct BrowserToolbarView: View {
    let webViewPool: WebViewPool?
    var onReaderMode: () -> Void

    @Environment(TabManager.self) private var tabManager
    @Environment(\.modelContext) private var modelContext
    @State private var showShareSheet = false

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

            Button { onReaderMode() } label: {
                Image(systemName: "doc.plaintext")
            }

            if let url = tabManager.selectedTab?.url {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                }
            } else {
                Button { } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(true)
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

    private func addBookmark() {
        guard let tab = tabManager.selectedTab, let url = tab.url else { return }
        let store = BookmarkStore(modelContext: modelContext)
        store.add(title: tab.displayTitle, url: url)
        HapticService.success()
        syncBookmarksToCloud(store: store)
    }

    private func syncBookmarksToCloud(store: BookmarkStore) {
        let syncable = store.fetchAll().map {
            SyncableBookmark(id: $0.id, title: $0.title, urlString: $0.urlString, createdAt: $0.createdAt)
        }
        CloudSyncService.shared.pushBookmarks(syncable)
    }
}
