import CoreGraphics

/// QA pass rules for the Tools keyboard. Large and accessibility extra large.
///
/// 1. With the keyboard up, the whole input box sits at least `aboveRaisedBar`
///    (16 pt) above the raised bar. When another input row is below the focused
///    box, that next row’s bottom is the edge that must clear the bar, so Done
///    does not cover it. The last field has no next row.
/// 2. The Done button never covers a unit label.
/// 3. The floating tab bar hides while the keyboard is up and returns after Done
///    on the same selected tab. Keyboard chrome does not reset tab selection
///    or navigation.
enum ToolsKeyboardPass {
    /// Clear space between a focused input box and the raised bar or keyboard top.
    static let aboveRaisedBar: CGFloat = 16

    /// Highest cover: the smaller y is the one the box must clear.
    static func raisedBarTop(_ candidates: [CGFloat]) -> CGFloat? {
        candidates.min()
    }

    static func inputBoxClearsRaisedBar(boxMaxY: CGFloat, raisedBarTop: CGFloat) -> Bool {
        boxMaxY <= raisedBarTop - aboveRaisedBar
    }

    /// Nearest input row whose top is at or below the focused box’s bottom.
    /// A box beside the focused field shares its vertical span and is not next.
    /// Nil when this field is the last one.
    static func nextRow(below focused: CGRect, rows: [CGRect]) -> CGRect? {
        let below = rows.filter { row in
            row.width > 0 && row.height > 0 && row.minY >= focused.maxY
        }
        return below.min { $0.minY < $1.minY }
    }

    /// Bottom that must sit `aboveRaisedBar` above the keyboard toolbar.
    /// The next row’s bottom when there is one; otherwise the focused box.
    static func clearanceEdge(focused: CGRect, rows: [CGRect]) -> CGFloat {
        guard let next = nextRow(below: focused, rows: rows) else { return focused.maxY }
        return max(focused.maxY, next.maxY)
    }

    /// How far the box still sits below the 16 pt line. Zero or less means it already clears.
    static func overflow(boxMaxY: CGFloat, raisedBarTop: CGFloat) -> CGFloat {
        boxMaxY - (raisedBarTop - aboveRaisedBar)
    }

    static func contentOffsetY(current: CGFloat, overflow: CGFloat) -> CGFloat {
        guard overflow > 0 else { return current }
        return current + overflow
    }

    static func clampedOffset(_ target: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        let cap = max(lower, upper)
        return min(max(target, lower), cap)
    }

    static func doneCoversUnit(unit: CGRect, done: CGRect) -> Bool {
        guard unit.width > 0, unit.height > 0, done.width > 0, done.height > 0 else { return false }
        return unit.intersects(done)
    }

    /// Sheets and other tabs keep the bar. Tools hides it only while the keyboard is up.
    static func showsFloatingTabBar(onToolsTab: Bool, keyboardVisible: Bool, sheetPresented: Bool) -> Bool {
        if sheetPresented || !keyboardVisible || !onToolsTab {
            return true
        }
        return false
    }

    static func preservesSelection<Selection: Equatable>(_ selection: Selection, afterKeyboardDismissed selectionAfter: Selection) -> Bool {
        selection == selectionAfter
    }
}
