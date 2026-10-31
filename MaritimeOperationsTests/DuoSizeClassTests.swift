import Foundation
import SwiftUI
import Testing
@testable import MaritimeOperations

/// Duo size-class shell. Compact stays Soft C. Regular width splits Home and Tools.
@MainActor
struct DuoSizeClassTests {
    @Test func compactWidthStaysOneColumn() {
        #expect(!DuoSizeClass.usesSplit(horizontal: .compact, vertical: .regular))
        #expect(!DuoSizeClass.usesSplit(horizontal: .compact, vertical: .compact))
        #expect(!DuoSizeClass.usesSplit(horizontal: .unspecified, vertical: .regular))
        #expect(!DuoSizeClass.usesSplit(horizontal: .unspecified, vertical: .unspecified))
    }

    @Test func regularWidthSplitsRegardlessOfVerticalClass() {
        #expect(DuoSizeClass.usesSplit(horizontal: .regular, vertical: .regular))
        #expect(DuoSizeClass.usesSplit(horizontal: .regular, vertical: .compact))
        #expect(DuoSizeClass.usesSplit(horizontal: .regular, vertical: .unspecified))
    }

    @Test func compactHomeIsTheSoftCColumn() {
        let plain = DuoHomeLayout.columns(split: false, hasSecondary: false)
        #expect(plain.left == [.onMainChip, .primaryHero, .latestActivity])
        #expect(plain.right.isEmpty)

        let withSecondary = DuoHomeLayout.columns(split: false, hasSecondary: true)
        #expect(withSecondary.left == [.onMainChip, .primaryHero, .secondaryCard, .latestActivity])
        #expect(withSecondary.right.isEmpty)
        #expect(!withSecondary.left.contains(.yourBooks))
    }

    @Test func regularHomeSplitsTimerFromBooksAndActivity() {
        let plain = DuoHomeLayout.columns(split: true, hasSecondary: false)
        #expect(plain.left == [.primaryHero])
        #expect(plain.right == [.yourBooks, .latestActivity])
        #expect(!plain.left.contains(.yourBooks))
        #expect(!plain.right.contains(.primaryHero))

        let withSecondary = DuoHomeLayout.columns(split: true, hasSecondary: true)
        #expect(withSecondary.left == [.primaryHero])
        #expect(withSecondary.right == [.yourBooks, .secondaryCard, .latestActivity])
        #expect(!withSecondary.left.contains(.onMainChip))
    }

    @Test func yourBooksListsPrimaryThenSecondary() {
        #expect(DuoHomeLayout.onMainBooks(HomeBooks(primary: .dp)) == [.dp])
        #expect(DuoHomeLayout.onMainBooks(HomeBooks(primary: .dp, secondary: .crane)) == [.dp, .crane])
        #expect(DuoHomeLayout.onMainBooks(HomeBooks(primary: .crane, secondary: .dp)) == [.crane, .dp])
        #expect(DuoHomeLayout.onMainBooks(HomeBooks(primary: .dp, secondary: .dp)) == [.dp])
    }

    @Test func dpHeroKeepsStartDPAndDropsTheSecondAction() {
        #expect(HomeBook.dp.hero.primary == "Start DP")
        #expect(HomeBook.dp.hero.secondary == nil)
        #expect(HomeBook.dp.hero.caption == "Start when the vessel goes on DP. Stop saves the session to Entries.")
        #expect(HomeBook.dp.hero.eyebrow == "DP TIMER")
    }

    @Test func softCTabsStayMainEntriesToolsExport() {
        #expect(AppTab.allCases.map(\.title) == ["Main", "Entries", "Tools", "Export"])
    }

    @Test func regularToolsDefaultToWinchAndNameTheEmptyDetail() {
        #expect(DeckTool.splitDefault == .winch)
        #expect(DuoToolsColumn.defaultToolID == "winch")
        #expect(DuoToolsColumn.emptyDetail == "Select a tool")
        #expect(DuoToolsColumn.sidebarMin == 300)
        #expect(DuoToolsColumn.sidebarIdeal == 320)
        #expect(DuoToolsColumn.sidebarMax == 340)
        #expect(DuoToolsColumn.sidebarMin <= DuoToolsColumn.sidebarIdeal)
        #expect(DuoToolsColumn.sidebarIdeal <= DuoToolsColumn.sidebarMax)
    }

    @Test func slingingHitchKeepsIconLabels() {
        #expect(RiggingMath.Hitch.allCases.map(\.rawValue) == ["Straight", "Choke", "Basket"])
    }

    @Test func tabTitlesNeverSayLog() {
        #expect(AppTab.allCases.map(\.title) == ["Main", "Entries", "Tools", "Export"])
        #expect(!AppTab.allCases.map(\.title).contains("Log"))
        #expect(AppTab.log.title == "Entries")
    }

    @Test func regularEntriesDefaultsToDPAndNamesTheEmptyDetail() {
        let order = LogBook.entriesListOrder
        #expect(DuoEntriesColumn.defaultSelection(available: order, primary: .crane) == .dp)
        #expect(DuoEntriesColumn.defaultSelection(available: order, primary: .dp) == .dp)
        #expect(DuoEntriesColumn.defaultSelection(available: [.crane, .rov], primary: .rov) == .rov)
        #expect(DuoEntriesColumn.defaultSelection(available: [.anchorHandling, .crane], primary: .dp) == .anchorHandling)
        #expect(DuoEntriesColumn.defaultSelection(available: [], primary: .dp) == nil)
        #expect(DuoEntriesColumn.emptyDetail == "Select a book")
        #expect(DuoEntriesColumn.sidebarMin == DuoSidebar.min)
        #expect(DuoEntriesColumn.sidebarIdeal == DuoSidebar.ideal)
        #expect(DuoEntriesColumn.sidebarMax == DuoSidebar.max)
        #expect(DuoSidebar.min == 300)
        #expect(DuoSidebar.max == 340)
    }

    @Test func softBEmptyBookCTAsStay() {
        #expect(BookEmptyCopy.of(.dp).cta == "Start DP")
        #expect(BookEmptyCopy.of(.crane).cta == "New lift")
        #expect(BookEmptyCopy.of(.anchorHandling).cta == "New rig move")
        #expect(BookEmptyCopy.of(.rov).cta == "New ROV entry")
        #expect(HomeBooks.entriesFootnote == "Star up to two books for Main (HB-13). Export lives on the Export tab.")
    }

    @Test func compactExportIsOneColumnAndRegularSplitsThePreview() {
        let compact = DuoExportLayout.columns(split: false)
        #expect(compact.left == [.books, .dateRange, .preview, .disclaimer, .share])
        #expect(compact.right.isEmpty)

        let split = DuoExportLayout.columns(split: true)
        #expect(split.left == [.books, .dateRange])
        #expect(split.right == [.preview, .disclaimer, .share])
        #expect(!split.left.contains(.share))
        #expect(!split.right.contains(.books))
    }

    @Test func exportDisclaimerAndShareHold() {
        #expect(
            ExportDisclaimer.text
                == "Personal aid only. This export is not an official IMCA DP Logbook record, and it is not a sign-off or certificate."
        )
        #expect(ExportDisclaimer.booksCaption == "ROV and Crane hours are never added to DP totals.")
        #expect(ExportDisclaimer.previewFooter == "DP hours are only from the DP book.")
        var none = ExportBookSelection()
        none.set(.dp, on: false)
        none.set(.anchorHandling, on: false)
        none.set(.rov, on: false)
        none.set(.crane, on: false)
        #expect(!none.canShare)
        #expect(ExportBookSelection().canShare)
        #expect(DPHoursScope.books == Set([LogBook.dp]))
        #expect(DPHoursScope.counts(.dp))
        #expect(!DPHoursScope.counts(.rov))
        #expect(!DPHoursScope.counts(.crane))
        #expect(!DPHoursScope.counts(.anchorHandling))
    }
}
