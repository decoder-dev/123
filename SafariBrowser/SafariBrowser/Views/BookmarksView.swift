import SwiftUI
import SafariBrowserCore

struct BookmarksView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var onSelect: (URL) -> Void

    @State private var bookmarks: [Bookmark] = []

    var body: some View {
        NavigationStack {
            Group {
                if bookmarks.isEmpty {
                    BrowserEmptyState(
                        icon: "book.closed",
                        title: "No Bookmarks",
                        message: "Save pages with the bookmark action in the toolbar menu."
                    )
                    .padding()
                } else {
                    List {
                        ForEach(bookmarks, id: \.id) { bookmark in
                            Button {
                                if let url = bookmark.url {
                                    onSelect(url)
                                    dismiss()
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bookmark.title)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(BrowserTheme.ink)
                                    Text(bookmark.urlString)
                                        .font(.caption)
                                        .foregroundStyle(BrowserTheme.muted)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .onDelete(perform: deleteBookmarks)
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { reload() }
        }
    }

    private func reload() {
        bookmarks = BookmarkStore(modelContext: modelContext).fetchAll()
    }

    private func deleteBookmarks(at offsets: IndexSet) {
        let store = BookmarkStore(modelContext: modelContext)
        for index in offsets {
            store.remove(bookmarks[index])
        }
        reload()
        pushBookmarksToCloud()
    }

    private func pushBookmarksToCloud() {
        let store = BookmarkStore(modelContext: modelContext)
        let syncable = store.fetchAll().map {
            SyncableBookmark(id: $0.id, title: $0.title, urlString: $0.urlString, createdAt: $0.createdAt)
        }
        CloudSyncService.shared.pushBookmarks(syncable)
    }
}
