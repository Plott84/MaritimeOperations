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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(isError ? AppTheme.danger : AppTheme.textSecondary)
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
                    .stroke(isError ? AppTheme.danger.opacity(0.85) : AppTheme.border, lineWidth: isError ? 1.5 : 1)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(caption)
                .font(.caption.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(AppTheme.teal)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(value)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
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
            .foregroundStyle(Color.white)
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
            .foregroundStyle(Color(red: 0.37, green: 0.94, blue: 0.77))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                Color(red: 0.09, green: 0.19, blue: 0.17).opacity(0.95),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(Color(red: 0.18, green: 0.43, blue: 0.37).opacity(0.9), lineWidth: 1)
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

