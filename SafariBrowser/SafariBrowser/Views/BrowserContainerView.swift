import SwiftUI
import SafariBrowserCore

struct BrowserContainerView: View {
    let webViewPool: WebViewPool?
    let urlResolver: URLResolver
    @Binding var findInPageVisible: Bool
    @Binding var findQuery: String
    @Binding var readerArticle: ReaderArticle?
    @Binding var showSettings: Bool
    @Binding var showBookmarks: Bool
    @Binding var showHistory: Bool
    @Binding var showDownloads: Bool
    @Binding var showUserScripts: Bool
    @Binding var showSitePermissions: Bool
    var usePager: Bool = true

    @Environment(TabManager.self) private var tabManager
    @Environment(ChromeState.self) private var chromeState
    @Environment(DownloadManager.self) private var downloadManager

    @State private var addressText = ""
    @State private var isEditingAddress = false
    @State private var showReaderUnavailable = false

    private var isPrivate: Bool {
        tabManager.selectedTab?.isPrivate == true || tabManager.isPrivateMode
    }

    var body: some View {
        ZStack {
            if let pool = webViewPool {
                TabPagerView(
                    webViewPool: pool,
                    urlResolver: urlResolver,
                    chromeState: chromeState,
                    downloadManager: downloadManager,
                    usePager: usePager
                )
                .scaleEffect(chromeState.isCreatingTab ? 0.96 : 1.0)
                .opacity(chromeState.isCreatingTab ? 0.85 : 1.0)
                .animation(BrowserMotion.chrome, value: chromeState.isCreatingTab)
            } else {
                ZStack {
                    BrowserBackground(isPrivate: isPrivate)
                    ProgressView("Loading…")
                        .tint(BrowserTheme.accent(forPrivate: isPrivate))
                }
            }

            if let error = tabManager.selectedTab?.lastErrorMessage {
                VStack {
                    ErrorBanner(message: error) {
                        tabManager.selectedTab?.lastErrorMessage = nil
                    }
                    Spacer()
                }
                .padding(.top, BrowserSpacing.sm)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if chromeState.isToolbarVisible {
                browserChrome
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(BrowserMotion.chrome, value: chromeState.isToolbarVisible)
        .onChange(of: tabManager.selectedTabID) { _, _ in syncAddressBar() }
        .onAppear { syncAddressBar() }
        .sheet(item: $readerArticle) { article in
            ReaderView(
                article: article,
                isPrivate: isPrivate
            )
        }
        .alert("Reader Unavailable", isPresented: $showReaderUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This page doesn't support Reader mode.")
        }
    }

    private var browserChrome: some View {
        VStack(spacing: BrowserSpacing.sm) {
            if findInPageVisible {
                FindInPageBar(
                    query: $findQuery,
                    isVisible: $findInPageVisible,
                    webViewPool: webViewPool
                )
            }

            AddressBarView(
                text: $addressText,
                isEditing: $isEditingAddress,
                isPrivate: isPrivate,
                pageURL: tabManager.selectedTab?.url,
                onSubmit: { submitAddress() },
                onFocus: { chromeState.showToolbar() }
            )

            BrowserToolbarView(
                webViewPool: webViewPool,
                showSettings: $showSettings,
                showBookmarks: $showBookmarks,
                showHistory: $showHistory,
                showDownloads: $showDownloads,
                showUserScripts: $showUserScripts,
                showSitePermissions: $showSitePermissions,
                findInPageVisible: $findInPageVisible,
                onReaderMode: { openReaderMode() }
            )
        }
        .padding(.horizontal, BrowserSpacing.chromeInset)
        .padding(.bottom, BrowserSpacing.sm)
    }

    private func syncAddressBar() {
        guard !isEditingAddress else { return }
        if let host = tabManager.selectedTab?.url?.host, !host.isEmpty {
            addressText = host
        } else {
            addressText = tabManager.selectedTab?.displayURL ?? ""
        }
    }

    private func submitAddress() {
        isEditingAddress = false
        let url = urlResolver.resolve(addressText)
        tabManager.selectedTab?.url = url
        if let pool = webViewPool, let tab = tabManager.selectedTab {
            pool.webView(for: tab).load(URLRequest(url: url))
        }
        addressText = url.host ?? url.absoluteString
    }

    private func openReaderMode() {
        guard let pool = webViewPool, let tab = tabManager.selectedTab else { return }
        let webView = pool.webView(for: tab)
        webView.evaluateJavaScript(ReaderModeService.extractionScript) { result, _ in
            Task { @MainActor in
                guard let json = result as? String,
                      let article = ReaderModeService.parse(json: json, sourceURL: tab.url) else {
                    showReaderUnavailable = true
                    return
                }
                readerArticle = article
            }
        }
    }
}

private struct ErrorBanner: View {
    let message: String
    var onDismiss: () -> Void

    var body: some View {
        Button(action: onDismiss) {
            HStack(spacing: BrowserSpacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(message)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, BrowserSpacing.lg)
            .padding(.vertical, BrowserSpacing.sm)
            .background(BrowserTheme.destructive.opacity(0.92), in: Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, BrowserSpacing.lg)
    }
}
