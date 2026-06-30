import AppKit
import SwiftUI

final class DockState: ObservableObject {
    @Published var profile: DockProfile
    init(profile: DockProfile) { self.profile = profile }
}

class DockPanel: NSPanel {
    private let state: DockState

    init(screen: NSScreen) {
        state = DockState(profile: ProfileManager.shared.activeProfile())
        super.init(
            contentRect: DockPanel.frame(for: screen),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 1)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        let hostingView = NSHostingView(rootView: DockView(state: state))
        hostingView.autoresizingMask = [.width, .height]
        contentView = hostingView
    }

    func reload(profile: DockProfile) {
        state.profile = profile
    }

    func updateFrame(for screen: NSScreen) {
        setFrame(DockPanel.frame(for: screen), display: true)
    }

    private static func frame(for screen: NSScreen) -> NSRect {
        let s = screen.frame
        let iconSize = UserDefaults.standard.object(forKey: "iconSize") as? Double ?? 44
        let height = CGFloat(iconSize) + 66  // matches the original 110 at the default 44pt
        let width: CGFloat = min(s.width * 0.65, 720)
        return NSRect(x: s.midX - width / 2, y: s.minY + 4, width: width, height: height)
    }
}
