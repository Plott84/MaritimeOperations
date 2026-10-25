import SwiftUI

/// Gyro tab of Gyro & Compass. Transit / Azimuth / Amplitude. Maths: `GyroMath`.
struct GyroCheckToolView: View {
    @Bindable var model: GyroCheckModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ToolSegmentBar(
                title: "Gyro method",
                barIdentifier: "gyro.method",
                selection: $model.mode,
                options: GyroCheckModel.Mode.allCases.map { mode in
                    ToolSegmentOption(
                        value: mode,
                        title: mode.rawValue,
                        accessibilityLabel: "Gyro method, \(mode.rawValue)",
                        accessibilityIdentifier: "gyro.method.\(mode.rawValue)"
                    )
                }
            )
            GlassCard { inputs }
            resultCard
        }
    }

    private var showsGoldFlag: Bool {
        if case .result(_, let err, _) = model.outcome { return err.flagged }
        return false
    }

    @ViewBuilder
    private var inputs: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionCaption("INPUTS")
            switch model.mode {
            case .azimuth:
                SharedLatDecFields(
                    position: model.position,
                    declinationMax: 90,
                    latitudeIdentifier: "gyro.latitude",
                    declinationIdentifier: "gyro.declination",
                    latitudeError: model.latitudeError,
                    declinationError: model.declinationError
                )
                ToolNumberField(
                    title: "LHA",
                    text: $model.lha,
                    placeholder: "045.0",
                    unit: "°",
                    systemImage: "clock",
                    fieldAccessibilityIdentifier: "gyro.lha"
                )
            case .amplitude:
                SharedLatDecFields(
                    position: model.position,
                    declinationMax: 90,
                    latitudeIdentifier: "gyro.latitude",
                    declinationIdentifier: "gyro.declination",
                    latitudeError: model.latitudeError,
                    declinationError: model.declinationError
                )
                ToolSegmentBar(
                    title: "Rising or setting",
                    barIdentifier: "gyro.event",
                    selection: $model.event,
                    options: GyroMath.SunEvent.allCases.map { event in
                        ToolSegmentOption(
                            value: event,
                            title: event.rawValue,
                            accessibilityLabel: "Rising or setting, \(event.rawValue)",
                            accessibilityIdentifier: "gyro.event.\(event.rawValue)"
                        )
                    }
                )
            case .transit:
                ToolNumberField(
                    title: "Charted true bearing",
                    text: $model.chartedTrue,
                    placeholder: "047.5",
                    unit: "°T",
                    systemImage: "location.north.line",
                    fieldAccessibilityIdentifier: "gyro.charted"
                )
            }
            ToolNumberField(
                title: "Gyro bearing observed",
                text: $model.gyro,
                placeholder: "046.8",
                unit: "°G",
                systemImage: "gyroscope",
                fieldAccessibilityIdentifier: "gyro.bearing"
            )
        }
    }

    private var resultCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionCaption("RESULT")
                switch model.outcome {
                case .incomplete:
                    ToolResultHero(caption: "TRUE BEARING", value: ToolsParse.dash)
                    Text(GyroCompassCopy.gyroEmpty)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                case .refused(let reason):
                    ToolResultHero(caption: "TRUE BEARING", value: ToolsParse.dash)
                    Label(reason, systemImage: "nosign")
                        .font(.body)
                        .foregroundStyle(AppTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                case .result(let zn, let err, let hc):
                    VStack(alignment: .leading, spacing: 12) {
                        ToolResultHero(caption: "TRUE BEARING", value: GyroMath.bearingDisplay(zn))
                        HStack {
                            Text("Gyro error")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                            Spacer()
                            Text(err.display)
                                .font(.title2.weight(.semibold).monospacedDigit())
                                .foregroundStyle(err.flagged ? AppTheme.gold : AppTheme.textPrimary)
                                .accessibilityIdentifier("gyro.error")
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(GyroMath.spokenResult(trueBearing: zn, error: err))
                    .accessibilityIdentifier("gyro.hero")
                    if let hc {
                        ToolResultRow(
                            title: "Hc",
                            value: (hc < 0 ? "−" : "") + GyroMath.dmDisplay(hc)
                        )
                        .accessibilityIdentifier("gyro.hc")
                    }
                    if err.flagged {
                        Label("Investigate: error over 1.0°", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundStyle(AppTheme.gold)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("gyro.flag")
                    }
                    if model.mode == .amplitude {
                        Text("Sun's centre on the celestial horizon")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text(GyroCompassCopy.liveNote)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay {
            if showsGoldFlag {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(AppTheme.gold, lineWidth: 1.5)
            }
        }
    }

    private func sectionCaption(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .tracking(1.1)
            .foregroundStyle(AppTheme.teal)
    }
}
