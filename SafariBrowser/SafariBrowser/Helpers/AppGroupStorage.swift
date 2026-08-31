import Foundation

/// Shared storage between app, extensions, and widget. Falls back to standard UserDefaults when the app group is unavailable (sideload builds).
enum AppGroupStorage {
    static let suiteName = "group.com.safaribrowser.app"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    enum Key {
        static let widgetLastTitle = "widget.lastTitle"
        static let widgetLastURL = "widget.lastURL"
        static let pendingShareURL = "pendingShareURL"
        static let pendingNewTab = "pendingNewTab"
    }

    static func clearSharedKeys() {
        let d = defaults
        d.removeObject(forKey: Key.widgetLastTitle)
        d.removeObject(forKey: Key.widgetLastURL)
        d.removeObject(forKey: Key.pendingShareURL)
        d.removeObject(forKey: Key.pendingNewTab)
    }
}
