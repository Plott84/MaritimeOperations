import SwiftUI
import SwiftData

struct RootView: View {
    @State private var tab: AppTab = .main
    @State private var session = ActiveDPSessionStore()
    @State private var showingAddRigMove = false
    @State private var logPath: [LogBook] = []
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
        .onOpenURL { url in
            openImport(from: url)
        }
        .sheet(isPresented: $showImport, onDismiss: { importPreload = nil }) {
            ImportSheet(preload: $importPreload, onFinished: finishImport)
        }
        .overlay(alignment: .bottom) {
            if let importToast {
                Text(importToast)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.85))
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
        tab = .log
        importToast = report.toastText
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
