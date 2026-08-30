import SwiftUI
import SafariBrowserCore
import WebKit

struct BrowserToolbarView: View {
    let webViewPool: WebViewPool?
    @Binding var showSettings: Bool
    @Binding var showBookmarks: Bool
    @Binding var showHistory: Bool
    @Binding var showDownloads: Bool
    @Binding var showUserScripts: Bool
    @Binding var showSitePermissions: Bool
    @Binding var findInPageVisible: Bool
    var onReaderMode: () -> Void

    @Environment(TabManager.self) private var tabManager
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack {
            Button { goBack() } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!(tabManager.selectedTab?.canGoBack ?? false))
            .accessibilityLabel("Back")

            Button { goForward() } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!(tabManager.selectedTab?.canGoForward ?? false))
            .accessibilityLabel("Forward")

            Spacer()

            Button { reload() } label: {
                Image(systemName: tabManager.selectedTab?.isLoading == true ? "xmark" : "arrow.clockwise")
            }
            .accessibilityLabel(tabManager.selectedTab?.isLoading == true ? "Stop" : "Reload")

            Button { onReaderMode() } label: {
                Image(systemName: "doc.plaintext")
            }
            .accessibilityLabel("Reader mode")

            if let url = tabManager.selectedTab?.url {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share")
            }

            Button { addBookmark() } label: {
                Image(systemName: "book")
            }
            .disabled(tabManager.selectedTab?.isPrivate == true || tabManager.isPrivateMode)
            .accessibilityLabel("Add bookmark")

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
            .accessibilityLabel("Tabs, \(tabManager.tabs.count) open")

            BrowserOverflowMenu(
                showSettings: $showSettings,
                showBookmarks: $showBookmarks,
                showHistory: $showHistory,
                showDownloads: $showDownloads,
                showUserScripts: $showUserScripts,
                showSitePermissions: $showSitePermissions,
                findInPageVisible: $findInPageVisible
            )
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
        guard let tab = tabManager.selectedTab, let url = tab.url, !tab.isPrivate else { return }
        let store = BookmarkStore(modelContext: modelContext)
        store.add(title: tab.displayTitle, url: url)
        HapticService.success()
        let syncable = store.fetchAll().map {
            SyncableBookmark(id: $0.id, title: $0.title, urlString: $0.urlString, createdAt: $0.createdAt)
        }
        CloudSyncService.shared.pushBookmarks(syncable)
    }
}
