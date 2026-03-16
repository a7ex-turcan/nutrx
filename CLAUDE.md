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
- **Bundle ID convention:** com.nutrx.app

---

## App Structure – Tab Navigation

The app has three tabs (defined in `App/MainTabView.swift`):

| Tab | Purpose |
|---|---|
| **Today** | The main daily tracking screen |
| **My Nutrients** | Create, edit, delete, and reorder custom nutrients |
| **History** | Browse past daily intake logs |

Profile and About are **not** tabs — they're accessed via a profile icon (top-right of every screen's navigation bar). Tapping it opens a menu with "Edit Profile" (sheet), "About" (sheet), and "Log Out". This is implemented via the `.withProfileMenu()` view modifier, which every tab applies.

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
│   └── Exclusion.swift
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
│   │   │   └── CustomAmountSheet.swift      # Half-sheet for entering a one-off custom intake amount.
│   │   └── ViewModels/
│   │       └── TodayViewModel.swift         # Computes today's intake by summing IntakeRecords for today's calendar day.
│   │                                        # Handles +/−/custom by inserting IntakeRecords.
│   │
│   ├── Nutrients/               # Tab 2 — manage the nutrient list. (Implemented)
│   │   └── Views/
│   │       ├── NutrientsListView.swift      # Reorderable list with add/edit/delete + confirmation alerts.
│   │       └── NutrientFormView.swift       # Sheet for creating and editing a nutrient. Delete button shown in edit mode.
│   │
│   ├── History/                 # Tab 3 — read-only log of past days. (Implemented)
│   │   ├── Views/
│   │   │   ├── HistoryListView.swift        # List of past days (most recent first) with nutrient preview summary.
│   │   │   └── HistoryDayView.swift         # Day detail: read-only NutrientRowViews. Tap nutrient for intake entries sheet.
│   │   └── ViewModels/
│   │       └── HistoryViewModel.swift       # Groups IntakeRecords by calendar day (excludes today), sums per nutrient.
│   │
│   ├── About/                   # Accessed via profile menu, not a tab. (Implemented)
│   │   └── Views/
│   │       └── AboutView.swift              # App info, privacy philosophy, how-it-works. Shown as sheet from profile menu.
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
    │   ├── ProfileMenuButton.swift          # Profile icon with dropdown menu (Edit Profile / About / Log Out).
    │   └── ProfileToolbarModifier.swift     # .withProfileMenu() modifier — adds profile button + edit/about sheets to any nav bar.
    └── Persistence/
        ├── ModelContainerFactory.swift      # Creates and configures the shared SwiftData ModelContainer.
        └── PreviewSampleData.swift          # previewContainer with seeded nutrients + intake for Xcode previews.
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

Nutrients can be reordered, edited, and deleted from the **My Nutrients** tab. Order is set by the user via **drag-and-drop** and is fully manual — no automatic sorting. The order defined in My Nutrients is the exact order nutrients appear on the Today screen. It never changes unless the user explicitly reorders them.

---

## Today Tab – Core Logging UX

This is the central feature and main selling point of the app.

Each nutrient is displayed as a **row** containing:
- The nutrient name and unit
- A **progress bar** showing current intake vs. daily target
- A **− button** on the left
- A **+ button** on the right

### Tap behaviour
- Tapping **+** increases the logged intake by the nutrient's configured step amount.
- Tapping **−** decreases the logged intake by the step amount (floor at 0, never go negative).

### Swipe actions
- **Swipe right** — opens the "Add Exact Amount" sheet (same as the context menu option).
- **Swipe left** — opens the "Edit Nutrient" sheet (same as the context menu option).

### Long press on the progress bar
Long pressing the progress bar opens a **context menu** with the following options:
- **Edit step amount** – opens a small focused sheet showing **only the step field** for that nutrient (not the full edit form). The user updates the value and confirms. The change is permanent and persists going forward. This is intentionally lightweight — the user is mid-logging and should not be taken to the full My Nutrients edit screen.
- **Enter custom amount** – opens a number input; the entered value is **added** to the current intake (not a replacement). e.g. if 200mg is already logged and the user enters 150, the new total is 350mg.
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

---

## Monetisation

- The app is **free with no ads**.
- A **Pro tier** is planned for a future release. It will only unlock AI-powered features (e.g. insights, personalised recommendations based on profile data). All tracking features remain free forever.
- Do not build any paywall or in-app purchase infrastructure for the MVP.

---

## Out of Scope for MVP

The following features are explicitly **deferred** and should not be built or scaffolded yet:

- Push notifications / reminders
- Home screen widgets
- Pro / in-app purchase
- AI features
- Data export
- iCloud sync

---

## Data Models

All persistence is handled via SwiftData. There are four models. No data is ever sent off-device.

### Design principles
- **Everything is derived from raw records** — there are no pre-aggregated or cached totals stored. Today's intake for a nutrient is computed by summing all `IntakeRecord` rows for that nutrient whose `date` falls on today's calendar date. History is all `IntakeRecord` rows whose `date` falls on a past calendar date. This keeps the model simple and the source of truth unambiguous.
- **Soft deletes on Nutrient** — nutrients are never hard-deleted. Setting `isDeleted = true` hides them from the UI while preserving all historical `IntakeRecord` data that references them.
- **SwiftData relationships use navigation properties** — no manual ID fields. `IntakeRecord` holds a direct `var nutrient: Nutrient` reference; SwiftData manages the underlying foreign key. This is equivalent to EF Core navigation properties.
- **Do not add `@unchecked Sendable`** to `@Model` classes — the `@Model` macro already synthesises `Sendable` conformance.
- **Date comparisons must use calendar day, not timestamp equality** — `IntakeRecord.date` is a full `Date` (timestamp of the tap). Queries for "today" must compare using `Calendar.current` day components, not raw `Date` equality.
- **Decrements are negative IntakeRecords** — tapping − inserts an `IntakeRecord` with a negative `amount`. The total is always computed by summing all records, and is floored at 0 in the UI. This keeps the record log append-only.
- **No explicit midnight reset** — since intake is computed by summing records for today's calendar day, a new day naturally returns 0 with no reset action needed.

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
| `name` | `String` | e.g. "Vitamin D", "Caffeine" |
| `unit` | `String` | e.g. "mg", "IU", "cups" |
| `step` | `Double` | Increment per + / − tap. Must be > 0 |
| `dailyTarget` | `Double` | The daily goal, in the nutrient's own unit |
| `sortOrder` | `Int` | Drives display order on Today and My Nutrients screens. Lower = higher up. Updated on every drag-and-drop reorder |
| `isDeleted` | `Bool` | Soft delete flag. When `true`, hidden from all active UI but retained so historical `IntakeRecord` rows remain valid |

**Relationships:**
- One `Nutrient` → many `IntakeRecord` (inverse: `IntakeRecord.nutrient`)
- One `Nutrient` → many `Exclusion` (inverse: `Exclusion.nutrient`)

---

### IntakeRecord

Represents a single logging event — one tap of + or a custom amount entry. To get the total intake for a nutrient on a given day, **SUM** all `IntakeRecord.amount` values where `nutrient` matches and `date` falls on that calendar day.

| Field | Type | Notes |
|---|---|---|
| `nutrient` | `Nutrient` | Navigation property (SwiftData relationship) |
| `amount` | `Double` | The amount logged in this single event, in the nutrient's unit. Always positive |
| `date` | `Date` | Full timestamp of when the record was created. Use calendar-day comparison for grouping, not raw equality |

**Query patterns:**
- **Today's intake for a nutrient:** `SUM(amount)` where `nutrient == x` and `date` is today's calendar day
- **Today's view:** all non-deleted, non-excluded nutrients, each with their summed intake for today
- **History for a past day:** all `IntakeRecord` rows where `date` falls on that day, grouped by nutrient

---

### Exclusion

Records that a specific nutrient has been excluded from a specific day's Today view. Exclusions are created by the "Exclude for today" action and cleared automatically at midnight (the next day the nutrient reappears by default).

| Field | Type | Notes |
|---|---|---|
| `nutrient` | `Nutrient` | Navigation property (SwiftData relationship) |
| `date` | `Date` | The calendar day the exclusion applies to. Only the date component is meaningful; time is ignored |

**Usage:** a nutrient is excluded from a given day's Today view if an `Exclusion` row exists for that nutrient where `date` matches that calendar day. At midnight (checked on foreground), any `Exclusion` rows for previous days can be purged — they are no longer needed since exclusions do not carry forward.

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