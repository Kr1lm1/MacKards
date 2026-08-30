import AppKit
import Foundation

struct QuickAction: Identifiable {
    let id: String
    let name: String
    let icon: String
    let targetURL: URL?
    let folderImage: NSImage?
    let action: () -> Void
    
    init(id: String, name: String, icon: String, targetURL: URL?, folderImage: NSImage? = nil, action: @escaping () -> Void) {
        self.id = id; self.name = name; self.icon = icon; self.targetURL = targetURL; self.folderImage = folderImage; self.action = action
    }
    
    func handleDrop(providers: [NSItemProvider]) {
        guard let target = targetURL else { return }
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                let src: URL? = {
                    if let data = item as? Data { return URL(dataRepresentation: data, relativeTo: nil) }
                    if let url = item as? URL { return url }
                    if let url = item as? NSURL { return url as URL }
                    return nil
                }()
                guard let src else { return }
                DispatchQueue.main.async {
                    let fm = FileManager.default
                    let dest = target.appendingPathComponent(src.lastPathComponent)
                    do {
                        if self.id == "trash" { try fm.trashItem(at: src, resultingItemURL: nil) }
                        else {
                            if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
                            try fm.moveItem(at: src, to: dest)
                        }
                    } catch { try? fm.copyItem(at: src, to: dest) }
                }
            }
        }
    }
    
    static let allActions: [QuickAction] = {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        func folderIcon(_ url: URL?) -> NSImage? {
            guard let url else { return nil }
            let img = NSWorkspace.shared.icon(forFile: url.path)
            img.size = NSSize(width: 64, height: 64)
            return img
        }
        func folder(_ id: String, _ name: String, _ icon: String, _ url: URL?) -> QuickAction {
            .init(id: id, name: name, icon: icon, targetURL: url, folderImage: folderIcon(url)) {
                guard let url else { return }
                NSWorkspace.shared.open(url)
            }
        }
        let downloads = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first
        let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first
        let desktop = fm.urls(for: .desktopDirectory, in: .userDomainMask).first
        let trash = fm.urls(for: .trashDirectory, in: .userDomainMask).first
        let iCloud = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        return [
            folder("downloads", "Downloads", "arrow.down.circle", downloads),
            folder("documents", "Documents", "doc.fill", documents),
            folder("desktop", "Desktop", "desktopcomputer", desktop),
            folder("home", "Home", "house.fill", home),
            folder("applications", "Apps", "square.grid.2x2.fill", URL(fileURLWithPath: "/Applications")),
            .init(id: "trash", name: "Trash", icon: "trash", targetURL: trash, folderImage: nil) {
                guard let url = trash else { return }
                NSWorkspace.shared.open(url)
            },
            folder("icloud", "iCloud", "icloud.fill", fm.fileExists(atPath: iCloud.path) ? iCloud : home),
        ]
    }()
}
