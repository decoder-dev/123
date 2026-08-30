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
        context.coordinator.container = nil
        context.coordinator.observeProgress(for: webView)

        let container = WebViewContainer(webView: webView)
        context.coordinator.container = container
        container.onScroll = { [weak chromeState] offsetY in
            chromeState?.handleScroll(offsetY: offsetY)
        }
        container.onRefresh = { [weak webView] in
            webView?.reload()
        }
        return container
    }

    func updateUIView(_ container: WebViewContainer, context: Context) {
        context.coordinator.tab = tab
        context.coordinator.downloadManager = downloadManager
        context.coordinator.container = container
        container.onScroll = { [weak chromeState] offsetY in
            chromeState?.handleScroll(offsetY: offsetY)
        }
    }

    static func dismantleUIView(_ uiView: WebViewContainer, coordinator: Coordinator) {
        coordinator.progressObservation?.invalidate()
        coordinator.progressObservation = nil
        uiView.webView.navigationDelegate = nil
        uiView.webView.uiDelegate = nil
        uiView.webView.scrollView.delegate = nil
        coordinator.container = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(tab: tab, onNavigationComplete: onNavigationComplete, downloadManager: downloadManager)
    }

    // MARK: - Container

    final class WebViewContainer: UIView {
        let webView: WKWebView
        let refreshControl = UIRefreshControl()
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
            refreshControl.addAction(UIAction { [weak self] _ in
                self?.onRefresh?()
            }, for: .valueChanged)
            webView.scrollView.refreshControl = refreshControl
        }

        func endRefreshing() {
            refreshControl.endRefreshing()
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
        weak var container: WebViewContainer?
        private var progressObservation: NSKeyValueObservation?

        init(tab: BrowserTab, onNavigationComplete: ((URL?, String) -> Void)?, downloadManager: DownloadManager?) {
            self.tab = tab
            self.onNavigationComplete = onNavigationComplete
            self.downloadManager = downloadManager
        }

        func observeProgress(for webView: WKWebView) {
            progressObservation?.invalidate()
            progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.tab.estimatedProgress = webView.estimatedProgress
                    self?.tab.isLoading = webView.estimatedProgress < 1.0
                }
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            tab.isLoading = true
            tab.lastErrorMessage = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            finishNavigation(webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            failNavigation(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            failNavigation(error)
        }

        private func finishNavigation(_ webView: WKWebView) {
            container?.endRefreshing()
            tab.isLoading = false
            tab.lastErrorMessage = nil
            tab.title = webView.title ?? tab.title
            tab.url = webView.url
            tab.canGoBack = webView.canGoBack
            tab.canGoForward = webView.canGoForward
            tab.lastVisitedAt = Date()
            onNavigationComplete?(webView.url, webView.title ?? "")

            guard !tab.isPrivate else { return }
            Task {
                if let url = webView.url {
                    tab.faviconData = await FaviconService.shared.fetchFavicon(for: url)
                    tab.faviconURL = FaviconService.shared.faviconURL(for: url)
                }
                tab.previewImageData = await TabPreviewService.shared.capturePreview(from: webView)
            }
        }

        private func failNavigation(_ error: Error) {
            container?.endRefreshing()
            tab.isLoading = false
            tab.lastErrorMessage = error.localizedDescription
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
            downloadManager?.handleWKDownload(
                download,
                originalURL: navigationAction.request.url ?? tab.url ?? URL(string: "about:blank")!,
                isPrivate: tab.isPrivate
            )
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
            JSPanelPresenter.alert(message: message, completion: completionHandler)
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (Bool) -> Void
        ) {
            JSPanelPresenter.confirm(message: message, completion: completionHandler)
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptTextInputPanelWithPrompt prompt: String,
            defaultText: String?,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (String?) -> Void
        ) {
            JSPanelPresenter.prompt(message: prompt, defaultText: defaultText, completion: completionHandler)
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

extension BrowserWebView.WebViewContainer: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        onScroll?(scrollView.contentOffset.y)
    }
}
