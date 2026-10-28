# Nutrx — Product Roadmap

> **Core promise (all versions):** Private by design. All tracking features free forever. No ads. No accounts. No servers.

---

## Feature Tracker

### MVP 1 — Core Tracking Loop ✅

| Feature | Status |
|---|---|
| User onboarding (name, birthday, weight, height) | ✅ Shipped |
| User-defined nutrients (name, unit, step, daily target) | ✅ Shipped |
| Today tab (+/− logging, custom amounts, exclusions) | ✅ Shipped |
| History tab (read-only, grouped by day) | ✅ Shipped |
| My Nutrients tab (create, edit, delete, reorder) | ✅ Shipped |
| Profile + About via profile menu | ✅ Shipped |
| Settings screen with daily check-in reminder | ✅ Shipped |
| SwiftData persistence, fully offline | ✅ Shipped |

### MVP 2 — Retention & Reach ✅

| Feature | Status |
|---|---|
| Per-nutrient dose reminders | ✅ Shipped (v1.1) |
| Nutrient notes | ✅ Shipped (v1.1) |
| Home screen & lock screen widgets | ✅ Shipped (v1.4) |
| History monthly section headers | ✅ Shipped (v1.1) |
| Streaks & consistency tracking | ✅ Shipped (v1.5) |
| Nutrient grouping / categories | ✅ Shipped (v1.2) |
| Group UX polish (completion counts, inline creation, haptics) | ✅ Shipped (v1.3) |

### MVP 3 — Ecosystem & Sync ✅

| Feature | Status |
|---|---|
| iCloud sync (CloudKit + SwiftData) | ✅ Shipped (v1.6) |
| In-app review prompt | ✅ Shipped (v1.6) |
| Expandable nutrient cards (Today intake breakdown) | ✅ Shipped (v1.7) |
| Analytics & charts (per-nutrient) | ✅ Shipped (v1.8) |
| Apple Health: read (Pro trends) | ✅ Shipped (v2.1) |
| Apple Health: write logged nutrients (HealthKit write) | 📋 Planned (#124) |

### Pre-Pro Sprint — Polish & Retention ✅

| Feature | Status |
|---|---|
| Nutrient goal types (minimum / maximum / range) | ✅ Shipped (v1.9) |
| Apple Watch companion app | ✅ Shipped (v1.10) |
| Data export (CSV) | ✅ Shipped (v2.1) |
| Quick-log stacks / templates | ✅ Shipped (v2.1) |
| Siri & App Shortcuts | ✅ Shipped (v2.1) |

### nutrx Pro — v2.1 ✅

Optional subscription or lifetime purchase that only adds features; everything else stays free. Plan: `docs/pro/PLAN.md`. It replaces the old "MVP 4 — Pro Tier & AI" list:
- "Daily AI insights" became the weekly recap (and the weekday pattern in free analytics).
- "Smart target suggestions" is out: nutrx doesn't suggest amounts or targets (PLAN.md principle 3).
- "Natural language logging" is out: no chat box (principle 4). Siri and Shortcuts log by name instead, for free.

AI runs on the device only.

| Feature | Status |
|---|---|
| Pro subscription (StoreKit 2): $1.99 / month, $14.99 / year with a free week, $29.99 lifetime | ✅ Shipped (v2.1) |
| Supply & refills | ✅ Shipped (v2.1) |
| Scan a label (on-device) | ✅ Shipped (v2.1) |
| Weekly recap (on-device wording) | ✅ Shipped (v2.1) |
| Trends with Apple Health (read only) | ✅ Shipped (v2.1) |
| Report for your doctor (PDF) | ✅ Shipped (v2.1) |
| Launch: App Store listing, review, website | ✅ Shipped (v2.1, 16 Oct 2026) |
| Streak freeze / grace period | 📋 Later, outside the plan (#125) |
| Shareable streak card | 📋 Later, outside the plan (#126) |

### v2.2 — Quality of life ✅

Released on the App Store on 18 Oct 2026 (build 63, phased release; tag `v2.2`).

| Feature | Status |
|---|---|
| Nutrients for a set time / courses (Pro) | ✅ Shipped (v2.2, #99) |
| Select several nutrients to move or delete | ✅ Shipped (v2.2, #98) |
| Free / PRO chip on Today | ✅ Shipped (v2.2, #101) |
| Your data (export, doctor report) in History | ✅ Shipped (v2.2, #103) |
| Where Apple Health insights appear | ✅ Shipped (v2.2, #102) |
| Stacks tab button order | ✅ Shipped (v2.2, #100) |
| Deleted nutrients stay deleted (iCloud) | ✅ Shipped (v2.2, #114) |
| iCloud Sync switch works, per device | ✅ Shipped (v2.2, #113) |
| "0 of 1 goal met" wording | ✅ Shipped (v2.2, #115) |
| VoiceOver in Settings (Groups +, About) | ✅ Shipped (v2.2, #120) |
| App Store release | ✅ Shipped (v2.2, 18 Oct 2026) |

### v2.2.1 — Fixes ✅

Released on the App Store on 21 Oct 2026 (build 128, phased release; tag `v2.2.1`).

| Fix | Status |
|---|---|
| New reminders show straight away; no duplicate times | ✅ Shipped (v2.2.1, #163) |
| My Nutrients at large text sizes | ✅ Shipped (v2.2.1, #108) |
| VoiceOver on the paywall while purchasing / loading | ✅ Shipped (v2.2.1, #94) |
| "Discard changes?" in the nutrient form | ✅ Shipped (v2.2.1, #74) |
| Disabled Add / Save look disabled in dark mode | ✅ Shipped (v2.2.1, #73) |
| Next reminder and notification banner refresh right away | ✅ Shipped (v2.2.1, #44, #45) |
| Courses listed on the Pro screens | ✅ Shipped (v2.2.1, #147) |

### v2.3 — Large screens ✅

Released on the App Store on 23 Oct 2026 (build 148, phased release; tag `v2.3`).

| Feature | Status |
|---|---|
| iPad: readable column, log sheet as a form sheet | ✅ Shipped (v2.3, #151) |
| iPad: Today in two columns, side column on wide screens | ✅ Shipped (v2.3, #152) |
| iPad: My Nutrients as a split view | ✅ Shipped (v2.3, #153) |
| iPad: History as a split view | ✅ Shipped (v2.3, #154, #196) |
| iPad: one column at the largest text sizes | ✅ Shipped (v2.3, #155) |
| Today keeps its place when the layout changes | ✅ Shipped (v2.3, part of #198) |
| iPhone Duo: the large-screen layouts when unfolded | ✅ Shipped (v2.3, #130) |
| "What's new" card on Today after an update | ✅ Shipped (v2.3, #148) |
| "Last day" on a course's card (Pro) | ✅ Shipped (v2.3, #128) |
| Analytics goal labels beside the chart; large text sizes | ✅ Shipped (v2.3, #47, #66) |
| VoiceOver doesn't read done goals as "Selected" | ✅ Shipped (v2.3, #77, #203) |
| Select bar at accessibility sizes | ✅ Shipped (v2.3, #171) |
| Stack log sheet: totals on one line, rows scroll | ✅ Shipped (v2.3, #97, #180) |
| Supply hints shorten to fit | ✅ Shipped (v2.3, #185) |
| Paywall: plans in view at large sizes and on iPad | ✅ Shipped (v2.3, #161, #189, #205) |
| App Store screenshots: iPhone Duo and iPad landscape | ✅ Shipped (v2.3, #211) |

### v2.4 — Schedules ✅

Released on the App Store on 24 Oct 2026 (build 173, phased release; tag `v2.4`). Main builds 2.5 from here.

| Feature | Status |
|---|---|
| Schedules: set weekdays, every few days, on and off, times a week (Pro) | ✅ Shipped (v2.4, #132) |
| Logging from Not today says it won't count | ✅ Shipped (v2.4, #247) |
| Weekly nutrients in the doctor report's summary | ✅ Shipped (v2.4, #248) |
| Day score collapses into a bar while scrolling; tap to bring it back | ✅ Shipped (v2.4, #243, #246) |
| Suggest a feature, from Settings | ✅ Shipped (v2.4, #142) |
| Courses reopen in the mode they were set in (Pro) | ✅ Shipped (v2.4, #188) |
| Chart dates under their own day | ✅ Shipped (v2.4, #95) |
| Log button in view on shorter screens, and above the keyboard | ✅ Shipped (v2.4, #212, #221) |
| Unit beside the log sheet's amount stays whole | ✅ Shipped (v2.4, #242) |
| Paywall wording at larger text sizes | ✅ Shipped (v2.4, #241) |
| Weekly progress read with a date-bounded fetch | ✅ Shipped (v2.4, #249) |
| `Tools/testflight` for manual TestFlight uploads | ✅ Shipped (v2.4, #144) |

### v2.5 — Supply costs, widgets and controls

Submitted for App Review on 28 Oct 2026 (build 205, phased release). Main builds 2.6 from here.

| Feature | Status |
|---|---|
| Supply costs: a price per bottle, monthly costs, Add to list (Pro) | ✅ Built (v2.5, #134) |
| Widgets and controls: Log stack and Log nutrient controls, a Nutrient widget, a Supply and courses widget (Pro) | ✅ Built (v2.5, #138) |
| Doctor report: "Days counted" for weekly nutrients | ✅ Built (v2.5, #257) |
| No "Fill to goal" on a day off | ✅ Built (v2.5, #256) |
| Editing an amount without thousands separators | ✅ Built (v2.5, #258) |
| Log clear of the Done bar with a hardware keyboard | ✅ Built (v2.5, #261, #274) |
| A shorter Pro page: features in four grouped rows | ✅ Built (v2.5, #304) |
| "Out of supply" in amber on Today | ✅ Built (v2.5, #303) |
| Supply and courses widget, medium: list rows with one or two items | ✅ Built (v2.5, #301) |
| A nutrient opened from a link shows its own numbers | ✅ Built (v2.5, #295) |
| Siri tip says "stack" once | ✅ Built (v2.5, #292) |
| Group names at the largest text sizes | ✅ Built (v2.5, #273) |

### v2.6 — Monthly and yearly recaps

In progress on main.

| Feature | Status |
|---|---|
| Monthly and yearly recaps: Week / Month / Year on Recaps, Today cards, notifications (Pro) | ✅ Built (v2.6, #136: #308–#312) |
| Recap polish: the weekday card, the streak unit, weekly sentences, today's ring, lone cards | ✅ Built (v2.6, #313–#317: #318) |
| Reminders at your usual time (Pro), and stack reminders | ✅ Built (v2.6, #137: #319–#322) |

Everything else that's left is a GitHub issue (labels `bug`, `enhancement`, `needs-you`).

---

## MVP 1 — Core Tracking Loop ✅

**Goal:** A fully functional, offline, privacy-first nutrient tracker.

- User onboarding (name, birthday, weight, height)
- User-defined nutrients (name, unit, step, daily target)
- Today tab with +/− logging, custom amounts, exclusions
- History tab (read-only, grouped by day)
- My Nutrients tab (create, edit, delete, reorder)
- Profile + About accessible via profile menu
- Settings screen (profile menu → "Settings") with daily check-in reminder toggle
- SwiftData persistence, fully offline, zero telemetry
- Daily check-in reminder (local notification at noon if nothing logged that day; ID: `daily-checkin-reminder`)

---

## MVP 2 — Retention & Reach ✅

**Goal:** Make the core loop stickier. Give users more reasons to open the app daily and more surfaces where the app is visible.

**Sequencing:** Features are listed in recommended build order. Complete Tier 1 before moving to Tier 2.

---

### Tier 1 — High Value, Ship First

#### 1. Per-Nutrient Dose Reminders ✅
**Status:** Shipped in v1.1

Each nutrient can have zero, one, or multiple dose reminders. Each reminder fires daily at a configured time. Smart suppression cancels upcoming reminders after the user logs intake. Configured via a "Reminders" section in the Edit Nutrient form, opening `NutrientRemindersSheet`. Model: `NutrientReminder`. Notification IDs: `nutrient-{id}-reminder-{HHmm}`.

---

#### 2. Home Screen & Lock Screen Widgets ✅
**Status:** Shipped in v1.4

Six widget configurations across a single WidgetKit extension (`NutrxWidgetsExtension`): interactive Today widget in small (2 nutrients), medium (3), and large (6) sizes with + buttons for quick logging; a completion ring (small home screen); lock screen circular gauge; lock screen inline text. All powered by a shared App Group SwiftData store (`group.nutrx-labs.nutrx`) with `LogNutrientIntent` for interactive logging. Widgets refresh on app foreground and after every intake action.

---

### Tier 2 — Meaningful UX Improvements

#### 4. Nutrient Notes ✅
**Status:** Shipped in v1.1

Optional free-form text field on `Nutrient` (`notes: String? = nil`). Editable in Create/Edit Nutrient form. Shown as a muted single line below the nutrient name on the Today card when non-empty.

---

#### 5. History Tab — Monthly Section Headers ✅
**Status:** Shipped in v1.1

Day entries grouped under sticky month section headers (e.g. "March, 2026"). Most recent month first. Grouping computed in `HistoryViewModel.monthSections`, rendered as `Section` headers in `HistoryListView`.

---

#### 6. Streaks & Consistency Tracking ✅
**Status:** Shipped in v1.5

Daily streak tracking across Today (🔥 X-day streak label), History (summary card with current + best streak, flame indicators on streak days), and widgets (small + medium). `StreakService` computes streaks from `IntakeRecord`, `Exclusion`, and `Nutrient.createdAt` data. Opt-in via `UserPreferences.streaksEnabled` (default `true`). Dedicated Streaks settings page in Settings. Model additions: `Nutrient.createdAt`, `UserPreferences.streaksEnabled`.

---

#### 7. Nutrient Grouping / Categories ✅
**Status:** Shipped in v1.2

Nutrients can be organised into named groups with collapsible sections on Today and My Nutrients screens. A system "General" group is seeded on first launch. Group management (create, rename, reorder, delete) lives in Settings → Manage Groups. "Move to Group" available via context menu. Group picker shown in Create Nutrient form (My Nutrients tab only). Model: `NutrientGroup`. Nutrient gains `group` and `groupSortOrder` fields.

---

### Settings Screen (already exists from MVP 1)

The Settings screen is accessible via the profile menu. It already contains the daily check-in reminder toggle from MVP 1. MVP 2 adds to it:

**Added in MVP 2:**
- **Streaks** page (new) — dedicated sub-page with "Track streaks" toggle, on by default. Accessed via Settings → Streaks.
- Global notifications permission prompt (requests `UNUserNotificationCenter` authorisation on first enable — shared by both notification systems)
- **Per-Nutrient Reminders** — a note directing users to configure these inside each nutrient's edit screen. No per-nutrient configuration lives in Settings.

**Reserved for future versions:**
- Appearance / theme (future)
- Units preference (future)

---

### MVP 2 — Out of Scope

The following are explicitly deferred to MVP 3 or later:

- iCloud sync
- Charts / analytics
- In-app purchase / Pro tier
- AI features
- Localisation
- iPad-specific layout optimisation

---

## MVP 3 — Ecosystem & Sync ✅

**Goal:** Make nutrx work seamlessly across a user's Apple devices and surface richer historical insight.

---

### iCloud Sync ✅

**Status:** Shipped in v1.6

Automatic CloudKit sync across all Apple devices. On by default, no setup. `ModelContainerFactory` uses `CloudKit.private("iCloud.nutrx-labs.nutrx")` with local-only fallback. All models audited for CloudKit compatibility (property-level defaults, optional relationships, no unique constraints). New-device flow waits up to 3 seconds for CloudKit data before falling back to onboarding. One-time sync banners on Today screen. Settings → iCloud Sync page with status, toggle, and "Delete iCloud Data" option. Singleton deduplication for General group, UserProfile, and UserPreferences. New `UserPreferences` fields: `iCloudSyncEnabled`, `hasSeenSyncRestoredBanner`, `hasSeenSyncEnabledBanner`. New components: `SyncLoadingView`, `SyncBannerView`.

---

### In-App Review Prompt ✅

**Status:** Shipped in v1.6

Uses Apple's native `SKStoreReviewController` to invite engaged users to rate the app at natural high points. No custom UI. Triggers: streak hits 3/7/14 days, or total intake count crosses 30. Guards: once per version, 90-day cooldown, account age ≥ 3 days, never on cold launch. Implemented in `ReviewService`, called after every intake action on the Today screen. New fields: `UserPreferences.lastReviewRequestedVersion`, `UserPreferences.lastReviewRequestedDate`. Helper: `Bundle+AppVersion.swift`.

---

### Expandable Nutrient Cards (Today Intake Breakdown) ✅

**Status:** Shipped in v1.7

Tap any nutrient card on Today to expand a chronological breakdown of all intake records for that nutrient today. Each row shows time, signed amount, and optional note inline. Multiple cards can be open simultaneously. State is transient — resets on tab switch. Components: `ExpandableNutrientCard` (wrapper), `NutrientIntakeHistoryView` (`@Query`-based list). Background/clipShape extracted from `NutrientRowView` into the wrapper.

---

### Analytics & Charts ✅

**Status:** Shipped in v1.8

Per-nutrient analytics screen accessible by tapping any row in the My Nutrients tab. Editing is preserved via swipe-left and long-press context menu.

#### Navigation

`NutrientAnalyticsView` is pushed onto the My Nutrients `NavigationStack` when the user taps a nutrient row. It receives the `Nutrient` model object. The screen title is the nutrient name.

#### Period picker

Segmented control at the top of the screen: **7D · 30D · 90D**. Defaults to 7D. Controls data range for Cards 1 and 2. Card 3 is always fixed at 4 weeks.

#### Card 1 — Daily Intake Chart

Built with Swift Charts (native, no third-party dependency — consistent with the app's no-external-libs policy). One `BarMark` per calendar day in the selected period. Bar height = SUM of `IntakeRecord.amount` for that nutrient on that calendar day, floored at 0 in the UI. A dashed `RuleMark` at `nutrient.dailyTarget` is the target line. Bars are color-coded: blue (below target), green (at or above target), orange (exceeded). Days with zero intake still render as a zero-height bar so the x-axis is continuous and gaps are visible. Card title: "Daily intake". Period picker sits in the card header trailing position.

#### Card 2 — Period Stats

Title: "This period". Three stats in a horizontal row:

| Stat | Label | Value |
|---|---|---|
| Hit rate | "On target" | "X / Y days" where X = days ≥ dailyTarget, Y = days in period |
| Average | "Daily avg" | Mean of all daily totals across the period, with unit |
| Target | "Target" | `nutrient.dailyTarget` with unit — static reference |

Responds to the period picker alongside Card 1.

#### Card 3 — Day of Week Patterns

Title: "Patterns". Subtitle: "Last 4 weeks". Always fixed — does not respond to the period picker. Seven bars, one per weekday (Mon–Sun). Bar height = average daily intake for that weekday over the last 28 days. Only days that have at least one `IntakeRecord` for this nutrient count toward the average — days with no data are excluded from the denominator. A dashed `RuleMark` at `nutrient.dailyTarget` is shown for reference. The highest bar is highlighted in accent blue; the rest are neutral grey.

#### ViewModel

`NutrientAnalyticsViewModel` holds `@Published var selectedPeriod: AnalyticsPeriod` (enum: `.week`, `.month`, `.quarter`). Fetches all `IntakeRecord` rows for the given nutrient within the date window via manual `ModelContext` fetch (no `@Query` in the VM — same pattern as widget `TimelineProvider`). Exposes:

- `dailyTotals: [Date: Double]` — keyed by start-of-day, covering every calendar day in the window including zeros
- `hitRate: (onTarget: Int, total: Int)`
- `periodAverage: Double`
- `dayOfWeekAverages: [Int: Double]` — keyed by `Calendar.weekday`

All amounts summed per day and floored at 0 before exposure to the view layer.

#### New files

```
Features/Nutrients/Views/NutrientAnalyticsView.swift
Features/Nutrients/Views/DailyIntakeChartCard.swift
Features/Nutrients/Views/PeriodStatsCard.swift
Features/Nutrients/Views/DayOfWeekCard.swift
Features/Nutrients/ViewModels/NutrientAnalyticsViewModel.swift
```

No new SwiftData models. No new services. No network requests.

---

### Apple Health Integration 📋

**Status:** Reading shipped in v2.1 as Pro's Health trends (sleep, workouts, active energy; read only). Writing is still planned: #124.

Optionally write logged nutrients to HealthKit (e.g. dietary Vitamin C, Magnesium, Calcium). Only nutrients that map to a known HealthKit quantity type can be written — user-defined nutrients without a HealthKit equivalent are not eligible. A mapping layer (automatic name-matching or user-configured) will be needed.

Read from Health (Health → nutrx ongoing sync) is out of scope for MVP3. Considered for a later version as an opt-in, per-nutrient setting.

---

## Pre-Pro Sprint — Polish & Retention ✅

**Goal:** Close any gaps that would cause churn or reduce Pro conversion before the paywall exists. Features here are chosen because they either carry a model-migration risk (better done before millions of iCloud records exist) or directly improve daily retention. Nothing here is gated behind Pro — this sprint strengthens the free tier so users are engaged and trusting when Pro launches.

**Sequencing:** Ship in the order listed.

---

### 1. Nutrient Goal Types (Minimum / Maximum / Range) ✅

**Status:** Shipped in v1.9

Today every nutrient implicitly targets a minimum ("hit at least X"). Real-world use cases require more: caffeine should stay *under* 200 mg, sodium within a range. This is a data model change — the longer it's deferred, the harder the migration becomes.

See CHANGELOG v1.9 for full details.

---

### 2. Apple Watch Companion App ✅

**Status:** Shipped in v1.10

A focused wrist companion for logging. The Watch app does one thing: lets the user log nutrient intake without reaching for their phone. No nutrient management, no history, no settings on Watch.

Two Xcode targets: `nutrx Watch App` (Bundle ID `nutrx-labs.nutrx.watchkitapp`) and `NutrxWatchWidgets` (Bundle ID `nutrx-labs.nutrx.watchkitapp.widgets`). Both share the existing App Group SwiftData store (`group.nutrx-labs.nutrx`) and CloudKit container (`iCloud.nutrx-labs.nutrx`) — no new data layer. After logging, `WidgetCenter.shared.reloadAllTimelines()` refreshes complications. Goal-type-aware progress bar tinting matches the iPhone (blue/green/orange).

Explicitly out of scope: custom amount entry, nutrient creation/editing, history browsing, settings, group headers.

See CHANGELOG v1.10 for user-facing details. Full implementation spec: `WATCH_APP_SPEC.md`.

---

### 3. Data Export (CSV) ✅

**Status:** Shipped in v2.1 (16 Oct 2026) (see CLAUDE.md → Data Export)

Export the full `IntakeRecord` history as a CSV file, shareable via the iOS share sheet. This is a trust and retention feature — users who know they can get their data out are more willing to commit to the app long-term. Especially important for the privacy-conscious audience nutrx targets.

#### Scope

- Accessible via Settings → Export Data
- One row per `IntakeRecord`: `date, time, nutrient_name, amount, unit, note`
- Sorted by date descending (most recent first)
- Filename: `nutrx-export-YYYY-MM-DD.csv`
- Shared via `ShareLink` / `UIActivityViewController` — no file saved to disk permanently

#### Implementation notes

- Pure in-memory generation — fetch all `IntakeRecord` rows, build a `String`, convert to `Data`, wrap in a temp file URL for the share sheet
- No new SwiftData models, no new services
- New file: `Shared/Services/ExportService.swift`
- New view: `Features/Settings/Views/ExportView.swift` (or inline sheet from SettingsView)

---

### 4. Quick-Log Stacks / Templates ✅

**Status:** Shipped in v2.1 (16 Oct 2026) (see CLAUDE.md → Stacks)

A stack is a named, ordered collection of nutrients with pre-set amounts. Tapping "Log stack" creates one `IntakeRecord` per nutrient in the stack, in a single action. Targets users who take the same set of supplements every morning — the most common churn point is daily logging becoming tedious.

#### Model

```swift
@Model
class LogStack {
    var name: String
    var sortOrder: Int = 0
    var entries: [LogStackEntry]? = nil
}

@Model
class LogStackEntry {
    var stack: LogStack
    var nutrient: Nutrient
    var amount: Double       // default amount to log
    var sortOrder: Int = 0
}
```

#### UI

- **Today tab** — "Stacks" button or section above the nutrient list (only shown when ≥ 1 stack exists). Tapping a stack shows a confirmation sheet listing what will be logged, with per-entry amount editable inline before confirming.
- **Manage Stacks** — Settings → Manage Stacks. Create, rename, reorder, delete stacks. Each stack has an entry list (add nutrients, set amounts, reorder).
- **Logging** — on confirm, one `IntakeRecord` per entry is inserted, context saved, widgets refreshed, haptic fired. Same path as a normal +/− tap.

#### CloudKit compatibility

Both new models follow the same CloudKit rules as existing models: optional relationship arrays, property-level defaults, no `@Attribute(.unique)`.

---

### 5. Siri & App Shortcuts ✅

**Status:** Shipped in v2.1 (16 Oct 2026) (see CLAUDE.md → Siri & App Shortcuts)

Expose `LogNutrientIntent` (already exists for widgets) to Siri and the Shortcuts app. Users can say "Hey Siri, log my magnesium in nutrx" or build automations. Low implementation lift relative to discoverability payoff — the `AppIntent` infrastructure is already in place.

The primary user goal is multi-nutrient morning routine shortcuts: one shortcut that logs Vitamin A 800µg, Magnesium 400mg, Omega-3 1g etc. in a single tap. The intent design must support this cleanly.

#### Scope

- Expose `LogNutrientIntent` to Siri and the Shortcuts app
- `NutrientEntity` parameter resolves nutrients **by name** via `EntityQuery` — never by raw UUID. The user picks from a list populated from the shared App Group SwiftData store (same container as widgets). Disambiguation shown automatically if names conflict.
- Optional `amount: Double` parameter. If nil → log one step increment (default, preserves existing widget behavior). If set → log that exact amount. This is what makes multi-nutrient stacks practical.
- Provide a suggested phrase per nutrient: "Log [nutrient name]"
- Surface in Settings → Siri & Shortcuts with a per-nutrient "Add to Siri" button

#### Implementation notes

- `NutrientEntity` must conform to `AppEntity` with an `EntityQuery` that fetches from the App Group SwiftData store — the same container `ModelContainerFactory` provides to widgets. This is the only non-trivial part; the rest follows from existing `LogNutrientIntent` infrastructure.
- `perform()` resolves the entity, applies `amount ?? nutrient.step`, inserts an `IntakeRecord`, saves context, calls `WidgetCenter.shared.reloadAllTimelines()`
- Do not expose nutrient UUIDs anywhere in the Shortcuts UI

#### Out of scope for this sprint

- Custom Shortcuts actions beyond logging (viewing history, checking progress) — deferred
- Focus filters — deferred

---

## MVP 4 — Pro Tier & AI (replaced, shipped as nutrx Pro in v2.1) ✅

> **Replaced by [`docs/pro/PLAN.md`](docs/pro/PLAN.md)** (agreed 2026-10-14): on-device AI only, no third-party LLM, no smart target suggestions (nutrx doesn't recommend amounts), stacks and Siri stay free, new prices. The text below is the original plan.

**Goal:** Introduce the Pro subscription. Monetise with AI-powered features that are genuinely useful without compromising the free tier. Pro launch is also the moment to ship two high-visibility engagement features (streak freeze, shareable card) as launch content.

### Pricing (indicative)
| Option | Price |
|---|---|
| Monthly | $2.99 / month |
| Annual | $19.99 / year |
| Lifetime | $49.99 one-time |

### What's gated behind Pro
All core tracking features remain **free forever**. Pro only unlocks AI-powered extras and engagement boosters:

| Feature | Description |
|---|---|
| **Daily AI insights** | Short natural-language summary of patterns (e.g. "You've been consistently under your Magnesium target on weekdays") |
| **Smart target suggestions** | Based on profile (age, weight) suggest reasonable starting daily targets for common nutrients |
| **Natural language logging** | Type "had a protein shake and two eggs" → app maps it to the user's defined nutrients |
| **Full history charts** | Trend charts beyond 90 days |
| **Streak freeze** | One mulligan per week — miss a day without breaking your streak. Duolingo-style. Reduces churn from accidental streak breaks. |
| **Shareable streak card** | Generated image of your current streak and daily summary, shareable to social. Zero-cost word-of-mouth marketing. |

### AI architecture
- **On-device (Apple Intelligence / Foundation Models framework):** used for natural language logging and insight phrasing. Preserves the "nothing leaves your device" story for these features.
- **Third-party LLM API (Anthropic / OpenAI):** used for nutritional reasoning and smart suggestions where on-device quality is insufficient. **Only aggregated summaries are sent** (e.g. 7-day averages per nutrient) — raw `IntakeRecord` data never leaves the device.
- This hybrid approach allows the privacy statement to remain: *"Your raw data never leaves your device."*

### Infrastructure required (not before MVP 4)
- StoreKit 2 for in-app purchase and subscription management
- A minimal backend (or Anthropic API called directly from app) for LLM-powered features
- Entitlement checking logic gating Pro views

---

## Guiding Principles Across All Versions

1. **Free tier is never degraded.** New versions add to Pro; they never remove from free.
2. **Privacy promise is never broken.** No analytics, no telemetry, no raw user data off-device — ever.
3. **Offline first.** Every feature must work without a network connection, except explicit AI Pro features which gracefully degrade when offline.
4. **Apple-native.** Every new screen and component follows Apple HIG. No third-party UI libraries.
5. **No third-party dependencies** outside of Apple frameworks unless unavoidable (currently: none).