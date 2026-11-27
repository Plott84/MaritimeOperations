import SwiftUI

/// Trailing Save pill on the Winch capacity nav bar.
///
/// The full "Save" label is the first choice. `fixedSize` keeps that label from
/// shrinking into "…" / "S…", so `ViewThatFits` can fall back to a checkmark when
/// the bar is narrow (Large and accessibility sizes). The checkmark still announces
/// "Save". The pill is at least a 44×44 pt tap target.
struct WinchSavePill: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            Text(NamedWinchCopy.save)
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Image(systemName: "checkmark")
                .font(.body.weight(.semibold))
                .accessibilityLabel("Save")
        }
        .foregroundStyle(AppTheme.onTeal)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(minWidth: 44, minHeight: 44)
        .background(AppTheme.teal, in: Capsule())
        .contentShape(Capsule())
    }
}
