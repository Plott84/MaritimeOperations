import SwiftUI
import SwiftData

/// ROV book entry form (one entry = one shift, with a dive count). Start is the only required
/// value; every other field starts empty, except Vessel, which prefills from the newest
/// DP / AH / ROV / Crane entry. Position (IMCA grade) and Support site start "Not set".
/// Save is disabled only while an "Other" pick (Position, Support site) has blank text.
struct AddROVEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var dpLines: [DPEntry]
    @Query private var ahEntries: [RigMove]
    @Query private var rovEntries: [ROVEntry]
    @Query private var craneEntries: [CraneEntry]

    private let existing: ROVEntry?

    @State private var start: Date
    @State private var end: Date
    @State private var vessel: String
    @State private var gradeRaw: String
    @State private var gradeOther: String
    @State private var underTraining: Bool
    @State private var rovSystem: String
    @State private var rovClass: ROVClass?
    @State private var fieldArea: String
    @State private var jobType: ROVJobType?
    @State private var tasks: Set<ROVTask>
    @State private var pilotingHoursText: String
    @State private var divesText: String
    @State private var supportSite: ROVSupportSite?
    @State private var supportSiteOther: String
    @State private var remarks: String

    @State private var didPrefill = false
    @State private var fieldError: String?
    @FocusState private var focusedField: Bool

    init(existing: ROVEntry? = nil) {
        self.existing = existing
        let now = Date()
        _start = State(initialValue: existing?.date ?? now)
        _end = State(initialValue: existing?.endTime ?? existing?.date ?? now)
        _vessel = State(initialValue: existing?.vessel ?? "")
        _gradeRaw = State(initialValue: existing?.gradeRaw ?? "")
        _gradeOther = State(initialValue: existing?.gradeOther ?? "")
        _underTraining = State(initialValue: existing?.underTraining ?? false)
        _rovSystem = State(initialValue: existing?.rovSystem ?? "")
        _rovClass = State(initialValue: existing?.rovClass)
        _fieldArea = State(initialValue: existing?.fieldArea ?? "")
        _jobType = State(initialValue: existing?.jobType)
        _tasks = State(initialValue: existing?.tasks ?? [])
        _pilotingHoursText = State(initialValue: LogNumber.text(existing?.pilotingHours))
        _divesText = State(initialValue: LogNumber.text(existing?.dives))
        _supportSite = State(initialValue: existing?.supportSite)
        _supportSiteOther = State(initialValue: existing?.supportSiteOther ?? "")
        _remarks = State(initialValue: existing?.remarks ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppCanvas()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        LogFormBookHeader(book: .rov)
                        if let fieldError {
                            Text(fieldError)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.danger)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("rovFieldError")
                        }
                        LogWhenCard(start: $start, end: $end, idPrefix: "rov")
                        jobCard
                        tasksCard
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(existing == nil ? "New ROV entry" : "Edit ROV entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("rovCancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .tint(AppTheme.teal)
                        .disabled(missingOther != nil)
                        .accessibilityIdentifier("rovSave")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = false }
                        .accessibilityIdentifier("rovKeyboardDone")
                }
            }
            .onAppear(perform: prefillVessel)
        }
        .accessibilityIdentifier("rovEntrySheet")
    }

    // MARK: Job

    private var jobCard: some View {
        AHSectionCard(title: "Job", systemImage: "ferry") {
            LogVesselRow(vessel: $vessel, shipNames: shipNames, idPrefix: "rov", focus: $focusedField)
            LogPositionRow(raw: $gradeRaw, options: BookPositions.rov, idPrefix: "rov")
            if grade?.isOther == true {
                LogOtherTextRow(title: "Other position", text: $gradeOther, identifier: "rovPositionOther", focus: $focusedField)
            }
            AHFieldRow(title: "Under training") {
                Toggle("Under training", isOn: $underTraining)
                    .labelsHidden()
                    .tint(AppTheme.teal)
                    .accessibilityIdentifier("rovUnderTraining")
            }
            AHFieldRow(title: "ROV system", showsDivider: false) {
                LogInlineTextField(title: "ROV system", text: $rovSystem, identifier: "rovSystem", focus: $focusedField)
            }

            LogFieldCaption(title: "ROV class")
                .padding(.top, 10)
            AHSegmented(
                options: ROVClass.allCases,
                selection: $rovClass,
                allowsClear: true,
                label: \.label,
                spokenLabel: { $0.spokenLabel },
                identifier: { "rovClass_\($0.rawValue)" }
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel("ROV class")
            LogFieldNote(text: rovClass?.caption ?? "Not set")
                .accessibilityIdentifier("rovClassCaption")
                .padding(.bottom, 4)

            Rectangle().fill(AppTheme.border).frame(height: 1)

            AHFieldRow(title: "Field or area", showsDivider: false) {
                LogInlineTextField(title: "Field or area", text: $fieldArea, identifier: "rovFieldArea", focus: $focusedField)
            }
            LogFieldNote(text: "Name only. No coordinates.")

            LogFieldCaption(title: "Job type")
                .padding(.top, 10)
            LogChoiceFlow(
                options: ROVJobType.allCases,
                selection: $jobType,
                label: \.label,
                spokenLabel: { $0.spokenLabel },
                identifier: { "rovJobType_\($0.rawValue)" }
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Job type")
        }
    }

    // MARK: Tasks, hours, remarks

    private var tasksCard: some View {
        AHSectionCard(title: "Tasks done", systemImage: "checklist") {
            LogChipSet(
                options: ROVTask.allCases,
                selection: $tasks,
                label: \.label,
                spokenLabel: { $0.spokenLabel },
                identifier: { "rovTask_\($0.rawValue)" }
            )
            .padding(.bottom, 10)

            numberTiles
            LogFieldNote(text: "Your own time at the controls, not the shift length.")
                .padding(.top, 2)

            AHFieldRow(title: "Support site") {
                LogMenuPicker(
                    title: "Support site",
                    options: ROVSupportSite.allCases,
                    selection: $supportSite,
                    label: \.label,
                    spokenLabel: { $0.spokenLabel },
                    identifier: "rovSupportSitePicker"
                )
            }
            .padding(.top, 6)
            if supportSite?.isOther == true {
                LogOtherTextRow(title: "Other support site", text: $supportSiteOther, identifier: "rovSupportSiteOther", focus: $focusedField)
            }
            if let missingOther {
                LogFieldNote(text: LogOtherText.message(for: missingOther))
                    .accessibilityIdentifier("rovOtherNeeded")
            }

            LogRemarksField(text: $remarks, identifier: "rovRemarks", focus: $focusedField)
        }
    }

    // Plain Grid/VStack, not LazyVGrid: both tiles stay in the view tree for VoiceOver and UI tests.
    @ViewBuilder
    private var numberTiles: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                pilotingTile
                divesTile
            }
        } else {
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    pilotingTile
                    divesTile
                }
            }
        }
    }

    private var pilotingTile: some View {
        AHValueTile(title: "Piloting hours") {
            AHNumberField(title: "Piloting hours", unit: "h", spokenUnit: "hours", text: $pilotingHoursText, identifier: "rovPilotingHours")
                .focused($focusedField)
        }
    }

    private var divesTile: some View {
        AHValueTile(title: "Dives") {
            AHNumberField(title: "Dives", unit: "", spokenUnit: "", text: $divesText, identifier: "rovDives", keyboard: .numberPad)
                .focused($focusedField)
        }
    }

    // MARK: Prefill and save

    private var grade: ROVGrade? { ROVGrade(rawValue: gradeRaw) }

    /// Label of an "Other" pick whose text is still blank; Save is disabled while set.
    private var missingOther: String? {
        LogOtherText.firstMissing([
            (label: "Position", choice: grade, text: gradeOther),
            (label: "Support site", choice: supportSite, text: supportSiteOther),
        ])
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
        let numbers = ROVNumberInput(pilotingHours: pilotingHoursText, dives: divesText)
        if let problem = numbers.firstProblem {
            fieldError = problem
            return
        }

        let target = existing ?? ROVEntry(date: start)
        if existing == nil {
            modelContext.insert(target)
        }
        target.date = start
        target.endTime = end
        target.vessel = LogEntryCheck.optionalText(vessel)
        target.gradeRaw = gradeRaw.isEmpty ? nil : gradeRaw
        target.gradeOther = LogOtherText.stored(grade, text: gradeOther)
        target.underTraining = LogEntryCheck.underTraining(isOn: underTraining, previous: target.underTraining)
        target.rovSystem = LogEntryCheck.optionalText(rovSystem)
        target.rovClass = rovClass
        target.fieldArea = LogEntryCheck.optionalText(fieldArea)
        target.jobType = jobType
        target.tasks = tasks
        target.pilotingHours = numbers.pilotingHoursValue
        target.dives = numbers.divesValue
        target.supportSite = supportSite
        target.supportSiteOther = LogOtherText.stored(supportSite, text: supportSiteOther)
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
