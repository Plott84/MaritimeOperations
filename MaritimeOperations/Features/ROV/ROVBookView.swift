import SwiftUI
import SwiftData

/// ROV book (Log → ROV). Newest first. Swipe to delete asks first; Cancel keeps the row.
struct ROVBookView: View {
    @Query(sort: \ROVEntry.date, order: .reverse) private var entries: [ROVEntry]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAdd = false
    @State private var editing: ROVEntry?
    @State private var pendingDelete: ROVEntry?

    var body: some View {
        ZStack {
            AppCanvas()
            List {
                Section {
                    LogBookHeaderCard(
                        book: .rov,
                        heading: "ROV dives",
                        count: entries.count,
                        idPrefix: "rov",
                        addLabel: "New ROV entry"
                    ) {
                        showingAdd = true
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                if entries.isEmpty {
                    Section {
                        Text("No ROV entries yet.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                } else {
                    Section {
                        ForEach(entries, id: \.id) { entry in
                            Button {
                                editing = entry
                            } label: {
                                LogBookRow(
                                    book: .rov,
                                    title: entry.rowTitle,
                                    date: entry.date,
                                    detail: entry.vesselSystemLine,
                                    hoursText: entry.pilotingHours.map { "\(AppFormatters.hoursString($0)) piloting" },
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
                                .accessibilityIdentifier("swipeDeleteROVEntry")
                            }
                            .accessibilityIdentifier("rovRow-\(entry.id.uuidString)")
                        }
                    }
                }

                Section {
                    LogBookExportRow(book: .rov, idPrefix: "rov")
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .padding(.bottom, 8)
        }
        .navigationTitle("ROV")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                TealCircleButton(systemImage: "plus") {
                    showingAdd = true
                }
                .accessibilityLabel("New ROV entry")
                .accessibilityIdentifier("navAddROVEntry")
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddROVEntryView()
        }
        .sheet(item: $editing) { entry in
            AddROVEntryView(existing: entry)
        }
        .logDeleteConfirmation(pending: $pendingDelete, idSuffix: "ROVEntry") { entry in
            modelContext.delete(entry)
            try? modelContext.save()
        }
    }

    private func spokenLabel(_ entry: ROVEntry) -> String {
        var parts = [entry.jobType?.spokenLabel ?? "R O V entry"]
        if let vessel = entry.vessel, !vessel.isEmpty { parts.append(vessel) }
        if let system = entry.rovSystem, !system.isEmpty { parts.append(system) }
        parts.append(entry.date.formatted(date: .long, time: .omitted))
        if let hours = entry.pilotingHours {
            parts.append("\(LogSpoken.hours(hours)) piloting")
        }
        if let dives = entry.dives {
            parts.append(dives == 1 ? "1 dive" : "\(dives) dives")
        }
        return parts.joined(separator: ", ")
    }
}
