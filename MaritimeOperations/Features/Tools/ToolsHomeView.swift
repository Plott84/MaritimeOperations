import SwiftUI

/// Tools tab home — two-column grid of live desk tools.
struct ToolsHomeView: View {
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private let tools: [ToolTile] = [
        .init(
            kind: .catenary,
            title: "Catenary",
            subtitle: "Free-hang span and sag",
            systemImage: "point.topleft.down.curvedto.point.bottomright.up"
        ),
        .init(
            kind: .winch,
            title: "Winch capacity",
            subtitle: "Drum length and layers",
            systemImage: "cylinder.split.1x2"
        ),
        .init(
            kind: .gyro,
            title: "Gyro check",
            subtitle: "Transit, sun azimuth, amplitude",
            systemImage: "location.north.line"
        ),
        .init(
            kind: .chainLocker,
            title: "Chain locker",
            subtitle: "Stowage volume and length",
            systemImage: "link"
        ),
        .init(
            kind: .craneHeel,
            title: "Crane heel",
            subtitle: "Static heel and ballast to level",
            systemImage: "ferry"
        )
    ]

    var body: some View {
        ZStack {
            AppCanvas()
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(tools) { tool in
                        NavigationLink {
                            destination(for: tool.kind)
                        } label: {
                            tile(tool)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Tools")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    @ViewBuilder
    private func destination(for kind: ToolTile.Kind) -> some View {
        switch kind {
        case .catenary: CatenaryToolView()
        case .winch: WinchCapacityToolView()
        case .gyro: GyroCheckToolView()
        case .chainLocker: ChainLockerToolView()
        case .craneHeel: CraneHeelView()
        }
    }

    private func tile(_ tool: ToolTile) -> some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: tool.systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppTheme.teal)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.black.opacity(0.28)))
                    .overlay(Circle().stroke(AppTheme.teal.opacity(0.55), lineWidth: 1))
                Text(tool.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                Text(tool.subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tool.title). \(tool.subtitle)")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("toolTile.\(tool.kind.rawValue)")
    }
}

private struct ToolTile: Identifiable {
    enum Kind: String { case catenary, winch, gyro, chainLocker, craneHeel }
    var id: String { kind.rawValue }
    let kind: Kind
    let title: String
    let subtitle: String
    let systemImage: String
}
