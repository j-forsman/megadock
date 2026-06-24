# MegaDock

A lightweight macOS menu bar app that puts a custom dock on your secondary screen, leaving the native Apple Dock on your primary display.

<!-- screenshot here -->

## Why

macOS only shows the Apple Dock on one screen at a time. If you work with an ultrawide or external monitor as your main workspace, the dock is always one display away. MegaDock adds a persistent glass-pill dock to every secondary screen, with its own app list and profile system.

## Features

- **Glass pill dock** on all secondary screens — stays above every window, never auto-hides
- **Profiles** — create named app lists and switch between them from the menu bar
- **Sync from Apple Dock** — one click to mirror your current Apple Dock layout
- **Drag to reorder** icons within the dock
- **Add / remove** apps via right-click or the + button
- **Running indicator** — dot below icons of running apps
- **Hover labels** — app name appears above icon on hover, Apple Dock style
- Display connect/disconnect handled automatically

## Requirements

- macOS 13 Ventura or later
- Xcode Command Line Tools (`xcode-select --install`)

## Build & run

```bash
# Clone
git clone https://github.com/yourusername/megadock.git
cd megadock

# Build and launch
bash build.sh
open MegaDock.app
```

The build script compiles a release binary with Swift Package Manager and assembles a minimal `.app` bundle. There is no Xcode project.

```bash
# Rebuild and relaunch (typical dev loop)
pkill MegaDock 2>/dev/null; bash build.sh && open MegaDock.app

# Kill the running app
pkill MegaDock
```

## Usage

MegaDock lives in the menu bar (no Dock icon). On first launch it reads your Apple Dock and creates a "Default" profile on every connected secondary screen.

**Profiles** — open the menu bar icon to create, switch, or delete profiles. Each profile is a JSON file in `~/Library/Application Support/MegaDock/profiles/`.

**Add an app** — click the `+` button in the dock or drag an `.app` from Finder.

**Remove an app** — right-click the icon → Remove from Dock.

**Sync** — Menu bar → Sync from Apple Dock replaces the active profile with your current Apple Dock layout.

## Architecture

Built with Swift + SwiftUI + AppKit, no Xcode project — compiled entirely via `swift build`.

| File | Responsibility |
|------|---------------|
| `AppDelegate.swift` | Menu bar, profile switching UI, launch-at-login |
| `ScreenManager.swift` | Display connect/disconnect, one panel per secondary screen |
| `DockPanel.swift` | `NSPanel` configuration and `DockState` observable model |
| `DockView.swift` | SwiftUI dock UI, drag-to-reorder, add/remove |
| `ProfileManager.swift` | Named profile CRUD, active profile persistence |
| `ProfileStore.swift` | `DockItem` / `DockProfile` models, Apple Dock plist parsing |
| `RunningAppsMonitor.swift` | Tracks running apps via `NSWorkspace` |
| `VisualEffectBackground.swift` | `NSVisualEffectView` wrapper for glass effect |

The panel sits at `CGWindowLevelForKey(.dockWindow) + 1` so it stays above the system Dock without covering other windows. `NSScreen.screens.first` (not `NSScreen.main`) is used to identify the primary screen reliably regardless of which window has focus.

## License

MIT
