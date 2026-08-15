import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var apps: [AppItem] = []
    @State private var tab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tabBtn("Appearance", "paintbrush.fill", 0)
                tabBtn("Apps", "square.grid.2x2.fill", 1)
                tabBtn("About", "info.circle.fill", 2)
            }.padding(.horizontal, 16).padding(.top, 12)
            Divider().padding(.top, 8)
            Group {
                switch tab {
                case 0: appearanceTab
                case 1: appsTab
                default: aboutTab
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 480, height: 420)
        .onAppear { apps = AppFinder.shared.getApps() }
    }
    
    private func tabBtn(_ title: String, _ icon: String, _ idx: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.12)) { tab = idx }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 16))
                Text(title).font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(RoundedRectangle(cornerRadius: 8).fill(tab == idx ? Color.accentColor.opacity(0.12) : .clear))
            .foregroundColor(tab == idx ? .accentColor : .secondary)
        }.buttonStyle(.plain)
    }
    
    // MARK: - Appearance
    
    private var appearanceTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                section("Size", "arrow.up.left.and.arrow.down.right") {
                    slider("Radius", $settings.radius, 80...200, 5, "%.0f")
                    slider("Card Size", $settings.cardSize, 50...110, 2, "%.0f")
                    slider("Count", Binding(get: { Double(settings.appCount) },
                                            set: { settings.appCount = Int($0) }), 4...12, 1, "%.0f")
                }
                section("Display", "eye") {
                    Toggle("Show Labels", isOn: $settings.showLabels).toggleStyle(.switch)
                    Toggle("Show Actions", isOn: $settings.showActions).toggleStyle(.switch)
                }
                if settings.showActions {
                    section("Actions", "bolt.fill") {
                        ForEach(QuickAction.allActions, id: \.id) { act in
                            Toggle(isOn: Binding(
                                get: { settings.enabledActions.contains(act.id) },
                                set: { on in
                                    if on { settings.enabledActions.append(act.id) }
                                    else { settings.enabledActions.removeAll { $0 == act.id } }
                                }
                            )) {
                                HStack(spacing: 6) {
                                    Image(systemName: act.icon).frame(width: 16).foregroundColor(.accentColor)
                                    Text(act.name).font(.system(size: 12)); Spacer()
                                }
                            }.toggleStyle(.switch).controlSize(.small)
                        }
                    }
                }
                HStack {
                    Spacer()
                    Button { withAnimation { settings.resetToDefaults() } } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise").font(.system(size: 12))
                            .padding(.vertical, 5).padding(.horizontal, 12).contentShape(Rectangle())
                    }.buttonStyle(.plain).foregroundColor(.secondary)
                    .background(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.3)))
                }
            }.padding(20)
        }
    }
    
    // MARK: - Apps
    
    private var appsTab: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pinned Apps").font(.system(size: 13, weight: .semibold))
                    Text("Drag .app here or pick from menu").font(.system(size: 11)).foregroundColor(.secondary)
                }
                Spacer()
                Menu {
                    ForEach(apps.filter { !settings.pinnedAppPaths.contains($0.url.path) }.prefix(30)) { app in
                        Button(app.name) { withAnimation { settings.pinnedAppPaths.append(app.url.path) } }
                    }
                } label: {
                    Label("Add", systemImage: "plus.circle.fill").font(.system(size: 12, weight: .medium))
                }.menuStyle(.borderlessButton).frame(width: 70)
            }.padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)
            Divider().padding(.horizontal, 16)
            List {
                ForEach(Array(settings.pinnedAppPaths.prefix(settings.appCount).enumerated()), id: \.element) { i, path in
                    HStack(spacing: 10) {
                        Text("\(i+1)").font(.system(size: 11, design: .rounded)).foregroundColor(.secondary).frame(width: 18)
                        Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().frame(width: 28, height: 28)
                        Text(URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent).font(.system(size: 13)).lineLimit(1)
                        Spacer()
                        Button { withAnimation { settings.pinnedAppPaths.removeAll { $0 == path } } } label: {
                            Image(systemName: "minus.circle.fill").foregroundColor(.red.opacity(0.7))
                                .frame(width: 28, height: 28).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }.padding(.vertical, 3).contentShape(Rectangle())
                }.onMove { from, to in settings.pinnedAppPaths.move(fromOffsets: from, toOffset: to) }
            }.listStyle(.plain)
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundColor(.secondary.opacity(0.4)).frame(height: 44)
                .overlay(HStack(spacing: 6) {
                    Image(systemName: "plus.app").foregroundColor(.secondary)
                    Text("Drop .app here").font(.system(size: 11)).foregroundColor(.secondary)
                })
                .padding(.horizontal, 20).padding(.vertical, 8)
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    for p in providers {
                        p.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                            guard let data = item as? Data,
                                  let url = URL(dataRepresentation: data, relativeTo: nil),
                                  url.pathExtension == "app" else { return }
                            DispatchQueue.main.async {
                                if !settings.pinnedAppPaths.contains(url.path) {
                                    withAnimation { settings.pinnedAppPaths.append(url.path) }
                                }
                            }
                        }
                    }; return true
                }
        }
    }
    
    // MARK: - About
    
    private var aboutTab: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "menucard.fill").font(.system(size: 48))
                .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text("MacKards").font(.system(size: 20, weight: .semibold))
            Text("v1.0").font(.system(size: 12)).foregroundColor(.secondary)
            Text("Hold ⌘⌥ to open").font(.system(size: 12)).foregroundColor(.secondary)
            Spacer()
        }.frame(maxWidth: .infinity)
    }
    
    // MARK: - Helpers
    
    private func section<C: View>(_ title: String, _ icon: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .medium)).foregroundColor(.accentColor)
                Text(title).font(.system(size: 12, weight: .semibold))
            }
            VStack(spacing: 8) { content() }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.03)))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.06)))
        }
    }
    
    private func slider(_ label: String, _ value: Binding<Double>, _ range: ClosedRange<Double>, _ step: Double, _ fmt: String) -> some View {
        HStack(spacing: 12) {
            Text(label).font(.system(size: 12)).frame(width: 80, alignment: .leading)
            Slider(value: value, in: range, step: step).controlSize(.small)
            Text(String(format: fmt, value.wrappedValue)).font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary).frame(width: 36, alignment: .trailing)
        }
    }
    
    private func slider(_ label: String, _ value: Binding<CGFloat>, _ range: ClosedRange<CGFloat>, _ step: CGFloat, _ fmt: String) -> some View {
        slider(label, Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = CGFloat($0) }),
               Double(range.lowerBound)...Double(range.upperBound), Double(step), fmt)
    }
}
