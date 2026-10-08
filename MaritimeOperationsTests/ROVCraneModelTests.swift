import Testing
import Foundation
import SwiftData
@testable import MaritimeOperations

/// ROV and Crane books: model defaults, multi-select storage, number validation,
/// vessel prefill across all four books, the model container and the Log totals.
@MainActor
struct ROVCraneModelTests {
    private let t0 = Date(timeIntervalSince1970: 1_780_000_000)

    // MARK: Defaults

    @Test func newROVEntryStartsEmptyExceptStart() {
        let entry = ROVEntry(date: t0)
        #expect(entry.date == t0)
        #expect(entry.endTime == nil)
        #expect(entry.vessel == nil)
        #expect(entry.gradeRaw == nil)
        #expect(entry.grade == nil)
        #expect(entry.gradeOther == nil)
        #expect(entry.supportSiteRaw == nil)
        #expect(entry.supportSite == nil)
        #expect(entry.supportSiteOther == nil)
        #expect(entry.underTraining == nil)
        #expect(entry.rovSystem == nil)
        #expect(entry.rovClassRaw == nil)
        #expect(entry.rovClass == nil)
        #expect(entry.fieldArea == nil)
        #expect(entry.jobTypeRaw == nil)
        #expect(entry.jobType == nil)
        #expect(entry.tasksRaw == nil)
        #expect(entry.tasks.isEmpty)
        #expect(entry.pilotingHours == nil)
        #expect(entry.dives == nil)
        #expect(entry.remarks == nil)
        #expect(entry.durationHours == nil)
        #expect(entry.rowTitle == "ROV entry")
        #expect(entry.vesselSystemLine == "")
    }

    @Test func newCraneEntryStartsEmptyExceptStart() {
        let entry = CraneEntry(date: t0)
        #expect(entry.date == t0)
        #expect(entry.endTime == nil)
        #expect(entry.vessel == nil)
        #expect(entry.rank == nil)
        #expect(entry.underTraining == nil)
        #expect(entry.craneName == nil)
        #expect(entry.craneType == nil)
        #expect(entry.craneTypeOther == nil)
        #expect(entry.fieldArea == nil)
        #expect(entry.hoursOperated == nil)
        #expect(entry.liftTypesRaw == nil)
        #expect(entry.liftTypes.isEmpty)
        #expect(entry.dayNight == nil)
        #expect(entry.windMS == nil)
        #expect(entry.waveHeightM == nil)
        #expect(entry.craneMode == nil)
        #expect(entry.remarks == nil)
        #expect(entry.rowTitle == "Crane entry")
    }

    @Test func unknownStoredValuesFallBackToNotSet() {
        let rov = ROVEntry(date: t0)
        rov.rovClassRaw = "VI"
        rov.jobTypeRaw = "drillingSupport"
        rov.tasksRaw = "piloting|bogus||tms"
        rov.gradeRaw = "trainee"
        rov.supportSiteRaw = "barge"
        #expect(rov.rovClass == nil)
        #expect(rov.jobType == nil)
        #expect(rov.tasks == [.piloting, .tms])
        #expect(rov.grade == nil)
        #expect(rov.supportSite == nil)

        let crane = CraneEntry(date: t0)
        crane.craneTypeRaw = "?"
        crane.dayNightRaw = "dusk"
        crane.craneModeRaw = "?"
        crane.liftTypesRaw = "heavy|deck"
        #expect(crane.craneType == nil)
        #expect(crane.dayNight == nil)
        #expect(crane.craneMode == nil)
        #expect(crane.liftTypes == [.deck])
    }

    @Test func storedRawValuesAreStable() {
        #expect(ROVClass.allCases.map(\.rawValue) == ["I", "II", "III", "IV", "V"])
        #expect(ROVJobType.allCases.map(\.rawValue) == [
            "observation", "survey", "inspection", "construction", "intervention", "burialTrenching"
        ])
        #expect(ROVJobType.allCases.map(\.label) == [
            "Observation", "Survey", "Inspection", "Construction", "Intervention", "Burial & trenching"
        ])
        #expect(CraneLiftType.allCases.map(\.rawValue) == [
            "deck", "supplyVessel", "overside", "subsea", "blind", "tandem", "personnel"
        ])
        #expect(CraneMode.allCases.map(\.label) == ["Normal", "AHC", "Constant tension"])
        #expect(CraneMode.ahc.spokenLabel == "Active heave compensation")
        #expect(CraneDayNight.allCases.map(\.label) == ["Day", "Night", "Both"])
        #expect(ROVClass.three.caption == "Class III · Work-class")
    }

    @Test func craneTypeListEndsWithOther() {
        #expect(CraneType.allCases.last == .other)
        #expect(CraneType.allCases.map(\.label) == [
            "Offshore crane", "Subsea / AHC crane", "Light offshore crane", "Deck crane", "Floating crane", "Other"
        ])
        #expect(CraneType.allCases.filter(\.isOther) == [.other])
    }

    // MARK: Position pickers

    @Test func craneOperatorIsAppendedAndExistingRankRawValuesAreUnchanged() {
        #expect(CrewRank.allCases.map(\.rawValue) == [
            "Eng.", "Ch. Eng.", "Elec.", "DPO", "Ch. Off.", "2nd Off.", "Master",
            "2nd Eng.", "3rd Eng.", "AB",
            "Crane operator"
        ])
        #expect(CrewRank.allCases.last == .craneOperator)
        #expect(CrewRank(rawValue: "ROV pilot") == nil, "No ROV pilot rank: ROV uses IMCA grades")
        #expect(CrewRank(rawValue: "Captain") == nil, "Master already exists")
    }

    @Test func cranePickerIsCraneOperatorThenAHOrder() {
        #expect(BookPositions.crane.map(\.rawValue) == [
            "Crane operator",
            "Master", "Ch. Off.", "2nd Off.", "DPO",
            "Ch. Eng.", "2nd Eng.", "3rd Eng.", "Eng.", "Elec.",
            "AB"
        ])
        #expect(Array(BookPositions.crane.dropFirst()) == CrewRank.ahPositionCases)
    }

    @Test func craneOperatorStaysOutOfDPAndAHPickers() {
        #expect(CrewRank.dpPickerCases.map(\.rawValue) == [
            "Eng.", "Ch. Eng.", "Elec.", "DPO", "Ch. Off.", "2nd Off.", "Master"
        ])
        #expect(!CrewRank.dpPickerCases.contains(.craneOperator))
        #expect(!CrewRank.ahPositionCases.contains(.craneOperator))
    }

    @Test func rovPositionIsIMCAGradesInOrderWithOtherLastAndNoTrainee() {
        #expect(BookPositions.rov == ROVGrade.allCases)
        #expect(ROVGrade.allCases.map(\.pickerLabel) == [
            "ROV Pilot/Technician Grade II",
            "ROV Pilot/Technician Grade I",
            "ROV Senior Pilot/Technician",
            "ROV Supervisor",
            "ROV Superintendent",
            "ROV Tooling Technician",
            "ROV Tooling Supervisor",
            "Other"
        ])
        #expect(ROVGrade.allCases.map(\.rawValue) == [
            "pilotTechnicianGradeII", "pilotTechnicianGradeI", "seniorPilotTechnician",
            "supervisor", "superintendent", "toolingTechnician", "toolingSupervisor", "other"
        ])
        #expect(ROVGrade.allCases.filter(\.isOther) == [.other])
        #expect(!ROVGrade.allCases.contains { $0.pickerLabel.localizedCaseInsensitiveContains("trainee") })
    }

    @Test func gradeStoresAsOptionalRawValueWithOtherText() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let entry = ROVEntry(date: t0)
        entry.grade = .other
        entry.gradeOther = "Survey pilot"
        context.insert(entry)
        try context.save()
        let fetched = try #require(try ModelContext(container).fetch(FetchDescriptor<ROVEntry>()).first)
        #expect(fetched.gradeRaw == "other")
        #expect(fetched.grade == .other)
        #expect(fetched.gradeLabel == "Survey pilot")
        fetched.grade = nil
        #expect(fetched.gradeRaw == nil)
    }

    // MARK: Support site and "Other"

    @Test func supportSiteIsOptionalWithFixedChoices() {
        #expect(ROVSupportSite.allCases.map(\.label) == [
            "Vessel on DP", "Vessel moored / anchored", "Mobile offshore unit", "Fixed installation", "Other"
        ])
        let entry = ROVEntry(date: t0)
        #expect(entry.supportSite == nil, "Starts Not set")
        #expect(entry.supportSiteLabel == nil)
        // Not set never blocks Save.
        #expect(LogOtherText.firstMissing([(label: "Support site", choice: entry.supportSite, text: "")]) == nil)
        entry.supportSite = .vesselOnDP
        #expect(entry.supportSiteRaw == "vesselOnDP")
        #expect(entry.supportSiteLabel == "Vessel on DP")
    }

    @Test func otherBlocksSaveOnlyWhileItsTextIsBlank() {
        // Not set and normal picks never block.
        #expect(!LogOtherText.isMissing(nil as ROVSupportSite?, text: ""))
        #expect(!LogOtherText.isMissing(ROVSupportSite.fixedInstallation, text: ""))
        #expect(!LogOtherText.isMissing(ROVGrade.supervisor, text: ""))
        #expect(!LogOtherText.isMissing(CraneType.offshore, text: ""))
        // Other + blank blocks; Other + text doesn't.
        for choice in [ROVSupportSite.other as any LogOtherChoice, ROVGrade.other, CraneType.other] {
            #expect(LogOtherText.isMissing(choice, text: ""))
            #expect(LogOtherText.isMissing(choice, text: "   "))
            #expect(!LogOtherText.isMissing(choice, text: "Barge"))
        }
        // The form reports the first field that's missing its text.
        let grade: ROVGrade? = .other
        let site: ROVSupportSite? = .other
        #expect(LogOtherText.firstMissing([
            (label: "Position", choice: grade, text: "x"),
            (label: "Support site", choice: site, text: ""),
        ]) == "Support site")
        #expect(LogOtherText.message(for: "Crane type") == "Crane type is Other: type what it is.")
        // Text is stored trimmed for Other only; switching away clears it.
        #expect(LogOtherText.stored(CraneType.other, text: " Gantry ") == "Gantry")
        #expect(LogOtherText.stored(CraneType.deck, text: "Gantry") == nil)
        #expect(LogOtherText.stored(nil as CraneType?, text: "Gantry") == nil)

        let crane = CraneEntry(date: t0)
        crane.craneType = .other
        crane.craneTypeOther = "Gantry"
        #expect(crane.craneTypeLabel == "Gantry")
    }

    // MARK: DP hours stay DP-only

    @Test func rovAndCraneHoursNeverCountTowardDP() {
        let line = DPEntry(source: .manual, date: t0, durationHours: 10, vessel: "S")
        let rov = ROVEntry(date: t0); rov.pilotingHours = 6
        let crane = CraneEntry(date: t0); crane.hoursOperated = 8
        let dpOnly = LogBookStats(entries: [line], moves: [], oldDPHoursText: "")
        let all = LogBookStats(entries: [line], moves: [], rovEntries: [rov], craneEntries: [crane], oldDPHoursText: "")
        #expect(all.dpHours == 10)
        #expect(all.dpEntries == 1)
        #expect(all.hours(for: .dp) == dpOnly.hours(for: .dp))
        #expect(all.logSpokenValue(for: .dp) == dpOnly.logSpokenValue(for: .dp))
        #expect(all.mainSpokenValue(for: .dp) == dpOnly.mainSpokenValue(for: .dp))
        #expect(all.mainCountText(for: .dp) == dpOnly.mainCountText(for: .dp))
    }

    @Test func dpExportScopeIsDPLinesOnly() {
        #expect(DPHoursScope.books == [.dp])
        #expect(DPHoursScope.counts(.dp))
        for book in [LogBook.anchorHandling, .rov, .crane] {
            #expect(!DPHoursScope.counts(book), "\(book) must never feed DP hours or the DP export")
        }
    }

    // MARK: Multi-select storage

    @Test func liftTypesStoreInFixedOrderAndEmptyIsNil() {
        let entry = CraneEntry(date: t0)
        entry.liftTypes = [.personnel, .deck, .supplyVessel]
        #expect(entry.liftTypesRaw == "deck|supplyVessel|personnel")
        #expect(entry.liftTypes == [.deck, .supplyVessel, .personnel])
        #expect(entry.rowTitle == "Deck, Supply vessel, Personnel")
        entry.liftTypes = []
        #expect(entry.liftTypesRaw == nil)
        entry.liftTypes = Set(CraneLiftType.allCases)
        #expect(entry.liftTypesRaw == CraneLiftType.allCases.map(\.rawValue).joined(separator: "|"))
    }

    @Test func rovTasksUseTheSameStorage() {
        let entry = ROVEntry(date: t0)
        entry.tasks = [.inspection, .launchRecovery]
        #expect(entry.tasksRaw == "launchRecovery|inspection")
        #expect(LogChoiceSet.decode(entry.tasksRaw, as: ROVTask.self) == [.launchRecovery, .inspection])
        #expect(LogChoiceSet.decode(nil, as: ROVTask.self).isEmpty)
        #expect(LogChoiceSet.decode("", as: ROVTask.self).isEmpty)
    }

    @Test func liftTypesSurviveASaveAndRefetch() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let entry = CraneEntry(date: t0, vessel: "Vessel B")
        entry.liftTypes = [.overside, .blind]
        context.insert(entry)
        try context.save()

        let fetched = try ModelContext(container).fetch(FetchDescriptor<CraneEntry>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.liftTypes == [.overside, .blind])
        #expect(fetched.first?.liftTypesRaw == "overside|blind")
        #expect(fetched.first?.hoursOperated == nil)
    }

    // MARK: Numbers

    @Test func rovNumbersEmptyIsNotSetAndJunkIsFlagged() {
        var input = ROVNumberInput(pilotingHours: "", dives: "")
        #expect(input.firstProblem == nil)
        #expect(input.pilotingHoursValue == nil)
        #expect(input.divesValue == nil)

        input = ROVNumberInput(pilotingHours: " 3,5 ", dives: "2")
        #expect(input.firstProblem == nil)
        #expect(input.pilotingHoursValue == 3.5)
        #expect(input.divesValue == 2)

        #expect(ROVNumberInput(pilotingHours: "abc", dives: "").firstProblem == "Piloting hours must be a number from 0 to 24.")
        #expect(ROVNumberInput(pilotingHours: "-1", dives: "").firstProblem != nil)
        #expect(ROVNumberInput(pilotingHours: "24.5", dives: "").firstProblem != nil)
        #expect(ROVNumberInput(pilotingHours: "24", dives: "").firstProblem == nil)
        #expect(ROVNumberInput(pilotingHours: "", dives: "1.5").firstProblem == "Dives must be a whole number.")
        #expect(ROVNumberInput(pilotingHours: "", dives: "-2").firstProblem != nil)
    }

    @Test func craneNumbersEmptyIsNotSetAndJunkIsFlagged() {
        var input = CraneNumberInput(hoursOperated: "", wind: "", waveHeight: "")
        #expect(input.firstProblem == nil)
        #expect(input.hoursOperatedValue == nil)
        #expect(input.windValue == nil)
        #expect(input.waveHeightValue == nil)

        input = CraneNumberInput(hoursOperated: "4.5", wind: "9", waveHeight: "1,8")
        #expect(input.firstProblem == nil)
        #expect(input.hoursOperatedValue == 4.5)
        #expect(input.windValue == 9)
        #expect(input.waveHeightValue == 1.8)

        #expect(CraneNumberInput(hoursOperated: "25", wind: "", waveHeight: "").firstProblem == "Hours operated must be a number from 0 to 24.")
        #expect(CraneNumberInput(hoursOperated: "", wind: "strong", waveHeight: "").firstProblem == "Wind must be a number.")
        #expect(CraneNumberInput(hoursOperated: "", wind: "", waveHeight: "?").firstProblem == "Wave height must be a number.")
        #expect(LogNumber.text(3.5) == "3.5")
        #expect(LogNumber.text(12.0) == "12")
        #expect(LogNumber.text(nil as Double?) == "")
        #expect(LogNumber.text(2 as Int?) == "2")
    }

    @Test func onlyEndBeforeStartBlocksSave() {
        #expect(LogEntryCheck.block(start: t0, end: t0) == nil)
        #expect(LogEntryCheck.block(start: t0, end: t0.addingTimeInterval(3600)) == nil)
        #expect(LogEntryCheck.block(start: t0, end: t0.addingTimeInterval(-60)) == "End is before start.")
        #expect(LogEntryCheck.optionalText("  ") == nil)
        #expect(LogEntryCheck.optionalText(" Field C ") == "Field C")
        #expect(LogEntryCheck.underTraining(isOn: false, previous: nil) == nil)
        #expect(LogEntryCheck.underTraining(isOn: false, previous: true) == false)
        #expect(LogEntryCheck.underTraining(isOn: true, previous: nil) == true)
    }

    // MARK: Vessel prefill (all four books)

    @Test func vesselPrefillTakesTheNewestOfFourBooks() {
        let dp = BookVesselPrefill.Candidate(vessel: "DP Ship", date: t0, createdAt: t0)
        let ah = BookVesselPrefill.Candidate(vessel: "AH Ship", date: t0.addingTimeInterval(3600), createdAt: t0)
        let rov = BookVesselPrefill.Candidate(vessel: "ROV Ship", date: t0.addingTimeInterval(7200), createdAt: t0)
        let crane = BookVesselPrefill.Candidate(vessel: " Crane Ship ", date: t0.addingTimeInterval(10_800), createdAt: t0)
        #expect(BookVesselPrefill.vessel(from: [dp, ah, rov, crane]) == "Crane Ship")
        #expect(BookVesselPrefill.vessel(from: [dp, ah, rov]) == "ROV Ship")
        let blankNewest = BookVesselPrefill.Candidate(vessel: "", date: t0.addingTimeInterval(99_999), createdAt: t0)
        #expect(BookVesselPrefill.vessel(from: [dp, rov, blankNewest]) == "ROV Ship")
        let tieLater = BookVesselPrefill.Candidate(vessel: "Later", date: t0, createdAt: t0.addingTimeInterval(5))
        #expect(BookVesselPrefill.vessel(from: [dp, tieLater]) == "Later")
        #expect(BookVesselPrefill.vessel(from: []) == "")
    }

    @Test func vesselPrefillFromModelsUsesEachBooksStartDate() {
        let line = DPEntry(source: .manual, date: t0, durationHours: 2, vessel: "DP Ship", rank: "DPO", createdAt: t0)
        let move = RigMove(rigName: "Rig A", date: t0.addingTimeInterval(-3600), vessel: "AH Ship", rank: "Master")
        let rov = ROVEntry(date: t0.addingTimeInterval(-7200), vessel: "ROV Ship", createdAt: t0)
        let crane = CraneEntry(date: t0.addingTimeInterval(-10_800), vessel: nil, createdAt: t0)

        #expect(BookVesselPrefill.vessel(dpLines: [line], ahEntries: [move], rovEntries: [rov], craneEntries: [crane]) == "DP Ship")
        rov.date = t0.addingTimeInterval(60)
        #expect(BookVesselPrefill.vessel(dpLines: [line], ahEntries: [move], rovEntries: [rov], craneEntries: [crane]) == "ROV Ship")
        crane.vessel = "Crane Ship"
        crane.date = t0.addingTimeInterval(120)
        #expect(BookVesselPrefill.vessel(dpLines: [line], ahEntries: [move], rovEntries: [rov], craneEntries: [crane]) == "Crane Ship")
        // An AH entry can be the newest too, and only the vessel is ever taken (never the rank).
        move.date = t0.addingTimeInterval(500)
        #expect(BookVesselPrefill.vessel(dpLines: [line], ahEntries: [move], rovEntries: [rov], craneEntries: [crane]) == "AH Ship")
    }

    @Test func loggedShipNamesCoverAllBooks() {
        let line = DPEntry(source: .manual, date: t0, durationHours: 1, vessel: "DP Ship", createdAt: t0, updatedAt: t0)
        let rov = ROVEntry(date: t0, vessel: "ROV Ship", createdAt: t0.addingTimeInterval(60))
        let crane = CraneEntry(date: t0, vessel: "dp ship", createdAt: t0.addingTimeInterval(120))
        let names = BookVesselPrefill.loggedShipNames(dpLines: [line], ahEntries: [], rovEntries: [rov], craneEntries: [crane])
        #expect(names == ["dp ship", "ROV Ship"], "Same ship once, newest spelling first")
    }

    // MARK: Container

    @Test func containerRegistersAllFourModels() throws {
        let names = Set(LaunchEnvironment.models.map { String(describing: $0) })
        #expect(names == ["DPEntry", "RigMove", "ROVEntry", "CraneEntry"])
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(ROVEntry(date: t0))
        context.insert(CraneEntry(date: t0))
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<ROVEntry>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<CraneEntry>()) == 1)
    }

    /// A store from the AH build (DP + RigMove only) opens with the four-model schema:
    /// old rows survive, and the new books start empty.
    @Test func storeFromAHBuildOpensWithROVAndCraneAdded() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rov-crane-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("ah-build.store")

        let lineID = UUID()
        let moveID = UUID()
        do {
            let oldSchema = Schema([DPEntry.self, RigMove.self])
            let old = try ModelContainer(for: oldSchema, configurations: [ModelConfiguration(schema: oldSchema, url: url)])
            let context = ModelContext(old)
            context.insert(DPEntry(id: lineID, source: .manual, date: t0, durationHours: 6, vessel: "Old Ship"))
            let move = RigMove(id: moveID, rigName: "Old Rig", date: t0, vessel: "Old Ship")
            move.ahTasks = [.runAnchor]
            context.insert(move)
            try context.save()
        }

        let newSchema = Schema(LaunchEnvironment.models)
        let container = try ModelContainer(for: newSchema, configurations: [ModelConfiguration(schema: newSchema, url: url)])
        let context = ModelContext(container)
        let lines = try context.fetch(FetchDescriptor<DPEntry>())
        let moves = try context.fetch(FetchDescriptor<RigMove>())
        #expect(lines.map(\.id) == [lineID])
        #expect(lines.first?.durationHours == 6)
        #expect(moves.map(\.id) == [moveID])
        #expect(moves.first?.ahTasks == [.runAnchor])
        #expect(try context.fetchCount(FetchDescriptor<ROVEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<CraneEntry>()) == 0)

        // New books save into the migrated store.
        context.insert(ROVEntry(date: t0, vessel: "Old Ship"))
        try context.save()
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<ROVEntry>()) == 1)
    }

    // MARK: Log books and totals

    @Test func logBooksKeepOrderAndRawValues() {
        #expect(LogBook.allCases.map(\.rawValue) == ["dp", "anchorHandling", "rov", "crane"])
        #expect(LogBook.rov.subtitle == "ROV dives · piloting hours")
        #expect(LogBook.crane.subtitle == "Crane work · hours operated")
        var raw = StarredBooks.toggled(.crane, in: StarredBooks.defaultRaw)
        raw = StarredBooks.toggled(.rov, in: raw)
        #expect(StarredBooks.decode(raw) == [.dp, .rov, .crane], "Main keeps the Log order")
        #expect(raw == "dp,rov,crane")
    }

    @Test func statsSumTypedHoursAndKeepOldDPAndAHCopy() {
        let rovA = ROVEntry(date: t0); rovA.pilotingHours = 3.5
        let rovB = ROVEntry(date: t0); rovB.pilotingHours = 4
        let rovBlank = ROVEntry(date: t0)
        let crane = CraneEntry(date: t0); crane.hoursOperated = 21
        let line = DPEntry(source: .manual, date: t0, durationHours: 10, vessel: "S")
        let stats = LogBookStats(
            entries: [line], moves: [RigMove(rigName: "R")],
            rovEntries: [rovA, rovB, rovBlank], craneEntries: [crane],
            oldDPHoursText: "76,0"
        )
        #expect(stats.dpHours == 86)
        #expect(stats.rovPilotingHours == 7.5)
        #expect(stats.rovEntries == 3)
        #expect(stats.craneHours == 21)
        #expect(stats.craneEntries == 1)

        #expect(stats.hours(for: .anchorHandling) == nil)
        #expect(stats.hours(for: .rov) == 7.5)
        #expect(stats.hoursCaption(for: .crane) == "operated")
        #expect(stats.countCaption(for: .crane) == "entry")
        #expect(stats.countCaption(for: .anchorHandling) == "rig move")

        // DP and AH copy unchanged from the AH build (UI tests read these).
        #expect(stats.logSpokenValue(for: .dp) == "\(LogBookStats.hoursNumber(86)) hours total, 1 entries")
        #expect(stats.logSpokenValue(for: .anchorHandling) == "1 rig moves")
        #expect(stats.mainSpokenValue(for: .dp) == "\(LogBookStats.hoursNumber(86)) hours, 1 entry")
        #expect(stats.mainCountText(for: .anchorHandling) == "1 rig move")

        #expect(stats.logSpokenValue(for: .rov) == "\(LogBookStats.hoursNumber(7.5)) piloting hours, 3 entries")
        #expect(stats.logSpokenValue(for: .crane) == "\(LogBookStats.hoursNumber(21)) hours operated, 1 entry")
        #expect(stats.mainSpokenValue(for: .rov) == "\(LogBookStats.hoursNumber(7.5)) piloting hours, 3 entries")
    }

    // MARK: Helpers

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(LaunchEnvironment.models)
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
    }
}
