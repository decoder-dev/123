import Foundation
import SafariBrowserCore
import Testing

@Test func urlResolverHandlesHTTPS() {
    let resolver = URLResolver()
    let url = resolver.resolve("https://example.com/path")
    #expect(url.host == "example.com")
}

@Test func urlResolverAddsScheme() {
    let resolver = URLResolver()
    let url = resolver.resolve("example.com")
    #expect(url.scheme == "https")
    #expect(url.host == "example.com")
}

@Test func urlResolverSearchFallback() {
    let resolver = URLResolver(searchEngine: .duckDuckGo)
    let url = resolver.resolve("swift programming")
    #expect(url.absoluteString.contains("duckduckgo.com"))
}

@Test func tabManagerStartsWithOneTab() {
    let manager = TabManager()
    #expect(manager.tabs.count == 1)
    #expect(manager.selectedTab != nil)
}

@Test func tabManagerCloseLastCreatesNew() {
    let manager = TabManager()
    let tab = manager.tabs[0]
    manager.closeTab(tab)
    #expect(manager.tabs.count == 1)
}

@Test func tabSnapshotsRoundTrip() {
    let manager = TabManager()
    manager.selectedTab?.url = URL(string: "https://apple.com")
    manager.selectedTab?.title = "Apple"
    let snapshots = manager.snapshots()
    let newManager = TabManager()
    newManager.restore(from: snapshots, selectedID: snapshots.first?.id)
    #expect(newManager.tabs.first?.title == "Apple")
}
