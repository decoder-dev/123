import Foundation
import WebKit

/// Caches WKWebView instances per tab to prevent reload on tab switch.
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
        guard let webView = cache.removeValue(forKey: tabID) else { return }
        teardown(webView)
    }

    public func clearAll() {
        let ids = Array(cache.keys)
        ids.forEach { removeWebView(for: $0) }
    }

    public func reloadAllConfigurations(for tabs: [BrowserTab]) {
        for tab in tabs {
            if cache[tab.id] != nil {
                removeWebView(for: tab.id)
                _ = webView(for: tab)
            }
        }
    }

    public func contains(_ tabID: UUID) -> Bool {
        cache[tabID] != nil
    }

    private func teardown(_ webView: WKWebView) {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.scrollView.delegate = nil
        webView.configuration.userContentController.removeAllUserScripts()
    }
}
