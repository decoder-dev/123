import SwiftUI
import SafariBrowserCore
import SwiftData
import WebKit

@main
struct SafariBrowserApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var tabManager = TabManager()
    @State private var settings = BrowserSettings()
    @State private var userscriptManager = UserscriptManager()
    @State private var sessionStore = SessionStore()
    @State private var chromeState = ChromeState()
    @State private var downloadManager = DownloadManager()

    var body: some Scene {
        WindowGroup {
            BrowserRootView()
                .environment(tabManager)
                .environment(settings)
                .environment(userscriptManager)
                .environment(chromeState)
                .environment(downloadManager)
                .task {
                    try? await ContentBlockerService.shared.compileRules()
                    ContentBlockerService.shared.setEnabled(settings.blockTrackers)
                    sessionStore.restore(into: tabManager)
                }
                .onChange(of: tabManager.tabs.count) { _, _ in
                    sessionStore.save(tabManager)
                }
                .onChange(of: tabManager.selectedTabID) { _, _ in
                    sessionStore.save(tabManager)
                }
        }
        .modelContainer(for: [Bookmark.self, HistoryEntry.self, StoredUserScript.self])
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                sessionStore.save(tabManager)
                if settings.clearDataOnExit {
                    clearPrivateData()
                }
            }
        }
    }

    private func clearPrivateData() {
        // modelContext not available here; WebKit + app group only on background exit
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: types) { records in
            WKWebsiteDataStore.default().removeData(ofTypes: types, for: records) {}
        }
        WKWebsiteDataStore.nonPersistent().fetchDataRecords(ofTypes: types) { records in
            WKWebsiteDataStore.nonPersistent().removeData(ofTypes: types, for: records) {}
        }
        BrowsingDataClearer.clearAppGroupData()
    }
}
