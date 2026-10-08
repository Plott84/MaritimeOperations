import SwiftUI

// MARK: - Callouts (Scout wording → focus targets)

/// Five drum-geometry callouts on the Winch capacity HOW TO MEASURE sketch.
/// Raw values match Scout labels exactly (accessibility + on-diagram text).
enum WinchDrumCallout: String, CaseIterable, Identifiable {
    case wireDia = "wire/rope dia"
    case barrelD0 = "core (barrel) D0"
    case drumWidthW = "drum length/width W"
    case flangeDf = "outer (flange) Df"
    case freeSpace = "radial free space"

    var id: String { rawValue }

    /// Suggested `@FocusState` / TextField keys in WinchCapacityToolView.
    var focusFieldHint: String {
        switch self {
        case .wireDia: return "wireDia"
        case .barrelD0: return "barrelD0"
        case .drumWidthW: return "drumWidthW"
        case .flangeDf: return "flangeDf"
        case .freeSpace: return "freeSpace"
        }
    }

    /// Stable UITest id for the callout button (`winchCallout.wireDia`, …).
    var accessibilityIdentifier: String { "winchCallout.\(focusFieldHint)" }

    /// Matching TextField accessibilityIdentifier on the Winch form.
    var fieldAccessibilityIdentifier: String { "winchField.\(focusFieldHint)" }
}

// MARK: - Diagram

/// Side-view drum geometry sketch for the Winch capacity page.
/// Geometry guided by `/workspace/catenary/winch3.html` (viewBox 338×272).
/// Prefer readable SwiftUI over a pixel-perfect SVG port.
///
/// 2026-10-06 (Pixel): design space 368×272, which draws about 8% smaller than the 338 mock. The drum is drawn
/// at its mock coordinates and shifted right by `drumOffsetX` (12), so it is **centred**, with equal 68-unit margins
/// outside each flange. The two-line labels sit in those margins, mirrored: "outer / (flange) Df" has its
/// trailing edge pinned 6 left of the left flange, and "core / (barrel) D0" has its leading edge pinned 6 right of the right flange.
///
/// Dead wraps and 1st-layer pull are intentionally **not** drawn.
struct WinchDrumGeometryDiagram: View {
    /// Fired when the user taps a callout label (or its hit target).
    var onSelect: ((WinchDrumCallout) -> Void)?

    /// Design-space size: mock SVG viewBox 338×272 plus 15 each side for the two-line flange labels.
    private static let designSize = CGSize(width: 368, height: 272)

    /// Shift applied to the whole drum drawing (mock coords) so it is centred in `designSize`:
    /// flanges span 56…288 in mock coords, so centre 172 → 184 = 368 / 2.
    private static let drumOffsetX: CGFloat = 12
    /// Outer edges of the flanges in mock (drum) coords. Must match `drawDrum` (padL 56, 338 − padR 50).
    private static let leftFlangeOuterX: CGFloat = 56
    private static let rightFlangeOuterX: CGFloat = 288
    /// Gap between a flange's outer edge and the near edge of its two-line label (design units), same on both sides.
    private static let flangeLabelGap: CGFloat = 6
    /// Vertical centres of the two-line labels (design units).
    private static let barrelLabelCenterY: CGFloat = 98
    private static let flangeLabelCenterY: CGFloat = 122
    /// Horizontal padding inside `calloutLabel` (kept in sync so the *text* edge is what gets pinned).
    private static let labelHPadding: CGFloat = 6

    // Palette (app / mock)
    private static let teal = Color(red: 0x5f / 255, green: 0xf0 / 255, blue: 0xc4 / 255)       // #5ff0c4
    private static let tealAccent = Color(red: 0x5f / 255, green: 0xe0 / 255, blue: 0xc8 / 255) // #5fe0c8
    private static let gold = Color(red: 0xff / 255, green: 0xd1 / 255, blue: 0x66 / 255)       // #ffd166
    private static let labelLight = Color(red: 0xe8 / 255, green: 0xee / 255, blue: 0xf5 / 255) // #e8eef5
    private static let labelMuted = Color(red: 0xa5 / 255, green: 0xad / 255, blue: 0xb2 / 255) // #a5adb2
    private static let flangeFill = Color(red: 0x3a / 255, green: 0x43 / 255, blue: 0x48 / 255)
    private static let flangeStroke = Color(red: 0xc9 / 255, green: 0xd4 / 255, blue: 0xe0 / 255)
    private static let barrelFill = Color(red: 0x1a / 255, green: 0x23 / 255, blue: 0x2d / 255)
    private static let axisStroke = Color(red: 0x4a / 255, green: 0x53 / 255, blue: 0x57 / 255)
    private static let layerSep = Color(red: 0x0d / 255, green: 0x16 / 255, blue: 0x1d / 255)

    var body: some View {
        GeometryReader { geo in
            let scale = min(
                geo.size.width / Self.designSize.width,
                geo.size.height / Self.designSize.height
            )
            let drawn = CGSize(
                width: Self.designSize.width * scale,
                height: Self.designSize.height * scale
            )
            let origin = CGPoint(
                x: (geo.size.width - drawn.width) / 2,
                y: (geo.size.height - drawn.height) / 2
            )

            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    // Draw in design space, then scale into the canvas; drum shifted to centre.
                    context.scaleBy(x: scale, y: scale)
                    context.translateBy(x: Self.drumOffsetX, y: 0)
                    Self.drawDrum(in: &context)
                }
                .frame(width: drawn.width, height: drawn.height)

                // Invisible / lightly padded hit targets over Scout label positions.
                // The two flange labels (Df left, D0 right) are placed in the overlay below, pinned by their inner edge.
                ForEach(WinchDrumCallout.allCases.filter { $0 != .barrelD0 && $0 != .flangeDf }) { callout in
                    calloutButton(callout)
                        .position(Self.labelHitCenter(for: callout, scale: scale, origin: origin))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .overlay(alignment: .topLeading) {
                // Mirrored two-line labels, pinned by the edge nearest the drum so a wider label (Dynamic Type)
                // grows outward, away from the flange. Being overlays, they can't resize or shift the diagram.
                // Mac sim 2026-10-06: the alignment-guide version rendered both labels at the top-left corner,
                // so each label now sits in a 1-pt-tall pin frame: the frame edge is the pinned text edge and the
                // fixed-size label overflows outward from it (left for Df, right for D0), centred on its y.
                // Left: "outer / (flange) Df", trailing text edge `flangeLabelGap` left of the left flange.
                let trailX = origin.x + (Self.leftFlangeOuterX + Self.drumOffsetX - Self.flangeLabelGap) * scale + Self.labelHPadding
                let dfMidY = origin.y + Self.flangeLabelCenterY * scale
                // Right: "core / (barrel) D0", leading text edge `flangeLabelGap` right of the right flange.
                let leadX = origin.x + (Self.rightFlangeOuterX + Self.drumOffsetX + Self.flangeLabelGap) * scale - Self.labelHPadding
                let d0MidY = origin.y + Self.barrelLabelCenterY * scale
                ZStack(alignment: .topLeading) {
                    calloutButton(.flangeDf)
                        .fixedSize()
                        .frame(width: max(1, trailX), height: 1, alignment: .trailing)
                        .offset(y: dfMidY - 0.5)
                    calloutButton(.barrelD0)
                        .fixedSize()
                        .frame(width: max(1, geo.size.width - leadX), height: 1, alignment: .leading)
                        .offset(x: leadX, y: d0MidY - 0.5)
                }
            }
        }
        .aspectRatio(Self.designSize.width / Self.designSize.height, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Drum geometry diagram"))
    }

    /// Tappable callout. ID / label / hint unchanged (`winchCallout.*`, Scout wording).
    private func calloutButton(_ callout: WinchDrumCallout) -> some View {
        Button {
            onSelect?(callout)
        } label: {
            calloutLabel(callout)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(callout.accessibilityIdentifier)
        .accessibilityLabel(Text(callout.rawValue))
        .accessibilityHint(Text("Focuses the \(callout.focusFieldHint) field"))
    }

    @ViewBuilder
    private func calloutLabel(_ callout: WinchDrumCallout) -> some View {
        let color: Color = {
            switch callout {
            case .wireDia: return Self.teal
            case .freeSpace: return Self.gold
            case .barrelD0: return Self.labelLight
            case .drumWidthW, .flangeDf: return Self.labelMuted
            }
        }()

        let stacked = callout == .flangeDf || callout == .barrelD0
        Group {
            if callout == .flangeDf {
                VStack(alignment: .leading, spacing: 0) {
                    Text("outer")
                    Text("(flange) Df")
                }
            } else if callout == .barrelD0 {
                // Same two-line style as "outer / (flange) Df".
                VStack(alignment: .leading, spacing: 0) {
                    Text("core")
                    Text("(barrel) D0")
                }
            } else {
                Text(callout.rawValue)
            }
        }
        .font(.caption.weight(.semibold))
        // Pixel 2026-10-06: diagram callouts stop growing past xxxLarge (fields below keep full Dynamic Type).
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .foregroundStyle(color)
        .multilineTextAlignment(stacked ? .leading : .center)
        .padding(.horizontal, Self.labelHPadding)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    // MARK: Label hit centers (design → view)

    private static func labelHitCenter(
        for callout: WinchDrumCallout,
        scale: CGFloat,
        origin: CGPoint
    ) -> CGPoint {
        let p = labelAnchor(for: callout)
        return CGPoint(x: origin.x + (p.x + drumOffsetX) * scale, y: origin.y + p.y * scale)
    }

    /// Approximate text-anchor centers from winch3.svg coordinates (mock / drum coords; `drumOffsetX` is added).
    /// Df and D0 are overlay-pinned in `body`; their entries here are reference only.
    private static func labelAnchor(for callout: WinchDrumCallout) -> CGPoint {
        switch callout {
        case .wireDia: return CGPoint(x: 110, y: 12)          // "wire/rope dia" near (76, 14)
        case .freeSpace: return CGPoint(x: 248, y: 12)        // "radial free space" near (212, 14)
        case .flangeDf: return CGPoint(x: 56 - 6, y: 122)     // trailing edge left of flange (overlay-pinned, see body)
        case .barrelD0: return CGPoint(x: 288 + 6, y: 98)     // leading edge right of flange (overlay-pinned, see body)
        case .drumWidthW: return CGPoint(x: 172, y: 252)      // bottom center
        }
    }

    // MARK: Canvas drawing (design space 338×272)

    private static func drawDrum(in context: inout GraphicsContext) {
        // Locked example proportions (T/W SB): D0=1800, Df=4300, free=400 → 9 layers.
        let cy: CGFloat = 130
        let Rf: CGFloat = 92
        let D0: CGFloat = 1800
        let Df: CGFloat = 4300
        let free: CGFloat = 400
        let R0 = Rf * D0 / Df
        let Ru = Rf * (Df - 2 * free) / Df
        let flangeT: CGFloat = 18
        let padL: CGFloat = 56
        let padR: CGFloat = 50
        let xInnerL = padL + flangeT          // 74
        let xInnerR = 338 - padR - flangeT    // 270
        let xFlL0 = padL
        let xFlR0 = xInnerR
        let xFlR1 = 338 - padR
        let barrelTop = cy - R0
        let barrelBot = cy + R0
        let flTop = cy - Rf
        let flBot = cy + Rf
        let wireTop = cy - Ru
        let wireBot = cy + Ru
        let bw = xInnerR - xInnerL
        let layers = 9

        // Axis
        var axis = Path()
        axis.move(to: CGPoint(x: xFlL0 - 4, y: cy))
        axis.addLine(to: CGPoint(x: xFlR1 + 4, y: cy))
        context.stroke(
            axis,
            with: .color(axisStroke),
            style: StrokeStyle(lineWidth: 1, dash: [3, 3])
        )

        // Wire layers (upper + lower packs)
        for i in 0..<layers {
            let rIn = R0 + (Ru - R0) * CGFloat(i) / CGFloat(layers)
            let rOut = R0 + (Ru - R0) * CGFloat(i + 1) / CGFloat(layers)
            let op = 0.30 + 0.55 * CGFloat(i + 1) / CGFloat(layers)
            let h = rOut - rIn
            for y0 in [cy - rOut, cy + rIn] {
                let rect = CGRect(x: xInnerL, y: y0, width: bw, height: h)
                context.fill(Path(rect), with: .color(teal.opacity(op)))
                var sep = Path()
                sep.move(to: CGPoint(x: xInnerL, y: y0))
                sep.addLine(to: CGPoint(x: xInnerR, y: y0))
                context.stroke(sep, with: .color(layerSep.opacity(0.45)), lineWidth: 0.8)
            }
        }

        // Barrel
        let barrelRect = CGRect(x: xInnerL, y: barrelTop, width: bw, height: 2 * R0)
        context.fill(Path(barrelRect), with: .color(barrelFill))
        context.stroke(Path(barrelRect), with: .color(labelLight), lineWidth: 1.7)

        // Flanges
        let flL = CGRect(x: xFlL0, y: flTop, width: flangeT, height: 2 * Rf)
        let flR = CGRect(x: xFlR0, y: flTop, width: flangeT, height: 2 * Rf)
        for fl in [flL, flR] {
            let path = Path(roundedRect: fl, cornerRadius: 2.5)
            context.fill(path, with: .color(flangeFill))
            context.stroke(path, with: .color(flangeStroke), lineWidth: 1.7)
        }

        // Radial free-space bands (gold dashed)
        let freeUpper = CGRect(x: xInnerL, y: flTop, width: bw, height: wireTop - flTop)
        let freeLower = CGRect(x: xInnerL, y: wireBot, width: bw, height: flBot - wireBot)
        for band in [freeUpper, freeLower] {
            context.fill(Path(band), with: .color(gold.opacity(0.06)))
            context.stroke(
                Path(band),
                with: .color(gold),
                style: StrokeStyle(lineWidth: 1.25, dash: [4, 3])
            )
        }

        // --- Dimension lines (labels are SwiftUI buttons on top) ---

        // outer (flange) Df — on the left flange near its outer edge (mirrors the D0 dimension, which sits
        // over the right flange), so the margin outside each flange is free for its two-line label.
        strokeDimVertical(
            in: &context,
            x: xFlL0 + 5,
            y0: flTop,
            y1: flBot,
            tick: 4,
            color: labelMuted
        )

        // core (barrel) D0 — right of barrel + leader
        strokeDimVertical(
            in: &context,
            x: xInnerR + 7,
            y0: barrelTop,
            y1: barrelBot,
            tick: 4,
            color: labelLight
        )
        // Leader ends just outside the right flange, under the two-line label's leading edge.
        var d0Leader = Path()
        d0Leader.move(to: CGPoint(x: xInnerR + 7, y: cy))
        d0Leader.addLine(to: CGPoint(x: xFlR1 + 4, y: cy - 14))
        context.stroke(d0Leader, with: .color(labelLight), lineWidth: 1)

        // drum length/width W — bottom
        strokeDimHorizontal(
            in: &context,
            y: flBot + 14,
            x0: xInnerL,
            x1: xInnerR,
            tick: 4,
            color: labelMuted
        )

        // wire/rope dia — one mid-layer thickness (upper pack)
        let iMid = layers / 2
        let rInM = R0 + (Ru - R0) * CGFloat(iMid) / CGFloat(layers)
        let rOutM = R0 + (Ru - R0) * CGFloat(iMid + 1) / CGFloat(layers)
        let yWireMid = cy - (rInM + rOutM) / 2
        let xWire = xInnerL + 26
        strokeDimVertical(
            in: &context,
            x: xWire,
            y0: cy - rOutM,
            y1: cy - rInM,
            tick: 3.5,
            color: teal,
            lineWidth: 2.2,
            tickWidth: 1.5
        )
        var wireLeader = Path()
        wireLeader.move(to: CGPoint(x: xWire, y: yWireMid))
        wireLeader.addLine(to: CGPoint(x: 76, y: 18))
        context.stroke(wireLeader, with: .color(teal), lineWidth: 1)

        // radial free space — upper band
        let xFree = (xInnerL + xInnerR) / 2 + 10
        let yFreeMid = (flTop + wireTop) / 2
        strokeDimVertical(
            in: &context,
            x: xFree,
            y0: flTop,
            y1: wireTop,
            tick: 4,
            color: gold,
            lineWidth: 1.6,
            tickWidth: 1.4
        )
        var freeLeader = Path()
        freeLeader.move(to: CGPoint(x: xFree, y: yFreeMid))
        freeLeader.addLine(to: CGPoint(x: 212, y: 18))
        context.stroke(freeLeader, with: .color(gold), lineWidth: 1)
    }

    private static func strokeDimVertical(
        in context: inout GraphicsContext,
        x: CGFloat,
        y0: CGFloat,
        y1: CGFloat,
        tick: CGFloat,
        color: Color,
        lineWidth: CGFloat = 1.25,
        tickWidth: CGFloat = 1.25
    ) {
        var stem = Path()
        stem.move(to: CGPoint(x: x, y: y0))
        stem.addLine(to: CGPoint(x: x, y: y1))
        context.stroke(stem, with: .color(color), lineWidth: lineWidth)

        for y in [y0, y1] {
            var t = Path()
            t.move(to: CGPoint(x: x - tick, y: y))
            t.addLine(to: CGPoint(x: x + tick, y: y))
            context.stroke(t, with: .color(color), lineWidth: tickWidth)
        }
    }

    private static func strokeDimHorizontal(
        in context: inout GraphicsContext,
        y: CGFloat,
        x0: CGFloat,
        x1: CGFloat,
        tick: CGFloat,
        color: Color,
        lineWidth: CGFloat = 1.25,
        tickWidth: CGFloat = 1.25
    ) {
        var stem = Path()
        stem.move(to: CGPoint(x: x0, y: y))
        stem.addLine(to: CGPoint(x: x1, y: y))
        context.stroke(stem, with: .color(color), lineWidth: lineWidth)

        for x in [x0, x1] {
            var t = Path()
            t.move(to: CGPoint(x: x, y: y - tick))
            t.addLine(to: CGPoint(x: x, y: y + tick))
            context.stroke(t, with: .color(color), lineWidth: tickWidth)
        }
    }
}

// MARK: - Preview helpers (Mac / Xcode only)

#if DEBUG
struct WinchDrumGeometryDiagram_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HOW TO MEASURE")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(red: 0x5f / 255, green: 0xe0 / 255, blue: 0xc8 / 255))
                .tracking(1.6)
            Text("Drum geometry")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            WinchDrumGeometryDiagram { callout in
                print("select", callout.rawValue)
            }
            .frame(maxWidth: 360)
            Text("Where the measurements sit on the drum.")
                .font(.caption)
                .foregroundStyle(Color(red: 0xa5 / 255, green: 0xad / 255, blue: 0xb2 / 255))
                .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(red: 0x0d / 255, green: 0x16 / 255, blue: 0x1d / 255))
        .preferredColorScheme(.dark)
    }
}
#endif
