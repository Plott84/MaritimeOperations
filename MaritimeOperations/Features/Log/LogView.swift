import SwiftUI
import SwiftData

// LogBook, StarredBooks and LogBookStats now live in Models/LogBooks.swift (four books).

extension LogBookStats {
    /// Totals from the stores. DP total matches the DP Entries screen: app lines + typed Old DP hours.
    init(
        entries: [DPEntry],
        moves: [RigMove],
        rovEntries: [ROVEntry] = [],
        craneEntries: [CraneEntry] = [],
        oldDPHoursText: String
    ) {
        self.init(
            dpHours: entries.reduce(0) { $0 + $1.durationHours } + Self.oldDPHours(oldDPHoursText),
            dpEntries: entries.count,
            rigMoves: moves.count,
            rovPilotingHours: rovEntries.reduce(0) { $0 + ($1.pilotingHours ?? 0) },
            rovEntries: rovEntries.count,
            craneHours: craneEntries.reduce(0) { $0 + ($1.hoursOperated ?? 0) },
            craneEntries: craneEntries.count
        )
    }
}

/// Log tab: one card per book. Tap a card to open the book; star it to show it on Main.
struct LogView: View {
    @Query private var entries: [DPEntry]
    @Query private var moves: [RigMove]
    @Query private var rovEntries: [ROVEntry]
    @Query private var craneEntries: [CraneEntry]
    @AppStorage("dp.oldHoursText") private var oldHoursText = ""
    @AppStorage(StarredBooks.storageKey) private var starredRaw = StarredBooks.defaultRaw
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var stats: LogBookStats {
        LogBookStats(entries: entries, moves: moves, rovEntries: rovEntries, craneEntries: craneEntries, oldDPHoursText: oldHoursText)
    }

    var body: some View {
        ZStack {
            AppCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Your logbooks")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(LogBook.allCases) { book in
                        bookCard(book)
                    }
                    Label {
                        Text("Starred books show on Main.")
                    } icon: {
                        Image(systemName: "star.fill")
                            .foregroundStyle(AppTheme.teal)
                    }
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func bookCard(_ book: LogBook) -> some View {
        let starred = StarredBooks.decode(starredRaw).contains(book)
        let stacked = dynamicTypeSize.isAccessibilitySize
        return GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                NavigationLink(value: book) {
                    HStack(alignment: .center, spacing: 12) {
                        if !stacked {
                            LogBookIcon(book: book, scale: 1.2)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppTheme.teal)
                                .frame(width: 44, height: 44)
                                .background(AppTheme.teal.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .accessibilityHidden(true)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            if book == .anchorHandling {
                                AHTag(title: "Rig Moves")
                            }
                            Text(book.subtitle)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(book.spokenTitle)
                .accessibilityValue(spokenStats(book))
                .accessibilityHint("Opens the book.")
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("logBook_\(book.rawValue)")

                Rectangle()
                    .fill(AppTheme.border)
                    .frame(height: 1)

                let layout = stacked
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                    : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
                layout {
                    statsLine(book)
                        .accessibilityElement(children: .combine)
                    if !stacked { Spacer(minLength: 8) }
                    starButton(book, starred: starred)
                }
            }
        }
    }

    /// "86.0 h total  12 entries", "4 rig moves", "7.5 h piloting  3 entries", "21.0 h operated  5 entries".
    @ViewBuilder
    private func statsLine(_ book: LogBook) -> some View {
        let count = statText(value: "\(stats.count(for: book))", caption: stats.countCaption(for: book))
        if let hours = stats.hours(for: book) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                statText(value: "\(LogBookStats.hoursNumber(hours)) h", caption: stats.hoursCaption(for: book))
                count
            }
        } else {
            count
        }
    }

    private func statText(value: String, caption: String) -> some View {
        Text("\(Text(value).font(.headline.weight(.bold)).foregroundStyle(AppTheme.textPrimary)) \(Text(caption).font(.footnote).foregroundStyle(AppTheme.textSecondary))")
            .fixedSize(horizontal: false, vertical: true)
    }

    private func spokenStats(_ book: LogBook) -> String {
        stats.logSpokenValue(for: book)
    }

    private func starButton(_ book: LogBook, starred: Bool) -> some View {
        Button {
            starredRaw = StarredBooks.toggled(book, in: starredRaw)
        } label: {
            Label("On Main", systemImage: starred ? "star.fill" : "star")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(minHeight: 44)
                .foregroundStyle(starred ? Color.black.opacity(0.85) : AppTheme.textPrimary.opacity(0.85))
                .background(starred ? AppTheme.teal : Color.black.opacity(0.28), in: Capsule())
                .overlay(Capsule().stroke(starred ? AppTheme.teal : AppTheme.border, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show \(book.spokenTitle) on Main")
        .accessibilityValue(starred ? "On" : "Off")
        .accessibilityAddTraits(starred ? .isSelected : [])
        .accessibilityIdentifier("logBookStar_\(book.rawValue)")
    }
}
