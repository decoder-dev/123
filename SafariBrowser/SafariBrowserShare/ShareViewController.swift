import UIKit
import Social

class ShareViewController: SLComposeServiceViewController {
    override func isContentValid() -> Bool { true }

    override func didSelectPost() {
        if let item = extensionContext?.inputItems.first as? NSExtensionItem,
           let attachments = item.attachments {
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier("public.url") {
                    provider.loadItem(forTypeIdentifier: "public.url") { item, _ in
                        if let url = item as? URL {
                            self.saveAndOpen(url)
                        } else if let urlString = item as? String, let url = URL(string: urlString) {
                            self.saveAndOpen(url)
                        }
                        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                    }
                    return
                }
            }
        }
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! { [] }

    private func saveAndOpen(_ url: URL) {
        let defaults = UserDefaults(suiteName: "group.com.safaribrowser.app")
        defaults?.set(url.absoluteString, forKey: "pendingShareURL")
        guard let encoded = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let openURL = URL(string: "safaribrowser://open?url=\(encoded)") else { return }
        extensionContext?.open(openURL, completionHandler: nil)
    }
}
