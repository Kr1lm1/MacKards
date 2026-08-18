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
        let st = PieMenuState.shared; st.hoveredApp = nil; st.hoveredAction = nil; st.isClosing = false
        
        let s = AppSettings.shared
        let mouse = NSEvent.mouseLocation
        let apps = loadApps()
        var actions = s.showActions ? QuickAction.allActions.filter { s.enabledActions.contains($0.id) } : []
        // Add pinned folders as actions
        for path in s.pinnedFolderPaths {
            let url = URL(fileURLWithPath: path)
            let folderIcon = NSWorkspace.shared.icon(forFile: path)
            folderIcon.size = NSSize(width: 64, height: 64)
            actions.append(QuickAction(id: "folder_\(path)", name: url.lastPathComponent, icon: "", targetURL: url, folderImage: folderIcon) {
                NSWorkspace.shared.open(url)
            })
        }
        let n = CGFloat(apps.count + actions.count)
        guard n > 0 else { visible = false; return }
        
        let circ = 2 * .pi * s.radius
        let card = min(circ / n, s.cardSize)
        let side = s.radius * 2 + card + 60
        
        let frame = NSRect(x: mouse.x - side/2, y: mouse.y - side/2, width: side, height: side)
        let win = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        win.level = .floating; win.isOpaque = false; win.backgroundColor = .clear
        win.hasShadow = false; win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.isReleasedWhenClosed = false
        
        let host = NSHostingView(rootView: PieMenuContentView(apps: apps, actions: actions, settings: s,
            onSelect: { [weak self] in self?.launch($0) }, onAction: { $0.action() }))
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
        
        let win = self.window; self.window = nil
        guard let win else { return }
        withAnimation(.easeIn(duration: 0.1)) { st.isClosing = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { win.orderOut(nil); st.isClosing = false }
    }
    
    private func loadApps() -> [AppItem] {
        if Date().timeIntervalSince(cacheTime) > 30 {
            apps = AppSettings.shared.pinnedAppPaths.compactMap { path in
                guard FileManager.default.fileExists(atPath: path) else { return nil }
                let url = URL(fileURLWithPath: path)
                let icon = NSWorkspace.shared.icon(forFile: path)
                icon.size = NSSize(width: 64, height: 64)
                return AppItem(id: url, name: url.deletingPathExtension().lastPathComponent, url: url, icon: icon)
            }
            cacheTime = Date()
        }
        return apps
    }
    
    private func launch(_ app: AppItem) {
        NSWorkspace.shared.openApplication(at: app.url, configuration: .init())
    }
}
