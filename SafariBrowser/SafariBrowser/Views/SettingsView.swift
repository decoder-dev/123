import SwiftUI
import SafariBrowserCore
import WebKit

struct SettingsView: View {
    @Environment(BrowserSettings.self) private var settings
    @Environment(TabManager.self) private var tabManager
    @Environment(\.dismiss) private var dismiss

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
                    Toggle("Clear Data on Exit", isOn: $settings.clearDataOnExit)
                    Button("Clear All Browsing Data", role: .destructive) {
                        clearBrowsingData()
                    }
                }

                Section("Browsing") {
                    Toggle("Private Mode", isOn: Binding(
                        get: { tabManager.isPrivateMode },
                        set: { _ in tabManager.togglePrivateMode() }
                    ))
                }

                Section("Sync") {
                    LabeledContent("iCloud Bookmarks") {
                        Text(CloudSyncService.shared.isAvailable ? "Available" : "Unavailable")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Extensions") {
                    if WebExtensionManager.shared.isLoaded {
                        ForEach(WebExtensionManager.shared.loadedExtensionNames, id: \.self) { name in
                            Label(name, systemImage: "puzzlepiece.extension")
                        }
                    } else {
                        Text("Place .webextension bundles in the Extensions/ folder.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Default Browser") {
                    Text("To set SafariBrowser as default, go to Settings → Apps → Default Browser and select SafariBrowser.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Engine", value: "WebKit (WKWebView)")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func clearBrowsingData() {
        let dataStore = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        dataStore.fetchDataRecords(ofTypes: types) { records in
            dataStore.removeData(ofTypes: types, for: records) {}
        }
    }
}
