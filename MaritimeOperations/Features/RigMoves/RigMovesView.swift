import SwiftUI
import SwiftData

struct RigMovesView: View {
    @Query(sort: \RigMove.date, order: .reverse) private var moves: [RigMove]
    @Binding var showingAdd: Bool

    private var completed: Int { moves.filter(\.isDone).count }
    private var open: Int { moves.filter { !$0.isDone }.count }

    var body: some View {
        ZStack {
            AppCanvas()
            ScrollView {
                VStack(spacing: 16) {
                    summaryCard
                    if moves.isEmpty {
                        Text("No rig moves yet.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.top, 8)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(moves, id: \.id) { move in
                                row(move)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Rig Moves")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                TealCircleButton(systemImage: "plus") {
                    showingAdd = true
                }
                .accessibilityLabel("Add Rig Move")
                .accessibilityIdentifier("navAddRigMove")
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddRigMoveView()
        }
    }

    private var summaryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label {
                            Text("FIELD MOVES")
                                .font(.caption.weight(.semibold))
                                .tracking(1.1)
                        } icon: {
                            Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                        }
                        .foregroundStyle(AppTheme.teal)
                        Text("Rig Move Register")
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

                Text("Capture each move fast with route, distance, equipment, water depth, and completion state.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    counter(title: "Completed", value: completed, systemImage: "checkmark.circle.fill", tint: AppTheme.teal)
                    counter(title: "Open", value: open, systemImage: "circle.circle", tint: AppTheme.gold)
                    counter(title: "Total", value: moves.count, systemImage: "sum", tint: AppTheme.teal)
                }

                HStack(spacing: 10) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add Rig Move", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.textPrimary)
                    .background(Color.black.opacity(0.28), in: Capsule())
                    .overlay(Capsule().stroke(AppTheme.teal.opacity(0.45), lineWidth: 1))
                    .accessibilityIdentifier("addRigMovePill")

                    Button {} label: {
                        Label("Share Rig Moves", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.textSecondary)
                    .background(Color.black.opacity(0.2), in: Capsule())
                    .overlay(Capsule().stroke(AppTheme.border, lineWidth: 1))
                    .disabled(true)
                }

                Text("Open includes all in-progress moves until they are marked completed.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func counter(title: String, value: Int, systemImage: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text("\(value)")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func row(_ move: RigMove) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("RM")
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 36, height: 36)
                .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(move.rigName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(dateLine(move))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Text(move.operation.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08), in: Capsule())
                if !move.notes.isEmpty {
                    Text(move.notes)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Text(move.isDone ? "Done" : "Open")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(move.isDone ? AppTheme.teal : AppTheme.gold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.28), in: Capsule())
                    .overlay(Capsule().stroke((move.isDone ? AppTheme.teal : AppTheme.gold).opacity(0.5), lineWidth: 1))
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

    private func dateLine(_ move: RigMove) -> String {
        let day = move.date.formatted(date: .abbreviated, time: .omitted)
        let tf = Date.FormatStyle(date: .omitted, time: .shortened)
        if let start = move.startTime, let end = move.endTime {
            return "\(day) · \(start.formatted(tf)) – \(end.formatted(tf))"
        }
        return day
    }
}
