import AppKit
import ApplicationServices

final class BadgeMonitor: ObservableObject {
    @Published var badges: [String: String] = [:]
    private var timer: Timer?

    func start() {
        let opts: [NSString: Any] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true]
        AXIsProcessTrustedWithOptions(opts as CFDictionary)
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.poll()
        }
        timer?.tolerance = 1
        poll()
    }

    deinit { timer?.invalidate() }

    private func poll() {
        guard AXIsProcessTrusted(),
              let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
        else { return }

        let pid = dock.processIdentifier
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var found: [String: String] = [:]
            Self.scan(AXUIElementCreateApplication(pid), into: &found)
            DispatchQueue.main.async { self?.badges = found }
        }
    }

    private static func scan(_ element: AXUIElement, into result: inout [String: String]) {
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
                scan(child, into: &result)
            }
        }
    }
}
