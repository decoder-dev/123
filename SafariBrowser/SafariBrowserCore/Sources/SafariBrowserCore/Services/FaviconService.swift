import Foundation

@MainActor
public final class FaviconService {
    public static let shared = FaviconService()
    private var cache: [String: Data] = [:]

    private init() {}

    public func faviconURL(for pageURL: URL) -> URL? {
        guard let host = pageURL.host else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=64")
    }

    public func fetchFavicon(for pageURL: URL) async -> Data? {
        let key = pageURL.host ?? pageURL.absoluteString
        if let cached = cache[key] { return cached }
        guard let favURL = faviconURL(for: pageURL) else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: favURL)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            cache[key] = data
            return data
        } catch {
            return nil
        }
    }
}
