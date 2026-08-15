import SwiftUI
import UniformTypeIdentifiers

struct PieMenuContentView: View {
    let apps: [AppItem]
    let actions: [QuickAction]
    let settings: AppSettings
    let onSelect: (AppItem) -> Void
    let onAction: (QuickAction) -> Void
    
    @State private var shown = 0
    @State private var hovered: Int? = nil
    @ObservedObject private var state = PieMenuState.shared
    
    private var total: Int { apps.count + actions.count }
    
    var body: some View {
        pieBody.onAppear {
            if settings.lowPower { shown = total; return }
            let n = total; let spd = settings.animSpeed; var i = 0
            Timer.scheduledTimer(withTimeInterval: 0.015 / spd, repeats: true) { t in
                i += 1
                withAnimation(.spring(response: 0.18 / spd, dampingFraction: 0.75)) { shown = i }
                if i >= n { t.invalidate() }
            }
        }
    }
    
    private var pieBody: some View {
        let n = CGFloat(total)
        let circ = 2 * .pi * settings.radius
        let card = min((circ - 0.5 * n) / n, settings.cardSize)
        let size = settings.radius * 2 + card + 60
        return ZStack {
            ForEach(0..<total, id: \.self) { i in pieCard(i, card: card) }
            if settings.showLabels, let h = hovered {
                Text(h < apps.count ? apps[h].name : actions[h - apps.count].name)
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(.primary)
                    .lineLimit(1).frame(maxWidth: settings.radius * 1.2)
                    .animation(.easeOut(duration: 0.08), value: hovered)
            }
        }.frame(width: size, height: size)
    }
    
    private func pieCard(_ i: Int, card: CGFloat) -> some View {
        let slice = 360.0 / Double(total)
        let ang = slice * Double(i) - 90
        let rad = ang * .pi / 180
        let isH = hovered == i
        let vis = i < shown && !state.isClosing
        let lp = settings.lowPower
        let r = settings.radius + (isH ? 6.0 : 0)
        let x = cos(rad) * r, y = sin(rad) * r
        let pr = (slice * Double(max(i-1, 0)) - 90) * .pi / 180
        let px = cos(pr) * settings.radius, py = sin(pr) * settings.radius
        let shape = PieSliceShape(narrowFactor: 0.55, rotation: ang + 90)
        
        return ZStack {
            if lp {
                shape.fill(Color(nsColor: .windowBackgroundColor).opacity(0.9)).frame(width: card, height: card)
            } else {
                shape.fill(.thinMaterial).frame(width: card, height: card)
            }
            shape.stroke(Color.primary.opacity(0.15), lineWidth: 0.5).frame(width: card, height: card)
            cardContent(i, card)
        }
        .frame(width: card, height: card)
        .contentShape(shape)
        .onTapGesture { if i < apps.count { onSelect(apps[i]) } else { onAction(actions[i-apps.count]) } }
        .onHover { on in
            let prev = hovered; hovered = on ? i : nil
            let st = PieMenuState.shared
            if on {
                if i < apps.count { st.hoveredApp = apps[i]; st.hoveredAction = nil }
                else { st.hoveredApp = nil; st.hoveredAction = actions[i-apps.count] }
                if prev != i && settings.haptics { NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now) }
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
    
    @ViewBuilder private func cardContent(_ i: Int, _ size: CGFloat) -> some View {
        if i < apps.count {
            Image(nsImage: apps[i].icon).resizable().aspectRatio(contentMode: .fit).frame(width: size*0.6, height: size*0.6)
        } else {
            let s = size * 0.4
            Image(systemName: actions[i-apps.count].icon).font(.system(size: s, weight: .medium))
                .foregroundStyle(.primary).frame(width: s*1.2, height: s*1.2)
        }
    }
}

struct PieSliceShape: Shape {
    let narrowFactor: CGFloat
    let rotation: Double
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height), c = CGPoint(x: rect.midX, y: rect.midY)
        let h = s/2, n = h*narrowFactor, cr = 4.0/s
        let tl=CGPoint(x:-h,y:-h),tr=CGPoint(x:h,y:-h),br=CGPoint(x:n,y:h),bl=CGPoint(x:-n,y:h)
        let oc=CGPoint(x:0,y:-h-s*0.06),ic=CGPoint(x:0,y:h-s*0.06)
        let a=rotation * .pi/180, ca=cos(a), sa=sin(a)
        func r(_ p:CGPoint)->CGPoint{CGPoint(x:c.x+p.x*ca-p.y*sa,y:c.y+p.x*sa+p.y*ca)}
        func l(_ a:CGPoint,_ b:CGPoint,_ t:CGFloat)->CGPoint{CGPoint(x:a.x+(b.x-a.x)*t,y:a.y+(b.y-a.y)*t)}
        let rTL=r(tl),rTR=r(tr),rBR=r(br),rBL=r(bl),rOC=r(oc),rIC=r(ic)
        var p = Path()
        p.move(to:l(rTL,rTR,cr))
        p.addQuadCurve(to:l(rTR,rTL,cr),control:rOC)
        p.addQuadCurve(to:l(rTR,rBR,cr),control:rTR)
        p.addLine(to:l(rBR,rTR,cr))
        p.addQuadCurve(to:l(rBR,rBL,cr),control:rBR)
        p.addQuadCurve(to:l(rBL,rBR,cr),control:rIC)
        p.addQuadCurve(to:l(rBL,rTL,cr),control:rBL)
        p.addLine(to:l(rTL,rBL,cr))
        p.addQuadCurve(to:l(rTL,rTR,cr),control:rTL)
        p.closeSubpath()
        return p
    }
}
