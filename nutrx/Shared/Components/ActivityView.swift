import SwiftUI

/// The system share sheet, for its completion callback (`ShareLink` has none, and the done state needs to know the
/// file was actually sent somewhere).
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    let onComplete: (_ completed: Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onComplete(completed)
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
