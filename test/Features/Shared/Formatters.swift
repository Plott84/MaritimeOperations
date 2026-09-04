import Foundation

enum AppFormatters {
    static let durationHours: MeasurementFormatter = {
        let f = MeasurementFormatter()
        f.unitStyle = .short
        f.numberFormatter.maximumFractionDigits = 1
        f.numberFormatter.minimumFractionDigits = 0
        return f
    }()

    static func hoursString(_ hours: Double) -> String {
        let nf = NumberFormatter()
        nf.maximumFractionDigits = 1
        nf.minimumFractionDigits = 0
        nf.decimalSeparator = Locale.current.decimalSeparator
        let value = nf.string(from: NSNumber(value: hours)) ?? String(format: "%.1f", hours)
        return "\(value) h"
    }

    static func timerString(from interval: TimeInterval) -> String {
        let total = Int(interval.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static let activityDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}
