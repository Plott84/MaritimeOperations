import SwiftUI

struct ActivityRowView: View {
    let entry: DPEntry

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(spacing: 0) {
                Circle()
                    .fill(AppTheme.teal.opacity(0.9))
                    .frame(width: 7, height: 7)
                Rectangle()
                    .fill(AppTheme.teal.opacity(0.28))
                    .frame(width: 1)
            }
            .frame(width: 10)

            Text("DP")
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 32, height: 32)
                .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text("DP session")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer(minLength: 8)
                    Text(AppFormatters.activityDate.string(from: entry.date))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.trailing)
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

    private var meta: String {
        [entry.vesselType, entry.dpClass, entry.vessel]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}
