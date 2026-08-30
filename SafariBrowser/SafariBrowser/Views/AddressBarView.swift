import SwiftUI

struct AddressBarView: View {
    @Binding var text: String
    @Binding var isEditing: Bool
    var onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isEditing ? "magnifyingglass" : "lock.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Search or enter URL", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .focused($isFocused)
                .onSubmit(onSubmit)
                .onChange(of: isFocused) { _, focused in
                    isEditing = focused
                }

            if isEditing && !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.systemGray6), in: Capsule())
    }
}
