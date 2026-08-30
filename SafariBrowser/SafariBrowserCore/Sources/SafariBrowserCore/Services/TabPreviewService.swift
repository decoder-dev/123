import Foundation
import WebKit

@MainActor
public final class TabPreviewService {
    public static let shared = TabPreviewService()

    private init() {}

    public func capturePreview(from webView: WKWebView) async -> Data? {
        let config = WKSnapshotConfiguration()
        config.snapshotWidth = NSNumber(value: 320)
        do {
            let image = try await webView.takeSnapshot(configuration: config)
            return image.pngData()
        } catch {
            return nil
        }
    }
}
