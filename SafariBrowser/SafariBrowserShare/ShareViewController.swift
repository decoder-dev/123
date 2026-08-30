import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        processSharedItems()
    }

    private func processSharedItems() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else {
            finish()
            return
        }

        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] item, _ in
                    DispatchQueue.main.async {
                        if let url = item as? URL {
                            self?.saveAndOpen(url)
                        } else if let urlString = item as? String, let url = URL(string: urlString) {
                            self?.saveAndOpen(url)
                        } else {
                            self?.finish()
                        }
                    }
                }
                return
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] item, _ in
                    DispatchQueue.main.async {
                        if let text = item as? String,
                           let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
                           url.scheme?.hasPrefix("http") == true {
                            self?.saveAndOpen(url)
                        } else {
                            self?.finish()
                        }
                    }
                }
                return
            }
        }
        finish()
    }

    private func saveAndOpen(_ url: URL) {
        let defaults = UserDefaults(suiteName: "group.com.safaribrowser.app")
        defaults?.set(url.absoluteString, forKey: "pendingShareURL")
        guard let encoded = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let openURL = URL(string: "safaribrowser://open?url=\(encoded)") else {
            finish()
            return
        }
        extensionContext?.open(openURL) { [weak self] _ in
            self?.finish()
        }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
