import Foundation
import Observation

/// Latitude and declination shared by the Gyro and Compass tabs.
/// Method fields (LHA, bearings, event, variation) stay on their own model.
@Observable
final class LatDecDraft {
    enum NS: String, CaseIterable, Identifiable, Hashable {
        case n = "N"
        case s = "S"
        var id: String { rawValue }
    }

    var latDeg = ""
    var latMin = ""
    var latNS: NS = .n
    var decDeg = ""
    var decMin = ""
    var decNS: NS = .n
}
