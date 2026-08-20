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
        if Date().timeIntervalSince(cacheTime) > 120 || cache.isEmpty { refresh() }
        return cache
    }
    
    private func refresh() {
        let fm = FileManager.default
        var result: [AppItem] = []
        for dir in ["/Applications", "/System/Applications", "/System/Applications/Utilities"] {
            guard let items = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in items where item.hasSuffix(".app") {
                let path = dir + "/" + item
                let url = URL(fileURLWithPath: path)
                let icon = NSWorkspace.shared.icon(forFile: path)
                icon.size = NSSize(width: 48, height: 48)
                result.append(AppItem(id: url, name: String(item.dropLast(4)), url: url, icon: icon))
            }
        }
        cache = result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        cacheTime = Date()
    }
}
