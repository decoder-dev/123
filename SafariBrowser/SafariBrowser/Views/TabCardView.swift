import SwiftUI
import SafariBrowserCore

struct TabCardView: View {
    let tab: BrowserTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    private var accent: Color {
        BrowserTheme.accent(forPrivate: tab.isPrivate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BrowserSpacing.sm) {
            HStack(spacing: 6) {
                faviconView
                    .frame(width: 18, height: 18)
                Text(tab.displayTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrowserTheme.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(BrowserTheme.muted)
                        .frame(width: 24, height: 24)
                        .background(BrowserTheme.card.opacity(0.7), in: Circle())
                }
                .browserPressable()
                .accessibilityLabel("Close tab")
            }

            preview
                .frame(height: 118)
                .clipShape(RoundedRectangle(cornerRadius: BrowserRadius.preview, style: .continuous))

            Text(tab.displayURL.isEmpty ? "New Tab" : tab.displayURL)
                .font(.caption2)
                .foregroundStyle(BrowserTheme.muted)
                .lineLimit(1)
        }
        .padding(BrowserSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: BrowserRadius.compact, style: .continuous)
                .fill(BrowserTheme.card.opacity(isSelected ? 0.95 : 0.65))
        }
        .overlay {
            RoundedRectangle(cornerRadius: BrowserRadius.compact, style: .continuous)
                .strokeBorder(
                    isSelected ? accent : Color.primary.opacity(0.06),
                    lineWidth: isSelected ? 2 : 0.8
                )
        }
        .shadow(color: isSelected ? accent.opacity(0.18) : .clear, radius: 10, y: 4)
        .onTapGesture(perform: onSelect)
    }

    @ViewBuilder
    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: BrowserRadius.preview, style: .continuous)
                .fill(
                    tab.isPrivate
                        ? BrowserTheme.privateAccent.opacity(0.08)
                        : BrowserTheme.accent.opacity(0.06)
                )
            if let data = tab.previewImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if tab.url != nil {
                Image(systemName: "globe")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(accent.opacity(0.45))
            } else {
                VStack(spacing: 6) {
                    Image(systemName: tab.isPrivate ? "hand.raised.fill" : "safari")
                        .font(.title2)
                        .foregroundStyle(accent.opacity(0.5))
                    Text("New Tab")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(BrowserTheme.muted)
                }
            }
        }
    }

    @ViewBuilder
    private var faviconView: some View {
        if tab.isPrivate {
            Image(systemName: "hand.raised.fill")
                .font(.caption2)
                .foregroundStyle(BrowserTheme.privateAccent)
        } else if let data = tab.faviconData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 3))
        } else {
            Image(systemName: "globe")
                .font(.caption2)
                .foregroundStyle(BrowserTheme.muted)
        }
    }
}
