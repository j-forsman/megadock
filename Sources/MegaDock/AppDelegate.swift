import AppKit
import ApplicationServices
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    private var screenManager: ScreenManager?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusBar()
        screenManager = ScreenManager()
        screenManager?.start()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(
            systemSymbolName: "dock.rectangle",
            accessibilityDescription: "MegaDock"
        )
        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()

        // Profiles submenu
        let profilesItem = NSMenuItem(title: "Profiles", action: nil, keyEquivalent: "")
        let profilesMenu = NSMenu()
        for name in ProfileManager.shared.profileNames {
            let item = NSMenuItem(title: name, action: #selector(switchProfile(_:)), keyEquivalent: "")
            item.representedObject = name
            item.state = name == ProfileManager.shared.activeProfileName ? .on : .off
            profilesMenu.addItem(item)
        }
        profilesMenu.addItem(.separator())
        profilesMenu.addItem(withTitle: "New Profile…", action: #selector(newProfile), keyEquivalent: "")
        profilesMenu.addItem(withTitle: "Rename Profile…", action: #selector(renameActiveProfile), keyEquivalent: "")
        if ProfileManager.shared.profileNames.count > 1 {
            let deleteItem = NSMenuItem(title: "Delete Profile", action: nil, keyEquivalent: "")
            let deleteMenu = NSMenu()
            for name in ProfileManager.shared.profileNames where name != ProfileManager.shared.activeProfileName {
                let item = NSMenuItem(title: name, action: #selector(deleteProfile(_:)), keyEquivalent: "")
                item.representedObject = name
                deleteMenu.addItem(item)
            }
            deleteItem.submenu = deleteMenu
            profilesMenu.addItem(deleteItem)
        }
        profilesItem.submenu = profilesMenu
        menu.addItem(profilesItem)

        menu.addItem(withTitle: "Sync from Apple Dock", action: #selector(syncFromAppleDock), keyEquivalent: "")

        // Icon size submenu
        let sizeItem = NSMenuItem(title: "Icon Size", action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu()
        let current = UserDefaults.standard.object(forKey: "iconSize") as? Double ?? 44
        for (title, value) in [("Small", 36.0), ("Medium", 44.0), ("Large", 56.0)] {
            let item = NSMenuItem(title: title, action: #selector(setIconSize(_:)), keyEquivalent: "")
            item.representedObject = value
            item.state = value == current ? .on : .off
            sizeMenu.addItem(item)
        }
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        if !AXIsProcessTrusted() {
            menu.addItem(withTitle: "Enable Notification Badges…", action: #selector(enableBadges), keyEquivalent: "")
        }

        menu.addItem(.separator())

        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit MegaDock", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusItem?.menu = menu
    }

    @objc private func switchProfile(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String,
              let profile = ProfileManager.shared.activate(profileNamed: name) else { return }
        screenManager?.reloadAll(with: profile)
        rebuildMenu()
    }

    @objc private func newProfile() {
        let alert = NSAlert()
        alert.messageText = "New Profile"
        alert.informativeText = "Starts as a copy of the current profile."
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        textField.placeholderString = "Profile name"
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !ProfileManager.shared.profileNames.contains(name) else { return }

        ProfileManager.shared.createProfile(named: name)
        if let profile = ProfileManager.shared.activate(profileNamed: name) {
            screenManager?.reloadAll(with: profile)
        }
        rebuildMenu()
    }

    @objc private func renameActiveProfile() {
        let current = ProfileManager.shared.activeProfileName
        let alert = NSAlert()
        alert.messageText = "Rename Profile"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        textField.stringValue = current
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != current, !ProfileManager.shared.profileNames.contains(name) else { return }

        ProfileManager.shared.renameProfile(from: current, to: name)
        rebuildMenu()
    }

    @objc private func deleteProfile(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        ProfileManager.shared.deleteProfile(named: name)
        rebuildMenu()
    }

    @objc private func syncFromAppleDock() {
        let alert = NSAlert()
        alert.messageText = "Replace “\(ProfileManager.shared.activeProfileName)” with your Apple Dock?"
        alert.informativeText = "This overwrites the current profile’s apps with the ones in your Apple Dock. This can’t be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        screenManager?.syncAllFromAppleDock()
    }

    @objc private func setIconSize(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        UserDefaults.standard.set(value, forKey: "iconSize")
        screenManager?.relayoutAll()
        rebuildMenu()
    }

    @objc private func enableBadges() {
        AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true] as CFDictionary)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("MegaDock: launch at login toggle failed: \(error)")
        }
        rebuildMenu()
    }
}
