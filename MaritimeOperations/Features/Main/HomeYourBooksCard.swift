import SwiftUI

/// Starred books on the regular-width Home column. Compact Home does not show this card.
/// Rows open the book. Edit opens the On Main picker. The secondary CTA stays on
/// `HomeSecondaryCard` under this card, not on the row.
struct HomeYourBooksCard: View {
    let books: HomeBooks
    let stats: LogBookStats
    var onEdit: () -> Void
    var onOpen: (HomeBook) -> Void

    private var listed: [HomeBook] { DuoHomeLayout.onMainBooks(books) }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                header
                VStack(spacing: 0) {
                    ForEach(Array(listed.enumerated()), id: \.element.id) { index, book in
                        if index > 0 {
                            Divider().overlay(AppTheme.cardBorder).padding(.leading, 52)
                        }
                        row(book)
                    }
                }
            }
        }
        .homeAccessibilityContainer("homeYourBooks")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .accessibilityHidden(true)
                    Text("STARRED")
                        .tracking(1.1)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.teal)
                .accessibilityAddTraits(.isHeader)
                Text("Your books")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 8)
            Button(action: onEdit) {
                Text("Edit ›")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.teal)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit")
            .accessibilityHint(HomeBook.changeHint)
            .accessibilityIdentifier("homeYourBooksEdit")
        }
    }

    private func row(_ book: HomeBook) -> some View {
        let logBook = book.logBook
        return Button {
            onOpen(book)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                LogBookIcon(book: logBook, scale: 1)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.teal)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(AppTheme.surface))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(logBook.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(stats.mainCountText(for: logBook))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if let hours = stats.hours(for: logBook) {
                    Text("\(LogBookStats.hoursNumber(hours)) h")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.textPrimary)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(logBook.spokenTitle)
        .accessibilityValue(stats.mainSpokenValue(for: logBook))
        .accessibilityHint("Opens the book.")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("homeYourBook_\(book.rawValue)")
    }
}
