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
    private var menuCenter: NSPoint = .zero
    private var submenuGroupIndex: Int?
    private var apps: [AppItem] = []
    private var mainApps: [AppItem] = []
    private var mainActions: [QuickAction] = []
    private var mainGroups: [AppGroup] = []
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
        menuCenter = mouse
        let apps = loadApps()
        var actions = s.showActions ? QuickAction.allActions.filter { s.enabledActions.contains($0.id) } : []
        for path in s.pinnedFolderPaths {
            let url = URL(fileURLWithPath: path)
            actions.append(QuickAction(id: "folder_\(path)", name: url.lastPathComponent, icon: "", targetURL: url, folderImage: cachedIcon(for: path)) {
                NSWorkspace.shared.open(url)
            })
        }
        let groups = s.pinnedGroups
        self.mainApps = apps
        self.mainActions = actions
        self.mainGroups = groups

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
                guard let self else { return }
                let idx = self.mainGroups.firstIndex(where: { $0.id == group.id }) ?? 0
                self.openSubmenu(group: group, totalMain: self.mainApps.count + self.mainActions.count + self.mainGroups.count, groupIndex: idx)
            },
            onCloseSubmenu: { [weak self] in self?.closeSubmenu() }))
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

    private func openSubmenu(group: AppGroup, totalMain: Int, groupIndex: Int) {
        if submenuWindow != nil, submenuGroupIndex == groupIndex { return }
        if submenuWindow != nil { closeOldSubmenuImmediately() }
        submenuGroupIndex = groupIndex
        let s = AppSettings.shared
        let apps = group.paths.prefix(8).compactMap { path -> AppItem? in
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            let url = URL(fileURLWithPath: path)
            return AppItem(id: url, name: url.deletingPathExtension().lastPathComponent, url: url, icon: cachedIcon(for: path))
        }
        let n = max(apps.count, 1)

        let mainCard = min((2 * .pi * Double(s.radius)) / Double(max(totalMain, 1)), Double(s.cardSize))
        let gapSub = 2.0
        let minRadius = s.radius + s.ringThickness + 12
        let midGapAng = gapSub / Double(minRadius) * 180 / .pi
        let iconAng = mainCard / Double(minRadius) * 180 / .pi
        let cardSub = mainCard
        let edgePadAng = 2.5
        let iconSpanDeg = max(30.0, 2 * edgePadAng + max(0.0, Double(n - 1)) * midGapAng + Double(n) * iconAng)
        let bgPadAng = 1.25
        let bgSpanDeg = min(260.0, iconSpanDeg + 2 * bgPadAng)
        let radius = minRadius

        let side = radius * 2 + CGFloat(cardSub) + 80
        let frame = NSRect(x: menuCenter.x - side/2, y: menuCenter.y - side/2, width: side, height: side)

        let stepDeg = 360.0 / Double(max(totalMain, 1))
        let dir = -90.0 + stepDeg * Double(mainApps.count + mainActions.count + groupIndex) + stepDeg / 2
        let iconStart = dir - iconSpanDeg / 2
        let iconArc = iconStart...(iconStart + iconSpanDeg)
        let bgStart = iconStart - bgPadAng
        let bgArc = bgStart...(bgStart + bgSpanDeg)

        let win = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        win.level = .floating; win.isOpaque = false; win.backgroundColor = .clear
        win.hasShadow = false; win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.isReleasedWhenClosed = false

        let host = NSHostingView(rootView: PieMenuContentView(
            apps: apps, actions: [], groups: [], settings: s,
            onSelect: { [weak self] app in self?.launchAndClose(app) },
            onAction: { _ in }, onGroup: { _ in },
            onCloseSubmenu: {},
            arc: iconArc, bgArc: bgArc, edgePadDeg: edgePadAng, midGapDeg: midGapAng,
            radiusOverride: radius, cardSizeOverride: CGFloat(cardSub)))
        host.frame = NSRect(origin: .zero, size: frame.size)
        win.contentView = host
        self.submenuWindow = win
        win.orderFrontRegardless()

    }

    private func closeOldSubmenuImmediately() {
        guard let win = submenuWindow else { return }
        submenuWindow = nil
        submenuGroupIndex = nil
        win.orderOut(nil)
    }

    private func closeSubmenu() {
        guard let win = submenuWindow else { return }
        submenuWindow = nil
        submenuGroupIndex = nil
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
