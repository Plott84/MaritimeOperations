import SwiftUI

/// Regular-width Tools: grouped list beside the selected tool.
/// Compact width keeps `ToolsHomeView` pushed on a `NavigationStack`.
struct ToolsSplitView: View {
    @State private var selection: DeckTool? = DeckTool.splitDefault

    var body: some View {
        NavigationSplitView {
            ToolsHomeView(selection: $selection)
                .navigationSplitViewColumnWidth(
                    min: DuoToolsColumn.sidebarMin,
                    ideal: DuoToolsColumn.sidebarIdeal,
                    max: DuoToolsColumn.sidebarMax
                )
        } detail: {
            if let selection {
                selection.detail
            } else {
                ToolsSelectPrompt()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

/// Detail when nothing is selected. First paint selects Winch capacity instead.
struct ToolsSelectPrompt: View {
    var body: some View {
        ZStack {
            AppCanvas()
            Text(DuoToolsColumn.emptyDetail)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("toolsEmptyDetail")
        }
    }
}
