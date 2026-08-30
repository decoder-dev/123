import AppIntents

struct OpenURLIntent: AppIntent {
    static let title: LocalizedStringResource = "Open URL in SafariBrowser"
    static let description = IntentDescription("Opens a URL in SafariBrowser.")
    static let openAppWhenRun = true

    @Parameter(title: "URL")
    var url: URL

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$url) in SafariBrowser")
    }

    func perform() async throws -> some IntentResult {
        if let defaults = UserDefaults(suiteName: "group.com.safaribrowser.app") {
            defaults.set(url.absoluteString, forKey: "pendingShareURL")
        }
        return .result()
    }
}

struct NewTabIntent: AppIntent {
    static let title: LocalizedStringResource = "New Tab"
    static let description = IntentDescription("Opens a new tab in SafariBrowser.")
    static let openAppWhenRun = true

    @Parameter(title: "URL", default: URL(string: "about:blank")!)
    var url: URL

    func perform() async throws -> some IntentResult {
        if let defaults = UserDefaults(suiteName: "group.com.safaribrowser.app") {
            defaults.set(true, forKey: "pendingNewTab")
            if url.absoluteString != "about:blank" {
                defaults.set(url.absoluteString, forKey: "pendingShareURL")
            }
        }
        return .result()
    }
}

struct SafariBrowserShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NewTabIntent(),
            phrases: [
                "New tab in \(.applicationName)",
                "Open \(.applicationName)",
            ],
            shortTitle: "New Tab",
            systemImageName: "plus.square"
        )
        AppShortcut(
            intent: OpenURLIntent(),
            phrases: [
                "Open URL in \(.applicationName)",
                "Browse with \(.applicationName)",
            ],
            shortTitle: "Open URL",
            systemImageName: "globe"
        )
    }
}
