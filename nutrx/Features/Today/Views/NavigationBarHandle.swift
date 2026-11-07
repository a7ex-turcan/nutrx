import SwiftUI
import UIKit

/// A handle on the navigation bar Today sits under, for what SwiftUI can't ask of it: opening the large title again
/// after a text-size change left the page at its top under a collapsed bar (#198).
@MainActor
final class NavigationBarHandle {
    fileprivate weak var controller: UIViewController?

    /// The bar takes its full height again, the large title with it.
    func expandLargeTitle() {
        controller?.navigationController?.navigationBar.sizeToFit()
    }
}

extension View {
    /// Gives `handle` the navigation controller this view is in.
    func navigationBarHandle(_ handle: NavigationBarHandle) -> some View {
        background(NavigationBarHandleView(handle: handle).frame(width: 0, height: 0))
    }
}

private struct NavigationBarHandleView: UIViewControllerRepresentable {
    let handle: NavigationBarHandle

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        handle.controller = controller
        return controller
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        handle.controller = controller
    }
}
