import SwiftUI

extension Animation {
    /// `animation`, or none when Reduce Motion is on — for changes that move, resize or slide content
    /// (rows appearing, groups collapsing, banners leaving; DESIGN.md §6). Quick colour or opacity changes,
    /// like a picker's selection highlight, can keep their animation.
    ///
    /// Pass the view's `@Environment(\.accessibilityReduceMotion)`, the same source `ProgressRing` and
    /// `OnboardingFlow` read, so previews can override it.
    static func unlessReduceMotion(_ reduceMotion: Bool, _ animation: Animation = .default) -> Animation? {
        reduceMotion ? nil : animation
    }
}
