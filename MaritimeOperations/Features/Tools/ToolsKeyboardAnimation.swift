import SwiftUI
import UIKit

/// Keyboard notification timing. Duration and curve come from the system notification.
/// Reduce Motion snaps instead of animating. No point-size constant lives here.
enum ToolsKeyboardAnimation {
    static func duration(from notification: Notification) -> TimeInterval {
        number(notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey])?.doubleValue ?? 0
    }

    static func keyboardFrame(from notification: Notification) -> CGRect? {
        (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
    }

    static func curveRaw(from notification: Notification) -> UInt {
        number(notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey])?.uintValue
            ?? UInt(UIView.AnimationCurve.easeInOut.rawValue)
    }

    /// `UIView.AnimationOptions` stores the curve in the same bits the keyboard notification publishes.
    /// The shift is `curveLinear`'s trailing zeros, not a point size.
    static func uiOptions(curveRaw: UInt) -> UIView.AnimationOptions {
        let shift = UIView.AnimationOptions.curveLinear.rawValue.trailingZeroBitCount
        return UIView.AnimationOptions(rawValue: curveRaw << shift)
    }

    static func uiOptions(from notification: Notification) -> UIView.AnimationOptions {
        uiOptions(curveRaw: curveRaw(from: notification))
    }

    /// Nil when Reduce Motion is on, or when the keyboard did not publish a duration.
    static func swiftUI(from notification: Notification) -> Animation? {
        guard !UIAccessibility.isReduceMotionEnabled else { return nil }
        let duration = duration(from: notification)
        guard duration > 0 else { return nil }
        switch UIView.AnimationCurve(rawValue: Int(curveRaw(from: notification))) {
        case .easeIn:
            return .easeIn(duration: duration)
        case .easeOut:
            return .easeOut(duration: duration)
        case .linear:
            return .linear(duration: duration)
        case .easeInOut:
            return .easeInOut(duration: duration)
        default:
            return .easeInOut(duration: duration)
        }
    }

    /// Screen-coordinate keyboard frame converted into `window`. Hidden when it does not overlap the window.
    static func overlaps(_ frame: CGRect, window: UIWindow) -> Bool {
        guard frame.height > 1, frame.width > 1 else { return false }
        let inWindow = window.convert(frame, from: window.screen.coordinateSpace)
        return inWindow.minY < window.bounds.maxY && inWindow.maxY > window.bounds.minY
    }

    static func sheetIsPresented(in window: UIWindow?) -> Bool {
        window?.rootViewController?.presentedViewController != nil
    }

    private static func number(_ value: Any?) -> NSNumber? {
        value as? NSNumber
    }
}
