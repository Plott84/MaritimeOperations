import SwiftUI

/// New-watch card. Only vessel and DP class are copied, into this card's own values.
struct StartDPPrefillCard: View {
    let vessel: String
    let dpClassLevel: Int?
    let hasPreviousEntry: Bool
    let prefilledVessel: String
    let prefilledClass: Int?
    let suggestions: [String]
    let onVessel: (String) -> Void
    let onClass: (Int?) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showingVesselEditor = false
    @State private var showingClassChoices = false

    var body: some View {
        SpecSolidCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(DPStartPrefill.title)
                        .font(.caption.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(AppTheme.teal)
                        .accessibilityAddTraits(.isHeader)
                    Text(hasPreviousEntry ? DPStartPrefill.fromLastEntry : DPStartPrefill.noPreviousEntry)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textSecondary)
                        .accessibilityIdentifier("startDPPrefillCaption")
                }

                field(title: "Vessel") {
                    if vessel.isEmpty {
                        emptyChip(DPStartPrefill.addVessel, identifier: "startDPVesselChip") {
                            showingVesselEditor = true
                        }
                        .accessibilityLabel("Vessel, \(DPStartPrefill.addVessel)")
                    } else {
                        filledChip(
                            vessel,
                            identifier: "startDPVesselChip",
                            clearIdentifier: "startDPVesselClear",
                            accessibilityLabel: vesselLabel,
                            onEdit: { showingVesselEditor = true },
                            onClear: { onVessel("") }
                        )
                    }
                }

                field(title: "DP class") {
                    if let dpClassLevel {
                        filledChip(
                            "Class \(dpClassLevel)",
                            identifier: "startDPClassChip",
                            clearIdentifier: "startDPClassClear",
                            accessibilityLabel: classLabel(level: dpClassLevel),
                            onEdit: { showingClassChoices = true },
                            onClear: { onClass(nil) }
                        )
                    } else {
                        emptyChip(DPStartPrefill.chooseClass, identifier: "startDPClassChip") {
                            showingClassChoices = true
                        }
                        .accessibilityLabel("DP class, \(DPStartPrefill.chooseClass)")
                    }
                }

                VStack(spacing: 0) {
                    statusRow("Activity", "Empty")
                    hairline
                    statusRow("Start / end time", "Set by timer")
                    hairline
                    statusRow("Hours", "Set by timer")
                    hairline
                    statusRow("Notes", "Empty")
                }
            }
        }
        .accessibilityIdentifier("startDPNewWatch")
        .sheet(isPresented: $showingVesselEditor) {
            VesselChipSheet(name: vessel, suggestions: suggestions, onSave: onVessel)
        }
        .confirmationDialog("DP class", isPresented: $showingClassChoices, titleVisibility: .visible) {
            Button("Class 1") { onClass(1) }
            Button("Class 2") { onClass(2) }
            Button("Class 3") { onClass(3) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var vesselLabel: String {
        if hasPreviousEntry, vessel == prefilledVessel, !vessel.isEmpty {
            return "Vessel, \(vessel), from your last entry"
        }
        return "Vessel, \(vessel)"
    }

    private func classLabel(level: Int) -> String {
        if hasPreviousEntry, level == prefilledClass {
            return "DP class, Class \(level), from your last entry"
        }
        return "DP class, Class \(level)"
    }

    private func field(title: String, @ViewBuilder chip: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .accessibilityHidden(true)
            chip()
        }
    }

    private func emptyChip(_ title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .overlay {
            Capsule()
                .strokeBorder(AppTheme.fieldBorder, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
        .accessibilityIdentifier(identifier)
    }

    private func filledChip(
        _ title: String,
        identifier: String,
        clearIdentifier: String,
        accessibilityLabel: String,
        onEdit: @escaping () -> Void,
        onClear: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 0) {
            Button(action: onEdit) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.leading)
                    .padding(.leading, 14)
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityIdentifier(identifier)

            Button(action: onClear) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 20, height: 20)
                    .background(AppTheme.pickerFill, in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear")
            .accessibilityIdentifier(clearIdentifier)
        }
        .padding(.trailing, 2)
        .fixedSize(horizontal: true, vertical: false)
        .overlay {
            Capsule().strokeBorder(AppTheme.fieldBorder, lineWidth: 1)
        }
    }

    private func statusRow(_ title: String, _ value: String) -> some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
        return layout {
            Text(title)
            if !stacked { Spacer(minLength: 12) }
            Text(value)
                .multilineTextAlignment(stacked ? .leading : .trailing)
        }
        .font(.subheadline)
        .foregroundStyle(AppTheme.textSecondary)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value)")
    }

    private var hairline: some View {
        Rectangle()
            .fill(AppTheme.border)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

private struct VesselChipSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    let suggestions: [String]
    let onSave: (String) -> Void

    init(name: String, suggestions: [String], onSave: @escaping (String) -> Void) {
        _name = State(initialValue: name)
        self.suggestions = suggestions
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppCanvas()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Vessel")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                            TextField(
                                "Vessel",
                                text: $name,
                                prompt: Text("Vessel name").foregroundStyle(AppTheme.textSecondary)
                            )
                            .textInputAutocapitalization(.words)
                            .textFieldStyle(.plain)
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(12)
                            .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppTheme.fieldBorder, lineWidth: 1)
                            }
                            .accessibilityIdentifier("startDPVesselField")
                        }
                        if !suggestions.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Logged ships")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                ForEach(suggestions, id: \.self) { ship in
                                    Button {
                                        name = ship
                                    } label: {
                                        Text(ship)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(AppTheme.textPrimary)
                                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                            .padding(.horizontal, 12)
                                            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("shipOption_\(ship)")
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Vessel")
            .navigationBarTitleDisplayMode(.inline)
            .systemGlassNavigation()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("startDPVesselCancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .glassProminentSave()
                    .accessibilityIdentifier("startDPVesselSave")
                }
            }
        }
        .accessibilityIdentifier("startDPVesselSheet")
    }
}
