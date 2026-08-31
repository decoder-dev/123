import SwiftUI
import SafariBrowserCore

struct TabGridView: View {
    let webViewPool: WebViewPool?
    @Environment(TabManager.self) private var tabManager

    private let columns = [
        GridItem(.flexible(), spacing: BrowserSpacing.lg),
        GridItem(.flexible(), spacing: BrowserSpacing.lg),
    ]

    private var isPrivate: Bool { tabManager.isPrivateMode }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
                .onTapGesture {
                    withAnimation(BrowserMotion.grid) {
                        tabManager.isTabGridVisible = false
                    }
                }

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, BrowserSpacing.lg)
                    .padding(.top, BrowserSpacing.lg)
                    .padding(.bottom, BrowserSpacing.md)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: BrowserSpacing.lg) {
                        ForEach(tabManager.tabs) { tab in
                            TabCardView(
                                tab: tab,
                                isSelected: tab.id == tabManager.selectedTabID,
                                onSelect: {
                                    withAnimation(BrowserMotion.grid) {
                                        tabManager.selectTab(tab)
                                    }
                                },
                                onClose: {
                                    tabManager.closeTab(tab, webViewPool: webViewPool)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, BrowserSpacing.lg)
                    .padding(.bottom, BrowserSpacing.lg)
                }

                newTabButton
                    .padding(.horizontal, BrowserSpacing.lg)
                    .padding(.bottom, BrowserSpacing.lg)
            }
            .browserGlass(
                radius: BrowserRadius.card + 4,
                style: .regular,
                tint: isPrivate ? BrowserTheme.privateAccent.opacity(0.06) : nil
            )
            .padding(.horizontal, BrowserSpacing.sm)
            .padding(.top, 52)
            .padding(.bottom, BrowserSpacing.sm)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(tabManager.tabs.count) Tab\(tabManager.tabs.count == 1 ? "" : "s")")
                    .font(.title2.bold())
                    .foregroundStyle(BrowserTheme.ink)
                if isPrivate {
                    BrowserStatusPill(title: "Private", icon: "hand.raised.fill")
                }
            }
            Spacer()
            Button {
                withAnimation(BrowserMotion.grid) {
                    tabManager.isTabGridVisible = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(BrowserTheme.ink)
                    .frame(width: 36, height: 36)
                    .background(BrowserTheme.card.opacity(0.6), in: Circle())
            }
            .browserPressable()
            .accessibilityLabel("Close tab switcher")
        }
    }

    private var newTabButton: some View {
        Button {
            tabManager.addTab()
            withAnimation(BrowserMotion.grid) {
                tabManager.isTabGridVisible = false
            }
        } label: {
            Label("New Tab", systemImage: "plus")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, BrowserSpacing.lg)
                .background(
                    BrowserTheme.accent(forPrivate: isPrivate).gradient,
                    in: RoundedRectangle(cornerRadius: BrowserRadius.compact, style: .continuous)
                )
        }
        .browserPressable()
    }
}
