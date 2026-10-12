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
                let selected = selection == tab
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(height: 22)
                        // Accessibility text sizes: icons only; long-press shows the name (Large Content Viewer).
                        if !dynamicTypeSize.isAccessibilitySize {
                            Text(tab.title)
                                .font(.caption2.weight(.medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .foregroundStyle(selected ? AppTheme.teal : AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 2)
                    .modifier(SelectedTabGlass(isSelected: selected))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityShowsLargeContentViewer {
                    Label(tab.title, systemImage: tab.systemImage)
                }
                .accessibilityIdentifier("tab_\(tab.rawValue)")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }
}

/// Glass pill behind the selected tab. A full teal tint paints an opaque pill and hides the teal icon.
/// This wash stays translucent so the teal accent reads on glass.
private struct SelectedTabGlass: ViewModifier {
    var isSelected: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isSelected {
            content.glassEffect(.regular.tint(AppTheme.teal.opacity(0.18)), in: .capsule)
        } else {
            content
        }
    }
}
