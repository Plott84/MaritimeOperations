import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DPEntry.createdAt, order: .reverse) private var entries: [DPEntry]
    @Query private var rigMoves: [RigMove]
    @Query private var rovEntries: [ROVEntry]
    @Query private var craneEntries: [CraneEntry]
    @AppStorage(HomeBook.storageKey) private var homeBookRaw = HomeBook.defaultRaw
    @AppStorage(HomeBooks.secondaryStorageKey) private var homeBookSecondaryRaw = ""
    @AppStorage(DPDaysSettings.targetTextKey) private var dayTargetText = DPDaysSettings.defaultTargetText
    @AppStorage(DPDaysSettings.certificateKey) private var certificateISO = ""
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Bindable var session: ActiveDPSessionStore
    var onOpenRigMoves: () -> Void
    var onOpenBook: (LogBook) -> Void = { _ in }
    var onNewCraneEntry: () -> Void = {}
    var onNewROVEntry: () -> Void = {}

    @State private var saveErrorMessage: String?
    @State private var editingEntry: DPEntry?
    @State private var showDPDaysSettings = false
    @State private var showHomeBookPicker = false
    /// True after the user edits the new-watch chips. The draft is a copy; the last line is never written.
    @State private var didEditPrefill = false
    @State private var vesselDraft = ""
    @State private var classDraft: Int?

    private var books: HomeBooks {
        HomeBooks.resolve(primaryRaw: homeBookRaw, secondaryRaw: homeBookSecondaryRaw)
    }

    private var homeBook: HomeBook { books.primary }

    private var booksBinding: Binding<HomeBooks> {
        Binding(get: { books }, set: { store($0) })
    }

    /// Secondary is written first so a swap does not briefly store the same book twice.
    private func store(_ next: HomeBooks) {
        let normalized = HomeBooks(primary: next.primary, secondary: next.secondary)
        homeBookSecondaryRaw = normalized.storedSecondaryRaw
        homeBookRaw = normalized.primary.rawValue
    }

    var body: some View {
        ZStack {
            AppCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HomeBookChip(books: books) { showHomeBookPicker = true }
                    switch homeBook {
                    case .dp:
                        timerCard
                        if !session.isRunning {
                            startDPPrefillCard
                        }
                        dpDaysCard
                    case .crane:
                        craneHero
                    case .ah:
                        anchorHero
                    case .rov:
                        rovHero
                    }
                    // Prefill and DP days stay with the DP hero. The secondary card sits under that block.
                    if books.secondary != nil {
                        secondaryCard
                    }
                    HomeActivityCard(
                        book: homeBook,
                        items: activityItems,
                        primaryTitle: primaryTitle,
                        primarySymbol: primarySymbol,
                        onOpen: openActivity,
                        onEmptyPrimary: performPrimary
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollEdgeEffectStyle(.hard, for: .top)
        }
        .navigationTitle("Main")
        .navigationBarTitleDisplayMode(.inline)
        .systemGlassNavigation()
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showDPDaysSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
                .accessibilityIdentifier("mainSettings")
                HomeBookStarButton(books: books) { showHomeBookPicker = true }
            }
        }
        .navigationDestination(isPresented: $showDPDaysSettings) {
            DPDaysSettingsView()
        }
        .sheet(isPresented: $showHomeBookPicker) {
            HomeBookPickerSheet(books: booksBinding)
        }
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

    private var activityItems: [HomeActivityItem] {
        HomeActivity.latest(
            book: homeBook,
            dpEntries: entries,
            rigMoves: rigMoves,
            rovEntries: rovEntries,
            craneEntries: craneEntries
        )
    }

    private var timerCard: some View {
        GlassCard {
            VStack(spacing: 16) {
                HomeEyebrowHeader(
                    title: HomeBook.dp.hero.eyebrow,
                    book: .dp,
                    status: session.isRunning ? "Running" : "Ready",
                    running: session.isRunning
                )
                Group {
                    if session.startedAt != nil {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(AppFormatters.timerString(from: session.elapsed(at: context.date)))
                                .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 64 : 88, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(AppTheme.textPrimary)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                        }
                    } else {
                        Text("00:00")
                            .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 64 : 88, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.textPrimary)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)

                HomeCTAButton(
                    title: session.isRunning ? "Stop DP" : HomeBook.dp.hero.primary,
                    systemImage: session.isRunning ? "stop.fill" : "play.fill",
                    kind: .primary,
                    identifier: "homePrimaryCTA",
                    action: toggleTimer
                )
                Text(HomeBook.dp.hero.caption)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityIdentifier("homeHero_dp")
    }

    private var craneHero: some View {
        let lift = CraneHomeLastLift.latest(in: craneEntries)
        return HomeQuickStartCard(
            book: .crane,
            summaryLabel: lift == nil ? nil : "LAST LIFT",
            summaryValue: lift?.value,
            summarySub: lift?.sub,
            onPrimary: onNewCraneEntry,
            onSecondary: { onOpenBook(.crane) }
        )
    }

    private var anchorHero: some View {
        let summary = HomeActivity.newestMove(rigMoves).map { HomeEntrySummary.anchorHandling($0) }
        return HomeQuickStartCard(
            book: .ah,
            summaryLabel: summary == nil ? nil : "LAST ENTRY",
            summaryTitle: summary?.title,
            summarySub: summary?.sub,
            onPrimary: onOpenRigMoves,
            onSecondary: { onOpenBook(.anchorHandling) }
        )
    }

    private var rovHero: some View {
        let summary = HomeActivity.newestROV(rovEntries).map { HomeEntrySummary.rov($0) }
        return HomeQuickStartCard(
            book: .rov,
            summaryLabel: summary == nil ? nil : "LAST ENTRY",
            summaryTitle: summary?.title,
            summarySub: summary?.sub,
            onPrimary: onNewROVEntry,
            onSecondary: { onOpenBook(.rov) }
        )
    }

    @ViewBuilder private var secondaryCard: some View {
        if let secondary = books.secondary {
            if secondary == .dp {
                dpSecondaryCard
            } else {
                HomeSecondaryCard(
                    book: secondary,
                    status: secondaryStatus(secondary, dpClock: "00:00", dpRunning: false),
                    cta: HomeSecondaryLine.cta(book: secondary, dpRunning: false),
                    systemImage: secondary.primarySymbol,
                    action: { perform(secondary) }
                )
            }
        }
    }

    private var dpSecondaryCard: some View {
        Group {
            if session.startedAt != nil {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let clock = AppFormatters.timerString(from: session.elapsed(at: context.date))
                    HomeSecondaryCard(
                        book: .dp,
                        status: HomeSecondaryLine.status(book: .dp, dpClock: clock, dpRunning: true),
                        cta: HomeSecondaryLine.cta(book: .dp, dpRunning: true),
                        systemImage: "stop.fill",
                        action: { perform(.dp) }
                    )
                }
            } else {
                HomeSecondaryCard(
                    book: .dp,
                    status: HomeSecondaryLine.status(book: .dp, dpClock: "00:00", dpRunning: false),
                    cta: HomeSecondaryLine.cta(book: .dp, dpRunning: false),
                    systemImage: HomeBook.dp.primarySymbol,
                    action: { perform(.dp) }
                )
            }
        }
    }

    private func secondaryStatus(_ book: HomeBook, dpClock: String, dpRunning: Bool) -> String {
        HomeSecondaryLine.status(
            book: book,
            dpClock: dpClock,
            dpRunning: dpRunning,
            craneLift: book == .crane ? CraneHomeLastLift.latest(in: craneEntries) : nil,
            anchor: book == .ah ? HomeActivity.newestMove(rigMoves).map { HomeEntrySummary.anchorHandling($0) } : nil,
            rov: book == .rov ? HomeActivity.newestROV(rovEntries).map { HomeEntrySummary.rov($0) } : nil
        )
    }

    private func perform(_ book: HomeBook) {
        switch book {
        case .dp: toggleTimer()
        case .ah: onOpenRigMoves()
        case .crane: onNewCraneEntry()
        case .rov: onNewROVEntry()
        }
    }

    private var prefill: DPStartPrefill.Draft {
        DPStartPrefill.make(from: entries)
    }

    private var shownVessel: String {
        didEditPrefill ? vesselDraft : prefill.vessel
    }

    private var shownClass: Int? {
        didEditPrefill ? classDraft : prefill.dpClassLevel
    }

    private var dpDaysResult: DPDaysCount.Result {
        DPDaysCount.count(
            intervals: entries.map(\.dpDaysInterval),
            asOf: .now,
            timeZone: .current,
            target: DPDaysSettings.parsedTarget(dayTargetText),
            certificateIssued: DPDaysSettings.parsedCertificate(certificateISO)
        )
    }

    private var dpDaysCard: some View {
        DPDaysCard(result: dpDaysResult, timeZone: .current) {
            showDPDaysSettings = true
        }
    }

    private var startDPPrefillCard: some View {
        StartDPPrefillCard(
            vessel: shownVessel,
            dpClassLevel: shownClass,
            hasPreviousEntry: prefill.hasPreviousEntry,
            prefilledVessel: prefill.vessel,
            prefilledClass: prefill.dpClassLevel,
            suggestions: ShipNameSuggestions.names(from: entries),
            onVessel: setDraftVessel,
            onClass: setDraftClass
        )
    }

    private func setDraftVessel(_ vessel: String) {
        snapshotDraftIfNeeded()
        vesselDraft = DPStartPrefill.cleanedVessel(vessel)
    }

    private func setDraftClass(_ level: Int?) {
        snapshotDraftIfNeeded()
        classDraft = level
    }

    private func snapshotDraftIfNeeded() {
        guard !didEditPrefill else { return }
        vesselDraft = prefill.vessel
        classDraft = prefill.dpClassLevel
        didEditPrefill = true
    }

    private var primaryTitle: String {
        if homeBook == .dp, session.isRunning { return "Stop DP" }
        return homeBook.hero.primary
    }

    private var primarySymbol: String {
        if homeBook == .dp, session.isRunning { return "stop.fill" }
        return homeBook.primarySymbol
    }

    private func performPrimary() {
        perform(homeBook)
    }

    private func openActivity(_ item: HomeActivityItem) {
        switch item.book {
        case .dp:
            if let entry = entries.first(where: { $0.id.uuidString == item.id }) {
                editingEntry = entry
            }
        case .anchorHandling, .rov, .crane:
            onOpenBook(item.book)
        }
    }

    private func toggleTimer() {
        if session.isRunning {
            stopAndSave()
        } else {
            // Chips are the new watch only. Times and hours come from the timer.
            session.vessel = shownVessel
            session.dpClassLevel = shownClass
            session.dpClass = shownClass.map { "Class \($0)" } ?? ""
            session.rig = ""
            session.vesselType = ""
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
            vessel: session.vessel,
            rig: session.rig,
            vesselType: session.vesselType,
            dpClass: session.dpClass,
            dpClassLevel: session.dpClassLevel
        )
        modelContext.insert(entry)
        do {
            try modelContext.save()
            session.clear()
            didEditPrefill = false
        } catch {
            modelContext.delete(entry)
            saveErrorMessage = "Couldn’t save this DP session. Timer is still running — try Stop again."
        }
    }
}
