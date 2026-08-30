import Foundation

public struct SyncableBookmark: Codable, Sendable {
    public let id: UUID
    public let title: String
    public let urlString: String
    public let createdAt: Date

    public init(id: UUID, title: String, urlString: String, createdAt: Date) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.createdAt = createdAt
    }
}

@MainActor
public final class CloudSyncService {
    public static let shared = CloudSyncService()
    private let store = NSUbiquitousKeyValueStore.default
    private let bookmarksKey = "icloud.bookmarks"

    private init() {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.externalChangeHandler?() }
        }
        store.synchronize()
    }

    public var externalChangeHandler: (() -> Void)?

    public var isAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    public func pushBookmarks(_ bookmarks: [SyncableBookmark]) {
        guard isAvailable, let data = try? JSONEncoder().encode(bookmarks) else { return }
        store.set(data, forKey: bookmarksKey)
        store.synchronize()
    }

    public func pullBookmarks() -> [SyncableBookmark] {
        guard isAvailable,
              let data = store.data(forKey: bookmarksKey),
              let bookmarks = try? JSONDecoder().decode([SyncableBookmark].self, from: data) else { return [] }
        return bookmarks
    }
}
