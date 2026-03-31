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
│   │   └── Views/
│   │       ├── NutrientsListView.swift      # Reorderable list with add/edit/delete.
│   │       ├── NutrientFormView.swift       # Create/edit form with group picker and reminders section.
│   │       └── NutrientRemindersSheet.swift # Per-nutrient dose reminder management.
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

Each nutrient supports zero or more **dose reminders** — times of day that fire local notifications. Smart suppression cancels upcoming reminders after logging intake. Managed via the "Reminders" section in the Edit Nutrient form.

---

## Today Tab – Core Logging UX

The central feature. Each nutrient row shows: name, unit, progress bar, −/+ buttons. Haptic feedback on tap.

- **Swipe right** → Add Exact Amount sheet
- **Swipe left** → Edit Nutrient sheet
- **Long press** → context menu: Edit step amount, Enter custom amount, Exclude for today, Move to Group

Progress bar: blue (in progress), green (at/above target), orange (exceeded). Exceeding a target is allowed.

Intake is computed by summing `IntakeRecord` rows for today's calendar day. No explicit midnight reset needed.

### Expandable Nutrient Cards

Each nutrient card supports an expanded state that shows a chronological breakdown of all `IntakeRecord` entries for that nutrient today.

**Toggle:** Tapping anywhere on the card body expands or collapses it. The `[−]` and `[+]` buttons remain visible in both states — expansion is informational only and does not alter the logging UX.

**Expanded section:**
- All `IntakeRecord` rows for that nutrient today, sorted chronologically (oldest first).
- Each row: time (formatted as "HH:mm") + amount with unit. Positive amounts shown normally. **Negative amounts (decrements) are always shown**, styled in a muted destructive colour (system orange) so the user can understand the running total.
- If `IntakeRecord.note` is non-empty, render it as a muted caption beneath that row.
- Empty state (no intakes yet): show "No intakes logged yet" as a muted placeholder.
- No cap on entries — render all. The screen is already in a `ScrollView`.

**State:** `@State private var expandedNutrientIDs: Set<UUID> = []` in `TodayView`. Never persisted — resets on tab switch and app relaunch.

**Multiple cards open:** Allowed. No accordion/auto-collapse behaviour.

**Animation:** `withAnimation(.spring(response: 0.35, dampingFraction: 0.8))` wrapping the `expandedNutrientIDs` mutation. Expansion content is conditionally present in the view tree so SwiftUI animates automatically.

**Gesture safety:** Apply `contentShape(Rectangle())` to the card tap target. Existing swipe-right / swipe-left actions take priority over tap naturally in SwiftUI — no `simultaneousGesture` override needed.

**New components:**
- `ExpandableNutrientCard` (`Shared/Components/`) — wraps `NutrientRowView` (unchanged) with the expansion section below it.
- `NutrientIntakeHistoryView` (`Shared/Components/`) — the expanded list. Uses `@Query` filtered by nutrient ID and today's calendar date range to fetch `[IntakeRecord]` independently, keeping `NutrientRowView` free of intake-record data.

---

## History Tab

Chronological list of past days (most recent first), grouped by month. Read-only. Streak summary card at the top shows current and best streak when enabled.

---

## Notifications

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

**MVP 3 (in progress):** Analytics & charts, Apple Health integration (HealthKit write)

**MVP 4:** Pro tier (StoreKit 2), AI features (on-device + third-party LLM)

**Deferred:** Localisation, iPad-specific layout, data export

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