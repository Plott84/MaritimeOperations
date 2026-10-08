import SwiftUI

// Crane heel — Tools screen, B2 layout (iOS 18, SwiftUI).
// UNCOMPILED: written offline on the Linux box (no iOS SDK); only `swiftc -parse` was run. Build on the Mac.
// Design: /workspace/catenary/crane-heel-B2.png (+ crane-heel-B2.py / .html / crane-heel-B2-swing.gif).
//
// Thin view. Every string, number and show/hide rule comes from `CraneHeelPresentation` (Foundation only,
// unit-tested on Linux); the math is `CraneHeelMath`. Cards, top to bottom:
//   1. STATIC HEEL  — one heel (End), pill, stern view (looking forward from aft: stbd heel tilts right) with the
//                     stretched clinometer, ballast tile / "add distance" line, note.
//   2. LIFT         — Start · on deck / End · over side segment, Start + End rows (heel on End only), top-view ring
//                     (drag writes the active angle field), quick angles, Exact azimuth + Outreach fields.
//   3. CRANE        — hook load.
//   4. SHIP         — Δ, GM, distance between tanks, pivot off CL ("On CL").
//
// App helpers this file relies on (already in MaritimeOperations, see WIRING.md):
//   AppCanvas, GlassCard, AppTheme.{primaryBlue, teal, gold, danger, surface, textPrimary, textSecondary, border},
//   ToolNumberField(title:text:placeholder:unit:keyboard:isError:errorReason:accessibilityName:fieldAccessibilityIdentifier:),
//   ToolClearPill, ToolWarningPill, View.toolsKeyboardDone(onDone:)

struct CraneHeelView: View {
    private typealias P = CraneHeelPresentation

    /// All fields start empty. Example values only in #Preview; no default Δ/GM for any ship.
    @State private var inputs: CraneHeelPresentation.Inputs
    /// Which position the ring, quick buttons and the two Lift fields edit. End first (the lift over the side).
    @State private var position: CraneHeelPresentation.LiftPosition = .end
    @FocusState private var focusedField: CraneHeelPresentation.Field?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(inputs: CraneHeelPresentation.Inputs = .empty, position: CraneHeelPresentation.LiftPosition = .end) {
        _inputs = State(initialValue: inputs)
        _position = State(initialValue: position)
    }

    var body: some View {
        let state = CraneHeelPresentation(inputs: inputs)
        ZStack {
            AppCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GlassCard { heroCard(state) }
                    GlassCard { liftCard(state) }
                    GlassCard { craneCard(state) }
                    GlassCard { shipCard(state) }
                    Text(P.footer)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("craneResult.footer")
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(P.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolsKeyboardDone()
    }

    // MARK: - 1. STATIC HEEL

    @ViewBuilder
    private func heroCard(_ state: CraneHeelPresentation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            eyebrow(P.heroEyebrow, systemImage: "ferry")

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(state.lift == nil ? P.dash : "\(state.heelValueText)°")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(CraneColors.tone(state.tone))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(1)
                if let side = state.sideText {
                    Text(side)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(state.heelAccessibilityLabel)
            .accessibilityIdentifier("craneResult.heel")

            // One pill, from the rounded heel. Visible text has no side (mock); VoiceOver gets the side.
            if let pill = state.livePillText, let tone = state.tone {
                // Hugs its text when it fits; at the largest text sizes it wraps inside the card's
                // normal margins instead of pushing the card wider than the screen (AX5).
                ViewThatFits(in: .horizontal) {
                    CraneHeelPill(text: pill, tone: tone)
                        .fixedSize()
                    CraneHeelPill(text: pill, tone: tone)
                        .fixedSize(horizontal: false, vertical: true)
                }
                    .accessibilityLabel(state.resultPillText ?? pill)
                    .accessibilityIdentifier("craneResult.pill")
            } else if let reason = state.generalErrorReason {
                Text(reason)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.danger)
                    .accessibilityIdentifier("craneResult.error")
            }

            SternHeelView(
                tiltDeg: state.glyphRotationDeg,
                needleDialDeg: state.gaugeNeedleDialDeg,
                zones: state.gaugeZones,
                needleColor: CraneColors.tone(state.tone),
                start: P.sketchPosition(azimuthText: inputs.startAzimuth, outreachText: inputs.startOutreach),
                end: P.sketchPosition(azimuthText: inputs.azimuth, outreachText: inputs.outreach),
                loadLabel: label(for: .hookLoad, suffix: " t")
            )
            .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: state.glyphRotationDeg)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: state.gaugeNeedleDialDeg)
            .frame(maxWidth: 420)
            .frame(maxWidth: .infinity)
            // Gauge = legend (zones Clear <5 / Soft ≥5 / Hard ≥10). One element for VoiceOver.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(P.gaugeAccessibilityLabel)
            .accessibilityValue(state.gaugeAccessibilityValue)
            .accessibilityIdentifier("craneResult.legend")

            // Two-line ballast tile (Pixel AX L): line 1 value+direction, line 2 qualifier.
            // Never truncates at large Dynamic Type; VoiceOver label / id unchanged.
            if let b = state.ballast {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.teal)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        (Text("\(b.value) \(b.unit)")
                            .font(.headline.weight(.bold))
                            .monospacedDigit()
                         + Text(" \(b.direction)")
                            .font(.subheadline.weight(.semibold)))
                            .foregroundStyle(AppTheme.textPrimary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(b.qualifier)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.border, lineWidth: 1) }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(b.accessibilityLabel)
                .accessibilityIdentifier("craneResult.ballast")
            } else if let prompt = state.ballastPrompt {
                Text(prompt)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("craneResult.ballastPrompt")
            }

            if let note = state.note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .accessibilityIdentifier("craneResult.note")
            }
        }
    }

    // MARK: - 2. LIFT

    @ViewBuilder
    private func liftCard(_ state: CraneHeelPresentation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            eyebrow(P.liftEyebrow, systemImage: "shippingbox")

            // Segment: which position the controls below edit.
            HStack(spacing: 4) {
                ForEach(P.LiftPosition.allCases, id: \.self) { pos in
                    Button { select(pos) } label: {
                        Text(pos.segmentTitle)
                            .font(.subheadline.weight(position == pos ? .semibold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundStyle(position == pos ? Color.white : AppTheme.textSecondary)
                            .background(position == pos ? AppTheme.primaryBlue : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(position == pos ? .isSelected : [])
                    .accessibilityIdentifier(pos.segmentAccessibilityIdentifier)
                }
            }
            .padding(3)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            liftRow(.start, text: state.startRowText ?? P.startNotSetHint, heel: nil, tone: nil,
                    id: P.LiftPosition.start.rowAccessibilityIdentifier)
            // End row keeps the old LIVE HEEL id (it is the row that carries the heel).
            liftRow(.end, text: state.endRowText ?? P.positionNotSet, heel: state.endRowHeelText, tone: state.tone,
                    id: "craneResult.liveHeel")

            if !state.isStartBlank {
                Button(P.clearStartTitle) {
                    inputs.startAzimuth = ""
                    inputs.startOutreach = ""
                    select(.end)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.primaryBlue)
                .accessibilityIdentifier("craneLift.clearStart")
            }

            // An error on the position that isn't shown (e.g. only one Start field filled).
            if let f = state.errorField, let reason = state.errorReason, isLiftField(f), !isShown(f) {
                Button { select(f == .startAzimuth || f == .startOutreach ? .start : .end) } label: {
                    Text("\(f == .startAzimuth || f == .startOutreach ? "Start" : "End"): \(reason)")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.danger)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("craneResult.liftError")
            }

            let row = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .center, spacing: 12))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
            row {
                ringControl(state)
                quickGrid
            }
            .padding(.top, 4)

            let fields = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
            fields {
                numberField(position.azimuthField, title: P.exactAzimuthLabel, state: state)
                numberField(position.outreachField, title: P.outreachLabel, state: state)
            }
            .id(position)   // swap Start/End fields cleanly (focus, error)
            if let helper = position.outreachField.helper {
                helperText(helper)
            }
        }
    }

    private func liftRow(_ pos: CraneHeelPresentation.LiftPosition, text: String, heel: String?,
                         tone: CraneHeelPresentation.Tone?, id: String) -> some View {
        let active = position == pos
        return Button { select(pos) } label: {
            HStack(spacing: 9) {
                Image(systemName: pos == .start ? "shippingbox" : "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(active ? AppTheme.gold : AppTheme.textSecondary)
                    .frame(width: 22)
                // Accessibility sizes: the value goes on its own line under "Start"/"End" and wraps
                // freely (no line limit); other sizes keep the single line.
                let stacked = dynamicTypeSize.isAccessibilitySize
                let titleValue = stacked
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                    : AnyLayout(HStackLayout(alignment: .center, spacing: 9))
                titleValue {
                    Text(pos.rowTitle)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(minWidth: 40, alignment: .leading)
                    Text(text)
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(active ? AppTheme.textPrimary : AppTheme.textSecondary)
                        .lineLimit(stacked ? nil : 1)
                        .minimumScaleFactor(stacked ? 1 : 0.7)
                        .fixedSize(horizontal: false, vertical: stacked)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                if let heel {
                    Text(heel)
                        .font(.subheadline.weight(.heavy))
                        .monospacedDigit()
                        .foregroundStyle(CraneColors.tone(tone))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(active ? AppTheme.primaryBlue.opacity(0.16) : AppTheme.surface,
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(active ? AppTheme.primaryBlue.opacity(0.8) : AppTheme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(pos.rowTitle): \(text)\(heel.map { ", heel \($0)" } ?? "")")
        .accessibilityHint("Edit the \(pos.rowTitle.lowercased()) position")
        .accessibilityAddTraits(active ? .isSelected : [])
        .accessibilityIdentifier(id)
    }

    /// Top-view ring: drag the boom (ring band) to set the active position's azimuth. Wraps past 360.
    private func ringControl(_ state: CraneHeelPresentation) -> some View {
        let activeDeg = position == .start ? state.startRingAzimuthDeg : state.ringAzimuthDeg
        return TopViewRing(
            start: P.sketchPosition(azimuthText: inputs.startAzimuth, outreachText: inputs.startOutreach),
            startAzimuthDeg: state.startRingAzimuthDeg,
            end: P.sketchPosition(azimuthText: inputs.azimuth, outreachText: inputs.outreach),
            endAzimuthDeg: state.ringAzimuthDeg,
            active: position,
            onDrag: { dx, dy in
                if let text = P.dragAzimuthText(dx: dx, dy: dy) { inputs[position.azimuthField] = text }
            }
        )
        .frame(width: 132, height: 132)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(P.ringAccessibilityLabel), \(position.rowTitle.lowercased())")
        .accessibilityValue(P.ringAccessibilityValue(activeDeg))
        .accessibilityHint(P.ringAccessibilityHint)
        .accessibilityAddTraits(.allowsDirectInteraction)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                inputs[position.azimuthField] = P.azimuthFieldText(P.stepAzimuth(activeDeg, increment: true))
            case .decrement:
                inputs[position.azimuthField] = P.azimuthFieldText(P.stepAzimuth(activeDeg, increment: false))
            @unknown default:
                break
            }
        }
        .accessibilityIdentifier("craneField.azimuthRing")
        .sensoryFeedback(.selection, trigger: Int(((activeDeg ?? -15) / 15).rounded(.down)))
    }

    private var quickGrid: some View {
        let text = inputs[position.azimuthField]
        return Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(0..<2, id: \.self) { r in
                GridRow {
                    ForEach(P.QuickAngle.gridOrder[(r * 2)..<(r * 2 + 2)], id: \.self) { q in
                        let on = q.isSelected(azimuthText: text)
                        Button { inputs[position.azimuthField] = q.fieldText } label: {
                            VStack(spacing: 1) {
                                Text(q.title).font(.subheadline.weight(.bold))
                                Text(q.subtitle).font(.caption2).monospacedDigit()
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(on ? Color.white : AppTheme.textPrimary)
                            .background(on ? AppTheme.primaryBlue : AppTheme.surface,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(on ? AppTheme.primaryBlue : AppTheme.border, lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(q.accessibilityLabel)
                        .accessibilityAddTraits(on ? .isSelected : [])
                        .accessibilityIdentifier(q.accessibilityIdentifier)
                        .sensoryFeedback(.selection, trigger: on)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 3. CRANE, 4. SHIP

    @ViewBuilder
    private func craneCard(_ state: CraneHeelPresentation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            eyebrow(P.craneEyebrow, systemImage: "arrow.up.and.down.and.arrow.left.and.right")
            numberField(.hookLoad, title: P.Field.hookLoad.title, state: state)
            if let h = P.Field.hookLoad.helper { helperText(h) }
        }
    }

    @ViewBuilder
    private func shipCard(_ state: CraneHeelPresentation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            eyebrow(P.shipEyebrow, systemImage: "ferry")
            let pair = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
            pair {
                numberField(.displacement, title: P.Field.displacement.title, state: state)
                numberField(.gm, title: P.Field.gm.title, state: state)
            }
            if let h = P.Field.displacement.helper { helperText(h) }
            numberField(.tankDistance, title: P.Field.tankDistance.title, state: state)
                .padding(.top, 4)
            if let h = P.Field.tankDistance.helper { helperText(h) }
            numberField(.pivotOffset, title: P.Field.pivotOffset.title, state: state)
                .padding(.top, 4)
            if let h = P.Field.pivotOffset.helper { helperText(h) }
        }
    }

    // MARK: - Helpers

    private func numberField(_ field: CraneHeelPresentation.Field, title: String, state: CraneHeelPresentation) -> some View {
        ToolNumberField(
            title: title,
            text: binding(field),
            placeholder: field.placeholder,
            unit: field.unit,
            // Azimuths wrap negatives and pivot can be to port: the decimal pad has no minus key.
            keyboard: (field == .azimuth || field == .startAzimuth || field == .pivotOffset) ? .numbersAndPunctuation : .decimalPad,
            isError: state.errorField == field,
            errorReason: state.errorField == field ? state.errorReason : nil,
            accessibilityName: field.title,
            fieldAccessibilityIdentifier: field.accessibilityIdentifier
        )
        .focused($focusedField, equals: field)
    }

    private func select(_ pos: CraneHeelPresentation.LiftPosition) {
        guard position != pos else { return }
        if reduceMotion {
            position = pos
        } else {
            withAnimation(.easeOut(duration: 0.2)) { position = pos }
        }
    }

    private func isLiftField(_ f: CraneHeelPresentation.Field) -> Bool {
        [.azimuth, .outreach, .startAzimuth, .startOutreach].contains(f)
    }

    private func isShown(_ f: CraneHeelPresentation.Field) -> Bool {
        f == position.azimuthField || f == position.outreachField
    }

    private func binding(_ field: CraneHeelPresentation.Field) -> Binding<String> {
        Binding(get: { inputs[field] }, set: { inputs[field] = $0 })
    }

    /// Sketch label from what the user typed (e.g. "80 t"); nil while the field isn't a number.
    private func label(for field: CraneHeelPresentation.Field, suffix: String) -> String? {
        guard case .value = P.parse(inputs[field]) else { return nil }
        return inputs[field].trimmingCharacters(in: .whitespacesAndNewlines) + suffix
    }

    private func eyebrow(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.bold))
            .tracking(1.1)
            .foregroundStyle(AppTheme.teal)
            .accessibilityAddTraits(.isHeader)
    }

    private func helperText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(AppTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }
}

// MARK: - Pill

/// Pill by tone: clear = app mint pill, soft = restrained gold, hard = app red warning pill.
private struct CraneHeelPill: View {
    let text: String
    let tone: CraneHeelPresentation.Tone

    var body: some View {
        switch tone {
        case .clear:
            ToolClearPill(text: text)
        case .soft:
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.gold)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(CraneColors.amberFill, in: Capsule())
                .overlay { Capsule().stroke(AppTheme.gold.opacity(0.45), lineWidth: 1) }
        case .hard:
            ToolWarningPill(text: text)
        }
    }
}

// MARK: - Stern view + clinometer

/// Stern view drawn LOOKING FORWARD FROM AFT: port on the left (P), stbd on the right (S), so a + (stbd) heel
/// rotates the hull clockwise = tilts right. ViewBox 330×236, geometry from crane-heel-B2.py.
/// Layers share one frame so `rotationEffect` anchors line up:
///   gauge (static) · hull + crane (rotated by the heel) · needle (rotated by the dial angle) · water (static).
/// The rotations animate (unless Reduce Motion); the hanging load is counter-rotated inside the hull layer so it
/// ends truly vertical.
private struct SternHeelView: View {
    let tiltDeg: Double
    let needleDialDeg: Double?
    let zones: [CraneHeelPresentation.GaugeZone]
    let needleColor: Color
    let start: CraneHeelPresentation.SketchPosition?
    let end: CraneHeelPresentation.SketchPosition?
    let loadLabel: String?

    static let W = 330.0, H = 236.0
    static let cx = 165.0, wl = 182.0          // centre line / waterline = rotation centre and gauge hub
    static let rg = 132.0, bw = 12.0           // gauge radius / band width
    static var anchor: UnitPoint { UnitPoint(x: cx / W, y: wl / H) }

    var body: some View {
        ZStack {
            Canvas { ctx, size in
                ctx.scaleBy(x: size.width / Self.W, y: size.width / Self.W)
                drawGauge(&ctx)
            }
            Canvas { ctx, size in
                ctx.scaleBy(x: size.width / Self.W, y: size.width / Self.W)
                drawShip(&ctx)
            }
            .rotationEffect(.degrees(tiltDeg), anchor: Self.anchor)
            if let needle = needleDialDeg {
                Canvas { ctx, size in
                    ctx.scaleBy(x: size.width / Self.W, y: size.width / Self.W)
                    drawNeedle(&ctx)
                }
                .rotationEffect(.degrees(needle), anchor: Self.anchor)
            }
            Canvas { ctx, size in
                ctx.scaleBy(x: size.width / Self.W, y: size.width / Self.W)
                drawWater(&ctx)
            }
        }
        .aspectRatio(Self.W / Self.H, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func pt(_ dialDeg: Double, _ r: Double) -> CGPoint {
        let a = dialDeg * .pi / 180
        return CGPoint(x: Self.cx + r * sin(a), y: Self.wl - r * cos(a))
    }

    private func line(_ a: CGPoint, _ b: CGPoint) -> Path {
        var p = Path(); p.move(to: a); p.addLine(to: b); return p
    }

    private func drawGauge(_ ctx: inout GraphicsContext) {
        ctx.fill(Path(CGRect(x: 0, y: 0, width: Self.W, height: Self.H)), with: .color(CraneColors.sternBackground))
        // Zones: fixed sections, active one at full strength. Dial angle 0 = up, + = clockwise (stbd).
        for z in zones {
            var arc = Path()
            arc.addArc(center: CGPoint(x: Self.cx, y: Self.wl), radius: Self.rg,
                       startAngle: .degrees(z.fromDial - 90), endAngle: .degrees(z.toDial - 90), clockwise: false)
            ctx.stroke(arc, with: .color(CraneColors.tone(z.tone).opacity(z.isActive ? 1 : 0.32)), lineWidth: Self.bw)
        }
        // Thin gaps at the zone edges (±5, ±10) so 5° and 10° read as ticks on the band too.
        for z in zones.dropFirst() {
            ctx.stroke(line(pt(z.fromDial, Self.rg - Self.bw / 2 - 1), pt(z.fromDial, Self.rg + Self.bw / 2 + 1)),
                       with: .color(CraneColors.sternBackground), lineWidth: 2)
        }
        // Ticks inside the band; labels OUTSIDE (inside is busy with the crane).
        for t in CraneHeelPresentation.gaugeTicks {
            let r1 = Self.rg - Self.bw / 2 - 2, r2 = Self.rg - Self.bw / 2 - (t.isMajor ? 9 : 5)
            ctx.stroke(line(pt(t.dialDeg, r1), pt(t.dialDeg, r2)),
                       with: .color(t.isMajor ? CraneColors.tickMajor : CraneColors.tickMinor), lineWidth: t.isMajor ? 1.6 : 1.1)
            if let label = t.label {
                let p = pt(t.dialDeg, Self.rg + Self.bw / 2 + 10)
                ctx.draw(Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(CraneColors.label2), at: p)
            }
        }
        // P / S and the centreline (upright reference).
        ctx.draw(Text("P").font(.system(size: 13, weight: .bold)).foregroundStyle(CraneColors.label1),
                 at: CGPoint(x: 16, y: 22), anchor: .leading)
        ctx.draw(Text("S").font(.system(size: 13, weight: .bold)).foregroundStyle(CraneColors.label1),
                 at: CGPoint(x: Self.W - 16, y: 22), anchor: .trailing)
        ctx.stroke(line(CGPoint(x: Self.cx, y: Self.wl - 106), CGPoint(x: Self.cx, y: Self.H - 6)),
                   with: .color(CraneColors.centreline), style: StrokeStyle(lineWidth: 1.3, dash: [4, 4]))
    }

    /// Crane tip in ship coordinates (px from CL / waterline, y down): transverse 6.4 px per m of lever,
    /// height from a 24 m luffing boom (higher when the outreach is short). Clamped to stay in the frame.
    private func tip(_ p: CraneHeelPresentation.SketchPosition) -> CGPoint {
        let h = (max(0, 24 * 24 - min(p.outreach, 24) * min(p.outreach, 24))).squareRoot()
        let x = max(-150, min(150, 6.4 * p.y))
        return CGPoint(x: x, y: -66 - 1.2 * (h - 13.27) - 6)
    }

    private func drawShip(_ ctx: inout GraphicsContext) {
        var g = ctx
        g.translateBy(x: Self.cx, y: Self.wl)
        // Hull + superstructure (mock path, scale 1.5 around (75, 80)).
        var hullCtx = g
        hullCtx.scaleBy(x: 1.5, y: 1.5)
        hullCtx.translateBy(x: -75, y: -80)
        var hull = Path()
        hull.move(to: CGPoint(x: 23, y: 58)); hull.addLine(to: CGPoint(x: 127, y: 58)); hull.addLine(to: CGPoint(x: 126, y: 86))
        hull.addQuadCurve(to: CGPoint(x: 105, y: 105), control: CGPoint(x: 124, y: 103))
        hull.addLine(to: CGPoint(x: 45, y: 105))
        hull.addQuadCurve(to: CGPoint(x: 24, y: 86), control: CGPoint(x: 26, y: 103))
        hull.closeSubpath()
        hullCtx.fill(hull, with: .color(CraneColors.hullFill))
        hullCtx.stroke(hull, with: .color(CraneColors.hullStroke), lineWidth: 1.2)
        hullCtx.stroke(line(CGPoint(x: 23, y: 64), CGPoint(x: 127, y: 64)), with: .color(CraneColors.deck), lineWidth: 0.7)
        let house = Path(roundedRect: CGRect(x: 51, y: 33, width: 48, height: 25), cornerRadius: 4)
        hullCtx.fill(house, with: .color(CraneColors.bridge)); hullCtx.stroke(house, with: .color(CraneColors.bridgeStroke), lineWidth: 0.9)
        hullCtx.fill(Path(roundedRect: CGRect(x: 56, y: 38, width: 38, height: 5), cornerRadius: 1.5), with: .color(CraneColors.window))
        let top = Path(roundedRect: CGRect(x: 60, y: 22, width: 30, height: 11), cornerRadius: 3)
        hullCtx.fill(top, with: .color(CraneColors.bridge)); hullCtx.stroke(top, with: .color(CraneColors.bridgeStroke), lineWidth: 0.8)
        hullCtx.fill(Path(CGRect(x: 72, y: 40, width: 6, height: 18)), with: .color(CraneColors.pedestal))
        hullCtx.fill(Path(roundedRect: CGRect(x: 68.5, y: 33, width: 13, height: 8), cornerRadius: 1.8), with: .color(AppTheme.gold))

        let pivot = CGPoint(x: 0, y: -66)
        // Ghost START: boom luffed up, load resting on deck (drawn with the hull).
        if let s = start {
            let t = tip(s)
            var ghost = g
            ghost.opacity = 0.45
            ghost.stroke(line(pivot, t), with: .color(AppTheme.gold), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
            let box = CGRect(x: t.x - 17, y: -53, width: 34, height: 20)
            ghost.stroke(line(t, CGPoint(x: t.x, y: box.minY)), with: .color(CraneColors.label1), style: StrokeStyle(lineWidth: 1.1, dash: [2, 2]))
            ghost.stroke(Path(roundedRect: box, cornerRadius: 4), with: .color(AppTheme.gold), style: StrokeStyle(lineWidth: 1.4, dash: [3, 2]))
            if let l = loadLabel {
                ghost.draw(Text(l).font(.system(size: 11, weight: .heavy)).foregroundStyle(AppTheme.gold), at: CGPoint(x: box.midX, y: box.midY))
            }
        }
        // END: boom + hook load hanging from the tip. The load is counter-rotated so it hangs plumb.
        if let e = end {
            let t = tip(e)
            g.stroke(line(pivot, t), with: .color(AppTheme.gold), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            g.fill(Path(ellipseIn: CGRect(x: t.x - 2.6, y: t.y - 2.6, width: 5.2, height: 5.2)), with: .color(CraneColors.ink))
            var load = g
            load.translateBy(x: t.x, y: t.y)
            load.rotate(by: .degrees(-tiltDeg))
            load.stroke(line(CGPoint(x: 0, y: 2), CGPoint(x: 0, y: 14)), with: .color(CraneColors.label1), lineWidth: 1.3)
            var sling = Path()
            sling.move(to: CGPoint(x: -7, y: 22)); sling.addLine(to: CGPoint(x: 0, y: 14)); sling.addLine(to: CGPoint(x: 7, y: 22))
            load.stroke(sling, with: .color(CraneColors.label1), lineWidth: 1.1)
            let box = Path(roundedRect: CGRect(x: -17, y: 22, width: 34, height: 20), cornerRadius: 4)
            load.fill(box, with: .color(AppTheme.gold))
            load.stroke(box, with: .color(CraneColors.ink), lineWidth: 1.2)
            if let l = loadLabel {
                load.draw(Text(l).font(.system(size: 11.5, weight: .heavy)).foregroundStyle(CraneColors.goldInk), at: CGPoint(x: 0, y: 32))
            }
        }
    }

    /// Needle drawn pointing straight up from the hub; the layer is rotated by the dial angle.
    private func drawNeedle(_ ctx: inout GraphicsContext) {
        let r1 = 110.0, r2 = Self.rg - Self.bw / 2 - 1
        ctx.stroke(line(CGPoint(x: Self.cx, y: Self.wl - r1), CGPoint(x: Self.cx, y: Self.wl - r2 + 8)),
                   with: .color(needleColor), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        var tri = Path()
        tri.move(to: CGPoint(x: Self.cx, y: Self.wl - r2))
        tri.addLine(to: CGPoint(x: Self.cx - 5, y: Self.wl - r2 + 10))
        tri.addLine(to: CGPoint(x: Self.cx + 5, y: Self.wl - r2 + 10))
        tri.closeSubpath()
        ctx.fill(tri, with: .color(needleColor))
    }

    private func drawWater(_ ctx: inout GraphicsContext) {
        let water = Path(CGRect(x: 0, y: Self.wl, width: Self.W, height: Self.H - Self.wl))
        ctx.fill(water, with: .linearGradient(Gradient(colors: [CraneColors.waterTop, CraneColors.waterBottom]),
                                              startPoint: CGPoint(x: 0, y: Self.wl), endPoint: CGPoint(x: 0, y: Self.H)))
        var wave = Path()
        wave.move(to: CGPoint(x: 0, y: Self.wl))
        for i in 0..<22 {
            let x0 = Double(i) * 15
            wave.addQuadCurve(to: CGPoint(x: x0 + 15, y: Self.wl), control: CGPoint(x: x0 + 7.5, y: Self.wl - 2.4))
        }
        ctx.stroke(wave, with: .color(CraneColors.waterLine), lineWidth: 1.7)
        ctx.draw(Text(CraneHeelPresentation.sternCaption).font(.system(size: 10.5)).foregroundStyle(CraneColors.caption),
                 at: CGPoint(x: Self.W - 14, y: Self.H - 12), anchor: .trailing)
    }
}

// MARK: - Top-view ring (Lift card)

/// Bow up. Ghost Start boom + dashed knob, solid End boom + knob, teal arc 0 → active azimuth.
/// Only the ring band (±18 pt around the ring) takes the drag, so scrolling over the hull still scrolls.
private struct TopViewRing: View {
    let start: CraneHeelPresentation.SketchPosition?
    let startAzimuthDeg: Double?
    let end: CraneHeelPresentation.SketchPosition?
    let endAzimuthDeg: Double?
    let active: CraneHeelPresentation.LiftPosition
    let onDrag: (Double, Double) -> Void

    static let size = 132.0, c = 66.0, ringR = 46.0

    var body: some View {
        Canvas { ctx, sz in
            ctx.scaleBy(x: sz.width / Self.size, y: sz.width / Self.size)
            draw(&ctx)
        }
        .contentShape(RingBand(), eoFill: true)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    // Points → viewBox units are the same here (fixed 132 × 132 frame).
                    onDrag(v.location.x - Self.c, v.location.y - Self.c)
                }
        )
    }

    private func pt(_ deg: Double, _ r: Double) -> CGPoint {
        let a = deg * .pi / 180
        return CGPoint(x: Self.c + r * sin(a), y: Self.c - r * cos(a))
    }

    private func draw(_ ctx: inout GraphicsContext) {
        let c = Self.c, rr = Self.ringR
        ctx.stroke(Path(ellipseIn: CGRect(x: c - rr, y: c - rr, width: 2 * rr, height: 2 * rr)),
                   with: .color(CraneColors.ringTrack), lineWidth: 7)
        let activeDeg = active == .start ? startAzimuthDeg : endAzimuthDeg
        if let a = activeDeg, a > 0 {
            var arc = Path()
            arc.addArc(center: CGPoint(x: c, y: c), radius: rr, startAngle: .degrees(-90), endAngle: .degrees(a - 90), clockwise: false)
            ctx.stroke(arc, with: .color(AppTheme.teal.opacity(0.85)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        }
        let f = Font.system(size: 11, weight: .bold)
        ctx.draw(Text("B").font(f).foregroundStyle(CraneColors.label2), at: CGPoint(x: c, y: 6))
        ctx.draw(Text("A").font(f).foregroundStyle(CraneColors.label2), at: CGPoint(x: c, y: Self.size - 6))
        ctx.draw(Text("S").font(f).foregroundStyle(CraneColors.label2), at: CGPoint(x: Self.size - 5, y: c))
        ctx.draw(Text("P").font(f).foregroundStyle(CraneColors.label2), at: CGPoint(x: 5, y: c))
        // Hull, bow up.
        let bh = 13.0, bf = 38.0, ba = 34.0
        var hull = Path()
        hull.move(to: CGPoint(x: c, y: c - bf))
        hull.addCurve(to: CGPoint(x: c + bh, y: c - 7), control1: CGPoint(x: c + bh * 0.9, y: c - bf + 13), control2: CGPoint(x: c + bh, y: c - 17))
        hull.addLine(to: CGPoint(x: c + bh, y: c + ba - 3))
        hull.addQuadCurve(to: CGPoint(x: c + bh - 3, y: c + ba), control: CGPoint(x: c + bh, y: c + ba))
        hull.addLine(to: CGPoint(x: c - bh + 3, y: c + ba))
        hull.addQuadCurve(to: CGPoint(x: c - bh, y: c + ba - 3), control: CGPoint(x: c - bh, y: c + ba))
        hull.addLine(to: CGPoint(x: c - bh, y: c - 7))
        hull.addCurve(to: CGPoint(x: c, y: c - bf), control1: CGPoint(x: c - bh, y: c - 17), control2: CGPoint(x: c - bh * 0.9, y: c - bf + 13))
        hull.closeSubpath()
        ctx.fill(hull, with: .color(CraneColors.hullFill))
        ctx.stroke(hull, with: .color(CraneColors.hullStroke), lineWidth: 1.4)
        // Booms: length ∝ outreach (capped inside the ring).
        func boom(_ p: CraneHeelPresentation.SketchPosition, ghost: Bool) {
            var b = ctx
            b.opacity = ghost ? 0.42 : 1
            let tip = pt(p.azimuthDeg, min(rr - 6, 1.45 * p.outreach))
            var l = Path(); l.move(to: CGPoint(x: c, y: c)); l.addLine(to: tip)
            b.stroke(l, with: .color(AppTheme.gold), style: StrokeStyle(lineWidth: ghost ? 4 : 5, lineCap: .round))
            let box = Path(roundedRect: CGRect(x: tip.x - 6, y: tip.y - 6, width: 12, height: 12), cornerRadius: 3)
            b.fill(box, with: .color(AppTheme.gold)); b.stroke(box, with: .color(CraneColors.ink), lineWidth: 1.2)
        }
        if let s = start { boom(s, ghost: true) }
        if let e = end { boom(e, ghost: false) }
        // Knobs on the ring.
        if let a = startAzimuthDeg {
            let k = pt(a, rr)
            ctx.stroke(Path(ellipseIn: CGRect(x: k.x - 5.5, y: k.y - 5.5, width: 11, height: 11)),
                       with: .color(active == .start ? AppTheme.primaryBlue : CraneColors.label2),
                       style: StrokeStyle(lineWidth: active == .start ? 2.4 : 1.6, dash: [2, 2]))
        }
        if let a = endAzimuthDeg {
            let k = pt(a, rr)
            ctx.fill(Path(ellipseIn: CGRect(x: k.x - 7, y: k.y - 7, width: 14, height: 14)), with: .color(CraneColors.label1))
            ctx.stroke(Path(ellipseIn: CGRect(x: k.x - 7, y: k.y - 7, width: 14, height: 14)),
                       with: .color(active == .end ? AppTheme.primaryBlue : CraneColors.ink), lineWidth: 2)
            ctx.fill(Path(ellipseIn: CGRect(x: k.x - 2.6, y: k.y - 2.6, width: 5.2, height: 5.2)), with: .color(AppTheme.teal))
        }
    }
}

/// Touch target for the top-view ring: a band ±18 pt around the ring radius (even-odd = hole in the middle).
private struct RingBand: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / TopViewRing.size
        let c = CGPoint(x: TopViewRing.c * s, y: TopViewRing.c * s)
        let outer = (TopViewRing.ringR + 18) * s, inner = (TopViewRing.ringR - 18) * s
        var p = Path()
        p.addEllipse(in: CGRect(x: c.x - outer, y: c.y - outer, width: 2 * outer, height: 2 * outer))
        p.addEllipse(in: CGRect(x: c.x - inner, y: c.y - inner, width: 2 * inner, height: 2 * inner))
        return p
    }
}

// MARK: - Colours

/// Sketch-only colours (navy hull, water). App colours (blue primary, teal, restrained gold, danger) come from AppTheme.
private enum CraneColors {
    static func rgb(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
    static let sternBackground = rgb(0x152129)
    static let ink = rgb(0x0d161d)
    static let goldInk = rgb(0x2a1f00)
    static let label1 = rgb(0xe8eef5)
    static let label2 = rgb(0xa5adb2)
    static let caption = rgb(0x7f9aa8)
    static let tickMajor = rgb(0xc9d4e0)
    static let tickMinor = rgb(0x6f7a80)
    static let centreline = rgb(0x7f8c96)
    static let hullFill = rgb(0x24323c)
    static let hullStroke = rgb(0xd3dde7)
    static let deck = rgb(0x3b4a55)
    static let bridge = rgb(0x33414b)
    static let bridgeStroke = rgb(0x9fb0c2)
    static let window = rgb(0x0b2233)
    static let pedestal = rgb(0x4a5661)
    static let waterTop = rgb(0x1d5566).opacity(0.82)
    static let waterBottom = rgb(0x0a2030).opacity(0.96)
    static let waterLine = rgb(0x4fc6d8)
    static let ringTrack = rgb(0x2a3337)
    static let amberFill = rgb(0x3a2f14)

    /// Tone colour for the heel number, End-row heel, needle and zones. nil (no result) = secondary text.
    static func tone(_ t: CraneHeelPresentation.Tone?) -> Color {
        switch t {
        case .clear?: return AppTheme.teal
        case .soft?: return AppTheme.gold
        case .hard?: return AppTheme.danger
        case nil: return AppTheme.textSecondary
        }
    }
}

// MARK: - Previews (the only place example numbers appear)

#Preview("B2 example: aft 12 m → stbd 20 m (example only)") {
    NavigationStack {
        CraneHeelView(inputs: .init(azimuth: "90", outreach: "20", hookLoad: "80", displacement: "8000", gm: "1.50",
                                    tankDistance: "12", startAzimuth: "180", startOutreach: "12"))
    }
}

#Preview("Start blank: single point, crane on CL") {
    NavigationStack {
        CraneHeelView(inputs: .init(azimuth: "90", outreach: "20", hookLoad: "80", displacement: "8000", gm: "1.50", tankDistance: "12"))
    }
}

#Preview("Hard, port, no tank distance") {
    NavigationStack {
        CraneHeelView(inputs: .init(azimuth: "270", outreach: "20", hookLoad: "80", displacement: "8000", gm: "1.50",
                                    startAzimuth: "90", startOutreach: "20"), position: .start)
    }
}

#Preview("App start (all empty)") {
    NavigationStack { CraneHeelView() }
}
