import Testing
import Foundation
@testable import MaritimeOperations

@MainActor
struct ActivityCodeTests {
    @Test func bookCodesAreFifteenInBookOrder() {
        let codes = ActivityCode.allCases.map(\.rawValue)
        #expect(codes.count == 15)
        #expect(codes == ["ACCOMM", "A", "D", "DRILL", "FL", "HL", "OL", "PL", "PSV", "ROV", "SB", "TR", "WK", "WS", "OT"])
    }

    @Test func myCodesHoldOnlyAnchorHandling() {
        #expect(MyActivityCode.allCases.map(\.rawValue) == ["AH"])
        #expect(MyActivityCode.ah.meaning == "Anchor handling")
    }

    @Test func otRequiresSpecify() {
        var selection = ActivityCodeSelection(code: "OT")
        #expect(selection.validationError != nil)
        selection.specify = "   "
        #expect(selection.validationError != nil)
        selection.specify = "\n\t "
        #expect(selection.validationError != nil)
        selection.specify = " Crew change "
        #expect(selection.validationError == nil)
        #expect(selection.storedValue == "OT – Crew change")
    }

    @Test func otherCodesNeedNoSpecify() {
        #expect(ActivityCodeSelection(code: "PSV").validationError == nil)
        #expect(ActivityCodeSelection(code: "AH").validationError == nil)
        #expect(ActivityCodeSelection().validationError == nil)
        #expect(ActivityCodeSelection().storedValue == nil)
    }

    @Test func ahIsStoredAsIsButExportsAsOT() {
        #expect(ActivityCodeSelection(code: "AH").storedValue == "AH")
        #expect(ActivityCodeExport.text(for: "AH") == "OT – Anchor handling")
        #expect(ActivityCodeExport.text(for: " AH ") == "OT – Anchor handling")
        #expect(ActivityCodeExport.text(for: "PSV") == "PSV")
        #expect(ActivityCodeExport.text(for: "OT – Crew change") == "OT – Crew change")
        #expect(ActivityCodeExport.text(for: nil) == "")
    }

    @Test func storedValuesRoundTrip() {
        #expect(ActivityCodeSelection(stored: "PSV").code == "PSV")
        #expect(ActivityCodeSelection(stored: "PSV").legacyValue == nil)
        #expect(ActivityCodeSelection(stored: "AH").code == "AH")
        let ot = ActivityCodeSelection(stored: "OT – Crew change")
        #expect(ot.isOT)
        #expect(ot.specify == "Crew change")
        #expect(ot.storedValue == "OT – Crew change")
        #expect(ActivityCodeSelection(stored: nil).code == "")
    }

    @Test func oldFreeTextIsKeptNotWiped() {
        let old = ActivityCodeSelection(stored: "Pipe lay stby")
        #expect(old.code == ActivityCodeSelection.legacyTag)
        #expect(old.legacyValue == "Pipe lay stby")
        #expect(old.storedValue == "Pipe lay stby")
        #expect(old.validationError == nil)

        let bareOT = ActivityCodeSelection(stored: "OT")
        #expect(bareOT.legacyValue == "OT")
        #expect(!bareOT.isOT)
        #expect(bareOT.storedValue == "OT")
        #expect(bareOT.validationError == nil)
    }
}

@MainActor
struct ShipNameSuggestionsTests {
    private func use(_ name: String, _ minutesAgo: Double) -> ShipNameSuggestions.Use {
        ShipNameSuggestions.Use(name: name, usedAt: Date(timeIntervalSince1970: 1_000_000 - minutesAgo * 60))
    }

    @Test func dedupsTrimmedCaseInsensitiveNewestFirst() {
        let names = ShipNameSuggestions.names(from: [
            use("Skandi Africa", 300),
            use("normand maximus", 200),
            use("  SKANDI AFRICA ", 100),
            use("Far Sun", 50),
            use("Normand Maximus", 400),
        ])
        #expect(names == ["Far Sun", "SKANDI AFRICA", "normand maximus"])
    }

    @Test func skipsBlankAndPlaceholder() {
        let names = ShipNameSuggestions.names(from: [use("", 1), use("   ", 2), use("Vessel", 3), use("vessel ", 4), use("Island Victory", 5)])
        #expect(names == ["Island Victory"])
    }

    @Test func keyNormalizes() {
        #expect(ShipNameSuggestions.key("  Far Sun ") == ShipNameSuggestions.key("FAR SUN"))
    }

    @Test func searchFiltersCaseInsensitive() {
        let all = ["Far Sun", "Skandi Africa", "Far Searcher"]
        #expect(ShipNameSuggestions.filter(all, query: "far") == ["Far Sun", "Far Searcher"])
        #expect(ShipNameSuggestions.filter(all, query: "  ") == all)
    }
}
