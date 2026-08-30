import Testing
import SafariBrowserCore

@Test func chromeStateCollapsesOnScrollDown() {
    let chrome = ChromeState()
    chrome.handleScroll(offsetY: 0)
    chrome.handleScroll(offsetY: 100)
    #expect(chrome.isToolbarVisible == false)
}

@Test func chromeStateExpandsOnScrollUp() {
    let chrome = ChromeState()
    chrome.handleScroll(offsetY: 100)
    chrome.isToolbarVisible = false
    chrome.handleScroll(offsetY: 90)
    chrome.handleScroll(offsetY: 70)
    #expect(chrome.isToolbarVisible == true)
}

@Test func readerModeParsesJSON() {
    let json = #"{"title":"Test","byline":"Author","contentHTML":"<p>Hello</p>"}"#
    let article = ReaderModeService.parse(json: json, sourceURL: URL(string: "https://example.com"))
    #expect(article?.title == "Test")
    #expect(article?.contentHTML.contains("Hello") == true)
}

@Test func sitePermissionStoreRoundTrip() {
    SitePermissionStore.shared.setDecision(.allow, host: "example.com", type: .camera)
    #expect(SitePermissionStore.shared.decision(for: "example.com", type: .camera) == .allow)
    SitePermissionStore.shared.setDecision(.ask, host: "example.com", type: .camera)
}
