import Foundation
import WebKit

/// Caches WKWebView instances per tab to prevent reload on tab switch.
/// Pattern from Firefox iOS / factoryfloor BrowserView cache.
@MainActor
public final class WebViewPool {
    private var cache: [UUID: WKWebView] = [:]
    private let configFactory: WebViewConfigurationFactory

    public init(configFactory: WebViewConfigurationFactory) {
        self.configFactory = configFactory
    }

    public func webView(for tab: BrowserTab) -> WKWebView {
        if let existing = cache[tab.id] {
            return existing
        }
        let config = configFactory.makeConfiguration(isPrivate: tab.isPrivate, url: tab.url)
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        cache[tab.id] = webView

        if let url = tab.url {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    public func removeWebView(for tabID: UUID) {
        cache.removeValue(forKey: tabID)
    }

    public func clearAll() {
        cache.removeAll()
    }

    public func contains(_ tabID: UUID) -> Bool {
        cache[tabID] != nil
    }
}
