import SwiftUI

/// Activity code dropdown (IMCA DP Logbook Part 7 + My codes) and the OT "Specify" field.
struct ActivityCodePicker: View {
    @Binding var selection: ActivityCodeSelection

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DPLineFieldRow(title: "Activity code") {
                Picker("Activity code", selection: $selection.code) {
                    Text("None").tag("")
                    if let legacy = selection.legacyValue {
                        Text("Current: \(legacy)").tag(ActivityCodeSelection.legacyTag)
                    }
                    Section("IMCA DP Logbook") {
                        ForEach(ActivityCode.allCases) { code in
                            Text(code.rawValue).tag(code.rawValue)
                        }
                    }
                    Section("My codes") {
                        ForEach(MyActivityCode.allCases) { code in
                            Text(code.menuTitle).tag(code.rawValue)
                        }
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.teal)
                .labelsHidden()
                .accessibilityIdentifier("dpActivityCode")
            }

            if selection.isOT {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Specify (required for OT)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    TextField("Specify", text: $selection.specify)
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.sentences)
                        .padding(12)
                        .foregroundStyle(AppTheme.textPrimary)
                        .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppTheme.border, lineWidth: 1)
                        }
                        .accessibilityLabel("Specify")
                        .accessibilityIdentifier("dpActivitySpecify")
                }
            }
        }
    }
}
