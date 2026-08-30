import Foundation

public enum SearchEngine: String, CaseIterable, Codable, Sendable, Identifiable {
    case google
    case duckDuckGo
    case bing
    case yandex

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .google: "Google"
        case .duckDuckGo: "DuckDuckGo"
        case .bing: "Bing"
        case .yandex: "Yandex"
        }
    }

    public func searchURL(for query: String) -> URL? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        switch self {
        case .google:
            return URL(string: "https://www.google.com/search?q=\(encoded)")
        case .duckDuckGo:
            return URL(string: "https://duckduckgo.com/?q=\(encoded)")
        case .bing:
            return URL(string: "https://www.bing.com/search?q=\(encoded)")
        case .yandex:
            return URL(string: "https://yandex.com/search/?text=\(encoded)")
        }
    }
}
