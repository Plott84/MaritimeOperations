import SwiftUI
import SwiftData
import CoreLocation

/// One DP log line. Timer path prefills start and stop. Add and edit do not ask for GPS until the button.
struct DPEntryFieldsSheet: View {
    enum Mode {
        case confirmStop
        case add
        case edit(DPEntry)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let mode: Mode
    var session: ActiveDPSessionStore?
    var onSaved: () -> Void = {}

    @State private var start: Date?
    @State private var stop: Date?
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
        case .add:
            _start = State(initialValue: nil)
            _stop = State(initialValue: nil)
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

    private var derivedHours: Double? {
        guard let start, let stop, stop > start else { return nil }
        return stop.timeIntervalSince(start) / 3600
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppCanvas()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        lineCard
                        if let fieldError {
                            Text(fieldError)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.danger)
                        }
                        if let saveError {
                            Text(saveError)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.danger)
                        }
                        saveButton
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("DP log line")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if isConfirm {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Skip") { dismiss() }
                            .accessibilityIdentifier("dpFieldsSkip")
                    }
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .accessibilityIdentifier("dpFieldsCancel")
                    }
                }
            }
            .interactiveDismissDisabled(isConfirm)
            .onAppear(perform: wireLocator)
        }
        .accessibilityIdentifier("dpEntryFieldsSheet")
    }

    private var lineCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(headerCopy)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                timeRow(title: "Start", date: $start, identifier: "dpStartTime", onSet: setStart)
                timeRow(title: "Stop", date: $stop, identifier: "dpStopTime", onSet: setStop)

                HStack {
                    Text("Hours")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Text(hoursCopy)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.teal)
                        .accessibilityIdentifier("dpHours")
                }

                labeledField("Ship name", text: $shipName, capitalize: .words)
                labeledField("Location name", text: $locationName, capitalize: .words)

                labeledField("Latitude N/S xx° xx.x'", text: $latitudeText, capitalize: .characters)
                labeledField("Longitude E/W xxx° xx.x'", text: $longitudeText, capitalize: .characters)

                Button(action: usePhoneLocation) {
                    Label("Use phone location", systemImage: "location")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.textPrimary)
                .background(Color.black.opacity(0.28), in: Capsule())
                .overlay(Capsule().stroke(AppTheme.teal.opacity(0.45), lineWidth: 1))
                .accessibilityIdentifier("usePhoneLocation")

                if let gpsNote {
                    Text(gpsNote)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                labeledField("Activity code", text: $activityCode, capitalize: .characters)
                labeledField("Notes", text: $notes, capitalize: .sentences, axis: .vertical)
            }
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("Save")
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.black.opacity(0.85))
        .background(AppTheme.teal, in: Capsule())
        .accessibilityIdentifier("dpFieldsSave")
    }

    private func timeRow(title: String, date: Binding<Date?>, identifier: String, onSet: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            if let value = date.wrappedValue {
                DatePicker(
                    title,
                    selection: Binding(
                        get: { value },
                        set: { date.wrappedValue = $0 }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .accessibilityIdentifier(identifier)
            } else {
                Button("Set \(title.lowercased())", action: onSet)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.teal)
                    .accessibilityIdentifier(identifier)
            }
        }
    }

    private func labeledField(
        _ title: String,
        text: Binding<String>,
        capitalize: TextInputAutocapitalization,
        axis: Axis = .horizontal
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            TextField(title, text: text, axis: axis)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(capitalize)
                .lineLimit(axis == .vertical ? 3...6 : 1...1)
                .padding(12)
                .foregroundStyle(AppTheme.textPrimary)
                .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                }
                .accessibilityLabel(title)
        }
    }

    private var isConfirm: Bool {
        if case .confirmStop = mode { return true }
        return false
    }

    private var hoursCopy: String {
        guard let derivedHours else { return "—" }
        return AppFormatters.hoursString(derivedHours)
    }

    private var headerCopy: String {
        switch mode {
        case .confirmStop:
            return "The timer set start and stop. Change them if you need to. Hours follow. Skip writes nothing and leaves the timer running."
        case .add:
            return "Enter start and stop. Hours follow those times."
        case .edit:
            return "Edit the DP line. Hours follow start and stop."
        }
    }

    private func setStart() {
        let value = Date.now
        start = value
        if let stop, stop <= value {
            self.stop = value.addingTimeInterval(3600)
        }
    }

    private func setStop() {
        let base = start ?? .now
        stop = base.addingTimeInterval(3600)
    }

    private func wireLocator() {
        locator.onFix = { location in
            latitudeText = CoordinateFormat.latitude(location.coordinate.latitude)
            longitudeText = CoordinateFormat.longitude(location.coordinate.longitude)
            gpsNote = "GPS filled. You can edit it."
        }
        locator.onDenied = {
            gpsNote = "No GPS fix. You can still save and type a position."
        }
    }

    private func usePhoneLocation() {
        wireLocator()
        locator.request()
    }

    private func save() {
        fieldError = nil
        let ship = shipName.trimmingCharacters(in: .whitespacesAndNewlines)
        if ship.isEmpty || ship.caseInsensitiveCompare("Vessel") == .orderedSame {
            fieldError = "Ship name is required."
            return
        }
        guard let start, let stop else {
            fieldError = "Start and stop are required."
            return
        }
        if stop <= start {
            fieldError = "Stop must be after start."
            return
        }

        let hours = stop.timeIntervalSince(start) / 3600
        switch mode {
        case .confirmStop:
            guard let session else { dismiss(); return }
            insert(
                source: .timed,
                start: start,
                stop: stop,
                hours: hours,
                ship: ship,
                then: { session.clear() }
            )
        case .add:
            insert(
                source: .manual,
                start: start,
                stop: stop,
                hours: hours,
                ship: ship,
                then: {}
            )
        case .edit(let entry):
            entry.date = start
            entry.startTime = start
            entry.endTime = stop
            entry.durationHours = hours
            entry.vessel = ship
            applyOptionalFields(to: entry)
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

    private func insert(
        source: DPEntrySource,
        start: Date,
        stop: Date,
        hours: Double,
        ship: String,
        then: () -> Void
    ) {
        let entry = DPEntry(
            source: source,
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
            then()
            onSaved()
            dismiss()
        } catch {
            modelContext.delete(entry)
            saveError = isConfirm
                ? "Couldn’t save this DP session. Timer is still running — try Save again."
                : "Couldn’t save this DP line. Try again."
        }
    }

    private func applyOptionalFields(to entry: DPEntry) {
        entry.locationName = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.latitudeText = latitudeText.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.longitudeText = longitudeText.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.activityCode = optional(activityCode)
        entry.notes = optional(notes)
    }

    private func optional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
