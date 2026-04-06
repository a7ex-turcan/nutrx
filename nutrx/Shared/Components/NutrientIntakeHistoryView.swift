import SwiftUI
import SwiftData

struct NutrientIntakeHistoryView: View {
    let nutrientID: UUID
    let unit: String

    @Query private var records: [IntakeRecord]

    init(nutrientID: UUID, unit: String) {
        self.nutrientID = nutrientID
        self.unit = unit

        let startOfDay = Calendar.current.startOfDay(for: .now)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        _records = Query(
            filter: #Predicate<IntakeRecord> {
                $0.nutrient?.id == nutrientID
                    && $0.date >= startOfDay
                    && $0.date < endOfDay
            },
            sort: \IntakeRecord.date
        )
    }

    private static let collapsedLimit = 5
    @State private var showAll = false

    private var visibleRecords: [IntakeRecord] {
        if showAll || records.count <= Self.collapsedLimit {
            return records
        }
        return Array(records.suffix(Self.collapsedLimit))
    }

    private var hiddenCount: Int {
        records.count - Self.collapsedLimit
    }

    var body: some View {
        if records.isEmpty {
            Text("No intakes logged yet")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 4)
        } else {
            VStack(spacing: 6) {
                if !showAll && records.count > Self.collapsedLimit {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAll = true
                        }
                    } label: {
                        Text("Show all \(records.count) entries")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }

                ForEach(visibleRecords, id: \.persistentModelID) { record in
                    recordRow(record)
                }
            }
        }
    }

    private func recordRow(_ record: IntakeRecord) -> some View {
        HStack {
            Text(record.date, format: .dateTime.hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)

            if let note = record.note, !note.isEmpty {
                Text("· \(note)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            let isNegative = record.amount < 0
            Text("\(isNegative ? "" : "+")\(record.amount.displayString) \(unit)")
                .font(.caption.weight(.medium))
                .foregroundStyle(isNegative ? .orange : .primary)
        }
    }
}
