import Foundation
import AppKit
import ServiceManagement

final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let d = UserDefaults.standard
    
    @Published var radius: CGFloat { didSet { d.set(Double(radius), forKey: "r") } }
    @Published var cardSize: CGFloat { didSet { d.set(Double(cardSize), forKey: "cs") } }
    @Published var hoverScale: CGFloat { didSet { d.set(Double(hoverScale), forKey: "hs") } }
    @Published var iconScale: CGFloat { didSet { d.set(Double(iconScale), forKey: "is") } }
    @Published var animSpeed: Double { didSet { d.set(animSpeed, forKey: "as") } }
    @Published var menuStyle: Int { didSet { d.set(menuStyle, forKey: "ms") } } // 0=cards, 1=ring, 2=overlap
    @Published var cardGap: CGFloat { didSet { d.set(Double(cardGap), forKey: "cg") } }
    @Published var ringThickness: CGFloat { didSet { d.set(Double(ringThickness), forKey: "rt") } }
    @Published var showLabels: Bool { didSet { d.set(showLabels, forKey: "sl") } }
    @Published var showActions: Bool { didSet { d.set(showActions, forKey: "sa") } }
    @Published var haptics: Bool { didSet { d.set(haptics, forKey: "hp") } }
    @Published var hapticStyle: Int { didSet { d.set(hapticStyle, forKey: "hps") } } // 0=light 1=medium 2=strong
    @Published var lowPower: Bool { didSet { d.set(lowPower, forKey: "lp") } }
    @Published var launchAtLogin: Bool {
        didSet {
            d.set(launchAtLogin, forKey: "lal")
            if #available(macOS 13.0, *) {
                try? SMAppService.mainApp.register()
                if !launchAtLogin { try? SMAppService.mainApp.unregister() }
            }
        }
    }
    @Published var hotkeyMod1: Int { didSet { d.set(hotkeyMod1, forKey: "hm1"); notify() } }
    @Published var hotkeyMod2: Int { didSet { d.set(hotkeyMod2, forKey: "hm2"); notify() } }
    @Published var enabledActions: [String] { didSet { d.set(enabledActions, forKey: "ea"); notify() } }
    @Published var pinnedAppPaths: [String] { didSet { d.set(pinnedAppPaths, forKey: "pa"); notify() } }
    @Published var pinnedFolderPaths: [String] { didSet { d.set(pinnedFolderPaths, forKey: "pf"); notify() } }
    
    private func notify() { NotificationCenter.default.post(name: .settingsChanged, object: nil) }
    
    private init() {
        let r = d.double(forKey: "r"); radius = r > 0 ? r : 130
        let cs = d.double(forKey: "cs"); cardSize = cs > 0 ? cs : 72
        let hs = d.double(forKey: "hs"); hoverScale = hs > 0 ? hs : 1.2
        let is_ = d.double(forKey: "is"); iconScale = is_ > 0 ? is_ : 0.6
        let a = d.double(forKey: "as"); animSpeed = a > 0 ? a : 1.0
        menuStyle = d.integer(forKey: "ms")
        let cg = d.object(forKey: "cg"); cardGap = cg != nil ? CGFloat(d.double(forKey: "cg")) : 0
        let rt = d.double(forKey: "rt"); ringThickness = rt > 0 ? rt : 36
        showLabels = d.object(forKey: "sl") == nil ? true : d.bool(forKey: "sl")
        showActions = d.object(forKey: "sa") == nil ? true : d.bool(forKey: "sa")
        haptics = d.object(forKey: "hp") == nil ? true : d.bool(forKey: "hp")
        hapticStyle = d.object(forKey: "hps") == nil ? 1 : d.integer(forKey: "hps")
        lowPower = d.bool(forKey: "lp")
        launchAtLogin = d.bool(forKey: "lal")
        hotkeyMod1 = d.object(forKey: "hm1") == nil ? 0 : d.integer(forKey: "hm1")
        hotkeyMod2 = d.object(forKey: "hm2") == nil ? 2 : d.integer(forKey: "hm2")
        enabledActions = d.stringArray(forKey: "ea") ?? ["downloads","documents","desktop","applications"]
        pinnedAppPaths = d.stringArray(forKey: "pa") ?? Self.defaultApps()
        pinnedFolderPaths = d.stringArray(forKey: "pf") ?? []
    }
    
    func resetToDefaults() {
        radius=130;cardSize=72;hoverScale=1.2;iconScale=0.6;animSpeed=1;menuStyle=0;cardGap=0;ringThickness=36;showLabels=true;showActions=true;haptics=true;hapticStyle=1;lowPower=false;launchAtLogin=false;hotkeyMod1=0;hotkeyMod2=2
        enabledActions=["downloads","documents","desktop","applications"]
        pinnedAppPaths=Self.defaultApps()
        pinnedFolderPaths=[]
    }
    
    private static func defaultApps() -> [String] {
        ["/Applications/Safari.app","/Applications/Google Chrome.app",
         "/System/Applications/Messages.app","/Applications/Telegram.app",
         "/System/Applications/Mail.app","/System/Applications/Notes.app",
         "/System/Applications/System Settings.app","/Applications/Spotify.app",
         "/System/Applications/Music.app","/Applications/Visual Studio Code.app",
         "/System/Applications/Finder.app","/System/Applications/Calendar.app",
         "/Applications/Slack.app","/Applications/Discord.app",
         "/System/Applications/Terminal.app","/System/Applications/Photos.app"
        ].filter { FileManager.default.fileExists(atPath: $0) }
    }
    
    private static let modFlags: [NSEvent.ModifierFlags] = [.command,.control,.option,.shift]
    private static let modLabels = ["⌘","⌃","⌥","⇧"]
    var hotkeyModifiers: NSEvent.ModifierFlags { [Self.modFlags[hotkeyMod1], Self.modFlags[hotkeyMod2]] }
    var hotkeyLabel: String { Self.modLabels[hotkeyMod1]+Self.modLabels[hotkeyMod2] }
    static var modifierOptions: [String] { modLabels }
}

extension Notification.Name {
    static let settingsChanged = Notification.Name("sc")
    static let openSettings = Notification.Name("os")
}
