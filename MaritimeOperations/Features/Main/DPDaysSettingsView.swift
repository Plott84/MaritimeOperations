import SwiftUI

/// DP day target and the optional issue date. Reached from Main and from the no-target hint.
struct DPDaysSettingsView: View {
    @AppStorage(DPDaysSettings.targetTextKey) private var targetText = DPDaysSettings.defaultTargetText
    @AppStorage(DPDaysSettings.certificateKey) private var certificateISO = ""
    @FocusState private var targetFocused: Bool

    var body: some View {
        ZStack {
            AppCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("DP days")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    GlassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            targetSection
                            Rectangle()
                                .fill(AppTheme.border)
                                .frame(height: 1)
                                .accessibilityHidden(true)
                            certificateSection
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollEdgeEffectStyle(.hard, for: .top)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .systemGlassNavigation()
        .accessibilityIdentifier("dpDaysSettings")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { targetFocused = false }
            }
        }
    }

    private var targetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DP day target")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
                .accessibilityHidden(true)
            HStack(spacing: 0) {
                TextField(
                    "DP day target",
                    text: $targetText,
                    prompt: Text("Empty").foregroundStyle(AppTheme.textSecondary)
                )
                .textFieldStyle(.plain)
                .keyboardType(.numberPad)
                .autocorrectionDisabled()
                .monospacedDigit()
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.leading, 12)
                .frame(minHeight: 44)
                .focused($targetFocused)
                .accessibilityIdentifier("dpDayTarget")
                .onChange(of: targetText) { _, newValue in
                    let digits = String(newValue.filter(\.isNumber).prefix(6))
                    if digits != newValue { targetText = digits }
                }

                if !targetText.isEmpty {
                    Button {
                        targetText = ""
                    } label: {
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
                    .accessibilityIdentifier("dpDayTargetClear")
                }
            }
            .padding(.trailing, 4)
            .background(AppTheme.pickerFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(AppTheme.fieldBorder, lineWidth: 1)
            }
            Text("A whole number. Clear the field, or enter 0, to hide the ratio and the bar.")
                .font(.footnote)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var certificateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Certificate issued")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
                .accessibilityHidden(true)
            if DPDaysSettings.parsedCertificate(certificateISO) != nil {
                HStack(spacing: 12) {
                    DatePicker(
                        "Certificate issued",
                        selection: certificateBinding,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerChrome()
                    .accessibilityIdentifier("certificateIssuedPicker")
                    Spacer(minLength: 8)
                    Button("Clear") { certificateISO = "" }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.teal)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("certificateIssuedClear")
                }
            } else {
                Button {
                    certificateISO = DPDaysSettings.isoString(from: .now, timeZone: .current)
                } label: {
                    HStack {
                        Text("Not set")
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Image(systemName: "calendar")
                            .foregroundStyle(AppTheme.teal)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(AppTheme.pickerFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(AppTheme.fieldBorder, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Certificate issued")
                .accessibilityValue("Not set")
                .accessibilityIdentifier("certificateIssuedNotSet")
            }
            Text("Optional. If this date is later than today minus 5 years, the window starts the day after it. The issue date itself is outside the window.")
                .font(.footnote)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var certificateBinding: Binding<Date> {
        Binding(
            get: {
                guard let day = DPDaysSettings.parsedCertificate(certificateISO),
                      let date = day.date(timeZone: .current) else { return .now }
                return date
            },
            set: { newValue in
                certificateISO = DPDaysSettings.isoString(from: newValue, timeZone: .current)
            }
        )
    }
}
