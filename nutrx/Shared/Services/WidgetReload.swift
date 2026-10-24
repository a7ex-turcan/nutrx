import WidgetKit

/// Asks the widgets and the Control Center controls (#138) to read the store again after something they show changed.
/// Controls don't follow widget timeline reloads, so one call does both.
enum WidgetReload {
    static func all() {
        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadAllControls()
    }
}
