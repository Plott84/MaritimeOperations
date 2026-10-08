import SwiftUI
import SwiftData

struct EntriesView: View {
    @Query(sort: \DPEntry.date, order: .reverse) private var entries: [DPEntry]
    @Environment(\.modelContext) private var modelContext
    var session: ActiveDPSessionStore
    @AppStorage("dp.oldHoursText") private var oldHoursText = ""
    @FocusState private var oldHoursFocused: Bool
    @State private var showingAdd = false
    @State private var editingEntry: DPEntry?
    @State private var pendingDelete: DPEntry?

    private var appHours: Double {
        entries.reduce(0) { $0 + $1.durationHours }
    }

    /// Empty Old DP hours counts as zero.
    private var oldHours: Double {
        let trimmed = oldHoursText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        return Double(trimmed.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var totalHours: Double { appHours + oldHours }

    var body: some View {
        ZStack {
            AppCanvas()
            List {
                Section {
                    summaryCard
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                if entries.isEmpty {
                    Section {
                        Text("No entries yet. Add a DP log line, or stop the timer on Main.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 8)
                            .padding(.top, 8)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                } else {
                    Section {
                        ForEach(entries, id: \.id) { entry in
                            Button {
                                editingEntry = entry
                            } label: {
                                entryRow(entry)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .modifier(DPEntrySwipeDelete(
                                isEnabled: !entry.isRunningTimerEntry(sessionStartedAt: session.startedAt),
                                onDelete: { pendingDelete = entry }
                            ))
                            .accessibilityIdentifier("dpEntryRow-\(entry.id.uuidString)")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .padding(.bottom, 8)
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
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { oldHoursFocused = false }
            }
        }
        .sheet(isPresented: $showingAdd) {
            DPEntryFieldsSheet(mode: .add)
        }
        .sheet(item: $editingEntry) { entry in
            DPEntryFieldsSheet(mode: .edit(entry))
        }
        .alert(
            DeleteEntryPrompt.confirm,
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                guard let entry = pendingDelete else { return }
                modelContext.delete(entry)
                try? modelContext.save()
                pendingDelete = nil
            }
            .accessibilityIdentifier("confirmDeleteEntry")
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
            .accessibilityIdentifier("cancelDeleteEntry")
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

                VStack(spacing: 6) {
                    Text(AppFormatters.hoursString(totalHours))
                        .font(.title.weight(.bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .accessibilityIdentifier("totalDPHours")
                    Text("Total hours")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Old DP hours")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    TextField("Old DP hours", text: $oldHoursText)
                        .focused($oldHoursFocused)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .foregroundStyle(AppTheme.textPrimary)
                        .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppTheme.border, lineWidth: 1)
                        }
                        .accessibilityLabel("Old DP hours")
                        .accessibilityIdentifier("oldDPHours")
                    Text("Hours already in the book, not in the app. Empty counts as zero.")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add", systemImage: "plus")
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
                Text(entry.vessel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Needs details" : entry.vessel)
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
        var parts = [entry.rig, entry.vesselType, entry.dpClassLabel]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if entry.locationFromPhone {
            parts.append("Phone position")
        } else {
            let place = entry.locationName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !place.isEmpty { parts.append(place) }
        }
        return parts.joined(separator: " · ")
    }
}

/// Trailing destructive swipe that only arms confirmation — never deletes immediately.
private struct DPEntrySwipeDelete: ViewModifier {
    let isEnabled: Bool
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("Delete", role: .destructive, action: onDelete)
                        .tint(.red)
                        .accessibilityIdentifier("swipeDeleteDPEntry")
                }
        } else {
            content
        }
    }
}
