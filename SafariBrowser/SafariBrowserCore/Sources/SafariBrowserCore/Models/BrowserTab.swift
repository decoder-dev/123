import Foundation

@Observable
public final class BrowserTab: Identifiable, @unchecked Sendable {
    public let id: UUID
    public var url: URL?
    public var title: String
    public var isLoading: Bool
    public var canGoBack: Bool
    public var canGoForward: Bool
    public var estimatedProgress: Double
    public var isPrivate: Bool
    public var faviconURL: URL?
    public var faviconData: Data?
    public var previewImageData: Data?
    public var lastVisitedAt: Date

    public init(
        id: UUID = UUID(),
        url: URL? = nil,
        title: String = "New Tab",
        isPrivate: Bool = false
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.isLoading = false
        self.canGoBack = false
        self.canGoForward = false
        self.estimatedProgress = 0
        self.isPrivate = isPrivate
        self.lastVisitedAt = Date()
    }

    public var displayURL: String {
        url?.absoluteString ?? ""
    }

    public var displayTitle: String {
        title.isEmpty ? "New Tab" : title
    }
}

public struct TabSnapshot: Codable, Sendable {
    public let id: UUID
    public let url: URL?
    public let title: String
    public let isPrivate: Bool

    public init(from tab: BrowserTab) {
        id = tab.id
        url = tab.url
        title = tab.title
        isPrivate = tab.isPrivate
    }

    public func makeTab() -> BrowserTab {
        BrowserTab(id: id, url: url, title: title, isPrivate: isPrivate)
    }
}
