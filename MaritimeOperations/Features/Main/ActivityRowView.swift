import SwiftUI

struct ActivityRowView: View {
    let entry: DPEntry
    var showsRail: Bool = true

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if showsRail {
                VStack(spacing: 0) {
                    Circle()
                        .fill(AppTheme.teal.opacity(0.85))
                        .frame(width: 7, height: 7)
                    Rectangle()
                        .fill(AppTheme.teal.opacity(0.35))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
                .frame(width: 10)
            }

            HStack(alignment: .top, spacing: 10) {
                Text("DP")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 28, height: 28)
                    .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
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
                    Text(lineOne)
                        .font(.caption)
                        .foregroundStyle(AppTheme.teal)
                        .fixedSize(horizontal: false, vertical: true)
                    if !lineTwo.isEmpty {
                        Text(lineTwo)
                            .font(.caption)
                            .foregroundStyle(AppTheme.teal.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .trailing, spacing: 2) {
                    Label(AppFormatters.hoursString(entry.durationHours), systemImage: "clock")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(10)
            .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .accessibilityElement(children: .combine)
    }

    private var lineOne: String {
        [entry.vesselType, entry.dpClass]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var lineTwo: String {
        entry.vessel.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
