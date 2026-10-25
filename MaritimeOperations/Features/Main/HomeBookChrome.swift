import SwiftUI

struct HomeBookStarButton: View {
    let book: HomeBook
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "star.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.onTeal)
                .frame(minWidth: 44, minHeight: 44)
                .background(AppTheme.teal, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(book.starAccessibilityLabel)
        .accessibilityHint(HomeBook.changeHint)
        .accessibilityIdentifier("homeBookStar")
    }
}

struct HomeBookChip: View {
    let book: HomeBook
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            (Text("Home book · ★ \(book.chipTitle) · ")
                .foregroundStyle(AppTheme.textPrimary)
                + Text("Change ›")
                .foregroundStyle(AppTheme.teal))
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(minHeight: 44, alignment: .leading)
                .background(AppTheme.surfaceElevated, in: Capsule())
                .overlay(Capsule().strokeBorder(AppTheme.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(book.starAccessibilityLabel)
        .accessibilityHint(HomeBook.changeHint)
        .accessibilityIdentifier("homeBookChip")
    }
}

struct HomeBookPickerSheet: View {
    @Binding var selection: HomeBook
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppCanvas()
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(HomeBook.allCases) { book in
                            option(book)
                        }
                        Text(HomeBook.pickerFootnote)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 6)
                            .accessibilityIdentifier("homeBookFootnote")
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Home book")
            .navigationBarTitleDisplayMode(.inline)
            .systemGlassNavigation()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .accessibilityIdentifier("homeBookClose")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func option(_ book: HomeBook) -> some View {
        let selected = book == selection
        return Button {
            selection = book
            dismiss()
        } label: {
            HStack(spacing: 12) {
                LogBookIcon(book: book.logBook, scale: 0.9)
                    .foregroundStyle(AppTheme.teal)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
                Text(book.chipTitle)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.teal)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? AppTheme.teal : AppTheme.cardBorder, lineWidth: selected ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(book.voiceName)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("homeBookOption_\(book.rawValue)")
    }
}

struct HomeStatusPill: View {
    var text: String
    var isRunning: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isRunning ? AppTheme.gold : AppTheme.ready)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppTheme.badgeFill, in: Capsule())
        .overlay(Capsule().strokeBorder(AppTheme.fieldBorder, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

struct HomeEyebrowHeader: View {
    let title: String
    let book: LogBook
    var status: String
    var running: Bool = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center))
        layout {
            HStack(spacing: 6) {
                icon
                    .accessibilityHidden(true)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .tracking(1.1)
                    .foregroundStyle(AppTheme.teal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityAddTraits(.isHeader)
            }
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 8)
            }
            HomeStatusPill(text: status, isRunning: running)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var icon: some View {
        if book == .dp {
            Image(systemName: "scope")
                .foregroundStyle(AppTheme.teal)
        } else {
            LogBookIcon(book: book, scale: 0.85)
                .foregroundStyle(AppTheme.teal)
        }
    }
}

struct HomeCTAButton: View {
    enum Kind { case primary, secondary }

    var title: String
    var systemImage: String
    var kind: Kind
    var identifier: String
    /// Spoken name when it should differ from `title` (empty-state repeat of the hero CTA).
    var spokenTitle: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(title)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: systemImage)
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, kind == .primary ? 12 : 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(kind == .primary ? AppTheme.onTeal : AppTheme.textPrimary)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(kind == .primary ? AppTheme.teal : AppTheme.surfaceElevated)
        }
        .overlay {
            if kind == .secondary {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AppTheme.fieldBorder, lineWidth: 1)
            }
        }
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(spokenTitle ?? title)
    }
}

/// Crane, AH, and ROV heroes. DP keeps its timer card. `showsDPTimer` is false for every book passed here.
struct HomeQuickStartCard: View {
    let book: HomeBook
    var summaryLabel: String?
    var summaryValue: String?
    var summaryTitle: String?
    var summarySub: String?
    var onPrimary: () -> Void
    var onSecondary: () -> Void

    var body: some View {
        let copy = book.hero
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HomeEyebrowHeader(title: copy.eyebrow, book: book.logBook, status: "Ready")
                summary
                HomeCTAButton(
                    title: copy.primary,
                    systemImage: book.primarySymbol,
                    kind: .primary,
                    identifier: "homePrimaryCTA",
                    action: onPrimary
                )
                HomeCTAButton(
                    title: copy.secondary,
                    systemImage: book.secondarySymbol,
                    kind: .secondary,
                    identifier: "homeSecondaryCTA",
                    action: onSecondary
                )
                Text(copy.caption)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityIdentifier("homeHero_\(book.rawValue)")
    }

    @ViewBuilder private var summary: some View {
        if summaryLabel != nil || summaryValue != nil || summaryTitle != nil || summarySub != nil {
            VStack(alignment: .leading, spacing: 4) {
                if let summaryLabel {
                    Text(summaryLabel)
                        .font(.caption2.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                if let summaryValue {
                    Text(summaryValue)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("homeLastLiftValue")
                }
                if let summaryTitle {
                    Text(summaryTitle)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let summarySub {
                    Text(summarySub)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct HomeActivityCard: View {
    let book: HomeBook
    let items: [HomeActivityItem]
    var primaryTitle: String
    var primarySymbol: String
    var onOpen: (HomeActivityItem) -> Void
    var onEmptyPrimary: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let copy = book.hero
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                header(copy)
                Text(copy.activityCaption)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if items.isEmpty {
                    Text(copy.emptyTitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("homeActivityEmpty")
                    HomeCTAButton(
                        title: primaryTitle,
                        systemImage: primarySymbol,
                        kind: .primary,
                        identifier: "homeEmptyCTA",
                        spokenTitle: "\(copy.emptyTitle), \(primaryTitle)",
                        action: onEmptyPrimary
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(items) { item in
                            Button {
                                onOpen(item)
                            } label: {
                                ActivityRowView(item: item)
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(item.badgeText), \(item.title)")
                            .accessibilityValue(spokenValue(item))
                            .accessibilityIdentifier("homeActivity_\(item.id)")
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("homeActivity")
    }

    private func header(_ copy: HomeHeroCopy) -> some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        return VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("ACTIVITY")
                    .font(.caption.weight(.semibold))
                    .tracking(1.1)
            } icon: {
                Image(systemName: "waveform.path.ecg")
            }
            .foregroundStyle(AppTheme.teal)
            let layout = stacked
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
            layout {
                Text("Latest Activity")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if !stacked { Spacer(minLength: 8) }
                Text(copy.activityChip)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.3), in: Capsule())
                    .overlay(Capsule().stroke(AppTheme.fieldBorder, lineWidth: 1))
                    .accessibilityIdentifier("homeActivityChip")
            }
        }
    }

    private func spokenValue(_ item: HomeActivityItem) -> String {
        [item.subtitle, item.trailing].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}
