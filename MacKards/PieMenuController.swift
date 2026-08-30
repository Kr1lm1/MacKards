import AppKit
import SwiftUI

final class PieMenuState: ObservableObject {
    static let shared = PieMenuState()
    @Published var hoveredApp: AppItem?
    @Published var hoveredAction: QuickAction?
    @Published var isClosing = false
    @Published var isSubmenuClosing = false
}

final class PieMenuController {
    private var window: NSWindow?
    private var submenuWindow: NSWindow?
    private var submenuState = SubmenuState()
    private var visible = false
    private var menuCenter: NSPoint = .zero
    private var submenuGroupIndex: Int?
    private var apps: [AppItem] = []
    private var mainApps: [AppItem] = []
    private var mainActions: [QuickAction] = []
    private var mainGroups: [AppGroup] = []
    private var cacheTime: Date = .distantPast
    private var submenuOpenTask: DispatchWorkItem?
    private var submenuCloseTask: DispatchWorkItem?
    private let iconCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 128
        return cache
    }()

    init() {
        NotificationCenter.default.addObserver(forName: .settingsChanged, object: nil, queue: .main) { [weak self] _ in
            self?.cacheTime = .distantPast
            self?.iconCache.removeAllObjects()
        }
    }

    func show() {
        if let w = window { w.orderOut(nil) }
        window = nil
        visible = true

        let st = PieMenuState.shared
        st.hoveredApp = nil
        st.hoveredAction = nil
        st.isClosing = false

        let s = AppSettings.shared
        let mouse = NSEvent.mouseLocation
        menuCenter = mouse

        let apps = loadApps()
        var actions = s.showActions ? QuickAction.allActions.filter { s.enabledActions.contains($0.id) } : []
        if s.showActions && s.showActionIcons {
            actions.append(contentsOf: actionIcons())
        }
        for path in s.pinnedFolderPaths {
            let url = URL(fileURLWithPath: path)
            actions.append(QuickAction(
                id: "folder_\(path)",
                name: url.lastPathComponent,
                icon: "",
                targetURL: url,
                folderImage: rasterizedIcon(for: path)
            ) {
                NSWorkspace.shared.open(url)
            })
        }
        let groups = s.pinnedGroups

        self.mainApps = apps
        self.mainActions = actions
        self.mainGroups = groups

        let totalMain = apps.count + actions.count + groups.count
        guard totalMain > 0 else { visible = false; return }
        let n = CGFloat(totalMain)

        let circ = 2 * .pi * s.radius
        let card = min(circ / n, s.cardSize)
        let side = s.radius * 2 + card + 180

        let frame = NSRect(x: mouse.x - side / 2, y: mouse.y - side / 2, width: side, height: side)
        let win = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        win.level = .floating
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: PieMenuContentView(
            apps: apps,
            actions: actions,
            groups: groups,
            settings: s,
            onSelect: { [weak self] in self?.launchAndClose($0) },
            onAction: { [weak self] act in self?.runActionAndClose(act) },
            onGroup: { [weak self] group in
                guard let self else { return }
                guard let currentGroup = AppSettings.shared.pinnedGroups.first(where: { $0.id == group.id }) else { return }
                let idx = self.mainGroups.firstIndex(where: { $0.id == group.id }) ?? 0
                self.openSubmenu(
                    paths: Array(currentGroup.paths.prefix(8)),
                    totalMain: totalMain,
                    index: self.mainApps.count + self.mainActions.count + idx,
                    cacheIcons: true,
                    onDelete: { appIndex in
                        guard let groupIndex = AppSettings.shared.pinnedGroups.firstIndex(where: { $0.id == group.id }) else { return }
                        var group = AppSettings.shared.pinnedGroups[groupIndex]
                        guard appIndex < group.paths.count else { return }
                        group.paths.remove(at: appIndex)
                        AppSettings.shared.pinnedGroups[groupIndex] = group
                        withAnimation {
                            self.submenuState.apps.remove(at: appIndex)
                            if self.submenuState.apps.isEmpty { self.closeSubmenu() }
                        }
                    }
                )
            },
            onFolder: { [weak self] act in
                guard let self, let url = act.targetURL else { return }
                let idx = self.mainActions.firstIndex(where: { $0.id == act.id }) ?? 0
                let paths = act.id == "trash" ? self.trashContents(url) : self.folderContents(url)
                self.openSubmenu(
                    paths: paths,
                    totalMain: totalMain,
                    index: self.mainApps.count + idx,
                    onDelete: act.id == "trash" ? nil : { fileIndex in
                        guard fileIndex < self.submenuState.apps.count else { return }
                        let fileURL = self.submenuState.apps[fileIndex].url
                        let fm = FileManager.default
                        var removed = false
                        do {
                            try fm.trashItem(at: fileURL, resultingItemURL: nil)
                            removed = true
                        } catch {
                            do { try fm.removeItem(at: fileURL); removed = true } catch {}
                        }
                        guard removed else { return }
                        withAnimation {
                            self.submenuState.apps.remove(at: fileIndex)
                            if self.submenuState.apps.isEmpty { self.closeSubmenu() }
                        }
                    }
                )
            },
            onCloseSubmenu: { [weak self] in self?.closeSubmenu() },
            onLeaveFolderGroup: { [weak self] in self?.scheduleSubmenuClose() }
        ))
        host.frame = NSRect(origin: .zero, size: frame.size)
        win.contentView = host

        self.window = win
        win.orderFrontRegardless()
    }

    func hide() {
        guard visible else { return }
        visible = false

        let st = PieMenuState.shared
        if let app = st.hoveredApp {
            launch(app)
        } else if let act = st.hoveredAction {
            act.action()
        }
        st.hoveredApp = nil
        st.hoveredAction = nil

        cancelSubmenuOpen()
        closeSubmenu()

        let win = self.window
        self.window = nil
        guard let win else { return }

        withAnimation(.easeIn(duration: 0.12)) { st.isClosing = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            win.orderOut(nil)
            st.isClosing = false
        }
    }

    private func runActionAndClose(_ act: QuickAction) {
        act.action()
        hide()
    }

    private func launchAndClose(_ app: AppItem) {
        launch(app)
        hide()
    }

    private func openSubmenu(paths: [String], totalMain: Int, index: Int, cacheIcons: Bool = false, onDelete: ((Int) -> Void)? = nil) {
        if submenuWindow != nil, submenuGroupIndex == index { return }
        cancelSubmenuOpen()
        cancelSubmenuClose()
        submenuGroupIndex = index

        let s = AppSettings.shared
        let apps = paths.prefix(8).compactMap { path -> AppItem? in
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            let url = URL(fileURLWithPath: path)
            return AppItem(
                id: url,
                name: url.deletingPathExtension().lastPathComponent,
                url: url,
                icon: cacheIcons ? appIcon(for: path) : rasterizedIcon(for: path)
            )
        }

        let mainCard = min((2 * .pi * Double(s.radius)) / Double(max(totalMain, 1)), Double(s.cardSize))
        let gapSub = 2.0
        let minRadius = s.radius + s.ringThickness + 3
        let midGapAng = gapSub / Double(minRadius) * 180 / .pi
        let cardSub = mainCard
        let edgePadAng = 0.0
        let radius = minRadius
        let side = radius * 2 + CGFloat(cardSub) + 80
        let frame = NSRect(x: menuCenter.x - side / 2, y: menuCenter.y - side / 2, width: side, height: side)
        let stepDeg = 360.0 / Double(max(totalMain, 1))
        let dir = -90.0 + stepDeg * Double(index) + stepDeg / 2

        submenuState.isClosing = false

        if let win = submenuWindow {
            withAnimation(.easeOut(duration: 0.18)) {
                submenuState.apps = apps
                submenuState.dir = dir
                submenuState.radius = radius
                submenuState.cardSize = CGFloat(cardSub)
                submenuState.edgePadDeg = edgePadAng
                submenuState.midGapDeg = midGapAng
            }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.18
                win.animator().setFrame(frame, display: true)
            })
        } else {
            submenuState.apps = apps
            submenuState.dir = dir
            submenuState.radius = radius
            submenuState.cardSize = CGFloat(cardSub)
            submenuState.edgePadDeg = edgePadAng
            submenuState.midGapDeg = midGapAng

            let task = DispatchWorkItem { [weak self] in
                guard
                    let self,
                    self.visible,
                    self.submenuWindow == nil,
                    self.submenuGroupIndex == index
                else { return }

                let win = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
                win.level = .floating
                win.isOpaque = false
                win.backgroundColor = .clear
                win.hasShadow = false
                win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                win.isReleasedWhenClosed = false
                let host = NSHostingView(rootView: SubmenuView(
                    state: self.submenuState,
                    settings: s,
                    onSelect: { [weak self] app in self?.launchAndClose(app) },
                    onHover: { [weak self] isHovering in
                        guard let self else { return }
                        if isHovering {
                            self.cancelSubmenuClose()
                        } else {
                            self.scheduleSubmenuClose()
                        }
                    },
                    onDelete: onDelete
                ))
                host.frame = NSRect(origin: .zero, size: frame.size)
                win.contentView = host
                self.submenuWindow = win
                win.orderFrontRegardless()
            }
            submenuOpenTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: task)
        }
    }

    private func folderContents(_ url: URL) -> [String] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: url.path) else { return [] }
        return items
            .filter { !$0.hasPrefix(".") }
            .prefix(8)
            .map { url.appendingPathComponent($0).path }
    }

    private func trashContents(_ url: URL) -> [String] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: url.path) else { return [] }
        return items
            .filter { !$0.hasPrefix(".") }
            .compactMap { name -> (path: String, date: Date)? in
                let path = url.appendingPathComponent(name).path
                guard let attrs = try? fm.attributesOfItem(atPath: path),
                      let date = attrs[.modificationDate] as? Date else { return nil }
                return (path, date)
            }
            .sorted { $0.date > $1.date }
            .prefix(5)
            .map { $0.path }
    }

    private func actionIcons() -> [QuickAction] {
        let fm = FileManager.default
        var icons: [QuickAction] = []

        if let trash = fm.urls(for: .trashDirectory, in: .userDomainMask).first {
            icons.append(.init(id: "trash", name: "Trash", icon: "trash", targetURL: trash, folderImage: nil) {
                NSWorkspace.shared.open(trash)
            })
        }

        if let trayURL = trayFolderURL() {
            try? fm.createDirectory(at: trayURL, withIntermediateDirectories: true, attributes: nil)
            icons.append(.init(id: "tray", name: "Tray", icon: "tray", targetURL: trayURL, folderImage: nil) {
                NSWorkspace.shared.open(trayURL)
            })
        }

        return icons
    }

    private func trayFolderURL() -> URL? {
        let fm = FileManager.default
        var url = Bundle.main.bundleURL
        for _ in 0..<6 {
            let packageURL = url.appendingPathComponent("Package.swift")
            if fm.fileExists(atPath: packageURL.path) {
                return url.appendingPathComponent("Tray")
            }
            url = url.deletingLastPathComponent()
        }
        return nil
    }

    private func scheduleSubmenuClose() {
        cancelSubmenuOpen()
        guard submenuWindow != nil else {
            submenuGroupIndex = nil
            return
        }
        guard submenuCloseTask == nil else { return }
        let task = DispatchWorkItem { [weak self] in
            self?.closeSubmenu()
        }
        submenuCloseTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: task)
    }

    private func cancelSubmenuClose() {
        submenuCloseTask?.cancel()
        submenuCloseTask = nil
    }

    private func cancelSubmenuOpen() {
        submenuOpenTask?.cancel()
        submenuOpenTask = nil
    }

    private func closeSubmenu() {
        guard let win = submenuWindow, !submenuState.isClosing else { return }
        cancelSubmenuOpen()
        cancelSubmenuClose()
        // Чтобы метка главного меню не моргала именем элемента подменю во время закрытия
        if let app = PieMenuState.shared.hoveredApp, submenuState.apps.contains(where: { $0.id == app.id }) {
            PieMenuState.shared.hoveredApp = nil
        }
        PieMenuState.shared.isSubmenuClosing = true
        submenuState.isClosing = true
        let closeDuration = 0.3 / max(AppSettings.shared.animSpeed, 0.1) * 2.25
        DispatchQueue.main.asyncAfter(deadline: .now() + closeDuration) { [weak self] in
            guard let self, self.submenuWindow === win else { return }
            self.submenuWindow = nil
            self.submenuGroupIndex = nil
            self.submenuState.isClosing = false
            PieMenuState.shared.isSubmenuClosing = false
            win.orderOut(nil)
        }
    }

    private func rasterizedIcon(for path: String) -> NSImage {
        let source = NSWorkspace.shared.icon(forFile: path)
        source.isTemplate = false
        source.size = NSSize(width: 64, height: 64)
        var rect = NSRect(origin: .zero, size: source.size)
        guard let cgImage = source.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return source }
        let img = NSImage(cgImage: cgImage, size: source.size)
        img.isTemplate = false
        return img
    }

    private func appIcon(for path: String) -> NSImage {
        if let img = iconCache.object(forKey: path as NSString) { return img }
        let img = rasterizedIcon(for: path)
        iconCache.setObject(img, forKey: path as NSString)
        return img
    }

    private func loadApps() -> [AppItem] {
        if Date().timeIntervalSince(cacheTime) > 30 {
            apps = AppSettings.shared.pinnedAppPaths.compactMap { path in
                guard FileManager.default.fileExists(atPath: path) else { return nil }
                let url = URL(fileURLWithPath: path)
                return AppItem(
                    id: url,
                    name: url.deletingPathExtension().lastPathComponent,
                    url: url,
                    icon: appIcon(for: path)
                )
            }
            cacheTime = Date()
        }
        return apps
    }

    private func launch(_ app: AppItem) {
        if app.url.pathExtension == "app" {
            NSWorkspace.shared.openApplication(at: app.url, configuration: .init())
        } else {
            NSWorkspace.shared.open(app.url)
        }
    }
}
