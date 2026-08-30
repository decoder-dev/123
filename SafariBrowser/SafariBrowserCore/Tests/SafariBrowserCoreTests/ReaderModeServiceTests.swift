import Foundation
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

@Test func sanitizeHTMLRemovesUnquotedHandlers() {
    let input = "<img src=x onerror=alert(1)>"
    let output = ReaderModeService.sanitizeHTML(input)
    #expect(!output.lowercased().contains("onerror"))
}

@Test func publicTabSnapshotsFilter() {
    let snapshots = [
        TabSnapshot(from: BrowserTab(url: URL(string: "https://a.com"), isPrivate: false)),
        TabSnapshot(from: BrowserTab(url: URL(string: "https://b.com"), isPrivate: true))
    ]
    let publicOnly = snapshots.filter { !$0.isPrivate }
    #expect(publicOnly.count == 1)
    #expect(publicOnly.first?.url?.host == "a.com")
}
