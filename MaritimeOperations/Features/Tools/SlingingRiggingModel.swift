import Foundation
import Observation

/// Form state for Slinging & Rigging. Text stays text until a result is built.
/// Slings and Chain block keep their own fields. Maths: `RiggingMath`.
@Observable
final class SlingingRiggingModel {
    enum Tab: String, CaseIterable, Identifiable, Hashable {
        case slings = "Slings"
        case chain = "Chain block"
        var id: String { rawValue }
    }

    enum AngleMode: String, CaseIterable, Identifiable, Hashable {
        case angle = "Angle"
        case lengthHeight = "Length + height"
        var id: String { rawValue }
    }

    enum ChainMode: String, CaseIterable, Identifiable, Hashable {
        case single = "Single"
        case twoBlock = "Two-block"
        var id: String { rawValue }
    }

    enum Panel: Equatable {
        case guidance(String)
        case invalid(String)
        case blocked(String)
        case sling(SlingReadout)
        case chainSingle(ChainSingleReadout)
        case chainPair(ChainPairReadout)
    }

    struct FieldErrors: Equatable {
        var load: String?
        var length: String?
        var height: String?
        var angle: String?
        var tag: String?
        var blockWLL: String?
        var beta1: String?
        var beta2: String?
        var block1: String?
        var block2: String?
    }

    struct Echo: Equatable {
        var visible: String
        var spoken: String
    }

    struct SlingReadout: Equatable {
        var hero: String
        var heroSpoken: String
        var within: Bool
        var angleLabel: String
        var bandLine: String
        var bandSpoken: String
        var requiredLine: String
        var requiredSpoken: String
        var assemblyLine: String
        var assemblySpoken: String
        var tensionLine: String
        var tensionSpoken: String
        var trigLine: String
        var assumptions: String
        var amber: String?
    }

    struct ChainSingleReadout: Equatable {
        var hero: String
        var heroSpoken: String
        var within: Bool
        var loadLine: String
        var loadSpoken: String
        var wllLine: String
        var wllSpoken: String
        var angleLine: String
        var angleSpoken: String
        var noReduction: String?
        var amber: String?
    }

    struct ChainPairReadout: Equatable {
        var hero: String?
        var heroSpoken: String?
        var within: Bool?
        var tension1Line: String
        var tension1Spoken: String
        var tension2Line: String
        var tension2Spoken: String
        var angle1Line: String
        var angle1Spoken: String
        var angle2Line: String
        var angle2Spoken: String
        var share1Line: String?
        var share1Spoken: String?
        var share2Line: String?
        var share2Spoken: String?
        var hint: String?
        var amber: String
    }

    struct SlingScreen: Equatable {
        var errors: FieldErrors
        var echo: Echo?
        var panel: Panel
    }

    struct ChainScreen: Equatable {
        var errors: FieldErrors
        var echo: Echo?
        var panel: Panel
    }

    static let unitStorageKey = "rigging.unit"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var tab: Tab = .slings
    var angleMode: AngleMode = .lengthHeight
    var legs: Int = 2
    var hitch: RiggingMath.Hitch = .straight
    var slingUnit: RiggingMath.MassUnit = .tonnes
    var loadText = ""
    var lengthText = ""
    var heightText = ""
    var angleText = ""
    var tagText = ""

    var chainMode: ChainMode = .single
    var chainUnit: RiggingMath.MassUnit = .tonnes
    var chainLoadText = ""
    var chainWLLText = ""
    var chainAngleText = ""
    var chainBeta1Text = ""
    var chainBeta2Text = ""
    var chainWLL1Text = ""
    var chainWLL2Text = ""

    var legNote: String? { legs >= 3 ? RiggingCopy.legNote : nil }
    var chokeNote: String? { hitch == .choke ? RiggingCopy.chokeCaption : nil }

    var slingScreen: SlingScreen { Self.makeSling(self) }
    var chainScreen: ChainScreen { Self.makeChain(self) }

    var lastResultSummary: String? {
        switch tab {
        case .slings: return slingSummary
        case .chain: return chainSummary
        }
    }

    private var slingSummary: String? {
        switch slingScreen.panel {
        case .blocked:
            return "Last sling · outside rated range"
        case .sling(let row):
            let word = row.within ? "within" : "exceeds"
            let angle = RiggingMath.summaryDegrees(row.angleLabel)
            return "Last sling \(summaryMass(loadText, unit: slingUnit)) · \(word) · \(angle)°"
        default:
            return nil
        }
    }

    private var chainSummary: String? {
        switch chainScreen.panel {
        case .blocked:
            return "Last block · outside rated range"
        case .chainSingle(let row):
            let word = row.within ? "within" : "exceeds"
            return "Last block \(summaryMass(chainLoadText, unit: chainUnit)) · \(word)"
        case .chainPair(let row):
            let load = summaryMass(chainLoadText, unit: chainUnit)
            if let within = row.within {
                return "Last block \(load) · \(within ? "within" : "exceeds")"
            }
            return "Last block \(load) · two-block"
        default:
            return nil
        }
    }

    func applyStoredUnit(_ raw: String) {
        guard let unit = RiggingMath.MassUnit(rawValue: raw) else { return }
        setSlingUnit(unit)
        setChainUnit(unit)
    }

    func setSlingUnit(_ unit: RiggingMath.MassUnit) {
        guard unit != slingUnit else { return }
        let old = slingUnit
        loadText = RiggingMath.converting(loadText, from: old, to: unit)
        tagText = RiggingMath.converting(tagText, from: old, to: unit)
        slingUnit = unit
        defaults.set(unit.rawValue, forKey: Self.unitStorageKey)
    }

    func setChainUnit(_ unit: RiggingMath.MassUnit) {
        guard unit != chainUnit else { return }
        let old = chainUnit
        chainLoadText = RiggingMath.converting(chainLoadText, from: old, to: unit)
        chainWLLText = RiggingMath.converting(chainWLLText, from: old, to: unit)
        chainWLL1Text = RiggingMath.converting(chainWLL1Text, from: old, to: unit)
        chainWLL2Text = RiggingMath.converting(chainWLL2Text, from: old, to: unit)
        chainUnit = unit
        defaults.set(unit.rawValue, forKey: Self.unitStorageKey)
    }

    private func summaryMass(_ text: String, unit: RiggingMath.MassUnit) -> String {
        let trimmed = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        return "\(trimmed) \(unit.rawValue)"
    }
}

// MARK: - Evaluation

extension SlingingRiggingModel {
    fileprivate static func makeSling(_ m: SlingingRiggingModel) -> SlingScreen {
        var errors = FieldErrors()
        let load = mass(&errors.load, m.loadText, positive: RiggingCopy.loadPositive)
        let tag = mass(&errors.tag, m.tagText, positive: RiggingCopy.tagPositive)

        let beta: Decimal?
        switch m.angleMode {
        case .angle:
            beta = angle(&errors.angle, m.angleText)
        case .lengthHeight:
            beta = geometryBeta(&errors, lengthText: m.lengthText, heightText: m.heightText)
        }

        // A known angle past 60° blocks the result. Other field errors still tint their fields.
        if errors.angle == nil, errors.length == nil, errors.height == nil, let beta, beta > 60 {
            return SlingScreen(errors: errors, echo: nil, panel: .blocked(RiggingCopy.blocked))
        }
        if errors.hasAny {
            return SlingScreen(errors: errors, echo: nil, panel: .invalid(errors.firstMessage))
        }
        let echo = beta.map { echoLine($0) }
        guard let beta, let load, let tag else {
            let text = m.angleMode == .lengthHeight ? RiggingCopy.slingGuidanceLength : RiggingCopy.slingGuidanceAngle
            return SlingScreen(errors: errors, echo: echo, panel: .guidance(text))
        }
        guard let value = RiggingMath.sling(
            load: load, legs: m.legs, hitch: m.hitch, beta: beta, tag: tag, unit: m.slingUnit
        ) else {
            return SlingScreen(errors: errors, echo: nil, panel: .blocked(RiggingCopy.blocked))
        }
        return SlingScreen(errors: errors, echo: echo, panel: .sling(slingReadout(value, unit: m.slingUnit)))
    }

    fileprivate static func makeChain(_ m: SlingingRiggingModel) -> ChainScreen {
        switch m.chainMode {
        case .single: return makeSingle(m)
        case .twoBlock: return makePair(m)
        }
    }

    private static func makeSingle(_ m: SlingingRiggingModel) -> ChainScreen {
        var errors = FieldErrors()
        let load = mass(&errors.load, m.chainLoadText, positive: RiggingCopy.loadPositive)
        let wll = mass(&errors.blockWLL, m.chainWLLText, positive: RiggingCopy.wllPositive)
        let beta = angle(&errors.angle, m.chainAngleText)
        if errors.angle == nil, let beta, beta > 60 {
            return ChainScreen(errors: errors, echo: nil, panel: .blocked(RiggingCopy.blocked))
        }
        if errors.hasAny {
            return ChainScreen(errors: errors, echo: nil, panel: .invalid(errors.firstMessage))
        }
        let echo = beta.map { chainEcho($0) }
        guard let beta, let load, let wll else {
            return ChainScreen(errors: errors, echo: echo, panel: .guidance(RiggingCopy.chainGuidance))
        }
        let within = load <= wll
        let angleLabel = RiggingMath.angleText(beta)
        let loadLine = RiggingMath.massText(load, unit: m.chainUnit)
        let wllLine = RiggingMath.massText(wll, unit: m.chainUnit)
        let hero = within ? RiggingCopy.withinBlock : RiggingCopy.exceeds
        let spokenAngle = "Angle \(angleLabel) degrees from vertical."
        let blockUnit = m.chainUnit == .tonnes ? "tonne" : "kilogram"
        let heroSpoken = "\(spokenHero(hero)). Load \(massNumber(loadLine, unit: m.chainUnit)) \(m.chainUnit.spoken) on a \(massNumber(wllLine, unit: m.chainUnit)) \(blockUnit) block. \(spokenAngle)"
        let amber: String? = beta > 0 ? RiggingCopy.chainAmber : nil
        let row = ChainSingleReadout(
            hero: hero,
            heroSpoken: heroSpoken,
            within: within,
            loadLine: loadLine,
            loadSpoken: "Load \(spokenMass(loadLine, unit: m.chainUnit)).",
            wllLine: wllLine,
            wllSpoken: "Block W L L \(spokenMass(wllLine, unit: m.chainUnit)).",
            angleLine: "\(angleLabel)° from vertical",
            angleSpoken: spokenAngle,
            noReduction: beta == 0 ? RiggingCopy.noReduction : nil,
            amber: amber
        )
        return ChainScreen(errors: errors, echo: echo, panel: .chainSingle(row))
    }

    private static func makePair(_ m: SlingingRiggingModel) -> ChainScreen {
        var errors = FieldErrors()
        let load = mass(&errors.load, m.chainLoadText, positive: RiggingCopy.loadPositive)
        let b1 = angle(&errors.beta1, m.chainBeta1Text)
        let b2 = angle(&errors.beta2, m.chainBeta2Text)
        let w1 = mass(&errors.block1, m.chainWLL1Text, positive: RiggingCopy.wllPositive)
        let w2 = mass(&errors.block2, m.chainWLL2Text, positive: RiggingCopy.wllPositive)
        let pastLimit = (b1.map { $0 > 60 } ?? false) || (b2.map { $0 > 60 } ?? false)
        if pastLimit {
            return ChainScreen(errors: errors, echo: nil, panel: .blocked(RiggingCopy.blocked))
        }
        if errors.hasAny {
            return ChainScreen(errors: errors, echo: nil, panel: .invalid(errors.firstMessage))
        }
        guard let load, let b1, let b2 else {
            return ChainScreen(errors: errors, echo: nil, panel: .guidance(RiggingCopy.pairGuidance))
        }
        if b1 + b2 == 0 {
            return ChainScreen(errors: errors, echo: nil, panel: .invalid(RiggingCopy.blocksApart))
        }
        guard let tensions = RiggingMath.pairTensions(load: load, beta1: b1, beta2: b2, unit: m.chainUnit) else {
            return ChainScreen(errors: errors, echo: nil, panel: .invalid(RiggingCopy.blocksApart))
        }
        let unit = m.chainUnit
        let t1 = RiggingMath.massText(tensions.t1, unit: unit)
        let t2 = RiggingMath.massText(tensions.t2, unit: unit)
        let a1 = RiggingMath.angleText(b1)
        let a2 = RiggingMath.angleText(b2)
        let comparisons = [(tensions.t1, w1), (tensions.t2, w2)].compactMap { tension, wll -> Bool? in
            guard let wll else { return nil }
            return tension <= wll
        }
        let within: Bool? = comparisons.isEmpty ? nil : comparisons.allSatisfy { $0 }
        let hero = within.map { $0 ? RiggingCopy.withinBlock : RiggingCopy.exceeds }
        let share1 = share(tension: tensions.t1, wll: w1, index: 1)
        let share2 = share(tension: tensions.t2, wll: w2, index: 2)
        let hint: String?
        if w1 == nil && w2 == nil {
            hint = RiggingCopy.compareHint
        } else if w1 == nil || w2 == nil {
            hint = RiggingCopy.oneWLLMissing
        } else {
            hint = nil
        }
        let row = ChainPairReadout(
            hero: hero,
            heroSpoken: hero.map { spokenHero($0) },
            within: within,
            tension1Line: t1,
            tension1Spoken: "Tension T 1 \(spokenMass(t1, unit: unit)).",
            tension2Line: t2,
            tension2Spoken: "Tension T 2 \(spokenMass(t2, unit: unit)).",
            angle1Line: "\(a1)° from vertical",
            angle1Spoken: "Angle beta 1 \(a1) degrees from vertical.",
            angle2Line: "\(a2)° from vertical",
            angle2Spoken: "Angle beta 2 \(a2) degrees from vertical.",
            share1Line: share1?.line,
            share1Spoken: share1?.spoken,
            share2Line: share2?.line,
            share2Spoken: share2?.spoken,
            hint: hint,
            amber: RiggingCopy.chainAmber
        )
        return ChainScreen(errors: errors, echo: nil, panel: .chainPair(row))
    }

    private static func slingReadout(_ value: RiggingMath.SlingValue, unit: RiggingMath.MassUnit) -> SlingReadout {
        let angle = RiggingMath.angleText(value.beta)
        let required = RiggingMath.massText(value.requiredTag, unit: unit)
        let assembly = RiggingMath.massText(value.assembly, unit: unit)
        let tension = RiggingMath.massText(value.tension, unit: unit)
        let hero = value.within ? RiggingCopy.withinMarked : RiggingCopy.exceeds
        let bandLine = "\(value.band.title) · M = \(RiggingMath.formatMode(value.modeFactor))"
        let amber = value.band.isHighAngle ? RiggingCopy.highAngle : nil
        var heroSpoken = "Angle \(angle) degrees from vertical, band \(value.band.spokenRange)."
        if amber != nil { heroSpoken += " Amber, high angle warning." }
        heroSpoken += " \(spokenHero(hero)). Tension per leg \(spokenMass(tension, unit: unit))."
        return SlingReadout(
            hero: hero,
            heroSpoken: heroSpoken,
            within: value.within,
            angleLabel: angle,
            bandLine: bandLine,
            bandSpoken: "Band \(value.band.spokenRange) degrees from vertical, mode factor \(RiggingMath.formatMode(value.modeFactor)).",
            requiredLine: "≥ \(required)",
            requiredSpoken: "Required tag W L L at least \(spokenMass(required, unit: unit)).",
            assemblyLine: assembly,
            assemblySpoken: "Assembly W L L \(spokenMass(assembly, unit: unit)).",
            tensionLine: tension,
            tensionSpoken: "Tension per leg \(spokenMass(tension, unit: unit)).",
            trigLine: RiggingCopy.trigLine(factor: RiggingMath.formatTrigFactor(value.trigFactor), tension: tension),
            assumptions: RiggingCopy.assumptions,
            amber: amber
        )
    }

    private static func echoLine(_ beta: Decimal) -> Echo {
        let angle = RiggingMath.angleText(beta)
        let band = RiggingMath.band(beta: beta)
        let visible = RiggingCopy.echo(angle: angle, band: band.title)
        var spoken = "Angle \(angle) degrees from vertical, band \(band.spokenRange)."
        if band.isHighAngle { spoken += " Amber, high angle warning." }
        return Echo(visible: visible, spoken: spoken)
    }

    private static func chainEcho(_ beta: Decimal) -> Echo {
        let angle = RiggingMath.angleText(beta)
        let visible = RiggingCopy.chainEcho(angle: angle, straight: beta == 0)
        return Echo(visible: visible, spoken: "Angle \(angle) degrees from vertical.")
    }

    private static func share(tension: Decimal, wll: Decimal?, index: Int) -> (line: String, spoken: String)? {
        guard let wll, let pct = RiggingMath.percentOfWLL(tension: tension, wll: wll) else { return nil }
        let digits = RiggingMath.formatFixed(pct, places: 0)
        return (
            "\(digits)%",
            "Block \(index) \(digits) percent of its W L L."
        )
    }

    private static func spokenHero(_ hero: String) -> String {
        if hero == RiggingCopy.withinMarked { return "Within marked W L L" }
        if hero == RiggingCopy.withinBlock { return "Within block W L L" }
        return hero
    }

    private static func massNumber(_ line: String, unit: RiggingMath.MassUnit) -> String {
        line.replacingOccurrences(of: " \(unit.rawValue)", with: "")
    }

    private static func spokenMass(_ line: String, unit: RiggingMath.MassUnit) -> String {
        "\(massNumber(line, unit: unit)) \(unit.spoken)"
    }

    /// Positive mass, or nil when the field is empty. Writes a field error when the text is unusable.
    private static func mass(_ error: inout String?, _ text: String, positive message: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        guard let value = RiggingMath.parseDecimal(trimmed) else {
            error = RiggingCopy.enterNumber
            return nil
        }
        if value <= 0 {
            error = message
            return nil
        }
        return value
    }

    /// Angle from vertical, 0...90 inclusive. Above 60 and at most 90 is returned so the caller can block it.
    private static func angle(_ error: inout String?, _ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        guard let value = RiggingMath.parseDecimal(trimmed) else {
            error = RiggingCopy.enterNumber
            return nil
        }
        if value < 0 {
            error = RiggingCopy.angleNegative
            return nil
        }
        if value > 90 {
            error = RiggingCopy.angleTooWide
            return nil
        }
        return value
    }

    private static func geometryBeta(_ errors: inout FieldErrors, lengthText: String, heightText: String) -> Decimal? {
        let lengthTrim = lengthText.trimmingCharacters(in: .whitespacesAndNewlines)
        let heightTrim = heightText.trimmingCharacters(in: .whitespacesAndNewlines)
        let length = lengthTrim.isEmpty ? nil : RiggingMath.parseDecimal(lengthTrim)
        let height = heightTrim.isEmpty ? nil : RiggingMath.parseDecimal(heightTrim)
        if !lengthTrim.isEmpty && length == nil { errors.length = RiggingCopy.enterNumber }
        if !heightTrim.isEmpty && height == nil { errors.height = RiggingCopy.enterNumber }
        if errors.length != nil || errors.height != nil { return nil }
        guard let length, let height else { return nil }
        switch RiggingMath.geometry(length: length, height: height) {
        case .lengthNotPositive:
            errors.length = RiggingCopy.lengthPositive
            return nil
        case .heightNotPositive:
            errors.height = RiggingCopy.heightPositive
            return nil
        case .heightExceedsLength:
            errors.height = RiggingCopy.heightTooTall
            return nil
        case .angle(let beta, let blocked):
            // H < L/2 is outside the rated range even if trig rounds back onto 60°.
            if blocked, beta <= 60 { return 61 }
            return beta
        }
    }
}

extension SlingingRiggingModel.FieldErrors {
    var hasAny: Bool {
        load != nil || length != nil || height != nil || angle != nil || tag != nil
            || blockWLL != nil || beta1 != nil || beta2 != nil || block1 != nil || block2 != nil
    }

    var firstMessage: String {
        load ?? length ?? height ?? angle ?? tag ?? blockWLL ?? beta1 ?? beta2 ?? block1 ?? block2 ?? RiggingCopy.enterNumber
    }
}
