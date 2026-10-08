import SwiftUI
import SwiftData

/// Crane book entry form (one entry = one shift on one crane). Start is the only required value;
/// every other field starts empty, except Vessel, which prefills from the newest
/// DP / AH / ROV / Crane entry. Position starts "Not set".
/// Save is disabled only while crane type "Other" has blank text.
struct AddCraneEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var dpLines: [DPEntry]
    @Query private var ahEntries: [RigMove]
    @Query private var rovEntries: [ROVEntry]
    @Query private var craneEntries: [CraneEntry]

    private let existing: CraneEntry?

    @State private var start: Date
    @State private var end: Date
    @State private var vessel: String
    @State private var rank: String
    @State private var underTraining: Bool
    @State private var craneName: String
    @State private var craneType: CraneType?
    @State private var craneTypeOther: String
    @State private var fieldArea: String
    @State private var hoursText: String
    @State private var liftTypes: Set<CraneLiftType>
    @State private var craneMode: CraneMode?
    @State private var dayNight: CraneDayNight?
    @State private var windText: String
    @State private var waveHeightText: String
    @State private var remarks: String

    @State private var didPrefill = false
    @State private var fieldError: String?
    @FocusState private var focusedField: Bool

    init(existing: CraneEntry? = nil) {
        self.existing = existing
        let now = Date()
        _start = State(initialValue: existing?.date ?? now)
        _end = State(initialValue: existing?.endTime ?? existing?.date ?? now)
        _vessel = State(initialValue: existing?.vessel ?? "")
        _rank = State(initialValue: existing?.rank ?? "")
        _underTraining = State(initialValue: existing?.underTraining ?? false)
        _craneName = State(initialValue: existing?.craneName ?? "")
        _craneType = State(initialValue: existing?.craneType)
        _craneTypeOther = State(initialValue: existing?.craneTypeOther ?? "")
        _fieldArea = State(initialValue: existing?.fieldArea ?? "")
        _hoursText = State(initialValue: LogNumber.text(existing?.hoursOperated))
        _liftTypes = State(initialValue: existing?.liftTypes ?? [])
        _craneMode = State(initialValue: existing?.craneMode)
        _dayNight = State(initialValue: existing?.dayNight)
        _windText = State(initialValue: LogNumber.text(existing?.windMS))
        _waveHeightText = State(initialValue: LogNumber.text(existing?.waveHeightM))
        _remarks = State(initialValue: existing?.remarks ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppCanvas()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        LogFormBookHeader(book: .crane)
                        if let fieldError {
                            Text(fieldError)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.danger)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("craneFieldError")
                        }
                        LogWhenCard(start: $start, end: $end, idPrefix: "crane")
                        jobCard
                        liftsCard
                        conditionsCard
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(existing == nil ? "New crane entry" : "Edit crane entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("craneCancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .tint(AppTheme.teal)
                        .disabled(missingOther != nil)
                        .accessibilityIdentifier("craneSave")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = false }
                        .accessibilityIdentifier("craneKeyboardDone")
                }
            }
            .onAppear(perform: prefillVessel)
        }
        .accessibilityIdentifier("craneEntrySheet")
    }

    // MARK: Job

    private var jobCard: some View {
        AHSectionCard(title: "Job", systemImage: "ferry") {
            LogVesselRow(vessel: $vessel, shipNames: shipNames, idPrefix: "crane", focus: $focusedField)
            LogPositionRow(raw: $rank, options: BookPositions.crane, idPrefix: "crane")
            AHFieldRow(title: "Under training") {
                Toggle("Under training", isOn: $underTraining)
                    .labelsHidden()
                    .tint(AppTheme.teal)
                    .accessibilityIdentifier("craneUnderTraining")
            }
            AHFieldRow(title: "Crane") {
                LogInlineTextField(title: "Crane", text: $craneName, identifier: "craneName", focus: $focusedField)
            }
            AHFieldRow(title: "Crane type") {
                LogMenuPicker(
                    title: "Crane type",
                    options: CraneType.allCases,
                    selection: $craneType,
                    label: \.label,
                    spokenLabel: { $0.spokenLabel },
                    identifier: "craneTypePicker"
                )
            }
            if craneType?.isOther == true {
                LogOtherTextRow(title: "Other crane type", text: $craneTypeOther, identifier: "craneTypeOther", focus: $focusedField)
            }
            if let missingOther {
                LogFieldNote(text: LogOtherText.message(for: missingOther))
                    .accessibilityIdentifier("craneOtherNeeded")
            }
            AHFieldRow(title: "Field or area", showsDivider: false) {
                LogInlineTextField(title: "Field or area", text: $fieldArea, identifier: "craneFieldArea", focus: $focusedField)
            }
            LogFieldNote(text: "Name only. No coordinates.")
        }
    }

    // MARK: Lifts

    private var liftsCard: some View {
        AHSectionCard(title: "Lifts", systemImage: "checklist") {
            AHValueTile(title: "Hours operated") {
                AHNumberField(title: "Hours operated", unit: "h", spokenUnit: "hours", text: $hoursText, identifier: "craneHoursOperated")
                    .focused($focusedField)
            }
            LogFieldNote(text: "Your own time at the controls, not the shift length.")
                .padding(.top, 2)

            LogFieldCaption(title: "Lift type")
                .padding(.top, 10)
            LogChipSet(
                options: CraneLiftType.allCases,
                selection: $liftTypes,
                label: \.label,
                spokenLabel: { $0.spokenLabel },
                identifier: { "craneLift_\($0.rawValue)" }
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Lift type")

            LogFieldCaption(title: "Crane mode")
                .padding(.top, 12)
            LogChoiceFlow(
                options: CraneMode.allCases,
                selection: $craneMode,
                label: \.label,
                spokenLabel: { $0.spokenLabel },
                identifier: { "craneMode_\($0.rawValue)" }
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Crane mode")
        }
    }

    // MARK: Conditions

    private var conditionsCard: some View {
        AHSectionCard(title: "Conditions", systemImage: "water.waves") {
            LogFieldCaption(title: "Day / Night")
            AHSegmented(
                options: CraneDayNight.allCases,
                selection: $dayNight,
                allowsClear: true,
                label: \.label,
                spokenLabel: { $0.spokenLabel },
                identifier: { "craneDayNight_\($0.rawValue)" }
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Day or night")
            .padding(.bottom, 10)

            weatherTiles
            LogFieldNote(text: "Your own observation.")
                .padding(.top, 2)

            LogRemarksField(text: $remarks, identifier: "craneRemarks", focus: $focusedField)
        }
    }

    // Plain Grid/VStack, not LazyVGrid: both tiles stay in the view tree for VoiceOver and UI tests.
    @ViewBuilder
    private var weatherTiles: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                windTile
                waveTile
            }
        } else {
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    windTile
                    waveTile
                }
            }
        }
    }

    private var windTile: some View {
        AHValueTile(title: "Wind") {
            AHNumberField(title: "Wind", unit: "m/s", spokenUnit: "metres per second", text: $windText, identifier: "craneWind")
                .focused($focusedField)
        }
    }

    private var waveTile: some View {
        AHValueTile(title: "Wave height (Hs)") {
            AHNumberField(title: "Wave height", unit: "m", spokenUnit: "metres", text: $waveHeightText, identifier: "craneWaveHeight")
                .focused($focusedField)
        }
    }

    // MARK: Prefill and save

    /// Label of an "Other" pick whose text is still blank; Save is disabled while set.
    private var missingOther: String? {
        LogOtherText.firstMissing([(label: "Crane type", choice: craneType, text: craneTypeOther)])
    }

    private var shipNames: [String] {
        BookVesselPrefill.loggedShipNames(dpLines: dpLines, ahEntries: ahEntries, rovEntries: rovEntries, craneEntries: craneEntries)
    }

    /// A new entry starts with the ship of the newest entry in any book. Position stays "Not set".
    private func prefillVessel() {
        guard existing == nil, !didPrefill else { return }
        didPrefill = true
        vessel = BookVesselPrefill.vessel(dpLines: dpLines, ahEntries: ahEntries, rovEntries: rovEntries, craneEntries: craneEntries)
    }

    private func save() {
        if let block = LogEntryCheck.block(start: start, end: end) {
            fieldError = block
            return
        }
        if let missingOther {
            fieldError = LogOtherText.message(for: missingOther)
            return
        }
        let numbers = CraneNumberInput(hoursOperated: hoursText, wind: windText, waveHeight: waveHeightText)
        if let problem = numbers.firstProblem {
            fieldError = problem
            return
        }

        let target = existing ?? CraneEntry(date: start)
        if existing == nil {
            modelContext.insert(target)
        }
        target.date = start
        target.endTime = end
        target.vessel = LogEntryCheck.optionalText(vessel)
        target.rank = rank.isEmpty ? nil : rank
        target.underTraining = LogEntryCheck.underTraining(isOn: underTraining, previous: target.underTraining)
        target.craneName = LogEntryCheck.optionalText(craneName)
        target.craneType = craneType
        target.craneTypeOther = LogOtherText.stored(craneType, text: craneTypeOther)
        target.fieldArea = LogEntryCheck.optionalText(fieldArea)
        target.hoursOperated = numbers.hoursOperatedValue
        target.liftTypes = liftTypes
        target.craneMode = craneMode
        target.dayNight = dayNight
        target.windMS = numbers.windValue
        target.waveHeightM = numbers.waveHeightValue
        target.remarks = LogEntryCheck.optionalText(remarks)
        target.updatedAt = .now

        do {
            try modelContext.save()
            dismiss()
        } catch {
            if existing == nil {
                modelContext.delete(target)
            }
            fieldError = "Couldn’t save this entry. Try again."
        }
    }
}
