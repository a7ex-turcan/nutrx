# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Nutrx** is a native iOS/iPadOS SwiftUI application. Bundle ID: `nutrx-labs.nutrx`.

- **Language**: Swift 5.0
- **UI Framework**: SwiftUI
- **iOS Deployment Target**: 26.0
- **Built with**: Xcode 26.3

## Build & Run

Open in Xcode:
```bash
open nutrx.xcodeproj
```

Build from command line (skip signing for CLI-only builds):
```bash
xcodebuild -scheme nutrx -configuration Debug -destination 'generic/platform=iOS' build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

Run tests:
```bash
xcodebuild test -scheme nutrx -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Swift Configuration

Notable build settings in the Xcode project:
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — All types default to `@MainActor`
- `SWIFT_APPROACHABLE_CONCURRENCY = YES` — Strict concurrency checking enabled
- SwiftUI previews enabled (`ENABLE_PREVIEWS = YES`)
- Xcode project uses `PBXFileSystemSynchronizedRootGroup` — new files added to the `nutrx/` directory are auto-discovered by Xcode (no manual pbxproj edits needed)

## What is this app?

nutrx is a privacy-first iOS app for tracking daily nutrient intake.
It is intentionally simple, flexible, and fully offline — no accounts, no servers, no ads.
A Pro plan is planned for the future but will only gate AI-powered extras;
all core tracking features remain free forever.

---

## Core Philosophy

- **Private by design** – all data lives exclusively on the user's device (SwiftData). Nothing is ever sent to an external server. There is no backend, no analytics, no telemetry.
- **User-defined everything** – there is no hardcoded list of nutrients. Users define exactly what they want to track, how it's measured, and in what increments.
- **Zero friction daily use** – logging an intake should take seconds. The UI must prioritise speed and clarity over feature density.
- **Apple-native feel** – follow Apple HIG throughout. Use SF Symbols, system fonts, and native components. Aim for an app that feels like it could ship with iOS.

---

## Platform & Tech Stack

- **Platform:** iOS (native Swift / SwiftUI)
- **Persistence:** SwiftData with CloudKit sync (iCloud.nutrx-labs.nutrx)
- **Networking:** None — the app is fully offline (CloudKit sync is transparent/additive)
- **Minimum iOS target:** Latest stable iOS (always target the most recent release)
- **Bundle ID convention:** nutrx-labs.nutrx

---

## App Structure – Tab Navigation

The app has three tabs (defined in `App/MainTabView.swift`):

| Tab | Purpose |
|---|---|
| **Today** | The main daily tracking screen |
| **My Nutrients** | Create, edit, delete, and reorder custom nutrients |
| **History** | Browse past daily intake logs |

Profile, Settings, and About are **not** tabs — they're accessed via a profile icon (top-right of every screen's navigation bar). Tapping it opens a flyout menu with three items: "Edit Profile" (opens a sheet), "Settings" (opens a sheet), and "Log Out". About has been moved inside the Settings sheet. This is implemented via the `.withProfileMenu()` view modifier, which every tab applies.

---

## Project Directory Structure

The Xcode project is named `nutrx`. All Swift source lives under `nutrx/`. The structure mirrors the three-tab feature split plus shared infrastructure.

```
nutrx/
├── nutrxApp.swift               # @main entry point. Bootstraps the SwiftData container and decides
│                                # whether to show Onboarding or the main TabView.
├── ContentView.swift            # Root view. Reads onboarding-complete flag and switches between
│                                # OnboardingFlow and MainTabView.
│
├── App/
│   └── MainTabView.swift        # The TabView shell with three tabs. Each tab has a NavigationStack with .withProfileMenu().
│
├── Models/                      # SwiftData model classes — pure data, zero UI, zero business logic.
│   ├── UserProfile.swift
│   ├── Nutrient.swift
│   ├── IntakeRecord.swift
│   ├── Exclusion.swift
│   ├── NutrientReminder.swift   # One row per dose reminder per nutrient.
│   └── NutrientGroup.swift      # Named group for organising nutrients. System "General" group seeded on first launch.
│
├── Features/
│   ├── Onboarding/              # Shown on first launch only. Two steps: personal info → first nutrient.
│   │   ├── Views/
│   │   │   ├── OnboardingFlow.swift
│   │   │   ├── OnboardingPersonalInfoView.swift
│   │   │   └── OnboardingFirstNutrientView.swift
│   │   └── ViewModels/
│   │       └── OnboardingViewModel.swift
│   │
│   ├── Today/                   # Tab 1 — the main daily logging screen.
│   │   ├── Views/
│   │   │   ├── TodayView.swift              # Nutrient list with swipe actions, context menu, banners.
│   │   │   │                                # Listens for NSPersistentStoreRemoteChange to refresh on CloudKit sync.
│   │   │   ├── CustomAmountSheet.swift
│   │   │   └── NotificationBannerView.swift
│   │   └── ViewModels/
│   │       └── TodayViewModel.swift         # Computes today's intake by summing IntakeRecords.
│   │                                        # Updates totals in-place on +/−/custom (avoids re-fetch reordering).
│   │                                        # Explicitly saves context after every intake mutation.
│   │
│   ├── Nutrients/               # Tab 2 — manage the nutrient list.
│   │   ├── Views/
│   │   │   ├── NutrientsListView.swift          # Reorderable list with add/edit/delete. Row shows note inline, summary with target/reminders/step.
│   │   │   ├── NutrientFormView.swift           # Create/edit form with group picker and reminders section.
│   │   │   ├── NutrientRemindersSheet.swift     # Per-nutrient dose reminder management.
│   │   │   ├── NutrientAnalyticsView.swift      # Per-nutrient analytics screen. Three cards: bar chart, stats, day-of-week. Pushed onto NavigationStack on row tap.
│   │   │   ├── DailyIntakeChartCard.swift       # Card 1 — bar chart with period picker (7D/30D/90D) and target RuleMark.
│   │   │   ├── PeriodStatsCard.swift            # Card 2 — hit rate, average, target stats derived from selected period.
│   │   │   └── DayOfWeekCard.swift              # Card 3 — fixed 4-week average broken down by weekday.
│   │   └── ViewModels/
│   │       └── NutrientAnalyticsViewModel.swift # Fetches and aggregates IntakeRecords for the selected nutrient and period. Exposes dailyTotals, hitRate, average, dayOfWeekAverages.
│   │
│   ├── History/                 # Tab 3 — read-only log of past days.
│   │   ├── Views/
│   │   │   ├── HistoryListView.swift        # Day list with monthly section headers and streak summary card.
│   │   │   └── HistoryDayView.swift         # Day detail with intake drill-down.
│   │   └── ViewModels/
│   │       └── HistoryViewModel.swift
│   │
│   ├── About/
│   │   └── Views/
│   │       └── AboutView.swift              # Shown inside SettingsView.
│   │
│   ├── Settings/
│   │   └── Views/
│   │       ├── SettingsView.swift           # Sections: iCloud Sync, Manage Groups, Streaks, Notifications, About.
│   │       └── ManageGroupsView.swift       # Create, rename, reorder, delete groups.
│   │
│   └── Profile/
│       ├── Views/
│       │   └── ProfileView.swift
│       └── ViewModels/
│           └── ProfileViewModel.swift
│
└── Shared/
    ├── Extensions/
    │   ├── Bundle+AppVersion.swift         # CFBundleShortVersionString helper for ReviewService.
    │   ├── Date+Calendar.swift
    │   └── Double+Formatting.swift
    ├── Components/
    │   ├── FormField.swift
    │   ├── NutrientFormFields.swift         # Reusable nutrient form + NutrientDraft observable.
    │   ├── NutrientRowView.swift            # Card with +/− buttons, progress bar.
    │   ├── NutrientProgressBar.swift        # Blue (in progress), green (complete), orange (exceeded).
    │   ├── ExpandableNutrientCard.swift     # Wraps NutrientRowView + NutrientIntakeHistoryView. Owns tap-to-expand toggle.
    │   ├── NutrientIntakeHistoryView.swift  # Expanded intake list. @Query-fetches today's IntakeRecords for one nutrient.
    │   ├── GroupHeaderView.swift            # Collapsible group header with completion count.
    │   ├── MoveToGroupSheet.swift
    │   ├── CameraView.swift                 # UIImagePickerController wrapper for camera capture.
    │   ├── SyncLoadingView.swift            # Spinner during CloudKit sync wait.
    │   ├── SyncBannerView.swift             # Dismissible iCloud sync banner.
    │   ├── ProfileMenuButton.swift
    │   └── ProfileToolbarModifier.swift     # .withProfileMenu() modifier.
    ├── Persistence/
    │   ├── ModelContainerFactory.swift      # CloudKit-backed config with local fallback.
    │   │                                    # Backs up local store before first CloudKit init to prevent data loss.
    │   │                                    # Singleton deduplication. Logs via os.log.
    │   └── PreviewSampleData.swift
    └── Services/
        ├── NotificationService.swift        # Daily check-in reminder + per-nutrient dose reminders.
        │                                    # Smart scheduling and suppression after logging intake.
        ├── StreakService.swift              # Computes current/best streak from IntakeRecord + Exclusion data.
        └── ReviewService.swift              # SKStoreReviewController prompt at streak milestones or intake count 30.
```

### Rules Claude Code must follow for file placement

- **New SwiftData models** → `Models/`
- **New tab** → new folder under `Features/` with its own `Views/` and `ViewModels/` subfolders
- **New view used in only one feature** → inside that feature's `Views/` folder
- **New view used across two or more features** → `Shared/Components/`
- **Date / number / string utilities** → `Shared/Extensions/`
- **No files at the root of `Features/`** — everything must be inside a named feature folder
- **No business logic in view files** — if a view needs to do anything beyond layout and user input forwarding, that logic belongs in the corresponding ViewModel

---

## Onboarding

Mandatory on first launch. Two-step flow:

1. **Personal Info** — name, birthday, weight (kg/lbs), height (cm/ft) on a single screen
2. **First Nutrient** — create at least one nutrient so the Today screen is never empty

Completion tracked via `UserProfile.onboardingCompleted`. On a new device with iCloud data, onboarding is skipped if a completed profile syncs within 3 seconds.

---

## Nutrient Configuration

Users create and manage their own nutrients. No preset list — fully user-defined. Each nutrient has: **name**, **unit**, **step** (increment per +/− tap), **daily target**, and optional **notes**. Nutrients can be reordered via drag-and-drop. Order in My Nutrients = order on Today screen.

Each nutrient supports zero or more **dose reminders** — times of day that fire local notifications. Smart suppression cancels upcoming reminders after logging intake. Reminders can be configured both during nutrient creation (inline in the form) and via the "Reminders" section in the Edit Nutrient form. Notification permission is requested on first reminder add if not yet granted.

---

## Today Tab – Core Logging UX

The central feature. Each nutrient row shows: name, unit, progress bar, −/+ buttons. Haptic feedback on tap.

- **Swipe right** → Add Exact Amount sheet
- **Swipe left** → Edit Nutrient sheet
- **Long press** → context menu: Edit step amount, Enter custom amount, Exclude for today, Move to Group

Progress bar: blue (in progress), green (at/above target), orange (exceeded). Exceeding a target is allowed.

Intake is computed by summing `IntakeRecord` rows for today's calendar day. No explicit midnight reset needed.

### Expandable Nutrient Cards

Tap any nutrient card to expand a chronological breakdown of all `IntakeRecord` entries for that nutrient today. Each row shows time, signed amount (decrements in orange), and optional note inline. A centered + button at the bottom opens the exact amount sheet. Multiple cards can be open simultaneously. State is transient (`expandedNutrientIDs: Set<UUID>` in `TodayView`) — resets on tab switch. `ExpandableNutrientCard` wraps `NutrientRowView` and owns the card background/clip. `NutrientIntakeHistoryView` fetches records via `@Query`.

---

## History Tab

Chronological list of past days (most recent first), grouped by month. Read-only. Streak summary card at the top shows current and best streak when enabled.

---

## Nutrient Analytics

Accessed by tapping any nutrient row in the My Nutrients tab. Replaces the previous tap-to-edit behaviour — editing is still available via swipe-left on the row or long-press context menu, both of which were already shipped.

`NutrientAnalyticsView` is pushed onto the My Nutrients `NavigationStack`. It receives the `Nutrient` model object and hosts `NutrientAnalyticsViewModel`.

### Period picker

A segmented control at the top of the screen with three options: **7D · 30D · 90D**. Defaults to 7D on open. Controls the data range for Cards 1 and 2. Card 3 is always fixed at 4 weeks regardless of this selection.

### Card 1 — Daily Intake Chart

Built with **Swift Charts** (native, no third-party dependency). One `BarMark` per calendar day in the selected period. Bar height = total intake for that day (SUM of `IntakeRecord.amount` for that nutrient, same aggregation logic as `TodayViewModel` — floored at 0 in the UI, never negative). A dashed `RuleMark` at `nutrient.dailyTarget` acts as the target line. Bars are color-coded using the same three-state logic as `NutrientProgressBar`: blue (below target), green (at or above target), orange (exceeded by more than 0%). Card title: "Daily intake". Period picker lives in the card header trailing position.

**Important:** days with zero intake must still render as a zero-height bar so the x-axis is continuous and the user can see gaps clearly.

### Card 2 — Period Stats

Title: "This period" (updates label to reflect "Last 7 days" / "Last 30 days" / "Last 90 days" as a subtitle). Three stat items displayed in a horizontal row:

| Stat | Label | Derivation |
|---|---|---|
| Hit rate | "On target" | Days where total ≥ dailyTarget ÷ total days in period, displayed as "X / Y days" |
| Average | "Daily avg" | Sum of all daily totals ÷ number of days in period, displayed with unit |
| Target | "Target" | `nutrient.dailyTarget` with unit — static, for quick reference |

### Card 3 — Day of Week Patterns

Title: "Patterns". Subtitle: "Last 4 weeks" — always fixed, does not respond to the period picker. Seven small bars, one per weekday (Mon–Sun). Each bar height = average daily intake for that weekday over the last 28 days (only days that have at least one `IntakeRecord` for this nutrient count toward the average — days with no data are excluded from the denominator so the average isn't dragged down by days the user simply didn't log). A dashed `RuleMark` at `nutrient.dailyTarget` is shown for reference. The highest bar is highlighted in accent blue; the rest are neutral grey. This lets the user instantly spot their strongest and weakest days of the week.

### ViewModel — NutrientAnalyticsViewModel

Holds `@Published var selectedPeriod: AnalyticsPeriod` (enum: `.week`, `.month`, `.quarter`). On init and on period change, fetches all `IntakeRecord` rows for the given nutrient within the date window using a manual `ModelContext` fetch (same pattern as widget `TimelineProvider` — no `@Query` in the VM). Computes and exposes:

- `dailyTotals: [Date: Double]` — keyed by calendar day (start-of-day), covering every day in the window including zeros
- `hitRate: (Int, Int)` — (daysOnTarget, totalDays)
- `periodAverage: Double`
- `dayOfWeekAverages: [Int: Double]` — keyed by `Calendar.weekday` (1 = Sunday … 7 = Saturday)

All aggregation uses calendar-day comparison, consistent with the rest of the app. Amounts are summed per day and floored at 0 before being exposed to the view layer.

### File placement summary

```
Features/Nutrients/Views/
  NutrientAnalyticsView.swift       ← screen shell, hosts the three cards + period picker
  DailyIntakeChartCard.swift        ← Card 1
  PeriodStatsCard.swift             ← Card 2
  DayOfWeekCard.swift               ← Card 3

Features/Nutrients/ViewModels/
  NutrientAnalyticsViewModel.swift  ← data fetching + aggregation
```

No new SwiftData models required. No new services. No network requests.

---

## Nutrient Goal Types

Every nutrient has a `GoalType` that controls how progress, colors, streaks, and analytics are computed. This is a first-class concept across the entire app — every surface that reads `dailyTarget` must also read `goalType`.

### The enum

```swift
enum GoalType: String, Codable {
    case minimum   // hit at least X — default, matches legacy behaviour
    case maximum   // stay under X
    case range     // stay between dailyTarget (lower) and upperBound (upper)
}
```

`GoalType` is stored as a `String` on `Nutrient` with a property-level default of `"minimum"` for SwiftData lightweight migration. Existing nutrients silently become `.minimum` — no data loss, no migration script needed.

`dailyTarget` is repurposed as the lower bound when `goalType == .range`. `upperBound` is only non-nil for `.range`. All other goal types ignore `upperBound`.

---

### NutrientProgressBar — color and fill logic

`NutrientProgressBar` is the single source of truth for color state. Accepts `goalType` and `upperBound` alongside `current` and `target`. All colors use gradual blending (UIColor interpolation) rather than discrete switches. Maximum and range bars scale the limit to 85% of bar width so overflow is visually obvious.

**`.minimum`:**
- Bar fill maps `current / dailyTarget`, capped at 100%
- Gradual blue → green as `current` approaches `dailyTarget`. Green at exactly 100%. Yellow → red when exceeded (fully red at 2× target).

**`.maximum`:**
- Bar fill maps `current / dailyTarget × 0.85` — limit tick mark sits at 85%
- Gradual orange → red as `current` approaches `dailyTarget`. Stays red when exceeded. Tick mark at the 85% position reinforces the ceiling.

**`.range`:**
- Bar fill maps `current / upperBound × 0.85` — upper tick mark at 85%
- Background track renders a subtle green-tinted band between the lower and upper tick marks
- Two tick marks: one at `dailyTarget / upperBound × 0.85`, one at 85%
- Gradual blue → green as `current` approaches `dailyTarget`. Solid green within range. Yellow → red when `current > upperBound` (fully red at 2× upper).

---

### Today Tab — value label

The value label to the right of the progress bar (e.g. "400 / 1000 IU") should adapt:

| Goal type | Label format |
|---|---|
| `.minimum` | `current / target unit` (existing) |
| `.maximum` | `current / target unit` |
| `.range` | `current / lower–upper unit` e.g. "1.2 / 1.0–2.0 g" |

For `.maximum`, consider prefixing with "Max:" on the nutrient form but keeping the Today label identical in format to minimum for scannability.

---

### NutrientFormView — setup UX

The goal type picker is a segmented control with plain-English labels, not enum names:

| Display label | Maps to |
|---|---|
| At least | `.minimum` |
| At most | `.maximum` |
| Between | `.range` |

Place the segmented control at the top of the target section, above the target value field(s).

**Dynamic caption** — a single sentence directly below the segmented control that updates live as the user changes goal type or edits values:
- At least: *"Your bar fills green when you hit [target] [unit] or more."*
- At most: *"Your bar turns orange if you go over [target] [unit]."*
- Between: *"Your bar is green when you stay between [lower] and [upper] [unit]."*

Use the actual typed values so the caption reads as a real description of their specific nutrient. Fall back to placeholder text (e.g. "your target") if the value field is empty.

**Live mini progress bar preview** — a small non-interactive `NutrientProgressBar` directly below the caption, pre-filled to a representative value so the user sees the exact color and fill they'll get on Today before saving:
- `.minimum`: preview at 60% of target (blue, in progress)
- `.maximum`: preview at 70% of target (orange, spending budget)
- `.range`: preview at a value inside the range (green, on target)

This is ~20 lines of SwiftUI. It eliminates the most common confusion about what each goal type means in practice.

**Field layout for `.range`:** reveal a second `upperBound` field below `dailyTarget` with a smooth animation when "Between" is selected. Label them "Minimum" and "Maximum" (not "Lower bound / Upper bound"). Validate that `upperBound > dailyTarget` before allowing save — show an inline error if not.

---

### Analytics — DailyIntakeChartCard and DayOfWeekCard

**Rule marks:**
- `.minimum` → single dashed `RuleMark` at `dailyTarget`, neutral color, labeled "Target"
- `.maximum` → single dashed `RuleMark` at `dailyTarget`, orange tint, labeled "Max"
- `.range` → two dashed `RuleMarks`: green at `dailyTarget` labeled "Min", orange at `upperBound` labeled "Max". A subtle filled area between the two lines reinforces the target window (use `AreaMark` or a background `RectangleMark` at low opacity). Check that labels don't overlap on narrow chart widths — offset vertically if needed.

**Bar colors:** mirror `NutrientProgressBar` logic exactly — blue / green / orange based on goal type and the same threshold conditions. Consistency between Today and Analytics is critical.

---

### Analytics — PeriodStatsCard

**Hit rate computation** changes silently by goal type (label stays "On target"):
- `.minimum` — day counts if total ≥ `dailyTarget`
- `.maximum` — day counts if total ≤ `dailyTarget`
- `.range` — day counts if `dailyTarget ≤ total ≤ upperBound`

**Target stat** (rightmost column):
- `.minimum` / `.maximum` → `"target unit"` as today
- `.range` → `"lower–upper unit"` e.g. `"1,000–2,000 mg"` — no line break, en dash between values

---

### StreakService

`StreakService.compute` must evaluate each nutrient using its `goalType`. See the Streaks section above for the per-type conditions.

---

### File changes summary

| File | Change |
|---|---|
| `Models/Nutrient.swift` | Add `goalType: GoalType = .minimum`, `upperBound: Double? = nil` |
| `Shared/Components/NutrientProgressBar.swift` | Refactor signature + implement all three color/fill modes |
| `Shared/Components/NutrientFormFields.swift` | Add goal type picker, dynamic caption, live preview bar, conditional `upperBound` field |
| `Features/Today/ViewModels/TodayViewModel.swift` | No change — totals are still raw sums; color logic lives in the bar |
| `Features/Nutrients/Views/NutrientAnalyticsView.swift` | Pass `goalType` + `upperBound` down to chart cards |
| `Features/Nutrients/Views/DailyIntakeChartCard.swift` | Update `RuleMark`s + bar color logic |
| `Features/Nutrients/Views/PeriodStatsCard.swift` | Update hit rate logic + target stat display for range |
| `Features/Nutrients/Views/DayOfWeekCard.swift` | Update `RuleMark`s + bar color logic |
| `Features/Nutrients/ViewModels/NutrientAnalyticsViewModel.swift` | Update hit rate derivation |
| `Shared/Services/StreakService.swift` | Update per-nutrient completion check for all three goal types |

No new SwiftData models, services, or files required beyond the above edits.

All local — no push infrastructure. Two notification types:

1. **Daily check-in reminder** — fires at noon if no intake logged. Opt-in via Settings. Smart one-shot scheduling refreshed on foreground and after every intake action. ID: `daily-checkin-reminder`.
2. **Per-nutrient dose reminders** — configurable times per nutrient. Smart suppression after logging. IDs: `nutrient-{id}-reminder-{HHmm}`.

Permission flow handles not-asked, granted, and denied states. A one-time notification banner appears on Today after onboarding.

**Reinstall/new-device safety:** iOS resets notification permission on app delete, but CloudKit may sync stale `dailyReminderEnabled` and `hasSeenNotificationBanner` flags. On appear, both TodayView and NotificationsSettingsView check the actual iOS permission status — if `notDetermined`, they reset the synced flags so the banner reappears and the toggle reflects reality.

---

## Nutrient Grouping

Nutrients are organised into named groups. Collapsible sections on Today and My Nutrients screens with completion counts and aggregate progress bars.

- **General group** — system group (`isSystem = true`), always exists, cannot be renamed/deleted. Nutrients with `group = nil` resolve to General at query time.
- **Group management** — Settings → Manage Groups. Create, rename, reorder, delete (moves nutrients to General).
- **Move to Group** — via context menu on nutrient rows. Half-sheet with group list and inline "New Group" option.
- Group headers hidden when only General group exists.

---

## Streaks

Daily streak tracking, opt-in via `UserPreferences.streaksEnabled` (default `true`). A streak day is a completed past day where all active non-excluded nutrients met their targets. Today is never counted. `Nutrient.createdAt` scopes each nutrient's streak window.

**Goal type awareness:** `StreakService` must evaluate each nutrient's `goalType` when deciding whether a day counts toward a streak:
- `.minimum` — total ≥ `dailyTarget`
- `.maximum` — total ≤ `dailyTarget`
- `.range` — total ≥ `dailyTarget` AND total ≤ `upperBound`

**UI:** `🔥 X-day streak` on Today (when ≥ 1), summary card in History, streak labels in small/medium widgets. `StreakService.compute(context:) → StreakResult` runs on foreground and after intake actions.

---

## In-App Review Prompt

Uses `SKStoreReviewController` — no custom UI. Triggered after intake actions when any condition is met: streak hits 3/7/14 days, or total intake count crosses 30. Guards: once per app version, 90-day cooldown, account age ≥ 3 days, never on cold launch. Implemented in `ReviewService`.

---

## Widgets

Four widget configurations in `NutrxWidgetsExtension`:

| Widget | Kind ID | Family | Content |
|---|---|---|---|
| Small | `NutrxSmallWidget` | `.systemSmall` | Completion ring with count |
| Medium | `NutrxMediumWidget` | `.systemMedium` | 3 nutrient rows with interactive + buttons |
| Circular | `NutrxCircularWidget` | `.accessoryCircular` | Lock screen ring gauge |
| Inline | `NutrxInlineWidget` | `.accessoryInline` | Lock screen text: "3 / 6 on target" |

**Infrastructure:** App Group `group.nutrx-labs.nutrx` for shared SwiftData store. `LogNutrientIntent` (AppIntent) for interactive + buttons — target membership must include both app and widget extension. `ModelContainerFactory` shared across both targets. No `@Query` in widgets — manual `ModelContext` fetches in `TimelineProvider`. Widgets refresh on intent completion and app foreground.

---

## iCloud Sync

Automatic CloudKit sync across all Apple devices. On by default, no setup required.

**Key details:**
- Container: `iCloud.nutrx-labs.nutrx`. Falls back to local-only if CloudKit unavailable.
- Entitlements: both main app and widget extension need iCloud + CloudKit capability.
- **New-device flow:** waits up to 3 seconds for CloudKit sync, skips onboarding if `UserProfile` found.
- **Conflict resolution:** last-write-wins for most models. `IntakeRecord` is append-only, so concurrent logging from two devices produces two valid records (correct by design).
- **Local → CloudKit upgrade:** on first CloudKit launch, backs up existing store before init. If CloudKit creates an empty store, migrates all data from backup (prevents TestFlight update data loss). Tracked via `UserDefaults` key `nutrx.hasCompletedCloudKitUpgrade`.
- **Remote changes:** Today screen listens for `NSPersistentStoreRemoteChange` to auto-refresh on sync.
- **Settings:** iCloud Sync section with toggle, status display, and "Delete iCloud Data" option.
- **Banners:** one-time sync-restored and sync-enabled banners on Today screen (priority below notification banner).
- **CloudKit model rules:** all relationships optional arrays (`[T]?`), no `@Attribute(.unique)`, all scalars need property-level defaults.

---

## Monetisation

- Free with no ads. **Pro tier** planned for MVP 4 — only AI-powered features (insights, smart targets, NLP logging, full history charts).
- Indicative pricing: $2.99/month · $19.99/year · $49.99 lifetime.
- Do not build any paywall, StoreKit, or AI infrastructure before MVP 4.

---

## Out of Scope — Not Yet Built

**MVP 3 (remaining):** Apple Health integration (HealthKit write)

**Pre-Pro Sprint:** Nutrient goal types (min/max/range), data export (CSV), quick-log stacks, Siri & App Shortcuts — see ROADMAP.md for full specs

**MVP 4:** Pro tier (StoreKit 2), AI features (on-device + third-party LLM), streak freeze, shareable streak card

**Deferred:** Localisation, iPad-specific layout

---

## Data Models

All persistence is handled via SwiftData. Seven model classes. No data is ever sent off-device.

### Design principles
- **Everything is derived from raw records** — no pre-aggregated totals. Today's intake = SUM of `IntakeRecord` rows for today's calendar day.
- **Soft deletes on Nutrient** — `isDeleted = true` hides from UI, preserves historical data.
- **SwiftData relationships use navigation properties** — no manual ID fields.
- **Do not add `@unchecked Sendable`** to `@Model` classes — the macro handles it.
- **Date comparisons must use calendar day** — not timestamp equality.
- **Decrements are negative IntakeRecords** — total is always SUM, floored at 0 in UI.
- **No explicit midnight reset** — calendar-day scoping handles this naturally.
- **Property-level defaults on @Model fields** — required for SwiftData lightweight migration.
- **CloudKit compatibility** — optional relationship arrays (`[T]?`, access via `?? []`), no `@Attribute(.unique)`, all scalars default.

---

### UserProfile

Single instance. Collected during onboarding, editable via Profile.

| Field | Type | Notes |
|---|---|---|
| `name` | `String` | Free text |
| `birthdate` | `Date` | Date only |
| `weight` | `Double` | In user's chosen unit |
| `weightUnit` | `String` | `"kg"` or `"lbs"` |
| `height` | `Double` | In user's chosen unit |
| `heightUnit` | `String` | `"cm"` or `"ft"` |
| `onboardingCompleted` | `Bool` | Gate for main app access |
| `createdAt` | `Date = Date()` | Used by ReviewService for account age guard |
| `profileImageData` | `Data?` | JPEG profile photo, `@Attribute(.externalStorage)` |

---

### Nutrient

User-defined nutrient to track.

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID = UUID()` | Used by `LogNutrientIntent` for widgets |
| `name` | `String` | e.g. "Vitamin D" |
| `unit` | `String` | e.g. "mg", "IU" |
| `step` | `Double` | Increment per +/− tap, must be > 0 |
| `dailyTarget` | `Double` | The daily goal |
| `sortOrder` | `Int` | Legacy flat sort order, tiebreaker for groupSortOrder |
| `groupSortOrder` | `Int = 0` | Order within group |
| `isDeleted` | `Bool` | Soft delete flag |
| `notes` | `String?` | Shown on Today card when non-empty |
| `group` | `NutrientGroup?` | `nil` → General group |
| `createdAt` | `Date = Date()` | Used by streak computation |
| `goalType` | `GoalType = .minimum` | `.minimum`, `.maximum`, or `.range` — see Nutrient Goal Types section |
| `upperBound` | `Double? = nil` | Only non-nil when `goalType == .range`. `dailyTarget` acts as the lower bound. |

**Relationships:** → many `IntakeRecord`? (cascade), → many `Exclusion`? (cascade), → many `NutrientReminder`? (cascade), → one `NutrientGroup?` (nullify)

---

### IntakeRecord

Single logging event. Total = SUM of all records for a nutrient on a calendar day.

| Field | Type | Notes |
|---|---|---|
| `nutrient` | `Nutrient` | Relationship |
| `amount` | `Double` | Can be negative (decrements) |
| `date` | `Date` | Full timestamp, use calendar-day comparison for grouping |
| `note` | `String?` | Optional, set via Add Exact Amount |

---

### UserPreferences

Single instance. App-wide settings.

| Field | Type | Default | Notes |
|---|---|---|---|
| `dailyReminderEnabled` | `Bool` | `false` | Daily check-in notification |
| `hasSeenNotificationBanner` | `Bool` | `false` | One-time banner suppression |
| `streaksEnabled` | `Bool` | `true` | Streak tracking toggle |
| `iCloudSyncEnabled` | `Bool` | `true` | CloudKit sync toggle |
| `hasSeenSyncRestoredBanner` | `Bool` | `false` | One-time banner |
| `hasSeenSyncEnabledBanner` | `Bool` | `false` | One-time banner |
| `lastReviewRequestedVersion` | `String?` | `nil` | Review prompt version gate |
| `lastReviewRequestedDate` | `Date?` | `nil` | Review prompt 90-day cooldown |

---

### Exclusion

Nutrient excluded from a specific day's Today view. Created by "Exclude for today", auto-cleared next day.

| Field | Type | Notes |
|---|---|---|
| `nutrient` | `Nutrient` | Relationship |
| `date` | `Date` | Calendar day only |

---

### NutrientGroup

Named group for organising nutrients.

| Field | Type | Notes |
|---|---|---|
| `name` | `String` | User-defined label |
| `sortOrder` | `Int` | Display order |
| `isSystem` | `Bool = false` | `true` only for General group |
| `isCollapsed` | `Bool = false` | Persisted collapsed state |

**Relationships:** → many `Nutrient`? (nullify)

---

### NutrientReminder

Scheduled dose reminder for a nutrient. Maps to one daily local notification.

| Field | Type | Notes |
|---|---|---|
| `nutrient` | `Nutrient` | Relationship |
| `timeOfDay` | `Date` | Only time component used |

---

## Code & Architecture Guidelines

- Use **SwiftUI** throughout — no UIKit unless absolutely unavoidable.
- Use **SwiftData** for all persistence (user profile, nutrients, daily logs, history).
- Follow **MVVM** — keep views dumb, push logic into view models or model layer.
- Use **Swift concurrency** (async/await) — no Combine or callbacks unless SwiftData requires it.
- Keep features modular: each tab should live in its own folder/group.
- No third-party dependencies for the MVP — use only Apple frameworks.
- Prefer **SF Symbols** for all icons.
- All user-facing strings should be in English for MVP (no localisation infrastructure needed yet).
- Write code that is **readable over clever** — Claude Code will be iterating on this frequently.