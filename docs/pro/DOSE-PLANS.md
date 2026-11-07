# Dose plans — spec (nutrx Pro, #135)

A nutrient's goal can follow a plan of steps that the user, or their doctor, sets: "200 mg for a week, then 400 mg", or a taper down ("400 mg, 300 mg, 200 mg, then stop"). nutrx never suggests the steps. Planned for 2.7.

Decided with the user on 2026-11-07:
- **The end is chosen per plan:** after the last step the plan either keeps its last goal (a ramp-up that settles), or stops, which ends the nutrient's course as a course's end does.
- **A step sets only the goal.** The each-tap amount stays as the user set it.
- **Every goal type:** at least (the amount), at most (the limit, to taper caffeine) and between (both ends).
- **Without Pro the plan holds** at the step in effect, and resumes where it left off if Pro comes back.

This document is the spec to build from. The build phases are at the end.

---

## 1. What a plan is

- **Steps**, in order, from a **start day** (today, or a later day). There are 2–6 of them. A plan with one step would just be a goal.
- **Each step** is a goal for a length:
  - **The goal** takes the nutrient's goal type: an amount for at least, a limit for at most, or a minimum and a maximum for between. It's checked the way the form checks a goal: above zero, and for a range, the maximum above the minimum.
  - **The length** is 1–90 days. It's set as days or as weeks (a multiple of 7).
- **Then**, after the last step:
  - **Keep the last goal:** the plan settles there, with no end.
  - **Stop:** the nutrient's course ends on the last step's last day.
- **Examples:**
  - "200 mg for 7 days, then 400 mg for 14 days, then keep 400 mg."
  - "Caffeine at most 400 mg for 2 weeks, 300 mg for 2 weeks, 200 mg for 2 weeks, then stop."
- **Before the start day,** the nutrient's own goal applies: `dailyTarget` / `upperBound`, here called the **base goal**.
- **The each-tap amount** (`step`) and the goal type don't change with the plan.
- **Steps count calendar days, not dose days.** With a schedule (#132), "for 2 weeks" is 14 days, whatever the schedule makes due in them. The plan only decides what the goal is on whichever days count.

## 2. The one rule

`NutrientDosePlan` (pure) goes in `Nutrient.swift` next to `NutrientCourse` and `NutrientSchedule`, so the widgets, the Watch and the complications have it too. It's tested in `NutrientDosePlanTests`.
- `goal(on day:) -> NutrientGoal?` gives the plan's goal for a day, or nil, which means the base goal (before the plan, or after a removed one).
- `step(on day:)` gives the step's number, the step count and the step's last day, for "Step 2 of 3 · until Fri 20 Nov". It's nil outside the steps, and when the last goal is being kept.
- `held(on:)` tells whether the plan is held (§6).

`Nutrient.goal(on day:) -> NutrientGoal` (target, upper bound) is the plan's goal when it has one for that day, else the base goal. **Every goal reader goes through it**:
- **The current goal**, through `GoalProgress(nutrient:current:on:)`, which defaults to today:
  - Today's cards and the day score;
  - the log sheet (its ring and "Fill to goal");
  - the stack sheet's totals and Not today;
  - the widgets, the Nutrient widget and the controls;
  - the Watch list and the complications;
  - the Siri answers ("3,000 of 4,000 IU today");
  - supply costs' fallback dose.
- **Each past day's own goal:**
  - `HistoryLog`, through its `HistoryNutrient`, which gets a goal per day in place of its one target, and so `StreakService`, History's calendar and days, and the recaps (week, month and year);
  - `AnalyticsSummary`, `WeekdayPattern` and `DailyIntakeChart`;
  - the doctor report.

No reader reads `dailyTarget` / `upperBound` for a day any more. The form edits the base goal through them, as now.

## 3. Changing a plan doesn't rewrite History

As with schedules (#132):
- A plan is stored as the goals it gives, each **from its day**. Past days keep the goal they had.
- **Editing a plan** (its steps, their lengths or its end) applies **from today**. Days before today keep their pieces, and a change can't make last week's misses into hits.
- **Removing a plan** also applies from today:
  - From today the base goal is back.
  - Removing a plan that was keeping its last goal first makes that goal the base goal, so nothing jumps.
- **Calendar days are stored as `yyyyMMdd`** and rebuilt in the reading calendar, as course gaps and schedules are, so a time-zone change never moves a step.

The base goal still behaves as it does now. Editing it in the form re-judges the days that aren't covered by a plan piece, as editing a goal always has. While a plan applies today, the form's goal card hands over to the plan (§5).

## 4. Where it shows

| Place | With a plan |
|---|---|
| **Today** | The ring, the value ("**200** / 400 mg") and the status line use today's goal. The third line reads "⤴ Step 2 of 3 · until Fri" (`DosePlanText`). It shares the line like the course's "Last day" (#128), so the card's height doesn't change. A step's last day reads "Step 2 of 3 · last day", and "Last day" takes over on the plan's very last day when it stops. While held: "Plan paused". |
| **Log sheet** | The header's goal and "Fill to goal" use today's goal. |
| **Day score, streaks, History** | Each day is judged by its own goal: "met" is `GoalProgress.countsAsMet` against that day's piece. History's day rows read "**200** / 200 mg" with that day's goal. |
| **Analytics** | The header reads "At least 400 mg a day · Step 2 of 3, until 20 Nov". The stats judge each day by its goal. The chart's goal rule is **stepped**: one dashed segment per goal across its days, with its label ("Goal 400") at today's segment. A range draws Min and Max per segment. The heatmap judges each day by its goal. |
| **Recaps** | Each day by its goal (through `HistoryLog`). The template sentence stays as it is: it counts days met, not amounts. |
| **Report for your doctor** | Each day by its goal. A nutrient's section lists the plan ("Dose plan: 200 mg until 16 Nov, then 400 mg"), so the doctor sees the steps, and the summary table's goal reads "200 → 400 mg". It stays labelled as self-reported. |
| **Widgets, Watch, complications, controls** | Today's goal. |
| **Reminders** | Unchanged: they don't depend on the goal. |
| **Supply** | The daily use still comes from the logs. Without enough history, the fallback dose (`SupplyCost`, the sheet's sentence) is today's goal. |
| **Stacks** | Unchanged: an entry's amount is its own, and the stack sheet's totals use today's goal. |

## 5. Setting a plan

- **The nutrient form** gets a **Dose plan** row right after Schedule, a `ProGatedButton` (free users see the PRO chip and get the paywall). It reads "None", "200 → 400 mg · step 1 of 2", "400 mg · plan kept" (after the steps, keeping) or "Paused" (`DosePlanText.summary`). It's in the new-nutrient form too, starting the day it's added, but not in onboarding.
- **`DosePlanSheet`**, built like `DurationSheet` and `ScheduleSheet`:
  - **Starting:** Today, or a date picker, today on. A running plan shows its start, read-only. Edits apply from today.
  - **The steps:** a list of rows, each with the goal fields for the goal type (the form's fields, `NutrientFormFields`' goal pieces) and the length ("for 7 days", with a stepper and a days / weeks switch). Add step goes up to 6, and swipe deletes down to 2. A new plan starts with two steps, both at the current goal, for the user to change.
  - **Then:** a choice between **Keep the last goal** and **Stop**, which ends the course.
  - **The footer sentence:** "200 mg until Sun 15 Nov, then 400 mg from Mon 16 Nov, and keeps 400 mg."
  - **The no-advice line:** "nutrx doesn't suggest amounts. Set the steps you or your doctor chose."
  - **Remove plan**, when editing, with a confirmation that says past days keep their goals.
  - Cancel / Done.
- **The form's goal card while a plan applies today** is replaced by a summary: "Set by your dose plan: 400 mg a day until Fri", with **Edit plan**. Before the plan starts, or after it was removed, the goal card is as now.
- **With Duration:**
  - A plan that **stops** sets the course's end (`Nutrient.setCourse(endDate:)`, its last step's last day). The Duration row then reads "Ends with the dose plan · Sun 6 Dec" and opens the plan sheet.
  - A plan that **keeps** leaves Duration alone. If a course ends before the plan does, the sheet's footer says the plan is cut short on that day.
- **The paywall:** dose plans join the "Courses, schedules & reminders" group (`ProFeatureGroup.plans`). Its title and subtitle change in the ship phase, worded so the plans still start on screen on the iPhone SE, which the paywall UI tests (#339) can check.

## 6. Without Pro

- **The hold:** from the first day the app knows Pro isn't active, the goal stays at the step in effect that day, and later steps wait.
  - "Knows" means `ProAccess.refreshEntitlement` came back false, never an unknown entitlement such as a cold background launch.
  - The hold day is stored in the plan, so it syncs and every device, widget and the Watch holds the same way. It's plan data, not the entitlement, which is still never stored.
  - A held plan that was going to **stop** doesn't stop. Its course end is lifted while held, and set again on resume.
- **Pro comes back:** the plan **resumes where it held**. The remaining steps, and the stop day, move later by the days it was held, and the hold is cleared.
- **Setting or editing a plan needs Pro.** **Removing one doesn't**: it never takes anything free away.
  - **The row:** while held, it reads "Paused" with the PRO chip.
  - **The sheet:** it opens read-only, with "Paused without nutrx Pro since 20 Nov" and Remove plan.
- **The base goal stays free,** as every goal is today.

## 7. Data

- **The field:** `Nutrient.dosePlanRaw: String = ""`. Empty means no plan.
- **What it stores:**
  - the goal pieces, each from its day, with an upper bound for a range;
  - the plan's definition, for editing: the start day, the steps' goals and lengths, and keep or stop;
  - the hold day, when there is one.

  The exact encoding is settled in phase 1, with round-trip tests, in the style of `scheduleRaw`'s pieces (`20261110=200;20261117=400`).
- **CloudKit:** it's a CloudKit-safe scalar with a default. **Its field (`CD_dosePlanRaw`) must be in the production schema before the first TestFlight build with it:**
  - development is imported with `cktool`;
  - production is the user's Console deploy;
  - `Tools/CloudKitSchema/fields.txt` gets the field, and `Tools/check-cloudkit-schema` checks it.
- **No change to `IntakeRecord`.** Logs are logs, whatever the goal.

## 8. Rules it keeps (docs/pro/PLAN.md §0)

- **On the device:** everything runs there.
- **No advice:** nutrx never suggests steps, amounts or a taper. The sheet says so, and the steps start at the user's own goal.
- **Nothing free becomes Pro:** the base goal stays free, and a plan is new. Removing a plan is always allowed.
- **Health data:** untouched and never stored.

## 9. Build phases (one PR each, in order)

1. **The rule and today's goal:**
   - `NutrientDosePlan` (encode / decode, `goal(on:)`, `step(on:)`, edits from today, removal, hold and resume) and its tests;
   - `Nutrient.dosePlanRaw`, `Nutrient.goal(on:)` and `GoalProgress(nutrient:current:on:)`;
   - **today's readers** move to it: Today, the log sheet, the stack sheet, the widgets, the controls, the Watch, the complications, the Siri answers and the supply fallback;
   - a Debug-only way to set a plan, like `ScheduleDebug`;
   - `ProFeature.dosePlans`, not shipped;
   - the CloudKit field in development, and the production deploy (the user's) before merging.
2. **Past days:** `HistoryNutrient` gets a goal per day, so `HistoryLog`, `StreakService`, History, the recaps, `AnalyticsSummary`, `WeekdayPattern` and the report judge each day by its goal. Also the stepped goal rule in the chart, and the report's plan line.
3. **The sheet:**
   - the Dose plan row, `DosePlanSheet` and `DosePlanText`;
   - Today's step line and the analytics header;
   - the form's goal card while a plan applies;
   - Duration with a plan that stops;
   - Remove plan.
4. **Without Pro and shipping:**
   - the hold and resume, wired to `ProAccess`, and the "Plan paused" lines;
   - `isShipped`, the paywall group's wording, and the What's New entry for 2.7;
   - a plan in the demo data for screenshots;
   - CLAUDE.md, CHANGELOG and ROADMAP.

Phases 2–4 each come with simulator checks and screenshots in their PR: the iPhone 17 and the SE, light and dark, and a large text size. Phase 2 needs a plan on a demo nutrient (Magnesium), so its history shows two goals.
