import Foundation
import AppKit

final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let d = UserDefaults.standard
    
    @Published var radius: CGFloat { didSet { d.set(Double(radius), forKey: "r") } }
    @Published var cardSize: CGFloat { didSet { d.set(Double(cardSize), forKey: "cs") } }
    @Published var hoverScale: CGFloat { didSet { d.set(Double(hoverScale), forKey: "hs") } }
    @Published var animSpeed: Double { didSet { d.set(animSpeed, forKey: "as") } }
    @Published var showLabels: Bool { didSet { d.set(showLabels, forKey: "sl") } }
    @Published var showActions: Bool { didSet { d.set(showActions, forKey: "sa") } }
    @Published var haptics: Bool { didSet { d.set(haptics, forKey: "hp") } }
    @Published var lowPower: Bool { didSet { d.set(lowPower, forKey: "lp") } }
    @Published var hotkeyMod1: Int { didSet { d.set(hotkeyMod1, forKey: "hm1"); notify() } }
    @Published var hotkeyMod2: Int { didSet { d.set(hotkeyMod2, forKey: "hm2"); notify() } }
    @Published var enabledActions: [String] { didSet { d.set(enabledActions, forKey: "ea"); notify() } }
    @Published var pinnedAppPaths: [String] { didSet { d.set(pinnedAppPaths, forKey: "pa"); notify() } }
    
    private func notify() { NotificationCenter.default.post(name: .settingsChanged, object: nil) }
    
    private init() {
        let r = d.double(forKey: "r"); radius = r > 0 ? r : 130
        let cs = d.double(forKey: "cs"); cardSize = cs > 0 ? cs : 72
        let hs = d.double(forKey: "hs"); hoverScale = hs > 0 ? hs : 1.08
        let a = d.double(forKey: "as"); animSpeed = a > 0 ? a : 1.0
        showLabels = d.object(forKey: "sl") == nil ? true : d.bool(forKey: "sl")
        showActions = d.object(forKey: "sa") == nil ? true : d.bool(forKey: "sa")
        haptics = d.object(forKey: "hp") == nil ? true : d.bool(forKey: "hp")
        lowPower = d.bool(forKey: "lp")
        hotkeyMod1 = d.object(forKey: "hm1") == nil ? 0 : d.integer(forKey: "hm1")
        hotkeyMod2 = d.object(forKey: "hm2") == nil ? 2 : d.integer(forKey: "hm2")
        enabledActions = d.stringArray(forKey: "ea") ?? ["downloads","documents","desktop","applications"]
        pinnedAppPaths = d.stringArray(forKey: "pa") ?? Self.defaultApps()
    }
    
    func resetToDefaults() {
        radius=130;cardSize=72;hoverScale=1.08;animSpeed=1;showLabels=true;showActions=true;haptics=true;lowPower=false;hotkeyMod1=0;hotkeyMod2=2
        enabledActions=["downloads","documents","desktop","applications"]
        pinnedAppPaths=Self.defaultApps()
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
