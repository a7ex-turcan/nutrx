import Foundation

/// ↑ / ↓ in My Nutrients' iPad sidebar (#195): which row the selection moves to (pure).
enum SidebarStep {
    /// The id `offset` rows from `current` in `order`, held at the ends. With nothing selected, or a row that's no
    /// longer shown, ↓ starts at the first row and ↑ at the last. Nil with no rows.
    static func next<ID: Equatable>(in order: [ID], from current: ID?, by offset: Int) -> ID? {
        guard !order.isEmpty else { return nil }
        guard let current, let index = order.firstIndex(of: current) else {
            return offset >= 0 ? order.first : order.last
        }
        return order[min(max(index + offset, 0), order.count - 1)]
    }
}
