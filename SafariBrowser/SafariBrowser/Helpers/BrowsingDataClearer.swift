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
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: types) { records in
            WKWebsiteDataStore.default().removeData(ofTypes: types, for: records) {}
        }
        WKWebsiteDataStore.nonPersistent().fetchDataRecords(ofTypes: types) { records in
            WKWebsiteDataStore.nonPersistent().removeData(ofTypes: types, for: records) {}
        }

        HistoryStore(modelContext: modelContext).clearAll()
        downloadManager.clearAll()
        sessionStore.clear()
        clearAppGroupData()

        tabManager.tabs.removeAll()
        tabManager.addTab()
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func clearAppGroupData() {
        guard let defaults = UserDefaults(suiteName: "group.com.safaribrowser.app") else { return }
        defaults.removeObject(forKey: "widget.lastTitle")
        defaults.removeObject(forKey: "widget.lastURL")
        defaults.removeObject(forKey: "pendingShareURL")
        defaults.removeObject(forKey: "pendingNewTab")
    }

    static func clearWidgetData() {
        clearAppGroupData()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
