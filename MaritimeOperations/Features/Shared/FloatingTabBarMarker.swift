import SwiftUI
import UIKit

/// Layout frame of the floating tab bar, including its padding. Not an accessibility
/// container: a container id would be copied onto `tab_*` and hide those buttons.
struct FloatingTabBarMarker: UIViewRepresentable {
    func makeUIView(context: Context) -> FloatingTabBarMarkerView {
        let view = FloatingTabBarMarkerView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ uiView: FloatingTabBarMarkerView, context: Context) {}

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: FloatingTabBarMarkerView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }
}

/// Found by class from the input-box scroller. Opacity on the bar does not remove this frame.
final class FloatingTabBarMarkerView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) {
        nil
    }
}
