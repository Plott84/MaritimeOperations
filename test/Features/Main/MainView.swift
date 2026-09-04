import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DPEntry.createdAt, order: .reverse) private var entries: [DPEntry]
    @Bindable var session: ActiveDPSessionStore
    var onOpenRigMoves: () -> Void

    private var latestFive: [DPEntry] { Array(entries.prefix(5)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                timerCard
                activityCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Main")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var timerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label {
                    Text("DP TIMER")
                        .font(.caption.weight(.semibold))
                        .tracking(1.0)
                        .foregroundStyle(AppTheme.teal)
                } icon: {
                    Image(systemName: "location.north.circle.fill")
                        .foregroundStyle(AppTheme.teal)
                }
                Spacer()
                statusPill
            }

            Group {
                if let startedAt = session.startedAt {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(AppFormatters.timerString(from: session.elapsed(at: context.date)))
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.textPrimary)
                            .accessibilityLabel("Elapsed \(AppFormatters.timerString(from: session.elapsed(at: context.date)))")
                            .accessibilityHint("Started \(startedAt.formatted())")
                    }
                } else {
                    Text("00:00")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Button(action: toggleTimer) {
                    Label(session.isRunning ? "Stop DP" : "Start DP", systemImage: session.isRunning ? "stop.fill" : "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.black)
                .background(AppTheme.teal, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button(action: onOpenRigMoves) {
                    Label("New Rig Move", systemImage: "ferry.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.textPrimary)
                .background(AppTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                }
            }

            Text("Start when the vessel goes on DP. Stop saves the session to Entries.")
                .font(.footnote)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.teal.opacity(0.35), lineWidth: 1)
        }
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
    }

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ACTIVITY")
                        .font(.caption.weight(.semibold))
                        .tracking(1.0)
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
            }

            Text("Newest 5 records across DP logs and rig moves.")
                .font(.footnote)
                .foregroundStyle(AppTheme.textSecondary)

            if latestFive.isEmpty {
                Text("No activity yet. Start DP or add a manual entry.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(latestFive, id: \.id) { entry in
                        ActivityRowView(entry: entry)
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
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
            vessel: session.vessel,
            rig: session.rig,
            vesselType: session.vesselType,
            dpClass: session.dpClass
        )
        modelContext.insert(entry)
        try? modelContext.save()
        session.clear()
    }
}
