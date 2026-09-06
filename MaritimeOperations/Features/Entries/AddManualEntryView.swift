import SwiftUI
import SwiftData

struct AddManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var date = Date()
    @State private var durationText = ""
    @State private var vessel = ""
    @State private var rig = ""
    @State private var vesselType = "AH"
    @State private var dpClass = "Class 2"
    @State private var mode = ""
    @State private var activityCode = ""
    @State private var masterInitials = ""
    @State private var notes = ""
    @State private var fieldError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Duration (hours)", text: $durationText)
                        .keyboardType(.decimalPad)
                    TextField("Vessel", text: $vessel)
                        .textInputAutocapitalization(.words)
                    TextField("Rig", text: $rig)
                    TextField("Vessel type", text: $vesselType)
                    TextField("DP class", text: $dpClass)
                }

                Section("Optional (book fields)") {
                    TextField("Mode (Active / Passive)", text: $mode)
                    TextField("Activity code", text: $activityCode)
                    TextField("Master’s initials", text: $masterInitials)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let fieldError {
                    Section {
                        Text(fieldError)
                            .foregroundStyle(AppTheme.danger)
                            .font(.footnote)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Add Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func save() {
        fieldError = nil
        let trimmedVessel = vessel.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedVessel.isEmpty {
            fieldError = "Vessel is required."
            return
        }

        let normalized = durationText.replacingOccurrences(of: ",", with: ".")
        guard let hours = Double(normalized) else {
            fieldError = "Enter a valid duration in hours."
            return
        }
        if hours < 0 {
            fieldError = "Duration can’t be negative."
            return
        }

        let entry = DPEntry(
            source: .manual,
            date: date,
            startTime: nil,
            endTime: nil,
            durationHours: hours,
            vessel: trimmedVessel,
            rig: rig.trimmingCharacters(in: .whitespacesAndNewlines),
            vesselType: vesselType.trimmingCharacters(in: .whitespacesAndNewlines),
            dpClass: dpClass.trimmingCharacters(in: .whitespacesAndNewlines),
            mode: optional(mode),
            activityCode: optional(activityCode),
            notes: optional(notes),
            masterInitials: optional(masterInitials)
        )
        modelContext.insert(entry)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            fieldError = "Couldn’t save entry. Try again."
        }
    }

    private func optional(_ value: String) -> String? {
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
