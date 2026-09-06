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
        case .entries: return "clipboard"
        case .rigMoves: return "arrow.triangle.swap"
        case .tools: return "wrench.and.screwdriver"
        case .export: return "doc.badge.arrow.down"
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
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 18, weight: .semibold))
                        Text(tab.title)
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(selection == tab ? AppTheme.teal : AppTheme.textPrimary.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
