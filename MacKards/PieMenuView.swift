import SwiftUI
import UniformTypeIdentifiers

private let lpColor = Color(nsColor: .controlBackgroundColor)

struct PieMenuContentView: View {
    let apps: [AppItem]
    let actions: [QuickAction]
    let groups: [AppGroup]
    let settings: AppSettings
    let onSelect: (AppItem) -> Void
    let onAction: (QuickAction) -> Void
    let onGroup: (AppGroup) -> Void
    let onFolder: (QuickAction) -> Void
    let onCloseSubmenu: () -> Void
    let onLeaveFolderGroup: () -> Void
    var arc: ClosedRange<Double>? = nil
    var bgArc: ClosedRange<Double>? = nil
    var edgePadDeg: Double? = nil
    var midGapDeg: Double? = nil
    var radiusOverride: CGFloat? = nil
    var cardSizeOverride: CGFloat? = nil
    
    @State private var shown = 0
    @State private var hovered: Int? = nil
    @State private var ringVis = false
    @State private var menuScale: CGFloat = 0.01
    @State private var menuOpacity: Double = 0
    @State private var emptyMessage: String? = nil
    @ObservedObject private var state = PieMenuState.shared
    
    private var total: Int { apps.count + actions.count + groups.count }
    private var radius: CGFloat { radiusOverride ?? settings.radius }
    
    var body: some View {
        pieBody
            .onAppear { animateIn() }
            .onChange(of: state.isClosing) { _, closing in
                if closing {
                    withAnimation(.easeIn(duration: 0.12)) { menuOpacity = 0 }
                    withAnimation(.easeIn(duration: 0.24)) { menuScale = 0.01 }
                }
            }
    }
    
    private var baseDuration: Double { 0.3 / max(settings.animSpeed, 0.1) }

    private func labelText(for hovered: Int?) -> String? {
        if let app = state.hoveredApp { return app.name }
        if let act = state.hoveredAction { return act.name }
        guard let h = hovered else { return nil }
        if h < apps.count { return apps[h].name }
        if h < apps.count + actions.count { return actions[h - apps.count].name }
        return groups[h - apps.count - actions.count].name
    }

    private func isFolderEmpty(_ url: URL) -> Bool {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: url.path) else { return true }
        return items.filter { !$0.hasPrefix(".") }.isEmpty
    }

    private func handleDropIntoGroup(providers: [NSItemProvider], groupIndex: Int) -> Bool {
        guard groupIndex < groups.count else { return false }
        let groupID = groups[groupIndex].id
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
                    guard let settingsIndex = AppSettings.shared.pinnedGroups.firstIndex(where: { $0.id == groupID }) else { return }
                    var group = AppSettings.shared.pinnedGroups[settingsIndex]
                    let path = src.path
                    guard !group.paths.contains(path), group.paths.count < 8 else { return }
                    group.paths.append(path)
                    AppSettings.shared.pinnedGroups[settingsIndex] = group
                }
            }
        }
        return true
    }

    private func animateIn() {
        let n = total
        shown = n
        let bloom = settings.ringOpenAnim == 1
        if settings.openAnim == 1, !settings.lowPower, !bloom {
            ringVis = true
            withAnimation(.spring(response: baseDuration, dampingFraction: 0.55)) {
                menuScale = 1
                menuOpacity = 1
            }
        } else {
            ringVis = true; menuScale = 1; menuOpacity = 1
        }
    }
    
    private var pieBody: some View {
        let n = CGFloat(max(total, 1)), lp = settings.lowPower
        let baseR = settings.radius
        let circ = 2 * .pi * baseR
        let card = cardSizeOverride ?? min((circ - settings.cardGap * n) / n, settings.cardSize)
        let size = radius * 2 + card + 60
        let ring = settings.menuStyle == 1 && arc == nil
        let thick = settings.ringThickness
        let outline = Color.primary.opacity(0.125)

        return ZStack {
            if ring {
                let outer = radius + thick / 2, inner = max(radius - thick / 2, 10)
                let closing = state.isClosing
                let bloom = settings.ringOpenAnim == 1
                ZStack {
                    DonutShape(outerRadius: outer, innerRadius: inner)
                        .fill(lp ? AnyShapeStyle(lpColor) : settings.menuMaterial)
                        .frame(width: size, height: size)
                        .overlay(DonutShape(outerRadius: outer, innerRadius: inner).stroke(outline, lineWidth: 1.5).frame(width: size, height: size))
                        .opacity(ringVis && !closing ? 1 : 0)
                        .blur(radius: lp || !bloom ? 0 : (ringVis && !closing ? 0 : 100))
                        .animation(lp ? nil : (bloom ? .easeOut(duration: baseDuration) : .spring(response: baseDuration, dampingFraction: 0.75)), value: ringVis)
                        .animation(lp ? nil : .easeIn(duration: baseDuration * 0.75), value: closing)
                }
                .scaleEffect(bloom ? (ringVis && !closing ? 1 : 0.5) : (!lp ? (ringVis && !closing ? 1 : 0.85) : 1))
.animation(lp ? nil : (bloom ? .spring(response: baseDuration * 1.5, dampingFraction: 0.55) : .spring(response: baseDuration, dampingFraction: 0.75)), value: ringVis)
                    .animation(lp ? nil : .easeIn(duration: baseDuration * 0.75), value: closing)
            } else if let arcRange = arc {
                let bgRange = bgArc ?? arcRange
                let bgThick = max(26, thick * 0.85)
                let outerR = radius + bgThick / 2
                let innerR = max(radius - bgThick / 2, 0)
                ZStack {
                    ArcSegmentShape(outerRadius: outerR, innerRadius: innerR, start: bgRange.lowerBound, end: bgRange.upperBound)
                        .fill(lp ? AnyShapeStyle(lpColor) : AnyShapeStyle(settings.menuMaterial))
                        .overlay(ArcSegmentShape(outerRadius: outerR, innerRadius: innerR, start: bgRange.lowerBound, end: bgRange.upperBound).stroke(outline, lineWidth: 1.5))
                        .frame(width: size, height: size)
                    let n = Double(max(apps.count, 1))
                    let iconAng = card / radius * 180 / .pi
                    let span = arcRange.upperBound - arcRange.lowerBound
                    let midGap = midGapDeg ?? max(0.1, (span - n * iconAng) / (n + 1))
                    let edgePad = edgePadDeg ?? midGap
                    let firstAng = arcRange.lowerBound + edgePad + iconAng / 2
                    ForEach(0..<apps.count, id: \.self) { i in
                        let ang = firstAng + Double(i) * (iconAng + midGap)
                        let rad = ang * .pi / 180
                        let jump = (hovered == i && !lp) ? 6.0 : 0.0
                        let rr = radius + jump
                        let cx = cos(rad) * rr
                        let cy = sin(rad) * rr
                        cardIcon(i, card)
                            .frame(width: card, height: card)
                            .contentShape(Circle())
                            .onHover { on in
                                hovered = on ? i : nil
                                let st = PieMenuState.shared
                                if on {
                                    st.hoveredApp = apps[i]; st.hoveredAction = nil
                                } else if st.hoveredApp?.id == apps[i].id {
                                    st.hoveredApp = nil
                                }
                                if on { haptic() }
                            }
                            .offset(x: cx, y: cy)
                            .animation(.spring(response: baseDuration * 0.8, dampingFraction: 0.75), value: hovered)
                            .onTapGesture { onSelect(apps[i]) }
                    }
                }
                .scaleEffect(ringVis ? 1 : 0.96)
                .opacity(ringVis ? 1 : 0)
                .animation(lp ? nil : .easeOut(duration: baseDuration), value: ringVis)
            }

            if arc == nil {
                let bloom = ring && settings.ringOpenAnim == 1
                Group {
                    Group {
                        ForEach(0..<total, id: \.self) { i in pieCard(i, card: card, ring: ring, bloom: bloom) }
                    }
                    .opacity(bloom ? (ringVis && !state.isClosing ? 1 : 0) : 1)
                    .blur(radius: bloom && !lp ? (ringVis && !state.isClosing ? 0 : 100) : 0)
                    .animation(lp || !bloom ? nil : .easeOut(duration: baseDuration), value: ringVis)
                    .animation(lp || !bloom ? nil : .easeIn(duration: baseDuration * 0.75), value: state.isClosing)
                }
                .scaleEffect(bloom ? (ringVis && !state.isClosing ? 1 : 0.5) : 1)
                .animation(lp || !bloom ? nil : .spring(response: baseDuration * 1.5, dampingFraction: 0.55), value: ringVis)
                .animation(lp || !bloom ? nil : .easeIn(duration: baseDuration * 0.75), value: state.isClosing)
            }

            // Мертвая зона в центре главного меню — не дает случайно выбрать элемент,
            // особенно в card-style, где секторы встречаются в центре
            let mainDeadZone = max(0, min(radius * 0.55, 120))
            Circle()
                .fill(Color.black.opacity(0.0001))
                .contentShape(Circle())
                .frame(width: mainDeadZone, height: mainDeadZone)

            if let message = emptyMessage, let h = hovered {
                let span = arc.map { $0.upperBound - $0.lowerBound } ?? 360.0
                let start = arc?.lowerBound ?? -90.0
                let slice = span / Double(total)
                let ang = start + slice * Double(h) + slice / 2
                let rad = ang * .pi / 180
                let hoverJump: CGFloat = lp ? 0 : 6
                let pos = CGSize(width: cos(rad) * (radius + hoverJump),
                                 height: sin(rad) * (radius + hoverJump))
                let dir = atan2(pos.height, pos.width)

                let font = NSFont.systemFont(ofSize: 11, weight: .medium)
                let textSize = (message as NSString).size(withAttributes: [.font: font])
                let labelW = textSize.width + 16
                let labelH = textSize.height + 4

                let hasFolderImage = state.hoveredAction?.folderImage != nil
                let iconFactor: CGFloat = hasFolderImage ? 0.5 : 0.39
                let iconOuter: CGFloat = card * settings.iconScale * iconFactor * (lp ? 1 : settings.hoverScale)
                let gap: CGFloat = 2
                let radialHalf = labelW / 2 * abs(cos(dir)) + labelH / 2 * abs(sin(dir))
                let desiredOffset = iconOuter + gap + radialHalf

                let windowHalf = (radius * 2 + card + 180) / 2
                let maxOffset = windowHalf - (radius + hoverJump) - radialHalf
                let offset = min(desiredOffset, maxOffset)

                Text(message)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(lp ? AnyShapeStyle(lpColor) : AnyShapeStyle(.thinMaterial)))
                    .offset(x: pos.width + cos(dir) * offset, y: pos.height + sin(dir) * offset)
            }

            if settings.showLabels, !state.isSubmenuClosing, let label = labelText(for: hovered) {
                Text(label)
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(.primary)
                    .lineLimit(1).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(lp ? AnyShapeStyle(lpColor) : AnyShapeStyle(.thinMaterial)))
                    .contentShape(Capsule())
                    .frame(maxWidth: radius * 1.2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scaleEffect(lp ? 1 : menuScale)
        .opacity(lp ? 1 : menuOpacity)
    }
    
    private func pieCard(_ i: Int, card: CGFloat, ring: Bool, bloom: Bool) -> some View {
        let span = arc.map { $0.upperBound - $0.lowerBound } ?? 360.0
        let start = arc?.lowerBound ?? -90.0
        let slice = span / Double(total)
        let ang = start + slice * Double(i) + slice / 2, rad = ang * .pi / 180
        let lp = settings.lowPower
        let isH = hovered == i, vis = i < shown && !state.isClosing
        let r = radius + (isH && !lp ? 6.0 : 0)
        let x = cos(rad) * r, y = sin(rad) * r
        let pr = (start + slice * Double(max(i-1,0)) + slice / 2) * .pi / 180
        let px = cos(pr) * radius, py = sin(pr) * radius
        let shape = PieSliceShape(narrowFactor: 0.55, rotation: ang + 90)
        
        let isAction = i >= apps.count && i < apps.count + actions.count
        let cardBody = ZStack {
            if !ring && arc == nil {
                shape.fill(lp ? AnyShapeStyle(lpColor) : settings.menuMaterial).frame(width: card, height: card)
                shape.stroke(Color.primary.opacity(0.15), lineWidth: 0.5).frame(width: card, height: card)
            }
            cardIcon(i, card)
        }
        .frame(width: card, height: card)
        .contentShape(ring ? AnyShape(Circle()) : AnyShape(shape))
        .onTapGesture {
            if i < apps.count { onSelect(apps[i]) }
            else if i < apps.count + actions.count { onAction(actions[i - apps.count]) }
        }
        .onHover { on in
            let prev = hovered; hovered = on ? i : nil
            let st = PieMenuState.shared
            if on {
                emptyMessage = nil
                if i < apps.count { st.hoveredApp = apps[i]; st.hoveredAction = nil; if arc == nil { onCloseSubmenu() } }
                else if i < apps.count + actions.count {
                    let act = actions[i - apps.count]
                    if settings.showSubmenu, act.id != "trash", let url = act.targetURL, url.hasDirectoryPath, FileManager.default.fileExists(atPath: url.path) {
                        if isFolderEmpty(url) {
                            emptyMessage = "Empty folder"
                            st.hoveredApp = nil; st.hoveredAction = act
                            if arc == nil { onCloseSubmenu() }
                        } else {
                            st.hoveredApp = nil; st.hoveredAction = act
                            if arc == nil { onFolder(act) }
                        }
                    } else {
                        st.hoveredApp = nil; st.hoveredAction = act
                        if arc == nil { onCloseSubmenu() }
                    }
                }
                else {
                    st.hoveredApp = nil; st.hoveredAction = nil
                    if settings.showSubmenu, arc == nil {
                        let g = i - apps.count - actions.count
                        if g < groups.count {
                            if groups[g].paths.isEmpty {
                                emptyMessage = "Empty group"
                                if arc == nil { onCloseSubmenu() }
                            } else {
                                onGroup(groups[g])
                            }
                        }
                    }
                }
                if prev != i { haptic() }
            } else {
                if i < apps.count { st.hoveredApp = nil }
                st.hoveredAction = nil
                hovered = nil
                emptyMessage = nil
                if i >= apps.count { onLeaveFolderGroup() }
            }
        }

        return Group {
            if isAction {
                let act = actions[i - apps.count]
                cardBody.onDrop(of: [.fileURL], isTargeted: nil) { p in
                    guard act.targetURL != nil else { return false }
                    act.handleDrop(providers: p); return true
                }
            } else if i >= apps.count + actions.count {
                let g = i - apps.count - actions.count
                cardBody.onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    handleDropIntoGroup(providers: providers, groupIndex: g)
                }
            } else {
                cardBody.onDrag {
                    NSItemProvider(contentsOf: apps[i].url) ?? NSItemProvider(object: apps[i].url as NSURL)
                }
            }
        }
        .scaleEffect(vis ? (isH && !lp ? settings.hoverScale : 1) : (lp || bloom ? 1 : 0.01))
        .opacity(vis ? 1 : 0)
        .offset(x: bloom || vis ? x : (lp ? x : px), y: bloom || vis ? y : (lp ? y : py))
        .animation(lp ? nil : .spring(response: baseDuration * 0.6, dampingFraction: 0.78), value: isH)
        .animation(lp ? nil : .spring(response: baseDuration * 0.8, dampingFraction: 0.75), value: vis)
    }
    
    private func haptic() {
        performHaptic(settings)
    }

    @ViewBuilder private func cardIcon(_ i: Int, _ size: CGFloat) -> some View {
        let scale = settings.iconScale
        if i < apps.count {
            Image(nsImage: apps[i].icon).resizable().aspectRatio(contentMode: .fit).frame(width: size*scale, height: size*scale)
        } else if i < apps.count + actions.count {
            let act = actions[i-apps.count]
            if let img = act.folderImage {
                Image(nsImage: img).resizable().aspectRatio(contentMode: .fit).frame(width: size*scale, height: size*scale)
            } else {
                let s = size * scale * 0.65
                Image(systemName: act.icon).font(.system(size: s, weight: .medium))
                    .foregroundStyle(.primary).frame(width: s*1.2, height: s*1.2)
            }
        } else {
            let s = size * scale * 0.65
            Image(systemName: "square.grid.2x2.fill").font(.system(size: s, weight: .medium))
                .foregroundStyle(.primary).frame(width: s*1.2, height: s*1.2)
        }
    }
}

// MARK: - Shapes

struct PieSliceShape: Shape {
    let narrowFactor: CGFloat, rotation: Double
    func path(in rect: CGRect) -> Path {
        let s=min(rect.width,rect.height),c=CGPoint(x:rect.midX,y:rect.midY)
        let h=s/2,n=h*narrowFactor,cr=4.0/s
        let a = rotation * .pi/180, ca = cos(a), sa = sin(a)
        func r(_ p:CGPoint)->CGPoint{.init(x:c.x+p.x*ca-p.y*sa,y:c.y+p.x*sa+p.y*ca)}
        func l(_ a:CGPoint,_ b:CGPoint,_ t:CGFloat)->CGPoint{.init(x:a.x+(b.x-a.x)*t,y:a.y+(b.y-a.y)*t)}
        let tl=r(.init(x:-h,y:-h)),tr=r(.init(x:h,y:-h))
        let br=r(.init(x:n,y:h)),bl=r(.init(x:-n,y:h))
        let oc=r(.init(x:0,y:-h-s*0.06)),ic=r(.init(x:0,y:h-s*0.06))
        var p=Path()
        p.move(to:l(tl,tr,cr))
        p.addQuadCurve(to:l(tr,tl,cr),control:oc)
        p.addQuadCurve(to:l(tr,br,cr),control:tr)
        p.addLine(to:l(br,tr,cr))
        p.addQuadCurve(to:l(br,bl,cr),control:br)
        p.addQuadCurve(to:l(bl,br,cr),control:ic)
        p.addQuadCurve(to:l(bl,tl,cr),control:bl)
        p.addLine(to:l(tl,bl,cr))
        p.addQuadCurve(to:l(tl,tr,cr),control:tl)
        p.closeSubpath()
        return p
    }
}

struct DonutShape: Shape {
    let outerRadius: CGFloat, innerRadius: CGFloat
    func path(in rect: CGRect) -> Path {
        let c=CGPoint(x:rect.midX,y:rect.midY)
        var p=Path()
        p.addArc(center:c,radius:outerRadius,startAngle:.zero,endAngle:.degrees(360),clockwise:false)
        p.addArc(center:c,radius:innerRadius,startAngle:.degrees(360),endAngle:.zero,clockwise:true)
        return p
    }
}

struct ArcSegmentShape: Shape, Animatable {
    var outerRadius: CGFloat, innerRadius: CGFloat, start: Double, end: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(start, end) }
        set { start = newValue.first; end = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var p = Path()
        p.addArc(center: c, radius: outerRadius, startAngle: .radians(start * .pi / 180), endAngle: .radians(end * .pi / 180), clockwise: false)
        p.addArc(center: c, radius: innerRadius, startAngle: .radians(end * .pi / 180), endAngle: .radians(start * .pi / 180), clockwise: true)
        p.closeSubpath()
        return p
    }
}


struct AnyShape: Shape, @unchecked Sendable {
    private let b: (CGRect) -> Path
    init<S: Shape>(_ s: S) { b = { s.path(in: $0) } }
    func path(in rect: CGRect) -> Path { b(rect) }
}

struct ArcOffsetEffect: GeometryEffect {
    var angle: Double
    var radius: CGFloat

    var animatableData: AnimatablePair<Double, CGFloat> {
        get { AnimatablePair(angle, radius) }
        set { angle = newValue.first; radius = newValue.second }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let rad = angle * .pi / 180
        let t = CGAffineTransform(translationX: cos(rad) * radius, y: sin(rad) * radius)
        return ProjectionTransform(t)
    }
}

// MARK: - Submenu

final class SubmenuState: ObservableObject {
    @Published var apps: [AppItem] = []
    @Published var dir: Double = -90
    @Published var radius: CGFloat = 0
    @Published var cardSize: CGFloat = 0
    @Published var edgePadDeg: Double = 0
    @Published var midGapDeg: Double = 0
    @Published var isClosing = false
}

private func performHaptic(_ settings: AppSettings) {
    guard settings.haptics else { return }
    let styles: [NSHapticFeedbackManager.FeedbackPattern] = [.levelChange, .generic, .alignment]
    let style = styles[min(max(settings.hapticStyle, 0), styles.count - 1)]
    NSHapticFeedbackManager.defaultPerformer.perform(style, performanceTime: .now)
}

struct SubmenuView: View {
    @ObservedObject var state: SubmenuState
    let settings: AppSettings
    let onSelect: (AppItem) -> Void
    let onHover: (Bool) -> Void
    let onDelete: ((Int) -> Void)?
    private var baseDuration: Double { 0.3 / max(settings.animSpeed, 0.1) }
    private var submenuDuration: Double { baseDuration * 1.5 }
    @State private var hovered: Int? = nil
    @State private var hoveredIndex: Int? = nil
    @State private var lastHoveredIndex: Int? = nil
    @State private var deleteIndex: Int? = nil
    @State private var ringVis = false
    @State private var rightClickMonitor: Any? = nil

    private var geometrySignature: String {
        "\(state.apps.count)_\(state.dir)_\(state.radius)_\(state.cardSize)_\(state.edgePadDeg)_\(state.midGapDeg)"
    }

    var body: some View {
        Group {
            if state.radius > 0 {
                submenuContent
            } else {
                Color.clear
            }
        }
        .onAppear {
            rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown]) { [self] event in
                if let idx = hoveredIndex ?? lastHoveredIndex {
                    withAnimation(.easeOut(duration: 0.12)) { deleteIndex = idx }
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = rightClickMonitor {
                NSEvent.removeMonitor(monitor)
                rightClickMonitor = nil
            }
        }
        .onChange(of: state.isClosing) { _, closing in
            if closing {
                withAnimation(.easeIn(duration: submenuDuration * 1.5)) { ringVis = false }
                withAnimation(.easeOut(duration: 0.08)) { deleteIndex = nil }
                lastHoveredIndex = nil
                // Не показывать имя элемента/папки подменю во время анимации закрытия
                PieMenuState.shared.hoveredApp = nil
                PieMenuState.shared.hoveredAction = nil
            }
        }
        .onChange(of: state.apps) { _, _ in
            withAnimation(.easeOut(duration: 0.08)) { deleteIndex = nil }
            lastHoveredIndex = nil
            // При смене содержимого подменю сбрасываем hover, чтобы не висело имя старого элемента
            PieMenuState.shared.hoveredApp = nil
        }
        .onChange(of: hoveredIndex) { _, new in
            if let new, new != deleteIndex {
                withAnimation(.easeOut(duration: 0.12)) { deleteIndex = nil }
            }
        }
    }

    private var submenuContent: some View {
        let lp = settings.lowPower
        let outline = Color.primary.opacity(0.125)
        let bgThick = max(26, settings.ringThickness * 0.85)
        let outerR = state.radius + bgThick / 2
        let innerR = max(state.radius - bgThick / 2, 0)
        let size = state.radius * 2 + state.cardSize + 80
        let n = Double(max(state.apps.count, 1))
        let iconAng = state.cardSize / state.radius * 180 / .pi
        let edgePad = state.edgePadDeg
        let midGap = state.midGapDeg
        let iconSpan = 2 * edgePad + max(0, n - 1) * midGap + n * iconAng
        let bgSpan = min(260.0, iconSpan + 2 * 0.625)
        let iconStart = state.dir - iconSpan / 2
        let bgStart = iconStart - 0.625

        return ZStack {
            ZStack {
                // Прозрачный фон на весь размер окна — не дает кликам/ховерам
                // проходить сквозь подменю к главному меню за ним
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .frame(width: size, height: size)

                ArcSegmentShape(outerRadius: outerR, innerRadius: innerR, start: bgStart, end: bgStart + bgSpan)
                    .fill(lp ? AnyShapeStyle(lpColor) : AnyShapeStyle(settings.menuMaterial))
                    .overlay(ArcSegmentShape(outerRadius: outerR, innerRadius: innerR, start: bgStart, end: bgStart + bgSpan).stroke(outline, lineWidth: 1.5))
                    .frame(width: size, height: size)
                    .onHover { on in
                        if on {
                            onHover(true)
                        } else {
                            onHover(false)
                            PieMenuState.shared.hoveredApp = nil
                        }
                    }

                ForEach(0..<state.apps.count, id: \.self) { i in
                    let iconOffset = edgePad + iconAng / 2
                    let itemStep = Double(i) * (iconAng + midGap)
                    let ang = iconStart + iconOffset + itemStep
                    let rr = state.radius
                    let iconSize = state.cardSize * settings.iconScale
                    submenuItem(i, iconSize: iconSize, radius: rr, angle: ang, lp: lp)
                }

                // Мертвая зона в центре: клик/ховер здесь не должен выбирать элемент подменю
                let deadZone = max(0, min(state.radius - state.cardSize * settings.iconScale * 0.75, 140))
                Circle()
                    .fill(Color.black.opacity(0.0001))
                    .contentShape(Circle())
                    .frame(width: deadZone, height: deadZone)

                if onDelete != nil {
                    let deleteIconOffset = edgePad + iconAng / 2
                    ForEach(0..<state.apps.count, id: \.self) { i in
                        let deleteItemStep = Double(i) * (iconAng + midGap)
                        let deleteAng = iconStart + deleteIconOffset + deleteItemStep
                        let deleteRad = deleteAng * .pi / 180
                        let iconCenterR = state.radius + 6.0
                        let iconX = cos(deleteRad) * iconCenterR
                        let iconY = sin(deleteRad) * iconCenterR
                        let visible = deleteIndex == i
                        Button {
                            onDelete?(i)
                            withAnimation(.easeOut(duration: 0.12)) { deleteIndex = nil }
                        } label: {
                            Label("Remove", systemImage: "trash")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.red))
                        }
                        .buttonStyle(.plain)
                        .offset(x: iconX + 44, y: iconY + 20)
                        .opacity(visible ? 1 : 0)
                        .allowsHitTesting(visible)
                        .zIndex(1)
                    }
                }
            }
            .frame(width: size, height: size)
            .opacity(ringVis ? 1 : 0)
            .blur(radius: lp || settings.ringOpenAnim != 1 ? 0 : (ringVis ? 0 : 100))
            .animation(lp ? nil : (settings.ringOpenAnim == 1 ? .easeOut(duration: submenuDuration) : .easeOut(duration: submenuDuration * 0.5)), value: ringVis)
            .animation(lp ? nil : .easeOut(duration: submenuDuration * 0.5), value: geometrySignature)
        }
        .scaleEffect(settings.ringOpenAnim == 1 ? (ringVis ? 1 : 0.5) : (!lp ? (ringVis ? 1 : 0.96) : 1))
        .animation(lp ? nil : (settings.ringOpenAnim == 1 ? .spring(response: submenuDuration * 1.5, dampingFraction: 0.55) : .easeOut(duration: submenuDuration * 0.5)), value: ringVis)
        .onAppear {
            if settings.ringOpenAnim == 1 {
                withAnimation(.spring(response: submenuDuration * 1.5, dampingFraction: 0.55)) { ringVis = true }
            } else {
                withAnimation(.easeOut(duration: submenuDuration * 0.5)) { ringVis = true }
            }
        }
    }

    private func submenuItem(_ i: Int, iconSize: CGFloat, radius: CGFloat, angle: Double, lp: Bool) -> some View {
        let rr = radius + (hovered == i && !lp ? 6.0 : 0.0)
        return Image(nsImage: state.apps[i].icon)
            .resizable().aspectRatio(contentMode: .fit)
            .frame(width: iconSize, height: iconSize)
            .frame(width: iconSize * 1.5, height: iconSize * 1.5)
            .scaleEffect(hovered == i && !lp ? settings.hoverScale : 1)
            .modifier(ArcOffsetEffect(angle: angle, radius: rr))
            .onHover { on in
                hovered = on ? i : nil
                hoveredIndex = on ? i : nil
                if on {
                    lastHoveredIndex = i
                    onHover(true)
                    PieMenuState.shared.hoveredApp = state.apps[i]
                    performHaptic(settings)
                } else {
                    PieMenuState.shared.hoveredApp = nil
                }
            }
            .animation(.spring(response: 0.18, dampingFraction: 0.75), value: hovered)
            .transition(.asymmetric(
                insertion: .opacity.animation(.easeOut(duration: 0.12).delay(0.08)),
                removal: .identity
            ))
            .onTapGesture { onSelect(state.apps[i]) }
    }
}
