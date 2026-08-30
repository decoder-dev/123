import Foundation
import UIKit

@MainActor
public enum HapticService {
    public static func tabSwitch() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    public static func newTab() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    public static func toolbarToggle() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    public static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
