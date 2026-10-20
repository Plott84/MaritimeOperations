import SwiftUI

/// Tools tab home — grouped list (DP & NAV · DECK CALCS · REFERENCE).
/// Each row shows a one-line status from the tool's last valid result on this device.
struct ToolsHomeView: View {
    @State private var statuses: [ToolTile.Kind: String] = [:]
    @State private var portCountText: String?
    private let store = ToolLastResultStore()

    private struct Section: Identifiable {
        let title: String
        let tools: [ToolTile]
        var id: String { title }
    }

    private let sections: [Section] = [
        .init(title: "DP & NAV", tools: [
            .init(kind: .gyro, title: "Gyro check", hint: "Transit, sun azimuth, amplitude",
                  systemImage: "location.north.line"),
            .init(kind: .compassError, title: "Compass error", hint: "Compass error and deviation from the sun's amplitude",
                  systemImage: "safari")
        ]),
        .init(title: "DECK CALCS", tools: [
            .init(kind: .catenary, title: "Catenary", hint: "Free-hang span and sag",
                  systemImage: "point.topleft.down.curvedto.point.bottomright.up"),
            .init(kind: .winch, title: "Winch capacity", hint: "Drum length and layers",
                  systemImage: "cylinder.split.1x2"),
            .init(kind: .chainLocker, title: "Chain locker", hint: "Stowage volume and length",
                  systemImage: "link"),
            .init(kind: .craneHeel, title: "Crane heel", hint: "Static heel and ballast to level",
                  systemImage: "ferry")
        ]),
        .init(title: "REFERENCE", tools: [
            .init(kind: .portUnlocode, title: "Port UN/LOCODE", hint: "Offline UNECE port codes",
                  systemImage: "mappin.and.ellipse")
        ])
    ]

    var body: some View {
        ZStack {
            AppCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .font(.caption.weight(.semibold))
                                .tracking(1.0)
                                .foregroundStyle(AppTheme.textSecondary)
                                .padding(.leading, 4)
                                .accessibilityAddTraits(.isHeader)
                            GlassCard(padding: 0) {
                                VStack(spacing: 0) {
                                    ForEach(Array(section.tools.enumerated()), id: \.element.id) { index, tool in
                                        if index > 0 {
                                            Divider().overlay(AppTheme.cardBorder).padding(.leading, 62)
                                        }
                                        NavigationLink {
                                            destination(for: tool.kind)
                                        } label: {
                                            row(tool)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    Text("Subtitles show your last inputs on this device only.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Tools")
        .navigationBarTitleDisplayMode(.inline)
        .systemGlassNavigation()
        .onAppear(perform: reloadStatuses)
        .onReceive(NotificationCenter.default.publisher(for: ToolLastResultStore.didChange)) { _ in reloadStatuses() }
        .task { await loadPortCount() }
    }

    private func reloadStatuses() {
        var s: [ToolTile.Kind: String] = [:]
        for tool in sections.flatMap(\.tools) {
            guard let k = tool.kind.lastResultKind else { continue }
            if k == .portUnlocode {
                if store.load(for: k) != nil { s[tool.kind] = "searched" }
            } else {
                s[tool.kind] = store.status(for: k)
            }
        }
        statuses = s
    }

    private func loadPortCount() async {
        guard portCountText == nil else { return }
        let count = await Task.detached(priority: .utility) {
            (try? PortUnlocodeCatalog.loadBundled())?.count
        }.value
        if let count { portCountText = ToolsHomeView.portCountLine(count) }
    }

    /// 17_612 → "17.6k ports offline"
    static func portCountLine(_ count: Int) -> String {
        if count < 1000 { return "\(count) ports offline" }
        return String(format: "%.1fk ports offline", Double(count) / 1000)
    }

    private func status(for tool: ToolTile) -> (text: String, isEmpty: Bool) {
        if tool.kind == .portUnlocode {
            // Spec: never empty. "17.6k ports offline · no searches yet" until the first search.
            guard let count = portCountText else { return ("Offline UNECE port codes", false) }
            return (statuses[.portUnlocode] == nil ? "\(count) · no searches yet" : count, false)
        }
        let s = statuses[tool.kind] ?? ToolLastResultStore.notUsed
        return (s, s == ToolLastResultStore.notUsed)
    }

    @ViewBuilder
    private func destination(for kind: ToolTile.Kind) -> some View {
        switch kind {
        case .catenary: CatenaryToolView()
        case .winch: WinchCapacityToolView()
        case .gyro: GyroCheckToolView()
        case .compassError: CompassErrorToolView()
        case .chainLocker: ChainLockerToolView()
        case .craneHeel: CraneHeelView()
        case .portUnlocode: PortUnlocodeToolView()
        }
    }

    private func row(_ tool: ToolTile) -> some View {
        let st = status(for: tool)
        return HStack(alignment: .center, spacing: 12) {
            Image(systemName: tool.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.teal)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(AppTheme.surface))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(st.text)
                    .font(.subheadline)
                    .italic(st.isEmpty)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .accessibilityIdentifier("toolStatus.\(tool.kind.rawValue)")
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 58)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tool.title), \(st.text)")
        .accessibilityHint(tool.hint)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("toolTile.\(tool.kind.rawValue)")
    }
}

private struct ToolTile: Identifiable {
    enum Kind: String { case gyro, compassError, catenary, winch, chainLocker, craneHeel, portUnlocode
        var lastResultKind: ToolLastResultKind? { ToolLastResultKind(rawValue: rawValue) }
    }
    var id: String { kind.rawValue }
    let kind: Kind
    let title: String
    let hint: String
    let systemImage: String
}
