import WidgetKit
import SwiftUI

@main
struct NutrxWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NutrxSmallWidget()
        NutrxMediumWidget()
        NutrxCircularWidget()
        NutrxInlineWidget()
    }
}
