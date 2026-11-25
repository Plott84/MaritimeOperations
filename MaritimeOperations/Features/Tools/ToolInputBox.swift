import SwiftUI
import UIKit

extension View {
    /// Marks the rounded input row — text, padding, and unit — as the box that must
    /// clear the raised bar. The text field alone is not the box.
    func toolInputBox() -> some View {
        background {
            ToolInputBoxAnchor()
        }
    }
}

private struct ToolInputBoxAnchor: UIViewRepresentable {
    func makeUIView(context: Context) -> ToolInputBoxAnchorView {
        let view = ToolInputBoxAnchorView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ uiView: ToolInputBoxAnchorView, context: Context) {}

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: ToolInputBoxAnchorView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }
}

/// Scrolls the enclosing Tools scroll view so this box sits `ToolsKeyboardPass.aboveRaisedBar`
/// above the raised bar (tab-bar marker, keyboard top, and the scroll view's visible bottom).
final class ToolInputBoxAnchorView: UIView {
    private var observing = false
    private var keyboardVisible = false
    private var screenKeyboardFrame: CGRect?
    private var adjusting = false
    private var queued = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        startObservingIfNeeded()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !adjusting else { return }
        adjusting = true
        alignToRaisedBar()
        adjusting = false
    }

    private func startObservingIfNeeded() {
        guard !observing else { return }
        observing = true
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        center.addObserver(self, selector: #selector(keyboardWillChange(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        center.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        center.addObserver(self, selector: #selector(textDidBegin), name: UITextField.textDidBeginEditingNotification, object: nil)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        noteKeyboard(notification, visible: true)
    }

    @objc private func keyboardWillChange(_ notification: Notification) {
        guard let frame = ToolsKeyboardAnimation.keyboardFrame(from: notification), let window else {
            noteKeyboard(notification, visible: false)
            return
        }
        noteKeyboard(notification, visible: ToolsKeyboardAnimation.overlaps(frame, window: window))
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        noteKeyboard(notification, visible: false)
    }

    @objc private func textDidBegin() {
        guard keyboardVisible else { return }
        setNeedsLayout()
    }

    private func noteKeyboard(_ notification: Notification, visible: Bool) {
        keyboardVisible = visible
        screenKeyboardFrame = visible ? ToolsKeyboardAnimation.keyboardFrame(from: notification) : nil
        setNeedsLayout()
    }

    /// Window y is stable: scrolling changes the box, not the keyboard. Content y would
    /// chase `contentOffset` and keep scrolling.
    private func alignToRaisedBar() {
        guard keyboardVisible, bounds.width > 1, bounds.height > 1, let window else { return }
        guard containsFocusedField(in: window), let scroll = enclosingScrollView() else { return }
        guard let raised = raisedBarTop(in: window, scroll: scroll) else { return }
        let boxMaxY = convert(bounds, to: window).maxY
        let overflow = ToolsKeyboardPass.overflow(boxMaxY: boxMaxY, raisedBarTop: raised)
        let target = ToolsKeyboardPass.contentOffsetY(current: scroll.contentOffset.y, overflow: overflow)
        let lower = -scroll.adjustedContentInset.top
        let rawUpper = scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom
        let clamped = ToolsKeyboardPass.clampedOffset(target, lower: lower, upper: rawUpper)
        let before = scroll.contentOffset.y
        guard clamped != before else { return }
        scroll.contentOffset.y = clamped
        // Ignored sets must not schedule another pass. A set that lands gets one follow-up
        // after this layout pass, when the box frame has moved.
        guard scroll.contentOffset.y != before, !queued else { return }
        queued = true
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.queued = false
                guard !self.adjusting else { return }
                self.alignToRaisedBar()
            }
        }
    }

    private func containsFocusedField(in window: UIWindow) -> Bool {
        guard let focused = window.firstResponderDescendant() else { return false }
        let box = convert(bounds, to: window)
        let field = focused.convert(focused.bounds, to: window)
        return box.intersects(field)
    }

    private func enclosingScrollView() -> UIScrollView? {
        var current: UIView? = superview
        while let view = current {
            if let scroll = view as? UIScrollView { return scroll }
            current = view.superview
        }
        return nil
    }

    private func raisedBarTop(in window: UIWindow, scroll: UIScrollView) -> CGFloat? {
        var candidates: [CGFloat] = []
        let localBottom = scroll.bounds.maxY - scroll.adjustedContentInset.bottom
        let visibleBottom = scroll.convert(CGPoint(x: 0, y: localBottom), to: window).y
        if visibleBottom > 0 {
            candidates.append(visibleBottom)
        }
        if let frame = screenKeyboardFrame, ToolsKeyboardAnimation.overlaps(frame, window: window) {
            let inWindow = window.convert(frame, from: window.screen.coordinateSpace)
            candidates.append(inWindow.minY)
        }
        if let marker = window.firstDescendant(of: FloatingTabBarMarkerView.self) {
            let frame = marker.convert(marker.bounds, to: window)
            if frame.height > 1, frame.minY > 0 {
                candidates.append(frame.minY)
            }
        }
        return ToolsKeyboardPass.raisedBarTop(candidates)
    }
}

private extension UIView {
    func firstResponderDescendant() -> UIView? {
        if isFirstResponder { return self }
        for subview in subviews {
            if let found = subview.firstResponderDescendant() { return found }
        }
        return nil
    }

    func firstDescendant<T: UIView>(of type: T.Type) -> T? {
        if let match = self as? T { return match }
        for subview in subviews {
            if let found = subview.firstDescendant(of: type) { return found }
        }
        return nil
    }
}
