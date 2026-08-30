import SwiftUI
import SafariBrowserCore
import SwiftData

struct BrowserRootView: View {
    @Environment(TabManager.self) private var tabManager
    @Environment(BrowserSettings.self) private var settings
    @Environment(UserscriptManager.self) private var userscriptManager
    @Environment(\.modelContext) private var modelContext

    @State private var webViewPool: WebViewPool?
    @State private var urlResolver = URLResolver()
    @State private var showSettings = false
    @State private var showBookmarks = false
    @State private var showHistory = false
    @State private var showUserScripts = false
    @State private var findInPageVisible = false
    @State private var findQuery = ""

    var body: some View {
        ZStack {
            BrowserContainerView(
                webViewPool: webViewPool,
                urlResolver: urlResolver,
                findInPageVisible: $findInPageVisible,
                findQuery: $findQuery
            )

            if tabManager.isTabGridVisible {
                TabGridView(webViewPool: webViewPool)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(1)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: tabManager.isTabGridVisible)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showBookmarks) {
            BookmarksView(onSelect: navigateTo)
        }
        .sheet(isPresented: $showHistory) {
            HistoryView(onSelect: navigateTo)
        }
        .sheet(isPresented: $showUserScripts) {
            UserScriptsView()
        }
        .onAppear {
            setupServices()
        }
        .onChange(of: settings.searchEngine) { _, newEngine in
            urlResolver.searchEngine = newEngine
        }
        .onChange(of: settings.blockTrackers) { _, enabled in
            ContentBlockerService.shared.setEnabled(enabled)
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                overflowMenu
            }
        }
    }

    private var overflowMenu: some View {
        Menu {
            Button { showBookmarks = true } label: {
                Label("Bookmarks", systemImage: "book")
            }
            Button { showHistory = true } label: {
                Label("History", systemImage: "clock")
            }
            Button { showUserScripts = true } label: {
                Label("Userscripts", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            Button { findInPageVisible.toggle() } label: {
                Label("Find in Page", systemImage: "magnifyingglass")
            }
            Divider()
            Button { showSettings = true } label: {
                Label("Settings", systemImage: "gear")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private func setupServices() {
        urlResolver.searchEngine = settings.searchEngine
        let factory = WebViewConfigurationFactory(userscriptManager: userscriptManager)
        webViewPool = WebViewPool(configFactory: factory)
        loadUserscriptsFromStore()
    }

    private func loadUserscriptsFromStore() {
        let descriptor = FetchDescriptor<StoredUserScript>()
        if let stored = try? modelContext.fetch(descriptor) {
            userscriptManager.scripts = stored.map { $0.toUserscript() }
        }
    }

    private func navigateTo(_ url: URL) {
        tabManager.selectedTab?.url = url
        if let pool = webViewPool, let tab = tabManager.selectedTab {
            pool.webView(for: tab).load(URLRequest(url: url))
        }
    }
}
