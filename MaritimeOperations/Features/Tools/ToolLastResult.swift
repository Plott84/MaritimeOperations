import Foundation

/// Which tool a saved "last result" belongs to. Raw values are the UserDefaults key suffix.
enum ToolLastResultKind: String, CaseIterable, Sendable {
    case gyro, compassError, catenary, winch, chainLocker, craneHeel, portUnlocode
}

/// One short status line per tool, shown under the row on the Tools tab.
/// Stored on this device only (UserDefaults). Written only when a valid result is shown.
struct ToolLastResult: Codable, Equatable, Sendable {
    var summary: String
    var date: Date
}

struct ToolLastResultStore {
    /// Sentinel when nothing is saved. The Tools list shows a per-tool blurb instead of this string.
    static let notUsed = "Not used yet"
    static let keyPrefix = "toolLastResult."
    /// Posted after a save so the Tools tab can refresh (a tool's onDisappear can run after the list's onAppear).
    static let didChange = Notification.Name("ToolLastResultStore.didChange")

    var defaults: UserDefaults = .standard

    func save(_ summary: String, for kind: ToolLastResultKind, date: Date = .now) {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return } // never overwrite a good value with nothing
        let value = ToolLastResult(summary: trimmed, date: date)
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: Self.keyPrefix + kind.rawValue)
        NotificationCenter.default.post(name: Self.didChange, object: nil)
    }

    func load(for kind: ToolLastResultKind) -> ToolLastResult? {
        guard let data = defaults.data(forKey: Self.keyPrefix + kind.rawValue) else { return nil }
        return try? JSONDecoder().decode(ToolLastResult.self, from: data)
    }

    func status(for kind: ToolLastResultKind) -> String {
        load(for: kind)?.summary ?? Self.notUsed
    }

    func clear(_ kind: ToolLastResultKind) {
        defaults.removeObject(forKey: Self.keyPrefix + kind.rawValue)
    }

    // MARK: Summary text (pure, testable)

    /// "+1.2°" / "−0.8°" / "0.0°"
    static func signedDegrees(_ v: Double) -> String {
        let r = (v * 10).rounded() / 10
        let mag = String(format: "%.1f°", abs(r))
        if r == 0 { return mag }
        return (r > 0 ? "+" : "−") + mag
    }

    static func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.setLocalizedDateFormatFromTemplate("d MMM")
        return f.string(from: date)
    }

    static func gyroSummary(error: Double, date: Date = .now) -> String {
        "Last gyro \(signedDegrees(error)) · \(shortDate(date))"
    }

    /// Which tab's valid result is written to the single Gyro & Compass row.
    /// An empty tab does not replace a result the other tab already has — the caller skips a nil.
    enum GyroCompassTab: String, Sendable {
        case gyro, compass
    }

    static func summaryToSave(tab: GyroCompassTab, gyro: String?, compass: String?) -> String? {
        switch tab {
        case .gyro: return gyro
        case .compass: return compass
        }
    }
}
