import SwiftUI
import SafariBrowserCore
import SwiftData
import WebKit

struct SettingsView: View {
    var contentBlockerReady: Bool = true

    @Environment(BrowserSettings.self) private var settings
    @Environment(TabManager.self) private var tabManager
    @Environment(DownloadManager.self) private var downloadManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showPrivateModeConfirm = false
    @State private var pendingPrivateMode = false

    private let sessionStore = SessionStore()

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                Section("Search") {
                    Picker("Search Engine", selection: $settings.searchEngine) {
                        ForEach(SearchEngine.allCases) { engine in
                            Text(engine.displayName).tag(engine)
                        }
                    }
                }

                Section("Privacy") {
                    Toggle("Block Trackers & Ads", isOn: $settings.blockTrackers)
                    if !contentBlockerReady {
                        Label("Content blocking rules unavailable", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Toggle("Clear Web Cache on Exit", isOn: $settings.clearDataOnExit)
                    Button("Clear All Browsing Data", role: .destructive) {
                        clearBrowsingData()
                    }
                }

                Section("Browsing") {
                    Toggle("Private Mode", isOn: Binding(
                        get: { tabManager.isPrivateMode },
                        set: { newValue in
                            guard newValue != tabManager.isPrivateMode else { return }
                            pendingPrivateMode = newValue
                            showPrivateModeConfirm = true
                        }
                    ))
                    Toggle("Hide Toolbar by Default", isOn: $settings.toolbarCollapsedByDefault)
                }

                Section("Sync") {
                    LabeledContent("iCloud Bookmarks") {
                        Text(CloudSyncService.shared.isAvailable ? "Available" : "Unavailable")
                            .foregroundStyle(BrowserTheme.muted)
                    }
                }

                Section("Extensions") {
                    if WebExtensionManager.shared.isLoaded {
                        ForEach(WebExtensionManager.shared.loadedExtensionNames, id: \.self) { name in
                            Label(name, systemImage: "puzzlepiece.extension")
                        }
                    } else if #available(iOS 18.4, *) {
                        Text("Place .webextension bundles in the Extensions/ folder.")
                            .font(.caption)
                            .foregroundStyle(BrowserTheme.muted)
                    } else {
                        Text("Web extensions require iOS 18.4 or later.")
                            .font(.caption)
                            .foregroundStyle(BrowserTheme.muted)
                    }
                }

                Section("Default Browser") {
                    Text("Settings → Apps → Default Browser → SafariBrowser")
                        .font(.caption)
                        .foregroundStyle(BrowserTheme.muted)
                }

                Section("About") {
                    LabeledContent("Version", value: "\(appVersion) (\(buildNumber))")
                    LabeledContent("Engine", value: "WebKit")
                    LabeledContent("Minimum iOS", value: "18.0")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Switch browsing mode?",
                isPresented: $showPrivateModeConfirm,
                titleVisibility: .visible
            ) {
                Button(pendingPrivateMode ? "Enter Private Mode" : "Exit Private Mode") {
                    tabManager.togglePrivateMode()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This closes all open tabs.")
            }
        }
    }

    private func clearBrowsingData() {
        BrowsingDataClearer.clearAll(
            downloadManager: downloadManager,
            sessionStore: sessionStore,
            tabManager: tabManager,
            modelContext: modelContext
        )
    }
}
