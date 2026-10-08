import SwiftUI

struct ActivityRowView: View {
    let entry: DPEntry
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                Circle()
                    .fill(AppTheme.teal.opacity(0.9))
                    .frame(width: 7, height: 7)
                    .padding(.top, 12)
                Rectangle()
                    .fill(AppTheme.teal.opacity(0.28))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 10)

            // Accessibility sizes: fixed-size DP icon instead of letters (row already reads "DP session").
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: "scope")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.teal)
                } else {
                    Text("DP")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
            .frame(width: 32, height: 32)
            .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                // Accessibility sizes: title above the date so "DP session" never breaks mid-word.
                titleDateLayout {
                    Text("DP session")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .layoutPriority(1)
                    if !dynamicTypeSize.isAccessibilitySize {
                        Spacer(minLength: 8)
                    }
                    Text(AppFormatters.activityDate.string(from: entry.date))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
                }
                if !meta.isEmpty {
                    Text(meta)
                        .font(.caption)
                        .foregroundStyle(AppTheme.teal)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                Text(AppFormatters.hoursString(entry.durationHours))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private var titleDateLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
    }

    private var meta: String {
        var parts = [entry.vesselType, entry.dpClassLabel]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let ship = entry.vessel.trimmingCharacters(in: .whitespacesAndNewlines)
        parts.append(ship.isEmpty ? "Needs details" : ship)
        if entry.locationFromPhone {
            parts.append("Phone position")
        }
        return parts.joined(separator: " · ")
    }
}
