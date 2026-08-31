import Foundation
import SafariBrowserCore
import SwiftData
import WebKit
import WidgetKit

@MainActor
enum BrowsingDataClearer {
    static func clearAll(
        downloadManager: DownloadManager,
        sessionStore: SessionStore,
        tabManager: TabManager,
        modelContext: ModelContext
    ) {
        clearWebKitStores()
        HistoryStore(modelContext: modelContext).clearAll()
        downloadManager.clearAll()
        sessionStore.clear()
        clearSharedData()
        tabManager.resetToSingleTab()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Clears caches/cookies and shared keys when leaving the app (Settings → Clear Web Cache on Exit).
    static func clearOnExit() {
        clearWebKitStores()
        clearSharedData()
    }

    static func clearSharedData() {
        AppGroupStorage.clearSharedKeys()
    }

    static func clearWidgetData() {
        clearSharedData()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func clearWebKitStores() {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: types) { records in
            WKWebsiteDataStore.default().removeData(ofTypes: types, for: records) {}
        }
        WKWebsiteDataStore.nonPersistent().fetchDataRecords(ofTypes: types) { records in
            WKWebsiteDataStore.nonPersistent().removeData(ofTypes: types, for: records) {}
        }
    }
}

extension Notification.Name {
    static let userscriptsDidChange = Notification.Name("SafariBrowser.userscriptsDidChange")
    static let reloadWebViewConfigurations = Notification.Name("SafariBrowser.reloadWebViewConfigurations")
}
