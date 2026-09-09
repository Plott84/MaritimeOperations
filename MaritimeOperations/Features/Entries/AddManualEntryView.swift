import SwiftUI
import SwiftData

struct AddManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var date = Date()
    @State private var durationText = ""
    @State private var vessel = ""
    @State private var rig = ""
    @State private var vesselType = ""
    @State private var dpClass = ""
    @State private var modeSelection: ModeOption = .unspecified
    @State private var activityCode = ""
    @State private var masterInitials = ""
    @State private var notes = ""

    @State private var vesselError: String?
    @State private var durationError: String?
    @State private var saveError: String?
    @State private var showDiscardConfirm = false

    private enum ModeOption: String, CaseIterable, Identifiable {
        case unspecified = ""
        case active = "Active"
        case passive = "Passive"

        var id: String { rawValue.isEmpty ? "unspecified" : rawValue }

        var label: String {
            switch self {
            case .unspecified: return "Not set"
            case .active, .passive: return rawValue
            }
        }
    }

    private var isDirty: Bool {
        !durationText.isEmpty
            || !vessel.isEmpty
            || !rig.isEmpty
            || vesselType != "AH"
            || dpClass != "Class 2"
            || modeSelection != .unspecified
            || !activityCode.isEmpty
            || !masterInitials.isEmpty
            || !notes.isEmpty
            || !Calendar.current.isDateInToday(date)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Transcribe a line from your old logbook.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .listRowBackground(Color.clear)
                }

                Section("Session") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Duration (hours)", text: $durationText)
                            .keyboardType(.decimalPad)
                            .onChange(of: durationText) { _, _ in durationError = nil }
                        if let durationError {
                            Text(durationError)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.danger)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Vessel", text: $vessel)
                            .textInputAutocapitalization(.words)
                            .onChange(of: vessel) { _, _ in vesselError = nil }
                        if let vesselError {
                            Text(vesselError)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.danger)
                        }
                    }

                    TextField("Rig", text: $rig)
                    TextField("Vessel type", text: $vesselType)
                    TextField("DP class", text: $dpClass)
                }

                Section("Optional (book fields)") {
                    Picker("Mode", selection: $modeSelection) {
                        ForEach(ModeOption.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }

                    TextField("Activity code", text: $activityCode)
                    TextField("Master’s initials", text: $masterInitials)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let saveError {
                    Section {
                        Text(saveError)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.danger)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Add Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { attemptDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
            .confirmationDialog(
                "Discard this entry?",
                isPresented: $showDiscardConfirm,
                titleVisibility: .visible
            ) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("You have unsaved changes.")
            }
            .interactiveDismissDisabled(isDirty)
        }
    }

    private func attemptDismiss() {
        if isDirty {
            showDiscardConfirm = true
        } else {
            dismiss()
        }
    }

    private func save() {
        vesselError = nil
        durationError = nil
        saveError = nil

        let trimmedVessel = vessel.trimmingCharacters(in: .whitespacesAndNewlines)
        var hasError = false

        if trimmedVessel.isEmpty {
            vesselError = "Vessel is required."
            hasError = true
        }

        let normalized = durationText.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        if normalized.isEmpty {
            durationError = "Duration is required."
            hasError = true
        } else if let hours = Double(normalized) {
            if hours < 0 {
                durationError = "Duration can’t be negative."
                hasError = true
            } else if !hasError {
                commit(hours: hours, vessel: trimmedVessel)
                return
            }
        } else {
            durationError = "Enter a valid duration in hours."
            hasError = true
        }

        _ = hasError
    }

    private func commit(hours: Double, vessel: String) {
        let entry = DPEntry(
            source: .manual,
            date: date,
            startTime: nil,
            endTime: nil,
            durationHours: hours,
            vessel: vessel,
            rig: rig.trimmingCharacters(in: .whitespacesAndNewlines),
            vesselType: vesselType.trimmingCharacters(in: .whitespacesAndNewlines),
            dpClass: dpClass.trimmingCharacters(in: .whitespacesAndNewlines),
            mode: modeSelection == .unspecified ? nil : modeSelection.rawValue,
            activityCode: optional(activityCode),
            notes: optional(notes),
            masterInitials: optional(masterInitials)
        )
        modelContext.insert(entry)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.delete(entry)
            saveError = "Couldn’t save entry. Try again."
        }
    }

    private func optional(_ value: String) -> String? {
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
