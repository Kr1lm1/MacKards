import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var apps: [AppItem] = []
    @State private var tab = 0
    @State private var iconCache: [String: NSImage] = [:]
    
    private func iconFor(_ path: String) -> NSImage {
        if let cached = iconCache[path] { return cached }
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 24, height: 24)
        DispatchQueue.main.async { iconCache[path] = icon }
        return icon
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tabs
            HStack(spacing: 2) {
                tabBtn("General", "gearshape.fill", 0)
                tabBtn("Apps", "square.grid.2x2.fill", 1)
                tabBtn("About", "info.circle.fill", 2)
            }.padding(.horizontal, 12).padding(.top, 10)
            Divider().padding(.top, 6)
            
            Group {
                switch tab {
                case 0: generalTab
                case 1: appsTab
                default: aboutTab
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 520, height: 480)
        .onAppear { apps = AppFinder.shared.getApps() }
    }
    
    private func tabBtn(_ title: String, _ icon: String, _ idx: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.1)) { tab = idx }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11))
                Text(title).font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .contentShape(Rectangle())
            .background(RoundedRectangle(cornerRadius: 6).fill(tab == idx ? Color.accentColor.opacity(0.12) : .clear))
            .foregroundColor(tab == idx ? .accentColor : .secondary)
        }.buttonStyle(.plain)
    }
    
    // MARK: - General
    
    private var generalTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Mode & Hotkeys
                section("Mode & Hotkeys", "paintbrush") {
                    HStack {
                        Picker("Mode", selection: $settings.menuStyle) {
                            Text("Cards").tag(0)
                            Text("Ring").tag(1)
                        }.pickerStyle(.segmented).labelsHidden()
                        
                        HStack(spacing: 4) {
                            Spacer()
                            Text("← mode").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary.opacity(0.25))
                            Text("·").font(.system(size: 12)).foregroundColor(.secondary.opacity(0.2))
                            Text("hotkeys →").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary.opacity(0.25))
                            Spacer()
                        }.frame(maxWidth: .infinity)
                        
                        HStack(spacing: 4) {
                            Picker("", selection: $settings.hotkeyMod1) {
                                ForEach(0..<4) { Text(AppSettings.modifierOptions[$0]).tag($0) }
                            }.labelsHidden().frame(width: 44)
                            Text("+").font(.system(size: 10)).foregroundColor(.secondary)
                            Picker("", selection: $settings.hotkeyMod2) {
                                ForEach(0..<4) { Text(AppSettings.modifierOptions[$0]).tag($0) }
                            }.labelsHidden().frame(width: 44)
                        }
                    }
                }
                
                // Layout
                section("Layout", "circle.grid.2x2") {
                    slider("Radius", $settings.radius, 80...200, 5, "%.0f")
                    if settings.menuStyle == 0 {
                        slider("Card Size", $settings.cardSize, 50...110, 2, "%.0f")
                    } else {
                        slider("Thickness", $settings.ringThickness, 40...100, 2, "%.0f")
                    }
                    slider("Icon Scale", Binding(get: { Double(settings.iconScale) }, set: { settings.iconScale = CGFloat($0) }), 0.3...0.9, 0.05, "%.2f")
                    slider("Anim Speed", $settings.animSpeed, 0.5...3.0, 0.25, "%.1fx")
                }
                
                // Opening Animation
                section("Opening Animation", "play.rectangle.fill") {
                    HStack {
                        Picker("", selection: $settings.openAnim) {
                            Text("Stagger").tag(0)
                            Text("Scale").tag(1)
                            Text("Fade").tag(2)
                            Text("Bounce").tag(3)
                        }
                        .pickerStyle(.segmented)
                        Spacer()
                    }
                }
                
                // Options
                section("Options", "slider.horizontal.3") {
                    optionRow("Labels", $settings.showLabels)
                    optionRow("Folders", $settings.showActions)
                    optionRow("Haptics", $settings.haptics)
                    optionRow("Low Power", $settings.lowPower)
                    optionRow("Launch at Login", $settings.launchAtLogin)
                }
                
                // Folders
                if settings.showActions {
                    section("Folders", "folder.fill") {
                        ForEach(QuickAction.allActions, id: \.id) { act in
                            Toggle(isOn: Binding(
                                get: { settings.enabledActions.contains(act.id) },
                                set: { on in
                                    if on { settings.enabledActions.append(act.id) }
                                    else { settings.enabledActions.removeAll { $0 == act.id } }
                                }
                            )) {
                                HStack(spacing: 5) {
                                    Image(systemName: act.icon).frame(width: 14).foregroundColor(.accentColor).font(.system(size: 10))
                                    Text(act.name).font(.system(size: 11))
                                    Spacer()
                                }
                            }.toggleStyle(.switch).controlSize(.mini)
                        }
                        // Pinned custom folders
                        if !settings.pinnedFolderPaths.isEmpty {
                            Divider()
                            ForEach(settings.pinnedFolderPaths, id: \.self) { path in
                                HStack(spacing: 5) {
                                    Image(systemName: "folder.fill").frame(width: 14).foregroundColor(.orange).font(.system(size: 10))
                                    Text(URL(fileURLWithPath: path).lastPathComponent).font(.system(size: 11))
                                    Spacer()
                                    Button { settings.pinnedFolderPaths.removeAll { $0 == path } } label: {
                                        Image(systemName: "xmark.circle.fill").font(.system(size: 10)).foregroundColor(.secondary.opacity(0.5))
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                
                // Reset
                Button { withAnimation { settings.resetToDefaults() } } label: {
                    Label("Reset All", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 11)).padding(.vertical, 4).padding(.horizontal, 10)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).foregroundColor(.secondary)
                .background(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.secondary.opacity(0.25)))
                .frame(maxWidth: .infinity, alignment: .trailing)
            }.padding(18)
        }
    }
    
    // MARK: - Apps
    
    private var appsTab: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Pinned Apps").font(.system(size: 12, weight: .semibold))
                Spacer()
                Menu {
                    ForEach(apps.filter { !settings.pinnedAppPaths.contains($0.url.path) }.prefix(30)) { app in
                        Button(app.name) { settings.pinnedAppPaths.append(app.url.path) }
                    }
                } label: {
                    Image(systemName: "plus.circle.fill").font(.system(size: 14))
                }.menuStyle(.borderlessButton).frame(width: 30)
            }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 6)
            Divider().padding(.horizontal, 12)
            List {
                ForEach(Array(settings.pinnedAppPaths.enumerated()), id: \.element) { i, path in
                    HStack(spacing: 8) {
                        Image(nsImage: iconFor(path)).resizable().frame(width: 24, height: 24)
                        Text(String(path.split(separator: "/").last?.dropLast(4) ?? ""))
                            .font(.system(size: 12)).lineLimit(1)
                        Spacer()
                        Button { settings.pinnedAppPaths.remove(at: i) } label: {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 12))
                                .foregroundColor(.secondary.opacity(0.6))
                                .frame(width: 22, height: 22).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }.padding(.vertical, 2).contentShape(Rectangle())
                }.onMove { from, to in settings.pinnedAppPaths.move(fromOffsets: from, toOffset: to) }
            }.listStyle(.plain)
            // Drop zone
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                .foregroundColor(.secondary.opacity(0.3))
                .frame(height: 128)
                .frame(maxWidth: .infinity)
                .overlay(
                    VStack(spacing: 4) {
                        Image(systemName: "plus.app").font(.system(size: 16)).foregroundColor(.secondary.opacity(0.5))
                        Text("Drop .app or folder here").font(.system(size: 11)).foregroundColor(.secondary)
                    }
                )
                .padding(.horizontal, 12).padding(.vertical, 12)
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    for p in providers {
                        p.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                            guard let data = item as? Data,
                                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                            DispatchQueue.main.async {
                                if url.pathExtension == "app" {
                                    if !settings.pinnedAppPaths.contains(url.path) {
                                        settings.pinnedAppPaths.append(url.path)
                                    }
                                } else {
                                    var isDir: ObjCBool = false
                                    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                                        if !settings.pinnedFolderPaths.contains(url.path) {
                                            settings.pinnedFolderPaths.append(url.path)
                                        }
                                    }
                                }
                            }
                        }
                    }; return true
                }
        }
    }
    
    // MARK: - About
    
    private var aboutTab: some View {
        VStack(spacing: 14) {
                Spacer()
                Image(systemName: "rectangle.portrait.on.rectangle.portrait.angled.fill").font(.system(size: 44))
                    .foregroundStyle(.primary)
                VStack(spacing: 3) {
                    Text("MacKards").font(.system(size: 20, weight: .semibold))
                    Text("by KRILMIW • Open Source").font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
                }
                Text("v1.0 beta • macOS Golden Gate").font(.system(size: 10)).foregroundColor(.secondary.opacity(0.7))
                
                Divider().frame(width: 80).padding(.vertical, 2)
                
                Text("Radial launcher for your favorite apps.\nHold \(settings.hotkeyLabel) to summon the ring.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                
                Spacer()
                
                HStack(spacing: 16) {
                    Label("Swift", systemImage: "swift").font(.system(size: 10)).foregroundColor(.secondary)
                    Label("SwiftUI", systemImage: "rectangle.on.rectangle").font(.system(size: 10)).foregroundColor(.secondary)
                }.padding(.bottom, 14)
        }.frame(maxWidth: .infinity)
    }
    
    // MARK: - Helpers
    
    private func section<C: View>(_ title: String, _ icon: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10, weight: .medium)).foregroundColor(.accentColor)
                Text(title).font(.system(size: 11, weight: .semibold))
            }
            VStack(spacing: 5) { content() }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.03)))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.05)))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func slider(_ label: String, _ value: Binding<Double>, _ range: ClosedRange<Double>, _ step: Double, _ fmt: String) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.system(size: 11)).frame(width: 65, alignment: .leading)
            Slider(value: value, in: range, step: step).controlSize(.mini)
            Text(String(format: fmt, value.wrappedValue)).font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary).frame(width: 30, alignment: .trailing)
        }
    }
    
    private func slider(_ label: String, _ value: Binding<CGFloat>, _ range: ClosedRange<CGFloat>, _ step: CGFloat, _ fmt: String) -> some View {
        slider(label, Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = CGFloat($0) }),
               Double(range.lowerBound)...Double(range.upperBound), Double(step), fmt)
    }
    
    private func optionRow(_ label: String, _ value: Binding<Bool>) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.system(size: 11))
            Line().stroke(style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                .foregroundColor(.secondary.opacity(0.4)).frame(height: 1)
            Toggle("", isOn: value).toggleStyle(.switch).controlSize(.mini).labelsHidden()
        }
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in p.move(to: .init(x: 0, y: rect.midY)); p.addLine(to: .init(x: rect.width, y: rect.midY)) }
    }
}
