---
name: swiftdata-patterns
description: >
  nutrx-specific SwiftData rules and query patterns. Use whenever writing or
  modifying any SwiftData model, query, fetch descriptor, or persistence logic
  in the nutrx project. Covers date comparisons, intake aggregation, soft
  deletes, relationships, and the daily reset / exclusion lifecycle.
---

# SwiftData Patterns for nutrx

## Golden Rules — Never Break These

### 1. Date comparisons use calendar day, not timestamp equality

`IntakeRecord.date` is a full `Date` timestamp. **Never** compare it with `==` or
range-based timestamp arithmetic to determine "today" or a specific day.

Always use `Calendar.current` day components:

```swift
// ✅ CORRECT
let calendar = Calendar.current
let records = allRecords.filter { calendar.isDate($0.date, inSameDayAs: target) }

// ❌ WRONG — timestamps will never match
let records = allRecords.filter { $0.date == today }

// ❌ WRONG — fragile, breaks across DST and midnight edge cases
let records = allRecords.filter { $0.date >= startOfDay && $0.date < endOfDay }
```

The helpers in `Shared/Extensions/Date+Calendar.swift` (`isToday`, `isSameDay(_:)`,
`startOfDay`) exist precisely for this. Use them everywhere.

---

### 2. Intake totals are always computed by summing raw records — never stored

There is no `totalToday` field on `Nutrient`. Today's intake for a nutrient is
always the **sum of all matching `IntakeRecord.amount` values** for that calendar day.

```swift
// ✅ CORRECT — derive totals at query time
func totalIntake(for nutrient: Nutrient, on date: Date, records: [IntakeRecord]) -> Double {
    records
        .filter { $0.nutrient == nutrient && Calendar.current.isDate($0.date, inSameDayAs: date) }
        .reduce(0) { $0 + $1.amount }
}

// ❌ WRONG — do not add a cached/pre-aggregated field to any model
// nutrient.totalToday += step  ← never do this
```

---

### 3. Nutrients are soft-deleted — never hard-deleted

Setting `isDeleted = true` on a `Nutrient` hides it from all active UI.
The record must be **retained** so that historical `IntakeRecord` rows that
reference it remain valid and visible in History.

```swift
// ✅ CORRECT
nutrient.isDeleted = true

// ❌ WRONG — destroys historical data
modelContext.delete(nutrient)
```

When querying for the active nutrient list, always filter out deleted nutrients:

```swift
let descriptor = FetchDescriptor<Nutrient>(
    predicate: #Predicate { !$0.isDeleted },
    sortBy: [SortDescriptor(\.sortOrder)]
)
```

---

### 4. SwiftData relationships use navigation properties — no manual ID fields

`IntakeRecord` holds `var nutrient: Nutrient` directly. SwiftData manages the
underlying foreign key. Never add a `var nutrientID: UUID` or equivalent.

```swift
// ✅ CORRECT
let record = IntakeRecord(nutrient: nutrient, amount: step, date: .now)

// ❌ WRONG — manual ID field, not how SwiftData works
let record = IntakeRecord(nutrientID: nutrient.id, amount: step, date: .now)
```

---

### 5. The ModelContainer is created once in ModelContainerFactory

Never instantiate a `ModelContainer` inline in a view or view model.
Always use `ModelContainerFactory.shared` (or equivalent static accessor).
Schema registration lives there so `nutrxApp.swift` stays clean.

---

## Daily Reset Logic

The reset is **checked on foreground**, not via a background task.

Steps when the app foregrounds:
1. Compare the stored last-session date with `Calendar.current.startOfDay(for: .now)`.
2. If they differ (i.e. it's a new calendar day), the reset applies.
3. Save any pending state for the previous day to the History store before resetting.
4. Purge all `Exclusion` rows whose `date` is before today — they are no longer needed.
5. Do **not** delete `IntakeRecord` rows — they are the source of truth for History.

```swift
// Exclusion cleanup at reset
let staleExclusions = exclusions.filter {
    !Calendar.current.isDate($0.date, inSameDayAs: .now) &&
    $0.date < .now
}
staleExclusions.forEach { modelContext.delete($0) }
```

---

## Exclusion Lifecycle

An `Exclusion` row means: hide this nutrient from the Today view **on this calendar day only**.

- Created when the user taps "Exclude for today".
- Checked in `TodayViewModel` when building the visible nutrient list.
- Purged at the next midnight reset — exclusions never carry forward.
- Use `Exclusion.date`'s calendar day for matching, not the full timestamp.

```swift
// ✅ Check if a nutrient is excluded today
func isExcluded(_ nutrient: Nutrient, exclusions: [Exclusion]) -> Bool {
    exclusions.contains {
        $0.nutrient == nutrient &&
        Calendar.current.isDateInToday($0.date)
    }
}
```

---

## Standard Query Patterns

### Active nutrients for Today / My Nutrients (ordered)
```swift
FetchDescriptor<Nutrient>(
    predicate: #Predicate { !$0.isDeleted },
    sortBy: [SortDescriptor(\.sortOrder)]
)
```

### All IntakeRecords for a specific calendar day
```swift
// Fetch all, then filter in-memory using Calendar (avoids predicate DST issues)
let all = try modelContext.fetch(FetchDescriptor<IntakeRecord>())
let dayRecords = all.filter { Calendar.current.isDate($0.date, inSameDayAs: targetDate) }
```

### Distinct past days for History (most recent first)
```swift
// Fetch all records, extract unique calendar days, sort descending
let allRecords = try modelContext.fetch(FetchDescriptor<IntakeRecord>())
let days = Set(allRecords.map { Calendar.current.startOfDay(for: $0.date) })
let sortedDays = days.sorted(by: >)
```

### UserProfile — always exactly one instance
```swift
let profiles = try modelContext.fetch(FetchDescriptor<UserProfile>())
let profile = profiles.first  // There is always exactly one
```

---

## Model Field Reference

| Model | Key fields | Notes |
|---|---|---|
| `UserProfile` | name, birthdate, weight, weightUnit, gender | Singleton — one row always |
| `Nutrient` | name, unit, step, dailyTarget, sortOrder, isDeleted | Soft-deleted, never hard-deleted |
| `IntakeRecord` | nutrient (nav), amount, date | One row per tap / custom entry |
| `Exclusion` | nutrient (nav), date | One row per excluded-day pair |

---

## Out of Scope

- No networking, no sync, no CloudKit — all data stays on device.
- No pre-aggregated totals — derive everything from raw `IntakeRecord` rows.
- No hard deletes on `Nutrient`.
