import SwiftUI

/// Solid DP days card. Glass stays on the tab bar and toolbar.
struct SpecSolidCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppTheme.card)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(AppTheme.cardBorder, lineWidth: 1)
            }
    }
}

struct DPDaysCard: View {
    let result: DPDaysCount.Result
    let timeZone: TimeZone
    var onOpenSettings: () -> Void

    @ScaledMetric(relativeTo: .caption2) private var eyebrowSize: CGFloat = 11.5
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 44
    @ScaledMetric(relativeTo: .title) private var suffixSize: CGFloat = 30
    @ScaledMetric(relativeTo: .caption) private var captionSize: CGFloat = 12.5
    @ScaledMetric(relativeTo: .footnote) private var hintSize: CGFloat = 13
    @ScaledMetric(relativeTo: .caption2) private var footerSize: CGFloat = 11.5
    @ScaledMetric(relativeTo: .subheadline) private var pillSize: CGFloat = 14

    var body: some View {
        SpecSolidCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("DP DAYS")
                    .font(.system(size: eyebrowSize, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.teal)
                    .accessibilityHidden(true)

                numberBlock
                    .padding(.top, 2)

                Text(DPDaysCount.caption)
                    .font(.system(size: captionSize))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)

                if let fraction = result.progressFraction {
                    progressBar(fraction)
                        .padding(.top, 4)
                        .accessibilityHidden(true)
                }

                Text(DPDaysCount.windowLine(
                    windowStart: result.windowStart,
                    windowEnd: result.windowEnd,
                    timeZone: timeZone
                ))
                .font(.system(size: captionSize))
                .foregroundStyle(AppTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
                .accessibilityIdentifier("dpDaysWindow")

                if result.target == nil {
                    Button(action: onOpenSettings) {
                        Text(DPDaysCount.settingsHint)
                            .font(.system(size: hintSize, weight: .semibold))
                            .foregroundStyle(AppTheme.teal)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens Settings.")
                    .accessibilityIdentifier("dpDaysOpenSettings")
                }

                if !result.classPills.isEmpty {
                    pillBlock
                        .padding(.top, 4)
                }

                Rectangle()
                    .fill(AppTheme.border)
                    .frame(height: 1)
                    .padding(.top, 6)
                    .accessibilityHidden(true)

                Text(DPDaysCount.footer)
                    .font(.system(size: footerSize))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("dpDaysCard")
    }

    private var numberBlock: some View {
        ViewThatFits(in: .horizontal) {
            numberLine(stacked: false)
            numberLine(stacked: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(DPDaysCount.voiceOverSummary(days: result.days, target: result.target))
        .accessibilityIdentifier("dpDaysSummary")
    }

    private func numberLine(stacked: Bool) -> some View {
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 0))
        return layout {
            Text("\(result.days)")
                .font(.system(size: numberSize, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
            Text(suffix(stacked: stacked))
                .font(.system(size: suffixSize, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
        }
        .fixedSize(horizontal: !stacked, vertical: true)
    }

    private func suffix(stacked: Bool) -> String {
        if let target = result.target {
            return stacked ? "/ \(target)" : " / \(target)"
        }
        return stacked ? "days" : " days"
    }

    private func progressBar(_ fraction: Double) -> some View {
        Capsule()
            .fill(AppTheme.pickerFill)
            .frame(height: 6)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(AppTheme.teal)
                        .frame(width: max(CGFloat(0), proxy.size.width * CGFloat(fraction)))
                }
            }
            .clipShape(Capsule())
    }

    private var pillBlock: some View {
        ViewThatFits(in: .horizontal) {
            pillRow(stacked: false)
            pillRow(stacked: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            result.classPills
                .map { "Class \($0.level), \($0.days) days" }
                .joined(separator: ". ")
        )
    }

    private func pillRow(stacked: Bool) -> some View {
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
        return layout {
            ForEach(result.classPills, id: \.level) { pill in
                classPill(level: pill.level, days: pill.days, expands: stacked)
            }
        }
        .fixedSize(horizontal: !stacked, vertical: true)
        .frame(maxWidth: stacked ? .infinity : nil, alignment: .leading)
    }

    private func classPill(level: Int, days: Int, expands: Bool) -> some View {
        HStack(spacing: 0) {
            Text("Class \(level) · ")
                .foregroundStyle(AppTheme.textSecondary)
            Text("\(days)")
                .foregroundStyle(AppTheme.textPrimary)
            Text(" days")
                .foregroundStyle(AppTheme.textSecondary)
        }
        .font(.system(size: pillSize, weight: .semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: expands ? .infinity : nil, alignment: .leading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .fixedSize(horizontal: false, vertical: true)
    }
}
