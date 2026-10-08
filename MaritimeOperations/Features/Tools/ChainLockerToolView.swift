import SwiftUI

struct ChainLockerToolView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case spaceNeeded = "Space needed"
        case lengthFits = "Length that fits"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .spaceNeeded
    @State private var diameterText = ""
    @State private var shotsText = ""
    @State private var shotLengthText = "27.5"
    @State private var volumeText = ""

    private enum Field { case diameter, shots, shotLength, volume }

    private struct Eval {
        var outcome: ChainLockerMath.Outcome?
        var errorField: Field?
        var errorReason: String?
    }

    private var eval: Eval {
        switch mode {
        case .spaceNeeded:
            guard let d = ToolsParse.double(diameterText),
                  let shots = ToolsParse.double(shotsText) else {
                return Eval(outcome: nil, errorField: nil, errorReason: nil)
            }
            let shotLen: Double
            let shotTrim = shotLengthText.trimmingCharacters(in: .whitespacesAndNewlines)
            if shotTrim.isEmpty {
                shotLen = ChainLockerMath.defaultShotLengthM
            } else if let v = ToolsParse.double(shotLengthText) {
                shotLen = v
            } else {
                return Eval(outcome: .invalid(reason: "Check shot length"), errorField: .shotLength, errorReason: "Check shot length")
            }

            let outcome = ChainLockerMath.volume(diameterMm: d, shots: shots, shotLengthM: shotLen)
            return mapOutcome(outcome)

        case .lengthFits:
            guard let d = ToolsParse.double(diameterText),
                  let V = ToolsParse.double(volumeText) else {
                return Eval(outcome: nil, errorField: nil, errorReason: nil)
            }
            let shotLen: Double
            let shotTrim = shotLengthText.trimmingCharacters(in: .whitespacesAndNewlines)
            if shotTrim.isEmpty {
                shotLen = ChainLockerMath.defaultShotLengthM
            } else if let v = ToolsParse.double(shotLengthText) {
                shotLen = v
            } else {
                return Eval(outcome: .invalid(reason: "Check shot length"), errorField: .shotLength, errorReason: "Check shot length")
            }

            let outcome = ChainLockerMath.shotsFromVolume(volumeM3: V, diameterMm: d, shotLengthM: shotLen)
            return mapOutcome(outcome)
        }
    }

    private func mapOutcome(_ outcome: ChainLockerMath.Outcome) -> Eval {
        if case .invalid(let r) = outcome {
            let field: Field
            switch r {
            case "Check shots": field = .shots
            case "Check shot length": field = .shotLength
            default:
                if r.lowercased().contains("volume") { field = .volume }
                else if r.lowercased().contains("diameter") { field = .diameter }
                else { field = .diameter }
            }
            return Eval(outcome: outcome, errorField: field, errorReason: r)
        }
        return Eval(outcome: outcome, errorField: nil, errorReason: nil)
    }

    var body: some View {
        ZStack {
            AppCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Chain locker mode")

                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("INPUTS")
                                .font(.caption.weight(.bold))
                                .tracking(1.1)
                                .foregroundStyle(AppTheme.teal)

                            ToolNumberField(
                                title: "Chain diameter",
                                text: $diameterText,
                                placeholder: "76",
                                unit: "mm",
                                isError: eval.errorField == .diameter,
                                errorReason: eval.errorField == .diameter ? eval.errorReason : nil
                            )

                            if mode == .spaceNeeded {
                                ToolNumberField(
                                    title: "Shots",
                                    text: $shotsText,
                                    placeholder: "25",
                                    unit: nil,
                                    isError: eval.errorField == .shots,
                                    errorReason: eval.errorField == .shots ? eval.errorReason : nil
                                )
                            }

                            if mode == .lengthFits {
                                ToolNumberField(
                                    title: "Locker volume V",
                                    text: $volumeText,
                                    placeholder: "81",
                                    unit: "m³",
                                    isError: eval.errorField == .volume,
                                    errorReason: eval.errorField == .volume ? eval.errorReason : nil
                                )
                            }

                            ToolNumberField(
                                title: "Shot length",
                                text: $shotLengthText,
                                placeholder: "27.5",
                                unit: "m",
                                isError: eval.errorField == .shotLength,
                                errorReason: eval.errorField == .shotLength ? eval.errorReason : nil
                            )
                        }
                    }

                    GlassCard {
                        resultsBlock
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Chain locker")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolsKeyboardDone()
    }

    @ViewBuilder
    private var resultsBlock: some View {
        switch eval.outcome {
        case nil:
            if mode == .spaceNeeded {
                ToolResultHero(caption: "VOLUME", value: ToolsParse.dash, unit: "m³")
                Text("Class min \(ToolsParse.dash) m³")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ToolResultHero(caption: "LENGTH", value: ToolsParse.dash, unit: "m")
                ToolResultRow(title: "Shots", value: ToolsParse.dash)
            }
        case .invalid(let reason):
            ToolResultHero(
                caption: mode == .spaceNeeded ? "VOLUME" : "LENGTH",
                value: ToolsParse.dash,
                unit: mode == .spaceNeeded ? "m³" : "m"
            )
            if eval.errorField == nil {
                Text(reason)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.danger)
            }
        case .ok(let r):
            if mode == .spaceNeeded {
                ToolResultHero(
                    caption: "VOLUME",
                    value: ToolsParse.format(r.volumeM3, decimals: 1),
                    unit: "m³"
                )
                Text("Class min \(ToolsParse.format(r.classVolumeM3, decimals: 1)) m³")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                ToolResultRow(title: "Length", value: "\(ToolsParse.format(r.lengthM, decimals: 1)) m")
            } else {
                ToolResultHero(
                    caption: "LENGTH",
                    value: ToolsParse.format(r.lengthM, decimals: 1),
                    unit: "m"
                )
                if let shots = r.shots {
                    ToolResultRow(title: "Shots", value: ToolsParse.format(shots, decimals: 1))
                }
                Text("Class min \(ToolsParse.format(r.classVolumeM3, decimals: 1)) m³")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}
