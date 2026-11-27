import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

/// Import sheet. Solid navy cards — no Liquid Glass on this screen.
struct ImportSheet: View {
    @Binding var preload: ImportReadFile?
    @Binding var limitFailure: ImportLimitError?
    var onFinished: (ImportReport) -> Void

    init(
        preload: Binding<ImportReadFile?>,
        limitFailure: Binding<ImportLimitError?> = .constant(nil),
        onFinished: @escaping (ImportReport) -> Void
    ) {
        _preload = preload
        _limitFailure = limitFailure
        self.onFinished = onFinished
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var session = ImportSession()
    @State private var loadedPreloadID: UUID?
    @State private var showPicker = false
    @State private var confirmReplace = false
    @State private var showSaveError = false
    /// Keeps the alert copy on screen while the alert dismisses.
    @State private var retainedLimitFailure: ImportLimitError?
    @State private var hapticFailure: ImportLimitError?

    var body: some View {
        sheetChrome
            .duoRegularPageSheet()
    }

    private var scrollContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            sourceCard
            previewCard
            modeCard
            disclaimerCard
            importButton
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    private var sheetChrome: some View {
        NavigationStack {
            ZStack {
                AppCanvas()
                ScrollView {
                    scrollContent
                }
            }
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(ImportCopy.cancel) { dismiss() }
                        .accessibilityIdentifier("importCancel")
                }
            }
        }
        .presentationBackground(AppTheme.background)
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("importSheet")
        .onAppear {
            loadPreloadIfNeeded()
            adoptLimitFailureIfNeeded()
        }
        .onChange(of: preload?.id) { _, _ in
            loadPreloadIfNeeded()
        }
        .onChange(of: limitFailure) { _, _ in
            adoptLimitFailureIfNeeded()
        }
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: [.pdf, .commaSeparatedText],
            allowsMultipleSelection: false,
            onCompletion: handlePick
        )
        .alert(ImportCopy.replaceAlertTitle, isPresented: $confirmReplace) {
            Button(ImportCopy.cancel, role: .cancel) {}
            Button(ImportCopy.replaceAlertButton, role: .destructive) {
                commit(replaceConfirmed: true)
            }
        } message: {
            Text(ImportCopy.replaceWarning)
        }
        .alert("Could not save the import", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Nothing was changed.")
        }
        .alert(ImportLimitCopy.tooLargeTitle, isPresented: tooLargePresented) {
            limitAlertActions
        } message: {
            limitAlertMessage(
                displayedFailureMessage(matchingTooLarge: true),
                identifier: ImportLimitCopy.tooLargeIdentifier
            )
        }
        .alert(ImportLimitCopy.tooManyEntriesTitle, isPresented: tooManyPresented) {
            limitAlertActions
        } message: {
            limitAlertMessage(
                displayedFailureMessage(matchingTooLarge: false),
                identifier: ImportLimitCopy.tooManyEntriesIdentifier
            )
        }
        .background {
            ImportLimitAlertMarker(failure: limitFailure ?? retainedLimitFailure)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Source

    private var sourceCard: some View {
        ImportSolidCard {
            ImportEyebrow(title: "SOURCE", systemImage: "doc")
            if let name = session.chosenName, let bytes = session.chosenByteCount {
                chosenFile(name: name, bytes: bytes)
            } else {
                chooseFileButton
                Text(ImportCopy.capsNote)
                    .font(.caption)
                    .foregroundStyle(ImportTokens.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("importSourceEmpty")
            }
        }
    }

    private var chooseFileButton: some View {
        Button {
            showPicker = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "doc")
                    .font(.title3.weight(.semibold))
                Text("Choose file")
                    .font(.body.weight(.bold))
            }
            .foregroundStyle(AppTheme.teal)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.teal.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose file")
        .accessibilityHint("PDF or CSV from Export.")
        .accessibilityIdentifier("importChooseFile")
    }

    private func chosenFile(name: String, bytes: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "doc")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.teal)
                    .frame(width: 36, height: 36)
                    .background(ImportTokens.iconWell, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.body.weight(.bold))
                        .foregroundStyle(ImportTokens.text)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                        .truncationMode(.middle)
                    Text(ImportFilePresentation.detail(byteCount: bytes, filename: name))
                        .font(.caption)
                        .foregroundStyle(ImportTokens.secondary)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 8)
                Button("Change") { showPicker = true }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.teal)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("importChangeFile")
            }
            if let message = session.inlineError {
                Text(message)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("importError")
                    .accessibilityLabel(message)
            } else {
                Text(ImportCopy.chosenVia)
                    .font(.caption)
                    .foregroundStyle(ImportTokens.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Preview

    private var previewCard: some View {
        ImportSolidCard {
            ImportEyebrow(title: "WHAT'S INSIDE", systemImage: "list.bullet")
            if let payload = session.payload {
                if payload.booksPresent.isEmpty {
                    Text(ExportDisclaimer.emptyPreview)
                        .font(.subheadline)
                        .foregroundStyle(ImportTokens.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(payload.booksPresent) { book in
                        ImportPreviewRow(
                            title: book.title,
                            value: payload.exportSnapshot().previewValue(for: book),
                            spoken: payload.exportSnapshot().previewLine(for: book),
                            identifier: "importPreview_\(book.rawValue)",
                            showsDivider: book != payload.booksPresent.last
                        )
                    }
                }
                Text(ExportDisclaimer.booksCaption)
                    .font(.caption)
                    .foregroundStyle(ImportTokens.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                    .accessibilityLabel(ExportDisclaimer.booksCaption)
                    .accessibilityIdentifier("importHoursCaption")
            } else {
                Text(ImportCopy.emptyPreview)
                    .font(.subheadline)
                    .foregroundStyle(ImportTokens.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("importPreviewEmpty")
            }
        }
    }

    // MARK: - Mode

    private var modeCard: some View {
        ImportSolidCard {
            ImportEyebrow(title: "HOW TO ADD", systemImage: "arrow.triangle.branch")
            HStack(spacing: 8) {
                modeButton(.merge)
                modeButton(.replaceBooks)
            }
            .disabled(!session.canImport)
            .opacity(session.canImport ? 1 : 0.45)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("importMode")

            if session.mode == .replaceBooks {
                Text(ImportCopy.replaceWarning)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(ImportTokens.gold)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                    .accessibilityIdentifier("importReplaceWarning")
            } else {
                Text(ImportCopy.mergeHelper)
                    .font(.caption)
                    .foregroundStyle(ImportTokens.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                    .accessibilityIdentifier("importMergeHelper")
            }
        }
    }

    private func modeButton(_ mode: ImportMode) -> some View {
        let selected = session.mode == mode
        return Button {
            session.mode = mode
        } label: {
            Text(mode.title)
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(selected ? ImportTokens.onTeal : ImportTokens.secondary)
                .background(
                    selected ? AppTheme.teal : ImportTokens.segmentIdle,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(mode == .merge ? "importMerge" : "importReplace")
    }

    // MARK: - Disclaimer

    private var disclaimerCard: some View {
        ImportSolidCard(border: ImportTokens.goldBorder) {
            ImportEyebrow(title: "DISCLAIMER", systemImage: "info.circle", tint: ImportTokens.gold)
            Text(ExportDisclaimer.text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ImportTokens.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("importDisclaimer")
                .accessibilityLabel(ExportDisclaimer.text)
        }
    }

    // MARK: - Import

    private var importButton: some View {
        Button(action: importTapped) {
            Text(ImportCopy.importButton)
                .font(.body.weight(.heavy))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .frame(minHeight: HomeCTAButton.hardMinimumHit)
        }
        .buttonStyle(.plain)
        .foregroundStyle(session.canImport ? ImportTokens.onTeal : ImportTokens.secondary)
        .background(
            session.canImport ? AppTheme.teal : ImportTokens.disabledFill,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .disabled(!session.canImport)
        .accessibilityLabel("Import")
        .accessibilityValue(session.canImport ? "Enabled" : "Disabled")
        .accessibilityHint(session.canImport ? "Imports the chosen file." : "Choose a valid export file to import.")
        .accessibilityIdentifier("importCommit")
    }

    // MARK: - Actions

    private func loadPreloadIfNeeded() {
        guard limitFailure == nil else { return }
        guard let file = preload else { return }
        guard loadedPreloadID != file.id else { return }
        loadedPreloadID = file.id
        limitFailure = session.receiveFile(name: file.name, data: file.data)
    }

    private func handlePick(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            let ns = error as NSError
            if error is CancellationError { return }
            if ns.domain == NSCocoaErrorDomain && ns.code == NSUserCancelledError { return }
            return
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let file = try ImportFileAccess.read(url: url)
                limitFailure = session.receiveFile(name: file.name, data: file.data)
            } catch let error as ImportLimitError {
                session.rejectOverLimit()
                limitFailure = error
            } catch {
                limitFailure = nil
                session.failRead(name: url.lastPathComponent)
            }
        }
    }

    private var tooLargePresented: Binding<Bool> {
        Binding(
            get: {
                if case .tooLarge = limitFailure { return true }
                return false
            },
            set: { isPresented in
                if !isPresented, case .tooLarge = limitFailure {
                    limitFailure = nil
                }
            }
        )
    }

    private var tooManyPresented: Binding<Bool> {
        Binding(
            get: {
                if case .tooManyEntries = limitFailure { return true }
                return false
            },
            set: { isPresented in
                if !isPresented, case .tooManyEntries = limitFailure {
                    limitFailure = nil
                }
            }
        )
    }

    /// Default action reopens the picker. Cancel leaves existing entries alone.
    /// Neither button is destructive.
    @ViewBuilder
    private var limitAlertActions: some View {
        Button(ImportLimitCopy.chooseAnotherFile) {
            limitFailure = nil
            // After the alert finishes dismissing, otherwise the picker will not present.
            Task { @MainActor in
                showPicker = true
            }
        }
        .keyboardShortcut(.defaultAction)
        Button(ImportCopy.cancel, role: .cancel) {}
    }

    /// Full message at AXL: wrap, do not shrink, do not truncate.
    private func limitAlertMessage(_ text: String, identifier: String) -> some View {
        Text(text)
            .font(.body)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .minimumScaleFactor(1)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier(identifier)
    }

    private func displayedFailureMessage(matchingTooLarge: Bool) -> String {
        guard let failure = limitFailure ?? retainedLimitFailure else { return "" }
        switch failure {
        case .tooLarge where matchingTooLarge:
            return failure.message
        case .tooManyEntries where !matchingTooLarge:
            return failure.message
        default:
            return ""
        }
    }

    private func adoptLimitFailureIfNeeded() {
        if let failure = limitFailure {
            retainedLimitFailure = failure
            session.rejectOverLimit()
            if hapticFailure != failure {
                hapticFailure = failure
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
            return
        }
        hapticFailure = nil
    }

    private func importTapped() {
        guard session.canImport else { return }
        if session.mode == .replaceBooks {
            confirmReplace = true
            return
        }
        commit(replaceConfirmed: false)
    }

    /// Replace reaches this only from the confirm alert. Cancel on that alert does not call it.
    private func commit(replaceConfirmed: Bool) {
        guard let payload = session.payload else { return }
        guard ImportWriteGate.shouldWrite(
            canImport: session.canImport,
            mode: session.mode,
            replaceConfirmed: replaceConfirmed
        ) else { return }
        do {
            let report = try ImportStore.apply(mode: session.mode, payload: payload, context: modelContext)
            onFinished(report)
        } catch {
            showSaveError = true
        }
    }
}

// MARK: - Solid navy tokens (same sheet as Export — no glass)

private enum ImportTokens {
    static let text = Color(red: 0.933, green: 0.953, blue: 0.969)       // #EEF3F7
    static let secondary = Color(red: 0.706, green: 0.745, blue: 0.769)  // #B4BEC4
    static let card = Color(red: 0.106, green: 0.137, blue: 0.153)       // #1B2327
    static let cardBorder = Color(red: 0.227, green: 0.278, blue: 0.302) // #3A474D
    static let iconWell = Color(red: 0.157, green: 0.227, blue: 0.231)
    static let segmentIdle = Color(red: 0.20, green: 0.24, blue: 0.26)
    static let disabledFill = Color(red: 0.227, green: 0.267, blue: 0.282)
    static let onTeal = Color(red: 0.051, green: 0.165, blue: 0.149)
    static let gold = Color(red: 217 / 255, green: 173 / 255, blue: 82 / 255) // #D9AD52
    static let goldBorder = Color(red: 217 / 255, green: 173 / 255, blue: 82 / 255).opacity(0.45)
}

private struct ImportSolidCard<Content: View>: View {
    var border: Color = ImportTokens.cardBorder
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ImportTokens.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
    }
}

private struct ImportPreviewRow: View {
    let title: String
    let value: String
    let spoken: String
    let identifier: String
    let showsDivider: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ImportTokens.text)
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(ImportTokens.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            if showsDivider {
                Rectangle()
                    .fill(ImportTokens.cardBorder)
                    .frame(height: 1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spoken)
        .accessibilityIdentifier(identifier)
    }
}

private struct ImportEyebrow: View {
    let title: String
    let systemImage: String
    var tint: Color = AppTheme.teal

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.bold))
            .tracking(1.4)
            .foregroundStyle(tint)
            .padding(.bottom, 8)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Stamps `importErrorTooLarge` / `importErrorTooManyEntries` on the system alert, and
/// keeps the message labels wrapping at AXL instead of truncating.
private struct ImportLimitAlertMarker: UIViewRepresentable {
    var failure: ImportLimitError?

    func makeUIView(context: Context) -> MarkerView {
        let view = MarkerView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ uiView: MarkerView, context: Context) {
        if uiView.failure != failure {
            uiView.retries = 0
        }
        uiView.failure = failure
        uiView.apply()
    }

    final class MarkerView: UIView {
        var failure: ImportLimitError?
        var retries = 0

        override func didMoveToWindow() {
            super.didMoveToWindow()
            apply()
        }

        func apply() {
            guard let failure else { return }
            guard let alert = presentedAlert(title: failure.title) else {
                scheduleRetry()
                return
            }
            alert.view.accessibilityIdentifier = failure.accessibilityIdentifier
            wrapLabels(in: alert.view)
        }

        private func scheduleRetry() {
            guard retries < 4 else { return }
            retries += 1
            DispatchQueue.main.async { [weak self] in
                self?.apply()
            }
        }

        private func presentedAlert(title: String) -> UIAlertController? {
            guard let root = window?.rootViewController else { return nil }
            return search(root, title: title)
        }

        private func search(_ controller: UIViewController, title: String) -> UIAlertController? {
            if let alert = controller as? UIAlertController, alert.title == title {
                return alert
            }
            if let presented = controller.presentedViewController,
               let found = search(presented, title: title) {
                return found
            }
            for child in controller.children {
                if let found = search(child, title: title) {
                    return found
                }
            }
            return nil
        }

        private func wrapLabels(in view: UIView) {
            if let label = view as? UILabel {
                label.numberOfLines = 0
                label.lineBreakMode = .byWordWrapping
                label.adjustsFontSizeToFitWidth = false
                label.allowsDefaultTighteningForTruncation = false
                label.adjustsFontForContentSizeCategory = true
            }
            for subview in view.subviews {
                wrapLabels(in: subview)
            }
        }
    }
}

#Preview {
    ImportSheet(preload: .constant(nil), onFinished: { _ in })
        .modelContainer(for: [DPEntry.self, RigMove.self, ROVEntry.self, CraneEntry.self], inMemory: true)
        .preferredColorScheme(.dark)
}
