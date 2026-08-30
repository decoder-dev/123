import Foundation
import WebKit

@MainActor
public final class WebExtensionManager {
    public static let shared = WebExtensionManager()
    public private(set) var isLoaded = false
    public private(set) var loadedExtensionNames: [String] = []

    private var controller: Any?

    private init() {}

    /// Loads bundled .webextension resources from the app bundle's Extensions/ folder.
    public func loadBundledExtensions() async {
        guard #available(iOS 18.4, *) else { return }
        guard let extensionsURL = Bundle.main.resourceURL?.appendingPathComponent("Extensions") else { return }
        guard FileManager.default.fileExists(atPath: extensionsURL.path) else { return }

        let controller = WKWebExtensionController()
        var names: [String] = []

        if let contents = try? FileManager.default.contentsOfDirectory(at: extensionsURL, includingPropertiesForKeys: nil) {
            for url in contents where url.pathExtension == "webextension" || url.hasDirectoryPath {
                do {
                    let extensionObj = try await WKWebExtension(resourceBaseURL: url)
                    let context = try await WKWebExtensionContext(for: extensionObj)
                    try controller.load(context)
                    names.append(url.deletingPathExtension().lastPathComponent)
                } catch {
                    continue
                }
            }
        }

        self.controller = controller
        self.loadedExtensionNames = names
        self.isLoaded = !names.isEmpty
    }

    public func attachToConfiguration(_ configuration: WKWebViewConfiguration) {
        guard #available(iOS 18.4, *),
              let controller = controller as? WKWebExtensionController else { return }
        configuration.webExtensionController = controller
    }
}
