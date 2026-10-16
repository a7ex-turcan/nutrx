import Foundation
import SwiftData

/// Logging a stack and the small rules around it, shared by Today's log sheet and the Stacks tab (and Siri
/// later): which entries count, whether the stack was logged today, adding a nutrient, undo.
enum StackLogging {
    /// What one log of a stack did, so the sheet can show it and undo it.
    struct Logged {
        let records: [IntakeRecord]
        let previousLastLoggedAt: Date?
        let date: Date
    }

    /// The entries a stack logs, in order: those whose nutrient still exists (deleted nutrients keep their entries
    /// for history, but a stack skips them).
    static func activeEntries(of stack: LogStack) -> [LogStackEntry] {
        (stack.entries ?? [])
            .filter { $0.nutrient.map { !$0.isDeleted } ?? false }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Logged on `now`'s calendar day, from any device.
    static func isLoggedToday(_ stack: LogStack, now: Date = .now, calendar: Calendar = .current) -> Bool {
        stack.lastLoggedAt.map { calendar.isDate($0, inSameDayAs: now) } ?? false
    }

    /// "Vitamin D, Omega-3, Magnesium", or "No nutrients yet".
    static func summary(of stack: LogStack) -> String {
        let names = activeEntries(of: stack).compactMap { $0.nutrient?.name }
        return names.isEmpty ? "No nutrients yet" : names.formatted(.list(type: .and, width: .narrow))
    }

    /// One intake record per active entry, at its amount — or at `amounts[entry]` when the user changed it for
    /// this time. Zero amounts are skipped. Sets `lastLoggedAt` when anything was logged, and saves.
    @MainActor
    @discardableResult
    static func log(_ stack: LogStack, amounts: [PersistentIdentifier: Double] = [:], context: ModelContext,
                    now: Date = .now) -> Logged {
        let previous = stack.lastLoggedAt
        var records: [IntakeRecord] = []
        for entry in activeEntries(of: stack) {
            guard let nutrient = entry.nutrient else { continue }
            let amount = amounts[entry.persistentModelID] ?? entry.amount
            guard amount > 0 else { continue }
            let record = IntakeRecord(nutrient: nutrient, amount: amount, date: now)
            context.insert(record)
            records.append(record)
        }
        if !records.isEmpty {
            stack.lastLoggedAt = now
        }
        try? context.save()
        return Logged(records: records, previousLastLoggedAt: previous, date: now)
    }

    /// Takes back exactly what `log` added and restores the stack's previous `lastLoggedAt`.
    @MainActor
    static func undo(_ logged: Logged, of stack: LogStack, context: ModelContext) {
        for record in logged.records {
            context.delete(record)
        }
        stack.lastLoggedAt = logged.previousLastLoggedAt
        try? context.save()
    }

    /// Adds a nutrient at the end, with its step as the amount ("Amounts start at each nutrient's step").
    @MainActor
    @discardableResult
    static func add(_ nutrient: Nutrient, to stack: LogStack, context: ModelContext) -> LogStackEntry {
        let order = ((stack.entries ?? []).map(\.sortOrder).max() ?? -1) + 1
        let entry = LogStackEntry(nutrient: nutrient, amount: nutrient.step, sortOrder: order)
        context.insert(entry)
        entry.stack = stack
        try? context.save()
        return entry
    }

    /// Whether the nutrient is in the stack.
    static func contains(_ stack: LogStack, _ nutrient: Nutrient) -> Bool {
        (stack.entries ?? []).contains { $0.nutrient?.persistentModelID == nutrient.persistentModelID }
    }

    /// Adds the nutrient to the stack (at its step) or takes it out ("Add to Stack…" in My Nutrients).
    @MainActor
    static func toggle(_ nutrient: Nutrient, in stack: LogStack, context: ModelContext) {
        let entries = (stack.entries ?? []).filter { $0.nutrient?.persistentModelID == nutrient.persistentModelID }
        if entries.isEmpty {
            add(nutrient, to: stack, context: context)
        } else {
            entries.forEach(context.delete)
            try? context.save()
        }
    }

    /// A stack picked for a nutrient that isn't saved yet: an existing one, or a new one created with it.
    enum Choice: Hashable {
        case existing(UUID)
        case new(String)
    }

    /// Puts a just-added nutrient in the stacks picked in its form, creating the new ones. Returns whether any stack
    /// was created or changed, so the caller can refresh Siri's stack phrases.
    @MainActor
    @discardableResult
    static func add(_ nutrient: Nutrient, toStacks choices: [Choice], context: ModelContext) -> Bool {
        guard !choices.isEmpty else { return false }
        let stacks = (try? context.fetch(FetchDescriptor<LogStack>())) ?? []
        for choice in choices {
            switch choice {
            case .existing(let id):
                if let stack = stacks.first(where: { $0.id == id }), !contains(stack, nutrient) {
                    add(nutrient, to: stack, context: context)
                }
            case .new(let name):
                // Made by an earlier nutrient from the same label (or since): join it rather than make a second one.
                let current = (try? context.fetch(FetchDescriptor<LogStack>())) ?? []
                let stack = stack(named: name, in: current) ?? createStack(named: name, context: context)
                if !contains(stack, nutrient) { add(nutrient, to: stack, context: context) }
            }
        }
        return true
    }

    /// Today suggests making a stack once there are a few nutrients to put in one, until there's a stack or the
    /// suggestion is hidden.
    static func suggestsStack(nutrientCount: Int, stackCount: Int, hidden: Bool) -> Bool {
        nutrientCount >= suggestionNutrientCount && stackCount == 0 && !hidden
    }

    static let suggestionNutrientCount = 3

    /// A stack with this name already (ignoring case and surrounding spaces), so "New Stack… Morning" picks the
    /// existing Morning instead of making a second one Siri couldn't tell apart.
    static func stack(named name: String, in stacks: [LogStack]) -> LogStack? {
        let key = name.trimmingCharacters(in: .whitespaces).lowercased()
        return stacks.first { $0.name.trimmingCharacters(in: .whitespaces).lowercased() == key }
    }

    /// The New Stack alert's message, wherever a stack is made, suggesting a name nobody has used yet. (The field's
    /// placeholder is "Stack name": in an alert it's the only name VoiceOver gets for the field.)
    static func newStackMessage(existing: [String]) -> String {
        "A stack logs several nutrients in one tap. Name it after when you take them, like “\(suggestedName(existing: existing))”."
    }

    /// A usual stack name nobody has used yet.
    static func suggestedName(existing: [String]) -> String {
        let taken = Set(existing.map { $0.lowercased() })
        return ["Morning", "Evening", "Night", "With meals", "Workout"].first { !taken.contains($0.lowercased()) }
            ?? "Stack"
    }

    /// "None", "Morning", "Morning and Evening", "3 stacks" for the form's Stacks row.
    static func summary(names: [String]) -> String {
        switch names.count {
        case 0: "None"
        case 1: names[0]
        case 2: "\(names[0]) and \(names[1])"
        default: "\(names.count) stacks"
        }
    }

    /// A new, empty stack at the end of the list.
    @MainActor
    static func createStack(named name: String, context: ModelContext) -> LogStack {
        let existing = (try? context.fetch(FetchDescriptor<LogStack>())) ?? []
        let stack = LogStack(name: name, sortOrder: (existing.map(\.sortOrder).max() ?? -1) + 1)
        context.insert(stack)
        try? context.save()
        return stack
    }

    /// Gives every stack its own `id`. Adding `LogStack.id` to an existing store filled every stack made before it
    /// with the same default value, and Siri picks stacks by that id. Keeps the first stack's id, saves only if it
    /// changed something. Run at launch and whenever the app becomes active (a synced device may bring duplicates).
    /// Returns whether it changed anything, so the caller can refresh Siri's stack phrases.
    @MainActor
    @discardableResult
    static func repairDuplicateIDs(context: ModelContext) -> Bool {
        let stacks = (try? context.fetch(FetchDescriptor<LogStack>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        var seen = Set<UUID>()
        var changed = false
        for stack in stacks {
            if !seen.insert(stack.id).inserted {
                stack.id = UUID()
                seen.insert(stack.id)
                changed = true
            }
        }
        if changed {
            try? context.save()
        }
        return changed
    }

    /// The next amount a − / + step gives: a step at a time, never below one step.
    static func stepped(_ amount: Double, by step: Double, up: Bool) -> Double {
        guard step > 0 else { return amount }
        return up ? amount + step : max(step, amount - step)
    }
}
