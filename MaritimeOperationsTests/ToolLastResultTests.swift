import Testing
import Foundation
@testable import MaritimeOperations

struct ToolLastResultTests {
    private func freshStore() -> (ToolLastResultStore, UserDefaults) {
        let name = "ToolLastResultTests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return (ToolLastResultStore(defaults: d), d)
    }

    @Test func defaultsToNotUsedYet() {
        let (store, _) = freshStore()
        for k in ToolLastResultKind.allCases {
            #expect(store.status(for: k) == "Not used yet")
            #expect(store.load(for: k) == nil)
        }
    }

    @Test func saveAndLoadPerTool() {
        let (store, d) = freshStore()
        let date = Date(timeIntervalSince1970: 1_760_000_000)
        store.save("Last: 2.2° W · true 046.8°", for: .compassError, date: date)
        #expect(store.status(for: .compassError) == "Last: 2.2° W · true 046.8°")
        #expect(store.load(for: .compassError)?.date == date)
        #expect(store.status(for: .gyro) == "Not used yet")
        // Persists across store instances on the same defaults
        #expect(ToolLastResultStore(defaults: d).status(for: .compassError) == "Last: 2.2° W · true 046.8°")
    }

    @Test func emptySummaryKeepsPrevious() {
        let (store, _) = freshStore()
        store.save("Last: 600 m wire · sag 41.3 m", for: .catenary)
        store.save("   ", for: .catenary)
        #expect(store.status(for: .catenary) == "Last: 600 m wire · sag 41.3 m")
        store.clear(.catenary)
        #expect(store.status(for: .catenary) == "Not used yet")
    }

    @Test func gyroSummaryFormat() {
        var c = DateComponents(); c.year = 2026; c.month = 10; c.day = 14; c.hour = 12
        let date = Calendar(identifier: .gregorian).date(from: c)!
        #expect(ToolLastResultStore.gyroSummary(error: 1.2, date: date) == "Last check +1.2° · 14 Oct")
        #expect(ToolLastResultStore.signedDegrees(-0.84) == "−0.8°")
        #expect(ToolLastResultStore.signedDegrees(0.04) == "0.0°")
    }
}
