import AppKit

class ScreenManager {
    private var panels: [CGDirectDisplayID: DockPanel] = [:]
    private var observer: Any?

    func start() {
        updatePanels()
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updatePanels()
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func reloadAll(with profile: DockProfile) {
        for panel in panels.values {
            panel.reload(profile: profile)
        }
    }

    func syncAllFromAppleDock() {
        let fresh = DockProfile.fromAppleDock
        ProfileManager.shared.saveActive(fresh)
        reloadAll(with: fresh)
    }

    private func updatePanels() {
        let activeScreens = NSScreen.screens
        let activeIDs = Set(activeScreens.compactMap(\.displayID))

        for id in panels.keys where !activeIDs.contains(id) {
            panels[id]?.close()
            panels.removeValue(forKey: id)
        }

        for screen in activeScreens {
            guard let id = screen.displayID else { continue }
            guard screen != activeScreens.first else { continue }
            if panels[id] == nil {
                let panel = DockPanel(screen: screen)
                panel.orderFrontRegardless()
                panels[id] = panel
            }
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
