import Foundation

/// The words around a dose plan (nutrx Pro, #135, docs/pro/DOSE-PLANS.md §4–5): the form's Dose plan row, Today's
/// step line, the analytics header, the sheet's sentence, the form's goal card and Remove plan. Pure, tested in
/// `DosePlanTextTests`. It describes the steps the user set and never suggests one.
struct DosePlanText {
    let goalType: GoalType
    let unit: String
    var calendar: Calendar = .current
    var locale: Locale = .current

    static let none = "None"
    static let paused = "Paused"
    static let todayPaused = "Plan paused"
    static let noAdvice = "nutrx doesn't suggest amounts. Set the steps you or your doctor chose."
    static let typeLocked = "Remove the dose plan to change the goal type."
    static let removeTitle = "Remove the dose plan?"
    static let editPlan = "Edit plan"
    static let needsPro = "Changing a dose plan is part of nutrx Pro. Removing it isn't."

    /// The sheet without Pro (§6): "Paused without nutrx Pro since 20 Nov".
    func pausedSince(_ heldFrom: Date) -> String {
        "Paused without nutrx Pro since \(date(heldFrom, weekday: false))"
    }

    // MARK: - Amounts

    /// "200 mg", or a range's "120–160 g".
    func amount(_ goal: NutrientGoal) -> String {
        if goalType == .range, let upper = goal.upperBound {
            return "\(number(goal.target))–\(number(upper)) \(unit)"
        }
        return "\(number(goal.target)) \(unit)"
    }

    /// "200 → 400 mg": every step up to three, else the first and the last (the report's rule).
    func goals(_ steps: [NutrientDosePlan.Step]) -> String {
        let shown = steps.count <= 3 ? steps : [steps[0], steps[steps.count - 1]]
        let values = shown.map { step in
            goalType == .range && step.goal.upperBound != nil
                ? "\(number(step.goal.target))–\(number(step.goal.upperBound ?? 0))" : number(step.goal.target)
        }
        return values.joined(separator: " → ") + " \(unit)"
    }

    // MARK: - The form

    /// The form's Dose plan row: "None", "200 → 400 mg · from Mon 16 Nov", "200 → 400 mg · step 1 of 2",
    /// "400 mg · plan kept", "Ended 6 Dec" or "Paused".
    func summary(_ plan: NutrientDosePlan.Plan?, today: Date) -> String {
        guard let plan, !plan.steps.isEmpty else { return Self.none }
        let day = calendar.startOfDay(for: today)
        if let heldFrom = plan.heldFrom, day >= heldFrom { return Self.paused }
        if day < plan.start { return "\(goals(plan.steps)) · from \(date(plan.start, weekday: true))" }
        if let position = plan.position(on: day, calendar: calendar) {
            return "\(goals(plan.steps)) · step \(position.step) of \(position.count)"
        }
        if plan.end == .stop { return "Ended \(date(plan.lastDay(calendar: calendar), weekday: false))" }
        return "\(amount(plan.steps[plan.steps.count - 1].goal)) · plan kept"
    }

    /// The row's value when the summary doesn't fit: "Step 1 of 2", "From Mon 16 Nov"; nil when the summary is short
    /// already.
    func shortSummary(_ plan: NutrientDosePlan.Plan?, today: Date) -> String? {
        guard let plan, !plan.steps.isEmpty else { return nil }
        let day = calendar.startOfDay(for: today)
        if let heldFrom = plan.heldFrom, day >= heldFrom { return nil }
        if day < plan.start { return "From \(date(plan.start, weekday: true))" }
        if let position = plan.position(on: day, calendar: calendar) {
            return "Step \(position.step) of \(position.count)"
        }
        return plan.end == .keep ? "Plan kept" : nil
    }

    /// The goal card while a plan sets today's goal: "Set by your dose plan: 400 mg a day until Fri", or without
    /// "until" once the last goal is kept (or while held).
    func goalCard(_ plan: NutrientDosePlan.Plan, today: Date) -> String? {
        let day = calendar.startOfDay(for: today)
        guard let goal = plan.goal(on: day, calendar: calendar) else { return nil }
        let held = plan.heldFrom.map { day >= $0 } ?? false
        guard !held, let position = plan.position(on: day, calendar: calendar) else {
            return "Set by your dose plan: \(amount(goal)) a day"
        }
        return "Set by your dose plan: \(amount(goal)) a day until \(shortDay(position.lastDay, today: day))"
    }

    /// The Duration row of a plan that stops: "Ends with the dose plan · Sun 6 Dec".
    func durationSummary(_ plan: NutrientDosePlan.Plan) -> String {
        "Ends with the dose plan · \(date(plan.lastDay(calendar: calendar), weekday: true))"
    }

    /// When that doesn't fit: "With the plan · Sun 6 Dec".
    func shortDurationSummary(_ plan: NutrientDosePlan.Plan) -> String {
        "With the plan · \(date(plan.lastDay(calendar: calendar), weekday: true))"
    }

    // MARK: - The sheet

    /// The footer: "200 mg until Sun 15 Nov, then 400 mg from Mon 16 Nov, and keeps 400 mg." A later start leads
    /// ("From Mon 16 Nov: …"), a plan that stops ends "…, and stops after Sun 6 Dec.", and a course that ends before
    /// the steps do adds that the plan stops there.
    func sentence(_ plan: NutrientDosePlan.Plan, today: Date, courseEnd: Date? = nil) -> String {
        guard !plan.steps.isEmpty else { return "" }
        let ranges = plan.stepDays(calendar: calendar)
        var parts: [String] = []
        for (index, step) in plan.steps.enumerated() {
            let goal = amount(step.goal)
            let isLast = index == plan.steps.count - 1
            switch (index, isLast) {
            case (0, _):
                parts.append("\(goal) until \(date(ranges[index].upperBound, weekday: true))")
            case (_, false):
                parts.append("then \(goal) from \(date(ranges[index].lowerBound, weekday: true)) until "
                             + date(ranges[index].upperBound, weekday: true))
            case (_, true):
                parts.append("then \(goal) from \(date(ranges[index].lowerBound, weekday: true))")
            }
        }
        let lastGoal = amount(plan.steps[plan.steps.count - 1].goal)
        let ending = plan.end == .keep
            ? "and keeps \(lastGoal)."
            : "and stops after \(date(plan.lastDay(calendar: calendar), weekday: true))."
        var text = (parts + [ending]).joined(separator: ", ")
        if plan.start > calendar.startOfDay(for: today) {
            text = "From \(date(plan.start, weekday: true)): " + text
        }
        if let courseEnd, plan.end == .keep, calendar.startOfDay(for: courseEnd) < plan.lastDay(calendar: calendar) {
            text += " Its course ends on \(date(courseEnd, weekday: true)), so the plan stops there."
        }
        if let courseEnd, plan.end == .stop, calendar.startOfDay(for: courseEnd) != plan.lastDay(calendar: calendar) {
            text += " This replaces the course's end on \(date(courseEnd, weekday: true))."
        }
        return text
    }

    /// "for 7 days", "for 2 weeks".
    static func length(days: Int, inWeeks: Bool) -> String {
        if inWeeks {
            let weeks = max(1, days / 7)
            return weeks == 1 ? "for 1 week" : "for \(weeks) weeks"
        }
        return days == 1 ? "for 1 day" : "for \(days) days"
    }

    /// Remove plan's confirmation: past days stay as they were, and the goal from today.
    func removeMessage(name: String, goalFromToday: NutrientGoal, endsWithPlan: Bool) -> String {
        let goal = "From today \(name)'s goal is \(amount(goalFromToday)) a day"
        return "Past days keep the goals they had. " + goal + (endsWithPlan ? ", with no end." : ".")
    }

    // MARK: - Today and analytics

    /// Today's third line, and shorter forms for beside the goal status when it doesn't fit (as a low bottle's
    /// hint shortens): "Step 2 of 3", then "2 of 3".
    struct TodayLine: Equatable {
        let text: String
        var shortText: String? = nil
        var compactText: String? = nil
    }

    /// Today's third line: "Step 2 of 3 · until Fri", "Step 2 of 3 · last day", or "Plan paused". Nil outside the
    /// steps, and on the very last day of a plan that stops, where the course's "Last day" says it.
    func todayLine(_ plan: NutrientDosePlan, today: Date) -> TodayLine? {
        let day = calendar.startOfDay(for: today)
        if plan.isHeld(on: day, calendar: calendar) { return TodayLine(text: Self.todayPaused) }
        guard let position = plan.position(on: day, calendar: calendar) else { return nil }
        let step = "Step \(position.step) of \(position.count)"
        let compact = "\(position.step) of \(position.count)"
        if position.lastDay == day {
            if plan.stopDay(calendar: calendar) == day { return nil }
            return TodayLine(text: "\(step) · last day", shortText: step, compactText: compact)
        }
        return TodayLine(text: "\(step) · until \(shortDay(position.lastDay, today: day))", shortText: step,
                         compactText: compact)
    }

    /// The analytics header's part: "Step 2 of 3, until 20 Nov", or "Plan paused".
    func headerPart(_ plan: NutrientDosePlan, today: Date) -> String? {
        let day = calendar.startOfDay(for: today)
        if plan.isHeld(on: day, calendar: calendar) { return Self.todayPaused }
        guard let position = plan.position(on: day, calendar: calendar) else { return nil }
        return "Step \(position.step) of \(position.count), until \(date(position.lastDay, weekday: false))"
    }

    // MARK: - Pieces

    /// The weekday within the coming week ("Fri"), else the date ("20 Nov").
    private func shortDay(_ day: Date, today: Date) -> String {
        let ahead = calendar.dateComponents([.day], from: today, to: day).day ?? 0
        if (0...6).contains(ahead) {
            var style = Date.FormatStyle.dateTime.weekday(.abbreviated).locale(locale)
            style.timeZone = calendar.timeZone
            return day.formatted(style)
        }
        return date(day, weekday: false)
    }

    /// "Sun 15 Nov", or "15 Nov", with no-break spaces so a line never ends inside a date ("14 / Nov").
    private func date(_ date: Date, weekday: Bool) -> String {
        let style = weekday ? Date.FormatStyle.dateTime.weekday(.abbreviated).day().month(.abbreviated)
                            : Date.FormatStyle.dateTime.day().month(.abbreviated)
        var formatted = style.locale(locale)
        formatted.timeZone = calendar.timeZone
        return date.formatted(formatted).replacingOccurrences(of: " ", with: "\u{00A0}")
    }

    private func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).locale(locale))
    }
}
