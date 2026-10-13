import WidgetKit
import SwiftUI

@main
struct NutrxWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NutrxCircularComplication()
        NutrxCornerComplication()
        NutrxRectangularComplication()
        NutrxInlineComplication()
    }
}
