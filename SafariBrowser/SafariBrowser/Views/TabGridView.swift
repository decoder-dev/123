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

struct TabCardView: View {
    let tab: BrowserTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: tab.isPrivate ? "hand.raised.fill" : "globe")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(tab.displayTitle)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .padding(4)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }

            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(height: 120)
                .overlay {
                    if tab.url != nil {
                        Image(systemName: "photo")
                            .foregroundStyle(.tertiary)
                    } else {
                        Text("New Tab")
                            .foregroundStyle(.tertiary)
                    }
                }

            Text(tab.displayURL.isEmpty ? "about:blank" : tab.displayURL)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .onTapGesture(perform: onSelect)
    }
}
