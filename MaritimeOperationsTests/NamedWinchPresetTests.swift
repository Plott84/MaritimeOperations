import Foundation
import Testing
@testable import MaritimeOperations

/// Named winch presets (Soft A). Store behaviour behind WS-01…WS-04, WS-02a, WS-07, and the Salt 200 seed.
struct NamedWinchPresetTests {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private let t1 = Date(timeIntervalSince1970: 1_700_000_100)
    private let t2 = Date(timeIntervalSince1970: 1_700_000_200)

    /// Empty user library whose seed flag is already set, so reads stay empty (S200-02).
    private func freshStore() -> (NamedWinchPresetStore, UserDefaults) {
        let (store, defaults, _) = makeStore(seededFlag: true)
        return (store, defaults)
    }

    /// Empty library that has never decided the seed. The first read writes the four Salt 200 drums.
    private func unseededStore() -> (NamedWinchPresetStore, UserDefaults, String) {
        makeStore(seededFlag: false)
    }

    private func makeStore(seededFlag: Bool) -> (NamedWinchPresetStore, UserDefaults, String) {
        let name = "NamedWinchPresetTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        if seededFlag {
            defaults.set(true, forKey: NamedWinchPresetStore.factorySeedKey)
        }
        return (NamedWinchPresetStore(defaults: defaults), defaults, name)
    }

    /// A-frame port example from the locked mock.
    private func aFrame(
        wire: Double = 87,
        barrel: Double = 1800,
        width: Double = 3400,
        flange: Double = 4300,
        free: Double = 400,
        dead: Int = 3,
        pull: Double? = 170
    ) -> NamedWinchInputs {
        NamedWinchInputs(
            wireDiameterMm: wire,
            barrelDiameterMm: barrel,
            drumWidthMm: width,
            flangeDiameterMm: flange,
            freeSpaceMm: free,
            deadWraps: dead,
            firstLayerPullTonnes: pull
        )
    }

    private func starboard() -> NamedWinchInputs {
        aFrame(wire: 76, barrel: 1400, width: 2000, flange: 3600, free: 400, dead: 3, pull: 150)
    }

    // MARK: - WS-01 Save new

    @Test func ws01SaveNewPresetStoresNameAndSevenInputs() {
        let (store, _) = freshStore()
        let inputs = aFrame()
        #expect(store.match(name: "  A-frame port") == .available(trimmed: "A-frame port"))
        let saved = store.save(name: "A-frame port", inputs: inputs, at: t0)

        #expect(saved?.name == "A-frame port")
        #expect(saved?.inputs == inputs)
        #expect(saved?.updatedAt == t0)
        #expect(store.all().count == 1)
        #expect(store.all().first == saved)
        #expect(store.match(name: "A-frame port") == .collision(existingDisplayName: "A-frame port"))
    }

    @Test func trimmedNameIsWhatGetsStored() {
        let (store, _) = freshStore()
        let saved = store.save(name: "  A-frame port  ", inputs: aFrame(), at: t0)
        #expect(saved?.name == "A-frame port")
        #expect(store.match(name: "a-frame port") == .collision(existingDisplayName: "A-frame port"))
    }

    @Test func blankNameDoesNotWrite() {
        let (store, _) = freshStore()
        #expect(store.match(name: "   ") == .empty)
        #expect(store.match(name: "") == .empty)
        #expect(store.save(name: "   ", inputs: aFrame(), at: t0) == nil)
        #expect(store.all().isEmpty)
    }

    // MARK: - WS-02 Overwrite, same casing

    @Test func ws02SameCasingAsksToReplaceThenUpdatesOrCancelLeavesLibrary() {
        let (store, _) = freshStore()
        let original = aFrame()
        store.save(name: "A-frame port", inputs: original, at: t0)
        let edited = starboard()

        #expect(store.match(name: "A-frame port") == .collision(existingDisplayName: "A-frame port"))
        // Cancel: match does not write.
        #expect(store.all().first?.inputs == original)
        #expect(store.all().first?.updatedAt == t0)

        let replaced = store.save(name: "A-frame port", inputs: edited, at: t1)
        #expect(replaced?.name == "A-frame port")
        #expect(replaced?.inputs == edited)
        #expect(replaced?.updatedAt == t1)
        #expect(replaced?.id == store.all().first?.id)
        #expect(store.all().count == 1)
        #expect(store.all().first?.inputs == edited)
    }

    // MARK: - WS-02a Case fold

    @Test func ws02aLowercaseTypedAgainstStoredTitleHitsSameReplace() {
        let (store, _) = freshStore()
        let original = aFrame()
        let created = store.save(name: "A-frame", inputs: original, at: t0)

        #expect(store.match(name: "a-frame") == .collision(existingDisplayName: "A-frame"))
        #expect(store.match(name: "a-Frame") == .collision(existingDisplayName: "A-frame"))
        #expect(store.match(name: "  A-FRAME ") == .collision(existingDisplayName: "A-frame"))
        // Cancel still leaves the stored casing and values.
        #expect(store.all().first?.name == "A-frame")
        #expect(store.all().first?.inputs == original)

        let edited = starboard()
        let replaced = store.save(name: "a-frame", inputs: edited, at: t1)
        #expect(replaced?.id == created?.id)
        #expect(replaced?.name == "a-frame")
        #expect(replaced?.inputs == edited)
        #expect(store.all().count == 1)
        #expect(store.all().first?.name == "a-frame")
        #expect(store.match(name: "A-frame") == .collision(existingDisplayName: "a-frame"))
    }

    @Test func ws02aTitleTypedAgainstStoredLowercaseHitsSameReplace() {
        let (store, _) = freshStore()
        store.save(name: "a-frame", inputs: aFrame(), at: t0)

        #expect(store.match(name: "A-frame") == .collision(existingDisplayName: "a-frame"))
        #expect(store.match(name: "a-Frame") == .collision(existingDisplayName: "a-frame"))

        let replaced = store.save(name: "A-frame", inputs: starboard(), at: t1)
        #expect(replaced?.name == "A-frame")
        #expect(replaced?.inputs == starboard())
        #expect(store.all().count == 1)
        #expect(store.all().first?.name == "A-frame")
    }

    @Test func distinctNamesStaySeparateWhenOneIsReplaced() {
        let (store, _) = freshStore()
        store.save(name: "Port tugger", inputs: aFrame(wire: 52, barrel: 900, width: 1600, flange: 2200, pull: 40), at: t0)
        store.save(name: "A-frame", inputs: aFrame(), at: t1)
        store.save(name: "a-frame", inputs: starboard(), at: t2)

        #expect(store.all().count == 2)
        #expect(store.all().map(\.name) == ["a-frame", "Port tugger"])
        #expect(store.all().last?.wireDiameterMm == 52)
        #expect(store.all().first?.inputs == starboard())
    }

    // MARK: - WS-03 Load

    @Test func ws03SavedPresetKeepsAllSevenInputsForLoad() {
        let (store, _) = freshStore()
        let inputs = aFrame()
        store.save(name: "A-frame port", inputs: inputs, at: t0)
        store.save(name: "T/W starboard", inputs: starboard(), at: t1)

        let loaded = store.all().first { $0.name == "A-frame port" }
        #expect(loaded?.inputs == inputs)
        #expect(loaded?.wireDiameterMm == 87)
        #expect(loaded?.barrelDiameterMm == 1800)
        #expect(loaded?.drumWidthMm == 3400)
        #expect(loaded?.flangeDiameterMm == 4300)
        #expect(loaded?.freeSpaceMm == 400)
        #expect(loaded?.deadWraps == 3)
        #expect(loaded?.firstLayerPullTonnes == 170)
    }

    @Test func fieldTextRoundTripsThroughCapture() {
        let text = NamedWinchFieldText(
            wire: "87",
            barrel: "1800",
            width: "3400",
            flange: "4300",
            freeSpace: "400",
            deadWraps: "3",
            firstLayerPull: "170"
        )
        let captured = NamedWinchInputs.capture(text)
        #expect(captured == aFrame())
        #expect(captured?.fieldText == NamedWinchFieldText(
            wire: "87",
            barrel: "1800",
            width: "3400",
            flange: "4300",
            freeSpace: "400",
            deadWraps: "3",
            firstLayerPull: "170"
        ))
        #expect(NamedWinchInputs.capture(captured!.fieldText) == captured)

        let decimal = NamedWinchInputs.capture(
            wire: "87,5",
            barrel: "1800",
            width: "3400",
            flange: "4300",
            freeSpace: "400",
            deadWraps: "3",
            firstLayerPull: "170.5"
        )
        #expect(decimal?.wireDiameterMm == 87.5)
        #expect(decimal?.firstLayerPullTonnes == 170.5)
        #expect(decimal?.fieldText.wire == "87.5")
        #expect(decimal?.fieldText.firstLayerPull == "170.5")
        #expect(NamedWinchInputs.capture(decimal!.fieldText) == decimal)
    }

    @Test func emptyOptionalFieldsUseMathDefaultsAndOmitPull() {
        let captured = NamedWinchInputs.capture(
            wire: "87",
            barrel: "1800",
            width: "3400",
            flange: "4300",
            freeSpace: "  ",
            deadWraps: "",
            firstLayerPull: ""
        )
        #expect(captured?.freeSpaceMm == WinchCapacityMath.defaultFreeSpaceMm)
        #expect(captured?.deadWraps == WinchCapacityMath.defaultDeadWraps)
        #expect(captured?.firstLayerPullTonnes == nil)
        #expect(captured?.fieldText.freeSpace == "400")
        #expect(captured?.fieldText.deadWraps == "3")
        #expect(captured?.fieldText.firstLayerPull == "")
    }

    @Test func captureRejectsIncompleteOrGarbage() {
        #expect(NamedWinchInputs.capture(
            wire: "", barrel: "1800", width: "3400", flange: "4300",
            freeSpace: "", deadWraps: "", firstLayerPull: ""
        ) == nil)
        #expect(NamedWinchInputs.capture(
            wire: "87", barrel: "1800", width: "3400", flange: "4300",
            freeSpace: "abc", deadWraps: "3", firstLayerPull: ""
        ) == nil)
        #expect(NamedWinchInputs.capture(
            wire: "87", barrel: "1800", width: "3400", flange: "4300",
            freeSpace: "400", deadWraps: "1.5", firstLayerPull: ""
        ) == nil)
        #expect(NamedWinchInputs.capture(
            wire: "87", barrel: "1800", width: "3400", flange: "nope",
            freeSpace: "400", deadWraps: "3", firstLayerPull: "170"
        ) == nil)
        #expect(NamedWinchInputs.capture(
            wire: "87", barrel: "1800", width: "3400", flange: "4300",
            freeSpace: "400", deadWraps: "3", firstLayerPull: "nope"
        ) == nil)
    }

    // MARK: - WS-04 Empty

    @Test func ws04FreshStoreIsEmptyAndGarbageDoesNotCrash() {
        let (store, defaults) = freshStore()
        // Seed flag is already set, so an empty library stays empty.
        #expect(store.all().isEmpty)
        #expect(NamedWinchCopy.emptyTitle == "No saved winches yet")
        #expect(NamedWinchCopy.emptyBody == "Tap Save on the Winch capacity form to keep a named set of inputs on this device.")

        defaults.set(Data("nope".utf8), forKey: NamedWinchPresetStore.storageKey)
        #expect(NamedWinchPresetStore(defaults: defaults).all().isEmpty)

        defaults.set(Data("[]".utf8), forKey: NamedWinchPresetStore.storageKey)
        #expect(NamedWinchPresetStore(defaults: defaults).all().isEmpty)
    }

    // MARK: - WS-05 / WS-06 Chip

    @Test func ws05ClearChipDropsTheNameOnly() {
        var state = NamedWinchLoadState()
        state.show(name: "A-frame port", fields: "87|1800|3400")
        #expect(state.loadedName == "A-frame port")
        state.clearChip()
        #expect(state.loadedName == nil)
    }

    @Test func ws06EditingAFieldClearsTheChip() {
        var state = NamedWinchLoadState()
        state.show(name: "A-frame port", fields: "87|1800|3400")
        state.fieldsChanged(to: "87|1800|3400")
        #expect(state.loadedName == "A-frame port")
        state.fieldsChanged(to: "76|1800|3400")
        #expect(state.loadedName == nil)
        state.fieldsChanged(to: "87|1800|3400")
        #expect(state.loadedName == nil)
    }

    @Test func applyingTheSameSnapshotKeepsTheChip() {
        var state = NamedWinchLoadState()
        state.fieldsChanged(to: "87|1800")
        #expect(state.loadedName == nil)
        state.show(name: "A-frame port", fields: "76|1400")
        state.fieldsChanged(to: "76|1400")
        #expect(state.loadedName == "A-frame port")
    }

    // MARK: - WS-07 Persist

    @Test func ws07RelaunchOnTheSameDefaultsListsPresets() {
        let (store, defaults) = freshStore()
        #expect(NamedWinchPresetStore.storageKey == "namedWinchPresets.v1")
        store.save(name: "A-frame port", inputs: aFrame(), at: t0)
        store.save(name: "T/W starboard", inputs: starboard(), at: t1)

        let relaunch = NamedWinchPresetStore(defaults: defaults)
        #expect(relaunch.all().map(\.name) == ["T/W starboard", "A-frame port"])
        #expect(relaunch.all().first?.inputs == starboard())
        #expect(relaunch.all().last?.inputs == aFrame())
        #expect(relaunch.all().first?.updatedAt == t1)

        var noPull = aFrame()
        noPull.firstLayerPullTonnes = nil
        store.save(name: "No pull", inputs: noPull, at: t2)
        let again = NamedWinchPresetStore(defaults: defaults)
        #expect(again.all().first?.name == "No pull")
        #expect(again.all().first?.firstLayerPullTonnes == nil)
        #expect(again.all().count == 3)
    }

    @Test func listSortsMostRecentlyUpdatedFirst() {
        let (store, _) = freshStore()
        store.save(name: "Port tugger", inputs: aFrame(wire: 52, barrel: 900, width: 1600, flange: 2200), at: t0)
        store.save(name: "A-frame port", inputs: aFrame(), at: t1)
        #expect(store.all().map(\.name) == ["A-frame port", "Port tugger"])
        store.save(name: "Port tugger", inputs: aFrame(wire: 52, barrel: 900, width: 1600, flange: 2200, pull: 40), at: t2)
        #expect(store.all().map(\.name) == ["Port tugger", "A-frame port"])
    }

    // MARK: - Copy and summary

    @Test func dimsSummaryUsesSpaceGroupedThousands() {
        let a = NamedWinchPreset(name: "A-frame port", inputs: aFrame(), updatedAt: t0)
        let tw = NamedWinchPreset(name: "T/W starboard", inputs: aFrame(wire: 76, barrel: 1400, width: 2000, flange: 3600), updatedAt: t0)
        let tug = NamedWinchPreset(name: "Port tugger", inputs: aFrame(wire: 52, barrel: 900, width: 1600, flange: 2200), updatedAt: t0)
        #expect(a.dimsSummary == "d 87 \u{00B7} D0 1 800 \u{00B7} W 3 400 \u{00B7} Df 4 300")
        #expect(tw.dimsSummary == "d 76 \u{00B7} D0 1 400 \u{00B7} W 2 000 \u{00B7} Df 3 600")
        #expect(tug.dimsSummary == "d 52 \u{00B7} D0 900 \u{00B7} W 1 600 \u{00B7} Df 2 200")
    }

    @Test func trimmedNameOf64CharactersSavesAnd65IsRejected() {
        let (store, _) = freshStore()
        let sixtyFour = String(repeating: "A", count: 64)
        let sixtyFive = String(repeating: "B", count: 65)
        #expect(NamedWinchPresetStore.maxNameLength == 64)
        #expect(store.match(name: "  \(sixtyFour)  ") == .available(trimmed: sixtyFour))

        let saved = store.save(name: "  \(sixtyFour)  ", inputs: aFrame(), at: t0)
        #expect(saved?.name == sixtyFour)
        #expect(saved?.name.count == 64)
        #expect(store.all().count == 1)

        #expect(store.match(name: sixtyFive) == .tooLong)
        #expect(store.match(name: "  \(sixtyFive)  ") == .tooLong)
        #expect(store.save(name: sixtyFive, inputs: starboard(), at: t1) == nil)
        #expect(store.all().count == 1)
        #expect(store.all().first?.name == sixtyFour)
        #expect(store.all().first?.inputs == aFrame())
        #expect(store.all().first?.updatedAt == t0)

        let accented = String(repeating: "é", count: 64)
        #expect(store.save(name: accented, inputs: starboard(), at: t1)?.name == accented)
        #expect(store.save(name: accented + "é", inputs: aFrame(), at: t2) == nil)
        #expect(store.all().count == 2)
        #expect(store.all().first { $0.name == accented }?.inputs == starboard())
    }

    @Test func fiftyFirstNewPresetIsRefusedAndOverwriteStillWorks() {
        let (store, _) = freshStore()
        #expect(NamedWinchPresetStore.maxPresets == 50)
        for index in 1...NamedWinchPresetStore.maxPresets {
            let saved = store.save(
                name: "Winch \(index)",
                inputs: aFrame(wire: Double(index)),
                at: Date(timeIntervalSince1970: TimeInterval(index))
            )
            #expect(saved?.name == "Winch \(index)")
        }
        #expect(store.all().count == 50)
        #expect(store.match(name: "   ") == .empty)

        #expect(store.match(name: "Winch 51") == .libraryFull)
        #expect(store.save(name: "Winch 51", inputs: starboard(), at: t2) == nil)
        #expect(store.all().count == 50)
        #expect(store.all().contains { $0.name == "Winch 51" } == false)
        #expect(store.all().first { $0.name == "Winch 1" }?.wireDiameterMm == 1)
        #expect(store.all().first { $0.name == "Winch 1" }?.updatedAt == Date(timeIntervalSince1970: 1))

        // Length is checked before capacity, so a too-long name is not reported as a full library.
        #expect(store.match(name: String(repeating: "Z", count: 65)) == .tooLong)

        #expect(store.match(name: "winch 1") == .collision(existingDisplayName: "Winch 1"))
        let replaced = store.save(name: "winch 1", inputs: starboard(), at: t2)
        #expect(replaced?.name == "winch 1")
        #expect(replaced?.inputs == starboard())
        #expect(replaced?.updatedAt == t2)
        #expect(store.all().count == 50)
        #expect(store.all().contains { $0.name == "Winch 51" } == false)
        #expect(store.match(name: "A-frame port") == .libraryFull)
    }

    @Test func capCopyStatesTheLimits() {
        #expect(NamedWinchCopy.nameTooLong == "Name can be at most 64 characters.")
        #expect(NamedWinchCopy.libraryFull == "This device already has 50 saved winches. Save over an existing name to update it.")
    }

    @Test func ws08CopyMatchesLockedStrings() {
        #expect(NamedWinchCopy.navTitle == "Winch capacity")
        #expect(NamedWinchCopy.load == "Load")
        #expect(NamedWinchCopy.save == "Save")
        #expect(NamedWinchCopy.loaded == "Loaded")
        #expect(NamedWinchCopy.saveTitle == "Save winch")
        #expect(NamedWinchCopy.loadTitle == "Load winch")
        #expect(NamedWinchCopy.namePlaceholder == "A-frame port")
        #expect(NamedWinchCopy.saveCaption == "Saves the input values on this device. Not shared.")
        #expect(NamedWinchCopy.replaceTitle("A-frame") == "Replace \u{201C}A-frame\u{201D}?")
        #expect(NamedWinchCopy.replaceBody == "A winch with this name already exists. Replace it with the current values?")
        #expect(NamedWinchCopy.cancel == "Cancel")
        #expect(NamedWinchCopy.replace == "Replace")
        #expect(NamedWinchCopy.emptyTitle == "No saved winches yet")
        #expect(NamedWinchCopy.emptyBody == "Tap Save on the Winch capacity form to keep a named set of inputs on this device.")
        #expect(NamedWinchCopy.aid == "Aid for deck estimates. Not a class or maker rating.")
        for line in NamedWinchCopy.lockedStrings {
            #expect(!line.localizedCaseInsensitiveContains("safe"))
            #expect(!line.localizedCaseInsensitiveContains("ok to lift"))
        }
    }

    // MARK: - Salt 200 seed (S200)

    private let salt200Names = [
        "Salt 200 \u{00B7} AH",
        "Salt 200 \u{00B7} T/W STBD",
        "Salt 200 \u{00B7} T/W PORT",
        "Salt 200 \u{00B7} Secondary"
    ]

    /// Max spool weight 200 t on the secondary drum is not a Soft A field.
    /// T/W starboard and port 170 t are inferred. AH pull stays unset.
    @Test func s20001EmptyUnseededLibraryWritesTheFourSalt200Drums() {
        #expect(NamedWinchPresetStore.factorySeedKey == "namedWinchPresets.factorySeeded.v1")
        #expect(NamedWinchSeed.presets.map(\.name) == salt200Names)

        let (store, defaults, _) = unseededStore()
        #expect(defaults.bool(forKey: NamedWinchPresetStore.factorySeedKey) == false)

        let listed = store.loadList()
        #expect(listed.map(\.name) == salt200Names)
        #expect(store.all().map(\.name) == salt200Names)
        #expect(defaults.bool(forKey: NamedWinchPresetStore.factorySeedKey))
        #expect(store.all().count == 4)

        let ah = listed[0]
        #expect(ah.name == "Salt 200 \u{00B7} AH")
        #expect(ah.wireDiameterMm == 87)
        #expect(ah.barrelDiameterMm == 2500)
        #expect(ah.drumWidthMm == 9620)
        #expect(ah.flangeDiameterMm == 5050)
        #expect(ah.freeSpaceMm == 400)
        #expect(ah.deadWraps == 3)
        #expect(ah.deadWraps == WinchCapacityMath.defaultDeadWraps)
        #expect(ah.firstLayerPullTonnes == nil)
        #expect(ah.inputs.fieldText.firstLayerPull == "")
        #expect(ah.inputs.fieldText == NamedWinchFieldText(
            wire: "87", barrel: "2500", width: "9620", flange: "5050",
            freeSpace: "400", deadWraps: "3", firstLayerPull: ""
        ))
        #expect(ah.dimsSummary == "d 87 \u{00B7} D0 2 500 \u{00B7} W 9 620 \u{00B7} Df 5 050")
        #expect(ah.inputs == NamedWinchSeed.ah.inputs)

        let stbd = listed[1]
        #expect(stbd.name == "Salt 200 \u{00B7} T/W STBD")
        #expect(stbd.wireDiameterMm == 87)
        #expect(stbd.barrelDiameterMm == 1800)
        #expect(stbd.drumWidthMm == 3400)
        #expect(stbd.flangeDiameterMm == 4300)
        #expect(stbd.freeSpaceMm == 400)
        #expect(stbd.deadWraps == 3)
        #expect(stbd.firstLayerPullTonnes == 170)
        #expect(stbd.dimsSummary == "d 87 \u{00B7} D0 1 800 \u{00B7} W 3 400 \u{00B7} Df 4 300")

        let port = listed[2]
        #expect(port.name == "Salt 200 \u{00B7} T/W PORT")
        #expect(port.wireDiameterMm == 87)
        #expect(port.barrelDiameterMm == 1800)
        #expect(port.drumWidthMm == 2100)
        #expect(port.flangeDiameterMm == 4300)
        #expect(port.freeSpaceMm == 400)
        #expect(port.deadWraps == 3)
        #expect(port.firstLayerPullTonnes == 170)
        #expect(port.dimsSummary == "d 87 \u{00B7} D0 1 800 \u{00B7} W 2 100 \u{00B7} Df 4 300")

        let secondary = listed[3]
        #expect(secondary.name == "Salt 200 \u{00B7} Secondary")
        #expect(secondary.wireDiameterMm == 87)
        #expect(secondary.barrelDiameterMm == 1500)
        #expect(secondary.drumWidthMm == 4800)
        #expect(secondary.flangeDiameterMm == 4500)
        #expect(secondary.freeSpaceMm == 400)
        #expect(secondary.deadWraps == 3)
        #expect(secondary.firstLayerPullTonnes == 170)
        #expect(secondary.inputs.fieldText.firstLayerPull == "170")
        #expect(secondary.dimsSummary == "d 87 \u{00B7} D0 1 500 \u{00B7} W 4 800 \u{00B7} Df 4 500")

        let relaunch = NamedWinchPresetStore(defaults: defaults)
        #expect(relaunch.all().map(\.id) == listed.map(\.id))
        #expect(relaunch.all().first?.firstLayerPullTonnes == nil)
        #expect(relaunch.loadList().count == 4)
    }

    @Test func matchAndSaveOnAnUnseededLibrarySeedFirst() {
        let (matched, matchedDefaults, _) = unseededStore()
        #expect(matched.match(name: "Port tugger") == .available(trimmed: "Port tugger"))
        #expect(matchedDefaults.bool(forKey: NamedWinchPresetStore.factorySeedKey))
        #expect(matched.all().map(\.name) == salt200Names)

        let (savedStore, _, _) = unseededStore()
        let saved = savedStore.save(
            name: "Port tugger",
            inputs: aFrame(wire: 52, barrel: 900, width: 1600, flange: 2200, pull: 40),
            at: t0
        )
        #expect(saved?.name == "Port tugger")
        #expect(savedStore.all().count == 5)
        #expect(savedStore.all().filter { salt200Names.contains($0.name) }.count == 4)
    }

    @Test func s20002DeletingTheSeededRowsDoesNotReinject() {
        let (store, defaults, _) = unseededStore()
        #expect(store.all().map(\.name) == salt200Names)

        defaults.set(Data("[]".utf8), forKey: NamedWinchPresetStore.storageKey)
        #expect(defaults.bool(forKey: NamedWinchPresetStore.factorySeedKey))

        let reopen = NamedWinchPresetStore(defaults: defaults)
        #expect(reopen.all().isEmpty)
        #expect(reopen.loadList().isEmpty)
        #expect(reopen.match(name: "Salt 200 \u{00B7} AH") == .available(trimmed: "Salt 200 \u{00B7} AH"))
    }

    @Test func wipingUserDefaultsIncludingTheSeedFlagSeedsAgain() {
        let (store, defaults, suite) = unseededStore()
        _ = store.all()
        var edited = NamedWinchSeed.ah.inputs
        edited.drumWidthMm = 1111
        store.save(name: "Salt 200 \u{00B7} AH", inputs: edited, at: t1)
        #expect(store.all().first { $0.name == "Salt 200 \u{00B7} AH" }?.drumWidthMm == 1111)

        defaults.removePersistentDomain(forName: suite)
        defaults.removeObject(forKey: NamedWinchPresetStore.storageKey)
        defaults.removeObject(forKey: NamedWinchPresetStore.factorySeedKey)
        let wiped = UserDefaults(suiteName: suite)!
        let again = NamedWinchPresetStore(defaults: wiped)
        #expect(again.loadList().map(\.name) == salt200Names)
        #expect(again.all().first { $0.name == "Salt 200 \u{00B7} AH" }?.drumWidthMm == 9620)
        #expect(again.all().first { $0.name == "Salt 200 \u{00B7} AH" }?.firstLayerPullTonnes == nil)
        #expect(wiped.bool(forKey: NamedWinchPresetStore.factorySeedKey))
    }

    @Test func s20006NonEmptyLibrarySkipsSeedAndStaysSkippedAfterClear() {
        let (store, defaults) = freshStore()
        let tug = aFrame(wire: 52, barrel: 900, width: 1600, flange: 2200, pull: 40)
        let saved = store.save(name: "Port tugger", inputs: tug, at: t0)
        defaults.removeObject(forKey: NamedWinchPresetStore.factorySeedKey)

        let opened = NamedWinchPresetStore(defaults: defaults)
        #expect(opened.all().count == 1)
        #expect(opened.all().first == saved)
        #expect(opened.loadList().map(\.name) == ["Port tugger"])
        #expect(defaults.bool(forKey: NamedWinchPresetStore.factorySeedKey))

        defaults.set(Data("[]".utf8), forKey: NamedWinchPresetStore.storageKey)
        #expect(opened.all().isEmpty)
        #expect(opened.loadList().isEmpty)
        #expect(NamedWinchPresetStore(defaults: defaults).all().isEmpty)
    }

    @Test func s20005OverwriteSalt200AHReplacesTheOneRow() {
        let (store, _, _) = unseededStore()
        _ = store.all()
        let original = store.all().first { $0.name == "Salt 200 \u{00B7} AH" }
        var edited = NamedWinchSeed.ah.inputs
        edited.drumWidthMm = 1000

        #expect(store.match(name: "Salt 200 \u{00B7} AH") == .collision(existingDisplayName: "Salt 200 \u{00B7} AH"))
        let replaced = store.save(name: "salt 200 \u{00B7} ah", inputs: edited, at: t1)

        #expect(replaced?.id == original?.id)
        #expect(replaced?.name == "salt 200 \u{00B7} ah")
        #expect(replaced?.drumWidthMm == 1000)
        #expect(replaced?.firstLayerPullTonnes == nil)
        let ahRows = store.all().filter {
            NamedWinchPresetStore.nameKey($0.name) == NamedWinchPresetStore.nameKey("Salt 200 \u{00B7} AH")
        }
        #expect(ahRows.count == 1)
        #expect(ahRows.first?.inputs == edited)
        #expect(store.all().count == 4)
        #expect(store.all().contains { $0.name == "Salt 200 \u{00B7} T/W STBD" })
        #expect(store.all().first { $0.name == "Salt 200 \u{00B7} Secondary" }?.firstLayerPullTonnes == 170)
    }

    @Test func seedInsertSkipsAnExistingNameAndStopsAtFifty() {
        let custom = NamedWinchPreset(
            name: "salt 200 \u{00B7} ah",
            inputs: aFrame(width: 111, pull: nil),
            updatedAt: t0
        )
        let merged = NamedWinchSeed.inserting(into: [custom])
        #expect(merged.count == 4)
        #expect(merged.first?.name == "salt 200 \u{00B7} ah")
        #expect(merged.first?.drumWidthMm == 111)
        #expect(merged.first?.firstLayerPullTonnes == nil)
        let ahKeys = merged.filter {
            NamedWinchPresetStore.nameKey($0.name) == NamedWinchPresetStore.nameKey("Salt 200 \u{00B7} AH")
        }
        #expect(ahKeys.count == 1)

        let fillers = (1...49).map { index in
            NamedWinchPreset(
                name: "Winch \(index)",
                inputs: aFrame(wire: Double(index)),
                updatedAt: t0
            )
        }
        let capped = NamedWinchSeed.inserting(into: fillers)
        #expect(capped.count == 50)
        #expect(capped.contains { $0.name == "Salt 200 \u{00B7} AH" })
        #expect(capped.contains { $0.name == "Salt 200 \u{00B7} T/W STBD" } == false)
        #expect(NamedWinchSeed.inserting(into: capped).count == 50)
    }

    @Test func fullLibraryDoesNotGainSeedRowsWhenTheFlagIsCleared() {
        let (store, defaults) = freshStore()
        for index in 1...NamedWinchPresetStore.maxPresets {
            store.save(
                name: "Winch \(index)",
                inputs: aFrame(wire: Double(index)),
                at: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }
        defaults.removeObject(forKey: NamedWinchPresetStore.factorySeedKey)
        #expect(store.all().count == 50)
        #expect(store.loadList().count == 50)
        #expect(store.all().contains { $0.name == "Salt 200 \u{00B7} AH" } == false)
        #expect(defaults.bool(forKey: NamedWinchPresetStore.factorySeedKey))
        #expect(store.match(name: "Salt 200 \u{00B7} Secondary") == .libraryFull)
        #expect(store.save(name: "Salt 200 \u{00B7} Secondary", inputs: starboard(), at: t2) == nil)
        #expect(store.all().count == 50)
    }

    @Test func s20007SeedNamesAddNoExtraChrome() {
        #expect(NamedWinchCopy.aid == "Aid for deck estimates. Not a class or maker rating.")
        for name in salt200Names {
            #expect(name.contains("\u{00B7}"))
            #expect(!name.localizedCaseInsensitiveContains("tor viking"))
            #expect(!name.localizedCaseInsensitiveContains("safe"))
            #expect(!name.localizedCaseInsensitiveContains("ok to lift"))
        }
    }
}
