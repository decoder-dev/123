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
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isPrivate: Bool {
        tabManager.selectedTab?.isPrivate == true || tabManager.isPrivateMode
    }

    var body: some View {
        HStack(spacing: 0) {
            navGroup

            Spacer(minLength: BrowserSpacing.sm)

            reloadButton

            if sizeClass != .regular {
                Spacer(minLength: BrowserSpacing.sm)

                BrowserTabBadgeButton(
                    count: tabManager.tabs.count,
                    isPrivate: isPrivate
                ) {
                    withAnimation(BrowserMotion.grid) {
                        tabManager.isTabGridVisible.toggle()
                    }
                }

                Spacer(minLength: BrowserSpacing.sm)
            } else {
                Spacer(minLength: BrowserSpacing.sm)
            }

            shareButton

            BrowserOverflowMenu(
                showSettings: $showSettings,
                showBookmarks: $showBookmarks,
                showHistory: $showHistory,
                showDownloads: $showDownloads,
                showUserScripts: $showUserScripts,
                showSitePermissions: $showSitePermissions,
                findInPageVisible: $findInPageVisible,
                onReaderMode: onReaderMode,
                onAddBookmark: addBookmark,
                canBookmark: !isPrivate && tabManager.selectedTab?.url != nil
            )
        }
        .font(.system(size: 18, weight: .semibold))
        .padding(.horizontal, BrowserSpacing.sm)
        .padding(.vertical, 5)
        .browserGlass(
            radius: BrowserRadius.chrome,
            style: .interactive,
            tint: isPrivate ? BrowserTheme.privateAccent.opacity(0.08) : nil
        )
    }

    private var navGroup: some View {
        HStack(spacing: 2) {
            toolbarButton(
                "chevron.left",
                label: "Back",
                enabled: tabManager.selectedTab?.canGoBack ?? false,
                action: goBack
            )
            toolbarButton(
                "chevron.right",
                label: "Forward",
                enabled: tabManager.selectedTab?.canGoForward ?? false,
                action: goForward
            )
        }
    }

    private var reloadButton: some View {
        toolbarButton(
            tabManager.selectedTab?.isLoading == true ? "xmark" : "arrow.clockwise",
            label: tabManager.selectedTab?.isLoading == true ? "Stop" : "Reload",
            action: reload
        )
    }

    @ViewBuilder
    private var shareButton: some View {
        if let url = tabManager.selectedTab?.url, !isPrivate {
            ShareLink(item: url) {
                Image(systemName: "square.and.arrow.up")
                    .frame(width: BrowserMetrics.iconButton, height: BrowserMetrics.iconButton)
                    .foregroundStyle(BrowserTheme.ink)
            }
            .browserPressable()
            .accessibilityLabel("Share")
        }
    }

    private func toolbarButton(
        _ systemName: String,
        label: String,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(width: BrowserMetrics.iconButton, height: BrowserMetrics.iconButton)
        }
        .disabled(!enabled)
        .foregroundStyle(enabled ? BrowserTheme.ink : BrowserTheme.muted.opacity(0.4))
        .browserPressable()
        .accessibilityLabel(label)
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
