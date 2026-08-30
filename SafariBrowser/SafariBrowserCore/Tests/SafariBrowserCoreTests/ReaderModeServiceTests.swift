import Testing
@testable import SafariBrowserCore

@Test func sanitizeHTMLRemovesScriptTags() {
    let input = "<p>Hello</p><script>alert(1)</script><p>World</p>"
    let output = ReaderModeService.sanitizeHTML(input)
    #expect(!output.contains("<script"))
    #expect(output.contains("Hello"))
    #expect(output.contains("World"))
}

@Test func sanitizeHTMLRemovesInlineHandlers() {
    let input = "<img src=\"x\" onerror=\"alert(1)\">"
    let output = ReaderModeService.sanitizeHTML(input)
    #expect(!output.lowercased().contains("onerror"))
}

@Test func sanitizeHTMLRemovesJavascriptURLs() {
    let input = "<a href=\"javascript:alert(1)\">Click</a>"
    let output = ReaderModeService.sanitizeHTML(input)
    #expect(!output.lowercased().contains("javascript:"))
}

@Test func sessionSnapshotExcludesPrivateTabs() {
    let manager = TabManager()
    manager.tabs.removeAll()
    manager.addTab(url: URL(string: "https://example.com"), isPrivate: false)
    manager.addTab(url: URL(string: "https://private.example"), isPrivate: true)
    let snapshots = manager.snapshots()
    #expect(snapshots.count == 2)
    #expect(snapshots.filter { !$0.isPrivate }.count == 1)
}
