import CoreGraphics
import SwiftUI
import Testing
import UIKit
@testable import MaritimeOperations

/// QA pass rules for Tools keyboard chrome. Geometry only — no simulator.
@MainActor
struct ToolsKeyboardPassTests {
    @Test func clearanceIsTheNamed16PointGap() {
        #expect(ToolsKeyboardPass.aboveRaisedBar == 16)
    }

    @Test func raisedBarIsTheHighestCover() {
        #expect(ToolsKeyboardPass.raisedBarTop([800, 640, 700]) == 640)
        #expect(ToolsKeyboardPass.raisedBarTop([]) == nil)
    }

    @Test func inputBoxClearsWhenItsBottomIs16PointsAboveTheBar() {
        #expect(ToolsKeyboardPass.inputBoxClearsRaisedBar(boxMaxY: 624, raisedBarTop: 640))
        #expect(ToolsKeyboardPass.inputBoxClearsRaisedBar(boxMaxY: 600, raisedBarTop: 640))
        #expect(!ToolsKeyboardPass.inputBoxClearsRaisedBar(boxMaxY: 625, raisedBarTop: 640))
        #expect(!ToolsKeyboardPass.inputBoxClearsRaisedBar(boxMaxY: 640, raisedBarTop: 640))
    }

    @Test func nextRowIsTheNearestInputBelowTheFocusedBox() {
        let focused = CGRect(x: 0, y: 100, width: 300, height: 48)
        let beside = CGRect(x: 160, y: 100, width: 140, height: 48)
        let next = CGRect(x: 0, y: 170, width: 300, height: 48)
        let later = CGRect(x: 0, y: 240, width: 300, height: 60)
        #expect(ToolsKeyboardPass.nextRow(below: focused, rows: [beside, later, next, focused]) == next)
        #expect(ToolsKeyboardPass.clearanceEdge(focused: focused, rows: [beside, later, next]) == next.maxY)
    }

    @Test func lastFieldKeepsTheFocusedBoxAsTheClearanceEdge() {
        let focused = CGRect(x: 0, y: 400, width: 300, height: 48)
        let above = CGRect(x: 0, y: 300, width: 300, height: 48)
        let empty = CGRect.zero
        #expect(ToolsKeyboardPass.nextRow(below: focused, rows: [above, empty, focused]) == nil)
        #expect(ToolsKeyboardPass.clearanceEdge(focused: focused, rows: [above, empty]) == focused.maxY)
    }

    @Test func aClearFocusedFieldStillScrollsWhenTheNextRowIsUnderTheBar() {
        let focused = CGRect(x: 0, y: 520, width: 300, height: 48)
        let next = CGRect(x: 0, y: 630, width: 300, height: 70)
        let edge = ToolsKeyboardPass.clearanceEdge(focused: focused, rows: [next])
        #expect(edge == next.maxY)
        #expect(ToolsKeyboardPass.overflow(boxMaxY: focused.maxY, raisedBarTop: 640) < 0)
        #expect(ToolsKeyboardPass.overflow(boxMaxY: edge, raisedBarTop: 640) == 76)
    }

    @Test func overflowIsHowFarTheBoxStillSitsBelowThe16PointLine() {
        #expect(ToolsKeyboardPass.overflow(boxMaxY: 624, raisedBarTop: 640) == 0)
        #expect(ToolsKeyboardPass.overflow(boxMaxY: 700, raisedBarTop: 640) == 76)
        #expect(ToolsKeyboardPass.overflow(boxMaxY: 600, raisedBarTop: 640) == -24)
        #expect(ToolsKeyboardPass.contentOffsetY(current: 40, overflow: 76) == 116)
        #expect(ToolsKeyboardPass.contentOffsetY(current: 40, overflow: 0) == 40)
        #expect(ToolsKeyboardPass.contentOffsetY(current: 40, overflow: -8) == 40)
    }

    @Test func offsetStaysInsideTheScrollRange() {
        #expect(ToolsKeyboardPass.clampedOffset(50, lower: 0, upper: 80) == 50)
        #expect(ToolsKeyboardPass.clampedOffset(-4, lower: 0, upper: 80) == 0)
        #expect(ToolsKeyboardPass.clampedOffset(90, lower: 0, upper: 80) == 80)
        #expect(ToolsKeyboardPass.clampedOffset(10, lower: 4, upper: 0) == 4)
    }

    @Test func doneCoversAUnitOnlyWhenTheFramesOverlap() {
        let unit = CGRect(x: 300, y: 600, width: 20, height: 18)
        let done = CGRect(x: 310, y: 610, width: 64, height: 36)
        let clear = CGRect(x: 310, y: 640, width: 64, height: 36)
        let empty = CGRect.zero
        #expect(ToolsKeyboardPass.doneCoversUnit(unit: unit, done: done))
        #expect(!ToolsKeyboardPass.doneCoversUnit(unit: unit, done: clear))
        #expect(!ToolsKeyboardPass.doneCoversUnit(unit: unit, done: empty))
    }

    @Test func tabBarHidesOnlyForTheToolsKeyboardAndReturnsWithTheSameTab() {
        #expect(!ToolsKeyboardPass.showsFloatingTabBar(onToolsTab: true, keyboardVisible: true, sheetPresented: false))
        #expect(ToolsKeyboardPass.showsFloatingTabBar(onToolsTab: true, keyboardVisible: false, sheetPresented: false))
        #expect(ToolsKeyboardPass.showsFloatingTabBar(onToolsTab: false, keyboardVisible: true, sheetPresented: false))
        #expect(ToolsKeyboardPass.showsFloatingTabBar(onToolsTab: true, keyboardVisible: true, sheetPresented: true))
        #expect(ToolsKeyboardPass.preservesSelection(AppTab.tools.rawValue, afterKeyboardDismissed: AppTab.tools.rawValue))
        #expect(!ToolsKeyboardPass.preservesSelection(AppTab.tools.rawValue, afterKeyboardDismissed: AppTab.log.rawValue))
    }

    @Test func keyboardCurveOptionsUseTheSystemCurveBits() {
        let easeIn = ToolsKeyboardAnimation.uiOptions(curveRaw: UInt(UIView.AnimationCurve.easeIn.rawValue))
        let linear = ToolsKeyboardAnimation.uiOptions(curveRaw: UInt(UIView.AnimationCurve.linear.rawValue))
        #expect(easeIn.contains(.curveEaseIn))
        #expect(linear.contains(.curveLinear))
    }
}
