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

    var body: some View {
        if records.isEmpty {
            Text("No intakes logged yet")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 4)
        } else {
            VStack(spacing: 6) {
                ForEach(records, id: \.persistentModelID) { record in
                    recordRow(record)
                }
            }
        }
    }

    private func recordRow(_ record: IntakeRecord) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(record.date, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                let isNegative = record.amount < 0
                Text("\(isNegative ? "" : "+")\(record.amount.displayString) \(unit)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isNegative ? .orange : .primary)
            }

            if let note = record.note, !note.isEmpty {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}
