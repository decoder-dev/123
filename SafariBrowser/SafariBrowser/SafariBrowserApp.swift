import SwiftUI
import SafariBrowserCore
import SwiftData

@main
struct SafariBrowserApp: App {
    @State private var tabManager = TabManager()
    @State private var settings = BrowserSettings()
    @State private var userscriptManager = UserscriptManager()
    @State private var sessionStore = SessionStore()

    var body: some Scene {
        WindowGroup {
            BrowserRootView()
                .environment(tabManager)
                .environment(settings)
                .environment(userscriptManager)
                .task {
                    await ContentBlockerService.shared.compileRules()
                    ContentBlockerService.shared.setEnabled(settings.blockTrackers)
                    sessionStore.restore(into: tabManager)
                }
                .onChange(of: tabManager.tabs.count) { _, _ in
                    sessionStore.save(tabManager)
                }
        }
        .modelContainer(for: [Bookmark.self, HistoryEntry.self, StoredUserScript.self])
    }
}
