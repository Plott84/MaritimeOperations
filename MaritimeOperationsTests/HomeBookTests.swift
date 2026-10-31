import Foundation
import Testing
@testable import MaritimeOperations

/// Home books: primary plus an optional secondary. DP by default. Crane Home must not describe a DP timer.
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
        #expect(HomeBook.dp.chipLine == "On Main · ★ DP · Change ›")
        #expect(HomeBook.crane.chipLine == "On Main · ★ Crane · Change ›")
        #expect(HomeBook.ah.chipTitle == "AH")
        #expect(HomeBook.rov.chipTitle == "ROV")
        #expect(HomeBook.dp.starAccessibilityLabel == "On Main, D P")
        #expect(HomeBook.crane.starAccessibilityLabel == "On Main, Crane")
        #expect(HomeBook.ah.starAccessibilityLabel == "On Main, A H")
        #expect(HomeBook.changeHint == "Double tap to change.")
        #expect(HomeBook.pickerTitle == "On Main")
        #expect(HomeBook.pickerFootnote == "Primary gets the big card. Secondary sits under it. Max two.")
        #expect(HomeBooks.entriesFootnote == "Star up to two books for Main (HB-13). Export lives on the Export tab.")
        let pair = HomeBooks(primary: .dp, secondary: .crane)
        #expect(pair.chipLine == "On Main · ★ DP · ★ Crane · Change ›")
        #expect(pair.voiceLabel == "On Main, D P, Crane")
        #expect(HomeBooks(primary: .crane, secondary: .dp).voiceLabel == "On Main, Crane, D P")
    }

    /// Soft B empty books: Soft #19 CTA, no New Rig Move, no lift-clearance language.
    @Test func softBEmptyBooksUseThePrimaryCTA() {
        let dp = BookEmptyCopy.of(.dp)
        #expect(dp.title == "No DP entries yet")
        #expect(dp.message == "Start DP on Main, or add a manual line. Sessions land here under Entries · DP.")
        #expect(dp.cta == "Start DP")
        #expect(dp.opensMainTimer)
        #expect(dp.accessibilityIdentifier == "bookEmptyCTA_dp")

        let ah = BookEmptyCopy.of(.anchorHandling)
        #expect(ah.title == "No rig moves yet")
        #expect(ah.message == "Add a rig move to the Anchor handling book.")
        #expect(ah.cta == "New rig move")
        #expect(!ah.opensMainTimer)
        #expect(ah.accessibilityIdentifier == "addRigMovePill")

        let crane = BookEmptyCopy.of(.crane)
        #expect(crane.title == "No Crane entries yet")
        #expect(crane.message == "New lift opens the Crane entry form. Saved lifts land here under Entries · Crane.")
        #expect(crane.cta == "New lift")
        #expect(!crane.opensMainTimer)
        #expect(crane.accessibilityIdentifier == "craneAddEntryPill")

        let rov = BookEmptyCopy.of(.rov)
        #expect(rov.title == "No ROV entries yet")
        #expect(rov.message == "Add an ROV entry to this book.")
        #expect(rov.cta == "New ROV entry")
        #expect(!rov.opensMainTimer)
        #expect(rov.accessibilityIdentifier == "rovAddEntryPill")

        #expect(BookEmptyCopy.of(.dp).cta != "New Rig Move")
        for book in LogBook.allCases {
            let copy = BookEmptyCopy.of(book)
            let blob = "\(copy.title)\n\(copy.message)\n\(copy.cta)"
            #expect(!blob.contains("New Rig Move"))
            #expect(!blob.contains("SAFE"))
            #expect(!blob.contains("OK to lift"))
            #expect(!blob.contains("to Log"))
            #expect(!copy.title.hasSuffix("."))
        }
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

    /// HB-13a: star DP, then Crane. DP stays the hero. Crane is the compact secondary.
    @Test func starringDPThenCraneKeepsDPHeroAndAddsCraneSecondary() {
        var books = HomeBooks(primary: .dp)
        #expect(books.role(of: .dp) == .primary)
        books = books.starring(.dp)
        #expect(books == HomeBooks(primary: .dp))
        books = books.starring(.crane)
        #expect(books == HomeBooks(primary: .dp, secondary: .crane))
        #expect(books.role(of: .dp) == .primary)
        #expect(books.role(of: .crane) == .secondary)
        #expect(books.role(of: .ah) == .off)
        #expect(books.chipLine == "On Main · ★ DP · ★ Crane · Change ›")
        #expect(HomeBook.dp.hero.primary == "Start DP")
        #expect(HomeBook.dp.hero.secondary == nil)
        #expect(HomeSecondaryLine.cta(book: .crane) == "New lift")
        #expect(HomeSecondaryLine.accessibilityLabel(book: .crane, cta: "New lift") == "Crane on Main, New lift")
        #expect(!HomeSecondaryLine.cta(book: .crane).contains("Open Crane log"))
        #expect(HomeSecondaryLine.cta(book: .ah) != "New Rig Move")
        #expect(HomeSecondaryLine.cta(book: .rov) == "New ROV entry")
        #expect(HomeSecondaryLine.cta(book: .dp) == "Start DP")
    }

    /// HB-13b: a third star replaces secondary. Primary stays.
    @Test func thirdStarReplacesSecondaryAndLeavesPrimary() {
        let paired = HomeBooks(primary: .dp, secondary: .crane)
        let next = paired.starring(.ah)
        #expect(next.primary == .dp)
        #expect(next.secondary == .ah)
        #expect(next.role(of: .crane) == .off)
        #expect(next.role(of: .ah) == .secondary)
        #expect(paired.starring(.dp) == paired, "Primary stays while a secondary is set")
        #expect(next.starring(.ah) == HomeBooks(primary: .dp), "Starring the secondary clears it")
    }

    /// HB-13c: Make primary swaps the two books. Crane hero still has no DP timer.
    @Test func makePrimarySwapsSecondaryIntoTheHero() {
        let swapped = HomeBooks(primary: .dp, secondary: .crane).makingSecondaryPrimary()
        #expect(swapped == HomeBooks(primary: .crane, secondary: .dp))
        #expect(swapped.selectingPrimary(.dp) == HomeBooks(primary: .dp, secondary: .crane))
        #expect(!HomeBook.crane.hero.showsDPTimer)
        #expect(!HomeBook.crane.hero.eyebrow.contains("DP TIMER"))
        let dpLine = HomeSecondaryLine.status(book: .dp, dpClock: "00:00", dpRunning: false)
        #expect(dpLine == "00:00 · Ready")
        #expect(HomeSecondaryLine.cta(book: .dp, dpRunning: false) == "Start DP")
        #expect(HomeSecondaryLine.cta(book: .dp, dpRunning: true) == "Stop DP")
        let running = HomeSecondaryLine.status(book: .dp, dpClock: "01:02", dpRunning: true)
        #expect(running == "01:02 · Running")
        #expect(HomeBooks(primary: .crane).makingSecondaryPrimary() == HomeBooks(primary: .crane))
    }

    /// HB-13d: Latest Activity is the primary book only.
    @Test func latestActivityStaysOnThePrimaryBook() {
        let t0 = Date(timeIntervalSince1970: 1_780_000_000)
        let dp = DPEntry(
            source: .manual,
            date: t0,
            durationHours: 6,
            vessel: "Seven Falcon",
            vesselType: "PSV",
            dpClassLevel: 2,
            createdAt: t0
        )
        let crane = CraneEntry(date: t0, vessel: "Vessel B", createdAt: t0)
        crane.liftWeightTonnes = 10
        crane.wireOutMetres = 85
        let books = HomeBooks(primary: .dp, secondary: .crane)
        let items = HomeActivity.latest(
            book: books.primary,
            dpEntries: [dp],
            rigMoves: [],
            rovEntries: [],
            craneEntries: [crane],
            locale: locale,
            timeZone: timeZone
        )
        #expect(items.count == 1)
        #expect(items.allSatisfy { $0.book == .dp })
        #expect(items[0].title == "DP session")
        #expect(!items.contains { $0.book == .crane })
        #expect(books.primary.hero.activityChip == "5 latest · DP")
        #expect(crane.liftWeightTonnes == 10, "Reading activity must not delete the crane entry")
    }

    /// HB-13e: primary and secondary survive a fresh defaults read. Missing secondary stays nil.
    @Test func primaryAndSecondaryPersistAndMigrateWithoutASecondary() {
        let suite = "homeBooks-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set("crane", forKey: HomeBook.storageKey)
        defaults.set("keep-me", forKey: "dp.oldHoursText")
        defaults.set("dp,crane", forKey: "log.starredBooks")
        let migrated = HomeBooks.load(defaults: defaults)
        #expect(migrated == HomeBooks(primary: .crane))
        #expect(defaults.object(forKey: HomeBooks.secondaryStorageKey) == nil)
        #expect(defaults.string(forKey: "log.starredBooks") == "dp,crane")

        HomeBooks(primary: .dp, secondary: .crane).save(to: defaults)
        let relaunch = UserDefaults(suiteName: suite)!
        #expect(HomeBooks.load(defaults: relaunch) == HomeBooks(primary: .dp, secondary: .crane))
        #expect(relaunch.string(forKey: HomeBook.storageKey) == "dp")
        #expect(relaunch.string(forKey: HomeBooks.secondaryStorageKey) == "crane")
        #expect(relaunch.string(forKey: "dp.oldHoursText") == "keep-me")

        HomeBooks(primary: .dp, secondary: .dp).save(to: defaults)
        #expect(HomeBooks.load(defaults: defaults).secondary == nil)
        #expect(defaults.object(forKey: HomeBooks.secondaryStorageKey) == nil)
        #expect(defaults.string(forKey: HomeBook.storageKey) == "dp")

        defaults.set("rov", forKey: HomeBook.storageKey)
        defaults.set("rov", forKey: HomeBooks.secondaryStorageKey)
        #expect(HomeBooks.load(defaults: defaults) == HomeBooks(primary: .rov))
        defaults.set("", forKey: HomeBooks.secondaryStorageKey)
        #expect(HomeBooks.load(defaults: defaults).secondary == nil)
        defaults.set("nope", forKey: HomeBooks.secondaryStorageKey)
        #expect(HomeBooks.load(defaults: defaults) == HomeBooks(primary: .rov))
        #expect(defaults.string(forKey: "dp.oldHoursText") == "keep-me")
    }

    @Test func secondaryStatusIsOneLineAndCraneDoesNotBorrowTheDPClock() {
        let date = octoberThird
        let lift = CraneHomeLastLift.make(
            weightTonnes: 10,
            wireMetres: 85,
            vessel: "Vessel B",
            craneName: "Crane A",
            date: date,
            hours: 4.5,
            locale: locale,
            timeZone: timeZone
        )
        #expect(HomeSecondaryLine.status(book: .crane, dpClock: "00:00", dpRunning: true, craneLift: lift) == "Last lift · 10 t · 85 m wire")
        let noClock = HomeSecondaryLine.status(book: .crane, dpClock: "12:34", dpRunning: true, craneLift: nil)
        #expect(noClock == "No entries yet")
        #expect(!noClock.contains("12:34"))
        #expect(!noClock.contains("DP TIMER"))
        #expect(!noClock.contains("Start DP"))

        let bare = CraneHomeLastLift.make(
            weightTonnes: nil,
            wireMetres: nil,
            vessel: "Vessel B",
            craneName: nil,
            date: date,
            hours: nil,
            locale: locale,
            timeZone: timeZone
        )
        #expect(HomeSecondaryLine.status(book: .crane, craneLift: bare) == "Last lift · Vessel B · 3 Oct")

        let move = RigMove(rigName: "Rig A", date: date, vessel: "Vessel B")
        let anchor = HomeEntrySummary.anchorHandling(move, locale: locale, timeZone: timeZone)
        #expect(HomeSecondaryLine.status(book: .ah, anchor: anchor) == "Rig move · Rig A · Vessel B · 3 Oct")
        #expect(HomeSecondaryLine.status(book: .ah) == "No entries yet")
        #expect(HomeSecondaryLine.status(book: .rov) == "No entries yet")

        let cleared = HomeBooks(primary: .ah).starring(.ah)
        #expect(cleared == HomeBooks(primary: .dp))
        let added = HomeBooks(primary: .crane).starring(.dp)
        #expect(added == HomeBooks(primary: .crane, secondary: .dp))
        let kept = HomeBooks(primary: .dp, secondary: .rov).selectingPrimary(.ah)
        #expect(kept == HomeBooks(primary: .ah, secondary: .rov))
        let rejected = HomeBooks(primary: .dp, secondary: .crane).selectingSecondary(.dp)
        #expect(rejected == HomeBooks(primary: .dp, secondary: .crane))
        #expect(HomeBooks(primary: .dp, secondary: .crane).selectingSecondary(nil) == HomeBooks(primary: .dp))
    }

    /// HC-01…04 floors. Default visuals are 50 / 48 / 44. Picker rows use the same 44 pt button-body floor.
    @Test func homeCTAHitFloorsStayAtLeast44() {
        #expect(HomeCTAButton.hardMinimumHit == 44)
        #expect(HomeCTAButton.Kind.primary.minimumHeight == 50)
        #expect(HomeCTAButton.Kind.secondary.minimumHeight == 48)
        #expect(HomeSecondaryCard.minimumHitHeight == 44)
        #expect(HomeCTAButton.Kind.primary.minimumHeight >= HomeCTAButton.hardMinimumHit)
        #expect(HomeCTAButton.Kind.secondary.minimumHeight >= HomeCTAButton.hardMinimumHit)
        #expect(HomeSecondaryCard.minimumHitHeight >= HomeCTAButton.hardMinimumHit)
        #expect(HomeBookOptionHit.minimumHeight == 44)
        #expect(HomeBookOptionHit.minimumHeight == HomeCTAButton.hardMinimumHit)
    }

    /// HC-07 / HC-10: DP hero stays Start DP. Home CTA copy makes no lift or class claim.
    /// "saves" in the DP caption is not the word "safe".
    @Test func homeHeroCopyMakesNoLiftClaim() {
        let banned = ["safe", "class"]
        for book in HomeBook.allCases {
            let copy = book.hero
            let blob = [copy.eyebrow, copy.primary, copy.secondary ?? "", copy.caption].joined(separator: "\n")
            let words = blob.lowercased().split { !$0.isLetter }.map(String.init)
            for word in banned {
                #expect(!words.contains(word), "\(word) in \(book.rawValue) hero")
            }
            #expect(!blob.lowercased().contains("ok to lift"))
            #expect(copy.primary != "New Rig Move")
        }
        #expect(HomeBook.dp.hero.primary == "Start DP")
        #expect(HomeBook.dp.hero.secondary == nil)
        #expect(HomeSecondaryLine.cta(book: .dp) == "Start DP")
        #expect(HomeSecondaryLine.cta(book: .crane) == "New lift")
    }
}
