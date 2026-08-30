import Foundation
import UIKit

/// Tracks bottom chrome visibility based on web view scroll (Safari-style).
@MainActor
@Observable
public final class ChromeState {
    public var isToolbarVisible = true
    public var isCreatingTab = false

    private var lastScrollOffset: CGFloat = 0
    private let hideThreshold: CGFloat = 20

    public init() {}

    public func handleScroll(offsetY: CGFloat) {
        let delta = offsetY - lastScrollOffset
        lastScrollOffset = offsetY

        guard offsetY > 0 else {
            if !isToolbarVisible {
                isToolbarVisible = true
                HapticService.toolbarToggle()
            }
            return
        }

        if delta > hideThreshold, isToolbarVisible {
            isToolbarVisible = false
            HapticService.toolbarToggle()
        } else if delta < -hideThreshold, !isToolbarVisible {
            isToolbarVisible = true
            HapticService.toolbarToggle()
        }
    }

    public func showToolbar() {
        if !isToolbarVisible {
            isToolbarVisible = true
        }
    }

    public func triggerNewTabAnimation() {
        isCreatingTab = true
        HapticService.newTab()
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            isCreatingTab = false
        }
    }
}
