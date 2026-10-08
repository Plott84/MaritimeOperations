import Foundation

/// Screen copy + state for `CraneHeelView`. Pure Foundation, so it builds and tests on Linux.
/// The SwiftUI view only lays this out. Every string the user sees and every show/hide rule lives here.
///
/// Locked copy rules (Pixel + Builder, 2026-10-06):
/// - Ballast field label "Distance between tanks (m)", helper "Port tank to stbd tank, measured across."
///   Math unchanged: w = |MH| / d.
/// - Ballast tile, e.g. "133.3 t to move stbd tank → port tank" (direction from `pumpTo`).
/// - Result pill: shown heel 0.0° → just "Clear · under 5°". Otherwise "<Level> to <side> · <band>",
///   e.g. "Soft heel to stbd · 5° or more", "Hard heel to port · 10° or more", "Clear to stbd · under 5°".
/// - Ballast line hidden when the shown heel is 0.0 or the boom is on CL (math returns nil).
/// - All fields start empty, with no default Δ/GM. Example values go only in `#Preview`.
///
/// B2 two-point lift (Pixel `crane-heel-B2.png`, locked 2026-10-07):
/// - Start (load on deck) + End (over the side). ONE heel only: the End heel from `CraneHeelMath.move`.
///   Start blank (both fields empty) → single-point result. Only one Start field → invalid on the empty one.
/// - Note: "Ship level at start" whenever Start is filled; "Crane on CL assumed" only when Start AND the pivot
///   field are both blank (a typed "0" pivot gets no note). Never both. Only shown with a result.
/// - Ballast tonnes rounded half away from zero (same helper as the heel); tile hidden when that shows 0.0 t.
/// - Tank distance blank → no tile, grey line "Add distance between tanks to see ballast" (heel still shows).
/// - Gauge: needle, active zone and pill all use the same rounded heel. Stretched dial, fixed sections:
///   |heel| 0–5 → 0–20°, 5–10 → 20–40°, 10–20 → 40–60° of dial, pegged beyond 20°.
public struct CraneHeelPresentation: Equatable, Sendable {

    // MARK: - Static copy

    public static let navigationTitle = "Crane heel"
    public static let boomCardEyebrow = "BOOM POSITION"
    public static let boomCardTitle = "Lift over the side"
    public static let sketchCaption = "Drag the ring to set boom azimuth. Seen from above, bow up."
    public static let liveHeelEyebrow = "LIVE HEEL"
    public static let resultEyebrow = "RESULT"
    public static let resultTitle = "Static heel"
    public static let heelCaption = "Heel · + is stbd"
    public static let noteBold = "Boom at 0° or 180°:"
    public static let noteBody = "Into trim — heel 0°. Ballast line hidden when heel shows 0.0°."
    public static let inputsEyebrow = "INPUTS"
    /// Kept footer. (The mock's "Example numbers · Builder case C" line is intentionally NOT in the app.)
    public static let footer = "Deck estimate for static heel. Not a class or loading-computer calculation."
    public static let dash = "—"
    public static let sliderTicks = ["0 Bow", "90 Stbd", "180 Aft", "270 Port", "360"]
    public static let ringAccessibilityLabel = "Boom azimuth"
    public static let ringAccessibilityHint = "Swipe up or down to turn the boom 5 degrees."
    /// VoiceOver adjustable step for the ring, degrees.
    public static let ringStepDeg = 5.0

    // B2 copy
    public static let heroEyebrow = "STATIC HEEL"
    public static let liftEyebrow = "LIFT"
    public static let craneEyebrow = "CRANE"
    public static let shipEyebrow = "SHIP"
    public static let noteShipLevelAtStart = "Ship level at start"
    public static let noteCraneOnCL = "Crane on CL assumed"
    public static let ballastPromptText = "Add distance between tanks to see ballast"
    public static let ballastQualifierMove = "for this lift"
    public static let ballastQualifierSingle = "to level"
    public static let sternCaption = "Seen from aft"
    /// Visible label above the azimuth box in the Lift card (both Start and End).
    public static let exactAzimuthLabel = "Exact azimuth (°)"
    public static let outreachLabel = "Outreach R (m)"
    public static let positionNotSet = "Not set"
    public static let startNotSetHint = "Not set · one position only"
    public static let clearStartTitle = "Clear start"
    public static let gaugeAccessibilityLabel = "Heel gauge"

    // MARK: - Types

    public enum Field: String, CaseIterable, Sendable {
        case azimuth, outreach, hookLoad, displacement, gm, pivotOffset, tankDistance
        /// B2 Start position (load on deck). Optional as a pair: both empty = single-point check.
        case startAzimuth, startOutreach

        /// UITest id on the TextField, e.g. `craneField.gm`.
        public var accessibilityIdentifier: String { "craneField.\(rawValue)" }

        public var title: String {
            switch self {
            case .azimuth: return "Boom azimuth (°)"
            case .outreach: return "Outreach R (m)"
            case .hookLoad: return "Hook load PL (t)"
            case .displacement: return "Displacement Δ (t)"
            case .gm: return "GM (m)"
            case .pivotOffset: return "Pivot off CL (m) · optional"
            case .tankDistance: return "Distance between tanks (m)"
            case .startAzimuth: return "Start azimuth (°)"
            case .startOutreach: return "Start outreach R (m)"
            }
        }

        public var helper: String? {
            switch self {
            case .hookLoad: return "cargo + hook + rigging + spreader"
            case .displacement: return "Displacement incl. lift (t)"
            case .pivotOffset: return "Crane pivot off centreline, + to stbd. Empty = on CL."
            case .tankDistance: return "Port tank to stbd tank, measured across."
            case .startOutreach: return "Load on deck. Leave Start empty to check one position."
            default: return nil
            }
        }

        public var unit: String {
            switch self {
            case .azimuth, .startAzimuth: return "°"
            case .hookLoad, .displacement: return "t"
            default: return "m"
            }
        }

        /// Grey prompt only. Never a number that could pass for a default. Empty pivot = "On CL" (B2).
        public var placeholder: String {
            switch self {
            case .pivotOffset: return "On CL"
            case .tankDistance, .startAzimuth, .startOutreach: return "Optional"
            case .azimuth: return "0–360"
            default: return "Required"
            }
        }

        public var isRequired: Bool {
            switch self {
            case .pivotOffset, .tankDistance, .startAzimuth, .startOutreach: return false
            default: return true
            }
        }

        /// Red-field copy under the input.
        public var errorReason: String {
            switch self {
            case .azimuth: return CraneHeelMath.Reason.azimuth
            case .outreach: return CraneHeelMath.Reason.outreach
            case .hookLoad: return CraneHeelMath.Reason.hookLoad
            case .displacement: return CraneHeelMath.Reason.displacement
            case .gm: return CraneHeelMath.Reason.gm
            case .pivotOffset: return CraneHeelMath.Reason.pivotOffset
            case .tankDistance: return "Check distance between tanks"
            case .startAzimuth: return CraneHeelMath.MoveReason.startAzimuth
            case .startOutreach: return CraneHeelMath.MoveReason.startOutreach
            }
        }
    }

    public struct Inputs: Equatable, Sendable {
        public var azimuth: String
        public var outreach: String
        public var hookLoad: String
        public var displacement: String
        public var gm: String
        public var pivotOffset: String
        public var tankDistance: String
        /// B2 Start (load on deck). `azimuth` / `outreach` above are the End (over the side).
        public var startAzimuth: String
        public var startOutreach: String

        public init(azimuth: String = "", outreach: String = "", hookLoad: String = "", displacement: String = "",
                    gm: String = "", pivotOffset: String = "", tankDistance: String = "",
                    startAzimuth: String = "", startOutreach: String = "") {
            self.azimuth = azimuth; self.outreach = outreach; self.hookLoad = hookLoad
            self.displacement = displacement; self.gm = gm; self.pivotOffset = pivotOffset; self.tankDistance = tankDistance
            self.startAzimuth = startAzimuth; self.startOutreach = startOutreach
        }

        /// The app's starting state: every field empty.
        public static let empty = Inputs()

        public subscript(field: Field) -> String {
            get {
                switch field {
                case .azimuth: return azimuth
                case .outreach: return outreach
                case .hookLoad: return hookLoad
                case .displacement: return displacement
                case .gm: return gm
                case .pivotOffset: return pivotOffset
                case .tankDistance: return tankDistance
                case .startAzimuth: return startAzimuth
                case .startOutreach: return startOutreach
                }
            }
            set {
                switch field {
                case .azimuth: azimuth = newValue
                case .outreach: outreach = newValue
                case .hookLoad: hookLoad = newValue
                case .displacement: displacement = newValue
                case .gm: gm = newValue
                case .pivotOffset: pivotOffset = newValue
                case .tankDistance: tankDistance = newValue
                case .startAzimuth: startAzimuth = newValue
                case .startOutreach: startOutreach = newValue
                }
            }
        }
    }

    public enum Tone: String, Equatable, Sendable { case clear, soft, hard }

    public enum Status: Equatable, Sendable {
        /// A required field is empty or half-typed ("-", "."). Dash everywhere, no red.
        case incomplete
        /// `field` nil = not tied to one input ("Check inputs"); show reason under the result.
        case invalid(field: Field?, reason: String)
        case ok
    }

    public struct BallastTile: Equatable, Sendable {
        public let value: String          // "133.3" (rounded half away from zero, never "0.0")
        public let unit: String           // "t"
        public let caption: String        // "to move stbd tank → port tank"
        public let pumpTo: CraneHeelMath.Board
        /// B2 tile direction, e.g. "stbd tank → port tank" (flips with the sign of w = MH/d).
        public let direction: String
        /// B2 tile tail: "for this lift" (move) or "to level" (single point).
        public let qualifier: String
        /// Signed w = MH/d as shown (0.1 t): + = stbd tank → port tank, − = port tank → stbd tank.
        public let signedTonnes: Double
        /// "133.3 t to move stbd tank → port tank"
        public var text: String { "\(value) \(unit) \(caption)" }
        /// Sketch label next to the highlighted tank, e.g. "to port tank".
        public var sketchCaption: String { "to \(pumpTo.rawValue) tank" }
        public var accessibilityLabel: String {
            let from = pumpTo == .port ? "starboard" : "port"
            let to = pumpTo == .port ? "port" : "starboard"
            return "Ballast to level: move \(value) tonnes from \(from) tank to \(to) tank"
        }
    }

    public struct LegendChip: Equatable, Sendable {
        public let text: String
        public let tone: Tone
        public let isActive: Bool
    }

    // MARK: - Output state

    public let status: Status
    public let result: CraneHeelMath.Result?
    /// Wrapped azimuth for the ring knob / slider, nil while the azimuth field is empty or not a number.
    public let ringAzimuthDeg: Double?
    /// "+7.6", "-7.6", "0.0", or "—". The unit "°" is drawn separately.
    public let heelValueText: String
    /// "Stbd" / "Port" / "Upright", nil when there is no result.
    public let sideText: String?
    /// LIVE HEEL row: "+7.6° Stbd", "0.0° Upright", or "—".
    public let liveHeelText: String
    /// Pill under LIVE HEEL (no side): "Soft heel · 5° or more". nil when there is no result.
    public let livePillText: String?
    /// RESULT card pill. nil when there is no result.
    public let resultPillText: String?
    public let tone: Tone?
    /// nil = hide the ballast tile and tank highlight.
    public let ballast: BallastTile?
    public let legend: [LegendChip]
    /// Rotation for the stern-view glyph, degrees (+ = stbd down). Heel clamped to ±45 so the glyph stays readable.
    public let glyphRotationDeg: Double
    public let heelAccessibilityLabel: String

    // B2 output state
    /// The math result behind every number on screen (single or move). nil while incomplete / invalid.
    public let lift: CraneHeelMath.MoveResult?
    /// Start azimuth wrapped, for the ghost boom / Start knob. nil while not a number.
    public let startRingAzimuthDeg: Double?
    /// Both Start fields empty (single-point check).
    public let isStartBlank: Bool
    /// "Ship level at start" / "Crane on CL assumed" / nil. Never both.
    public let note: String?
    /// Grey line shown instead of the ballast tile when the tank distance is blank (and heel isn't 0.0).
    public let ballastPrompt: String?
    /// Lift card rows, e.g. "Aft 180° · 12 m". nil = not set. Start row never shows a heel.
    public let startRowText: String?
    public let endRowText: String?
    /// Heel on the End row, e.g. "+7.6°". nil without a result.
    public let endRowHeelText: String?
    /// Gauge needle in dial degrees (same rounded heel as the number and pill). nil without a result.
    public let gaugeNeedleDialDeg: Double?
    public let gaugeZones: [GaugeZone]
    /// |heel| beyond the dial's last section (20°): needle parked at the end stop.
    public let gaugeIsPegged: Bool
    /// VoiceOver value for the gauge, e.g. "+7.6 degrees, soft zone, starboard".
    public let gaugeAccessibilityValue: String

    public var errorField: Field? {
        if case .invalid(let f, _) = status { return f }
        return nil
    }
    public var errorReason: String? {
        if case .invalid(_, let r) = status { return r }
        return nil
    }
    /// Reason shown under the result when it isn't tied to a field.
    public var generalErrorReason: String? {
        if case .invalid(nil, let r) = status { return r }
        return nil
    }

    // MARK: - Build

    public init(inputs: Inputs) {
        var parsed: [Field: Double] = [:]
        var incomplete = false
        var failure: Status? = nil

        for field in Field.allCases {
            switch Self.parse(inputs[field]) {
            case .empty, .partial:
                if field.isRequired || Self.isPartial(inputs[field]) { incomplete = true }
            case .invalid:
                if failure == nil { failure = .invalid(field: field, reason: field.errorReason) }
            case .value(let v):
                parsed[field] = v
            }
        }

        if case .value(let a) = Self.parse(inputs.azimuth) {
            ringAzimuthDeg = CraneHeelMath.wrapAzimuth(a)
        } else {
            ringAzimuthDeg = nil
        }

        // B2 Start: both empty = single point; exactly one with a number and the other empty = reject.
        let startA = Self.parse(inputs.startAzimuth), startR = Self.parse(inputs.startOutreach)
        let startBlank = startA == .empty && startR == .empty
        if failure == nil {
            if case .value = startA, startR == .empty {
                failure = .invalid(field: .startOutreach, reason: CraneHeelMath.MoveReason.startIncomplete)
            } else if case .value = startR, startA == .empty {
                failure = .invalid(field: .startAzimuth, reason: CraneHeelMath.MoveReason.startIncomplete)
            }
        }
        isStartBlank = startBlank
        if case .value(let a) = startA { startRingAzimuthDeg = CraneHeelMath.wrapAzimuth(a) } else { startRingAzimuthDeg = nil }
        startRowText = Self.positionText(azimuthText: inputs.startAzimuth, outreachText: inputs.startOutreach)
        endRowText = Self.positionText(azimuthText: inputs.azimuth, outreachText: inputs.outreach)

        let status: Status
        var result: CraneHeelMath.Result? = nil
        var lift: CraneHeelMath.MoveResult? = nil
        if let failure {
            status = failure
        } else if incomplete {
            status = .incomplete
        } else {
            // Start blank → `move` returns exactly `heel(...)` (single point); otherwise the two-point move.
            let outcome = CraneHeelMath.move(
                endAzimuthDeg: parsed[.azimuth]!,
                endOutreach: parsed[.outreach]!,
                hookLoad: parsed[.hookLoad]!,
                displacement: parsed[.displacement]!,
                gm: parsed[.gm]!,
                startAzimuthDeg: parsed[.startAzimuth],
                startOutreach: parsed[.startOutreach],
                pivotOffset: parsed[.pivotOffset] ?? 0.0,
                ballastLever: parsed[.tankDistance]
            )
            switch outcome {
            case .ok(let m):
                status = .ok
                lift = m
                result = m.single
            case .invalid(let reason):
                let field = Self.field(forMathReason: reason)
                status = .invalid(field: field, reason: field?.errorReason ?? reason)
            }
        }

        self.status = status
        self.result = result
        self.lift = lift

        guard let r = lift else {
            heelValueText = Self.dash
            sideText = nil
            liveHeelText = Self.dash
            livePillText = nil
            resultPillText = nil
            tone = nil
            ballast = nil
            legend = Self.legend(active: nil)
            glyphRotationDeg = 0
            heelAccessibilityLabel = "Heel not available. Enter boom azimuth, outreach, hook load, displacement and GM."
            note = nil
            ballastPrompt = nil
            endRowHeelText = nil
            gaugeNeedleDialDeg = nil
            gaugeZones = Self.gaugeZones(activeHeel: nil)
            gaugeIsPegged = false
            gaugeAccessibilityValue = "Not available"
            return
        }

        let heel = Self.formatHeel(r.heelDeg)
        let side = Self.sideWord(r.side)
        let level = Self.tone(r.warning)
        heelValueText = heel
        sideText = side
        liveHeelText = "\(heel)° \(side)"
        livePillText = Self.levelPill(level)
        resultPillText = Self.resultPill(tone: level, heelDeg: r.heelDeg, side: r.side)
        tone = level
        // Ballast: rounded half away from zero (same helper as the heel); hidden when that shows 0.0 t.
        let shownBallast = r.ballastTonnes.map { CraneHeelMath.roundHeel($0) }
        if let shown = shownBallast, shown != 0, let pump = r.pumpTo {
            ballast = BallastTile(value: Self.format1(shown), unit: "t", caption: Self.ballastCaption(pumpTo: pump), pumpTo: pump,
                                  direction: Self.ballastDirection(pumpTo: pump),
                                  qualifier: r.mode == .move ? Self.ballastQualifierMove : Self.ballastQualifierSingle,
                                  signedTonnes: pump == .port ? shown : -shown)
        } else {
            ballast = nil
        }
        ballastPrompt = (Self.parse(inputs.tankDistance) == .empty && r.heelDeg != 0) ? Self.ballastPromptText : nil
        if r.mode == .move {
            note = Self.noteShipLevelAtStart
        } else if startBlank && Self.parse(inputs.pivotOffset) == .empty {
            note = Self.noteCraneOnCL
        } else {
            note = nil
        }
        endRowHeelText = "\(heel)°"
        gaugeNeedleDialDeg = Self.gaugeDialDeg(forHeel: r.heelDeg)
        gaugeZones = Self.gaugeZones(activeHeel: r.heelDeg)
        gaugeIsPegged = abs(r.heelDeg) > Self.gaugeMaxHeelDeg
        gaugeAccessibilityValue = Self.gaugeValueText(heelDeg: r.heelDeg, tone: level, side: r.side)
        legend = Self.legend(active: level)
        glyphRotationDeg = max(-45, min(45, r.heelDeg))
        switch r.side {
        case .upright: heelAccessibilityLabel = "Heel 0.0 degrees, upright. \(Self.levelPill(level))"
        case .stbd, .port:
            let dir = r.side == .stbd ? "starboard" : "port"
            heelAccessibilityLabel = "Heel \(Self.format1(abs(r.heelDeg))) degrees to \(dir). \(resultPillText ?? "")"
        }
    }

    // MARK: - Copy helpers (public for tests / previews)

    /// "+7.6" for stbd, "-7.6" for port, "0.0" upright. Never "-0.0" or "+0.0".
    public static func formatHeel(_ deg: Double) -> String {
        let s = format1(deg)
        if s == "0.0" || s == "-0.0" { return "0.0" }
        return deg > 0 ? "+" + s : s
    }

    /// One decimal, "." separator, locale-independent (matches the mock).
    public static func format1(_ v: Double) -> String { String(format: "%.1f", v) }

    public static func sideWord(_ side: CraneHeelMath.HeelSide) -> String {
        switch side {
        case .stbd: return "Stbd"
        case .port: return "Port"
        case .upright: return "Upright"
        }
    }

    public static func tone(_ w: CraneHeelMath.Warning) -> Tone {
        switch w {
        case .none: return .clear
        case .soft: return .soft
        case .hard: return .hard
        }
    }

    /// Pill text without side, used for the LIVE HEEL row.
    public static func levelPill(_ tone: Tone) -> String {
        switch tone {
        case .clear: return "Clear · under 5°"
        case .soft: return "Soft heel · 5° or more"
        case .hard: return "Hard heel · 10° or more"
        }
    }

    /// RESULT pill: 0.0° → "Clear · under 5°" (no "to …"), otherwise "<Level> to <side> · <band>".
    public static func resultPill(tone: Tone, heelDeg: Double, side: CraneHeelMath.HeelSide) -> String {
        guard heelDeg != 0, side != .upright else { return levelPill(.clear) }
        let sideLower = side == .stbd ? "stbd" : "port"
        switch tone {
        case .clear: return "Clear to \(sideLower) · under 5°"
        case .soft: return "Soft heel to \(sideLower) · 5° or more"
        case .hard: return "Hard heel to \(sideLower) · 10° or more"
        }
    }

    /// pumpTo .port → "to move stbd tank → port tank"; .stbd → "to move port tank → stbd tank".
    public static func ballastCaption(pumpTo: CraneHeelMath.Board) -> String {
        "to move " + ballastDirection(pumpTo: pumpTo)
    }

    /// B2 tile direction. pumpTo .port (w > 0) → "stbd tank → port tank"; .stbd (w < 0) → "port tank → stbd tank".
    public static func ballastDirection(pumpTo: CraneHeelMath.Board) -> String {
        pumpTo == .port ? "stbd tank → port tank" : "port tank → stbd tank"
    }

    public static func legend(active: Tone?) -> [LegendChip] {
        [LegendChip(text: "Clear <5°", tone: .clear, isActive: active == .clear),
         LegendChip(text: "Soft ≥5°", tone: .soft, isActive: active == .soft),
         LegendChip(text: "Hard ≥10°", tone: .hard, isActive: active == .hard)]
    }

    static func field(forMathReason reason: String) -> Field? {
        switch reason {
        case CraneHeelMath.Reason.azimuth: return .azimuth
        case CraneHeelMath.Reason.outreach: return .outreach
        case CraneHeelMath.Reason.hookLoad: return .hookLoad
        case CraneHeelMath.Reason.displacement: return .displacement
        case CraneHeelMath.Reason.gm: return .gm
        case CraneHeelMath.Reason.pivotOffset: return .pivotOffset
        case CraneHeelMath.Reason.ballastLever: return .tankDistance
        case CraneHeelMath.MoveReason.startAzimuth: return .startAzimuth
        case CraneHeelMath.MoveReason.startOutreach: return .startOutreach
        default: return nil
        }
    }

    // MARK: - Parsing

    public enum Parsed: Equatable, Sendable {
        case empty
        /// Half-typed number: "-", "+", ".", ",", "-." — treated as not yet entered (no red flash).
        case partial
        case invalid
        case value(Double)
    }

    private static let partialTokens: Set<String> = ["-", "+", ".", ",", "-.", "-,", "+.", "+,"]

    static func isPartial(_ text: String) -> Bool {
        partialTokens.contains(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Accepts "1.5" or "1,5" (Norwegian decimal pad), an optional sign and exponent, and spaces as
    /// thousands separators ("8 000"). Rejects text such as "abc", "inf", "nan" or "0x10", and anything non-finite such as "1e400".
    public static func parse(_ text: String) -> Parsed {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return .empty }
        if partialTokens.contains(s) { return .partial }
        s = s.replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: "\u{202F}", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        let allowed = Set("0123456789+-.eE")
        guard s.allSatisfy({ allowed.contains($0) }), let v = Double(s), v.isFinite else { return .invalid }
        return .value(v)
    }

    // MARK: - Ring helpers

    /// Azimuth from a touch on the ring. `dx`/`dy` are relative to the ring centre in screen points
    /// (y down). Bow is up, so (0, -1) → 0°, (1, 0) → 90°. Snapped to whole degrees, 0..<360.
    public static func azimuthFromDrag(dx: Double, dy: Double) -> Double? {
        guard dx.isFinite, dy.isFinite, dx != 0 || dy != 0 else { return nil }
        let deg = atan2(dx, -dy) * 180.0 / Double.pi
        let snapped = deg.rounded()
        return CraneHeelMath.wrapAzimuth(snapped)
    }

    /// VoiceOver adjustable action: ±`ringStepDeg`, wrapping 355 + 5 → 0. An empty field starts from 0.
    public static func stepAzimuth(_ current: Double?, increment: Bool) -> Double {
        let base = current.map(CraneHeelMath.wrapAzimuth) ?? 0
        return CraneHeelMath.wrapAzimuth(base + (increment ? ringStepDeg : -ringStepDeg))
    }

    /// Text written back into the azimuth field after a drag / slider / VoiceOver change: whole degrees.
    public static func azimuthFieldText(_ deg: Double) -> String {
        String(Int(CraneHeelMath.wrapAzimuth(deg.rounded())))
    }

    /// Slider position for the azimuth text: typed 0…360 is used as-is (so "360" keeps the thumb at the end),
    /// anything else is wrapped. Empty or not a number → 0.
    public static func sliderValue(forAzimuthText text: String) -> Double {
        guard case .value(let v) = parse(text) else { return 0 }
        return (0...360).contains(v) ? v : CraneHeelMath.wrapAzimuth(v)
    }

    /// Text written by the slider: whole degrees 0…360, not wrapped (the math wraps 360 → 0).
    public static func sliderFieldText(_ v: Double) -> String {
        String(Int(min(360, max(0, v.rounded()))))
    }

    /// VoiceOver value for the ring, e.g. "90 degrees, starboard side".
    public static func ringAccessibilityValue(_ deg: Double?) -> String {
        guard let d = deg else { return "Not set" }
        let w = CraneHeelMath.wrapAzimuth(d)
        let deg = w == w.rounded() ? String(Int(w)) : format1(w)
        let where_: String
        switch w {
        case 0: where_ = "over the bow, on centreline"
        case 180: where_ = "over the stern, on centreline"
        case 90: where_ = "starboard beam"
        case 270: where_ = "port beam"
        case let x where x > 0 && x < 180: where_ = "starboard side"
        default: where_ = "port side"
        }
        return "\(deg) degrees, \(where_)"
    }

    // MARK: - B2 lift positions

    /// Which position the Lift card's ring, quick buttons and two fields are editing.
    public enum LiftPosition: String, CaseIterable, Sendable {
        case start, end

        /// Segmented control, e.g. "Start · on deck".
        public var segmentTitle: String { self == .start ? "Start · on deck" : "End · over side" }
        /// Row title in the Lift card.
        public var rowTitle: String { self == .start ? "Start" : "End" }
        public var azimuthField: Field { self == .start ? .startAzimuth : .azimuth }
        public var outreachField: Field { self == .start ? .startOutreach : .outreach }
        /// UITest id on the Lift card row, e.g. `craneLift.start`.
        public var rowAccessibilityIdentifier: String { "craneLift.\(rawValue)" }
        /// UITest id on the segment button, e.g. `craneLift.segment.start`.
        public var segmentAccessibilityIdentifier: String { "craneLift.segment.\(rawValue)" }
    }

    /// Quick angle buttons. `allCases` is Bow 0 / Stbd 90 / Aft 180 / Port 270; the mock's 2×2 grid is `gridOrder`.
    public enum QuickAngle: String, CaseIterable, Sendable {
        case bow, stbd, aft, port

        public var degrees: Double {
            switch self {
            case .bow: return 0
            case .stbd: return 90
            case .aft: return 180
            case .port: return 270
            }
        }
        public var title: String {
            switch self {
            case .bow: return "Bow"
            case .stbd: return "Stbd"
            case .aft: return "Aft"
            case .port: return "Port"
            }
        }
        /// "90°"
        public var subtitle: String { "\(Int(degrees))°" }
        /// Text written into the active azimuth field.
        public var fieldText: String { String(Int(degrees)) }
        /// UITest id, e.g. `craneQuick.stbd`.
        public var accessibilityIdentifier: String { "craneQuick.\(rawValue)" }
        public var accessibilityLabel: String {
            switch self {
            case .bow: return "Bow, 0 degrees"
            case .stbd: return "Starboard, 90 degrees"
            case .aft: return "Aft, 180 degrees"
            case .port: return "Port, 270 degrees"
            }
        }
        /// Mock layout: Port | Bow / Stbd | Aft.
        public static let gridOrder: [QuickAngle] = [.port, .bow, .stbd, .aft]

        /// Highlighted when the typed azimuth wraps to exactly this angle (e.g. "-270" lights Stbd).
        public func isSelected(azimuthText: String) -> Bool {
            guard case .value(let v) = CraneHeelPresentation.parse(azimuthText) else { return false }
            return CraneHeelMath.wrapAzimuth(v) == degrees
        }
    }

    /// Lift row text from the two typed fields: "Aft 180° · 12 m", "Stbd 90° · —", nil when neither is a number.
    public static func positionText(azimuthText: String, outreachText: String) -> String? {
        let a = parse(azimuthText), r = parse(outreachText)
        var azPart = dash, rPart = dash
        var any = false
        if case .value(let v) = a {
            let w = displayAzimuth(v)
            azPart = "\(sectorName(w)) \(formatAmount(w))°"
            any = true
        }
        if case .value(let v) = r {
            rPart = "\(formatAmount(v)) m"
            any = true
        }
        return any ? "\(azPart) · \(rPart)" : nil
    }

    /// Wrapped azimuth rounded to 0.1° for display; 359.96 shows as 0.
    public static func displayAzimuth(_ deg: Double) -> Double {
        let w = CraneHeelMath.wrapAzimuth(deg)
        let r = (w * 10).rounded() / 10
        return r >= 360 ? 0 : r
    }

    /// Bow / Stbd / Aft / Port on the cardinals; between them, the side the boom is over (Stbd 0–180, Port 180–360).
    public static func sectorName(_ wrappedDeg: Double) -> String {
        switch wrappedDeg {
        case 0: return "Bow"
        case 90: return "Stbd"
        case 180: return "Aft"
        case 270: return "Port"
        case let x where x > 0 && x < 180: return "Stbd"
        default: return "Port"
        }
    }

    /// "12", "12.5", "12.25": whole numbers without decimals, otherwise up to 2 decimals.
    public static func formatAmount(_ v: Double) -> String {
        if v == v.rounded(), abs(v) < 1e15 { return String(Int(v)) }
        var s = String(format: "%.2f", v)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s == "-0" ? "0" : s
    }

    /// Where a position puts the hook, for the sketches (not for the math): wrapped azimuth, outreach and the
    /// transverse lever y = R·sin θ (exact at 0/90/180/270, + stbd, pivot not included). nil until both are numbers.
    public struct SketchPosition: Equatable, Sendable {
        public let azimuthDeg: Double
        public let outreach: Double
        public let y: Double
    }

    public static func sketchPosition(azimuthText: String, outreachText: String) -> SketchPosition? {
        guard case .value(let a) = parse(azimuthText), case .value(let r) = parse(outreachText), r >= 0 else { return nil }
        let w = CraneHeelMath.wrapAzimuth(a)
        return SketchPosition(azimuthDeg: w, outreach: r, y: r * CraneHeelMath.exactSinCos(wrappedDeg: w).sin)
    }

    // MARK: - B2 drag helpers

    /// Field text for a boom drag on the top-view ring: whole degrees, wrapped, so dragging past the bow
    /// goes 359 → 0 → 1 (never "360"). nil for a touch on the centre.
    public static func dragAzimuthText(dx: Double, dy: Double) -> String? {
        guard let deg = azimuthFromDrag(dx: dx, dy: dy) else { return nil }
        return azimuthFieldText(deg)
    }

    /// Turn the boom by `delta` degrees from `current`, wrapping past 360 either way (350 + 20 → 10, 10 − 20 → 350).
    public static func rotatedAzimuth(_ current: Double, byDeg delta: Double) -> Double {
        CraneHeelMath.wrapAzimuth(current + delta)
    }

    // MARK: - B2 gauge (stretched clinometer)

    /// Last heel on the dial; beyond it the needle parks at the end stop.
    public static let gaugeMaxHeelDeg = 20.0
    /// Fixed sections: heel breakpoints and the dial angle (degrees from top, + = clockwise/stbd) they land on.
    /// Clear 0–5 and Soft 5–10 each get 20° of dial, Hard 10–20 gets 20°. So 5° and 10° sit exactly on their ticks.
    public static let gaugeBreakHeels: [Double] = [0, 5, 10, 20]
    public static let gaugeBreakDials: [Double] = [0, 20, 40, 60]
    public static var gaugeMaxDialDeg: Double { gaugeBreakDials[gaugeBreakDials.count - 1] }

    /// Heel (degrees, + stbd) → dial angle (degrees from top, + clockwise). Odd, monotonic, piecewise linear,
    /// exact at the breakpoints, clamped at ±`gaugeMaxHeelDeg`. NaN → 0. Never −0.0.
    public static func gaugeDialDeg(forHeel h: Double) -> Double {
        if h.isNaN { return 0 }
        let a = min(abs(h), gaugeMaxHeelDeg)
        var dial = gaugeMaxDialDeg
        for i in 1..<gaugeBreakHeels.count where a <= gaugeBreakHeels[i] {
            let h0 = gaugeBreakHeels[i - 1], h1 = gaugeBreakHeels[i]
            let d0 = gaugeBreakDials[i - 1], d1 = gaugeBreakDials[i]
            dial = a == h1 ? d1 : (a == h0 ? d0 : d0 + (a - h0) / (h1 - h0) * (d1 - d0))
            break
        }
        let v = h < 0 ? -dial : dial
        return v == 0 ? 0.0 : v
    }

    public struct GaugeZone: Equatable, Sendable {
        /// "port.hard", "port.soft", "clear", "stbd.soft", "stbd.hard"
        public let id: String
        public let tone: Tone
        public let fromHeel: Double
        public let toHeel: Double
        public let fromDial: Double
        public let toDial: Double
        public let isActive: Bool
    }

    /// The five dial zones, port to stbd. Active zone from the ROUNDED heel (same thresholds as the warning).
    public static func gaugeZones(activeHeel: Double?) -> [GaugeZone] {
        let soft = CraneHeelMath.softWarnDeg, hard = CraneHeelMath.hardWarnDeg, end = gaugeMaxHeelDeg
        let spans: [(String, Tone, Double, Double)] = [
            ("port.hard", .hard, -end, -hard), ("port.soft", .soft, -hard, -soft), ("clear", .clear, -soft, soft),
            ("stbd.soft", .soft, soft, hard), ("stbd.hard", .hard, hard, end),
        ]
        var activeID: String? = nil
        if let h = activeHeel, !h.isNaN {
            let a = abs(h)
            if a >= hard { activeID = h > 0 ? "stbd.hard" : "port.hard" }
            else if a >= soft { activeID = h > 0 ? "stbd.soft" : "port.soft" }
            else { activeID = "clear" }
        }
        return spans.map { id, tone, f, t in
            GaugeZone(id: id, tone: tone, fromHeel: f, toHeel: t,
                      fromDial: gaugeDialDeg(forHeel: f), toDial: gaugeDialDeg(forHeel: t), isActive: id == activeID)
        }
    }

    public struct GaugeTick: Equatable, Sendable {
        public let heelDeg: Double
        public let dialDeg: Double
        public let isMajor: Bool
        /// "0", "5", "10" (no sign; P/S are marked on the view). nil = unlabelled.
        public let label: String?
    }

    /// Ticks every 5° of heel; zone edges (0, ±5, ±10) and the end stops are major; 0/5/10 labelled.
    public static let gaugeTicks: [GaugeTick] = stride(from: -20.0, through: 20.0, by: 5.0).map { h in
        let a = abs(h)
        return GaugeTick(heelDeg: h, dialDeg: gaugeDialDeg(forHeel: h), isMajor: a != 15,
                         label: a <= 10 ? String(Int(a)) : nil)
    }

    /// "+7.6 degrees, soft zone, starboard"; "0.0 degrees, clear zone"; adds ", beyond the dial" past 20°.
    public static func gaugeValueText(heelDeg: Double, tone: Tone, side: CraneHeelMath.HeelSide) -> String {
        var s = "\(formatHeel(heelDeg)) degrees, \(tone.rawValue) zone"
        if side == .stbd { s += ", starboard" } else if side == .port { s += ", port" }
        if abs(heelDeg) > gaugeMaxHeelDeg { s += ", beyond the dial" }
        return s
    }
}
