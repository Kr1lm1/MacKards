import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var pieMenu: PieMenuController!
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var settingsWindow: NSWindow?
    private var holding = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "squares.leading.rectangle", accessibilityDescription: "MacKards")
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Hold ⌘⌥ to open", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        
        pieMenu = PieMenuController()
        
        NotificationCenter.default.addObserver(forName: .openSettings, object: nil, queue: .main) { [weak self] _ in
            self?.openSettings()
        }
        
        let cmdOpt: NSEvent.ModifierFlags = [.command, .option]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] e in
            self?.checkFlags(e.modifierFlags, cmdOpt)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] e in
            self?.checkFlags(e.modifierFlags, cmdOpt)
            return e
        }
    }
    
    private func checkFlags(_ flags: NSEvent.ModifierFlags, _ target: NSEvent.ModifierFlags) {
        let active = flags.intersection(.deviceIndependentFlagsMask).contains(target)
        if active && !holding { holding = true; pieMenu.show() }
        else if !active && holding { holding = false; pieMenu.hide() }
    }
    
    @objc private func openSettings() {
        if let w = settingsWindow, w.isVisible {
            w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return
        }
        let w = NSWindow(contentRect: .init(x: 0, y: 0, width: 480, height: 420),
                         styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        w.center(); w.title = "MacKards Settings"
        w.isReleasedWhenClosed = false
        w.contentView = NSHostingView(rootView: SettingsView())
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = w
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
    }
}
