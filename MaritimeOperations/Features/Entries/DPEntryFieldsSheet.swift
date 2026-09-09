import SwiftUI
import SwiftData
import CoreLocation

/// DP line: start/stop times, derived hours, ship, location or GPS, activity code, notes.
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

    @State private var start: Date
    @State private var stop: Date
    @State private var shipName: String
    @State private var locationName: String
    @State private var latitudeText: String
    @State private var longitudeText: String
    @State private var activityCode: String
    @State private var notes: String
    @State private var fieldError: String?
    @State private var saveError: String?
    @State private var gpsNote: String?
    @State private var locator = WhenInUseLocation()

    init(mode: Mode, session: ActiveDPSessionStore? = nil, onSaved: @escaping () -> Void = {}) {
        self.mode = mode
        self.session = session
        self.onSaved = onSaved
        switch mode {
        case .confirmStop:
            let started = session?.startedAt ?? .now
            _start = State(initialValue: started)
            _stop = State(initialValue: .now)
            _shipName = State(initialValue: "")
            _locationName = State(initialValue: "")
            _latitudeText = State(initialValue: "")
            _longitudeText = State(initialValue: "")
            _activityCode = State(initialValue: "")
            _notes = State(initialValue: "")
        case .edit(let entry):
            let started = entry.startTime ?? entry.date
            let ended = entry.endTime ?? started.addingTimeInterval(entry.durationHours * 3600)
            _start = State(initialValue: started)
            _stop = State(initialValue: ended)
            _shipName = State(initialValue: entry.vessel == "Vessel" ? "" : entry.vessel)
            _locationName = State(initialValue: entry.locationName)
            _latitudeText = State(initialValue: entry.latitudeText)
            _longitudeText = State(initialValue: entry.longitudeText)
            _activityCode = State(initialValue: entry.activityCode ?? "")
            _notes = State(initialValue: entry.notes ?? "")
        }
    }

    private var hours: Double {
        max(0, stop.timeIntervalSince(start) / 3600)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(headerCopy)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Section("Times") {
                    DatePicker("Start", selection: $start)
                    DatePicker("Stop", selection: $stop)
                    LabeledContent("Hours") {
                        Text(AppFormatters.hoursString(hours))
                            .foregroundStyle(AppTheme.teal)
                    }
                }
                Section("Ship") {
                    TextField("Ship name", text: $shipName)
                        .textInputAutocapitalization(.words)
                }
                Section("Location") {
                    TextField("Location name", text: $locationName)
                    TextField("Latitude N/S xx° xx.x'", text: $latitudeText)
                        .textInputAutocapitalization(.characters)
                    TextField("Longitude E/W xxx° xx.x'", text: $longitudeText)
                        .textInputAutocapitalization(.characters)
                    Button("Use phone GPS") { locator.request() }
                    if let gpsNote {
                        Text(gpsNote)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                Section("Log") {
                    TextField("Activity code", text: $activityCode)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
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
            .onAppear {
                locator.onFix = { location in
                    latitudeText = CoordinateFormat.latitude(location.coordinate.latitude)
                    longitudeText = CoordinateFormat.longitude(location.coordinate.longitude)
                    gpsNote = "GPS filled. You can edit it."
                }
                locator.onDenied = {
                    if latitudeText.isEmpty && longitudeText.isEmpty {
                        gpsNote = "No GPS fix. You can still save and type a position."
                    }
                }
                locator.request()
            }
        }
        .accessibilityIdentifier("dpEntryFieldsSheet")
    }

    private var isConfirm: Bool {
        if case .confirmStop = mode { return true }
        return false
    }

    private var title: String { isConfirm ? "Save DP session" : "Edit entry" }
    private var skipTitle: String { isConfirm ? "Skip" : "Cancel" }

    private var headerCopy: String {
        isConfirm
            ? "The timer set start and stop. Change them if you need to. Hours follow. Skip writes nothing and leaves the timer running."
            : "Edit the DP line. Hours follow start and stop."
    }

    private func save() {
        fieldError = nil
        let ship = shipName.trimmingCharacters(in: .whitespacesAndNewlines)
        if ship.isEmpty || ship.caseInsensitiveCompare("Vessel") == .orderedSame {
            fieldError = "Ship name is required."
            return
        }
        if stop <= start {
            fieldError = "Stop must be after start."
            return
        }

        let hours = hours
        switch mode {
        case .confirmStop:
            guard let session else { dismiss(); return }
            let entry = DPEntry(
                source: .timed,
                date: start,
                startTime: start,
                endTime: stop,
                durationHours: hours,
                vessel: ship,
                activityCode: optional(activityCode),
                notes: optional(notes),
                locationName: locationName.trimmingCharacters(in: .whitespacesAndNewlines),
                latitudeText: latitudeText.trimmingCharacters(in: .whitespacesAndNewlines),
                longitudeText: longitudeText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            modelContext.insert(entry)
            do {
                try modelContext.save()
                session.clear()
                onSaved()
                dismiss()
            } catch {
                modelContext.delete(entry)
                saveError = "Couldn’t save this DP session. Timer is still running — try Save again."
            }
        case .edit(let entry):
            entry.date = start
            entry.startTime = start
            entry.endTime = stop
            entry.durationHours = hours
            entry.vessel = ship
            entry.locationName = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.latitudeText = latitudeText.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.longitudeText = longitudeText.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.activityCode = optional(activityCode)
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
