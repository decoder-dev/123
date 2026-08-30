import SwiftUI
import SafariBrowserCore

struct DownloadsView: View {
    @Environment(DownloadManager.self) private var downloadManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var downloadManager = downloadManager

        NavigationStack {
            Group {
                if downloadManager.downloads.isEmpty {
                    ContentUnavailableView(
                        "No Downloads",
                        systemImage: "arrow.down.circle",
                        description: Text("Files you download will appear here.")
                    )
                } else {
                    List {
                        ForEach(downloadManager.downloads) { download in
                            DownloadRow(download: download)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                downloadManager.remove(downloadManager.downloads[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("Downloads")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct DownloadRow: View {
    let download: BrowserDownload

    var body: some View {
        HStack {
            Image(systemName: download.isComplete ? "checkmark.circle.fill" : "arrow.down.circle")
                .foregroundStyle(download.isComplete ? .green : .accentColor)
            VStack(alignment: .leading) {
                Text(download.filename)
                    .lineLimit(1)
                if !download.isComplete {
                    ProgressView(value: download.progress)
                } else if download.isPrivate {
                    Text("Private download")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
