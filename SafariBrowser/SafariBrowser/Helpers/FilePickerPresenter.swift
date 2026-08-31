import UIKit
import UniformTypeIdentifiers

@MainActor
final class FilePickerPresenter: NSObject, UIDocumentPickerDelegate {
    static let shared = FilePickerPresenter()
    private var completion: (([URL]) -> Void)?

    func pick(allowsMultiple: Bool, completion: @escaping ([URL]) -> Void) {
        self.completion = completion
        let types: [UTType] = [.item, .data, .content, .image, .pdf, .audio, .video, .text]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = allowsMultiple
        picker.delegate = self
        topViewController()?.present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        completion?(urls)
        completion = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completion?([])
        completion = nil
    }

    private func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let base = base ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        if let nav = base as? UINavigationController { return topViewController(base: nav.visibleViewController) }
        if let tab = base as? UITabBarController { return topViewController(base: tab.selectedViewController) }
        if let presented = base?.presentedViewController { return topViewController(base: presented) }
        return base
    }
}
