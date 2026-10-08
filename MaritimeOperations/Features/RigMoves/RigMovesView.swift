import SwiftUI
import SwiftData

/// Anchor handling book (Log → Anchor handling). Rows are the existing RigMove records, newest first.
struct RigMovesView: View {
    @Query(sort: \RigMove.date, order: .reverse) private var moves: [RigMove]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var showingAdd: Bool
    @State private var editingMove: RigMove?
    @State private var pendingDelete: RigMove?

    var body: some View {
        ZStack {
            AppCanvas()
            List {
                Section {
                    headerCard
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                if moves.isEmpty {
                    Section {
                        Text("No rig moves yet.")
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
                        ForEach(moves, id: \.id) { move in
                            Button {
                                editingMove = move
                            } label: {
                                row(move)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("Delete", role: .destructive) {
                                    pendingDelete = move
                                }
                                .tint(.red)
                                .accessibilityIdentifier("swipeDeleteRigMove")
                            }
                            .accessibilityIdentifier("rigMoveRow-\(move.id.uuidString)")
                        }
                    }
                }

                Section {
                    exportRow
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .padding(.bottom, 8)
        }
        .navigationTitle("Anchor handling")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                TealCircleButton(systemImage: "plus") {
                    showingAdd = true
                }
                .accessibilityLabel("New anchor handling entry")
                .accessibilityIdentifier("navAddRigMove")
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddRigMoveView()
        }
        .sheet(item: $editingMove) { move in
            AddRigMoveView(existing: move)
        }
        .alert(
            DeleteEntryPrompt.confirm,
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                guard let move = pendingDelete else { return }
                modelContext.delete(move)
                try? modelContext.save()
                pendingDelete = nil
            }
            .accessibilityIdentifier("confirmDeleteRigMove")
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
            .accessibilityIdentifier("cancelDeleteRigMove")
        }
    }

    private var headerCard: some View {
        VStack(spacing: 12) {
            AHTag(title: "Rig Moves")
                .accessibilityLabel("Filter: Rig Moves")
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label {
                        Text("ANCHOR HANDLING")
                            .font(.caption.weight(.semibold))
                            .tracking(1.1)
                    } icon: {
                        AnchorIcon(scale: 0.75)
                    }
                    .foregroundStyle(AppTheme.teal)
                    .accessibilityAddTraits(.isHeader)

                    HStack(alignment: .firstTextBaseline) {
                        Text("Rig moves")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Spacer(minLength: 8)
                        Text(moves.count == 1 ? "1 row" : "\(moves.count) rows")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.3), in: Capsule())
                            .overlay(Capsule().stroke(AppTheme.border, lineWidth: 1))
                            .accessibilityIdentifier("ahRowCount")
                    }
                    Text("Newest first.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textSecondary)

                    Button {
                        showingAdd = true
                    } label: {
                        Label("New entry", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.textPrimary)
                    .background(Color.black.opacity(0.28), in: Capsule())
                    .overlay(Capsule().stroke(AppTheme.teal.opacity(0.45), lineWidth: 1))
                    .accessibilityLabel("New anchor handling entry")
                    .accessibilityIdentifier("addRigMovePill")
                }
            }
        }
    }

    private func row(_ move: RigMove) -> some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        return HStack(alignment: .center, spacing: 12) {
            if !stacked {
                Text("AH")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 4) {
                let layout = stacked
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
                layout {
                    Text(move.ahJobType.label)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !stacked { Spacer(minLength: 8) }
                    Text(move.date.formatted(.dateTime.day().month(.abbreviated).year()))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                layout {
                    Text(move.rigVesselLine.isEmpty ? "Not set" : move.rigVesselLine)
                        .font(.subheadline)
                        .foregroundStyle(move.rigVesselLine.isEmpty ? AppTheme.textSecondary : AppTheme.teal)
                        .fixedSize(horizontal: false, vertical: true)
                    if !stacked { Spacer(minLength: 8) }
                    if let hours = move.workedHours {
                        Label(AppFormatters.hoursString(hours), systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
                .accessibilityHidden(true)
        }
        .padding(12)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.teal.opacity(0.28), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowSpokenLabel(move))
        .accessibilityHint("Opens the entry.")
    }

    private func rowSpokenLabel(_ move: RigMove) -> String {
        var parts = [move.ahJobType.spokenLabel]
        if !move.rigName.isEmpty { parts.append(move.rigName) }
        if !move.vessel.isEmpty { parts.append(move.vessel) }
        parts.append(move.date.formatted(date: .long, time: .omitted))
        if let hours = move.workedHours {
            parts.append(AppFormatters.hoursString(hours).replacingOccurrences(of: " h", with: " hours"))
        }
        return parts.joined(separator: ", ")
    }

    private var exportRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "doc.text")
                    .accessibilityHidden(true)
                Text("Export Anchor handling")
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(AppTheme.textSecondary)
            .padding(14)
            .frame(minHeight: 44)
            .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Export Anchor handling")
            .accessibilityValue("Not available yet")
            .accessibilityIdentifier("ahExportBook")
            Text("Exports this book only. Export comes in a later build.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
