import AppKit
import ApplicationServices

final class BadgeMonitor: ObservableObject {
    static let shared = BadgeMonitor()
    @Published var badges: [String: String] = [:]
    private var timer: Timer?

    private init() {}

    func start() {
        guard timer == nil else { return }  // C2: prevent double-start / timer leak
        AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true] as CFDictionary)
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.poll()
        }
        timer?.tolerance = 1
        poll()
    }

    deinit { timer?.invalidate() }

    private func poll() {
        // C1/C4: AX API is not thread-safe; run entirely on the main thread.
        // The scan is fast (< 5ms for a typical Dock) and does not block the UI.
        guard AXIsProcessTrusted(),
              let dock = NSRunningApplication.runningApplications(
                  withBundleIdentifier: "com.apple.dock").first
        else { return }

        var found: [String: String] = [:]
        Self.scan(AXUIElementCreateApplication(dock.processIdentifier), into: &found)
        if found != badges { badges = found }  // C8/C9: skip assignment when nothing changed
    }

    private static func scan(_ element: AXUIElement, into result: inout [String: String], depth: Int = 0) {
        guard depth < 10 else { return }  // C3: bound recursion against unexpectedly deep AX trees
        var ref: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &ref) == .success,
              let children = ref as? [AXUIElement] else { return }

        for child in children {
            var subroleRef: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXSubroleAttribute as CFString, &subroleRef)

            if subroleRef as? String == "AXApplicationDockItem" {
                var badgeRef: AnyObject?
                guard AXUIElementCopyAttributeValue(child, "AXStatusLabel" as CFString, &badgeRef) == .success,
                      let badge = badgeRef as? String, !badge.isEmpty else { continue }

                var urlRef: AnyObject?
                AXUIElementCopyAttributeValue(child, kAXURLAttribute as CFString, &urlRef)
                if let nsURL = urlRef as? NSURL,
                   let bundleID = Bundle(url: nsURL as URL)?.bundleIdentifier {
                    result[bundleID] = badge
                }
            } else {
                scan(child, into: &result, depth: depth + 1)
            }
        }
    }
}
