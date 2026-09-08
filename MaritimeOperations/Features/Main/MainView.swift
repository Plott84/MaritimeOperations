import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DPEntry.createdAt, order: .reverse) private var entries: [DPEntry]
    @Bindable var session: ActiveDPSessionStore
    var onOpenRigMoves: () -> Void

    @State private var saveErrorMessage: String?

    private var latestFive: [DPEntry] { Array(entries.prefix(5)) }

    var body: some View {
        ZStack {
            AppCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    timerCard
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
                HStack {
                    Label {
                        Text("DP TIMER")
                            .font(.caption.weight(.semibold))
                            .tracking(1.1)
                            .foregroundStyle(AppTheme.teal)
                    } icon: {
                        Image(systemName: "scope")
                            .foregroundStyle(AppTheme.teal)
                    }
                    Spacer()
                    statusPill
                }

                Group {
                    if session.startedAt != nil {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(AppFormatters.timerString(from: session.elapsed(at: context.date)))
                                .font(.system(size: 72, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(AppTheme.textPrimary)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                        }
                    } else {
                        Text("00:00")
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
                .frame(maxWidth: .infinity)

                Button(action: toggleTimer) {
                    Label(session.isRunning ? "Stop DP" : "Start DP", systemImage: session.isRunning ? "stop.fill" : "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
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

                Text("Start when the vessel goes on DP. Stop saves the session to Entries.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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
                    VStack(spacing: 8) {
                        ForEach(latestFive, id: \.id) { entry in
                            ActivityRowView(entry: entry)
                        }
                    }
                }
            }
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
        do {
            try modelContext.save()
            session.clear()
        } catch {
            modelContext.delete(entry)
            saveErrorMessage = "Couldn’t save this DP session. Timer is still running — try Stop again."
        }
    }
}
