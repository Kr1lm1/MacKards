import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AnimatedScrollIndicator: ViewModifier {
    @State private var geo: ScrollGeometry?
    @State private var show = false
    @State private var hideTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: ScrollGeometry.self, of: { $0 }) { _, new in
                geo = new
                withAnimation(.easeInOut(duration: 0.15)) { show = true }
                hideTask?.cancel()
                hideTask = Task {
                    try? await Task.sleep(for: .seconds(1.0))
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.3)) { show = false }
                    }
                }
            }
            .overlay(alignment: .trailing) {
                if let geo, geo.contentSize.height > geo.containerSize.height + 1 {
                    GeometryReader { proxy in
                        let trackH = proxy.size.height
                        let ratio = geo.containerSize.height / geo.contentSize.height
                        let thumbH = max(24, trackH * ratio)
                        let maxOffset = max(1, geo.contentSize.height - geo.containerSize.height)
                        let progress = min(max(geo.contentOffset.y / maxOffset, 0), 1)
                        let thumbOffset = progress * (trackH - thumbH)

                        RoundedRectangle(cornerRadius: thumbH / 2)
                            .fill(Color.primary.opacity(0.4))
                            .frame(width: 5, height: thumbH)
                            .position(x: proxy.size.width - 5, y: thumbOffset + thumbH / 2)
                            .opacity(show ? 1 : 0)
                            .animation(.easeInOut(duration: 0.2), value: show)
                    }
                }
            }
    }
}

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var apps: [AppItem] = []
    @State private var tab = 0
    @State private var appeared = false
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
            }
            .id(tab)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.move(edge: .trailing).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.22), value: tab)
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : 24)
        .animation(.easeOut(duration: 0.28), value: appeared)
        .onAppear { appeared = true }
        .frame(width: 520, height: 560)
        .onAppear { AppFinder.shared.getApps { apps = $0 } }
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
    
    private func modeBtn(_ title: String, _ idx: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.1)) { settings.menuStyle = idx }
        } label: {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .background(RoundedRectangle(cornerRadius: 5).fill(settings.menuStyle == idx ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.04)))
                .foregroundColor(settings.menuStyle == idx ? .accentColor : .secondary)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(settings.menuStyle == idx ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.1), lineWidth: 0.5))
        }.buttonStyle(.plain)
    }
    
    private func animBtnSmall(_ title: String, _ idx: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.1)) { settings.openAnim = idx }
        } label: {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .background(RoundedRectangle(cornerRadius: 5).fill(settings.openAnim == idx ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.04)))
                .foregroundColor(settings.openAnim == idx ? .accentColor : .secondary)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(settings.openAnim == idx ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.1), lineWidth: 0.5))
        }.buttonStyle(.plain)
    }
    
    // MARK: - General
    
    private var generalTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Mode, Hotkey & Animation
                HStack(alignment: .top, spacing: 8) {
                    sectionSmall("Mode", "paintbrush") {
                        HStack(spacing: 6) {
                            modeBtn("Cards", 0)
                            modeBtn("Ring", 1)
                        }
                    }
                    
                    sectionSmall("Hotkey", "keyboard") {
                        HStack(spacing: 6) {
                            Picker("", selection: $settings.hotkeyMod1) {
                                ForEach(0..<4) { Text(AppSettings.modifierOptions[$0]).tag($0) }
                            }.labelsHidden().frame(width: 54)
                            Text("+").font(.system(size: 13)).foregroundColor(.secondary)
                            Picker("", selection: $settings.hotkeyMod2) {
                                ForEach(0..<4) { Text(AppSettings.modifierOptions[$0]).tag($0) }
                            }.labelsHidden().frame(width: 54)
                        }
                    }
                    
                    sectionSmall("Animation", "play.rectangle.fill") {
                        HStack(spacing: 6) {
                            animBtnSmall("Wave", 0)
                            animBtnSmall("Bounce", 1)
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
                            HStack(spacing: 4) {
                                Image(systemName: act.icon).frame(width: 14).foregroundColor(.accentColor).font(.system(size: 10))
                                Text(act.name).font(.system(size: 11))
                                Line().stroke(style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                                    .foregroundColor(.secondary.opacity(0.4)).frame(height: 1)
                                Toggle("", isOn: Binding(
                                    get: { settings.enabledActions.contains(act.id) },
                                    set: { on in
                                        if on { settings.enabledActions.append(act.id) }
                                        else { settings.enabledActions.removeAll { $0 == act.id } }
                                    }
                                )).toggleStyle(.switch).controlSize(.mini).labelsHidden()
                            }
                        }
                        // Pinned custom folders
                        if !settings.pinnedFolderPaths.isEmpty {
                            Divider()
                            ForEach(settings.pinnedFolderPaths, id: \.self) { path in
                                HStack(spacing: 4) {
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
        .modifier(AnimatedScrollIndicator())
    }

    private func pickApp(into index: Int) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true; panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.application]
        if panel.runModal() == .OK {
            for url in panel.urls where url.pathExtension == "app" {
                if settings.pinnedGroups[index].paths.count >= 8 { break }
                if !settings.pinnedGroups[index].paths.contains(url.path) {
                    settings.pinnedGroups[index].paths.append(url.path)
                }
            }
        }
    }
    
    // MARK: - Apps
    
    private var appsTab: some View {
        List {
            // Pinned Apps
            Section {
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
                }
                .onMove { from, to in settings.pinnedAppPaths.move(fromOffsets: from, toOffset: to) }
                .transition(.move(edge: .leading).combined(with: .opacity))
            } header: {
                Text("Pinned Apps").font(.system(size: 13, weight: .semibold))
            } footer: {
                Button {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = true; panel.canChooseDirectories = false
                    panel.allowsMultipleSelection = true
                    panel.allowedContentTypes = [.application]
                    if panel.runModal() == .OK {
                        for url in panel.urls where url.pathExtension == "app" {
                            if !settings.pinnedAppPaths.contains(url.path) {
                                settings.pinnedAppPaths.append(url.path)
                            }
                        }
                    }
                } label: {
                    Label("Add app", systemImage: "plus.circle.fill").font(.system(size: 11)).foregroundColor(.accentColor)
                }.buttonStyle(.plain).frame(maxWidth: .infinity, alignment: .leading)
            }

            // Groups
            if settings.showActions {
                Section {
                    if settings.pinnedGroups.isEmpty {
                        Text("No groups. Tap + to create one.").font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    ForEach(Array(settings.pinnedGroups.enumerated()), id: \.element.id) { idx, group in
                        DisclosureGroup {
                            VStack(spacing: 4) {
                                ForEach(group.paths.indices, id: \.self) { i in
                                    let path = group.paths[i]
                                    HStack(spacing: 6) {
                                        Image(nsImage: iconFor(path)).resizable().frame(width: 18, height: 18)
                                        Text(URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent).font(.system(size: 10)).lineLimit(1)
                                        Spacer()
                                        Button { settings.pinnedGroups[idx].paths.remove(at: i) } label: {
                                            Image(systemName: "xmark.circle.fill").font(.system(size: 10)).foregroundColor(.secondary.opacity(0.5))
                                        }.buttonStyle(.plain)
                                    }
                                }
                                Button { pickApp(into: idx) } label: {
                                    Label("Add app", systemImage: "plus.circle.fill").font(.system(size: 10)).foregroundColor(.accentColor)
                                }.buttonStyle(.plain).frame(maxWidth: .infinity, alignment: .leading)
                            }.padding(.vertical, 4)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.grid.2x2.fill").font(.system(size: 11)).foregroundColor(.accentColor)
                                TextField("Group name", text: $settings.pinnedGroups[idx].name)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                                    .textFieldStyle(.plain)
                                Spacer()
                                Button { settings.pinnedGroups.remove(at: idx) } label: {
                                    Image(systemName: "xmark.circle.fill").font(.system(size: 10)).foregroundColor(.secondary.opacity(0.5))
                                }.buttonStyle(.plain)
                            }
                        }
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                    Button {
                        settings.pinnedGroups.append(AppGroup(name: "New Group", paths: []))
                    } label: {
                        Label("New Group", systemImage: "plus.circle.fill").font(.system(size: 11))
                    }.buttonStyle(.plain).frame(maxWidth: .infinity, alignment: .leading)
                } header: {
                    Text("Groups").font(.system(size: 13, weight: .semibold))
                }
            }
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 30)
        .padding(.horizontal, 2)
        .animation(.easeInOut(duration: 0.2), value: settings.pinnedAppPaths.count)
        .animation(.easeInOut(duration: 0.2), value: settings.pinnedGroups.count)
        .modifier(AnimatedScrollIndicator())
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
    
    private func sectionSmall<C: View>(_ title: String, _ icon: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 9, weight: .medium)).foregroundColor(.accentColor)
                Text(title).font(.system(size: 9, weight: .semibold))
            }
            .frame(height: 12, alignment: .leading)
            VStack(spacing: 0) { content() }
                .frame(maxWidth: .infinity, minHeight: 46, maxHeight: 46, alignment: .center)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.03)))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.05)))
        }
        .frame(maxWidth: .infinity, minHeight: 76, maxHeight: 76, alignment: .topLeading)
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
