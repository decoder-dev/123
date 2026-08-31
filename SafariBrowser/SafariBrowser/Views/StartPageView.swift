import SwiftUI

struct StartPageView: View {
    var isPrivate: Bool = false

    var body: some View {
        ZStack {
            BrowserBackground(isPrivate: isPrivate)
            VStack(spacing: BrowserSpacing.xl) {
                Spacer()
                VStack(spacing: BrowserSpacing.md) {
                    Image(systemName: isPrivate ? "hand.raised.fill" : "safari")
                        .font(.system(size: 52, weight: .medium))
                        .foregroundStyle(
                            BrowserTheme.accent(forPrivate: isPrivate).gradient
                        )
                        .symbolRenderingMode(.hierarchical)
                    Text(isPrivate ? "Private Browsing" : "SafariBrowser")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(BrowserTheme.ink)
                    Text(isPrivate
                         ? "Your activity is not saved on this device."
                         : "Search or enter an address in the bar below.")
                        .font(.subheadline)
                        .foregroundStyle(BrowserTheme.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, BrowserSpacing.xl)
                }
                .padding(BrowserSpacing.xl)
                .browserGlass(radius: BrowserRadius.card, tint: isPrivate ? BrowserTheme.privateAccent.opacity(0.08) : nil)
                .padding(.horizontal, BrowserSpacing.lg)
                Spacer()
                Spacer()
            }
        }
        .allowsHitTesting(false)
    }
}
