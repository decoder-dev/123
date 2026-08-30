import Foundation
import WebKit

public struct BrowserDownload: Identifiable, Codable, Sendable {
    public let id: UUID
    public var filename: String
    public var urlString: String
    public var progress: Double
    public var isComplete: Bool
    public var localPath: String?
    public var createdAt: Date

    public init(id: UUID = UUID(), filename: String, url: URL) {
        self.id = id
        self.filename = filename
        self.urlString = url.absoluteString
        self.progress = 0
        self.isComplete = false
        self.createdAt = Date()
    }

    public var url: URL? { URL(string: urlString) }
}

@MainActor
@Observable
public final class DownloadManager: NSObject {
    public private(set) var downloads: [BrowserDownload] = []
    private var activeDownloads: [ObjectIdentifier: UUID] = [:]
    private var progressObservations: [ObjectIdentifier: NSKeyValueObservation] = [:]
    private let storageKey = "browser.downloads"

    public override init() {
        super.init()
        load()
    }

    public func startDownload(from url: URL, suggestedFilename: String? = nil) {
        var download = BrowserDownload(
            filename: suggestedFilename ?? url.lastPathComponent.isEmpty ? "download" : url.lastPathComponent,
            url: url
        )
        downloads.insert(download, at: 0)
        save()
        Task { await fetchDownload(downloadID: download.id, url: url) }
    }

    public func handleWKDownload(_ wkDownload: WKDownload, originalURL: URL) {
        let download = BrowserDownload(filename: originalURL.lastPathComponent, url: originalURL)
        downloads.insert(download, at: 0)
        let key = ObjectIdentifier(wkDownload)
        activeDownloads[key] = download.id
        wkDownload.delegate = self
        progressObservations[key] = wkDownload.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            Task { @MainActor in
                self?.updateWKProgress(for: wkDownload, fraction: progress.fractionCompleted)
            }
        }
        save()
    }

    private func updateWKProgress(for wkDownload: WKDownload, fraction: Double) {
        guard let entryID = activeDownloads[ObjectIdentifier(wkDownload)],
              let index = downloads.firstIndex(where: { $0.id == entryID }) else { return }
        downloads[index].progress = fraction
    }

    private func cleanupWKDownload(_ wkDownload: WKDownload) {
        let key = ObjectIdentifier(wkDownload)
        progressObservations.removeValue(forKey: key)?.invalidate()
        activeDownloads.removeValue(forKey: key)
    }

    public func remove(_ download: BrowserDownload) {
        downloads.removeAll { $0.id == download.id }
        save()
    }

    private func fetchDownload(downloadID: UUID, url: URL) async {
        do {
            let (tempURL, response) = try await URLSession.shared.download(from: url)
            guard let index = downloads.firstIndex(where: { $0.id == downloadID }) else { return }
            let filename = downloads[index].filename
            let dest = downloadsDirectory().appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tempURL, to: dest)
            downloads[index].progress = 1.0
            downloads[index].isComplete = true
            downloads[index].localPath = dest.path
            if let http = response as? HTTPURLResponse, !filename.contains(".") {
                let ext = http.mimeType.flatMap { mimeToExtension($0) }
                if let ext {
                    downloads[index].filename = "\(filename).\(ext)"
                }
            }
            save()
            HapticService.success()
        } catch {
            downloads.removeAll { $0.id == downloadID }
            save()
        }
    }

    private func downloadsDirectory() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func mimeToExtension(_ mime: String) -> String? {
        switch mime {
        case "application/pdf": return "pdf"
        case "image/png": return "png"
        case "image/jpeg": return "jpg"
        case "text/plain": return "txt"
        default: return nil
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([BrowserDownload].self, from: data) else { return }
        downloads = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(downloads) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

extension DownloadManager: WKDownloadDelegate {
    public func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let dest = downloadsDirectory().appendingPathComponent(suggestedFilename)
        if let entryID = activeDownloads[ObjectIdentifier(download)],
           let index = downloads.firstIndex(where: { $0.id == entryID }) {
            downloads[index].filename = suggestedFilename
            save()
        }
        completionHandler(dest)
    }

    public func downloadDidFinish(_ download: WKDownload) {
        if let entryID = activeDownloads[ObjectIdentifier(download)],
           let index = downloads.firstIndex(where: { $0.id == entryID }) {
            downloads[index].isComplete = true
            downloads[index].progress = 1.0
            downloads[index].localPath = downloadsDirectory().appendingPathComponent(downloads[index].filename).path
            save()
            HapticService.success()
        }
        cleanupWKDownload(download)
    }

    public func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        if let entryID = activeDownloads[ObjectIdentifier(download)] {
            downloads.removeAll { $0.id == entryID }
            save()
        }
        cleanupWKDownload(download)
    }
}
