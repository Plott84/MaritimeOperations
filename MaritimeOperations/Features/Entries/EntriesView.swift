import SwiftUI
import SwiftData

struct EntriesView: View {
    @Query(sort: \DPEntry.date, order: .reverse) private var entries: [DPEntry]
    @State private var showingAdd = false

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView {
                    Label("No entries yet", systemImage: "clipboard")
                } description: {
                    Text("Stop a DP timer or add a manual line from your old book.")
                } actions: {
                    Button("Add Manual Entry") {
                        showingAdd = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.teal)
                }
                .foregroundStyle(AppTheme.textSecondary)
            } else {
                List {
                    ForEach(entries, id: \.id) { entry in
                        entryRow(entry)
                            .listRowBackground(AppTheme.surface)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Entries")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add Manual Entry", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddManualEntryView()
        }
    }

    @ViewBuilder
    private func entryRow(_ entry: DPEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.vessel.isEmpty ? "Untitled vessel" : entry.vessel)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text(AppFormatters.hoursString(entry.durationHours))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryBlue)
            }

            // BUG-002: two lines — don’t squeeze metadata into one HStack with duration
            if !lineOne(entry).isEmpty {
                Text(lineOne(entry))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.teal)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !lineTwo(entry).isEmpty {
                Text(lineTwo(entry))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.teal)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Text(entry.source.label)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text(entry.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                if entry.isEligibleUnderCurrentRule {
                    Text("Eligible")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.gold)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func lineOne(_ entry: DPEntry) -> String {
        [entry.vesselType, entry.dpClass]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
    }

    private func lineTwo(_ entry: DPEntry) -> String {
        let rig = entry.rig.trimmingCharacters(in: .whitespacesAndNewlines)
        return rig
    }
}
