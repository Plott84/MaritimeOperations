import SwiftUI
import UIKit

/// Reports keyboard visibility to the root tab bar. Sheets are reported separately so a
/// sheet keyboard does not hide the bar or change the sheet's layout.
struct ToolsKeyboardVisibilityAnchor: UIViewRepresentable {
    var onChange: (_ keyboardVisible: Bool, _ sheetPresented: Bool, _ animation: Animation?) -> Void

    func makeUIView(context: Context) -> ToolsKeyboardVisibilityView {
        let view = ToolsKeyboardVisibilityView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.isAccessibilityElement = false
        view.onChange = onChange
        return view
    }

    func updateUIView(_ uiView: ToolsKeyboardVisibilityView, context: Context) {
        uiView.onChange = onChange
    }
}

final class ToolsKeyboardVisibilityView: UIView {
    var onChange: ((Bool, Bool, Animation?) -> Void)?
    private var observing = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        startObservingIfNeeded()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func startObservingIfNeeded() {
        guard !observing else { return }
        observing = true
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        center.addObserver(self, selector: #selector(keyboardWillChange(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        center.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        deliver(notification, forceVisible: true)
    }

    @objc private func keyboardWillChange(_ notification: Notification) {
        guard let frame = ToolsKeyboardAnimation.keyboardFrame(from: notification), let window else {
            deliver(notification, forceVisible: false)
            return
        }
        deliver(notification, forceVisible: ToolsKeyboardAnimation.overlaps(frame, window: window))
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        deliver(notification, forceVisible: false)
    }

    private func deliver(_ notification: Notification, forceVisible: Bool) {
        let sheet = ToolsKeyboardAnimation.sheetIsPresented(in: window)
        onChange?(forceVisible, sheet, ToolsKeyboardAnimation.swiftUI(from: notification))
    }
}
