import AppKit

struct DockItem: Identifiable, Codable {
    let id: UUID
    let bundleID: String
    let name: String
    let path: String

    func launch() {
        let instances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        guard let app = instances.first else {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
            return
        }
        if app.isActive {
            instances.forEach { $0.hide() }
        } else {
            app.unhide()
            app.activate(options: [.activateIgnoringOtherApps])
            unminimizeWindows(of: app)
        }
    }

    // ponytail: AX API is the only way to restore yellow-button-minimized windows;
    // unhide()/activate() don't. Needs Accessibility permission, silently no-ops without it.
    private func unminimizeWindows(of app: NSRunningApplication) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else { return }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else { return }
        for window in windows {
            var minimized: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized) == .success,
               (minimized as? Bool) == true {
                AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, false as CFTypeRef)
            }
        }
    }
}

struct DockProfile: Codable {
    var items: [DockItem]

    static var fromAppleDock: DockProfile {
        DockProfile(items: readAppleDockItems())
    }

    private static func readAppleDockItems() -> [DockItem] {
        guard
            let libURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first,
            let data = try? Data(contentsOf: libURL.appendingPathComponent("Preferences/com.apple.dock.plist")),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let apps = plist["persistent-apps"] as? [[String: Any]]
        else { return [] }

        return apps.compactMap { app -> DockItem? in
            guard
                let tile = app["tile-data"] as? [String: Any],
                let fileData = tile["file-data"] as? [String: Any],
                let rawURL = fileData["_CFURLString"] as? String
            else { return nil }

            var path = rawURL.hasPrefix("file://") ? String(rawURL.dropFirst(7)) : rawURL
            path = path.removingPercentEncoding ?? path
            if path.hasSuffix("/") { path = String(path.dropLast()) }

            let name = tile["file-label"] as? String
                ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            let bundleID = Bundle(path: path)?.bundleIdentifier ?? name

            return DockItem(id: UUID(), bundleID: bundleID, name: name, path: path)
        }
    }
}
