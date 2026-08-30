import Foundation

public struct URLResolver: Sendable {
    public var searchEngine: SearchEngine

    public init(searchEngine: SearchEngine = .google) {
        self.searchEngine = searchEngine
    }

    /// Resolves user input into a navigable URL.
    /// Handles http/https, localhost, IPv6, ports, and falls back to search.
    public func resolve(_ input: String) -> URL {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return URL(string: "about:blank")!
        }

        if trimmed.hasPrefix("about:") || trimmed.hasPrefix("file:") {
            return URL(string: trimmed) ?? fallbackSearch(trimmed)
        }

        if looksLikeURL(trimmed) {
            let withScheme = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
            if let url = URL(string: withScheme), url.host != nil {
                return url
            }
        }

        return fallbackSearch(trimmed)
    }

    private func fallbackSearch(_ query: String) -> URL {
        searchEngine.searchURL(for: query) ?? URL(string: "https://www.google.com")!
    }

    private func looksLikeURL(_ input: String) -> Bool {
        if input.contains(" ") { return false }
        if input.contains(".") { return true }
        if input.hasPrefix("localhost") { return true }
        if input.hasPrefix("http://") || input.hasPrefix("https://") { return true }
        if input.contains(":") && !input.contains(" ") { return true }
        return false
    }
}
