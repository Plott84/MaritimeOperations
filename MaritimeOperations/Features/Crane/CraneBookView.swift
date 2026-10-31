import SwiftUI
import SwiftData

/// Crane book (Log → Crane). Newest first. Swipe to delete asks first; Cancel keeps the row.
struct CraneBookView: View {
    @Query(sort: \CraneEntry.date, order: .reverse) private var entries: [CraneEntry]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAdd = false
    @State private var editing: CraneEntry?
    @State private var pendingDelete: CraneEntry?

    var body: some View {
        ZStack {
            AppCanvas()
            List {
                if entries.isEmpty {
                    Section {
                        BookEmptyCard(book: .crane) { showingAdd = true }
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                } else {
                    Section {
                        LogBookHeaderCard(
                            book: .crane,
                            heading: "Crane work",
                            count: entries.count,
                            idPrefix: "crane",
                            addLabel: "New crane entry"
                        ) {
                            showingAdd = true
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }

                    Section {
                        ForEach(entries, id: \.id) { entry in
                            Button {
                                editing = entry
                            } label: {
                                LogBookRow(
                                    book: .crane,
                                    title: entry.rowTitle,
                                    date: entry.date,
                                    detail: entry.vesselCraneLine,
                                    hoursText: entry.hoursOperated.map { "\(AppFormatters.hoursString($0)) operated" },
                                    underHours: CraneLiftWeight.rowLine(
                                        weightTonnes: entry.liftWeightTonnes,
                                        wireMetres: entry.wireOutMetres
                                    ),
                                    spokenLabel: spokenLabel(entry)
                                )
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("Delete", role: .destructive) {
                                    pendingDelete = entry
                                }
                                .tint(.red)
                                .accessibilityIdentifier("swipeDeleteCraneEntry")
                            }
                            .accessibilityIdentifier("craneRow-\(entry.id.uuidString)")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .padding(.bottom, 8)
        }
        .navigationTitle("Crane")
        .navigationBarTitleDisplayMode(.inline)
        .systemGlassNavigation()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New crane entry")
                .accessibilityIdentifier("navAddCraneEntry")
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddCraneEntryView()
        }
        .sheet(item: $editing) { entry in
            AddCraneEntryView(existing: entry)
        }
        .logDeleteConfirmation(pending: $pendingDelete, idSuffix: "CraneEntry") { entry in
            modelContext.delete(entry)
            try? modelContext.save()
        }
    }

    private func spokenLabel(_ entry: CraneEntry) -> String {
        let lifts = CraneLiftType.allCases.filter { entry.liftTypes.contains($0) }.map(\.label)
        var parts = [lifts.isEmpty ? "Crane entry" : lifts.joined(separator: ", ") + (lifts.count == 1 ? " lift" : " lifts")]
        if let vessel = entry.vessel, !vessel.isEmpty { parts.append(vessel) }
        if let crane = entry.craneName, !crane.isEmpty { parts.append(crane) }
        parts.append(entry.date.formatted(date: .long, time: .omitted))
        if let hours = entry.hoursOperated {
            parts.append("\(LogSpoken.hours(hours)) operated")
        }
        if let summary = CraneLiftWeight.spokenSummary(
            weightTonnes: entry.liftWeightTonnes,
            wireMetres: entry.wireOutMetres
        ) {
            parts.append(summary)
        }
        return parts.joined(separator: ", ")
    }
}
