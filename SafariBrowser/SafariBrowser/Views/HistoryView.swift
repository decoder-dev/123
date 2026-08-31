import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var onSelect: (URL) -> Void

    @State private var entries: [HistoryEntry] = []

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    BrowserEmptyState(
                        icon: "clock",
                        title: "No History",
                        message: "Pages you visit will appear here."
                    )
                    .padding()
                } else {
                    List {
                        ForEach(entries, id: \.id) { entry in
                            Button {
                                if let url = entry.url {
                                    onSelect(url)
                                    dismiss()
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.title)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(BrowserTheme.ink)
                                    HStack {
                                        Text(entry.urlString)
                                        Spacer()
                                        Text(entry.visitedAt, style: .relative)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(BrowserTheme.muted)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Clear") {
                        HistoryStore(modelContext: modelContext).clearAll()
                        reload()
                    }
                    .disabled(entries.isEmpty)
                }
            }
            .onAppear { reload() }
        }
    }

    private func reload() {
        entries = HistoryStore(modelContext: modelContext).fetchAll()
    }
}
