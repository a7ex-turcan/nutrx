# Reminders at your usual time — spec (nutrx Pro, #137)

A reminder that learns when you usually log, and nudges only when you're running late. Planned for 2.6, beside the monthly and yearly recaps.

Decided with the user on 2026-10-28:
- **When it fires:** a bit after your usual time: the time by which you've logged on most days (about 3 in 4) over the last 4 weeks, e.g. "usually by 8:30". On a normal day you've logged by then and it never fires.
- **Setup:** per nutrient, in its Reminders: **At set times** (free, as now) or **At my usual time** (Pro). One or the other, so there's never a double nudge.
- **Before it has learned** (7 logged days in the last 4 weeks): a set time you pick, which the reminder moves from once it has learned. The row says "Learning, 3 of 7 days".
- **Stacks too:** a stack gets a reminder, at a set time or at its usual time.

"Only if not logged", the issue's other half, is already how every reminder works: logging a nutrient silences the rest of that day's reminders for it (CLAUDE.md, Notifications). This spec keeps that rule, and it applies to usual-time reminders too.

---

## 1. Rules it keeps (docs/pro/PLAN.md §0)

- **Nothing free becomes Pro.** Reminders at set times stay free for nutrients, and stack reminders at a set time are free as well: they're the same kind of reminder. Only the learned time is Pro.
- **On the device only.** The usual time is worked out from the store's own `IntakeRecord` times. Nothing leaves the device and nothing new is stored about the user's habits: the learned time is recomputed, never synced.
- **No advice.** It reminds you to log what you've set up. It never suggests a time to take something or an amount.
- **Pro lapses gracefully.** If Pro ends, a usual-time reminder fires at its starting time (§3). It's never silently dropped.

## 2. The usual time (`UsualTime`, pure, `UsualTimeTests`)

From the last **28 completed days** (today never counts, as in recaps):

| Rule | Detail |
|---|---|
| **A sample** | On a day the nutrient was due (its schedule, #132; its course, #99) and logged, the time of its **first** log that day. Days not due or not logged give no sample. |
| **Learned** | With at least **7 samples**. Fewer: "Learning, 3 of 7 days", and the set time is used. |
| **The time** | The **75th percentile** of the samples (the time by which it was logged on about 3 days in 4), rounded **up** to the next 5 minutes: "Usually by 8:30". |
| **Weekdays and weekends** | When both have at least 4 samples and their times differ by **an hour or more**, each gets its own: "Usually by 8:30 on weekdays, 10:15 at weekends". The weekend is the calendar's (`Calendar.isDateInWeekend`): Saturday and Sunday in most places. |
| **Limits** | Not after 23:30. A time that would be past it means the habit is around midnight: the reminder stays at the set time, and the row says why. |

**Several doses a day:** a usual-time reminder is **one a day**, for the day's **first** log. **At my usual time** is offered whatever the set times. With two or more set times, the sheet says so: "One reminder a day, for the first time you log it. Your 3 set times come back if you switch back."

**Stacks:** a sample is a day on which **every** nutrient in the stack had something logged, at the latest of their first logs. That's the moment the stack was done, however it was logged: all together with Log, or one by one. A stack with a nutrient that wasn't due that day counts the others.

## 3. Nutrients

- **The Reminders sheet** (`NutrientRemindersSheet`, and `PendingRemindersSheet` for a nutrient not saved yet) gets a choice at the top: **At set times** or **At my usual time** (a `ProGatedButton`: PRO chip and paywall for free users).
  - **At set times:** as now.
  - **At my usual time:** "Usually by 8:30. nutrx reminds you then if you haven't logged it." While learning: "Learning your usual time, 3 of 7 days. Until then:" and one time picker, the **starting time**.
  - **The starting time** is its own value, never one of the set times. Switching to the usual time sets it to the earliest set time, or 9:00 with none. The picker edits only it, so the set times are untouched and switching back restores them exactly. It's what fires while learning, around midnight, and after a Pro lapse.
- **The model:** `Nutrient.usualReminderMinutes: Int = -1` (CloudKit `CD_usualReminderMinutes`): -1 means at set times, and 0 or more means at the usual time, with that starting time (minutes after midnight). One field for both, with a `remindsAtUsualTime` read on top. A nutrient at its usual time is scheduled whether or not it has set reminders.
- **The Reminders row** (`NutrientSummaryText`, analytics and the form): "Usually by 8:30", "Learning (9:00)", or as now.
- **Today's next-reminder line** follows the scheduled time, as now.

## 4. Stacks

- **Stack detail** gets a **Reminder** row: "None", "9:00" or "Usually by 8:30". It opens a sheet with **Off**, **At a set time** (free) and **At my usual time** (Pro, with the same learning state and starting time).
- **The model:** `LogStack.reminderMinutes: Int = -1` (minutes after midnight, -1 for none) and `LogStack.remindsAtUsualTime: Bool = false` (CloudKit `CD_reminderMinutes`, `CD_remindsAtUsualTime`). A stack has one time, so its set time is also its starting time.
- **Its nutrients' own reminders** still come; the scheduler doesn't merge them. The sheet says so when any of them has reminders: "Vitamin D and Omega-3 have reminders of their own too." Someone who wants one nudge turns those off.
- **When it's silent:** a stack that's **done today**. That's logged with Log (`StackLogging`'s rule, from any device), or every one of its due nutrients already logged today, as on Today's card. It's also silent on a day with nothing due in it.
- **The notification:** "Time for your Morning stack", with the body "Vitamin D, Omega-3 and Magnesium": what it logs **that day**, so a nutrient taken on Mondays isn't named on a Tuesday. A tap opens Today with that stack's log sheet.
- **Kept in step:** deleting a stack, renaming it, or adding or removing its nutrients (stack detail, Add to Stack…, a new nutrient's stacks) reschedules, so a deleted stack's reminder never fires.
- **Logging the stack** logs its nutrients, which silences their own reminders for the day too.
- **Today's next-reminder line** names it like a nutrient's: "Morning stack at 9:00", while something in it is due and it isn't done.

## 5. Scheduling (`ReminderSchedule`, `NotificationService`)

- **Times:** a usual-time reminder is a plan whose time is the learned one, or the starting time while learning or without Pro. A stack reminder is a plan of its own, with one time a day.
- **Budget:** both share the dose reminders' budget (60, after refills and recaps). A usual-time reminder is one a day, like the set time it replaces.
- **Identifiers:** `nutrient-<uuid>-reminder-HHmm-yyyyMMdd` as now, so a learned time that moves replaces the request. Stacks use `stack-<uuid>-reminder-HHmm-yyyyMMdd`.
- **Learning cost:** the usual time is computed once a day per nutrient and stack in usual mode, reading their last 28 days of records, and kept in memory for that day. It's not stored and not synced, because it only changes when a day completes.
- **Pro:** through `NotificationService.supplyRemindersEnabled`'s three states. Without Pro it plans the starting time. Every sync replans the `nutrient-` requests whatever the entitlement, so a pending one can't simply "stay". With the entitlement unknown (a cold background launch, say from the refresh task), it plans the **learned** time, so a background sync never moves 8:30 back to the starting time. The next sync with the entitlement known puts it right.

## 6. Pro and shipping

- **`ProFeature.reminders`:** "Reminders at your usual time", with the line "A nudge only when you're running late". Once shipped it joins the **Courses & schedules** group, which becomes "Courses, schedules & reminders": "Take something for a set time or on set days, and get a nudge when you're running late".
- **What's New 2.6:** "Reminders at your usual time" (PRO), and "Stack reminders" (free).
- **CloudKit:** every merge to `main` becomes a TestFlight build, so each field reaches production **in the phase that adds it**, before that phase merges, as SCHEDULES.md did. That's `CD_usualReminderMinutes` in phase 1, and `CD_reminderMinutes` and `CD_remindsAtUsualTime` on `LogStack` in phase 2. Development goes in with `cktool`, and production is the user's Console deploy, checked with `Tools/check-cloudkit-schema`. Each is added to `Tools/CloudKitSchema/fields.txt`.
- **Hidden until shipped:** `ProFeature.reminders` arrives in phase 1, not shipped (`isShipped` false), as `ProFeature.schedules` did. Until phase 3 flips it, the sheets' choice and the stack's whole Reminder row (set time too) show only in Debug builds, so phases 1 and 2 reach TestFlight with nothing half-shipped. The paywall row and What's New come with phase 3.

## 7. Build phases (one PR each)

1. **The usual time and nutrients:**
   - `UsualTime` (pure, tested: percentile, rounding, weekday split, limits, schedules);
   - `Nutrient.usualReminderMinutes`, with its CloudKit field in development, and the production deploy (the user's) before merging;
   - `ProFeature.reminders`, not shipped;
   - the scheduler;
   - the Reminders sheet choice and row text, Debug-only;
   - Pro gating and the lapse fallback.
2. **Stack reminders:** the `LogStack` fields, with their CloudKit fields in development and production before merging, then the Reminder row and sheet (Debug-only as a whole), scheduling, the done-today rule, and the notification and its tap.
3. **Shipping:** `ProFeature.reminders.isShipped` and its paywall group, What's New, and CHANGELOG, ROADMAP and CLAUDE.md.

Each phase is checked on nutrx iPhone 17 with the demo data. The demo set logs Vitamin D first at 8:00 every day, so it learns "Usually by 8:00" as it is; a test checks that. Light and dark, and a large text size.

**Not in this plan:** an action that logs the stack from the notification itself. It's possible later, through `StackLogging.log` from the notification handler, as refills do.
