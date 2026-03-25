# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Nutrx** is a native iOS/iPadOS SwiftUI application. Bundle ID: `nutrx-labs.nutrx`.

- **Language**: Swift 5.0
- **UI Framework**: SwiftUI
- **iOS Deployment Target**: 26.2
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
- **Persistence:** SwiftData (Apple's current recommended local persistence layer)
- **Networking:** None — the app is fully offline
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
│   │
│   ├── Onboarding/              # Shown on first launch only. Mandatory before accessing the app.
│   │   ├── Views/
│   │   │   ├── OnboardingFlow.swift              # Coordinator view using paged TabView to step through screens.
│   │   │   ├── OnboardingPersonalInfoView.swift  # Step 1: name, birthday, weight, height on a single screen.
│   │   │   └── OnboardingFirstNutrientView.swift # Step 2: create first nutrient(s). At least one required to proceed.
│   │   └── ViewModels/
│   │       └── OnboardingViewModel.swift     # Holds draft state, validates inputs, writes UserProfile on step 1 completion.
│   │
│   ├── Today/                   # Tab 1 — the main daily logging screen. (Implemented)
│   │   ├── Views/
│   │   │   ├── TodayView.swift              # List of NutrientRowView cards. Swipe right = Add Exact Amount,
│   │   │   │                                # swipe left = Edit Nutrient. Long-press context menu. Refreshes on foreground.
│   │   │   │                                # Shows NotificationBannerView at the top when applicable.
│   │   │   ├── CustomAmountSheet.swift      # Half-sheet for entering a one-off custom intake amount.
│   │   │   └── NotificationBannerView.swift # Dismissible banner prompting the user to enable the daily check-in reminder.
│   │   │                                    # Shown once after onboarding; never shown again once dismissed or permission granted.
│   │   └── ViewModels/
│   │       └── TodayViewModel.swift         # Computes today's intake by summing IntakeRecords for today's calendar day.
│   │                                        # Handles +/−/custom by inserting IntakeRecords.
│   │
│   ├── Nutrients/               # Tab 2 — manage the nutrient list. (Implemented)
│   │   └── Views/
│   │       ├── NutrientsListView.swift      # Reorderable list with add/edit/delete + confirmation alerts.
│   │       ├── NutrientFormView.swift       # Sheet for creating and editing a nutrient. Delete button shown in edit mode.
│   │       │                                # Includes a group picker with inline "New Group…" option for creating groups without leaving the form.
│   │       │                                # In edit mode, shows a "Reminders" section linking to NutrientRemindersSheet.
│   │       └── NutrientRemindersSheet.swift # Half-sheet for managing per-nutrient dose reminders. Lists existing reminders
│   │                                        # sorted by time, swipe-to-delete, compact DatePicker for adding new ones.
│   │                                        # Uses @Query for reliable SwiftUI updates on insert/delete.
│   │
│   ├── History/                 # Tab 3 — read-only log of past days. (Implemented)
│   │   ├── Views/
│   │   │   ├── HistoryListView.swift        # List of past days (most recent first) with nutrient preview summary.
│   │   │   └── HistoryDayView.swift         # Day detail: read-only NutrientRowViews. Tap nutrient for intake entries sheet.
│   │   └── ViewModels/
│   │       └── HistoryViewModel.swift       # Groups IntakeRecords by calendar day (excludes today), sums per nutrient.
│   │
│   ├── About/                   # Accessed via Settings screen, not directly from the profile menu. (Implemented)
│   │   └── Views/
│   │       └── AboutView.swift              # App info, privacy philosophy, how-it-works. Shown as a section at the
│   │                                        # bottom of SettingsView (standard iOS convention).
│   │
│   ├── Settings/                # Accessed via profile menu flyout → "Settings". (Implemented)
│   │   └── Views/
│   │       ├── SettingsView.swift           # Grouped list sheet. Sections: Manage Groups, Streaks, Notifications, About.
│   │       └── ManageGroupsView.swift       # Reorderable group list. Create, rename (tap), reorder (drag),
│   │                                        # delete (swipe) custom groups. System "General" group shown locked.
│   │
│   └── Profile/                 # Accessed via profile menu, not a tab. (Implemented)
│       ├── Views/
│       │   └── ProfileView.swift            # Editable form presented as a sheet. Cancel + Save toolbar, toast on save.
│       └── ViewModels/
│           └── ProfileViewModel.swift       # Loads UserProfile, tracks changes vs original, saves back.
│
└── Shared/                      # Reusable components and utilities used across multiple features.
    ├── Extensions/
    │   ├── Date+Calendar.swift              # Helpers for calendar-day comparisons (isToday, isSameDay(_:), startOfDay).
    │   └── Double+Formatting.swift          # Consistent number display (strip trailing zeros, etc.).
    ├── Components/
    │   ├── FormField.swift                  # Labeled field wrapper with consistent card styling.
    │   ├── NutrientFormFields.swift         # Reusable nutrient form (name, unit, step, target) + NutrientDraft observable.
    │   ├── NutrientRowView.swift            # Card with name, intake label, progress bar. +/− buttons optional (nil = read-only).
    │   ├── NutrientProgressBar.swift        # Progress bar: blue (in progress), green (complete), orange (exceeded).
    │   ├── GroupHeaderView.swift            # Collapsible group section header with chevron and aggregate progress bar.
    │   ├── MoveToGroupSheet.swift           # Half-sheet for moving a nutrient to a different group.
    │   ├── ProfileMenuButton.swift          # Profile icon with dropdown menu (Edit Profile / Settings / Log Out).
    │   └── ProfileToolbarModifier.swift     # .withProfileMenu() modifier — adds profile button + flyout menu (Edit Profile,
    │                                        # Settings, Log Out) to any nav bar. Opens ProfileView or SettingsView as sheets.
    ├── Persistence/
    │   ├── ModelContainerFactory.swift      # Creates and configures the shared SwiftData ModelContainer.
    │   └── PreviewSampleData.swift          # previewContainer with seeded nutrients + intake for Xcode previews.
    └── Services/
        ├── NotificationService.swift        # Wraps UNUserNotificationCenter. Responsibilities:
        │                                    # - Request authorisation and return current permission status.
        │                                    # - Schedule / cancel the daily check-in reminder (noon, id: daily-checkin-reminder).
        │                                    # - Schedule / cancel per-nutrient dose reminders (id: nutrient-{id}-reminder-{HHmm}).
        │                                    # - Smart suppression: cancel upcoming nutrient reminders after logging intake.
        │                                    # - refreshAllNutrientReminders(context:) — called on every app foreground.
        │                                    # Pure Swift class — no SwiftUI imports.
        └── StreakService.swift              # Computes current streak and best streak from IntakeRecord + Exclusion + Nutrient data.
                                             # - compute(context:) → StreakResult (currentStreak: Int, bestStreak: Int)
                                             # - Returns (0, 0) immediately if UserPreferences.streaksEnabled == false.
                                             # - Called on every app foreground and after every intake action.
                                             # Pure Swift class — no SwiftUI imports.
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

Onboarding is **mandatory** on first launch. It must be completed before the user can access the main app. It is a two-step flow:

**Step 1 — Personal Info** (implemented in `OnboardingPersonalInfoView`): collects all fields on a single screen:
- **Name**
- **Birthday** (date picker)
- **Weight** + **unit preference** (kg / lbs segmented picker)
- **Height** + **unit preference** (cm / ft segmented picker)

**Step 2 — First Nutrient**: the user is prompted to **create their first nutrient** so the Today screen is never empty on first use.

Onboarding completion is tracked via `UserProfile.onboardingCompleted`. `ContentView` queries this flag to decide whether to show `OnboardingFlow` or the main app.

These fields are stored locally (SwiftData) and are editable later from the Profile tab.

---

## Nutrient Configuration

Users create and manage their own nutrients. There is no preset or suggested list — the slate is completely blank.

Each nutrient has:

- **Name** – free text (e.g. "Vitamin D", "Caffeine", "Omega-3")
- **Unit** – user-defined string (e.g. "mg", "g", "IU", "ml", "cups")
- **Step** – the increment used when tapping + or − on the Today screen (e.g. 0.5, 1, 100). Must be a positive number.
- **Daily target** – the goal for the day, expressed in the nutrient's own unit. Shown as the "full" value of the progress bar on the Today screen. Required.
- **Notes** – optional free-form text (e.g. "doctor recommended for bone density", "read about sleep benefits"). Editable in the nutrient form. Shown as a single muted line below the nutrient name on the Today card; only rendered when non-empty.

Nutrients can be reordered, edited, and deleted from the **My Nutrients** tab. Order is set by the user via **drag-and-drop** and is fully manual — no automatic sorting. The order defined in My Nutrients is the exact order nutrients appear on the Today screen. It never changes unless the user explicitly reorders them.

### Reminders

Each nutrient supports zero, one, or multiple dose reminders. See the **Per-nutrient notifications** section under Notifications for the full spec.

---

## Today Tab – Core Logging UX

This is the central feature and main selling point of the app.

Each nutrient is displayed as a **row** containing:
- The nutrient name and unit
- A **progress bar** showing current intake vs. daily target
- A **− button** on the left
- A **+ button** on the right

### Tap behaviour
- Tapping **+** increases the logged intake by the nutrient's configured step amount. Triggers subtle haptic feedback.
- Tapping **−** decreases the logged intake by the step amount (floor at 0, never go negative). Triggers subtle haptic feedback.

### Swipe actions
- **Swipe right** — opens the "Add Exact Amount" sheet (same as the context menu option).
- **Swipe left** — opens the "Edit Nutrient" sheet (same as the context menu option).

### Long press on the progress bar
Long pressing the progress bar opens a **context menu** with the following options:
- **Edit step amount** – opens a small focused sheet showing **only the step field** for that nutrient (not the full edit form). The user updates the value and confirms. The change is permanent and persists going forward. This is intentionally lightweight — the user is mid-logging and should not be taken to the full My Nutrients edit screen.
- **Enter custom amount** – opens a number input with an optional note field; the entered value is **added** to the current intake (not a replacement). e.g. if 200mg is already logged and the user enters 150, the new total is 350mg. Notes are stored on the `IntakeRecord` and displayed in the History intake detail sheet.
- **Exclude for today** – hides this nutrient from today's view without deleting it (it comes back tomorrow)
- *(further options may be added in future iterations)*

### Visual states
- Progress bar fills as intake approaches the daily target.
- When the target is reached or exceeded, show a distinct visual state (e.g. filled colour, checkmark, or subtle animation).
- Exceeding a target should be allowed and visually indicated (e.g. the bar overflows or changes colour) — some nutrients have soft targets.

---

## Daily Reset Logic

- At **midnight**, all daily intake values reset to 0.
- In practice, the reset is checked **when the app is foregrounded** (not via a background task). If the stored date of the last session is before today's date, trigger the reset.
- Resets are **non-destructive** — before zeroing out, the previous day's data is saved to the History store.
- If a nutrient is marked "excluded for today", that exclusion is also reset at midnight (the nutrient reappears the next day by default).

---

## History Tab

- Displays a **chronological list of past days**, most recent first.
- Each entry shows the date and the intake logged for each nutrient that day.
- Read-only — the user cannot edit past entries.
- History is stored locally via SwiftData and is never deleted automatically.

### Monthly section headers

- The day list uses sticky section headers grouped by month (e.g. "March, 2026").
- Grouping is computed in `HistoryViewModel.monthSections` and rendered as `Section` headers in `HistoryListView`.
- Most recent month first; days within each month sorted most-recent-first.

---

## Notifications

nutrx uses **local notifications only** — no push infrastructure, no server. All scheduling is done on-device via `UNUserNotificationCenter`.

### Daily check-in reminder

A single notification fires at **12:00 noon** if the user has not logged any intake that day. It is the only notification type in the current version.

- Notification identifier: `daily-checkin-reminder` — use namespaced identifiers for all future notification types (e.g. `nutrient-{id}-reminder`) to avoid conflicts.
- The reminder is **opt-in**. The app never schedules it without the user explicitly granting permission. The preference is stored in `UserPreferences.dailyReminderEnabled`.
- Scheduling and cancellation logic lives in `NotificationService.swift` (see Shared layer).
- **Smart scheduling**: uses one-shot (non-repeating) notifications instead of repeating ones. `NotificationService.refreshDailyReminder(context:)` checks whether the user has logged any intake today and schedules accordingly:
  - No intake today + before noon → schedule for today at noon.
  - No intake today + after noon → schedule for tomorrow at noon.
  - Intake logged today → cancel today's notification, schedule for tomorrow.
  - Reminder disabled or permissions revoked → cancel all pending.
- **Refresh triggers**: `refreshDailyReminder` is called on every app foreground, after every intake action (increment/decrement/custom amount), and when the Settings toggle changes.

### Permission flow

iOS notification permission has three distinct states that the UI must handle differently:

| State | What the UI does |
|---|---|
| **Not yet asked** | Trigger the OS permission prompt via `UNUserNotificationCenter.requestAuthorization` |
| **Granted** | Show a confirmation / active status. Schedule the reminder if not already scheduled. |
| **Denied** | Cannot re-prompt programmatically. Show a message explaining that notifications are disabled and provide a button that deep-links to iOS Settings via `UIApplication.openSettingsURLString`. |

### Notification banner (Today screen)

- A small dismissible banner is shown **at the top of the Today screen**, above the nutrient list, the first time the user lands on Today after completing onboarding.
- It has two actions: **"Enable"** (triggers the OS permission prompt) and a dismiss button (×).
- Once dismissed — or once the user grants or denies the OS prompt — the banner is **never shown again**. Persisted via `UserPreferences.hasSeenNotificationBanner`.
- The banner is not shown if permission is already granted.

### Settings screen (profile menu → Settings)

- A grouped list sheet with two sections:
  1. **Daily check-in reminder** — a toggle or status row that reflects current permission state and handles all three states described above.
  2. **About** — `AboutView` rendered inline at the bottom of the sheet (standard iOS convention; About always lives at the bottom of Settings).
- The Settings sheet replaces the former direct "About" item in the profile flyout menu.

### Per-nutrient notifications

Each nutrient can have zero, one, or multiple **dose reminders** — each reminder is a time of day that fires daily.

**User-facing behaviour:**
- Notification message: *"Time to log your [Nutrient Name]"*
- **Smart suppression:** if the user has already logged that nutrient since the previous reminder fired, the upcoming notification is cancelled silently and rescheduled for the following day. Implemented via `NotificationService.suppressRemindersAfterLogging(for:)`, called on every intake action.
- Fully local — no server, no network.

**Where it lives:**
- A dedicated **"Reminders" section** at the bottom of `NutrientFormView` (edit mode only — shown when a `nutrient` is passed).
- The section shows a summary (e.g. "3 reminders" or "No reminders") and opens `NutrientRemindersSheet` on tap.
- The Reminders sheet lists all configured times sorted chronologically, with swipe-to-delete and a compact DatePicker for adding new reminders.
- Uses `@Query private var allReminders: [NutrientReminder]` (not relationship reads) for reliable SwiftUI view updates on insert/delete.

**SwiftData model: `NutrientReminder`** (see Data Models section).

**Notification IDs:** use the namespaced pattern `nutrient-{id}-reminder-{HHmm}` (e.g. `nutrient-abc123-reminder-0900`). When the user logs an intake for a nutrient, call `UNUserNotificationCenter.removePendingNotificationRequests(withIdentifiers:)` for that nutrient's reminders. On every app foreground, `NotificationService.refreshAllNutrientReminders(context:)` reschedules all reminders.

**Permission handling in sheets:** The OS notification permission prompt can be swallowed when triggered from within a presented sheet. The pattern used is a two-stage approach: show an in-app `.alert` first explaining why permissions are needed, then trigger the OS prompt from the alert's button action.

---

## Nutrient Grouping

Nutrients can be organised into named groups. Groups are collapsible on the Today screen and orderable. All grouping features are part of MVP 2.

### General group

- Always exists as a real `NutrientGroup` row with `isSystem = true`.
- Seeded by `ModelContainerFactory` on first launch if no groups exist (handles both fresh installs and upgrades).
- Acts as the default home for all nutrients. Newly created nutrients are assigned to General.
- Nutrients with `group = nil` are treated as belonging to General at query time — no backfill migration needed.
- Cannot be renamed, deleted, or reordered above other groups.

### Group management

- Lives in **Settings → Manage Groups** — a section within the existing `SettingsView` sheet.
- Renders a reorderable list of all non-system groups with drag handles (updates `NutrientGroup.sortOrder`).
- General is shown at the bottom with a visual indicator that it is a system group; no drag handle or delete affordance.
- **Create:** + toolbar button opens a name prompt. New group is appended to the bottom of the order.
- **Rename:** tap a group row to edit its name inline or via a focused sheet.
- **Delete (non-system groups only):** swipe-to-delete triggers a confirmation alert — *"[Name] will be deleted. Its X nutrients will move to General."* — then migrates all nutrients in that group (`nutrient.group = General`, `nutrient.groupSortOrder = max(General) + 1`) before deleting the row.

### "Move to group" action

- Exposed via **long-press context menu** on nutrient rows in both Today and My Nutrients.
- Menu item: "Move to Group".
- Opens a half-sheet listing all groups. The current group is shown with a checkmark.
- Selecting a group sets `nutrient.group` to the target and assigns `nutrient.groupSortOrder = max(existing groupSortOrder in that group) + 1`.
- A "New Group…" row at the bottom of the list lets the user create a group inline and immediately move the nutrient into it.

### Today screen — collapsible group sections

- Nutrients render in `NutrientGroup.sortOrder` order, each group as a named section.
- Within a section, nutrients appear in `Nutrient.groupSortOrder` order.
- **Section header contains:**
  - Group name (left-aligned)
  - Completion count showing how many nutrients have reached their daily target (e.g. "2 / 5")
  - Collapse chevron (right-aligned, rotates on state change)
  - When collapsed: aggregate progress bar spanning the full header width
- **Aggregate progress bar colour logic:**
  - All nutrients in group at or above target → green
  - Any nutrient exceeded → orange
  - Otherwise → blue (in progress)
- Tapping the header toggles `NutrientGroup.isCollapsed` and persists the change immediately to SwiftData.
- When collapsed, individual nutrient rows are hidden; only the header row is shown.
- Drag-to-reorder within an expanded section updates `groupSortOrder`. Cross-group reordering via drag is not supported — users use "Move to group" instead.

### My Nutrients screen

- Same grouped section structure. Groups are also collapsible here (same `isCollapsed` property).
- Drag-to-reorder within a section updates `groupSortOrder`.

### Migration notes

- On first launch after this update, `ModelContainerFactory` checks for the absence of any `NutrientGroup` rows and seeds the General group if none exist.
- Existing `Nutrient` rows have `group = nil` — no migration required; they resolve to General at query time.
- `groupSortOrder` for existing nutrients should be seeded from their legacy `sortOrder` value so relative order is preserved.
- Both new fields on `Nutrient` (`group: NutrientGroup? = nil`, `groupSortOrder: Int = 0`) must have property-level defaults for SwiftData lightweight migration.

---

## Streaks

nutrx tracks a daily streak to reward consistency. All streak logic is opt-in via `UserPreferences.streaksEnabled` (default `true`). When disabled, all streak UI is hidden and `StreakService` is never called.

### Definition

A **streak day** is any completed calendar day (never today) where:
- Every non-deleted nutrient that existed on that day — meaning `nutrient.createdAt`'s calendar day ≤ that day — reached or exceeded its `dailyTarget`
- Nutrients with an `Exclusion` record matching that day are ignored entirely
- Days where the active nutrient set is empty do not count (cannot streak before any nutrients are created)

The **current streak** is the count of consecutive streak days ending on yesterday. If yesterday was not a streak day, current streak = 0.

The **best streak** is the longest such consecutive run across all of history.

### Key rules

- **Today is never counted** — streak reflects completed past days only
- **`createdAt` scopes each nutrient's streak window** — a nutrient only contributes to streak calculation from the calendar day it was created onward. Adding a new nutrient never retroactively breaks an existing streak.
- **Soft-deleted nutrients** are excluded from all streak calculations, past and present
- **Excluded nutrients** (via "Exclude for today") are ignored for that day — they do not count against the streak
- **Gaps matter** — the algorithm walks day by day from yesterday, not just across days that have records. A day with zero intake records is a missed day and breaks the streak.
- **No data if no history** — if the user has no completed days, streak = 0 and no UI is shown

### StreakService

Lives at `Shared/Services/StreakService.swift`. Pure Swift class, no SwiftUI imports.

```swift
struct StreakResult {
    let currentStreak: Int
    let bestStreak: Int
}
```

**Algorithm (`compute(context:) → StreakResult`):**

1. Check `UserPreferences.streaksEnabled` — if `false`, return `(0, 0)` immediately
2. Fetch all non-deleted `Nutrient` records with their `createdAt` dates
3. Fetch all `IntakeRecord` records (excluding today)
4. Fetch all `Exclusion` records
5. Walk backward day by day from yesterday:
   - Determine the active nutrient set for the day: nutrients where `createdAt` calendar day ≤ current day
   - If active set is empty, stop walking (no nutrients existed yet)
   - Remove nutrients that have an `Exclusion` for the current day
   - Sum `IntakeRecord.amount` values per nutrient for the current day
   - If every remaining nutrient's sum ≥ its `dailyTarget` → day passes, increment current streak counter
   - Otherwise → current streak is finalised, stop
6. For best streak: make a separate full pass over all history using the same per-day logic, tracking the longest consecutive run

Called on every app foreground and after every intake action (same triggers as `NotificationService`).

### UI — Today screen

Shown subtly below the date in the navigation bar area, only when `streaksEnabled == true` and `currentStreak ≥ 1`:

```
🔥 12-day streak
```

When streak = 0, show nothing — the absence is the message. Never show "0-day streak".

### UI — History tab

A summary card rendered at the top of `HistoryListView`, above the day entries. Shown only when `streaksEnabled == true` and at least one of `currentStreak` or `bestStreak` is > 0:

| | |
|---|---|
| 🔥 Current streak | **12 days** |
| 🏆 Best streak | **34 days** |

Styled as a white card with a subtle border, consistent with the existing History UI.

Individual day rows in the list also show a small visual indicator (e.g. a flame SF Symbol or subtle green dot) when that day qualified as a streak day. Unobtrusive — decorative only.

### UI — Widgets

- **Small widget:** compact `🔥 12` label below the main ring. Only shown when `streaksEnabled == true` and `currentStreak ≥ 1`.
- **Medium widget:** `🔥 12` added to the header row between the "Today" label and the `"X / Y"` completion badge. Same conditions.
- **Lock screen widgets:** no change — too space-constrained.

The `WidgetEntry` struct must include `currentStreak: Int` and `streaksEnabled: Bool` so widget views can conditionally render the streak label.

### Settings

`SettingsView` gains a new **"Streaks"** section, positioned between "Manage Groups" and "Notifications":

- Single row: **"Track streaks"** — standard iOS `Toggle` bound to `UserPreferences.streaksEnabled`
- Default: `true`
- When toggled off: all streak UI disappears immediately; `StreakService` computation is skipped on all future triggers
- When re-enabled: streaks recompute from scratch on next foreground — no data is lost

### Out of scope for this iteration

- Per-nutrient streaks
- Streak freeze / grace day mechanics
- Streak-based notifications ("you're on a 7-day streak, keep it up!")

---

## Widgets

nutrx ships four widget configurations across three surfaces: small home screen, medium home screen, lock screen circular, and lock screen inline. Standby mode reuses the medium widget automatically — no separate implementation needed.

> ⚠️ **Build order — do these three things before writing any widget view code:**
> 1. **Create the WidgetKit extension target first.** Add a new WidgetKit extension target (`NutrxWidgets`) to the Xcode project. Everything else depends on this existing.
> 2. **Update `ModelContainerFactory` to use the App Group container URL.** This is the linchpin — without it the widget reads from a different store than the app and sees no data. Add `ModelContainerFactory.swift` to the widget extension's target membership so both targets share the same factory.
> 3. **Set `LogNutrientIntent` target membership to include both the main app and the widget extension.** This will not happen automatically. It must be done explicitly in Xcode's target membership panel, otherwise the interactive + button will fail to compile in the widget extension.

### Infrastructure requirements

- **WidgetKit extension target** — a separate target (e.g. `NutrxWidgets`) must be added to the Xcode project. This is a distinct binary from the main app.
- **App Group** — both the main app target and the widget extension must share the App Group `group.nutrx-labs.nutrx`. This is the only way the widget can read the SwiftData store. Both targets must have the App Group entitlement configured in Xcode and on the provisioning profile.
- **Shared ModelContainer** — `ModelContainerFactory` must be updated to initialise the container using the App Group's shared container URL rather than the default app sandbox location. The widget extension uses the same factory to open the same store read-only.
- **AppIntent for logging** — interactive buttons require an `AppIntent` conforming type (`LogNutrientIntent`). This intent writes an `IntakeRecord` to the shared SwiftData store and triggers a widget timeline reload. It must be declared in a target-membership that includes both the main app and the widget extension (or in a shared framework).
- **No `@Query` in widgets** — WidgetKit does not support SwiftData's `@Query` macro. Data must be fetched manually using a `ModelContext` inside the `TimelineProvider`.

### Widget 1 — Small (Home Screen)

**Kind identifier:** `NutrxSmallWidget`

**Content:**
- nutrx app icon (small, top-left)
- Large centre figure: number of nutrients that have reached or exceeded their daily target today (e.g. `3`)
- Subtitle: `"of 6 on target"` (total non-deleted, non-excluded nutrient count)
- A circular progress ring behind or around the figure representing overall completion ratio

**Interaction:** entire widget is a `Link` that deep-links to the Today tab. No interactive elements.

**States:**
- **Empty (no nutrients defined):** ring at zero, label `"Add nutrients"`, tapping opens the app to My Nutrients
- **Nothing logged yet:** ring at zero, `"0 of N on target"`, normal tap → Today tab
- **All complete:** ring full, green tint on ring and figure
- **Normal (partial):** blue ring, current count

### Widget 2 — Medium (Home Screen)

**Kind identifier:** `NutrxMediumWidget`

**Content:**
- Header row: `"Today"` label (left) + `"X / Y"` completion badge (right, grey pill)
- 3 nutrient rows, drawn from the first 3 non-deleted nutrients ordered by `groupSortOrder` within their group, then `NutrientGroup.sortOrder` — i.e. the same order as the Today screen. If fewer than 3 nutrients exist, show only what is available.
- Each nutrient row contains:
  - Nutrient name (left, medium weight)
  - Progress bar (full width, coloured by state — see colour logic below)
  - Current / target label in the nutrient's unit (e.g. `"400 / 1000 IU"`)
  - **+ button** (right-aligned, circular, tappable — triggers `LogNutrientIntent`)

**Progress bar colour logic** (matches the main app):
- Below target → blue
- At or above target → green
- Exceeded → orange (bar fills to edge, value shown in orange)

**+ button states:**
- Below target → `+` symbol, accent blue
- At or above target → `✓` symbol, green — **still tappable**. Tapping logs another step (soft targets, same as in-app behaviour). The checkmark is a visual indicator only, not a lock.
- The intent always inserts one `IntakeRecord` for that nutrient with `amount = nutrient.step`.

**Interaction:**
- Tapping the **+** button fires `LogNutrientIntent(nutrientID:)`, writes an `IntakeRecord` to the shared store, then calls `WidgetCenter.shared.reloadTimelines(ofKind:)` to refresh.
- Tapping anywhere else (outside a + button) → deep-links to Today tab.

**States:**
- **Empty (no nutrients defined):** single centred label `"Open nutrx to add nutrients"`, tapping opens app
- **Fewer than 3 nutrients:** show only the nutrients that exist, no placeholder rows

**Standby:** the medium widget renders in Standby automatically at larger scale with a dark background. Ensure all colours use adaptive SwiftUI values (`.primary`, `.secondary`, or explicit dark-mode variants) so the widget looks correct on the dark Standby canvas.

### Widget 3 — Lock Screen Circular

**Kind identifier:** `NutrxCircularWidget`  
**WidgetKit family:** `.accessoryCircular`

**Content:**
- Circular progress ring (`Gauge` with `.accessoryCircularCapacity` style, or a custom `Circle` arc)
- Centre: integer count of nutrients on target today
- No label text (space is too constrained)

**Interaction:** read-only. Tap → Today tab.

**States:** same as Small widget — empty shows `0`, all-complete shows full ring.

### Widget 4 — Lock Screen Inline

**Kind identifier:** `NutrxInlineWidget`  
**WidgetKit family:** `.accessoryInline`

**Content:**
- Plain text string rendered above the clock face
- Format: `"3 / 6 on target"` — always reflects today's completion at last refresh
- When all complete: `"All done today ✓"`
- When no nutrients: `"Open nutrx"`

**Interaction:** read-only. Tap → Today tab.

### Timeline & refresh strategy

- Use a **non-repeating timeline** with a single entry valid until end of day (`Calendar.current.startOfDay` + 24 hours). WidgetKit will request a new timeline at that point automatically.
- After `LogNutrientIntent` fires, call `WidgetCenter.shared.reloadAllTimelines()` to force an immediate refresh so the progress bar updates after a widget tap.
- The main app calls `WidgetCenter.shared.reloadAllTimelines()` on every foreground (in `nutrxApp` via `.onReceive(NotificationCenter...willEnterForegroundNotification)`) so widgets always reflect the latest state after the user logs something in-app.
- WidgetKit refresh budget is limited by iOS — do not schedule frequent periodic refreshes. Rely on the two triggers above (intent completion + app foreground).

### AppIntent — LogNutrientIntent

```swift
// Sketch — Claude Code should implement fully
struct LogNutrientIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Nutrient"
    
    @Parameter(title: "Nutrient ID")
    var nutrientID: String  // the nutrient's persistent model ID as a string
    
    func perform() async throws -> some IntentResult {
        // 1. Open shared ModelContainer via ModelContainerFactory
        // 2. Fetch Nutrient by ID
        // 3. Insert IntakeRecord(nutrient:, amount: nutrient.step, date: .now, note: nil)
        // 4. Save context
        // 5. WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
```

**Important:** `LogNutrientIntent` must have its target membership set to include both the main app and the widget extension. Alternatively, place it in a shared Swift package or framework that both targets import. The `ModelContainerFactory` must also be accessible from both targets.

### File placement

```
NutrxWidgets/                        # New WidgetKit extension target
├── NutrxWidgets.swift               # @main entry point, declares all four widget kinds in a WidgetBundle
├── Provider.swift                   # TimelineProvider — fetches data from shared SwiftData store, builds entries
├── WidgetEntry.swift                # TimelineEntry — snapshot of data needed to render all widgets
├── SmallWidgetView.swift            # View for NutrxSmallWidget
├── MediumWidgetView.swift           # View for NutrxMediumWidget
├── CircularWidgetView.swift         # View for NutrxCircularWidget (lock screen)
├── InlineWidgetView.swift           # View for NutrxInlineWidget (lock screen)
└── LogNutrientIntent.swift          # AppIntent for + button — must also be in main app target membership
```

`ModelContainerFactory.swift` (already in `Shared/Persistence/`) must be added to the widget extension's target membership so both targets share the same factory and open the same App Group store.

---

## Monetisation

- The app is **free with no ads**.
- A **Pro tier** is planned for MVP 4. It will only unlock AI-powered features. All core tracking features remain free forever.
- **Indicative Pro pricing:** $2.99/month · $19.99/year · $49.99 lifetime one-time purchase.
- **Planned Pro features:** daily AI insights, smart target suggestions, natural language logging, full history charts.
- **AI architecture (MVP 4):** hybrid — on-device (Apple Intelligence / Foundation Models framework) for natural language logging and insight phrasing; third-party LLM API (Anthropic / OpenAI) for nutritional reasoning where on-device quality is insufficient. Only aggregated summaries are ever sent off-device — raw `IntakeRecord` data never leaves the device.
- Do not build any paywall, StoreKit, or AI infrastructure before MVP 4.

---

## Out of Scope — Not Yet Built

The following features are planned in future MVPs but must not be built or scaffolded until their target version.

**MVP 2 (next):**
- Streaks & consistency tracking — see the **Streaks** section below for full spec

**MVP 3:**
- iCloud sync (CloudKit + SwiftData — requires `NSPersistentCloudKitContainer`, `iCloud` + `CloudKit` entitlements, all `@Model` fields must have property-level defaults)
- Analytics & charts (weekly/monthly breakdowns per nutrient)
- Apple Health integration (HealthKit write, no read)

**MVP 4:**
- Pro tier / in-app purchase (StoreKit 2)
- AI features (on-device Foundation Models + third-party LLM API)

**Indefinitely deferred:**
- Localisation / internationalisation
- iPad-specific layout optimisation
- Data export

---

## Data Models

All persistence is handled via SwiftData. There are five models. No data is ever sent off-device.

### Design principles
- **Everything is derived from raw records** — there are no pre-aggregated or cached totals stored. Today's intake for a nutrient is computed by summing all `IntakeRecord` rows for that nutrient whose `date` falls on today's calendar date. History is all `IntakeRecord` rows whose `date` falls on a past calendar date. This keeps the model simple and the source of truth unambiguous.
- **Soft deletes on Nutrient** — nutrients are never hard-deleted. Setting `isDeleted = true` hides them from the UI while preserving all historical `IntakeRecord` data that references them.
- **SwiftData relationships use navigation properties** — no manual ID fields. `IntakeRecord` holds a direct `var nutrient: Nutrient` reference; SwiftData manages the underlying foreign key. This is equivalent to EF Core navigation properties.
- **Do not add `@unchecked Sendable`** to `@Model` classes — the `@Model` macro already synthesises `Sendable` conformance.
- **Date comparisons must use calendar day, not timestamp equality** — `IntakeRecord.date` is a full `Date` (timestamp of the tap). Queries for "today" must compare using `Calendar.current` day components, not raw `Date` equality.
- **Decrements are negative IntakeRecords** — tapping − inserts an `IntakeRecord` with a negative `amount`. The total is always computed by summing all records, and is floored at 0 in the UI. This keeps the record log append-only.
- **No explicit midnight reset** — since intake is computed by summing records for today's calendar day, a new day naturally returns 0 with no reset action needed.
- **Property-level defaults on @Model fields** — when adding new non-optional fields to an existing `@Model`, always assign a default value at the property declaration (e.g. `var flag: Bool = false`), not just in the initialiser. SwiftData's lightweight migration requires this to populate the column for existing rows.

---

### UserProfile

Stores the single user's personal information collected during onboarding.

| Field | Type | Notes |
|---|---|---|
| `name` | `String` | Free text |
| `birthdate` | `Date` | Date only; time component ignored |
| `weight` | `Double` | Stored in the user's chosen unit |
| `weightUnit` | `String` | `"kg"` or `"lbs"` |
| `height` | `Double` | Stored in the user's chosen unit |
| `heightUnit` | `String` | `"cm"` or `"ft"` |
| `onboardingCompleted` | `Bool` | Set to `true` when the full onboarding flow is finished |

There is always exactly one `UserProfile` instance in the store.

---

### Nutrient

Represents a user-defined nutrient that the user wants to track.

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID = UUID()` | Stable unique identifier. Used by `LogNutrientIntent` for widget interactions. `@Attribute(.unique)` |
| `name` | `String` | e.g. "Vitamin D", "Caffeine" |
| `unit` | `String` | e.g. "mg", "IU", "cups" |
| `step` | `Double` | Increment per + / − tap. Must be > 0 |
| `dailyTarget` | `Double` | The daily goal, in the nutrient's own unit |
| `sortOrder` | `Int` | Legacy flat sort order. Still used as the initial seed for `groupSortOrder` on migration |
| `groupSortOrder` | `Int = 0` | Display order within the nutrient's group. Property-level default required for SwiftData migration |
| `isDeleted` | `Bool` | Soft delete flag. When `true`, hidden from all active UI but retained so historical `IntakeRecord` rows remain valid |
| `notes` | `String?` | Optional free-form text capturing why the user tracks this nutrient. Shown as a muted single line on the Today card when non-empty. |
| `group` | `NutrientGroup?` | Optional relationship to a `NutrientGroup`. `nil` resolves to the General group at query time. Property-level default `nil` required for SwiftData migration |
| `createdAt` | `Date = Date()` | Timestamp of when the nutrient was created. Used by streak computation to determine which nutrients were active on any given past day. Property-level default required for SwiftData migration — existing nutrients receive the migration date, which is a safe approximation. |

**Relationships:**
- One `Nutrient` → many `IntakeRecord` (inverse: `IntakeRecord.nutrient`)
- One `Nutrient` → many `Exclusion` (inverse: `Exclusion.nutrient`)
- One `Nutrient` → many `NutrientReminder` (inverse: `NutrientReminder.nutrient`)
- Many `Nutrient` → one `NutrientGroup?` (inverse: `NutrientGroup.nutrients`)

---

### IntakeRecord

Represents a single logging event — one tap of + or a custom amount entry. To get the total intake for a nutrient on a given day, **SUM** all `IntakeRecord.amount` values where `nutrient` matches and `date` falls on that calendar day.

| Field | Type | Notes |
|---|---|---|
| `nutrient` | `Nutrient` | Navigation property (SwiftData relationship) |
| `amount` | `Double` | The amount logged in this single event, in the nutrient's unit. Always positive |
| `date` | `Date` | Full timestamp of when the record was created. Use calendar-day comparison for grouping, not raw equality |
| `note` | `String?` | Optional user-provided note (e.g. "with breakfast"). Only set via Add Exact Amount |

**Query patterns:**
- **Today's intake for a nutrient:** `SUM(amount)` where `nutrient == x` and `date` is today's calendar day
- **Today's view:** all non-deleted, non-excluded nutrients, each with their summed intake for today
- **History for a past day:** all `IntakeRecord` rows where `date` falls on that day, grouped by nutrient

---

### UserPreferences

Stores app-wide user preferences. There is always exactly one instance in the store.

| Field | Type | Notes |
|---|---|---|
| `dailyReminderEnabled` | `Bool` | Whether the daily check-in notification is active. Default `false` |
| `hasSeenNotificationBanner` | `Bool` | Whether the Today screen notification banner has been shown/dismissed. Default `false` |
| `streaksEnabled` | `Bool = true` | Whether streak tracking is active. When `false`, all streak UI is hidden and `StreakService` computation is skipped entirely. Property-level default required for SwiftData migration — existing users get streaks on. |

---

### Exclusion

Records that a specific nutrient has been excluded from a specific day's Today view. Exclusions are created by the "Exclude for today" action and cleared automatically at midnight (the next day the nutrient reappears by default).

| Field | Type | Notes |
|---|---|---|
| `nutrient` | `Nutrient` | Navigation property (SwiftData relationship) |
| `date` | `Date` | The calendar day the exclusion applies to. Only the date component is meaningful; time is ignored |

**Usage:** a nutrient is excluded from a given day's Today view if an `Exclusion` row exists for that nutrient where `date` matches that calendar day. At midnight (checked on foreground), any `Exclusion` rows for previous days can be purged — they are no longer needed since exclusions do not carry forward.

---

### NutrientGroup

Represents a user-defined group that organises nutrients on the Today and My Nutrients screens.

| Field | Type | Notes |
|---|---|---|
| `name` | `String` | User-defined label, e.g. "Vitamins", "Minerals", "Supplements" |
| `sortOrder` | `Int` | Controls the display order of groups. Lower = higher up |
| `isSystem` | `Bool = false` | `true` only for the General group. Blocks rename and delete in the UI |
| `isCollapsed` | `Bool = false` | Persisted collapsed state for Today and My Nutrients screens. Written back immediately on header tap |

**The General group:**
- A physical `NutrientGroup` row with `isSystem = true` and `name = "General"`.
- Seeded once by `ModelContainerFactory` on first launch if no `NutrientGroup` rows exist (covers both new installs and upgrades from pre-grouping versions).
- Nutrients with `group = nil` resolve to General at query time — no data migration of existing rows is needed.
- Cannot be renamed, deleted, or reordered above other groups. Rendered last in all group lists.

**Relationships:**
- One `NutrientGroup` → many `Nutrient` (inverse: `Nutrient.group`)

---

### NutrientReminder

Represents a single scheduled dose reminder for a nutrient. Each instance maps to one local notification that fires daily at the configured time.

| Field | Type | Notes |
|---|---|---|
| `nutrient` | `Nutrient` | Navigation property (SwiftData relationship) |
| `timeOfDay` | `Date` | Only the time component is meaningful; date is ignored |

**Relationships:**
- One `Nutrient` → many `NutrientReminder` (inverse: `NutrientReminder.nutrient`)

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