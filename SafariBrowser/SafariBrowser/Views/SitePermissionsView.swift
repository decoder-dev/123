import SwiftUI
import SafariBrowserCore

struct SitePermissionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var permissions: [SitePermission] = []

    var body: some View {
        NavigationStack {
            Group {
                if permissions.isEmpty {
                    ContentUnavailableView(
                        "No Site Permissions",
                        systemImage: "lock.shield",
                        description: Text("Permissions you set for websites will appear here.")
                    )
                } else {
                    List {
                        ForEach(groupedByHost, id: \.host) { group in
                            Section(group.host) {
                                ForEach(group.permissions) { perm in
                                    Picker(perm.type.displayName, selection: binding(for: perm)) {
                                        Text("Ask").tag(SitePermissionDecision.ask)
                                        Text("Allow").tag(SitePermissionDecision.allow)
                                        Text("Deny").tag(SitePermissionDecision.deny)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Site Permissions")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { permissions = SitePermissionStore.shared.allPermissions() }
        }
    }

    private var groupedByHost: [(host: String, permissions: [SitePermission])] {
        Dictionary(grouping: permissions, by: \.host)
            .map { ($0.key, $0.value) }
            .sorted { $0.host < $1.host }
    }

    private func binding(for perm: SitePermission) -> Binding<SitePermissionDecision> {
        Binding(
            get: { SitePermissionStore.shared.decision(for: perm.host, type: perm.type) },
            set: { SitePermissionStore.shared.setDecision($0, host: perm.host, type: perm.type) }
        )
    }
}
