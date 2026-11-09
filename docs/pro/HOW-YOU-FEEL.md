# How you feel — spec (#133, 2.8)

A daily check-in on how the day went, with questions the user picks (energy, mood, sleep, a headache…), each on a 1–5 scale or yes/no. Checking in is free. nutrx Pro adds patterns: how those answers line up with each nutrient ("After days you hit Magnesium, you rated your Sleep 4.1 on average, vs 3.4 after other days."). They're worked out on the device, as Trends with Apple Health are, and describe without advising.

Decided with the user on 2026-11-08:
- **Checking in is free; the patterns are Pro.** That covers the analytics card, the recaps' line and the doctor report's section. Because checking in starts free, it can never become Pro.
- **Questions:** presets, plus up to 5 of the user's own, each a 1–5 scale or yes/no.
- **When:** an evening card on Today, from a time the user sets (19:00 by default) until the day ends, with an optional reminder. One check-in a day, about that day.
- **Patterns** are judged like Health trends: per nutrient, the days its goal was met (or a day near an "at most" limit) vs the other days, over 28 days, with at least 4 days on each side.
- **The name is "How you feel".** "Check-in" stays the noon reminder's name (Settings → Notifications → Daily check-in reminder). The code says "feeling" for the new feature, to keep the two apart.

This document is the spec to build from. The build phases are at the end.

---

## 1. Questions

- **Presets.** The user turns on any of them; Energy, Mood and Sleep are on when How you feel is first turned on.

  | Preset | Reads | Kind | Ends |
  |---|---|---|---|
  | Energy | Energy | 1–5 | Low – High |
  | Mood | Mood | 1–5 | Poor – Great |
  | Sleep | Sleep last night | 1–5 | Poor – Great |
  | Focus | Focus | 1–5 | Low – High |
  | Stress | Stress | 1–5 | Low – High |
  | Digestion | Digestion | 1–5 | Poor – Great |
  | Headache | Headache | Yes / No | |
  | Aches | Aches or pains | Yes / No | |

- **Sleep is about the night before.** Answered on the evening of day D, it describes the night between D − 1 and D, so the patterns pair it with D − 1's intake, the way Health trends pairs a day with the night after it (§3). Every other question, the user's own included, is about the day it's answered on.
- **The user's own:** up to 5, each a name (1–40 characters) and a kind. A scale's ends read "Low – High".
- **Symbols:** each preset has its own SF Symbol, and the user's own questions share a neutral one. They're picked in phase 1 and checked in the SF Symbols app for the deployment target.
- **Order** is the user's, set by drag in Settings.
- **Removing a question** takes it off the card but keeps its answers (`isRemoved`), so History and the patterns still read them. Turning a preset back on brings the same question back, answers and all.
- **Renaming** is fine. **The kind can't change** once a question has answers, because a scale and yes/no don't mix; Settings says so.

## 2. Checking in (free)

- **Off until turned on:** from Settings → How you feel (a new row), or the What's New 2.8 card's Set up. Existing users are never prompted otherwise.
- **Settings → How you feel:**
  - the switch;
  - **Ask from**, a time (19:00 by default);
  - **Remind me**, off by default: a notification at that time, unless the user has already checked in. It asks for notification permission the way reminders do;
  - **Questions:** the presets as toggles, then the user's own with Add, rename, reorder and remove;
  - **a privacy note:** "Your answers stay on your devices and in your private iCloud, like your logs. nutrx never sees them."
- **The Today card, "How was today?":**
  - It shows from the Ask from time until the day ends, with the other cards under the day score: after the recap cards, before the banners.
  - Each question is a row with its symbol and name, then five buttons 1–5 (the end words under the first and last), or Yes and No.
  - An answer is saved when it's tapped, so there's no Save. Tapping it again clears it.
  - Once every question has an answer, the card folds to one line: "Checked in · Energy 4 · Mood 3…", with Edit. Its ✕ hides it until tomorrow.
  - At accessibility sizes the scale buttons go onto a row of their own under the question.
  - **VoiceOver:** each scale is one adjustable element ("Energy, 4 of 5"), and yes/no are two buttons.
- **A day with no answers** simply has no check-in: no catch-up prompt, no streak, nothing marked missed.
- **History's day detail** gets a "How you felt" card with the day's answers. It shows on days from when How you feel was turned on, and reads "No check-in" when there's nothing. Today and the 7 days before can be edited there; older days are read-only.
- **One check-in a day, about that day.** Each question has one answer per day; changing it updates that answer (§6 covers two devices).
- **The reminder:**
  - "How was today?" at the Ask from time, only while today has no answer. The body names the questions in the user's order, as a list formatted for the locale (`ListFormatter`): "Check in on Energy." for one, "Check in on Energy, Mood and Sleep." for three. With more than three it names the first three and the rest as a count: "Check in on Energy, Mood, Sleep and 2 more."
  - It's scheduled like the noon check-in: only the next one, refreshed when the app becomes active, after a check-in, and by the background refresh.
  - **The budget:** iOS keeps 64 pending requests. Today `ReminderSchedule.budget` gives refills and dose reminders 60, leaving 4: the noon check-in and up to three recaps in December. This reminder is one more fixed request, so the budget drops to 59, with its doc comment, its tests and CLAUDE.md's Supply & refills budget line ("what's left of the 60"), and the total stays at 64.
  - A tap opens Today, where the card is.
- **Notifications off:** the card still shows, and the Remind me row says notifications are off, with the way to allow them.

## 3. Patterns (nutrx Pro)

- **`FeelingTrends`** (pure), like `HealthTrends.state`: over the last 28 completed days, per nutrient, for each active question.
  - **A paired day:** the nutrient counts that day (`HistoryLog`'s rule: tracked, due under its schedule, its course running), something was logged in nutrx that day, and the question has an answer about that day. For Sleep, that's the next day's answer, about the night after (§1), so the newest pair needs today's Sleep answer.
  - **The groups:** days over the threshold vs the others. The threshold is the same as Health trends': three quarters of an "at most" limit, else the goal met (`AnalyticsGoal.isMet`, with each day's own goal, dose plans included).
  - **Readiness is per question.** A question with fewer than 14 paired days is still gathering, and a question added later doesn't hold back the others.
  - **The nutrient's state:**
    - `findings`, from the ready questions;
    - else `noPattern(checkedDays:)` if any question is ready, with the most paired days among the ready ones;
    - else `notEnoughData(pairedDays:)`, with the most paired days among the questions. The card then reads "9 of 14 days" for that question ("Sleep: 9 of 14 days").
  - **A finding:** each group has at least 4 days. On a 1–5 scale, the averages differ by at least 0.5. For yes/no, the share of yes days differs by at least 25 points.
  - **At most two findings** per nutrient, the largest first: the scale's gap out of 4, against the yes/no share's gap.
- **The words (`FeelingText`)** follow `HealthText`'s rules: day counts always, "on average", never a cause, never advice.
  - "After days you hit Magnesium, you rated your Sleep 4.1 on average, vs 3.4 after other days." Sleep says "after", since it's the night after.
  - "On days you hit Vitamin D, you rated your Energy 3.9 on average, vs 3.2 on other days."
  - "On days Caffeine passes 300 mg, you had a Headache on 5 of 9 days, vs 2 of 15 other days."
  - The footer: "Patterns in your own answers, not causes. Worked out on this iPhone." (naming the device).
- **Where they show:**
  - **A nutrient's analytics:** a "With how you feel" card, below "With Apple Health". It has the findings with two bars and the basis, or the state.
    - With How you feel off, anyone sees "Turn on How you feel".
    - A free user with answers sees the teaser with the PRO chip.
  - **The weekly and monthly recaps:** one line at the end, the clearest finding of the 28 days up to the period's end. Health's recap line is on the weekly recap only; this one is on both, since a month covers about its 28 days. The yearly recap gets none, because a 28-day pattern doesn't describe a year.
  - **The doctor report:** "Include how you felt", on when the period has answers. For each question it lists the period's average (or yes days) and days answered, plus the findings for the nutrients included. It's labelled as self-reported.
- **The paywall:** `ProFeature.feelingPatterns` ("Patterns in how you feel") joins the "Recaps, trends & reports" row. Its line must still let the plans start on an SE's screen (`PaywallUITests`).

## 4. Without Pro

- Checking in, the Settings page, the card, the reminder, History's answers and export stay free.
- The analytics card shows the teaser. The recaps and the report are Pro already.
- When Pro lapses, the patterns hide and nothing is deleted.

## 5. Export (free)

- Export data adds a second file when there are answers: `nutrx-how-you-feel-YYYY-MM-DD.csv`, with the columns `date,question,answer,scale` (for example `2026-11-08,Energy,4,1–5` or `2026-11-08,Headache,yes,yes/no`). It uses the same quoting, BOM and formula guard as the log.
- The log's own file doesn't change, so anything reading it keeps working.

## 6. Data

- **`FeelingQuestion`** (`@Model`):
  - `id` (UUID), `title`, `kindRaw` (`scale` / `yesNo`), `presetRaw` (nil for the user's own), `sortOrder`, `isRemoved`, `createdAt`;
  - `answers` (`[FeelingAnswer]?`, nullify).
- **`FeelingAnswer`** (`@Model`): `day` (the start of the local day), `value` (1–5, or 1 yes / 0 no), `updatedAt`, and `question` (optional).
- **`UserPreferences`:**
  - `feelingsEnabled` (false), `feelingsAskMinutes` (1140, which is 19:00), `feelingsReminderEnabled` (false);
  - synced, with the same reinstall check as `dailyReminderEnabled`: if iOS hasn't been asked for notifications, the reminder reads as off.
- **CloudKit:**
  - new record types `CD_FeelingQuestion` and `CD_FeelingAnswer`, plus the three `CD_UserPreferences` fields;
  - development is imported with `cktool`, and production is the user's Console deploy, both before phase 1 merges, since every merge to `main` becomes a TestFlight build (`Tools/check-cloudkit-schema`; `fields.txt` is rewritten by `CloudKitSchemaFieldsTests`).
- **Two devices:**
  - Answers are read per question and day, and the newest `updatedAt` wins, so no repair is needed.
  - A preset is one question per `presetRaw`: turning one on reuses the existing (removed) one. Two made on two devices before syncing are merged at launch and on remote changes, keeping the oldest and moving the other's answers to it, like `StackLogging.repairDuplicateIDs`.
- **Names:** no property name uses the words `HealthPrivacyTests` rejects (sleep, energy, health…). "Sleep" and "Energy" are values of `presetRaw`, never property names.
- **Privacy:**
  - The answers are the user's own entries, not Apple Health data. PLAN.md §0.5 is about Health data, which stays unstored.
  - The website's privacy policy gets a line about How you feel, and the support FAQ an entry.
- **Demo data** (`-screenshotDemoData`): Energy, Mood and Sleep answered on most of the seven weeks, with Sleep higher on the days after Magnesium was met (Sleep pairs with the day before, §1), so the analytics card has a finding for the App Store shots.

## 7. Rules it keeps (docs/pro/PLAN.md §0)

- It runs on the device only.
- No advice: "on average", day counts, and never "take more" or a cause.
- Nothing free becomes Pro: checking in is free from the start.
- Apple Health data is still never stored.

## 8. Build phases (one PR each, in order)

1. **The data and Settings → How you feel:**
   - the models, the preferences and the presets;
   - the user's own questions;
   - the Settings page;
   - the CloudKit schema (development, and production by the user, both before this merges: §6);
   - tests for the questions, presets, merging duplicates and the schema fields.
2. **Checking in:**
   - the Today card;
   - History's "How you felt" with editing;
   - the reminder, with `ReminderSchedule.budget` down to 59;
   - export's second file;
   - the demo data;
   - What's New 2.8.
3. **Patterns (Pro):** `FeelingTrends` and `FeelingText`, the analytics card, and the teaser.
4. **Pro's other places:** the recaps' line, the report's section, `ProFeature` and the paywall row, and the docs.

2.8's smaller items are their own PRs, in any order between the phases:
- Today's date at AX5 (#360);
- the paywall opened from Settings on an SE (#352), with its UI test (#362);
- Siri on Apple Watch (#57, which needs a check on a real Watch);
- the website's screenshot tools (#361).
