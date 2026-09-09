import SwiftUI
import SwiftData

struct EntriesView: View {
    @Query(sort: \DPEntry.date, order: .reverse) private var entries: [DPEntry]
    @State private var showingAdd = false
    @State private var editingEntry: DPEntry?

    private var editableCount: Int { entries.count }

    var body: some View {
        ZStack {
            AppCanvas()
            ScrollView {
                VStack(spacing: 16) {
                    summaryCard
                    if entries.isEmpty {
                        Text("No entries yet. Stop a DP timer or add a line from your old book.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(entries, id: \.id) { entry in
                                entryRow(entry)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("DP Entries")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                TealCircleButton(systemImage: "plus") {
                    showingAdd = true
                }
                .accessibilityLabel("Add entry")
                .accessibilityIdentifier("navAddEntry")
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddManualEntryView()
        }
        .sheet(item: $editingEntry) { entry in
            DPEntryFieldsSheet(mode: .edit(entry))
        }
    }

    private var summaryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label {
                            Text("LOGBOOK")
                                .font(.caption.weight(.semibold))
                                .tracking(1.1)
                        } icon: {
                            Image(systemName: "waveform.path.ecg")
                        }
                        .foregroundStyle(AppTheme.teal)
                        Text("DP Sessions")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    Spacer()
                    Image(systemName: "square.and.arrow.up")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.black.opacity(0.25)))
                        .overlay(Circle().stroke(AppTheme.border, lineWidth: 1))
                        .accessibilityHidden(true)
                }

                Text("Review timed sessions, aggregate DP hours, and manual catch-up entries. Complete vessel, position, class, code, and notes when the job allows.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    counterTile(title: "Total entries", value: entries.count, systemImage: "list.clipboard")
                    counterTile(title: "Editable", value: editableCount, systemImage: "square.and.pencil")
                }

                HStack(spacing: 10) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add Manual Entry", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.textPrimary)
                    .background(Color.black.opacity(0.28), in: Capsule())
                    .overlay(Capsule().stroke(AppTheme.teal.opacity(0.45), lineWidth: 1))
                    .accessibilityIdentifier("addManualEntryPill")

                    Button {} label: {
                        Label("Share DP Entries", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.textSecondary)
                    .background(Color.black.opacity(0.2), in: Capsule())
                    .overlay(Capsule().stroke(AppTheme.border, lineWidth: 1))
                    .disabled(true)
                    .accessibilityLabel("Share DP Entries")
                }
            }
        }
    }

    private func counterTile(title: String, value: Int, systemImage: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(AppTheme.teal)
            Text("\(value)")
                .font(.title.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func entryRow(_ entry: DPEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                Text("DP")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
            }
            .frame(width: 36, height: 36)
            .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.vessel.isEmpty ? "Untitled vessel" : entry.vessel)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(dateLine(entry))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(metaLine(entry))
                    .font(.caption)
                    .foregroundStyle(AppTheme.teal)
                    .fixedSize(horizontal: false, vertical: true)
                Text(entry.source.label)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(AppFormatters.hoursString(entry.durationHours))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.teal)
                Text("Duration")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.teal.opacity(0.28), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func dateLine(_ entry: DPEntry) -> String {
        let day = entry.date.formatted(date: .abbreviated, time: .omitted)
        if let start = entry.startTime, let end = entry.endTime {
            let tf = Date.FormatStyle(date: .omitted, time: .shortened)
            return "\(day) · \(start.formatted(tf)) – \(end.formatted(tf))"
        }
        return day
    }

    private func metaLine(_ entry: DPEntry) -> String {
        [entry.rig, entry.vesselType, entry.dpClass]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}
