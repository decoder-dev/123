import SwiftUI
import WebKit
import SafariBrowserCore
import SwiftData

struct BrowserWebView: UIViewRepresentable {
    let tab: BrowserTab
    let webViewPool: WebViewPool
    var chromeState: ChromeState?
    var downloadManager: DownloadManager?
    var onNavigationComplete: ((URL?, String) -> Void)?

    func makeUIView(context: Context) -> WebViewContainer {
        let webView = webViewPool.webView(for: tab)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.observeProgress(for: webView)

        let container = WebViewContainer(webView: webView)
        container.onScroll = { [weak chromeState] offsetY in
            chromeState?.handleScroll(offsetY: offsetY)
        }
        container.onRefresh = { webView.reload() }
        return container
    }

    func updateUIView(_ container: WebViewContainer, context: Context) {
        context.coordinator.tab = tab
        context.coordinator.downloadManager = downloadManager
        container.onScroll = { [weak chromeState] offsetY in
            chromeState?.handleScroll(offsetY: offsetY)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(tab: tab, onNavigationComplete: onNavigationComplete, downloadManager: downloadManager)
    }

    // MARK: - Container

    final class WebViewContainer: UIView {
        let webView: WKWebView
        var onScroll: ((CGFloat) -> Void)?
        var onRefresh: (() -> Void)?

        init(webView: WKWebView) {
            self.webView = webView
            super.init(frame: .zero)
            webView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(webView)
            NSLayoutConstraint.activate([
                webView.topAnchor.constraint(equalTo: topAnchor),
                webView.leadingAnchor.constraint(equalTo: leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: trailingAnchor),
                webView.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
            webView.scrollView.delegate = self
            let refresh = UIRefreshControl()
            refresh.addAction(UIAction { [weak self] _ in
                self?.onRefresh?()
                refresh.endRefreshing()
            }, for: .valueChanged)
            webView.scrollView.refreshControl = refresh
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { nil }
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var tab: BrowserTab
        var onNavigationComplete: ((URL?, String) -> Void)?
        var downloadManager: DownloadManager?
        private var progressObservation: NSKeyValueObservation?

        init(tab: BrowserTab, onNavigationComplete: ((URL?, String) -> Void)?, downloadManager: DownloadManager?) {
            self.tab = tab
            self.onNavigationComplete = onNavigationComplete
            self.downloadManager = downloadManager
        }

        func observeProgress(for webView: WKWebView) {
            progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.tab.estimatedProgress = webView.estimatedProgress
                    self?.tab.isLoading = webView.estimatedProgress < 1.0
                }
            }
        }

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

            Task {
                if let url = webView.url {
                    tab.faviconData = await FaviconService.shared.fetchFavicon(for: url)
                    tab.faviconURL = FaviconService.shared.faviconURL(for: url)
                }
                tab.previewImageData = await TabPreviewService.shared.capturePreview(from: webView)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            tab.isLoading = false
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.shouldPerformDownload {
                decisionHandler(.download)
                return
            }
            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            navigationAction: WKNavigationAction,
            didBecome download: WKDownload
        ) {
            downloadManager?.handleWKDownload(download, originalURL: navigationAction.request.url ?? tab.url ?? URL(string: "about:blank")!)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let frame = navigationAction.targetFrame, frame.isMainFrame { return nil }
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

        @available(iOS 15.0, *)
        func webView(
            _ webView: WKWebView,
            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
            initiatedByFrame frame: WKFrameInfo,
            type: WKMediaCaptureType,
            decisionHandler: @escaping (WKPermissionDecision) -> Void
        ) {
            let host = origin.host
            let permType: SitePermissionType = type == .camera ? .camera : .microphone
            switch SitePermissionStore.shared.decision(for: host, type: permType) {
            case .allow: decisionHandler(.grant)
            case .deny: decisionHandler(.deny)
            case .ask: decisionHandler(.prompt)
            }
        }
    }
}

extension BrowserWebView.Coordinator: UIScrollViewDelegate {}
extension BrowserWebView.WebViewContainer: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        onScroll?(scrollView.contentOffset.y)
    }
}
