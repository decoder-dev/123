import SwiftUI
import SafariBrowserCore

/// iPad split view: sidebar tab list + main browser content.
struct BrowserSplitView: View {
    let webViewPool: WebViewPool?
    let urlResolver: URLResolver
    @Binding var findInPageVisible: Bool
    @Binding var findQuery: String
    @Binding var readerArticle: ReaderArticle?
    @Binding var showSettings: Bool
    @Binding var showBookmarks: Bool
    @Binding var showHistory: Bool
    @Binding var showDownloads: Bool
    @Binding var showUserScripts: Bool
    @Binding var showSitePermissions: Bool

    @Environment(TabManager.self) private var tabManager
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: Binding(
                get: { tabManager.selectedTabID },
                set: { if let id = $0, let tab = tabManager.tabs.first(where: { $0.id == id }) {
                    tabManager.selectTab(tab)
                }}
            )) {
                Section("Tabs") {
                    ForEach(tabManager.tabs) { tab in
                        HStack {
                            if let data = tab.faviconData, let img = UIImage(data: data) {
                                Image(uiImage: img).resizable().frame(width: 16, height: 16)
                            } else {
                                Image(systemName: "globe")
                            }
                            Text(tab.displayTitle).lineLimit(1)
                        }
                        .tag(tab.id)
                        .swipeActions {
                            Button(role: .destructive) {
                                tabManager.closeTab(tab, webViewPool: webViewPool)
                            } label: {
                                Label("Close", systemImage: "xmark")
                            }
                        }
                    }
                }
            }
            .navigationTitle("SafariBrowser")
            .toolbar {
                ToolbarItem {
                    Button { tabManager.addTab() } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        } detail: {
            BrowserContainerView(
                webViewPool: webViewPool,
                urlResolver: urlResolver,
                findInPageVisible: $findInPageVisible,
                findQuery: $findQuery,
                readerArticle: $readerArticle,
                showSettings: $showSettings,
                showBookmarks: $showBookmarks,
                showHistory: $showHistory,
                showDownloads: $showDownloads,
                showUserScripts: $showUserScripts,
                showSitePermissions: $showSitePermissions,
                usePager: false
            )
        }
    }
}
