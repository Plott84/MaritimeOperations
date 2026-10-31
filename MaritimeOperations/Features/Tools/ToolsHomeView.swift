import SwiftUI

/// Tools tab home — grouped list (DP & NAV · DECK CALCS · REFERENCE).
/// Until a tool has a saved result on this device, its row shows a one-line blurb.
/// After that, the last-input status line replaces the blurb. Port keeps its own count line.
struct ToolsHomeView: View {
    /// Nil keeps the compact push list. A binding selects a row for the regular-width detail.
    var selection: Binding<DeckTool?>?

    init(selection: Binding<DeckTool?>? = nil) {
        self.selection = selection
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
            .init(kind: .gyro, title: Self.gyroCompassTitle, hint: Self.blurb(.gyro),
                  systemImage: "location.north.line",
                  voiceOverHint: Self.gyroCompassHint)
        ]),
        .init(title: "DECK CALCS", tools: [
            .init(kind: .catenary, title: "Catenary", hint: Self.blurb(.catenary),
                  systemImage: "point.topleft.down.curvedto.point.bottomright.up"),
            .init(kind: .winch, title: "Winch capacity", hint: Self.blurb(.winch),
                  systemImage: "cylinder.split.1x2"),
            .init(kind: .chainLocker, title: "Chain locker", hint: Self.blurb(.chainLocker),
                  systemImage: "link"),
            .init(kind: .craneHeel, title: "Crane heel", hint: Self.blurb(.craneHeel),
                  systemImage: "ferry"),
            .init(kind: .rigging, title: "Slinging & Rigging", hint: Self.blurb(.rigging),
                  systemImage: "scalemass",
                  voiceOverHint: "Sling angle and chain-block check")
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
                            // Solid navy card (spec #1B2327 + 1px #3A474D, 20 pt). Glass stays on the tab bar only.
                            VStack(spacing: 0) {
                                ForEach(Array(section.tools.enumerated()), id: \.element.id) { index, tool in
                                    if index > 0 {
                                        Divider().overlay(AppTheme.cardBorder).padding(.leading, 62)
                                    }
                                    toolRow(tool)
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(AppTheme.card)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(AppTheme.cardBorder, lineWidth: 1)
                            )
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

    /// Visible title of the single DP & NAV row. The destination id stays `gyro`.
    static let gyroCompassTitle = "Gyro & Compass"
    /// VoiceOver hint for that row. Mentions both checks, empty or not.
    static let gyroCompassHint = GyroCompassCopy.rowHint

    /// Empty-row copy. Port has no blurb — that row uses the offline count line.
    /// Gyro & Compass shows the not-used sentinel until either tab saves a result.
    static func emptyBlurb(for kind: ToolLastResultKind) -> String? {
        switch kind {
        case .gyro: return ToolLastResultStore.notUsed
        case .compassError: return "Sun amplitude · °C / °T"
        case .catenary: return "Free-hang span and sag"
        case .winch: return "Drum length and layers"
        case .chainLocker: return "Stowage volume and length"
        case .craneHeel: return "Static heel and ballast to level"
        case .rigging: return ToolLastResultStore.notUsed
        case .portUnlocode: return nil
        }
    }

    private static func blurb(_ kind: ToolLastResultKind) -> String {
        emptyBlurb(for: kind) ?? ""
    }

    /// Calculation-tool subtitle. A missing or `notUsed` store value shows `blurb`; a saved summary wins.
    static func rowSubtitle(stored: String?, blurb: String) -> (text: String, isEmpty: Bool) {
        let s = stored ?? ToolLastResultStore.notUsed
        if s == ToolLastResultStore.notUsed {
            return (blurb, true)
        }
        return (s, false)
    }

    private func status(for tool: ToolTile) -> (text: String, isEmpty: Bool) {
        if tool.kind == .portUnlocode {
            // Spec: never empty. "17.6k ports offline · no searches yet" until the first search.
            guard let count = portCountText else { return ("Offline UNECE port codes", false) }
            return (statuses[.portUnlocode] == nil ? "\(count) · no searches yet" : count, false)
        }
        return Self.rowSubtitle(stored: statuses[tool.kind], blurb: tool.hint)
    }

    @ViewBuilder
    private func destination(for kind: ToolTile.Kind) -> some View {
        kind.deckTool.detail
    }

    /// Compact rows push. Regular rows set the split selection and keep the same row ids.
    @ViewBuilder
    private func toolRow(_ tool: ToolTile) -> some View {
        if let selection {
            let selected = selection.wrappedValue == tool.kind.deckTool
            Button {
                selection.wrappedValue = tool.kind.deckTool
            } label: {
                row(tool)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.teal.opacity(0.14))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                }
            }
        } else {
            NavigationLink {
                destination(for: tool.kind)
            } label: {
                row(tool)
            }
            .buttonStyle(.plain)
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
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
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
        // Empty rows already speak the blurb as the visible subtitle. A last-result row keeps the blurb as the hint.
        // Gyro & Compass always hints at both checks.
        .accessibilityHint(tool.voiceOverHint ?? (st.isEmpty ? "" : tool.hint))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("toolTile.\(tool.kind.rawValue)")
    }
}

private struct ToolTile: Identifiable {
    enum Kind: String { case gyro, catenary, winch, chainLocker, craneHeel, rigging, portUnlocode
        var lastResultKind: ToolLastResultKind? { ToolLastResultKind(rawValue: rawValue) }
        var deckTool: DeckTool {
            switch self {
            case .gyro: return .gyro
            case .catenary: return .catenary
            case .winch: return .winch
            case .chainLocker: return .chainLocker
            case .craneHeel: return .craneHeel
            case .rigging: return .rigging
            case .portUnlocode: return .portUnlocode
            }
        }
    }
    var id: String { kind.rawValue }
    let kind: Kind
    let title: String
    let hint: String
    let systemImage: String
    var voiceOverHint: String? = nil
}
