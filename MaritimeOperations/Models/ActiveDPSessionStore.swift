import Foundation
import Observation

/// Persists `startedAt` so elapsed time survives backgrounding and kill/relaunch.
@Observable
@MainActor
final class ActiveDPSessionStore {
    private static let startedAtKey = "activeDPSession.startedAt"
    private static let vesselKey = "activeDPSession.vessel"
    private static let rigKey = "activeDPSession.rig"
    private static let vesselTypeKey = "activeDPSession.vesselType"
    private static let dpClassKey = "activeDPSession.dpClass"

    var startedAt: Date? {
        didSet { persist() }
    }

    var vessel: String = "Vessel" {
        didSet { UserDefaults.standard.set(vessel, forKey: Self.vesselKey) }
    }

    var rig: String = "" {
        didSet { UserDefaults.standard.set(rig, forKey: Self.rigKey) }
    }

    var vesselType: String = "AH" {
        didSet { UserDefaults.standard.set(vesselType, forKey: Self.vesselTypeKey) }
    }

    var dpClass: String = "Class 2" {
        didSet { UserDefaults.standard.set(dpClass, forKey: Self.dpClassKey) }
    }

    var isRunning: Bool { startedAt != nil }

    init() {
        let defaults = UserDefaults.standard
        if let interval = defaults.object(forKey: Self.startedAtKey) as? Double {
            startedAt = Date(timeIntervalSince1970: interval)
        }
        vessel = defaults.string(forKey: Self.vesselKey) ?? "Vessel"
        rig = defaults.string(forKey: Self.rigKey) ?? ""
        vesselType = defaults.string(forKey: Self.vesselTypeKey) ?? "AH"
        dpClass = defaults.string(forKey: Self.dpClassKey) ?? "Class 2"
    }

    func start(at date: Date = .now) {
        startedAt = date
    }

    func clear() {
        startedAt = nil
        UserDefaults.standard.removeObject(forKey: Self.startedAtKey)
    }

    func elapsed(at now: Date = .now) -> TimeInterval {
        guard let startedAt else { return 0 }
        return max(0, now.timeIntervalSince(startedAt))
    }

    private func persist() {
        if let startedAt {
            UserDefaults.standard.set(startedAt.timeIntervalSince1970, forKey: Self.startedAtKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.startedAtKey)
        }
    }
}
