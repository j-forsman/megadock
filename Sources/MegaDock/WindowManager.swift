import AppKit
import ApplicationServices

enum WindowManager {
    struct AppWindow: Identifiable {
        let processIdentifier: pid_t
        let index: Int
        let title: String
        let displayTitle: String
        let isMinimized: Bool

        var id: String {
            "\(processIdentifier)-\(index)-\(title)"
        }
    }

    static var canReadWindows: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func requestAccessibilityIfNeeded() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func windows(bundleID: String, promptForAccessibility: Bool = false) -> [AppWindow] {
        if promptForAccessibility {
            guard requestAccessibilityIfNeeded() else { return [] }
        } else {
            guard AXIsProcessTrusted() else { return [] }
        }

        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .flatMap(windows(of:))
    }

    static func focusWindow(_ appWindow: AppWindow) {
        guard requestAccessibilityIfNeeded(),
              let app = NSRunningApplication(processIdentifier: appWindow.processIdentifier),
              let window = axWindow(matching: appWindow, in: app) else { return }

        app.unhide()
        if appWindow.isMinimized {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, false as CFTypeRef)
        }
        app.activate(options: [.activateIgnoringOtherApps])
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, true as CFTypeRef)
        AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, true as CFTypeRef)
    }

    static func showAllWindows(bundleID: String) {
        guard requestAccessibilityIfNeeded() else { return }

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

    private static func windows(of app: NSRunningApplication) -> [AppWindow] {
        axWindows(of: app).enumerated().map { index, window in
            let title = title(of: window, fallbackIndex: index)
            return AppWindow(
                processIdentifier: app.processIdentifier,
                index: index,
                title: title,
                displayTitle: displayTitle(for: title, appName: app.localizedName),
                isMinimized: isMinimized(window)
            )
        }
    }

    private static func axWindow(matching appWindow: AppWindow, in app: NSRunningApplication) -> AXUIElement? {
        let windows = axWindows(of: app)
        if windows.indices.contains(appWindow.index),
           title(of: windows[appWindow.index], fallbackIndex: appWindow.index) == appWindow.title {
            return windows[appWindow.index]
        }

        return windows.first { title(of: $0, fallbackIndex: 0) == appWindow.title }
    }

    private static func axWindows(of app: NSRunningApplication) -> [AXUIElement] {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else { return [] }
        return windows
    }

    private static func title(of window: AXUIElement, fallbackIndex: Int) -> String {
        var titleValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success,
           let title = titleValue as? String,
           !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        return "Untitled Window \(fallbackIndex + 1)"
    }

    private static func displayTitle(for title: String, appName: String?) -> String {
        let cleaned = title
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let separators = [" — ", " – ", " - ", " | "]
        let withoutAppName = stripAppNameSuffix(from: cleaned, appName: appName, separators: separators)

        if withoutAppName.count <= 48 {
            return withoutAppName
        }

        for separator in separators {
            let parts = withoutAppName.components(separatedBy: separator)
            if let first = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines),
               parts.count > 1,
               first.count >= 4 {
                return truncate(first, maxLength: 48)
            }
        }

        return truncate(withoutAppName, maxLength: 48)
    }

    private static func stripAppNameSuffix(from title: String, appName: String?, separators: [String]) -> String {
        guard let appName, !appName.isEmpty else { return title }

        for separator in separators {
            var parts = title.components(separatedBy: separator)
            while let last = parts.last,
                  last.localizedCaseInsensitiveContains(appName),
                  parts.count > 1 {
                parts.removeLast()
            }
            let stripped = parts.joined(separator: separator)
            if stripped != title {
                return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return title
    }

    private static func truncate(_ title: String, maxLength: Int) -> String {
        guard title.count > maxLength else { return title }
        let endIndex = title.index(title.startIndex, offsetBy: maxLength - 1)
        return String(title[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private static func isMinimized(_ window: AXUIElement) -> Bool {
        var minimized: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized) == .success else {
            return false
        }
        return (minimized as? Bool) == true
    }
}
