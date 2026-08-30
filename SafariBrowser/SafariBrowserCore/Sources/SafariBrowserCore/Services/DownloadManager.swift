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
    public var isPrivate: Bool

    public init(id: UUID = UUID(), filename: String, url: URL, isPrivate: Bool = false) {
        self.id = id
        self.filename = filename
        self.urlString = url.absoluteString
        self.progress = 0
        self.isComplete = false
        self.createdAt = Date()
        self.isPrivate = isPrivate
    }

    public var url: URL? { URL(string: urlString) }

    enum CodingKeys: String, CodingKey {
        case id, filename, urlString, progress, isComplete, localPath, createdAt, isPrivate
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        filename = try container.decode(String.self, forKey: .filename)
        urlString = try container.decode(String.self, forKey: .urlString)
        progress = try container.decode(Double.self, forKey: .progress)
        isComplete = try container.decode(Bool.self, forKey: .isComplete)
        localPath = try container.decodeIfPresent(String.self, forKey: .localPath)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isPrivate = try container.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
    }
}

@MainActor
@Observable
public final class DownloadManager: NSObject {
    private var persistedDownloads: [BrowserDownload] = []
    private var privateDownloads: [BrowserDownload] = []
    private var activeDownloads: [ObjectIdentifier: UUID] = [:]
    private var progressObservations: [ObjectIdentifier: NSKeyValueObservation] = [:]
    private let storageKey = "browser.downloads"

    public var downloads: [BrowserDownload] {
        (persistedDownloads + privateDownloads).sorted { $0.createdAt > $1.createdAt }
    }

    public override init() {
        super.init()
        load()
    }

    public func startDownload(from url: URL, suggestedFilename: String? = nil, isPrivate: Bool = false) {
        let download = BrowserDownload(
            filename: suggestedFilename ?? url.lastPathComponent.isEmpty ? "download" : url.lastPathComponent,
            url: url,
            isPrivate: isPrivate
        )
        insert(download)
        save()
        Task { await fetchDownload(downloadID: download.id, url: url, isPrivate: isPrivate) }
    }

    public func handleWKDownload(_ wkDownload: WKDownload, originalURL: URL, isPrivate: Bool = false) {
        let download = BrowserDownload(filename: originalURL.lastPathComponent, url: originalURL, isPrivate: isPrivate)
        insert(download)
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

    public func clearAll() {
        for download in downloads {
            if let path = download.localPath {
                try? FileManager.default.removeItem(atPath: path)
            }
        }
        persistedDownloads.removeAll()
        privateDownloads.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    public func remove(_ download: BrowserDownload) {
        if let path = download.localPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        if download.isPrivate {
            privateDownloads.removeAll { $0.id == download.id }
        } else {
            persistedDownloads.removeAll { $0.id == download.id }
            save()
        }
    }

    private func insert(_ download: BrowserDownload) {
        if download.isPrivate {
            privateDownloads.insert(download, at: 0)
        } else {
            persistedDownloads.insert(download, at: 0)
        }
    }

    private func index(of id: UUID) -> (array: String, index: Int)? {
        if let idx = privateDownloads.firstIndex(where: { $0.id == id }) {
            return ("private", idx)
        }
        if let idx = persistedDownloads.firstIndex(where: { $0.id == id }) {
            return ("persisted", idx)
        }
        return nil
    }

    private func updateDownload(id: UUID, _ block: (inout BrowserDownload) -> Void) {
        guard let loc = index(of: id) else { return }
        if loc.array == "private" {
            block(&privateDownloads[loc.index])
        } else {
            block(&persistedDownloads[loc.index])
            save()
        }
    }

    private func updateWKProgress(for wkDownload: WKDownload, fraction: Double) {
        guard let entryID = activeDownloads[ObjectIdentifier(wkDownload)] else { return }
        updateDownload(id: entryID) { $0.progress = fraction }
    }

    private func cleanupWKDownload(_ wkDownload: WKDownload) {
        let key = ObjectIdentifier(wkDownload)
        progressObservations.removeValue(forKey: key)?.invalidate()
        activeDownloads.removeValue(forKey: key)
    }

    private func fetchDownload(downloadID: UUID, url: URL, isPrivate: Bool) async {
        do {
            let (tempURL, response) = try await URLSession.shared.download(from: url)
            guard let loc = index(of: downloadID) else { return }
            var download = loc.array == "private" ? privateDownloads[loc.index] : persistedDownloads[loc.index]
            let dest = downloadsDirectory(isPrivate: isPrivate).appendingPathComponent(download.filename)
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tempURL, to: dest)
            download.progress = 1.0
            download.isComplete = true
            download.localPath = dest.path
            if let http = response as? HTTPURLResponse, !download.filename.contains(".") {
                let ext = http.mimeType.flatMap { mimeToExtension($0) }
                if let ext {
                    download.filename = "\(download.filename).\(ext)"
                }
            }
            if loc.array == "private" {
                privateDownloads[loc.index] = download
            } else {
                persistedDownloads[loc.index] = download
                save()
            }
            HapticService.success()
        } catch {
            removeByID(downloadID)
        }
    }

    private func removeByID(_ id: UUID) {
        privateDownloads.removeAll { $0.id == id }
        persistedDownloads.removeAll { $0.id == id }
        save()
    }

    private func downloadsDirectory(isPrivate: Bool) -> URL {
        let base: URL
        if isPrivate {
            base = FileManager.default.temporaryDirectory.appendingPathComponent("PrivateDownloads", isDirectory: true)
        } else {
            base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Downloads", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
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
        persistedDownloads = decoded.filter { !$0.isPrivate }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(persistedDownloads) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

extension DownloadManager: WKDownloadDelegate {
    public func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String
    ) async -> URL? {
        let isPrivate: Bool
        if let entryID = activeDownloads[ObjectIdentifier(download)], let loc = index(of: entryID) {
            isPrivate = loc.array == "private"
            updateDownload(id: entryID) { $0.filename = suggestedFilename }
        } else {
            isPrivate = false
        }
        return downloadsDirectory(isPrivate: isPrivate).appendingPathComponent(suggestedFilename)
    }

    public func downloadDidFinish(_ download: WKDownload) {
        if let entryID = activeDownloads[ObjectIdentifier(download)] {
            updateDownload(id: entryID) { item in
                item.isComplete = true
                item.progress = 1.0
                if item.localPath == nil {
                    item.localPath = downloadsDirectory(isPrivate: item.isPrivate)
                        .appendingPathComponent(item.filename).path
                }
            }
            HapticService.success()
        }
        cleanupWKDownload(download)
    }

    public func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        if let entryID = activeDownloads[ObjectIdentifier(download)] {
            removeByID(entryID)
        }
        cleanupWKDownload(download)
    }
}
