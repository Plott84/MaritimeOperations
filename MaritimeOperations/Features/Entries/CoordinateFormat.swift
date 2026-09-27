import Foundation
import CoreLocation

enum CoordinateFormat {
    /// N/S xx° xx.x'
    static func latitude(_ degrees: Double) -> String {
        hemisphere(degrees, positive: "N", negative: "S", degreeWidth: 2)
    }

    /// E/W xxx° xx.x'
    static func longitude(_ degrees: Double) -> String {
        hemisphere(degrees, positive: "E", negative: "W", degreeWidth: 3)
    }

    private static func hemisphere(_ degrees: Double, positive: String, negative: String, degreeWidth: Int) -> String {
        let sign = degrees >= 0 ? positive : negative
        let absValue = abs(degrees)
        let deg = Int(absValue)
        let minutes = (absValue - Double(deg)) * 60
        return String(format: "%@ %0*d° %04.1f'", sign, degreeWidth, deg, minutes)
    }
}

@MainActor
final class WhenInUseLocation: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var onFix: ((CLLocation) -> Void)?
    var onDenied: (() -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func request() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            onDenied?()
        @unknown default:
            onDenied?()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                onDenied?()
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            onFix?(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            onDenied?()
        }
    }
}
