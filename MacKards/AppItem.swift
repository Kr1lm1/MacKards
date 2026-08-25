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
