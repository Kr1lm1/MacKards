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
        pieBody
            .onAppear { startAnimation() }
    }
    
    // Single timer drives the staggered reveal
    private func startAnimation() {
        let count = total
        let interval: Double = 0.015
        var i = 0
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            i += 1
            withAnimation(.spring(response: 0.18, dampingFraction: 0.75)) { shown = i }
            if i >= count { timer.invalidate() }
        }
    }
    
    private var pieBody: some View {
        let n = CGFloat(total)
        let circ = 2.0 * .pi * settings.radius
        let card = min((circ - 0.5 * n) / n, settings.cardSize)
        let size = settings.radius * 2 + card + 60
        return ZStack {
            ForEach(0..<total, id: \.self) { i in pieCard(i, card: card) }
        }.frame(width: size, height: size)
    }
    
    private func pieCard(_ i: Int, card: CGFloat) -> some View {
        let slice = 360.0 / Double(total)
        let ang = slice * Double(i) - 90
        let rad = ang * .pi / 180
        let isH = hovered == i
        let vis = i < shown && !state.isClosing
        let r = settings.radius + (isH ? 6.0 : 0)
        let x = cos(rad) * r, y = sin(rad) * r
        let px = cos((slice * Double(max(i-1, 0)) - 90) * .pi / 180) * settings.radius
        let py = sin((slice * Double(max(i-1, 0)) - 90) * .pi / 180) * settings.radius
        
        let sliceShape = PieSliceShape(narrowFactor: 0.55, rotation: ang + 90)
        
        return ZStack {
            // Solid translucent background (no blur = no GPU cost)
            sliceShape
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.82))
                .frame(width: card, height: card)
            
            // Border
            sliceShape
                .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                .frame(width: card, height: card)
            
            // Content
            cardContent(i, size: card)
                .frame(width: card, height: card)
        }
        .frame(width: card, height: card)
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        .contentShape(sliceShape)
        .onTapGesture { trigger(i) }
        .onHover { setHover(i, $0) }
        .onDrop(of: [.fileURL], isTargeted: nil) { handleDrop(i, $0) }
        .scaleEffect(vis ? (isH ? 1.08 : 1.0) : 0.01)
        .opacity(vis ? 1 : 0)
        .offset(x: vis ? x : px, y: vis ? y : py)
        .animation(.spring(response: 0.14, dampingFraction: 0.78), value: isH)
        .animation(.spring(response: 0.18, dampingFraction: 0.75), value: vis)
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private func cardContent(_ i: Int, size: CGFloat) -> some View {
        if i < apps.count {
            let app = apps[i]
            let iconSz = size * 0.58
            VStack(spacing: 2) {
                Image(nsImage: app.icon).resizable().aspectRatio(contentMode: .fit)
                    .frame(width: iconSz, height: iconSz)
                if settings.showLabels {
                    Text(app.name).font(.system(size: max(size * 0.12, 8), weight: .medium))
                        .foregroundStyle(.primary).lineLimit(1).frame(maxWidth: size - 6)
                }
            }
        } else {
            let act = actions[i - apps.count]
            let iconSz = size * 0.38
            VStack(spacing: 2) {
                Image(systemName: act.icon).font(.system(size: iconSz, weight: .medium))
                    .foregroundStyle(.primary).frame(width: iconSz * 1.2, height: iconSz * 1.2)
                if settings.showLabels {
                    Text(act.name).font(.system(size: max(size * 0.1, 7), weight: .medium))
                        .foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func trigger(_ i: Int) {
        if i < apps.count { onSelect(apps[i]) } else { onAction(actions[i - apps.count]) }
    }
    
    private func handleDrop(_ i: Int, _ p: [NSItemProvider]) -> Bool {
        guard i >= apps.count else { return false }
        let act = actions[i - apps.count]
        guard act.targetURL != nil else { return false }
        act.handleDrop(providers: p); return true
    }
    
    private func setHover(_ i: Int, _ on: Bool) {
        hovered = on ? i : nil
        let s = PieMenuState.shared
        if on {
            if i < apps.count { s.hoveredApp = apps[i]; s.hoveredAction = nil }
            else { s.hoveredApp = nil; s.hoveredAction = actions[i - apps.count] }
        } else { s.hoveredApp = nil; s.hoveredAction = nil }
    }
}

// MARK: - Pie Slice Shape

struct PieSliceShape: Shape {
    let narrowFactor: CGFloat
    let rotation: Double
    
    func path(in rect: CGRect) -> Path {
        let size = min(rect.width, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let half = size / 2
        let narrow = half * narrowFactor
        let cr = 4.0 / size
        
        let tl = CGPoint(x: -half, y: -half)
        let tr = CGPoint(x: half, y: -half)
        let br = CGPoint(x: narrow, y: half)
        let bl = CGPoint(x: -narrow, y: half)
        let oc = CGPoint(x: 0, y: -half - size * 0.06)
        let ic = CGPoint(x: 0, y: half - size * 0.06)
        
        let a = rotation * .pi / 180
        let cosA = cos(a), sinA = sin(a)
        func rot(_ p: CGPoint) -> CGPoint {
            CGPoint(x: center.x + p.x * cosA - p.y * sinA,
                    y: center.y + p.x * sinA + p.y * cosA)
        }
        func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
        
        let rTL = rot(tl), rTR = rot(tr), rBR = rot(br), rBL = rot(bl)
        let rOC = rot(oc), rIC = rot(ic)
        
        var path = Path()
        path.move(to: lerp(rTL, rTR, cr))
        path.addQuadCurve(to: lerp(rTR, rTL, cr), control: rOC)
        path.addQuadCurve(to: lerp(rTR, rBR, cr), control: rTR)
        path.addLine(to: lerp(rBR, rTR, cr))
        path.addQuadCurve(to: lerp(rBR, rBL, cr), control: rBR)
        path.addQuadCurve(to: lerp(rBL, rBR, cr), control: rIC)
        path.addQuadCurve(to: lerp(rBL, rTL, cr), control: rBL)
        path.addLine(to: lerp(rTL, rBL, cr))
        path.addQuadCurve(to: lerp(rTL, rTR, cr), control: rTL)
        path.closeSubpath()
        return path
    }
}
