import AppKit
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
        screenManager?.syncAllFromAppleDock()
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
