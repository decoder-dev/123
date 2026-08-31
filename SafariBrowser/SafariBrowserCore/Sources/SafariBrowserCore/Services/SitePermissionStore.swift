import Foundation

public enum SitePermissionType: String, Codable, CaseIterable, Sendable, Identifiable {
    case camera
    case microphone
    case location
    case notifications

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .camera: "Camera"
        case .microphone: "Microphone"
        case .location: "Location"
        case .notifications: "Notifications"
        }
    }

    public var icon: String {
        switch self {
        case .camera: "camera.fill"
        case .microphone: "mic.fill"
        case .location: "location.fill"
        case .notifications: "bell.fill"
        }
    }

    /// Types with WebKit delegate wiring in the app target.
    public var isImplemented: Bool {
        switch self {
        case .camera, .microphone: true
        case .location, .notifications: false
        }
    }

    public static var implementedCases: [SitePermissionType] {
        allCases.filter(\.isImplemented)
    }
}

public enum SitePermissionDecision: String, Codable, Sendable {
    case ask
    case allow
    case deny
}

public struct SitePermission: Codable, Sendable, Identifiable {
    public var id: String { "\(host)-\(type.rawValue)" }
    public let host: String
    public let type: SitePermissionType
    public var decision: SitePermissionDecision

    public init(host: String, type: SitePermissionType, decision: SitePermissionDecision = .ask) {
        self.host = host
        self.type = type
        self.decision = decision
    }
}

@MainActor
public final class SitePermissionStore {
    public static let shared = SitePermissionStore()
    private let key = "site.permissions"
    private var permissions: [SitePermission] = []

    private init() { load() }

    public func decision(for host: String, type: SitePermissionType) -> SitePermissionDecision {
        permissions.first { $0.host == host && $0.type == type }?.decision ?? .ask
    }

    public func setDecision(_ decision: SitePermissionDecision, host: String, type: SitePermissionType) {
        if let index = permissions.firstIndex(where: { $0.host == host && $0.type == type }) {
            permissions[index].decision = decision
        } else {
            permissions.append(SitePermission(host: host, type: type, decision: decision))
        }
        save()
    }

    public func allPermissions() -> [SitePermission] {
        permissions
            .filter { $0.type.isImplemented }
            .sorted { $0.host < $1.host }
    }

    public func remove(_ permission: SitePermission) {
        permissions.removeAll { $0.host == permission.host && $0.type == permission.type }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SitePermission].self, from: data) else { return }
        permissions = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(permissions) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
