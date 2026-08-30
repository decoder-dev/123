import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var onSelect: (URL) -> Void

    @State private var entries: [HistoryEntry] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(entries, id: \.id) { entry in
                    Button {
                        if let url = entry.url {
                            onSelect(url)
                            dismiss()
                        }
                    } label: {
                        VStack(alignment: .leading) {
                            Text(entry.title)
                                .font(.body)
                            HStack {
                                Text(entry.urlString)
                                Spacer()
                                Text(entry.visitedAt, style: .relative)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                }
            }
            .onAppear { reload() }
        }
    }

    private func reload() {
        entries = HistoryStore(modelContext: modelContext).fetchAll()
    }
}
