import AppIntents
import SwiftData

/// A nutrient as Siri and the Shortcuts app see it: picked by name from the user's list, never by its id.
struct NutrientEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Nutrient"
    static let defaultQuery = NutrientEntityQuery()

    let id: UUID
    let name: String
    let unit: String
    let step: Double

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(stepSubtitle())")
    }

    /// "1,000 IU a step" under the name in the Shortcuts picker.
    func stepSubtitle(locale: Locale = .current) -> String {
        let unitSuffix = unit.isEmpty ? "" : " \(unit)"
        return "\(step.formattedAmount(locale: locale))\(unitSuffix) a step"
    }

    init(id: UUID, name: String, unit: String, step: Double) {
        self.id = id
        self.name = name
        self.unit = unit
        self.step = step
    }

    init(_ nutrient: Nutrient) {
        self.init(id: nutrient.id, name: nutrient.name, unit: nutrient.unit, step: nutrient.step)
    }
}

/// Looks nutrients up in the app's store (the container the app registers with `AppDependencyManager`).
struct NutrientEntityQuery: EntityStringQuery {
    @Dependency private var modelContainer: ModelContainer

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [NutrientEntity] {
        let wanted = Set(identifiers)
        return Self.activeNutrients(in: modelContainer.mainContext)
            .filter { wanted.contains($0.id) }
            .map(NutrientEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [NutrientEntity] {
        Self.matching(string, in: Self.activeNutrients(in: modelContainer.mainContext).map(NutrientEntity.init))
    }

    @MainActor
    func suggestedEntities() async throws -> [NutrientEntity] {
        Self.activeNutrients(in: modelContainer.mainContext).map(NutrientEntity.init)
    }

    /// Nutrients on Today (not deleted, course not ended), in Today's order: by group, then within the group.
    @MainActor
    static func activeNutrients(in context: ModelContext) -> [Nutrient] {
        let descriptor = FetchDescriptor<Nutrient>(predicate: #Predicate { !$0.isDeleted })
        return ordered(((try? context.fetch(descriptor)) ?? []).filter { $0.isRunning() })
    }

    /// Today's order. A nutrient without a group belongs to General, which comes last.
    static func ordered(_ nutrients: [Nutrient]) -> [Nutrient] {
        nutrients.sorted {
            let lhsGroup = $0.group?.sortOrder ?? Int.max, rhsGroup = $1.group?.sortOrder ?? Int.max
            if lhsGroup != rhsGroup { return lhsGroup < rhsGroup }
            if $0.groupSortOrder != $1.groupSortOrder { return $0.groupSortOrder < $1.groupSortOrder }
            return $0.sortOrder < $1.sortOrder
        }
    }

    /// Names containing what was typed or said, ignoring case and accents; names that start with it come first.
    static func matching(_ query: String, in entities: [NutrientEntity]) -> [NutrientEntity] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return entities }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        let hits = entities.filter { $0.name.range(of: needle, options: options) != nil }
        let prefixed = hits.filter { $0.name.range(of: needle, options: options.union(.anchored)) != nil }
        return prefixed + hits.filter { hit in !prefixed.contains { $0.id == hit.id } }
    }
}
