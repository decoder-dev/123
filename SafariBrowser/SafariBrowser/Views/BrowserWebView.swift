import SwiftUI
import WebKit
import SafariBrowserCore
import SwiftData

struct BrowserWebView: UIViewRepresentable {
    let tab: BrowserTab
    let webViewPool: WebViewPool
    var onNavigationComplete: ((URL?, String) -> Void)?

    func makeUIView(context: Context) -> WKWebView {
        let webView = webViewPool.webView(for: tab)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.observeProgress(for: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.tab = tab
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(tab: tab, onNavigationComplete: onNavigationComplete)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var tab: BrowserTab
        var onNavigationComplete: ((URL?, String) -> Void)?
        private var progressObservation: NSKeyValueObservation?

        init(tab: BrowserTab, onNavigationComplete: ((URL?, String) -> Void)?) {
            self.tab = tab
            self.onNavigationComplete = onNavigationComplete
        }

        func observeProgress(for webView: WKWebView) {
            progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.tab.estimatedProgress = webView.estimatedProgress
                    self?.tab.isLoading = webView.estimatedProgress < 1.0
                }
            }
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            tab.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            tab.isLoading = false
            tab.title = webView.title ?? tab.title
            tab.url = webView.url
            tab.canGoBack = webView.canGoBack
            tab.canGoForward = webView.canGoForward
            tab.lastVisitedAt = Date()
            onNavigationComplete?(webView.url, webView.title ?? "")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            tab.isLoading = false
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            decisionHandler(.allow)
        }

        // MARK: - WKUIDelegate (target=_blank, JS dialogs)

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let frame = navigationAction.targetFrame, frame.isMainFrame {
                return nil
            }
            if let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            completionHandler()
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (Bool) -> Void
        ) {
            completionHandler(true)
        }
    }
}
