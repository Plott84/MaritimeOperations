import SwiftUI

/// Measured height of the floating tab bar. Not a device constant.
struct FloatingTabBarHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct FloatingTabBarHeightEnvironmentKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private struct ToolsKeyboardClearanceActiveKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var floatingTabBarHeight: CGFloat {
        get { self[FloatingTabBarHeightEnvironmentKey.self] }
        set { self[FloatingTabBarHeightEnvironmentKey.self] = newValue }
    }

    /// True only while a Tools screen — not a sheet, not another tab — has the keyboard up.
    var toolsKeyboardClearanceActive: Bool {
        get { self[ToolsKeyboardClearanceActiveKey.self] }
        set { self[ToolsKeyboardClearanceActiveKey.self] = newValue }
    }
}

extension View {
    /// Lets this scroll view move its last row above the floating tab bar.
    ///
    /// The root `safeAreaInset` is not scroll margin inside a navigation stack.
    /// Writing `additionalSafeAreaInsets` on navigation controllers also left
    /// the Depth value at y=788 (Mac, 0b08089, both content sizes). This margin
    /// is applied on the scroll view and is the bar’s measured height, added
    /// on top of the safe area the keyboard already grows.
    ///
    /// While the Tools keyboard is up, the same margin also adds
    /// `ToolsKeyboardPass.aboveRaisedBar` so the focused box can scroll clear.
    /// Export’s sticky strip does not use this margin; its 78 pt pad stays.
    func scrollsAboveFloatingTabBar() -> some View {
        modifier(FloatingTabBarScrollMargin())
    }
}

private struct FloatingTabBarScrollMargin: ViewModifier {
    @Environment(\.floatingTabBarHeight) private var barHeight
    @Environment(\.toolsKeyboardClearanceActive) private var keyboardClearance

    func body(content: Content) -> some View {
        let extra = keyboardClearance ? ToolsKeyboardPass.aboveRaisedBar : 0
        content.contentMargins(.bottom, barHeight + extra, for: .scrollContent)
    }
}
