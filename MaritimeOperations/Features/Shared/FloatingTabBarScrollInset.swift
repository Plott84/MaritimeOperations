import SwiftUI
import UIKit

/// Height of the floating tab bar, measured from its layout (not a constant).
struct FloatingTabBarHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Forwards the floating tab bar’s height into each tab’s navigation controller.
///
/// `RootView` draws the bar with `.safeAreaInset`, but that inset does not become
/// scrollable margin inside a `NavigationStack` or `NavigationSplitView`. Scroll
/// content therefore rests on the home-indicator safe area and the last row stays
/// under the bar. On iPhone 17 the Depth value stuck at y=788 (874 − 34 − 52),
/// 13 pt below the glass at the default size and 10 pt below it at accessibility
/// extra large.
///
/// `additionalSafeAreaInsets` is the margin UIKit already adds on top of the
/// keyboard, so a focused field clears the raised bar as well as the keys.
/// Sheets are presented, not children of this host, and are left alone.
struct FloatingTabBarScrollInset: UIViewControllerRepresentable {
    var height: CGFloat

    func makeUIViewController(context: Context) -> Controller {
        let controller = Controller()
        controller.view.isUserInteractionEnabled = false
        controller.view.backgroundColor = .clear
        controller.view.accessibilityElementsHidden = true
        return controller
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.height = height
        controller.apply()
    }

    final class Controller: UIViewController {
        var height: CGFloat = 0

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            apply()
        }

        func apply() {
            guard height > 0, let root = view.window?.rootViewController else { return }
            for navigation in Self.navigationControllers(under: root) {
                let inset = navigation.additionalSafeAreaInsets
                guard abs(inset.bottom - height) > 0.5 else { continue }
                navigation.additionalSafeAreaInsets.bottom = height
            }
        }

        private static func navigationControllers(under viewController: UIViewController) -> [UINavigationController] {
            var found: [UINavigationController] = []
            if let navigation = viewController as? UINavigationController {
                found.append(navigation)
            }
            for child in viewController.children {
                found.append(contentsOf: navigationControllers(under: child))
            }
            return found
        }
    }
}
