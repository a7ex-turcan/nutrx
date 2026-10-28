# Monthly and yearly recaps — spec (nutrx Pro, #136)

The weekly recap, zoomed out: "Your October" at the start of each month, and a year in review. Same rules and the same parts as the weekly recap (CLAUDE.md, nutrx Pro: Weekly recap): facts from the `HistoryLog`, words from `RecapText`, an optional on-device rewording checked against the facts. Planned for 2.6.

Decided with the user on 2026-10-28:
- **Where:** the recap screen gets a **Week / Month / Year** switch. History's "Weekly recaps" row becomes **Recaps**.
- **Notifications:** "Your October in nutrx" on the 1st at 18:00 and "Your 2026 in nutrx" on 1 January at 18:00, each only when there's something in it. Settings → Notifications → **Weekly recap** becomes **Recaps** and covers all three.
- **Today:** "Your October" on the 1st and 2nd, "Your 2026" from 1 to 7 January, like the week card, with ✕ to hide it.
- **The year:** the full year from 1 January; before that, the Year tab shows **"2026 so far"**.

---

## 1. Rules it keeps (docs/pro/PLAN.md §0)

- **Facts, never advice.** It says what happened ("Vitamin D was your steadiest"), never what to take or change.
- **On the device only.** Built from the store; the rewording uses the on-device model with the same checks as the weekly one, or the template.
- **Nothing free becomes Pro.** History, streaks and the calendar stay as they are; recaps were Pro already.
- **A goal counts on a day exactly as in History and for streaks**, because every fact comes from the same `HistoryLog`. That includes rest days and schedules (#132), courses (#99), and weekly nutrients counted by their met days.
- **Only completed days count.** The running month or year (`lastDay` = yesterday) never reads today as missed, as in the weekly recap.

## 2. The month (`MonthlyRecap`, pure, `MonthlyRecapTests`)

Built from a `HistoryLog`, for a calendar month (the 1st to its last day). From the next month's 1st it's the whole month; before that it's the month so far.

| Fact | Rule |
|---|---|
| **Goals met** | "412 of 540 goals met": every counted day's goals, as in the week. A day with nothing logged meets nothing. |
| **Full days** | Days with every goal met (the streak rule), out of the month's days that aren't rest days: "18 of 30 full days". The hero ring is that fraction. |
| **Days logged** | "Logged 27 of 31 days." |
| **Steadiest / slipped / over limit** | The same picks as the week (`WeeklyRecap.picks`) over the month's counted days. |
| **Best streak this month** | The longest run of full days inside the month (rest days step over, as in `StreakService`). Left out with Streaks off, or under 2 days. |
| **Weekday you tend to miss** | The weekday most often not a full day in the month: missed at least twice, and more than any other weekday. |
| **Against last month** | "Up from 68 % in September" or "Down from 81 %", from the goals-met rate. Shown only when last month had at least 7 counted days and the gap is at least 3 points. |
| **Weekly nutrients** | Listed apart, as "3 of 4 weeks met", counting only weeks wholly inside the month and under that schedule. |

The month starts on the 1st whatever the locale's first weekday; weeks inside it are still Monday to Sunday (`NutrientSchedule.weekStart`).

## 3. The year (`YearlyRecap`, pure, `YearlyRecapTests`)

Built from the same log for a calendar year. From 1 January it's the whole past year; until then, the year so far ("2026 so far").

| Fact | Rule |
|---|---|
| **Goals met** and **full days** | As for the month, over the year: "3,960 of 5,400 goals met · 201 full days". |
| **Month by month** | Twelve small bars of each month's goals-met rate (empty for months with nothing counted); the best month is highlighted. |
| **Best month** | The highest rate among months with at least 10 counted days ("May, 92 %"). |
| **Longest streak** | The longest run of full days that ended in the year. Left out with Streaks off. |
| **Steadiest nutrient of the year** | The best hit rate among nutrients counted on at least 30 days. |
| **Days logged** and **the month you logged most** | "Logged 311 days; most in March (31 of 31)". |
| **Since you started** | Shown only in a nutrient's first year: "You started tracking Magnesium in April". |

## 4. Words (`RecapText`, `RecapPhrasing`)

- **Template sentences**, past tense for finished periods and present for "so far":
  - Month: "In October you met 76 % of your goals and had 18 full days. Vitamin D was your steadiest. Omega-3 slipped on weekends."
  - Year: "In 2026 you logged on 311 days and met 73 % of your goals. Your best month was May."
- **The rewording** is reused with the period's facts. It's cached per period in the same store as the weekly one (`nutrx.recapSummaries`, keys `2026-10` and `2026`, the last 12 months and 3 years). The same checks apply: numbers from the facts only, no advice words, the steadiest name kept.
- **Ranges:** "1 – 31 October", "October 2026", "2026", "2026 so far".
- **Share text:** the range, headline and summary, as for the week.

## 5. The screen

- **The recap screen** (now titled "Recaps"; `WeeklyRecapView` grows into `RecapsView`) has a segmented **Week / Month / Year** at the top. It opens on Week from History, and on the tab that matches a notification or Today card.
- **Month:** a forest hero with a fraction ring of full days, "October 2026", "412 of 540 goals met" and the summary. Then:
  - fact cards in two columns (one, without icons, at accessibility sizes, as for the week);
  - a small month grid (`MonthGrid`) with the full days lit;
  - "Earlier months": the last 12 months with something in them, as mini rings.
- **Year:** the hero ("2026" or "2026 so far", the goals-met ring), then the month-by-month bars, then fact cards and "Earlier years".
- **Nothing yet:** "Your first monthly recap arrives on 1 November", with the days logged so far. The Year tab is never empty, since it shows "so far".
- **Large screens:** the same 640 pt column as the week (`readableColumn()`).

## 6. Around the app

- **History row:** "Recaps".
  - Pro: "Latest: October · 412 of 540 goals", or the latest week's line before the first month is in.
  - Free: the PRO chip and "A short summary of each week, month and year", which opens the paywall.
- **Today card** (`RecapTodayCard`, one card): "Your October" on the 1st and 2nd, "Your 2026" from 1 to 7 January, "Your week" from Sunday 18:00 through Monday. When two would show, the longer period wins (year, then month, then week). ✕ hides that period's card (`nutrx.dismissedRecapMonth`, `nutrx.dismissedRecapYear`, beside the week's key). A tap opens the recap on that tab, in a sheet.
- **Notifications** (`RecapSchedule`, scheduled with the others):
  - **When:** the 1st at 18:00 for the month just ended, and 1 January at 18:00 for the year.
  - **Only with data:** each needs something logged in that period.
  - **Body:** it has numbers only when set up on that day, as for the week.
  - **Budget:** two slots of the 60, besides the week's one.
  - **Category and action:** `nutrx.recap`, so a tap opens the recap on the right tab, and **Turn off recaps** turns all three off.
- **Settings → Notifications:** "Weekly recap" becomes **Recaps** ("Weekly, monthly and yearly"). It keeps the per-device key `nutrx.weeklyRecapNotifications`, so an existing choice carries over.
- **Paywall:**
  - `ProFeature.recap`: "Recaps", "Your week, month and year, summarised".
  - The Recaps, trends & reports group reads "Your week, month and year summarised, Apple Health trends, and a PDF for your doctor".
  - The welcome name becomes "recaps".

## 7. Data and speed

- **Month:** the recap reads that month's log (`HistoryViewModel.loadLog(from:)`); "Earlier months" reads twelve months once per refresh.
- **Year:** the year's log, built once per refresh and kept while the screen is open (a year of three-times-a-day logging is about 3,000 records).
- **Not built on Today's refresh:** the Today card builds only the period it shows, as the week's card does.
- **Check it** with the demo data (seven weeks), and with a year of generated data in a test: `YearlyRecapTests` builds one from 365 days of logs and asserts how long it takes.

## 8. Build phases (one PR each, in order)

1. **The month:** `MonthlyRecap` (pure, tested), `RecapText` for months, and the rewording keyed by month.
2. **The screen:** `RecapsView` with Week and Month, the History row "Recaps", and Today's month card.
3. **The year:** `YearlyRecap` (pure, tested, with the timing test), the Year tab with its bars, and Today's year card.
4. **Notifications and shipping:**
   - the monthly and yearly notifications;
   - Settings "Recaps";
   - the paywall and `ProFeature` wording;
   - a 2.6 What's New item;
   - CHANGELOG, ROADMAP and CLAUDE.md.

Each phase comes with screenshots on nutrx iPhone 17 with demo data, light and dark, and the Debug flag `nutrx.debug.showRecapCard` extended to the month and year cards.

**Not in this plan:** the shareable "Year in nutrx" image (#126) can build on the Year tab later.
