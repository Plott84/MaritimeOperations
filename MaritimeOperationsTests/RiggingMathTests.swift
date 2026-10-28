import Foundation
import Testing
@testable import MaritimeOperations

/// P0 sling and chain-block cases (RG-12, 14, 18, 19, 23, 25, 27, 28, 37–43, 48–50)
/// plus the rounding and band rules those cases sit on.
struct RiggingMathTests {
    private func dec(_ text: String) -> Decimal {
        Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))!
    }

    private func sling(
        load: String = "6",
        tag: String = "5",
        legs: Int = 2,
        hitch: RiggingMath.Hitch = .straight,
        angle: String? = nil,
        length: String? = nil,
        height: String? = nil,
        unit: RiggingMath.MassUnit = .tonnes
    ) -> SlingingRiggingModel {
        let model = SlingingRiggingModel()
        if unit == .kilograms { model.setSlingUnit(.kilograms) }
        model.legs = legs
        model.hitch = hitch
        model.loadText = load
        model.tagText = tag
        if let angle {
            model.angleMode = .angle
            model.angleText = angle
        } else {
            model.angleMode = .lengthHeight
            model.lengthText = length ?? ""
            model.heightText = height ?? ""
        }
        return model
    }

    private func slingRow(_ model: SlingingRiggingModel) -> SlingingRiggingModel.SlingReadout? {
        if case .sling(let row) = model.slingScreen.panel { return row }
        return nil
    }

    private func single(
        load: String,
        wll: String,
        angle: String,
        unit: RiggingMath.MassUnit = .tonnes
    ) -> SlingingRiggingModel {
        let model = SlingingRiggingModel()
        model.tab = .chain
        model.chainMode = .single
        if unit == .kilograms { model.setChainUnit(.kilograms) }
        model.chainLoadText = load
        model.chainWLLText = wll
        model.chainAngleText = angle
        return model
    }

    private func hasDigit(_ text: String) -> Bool {
        text.rangeOfCharacter(from: .decimalDigits) != nil
    }

    private func assertClean(_ strings: [String]) {
        let banned = ["safe", "ok to lift", "certified", "approved", "compliant"]
        for text in strings {
            let lower = text.lowercased()
            for word in banned {
                #expect(!lower.contains(word), "\(word) in \(text)")
            }
        }
    }

    // MARK: - Rounding and factors

    @Test func roundingRequiredAndTensionUpCapacityDown() {
        #expect(RiggingMath.formatFixed(RiggingMath.roundUp(dec("4.2857"), places: 2), places: 2) == "4.29")
        #expect(RiggingMath.formatFixed(RiggingMath.roundUp(dec("3.916"), places: 2), places: 2) == "3.92")
        #expect(RiggingMath.formatFixed(RiggingMath.roundUp(dec("1.6961"), places: 2), places: 2) == "1.70")
        #expect(RiggingMath.formatFixed(RiggingMath.roundUp(dec("0.7082"), places: 2), places: 2) == "0.71")
        #expect(RiggingMath.formatFixed(RiggingMath.roundUp(dec("1.70750"), places: 3), places: 3) == "1.708")
        #expect(RiggingMath.formatFixed(RiggingMath.roundUp(dec("3.4641016"), places: 2), places: 2) == "3.47")
        #expect(RiggingMath.formatFixed(RiggingMath.roundDown(dec("5.333"), places: 2), places: 2) == "5.33")
        #expect(RiggingMath.formatFixed(RiggingMath.roundDown(dec("422.6"), places: 0), places: 0) == "422")
        #expect(RiggingMath.formatFixed(RiggingMath.roundDown(dec("7.42"), places: 2), places: 2) == "7.42")
        // Binary 5.3 × 1.4 is 7.41999… Decimal keeps 7.42, and capacity does not step down to 7.41.
        let product = dec("5.3") * dec("1.4")
        #expect(RiggingMath.formatFixed(RiggingMath.roundDown(product, places: 2), places: 2) == "7.42")
    }

    @Test func trigFactorTable() {
        let table: [(String, Double)] = [
            ("0", 1.000),
            ("15", 1.035276180410083),
            ("30", 1.1547005383792515),
            ("45", 1.414213562373095),
            ("50", 1.5557238268604123),
            ("60", 2.0)
        ]
        for (angle, expected) in table {
            let factor = RiggingMath.trigFactor(degrees: dec(angle))
            #expect(abs(factor - expected) < 0.001, "β \(angle)")
        }
        #expect(RiggingMath.formatTrigFactor(RiggingMath.trigFactor(degrees: dec("40"))) == "1.305")
        #expect(RiggingMath.formatTrigFactor(RiggingMath.trigFactor(degrees: dec("0"))) == "1.000")
        #expect(RiggingMath.formatTrigFactor(RiggingMath.trigFactor(degrees: dec("60"))) == "2.000")
    }

    @Test func angleLabelDoesNotCrossABand() {
        #expect(RiggingMath.angleText(dec("45")) == "45.0")
        #expect(RiggingMath.angleText(dec("45.04")) == "45.04")
        #expect(RiggingMath.angleText(dec("45.06")) == "45.1")
        #expect(RiggingMath.angleText(dec("60")) == "60.0")
        #expect(RiggingMath.angleText(dec("59.96")) == "60.0")
        #expect(RiggingMath.band(beta: dec("45")) == .to45)
        #expect(RiggingMath.band(beta: dec("45.04")) == .to60)
        #expect(RiggingMath.band(beta: dec("60")) == .to60)
        #expect(RiggingMath.band(beta: dec("60.04")) == .blocked)
        #expect(RiggingMath.summaryDegrees("40.0") == "40")
        #expect(RiggingMath.summaryDegrees("40.1") == "40.1")
    }

    // MARK: - Slings

    @Test func measuredLengthHeightUsesTrueBeta() throws {
        // 4.00 m / 3.06 m is acos(3.06/4) ≈ 40.09°, shown as 40.1°. The course sheet at
        // exactly 40° is the angle-mode case. Band, M, required tag and assembly match either way.
        let geometry = RiggingMath.geometry(length: dec("4.00"), height: dec("3.06"))
        guard case .angle(let beta, let blocked) = geometry else {
            Issue.record("expected an angle")
            return
        }
        #expect(!blocked)
        #expect(RiggingMath.angleText(beta) == "40.1")
        #expect(abs(NSDecimalNumber(decimal: beta).doubleValue - 40.093) < 0.02)

        let model = sling(load: "6.0", tag: "5.0", length: "4.00", height: "3.06")
        let row = try #require(slingRow(model))
        #expect(row.hero == "Within marked WLL")
        #expect(row.within)
        #expect(row.bandLine == "0–45° · M = 1.4")
        #expect(row.requiredLine == "≥ 4.29 t")
        #expect(!row.requiredLine.contains("4.28"))
        #expect(row.assemblyLine == "7.00 t")
        #expect(row.tensionLine == "3.93 t")
        #expect(row.trigLine == "Exact trig (info only): factor 1.307 · 3.93 t/leg. Band decides pass/fail.")
        #expect(row.amber == nil)
        #expect(row.assumptions == RiggingCopy.assumptions)
        let echo = try #require(model.slingScreen.echo)
        #expect(echo.visible == "β = 40.1° from vertical · band 0–45°")
        #expect(echo.spoken.contains("from vertical"))
        #expect(row.heroSpoken.contains("from vertical"))
        #expect(row.heroSpoken.contains("W L L"))
        #expect(row.bandSpoken.contains("from vertical"))
        #expect(model.lastResultSummary == "Last sling 6.0 t · within · 40.1°")
    }

    @Test func exactFortyDegreesMatchesCourseSheet() throws {
        let model = sling(load: "6", tag: "5", angle: "40")
        let row = try #require(slingRow(model))
        #expect(row.hero == "Within marked WLL")
        #expect(row.requiredLine == "≥ 4.29 t")
        #expect(row.assemblyLine == "7.00 t")
        #expect(row.tensionLine == "3.92 t")
        #expect(row.trigLine.contains("factor 1.305"))
        #expect(row.trigLine.contains("3.92 t/leg"))
        #expect(row.trigLine.contains("info only"))
        #expect(row.trigLine.contains("Band decides pass/fail."))
        #expect(model.slingScreen.echo?.visible.contains("40.0° from vertical") == true)
        model.loadText = "6.0"
        #expect(model.lastResultSummary == "Last sling 6.0 t · within · 40°")
    }

    @Test func bandBeatsTrigWhenTagWouldPassTrigOnly() throws {
        let model = sling(load: "6", tag: "4", angle: "40")
        let row = try #require(slingRow(model))
        #expect(row.hero == "Exceeds")
        #expect(!row.within)
        #expect(row.assemblyLine == "5.60 t")
        #expect(row.tensionLine == "3.92 t")
        #expect(row.trigLine.contains("info only"))
        #expect(model.lastResultSummary == "Last sling 6 t · exceeds · 40°")
    }

    @Test func threeAndFourLegsUseTwoLegMath() throws {
        let four = sling(load: "6", tag: "5.3", legs: 4, angle: "30")
        let fourRow = try #require(slingRow(four))
        #expect(fourRow.assemblyLine == "7.42 t")
        #expect(fourRow.bandLine.contains("M = 1.4"))
        #expect(!fourRow.assemblyLine.contains("11.13"))
        #expect(four.legNote == "3- and 4-leg slings are calculated as 2-leg.")
        #expect(RiggingMath.modeFactor(legs: 4, hitch: .straight, beta: dec("30")) == dec("1.4"))

        let three = sling(load: "6", tag: "5", legs: 3, angle: "30")
        let two = sling(load: "6", tag: "5", legs: 2, angle: "30")
        let threeRow = try #require(slingRow(three))
        let twoRow = try #require(slingRow(two))
        #expect(threeRow.tensionLine == "3.47 t")
        #expect(threeRow.tensionLine == twoRow.tensionLine)
        #expect(threeRow.requiredLine == twoRow.requiredLine)
        #expect(three.legNote == RiggingCopy.legNote)
        #expect(two.legNote == nil)
        three.legs = 1
        #expect(three.legNote == nil)
    }

    @Test func verticalAndSixtyDegreeTensions() throws {
        let flat = sling(load: "2000", tag: "2000", angle: "0", unit: .kilograms)
        let flatRow = try #require(slingRow(flat))
        #expect(flatRow.tensionLine == "1000 kg")
        #expect(flatRow.trigLine.contains("factor 1.000"))
        #expect(flatRow.bandLine.hasPrefix("0–45°"))
        #expect(flatRow.amber == nil)

        let steep = sling(load: "2000", tag: "3000", angle: "60", unit: .kilograms)
        let steepRow = try #require(slingRow(steep))
        #expect(steepRow.tensionLine == "2000 kg")
        #expect(steepRow.trigLine.contains("factor 2.000"))
        #expect(steepRow.amber == RiggingCopy.highAngle)
        #expect(steepRow.bandLine.hasPrefix("45–60°"))
    }

    @Test func sixtyDegreesFromHalfHeightStillShowsNumbers() throws {
        let model = sling(load: "6", tag: "8", length: "4", height: "2")
        let row = try #require(slingRow(model))
        #expect(model.slingScreen.echo?.visible.contains("60.0° from vertical") == true)
        #expect(row.amber == RiggingCopy.highAngle)
        #expect(row.tensionLine == "6.00 t")
        if case .blocked = model.slingScreen.panel {
            Issue.record("60° is inclusive")
        }
    }

    @Test func lengthHeightRuleOfThumbIsNotSnapped() throws {
        let shallow = sling(load: "2", tag: "5", length: "10", height: "8.5")
        #expect(shallow.slingScreen.echo?.visible.contains("31.8°") == true)
        #expect(slingRow(shallow)?.amber == nil)

        let steep = sling(load: "2", tag: "5", length: "10", height: "7")
        let row = try #require(slingRow(steep))
        #expect(steep.slingScreen.echo?.visible.contains("45.6°") == true)
        #expect(row.amber == RiggingCopy.highAngle)
        #expect(row.trigLine.contains("factor 1.429"))
    }

    @Test func shortHeightAndZeroHeightAndOverHeight() {
        let over = sling(load: "6", tag: "5", length: "2", height: "3")
        #expect(over.slingScreen.errors.height == "Height can't be more than sling length")
        if case .invalid(let message) = over.slingScreen.panel {
            #expect(message == RiggingCopy.heightTooTall)
        } else {
            Issue.record("expected a field error")
        }
        #expect(over.slingScreen.echo == nil)

        let zero = sling(load: "6", tag: "5", length: "4", height: "0")
        #expect(zero.slingScreen.errors.height == RiggingCopy.heightPositive)
        if case .sling = zero.slingScreen.panel { Issue.record("H = 0 must not produce a result") }

        let equal = sling(load: "6", tag: "5", length: "4", height: "4")
        #expect(slingRow(equal)?.tensionLine == "3.00 t")
        #expect(equal.slingScreen.echo?.visible.contains("0.0° from vertical") == true)
    }

    @Test func aboveSixtyShowsNoNumbers() {
        let model = sling(load: "6", tag: "5", angle: "40")
        for angle in ["61", "60.1", "89", "90"] {
            model.angleText = angle
            guard case .blocked(let message) = model.slingScreen.panel else {
                Issue.record("expected blocked at \(angle)")
                continue
            }
            #expect(message == "Outside rated range. Competent person only.")
            #expect(!hasDigit(message))
            #expect(!hasDigit("Warning. \(message)"))
            #expect(model.slingScreen.echo == nil)
        }
        model.angleMode = .lengthHeight
        model.lengthText = "4"
        model.heightText = "1.96"
        guard case .blocked(let message) = model.slingScreen.panel else {
            Issue.record("H = 0.49 L is outside the range")
            return
        }
        #expect(!hasDigit(message))
        #expect(model.lastResultSummary == "Last sling · outside rated range")
        #expect(!hasDigit(model.lastResultSummary ?? "0"))
    }

    @Test func sixtyIsInclusiveAndSixtyPointZeroFourIsBlocked() throws {
        let onLimit = sling(load: "6", tag: "8", angle: "60")
        let row = try #require(slingRow(onLimit))
        #expect(row.amber != nil)
        #expect(onLimit.slingScreen.echo?.visible.contains("60.0°") == true)

        onLimit.angleText = "60.0"
        #expect(slingRow(onLimit) != nil)

        onLimit.angleText = "60.04"
        guard case .blocked(let message) = onLimit.slingScreen.panel else {
            Issue.record("60.04 is past the limit")
            return
        }
        #expect(onLimit.slingScreen.echo == nil)
        #expect(!message.contains("60"))
        #expect(!hasDigit(message))
    }

    @Test func amberStartsJustPastFortyFive() throws {
        let onBand = sling(load: "6", tag: "8", angle: "45")
        let onRow = try #require(slingRow(onBand))
        #expect(onRow.amber == nil)
        #expect(onRow.bandLine == "0–45° · M = 1.4")

        let justOver = sling(load: "6", tag: "8", angle: "45.1")
        let overRow = try #require(slingRow(justOver))
        #expect(overRow.amber == "High angle — check with lift plan / competent person.")
        #expect(overRow.bandLine == "45–60° · M = 1.0")
        #expect(overRow.heroSpoken.contains("from vertical"))
        #expect(overRow.heroSpoken.contains("high angle"))

        for angle in ["50", "59.9"] {
            let row = try #require(slingRow(sling(load: "6", tag: "8", angle: angle)))
            #expect(row.amber == RiggingCopy.highAngle)
        }
    }

    @Test func chokeAndBasketFactors() throws {
        let choked = sling(load: "1000", tag: "2000", legs: 1, hitch: .choke, angle: "0", unit: .kilograms)
        let row = try #require(slingRow(choked))
        #expect(row.requiredLine == "≥ 1250 kg")
        #expect(row.assemblyLine == "1600 kg")
        #expect(row.within)
        #expect(choked.chokeNote == "Choke angle ≥120°; edges protected")
        #expect(sling(load: "6", tag: "5", angle: "0").chokeNote == nil)

        #expect(RiggingMath.modeFactor(legs: 1, hitch: .basket, beta: 0) == dec("2"))
        #expect(RiggingMath.modeFactor(legs: 1, hitch: .basket, beta: dec("20")) == dec("1.4"))
        #expect(RiggingMath.modeFactor(legs: 2, hitch: .basket, beta: dec("50")) == dec("1"))
        #expect(RiggingMath.modeFactor(legs: 2, hitch: .choke, beta: dec("30")) == dec("1.12"))
        #expect(RiggingMath.modeFactor(legs: 2, hitch: .choke, beta: dec("50")) == dec("0.8"))
    }

    @Test func tonneAndKilogramHeroesAgree() throws {
        let tonnes = try #require(slingRow(sling(load: "2", tag: "5", angle: "40")))
        let kilograms = try #require(slingRow(sling(load: "2000", tag: "5000", angle: "40", unit: .kilograms)))
        #expect(tonnes.within)
        #expect(kilograms.within)
        #expect(tonnes.hero == kilograms.hero)

        let lowTonnes = try #require(slingRow(sling(load: "6", tag: "4", angle: "40")))
        let lowKg = try #require(slingRow(sling(load: "6000", tag: "4000", angle: "40", unit: .kilograms)))
        #expect(!lowTonnes.within)
        #expect(!lowKg.within)
        #expect(lowKg.requiredLine == "≥ 4286 kg")
    }

    @Test func badTextDoesNotProduceAResult() {
        let model = sling(load: "6", tag: "5", angle: "40")
        #expect(RiggingMath.parseDecimal("45°") == nil)
        #expect(RiggingMath.parseDecimal("6t") == nil)
        #expect(RiggingMath.parseDecimal("1e9") == nil)
        #expect(RiggingMath.parseDecimal("6,0") == Optional(Decimal(6)))
        #expect(RiggingMath.parseDecimal("6.0") == Optional(Decimal(6)))
        for junk in ["abc", "45°", "45 deg", "6t", "4.29t"] {
            model.angleText = junk
            guard case .invalid = model.slingScreen.panel else {
                Issue.record("expected invalid angle for \(junk)")
                continue
            }
            #expect(model.slingScreen.errors.angle == RiggingCopy.enterNumber)
            #expect(slingRow(model) == nil)
        }
        model.angleText = "-5"
        #expect(model.slingScreen.errors.angle == RiggingCopy.angleNegative)
        model.angleText = "40"
        model.loadText = "0"
        #expect(model.slingScreen.errors.load == RiggingCopy.loadPositive)
        model.loadText = "1e9"
        #expect(model.slingScreen.errors.load == RiggingCopy.enterNumber)
        model.loadText = "6,0"
        model.tagText = "5"
        #expect(slingRow(model)?.requiredLine == "≥ 4.29 t")

        model.loadText = ""
        model.tagText = ""
        model.angleText = ""
        model.angleMode = .lengthHeight
        if case .guidance(let text) = model.slingScreen.panel {
            #expect(text.contains("Enter load, length and height"))
            #expect(!hasDigit(text))
        } else {
            Issue.record("empty form")
        }
    }

    @Test func thousandsSeparatorsAreRejectedOnLoadAndWLL() {
        #expect(RiggingMath.parseDecimal("1,000") == nil)
        #expect(RiggingMath.parseDecimal("1.000") == nil)
        #expect(RiggingMath.parseDecimal("1.250") == nil)
        #expect(RiggingMath.parseDecimal("1,2,3") == nil)
        #expect(RiggingMath.parseDecimal("6.25") == Optional(dec("6.25")))
        #expect(RiggingMath.parseDecimal("45") == Optional(Decimal(45)))

        let load = sling(load: "1,000", tag: "5", angle: "40")
        #expect(load.slingScreen.errors.load == RiggingCopy.enterNumber)
        if case .invalid = load.slingScreen.panel {} else { Issue.record("load 1,000 should be invalid") }
        #expect(slingRow(load) == nil)

        let dotted = sling(load: "1.000", tag: "5", angle: "40")
        #expect(dotted.slingScreen.errors.load == RiggingCopy.enterNumber)

        let wll = single(load: "1", wll: "1.000", angle: "0")
        #expect(wll.chainScreen.errors.blockWLL == RiggingCopy.enterNumber)
        if case .invalid = wll.chainScreen.panel {} else { Issue.record("block WLL 1.000 should be invalid") }

        let tag = sling(load: "6", tag: "1,000", angle: "40")
        #expect(tag.slingScreen.errors.tag == RiggingCopy.enterNumber)
    }

    @Test func resultNumbersUseTheLocaleAfterRounding() {
        let required = RiggingMath.roundUp(dec("4.2857"), places: 2)
        let capacity = RiggingMath.roundDown(dec("5.333"), places: 2)
        let norway = Locale(identifier: "nb_NO")
        let english = Locale(identifier: "en_US")
        #expect(RiggingMath.formatLocalized(required, places: 2, locale: english) == "4.29")
        #expect(RiggingMath.formatLocalized(required, places: 2, locale: norway) == "4,29")
        #expect(RiggingMath.formatLocalized(capacity, places: 2, locale: english) == "5.33")
        #expect(RiggingMath.formatLocalized(capacity, places: 2, locale: norway) == "5,33")
        #expect(RiggingMath.massText(required, unit: .tonnes, locale: norway) == "4,29 t")
        #expect(RiggingMath.massText(required, unit: .tonnes, locale: english) == "4.29 t")
        #expect(RiggingMath.massText(Decimal(1000), unit: .kilograms, locale: english) == "1000 kg")
        #expect(RiggingMath.massText(Decimal(1000), unit: .kilograms, locale: norway) == "1000 kg")
    }

    @Test func selectedUnitPersists() {
        let name = "RiggingUnit.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        let model = SlingingRiggingModel(defaults: defaults)
        model.setSlingUnit(.kilograms)
        #expect(defaults.string(forKey: SlingingRiggingModel.unitStorageKey) == "kg")
        let restored = SlingingRiggingModel(defaults: defaults)
        restored.applyStoredUnit(defaults.string(forKey: SlingingRiggingModel.unitStorageKey) ?? "")
        #expect(restored.slingUnit == .kilograms)
        #expect(restored.chainUnit == .kilograms)
        restored.loadText = "1500"
        restored.setSlingUnit(.tonnes)
        #expect(restored.loadText == "1.5")
        #expect(defaults.string(forKey: SlingingRiggingModel.unitStorageKey) == "t")
    }

    @Test func unitSwitchConvertsMassesAndTabsKeepFields() {
        let model = sling(load: "6", tag: "5", length: "4", height: "3.06")
        model.setSlingUnit(.kilograms)
        model.loadText = "1500"
        model.setSlingUnit(.tonnes)
        #expect(model.loadText == "1.5")
        model.setSlingUnit(.kilograms)
        #expect(model.loadText == "1500")

        model.tab = .chain
        model.chainLoadText = "0.80"
        model.chainWLLText = "1"
        model.chainAngleText = "0"
        model.tab = .slings
        #expect(model.loadText == "1500")
        #expect(model.lengthText == "4")
        model.tab = .chain
        #expect(model.chainLoadText == "0.80")
        #expect(model.chainAngleText == "0")
    }

    // MARK: - Chain block

    @Test func singleVerticalHasNoAmber() throws {
        let model = single(load: "0.80", wll: "1.00", angle: "0")
        guard case .chainSingle(let row) = model.chainScreen.panel else {
            Issue.record("expected a single-block result")
            return
        }
        #expect(row.hero == "Within block WLL")
        #expect(row.within)
        #expect(row.amber == nil)
        #expect(row.noReduction == "No capacity reduction at 0°.")
        #expect(row.angleLine == "0.0° from vertical")
        #expect(row.angleSpoken.contains("from vertical"))
        #expect(row.heroSpoken == "Within block W L L. Load 0.80 tonnes on a 1.00 tonne block. Angle 0.0 degrees from vertical.")
        #expect(row.loadLine == "0.80 t")
        #expect(row.wllLine == "1.00 t")
        #expect(model.chainScreen.echo?.visible == "β = 0.0° from vertical · straight pull")
        #expect(model.lastResultSummary == "Last block 0.80 t · within")
        assertClean([row.hero, row.heroSpoken, row.angleLine, row.noReduction ?? ""])
    }

    @Test func singleOverloadAtVerticalHasNoAmber() {
        let model = single(load: "1.2", wll: "1", angle: "0")
        guard case .chainSingle(let row) = model.chainScreen.panel else {
            Issue.record("expected a result")
            return
        }
        #expect(row.hero == "Exceeds")
        #expect(!row.within)
        #expect(row.amber == nil)
        #expect(model.lastResultSummary == "Last block 1.2 t · exceeds")
        assertClean([row.hero, row.heroSpoken])
    }

    @Test func angledSingleShowsMakerLimitOnTheResult() {
        for angle in ["5", "30"] {
            let model = single(load: "0.80", wll: "1.00", angle: angle)
            guard case .chainSingle(let row) = model.chainScreen.panel else {
                Issue.record("expected single-block result at \(angle)")
                continue
            }
            #expect(row.within)
            #expect(row.hero == "Within block WLL")
            #expect(row.amber == RiggingCopy.chainAmber)
            #expect(row.noReduction == nil)
            #expect(row.angleLine.contains("from vertical"))
        }
    }

    @Test func twoBlockTransferRoundsUpAndAlwaysWarns() {
        let model = SlingingRiggingModel()
        model.tab = .chain
        model.chainMode = .twoBlock
        model.chainLoadText = "2.0"
        model.chainBeta1Text = "20"
        model.chainBeta2Text = "55"
        guard case .chainPair(let row) = model.chainScreen.panel else {
            Issue.record("expected tensions")
            return
        }
        #expect(row.tension1Line == "1.70 t")
        #expect(row.tension2Line == "0.71 t")
        #expect(row.amber == RiggingCopy.chainAmber)
        #expect(row.angle1Line.contains("from vertical"))
        #expect(row.angle2Line.contains("from vertical"))
        #expect(row.hero == nil)
        #expect(row.hint == RiggingCopy.compareHint)
        #expect(model.lastResultSummary == "Last block 2.0 t · two-block")

        model.chainWLL1Text = "2"
        model.chainWLL2Text = "1"
        guard case .chainPair(let compared) = model.chainScreen.panel else {
            Issue.record("expected a comparison")
            return
        }
        #expect(compared.hero == "Within block WLL")
        #expect(compared.within == true)
        #expect(compared.share1Line == "85%")
        #expect(compared.share2Line == "71%")
        #expect(compared.amber == RiggingCopy.chainAmber)

        model.chainWLL1Text = "1.6"
        guard case .chainPair(let over) = model.chainScreen.panel else { return }
        #expect(over.hero == "Exceeds")
        #expect(over.within == false)
    }

    @Test func twoBlockPastSixtyAndZeroSumHaveNoNumbers() {
        let model = SlingingRiggingModel()
        model.chainMode = .twoBlock
        model.chainLoadText = "0.5"
        model.chainBeta1Text = "65"
        model.chainBeta2Text = "65"
        guard case .blocked(let message) = model.chainScreen.panel else {
            Issue.record("65° is blocked")
            return
        }
        #expect(!hasDigit(message))

        model.chainBeta1Text = "0"
        model.chainBeta2Text = "0"
        guard case .invalid(let apart) = model.chainScreen.panel else {
            Issue.record("both vertical")
            return
        }
        #expect(apart == "Blocks must be apart.")
        #expect(!apart.lowercased().contains("nan"))
        #expect(!apart.lowercased().contains("inf"))

        model.chainBeta2Text = "30"
        guard case .chainPair(let row) = model.chainScreen.panel else {
            Issue.record("one vertical block is a real geometry")
            return
        }
        #expect(row.tension1Line == "0.50 t")
        #expect(row.tension2Line == "0.00 t")
        #expect(row.amber == RiggingCopy.chainAmber)
    }

    @Test func singlePastSixtyMatchesTheSlingBlock() {
        let model = single(load: "0.8", wll: "1", angle: "61")
        guard case .blocked(let message) = model.chainScreen.panel else {
            Issue.record("blocked")
            return
        }
        #expect(message == RiggingCopy.blocked)
        #expect(model.chainScreen.echo == nil)
        #expect(!hasDigit(message))
    }

    // MARK: - Copy

    @Test func footerAndStaticCopyStayInsideTheLockedWords() {
        #expect(RiggingCopy.footer == "Aid, not authority.")
        #expect(RiggingCopy.title == "Slinging & Rigging")
        #expect(!RiggingCopy.footer.contains("Design mock"))
        #expect(!RiggingCopy.staticStrings.joined(separator: "\n").contains("EXAMPLE"))
        #expect(!RiggingCopy.staticStrings.joined(separator: "\n").contains("Calculate"))
        #expect(RiggingCopy.angleCaption == "Measured from vertical. L includes hook/shackle.")
        #expect(RiggingCopy.legNote == "3- and 4-leg slings are calculated as 2-leg.")
        assertClean(RiggingCopy.staticStrings)
    }
}
