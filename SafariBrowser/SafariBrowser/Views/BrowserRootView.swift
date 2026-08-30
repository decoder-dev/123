import SwiftUI
import SafariBrowserCore
import SwiftData

struct BrowserRootView: View {
    @Environment(TabManager.self) private var tabManager
    @Environment(BrowserSettings.self) private var settings
    @Environment(UserscriptManager.self) private var userscriptManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var webViewPool: WebViewPool?
    @State private var urlResolver = URLResolver()
    @State private var showSettings = false
    @State private var showBookmarks = false
    @State private var showHistory = false
    @State private var showUserScripts = false
    @State private var showDownloads = false
    @State private var showSitePermissions = false
    @State private var findInPageVisible = false
    @State private var findQuery = ""
    @State private var readerArticle: ReaderArticle?

    var body: some View {
        ZStack {
            if sizeClass == .regular {
                BrowserSplitView(
                    webViewPool: webViewPool,
                    urlResolver: urlResolver,
                    findInPageVisible: $findInPageVisible,
                    findQuery: $findQuery,
                    readerArticle: $readerArticle
                )
            } else {
                BrowserContainerView(
                    webViewPool: webViewPool,
                    urlResolver: urlResolver,
                    findInPageVisible: $findInPageVisible,
                    findQuery: $findQuery,
                    readerArticle: $readerArticle
                )
            }

            if tabManager.isTabGridVisible, sizeClass != .regular {
                TabGridView(webViewPool: webViewPool)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(1)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: tabManager.isTabGridVisible)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showBookmarks) { BookmarksView(onSelect: navigateTo) }
        .sheet(isPresented: $showHistory) { HistoryView(onSelect: navigateTo) }
        .sheet(isPresented: $showUserScripts) { UserScriptsView() }
        .sheet(isPresented: $showDownloads) { DownloadsView() }
        .sheet(isPresented: $showSitePermissions) { SitePermissionsView() }
        .onAppear { setupServices() }
        .onReceive(NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)) { _ in
            mergeCloudBookmarks(into: modelContext)
        }
        .onChange(of: settings.searchEngine) { _, engine in urlResolver.searchEngine = engine }
        .onChange(of: settings.blockTrackers) { _, enabled in
            ContentBlockerService.shared.setEnabled(enabled)
        }
        .onOpenURL { url in handleIncomingURL(url) }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) { overflowMenu }
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
            Button { showDownloads = true } label: {
                Label("Downloads", systemImage: "arrow.down.circle")
            }
            Button { showUserScripts = true } label: {
                Label("Userscripts", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            Button { findInPageVisible.toggle() } label: {
                Label("Find in Page", systemImage: "magnifyingglass")
            }
            Button { showSitePermissions = true } label: {
                Label("Site Permissions", systemImage: "lock.shield")
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
        mergeCloudBookmarks(into: modelContext)
        Task { await WebExtensionManager.shared.loadBundledExtensions() }
        loadPendingShareURL()
    }

    private func loadUserscriptsFromStore() {
        let descriptor = FetchDescriptor<StoredUserScript>()
        if let stored = try? modelContext.fetch(descriptor) {
            userscriptManager.scripts = stored.map { $0.toUserscript() }
        }
    }

    private func mergeCloudBookmarks(into context: ModelContext) {
        let remote = CloudSyncService.shared.pullBookmarks()
        guard !remote.isEmpty else { return }
        let local = BookmarkStore(modelContext: context).fetchAll()
        let localIDs = Set(local.map(\.id))
        for item in remote where !localIDs.contains(item.id) {
            if let url = URL(string: item.urlString) {
                context.insert(Bookmark(id: item.id, title: item.title, url: url, createdAt: item.createdAt))
            }
        }
        try? context.save()
    }

    private func navigateTo(_ url: URL) {
        tabManager.selectedTab?.url = url
        if let pool = webViewPool, let tab = tabManager.selectedTab {
            pool.webView(for: tab).load(URLRequest(url: url))
        }
    }

    private func handleIncomingURL(_ url: URL) {
        if url.scheme == "safaribrowser", url.host == "open" {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let query = components.queryItems?.first(where: { $0.name == "url" })?.value,
               let target = URL(string: query) {
                navigateTo(target)
            }
        } else if url.scheme?.hasPrefix("http") == true {
            navigateTo(url)
        }
    }

    private func loadPendingShareURL() {
        guard let defaults = UserDefaults(suiteName: "group.com.safaribrowser.app"),
              let urlString = defaults.string(forKey: "pendingShareURL"),
              let url = URL(string: urlString) else { return }
        defaults.removeObject(forKey: "pendingShareURL")
        navigateTo(url)
    }
}
