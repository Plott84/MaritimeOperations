import Testing
import Foundation
import SwiftData
@testable import MaritimeOperations

/// Lift weight (preset list + Other…) and wire out: optional Crane fields only.
@MainActor
struct CraneLiftWeightTests {
    private let t0 = Date(timeIntervalSince1970: 1_780_000_000)
    private let en = Locale(identifier: "en_US")
    private let de = Locale(identifier: "de_DE")

    // MARK: Presets and Other…

    @Test func presetsAreTheLockedList() {
        #expect(CraneLiftWeight.presets == [2, 5, 10, 15, 20, 25, 50])
        #expect(CraneLiftWeight.weightCaption == "Optional. Nominal from the list \u{2014} your estimate, not the lift plan.")
        #expect(CraneLiftWeight.wireCaption == "Optional. How far the crane wire was paid out.")
        for preset in CraneLiftWeight.presets {
            #expect(CraneLiftWeight.isPreset(preset))
        }
        #expect(!CraneLiftWeight.isPreset(12.5))
        #expect(CraneLiftWeight.presetTag(10) == "10")
    }

    @Test func otherParsesOneDecimalAndBlankStaysEmpty() {
        #expect(CraneLiftWeight.parse("") == .empty)
        #expect(CraneLiftWeight.parse("  ") == .empty)
        #expect(CraneLiftWeight.parse("12.5") == .value(12.5))
        #expect(CraneLiftWeight.parse("12,5") == .value(12.5))
        #expect(CraneLiftWeight.parse("12.50") == .value(12.5))
        #expect(CraneLiftWeight.parse("10") == .value(10))
        #expect(CraneLiftWeight.parse("12.55") == .tooManyDecimals)
        #expect(CraneLiftWeight.parse("12,55") == .tooManyDecimals)
        #expect(CraneLiftWeight.parse("abc") == .notANumber)
        #expect(CraneLiftWeight.parse("-3") == .notANumber)
        #expect(CraneLiftWeight.parse("1e2") == .notANumber)
        #expect(CraneLiftWeight.problem(for: .notANumber) == "Lift weight must be a number.")
        #expect(CraneLiftWeight.problem(for: .tooManyDecimals) == "Lift weight uses one decimal place.")
        #expect(CraneLiftWeight.problem(for: .empty) == nil)
        #expect(CraneLiftWeight.problem(for: .value(12.5)) == nil)
    }

    @Test func otherReopensAsTypedTextAndPresetReopensOnTheList() {
        let other = CraneLiftWeight.editing(storedTonnes: 12.5, locale: en)
        #expect(other.isOther)
        #expect(other.preset == nil)
        #expect(other.otherText == "12.5")

        let preset = CraneLiftWeight.editing(storedTonnes: 10, locale: en)
        #expect(!preset.isOther)
        #expect(preset.preset == 10)
        #expect(preset.otherText == "")

        let blank = CraneLiftWeight.editing(storedTonnes: nil, locale: en)
        #expect(!blank.isOther)
        #expect(blank.preset == nil)
        #expect(blank.otherText == "")

        var input = CraneNumberInput(
            hoursOperated: "",
            wind: "",
            waveHeight: "",
            liftWeightOther: other.otherText,
            liftWeightIsOther: other.isOther,
            liftWeightPreset: other.preset
        )
        #expect(input.firstProblem == nil)
        #expect(input.liftWeightValue == 12.5)

        input.liftWeightOther = ""
        #expect(input.liftWeightValue == nil, "Blank Other omits the weight")
        #expect(input.firstProblem == nil)

        input.liftWeightOther = "12.55"
        #expect(input.firstProblem == "Lift weight uses one decimal place.")
        #expect(input.liftWeightValue == nil)

        input.liftWeightOther = "nope"
        #expect(input.firstProblem == "Lift weight must be a number.")

        input = CraneNumberInput(
            hoursOperated: "",
            wind: "",
            waveHeight: "",
            liftWeightOther: "12.5",
            liftWeightIsOther: true,
            liftWeightPreset: 10
        )
        #expect(input.liftWeightValue == 12.5, "Other wins over a leftover preset")
    }

    @Test func wireOutAcceptsLocaleDecimalAndBlankIsNil() {
        var input = CraneNumberInput(hoursOperated: "4.5", wind: "", waveHeight: "", wireOut: "")
        #expect(input.firstProblem == nil)
        #expect(input.wireOutValue == nil)
        #expect(input.liftWeightValue == nil)

        input.wireOut = "85,5"
        #expect(input.firstProblem == nil)
        #expect(input.wireOutValue == 85.5)

        input.wireOut = "  "
        #expect(input.wireOutValue == nil)

        input.wireOut = "far"
        #expect(input.firstProblem == "Wire out must be a number.")
        #expect(input.wireOutValue == nil)
    }

    // MARK: List copy

    @Test func rowLineShowsWeightAndWireAndOmitsWhenEmpty() {
        #expect(CraneLiftWeight.rowLine(weightTonnes: 10, wireMetres: 85, locale: en) == "10 t \u{00B7} 85 m out")
        #expect(CraneLiftWeight.rowLine(weightTonnes: 12.5, wireMetres: nil, locale: en) == "12.5 t")
        #expect(CraneLiftWeight.rowLine(weightTonnes: nil, wireMetres: 85, locale: en) == "85 m out")
        #expect(CraneLiftWeight.rowLine(weightTonnes: nil, wireMetres: nil, locale: en) == nil)
        #expect(CraneLiftWeight.rowLine(weightTonnes: 12.5, wireMetres: 85, locale: de) == "12,5 t \u{00B7} 85 m out")

        #expect(CraneLiftWeight.spokenSummary(weightTonnes: 10, wireMetres: 85, locale: en) == "10 tonnes, 85 metres out")
        #expect(CraneLiftWeight.spokenSummary(weightTonnes: 1, wireMetres: nil, locale: en) == "1 tonne")
        #expect(CraneLiftWeight.spokenSummary(weightTonnes: nil, wireMetres: 1, locale: en) == "1 metre out")
        #expect(CraneLiftWeight.spokenTonnes(10, locale: en) == "10 tonnes")
        #expect(CraneLiftWeight.spokenMetres(85, locale: en) == "85 metres")
        #expect(CraneLiftWeight.formSpoken(preset: 10, isOther: false, otherText: "", locale: en) == "10 tonnes")
        #expect(CraneLiftWeight.formSpoken(preset: nil, isOther: false, otherText: "", locale: en) == "Not set")
        #expect(CraneLiftWeight.formLabel(preset: 10, isOther: false, otherText: "", locale: en) == "10 t")
        #expect(CraneLiftWeight.spokenWireField("85", locale: en) == "85 metres")
        #expect(CraneLiftWeight.spokenWireField("", locale: en) == "Not set")
        #expect(CraneLiftWeight.spokenWeightField("12.5", locale: en) == "12.5 tonnes")
    }

    // MARK: Persist

    @Test func weightAndWirePersistAndEmptyStaysNil() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let filled = CraneEntry(date: t0, vessel: "Vessel B")
        filled.hoursOperated = 4.5
        filled.liftWeightTonnes = 12.5
        filled.wireOutMetres = 85
        let empty = CraneEntry(date: t0.addingTimeInterval(60))
        context.insert(filled)
        context.insert(empty)
        try context.save()

        let fetched = try ModelContext(container).fetch(FetchDescriptor<CraneEntry>(sortBy: [SortDescriptor(\.date)]))
        #expect(fetched.count == 2)
        #expect(fetched[0].liftWeightTonnes == 12.5)
        #expect(fetched[0].wireOutMetres == 85)
        #expect(fetched[0].hoursOperated == 4.5)
        #expect(fetched[1].liftWeightTonnes == nil)
        #expect(fetched[1].wireOutMetres == nil)
        #expect(fetched[1].hoursOperated == nil)
        #expect(CraneLiftWeight.rowLine(weightTonnes: fetched[1].liftWeightTonnes, wireMetres: fetched[1].wireOutMetres) == nil)
    }

    // MARK: Export / import

    @Test func exportIncludesValuesAndEmptyWritesNoZeroAndSkipsDPTotals() throws {
        let dp = DPEntry(source: .manual, date: t0, durationHours: 10, vessel: "DP Ship")
        let empty = CraneEntry(date: t0, vessel: "Crane")
        empty.hoursOperated = 4
        let filled = CraneEntry(date: t0.addingTimeInterval(60), vessel: "Crane")
        filled.hoursOperated = 1
        filled.liftWeightTonnes = 10
        filled.wireOutMetres = 85

        let filter = ExportDateFilter(quickRange: .allTime, from: nil, to: nil)
        let snap = ExportAggregator.snapshot(
            dp: [dp], moves: [], rov: [], crane: [empty, filled], filter: filter
        )
        #expect(snap.dpHours == 10)
        #expect(snap.craneHours == 5)
        #expect(snap.dpHours != snap.dpHours + (filled.liftWeightTonnes ?? 0) + (filled.wireOutMetres ?? 0))

        let csv = try ImportExchange.encodeCSV(
            books: ExportBookSelection(),
            filter: filter,
            dp: [dp],
            moves: [],
            rov: [],
            crane: [empty, filled]
        )
        #expect(csv.contains("\"DP\",1,10.0,\"DP book only; ROV/Crane excluded\""))
        #expect(csv.contains("\"Crane\",2,5.0,\"hours operated\""))

        let emptyLine = try #require(csv.split(separator: "\n").first { $0.contains(empty.id.uuidString) })
        let filledLine = try #require(csv.split(separator: "\n").first { $0.contains(filled.id.uuidString) })
        #expect(!emptyLine.contains("liftWeightTonnes"))
        #expect(!emptyLine.contains("wireOutMetres"))
        #expect(filledLine.contains("liftWeightTonnes"))
        #expect(filledLine.contains("wireOutMetres"))

        let payload = try ImportExchange.parse(data: Data(csv.utf8), filename: "crane.csv")
        let importedEmpty = try #require(payload.crane.first { $0.id == empty.id })
        let importedFilled = try #require(payload.crane.first { $0.id == filled.id })
        #expect(importedEmpty.liftWeightTonnes == nil)
        #expect(importedEmpty.wireOutMetres == nil)
        #expect(importedEmpty.makeModel().liftWeightTonnes == nil)
        #expect(importedEmpty.makeModel().wireOutMetres == nil)
        #expect(importedFilled.liftWeightTonnes == 10)
        #expect(importedFilled.wireOutMetres == 85)
        #expect(importedFilled.makeModel().wireOutMetres == 85)
        #expect(payload.exportSnapshot().dpHours == 10)
        #expect(payload.exportSnapshot().craneHours == 5)

        let drawn = Data("%PDF-1.4\n%%EOF".utf8)
        let pdf = ImportExchange.embedCSV(csv, in: drawn)
        let fromPDF = try ImportExchange.parse(data: pdf, filename: "MaritimeOperations-Export.pdf")
        #expect(fromPDF.crane.first { $0.id == filled.id }?.liftWeightTonnes == 10)
        #expect(fromPDF.crane.first { $0.id == filled.id }?.wireOutMetres == 85)
        #expect(fromPDF.crane.first { $0.id == empty.id }?.liftWeightTonnes == nil)
        #expect(fromPDF.exportSnapshot().dpHours == 10)
        #expect(fromPDF.exportSnapshot().craneHours == 5)
    }

    @Test func missingOrNullWeightKeysImportAsNil() throws {
        let entry = CraneEntry(date: t0)
        entry.liftWeightTonnes = 10
        entry.wireOutMetres = 85
        let object = try jsonObject(CraneRecord(entry))
        #expect(number(object, "liftWeightTonnes") == 10)
        #expect(number(object, "wireOutMetres") == 85)

        var stripped = object
        stripped.removeValue(forKey: "liftWeightTonnes")
        stripped.removeValue(forKey: "wireOutMetres")
        let fromOldFile = try decode(stripped)
        #expect(fromOldFile.liftWeightTonnes == nil)
        #expect(fromOldFile.wireOutMetres == nil)

        var nulled = object
        nulled["liftWeightTonnes"] = NSNull()
        nulled["wireOutMetres"] = NSNull()
        let fromNull = try decode(nulled)
        #expect(fromNull.liftWeightTonnes == nil)
        #expect(fromNull.wireOutMetres == nil)

        let fresh = try jsonObject(CraneRecord(CraneEntry(date: t0)))
        #expect(fresh.index(forKey: "liftWeightTonnes") == nil)
        #expect(fresh.index(forKey: "wireOutMetres") == nil)
        #expect(number(fresh, "liftWeightTonnes") == nil)
        #expect(number(fresh, "wireOutMetres") == nil)
    }

    // MARK: Helpers

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(LaunchEnvironment.models)
        return try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
    }

    private func jsonObject(_ record: CraneRecord) throws -> [String: Any] {
        let json = try ImportJSON.string(record)
        let data = try #require(json.data(using: .utf8))
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func decode(_ object: [String: Any]) throws -> CraneRecord {
        let data = try JSONSerialization.data(withJSONObject: object)
        let json = try #require(String(data: data, encoding: .utf8))
        return try ImportJSON.value(json, as: CraneRecord.self)
    }

    private func number(_ object: [String: Any], _ key: String) -> Double? {
        guard let value = object[key], !(value is NSNull) else { return nil }
        if let number = value as? NSNumber { return number.doubleValue }
        return nil
    }
}
