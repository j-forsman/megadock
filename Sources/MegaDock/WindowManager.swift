import AppKit
import ApplicationServices

enum WindowManager {
    static func showAllWindows(bundleID: String) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else { return }

        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .forEach { app in
                app.unhide()
                unminimizeWindows(of: app, promptForAccessibility: false)
            }
    }

    static func unminimizeWindows(of app: NSRunningApplication, promptForAccessibility: Bool = true) {
        if promptForAccessibility {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            guard AXIsProcessTrustedWithOptions(options) else { return }
        } else {
            guard AXIsProcessTrusted() else { return }
        }

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
