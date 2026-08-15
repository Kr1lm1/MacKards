import Foundation
import AppKit

struct AppItem: Identifiable, Hashable {
    let id: URL
    let name: String
    let url: URL
    let icon: NSImage
    func hash(into hasher: inout Hasher) { hasher.combine(url) }
    static func == (lhs: AppItem, rhs: AppItem) -> Bool { lhs.url == rhs.url }
}

final class AppFinder {
    static let shared = AppFinder()
    private var cache: [AppItem] = []
    private var cacheTime: Date = .distantPast
    private init() {}
    
    func getApps() -> [AppItem] {
        if Date().timeIntervalSince(cacheTime) > 60 || cache.isEmpty { refresh() }
        return cache
    }
    
    func getFrequentApps(limit: Int) -> [AppItem] {
        Array(getApps().prefix(limit))
    }
    
    private func refresh() {
        let fm = FileManager.default
        let dirs = ["/Applications", "/System/Applications", "/System/Applications/Utilities",
                    NSHomeDirectory() + "/Applications"]
        var result: [AppItem] = []
        for dir in dirs {
            guard let items = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in items where item.hasSuffix(".app") {
                let url = URL(fileURLWithPath: dir + "/" + item)
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                icon.size = NSSize(width: 48, height: 48)
                result.append(AppItem(id: url, name: String(item.dropLast(4)), url: url, icon: icon))
            }
        }
        cache = result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        cacheTime = Date()
    }
}
