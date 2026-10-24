import SwiftUI

/// Pushed list for Lift weight: the locked presets, Not set, and Other… (one decimal).
struct CraneLiftWeightList: View {
    @Binding var tonnes: Double?
    @Binding var isOther: Bool
    @Binding var otherText: String

    @Environment(\.dismiss) private var dismiss
    @FocusState private var otherFocused: Bool

    var body: some View {
        ZStack {
            AppCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    GlassCard {
                        VStack(spacing: 0) {
                            choice(
                                title: "Not set",
                                spoken: "Not set",
                                selected: tonnes == nil && !isOther,
                                identifier: "craneLiftWeight_none"
                            ) {
                                clear()
                            }
                            hairline
                            ForEach(CraneLiftWeight.presets, id: \.self) { preset in
                                choice(
                                    title: CraneLiftWeight.tonnesLabel(preset) ?? "",
                                    spoken: CraneLiftWeight.spokenTonnes(preset),
                                    selected: presetSelected(preset),
                                    identifier: "craneLiftWeight_\(CraneLiftWeight.presetTag(preset))"
                                ) {
                                    select(preset)
                                }
                                hairline
                            }
                            choice(
                                title: "Other\u{2026}",
                                spoken: "Other",
                                selected: isOther,
                                identifier: "craneLiftWeight_other"
                            ) {
                                selectOther()
                            }
                            if isOther {
                                hairline
                                otherField
                                    .padding(.top, 8)
                            }
                        }
                    }
                    LogFieldNote(text: CraneLiftWeight.weightCaption)
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Lift weight")
        .navigationBarTitleDisplayMode(.inline)
        .systemGlassNavigation()
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { otherFocused = false }
                    .accessibilityIdentifier("craneLiftWeightKeyboardDone")
            }
        }
        .accessibilityIdentifier("craneLiftWeightList")
    }

    private var otherField: some View {
        AHValueTile(title: "Tonnes") {
            AHNumberField(
                title: "Lift weight",
                unit: "t",
                spokenUnit: "tonnes",
                text: $otherText,
                identifier: "craneLiftWeightOther",
                spokenValue: CraneLiftWeight.spokenWeightField(otherText)
            )
            .focused($otherFocused)
        }
    }

    private var hairline: some View {
        Rectangle()
            .fill(AppTheme.border)
            .frame(height: 1)
    }

    private func choice(
        title: String,
        spoken: String,
        selected: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.subheadline.weight(selected ? .semibold : .regular))
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.teal)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(identifier)
    }

    private func presetSelected(_ preset: Double) -> Bool {
        guard !isOther, let tonnes else { return false }
        return CraneLiftWeight.matches(tonnes, preset)
    }

    private func clear() {
        tonnes = nil
        isOther = false
        otherText = ""
        dismiss()
    }

    private func select(_ preset: Double) {
        tonnes = preset
        isOther = false
        otherText = ""
        dismiss()
    }

    /// Other keeps the current number in the field so a switch does not wipe a saved estimate.
    private func selectOther() {
        if !isOther, let tonnes {
            otherText = CraneLiftWeight.amount(tonnes, fractionDigits: 1)
        }
        isOther = true
        tonnes = nil
        otherFocused = true
    }
}

/// Form row that pushes the lift-weight list. Whole row is one button.
struct CraneLiftWeightLinkLabel: View {
    let value: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        layout {
            Text("Lift weight")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if !stacked {
                Spacer(minLength: 8)
            }
            HStack(spacing: 4) {
                AHValueText(value: value)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
