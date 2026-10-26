import Foundation
import Testing
@testable import MaritimeOperations

/// Home book: one preference, DP by default. Crane Home must not describe a DP timer.
@MainActor
struct HomeBookTests {
    private let locale = Locale(identifier: "en_US_POSIX")
    private let timeZone = TimeZone(secondsFromGMT: 0)!

    private var octoberThird: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 12))!
    }

    @Test func defaultHomeBookIsDP() {
        #expect(HomeBook.storageKey == "homeBook")
        #expect(HomeBook.defaultRaw == "dp")
        #expect(HomeBook.resolve(nil) == .dp)
        #expect(HomeBook.resolve("") == .dp)
        #expect(HomeBook.resolve("junk") == .dp)
        #expect(HomeBook.resolve("anchorHandling") == .dp, "Stored value is ah, not the Log raw value")
        #expect(HomeBook.resolve("dp") == .dp)
        #expect(HomeBook.resolve("ah") == .ah)
        #expect(HomeBook.resolve("crane") == .crane)
        #expect(HomeBook.resolve("rov") == .rov)
        #expect(HomeBook.allCases.map(\.rawValue) == ["dp", "ah", "crane", "rov"])
    }

    @Test func chipAndVoiceNameTheCurrentBook() {
        #expect(HomeBook.dp.chipLine == "Home book · ★ DP · Change ›")
        #expect(HomeBook.crane.chipLine == "Home book · ★ Crane · Change ›")
        #expect(HomeBook.ah.chipTitle == "AH")
        #expect(HomeBook.rov.chipTitle == "ROV")
        #expect(HomeBook.dp.starAccessibilityLabel == "Home book, D P")
        #expect(HomeBook.crane.starAccessibilityLabel == "Home book, Crane")
        #expect(HomeBook.ah.starAccessibilityLabel == "Home book, A H")
        #expect(HomeBook.changeHint == "Double tap to change.")
        #expect(HomeBook.pickerFootnote == "Main shows this book\u{2019}s quick-start. Change anytime.")
    }

    @Test func logStarMapsOntoTheSameBook() {
        #expect(HomeBook(logBook: .dp) == .dp)
        #expect(HomeBook(logBook: .anchorHandling) == .ah)
        #expect(HomeBook(logBook: .crane) == .crane)
        #expect(HomeBook(logBook: .rov) == .rov)
        #expect(LogBook.allCases.map { HomeBook(logBook: $0).logBook } == Array(LogBook.allCases))
        for book in HomeBook.allCases {
            #expect(!book.rawValue.contains(","), "One book, never a starred list")
        }
    }

    @Test func preferencePersistsAcrossAFreshDefaultsRead() {
        let suite = "homeBook-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set("keep-me", forKey: "dp.oldHoursText")
        #expect(HomeBook.load(defaults: defaults) == .dp)

        HomeBook.save(.crane, defaults: defaults)
        let relaunch = UserDefaults(suiteName: suite)!
        #expect(HomeBook.load(defaults: relaunch) == .crane)
        #expect(relaunch.string(forKey: HomeBook.storageKey) == "crane")

        HomeBook.save(.ah, defaults: relaunch)
        #expect(HomeBook.load(defaults: defaults) == .ah)
        #expect(defaults.string(forKey: HomeBook.storageKey) == "ah")
        #expect(defaults.string(forKey: "dp.oldHoursText") == "keep-me")
    }

    /// HB-11: idle DP hero is the timer plus Start DP. No secondary rig-move CTA.
    @Test func dpHomeIdleHeroShowsOnlyStartDP() {
        let copy = HomeBook.dp.hero
        #expect(copy.showsDPTimer)
        #expect(copy.eyebrow == "DP TIMER")
        #expect(copy.primary == "Start DP")
        #expect(copy.secondary == nil)
        #expect(copy.caption == "Start when the vessel goes on DP. Stop saves the session to Entries.")
        #expect(copy.activityCaption == "Newest 5 records in the DP book.")
        #expect(!copy.activityCaption.contains("Rig Moves"))
        #expect(copy.activityChip == "5 latest · DP")
        #expect(copy.emptyTitle == "No DP entries yet.")
    }

    @Test func craneHomeDoesNotOfferTheDPTimer() {
        let copy = HomeBook.crane.hero
        #expect(!copy.showsDPTimer)
        #expect(copy.eyebrow == "CRANE")
        #expect(copy.primary == "New lift")
        #expect(copy.secondary == "Open Crane log")
        #expect(copy.caption == "New lift opens the Crane entry form. Stop / Save lands in Entries · Crane.")
        #expect(copy.activityCaption == "Newest 5 Crane entries. DP timer is not on this Home.")
        #expect(copy.activityChip == "5 latest · Crane")
        #expect(copy.emptyTitle == "No Crane entries yet.")
        let blob = [copy.eyebrow, copy.primary, copy.secondary ?? "", copy.caption, copy.activityCaption].joined(separator: "\n")
        #expect(!blob.contains("DP TIMER"))
        #expect(!blob.contains("Start DP"))
        #expect(!blob.contains("Stop DP"))
        #expect(!blob.contains("New Rig Move"))
        #expect(!blob.contains("00:00"))
    }

    @Test func anchorHandlingAndROVAreStubsWithoutTheDPTimer() {
        let ah = HomeBook.ah.hero
        #expect(!ah.showsDPTimer)
        #expect(ah.eyebrow == "ANCHOR HANDLING")
        #expect(ah.primary == "New rig move")
        #expect(ah.secondary == "Open Anchor handling log")
        #expect(ah.activityChip == "5 latest · AH")
        #expect(ah.emptyTitle == "No AH entries yet.")
        #expect(!ah.primary.contains("DP TIMER"))
        #expect(ah.secondary != "New Rig Move")

        let rov = HomeBook.rov.hero
        #expect(!rov.showsDPTimer)
        #expect(rov.eyebrow == "ROV")
        #expect(rov.primary == "New ROV entry")
        #expect(rov.secondary == "Open ROV log")
        #expect(rov.activityChip == "5 latest · ROV")
        #expect(rov.emptyTitle == "No ROV entries yet.")
    }

    /// HB-12: four tabs. Rig moves stay in Entries (AH), not a fifth tab.
    @Test func tabBarIsMainEntriesToolsExport() {
        #expect(AppTab.allCases.map(\.title) == ["Main", "Entries", "Tools", "Export"])
        #expect(AppTab.allCases.map(\.rawValue) == ["main", "log", "tools", "export"])
        #expect(AppTab.log.rawValue == "log", "Entries keeps the tab_log identifier")
        #expect(!AppTab.allCases.contains { $0.title == "Rig Moves" || $0.rawValue == "rigMoves" })
    }

    @Test func craneActivityIsCraneOnlyAndCapsAtFive() {
        let t0 = Date(timeIntervalSince1970: 1_780_000_000)
        var cranes: [CraneEntry] = []
        for index in 0..<6 {
            let entry = CraneEntry(
                date: t0.addingTimeInterval(Double(index) * 3_600),
                vessel: "V\(index)",
                createdAt: t0.addingTimeInterval(Double(index))
            )
            entry.craneName = "C\(index)"
            entry.hoursOperated = Double(index)
            cranes.append(entry)
        }
        let dp = DPEntry(
            source: .manual,
            date: t0.addingTimeInterval(100_000),
            durationHours: 4,
            vessel: "DP Ship",
            vesselType: "PSV",
            dpClassLevel: 2,
            createdAt: t0.addingTimeInterval(100_000)
        )
        let move = RigMove(rigName: "Rig Z", date: t0.addingTimeInterval(100_000), vessel: "AH Ship")
        let rov = ROVEntry(date: t0.addingTimeInterval(100_000), vessel: "ROV Ship")

        let items = HomeActivity.latest(
            book: .crane,
            dpEntries: [dp],
            rigMoves: [move],
            rovEntries: [rov],
            craneEntries: cranes,
            locale: locale,
            timeZone: timeZone
        )
        #expect(items.count == 5)
        #expect(items.allSatisfy { $0.book == .crane && $0.book.badge == "CR" })
        #expect(items.map(\.id) == cranes.reversed().prefix(5).map(\.id.uuidString))
        #expect(items.first?.title == "Crane entry")
        #expect(items.first?.subtitle == "V5 · C5")
        #expect(items.first?.trailing == "5 h")
        #expect(items.allSatisfy { !$0.subtitle.contains("DP Ship") && !$0.title.contains("DP") })
        #expect(cranes.count == 6, "Filtering must not delete crane entries")
        #expect(dp.vessel == "DP Ship")

        let dpItems = HomeActivity.latest(
            book: .dp,
            dpEntries: [dp],
            rigMoves: [move],
            rovEntries: [rov],
            craneEntries: cranes,
            locale: locale,
            timeZone: timeZone
        )
        #expect(dpItems.count == 1)
        #expect(dpItems[0].book == .dp)
        #expect(dpItems[0].title == "DP session")
        #expect(dpItems[0].subtitle == "PSV · Class 2 · DP Ship")

        let emptyCrane = HomeActivity.latest(
            book: .crane,
            dpEntries: [dp],
            rigMoves: [move],
            rovEntries: [rov],
            craneEntries: []
        )
        #expect(emptyCrane.isEmpty)

        let ahItems = HomeActivity.latest(
            book: .ah,
            dpEntries: [dp],
            rigMoves: [move],
            rovEntries: [rov],
            craneEntries: cranes,
            locale: locale,
            timeZone: timeZone
        )
        #expect(ahItems.count == 1)
        #expect(ahItems[0].book == .anchorHandling)
        #expect(ahItems[0].badgeText == "AH")
    }

    @Test func lastLiftOmitsEmptyWeightOrWire() {
        let date = octoberThird
        let both = CraneHomeLastLift.make(
            weightTonnes: 12.5,
            wireMetres: 18,
            vessel: "Northern Pioneer",
            craneName: "Port crane",
            date: date,
            hours: 2.5,
            locale: locale,
            timeZone: timeZone
        )
        #expect(both.value == "12.5 t · 18 m wire")
        #expect(both.sub == "Northern Pioneer · Port crane · 3 Oct · 2.5 h")

        let weightOnly = CraneHomeLastLift.make(
            weightTonnes: 10,
            wireMetres: nil,
            vessel: "  ",
            craneName: nil,
            date: date,
            hours: nil,
            locale: locale,
            timeZone: timeZone
        )
        #expect(weightOnly.value == "10 t")
        #expect(weightOnly.sub == "3 Oct")

        let wireOnly = CraneHomeLastLift.make(
            weightTonnes: nil,
            wireMetres: 4.5,
            vessel: "Ship",
            craneName: "",
            date: date,
            hours: nil,
            locale: locale,
            timeZone: timeZone
        )
        #expect(wireOnly.value == "4.5 m wire")
        #expect(wireOnly.sub == "Ship · 3 Oct")

        let neither = CraneHomeLastLift.make(
            weightTonnes: nil,
            wireMetres: nil,
            vessel: nil,
            craneName: nil,
            date: date,
            hours: nil,
            locale: locale,
            timeZone: timeZone
        )
        #expect(neither.value == nil)
        #expect(neither.sub == "3 Oct")
    }

    @Test func lastLiftUsesTheNewestCraneEntry() {
        let date = octoberThird
        let older = CraneEntry(date: date.addingTimeInterval(-3_600), vessel: "Old", createdAt: date.addingTimeInterval(-3_600))
        older.liftWeightTonnes = 50
        older.wireOutMetres = 10
        let newer = CraneEntry(date: date, vessel: "Northern Pioneer", createdAt: date)
        newer.craneName = "Port crane"
        newer.hoursOperated = 2.5
        let lift = CraneHomeLastLift.latest(in: [older, newer], locale: locale, timeZone: timeZone)
        #expect(lift?.value == nil, "Newer entry left weight and wire empty")
        #expect(lift?.sub == "Northern Pioneer · Port crane · 3 Oct · 2.5 h")
        #expect(CraneHomeLastLift.latest(in: []) == nil)
        #expect(older.liftWeightTonnes == 50, "Reading the latest lift must not clear the other entry")
    }

    @Test func stubSummariesUseTheNewestRow() {
        let date = octoberThird
        let move = RigMove(rigName: "Rig A", date: date, vessel: "Vessel B")
        move.startTime = date
        move.endTime = date.addingTimeInterval(2.5 * 3_600)
        let ah = HomeEntrySummary.anchorHandling(move, locale: locale, timeZone: timeZone)
        #expect(ah.title == "Rig move")
        #expect(ah.sub == "Rig A · Vessel B · 3 Oct · 2.5 h")

        let rov = ROVEntry(date: date, vessel: "Vessel B")
        rov.rovSystem = "System A"
        rov.pilotingHours = 3
        let rovSummary = HomeEntrySummary.rov(rov, locale: locale, timeZone: timeZone)
        #expect(rovSummary.title == "ROV entry")
        #expect(rovSummary.sub == "Vessel B · System A · 3 Oct · 3 h")
    }
}
