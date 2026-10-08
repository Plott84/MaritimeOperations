import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DPEntry.createdAt, order: .reverse) private var entries: [DPEntry]
    @Query private var rigMoves: [RigMove]
    @Query private var rovEntries: [ROVEntry]
    @Query private var craneEntries: [CraneEntry]
    @AppStorage("dp.oldHoursText") private var oldHoursText = ""
    @AppStorage(StarredBooks.storageKey) private var starredRaw = StarredBooks.defaultRaw
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Bindable var session: ActiveDPSessionStore
    var onOpenRigMoves: () -> Void
    var onOpenBook: (LogBook) -> Void = { _ in }
    var onOpenLog: () -> Void = {}

    @State private var saveErrorMessage: String?
    @State private var editingEntry: DPEntry?

    private var latestFive: [DPEntry] { Array(entries.prefix(5)) }

    var body: some View {
        ZStack {
            AppCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    timerCard
                    starredBooksCard
                    activityCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Main")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(item: $editingEntry) { entry in
            DPEntryFieldsSheet(mode: .edit(entry))
        }
        .alert("Save failed", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { saveErrorMessage = nil }
        } message: {
            Text(saveErrorMessage ?? "")
        }
    }

    private var timerCard: some View {
        GlassCard {
            VStack(spacing: 16) {
                // Heading stays on one line; at accessibility sizes the Ready pill moves under it.
                timerHeaderLayout {
                    Label {
                        Text("DP TIMER")
                            .font(.caption.weight(.semibold))
                            .tracking(1.1)
                            .foregroundStyle(AppTheme.teal)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    } icon: {
                        Image(systemName: "scope")
                            .foregroundStyle(AppTheme.teal)
                    }
                    if !dynamicTypeSize.isAccessibilitySize {
                        Spacer()
                    }
                    statusPill
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Group {
                    if session.startedAt != nil {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(AppFormatters.timerString(from: session.elapsed(at: context.date)))
                                .font(.system(size: 88, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(timerGradient)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                        }
                    } else {
                        Text("00:00")
                            .font(.system(size: 88, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(timerGradient)
                    }
                }
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)

                Button(action: toggleTimer) {
                    Label(session.isRunning ? "Stop DP" : "Start DP", systemImage: session.isRunning ? "stop.fill" : "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.black.opacity(0.85))
                .background(AppTheme.teal, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: AppTheme.teal.opacity(0.35), radius: 10, y: 4)

                Button(action: onOpenRigMoves) {
                    Label("New Rig Move", systemImage: "ferry.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.textPrimary)
                .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                }

                Text("Start when the vessel goes on DP. Stop saves the session to Log.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var starredBooksCard: some View {
        let stats = LogBookStats(
            entries: entries,
            moves: rigMoves,
            rovEntries: rovEntries,
            craneEntries: craneEntries,
            oldDPHoursText: oldHoursText
        )
        let books = StarredBooks.shownOnMain(starredRaw)
        return VStack(spacing: 8) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label {
                                Text("STARRED")
                                    .font(.caption.weight(.semibold))
                                    .tracking(1.1)
                            } icon: {
                                Image(systemName: "star.fill")
                            }
                            .foregroundStyle(AppTheme.teal)
                            Text("Your books")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .accessibilityAddTraits(.isHeader)
                        }
                        Spacer(minLength: 8)
                        Button(action: onOpenLog) {
                            HStack(spacing: 2) {
                                Text("Edit")
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.bold))
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.teal)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit starred books")
                        .accessibilityHint("Opens the Log tab.")
                        .accessibilityIdentifier("mainEditStarredBooks")
                    }
                    ForEach(books) { book in
                        Button {
                            onOpenBook(book)
                        } label: {
                            starredRow(book, stats: stats)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("mainBook_\(book.rawValue)")
                    }
                }
            }
            if StarredBooks.decode(starredRaw).isEmpty {
                Text("Nothing starred? Main shows DP by default.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func starredRow(_ book: LogBook, stats: LogBookStats) -> some View {
        let count = stats.mainCountText(for: book)
        let spokenCount = stats.mainSpokenValue(for: book)
        return HStack(spacing: 12) {
            // Letters at default sizes; ROV / Crane switch to their fixed-size icon at accessibility sizes.
            LogBookBadge(book: book)
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(count)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 8)
            if let hours = stats.hours(for: book) {
                Text("\(LogBookStats.hoursNumber(hours)) h")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(10)
        .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(book.spokenTitle) book")
        .accessibilityValue(spokenCount)
        .accessibilityHint("Opens the book in Log.")
    }

    private var timerHeaderLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout())
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(session.isRunning ? AppTheme.gold : Color.green)
                .frame(width: 8, height: 8)
            Text(session.isRunning ? "Running" : "Ready")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.35), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var activityCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label {
                            Text("ACTIVITY")
                                .font(.caption.weight(.semibold))
                                .tracking(1.1)
                        } icon: {
                            Image(systemName: "waveform.path.ecg")
                        }
                        .foregroundStyle(AppTheme.teal)
                        Text("Latest Activity")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    Spacer()
                    Text("5 latest")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.3), in: Capsule())
                        .overlay(Capsule().stroke(AppTheme.border, lineWidth: 1))
                }

                Text("Newest 5 records across DP logs and rig moves.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)

                if latestFive.isEmpty {
                    Text("No activity yet. Start DP or add a manual entry.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                } else {
                    VStack(spacing: 0) {
                        ForEach(latestFive, id: \.id) { entry in
                            Button {
                                editingEntry = entry
                            } label: {
                                ActivityRowView(entry: entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }


    private var timerGradient: LinearGradient {
        LinearGradient(
            colors: [Color(white: 0.78), Color.white],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func toggleTimer() {
        if session.isRunning {
            stopAndSave()
        } else {
            session.start()
        }
    }

    private func stopAndSave() {
        guard let startedAt = session.startedAt else { return }
        let endedAt = Date()
        let hours = max(0, endedAt.timeIntervalSince(startedAt) / 3600.0)
        let entry = DPEntry(
            source: .timed,
            date: startedAt,
            startTime: startedAt,
            endTime: endedAt,
            durationHours: hours,
            vessel: "",
            rig: session.rig,
            vesselType: session.vesselType,
            dpClass: session.dpClass
        )
        modelContext.insert(entry)
        do {
            try modelContext.save()
            session.clear()
        } catch {
            modelContext.delete(entry)
            saveErrorMessage = "Couldn’t save this DP session. Timer is still running — try Stop again."
        }
    }
}
