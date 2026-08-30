import SwiftUI

struct BrowserOverflowMenu: View {
    @Binding var showSettings: Bool
    @Binding var showBookmarks: Bool
    @Binding var showHistory: Bool
    @Binding var showDownloads: Bool
    @Binding var showUserScripts: Bool
    @Binding var showSitePermissions: Bool
    @Binding var findInPageVisible: Bool

    var body: some View {
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
                .accessibilityLabel("More options")
        }
    }
}
