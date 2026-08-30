import Foundation
import SafariBrowserCore
import SwiftData

@Model
final class Bookmark {
    @Attribute(.unique) var id: UUID
    var title: String
    var urlString: String
    var createdAt: Date
    var folder: String?

    init(title: String, url: URL, folder: String? = nil) {
        self.id = UUID()
        self.title = title
        self.urlString = url.absoluteString
        self.createdAt = Date()
        self.folder = folder
    }

    var url: URL? { URL(string: urlString) }
}

@Model
final class HistoryEntry {
    @Attribute(.unique) var id: UUID
    var title: String
    var urlString: String
    var visitedAt: Date

    init(title: String, url: URL) {
        self.id = UUID()
        self.title = title
        self.urlString = url.absoluteString
        self.visitedAt = Date()
    }

    var url: URL? { URL(string: urlString) }
}

@Model
final class StoredUserScript {
    @Attribute(.unique) var id: UUID
    var name: String
    var source: String
    var matchPatternsData: Data
    var isEnabled: Bool
    var runAtRaw: String

    init(from script: Userscript) {
        self.id = script.id
        self.name = script.name
        self.source = script.source
        self.matchPatternsData = (try? JSONEncoder().encode(script.matchPatterns)) ?? Data()
        self.isEnabled = script.isEnabled
        self.runAtRaw = script.runAt.rawValue
    }

    func toUserscript() -> Userscript {
        let patterns = (try? JSONDecoder().decode([String].self, from: matchPatternsData)) ?? ["*://*/*"]
        return Userscript(
            id: id,
            name: name,
            source: source,
            matchPatterns: patterns,
            isEnabled: isEnabled,
            runAt: Userscript.RunAt(rawValue: runAtRaw) ?? .documentEnd
        )
    }
}
