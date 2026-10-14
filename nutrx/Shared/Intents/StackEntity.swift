import AppIntents
import SwiftData

/// A stack as Siri and the Shortcuts app see it: picked by name from the user's stacks, never by its id.
struct StackEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Stack"
    static let defaultQuery = StackEntityQuery()

    let id: UUID
    let name: String
    /// "Vitamin D, Omega-3, Magnesium" under the name in the Shortcuts picker.
    let summary: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(summary)")
    }

    init(id: UUID, name: String, summary: String) {
        self.id = id
        self.name = name
        self.summary = summary
    }

    init(_ stack: LogStack) {
        self.init(id: stack.id, name: stack.name, summary: StackLogging.summary(of: stack))
    }
}

/// Looks stacks up in the app's store (the container the app registers with `AppDependencyManager`).
struct StackEntityQuery: EntityStringQuery {
    @Dependency private var modelContainer: ModelContainer

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [StackEntity] {
        let wanted = Set(identifiers)
        return Self.stacks(in: modelContainer.mainContext)
            .filter { wanted.contains($0.id) }
            .map(StackEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [StackEntity] {
        Self.matching(string, in: Self.loggableStacks(in: modelContainer.mainContext).map(StackEntity.init))
    }

    @MainActor
    func suggestedEntities() async throws -> [StackEntity] {
        Self.loggableStacks(in: modelContainer.mainContext).map(StackEntity.init)
    }

    /// Every stack, in Today's order.
    @MainActor
    static func stacks(in context: ModelContext) -> [LogStack] {
        (try? context.fetch(FetchDescriptor<LogStack>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
    }

    /// The stacks Today shows: those with something to log. An empty one is still found by id (and then says so).
    @MainActor
    static func loggableStacks(in context: ModelContext) -> [LogStack] {
        stacks(in: context).filter { !StackLogging.activeEntries(of: $0).isEmpty }
    }

    /// Names containing what was typed or said, ignoring case and accents; names that start with it come first.
    static func matching(_ query: String, in entities: [StackEntity]) -> [StackEntity] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return entities }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        let hits = entities.filter { $0.name.range(of: needle, options: options) != nil }
        let prefixed = hits.filter { $0.name.range(of: needle, options: options.union(.anchored)) != nil }
        return prefixed + hits.filter { hit in !prefixed.contains { $0.id == hit.id } }
    }
}
