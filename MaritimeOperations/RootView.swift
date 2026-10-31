import SwiftUI
import SwiftData

struct RootView: View {
    @State private var tab: AppTab = .main
    @State private var session = ActiveDPSessionStore()
    @State private var showingAddRigMove = false
    @State private var showingAddCrane = false
    @State private var showingAddROV = false
    @State private var logPath: [LogBook] = []
    /// Regular-width Entries detail. Compact pushes `logPath` instead.
    @State private var entriesBook: LogBook? = DuoEntriesColumn.defaultSelection(
        available: LogBook.entriesListOrder,
        primary: .dp
    )
    @State private var showImport = false
    @State private var importPreload: ImportReadFile?
    @State private var importToast: String?

    var body: some View {
        Group {
            switch tab {
            case .main:
                NavigationStack {
                    MainView(
                        session: session,
                        onOpenRigMoves: { open(.anchorHandling, addingEntry: true) },
                        onOpenBook: { open($0) },
                        onNewCraneEntry: { showingAddCrane = true },
                        onNewROVEntry: { showingAddROV = true }
                    )
                }
            case .log:
                // Compact: Soft B books push. Regular: books | entry list. Bottom tabs either way.
                DuoSizeClassReader { split in
                    if split {
                        EntriesSplitView(
                            session: session,
                            selection: $entriesBook,
                            showingAddRigMove: $showingAddRigMove,
                            onStartDP: { tab = .main }
                        )
                    } else {
                        NavigationStack(path: $logPath) {
                            LogView()
                                .navigationDestination(for: LogBook.self) { book in
                                    BookDestination(
                                        book: book,
                                        session: session,
                                        showingAddRigMove: $showingAddRigMove,
                                        onStartDP: { tab = .main }
                                    )
                                }
                        }
                    }
                }
            case .tools:
                // Compact: grouped push list. Regular: list | detail. Bottom tabs either way.
                DuoSizeClassReader { split in
                    if split {
                        ToolsSplitView()
                    } else {
                        NavigationStack {
                            ToolsHomeView()
                        }
                    }
                }
            case .export:
                NavigationStack {
                    ExportView(onImport: {
                        importPreload = nil
                        showImport = true
                    })
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            FloatingTabBar(selection: $tab)
        }
        .preferredColorScheme(.dark)
        .tint(AppTheme.teal)
        .toggleStyle(TokenToggleStyle())
        .onOpenURL { url in
            openImport(from: url)
        }
        .sheet(isPresented: $showImport, onDismiss: { importPreload = nil }) {
            ImportSheet(preload: $importPreload, onFinished: finishImport)
        }
        .sheet(isPresented: $showingAddCrane) {
            AddCraneEntryView()
        }
        .sheet(isPresented: $showingAddROV) {
            AddROVEntryView()
        }
        .overlay(alignment: .bottom) {
            if let importToast {
                Text(importToast)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.onTeal)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppTheme.teal, in: Capsule())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 96)
                    .accessibilityLabel(importToast)
                    .accessibilityIdentifier("importResultToast")
            }
        }
        .animation(.easeInOut(duration: 0.2), value: importToast)
        .onChange(of: importToast) { _, text in
            guard text != nil else { return }
            Task {
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                importToast = nil
            }
        }
    }

    /// Files, AirDrop, or the share sheet opened an export. The sheet shows that file.
    private func openImport(from url: URL) {
        if let file = try? ImportFileAccess.read(url: url) {
            importPreload = file
        } else {
            importPreload = ImportReadFile(
                name: url.lastPathComponent.isEmpty ? "Export" : url.lastPathComponent,
                data: Data()
            )
        }
        showImport = true
    }

    /// Dismiss Import and show the Log books that changed. One book opens that book.
    private func finishImport(_ report: ImportReport) {
        showImport = false
        importPreload = nil
        showingAddRigMove = false
        logPath = report.logPath
        if let book = report.logPath.first {
            entriesBook = book
        }
        tab = .log
        importToast = report.toastText
    }

    /// Switch to Entries, optionally straight into a book (and its New entry form).
    private func open(_ book: LogBook?, addingEntry: Bool = false) {
        logPath = book.map { [$0] } ?? []
        if let book {
            entriesBook = book
        }
        tab = .log
        showingAddRigMove = addingEntry
    }
}

#Preview {
    RootView()
        .modelContainer(for: [DPEntry.self, RigMove.self, ROVEntry.self, CraneEntry.self], inMemory: true)
}
