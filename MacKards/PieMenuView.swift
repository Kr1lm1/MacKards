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
    let onCloseSubmenu: () -> Void
    var arc: ClosedRange<Double>? = nil
    var bgArc: ClosedRange<Double>? = nil
    var radiusOverride: CGFloat? = nil
    var cardSizeOverride: CGFloat? = nil
    
    @State private var shown = 0
    @State private var hovered: Int? = nil
    @State private var ringVis = false
    @State private var menuScale: CGFloat = 0.01
    @State private var menuOpacity: Double = 0
    @ObservedObject private var state = PieMenuState.shared
    
    private var total: Int { apps.count + actions.count + groups.count }
    private var radius: CGFloat { radiusOverride ?? settings.radius }
    
    var body: some View {
        pieBody
            .onAppear { animateIn() }
            .onChange(of: state.isClosing) { closing in
                if closing {
                    withAnimation(.easeIn(duration: 0.08)) { menuOpacity = 0 }
                    withAnimation(.easeIn(duration: 0.16)) { menuScale = 0.01 }
                }
            }
    }
    
    private func animateIn() {
        let n = total, lp = settings.lowPower, spd = settings.animSpeed
        if arc != nil {
            shown = n; menuScale = 1; menuOpacity = 1
            withAnimation(.easeOut(duration: 0.12)) { ringVis = true }
            return
        }
        if lp {
            shown = n; ringVis = true; menuScale = 1; menuOpacity = 1
            return
        }
        let base = 0.22 / max(spd, 0.2)
        switch settings.openAnim {
        case 1: // bounce
            shown = n; ringVis = true
            withAnimation(.spring(response: base * 1.4, dampingFraction: 0.5)) { menuScale = 1; menuOpacity = 1 }
        default: // stagger
            withAnimation(.spring(response: 0.18 / max(spd, 0.2), dampingFraction: 0.75)) { ringVis = true }
            menuScale = 1; menuOpacity = 1
            var i = 0
            let interval = max(0.015 / spd, 0.01)
            Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { t in
                i += 1
                withAnimation(.spring(response: 0.14 / max(spd, 0.2), dampingFraction: 0.75)) { shown = i }
                if i >= n { t.invalidate() }
            }
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
        let closing = state.isClosing
        let outline = Color.primary.opacity(0.125)

        return ZStack {
            if ring {
                let outer = radius + thick/2, inner = max(radius - thick/2, 10)
                DonutShape(outerRadius: outer, innerRadius: inner)
                    .fill(lp ? AnyShapeStyle(lpColor) : settings.menuMaterial)
                    .frame(width: size, height: size)
                    .overlay(DonutShape(outerRadius: outer, innerRadius: inner).stroke(outline, lineWidth: 1.5).frame(width: size, height: size))
                    .scaleEffect(ringVis && !closing ? 1 : 0.85)
                    .opacity(ringVis && !closing ? 1 : 0)
                    .animation(lp ? nil : .spring(response: 0.2, dampingFraction: 0.75), value: ringVis)
                    .animation(lp ? nil : .easeIn(duration: 0.1), value: closing)
            } else if let arcRange = arc {
                let bgRange = bgArc ?? arcRange
                ZStack {
                    ArcShape(radius: radius, thickness: thick, start: bgRange.lowerBound, end: bgRange.upperBound)
                        .stroke(outline, style: StrokeStyle(lineWidth: thick + 3, lineCap: .butt))
                        .frame(width: size, height: size)
                    ArcShape(radius: radius, thickness: thick, start: bgRange.lowerBound, end: bgRange.upperBound)
                        .stroke(lp ? AnyShapeStyle(lpColor) : AnyShapeStyle(settings.menuMaterial), style: StrokeStyle(lineWidth: thick, lineCap: .butt))
                        .frame(width: size, height: size)
                    ForEach(0..<apps.count, id: \.self) { i in
                        let span = arcRange.upperBound - arcRange.lowerBound
                        let n = Double(max(apps.count, 1))
                        let iconAng = card / radius * 180 / .pi
                        let gapAng = max(2.0, (span - n * iconAng) / (n + 1))
                        let ang = arcRange.lowerBound + gapAng + Double(i) * (iconAng + gapAng)
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
                                if on, settings.haptics {
                                    let styles: [NSHapticFeedbackManager.FeedbackPattern] = [.levelChange, .generic, .alignment]
                                    let style = styles[min(max(settings.hapticStyle, 0), styles.count - 1)]
                                    NSHapticFeedbackManager.defaultPerformer.perform(style, performanceTime: .now)
                                }
                            }
                            .offset(x: cx, y: cy)
                            .animation(.spring(response: 0.18, dampingFraction: 0.75), value: hovered)
                            .onTapGesture { onSelect(apps[i]) }
                    }
                }
                .scaleEffect(ringVis ? 1 : 0.96)
                .opacity(ringVis ? 1 : 0)
                .animation(lp ? nil : .easeOut(duration: 0.12), value: ringVis)
            }

            if arc == nil {
                ForEach(0..<total, id: \.self) { i in pieCard(i, card: card, ring: ring) }
            }

            if total == 0 {
                Text("No apps in group").font(.system(size: 12)).foregroundStyle(.secondary)
            }

            if settings.showLabels, let h = hovered {
                let label = h < apps.count ? apps[h].name
                    : h < apps.count + actions.count ? actions[h - apps.count].name
                    : groups[h - apps.count - actions.count].name
                Text(label)
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(.primary)
                    .lineLimit(1).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(lp ? AnyShapeStyle(lpColor) : AnyShapeStyle(.thinMaterial)))
                    .frame(maxWidth: radius * 1.2)
                    .animation(.easeOut(duration: 0.08), value: hovered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scaleEffect(lp ? 1 : menuScale)
        .opacity(lp ? 1 : menuOpacity)
    }
    
    private func pieCard(_ i: Int, card: CGFloat, ring: Bool) -> some View {
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
        
        return ZStack {
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
                if i < apps.count { st.hoveredApp = apps[i]; st.hoveredAction = nil; if arc == nil { onCloseSubmenu() } }
                else if i < apps.count + actions.count { st.hoveredApp = nil; st.hoveredAction = actions[i - apps.count]; if arc == nil { onCloseSubmenu() } }
                else {
                    st.hoveredApp = nil; st.hoveredAction = nil
                    if arc == nil {
                        let g = i - apps.count - actions.count
                        if g < groups.count { onGroup(groups[g]) }
                    }
                }
                if prev != i && settings.haptics {
                    let styles: [NSHapticFeedbackManager.FeedbackPattern] = [.levelChange, .generic, .alignment]
                    let style = styles[min(max(settings.hapticStyle, 0), styles.count - 1)]
                    NSHapticFeedbackManager.defaultPerformer.perform(style, performanceTime: .now)
                }
            } else { st.hoveredApp = nil; st.hoveredAction = nil }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { p in
            guard i >= apps.count, i < apps.count + actions.count else { return false }
            let act = actions[i - apps.count]; guard act.targetURL != nil else { return false }
            act.handleDrop(providers: p); return true
        }
        .scaleEffect(vis ? (isH && !lp ? settings.hoverScale : 1) : (lp ? 1 : 0.01))
        .opacity(vis ? 1 : 0)
        .offset(x: vis ? x : (lp ? x : px), y: vis ? y : (lp ? y : py))
        .animation(lp ? nil : .spring(response: 0.14, dampingFraction: 0.78), value: isH)
        .animation(lp ? nil : .spring(response: 0.18, dampingFraction: 0.75), value: vis)
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

struct ArcShape: Shape {
    let radius: CGFloat, thickness: CGFloat, start: Double, end: Double
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var p = Path()
        p.addArc(center: c, radius: radius, startAngle: .radians(start * .pi / 180), endAngle: .radians(end * .pi / 180), clockwise: false)
        return p
    }
}


struct AnyShape: Shape {
    private let b: (CGRect)->Path
    init<S:Shape>(_ s:S){b={s.path(in:$0)}}
    func path(in rect:CGRect)->Path{b(rect)}
}
