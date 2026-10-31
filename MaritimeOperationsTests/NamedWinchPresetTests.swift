import Foundation
import Testing
@testable import MaritimeOperations

/// Named winch presets (Soft A). Store behaviour behind WS-01…WS-04, WS-02a, and WS-07.
struct NamedWinchPresetTests {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private let t1 = Date(timeIntervalSince1970: 1_700_000_100)
    private let t2 = Date(timeIntervalSince1970: 1_700_000_200)

    private func freshStore() -> (NamedWinchPresetStore, UserDefaults) {
        let name = "NamedWinchPresetTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (NamedWinchPresetStore(defaults: defaults), defaults)
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
}
