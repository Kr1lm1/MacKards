import Foundation
import AppKit

final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let d = UserDefaults.standard
    
    @Published var radius: CGFloat { didSet { d.set(Double(radius), forKey: "r") } }
    @Published var cardSize: CGFloat { didSet { d.set(Double(cardSize), forKey: "cs") } }
    @Published var appCount: Int { didSet { d.set(appCount, forKey: "ac"); notify() } }
    @Published var showLabels: Bool { didSet { d.set(showLabels, forKey: "sl") } }
    @Published var showActions: Bool { didSet { d.set(showActions, forKey: "sa") } }
    @Published var enabledActions: [String] { didSet { d.set(enabledActions, forKey: "ea"); notify() } }
    @Published var pinnedAppPaths: [String] { didSet { d.set(pinnedAppPaths, forKey: "pa"); notify() } }
    
    private func notify() { NotificationCenter.default.post(name: .settingsChanged, object: nil) }
    
    private init() {
        let r = d.double(forKey: "r"); radius = r > 0 ? r : 130
        let cs = d.double(forKey: "cs"); cardSize = cs > 0 ? cs : 72
        let ac = d.integer(forKey: "ac"); appCount = ac > 0 ? ac : 8
        showLabels = d.object(forKey: "sl") == nil ? true : d.bool(forKey: "sl")
        showActions = d.object(forKey: "sa") == nil ? true : d.bool(forKey: "sa")
        enabledActions = d.stringArray(forKey: "ea") ?? ["downloads", "documents", "desktop", "applications"]
        pinnedAppPaths = d.stringArray(forKey: "pa") ?? Self.defaultApps()
    }
    
    func resetToDefaults() {
        radius = 130; cardSize = 72; appCount = 8; showLabels = true; showActions = true
        enabledActions = ["downloads", "documents", "desktop", "applications"]
        pinnedAppPaths = Self.defaultApps()
    }
    
    private static func defaultApps() -> [String] {
        ["/Applications/Safari.app", "/Applications/Google Chrome.app",
         "/System/Applications/Messages.app", "/Applications/Telegram.app",
         "/System/Applications/Mail.app", "/System/Applications/Notes.app",
         "/System/Applications/System Settings.app", "/Applications/Spotify.app",
         "/System/Applications/Music.app", "/Applications/Visual Studio Code.app",
         "/System/Applications/Finder.app", "/System/Applications/Calendar.app",
         "/Applications/Slack.app", "/Applications/Discord.app",
         "/System/Applications/Terminal.app", "/System/Applications/Photos.app"
        ].filter { FileManager.default.fileExists(atPath: $0) }
    }
}

extension Notification.Name {
    static let settingsChanged = Notification.Name("sc")
    static let openSettings = Notification.Name("os")
}
