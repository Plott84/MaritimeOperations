import SwiftUI

/// Compass tab of Gyro & Compass: sun amplitude only. Maths: `AmplitudeMath`.
struct CompassErrorToolView: View {
    @Bindable var model: CompassErrorModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassCard { observation }
            resultSection
            GlassCard {
                Text(GyroCompassCopy.compassNote)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("compassError.note")
            }
        }
    }

    private var observation: some View {
        VStack(alignment: .leading, spacing: 14) {
            caption("OBSERVATION")
            Text(GyroCompassCopy.compassSubtitle)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("compassError.subtitle")
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Event")
                ToolSegmentBar(
                    title: "Event",
                    barIdentifier: "compassError.event",
                    selection: $model.event,
                    options: AmplitudeMath.Event.allCases.map { event in
                        ToolSegmentOption(
                            value: event,
                            title: event.rawValue,
                            accessibilityLabel: "Event, \(event.rawValue)",
                            accessibilityIdentifier: "compassError.event.\(event.rawValue)"
                        )
                    }
                )
            }
            SharedLatDecFields(
                position: model.position,
                declinationMax: CompassErrorModel.maxDeclination,
                latitudeIdentifier: "compassError.latitude",
                declinationIdentifier: "compassError.declination",
                latitudeError: errorField == .latitude ? errorReason : nil,
                declinationError: errorField == .declination ? errorReason : nil
            )
            ToolNumberField(
                title: "Compass bearing",
                text: $model.compass,
                placeholder: "049.0",
                unit: "°C",
                isError: errorField == .compass,
                errorReason: errorReason,
                accessibilityName: compassA11yLabel,
                fieldAccessibilityIdentifier: "compassError.compass",
                systemImage: "safari"
            )
            ToolNumberField(
                title: "Variation",
                text: $model.variation,
                placeholder: "For deviation",
                unit: "°",
                isError: errorField == .variation,
                errorReason: errorReason,
                accessibilityName: "Variation, optional",
                fieldAccessibilityIdentifier: "compassError.variation",
                systemImage: "arrow.left.and.right",
                titleNote: "optional"
            )
            ToolSegmentBar(
                title: "Variation name",
                barIdentifier: "compassError.varEW",
                selection: $model.varEW,
                options: [
                    ToolSegmentOption(value: CompassErrorModel.EW.e, title: "E", accessibilityLabel: "Variation name, East", accessibilityIdentifier: "compassError.varEW.E"),
                    ToolSegmentOption(value: CompassErrorModel.EW.w, title: "W", accessibilityLabel: "Variation name, West", accessibilityIdentifier: "compassError.varEW.W")
                ]
            )
        }
    }

    private var errorField: CompassErrorModel.Field? {
        if case .invalid(let field, _) = model.outcome { return field }
        return nil
    }

    private var errorReason: String? {
        if case .invalid(_, let reason) = model.outcome { return reason }
        return nil
    }

    @ViewBuilder
    private var resultSection: some View {
        switch model.outcome {
        case .polar:
            VStack(alignment: .leading, spacing: 10) {
                Label("NO RESULT", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(AppTheme.gold)
                Text(GyroCompassCopy.polarBody)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(GyroCompassCopy.polarHelper)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(AppTheme.card))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(AppTheme.gold, lineWidth: 1.5))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("compassError.polar")
        default:
            GlassCard { resultCard }
        }
    }

    @ViewBuilder
    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            caption("RESULT")
            if case .result(let r) = model.outcome {
                ToolResultHero(caption: "compass error", value: AmplitudeMath.eastWest(r.error))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        AmplitudeMath.spokenCompassResult(
                            error: r.error, trueBearing: r.trueBearing, compassBearing: r.compassBearing
                        )
                    )
                    .accessibilityIdentifier("compassError.hero")
                ToolResultRow(title: "Amplitude", value: AmplitudeMath.amplitudeText(r.amplitude, event: model.event))
                    .accessibilityIdentifier("compassError.amplitude")
                ToolResultRow(title: "True", value: AmplitudeMath.bearing(r.trueBearing, letter: "T"))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("True \(AmplitudeMath.spokenBearing(r.trueBearing, kind: "true"))")
                    .accessibilityIdentifier("compassError.trueBearing")
                ToolResultRow(title: "Compass", value: AmplitudeMath.bearing(r.compassBearing, letter: "C"))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Compass \(AmplitudeMath.spokenBearing(r.compassBearing, kind: "compass"))")
                    .accessibilityIdentifier("compassError.compassBearing")
                if let d = r.deviation {
                    ToolResultRow(title: "Deviation", value: AmplitudeMath.eastWest(d))
                        .accessibilityIdentifier("compassError.deviation")
                }
                Text(GyroCompassCopy.deviationNote)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ToolResultHero(caption: "compass error", value: ToolsParse.dash)
                Text(GyroCompassCopy.compassEmpty)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var compassA11yLabel: String {
        if let v = ToolsParse.double(model.compass), (0..<360).contains(v) {
            return AmplitudeMath.spokenBearing(v, kind: "compass")
        }
        return "Compass bearing"
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(.caption.weight(.bold)).tracking(1.1).foregroundStyle(AppTheme.teal)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(.caption.weight(.semibold)).tracking(0.6).foregroundStyle(AppTheme.textSecondary)
    }
}
