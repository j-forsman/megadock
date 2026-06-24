# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
# Build release binary and package into MegaDock.app bundle
bash build.sh

# Launch the app
open MegaDock.app

# Kill the running app
pkill MegaDock

# Rebuild and relaunch (typical dev loop)
pkill MegaDock 2>/dev/null; bash build.sh && open MegaDock.app
```

There is no Xcode project — the app is built entirely with `swift build` via SPM. `build.sh` compiles a release binary and wraps it in a hand-crafted `MegaDock.app` bundle with a minimal `Info.plist` (`LSUIElement=true` makes it an agent app with no Dock icon).

There are no tests.

## Architecture

MegaDock is a macOS menu bar agent app (Swift + SwiftUI + AppKit). It shows a floating dock panel on secondary screens, leaving the primary screen to the system Apple Dock.

### Key design decisions

- **Window level**: `CGWindowLevelForKey(.dockWindow) + 1` — sits just above the system Dock so it's never obscured.
- **Primary screen exclusion**: `NSScreen.screens.first` is always the primary (menu bar) screen; MegaDock skips it.
- **Profile system**: Named profiles live in `~/Library/Application Support/MegaDock/profiles/<name>.json`. The active profile name is persisted in `active-profile`. On first launch, migrates from legacy `default-secondary.json` if present.
- **Panel reload**: Switching profiles or syncing from Apple Dock replaces the `NSHostingView` entirely (`DockPanel.mount(profile:)`).
- **Apple Dock reading**: `DockProfile.fromAppleDock` parses `~/Library/Preferences/com.apple.dock.plist` directly.

### Data flow

```
ProfileManager (singleton)
  └── active profile → DockPanel.mount() → NSHostingView<DockView>
                                              ├── DockItemView (icon, label, dot)
                                              └── writes back via ProfileManager.saveActive()

ScreenManager
  ├── observes NSApplication.didChangeScreenParametersNotification
  ├── creates/destroys DockPanel per non-primary screen
  └── calls reloadAll(with:) on profile switch

AppDelegate
  ├── menu bar item → rebuildMenu()
  └── owns ScreenManager
```

### File responsibilities

| File | Responsibility |
|------|---------------|
| `AppDelegate.swift` | Menu bar setup, profile switching UI, launch-at-login |
| `ScreenManager.swift` | Display connect/disconnect, one `DockPanel` per secondary screen |
| `DockPanel.swift` | `NSPanel` configuration, mounts SwiftUI view |
| `DockView.swift` | SwiftUI dock UI, drag-to-reorder, add/remove apps |
| `ProfileManager.swift` | Named profile CRUD, active profile persistence |
| `ProfileStore.swift` | `DockItem` / `DockProfile` models, Apple Dock plist parsing |
| `RunningAppsMonitor.swift` | `ObservableObject` watching `NSWorkspace` for running apps |
| `VisualEffectBackground.swift` | `NSViewRepresentable` wrapping `NSVisualEffectView` for glass effect |
