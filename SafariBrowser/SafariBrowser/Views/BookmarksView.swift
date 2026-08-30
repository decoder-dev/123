import SwiftUI

struct BookmarksView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var onSelect: (URL) -> Void

    @State private var bookmarks: [Bookmark] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(bookmarks, id: \.id) { bookmark in
                    Button {
                        if let url = bookmark.url {
                            onSelect(url)
                            dismiss()
                        }
                    } label: {
                        VStack(alignment: .leading) {
                            Text(bookmark.title)
                                .font(.body)
                            Text(bookmark.urlString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteBookmarks)
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
    }
}
