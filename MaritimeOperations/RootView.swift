import SwiftUI
import SwiftData

struct RootView: View {
    @State private var tab: AppTab = .main
    @State private var session = ActiveDPSessionStore()
    @State private var showingAddRigMove = false
    @State private var logPath: [LogBook] = []

    var body: some View {
        Group {
            switch tab {
            case .main:
                NavigationStack {
                    MainView(
                        session: session,
                        onOpenRigMoves: { open(.anchorHandling, addingEntry: true) },
                        onOpenBook: { open($0) },
                        onOpenLog: { open(nil) }
                    )
                }
            case .log:
                NavigationStack(path: $logPath) {
                    LogView()
                        .navigationDestination(for: LogBook.self) { book in
                            switch book {
                            case .dp:
                                EntriesView(session: session)
                            case .anchorHandling:
                                RigMovesView(showingAdd: $showingAddRigMove)
                            case .rov:
                                ROVBookView()
                            case .crane:
                                CraneBookView()
                            }
                        }
                }
            case .tools:
                NavigationStack {
                    ToolsHomeView()
                }
            case .export:
                NavigationStack {
                    PlaceholderTabView(title: "Export", subtitle: "PDF date-range export comes after the logbook model is solid.")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            FloatingTabBar(selection: $tab)
        }
        .preferredColorScheme(.dark)
        .tint(AppTheme.teal)
    }

    /// Switch to Log, optionally straight into a book (and its New entry form).
    private func open(_ book: LogBook?, addingEntry: Bool = false) {
        logPath = book.map { [$0] } ?? []
        tab = .log
        if addingEntry {
            showingAddRigMove = true
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [DPEntry.self, RigMove.self, ROVEntry.self, CraneEntry.self], inMemory: true)
}
