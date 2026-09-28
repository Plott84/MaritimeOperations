import SwiftUI
import UIKit

extension View {
    /// Runs `action` when a tap on this view ends (the moment a menu opens), without taking the
    /// touch away from the view. Needed for menu Pickers: they give SwiftUI no tap or "did open" callback.
    func onTapPassthrough(perform action: @escaping () -> Void) -> some View {
        background(TapPassthroughObserver(action: action))
    }
}

/// Invisible anchor view. It puts a passive recognizer on its window that reports a touch that
/// starts and ends inside the anchor's bounds, then fails, so the touch carries on as normal.
/// It fires on touch-up, not touch-down: hiding the keyboard on touch-down moves the layout under
/// the finger and the menu then doesn't open.
private struct TapPassthroughObserver: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> AnchorView {
        let view = AnchorView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.action = action
        return view
    }

    func updateUIView(_ uiView: AnchorView, context: Context) {
        uiView.action = action
    }

    final class AnchorView: UIView, UIGestureRecognizerDelegate {
        var action: () -> Void = {}
        private lazy var recognizer: PassiveTouchRecognizer = {
            let recognizer = PassiveTouchRecognizer()
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            recognizer.delegate = self
            recognizer.onTap = { [weak self] began, ended in
                guard let self, self.window != nil, !self.isHidden else { return }
                guard self.bounds.contains(began), self.bounds.contains(ended.location(in: self)) else { return }
                DispatchQueue.main.async { self.action() }
            }
            return recognizer
        }()

        override func willMove(toWindow newWindow: UIWindow?) {
            super.willMove(toWindow: newWindow)
            recognizer.view?.removeGestureRecognizer(recognizer)
            newWindow?.addGestureRecognizer(recognizer)
        }

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }

    final class PassiveTouchRecognizer: UIGestureRecognizer {
        /// Touch start point in the anchor view, and the ending touch.
        var onTap: (CGPoint, UITouch) -> Void = { _, _ in }
        private var startInView: CGPoint?
        private weak var trackedTouch: UITouch?

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            guard trackedTouch == nil, touches.count == 1, let touch = touches.first,
                  let anchor = delegate as? UIView else {
                state = .failed
                return
            }
            trackedTouch = touch
            startInView = touch.location(in: anchor)
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
            if let touch = trackedTouch, touches.contains(touch), let start = startInView {
                onTap(start, touch)
            }
            state = .failed
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
            state = .failed
        }

        override func reset() {
            super.reset()
            trackedTouch = nil
            startInView = nil
        }
    }
}
