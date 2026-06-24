import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct DockView: View {
    @ObservedObject var state: DockState
    @StateObject private var runningMonitor = RunningAppsMonitor()
    @State private var draggedItem: DockItem? = nil

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 30)
            HStack(alignment: .center, spacing: 6) {
                ForEach(state.profile.items) { item in
                    DockItemView(
                        item: item,
                        isRunning: runningMonitor.runningBundleIDs.contains(item.bundleID),
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

                Button { addApp() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 28, height: 28)
                        .background(.secondary.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Add Application")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .padding(.bottom, 4)
            .onDrop(of: [UTType.plainText], isTargeted: nil) { _ in
                guard draggedItem != nil else { return false }
                draggedItem = nil
                ProfileManager.shared.saveActive(state.profile)
                return true
            }
        }
    }

    private func removeItem(_ item: DockItem) {
        state.profile.items.removeAll { $0.id == item.id }
        ProfileManager.shared.saveActive(state.profile)
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
        guard !state.profile.items.contains(where: { $0.bundleID == bundleID }) else { return }

        state.profile.items.append(DockItem(id: UUID(), bundleID: bundleID, name: name, path: path))
        ProfileManager.shared.saveActive(state.profile)
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
    let onRemove: () -> Void
    @State private var isHovered = false
    @State private var icon: NSImage? = nil

    var body: some View {
        VStack(spacing: 3) {
            Button { item.launch() } label: {
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
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
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
                Button("Open \(item.name)") { item.launch() }
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
}
