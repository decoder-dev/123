import SwiftUI
import SafariBrowserCore

struct TabCardView: View {
    let tab: BrowserTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                faviconView
                    .frame(width: 16, height: 16)
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
                    if let data = tab.previewImageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 120)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else if tab.url != nil {
                        Image(systemName: "globe")
                            .font(.largeTitle)
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

    @ViewBuilder
    private var faviconView: some View {
        if tab.isPrivate {
            Image(systemName: "hand.raised.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else if let data = tab.faviconData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "globe")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
