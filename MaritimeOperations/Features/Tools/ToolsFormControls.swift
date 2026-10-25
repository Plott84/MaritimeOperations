import SwiftUI
import UIKit

/// Caption + dark rounded number field used across Tools screens.
struct ToolNumberField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var unit: String? = nil
    var keyboard: UIKeyboardType = .decimalPad
    var isError: Bool = false
    var errorReason: String? = nil
    var accessibilityName: String? = nil
    /// Stable UITest id on the TextField itself (e.g. `winchField.wireDia`).
    var fieldAccessibilityIdentifier: String? = nil
    var systemImage: String? = nil
    /// Quiet word beside the title, e.g. "optional".
    var titleNote: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isError ? AppTheme.danger : AppTheme.teal)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(.caption.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(isError ? AppTheme.danger : AppTheme.textSecondary)
                if let titleNote {
                    Text(titleNote)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            HStack(spacing: 8) {
                TextField(
                    "",
                    text: $text,
                    prompt: Text(placeholder.isEmpty ? title : placeholder)
                        .foregroundStyle(AppTheme.textSecondary)
                )
                    .keyboardType(keyboard)
                    .textFieldStyle(.plain)
                    .foregroundStyle(AppTheme.textPrimary)
                    .accessibilityLabel(accessibilityName ?? title)
                    .accessibilityIdentifier(fieldAccessibilityIdentifier ?? "")
                if let unit {
                    Text(unit)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isError ? AppTheme.danger : AppTheme.fieldBorder, lineWidth: isError ? 1.5 : 1)
            }
            if let errorReason, isError {
                Text(errorReason)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Hero result block: caption + large value (or em dash).
struct ToolResultHero: View {
    let caption: String
    let value: String
    var unit: String? = nil
    var warning: String? = nil
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(caption)
                .font(.caption.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(AppTheme.teal)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(value)
                    .font(.system(size: heroSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.textPrimary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                if let unit {
                    Text(unit)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            if let warning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.danger)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ToolResultRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(AppTheme.textPrimary)
        }
    }
}

struct ToolWarningPill: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(AppTheme.danger.opacity(0.85), in: Capsule())
    }
}

/// Mint status pill (e.g. seabed clearance).
struct ToolClearPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.teal)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(AppTheme.surface, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(AppTheme.fieldBorder, lineWidth: 1)
            }
    }
}

// MARK: - Keyboard

enum ToolsKeyboard {
    static func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}

extension View {
    /// Number-pad Done bar for Tools screens (Pixel / QA).
    /// `onDone` runs after dismiss so results can refresh if a screen gates on end-editing.
    func toolsKeyboardDone(onDone: (() -> Void)? = nil) -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    ToolsKeyboard.dismiss()
                    onDone?()
                }
            }
        }
    }
}


// MARK: - Teal segment bar

struct ToolSegmentOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    let accessibilityLabel: String
    let accessibilityIdentifier: String
    var id: Value { value }
}

/// Full-width teal selected segment. At least 44 pt. Stacks vertically at accessibility text sizes.
struct ToolSegmentBar<Value: Hashable>: View {
    let title: String
    var barIdentifier: String = ""
    @Binding var selection: Value
    let options: [ToolSegmentOption<Value>]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 4) { buttons }
            } else {
                HStack(spacing: 4) { buttons }
            }
        }
        .padding(3)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(AppTheme.pickerFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AppTheme.fieldBorder, lineWidth: 1)
        }
        .accessibilityIdentifier(barIdentifier.isEmpty ? title : barIdentifier)
    }

    private var buttons: some View {
        ForEach(options) { option in
            segmentButton(option)
        }
    }

    private func segmentButton(_ option: ToolSegmentOption<Value>) -> some View {
        let selected = selection == option.value
        return Button {
            selection = option.value
        } label: {
            Text(option.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? AppTheme.onTeal : AppTheme.textPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(AppTheme.teal)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.accessibilityLabel)
        .accessibilityAddTraits(selected ? AccessibilityTraits.isSelected : AccessibilityTraits())
        .accessibilityIdentifier(option.accessibilityIdentifier)
    }
}

// MARK: - Degrees + minutes

/// Whole-degrees field + minutes field, a hemisphere segment,
/// optional quiet echo line ("= 20°15.3′ N") and inline error.
struct ToolDegMinInput<Hemi: Hashable>: View {
    let title: String
    @Binding var degrees: String
    @Binding var minutes: String
    @Binding var hemisphere: Hemi
    let hemispheres: [(Hemi, String)]
    let hemisphereLabel: String
    var echo: String? = nil
    var errorReason: String? = nil
    var identifier: String
    var systemImage: String? = nil
    var hemisphereAccessibility: [String]? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(errorReason != nil ? AppTheme.danger : AppTheme.teal)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(.caption.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(errorReason != nil ? AppTheme.danger : AppTheme.textSecondary)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { degField; minField }
                VStack(alignment: .leading, spacing: 8) { degField; minField }
            }
            ToolSegmentBar(
                title: hemisphereLabel,
                barIdentifier: "\(identifier).hemisphere",
                selection: $hemisphere,
                options: hemispheres.enumerated().map { index, pair in
                    let spoken = hemisphereAccessibility.flatMap { $0.indices.contains(index) ? $0[index] : nil } ?? pair.1
                    return ToolSegmentOption(
                        value: pair.0,
                        title: pair.1,
                        accessibilityLabel: "\(hemisphereLabel), \(spoken)",
                        accessibilityIdentifier: "\(identifier).hemisphere.\(pair.1)"
                    )
                }
            )
            if let errorReason {
                Text(errorReason)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("\(identifier).error")
            } else if let echo {
                Text(echo)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(AppTheme.textSecondary)
                    .accessibilityLabel("\(title) \(echo.replacingOccurrences(of: "= ", with: ""))")
                    .accessibilityIdentifier("\(identifier).echo")
            }
        }
    }

    private var degField: some View {
        box(TextField("deg", text: $degrees, prompt: Text("deg").foregroundStyle(AppTheme.textSecondary))
                .keyboardType(.numberPad)
                .accessibilityLabel("\(title) degrees")
                .accessibilityIdentifier("\(identifier).deg"),
            unit: "°")
    }

    private var minField: some View {
        box(TextField("min", text: $minutes, prompt: Text("min").foregroundStyle(AppTheme.textSecondary))
                .keyboardType(.decimalPad)
                .accessibilityLabel("\(title) minutes")
                .accessibilityIdentifier("\(identifier).min"),
            unit: "′")
    }

    private func box(_ field: some View, unit: String) -> some View {
        HStack(spacing: 4) {
            field
                .textFieldStyle(.plain)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(12)
                .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(errorReason != nil ? AppTheme.danger : AppTheme.fieldBorder,
                                      lineWidth: errorReason != nil ? 1.5 : 1)
                }
            Text(unit).foregroundStyle(AppTheme.textSecondary)
        }
    }
}
