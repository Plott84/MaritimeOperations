import SwiftUI

/// Compass error by the sun's amplitude (theoretical rise / set). Aid, not authority.
struct CompassErrorToolView: View {
    @State private var model = CompassErrorModel()
    private let store = ToolLastResultStore()

    init(model: CompassErrorModel = CompassErrorModel()) {
        _model = State(initialValue: model)
    }

    var body: some View {
        ZStack {
            AppCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GlassCard { observation }
                    resultSection
                    GlassCard {
                        Text("Theoretical rise or set (sun's centre on the celestial horizon). For a visible-horizon observation, the usual correction still applies.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("compassError.note")
                    }
                    Text("Aid, not authority. Use the ship's inclinometer and compass records.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("compassError.footer")
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Compass error")
        .navigationBarTitleDisplayMode(.inline)
        .systemGlassNavigation()
        .toolsKeyboardDone()
        .onDisappear {
            // Save once, on leaving, only if a valid result is on screen (not per keystroke).
            if let s = model.lastResultSummary { store.save(s, for: .compassError) }
        }
    }

    // MARK: Observation

    private var observation: some View {
        VStack(alignment: .leading, spacing: 14) {
            caption("OBSERVATION")
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Event")
                Picker("Event", selection: $model.event) {
                    ForEach(AmplitudeMath.Event.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("compassError.event")
            }
            ToolDegMinInput(
                title: "Latitude", degrees: $model.latDeg, minutes: $model.latMin,
                hemisphere: $model.latNS,
                hemispheres: [(.n, "N (north)"), (.s, "S (south)")],
                hemisphereLabel: "Latitude hemisphere",
                echo: model.latitudeEcho,
                errorReason: errorField == .latitude ? errorReason : nil,
                identifier: "compassError.latitude"
            )
            ToolDegMinInput(
                title: "Declination", degrees: $model.decDeg, minutes: $model.decMin,
                hemisphere: $model.decNS,
                hemispheres: [(.n, "N (north)"), (.s, "S (south)")],
                hemisphereLabel: "Declination name",
                echo: model.declinationEcho,
                errorReason: errorField == .declination ? errorReason : nil,
                identifier: "compassError.declination"
            )
            ToolNumberField(
                title: "Compass bearing", text: $model.compass, placeholder: "049.0", unit: "°C",
                isError: errorField == .compass, errorReason: errorReason,
                fieldAccessibilityIdentifier: "compassError.compass"
            )
            ToolNumberField(
                title: "Variation (optional)", text: $model.variation, placeholder: "For deviation", unit: "°",
                isError: errorField == .variation, errorReason: errorReason,
                accessibilityName: "Variation, optional",
                fieldAccessibilityIdentifier: "compassError.variation"
            )
            Picker("Variation name", selection: $model.varEW) {
                Text("E (east)").tag(CompassErrorModel.EW.e)
                Text("W (west)").tag(CompassErrorModel.EW.w)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Variation name")
            .accessibilityIdentifier("compassError.varEW")
        }
    }

    private var errorField: CompassErrorModel.Field? {
        if case .invalid(let f, _) = model.outcome { return f }
        return nil
    }

    private var errorReason: String? {
        if case .invalid(_, let r) = model.outcome { return r }
        return nil
    }

    // MARK: Result

    @ViewBuilder
    private var resultSection: some View {
        switch model.outcome {
        case .polar:
            VStack(alignment: .leading, spacing: 10) {
                Label("NO RESULT", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(AppTheme.gold)
                Text("Sun doesn't rise or set at this latitude and declination.")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Needs |sin dec ÷ cos lat| ≤ 1. Try a lower latitude or another day.")
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
                    .accessibilityLabel("Compass error \(spoken(r.error)). True bearing \(AmplitudeMath.bearing(r.trueBearing).replacingOccurrences(of: "°", with: "")) degrees.")
                    .accessibilityIdentifier("compassError.hero")
                ToolResultRow(title: "Amplitude", value: AmplitudeMath.amplitudeText(r.amplitude, event: model.event))
                ToolResultRow(title: "True bearing", value: AmplitudeMath.bearing(r.trueBearing))
                ToolResultRow(title: "Compass error", value: AmplitudeMath.eastWest(r.error))
                if let d = r.deviation {
                    ToolResultRow(title: "Deviation", value: AmplitudeMath.eastWest(d))
                        .accessibilityIdentifier("compassError.deviation")
                }
                Text("Deviation = error − variation. Error is East when true > compass.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ToolResultHero(caption: "compass error", value: ToolsParse.dash)
                Text("Enter latitude, declination and compass bearing")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func spoken(_ v: Double) -> String {
        let r = (abs(v) * 10).rounded() / 10
        let mag = String(format: "%.1f degrees", r)
        if r == 0 { return mag }
        return mag + (v > 0 ? " East" : " West")
    }

    private func caption(_ t: String) -> some View {
        Text(t).font(.caption.weight(.bold)).tracking(1.1).foregroundStyle(AppTheme.teal)
    }

    private func fieldLabel(_ t: String) -> some View {
        Text(t).font(.caption.weight(.semibold)).tracking(0.6).foregroundStyle(AppTheme.textSecondary)
    }
}
