import SwiftUI

/// Live tow-curve diagram matching Pixel mock3.
/// Uses `CatenaryMath.Result` only — true catenary path scaled to spanL/sag.
/// Depth and sag are drawn with a **2× vertical stretch** vs horizontal.
struct CatenaryTowCurveDiagram: View {
    /// Free-hang result; nil → placeholder (dashes, no crash).
    var result: CatenaryMath.Result?
    /// Water depth in metres when set; draws seabed dashed line + 2× caption.
    var depthMeters: Double?

    private let verticalStretch: CGFloat = 2
    private let leftPad: CGFloat = 96
    private let rightPad: CGFloat = 46
    private let waterY: CGFloat = 74

    @State private var measuredWidth: CGFloat = 320

    var body: some View {
        let h = contentHeight(width: measuredWidth)
        Canvas { context, size in
            var ctx = context
            draw(context: &ctx, size: size)
        }
        .frame(maxWidth: .infinity)
        .frame(height: h)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { measuredWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, newWidth in
                        measuredWidth = newWidth
                    }
            }
        )
        .accessibilityLabel("Tow curve diagram")
    }

    private func contentHeight(width: CGFloat) -> CGFloat {
        let plotW = max(width - leftPad - rightPad, 40)
        guard let r = result, r.spanL > 0, r.spanL.isFinite, r.sag.isFinite else {
            return waterY + 72
        }
        let k = plotW / CGFloat(r.spanL)
        let maxDropM = max(r.sag, depthMeters ?? r.sag)
        let drop = CGFloat(maxDropM) * k * verticalStretch
        return waterY + max(drop, 36) + 28
    }

    private func draw(context: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let sx = leftPad
        let ex = w - rightPad
        let sy = waterY
        let plotW = max(ex - sx, 40)

        // Water fill under waterline
        let waterRect = CGRect(x: 0, y: sy, width: w, height: max(size.height - sy, 0))
        context.fill(
            Path(waterRect),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.07, green: 0.20, blue: 0.28).opacity(0.85),
                    Color(red: 0.04, green: 0.12, blue: 0.19).opacity(0.9)
                ]),
                startPoint: CGPoint(x: 0, y: sy),
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )

        // Waterline (wavy)
        var waterline = Path()
        waterline.move(to: CGPoint(x: 0, y: sy))
        var xPos: CGFloat = 0
        var guardCount = 0
        while xPos < w && guardCount < 80 {
            let mid = xPos + 8
            let next = min(xPos + 16, w)
            waterline.addQuadCurve(
                to: CGPoint(x: next, y: sy),
                control: CGPoint(x: mid, y: sy - 2.5)
            )
            xPos = next
            guardCount += 1
        }
        context.stroke(waterline, with: .color(Color(red: 0.25, green: 0.71, blue: 0.79)), lineWidth: 1.5)

        guard let r = result,
              r.spanL > 0, r.sag >= 0,
              r.spanL.isFinite, r.sag.isFinite,
              r.H_kg.isFinite, r.w > 0, r.w.isFinite else {
            drawBoat(context: &context, sternX: sx, sy: sy)
            drawRig(context: &context, x: ex, sy: sy)
            var dash = Path()
            dash.move(to: CGPoint(x: sx, y: sy))
            dash.addQuadCurve(
                to: CGPoint(x: ex, y: sy),
                control: CGPoint(x: (sx + ex) / 2, y: sy + 48)
            )
            context.stroke(
                dash,
                with: .color(AppTheme.teal.opacity(0.45)),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [6, 5])
            )
            drawSpanLabel(context: &context, sx: sx, ex: ex, sy: sy, text: ToolsParse.dash)
            return
        }

        let L = CGFloat(r.spanL)
        let hSag = CGFloat(r.sag)
        let a = CGFloat(r.H_kg / r.w)
        let k = plotW / L
        let V = verticalStretch

        let samples = 121
        var points: [CGPoint] = []
        points.reserveCapacity(samples)
        for i in 0..<samples {
            let xm = L * CGFloat(i) / CGFloat(samples - 1)
            let yDown: CGFloat
            if a > 0, a.isFinite {
                yDown = a * (coshVal(L / (2 * a)) - coshVal((xm - L / 2) / a))
            } else {
                let t = xm / max(L, 1)
                yDown = 4 * hSag * t * (1 - t)
            }
            let px = sx + xm * k
            let py = sy + yDown * k * V
            if px.isFinite, py.isFinite {
                points.append(CGPoint(x: px, y: py))
            }
        }

        let seabedY: CGFloat?
        if let d = depthMeters, d > 0, d.isFinite {
            seabedY = sy + CGFloat(d) * k * V
        } else {
            seabedY = nil
        }

        if let seaY = seabedY, let d = depthMeters {
            let band = CGRect(x: 0, y: seaY, width: w, height: max(size.height - seaY, 0))
            context.fill(Path(band), with: .color(Color(red: 0.10, green: 0.14, blue: 0.18).opacity(0.95)))
            var seaLine = Path()
            seaLine.move(to: CGPoint(x: 0, y: seaY))
            seaLine.addLine(to: CGPoint(x: w, y: seaY))
            context.stroke(
                seaLine,
                with: .color(Color(red: 0.54, green: 0.59, blue: 0.66)),
                style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
            )
            let seabedLabel = Text("Seabed \(ToolsParse.format(d, decimals: 0)) m")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(red: 0.54, green: 0.59, blue: 0.66))
            context.draw(seabedLabel, at: CGPoint(x: w - 6, y: seaY + 12), anchor: .trailing)
            let caption = Text("Depth drawn 2× for clarity")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(red: 0.54, green: 0.59, blue: 0.66))
            context.draw(caption, at: CGPoint(x: 6, y: seaY + 12), anchor: .leading)
        }

        let teal = Color(red: 0.37, green: 0.94, blue: 0.77)
        let hot = Color(red: 1.0, green: 0.35, blue: 0.37)
        if let seaY = seabedY, r.seabedWarning {
            strokeSplit(context: &context, points: points, seabedY: seaY, above: teal, below: hot)
        } else {
            var path = Path()
            if let first = points.first {
                path.move(to: first)
                for p in points.dropFirst() { path.addLine(to: p) }
            }
            context.stroke(path, with: .color(teal), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }

        drawBoat(context: &context, sternX: sx, sy: sy)
        drawRig(context: &context, x: ex, sy: sy)

        let spanText = "\(ToolsParse.format(r.spanL, decimals: 1)) m"
        drawSpanLabel(context: &context, sx: sx, ex: ex, sy: sy, text: spanText)

        let midX = sx + L / 2 * k
        let lowY = sy + hSag * k * V
        var sagLine = Path()
        sagLine.move(to: CGPoint(x: midX, y: sy))
        sagLine.addLine(to: CGPoint(x: midX, y: lowY))
        context.stroke(
            sagLine,
            with: .color(Color(red: 1.0, green: 0.82, blue: 0.40)),
            style: StrokeStyle(lineWidth: 1.2, dash: [3, 3])
        )
        let sagLabel = Text("Sag \(ToolsParse.format(r.sag, decimals: 1)) m")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.40))
        context.draw(sagLabel, at: CGPoint(x: midX + 6, y: (sy + lowY) / 2), anchor: .leading)

        let rollerLabel = Text("Stern roller")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.40))
        context.draw(rollerLabel, at: CGPoint(x: sx - 2, y: sy + 18), anchor: .trailing)
    }

    private func strokeSplit(
        context: inout GraphicsContext,
        points: [CGPoint],
        seabedY: CGFloat,
        above: Color,
        below: Color
    ) {
        guard points.count >= 2 else { return }

        func appendSeg(_ pts: [CGPoint], color: Color) {
            guard pts.count >= 2 else { return }
            var path = Path()
            path.move(to: pts[0])
            for p in pts.dropFirst() { path.addLine(to: p) }
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }

        var abovePts: [CGPoint] = []
        var belowPts: [CGPoint] = []

        for i in 0..<(points.count - 1) {
            let p0 = points[i]
            let p1 = points[i + 1]
            let a0 = p0.y <= seabedY + 0.01
            let a1 = p1.y <= seabedY + 0.01

            if a0 && a1 {
                if abovePts.isEmpty { abovePts.append(p0) }
                abovePts.append(p1)
                if !belowPts.isEmpty { appendSeg(belowPts, color: below); belowPts.removeAll(keepingCapacity: true) }
            } else if !a0 && !a1 {
                if belowPts.isEmpty { belowPts.append(p0) }
                belowPts.append(p1)
                if !abovePts.isEmpty { appendSeg(abovePts, color: above); abovePts.removeAll(keepingCapacity: true) }
            } else {
                let dy = p1.y - p0.y
                let t = abs(dy) < 1e-9 ? 0.5 : (seabedY - p0.y) / dy
                let clamped = min(max(t, 0), 1)
                let cross = CGPoint(x: p0.x + (p1.x - p0.x) * clamped, y: seabedY)
                if a0 {
                    if abovePts.isEmpty { abovePts.append(p0) }
                    abovePts.append(cross)
                    appendSeg(abovePts, color: above)
                    abovePts.removeAll(keepingCapacity: true)
                    belowPts = [cross, p1]
                } else {
                    if belowPts.isEmpty { belowPts.append(p0) }
                    belowPts.append(cross)
                    appendSeg(belowPts, color: below)
                    belowPts.removeAll(keepingCapacity: true)
                    abovePts = [cross, p1]
                }
            }
        }
        appendSeg(abovePts, color: above)
        appendSeg(belowPts, color: below)
    }

    private func drawSpanLabel(context: inout GraphicsContext, sx: CGFloat, ex: CGFloat, sy: CGFloat, text: String) {
        let y = sy - 60
        var dim = Path()
        dim.move(to: CGPoint(x: sx, y: y))
        dim.addLine(to: CGPoint(x: ex, y: y))
        context.stroke(dim, with: .color(Color(red: 0.54, green: 0.59, blue: 0.66)), lineWidth: 1)
        var t0 = Path(); t0.move(to: CGPoint(x: sx, y: y - 4)); t0.addLine(to: CGPoint(x: sx, y: y + 4))
        var t1 = Path(); t1.move(to: CGPoint(x: ex, y: y - 4)); t1.addLine(to: CGPoint(x: ex, y: y + 4))
        context.stroke(t0, with: .color(Color(red: 0.54, green: 0.59, blue: 0.66)), lineWidth: 1)
        context.stroke(t1, with: .color(Color(red: 0.54, green: 0.59, blue: 0.66)), lineWidth: 1)

        let mid = (sx + ex) / 2
        let label = Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.white)
        let pillW: CGFloat = max(CGFloat(text.count) * 7.2, 56)
        let pillRect = CGRect(x: mid - pillW / 2, y: y - 10, width: pillW, height: 16)
        context.fill(Path(roundedRect: pillRect, cornerRadius: 8), with: .color(Color(red: 0.07, green: 0.16, blue: 0.23)))
        context.draw(label, at: CGPoint(x: mid, y: y), anchor: .center)
    }

    private func drawBoat(context: inout GraphicsContext, sternX: CGFloat, sy: CGFloat) {
        let x = sternX
        var hull = Path()
        hull.move(to: CGPoint(x: x - 84, y: sy - 14))
        hull.addLine(to: CGPoint(x: x, y: sy - 6))
        hull.addLine(to: CGPoint(x: x, y: sy + 6))
        hull.addLine(to: CGPoint(x: x - 74, y: sy + 6))
        hull.addQuadCurve(to: CGPoint(x: x - 88, y: sy - 14), control: CGPoint(x: x - 84, y: sy + 2))
        hull.closeSubpath()
        context.fill(hull, with: .color(Color(red: 0.85, green: 0.89, blue: 0.93)))

        var boot = Path()
        boot.move(to: CGPoint(x: x - 84, y: sy - 14))
        boot.addLine(to: CGPoint(x: x, y: sy - 6))
        boot.addLine(to: CGPoint(x: x, y: sy - 4))
        boot.addLine(to: CGPoint(x: x - 86, y: sy - 12))
        boot.closeSubpath()
        context.fill(boot, with: .color(Color(red: 0.75, green: 0.22, blue: 0.17)))

        let accom = CGRect(x: x - 80, y: sy - 30, width: 26, height: 17)
        context.fill(Path(roundedRect: accom, cornerRadius: 2), with: .color(Color(red: 0.91, green: 0.93, blue: 0.96)))
        let bridge = CGRect(x: x - 77, y: sy - 40, width: 20, height: 10)
        context.fill(Path(roundedRect: bridge, cornerRadius: 2), with: .color(Color(red: 0.91, green: 0.93, blue: 0.96)))
        context.fill(Path(CGRect(x: x - 75, y: sy - 37, width: 16, height: 3)), with: .color(Color(red: 0.04, green: 0.13, blue: 0.20)))
        context.fill(Path(CGRect(x: x - 76, y: sy - 27, width: 18, height: 3)), with: .color(Color(red: 0.04, green: 0.13, blue: 0.20)))
        context.fill(Path(CGRect(x: x - 68, y: sy - 48, width: 2, height: 8)), with: .color(Color(red: 0.91, green: 0.93, blue: 0.96)))
        context.fill(Path(CGRect(x: x - 50, y: sy - 17, width: 8, height: 8)), with: .color(Color(red: 0.62, green: 0.69, blue: 0.76)))
        let roller = Path(ellipseIn: CGRect(x: x - 5, y: sy - 9, width: 6, height: 6))
        context.fill(roller, with: .color(Color(red: 1.0, green: 0.82, blue: 0.40)))
    }

    private func drawRig(context: inout GraphicsContext, x: CGFloat, sy: CGFloat) {
        let pontoon = CGRect(x: x - 6, y: sy - 2, width: 44, height: 8)
        context.fill(Path(roundedRect: pontoon, cornerRadius: 3), with: .color(Color(red: 0.85, green: 0.89, blue: 0.93)))
        context.fill(Path(CGRect(x: x, y: sy - 20, width: 5, height: 18)), with: .color(Color(red: 0.85, green: 0.89, blue: 0.93)))
        context.fill(Path(CGRect(x: x + 27, y: sy - 20, width: 5, height: 18)), with: .color(Color(red: 0.85, green: 0.89, blue: 0.93)))
        let deck = CGRect(x: x - 4, y: sy - 30, width: 40, height: 10)
        context.fill(Path(roundedRect: deck, cornerRadius: 2), with: .color(Color(red: 0.91, green: 0.93, blue: 0.96)))
        var derrick = Path()
        derrick.move(to: CGPoint(x: x + 12, y: sy - 30))
        derrick.addLine(to: CGPoint(x: x + 16, y: sy - 52))
        derrick.addLine(to: CGPoint(x: x + 20, y: sy - 30))
        context.stroke(derrick, with: .color(Color(red: 0.91, green: 0.93, blue: 0.96)), lineWidth: 1.5)
    }

    private func coshVal(_ x: CGFloat) -> CGFloat {
        let e = Foundation.exp(Double(x))
        let ie = Foundation.exp(Double(-x))
        return CGFloat((e + ie) / 2)
    }
}
