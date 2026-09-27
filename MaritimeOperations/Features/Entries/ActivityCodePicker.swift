import SwiftUI
import UIKit

/// Activity code dropdown (IMCA DP Logbook Part 7, then "OT – Anchor handling") and the OT "Specify" field.
struct ActivityCodePicker: View {
    @Binding var selection: ActivityCodeSelection
    /// Called when the user taps the picker, so the parent can clear focus from its text fields.
    var onOpen: () -> Void = {}

    @FocusState private var specifyFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DPLineFieldRow(title: "Activity code") {
                Picker("Activity code", selection: $selection.code) {
                    Text("None").tag("")
                    if let legacy = selection.legacyValue {
                        Text("Current: \(legacy)").tag(ActivityCodeSelection.legacyTag)
                    }
                    ForEach(ActivityCodeMenu.options) { option in
                        Text(option.label).tag(option.tag)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.teal)
                .labelsHidden()
                .accessibilityIdentifier("dpActivityCode")
                // A menu Picker has no tap or "did open" hook, so watch for the tap that opens it.
                .onTapPassthrough { dismissKeyboard() }
            }

            if selection.isOT {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Specify (required for OT)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    TextField("Specify", text: $selection.specify)
                        .focused($specifyFocused)
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

    private func dismissKeyboard() {
        specifyFocused = false
        onOpen()
        // Fallback for any responder SwiftUI focus doesn't reach.
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
