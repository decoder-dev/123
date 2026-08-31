import SwiftUI

struct BrowserOverflowMenu: View {
    @Binding var showSettings: Bool
    @Binding var showBookmarks: Bool
    @Binding var showHistory: Bool
    @Binding var showDownloads: Bool
    @Binding var showUserScripts: Bool
    @Binding var showSitePermissions: Bool
    @Binding var findInPageVisible: Bool
    var onReaderMode: (() -> Void)?
    var onAddBookmark: (() -> Void)?
    var canBookmark: Bool = true

    var body: some View {
        Menu {
            if let onAddBookmark, canBookmark {
                Button(action: onAddBookmark) {
                    Label("Add Bookmark", systemImage: "book")
                }
            }
            Button { showBookmarks = true } label: {
                Label("Bookmarks", systemImage: "book.closed")
            }
            Button { showHistory = true } label: {
                Label("History", systemImage: "clock")
            }
            if let onReaderMode {
                Button(action: onReaderMode) {
                    Label("Reader Mode", systemImage: "doc.plaintext")
                }
            }
            Button { findInPageVisible.toggle() } label: {
                Label("Find in Page", systemImage: "magnifyingglass")
            }
            Button { showDownloads = true } label: {
                Label("Downloads", systemImage: "arrow.down.circle")
            }
            Button { showUserScripts = true } label: {
                Label("Userscripts", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            Button { showSitePermissions = true } label: {
                Label("Site Permissions", systemImage: "lock.shield")
            }
            Divider()
            Button { showSettings = true } label: {
                Label("Settings", systemImage: "gear")
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: BrowserMetrics.iconButton, height: BrowserMetrics.iconButton)
                .foregroundStyle(BrowserTheme.ink)
        }
        .accessibilityLabel("More options")
    }
}
