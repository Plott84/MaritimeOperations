import SwiftUI

struct HomeBookStarButton: View {
    let books: HomeBooks
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
        .accessibilityLabel(books.voiceLabel)
        .accessibilityHint(HomeBook.changeHint)
        .accessibilityIdentifier("homeBookStar")
    }
}

struct HomeBookChip: View {
    let books: HomeBooks
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            chipText
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
        .accessibilityLabel(books.voiceLabel)
        .accessibilityHint(HomeBook.changeHint)
        .accessibilityIdentifier("homeBookChip")
    }

    private var chipText: Text {
        var text = Text("On Main · ")
            .foregroundStyle(AppTheme.textPrimary)
            + Text("★ \(books.primary.chipTitle)")
            .foregroundStyle(AppTheme.teal)
        if let secondary = books.secondary {
            text = text
                + Text(" · ")
                .foregroundStyle(AppTheme.textPrimary)
                + Text("★ \(secondary.chipTitle)")
                .foregroundStyle(AppTheme.teal)
        }
        return text
            + Text(" · ")
            .foregroundStyle(AppTheme.textPrimary)
            + Text("Change ›")
            .foregroundStyle(AppTheme.teal)
    }
}

/// On Main picker rows (`homeBookOption_*`) go through `HomeMinimumHitButtonStyle`.
/// A 44 pt floor still measured 42.25 under AX5, so short rows use the secondary CTA floor (48).
enum HomeBookOptionHit {
    static let minimumHeight: CGFloat = HomeCTAButton.Kind.secondary.minimumHeight
}

struct HomeBookPickerSheet: View {
    @Binding var books: HomeBooks
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppCanvas()
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("PRIMARY")
                        ForEach(HomeBook.allCases) { book in
                            primaryOption(book)
                        }
                        sectionTitle("SECONDARY")
                            .padding(.top, 8)
                        noneOption
                        ForEach(HomeBook.allCases) { book in
                            secondaryOption(book)
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
            .navigationTitle(HomeBook.pickerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .systemGlassNavigation()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .accessibilityIdentifier("homeBookClose")
                }
            }
        }
        .presentationDetents([.large, .medium])
        .presentationDragIndicator(.visible)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .tracking(1.1)
            .foregroundStyle(AppTheme.teal)
            .accessibilityAddTraits(.isHeader)
    }

    private func primaryOption(_ book: HomeBook) -> some View {
        let selected = book == books.primary
        return Button {
            books = books.selectingPrimary(book)
            dismiss()
        } label: {
            optionLabel(book, showsCheck: selected)
        }
        .buttonStyle(bookOptionStyle(selected: selected))
        .accessibilityLabel(book.voiceName)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("homeBookOption_\(book.rawValue)")
    }

    /// Same button-body style as Home CTAs. Card fill keeps the picker row look.
    private func bookOptionStyle(selected: Bool) -> HomeMinimumHitButtonStyle {
        HomeMinimumHitButtonStyle(
            minimumHeight: HomeBookOptionHit.minimumHeight,
            fillsWidth: true,
            fill: AppTheme.card,
            foreground: AppTheme.textPrimary,
            stroke: selected ? AppTheme.teal : AppTheme.cardBorder,
            cornerRadius: 14,
            horizontalPadding: 14,
            verticalPadding: 10,
            strokeWidth: selected ? 1.5 : 1
        )
    }

    private var noneOption: some View {
        let selected = books.secondary == nil
        return Button {
            books = books.selectingSecondary(nil)
        } label: {
            HStack(spacing: 12) {
                Text("None")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer(minLength: 8)
                if selected {
                    checkmark
                }
            }
        }
        .buttonStyle(bookOptionStyle(selected: selected))
        .accessibilityLabel("None")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("homeBookSecondaryNone")
    }

    private func secondaryOption(_ book: HomeBook) -> some View {
        let isPrimary = book == books.primary
        let isSecondary = book == books.secondary
        return HStack(spacing: 4) {
            Button {
                books = books.selectingSecondary(book)
            } label: {
                HStack(spacing: 12) {
                    bookIcon(book)
                    Text(book.chipTitle)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    if isPrimary {
                        Text("Primary")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    } else if isSecondary {
                        checkmark
                    }
                }
                .padding(.leading, 14)
                .padding(.trailing, isSecondary ? 4 : 14)
            }
            .buttonStyle(HomeMinimumHitPlainButtonStyle())
            .disabled(isPrimary)
            .accessibilityLabel(book.voiceName)
            .accessibilityAddTraits(isSecondary ? .isSelected : [])
            .accessibilityIdentifier("homeBookSecondaryOption_\(book.rawValue)")
            if isSecondary {
                Button {
                    books = books.makingSecondaryPrimary()
                    dismiss()
                } label: {
                    Text("Make primary")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.teal)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(HomeMinimumHitPlainButtonStyle(fillsWidth: false))
                .fixedSize(horizontal: true, vertical: false)
                .padding(.trailing, 6)
                .accessibilityIdentifier("homeBookMakePrimary")
            }
        }
        .background(rowFill(selected: isSecondary))
        .opacity(isPrimary ? 0.45 : 1)
    }

    private func bookIcon(_ book: HomeBook) -> some View {
        LogBookIcon(book: book.logBook, scale: 0.9)
            .foregroundStyle(AppTheme.teal)
            .frame(width: 28, height: 28)
            .accessibilityHidden(true)
    }

    private func optionLabel(_ book: HomeBook, showsCheck: Bool) -> some View {
        HStack(spacing: 12) {
            bookIcon(book)
            Text(book.chipTitle)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if showsCheck {
                checkmark
            }
        }
    }

    private func rowFill(selected: Bool) -> some View {
        HomeBookOptionRowFill(selected: selected)
    }

    private var checkmark: some View {
        Image(systemName: "checkmark")
            .font(.body.weight(.semibold))
            .foregroundStyle(AppTheme.teal)
            .accessibilityHidden(true)
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
                    .tracking(dynamicTypeSize.isAccessibilitySize ? 0.0 : 1.1)
                    .foregroundStyle(AppTheme.teal)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1.0 : 0.6)
                    .fixedSize(horizontal: false, vertical: true)
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
    enum Kind {
        case primary
        case secondary

        /// Default visual height (50 / 48). Also the button-body floor: a minHeight on the
        /// label alone compresses under AX5 (measured ~42.25) and fails `frame.height > 43`.
        var minimumHeight: CGFloat {
            switch self {
            case .primary: return 50
            case .secondary: return 48
            }
        }
    }

    /// Every Home CTA hit target stays at least this tall, including AX5.
    static let hardMinimumHit: CGFloat = 44

    var title: String
    var systemImage: String
    var kind: Kind
    var identifier: String
    /// Spoken name when it should differ from `title` (empty-state repeat of the hero CTA).
    var spokenTitle: String? = nil
    var action: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            HomeCTALabel(
                title: title,
                systemImage: systemImage,
                stacksIcon: dynamicTypeSize.isAccessibilitySize
            )
            .font(.headline)
        }
        .buttonStyle(HomeMinimumHitButtonStyle(
            minimumHeight: kind.minimumHeight,
            fillsWidth: true,
            fill: kind == .primary ? AppTheme.teal : AppTheme.surfaceElevated,
            foreground: kind == .primary ? AppTheme.onTeal : AppTheme.textPrimary,
            stroke: kind == .secondary ? AppTheme.fieldBorder : nil,
            cornerRadius: 16,
            horizontalPadding: 12,
            verticalPadding: kind == .primary ? 12 : 10
        ))
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(spokenTitle ?? title)
    }
}

/// Icon beside the title at the default size. At accessibility sizes the icon stacks
/// above the title so the words use the full width and wrap instead of clipping.
private struct HomeCTALabel: View {
    var title: String
    var systemImage: String
    var stacksIcon: Bool
    /// nil wraps. The compact card keeps one line until the card itself stacks.
    var lineLimit: Int? = nil

    var body: some View {
        let titleText = Text(title)
            .multilineTextAlignment(.center)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
        if stacksIcon {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                titleText
            }
        } else {
            Label {
                titleText
            } icon: {
                Image(systemName: systemImage)
            }
        }
    }
}

extension View {
    /// Card id that keeps nested CTA identifiers queryable.
    /// A bare `accessibilityIdentifier` on the hero or secondary card flattens the tree
    /// so UI tests can see `homeHero_dp` and miss `homePrimaryCTA`.
    func homeAccessibilityContainer(_ identifier: String) -> some View {
        accessibilityElement(children: .contain)
            .accessibilityIdentifier(identifier)
    }
}

/// Minimum height lives on the button body (the style), not on label text.
/// Label-only `minHeight` is what AX5 compresses below 44.
private struct HomeMinimumHitButtonStyle: ButtonStyle {
    var minimumHeight: CGFloat
    var fillsWidth: Bool
    var fill: Color
    var foreground: Color
    var stroke: Color?
    var cornerRadius: CGFloat
    var horizontalPadding: CGFloat
    var verticalPadding: CGFloat
    var strokeWidth: CGFloat

    init(
        minimumHeight: CGFloat,
        fillsWidth: Bool,
        fill: Color,
        foreground: Color,
        stroke: Color?,
        cornerRadius: CGFloat,
        horizontalPadding: CGFloat,
        verticalPadding: CGFloat,
        strokeWidth: CGFloat = 1
    ) {
        self.minimumHeight = minimumHeight
        self.fillsWidth = fillsWidth
        self.fill = fill
        self.foreground = foreground
        self.stroke = stroke
        self.cornerRadius = cornerRadius
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.strokeWidth = strokeWidth
    }

    func makeBody(configuration: Configuration) -> some View {
        // A fixed-height strut sets the ideal size. `minHeight` alone stays under the
        // text line at AX5 (a 44 pt floor measured 42.25 on homeBookOption_crane).
        ZStack {
            Color.clear
                .frame(width: 1, height: minimumHeight)
                .accessibilityHidden(true)
            configuration.label
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
        }
        .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: minimumHeight)
        .foregroundStyle(foreground)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(fill)
        }
        .overlay {
            if let stroke {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: strokeWidth)
            }
        }
        .contentShape(Rectangle())
    }
}

/// Hit floor for picker rows that already draw their own chrome (secondary option, Make primary).
/// Label-only `minHeight` compresses under AX5, the same way the Home CTAs did.
private struct HomeMinimumHitPlainButtonStyle: ButtonStyle {
    var minimumHeight: CGFloat = HomeBookOptionHit.minimumHeight
    var fillsWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Color.clear
                .frame(width: 1, height: minimumHeight)
                .accessibilityHidden(true)
            configuration.label
                .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: .leading)
        }
        .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: minimumHeight, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct HomeBookOptionRowFill: View {
    var selected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(AppTheme.card)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? AppTheme.teal : AppTheme.cardBorder, lineWidth: selected ? 1.5 : 1)
            }
    }
}

/// Compact card under the hero. One status line and the book's start action. Not a second hero.
struct HomeSecondaryCard: View {
    /// Compact card CTA. Default visual and hard floor are both 44 pt.
    static let minimumHitHeight: CGFloat = HomeCTAButton.hardMinimumHit

    let book: HomeBook
    var status: String
    var cta: String
    var systemImage: String
    var action: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        GlassCard(padding: 14) {
            layout {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        eyebrowIcon
                        Text(book.hero.eyebrow)
                            .font(.caption.weight(.semibold))
                            .tracking(stacked ? 0 : 1.1)
                            .foregroundStyle(AppTheme.teal)
                            .lineLimit(stacked ? nil : 1)
                            .minimumScaleFactor(stacked ? 1 : 0.7)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                    }
                    Text(status)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(stacked ? nil : 1)
                        .minimumScaleFactor(stacked ? 1 : 0.75)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("homeBookSecondaryStatus")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: action) {
                    HomeCTALabel(
                        title: cta,
                        systemImage: systemImage,
                        stacksIcon: stacked,
                        lineLimit: stacked ? nil : 1
                    )
                    .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(HomeMinimumHitButtonStyle(
                    minimumHeight: Self.minimumHitHeight,
                    fillsWidth: stacked,
                    fill: AppTheme.teal,
                    foreground: AppTheme.onTeal,
                    stroke: nil,
                    cornerRadius: 14,
                    horizontalPadding: 14,
                    verticalPadding: 10
                ))
                .fixedSize(horizontal: !stacked, vertical: false)
                .layoutPriority(1)
                .accessibilityIdentifier("homeBookSecondaryCTA")
                .accessibilityLabel(HomeSecondaryLine.accessibilityLabel(book: book, cta: cta))
                .accessibilityValue(status)
            }
        }
        .homeAccessibilityContainer("homeBookSecondaryCard_\(book.rawValue)")
    }

    @ViewBuilder private var eyebrowIcon: some View {
        if book == .dp {
            Image(systemName: "scope")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.teal)
                .accessibilityHidden(true)
        } else {
            LogBookIcon(book: book.logBook, scale: 0.85)
                .foregroundStyle(AppTheme.teal)
                .accessibilityHidden(true)
        }
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
                if let secondary = copy.secondary {
                    HomeCTAButton(
                        title: secondary,
                        systemImage: book.secondarySymbol,
                        kind: .secondary,
                        identifier: "homeSecondaryCTA",
                        action: onSecondary
                    )
                }
                Text(copy.caption)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .homeAccessibilityContainer("homeHero_\(book.rawValue)")
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
