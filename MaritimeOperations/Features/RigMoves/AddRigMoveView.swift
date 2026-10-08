import SwiftUI
import SwiftData
import PhotosUI
import UIKit

/// Anchor handling entry form. Saves into the existing RigMove record (one entry = one AH job).
/// Only the rig name is required; every AH field is optional and starts empty.
struct AddRigMoveView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \DPEntry.date, order: .reverse) private var entries: [DPEntry]
    @Query(sort: \RigMove.createdAt, order: .reverse) private var moves: [RigMove]
    @Query private var rovEntries: [ROVEntry]
    @Query private var craneEntries: [CraneEntry]

    private let existing: RigMove?

    // When
    @State private var start: Date
    @State private var finish: Date
    // Job
    @State private var vessel: String
    @State private var rank: String
    @State private var underTraining: Bool
    @State private var rigName: String
    @State private var unitType: AHUnitType?
    @State private var fieldArea: String
    @State private var jobType: AHJobType?
    // Tasks / control / remarks
    @State private var tasks: Set<AHTask>
    @State private var controlMode: AHControlMode?
    @State private var notes: String
    // More details
    @State private var showMoreDetails: Bool
    @State private var supervised: AHYesNo?
    @State private var anchorCountText: String
    @State private var anchorIDs: String
    @State private var waterDepthText: String
    @State private var paidOutText: String
    @State private var tensionText: String
    @State private var waveHeightText: String
    @State private var windText: String
    @State private var windDirection: String
    // Earlier rig move fields (kept so nothing on older rows is lost)
    @State private var client: String
    @State private var fromLocation: String
    @State private var toLocation: String
    @State private var hasChain: Bool
    @State private var hasWire: Bool
    @State private var hasFiber: Bool
    @State private var hasSubBuoys: Bool
    @State private var hasOther: Bool
    @State private var otherEquipment: String
    @State private var photoData: Data?
    @State private var isDone: Bool

    @State private var didPrefill = false
    @State private var fieldError: String?
    @State private var showShipPicker = false
    @State private var showPhotoSource = false
    @State private var showLibraryPicker = false
    @State private var showCamera = false
    @State private var libraryItem: PhotosPickerItem?
    @FocusState private var focusedField: Bool

    init(existing: RigMove? = nil) {
        self.existing = existing
        let now = Date()
        _start = State(initialValue: existing?.startTime ?? existing?.date ?? now)
        _finish = State(initialValue: existing?.endTime ?? existing?.startTime ?? existing?.date ?? now)
        _vessel = State(initialValue: existing?.vessel ?? "")
        _rank = State(initialValue: existing?.rank ?? "")
        _underTraining = State(initialValue: existing?.ahUnderTraining ?? false)
        _rigName = State(initialValue: existing?.rigName ?? "")
        _unitType = State(initialValue: existing?.ahUnitType)
        _fieldArea = State(initialValue: existing?.ahFieldArea ?? "")
        _jobType = State(initialValue: existing?.ahJobType ?? .default)
        _tasks = State(initialValue: existing?.ahTasks ?? [])
        _controlMode = State(initialValue: existing?.ahControlMode)
        _notes = State(initialValue: existing?.notes ?? "")
        _supervised = State(initialValue: AHYesNo(existing?.ahSupervised))
        let count = existing?.anchorLineCount ?? 0
        _anchorCountText = State(initialValue: count > 0 ? "\(count)" : "")
        _anchorIDs = State(initialValue: existing?.ahAnchorIDs ?? "")
        _waterDepthText = State(initialValue: AHNumber.text(existing?.ahWaterDepthM))
        _paidOutText = State(initialValue: AHNumber.text(existing?.ahMaxPaidOutM))
        _tensionText = State(initialValue: AHNumber.text(existing?.ahPeakTensionT))
        _waveHeightText = State(initialValue: AHNumber.text(existing?.ahWaveHeightM))
        _windText = State(initialValue: AHNumber.text(existing?.ahWindKn))
        _windDirection = State(initialValue: existing?.ahWindDirection ?? "")
        _client = State(initialValue: existing?.client ?? "")
        _fromLocation = State(initialValue: existing?.fromLocation ?? "")
        _toLocation = State(initialValue: existing?.toLocation ?? "")
        _hasChain = State(initialValue: existing?.hasChain ?? false)
        _hasWire = State(initialValue: existing?.hasWire ?? false)
        _hasFiber = State(initialValue: existing?.hasFiber ?? false)
        _hasSubBuoys = State(initialValue: existing?.hasSubBuoys ?? false)
        _hasOther = State(initialValue: existing?.hasOther ?? false)
        _otherEquipment = State(initialValue: existing?.otherEquipment ?? "")
        _photoData = State(initialValue: existing?.photoJPEG)
        _isDone = State(initialValue: existing?.isDone ?? false)
        _showMoreDetails = State(initialValue: existing?.hasAHMoreDetails ?? false)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppCanvas()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        bookHeader
                        if let fieldError {
                            Text(fieldError)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.danger)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("ahFieldError")
                        }
                        whenCard
                        jobCard
                        tasksCard
                        moreDetailsCard
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(existing == nil ? "New entry" : "Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("rigMoveCancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .tint(AppTheme.teal)
                        .accessibilityIdentifier("rigMoveSave")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = false }
                        .accessibilityIdentifier("ahKeyboardDone")
                }
            }
            .onAppear(perform: prefillFromLastEntry)
            .sheet(isPresented: $showShipPicker) {
                ShipPickerSheet(names: loggedShipNames) { name in
                    vessel = name
                }
            }
            .confirmationDialog("Photo", isPresented: $showPhotoSource, titleVisibility: .visible) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take photo") { showCamera = true }
                }
                Button("Choose photo") { showLibraryPicker = true }
                if photoData != nil {
                    Button("Remove photo", role: .destructive) { photoData = nil }
                }
                Button("Cancel", role: .cancel) {}
            }
            .photosPicker(isPresented: $showLibraryPicker, selection: $libraryItem, matching: .images)
            .onChange(of: libraryItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            photoData = jpegData(from: data)
                            libraryItem = nil
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    photoData = jpegData(from: image)
                    showCamera = false
                } onCancel: {
                    showCamera = false
                }
                .ignoresSafeArea()
            }
        }
        .accessibilityIdentifier("rigMoveSheet")
    }

    // MARK: Header

    private var bookHeader: some View {
        HStack(spacing: 8) {
            Label {
                Text("Anchor handling")
            } icon: {
                AnchorIcon(scale: 0.8)
                    .foregroundStyle(AppTheme.teal)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.textPrimary.opacity(0.85))
            AHTag(title: "Rig Moves")
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Anchor handling book, Rig Moves")
    }

    // MARK: When

    private var whenCard: some View {
        AHSectionCard(title: "When", systemImage: "calendar") {
            AHFieldRow(title: "Start") {
                DatePicker("Start", selection: $start, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .accessibilityLabel("Start")
                    .accessibilityIdentifier("rigStart")
            }
            AHFieldRow(title: "End") {
                DatePicker("End", selection: $finish, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .accessibilityLabel("End")
                    .accessibilityIdentifier("rigFinish")
            }
            durationLayout {
                Label {
                    Text("Duration")
                } icon: {
                    Image(systemName: "clock")
                        .accessibilityHidden(true)
                }
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: 8)
                }
                HStack(spacing: 8) {
                    Text(durationCopy)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("rigHours")
                    AHTag(title: "auto")
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(AppTheme.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            .padding(.top, 8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Duration, \(durationCopy), calculated")
        }
    }

    private var durationLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(spacing: 8))
    }

    private var durationCopy: String {
        AHFormat.duration(start: start, end: finish) ?? "End is before start"
    }

    // MARK: Job

    private var jobCard: some View {
        AHSectionCard(title: "Job", systemImage: "ferry") {
            AHFieldRow(title: "Vessel") {
                HStack(spacing: 8) {
                    inlineTextField("Vessel", text: $vessel, identifier: "ahVessel")
                    if !loggedShipNames.isEmpty {
                        Button {
                            showShipPicker = true
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Pick a logged ship")
                        .accessibilityIdentifier("ahPickLoggedShip")
                    }
                }
            }
            AHFieldRow(title: "Position") {
                Menu {
                    Picker("Position", selection: $rank) {
                        Text("Not set").tag("")
                        if !rank.isEmpty, !CrewRank.ahPositionCases.contains(where: { $0.rawValue == rank }) {
                            Text(rank).tag(rank)
                        }
                        ForEach(CrewRank.ahPositionCases) { value in
                            Text(value.rawValue).tag(value.rawValue)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        AHValueText(value: rank)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .accessibilityLabel("Position")
                .accessibilityValue(rank.isEmpty ? "Not set" : (CrewRank(rawValue: rank)?.spokenName ?? rank))
                .accessibilityIdentifier("ahPositionPicker")
            }
            AHFieldRow(title: "Under training") {
                Toggle("Under training", isOn: $underTraining)
                    .labelsHidden()
                    .tint(AppTheme.teal)
                    .accessibilityIdentifier("ahUnderTraining")
            }
            AHFieldRow(title: "Rig name") {
                inlineTextField("Rig name", text: $rigName, prompt: "Required", identifier: "ahRigName")
            }
            AHFieldRow(title: "Unit type") {
                Menu {
                    Picker("Unit type", selection: $unitType) {
                        Text("Not set").tag(AHUnitType?.none)
                        ForEach(AHUnitType.allCases) { value in
                            Text(value.label).tag(AHUnitType?.some(value))
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        AHValueText(value: unitType?.label)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .accessibilityLabel("Unit type")
                .accessibilityValue(unitType?.label ?? "Not set")
                .accessibilityIdentifier("ahUnitTypePicker")
            }
            AHFieldRow(title: "Field or area", showsDivider: false) {
                inlineTextField("Field or area", text: $fieldArea, identifier: "ahFieldArea")
            }
            Text("Name only. No coordinates.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Job type")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.top, 10)
            AHSegmented(
                options: AHJobType.allCases,
                selection: $jobType,
                label: \.label,
                spokenLabel: { $0.spokenLabel },
                identifier: { "ahJobType_\($0.rawValue)" }
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Job type")
        }
    }

    // MARK: Tasks, control, remarks

    private var tasksCard: some View {
        AHSectionCard(title: "Tasks done", systemImage: "checklist") {
            AHFlowLayout(spacing: 8) {
                ForEach(AHTask.allCases) { task in
                    AHChip(
                        title: task.label,
                        spokenTitle: task.spokenLabel,
                        isOn: tasks.contains(task),
                        identifier: "ahTask_\(task.rawValue)"
                    ) {
                        if tasks.contains(task) {
                            tasks.remove(task)
                        } else {
                            tasks.insert(task)
                        }
                    }
                }
            }
            .padding(.bottom, 10)

            Rectangle().fill(AppTheme.border).frame(height: 1)

            AHFieldRow(title: "DP or Manual", showsDivider: false) {
                AHSegmented(
                    options: AHControlMode.allCases,
                    selection: $controlMode,
                    allowsClear: true,
                    label: \.label,
                    spokenLabel: { $0 == .dp ? "D P" : $0.label },
                    identifier: { "ahControl_\($0.rawValue)" }
                )
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 170)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Remarks")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                TextField("Remarks", text: $notes, prompt: Text("Own notes, in your own words").foregroundStyle(AppTheme.textSecondary), axis: .vertical)
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.sentences)
                    .lineLimit(3...8)
                    .focused($focusedField)
                    .padding(12)
                    .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    }
                    .accessibilityIdentifier("ahRemarks")
            }
            .padding(.top, 6)
        }
    }

    // MARK: More details

    private var moreDetailsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showMoreDetails.toggle() }
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("More details")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("optional")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer(minLength: 8)
                        Image(systemName: showMoreDetails ? "chevron.up" : "chevron.down")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.teal)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("More details, optional")
                .accessibilityValue(showMoreDetails ? "Expanded" : "Collapsed")
                .accessibilityIdentifier("ahMoreDetailsToggle")

                if showMoreDetails {
                    moreDetailsContent
                }
            }
        }
    }

    private var moreDetailsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            AHFieldRow(title: "Supervised", showsDivider: false) {
                AHSegmented(
                    options: AHYesNo.allCases,
                    selection: $supervised,
                    allowsClear: true,
                    label: \.label,
                    identifier: { "ahSupervised_\($0.rawValue)" }
                )
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 170)
            }

            detailTiles

            AHValueTile(title: "Wind") {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    AHNumberField(title: "Wind", unit: "kn", spokenUnit: "knots", text: $windText, identifier: "ahWind")
                        .focused($focusedField)
                    Text("·")
                        .foregroundStyle(AppTheme.textSecondary)
                        .accessibilityHidden(true)
                    TextField("Wind direction", text: $windDirection, prompt: Text("Dir.").foregroundStyle(AppTheme.textSecondary))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .textInputAutocapitalization(.characters)
                        .focused($focusedField)
                        .accessibilityIdentifier("ahWindDirection")
                }
            }

            Text("Own approximate readings. Not copied from client charts.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            earlierFields
        }
    }

    // Plain Grid/VStack, not LazyVGrid: all six tiles stay in the view tree, so VoiceOver,
    // UI tests and keyboard focus can reach a tile that is below the fold.
    @ViewBuilder
    private var detailTiles: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                anchorCountTile
                anchorIDsTile
                waterDepthTile
                paidOutTile
                tensionTile
                waveHeightTile
            }
        } else {
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    anchorCountTile
                    anchorIDsTile
                }
                GridRow {
                    waterDepthTile
                    paidOutTile
                }
                GridRow {
                    tensionTile
                    waveHeightTile
                }
            }
        }
    }

    private var anchorCountTile: some View {
        AHValueTile(title: "Anchor count") {
            AHNumberField(title: "Anchor count", unit: "", spokenUnit: "", text: $anchorCountText, identifier: "ahAnchorCount", keyboard: .numberPad)
                .focused($focusedField)
        }
    }

    private var anchorIDsTile: some View {
        AHValueTile(title: "Anchor IDs") {
            TextField("Anchor IDs", text: $anchorIDs, prompt: Text("#2, #3").foregroundStyle(AppTheme.textSecondary))
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .textInputAutocapitalization(.never)
                .focused($focusedField)
                .accessibilityIdentifier("ahAnchorIDs")
        }
    }

    private var waterDepthTile: some View {
        AHValueTile(title: "Water depth") {
            AHNumberField(title: "Water depth", unit: "m", spokenUnit: "metres", text: $waterDepthText, identifier: "ahWaterDepth")
                .focused($focusedField)
        }
    }

    private var paidOutTile: some View {
        AHValueTile(title: "Max wire paid out") {
            AHNumberField(title: "Max wire paid out", unit: "m", spokenUnit: "metres", text: $paidOutText, identifier: "ahMaxPaidOut")
                .focused($focusedField)
        }
    }

    private var tensionTile: some View {
        AHValueTile(title: "Approx. peak tension") {
            AHNumberField(title: "Approximate peak tension", unit: "t", spokenUnit: "tonnes", text: $tensionText, identifier: "ahPeakTension")
                .focused($focusedField)
        }
    }

    private var waveHeightTile: some View {
        AHValueTile(title: "Wave height") {
            AHNumberField(title: "Wave height", unit: "m", spokenUnit: "metres", text: $waveHeightText, identifier: "ahWaveHeight")
                .focused($focusedField)
        }
    }

    /// Rig move fields from before the AH form. Kept so older rows keep (and can edit) their data.
    private var earlierFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Move details")
                .font(.caption.weight(.semibold))
                .tracking(1.1)
                .foregroundStyle(AppTheme.teal)
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)

            if let earlierTag {
                Text(earlierTag)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("rigEarlierJobTag")
            }

            labeledField("Client or operator", text: $client, capitalize: .words)
            labeledField("From", text: $fromLocation, capitalize: .words)
            labeledField("To", text: $toLocation, capitalize: .words)

            VStack(alignment: .leading, spacing: 8) {
                Text("Line equipment")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                equipToggle("Chain", isOn: $hasChain, identifier: "equipChain")
                equipToggle("Wire", isOn: $hasWire, identifier: "equipWire")
                equipToggle("Fiber", isOn: $hasFiber, identifier: "equipFiber")
                equipToggle("Sub-buoys", isOn: $hasSubBuoys, identifier: "equipSubBuoys")
                equipToggle("Other", isOn: $hasOther, identifier: "equipOther")
            }
            if hasOther {
                labeledField("Other equipment", text: $otherEquipment, capitalize: .sentences)
            }
            photoSection
            Toggle("Done", isOn: $isDone)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .tint(AppTheme.teal)
                .accessibilityIdentifier("rigMoveDone")
        }
    }

    /// Older rows tagged Towing / Pre-lay / Project keep that tag; shown read-only.
    private var earlierTag: String? {
        guard let existing, existing.operation != .anchorHandling else { return nil }
        var line = "Earlier tag: \(existing.operation.label)"
        if existing.operation == .project, !existing.projectText.isEmpty {
            line += " – \(existing.projectText)"
        }
        return line
    }

    // MARK: Field helpers

    private func inlineTextField(_ title: String, text: Binding<String>, prompt: String = "Not set", identifier: String) -> some View {
        TextField(title, text: text, prompt: Text(prompt).foregroundStyle(AppTheme.textSecondary))
            .textFieldStyle(.plain)
            .textInputAutocapitalization(.words)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.textPrimary)
            .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
            .focused($focusedField)
            .accessibilityIdentifier(identifier)
    }

    private func labeledField(
        _ title: String,
        text: Binding<String>,
        capitalize: TextInputAutocapitalization
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            TextField(title, text: text)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(capitalize)
                .focused($focusedField)
                .padding(12)
                .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                }
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Photo")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            if let photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    }
                    .accessibilityLabel("Photo for this move")
                    .accessibilityIdentifier("rigMovePhotoThumb")
                HStack(spacing: 12) {
                    Button("Replace photo") { showPhotoSource = true }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.teal)
                        .accessibilityIdentifier("rigMoveReplacePhoto")
                    Button("Remove photo", role: .destructive) { self.photoData = nil }
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("rigMoveRemovePhoto")
                }
            } else {
                Button {
                    showPhotoSource = true
                } label: {
                    Text("Add photo")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(AppTheme.textPrimary)
                        .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppTheme.border, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("rigMoveAddPhoto")
            }
        }
    }

    private func equipToggle(_ title: String, isOn: Binding<Bool>, identifier: String) -> some View {
        Toggle(title, isOn: isOn)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.textPrimary)
            .tint(AppTheme.teal)
            .accessibilityIdentifier(identifier)
    }

    private func jpegData(from data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        return jpegData(from: image) ?? data
    }

    private func jpegData(from image: UIImage) -> Data? {
        image.jpegData(compressionQuality: 0.72)
    }

    private var loggedShipNames: [String] {
        BookVesselPrefill.loggedShipNames(dpLines: entries, ahEntries: moves, rovEntries: rovEntries, craneEntries: craneEntries)
    }

    /// A new entry starts with the ship of the newest DP, AH, ROV or Crane entry. Position stays "Not set".
    private func prefillFromLastEntry() {
        guard existing == nil, !didPrefill else { return }
        didPrefill = true
        vessel = BookVesselPrefill.vessel(dpLines: entries, ahEntries: moves, rovEntries: rovEntries, craneEntries: craneEntries)
    }

    // MARK: Save

    private func save() {
        if let block = RigMoveCheck.block(
            rigName: rigName,
            start: start,
            finish: finish,
            operation: existing?.operation ?? .anchorHandling,
            projectText: existing?.projectText ?? "",
            hasOther: hasOther,
            otherEquipment: otherEquipment
        ) {
            fieldError = block.message
            return
        }
        let numbers = AHNumberInput(
            anchorCount: anchorCountText,
            waterDepth: waterDepthText,
            paidOut: paidOutText,
            tension: tensionText,
            waveHeight: waveHeightText,
            wind: windText
        )
        if let bad = numbers.firstInvalidField {
            fieldError = "\(bad) must be a number."
            return
        }

        let name = rigName.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = existing ?? RigMove(rigName: name)
        if existing == nil {
            modelContext.insert(target)
        }
        target.rigName = name
        target.date = start
        target.startTime = start
        target.endTime = finish
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        target.isDone = isDone
        target.client = client.trimmingCharacters(in: .whitespacesAndNewlines)
        target.fromLocation = fromLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        target.toLocation = toLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        target.vessel = vessel.trimmingCharacters(in: .whitespacesAndNewlines)
        target.rank = rank
        target.anchorLineCount = numbers.anchorCountValue ?? 0
        target.hasChain = hasChain
        target.hasWire = hasWire
        target.hasFiber = hasFiber
        target.hasSubBuoys = hasSubBuoys
        target.hasOther = hasOther
        target.otherEquipment = hasOther
            ? otherEquipment.trimmingCharacters(in: .whitespacesAndNewlines)
            : ""
        target.photoJPEG = photoData

        // AH fields. An untouched field stays nil.
        target.ahJobType = jobType ?? .default
        target.ahUnderTraining = underTraining ? true : (target.ahUnderTraining == nil ? nil : false)
        target.ahUnitType = unitType
        target.ahFieldArea = AHText.optional(fieldArea)
        target.ahTasks = tasks
        target.ahControlMode = controlMode
        target.ahSupervised = supervised?.boolValue
        target.ahAnchorIDs = AHText.optional(anchorIDs)
        target.ahWaterDepthM = numbers.waterDepthValue
        target.ahMaxPaidOutM = numbers.paidOutValue
        target.ahPeakTensionT = numbers.tensionValue
        target.ahWaveHeightM = numbers.waveHeightValue
        target.ahWindKn = numbers.windValue
        target.ahWindDirection = AHText.optional(windDirection)

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

private struct CameraPicker: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onCapture: (UIImage) -> Void
        let onCancel: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            } else {
                onCancel()
            }
        }
    }
}
