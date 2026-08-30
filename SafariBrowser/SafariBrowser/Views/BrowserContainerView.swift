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

    var body: some View {
        ZStack(alignment: .bottom) {
            if let pool = webViewPool {
                TabPagerView(
                    webViewPool: pool,
                    urlResolver: urlResolver,
                    chromeState: chromeState,
                    downloadManager: downloadManager,
                    usePager: usePager
                )
                .ignoresSafeArea(edges: .top)
                .scaleEffect(chromeState.isCreatingTab ? 0.95 : 1.0)
                .opacity(chromeState.isCreatingTab ? 0.8 : 1.0)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: chromeState.isCreatingTab)
            } else {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if let error = tabManager.selectedTab?.lastErrorMessage {
                VStack {
                    ErrorBanner(message: error)
                    Spacer()
                }
                .padding(.top, 8)
            }

            VStack(spacing: 0) {
                if findInPageVisible {
                    FindInPageBar(
                        query: $findQuery,
                        isVisible: $findInPageVisible,
                        webViewPool: webViewPool
                    )
                }

                if chromeState.isToolbarVisible {
                    VStack(spacing: 8) {
                        AddressBarView(
                            text: $addressText,
                            isEditing: $isEditingAddress,
                            isPrivate: tabManager.selectedTab?.isPrivate == true || tabManager.isPrivateMode,
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
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .background(.ultraThinMaterial)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: chromeState.isToolbarVisible)
        .onChange(of: tabManager.selectedTabID) { _, _ in syncAddressBar() }
        .onAppear { syncAddressBar() }
        .sheet(item: $readerArticle) { article in
            ReaderView(
                article: article,
                isPrivate: tabManager.selectedTab?.isPrivate == true || tabManager.isPrivateMode
            )
        }
    }

    private func syncAddressBar() {
        guard !isEditingAddress else { return }
        addressText = tabManager.selectedTab?.displayURL ?? ""
    }

    private func submitAddress() {
        isEditingAddress = false
        let url = urlResolver.resolve(addressText)
        tabManager.selectedTab?.url = url
        if let pool = webViewPool, let tab = tabManager.selectedTab {
            pool.webView(for: tab).load(URLRequest(url: url))
        }
        addressText = url.absoluteString
    }

    private func openReaderMode() {
        guard let pool = webViewPool, let tab = tabManager.selectedTab else { return }
        let webView = pool.webView(for: tab)
        webView.evaluateJavaScript(ReaderModeService.extractionScript) { result, _ in
            Task { @MainActor in
                guard let json = result as? String,
                      let article = ReaderModeService.parse(json: json, sourceURL: tab.url) else { return }
                readerArticle = article
            }
        }
    }
}

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.red.opacity(0.9), in: Capsule())
            .padding(.horizontal)
    }
}
