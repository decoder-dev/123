import SwiftUI

struct AddressBarView: View {
    @Binding var text: String
    @Binding var isEditing: Bool
    var isPrivate: Bool = false
    var pageURL: URL?
    var onSubmit: () -> Void
    var onFocus: (() -> Void)?

    @FocusState private var isFocused: Bool

    private var securityIcon: String {
        if isEditing { return "magnifyingglass" }
        if isPrivate { return "hand.raised.fill" }
        guard let scheme = pageURL?.scheme?.lowercased() else { return "globe" }
        if scheme == "https" { return "lock.fill" }
        if scheme == "http" { return "lock.open.fill" }
        return "globe"
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: securityIcon)
                .font(.caption)
                .foregroundStyle(isPrivate ? .purple : .secondary)

            TextField(isPrivate ? "Private Search or URL" : "Search or enter URL", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .focused($isFocused)
                .onSubmit(onSubmit)
                .onChange(of: isFocused) { _, focused in
                    isEditing = focused
                    if focused { onFocus?() }
                }

            if isEditing && !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isPrivate ? Color.purple.opacity(0.12) : Color(.systemGray6), in: Capsule())
    }
}
