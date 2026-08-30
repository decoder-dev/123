import Foundation
import WebKit

public struct Userscript: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var source: String
    public var matchPatterns: [String]
    public var isEnabled: Bool
    public var runAt: RunAt

    public enum RunAt: String, Codable, Sendable, Hashable {
        case documentStart
        case documentEnd
    }

    public init(
        id: UUID = UUID(),
        name: String,
        source: String,
        matchPatterns: [String] = ["*://*/*"],
        isEnabled: Bool = true,
        runAt: RunAt = .documentEnd
    ) {
        self.id = id
        self.name = name
        self.source = source
        self.matchPatterns = matchPatterns
        self.isEnabled = isEnabled
        self.runAt = runAt
    }
}

@MainActor
public final class UserscriptManager {
    public var scripts: [Userscript] = []

    public init() {}

    public func inject(into configuration: WKWebViewConfiguration, for url: URL?) {
        guard let url else { return }
        let matching = scripts.filter { $0.isEnabled && matches(url: url, patterns: $0.matchPatterns) }
        for script in matching {
            let injectionTime: WKUserScriptInjectionTime = script.runAt == .documentStart ? .atDocumentStart : .atDocumentEnd
            let userScript = WKUserScript(
                source: script.source,
                injectionTime: injectionTime,
                forMainFrameOnly: true
            )
            configuration.userContentController.addUserScript(userScript)
        }
    }

    private func matches(url: URL, patterns: [String]) -> Bool {
        let urlString = url.absoluteString
        for pattern in patterns {
            if pattern == "*://*/*" { return true }
            let regex = pattern
                .replacingOccurrences(of: ".", with: "\\.")
                .replacingOccurrences(of: "*", with: ".*")
            if urlString.range(of: regex, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }
}
