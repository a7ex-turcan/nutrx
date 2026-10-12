import SwiftUI
import UIKit

extension Animation {
    /// `animation`, or none when Reduce Motion is on — for changes that move, resize or slide content
    /// (rows appearing, groups collapsing, banners leaving; DESIGN.md §6). Quick colour or opacity changes,
    /// like a picker's selection highlight, can keep their animation.
    static func unlessReduceMotion(_ animation: Animation = .default) -> Animation? {
        UIAccessibility.isReduceMotionEnabled ? nil : animation
    }
}
