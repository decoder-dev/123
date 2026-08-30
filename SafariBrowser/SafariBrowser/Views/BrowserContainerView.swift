import SwiftUI
import SafariBrowserCore

struct BrowserContainerView: View {
    let webViewPool: WebViewPool?
    let urlResolver: URLResolver
    @Binding var findInPageVisible: Bool
    @Binding var findQuery: String

    @Environment(TabManager.self) private var tabManager
    @State private var addressText = ""
    @State private var isEditingAddress = false
    @State private var toolbarVisible = true

    var body: some View {
        VStack(spacing: 0) {
            if let pool = webViewPool {
                TabPagerView(webViewPool: pool, urlResolver: urlResolver)
                    .ignoresSafeArea(edges: .top)
            } else {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if findInPageVisible {
                FindInPageBar(query: $findQuery, webViewPool: webViewPool)
            }

            if toolbarVisible {
                VStack(spacing: 8) {
                    AddressBarView(
                        text: $addressText,
                        isEditing: $isEditingAddress,
                        onSubmit: { submitAddress() }
                    )
                    BrowserToolbarView(webViewPool: webViewPool)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: tabManager.selectedTabID) { _, _ in
            syncAddressBar()
        }
        .onAppear { syncAddressBar() }
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
}
