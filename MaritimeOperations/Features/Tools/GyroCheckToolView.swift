import SwiftUI

/// Desk gyro check — Transit / Sun azimuth / Amplitude. Maths: `GyroMath`; form: `GyroCheckModel`.
struct GyroCheckToolView: View {
    @State private var model = GyroCheckModel()

    var body: some View {
        ZStack {
            AppCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Method", selection: $model.mode) {
                        ForEach(GyroCheckModel.Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Gyro check method")

                    GlassCard {
                        inputs
                    }

                    GlassCard {
                        resultCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Gyro check")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolsKeyboardDone()
    }

    @ViewBuilder
    private var inputs: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("INPUTS")
                .font(.caption.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(AppTheme.teal)

            switch model.mode {
            case .azimuth:
                latRow
                decRow
                degMinRow("LHA", deg: $model.lhaDeg, min: $model.lhaMin)
            case .amplitude:
                latRow
                decRow
                Picker("Sun", selection: $model.event) {
                    ForEach(GyroMath.SunEvent.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Rising or setting")
            case .transit:
                ToolNumberField(
                    title: "Charted true bearing",
                    text: $model.chartedTrue,
                    placeholder: "047.5",
                    unit: "°T"
                )
            }

            ToolNumberField(
                title: "Gyro bearing observed",
                text: $model.gyro,
                placeholder: "046.8",
                unit: "°G"
            )
        }
    }

    private var latRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            degMinRow("Latitude", deg: $model.latDeg, min: $model.latMin)
            nsPicker("Latitude hemisphere", selection: $model.latNS)
        }
    }

    private var decRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            degMinRow("Declination", deg: $model.decDeg, min: $model.decMin)
            nsPicker("Declination name", selection: $model.decNS)
        }
    }

    private func nsPicker(_ label: String, selection: Binding<GyroCheckModel.NS>) -> some View {
        Picker(label, selection: selection) {
            Text("N (north)").tag(GyroCheckModel.NS.n)
            Text("S (south)").tag(GyroCheckModel.NS.s)
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(label)
    }

    private func degMinRow(_ title: String, deg: Binding<String>, min: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(AppTheme.textSecondary)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { degField(deg, title); minField(min, title) }
                VStack(alignment: .leading, spacing: 8) { degField(deg, title); minField(min, title) }
            }
        }
    }

    private func degField(_ text: Binding<String>, _ title: String) -> some View {
        HStack(spacing: 4) {
            TextField("deg", text: text)
                .keyboardType(.numberPad)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                }
                .accessibilityLabel("\(title) degrees")
            Text("°")
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private func minField(_ text: Binding<String>, _ title: String) -> some View {
        HStack(spacing: 4) {
            TextField("min", text: text)
                .keyboardType(.decimalPad)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                }
                .accessibilityLabel("\(title) minutes")
            Text("′")
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    @ViewBuilder
    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RESULT")
                .font(.caption.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(AppTheme.teal)

            switch model.outcome {
            case .incomplete:
                ToolResultHero(caption: "TRUE BEARING", value: ToolsParse.dash)
                Text("Enter all fields to see the true bearing and gyro error.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
            case .refused(let reason):
                ToolResultHero(caption: "TRUE BEARING", value: ToolsParse.dash)
                Label(reason, systemImage: "nosign")
                    .font(.body)
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            case .result(let zn, let err, let hc):
                ToolResultHero(caption: "TRUE BEARING", value: GyroMath.bearingDisplay(zn))
                if let hc {
                    ToolResultRow(
                        title: "Hc",
                        value: (hc < 0 ? "−" : "") + GyroMath.dmDisplay(hc)
                    )
                }
                HStack {
                    Text("Gyro error")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Text(err.display)
                        .font(.title2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(err.flagged ? AppTheme.danger : AppTheme.textPrimary)
                        .accessibilityValue(
                            err.name == "E" ? "\(err.display), east"
                            : err.name == "W" ? "\(err.display), west"
                            : err.display
                        )
                }
                if err.flagged {
                    Label("Investigate: error over 1.0°", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(AppTheme.gold)
                }
                if model.mode == .amplitude {
                    Text("Sun's centre on the celestial horizon")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
