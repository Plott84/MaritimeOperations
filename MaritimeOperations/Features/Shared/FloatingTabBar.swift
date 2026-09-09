import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case main
    case entries
    case rigMoves
    case tools
    case export

    var id: String { rawValue }

    var title: String {
        switch self {
        case .main: return "Main"
        case .entries: return "Entries"
        case .rigMoves: return "Rig Moves"
        case .tools: return "Tools"
        case .export: return "Export"
        }
    }

    var systemImage: String {
        switch self {
        case .main: return "house.fill"
        case .entries: return "list.clipboard"
        case .rigMoves: return "point.topleft.down.curvedto.point.bottomright.up"
        case .tools: return "wrench.and.screwdriver"
        case .export: return "doc.text"
        }
    }
}

struct FloatingTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if selection == tab {
                                Circle()
                                    .fill(AppTheme.teal)
                                    .frame(width: 36, height: 36)
                            }
                            Image(systemName: tab.systemImage)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(selection == tab ? Color.black.opacity(0.85) : AppTheme.textPrimary.opacity(0.8))
                        }
                        .frame(height: 36)
                        Text(tab.title)
                            .font(.caption2.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(selection == tab ? AppTheme.teal : AppTheme.textPrimary.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(AppTheme.teal.opacity(0.35), lineWidth: 1)
                }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }
}
