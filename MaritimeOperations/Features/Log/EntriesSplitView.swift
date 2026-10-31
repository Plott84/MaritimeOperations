import SwiftUI

/// Regular-width Entries: Soft B book list beside the selected book.
/// Compact width keeps `LogView` pushed on a `NavigationStack`.
struct EntriesSplitView: View {
    var session: ActiveDPSessionStore
    @Binding var selection: LogBook?
    @Binding var showingAddRigMove: Bool
    var onStartDP: () -> Void

    var body: some View {
        NavigationSplitView {
            LogView(selection: $selection)
                .navigationSplitViewColumnWidth(
                    min: DuoEntriesColumn.sidebarMin,
                    ideal: DuoEntriesColumn.sidebarIdeal,
                    max: DuoEntriesColumn.sidebarMax
                )
        } detail: {
            if let selection {
                BookDestination(
                    book: selection,
                    session: session,
                    showingAddRigMove: $showingAddRigMove,
                    onStartDP: onStartDP
                )
            } else {
                EntriesSelectPrompt()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

/// One book’s list. Shared by the compact push and the regular detail pane.
struct BookDestination: View {
    let book: LogBook
    var session: ActiveDPSessionStore
    @Binding var showingAddRigMove: Bool
    var onStartDP: () -> Void

    var body: some View {
        switch book {
        case .dp:
            EntriesView(session: session, onStartDP: onStartDP)
        case .anchorHandling:
            RigMovesView(showingAdd: $showingAddRigMove)
        case .rov:
            ROVBookView()
        case .crane:
            CraneBookView()
        }
    }
}

/// Detail when no book is selected. First paint selects DP instead.
struct EntriesSelectPrompt: View {
    var body: some View {
        ZStack {
            AppCanvas()
            Text(DuoEntriesColumn.emptyDetail)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("entriesEmptyDetail")
        }
    }
}
