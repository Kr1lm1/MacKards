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
    private var submenuMonitor: Any?
    private var submenuGlobalMonitor: Any?
    private var submenuIconRects: [CGRect] = []
    private var lastSubmenuClick = Date.distantPast
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
                self.openSubmenu(group: group, at: NSEvent.mouseLocation, totalMain: self.mainApps.count + self.mainActions.count + self.mainGroups.count, groupIndex: idx)
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

    private func openSubmenu(group: AppGroup, at point: NSPoint, totalMain: Int, groupIndex: Int) {
        if submenuWindow != nil, submenuGroupIndex == groupIndex { closeSubmenu(); return }
        closeSubmenu()
        submenuGroupIndex = groupIndex
        let s = AppSettings.shared
        let apps = group.paths.compactMap { path -> AppItem? in
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            let url = URL(fileURLWithPath: path)
            return AppItem(id: url, name: url.deletingPathExtension().lastPathComponent, url: url, icon: cachedIcon(for: path))
        }
        let n = max(apps.count, 1)

        // Keep the same density (card size + gap) as the main ring
        let mainCard = min((2 * .pi * Double(s.radius)) / Double(max(totalMain, 1)), Double(s.cardSize))
        let gap = Double(s.cardGap)
        let stepDeg = 360.0 / Double(max(totalMain, 1))
        let spanDeg = max(15.0, min(360.0, Double(n) * stepDeg)) / 2.0
        let spanRad = spanDeg * .pi / 180
        let arcLen = Double(n) * (mainCard + gap)
        let computedRadius = CGFloat(arcLen / spanRad)
        let minRadius = s.radius + s.ringThickness * 0.22 + 1
        let radius = max(computedRadius, minRadius)

        let side = radius * 2 + CGFloat(mainCard) + 60
        let frame = NSRect(x: menuCenter.x - side/2, y: menuCenter.y - side/2, width: side, height: side)

        let dir = atan2(menuCenter.y - point.y, point.x - menuCenter.x) * 180 / .pi
        let start = dir - spanDeg / 2
        let arcRange = start...(start + spanDeg)

        let win = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        win.level = .floating; win.isOpaque = false; win.backgroundColor = .clear
        win.hasShadow = false; win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.isReleasedWhenClosed = false

        let host = NSHostingView(rootView: PieMenuContentView(
            apps: apps, actions: [], groups: [], settings: s,
            onSelect: { [weak self] app in self?.launchAndClose(app) },
            onAction: { _ in }, onGroup: { _ in },
            arc: arcRange, radiusOverride: radius, cardSizeOverride: CGFloat(mainCard)))
        host.frame = NSRect(origin: .zero, size: frame.size)
        win.contentView = host
        self.submenuWindow = win
        win.orderFrontRegardless()

        let nn = Double(apps.count)
        var rects: [CGRect] = []
        for i in 0..<apps.count {
            let aa = (dir - spanDeg/2) + (spanDeg/max(nn, 1)) * Double(i) + (spanDeg/max(nn, 1))/2
            let rad = aa * .pi/180
            let icx = menuCenter.x + CGFloat(cos(rad) * Double(radius))
            let icy = menuCenter.y + CGFloat(sin(rad) * Double(radius))
            let half = CGFloat(mainCard)/2 + 8
            rects.append(CGRect(x: icx - half, y: icy - half, width: half*2, height: half*2))
        }
        self.submenuIconRects = rects

        submenuMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] e in
            guard let self else { return e }
            let pt = NSEvent.mouseLocation
            if self.submenuIconRects.contains(where: { $0.contains(pt) }) { return e }
            self.handleSubmenuClick(pt)
            return nil
        }
        submenuGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            guard let self else { return }
            let pt = NSEvent.mouseLocation
            if self.submenuIconRects.contains(where: { $0.contains(pt) }) { return }
            self.handleSubmenuClick(pt)
        }
    }

    private func groupIndexAt(_ pt: NSPoint) -> Int? {
        let s = AppSettings.shared
        let totalMain = mainApps.count + mainActions.count + mainGroups.count
        guard totalMain > 0 else { return nil }
        for j in 0..<mainGroups.count {
            let i = mainApps.count + mainActions.count + j
            let step = 360.0 / Double(totalMain)
            let startA = -90.0 - step * Double(totalMain - 1) / 2
            let ang = (startA + step * Double(i)) * .pi / 180
            let cardMain = min((2 * CGFloat.pi * s.radius) / CGFloat(totalMain), CGFloat(s.cardSize))
            let px = menuCenter.x + CGFloat(cos(ang)) * s.radius
            let py = menuCenter.y + CGFloat(sin(ang)) * s.radius
            let r = CGRect(x: px - cardMain/2, y: py - cardMain/2, width: cardMain, height: cardMain)
            if r.contains(pt) { return j }
        }
        return nil
    }

    private func handleSubmenuClick(_ pt: NSPoint) {
        let now = Date()
        guard now.timeIntervalSince(lastSubmenuClick) > 0.15 else { return }
        lastSubmenuClick = now
        if submenuIconRects.contains(where: { $0.contains(pt) }) { return }
        if let g = groupIndexAt(pt) {
            if g == submenuGroupIndex { closeSubmenu() }
            else { openSubmenu(group: mainGroups[g], at: pt, totalMain: mainApps.count + mainActions.count + mainGroups.count, groupIndex: g) }
            return
        }
        closeSubmenu()
    }

    private func closeSubmenu() {
        if let m = submenuMonitor { NSEvent.removeMonitor(m); submenuMonitor = nil }
        if let m = submenuGlobalMonitor { NSEvent.removeMonitor(m); submenuGlobalMonitor = nil }
        submenuIconRects = []
        submenuGroupIndex = nil
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
