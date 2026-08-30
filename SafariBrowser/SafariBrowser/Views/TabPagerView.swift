import SwiftUI
import SafariBrowserCore
import SwiftData

struct TabPagerView: View {
    let webViewPool: WebViewPool
    let urlResolver: URLResolver

    @Environment(TabManager.self) private var tabManager
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView(selection: Binding(
            get: { tabManager.selectedIndex },
            set: { tabManager.selectTab(at: $0) }
        )) {
            ForEach(Array(tabManager.tabs.enumerated()), id: \.element.id) { index, tab in
                BrowserWebView(
                    tab: tab,
                    webViewPool: webViewPool,
                    onNavigationComplete: { url, title in
                        recordHistory(url: url, title: title)
                    }
                )
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .overlay(alignment: .top) {
            if let tab = tabManager.selectedTab, tab.isLoading {
                ProgressView(value: tab.estimatedProgress)
                    .progressViewStyle(.linear)
                    .animation(.easeInOut, value: tab.estimatedProgress)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < -80,
                       tabManager.selectedIndex == tabManager.tabs.count - 1 {
                        tabManager.addTab()
                    }
                }
        )
    }

    private func recordHistory(url: URL?, title: String) {
        guard let url, url.scheme?.hasPrefix("http") == true else { return }
        let store = HistoryStore(modelContext: modelContext)
        store.record(title: title.isEmpty ? url.host ?? url.absoluteString : title, url: url)
    }
}
