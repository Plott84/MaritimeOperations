import SwiftUI
import SwiftData
import UIKit

/// Multi-book Export tab — Pixel sheet: books · date range · live preview · disclaimer · sticky Share / Print / Copy.
/// Solid navy cards only — no Liquid Glass on this screen. Sticky actions use safeAreaInset so they clear the floating tab bar and never cover the disclaimer.
struct ExportView: View {
    @Query private var dpEntries: [DPEntry]
    @Query private var moves: [RigMove]
    @Query private var rovEntries: [ROVEntry]
    @Query private var craneEntries: [CraneEntry]

    var onImport: () -> Void = {}

    @State private var books = ExportBookSelection()
    @State private var dateFilter = ExportDateFilter.defaults(earliestEntry: nil)
    @State private var didApplyInitialRange = false
    @State private var showEmptyAlert = false
    @State private var showCopyToast = false
    @State private var showRenderError = false

    private var earliestEntry: Date? {
        ExportAggregator.earliestEntryDate(
            dp: dpEntries, moves: moves, rov: rovEntries, crane: craneEntries
        )
    }

    private var snapshot: ExportSnapshot {
        ExportAggregator.snapshot(
            dp: dpEntries, moves: moves, rov: rovEntries, crane: craneEntries,
            filter: dateFilter
        )
    }

    var body: some View {
        ZStack {
            AppCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    booksCard
                    includedLine
                    dateRangeCard
                    previewCard
                    disclaimerCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                // Breathing room above sticky Share strip (safeAreaInset below).
                .padding(.bottom, 20)
            }
        }
        // Sticky Share / Print / Copy above the floating tab bar so the
        // full disclaimer always scrolls clear of the action strip.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            stickyActions
        }
        .navigationTitle("Export")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            guard !didApplyInitialRange else { return }
            dateFilter = ExportDateFilter.defaults(earliestEntry: earliestEntry)
            didApplyInitialRange = true
        }
        .alert("Nothing to share", isPresented: $showEmptyAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(ExportDisclaimer.emptyShareMessage)
        }
        .alert("Could not build export", isPresented: $showRenderError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("PDF rendering failed. Try again.")
        }
        .overlay(alignment: .bottom) {
            if showCopyToast {
                Text("Summary copied")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppTheme.teal, in: Capsule())
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityLabel("Summary copied")
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showCopyToast)
    }

    // MARK: - Books

    private var booksCard: some View {
        ExportSolidCard {
            ExportEyebrow(title: "BOOKS", systemImage: "books.vertical")
            bookToggle(.dp, title: "DP", spoken: "D P")
            bookToggle(.anchorHandling, title: "Anchor handling", spoken: "Anchor handling", showRigMovesChip: true)
            bookToggle(.rov, title: "ROV", spoken: "R O V")
            bookToggle(.crane, title: "Crane", spoken: "Crane", isLast: true)
            Text(ExportDisclaimer.booksCaption)
                .font(.caption)
                .foregroundStyle(ExportTokens.secondary)
                .padding(.top, 10)
                .accessibilityLabel(ExportDisclaimer.booksCaption)
        }
    }

    private func bookToggle(
        _ book: LogBook,
        title: String,
        spoken: String,
        showRigMovesChip: Bool = false,
        isLast: Bool = false
    ) -> some View {
        let on = books.isOn(book)
        return Toggle(isOn: Binding(
            get: { books.isOn(book) },
            set: { books.set(book, on: $0) }
        )) {
            HStack(spacing: 11) {
                bookIcon(book)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(.bold))
                        .foregroundStyle(ExportTokens.text)
                    if showRigMovesChip {
                        AHTag(title: "Rig Moves")
                    }
                }
            }
        }
        .tint(AppTheme.teal)
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(ExportTokens.cardBorder)
                    .frame(height: 1)
            }
        }
        .accessibilityLabel(spoken)
        .accessibilityValue(on ? "On" : "Off")
        .accessibilityIdentifier("exportBook_\(book.rawValue)")
    }

    private func bookIcon(_ book: LogBook) -> some View {
        Group {
            if let name = book.systemImage {
                Image(systemName: name)
            } else {
                LogBookIcon(book: book, scale: 1.0)
            }
        }
        .font(.body.weight(.semibold))
        .foregroundStyle(AppTheme.teal)
        .frame(width: 36, height: 36)
        .background(Color(red: 0.157, green: 0.227, blue: 0.231), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .accessibilityHidden(true)
    }

    private var includedLine: some View {
        Text("Including: \(Text(books.includedSummary).foregroundStyle(AppTheme.teal).fontWeight(.bold))")
            .font(.caption)
            .foregroundStyle(ExportTokens.secondary)
            .padding(.horizontal, 4)
            .accessibilityLabel("Including \(books.includedSummary)")
    }

    // MARK: - Date range

    private var dateRangeCard: some View {
        ExportSolidCard {
            ExportEyebrow(title: "DATE RANGE", systemImage: "calendar")
            dateRow(label: "From", date: $dateFilter.from, isFrom: true)
            dateRow(label: "To", date: $dateFilter.to, isFrom: false)
            Text("Quick range")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ExportTokens.secondary)
                .padding(.top, 10)
            HStack(spacing: 7) {
                ForEach(ExportQuickRange.allCases) { range in
                    chip(range)
                }
            }
            Text("All time clears the date filter.")
                .font(.caption2)
                .foregroundStyle(ExportTokens.secondary)
                .padding(.top, 6)
        }
    }

    private func dateRow(label: String, date: Binding<Date?>, isFrom: Bool) -> some View {
        HStack {
            Text(label)
                .font(.body.weight(.medium))
                .foregroundStyle(ExportTokens.secondary)
            Spacer()
            if dateFilter.isAllTime {
                Text("All")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(ExportTokens.text)
                    .accessibilityLabel("\(label) All")
            } else if let value = date.wrappedValue {
                DatePicker(
                    label,
                    selection: Binding(
                        get: { value },
                        set: { newValue in
                            date.wrappedValue = Calendar.current.startOfDay(for: newValue)
                            dateFilter.quickRange = nil
                        }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
                .colorScheme(.dark)
                .accessibilityLabel(label)
                .accessibilityIdentifier(isFrom ? "exportFromDate" : "exportToDate")
            } else {
                Text("All")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(ExportTokens.text)
            }
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ExportTokens.cardBorder)
                .frame(height: 1)
        }
    }

    private func chip(_ range: ExportQuickRange) -> some View {
        let on = dateFilter.quickRange == range
        return Button {
            dateFilter = ExportDateFilter.applied(range, earliestEntry: earliestEntry)
        } label: {
            Text(range.title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(on ? Color(red: 0.051, green: 0.165, blue: 0.149) : ExportTokens.secondary)
                .background(on ? AppTheme.teal : ExportTokens.chipFill, in: Capsule())
                .overlay(Capsule().stroke(on ? AppTheme.teal : ExportTokens.fieldBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(range.title)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier("exportChip_\(range.rawValue)")
    }

    // MARK: - Preview

    private var previewCard: some View {
        ExportSolidCard {
            ExportEyebrow(title: "WHAT YOU GET", systemImage: "doc.text")
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("PDF")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(ExportTokens.text)
                Text("CSV also available")
                    .font(.caption)
                    .foregroundStyle(ExportTokens.secondary)
            }
            .padding(.bottom, 4)

            if !books.hasAnyBook {
                Text("Turn on at least one book to preview.")
                    .font(.subheadline)
                    .foregroundStyle(ExportTokens.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else if snapshot.isEmpty(for: books) {
                Text(ExportDisclaimer.emptyPreview)
                    .font(.subheadline)
                    .foregroundStyle(ExportTokens.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .accessibilityIdentifier("exportEmptyPreview")
            } else {
                ForEach(books.selectedBooks, id: \.self) { book in
                    HStack {
                        Text(book.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ExportTokens.text)
                        Spacer()
                        Text(snapshot.previewValue(for: book))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(ExportTokens.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.vertical, 8)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(ExportTokens.cardBorder)
                            .frame(height: 1)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(snapshot.previewLine(for: book))
                }
            }

            Text(ExportDisclaimer.previewFooter)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.teal)
                .padding(.top, 10)
                .accessibilityLabel(ExportDisclaimer.previewFooter)
        }
    }

    // MARK: - Disclaimer

    private var disclaimerCard: some View {
        ExportSolidCard(border: ExportTokens.goldBorder) {
            ExportEyebrow(title: "DISCLAIMER", systemImage: "exclamationmark.circle", tint: AppTheme.gold)
            Text(ExportDisclaimer.text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ExportTokens.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("exportDisclaimer")
                .accessibilityLabel(ExportDisclaimer.text)
        }
    }

    // MARK: - Actions

    /// Sticky action strip — solid navy (no glass). Nested above RootView’s
    /// floating tab-bar safeAreaInset so Share never covers the disclaimer.
    private var stickyActions: some View {
        VStack(spacing: 8) {
            Button(action: shareTapped) {
                Label("Share…", systemImage: "square.and.arrow.up")
                    .font(.body.weight(.heavy))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .foregroundStyle(books.canShare ? Color(red: 0.051, green: 0.165, blue: 0.149) : ExportTokens.secondary)
            .background(books.canShare ? AppTheme.teal : ExportTokens.disabledFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .disabled(!books.canShare)
            .accessibilityLabel("Share")
            .accessibilityHint(books.canShare ? "Shares a PDF and CSV of the selected books." : "Select at least one book to share.")
            .accessibilityIdentifier("exportShare")

            Button(action: printTapped) {
                Label("Print…", systemImage: "printer")
                    .font(.body.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(books.canShare ? AppTheme.teal : ExportTokens.secondary)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(books.canShare ? AppTheme.teal.opacity(0.45) : ExportTokens.cardBorder, lineWidth: 1)
            )
            .disabled(!books.canShare)
            .accessibilityLabel("Print")
            .accessibilityHint("AirPrint the PDF desk card.")
            .accessibilityIdentifier("exportPrint")

            Button(action: copyTapped) {
                Text("Copy summary")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .foregroundStyle(ExportTokens.secondary)
            .accessibilityLabel("Copy summary")
            .accessibilityIdentifier("exportCopySummary")

            Button(action: onImport) {
                Text(ImportCopy.importButton)
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.teal)
            .accessibilityLabel("Import")
            .accessibilityHint("Opens Import for an export PDF or CSV.")
            .accessibilityIdentifier("exportImport")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        // Nested safeAreaInset does not sit above RootView’s floating tab bar;
        // reserve matching clearance so Share / Print / Copy stay fully readable.
        .padding(.bottom, 78)
        .background(AppTheme.background)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Actions impl

    private func shareTapped() {
        guard books.canShare else { return }
        if snapshot.isEmpty(for: books) {
            showEmptyAlert = true
            return
        }
        do {
            let artifacts = try ExportDocumentBuilder.makeArtifacts(
                snapshot: snapshot, books: books, filter: dateFilter,
                dp: dpEntries, moves: moves, rov: rovEntries, crane: craneEntries
            )
            guard let presenter = ExportDocumentBuilder.topViewController() else { return }
            ExportDocumentBuilder.presentShare(
                pdfURL: artifacts.pdfURL, csvURL: artifacts.csvURL, from: presenter
            )
        } catch {
            showRenderError = true
        }
    }

    private func printTapped() {
        guard books.canShare else { return }
        if snapshot.isEmpty(for: books) {
            showEmptyAlert = true
            return
        }
        do {
            let artifacts = try ExportDocumentBuilder.makeArtifacts(
                snapshot: snapshot, books: books, filter: dateFilter,
                dp: dpEntries, moves: moves, rov: rovEntries, crane: craneEntries
            )
            guard let presenter = ExportDocumentBuilder.topViewController() else { return }
            ExportDocumentBuilder.presentPrint(pdfURL: artifacts.pdfURL, from: presenter)
        } catch {
            showRenderError = true
        }
    }

    private func copyTapped() {
        let text = snapshot.copySummary(for: books, dateFilter: dateFilter)
        UIPasteboard.general.string = text
        showCopyToast = true
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            showCopyToast = false
        }
    }
}

// MARK: - Solid navy tokens (Pixel sheet — no glass)

private enum ExportTokens {
    static let card = Color(red: 0.106, green: 0.137, blue: 0.153)       // #1B2327
    static let cardBorder = Color(red: 0.227, green: 0.278, blue: 0.302) // #3A474D
    static let text = Color(red: 0.933, green: 0.953, blue: 0.969)       // #EEF3F7
    static let secondary = Color(red: 0.706, green: 0.745, blue: 0.769)  // #B4BEC4
    static let fieldBorder = Color(red: 0.455, green: 0.514, blue: 0.537)
    static let chipFill = Color(red: 0.125, green: 0.157, blue: 0.173)
    static let disabledFill = Color(red: 0.227, green: 0.267, blue: 0.282)
    static let goldBorder = Color(red: 0.851, green: 0.678, blue: 0.322).opacity(0.35)
}

private struct ExportSolidCard<Content: View>: View {
    var border: Color = ExportTokens.cardBorder
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ExportTokens.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
    }
}

private struct ExportEyebrow: View {
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

#Preview {
    NavigationStack {
        ExportView()
    }
    .modelContainer(for: [DPEntry.self, RigMove.self, ROVEntry.self, CraneEntry.self], inMemory: true)
    .preferredColorScheme(.dark)
}
