import AppKit

class ScreenManager {
    private var panels: [CGDirectDisplayID: DockPanel] = [:]
    private var observer: Any?
    private var presentationCheckTimer: Timer?

    func start() {
        updatePanels()
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // ponytail: screen ordering settles ~300ms after the notification
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.updatePanels()
            }
        }
        // ponytail: no notification exists for "slideshow started" — poll the
        // app's own state instead. Runs off the main thread since it's a real
        // (blocking) Apple Event round-trip to another process.
        presentationCheckTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.checkPresentationState()
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        presentationCheckTimer?.invalidate()
    }

    func reloadAll(with profile: DockProfile) {
        for panel in panels.values {
            panel.reload(profile: profile)
        }
    }

    func relayoutAll() {
        for screen in NSScreen.screens {
            guard let id = screen.displayID, let panel = panels[id] else { continue }
            panel.updateFrame(for: screen)
        }
    }

    func syncAllFromAppleDock() {
        let fresh = DockProfile.fromAppleDock
        ProfileManager.shared.saveActive(fresh)
        reloadAll(with: fresh)
    }

    private static let presentationBundleIDs: Set<String> = [
        "com.microsoft.Powerpoint",
        "com.apple.iWork.Keynote",
    ]

    private func checkPresentationState() {
        // ponytail: the Apple Event round-trip only happens while PowerPoint/Keynote
        // is actually the frontmost app — free the rest of the time, instead of
        // pinging it once a second all day just because it's open in the background.
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
              Self.presentationBundleIDs.contains(bundleID)
        else {
            for panel in panels.values {
                panel.setHiddenForFullScreen(false)
            }
            return
        }

        DispatchQueue.global(qos: .utility).async {
            let presenting = Self.isPresenting(bundleID: bundleID)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                for panel in self.panels.values {
                    panel.setHiddenForFullScreen(presenting)
                }
            }
        }
    }

    /// True if PowerPoint or Keynote is actively running a slideshow.
    ///
    /// The slideshow surface itself is screen-capture-protected — invisible to
    /// both CGWindowList and the Accessibility API — so window introspection
    /// can't see it. Each app's own AppleScript dictionary exposes the real
    /// "is presenting" state directly, sidestepping that entirely.
    private static func isPresenting(bundleID: String) -> Bool {
        switch bundleID {
        case "com.microsoft.Powerpoint":
            return scriptBool(#"tell application "Microsoft PowerPoint" to exists slide show window of active presentation"#)
        case "com.apple.iWork.Keynote":
            return scriptBool(#"tell application "Keynote" to playing"#)
        default:
            return false
        }
    }

    private static func scriptBool(_ source: String) -> Bool {
        var error: NSDictionary?
        guard let result = NSAppleScript(source: source)?.executeAndReturnError(&error) else { return false }
        return result.booleanValue
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
