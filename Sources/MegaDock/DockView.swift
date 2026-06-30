import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct DockView: View {
    @ObservedObject var state: DockState
    @StateObject private var runningMonitor = RunningAppsMonitor()
    @ObservedObject private var badgeMonitor = BadgeMonitor.shared  // C5: shared across all screens
    @State private var draggedItem: DockItem? = nil

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 30)
            HStack(alignment: .center, spacing: 6) {
                ForEach(state.profile.items) { item in
                    DockItemView(
                        item: item,
                        isRunning: runningMonitor.runningBundleIDs.contains(item.bundleID),
                        badge: badgeMonitor.badges[item.bundleID],
                        onRemove: { removeItem(item) }
                    )
                    .opacity(draggedItem?.id == item.id ? 0.4 : 1.0)
                    .onDrag {
                        draggedItem = item
                        return NSItemProvider(object: item.id.uuidString as NSString)
                    }
                    .onDrop(of: [UTType.plainText], delegate: ReorderDropDelegate(
                        targetItem: item,
                        profile: $state.profile,
                        draggedItem: $draggedItem,
                        onCommit: { ProfileManager.shared.saveActive(state.profile) }
                    ))
                }

                Menu {
                    Button("Browse…") { addApp() }
                    Divider()
                    Button("Finder") { addItem(bundleID: "com.apple.finder", name: "Finder", path: "/System/Library/CoreServices/Finder.app") }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 28, height: 28)
                        .background(.secondary.opacity(0.15), in: Circle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Add Application")
                .accessibilityLabel("Add Application")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .padding(.bottom, 4)
            .onAppear {
                badgeMonitor.start()
            }
            .onDrop(of: [UTType.plainText, UTType.fileURL], isTargeted: nil) { providers in
                if draggedItem != nil {
                    draggedItem = nil
                    ProfileManager.shared.saveActive(state.profile)
                    return true
                }
                return handleExternalDrop(providers)
            }
        }
    }

    private func removeItem(_ item: DockItem) {
        state.profile.items.removeAll { $0.id == item.id }
        ProfileManager.shared.saveActive(state.profile)
    }

    private func addItem(bundleID: String, name: String, path: String) {
        guard !state.profile.items.contains(where: { $0.bundleID == bundleID }) else { return }
        state.profile.items.append(DockItem(id: UUID(), bundleID: bundleID, name: name, path: path))
        ProfileManager.shared.saveActive(state.profile)
    }

    private func handleExternalDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers where provider.canLoadObject(ofClass: URL.self) {
            handled = true
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url, url.pathExtension == "app" else { return }
                DispatchQueue.main.async {
                    let path = url.path
                    let name = url.deletingPathExtension().lastPathComponent
                    let bundleID = Bundle(path: path)?.bundleIdentifier ?? name
                    addItem(bundleID: bundleID, name: name, path: path)
                }
            }
        }
        return handled
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "Choose an application to add to MegaDock"
        panel.prompt = "Add"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let path = url.path
        let name = url.deletingPathExtension().lastPathComponent
        let bundleID = Bundle(path: path)?.bundleIdentifier ?? name
        addItem(bundleID: bundleID, name: name, path: path)
    }
}

struct ReorderDropDelegate: DropDelegate {
    let targetItem: DockItem
    @Binding var profile: DockProfile
    @Binding var draggedItem: DockItem?
    let onCommit: () -> Void

    func dropEntered(info: DropInfo) {
        guard
            let dragged = draggedItem,
            dragged.id != targetItem.id,
            let from = profile.items.firstIndex(where: { $0.id == dragged.id }),
            let to = profile.items.firstIndex(where: { $0.id == targetItem.id })
        else { return }

        withAnimation(.default) {
            profile.items.move(
                fromOffsets: IndexSet(integer: from),
                toOffset: to > from ? to + 1 : to
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        onCommit()
        return true
    }
}

struct DockItemView: View {
    let item: DockItem
    let isRunning: Bool
    let badge: String?
    let onRemove: () -> Void
    @AppStorage("iconSize") private var iconSize: Double = 44
    @State private var isHovered = false
    @State private var icon: NSImage? = nil

    var body: some View {
        VStack(spacing: 3) {
            Button { open() } label: {
                Group {
                    if let icon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Image(systemName: "app")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                }
                .frame(width: iconSize, height: iconSize)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.name)
            .accessibilityValue(isRunning ? "Running" : "")
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                        .offset(x: 8, y: -4)
                }
            }
            .overlay(alignment: .top) {
                Text(item.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background {
                        VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .offset(y: -30)
                    .opacity(isHovered ? 1 : 0)
                    .animation(.easeOut(duration: 0.1), value: isHovered)
                    .allowsHitTesting(false)
            }
            .contextMenu {
                Button("Open \(item.name)") { open() }
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
                }
                if isRunning {
                    Divider()
                    Button("Hide") {
                        // C6: target all instances (same bundle ID, different PIDs)
                        NSRunningApplication.runningApplications(withBundleIdentifier: item.bundleID)
                            .forEach { $0.hide() }
                    }
                    Button("Quit \(item.name)") {
                        NSRunningApplication.runningApplications(withBundleIdentifier: item.bundleID)
                            .forEach { $0.terminate() }
                    }
                    Button("Force Quit \(item.name)", role: .destructive) {
                        // C7: confirm before destroying unsaved work
                        let alert = NSAlert()
                        alert.messageText = "Force quit \(item.name)?"
                        alert.informativeText = "Unsaved changes will be lost."
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "Force Quit")
                        alert.addButton(withTitle: "Cancel")
                        guard alert.runModal() == .alertFirstButtonReturn else { return }
                        NSRunningApplication.runningApplications(withBundleIdentifier: item.bundleID)
                            .forEach { $0.forceTerminate() }
                    }
                }
                Divider()
                Button("Remove from Dock") { onRemove() }
            }
            .onHover { isHovered = $0 }

            Circle()
                .fill(.primary.opacity(0.7))
                .frame(width: 4, height: 4)
                .opacity(isRunning ? 1 : 0)
        }
        .task(id: item.path) {
            let img = NSWorkspace.shared.icon(forFile: item.path)
            let copy = img.copy() as? NSImage ?? img
            copy.size = NSSize(width: 256, height: 256)
            icon = copy
        }
    }

    private func open() {
        guard FileManager.default.fileExists(atPath: item.path) else {
            let alert = NSAlert()
            alert.messageText = "“\(item.name)” can’t be found."
            alert.informativeText = "It may have been moved or uninstalled. Remove it from the dock?"
            alert.addButton(withTitle: "Remove")
            alert.addButton(withTitle: "Keep")
            if alert.runModal() == .alertFirstButtonReturn { onRemove() }
            return
        }
        item.launch()
    }
}
