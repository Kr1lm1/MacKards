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
    private var visible = false
    private var apps: [AppItem] = []
    private var cacheTime: Date = .distantPast
    
    init() {
        NotificationCenter.default.addObserver(forName: .settingsChanged, object: nil, queue: .main) { [weak self] _ in
            self?.cacheTime = .distantPast
        }
    }
    
    func show() {
        if let w = window { w.orderOut(nil) }
        window = nil; visible = true
        PieMenuState.shared.hoveredApp = nil
        PieMenuState.shared.hoveredAction = nil
        PieMenuState.shared.isClosing = false
        
        let s = AppSettings.shared
        let mouse = NSEvent.mouseLocation
        let apps = loadApps()
        let actions = s.showActions ? QuickAction.allActions.filter { s.enabledActions.contains($0.id) } : []
        let n = CGFloat(apps.count + actions.count)
        
        let circ = 2.0 * .pi * s.radius
        let card = min((circ - 0.5 * n) / n, s.cardSize)
        let side = s.radius * 2 + card + 60
        
        let frame = NSRect(x: mouse.x - side/2, y: mouse.y - side/2, width: side, height: side)
        let win = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        win.level = .floating
        win.isOpaque = false; win.backgroundColor = .clear; win.hasShadow = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.isReleasedWhenClosed = false
        
        let view = PieMenuContentView(apps: apps, actions: actions, settings: s,
                                       onSelect: { [weak self] in self?.launch($0) },
                                       onAction: { $0.action() })
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: frame.size)
        win.contentView = host
        self.window = win
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }
    
    func hide() {
        guard visible else { return }
        visible = false
        
        if let app = PieMenuState.shared.hoveredApp { launch(app) }
        else if let act = PieMenuState.shared.hoveredAction { act.action() }
        PieMenuState.shared.hoveredApp = nil; PieMenuState.shared.hoveredAction = nil
        
        let win = self.window
        self.window = nil
        if let win {
            withAnimation(.easeIn(duration: 0.1)) { PieMenuState.shared.isClosing = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                win.orderOut(nil)
                PieMenuState.shared.isClosing = false
            }
        }
    }
    
    private func loadApps() -> [AppItem] {
        if Date().timeIntervalSince(cacheTime) > 30 {
            let s = AppSettings.shared
            let paths = s.pinnedAppPaths
            if paths.isEmpty { apps = AppFinder.shared.getFrequentApps(limit: s.appCount) }
            else {
                apps = paths.prefix(s.appCount).compactMap { path in
                    guard FileManager.default.fileExists(atPath: path) else { return nil }
                    let url = URL(fileURLWithPath: path)
                    let icon = NSWorkspace.shared.icon(forFile: path)
                    icon.size = NSSize(width: 64, height: 64)
                    return AppItem(id: url, name: url.deletingPathExtension().lastPathComponent, url: url, icon: icon)
                }
            }
            cacheTime = Date()
        }
        return apps
    }
    
    private func launch(_ app: AppItem) {
        NSWorkspace.shared.openApplication(at: app.url, configuration: .init())
    }
}
