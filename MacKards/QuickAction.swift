import AppKit
import Foundation

struct QuickAction: Identifiable {
    let id: String
    let name: String
    let icon: String
    let targetURL: URL?
    let action: () -> Void
    
    func handleDrop(providers: [NSItemProvider]) {
        guard let target = targetURL else { return }
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                guard let data = item as? Data,
                      let src = URL(dataRepresentation: data, relativeTo: nil) else { return }
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
        return [
            .init(id:"downloads",name:"Downloads",icon:"arrow.down.circle",targetURL:fm.urls(for:.downloadsDirectory,in:.userDomainMask).first){NSWorkspace.shared.open(fm.urls(for:.downloadsDirectory,in:.userDomainMask).first!)},
            .init(id:"documents",name:"Documents",icon:"doc.fill",targetURL:fm.urls(for:.documentDirectory,in:.userDomainMask).first){NSWorkspace.shared.open(fm.urls(for:.documentDirectory,in:.userDomainMask).first!)},
            .init(id:"desktop",name:"Desktop",icon:"desktopcomputer",targetURL:fm.urls(for:.desktopDirectory,in:.userDomainMask).first){NSWorkspace.shared.open(fm.urls(for:.desktopDirectory,in:.userDomainMask).first!)},
            .init(id:"home",name:"Home",icon:"house.fill",targetURL:home){NSWorkspace.shared.open(home)},
            .init(id:"applications",name:"Apps",icon:"square.grid.2x2.fill",targetURL:URL(fileURLWithPath:"/Applications")){NSWorkspace.shared.open(URL(fileURLWithPath:"/Applications"))},
            .init(id:"trash",name:"Trash",icon:"trash",targetURL:fm.urls(for:.trashDirectory,in:.userDomainMask).first){NSWorkspace.shared.open(fm.urls(for:.trashDirectory,in:.userDomainMask).first!)},
            .init(id:"icloud",name:"iCloud",icon:"icloud.fill",targetURL:home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")){
                let url=home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs");NSWorkspace.shared.open(fm.fileExists(atPath:url.path) ? url : home)},
        ]
    }()
}
