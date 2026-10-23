import SwiftUI

/// Which days a nutrient is taken on (nutrx Pro, #132, docs/pro/SCHEDULES.md §6): every day, on certain weekdays,
/// every few days, on and off, or a number of times a week (any days; "At least" goals only). Writes the kind to the draft; the form's Save or Add applies it from today on.
struct ScheduleSheet: View {
    @Bindable var draft: NutrientDraft

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var option: Option = .everyDay
    @State private var weekdays: Set<Int> = []
    @State private var every = 2
    @State private var daysOn = 5
    @State private var daysOff = 2
    @State private var inWeeks = false
    @State private var start = Date.now
    @State private var timesAWeek = 3

    private let text = ScheduleText()
    private var calendar: Calendar { .current }
    private var today: Date { calendar.startOfDay(for: .now) }

    enum Option: Hashable, CaseIterable {
        case everyDay, weekdays, everyFewDays, onAndOff, timesAWeek

        var title: String {
            switch self {
            case .everyDay: "Every day"
            case .weekdays: "On certain days"
            case .everyFewDays: "Every few days"
            case .onAndOff: "On and off"
            case .timesAWeek: "Times a week"
            }
        }
    }

    /// What Done saves, or nil while it can't be saved (no weekday picked).
    private var kind: NutrientSchedule.Kind? {
        let first = calendar.startOfDay(for: start)
        switch option {
        case .everyDay:
            return .everyDay
        case .weekdays:
            if weekdays.isEmpty { return nil }
            return weekdays.count == 7 ? .everyDay : .weekdays(weekdays)  // all seven is every day
        case .everyFewDays:
            return .cycle(on: 1, off: every - 1, start: first)
        case .onAndOff:
            let unit = inWeeks ? 7 : 1
            return .cycle(on: daysOn * unit, off: daysOff * unit, start: first)
        case .timesAWeek:
            return .weekly(times: timesAWeek)
        }
    }

    /// Times a week counts met days, which only makes sense for "At least" goals: a limit isn't something to meet a
    /// number of times.
    private var weeklyAllowed: Bool { draft.goalType == .minimum }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(Option.allCases, id: \.self) { choice in
                        let unavailable = choice == .timesAWeek && !weeklyAllowed
                        Button {
                            option = choice
                        } label: {
                            HStack {
                                Text(choice.title)
                                    .foregroundStyle(unavailable ? Theme.textSecondary : Theme.textPrimary)
                                Spacer()
                                if option == choice {
                                    // A real selection, so a checkmark symbol is right here (CLAUDE.md, accessibility).
                                    Image(systemName: "checkmark")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Theme.controlPrimary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(unavailable)
                        .accessibilityAddTraits(option == choice ? .isSelected : [])
                    }
                } footer: {
                    if !weeklyAllowed {
                        Text("Times a week works with an At least goal.")
                    }
                }
                .listRowBackground(Theme.surfaceCard)

                details
            }
            .contentMargins(.top, 8, for: .scrollContent)
            .scrollContentBackground(.hidden)
            .background(Theme.surfaceGround)
            .tint(Theme.controlPrimary)
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let kind { draft.scheduleKind = kind }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(kind == nil)
                }
            }
            .onAppear(perform: load)
        }
        // Full height: at half height the chosen option's controls and the footer with the next days were below the
        // fold.
        .presentationDetents([.large])
    }

    // MARK: - The chosen option's controls

    @ViewBuilder
    private var details: some View {
        switch option {
        case .everyDay:
            Section {
                Text("Shown on Today every day.")
                    .foregroundStyle(Theme.textSecondary)
            }
            .listRowBackground(Theme.surfaceCard)
        case .weekdays:
            Section {
                weekdayPicker
            } footer: {
                footer(weekdays.isEmpty ? "Pick at least one day." : nil)
            }
            .listRowBackground(Theme.surfaceCard)
        case .everyFewDays:
            Section {
                Stepper(value: $every, in: 2...30) {
                    Text(every == 2 ? "Every other day" : "Every \(every) days")
                        .monospacedDigit()
                }
                startPicker
            } footer: {
                footer(nil)
            }
            .listRowBackground(Theme.surfaceCard)
        case .timesAWeek:
            Section {
                Stepper(value: $timesAWeek, in: NutrientSchedule.timesAWeek) {
                    Text(text.summary(.weekly(times: timesAWeek))).monospacedDigit()
                }
            } footer: {
                footer(nil)
            }
            .listRowBackground(Theme.surfaceCard)
        case .onAndOff:
            Section {
                Picker("Count in", selection: $inWeeks) {
                    Text("Days").tag(false)
                    Text("Weeks").tag(true)
                }
                .pickerStyle(.segmented)
                .onChange(of: inWeeks) { _, weeks in
                    // Up to 8 weeks each way, so a cycle stays within 60 days on or off; at least 2 days on.
                    if weeks {
                        daysOn = min(daysOn, 8)
                        daysOff = min(daysOff, 8)
                    } else {
                        daysOn = max(daysOn, 2)
                    }
                }
                // From 2 days: 1 day on is Every few days.
                Stepper(value: $daysOn, in: inWeeks ? 1...8 : 2...NutrientSchedule.cycleLengths.upperBound) {
                    Text("\(daysOn) \(unitName(daysOn)) on").monospacedDigit()
                }
                Stepper(value: $daysOff, in: inWeeks ? 1...8 : NutrientSchedule.cycleLengths) {
                    Text("\(daysOff) \(unitName(daysOff)) off").monospacedDigit()
                }
                startPicker
            } footer: {
                footer(nil)
            }
            .listRowBackground(Theme.surfaceCard)
        }
    }

    /// Seven toggles in the locale's weekday order. At accessibility sizes, a list of full names with checkmarks:
    /// the buttons' short names broke mid-word there ("M/on").
    @ViewBuilder
    private var weekdayPicker: some View {
        if dynamicTypeSize.isAccessibilitySize {
            weekdayList
        } else {
            weekdayButtons
        }
    }

    private var weekdayList: some View {
        let fullNames = text.weekdayNames(.wide)
        return ForEach(text.ordered(1...7), id: \.self) { day in
            let isOn = weekdays.contains(day)
            Button {
                if isOn { weekdays.remove(day) } else { weekdays.insert(day) }
            } label: {
                HStack {
                    Text(fullNames[day - 1])
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    if isOn {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.controlPrimary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isOn ? .isSelected : [])
        }
    }

    private var weekdayButtons: some View {
        let names = text.weekdayNames(.abbreviated)
        let fullNames = text.weekdayNames(.wide)
        // Seven columns: the week on one row (an adaptive grid wrapped it 5 + 2 on an iPhone).
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 8) {
            ForEach(text.ordered(1...7), id: \.self) { day in
                let isOn = weekdays.contains(day)
                Button {
                    if isOn { weekdays.remove(day) } else { weekdays.insert(day) }
                } label: {
                    Text(names[day - 1])
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: Theme.minTouchTarget)
                        .foregroundStyle(isOn ? Theme.controlOnPrimary : Theme.textPrimary)
                        .background(isOn ? Theme.controlPrimary : Theme.surfaceChip,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(fullNames[day - 1])
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }

    /// Any day back (to line up with a routine already running), up to one cycle ahead.
    private var startPicker: some View {
        let cycle = option == .everyFewDays ? every : (daysOn + daysOff) * (inWeeks ? 7 : 1)
        let latest = calendar.date(byAdding: .day, value: cycle, to: today) ?? today
        return DatePicker("Starting", selection: $start, in: ...latest, displayedComponents: .date)
    }

    /// The next days it's due, or a hint while it can't be saved.
    private func footer(_ hint: String?) -> some View {
        Text(hint ?? kind.map { text.upcoming($0, today: today) } ?? "")
    }

    private func unitName(_ count: Int) -> String {
        inWeeks ? (count == 1 ? "week" : "weeks") : (count == 1 ? "day" : "days")
    }

    /// Opens on the draft's schedule.
    private func load() {
        switch draft.scheduleKind {
        case .everyDay:
            option = .everyDay
        case .weekly(let times):
            option = .timesAWeek
            timesAWeek = times
        case .weekdays(let days):
            option = .weekdays
            weekdays = days
        case .cycle(let on, let off, let cycleStart):
            start = cycleStart
            if on == 1 {
                option = .everyFewDays
                every = off + 1
            } else {
                option = .onAndOff
                inWeeks = on % 7 == 0 && off % 7 == 0
                daysOn = inWeeks ? on / 7 : on
                daysOff = inWeeks ? off / 7 : off
            }
        }
    }
}

private func previewDraft(_ kind: NutrientSchedule.Kind) -> NutrientDraft {
    let draft = NutrientDraft()
    draft.scheduleKind = kind
    return draft
}

#Preview("On certain days") { ScheduleSheet(draft: previewDraft(.weekdays([2, 4, 6]))) }
#Preview("Every few days") {
    ScheduleSheet(draft: previewDraft(.cycle(on: 1, off: 2, start: Calendar.current.startOfDay(for: .now))))
}
#Preview("On and off, weeks") {
    ScheduleSheet(draft: previewDraft(.cycle(on: 21, off: 7, start: Calendar.current.startOfDay(for: .now))))
}
#Preview("Dark") { ScheduleSheet(draft: previewDraft(.weekdays([1]))).preferredColorScheme(.dark) }
#Preview("Largest text") {
    ScheduleSheet(draft: previewDraft(.weekdays([2, 6]))).dynamicTypeSize(.accessibility5)
}
