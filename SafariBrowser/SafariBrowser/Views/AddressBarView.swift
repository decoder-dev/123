import SwiftUI

struct AddressBarView: View {
    @Binding var text: String
    @Binding var isEditing: Bool
    var isPrivate: Bool = false
    var pageURL: URL?
    var onSubmit: () -> Void
    var onFocus: (() -> Void)?

    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var accent: Color { BrowserTheme.accent(forPrivate: isPrivate) }

    private var securityIcon: String {
        if isFocused { return "magnifyingglass" }
        if isPrivate { return "hand.raised.fill" }
        guard let scheme = pageURL?.scheme?.lowercased() else { return "globe" }
        if scheme == "https" { return "lock.fill" }
        if scheme == "http" { return "lock.open.fill" }
        return "globe"
    }

    private var securityColor: Color {
        if isPrivate { return accent }
        if pageURL?.scheme?.lowercased() == "https" { return BrowserTheme.secure }
        return BrowserTheme.muted
    }

    private var placeholder: String {
        isPrivate ? "Private search or URL" : "Search or enter URL"
    }

    var body: some View {
        HStack(spacing: BrowserSpacing.sm) {
            Image(systemName: securityIcon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(securityColor)
                .frame(width: 22)

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .font(isFocused ? .body : .subheadline.weight(.semibold))
                .foregroundStyle(isFocused ? BrowserTheme.ink : BrowserTheme.ink)
                .focused($isFocused)
                .onSubmit(onSubmit)
                .onChange(of: isFocused) { _, focused in
                    isEditing = focused
                    if focused {
                        onFocus?()
                        if text.isEmpty || text == pageURL?.host {
                            text = pageURL?.absoluteString ?? text
                        }
                    } else {
                        syncDisplayText()
                    }
                }

            if isFocused && !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(BrowserTheme.muted)
                }
                .browserPressable()
                .accessibilityLabel("Clear")
            }
        }
        .padding(.horizontal, BrowserSpacing.lg)
        .padding(.vertical, 11)
        .browserGlass(
            radius: BrowserRadius.chrome,
            style: .interactive,
            tint: isPrivate ? accent.opacity(colorScheme == .dark ? 0.12 : 0.08) : accent.opacity(0.04)
        )
        .onAppear { syncDisplayText() }
        .onChange(of: pageURL) { _, _ in
            guard !isFocused else { return }
            syncDisplayText()
        }
    }

    private func syncDisplayText() {
        if let host = pageURL?.host, !host.isEmpty, !isFocused {
            text = host
        } else if pageURL == nil {
            text = ""
        }
    }
}
