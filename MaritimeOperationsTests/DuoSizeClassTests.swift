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
}
