import Foundation
import SwiftData

/// UI-test launch switches. Only honoured in DEBUG builds and only when a UI test passes
/// the argument, so a normal launch (and any Release build) always uses the real on-disk
/// store and the real saved timer.
///
/// - `-UITestResetState`: in-memory SwiftData store + clear this app's saved UserDefaults
///   (running DP timer, session fields, eligibility rule). Every UI test launches with this.
/// - `-UITestInMemoryStore`: in-memory store only, keeps UserDefaults. Used when a test
///   relaunches the app to check that a running timer survives.
enum LaunchEnvironment {
    static let resetStateArgument = "-UITestResetState"
    static let inMemoryStoreArgument = "-UITestInMemoryStore"

    static var resetsState: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains(resetStateArgument)
        #else
        false
        #endif
    }

    static var usesInMemoryStore: Bool {
        #if DEBUG
        resetsState || ProcessInfo.processInfo.arguments.contains(inMemoryStoreArgument)
        #else
        false
        #endif
    }

    /// Call once at startup, before any store reads UserDefaults.
    static func applyResetIfRequested() {
        guard resetsState, let domain = Bundle.main.bundleIdentifier else { return }
        UserDefaults.standard.removePersistentDomain(forName: domain)
    }

    static func makeModelContainer() -> ModelContainer {
        let schema = Schema([DPEntry.self, RigMove.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: usesInMemoryStore)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
