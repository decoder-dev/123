import SwiftUI
import SafariBrowserCore
import SwiftData
import WidgetKit

struct TabPagerView: View {
    let webViewPool: WebViewPool
    let urlResolver: URLResolver
    let chromeState: ChromeState
    let downloadManager: DownloadManager
    var usePager: Bool = true

    @Environment(TabManager.self) private var tabManager
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if usePager {
                pagerContent
            } else if let tab = tabManager.selectedTab {
                singleTabView(tab)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let tab = tabManager.selectedTab, tab.isLoading {
                ProgressView(value: max(tab.estimatedProgress, 0.02))
                    .progressViewStyle(.linear)
                    .tint(BrowserTheme.accent(forPrivate: tab.isPrivate || tabManager.isPrivateMode))
                    .animation(.easeInOut(duration: 0.2), value: tab.estimatedProgress)
            }
        }
        .simultaneousGesture(newTabSwipeGesture)
    }

    private var pagerContent: some View {
        TabView(selection: Binding(
            get: { tabManager.selectedIndex },
            set: { newIndex in
                if newIndex != tabManager.selectedIndex { HapticService.tabSwitch() }
                tabManager.selectTab(at: newIndex)
            }
        )) {
            ForEach(Array(tabManager.tabs.enumerated()), id: \.element.id) { index, tab in
                singleTabView(tab).tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private func singleTabView(_ tab: BrowserTab) -> some View {
        ZStack {
            if tab.url == nil {
                StartPageView(isPrivate: tab.isPrivate || tabManager.isPrivateMode)
            }
            BrowserWebView(
                tab: tab,
                webViewPool: webViewPool,
                chromeState: chromeState,
                downloadManager: downloadManager,
                onNavigationComplete: { url, title in recordHistory(url: url, title: title) }
            )
            .opacity(tab.url == nil ? 0 : 1)
        }
    }

    private var newTabSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 60)
            .onEnded { value in
                guard usePager else { return }
                let isLastTab = tabManager.selectedIndex == tabManager.tabs.count - 1
                if value.translation.width < -100, isLastTab {
                    chromeState.triggerNewTabAnimation()
                    tabManager.addTab()
                }
            }
    }

    private func recordHistory(url: URL?, title: String) {
        guard let tab = tabManager.selectedTab, !tab.isPrivate else { return }
        guard let url, url.scheme?.hasPrefix("http") == true else { return }
        let store = HistoryStore(modelContext: modelContext)
        store.record(title: title.isEmpty ? url.host ?? url.absoluteString : title, url: url)
        updateWidgetData(title: title, url: url)
    }

    private func updateWidgetData(title: String, url: URL) {
        let defaults = AppGroupStorage.defaults
        defaults.set(title.isEmpty ? url.host ?? "Page" : title, forKey: AppGroupStorage.Key.widgetLastTitle)
        defaults.set(url.absoluteString, forKey: AppGroupStorage.Key.widgetLastURL)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
