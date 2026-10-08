import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case main
    case log
    case tools
    case export

    var id: String { rawValue }

    var title: String {
        switch self {
        case .main: return "Main"
        case .log: return "Log"
        case .tools: return "Tools"
        case .export: return "Export"
        }
    }

    var systemImage: String {
        switch self {
        case .main: return "house.fill"
        case .log: return "book.closed"
        case .tools: return "wrench.and.screwdriver"
        case .export: return "doc.text"
        }
    }
}

struct FloatingTabBar: View {
    @Binding var selection: AppTab
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                        // Accessibility text sizes: icons only; long-press shows the name (Large Content Viewer).
                        if !dynamicTypeSize.isAccessibilitySize {
                            Text(tab.title)
                                .font(.caption2.weight(.medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .foregroundStyle(selection == tab ? AppTheme.teal : AppTheme.textPrimary.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityShowsLargeContentViewer {
                    Label(tab.title, systemImage: tab.systemImage)
                }
                .accessibilityIdentifier("tab_\(tab.rawValue)")
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
