# Schedules — spec (nutrx Pro, #132)

A nutrient can follow a schedule instead of every day: Mon / Wed / Fri, every other day, 5 days on and 2 off, or 3 times a week. Off days never read as missed. Planned for 2.4.

Decided with the user on 2026-10-23: all four kinds below, off days in a collapsed **Not today** section on Today, and screens built from existing patterns (no designer mockups). This document is the spec to build from; the build phases are at the end.

---

## 1. The kinds

| In the sheet | Example | Stored as |
|---|---|---|
| **Every day** | today's behaviour, the default | nothing (`""`) |
| **On certain days** | Mon, Wed, Fri · or just Sun for a weekly dose | the weekdays |
| **Every few days** | every other day, every 3rd day | a cycle: 1 on, N − 1 off |
| **On and off** | 5 days on, 2 off · 3 weeks on, 1 off | a cycle: X on, Y off, from a start day |
| **Times a week** | 3 times a week, any days | a weekly count (1–6) |

"Every few days" is a cycle with one day on, so the rule has three kinds: **weekdays**, **cycle** and **weekly**. The first two are *fixed*: they decide which days are dose days. **Weekly** is flexible: any day can count, until the week's count is reached.

Limits: weekdays need at least one day; every few days is 2–30; on and off is 1–60 days each (weeks are multiples of 7 days); times a week is 1–6 (7 is every day). **Times a week is only for "At least" goals**: "stay under 400 mg three times a week" doesn't mean anything. On a nutrient with another goal type the option is shown off, with a footnote.

## 2. The one rule

`NutrientSchedule` (pure, in `Nutrient.swift` next to `NutrientCourse`, so the widgets and the Watch have it), tested like `NutrientCourseTests`:

- `isDoseDay(_ day:)` for fixed kinds; every day for **Every day**.
- For weekly: `weekProgress(metDays:in week:)` → "1 of 3 this week", and whether the week is done.
- Weeks run **Monday to Sunday**, whatever the locale's first weekday, the same as the weekly recap.
- Combined with courses in one helper, `Nutrient.counts(on:)`: a day counts when the course includes it (`NutrientCourse.includes`) **and** the schedule makes it a dose day. Every place that reads `NutrientCourse.includes` today (11 files: Today, History, streaks, analytics, the weekday pattern, reminders, stacks, Health insights, the widgets, the Watch list and the complications) moves to it.

**Fixed kinds:** a dose day is exactly a day for a daily nutrient. An off day is like a day before `createdAt`: not counted anywhere, never missed, no reminders.

**Weekly:** a day counts **only when the goal was met that day**. It then adds a met goal to the day's score, History and the streak. A day it isn't met isn't a miss, so a weekly nutrient never breaks a daily streak or turns a calendar day amber. Whether the week's count was reached shows where weeks are the unit: analytics ("3 of 4 weeks"), the weekly recap and the report. A week that falls short does **not** break the daily streak: the streak stays a daily idea.

## 3. Changing a schedule doesn't rewrite History

Each schedule applies **from the day it was set**. Earlier days keep the schedule they had (or every day). So turning Tuesdays off doesn't turn last month's missed Tuesdays into rest days, and a streak doesn't jump when a schedule changes.

Stored as a short list of `(from day, schedule)` pieces in one field, newest last. Days before the first piece are every day. Calendar days are stored as `yyyyMMdd` and rebuilt in the reading calendar, as course gaps are, so a time zone change never moves a dose day. Cycles count from their own start day.

## 4. Where it shows

| Place | Fixed kinds (weekdays, cycles) | Weekly |
|---|---|---|
| **Today** | On dose days, a normal card. On off days, in **Not today**. | A normal card each day until the week is done, with "1 of 3 this week" on its status line. The day it's done it stays, Done; from the next day it's in **Not today** until Monday. |
| **Day score** | Counts on dose days. | Counts on a day only once met that day. |
| **History, streaks** | Dose days only. | Met days only, as a met goal. |
| **Analytics** | Hit rate over dose days. The weekday heatmap only shows weekdays that have dose days; a weekday with none is blank, not 0 %. | Hit rate as weeks: "3 of 4 weeks". The bars stay daily. No weekday heatmap or weakest-day line: there are no set days. |
| **Weekly recap** | Dose days in the week ("You hit Vitamin D on 3 of 3 days"). | "Vitamin D: 3 of 3 this week". |
| **Report for your doctor** | Dose days with entries count, as today. | A "Weeks met" box instead of the hit rate. |
| **Dose reminders** | On dose days only. | Each day until the week is done. |
| **Refill reminders, supply** | Unchanged: the daily-use estimate already spreads over the days. | Unchanged. |
| **Stacks** | A stack skips entries not due today, as for an ended course. | Skips the entry once the week is done. |
| **Widgets, Watch, complications** | As Today: dose days only. | As Today: until the week is done. |
| **Siri** | Logs any nutrient any day. It's an explicit request. | Same. |
| **Health trends** | Paired days are dose days. | Paired days are met days. |

**Logging on an off day** works, from the Not today section or Siri. It's kept and shows under History's "Also logged", but doesn't count.

## 5. Today: Not today

A collapsed section at the end of Today, after the groups, like My Nutrients' **Finished**. Its header is "NOT TODAY" with a count and a chevron; its rows have an icon tile, the name and when it's next: "Next: Sun", "Next: tomorrow", "Done this week · back Mon". Tapping a row opens the log sheet, to log anyway. It's collapsed by default, its open state is kept per device (`@AppStorage`), and it's hidden when empty. It isn't shown in the column layouts' side column; on large screens it follows the last group.

## 6. Setting a schedule

- **Nutrient form:** a **Schedule** row right after Duration, a `ProGatedButton` (free users see the PRO chip and get the paywall). It reads "Every day", "Mon, Wed, Fri", "Every 2 days", "5 on, 2 off" or "3 times a week" (`ScheduleText.summary`). It's in the new-nutrient form too, but not in onboarding.
- **`ScheduleSheet`**, built like `DurationSheet`:
  - The five options as a list of choices (five don't fit a segmented control).
  - The chosen one's controls:
    - **On certain days:** seven weekday toggles in the locale's order.
    - **Every few days:** a stepper ("Every 2 days") and a Starting date.
    - **On and off:** "Days on" and "Days off" steppers, with a days / weeks switch, and a Starting date.
    - **Times a week:** a stepper.
  - A footer sentence: "Next: Sun 25 Oct, then Wed 28 Oct." or "Any 3 days a week, Monday to Sunday."
  - Cancel / Done.
- **The paywall:** a seventh `ProFeature`, **Schedules** ("Take something on set days"), listed once it ships (`isShipped`).
- **If Pro lapses:** existing schedules keep working, as courses do. Setting or changing one needs Pro.

## 7. Data

- `Nutrient.scheduleRaw: String = ""`. Empty means every day; otherwise the pieces of §3, for example `20261023=days:1,4,6` or `20261023=cycle:5:2;20261101=week:3`. Weekdays use `Calendar` numbers (1 = Sunday).
- It's a CloudKit-safe scalar with a default. **Its field (`CD_scheduleRaw`) must be in the production CloudKit schema before the first TestFlight build with it:**
  - Development is imported with `cktool`, as for courses.
  - Production is the user's Console deploy.
  - `Tools/CloudKitSchema/fields.txt` gets the field, and `Tools/check-cloudkit-schema` checks it before any upload.
- No change to `IntakeRecord`. Logs are logs whatever the schedule.

## 8. Rules it keeps

Everything runs on the device. There's no advice on what or when to take: the user sets the schedule, and nutrx never suggests one. **Every day stays free**, and nothing that's free today becomes Pro. Health data is still never stored.

## 9. Build phases (one PR each, in order)

1. **The rule.** `NutrientSchedule`: kinds, encode/decode with history, dose days, week progress. Also `Nutrient.scheduleRaw`, `Nutrient.counts(on:)`, the CloudKit fields file and tests. Development schema with `cktool`; ask the user for the production deploy.
2. **Fixed kinds everywhere.** Every reader of `NutrientCourse.includes` moves to `counts(on:)`, plus the Not today section, the heatmap blanks and the recap wording. With a debug-only way to set a schedule, it can be tested before the sheet exists.
3. **The Schedule sheet and form row.** Also `ScheduleText` and `ProFeature.schedules`, still not `isShipped`.
4. **Times a week.** The Today status line, week counting in analytics, the recap and the report, and reminders until the week is done.
5. **Ship.** `isShipped`, the What's New entry for 2.4, docs (CLAUDE.md, CHANGELOG, ROADMAP), and screenshots in the PRs. The production schema must already be deployed.

Phases 2–4 each come with simulator checks and screenshots in their PR, as usual.
