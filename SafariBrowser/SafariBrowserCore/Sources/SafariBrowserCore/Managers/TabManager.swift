import Foundation

@MainActor
@Observable
public final class TabManager {
    public private(set) var tabs: [BrowserTab] = []
    public var selectedTabID: UUID?
    public var isPrivateMode: Bool = false
    public var isTabGridVisible: Bool = false

    public var selectedTab: BrowserTab? {
        guard let id = selectedTabID else { return tabs.first }
        return tabs.first { $0.id == id }
    }

    public var selectedIndex: Int {
        guard let id = selectedTabID else { return 0 }
        return tabs.firstIndex { $0.id == id } ?? 0
    }

    public init() {
        addTab()
    }

    @discardableResult
    public func addTab(url: URL? = nil, isPrivate: Bool? = nil) -> BrowserTab {
        let tab = BrowserTab(url: url, isPrivate: isPrivate ?? isPrivateMode)
        tabs.append(tab)
        selectedTabID = tab.id
        return tab
    }

    public func closeTab(_ tab: BrowserTab, webViewPool: WebViewPool? = nil) {
        webViewPool?.removeWebView(for: tab.id)
        tabs.removeAll { $0.id == tab.id }
        if tabs.isEmpty {
            addTab()
        } else if selectedTabID == tab.id {
            selectedTabID = tabs.last?.id
        }
    }

    public func closeTab(at index: Int, webViewPool: WebViewPool? = nil) {
        guard tabs.indices.contains(index) else { return }
        closeTab(tabs[index], webViewPool: webViewPool)
    }

    public func selectTab(_ tab: BrowserTab) {
        selectedTabID = tab.id
        isTabGridVisible = false
    }

    public func selectTab(at index: Int) {
        guard tabs.indices.contains(index) else { return }
        selectTab(tabs[index])
    }

    public func moveTab(from source: Int, to destination: Int) {
        guard tabs.indices.contains(source), destination >= 0, destination < tabs.count else { return }
        let tab = tabs.remove(at: source)
        tabs.insert(tab, at: destination)
    }

    public func resetToSingleTab() {
        tabs.removeAll()
        addTab()
    }

    public func togglePrivateMode() {
        isPrivateMode.toggle()
        tabs.removeAll()
        addTab()
    }

    public func snapshots() -> [TabSnapshot] {
        tabs.map(TabSnapshot.init)
    }

    public func restore(from snapshots: [TabSnapshot], selectedID: UUID?) {
        tabs = snapshots.map { $0.makeTab() }
        selectedTabID = selectedID ?? tabs.first?.id
    }
}
