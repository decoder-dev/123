import Foundation
import SafariBrowserCore
import SwiftData
import SwiftUI

@Observable
@MainActor
final class BrowserSettings {
    var searchEngine: SearchEngine {
        didSet { UserDefaults.standard.set(searchEngine.rawValue, forKey: "searchEngine") }
    }
    var blockTrackers: Bool {
        didSet { UserDefaults.standard.set(blockTrackers, forKey: "blockTrackers") }
    }
    var clearDataOnExit: Bool {
        didSet { UserDefaults.standard.set(clearDataOnExit, forKey: "clearDataOnExit") }
    }
    var toolbarCollapsedByDefault: Bool {
        didSet { UserDefaults.standard.set(toolbarCollapsedByDefault, forKey: "toolbarCollapsed") }
    }

    init() {
        let engineRaw = UserDefaults.standard.string(forKey: "searchEngine") ?? SearchEngine.google.rawValue
        searchEngine = SearchEngine(rawValue: engineRaw) ?? .google
        blockTrackers = UserDefaults.standard.object(forKey: "blockTrackers") as? Bool ?? true
        clearDataOnExit = UserDefaults.standard.bool(forKey: "clearDataOnExit")
        toolbarCollapsedByDefault = UserDefaults.standard.bool(forKey: "toolbarCollapsed")
    }
}

@MainActor
final class SessionStore {
    private let tabsKey = "session.tabs"
    private let selectedKey = "session.selectedTab"

    func save(_ manager: TabManager) {
        let snapshots = manager.snapshots()
        if let data = try? JSONEncoder().encode(snapshots) {
            UserDefaults.standard.set(data, forKey: tabsKey)
        }
        if let id = manager.selectedTabID {
            UserDefaults.standard.set(id.uuidString, forKey: selectedKey)
        }
    }

    func restore(into manager: TabManager) {
        guard let data = UserDefaults.standard.data(forKey: tabsKey),
              let snapshots = try? JSONDecoder().decode([TabSnapshot].self, from: data),
              !snapshots.isEmpty else { return }
        let selectedID = UserDefaults.standard.string(forKey: selectedKey).flatMap(UUID.init)
        manager.restore(from: snapshots, selectedID: selectedID)
    }
}

@MainActor
final class HistoryStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func record(title: String, url: URL) {
        let entry = HistoryEntry(title: title, url: url)
        modelContext.insert(entry)
        try? modelContext.save()
    }

    func fetchAll() -> [HistoryEntry] {
        let descriptor = FetchDescriptor<HistoryEntry>(sortBy: [SortDescriptor(\.visitedAt, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func clearAll() {
        let entries = fetchAll()
        entries.forEach { modelContext.delete($0) }
        try? modelContext.save()
    }
}

@MainActor
final class BookmarkStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func add(title: String, url: URL) {
        let bookmark = Bookmark(title: title, url: url)
        modelContext.insert(bookmark)
        try? modelContext.save()
    }

    func fetchAll() -> [Bookmark] {
        let descriptor = FetchDescriptor<Bookmark>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func remove(_ bookmark: Bookmark) {
        modelContext.delete(bookmark)
        try? modelContext.save()
    }
}
