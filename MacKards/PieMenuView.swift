import SwiftUI
import UniformTypeIdentifiers

private let lpColor = Color(nsColor: .controlBackgroundColor)

struct PieMenuContentView: View {
    let apps: [AppItem]
    let actions: [QuickAction]
    let settings: AppSettings
    let onSelect: (AppItem) -> Void
    let onAction: (QuickAction) -> Void
    
    @State private var shown = 0
    @State private var hovered: Int? = nil
    @State private var ringVis = false
    @State private var menuScale: CGFloat = 0.01
    @State private var menuOpacity: Double = 0
    @ObservedObject private var state = PieMenuState.shared
    
    private var total: Int { apps.count + actions.count }
    
    var body: some View {
        pieBody
            .onAppear { animateIn() }
            .onChange(of: state.isClosing) { closing in
                if closing {
                    menuScale = 0.01
                    menuOpacity = 0
                }
            }
    }
    
    private func animateIn() {
        let n = total, lp = settings.lowPower, spd = settings.animSpeed
        if lp {
            shown = n; ringVis = true; menuScale = 1; menuOpacity = 1
            return
        }
        switch settings.openAnim {
        case 1: // scale
            shown = n; ringVis = true
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) { menuScale = 1; menuOpacity = 1 }
        case 2: // fade
            shown = n; ringVis = true
            withAnimation(.easeOut(duration: 0.28)) { menuScale = 1; menuOpacity = 1 }
        case 3: // bounce
            shown = n; ringVis = true
            withAnimation(.interpolatingSpring(stiffness: 180, damping: 8)) { menuScale = 1; menuOpacity = 1 }
        default: // stagger
            withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) { ringVis = true }
            menuScale = 1; menuOpacity = 1
            var i = 0
            Timer.scheduledTimer(withTimeInterval: 0.015/spd, repeats: true) { t in
                i += 1
                withAnimation(.spring(response: 0.18/spd, dampingFraction: 0.75)) { shown = i }
                if i >= n { t.invalidate() }
            }
        }
    }
    
    private var pieBody: some View {
        let n = CGFloat(total), lp = settings.lowPower
        let circ = 2 * .pi * settings.radius
        let card = min((circ - settings.cardGap * n) / n, settings.cardSize)
        let size = settings.radius * 2 + card + 60
        let ring = settings.menuStyle == 1
        let thick = settings.ringThickness
        let closing = state.isClosing
        
        return ZStack {
            if ring {
                let outer = settings.radius + thick/2, inner = max(settings.radius - thick/2, 10)
                DonutShape(outerRadius: outer, innerRadius: inner)
                    .fill(lp ? AnyShapeStyle(lpColor) : AnyShapeStyle(.thinMaterial))
                    .frame(width: size, height: size)
                    .overlay(DonutShape(outerRadius: outer, innerRadius: inner).stroke(Color.primary.opacity(0.1), lineWidth: 0.5).frame(width: size, height: size))
                    .scaleEffect(ringVis && !closing ? 1 : 0.7)
                    .opacity(ringVis && !closing ? 1 : 0)
                    .animation(lp ? nil : .spring(response: 0.2, dampingFraction: 0.75), value: ringVis)
                    .animation(lp ? nil : .easeIn(duration: 0.1), value: closing)
            }
            
            ForEach(0..<total, id: \.self) { i in pieCard(i, card: card, ring: ring) }
            
            if settings.showLabels, let h = hovered {
                Text(h < apps.count ? apps[h].name : actions[h-apps.count].name)
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(.primary)
                    .lineLimit(1).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(lp ? AnyShapeStyle(lpColor) : AnyShapeStyle(.thinMaterial)))
                    .frame(maxWidth: settings.radius * 1.2)
                    .animation(.easeOut(duration: 0.08), value: hovered)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(lp ? 1 : menuScale)
        .opacity(lp ? 1 : menuOpacity)
    }
    
    private func pieCard(_ i: Int, card: CGFloat, ring: Bool) -> some View {
        let slice = 360.0 / Double(total)
        let ang = slice * Double(i) - 90, rad = ang * .pi / 180
        let lp = settings.lowPower
        let isH = hovered == i, vis = i < shown && !state.isClosing
        let r = settings.radius + (isH && !lp ? 6.0 : 0)
        let x = cos(rad) * r, y = sin(rad) * r
        let pr = (slice * Double(max(i-1,0)) - 90) * .pi / 180
        let px = cos(pr) * settings.radius, py = sin(pr) * settings.radius
        let shape = PieSliceShape(narrowFactor: 0.55, rotation: ang + 90)
        
        return ZStack {
            if !ring {
                shape.fill(lp ? AnyShapeStyle(lpColor) : AnyShapeStyle(.thinMaterial)).frame(width: card, height: card)
                shape.stroke(Color.primary.opacity(0.15), lineWidth: 0.5).frame(width: card, height: card)
            }
            cardIcon(i, card)
        }
        .frame(width: card, height: card)
        .contentShape(ring ? AnyShape(Circle()) : AnyShape(shape))
        .onTapGesture { i < apps.count ? onSelect(apps[i]) : onAction(actions[i-apps.count]) }
        .onHover { on in
            let prev = hovered; hovered = on ? i : nil
            let st = PieMenuState.shared
            if on {
                if i < apps.count { st.hoveredApp = apps[i]; st.hoveredAction = nil }
                else { st.hoveredApp = nil; st.hoveredAction = actions[i-apps.count] }
                if prev != i && settings.haptics {
                    NSHapticFeedbackManager.defaultPerformer.perform([.levelChange,.generic,.alignment][settings.hapticStyle], performanceTime: .now)
                }
            } else { st.hoveredApp = nil; st.hoveredAction = nil }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { p in
            guard i >= apps.count else { return false }
            let act = actions[i-apps.count]; guard act.targetURL != nil else { return false }
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
        } else {
            let act = actions[i-apps.count]
            if let img = act.folderImage {
                Image(nsImage: img).resizable().aspectRatio(contentMode: .fit).frame(width: size*scale, height: size*scale)
            } else {
                let s = size * scale * 0.65
                Image(systemName: act.icon).font(.system(size: s, weight: .medium))
                    .foregroundStyle(.primary).frame(width: s*1.2, height: s*1.2)
            }
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
        p.addArc(center:c,radius:innerRadius,startAngle:.zero,endAngle:.degrees(360),clockwise:true)
        return p
    }
}

struct AnyShape: Shape {
    private let b: (CGRect)->Path
    init<S:Shape>(_ s:S){b={s.path(in:$0)}}
    func path(in rect:CGRect)->Path{b(rect)}
}
