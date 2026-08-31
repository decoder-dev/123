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
                    BrowserEmptyState(
                        icon: "arrow.down.circle",
                        title: "No Downloads",
                        message: "Files you download will appear here."
                    )
                    .padding()
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
        HStack(spacing: BrowserSpacing.md) {
            Image(systemName: rowIcon)
                .foregroundStyle(rowColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(download.filename)
                    .lineLimit(1)
                    .font(.body.weight(.medium))
                if let error = download.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(BrowserTheme.destructive)
                        .lineLimit(2)
                } else if !download.isComplete {
                    ProgressView(value: download.progress)
                        .tint(BrowserTheme.accent)
                } else if download.isPrivate {
                    Text("Private download")
                        .font(.caption2)
                        .foregroundStyle(BrowserTheme.muted)
                }
            }
            Spacer(minLength: 0)
            if download.isComplete, let url = localFileURL {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                }
                .foregroundStyle(BrowserTheme.accent)
            }
        }
        .padding(.vertical, 2)
    }

    private var rowIcon: String {
        if download.errorMessage != nil { return "exclamationmark.circle.fill" }
        return download.isComplete ? "checkmark.circle.fill" : "arrow.down.circle"
    }

    private var rowColor: Color {
        if download.errorMessage != nil { return BrowserTheme.destructive }
        return download.isComplete ? BrowserTheme.secure : BrowserTheme.accent
    }

    private var localFileURL: URL? {
        guard let path = download.localPath else { return nil }
        return URL(fileURLWithPath: path)
    }
}
