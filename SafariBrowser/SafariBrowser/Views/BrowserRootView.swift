import SwiftUI
import SafariBrowserCore
import SwiftData

struct BrowserRootView: View {
    @Environment(TabManager.self) private var tabManager
    @Environment(BrowserSettings.self) private var settings
    @Environment(UserscriptManager.self) private var userscriptManager
    @Environment(ChromeState.self) private var chromeState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var scenePhase

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
    @State private var contentBlockerReady = true

    private let sessionStore = SessionStore()

    var body: some View {
        ZStack {
            if sizeClass == .regular {
                BrowserSplitView(
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
                    showSitePermissions: $showSitePermissions
                )
            } else {
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
                    showSitePermissions: $showSitePermissions
                )
            }

            if sizeClass != .regular, tabManager.isTabGridVisible {
                TabGridView(webViewPool: webViewPool)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.92)),
                        removal: .opacity.combined(with: .scale(scale: 0.96))
                    ))
                    .zIndex(1)
            }
        }
        .animation(BrowserMotion.grid, value: tabManager.isTabGridVisible)
        .sheet(isPresented: $showSettings) { SettingsView(contentBlockerReady: contentBlockerReady).browserSheet() }
        .sheet(isPresented: $showBookmarks) { BookmarksView(onSelect: navigateTo).browserSheet() }
        .sheet(isPresented: $showHistory) { HistoryView(onSelect: navigateTo).browserSheet() }
        .sheet(isPresented: $showUserScripts) { UserScriptsView().browserSheet() }
        .sheet(isPresented: $showDownloads) { DownloadsView().browserSheet() }
        .sheet(isPresented: $showSitePermissions) { SitePermissionsView().browserSheet() }
        .onAppear {
            chromeState.isToolbarVisible = !settings.toolbarCollapsedByDefault
            setupServices()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                loadPendingShareURL()
            } else if phase == .background {
                sessionStore.save(tabManager)
                if settings.clearDataOnExit {
                    BrowsingDataClearer.clearOnExit()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)) { _ in
            mergeCloudBookmarks(into: modelContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: .userscriptsDidChange)) { _ in
            reloadWebConfigurations()
        }
        .onReceive(NotificationCenter.default.publisher(for: .reloadWebViewConfigurations)) { _ in
            reloadWebConfigurations()
        }
        .onChange(of: settings.searchEngine) { _, engine in urlResolver.searchEngine = engine }
        .onChange(of: settings.blockTrackers) { _, enabled in
            ContentBlockerService.shared.setEnabled(enabled)
            reloadWebConfigurations()
        }
        .onChange(of: settings.toolbarCollapsedByDefault) { _, collapsed in
            if !chromeState.isCreatingTab {
                chromeState.isToolbarVisible = !collapsed
            }
        }
        .onChange(of: tabManager.isPrivateMode) { _, isPrivate in
            webViewPool?.clearAll()
            if isPrivate {
                BrowsingDataClearer.clearWidgetData()
            }
        }
        .onOpenURL { url in handleIncomingURL(url) }
    }

    private func setupServices() {
        urlResolver.searchEngine = settings.searchEngine
        let factory = WebViewConfigurationFactory(userscriptManager: userscriptManager)
        webViewPool = WebViewPool(configFactory: factory)
        loadUserscriptsFromStore()
        mergeCloudBookmarks(into: modelContext)
        loadPendingShareURL()

        Task {
            do {
                try await ContentBlockerService.shared.compileRules()
                contentBlockerReady = true
            } catch {
                contentBlockerReady = false
            }
            ContentBlockerService.shared.setEnabled(settings.blockTrackers)
            await WebExtensionManager.shared.loadBundledExtensions()
            reloadWebConfigurations()
        }
    }

    private func reloadWebConfigurations() {
        webViewPool?.reloadAllConfigurations(for: tabManager.tabs)
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
        if tabManager.selectedTab == nil { tabManager.addTab() }
        tabManager.selectedTab?.url = url
        if let pool = webViewPool, let tab = tabManager.selectedTab {
            pool.webView(for: tab).load(URLRequest(url: url))
        }
    }

    private func handleIncomingURL(_ url: URL) {
        if url.scheme == "safaribrowser" {
            if url.host == "open",
               let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let query = components.queryItems?.first(where: { $0.name == "url" })?.value,
               let target = URL(string: query) {
                navigateTo(target)
            } else if url.host == "newtab" {
                tabManager.addTab()
            }
        } else if url.scheme?.hasPrefix("http") == true {
            navigateTo(url)
        }
    }

    private func loadPendingShareURL() {
        let defaults = AppGroupStorage.defaults
        if defaults.bool(forKey: AppGroupStorage.Key.pendingNewTab) {
            defaults.removeObject(forKey: AppGroupStorage.Key.pendingNewTab)
            tabManager.addTab()
        }
        guard let urlString = defaults.string(forKey: AppGroupStorage.Key.pendingShareURL),
              let url = URL(string: urlString) else { return }
        defaults.removeObject(forKey: AppGroupStorage.Key.pendingShareURL)
        navigateTo(url)
    }
}
