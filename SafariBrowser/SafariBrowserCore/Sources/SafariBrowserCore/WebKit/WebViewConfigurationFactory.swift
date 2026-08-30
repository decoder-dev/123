import Foundation
import WebKit

@MainActor
public final class WebViewConfigurationFactory {
    private let contentBlocker: ContentBlockerService
    private let userscriptManager: UserscriptManager

    public init(
        contentBlocker: ContentBlockerService = .shared,
        userscriptManager: UserscriptManager
    ) {
        self.contentBlocker = contentBlocker
        self.userscriptManager = userscriptManager
    }

    /// Base configuration shared across all webviews (process pool, preferences).
    private lazy var baseConfiguration: WKWebViewConfiguration = {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.isElementFullscreenEnabled = true
        if #available(iOS 18.0, *) {
            config.preferences.shouldPrintBackgrounds = true
        }
        return config
    }()

    public func makeConfiguration(isPrivate: Bool, url: URL?) -> WKWebViewConfiguration {
        let config = baseConfiguration.copy() as! WKWebViewConfiguration
        config.websiteDataStore = isPrivate ? .nonPersistent() : .default()
        config.userContentController = WKUserContentController()
        contentBlocker.apply(to: config)
        userscriptManager.inject(into: config, for: url)
        return config
    }
}
