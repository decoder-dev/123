import SwiftUI
import SafariBrowserCore

struct TabGridView: View {
    let webViewPool: WebViewPool?
    @Environment(TabManager.self) private var tabManager

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    tabManager.isTabGridVisible = false
                }

            VStack(spacing: 20) {
                HStack {
                    Text("\(tabManager.tabs.count) Tab\(tabManager.tabs.count == 1 ? "" : "s")")
                        .font(.headline)
                    Spacer()
                    if tabManager.isPrivateMode {
                        Label("Private", systemImage: "hand.raised.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        tabManager.isTabGridVisible = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
                .padding(.horizontal)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(tabManager.tabs) { tab in
                            TabCardView(
                                tab: tab,
                                isSelected: tab.id == tabManager.selectedTabID,
                                onSelect: { tabManager.selectTab(tab) },
                                onClose: {
                                    webViewPool?.removeWebView(for: tab.id)
                                    tabManager.closeTab(tab)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }

                Button {
                    tabManager.addTab()
                    tabManager.isTabGridVisible = false
                } label: {
                    Label("New Tab", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .padding(.top, 60)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding()
        }
    }
}
