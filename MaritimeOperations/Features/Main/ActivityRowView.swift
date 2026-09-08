import SwiftUI

struct ActivityRowView: View {
    let entry: DPEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("DP")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("DP session")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer(minLength: 8)
                    Text(AppFormatters.activityDate.string(from: entry.date))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // BUG-002: stack metadata on two lines; duration on its own row
                if !lineOne.isEmpty {
                    Text(lineOne)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.teal)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !lineTwo.isEmpty {
                    Text(lineTwo)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.teal)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Label(AppFormatters.hoursString(entry.durationHours), systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.top, 4)
        }
        .padding(12)
        .background(AppTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var lineOne: String {
        [entry.vesselType, entry.dpClass]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
    }

    private var lineTwo: String {
        entry.vessel.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
