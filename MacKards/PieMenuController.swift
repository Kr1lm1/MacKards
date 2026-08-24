import AppKit
import SwiftUI

final class PieMenuState: ObservableObject {
    static let shared = PieMenuState()
    @Published var hoveredApp: AppItem?
    @Published var hoveredAction: QuickAction?
    @Published var isClosing = false
}

final class PieMenuController {
    private var window: NSWindow?
    private var submenuWindow: NSWindow?
    private var visible = false
    private var apps: [AppItem] = []
    private var cacheTime: Date = .distantPast
    private let iconCache = NSCache<NSString, NSImage>()

    init() {
        NotificationCenter.default.addObserver(forName: .settingsChanged, object: nil, queue: .main) { [weak self] _ in
            self?.cacheTime = .distantPast
            self?.iconCache.removeAllObjects()
        }
    }

    func show() {
        if let w = window { w.orderOut(nil) }
        window = nil; visible = true
        let st = PieMenuState.shared; st.hoveredApp = nil; st.hoveredAction = nil; st.isClosing = false

        let s = AppSettings.shared
        let mouse = NSEvent.mouseLocation
        let apps = loadApps()
        var actions = s.showActions ? QuickAction.allActions.filter { s.enabledActions.contains($0.id) } : []
        for path in s.pinnedFolderPaths {
            let url = URL(fileURLWithPath: path)
            actions.append(QuickAction(id: "folder_\(path)", name: url.lastPathComponent, icon: "", targetURL: url, folderImage: cachedIcon(for: path)) {
                NSWorkspace.shared.open(url)
            })
        }
        let groups = s.pinnedGroups

        let n = CGFloat(apps.count + actions.count + groups.count)
        guard n > 0 else { visible = false; return }

        let circ = 2 * .pi * s.radius
        let card = min(circ / n, s.cardSize)
        let side = s.radius * 2 + card + 60

        let frame = NSRect(x: mouse.x - side/2, y: mouse.y - side/2, width: side, height: side)
        let win = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        win.level = .floating; win.isOpaque = false; win.backgroundColor = .clear
        win.hasShadow = false; win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.isReleasedWhenClosed = false

        let host = NSHostingView(rootView: PieMenuContentView(
            apps: apps, actions: actions, groups: groups, settings: s,
            onSelect: { [weak self] in self?.launchAndClose($0) },
            onAction: { [weak self] act in self?.runActionAndClose(act) },
            onGroup: { [weak self] group in
                self?.openSubmenu(group: group, at: NSEvent.mouseLocation)
            }))
        host.frame = NSRect(origin: .zero, size: frame.size)
        win.contentView = host
        self.window = win
        win.orderFrontRegardless()
    }

    func hide() {
        guard visible else { return }
        visible = false
        let st = PieMenuState.shared
        if let app = st.hoveredApp { launch(app) }
        else if let act = st.hoveredAction { act.action() }
        st.hoveredApp = nil; st.hoveredAction = nil
        closeSubmenu()

        let win = self.window; self.window = nil
        guard let win else { return }
        withAnimation(.easeIn(duration: 0.08)) { st.isClosing = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { win.orderOut(nil); st.isClosing = false }
    }

    private func runActionAndClose(_ act: QuickAction) {
        act.action()
        hide()
    }

    private func launchAndClose(_ app: AppItem) {
        launch(app)
        hide()
    }

    private func openSubmenu(group: AppGroup, at point: NSPoint) {
        closeSubmenu()
        let s = AppSettings.shared
        let apps = group.paths.compactMap { path -> AppItem? in
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            let url = URL(fileURLWithPath: path)
            return AppItem(id: url, name: url.deletingPathExtension().lastPathComponent, url: url, icon: cachedIcon(for: path))
        }
        guard !apps.isEmpty else { return }

        let r = s.radius * 1.5
        let card = min(2 * .pi * r / CGFloat(apps.count), s.cardSize)
        let side = r * 2 + card + 60
        let frame = NSRect(x: point.x - side/2, y: point.y - side/2, width: side, height: side)

        let win = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        win.level = .floating; win.isOpaque = false; win.backgroundColor = .clear
        win.hasShadow = false; win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.isReleasedWhenClosed = false

        let host = NSHostingView(rootView: PieMenuContentView(
            apps: apps, actions: [], groups: [], settings: s,
            onSelect: { [weak self] app in self?.launchAndClose(app) },
            onAction: { _ in }, onGroup: { _ in },
            radiusOverride: r))
        host.frame = NSRect(origin: .zero, size: frame.size)
        win.contentView = host
        self.submenuWindow = win
        win.orderFrontRegardless()
    }

    private func closeSubmenu() {
        guard let win = submenuWindow else { return }
        submenuWindow = nil
        win.orderOut(nil)
    }

    private func cachedIcon(for path: String) -> NSImage {
        if let img = iconCache.object(forKey: NSString(string: path)) { return img }
        let img = NSWorkspace.shared.icon(forFile: path)
        img.size = NSSize(width: 64, height: 64)
        iconCache.setObject(img, forKey: NSString(string: path))
        return img
    }

    private func loadApps() -> [AppItem] {
        if Date().timeIntervalSince(cacheTime) > 30 {
            apps = AppSettings.shared.pinnedAppPaths.compactMap { path in
                guard FileManager.default.fileExists(atPath: path) else { return nil }
                let url = URL(fileURLWithPath: path)
                return AppItem(id: url, name: url.deletingPathExtension().lastPathComponent, url: url, icon: cachedIcon(for: path))
            }
            cacheTime = Date()
        }
        return apps
    }

    private func launch(_ app: AppItem) {
        NSWorkspace.shared.openApplication(at: app.url, configuration: .init())
    }
}
