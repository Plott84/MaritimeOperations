import SwiftUI
import SwiftData

struct RootView: View {
    @State private var tab: AppTab = .main
    @State private var session = ActiveDPSessionStore()

    var body: some View {
        NavigationStack {
            Group {
                switch tab {
                case .main:
                    MainView(session: session) {
                        tab = .rigMoves
                    }
                case .entries:
                    EntriesView()
                case .rigMoves:
                    PlaceholderTabView(title: "Rig Moves", subtitle: "Coming next — use this tab as a stub for now.")
                case .tools:
                    PlaceholderTabView(title: "Tools", subtitle: "Extra tools land after Entries MVP.")
                case .export:
                    PlaceholderTabView(title: "Export", subtitle: "PDF date-range export comes after the logbook model is solid.")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) {
                FloatingTabBar(selection: $tab)
            }
        }
        .preferredColorScheme(.dark)
        .tint(AppTheme.teal)
    }
}

#Preview {
    RootView()
        .modelContainer(for: DPEntry.self, inMemory: true)
}
