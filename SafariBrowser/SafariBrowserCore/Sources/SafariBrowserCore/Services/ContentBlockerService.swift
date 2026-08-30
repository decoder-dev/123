import Foundation
import WebKit

@MainActor
public final class ContentBlockerService {
    public static let shared = ContentBlockerService()

    private var compiledRuleList: WKContentRuleList?
    public private(set) var isEnabled = true

    private init() {}

    public func compileRules() async throws {
        let rulesJSON = Self.defaultRulesJSON
        compiledRuleList = try await WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "SafariBrowserBlockList",
            encodedContentRuleList: rulesJSON
        )
    }

    public func apply(to configuration: WKWebViewConfiguration) {
        guard isEnabled, let list = compiledRuleList else { return }
        configuration.userContentController.removeAllContentRuleLists()
        configuration.userContentController.add(list)
    }

    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    /// Basic tracker/ad blocking rules inspired by DuckDuckGo and Firefox blocklists.
    private static let defaultRulesJSON = """
    [
      {
        "trigger": {
          "url-filter": ".*",
          "if-domain": ["*doubleclick.net*", "*googlesyndication.com*", "*google-analytics.com*", "*facebook.net*", "*connect.facebook.net*"]
        },
        "action": { "type": "block" }
      },
      {
        "trigger": {
          "url-filter": ".*",
          "if-domain": ["*scorecardresearch.com*", "*hotjar.com*", "*mixpanel.com*", "*segment.io*"]
        },
        "action": { "type": "block" }
      },
      {
        "trigger": {
          "url-filter": ".*/ads/.*",
          "resource-type": ["script", "image"]
        },
        "action": { "type": "block" }
      }
    ]
    """
}
