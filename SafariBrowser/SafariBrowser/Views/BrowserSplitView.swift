import SwiftUI
import SafariBrowserCore

/// iPad split view: sidebar tab list + main browser content.
struct BrowserSplitView: View {
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

    @Environment(TabManager.self) private var tabManager
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: Binding(
                get: { tabManager.selectedTabID },
                set: { if let id = $0, let tab = tabManager.tabs.first(where: { $0.id == id }) {
                    tabManager.selectTab(tab)
                }}
            )) {
                Section {
                    ForEach(tabManager.tabs) { tab in
                        sidebarRow(for: tab)
                            .tag(tab.id)
                            .swipeActions {
                                Button(role: .destructive) {
                                    tabManager.closeTab(tab, webViewPool: webViewPool)
                                } label: {
                                    Label("Close", systemImage: "xmark")
                                }
                            }
                    }
                } header: {
                    HStack {
                        Text("Tabs")
                        Spacer()
                        if tabManager.isPrivateMode {
                            BrowserStatusPill(title: "Private", icon: "hand.raised.fill")
                        }
                    }
                }
            }
            .navigationTitle("SafariBrowser")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        tabManager.addTab()
                        HapticService.newTab()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New tab")
                }
            }
        } detail: {
            BrowserContainerView(
                webViewPool: webViewPool,
                urlResolver: urlResolver,
                findInPageVisible: $findInPageVisible,
                findQuery: $findQuery,
                readerArticle: $readerArticle,
                showSettings: $showSettings,
                showBookmarks: $showBookmarks,
                showHistory: $showHistory,
                showDownloads: $showDownloads,
                showUserScripts: $showUserScripts,
                showSitePermissions: $showSitePermissions,
                usePager: false
            )
        }
    }

    @ViewBuilder
    private func sidebarRow(for tab: BrowserTab) -> some View {
        HStack(spacing: BrowserSpacing.sm) {
            if tab.isPrivate {
                Image(systemName: "hand.raised.fill")
                    .font(.caption)
                    .foregroundStyle(BrowserTheme.privateAccent)
                    .frame(width: 18, height: 18)
            } else if let data = tab.faviconData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                Image(systemName: "globe")
                    .font(.caption)
                    .foregroundStyle(BrowserTheme.muted)
                    .frame(width: 18, height: 18)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.displayTitle)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                if !tab.displayURL.isEmpty {
                    Text(tab.displayURL)
                        .font(.caption2)
                        .foregroundStyle(BrowserTheme.muted)
                        .lineLimit(1)
                }
            }
            if tab.isLoading {
                Spacer(minLength: 4)
                ProgressView()
                    .controlSize(.small)
            }
        }
    }
}
