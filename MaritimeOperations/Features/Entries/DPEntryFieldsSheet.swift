import SwiftUI
import SwiftData

/// Confirm a timed stop, or edit an existing line. No new fields.
struct DPEntryFieldsSheet: View {
    enum Mode {
        case confirmStop
        case edit(DPEntry)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let mode: Mode
    var session: ActiveDPSessionStore?
    var onSaved: () -> Void = {}

    @State private var vessel: String
    @State private var rig: String
    @State private var vesselType: String
    @State private var dpClass: String
    @State private var modeText: String
    @State private var activityCode: String
    @State private var masterInitials: String
    @State private var notes: String
    @State private var fieldError: String?
    @State private var saveError: String?

    init(mode: Mode, session: ActiveDPSessionStore? = nil, onSaved: @escaping () -> Void = {}) {
        self.mode = mode
        self.session = session
        self.onSaved = onSaved
        switch mode {
        case .confirmStop:
            // A new line starts empty. Sample row values are not standing defaults.
            _vessel = State(initialValue: "")
            _rig = State(initialValue: "")
            _vesselType = State(initialValue: "")
            _dpClass = State(initialValue: "")
            _modeText = State(initialValue: "")
            _activityCode = State(initialValue: "")
            _masterInitials = State(initialValue: "")
            _notes = State(initialValue: "")
        case .edit(let entry):
            _vessel = State(initialValue: entry.vessel)
            _rig = State(initialValue: entry.rig)
            _vesselType = State(initialValue: entry.vesselType)
            _dpClass = State(initialValue: entry.dpClass)
            _modeText = State(initialValue: entry.mode ?? "")
            _activityCode = State(initialValue: entry.activityCode ?? "")
            _masterInitials = State(initialValue: entry.masterInitials ?? "")
            _notes = State(initialValue: entry.notes ?? "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(headerCopy)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Section("Logbook line") {
                    field("Vessel", text: $vessel)
                    field("Rig", text: $rig)
                    field("Vessel type", text: $vesselType)
                    field("DP class", text: $dpClass)
                }
                Section("Optional") {
                    TextField("Mode", text: $modeText)
                    TextField("Activity code", text: $activityCode)
                    TextField("Master’s initials", text: $masterInitials)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
                if let fieldError {
                    Section {
                        Text(fieldError)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.danger)
                    }
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
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(skipTitle) { dismiss() }
                        .accessibilityIdentifier("dpFieldsSkip")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("dpFieldsSave")
                }
            }
            .interactiveDismissDisabled(isConfirm)
        }
        .accessibilityIdentifier("dpEntryFieldsSheet")
    }

    private var isConfirm: Bool {
        if case .confirmStop = mode { return true }
        return false
    }

    private var title: String {
        isConfirm ? "Save DP session" : "Edit entry"
    }

    private var skipTitle: String {
        isConfirm ? "Skip" : "Cancel"
    }

    private var headerCopy: String {
        isConfirm
            ? "Confirm the logbook line before this session is saved. Skip keeps the timer running and does not create an entry."
            : "Finish the logbook fields. Source and times stay as they were."
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .textInputAutocapitalization(.words)
    }

    private func save() {
        fieldError = nil
        let vessel = vessel.trimmingCharacters(in: .whitespacesAndNewlines)
        let rig = rig.trimmingCharacters(in: .whitespacesAndNewlines)
        let vesselType = vesselType.trimmingCharacters(in: .whitespacesAndNewlines)
        let dpClass = dpClass.trimmingCharacters(in: .whitespacesAndNewlines)

        if vessel.isEmpty || vessel.caseInsensitiveCompare("Vessel") == .orderedSame {
            fieldError = "Vessel is required."
            return
        }
        if rig.isEmpty { fieldError = "Rig is required."; return }
        if vesselType.isEmpty { fieldError = "Vessel type is required."; return }
        if dpClass.isEmpty { fieldError = "DP class is required."; return }

        switch mode {
        case .confirmStop:
            guard let session, let startedAt = session.startedAt else {
                dismiss()
                return
            }
            let endedAt = Date()
            let hours = max(0, endedAt.timeIntervalSince(startedAt) / 3600.0)
            let entry = DPEntry(
                source: .timed,
                date: startedAt,
                startTime: startedAt,
                endTime: endedAt,
                durationHours: hours,
                vessel: vessel,
                rig: rig,
                vesselType: vesselType,
                dpClass: dpClass,
                mode: optional(modeText),
                activityCode: optional(activityCode),
                notes: optional(notes),
                masterInitials: optional(masterInitials)
            )
            modelContext.insert(entry)
            do {
                try modelContext.save()
                session.vessel = vessel
                session.rig = rig
                session.vesselType = vesselType
                session.dpClass = dpClass
                session.clear()
                onSaved()
                dismiss()
            } catch {
                modelContext.delete(entry)
                saveError = "Couldn’t save this DP session. Timer is still running — try Save again."
            }
        case .edit(let entry):
            entry.vessel = vessel
            entry.rig = rig
            entry.vesselType = vesselType
            entry.dpClass = dpClass
            entry.mode = optional(modeText)
            entry.activityCode = optional(activityCode)
            entry.masterInitials = optional(masterInitials)
            entry.notes = optional(notes)
            entry.updatedAt = .now
            do {
                try modelContext.save()
                onSaved()
                dismiss()
            } catch {
                saveError = "Couldn’t save changes. Try again."
            }
        }
    }

    private func optional(_ value: String) -> String? {
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
