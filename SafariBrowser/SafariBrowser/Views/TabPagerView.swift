import SwiftUI
import SafariBrowserCore
import SwiftData

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
        .overlay(alignment: .top) {
            if let tab = tabManager.selectedTab, tab.isLoading {
                ProgressView(value: tab.estimatedProgress)
                    .progressViewStyle(.linear)
                    .animation(.easeInOut, value: tab.estimatedProgress)
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
        BrowserWebView(
            tab: tab,
            webViewPool: webViewPool,
            chromeState: chromeState,
            downloadManager: downloadManager,
            onNavigationComplete: { url, title in recordHistory(url: url, title: title) }
        )
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
        guard let url, url.scheme?.hasPrefix("http") == true else { return }
        let store = HistoryStore(modelContext: modelContext)
        store.record(title: title.isEmpty ? url.host ?? url.absoluteString : title, url: url)
        updateWidgetData(title: title, url: url)
    }

    private func updateWidgetData(title: String, url: URL) {
        let defaults = UserDefaults(suiteName: "group.com.safaribrowser.app")
        defaults?.set(title.isEmpty ? url.host ?? "Page" : title, forKey: "widget.lastTitle")
        defaults?.set(url.absoluteString, forKey: "widget.lastURL")
    }
}
