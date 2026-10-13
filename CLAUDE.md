# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Nutrx** is a native iOS/iPadOS SwiftUI application with an Apple Watch companion. Bundle ID: `nutrx-labs.nutrx`.

- **Language**: Swift 5.0
- **UI Framework**: SwiftUI
- **iOS Deployment Target**: 26.0
- **watchOS Deployment Target**: 11.0
- **Built with**: Xcode 26.3

**Xcode targets:**
- `nutrx` — iOS/iPadOS app (`nutrx-labs.nutrx`)
- `NutrxWidgetsExtension` — iOS widgets (`nutrx-labs.nutrx.NutrxWidgets`)
- `nutrx Watch App` — watchOS companion (`nutrx-labs.nutrx.watchkitapp`)
- `NutrxWatchWidgets` — watchOS complications (`nutrx-labs.nutrx.watchkitapp.widgets`)
- `nutrxTests` — XCTest unit tests, hosted in the `nutrx` app (`@testable import nutrx`)

## Build & Run

Open in Xcode:
```bash
open nutrx.xcodeproj
```

Build from command line (skip signing for CLI-only builds):
```bash
xcodebuild -scheme nutrx -configuration Debug -destination 'generic/platform=iOS' build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

Run tests (the `nutrx` scheme's test action runs `nutrxTests`):
```bash
xcodebuild test -scheme nutrx -destination 'platform=iOS Simulator,name=iPhone 17'
```

## App Store Connect API

- `Tools/asc <get|post|patch|delete> <path> [body.json | -]` calls any App Store Connect API endpoint with the team key (team 6396A6L9J3). It's a dependency-free Swift package in `Tools/AppStoreConnect` (CryptoKit ES256 token, URLSession), a verbatim copy of the Softfill repo's tool: change it there first, then re-copy it here and check with `diff -r`. The wrapper builds the package on first use and whenever its sources are newer than the binary (`.build/` is git-ignored). `swift test --package-path Tools/AppStoreConnect` covers the signer and the client's URL, redirect and key-path rules. Requests go only to the API host: pass a path, or an absolute URL on `api.appstoreconnect.apple.com` such as a response's `links.next`. Any other host, and any redirect off that origin, is refused before the token is sent. The tool prints `HTTP <status>` on stderr and the JSON on stdout, and exits 1 on any non-2xx. A body can come on stdin with `-`.
- **Credentials:** the key lives at `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8` and **never enters the repo or the chat** (don't read, print or copy it). `ASC_KEY_ID` and `ASC_ISSUER_ID` come from the `env` of `.claude/settings.local.json`, which this repo's `.gitignore` excludes because the repo is public (never commit them). `ASC_KEY_PATH`, when set and not empty, overrides the key's location.
- **Rules:** `get` freely. `post` and `patch` only for a step the user asked for in the current session, one call at a time, reporting the response. Never `delete` without an explicit instruction from the user naming the resource. App records, agreements and Xcode Cloud onboarding are done by the user in the web UI, not through the API.
- Look up App Store Connect facts (IDs, versions, builds, review state) with the tool yourself instead of asking the user.
- nutrx app record `6760843478` ("nutrx - Nutrient Tracker", bundle and SKU `nutrx-labs.nutrx`). Example: `Tools/asc get '/v1/apps/6760843478/appStoreVersions?limit=5'`.

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

## Design (v2 redesign)

All UI work follows **`docs/design/DESIGN.md`** — brand tokens, components, screen specs, data-model additions and the phased build order. Target renders are in `docs/design/screens/*.png` (compare your previews against them); `docs/design/source/*.dc.html` holds exact values but is design-tool HTML — never port or ship it.

- "Branded native": system components and Liquid Glass chrome, plus a brand layer — forest/green colours from the asset catalog (`Theme.swift`), rounded numerals, progress **rings**, per-nutrient tint + SF Symbol.
- Build one phase from DESIGN.md §7 per session; don't mix phases.
- **Done:** Phase 1 (Foundations) — colour tokens in `Shared/DesignSystem/Colors.xcassets` + `Theme.swift`, `NutrientTint`, `Nutrient.tintRaw` / `symbolName`, `GoalStatus` / `GoalProgress`, `ProgressRing`, `SegmentedDayRing`, `NutrientIconTile`, `nutrxTests`. Phase 2 (Today) — `DayScoreCard`, `NutrientCard`, `GroupHeader`, `cardStyle()`, `DayScore`, `UpcomingReminder`, 44pt avatar. Phase 3 (Log sheet) — `LogSheet`; `CustomAmountSheet`, `ExpandableNutrientCard`, `NutrientIntakeHistoryView` deleted. Phase 4 (Nutrient form + My Nutrients) — `TintPicker`, `SymbolPicker`, `GoalTypePicker`, `NutrientPreviewRow`, form + list restyle, `GroupHeaderView` deleted. Phase 5 (Analytics) — `StatTriplet`, `DailyIntakeChart`, `WeekdayHeatmap`, `AnalyticsSummary`, `WeekdayPattern`, `AnalyticsStat`, `Text/OnTint`; `DailyIntakeChartCard`, `PeriodStatsCard`, `DayOfWeekCard` deleted. Phase 6 (History) — `StreakCard`, `MonthCalendar`, `HistoryLog`, `MonthGrid`, `HistoryText`, day detail restyle; `NutrientRowView` deleted. Phase 7 (Onboarding) — `OnboardingWelcomeView`, first-nutrient restyle, `StartingPoint`, `BrandMark` image asset, optional profile fields; `OnboardingPersonalInfoView` deleted. Phase 8 (Settings & Profile) — Settings restyle (profile card, icon-tile rows with values, Rate nutrx, privacy footer), `ProfileAvatar`, `SettingsSummary`, Profile / About / Groups restyle, settings detail views split into files, dead Log Out removed. Phase 9 (Widgets) — Today / Quick log / Goals / Next up (new, rectangular) / Goals and streak restyle, `WidgetSummary`, snapshots on `GoalProgress`. Phase 10 (Watch) — Watch list restyle (ring rows on `Watch/Cell`, "Today" + score header), `WatchLogConfirmationView`, complications (segmented ring, corner gauge, new rectangular bar, inline with streak), `GoalProgress.goalCaption`, `ContrastColor.ink(on:in:)`. Phase 11 (Polish) — accessibility pass (swipe-action labels, button traits, hidden check badges, banner close button), `Animation.unlessReduceMotion`, `Haptics` with a success haptic when a log meets a goal (`GoalProgress.reachesGoal(adding:)`), stacked form fields and banner buttons at accessibility sizes, capped glyphs in fixed badges, dark-mode-legible prominent buttons; `NutrientProgressBar` and the never-shown Profile "saved" toast deleted. **All §7 phases are done**.
- Where this file and DESIGN.md disagree about the UI, DESIGN.md wins. Update this file as each phase lands.
- **Accessibility conventions** (phase 11): icon-only buttons and swipe actions get a label (`Label(_:systemImage:)` in swipe actions); rings are one element with label + value and their check badge is hidden (VoiceOver reads a checkmark symbol as "Selected"); layout animations use `withAnimation(.unlessReduceMotion(reduceMotion, ...))` with the view's `@Environment(\.accessibilityReduceMotion)` (`Shared/Extensions/Animation+ReduceMotion.swift`) — colour / opacity highlights can animate anyway; haptics go through `Haptics` (`Shared/Services/Haptics.swift`): `logged(reachingGoal:)` (light, or success when that log met the goal — `GoalProgress.reachesGoal(adding:)`), `adjusted()`, `deleted()`. Text fields are named by their visible caption (`.accessibilityLabel`, plus the unit for amounts: "Each tap adds, mg") and the caption itself is hidden; a placeholder is never a field's name, and controls that relied on a caption for context get it in their own label ("Remove birthday", "Weight unit").

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

| Tab (SF Symbol) | Purpose |
|---|---|
| **Today** (`circle.circle`) | The main daily tracking screen |
| **Nutrients** (`leaf`) | Create, edit, delete, and reorder custom nutrients. The screen's title is "My Nutrients"; the tab label is "Nutrients" (DESIGN.md `Main.dc.html`). |
| **History** (`calendar`) | Browse past daily intake logs |

Profile, Settings, and About are **not** tabs — they're accessed via a profile icon (top-right of every screen's navigation bar). Tapping it opens a menu with two items: "Edit Profile" (opens a sheet) and "Settings" (opens a sheet). About lives inside Settings. (The old "Log Out" item was a no-op — nutrx has no accounts — and was removed in phase 8.) This is implemented via the `.withProfileMenu()` view modifier, which every tab applies.

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
│   ├── NutrientGroup.swift      # Named group for organising nutrients. System "General" group seeded on first launch.
│   └── NutrientTint.swift       # User-chosen nutrient colour (pure enum) + stable id-derived fallback.
│
├── Features/
│   ├── Onboarding/              # Shown on first launch only. Two steps: welcome → first nutrient.
│   │   ├── Views/
│   │   │   ├── OnboardingFlow.swift             # Switches welcome ↔ first nutrient (slide, or fade with Reduce Motion).
│   │   │   ├── OnboardingWelcomeView.swift      # Forest: brand mark, "Track what you take. Nothing else.", benefits, Get started.
│   │   │   └── OnboardingFirstNutrientView.swift # Back / progress / Skip, starting-point grid, "Something else", goal fields, Start tracking.
│   │   └── ViewModels/
│   │       ├── OnboardingViewModel.swift        # Step, selected starting point + draft; startTracking / complete (creates the empty profile).
│   │       └── StartingPoint.swift              # The six DESIGN.md §5.8 pre-fills (Vitamin D … Creatine), no amounts.
│   │
│   ├── Today/                   # Tab 1 — the main daily logging screen.
│   │   ├── Views/
│   │   │   ├── TodayView.swift              # Day-score card, banners, grouped NutrientCards with swipe actions + context menu.
│   │   │   │                                # Listens for NSPersistentStoreRemoteChange to refresh on CloudKit sync.
│   │   │   ├── LogSheet.swift               # Log an exact amount (stepper, ½×/1×/2×/Fill-to-goal chips, note) + today's entries with delete.
│   │   │   └── NotificationBannerView.swift
│   │   └── ViewModels/
│   │       └── TodayViewModel.swift         # Computes today's intake by summing IntakeRecords.
│   │                                        # Updates totals in-place on +/−/custom (avoids re-fetch reordering).
│   │                                        # Explicitly saves context after every intake mutation.
│   │
│   ├── Nutrients/               # Tab 2 — manage the nutrient list.
│   │   ├── Views/
│   │   │   ├── NutrientsListView.swift          # Large-title list of inset group cards; row = icon tile, name, goal-type tag + target, bell. Reorder, swipe, context menu, dashed "New group".
│   │   │   ├── NutrientFormView.swift           # Create/edit sheet: preview row, NutrientFormFields, Group + Reminders rows, notes.
│   │   │   ├── PendingRemindersSheet.swift      # Reminder times for a nutrient that isn't saved yet (kept on the draft).
│   │   │   ├── NutrientRemindersSheet.swift     # Per-nutrient dose reminder management.
│   │   │   ├── NutrientAnalyticsView.swift      # Per-nutrient analytics, pushed on row tap: header, period picker, stats + chart card, heatmap, Reminders row, Edit.
│   │   │   ├── StatTriplet.swift                # Hit rate / Daily avg / Best day columns (stack at accessibility sizes).
│   │   │   ├── DailyIntakeChart.swift           # Swift Charts bars in the tint, dashed today outline, dashed goal rule(s) + labels.
│   │   │   └── WeekdayHeatmap.swift             # 7 squares by 4-week hit rate + "Sundays are your weakest day."
│   │   └── ViewModels/
│   │       ├── NutrientAnalyticsViewModel.swift # Fetches day totals for the nutrient; exposes goal, summary, stats, weekdayPattern for the selected period.
│   │       ├── AnalyticsSummary.swift           # AnalyticsDay / AnalyticsGoal / AnalyticsSummary — period days, hit rate, average, best day (pure).
│   │       ├── WeekdayPattern.swift             # Per-weekday hit rate over the last 28 days, weakest-day insight, heatmap fill levels (pure).
│   │       ├── AnalyticsStat.swift              # Formatted stat-triplet text ("83 %", "5 of 6 days", "Peak day").
│   │       └── NutrientSummaryText.swift        # Analytics header goal line + Reminders row summary ("None", "13:00", "3 a day").
│   │
│   ├── History/                 # Tab 3 — read-only log of past days.
│   │   ├── Views/
│   │   │   ├── HistoryListView.swift        # Large title; StreakCard, MonthCalendar card, "Recent days" (dots + score). Taps push HistoryDayView.
│   │   │   ├── StreakCard.swift             # Forest card: flame, "10 days · Current streak", divider, best streak.
│   │   │   ├── MonthCalendar.swift          # Month grid (first weekday from the locale), all / some / none fills, today ring, chevrons, legend.
│   │   │   └── HistoryDayView.swift         # Weekday + date header, SegmentedDayRing summary, tint-bar rows with met badge, entries sheet.
│   │   └── ViewModels/
│   │       ├── HistoryViewModel.swift       # Fetches nutrients / intake / exclusions into a HistoryLog; streak; displayed month.
│   │       ├── HistoryLog.swift             # HistoryDay / DayCompletion — which nutrients count on a day and whether they were met (pure).
│   │       ├── MonthGrid.swift              # Month layout: leading blanks, days, weekday symbols (pure).
│   │       └── HistoryText.swift            # "10 days", "4 of 6 goals", "Missed Omega-3 and Protein".
│   │
│   ├── About/
│   │   └── Views/
│   │       └── AboutView.swift              # Shown inside SettingsView: brand mark, version, three cards.
│   │
│   ├── Settings/
│   │   ├── Views/
│   │   │   ├── SettingsView.swift           # Large title, profile card, icon-tile rows (iCloud Sync, Notifications, Streaks, Groups; Rate nutrx, About) with values, privacy footer.
│   │   │   ├── ICloudSyncSettingsView.swift # Status, sync toggle, Delete iCloud Data.
│   │   │   ├── NotificationsSettingsView.swift # Noon check-in toggle + permission flow.
│   │   │   ├── StreaksSettingsView.swift    # Streaks toggle.
│   │   │   └── ManageGroupsView.swift       # Create, rename, reorder, delete groups (counts exclude deleted nutrients).
│   │   └── ViewModels/
│   │       └── SettingsSummary.swift        # Row values: "On", "Noon check-in", "No account", group count, profile title.
│   │
│   └── Profile/
│       ├── Views/
│       │   └── ProfileView.swift
│       └── ViewModels/
│           └── ProfileViewModel.swift
│
└── Shared/
    ├── DesignSystem/
    │   ├── CardStyle.swift                 # .cardStyle(): card fill + radius, forest shadow on the card shape only (light) / hairline (dark).
    │   ├── ContrastColor.swift             # WCAG contrast maths on resolved colours — picks legible ink on runtime fills (heatmap, Watch pill).
    │   ├── Theme.swift                     # Brand colour tokens, NutrientTint colours, GoalStatus colours, spacing/radius constants.
    │   └── Colors.xcassets                 # Named colour sets (Any/Dark) for every token and tint. Shared with widget + Watch targets.
    ├── Extensions/
    │   ├── Animation+ReduceMotion.swift    # Animation.unlessReduceMotion(_:_:) — nil when the passed Reduce Motion flag is on.
    │   ├── Bundle+AppVersion.swift         # CFBundleShortVersionString helper for ReviewService.
    │   ├── Date+Calendar.swift
    │   └── Double+Formatting.swift
    ├── Components/
    │   ├── ProgressRing.swift               # Redesign ring: tint arc + track, centre symbol, check badge when met.
    │   ├── SegmentedDayRing.swift           # Day score ring, one segment per nutrient ("3/6 goals met").
    │   ├── NutrientIconTile.swift           # Rounded tile with a nutrient's symbol on its tint.
    │   ├── DayScoreCard.swift               # Today header: forest card with SegmentedDayRing, headline, streak chip, next reminder.
    │   ├── NutrientCard.swift               # Today row: ProgressRing, name, value, status line, − / + (44pt).
    │   ├── GroupHeader.swift                # Today group header: name, met-count chip, collapse chevron.
    │   ├── FormField.swift                  # Label + field on a Surface/Card rounded card (Profile).
    │   ├── ProfileAvatar.swift              # Photo / initial / person symbol; toolbar (pale) or forest style.
    │   ├── NutrientFormFields.swift         # NutrientDraft + shared fields: name/unit, Look (tint, symbol), Daily goal, notes.
    │   ├── NutrientPreviewRow.swift         # Live preview at the top of the nutrient form.
    │   ├── TintPicker.swift                 # 8 tint swatches.
    │   ├── SymbolPicker.swift               # 16-symbol grid (DESIGN.md §3 set).
    │   ├── GoalTypePicker.swift             # At least / At most / Between cards.
    │   ├── MoveToGroupSheet.swift
    │   ├── CameraView.swift                 # UIImagePickerController wrapper for camera capture.
    │   ├── SyncLoadingView.swift            # Spinner during CloudKit sync wait.
    │   ├── SyncBannerView.swift             # Dismissible iCloud sync banner.
    │   ├── ProfileMenuButton.swift          # 44pt ProfileAvatar with the Edit Profile / Settings menu.
    │   └── ProfileToolbarModifier.swift     # .withProfileMenu() modifier.
    ├── Persistence/
    │   ├── ModelContainerFactory.swift      # CloudKit-backed config with local fallback; createForExtension() for widgets / complications (no CloudKit).
    │   │                                    # Backs up local store before first CloudKit init to prevent data loss.
    │   │                                    # Singleton deduplication. Logs via os.log.
    │   ├── NutrientDraft+Persistence.swift  # insertNutrient / apply(to:) — the only writers of a draft to a Nutrient.
    │   ├── NutrientGroup+Create.swift       # NutrientGroup.create(named:among:in:) — new user group before General.
    │   └── PreviewSampleData.swift
    └── Services/
        ├── DayScore.swift                   # Met / total + the day-score card headline.
        ├── UpcomingReminder.swift           # Next dose reminder later today (for the day-score card).
        ├── GoalStatus.swift                 # GoalStatus + GoalProgress: status, ring fraction, status line, counts-as-met.
        │                                    # Single source of truth for "goal met" (streaks, History, analytics, Today).
        ├── Haptics.swift                    # logged(reachingGoal:) / adjusted() / deleted() — the app's haptics in one place.
        ├── NotificationService.swift        # Daily check-in reminder + per-nutrient dose reminders.
        │                                    # refreshAllNutrientReminders: one data-driven, serialized sync.
        ├── ReminderSchedule.swift           # Dose reminders as one-off requests per date (rolling window).
        ├── StreakService.swift              # Computes current/best streak from IntakeRecord + Exclusion data.
        └── ReviewService.swift              # SKStoreReviewController prompt at streak milestones or intake count 30;
                                             # writeReviewURL (App Store review page) for Settings → Rate nutrx.
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

## Apple Watch App

A focused wrist companion for logging. One job: log nutrient intake without reaching for the phone. No nutrient management, no history, no settings on Watch.

### Directory structure

```
nutrx Watch App/
├── nutrxWatchApp.swift                     # @main entry point. Boots the shared SwiftData container.
├── ContentView.swift                       # Root view — hosts WatchTodayView.
├── Views/
│   ├── WatchTodayView.swift                # "Today" + "3/6" header, rows by group on Watch/Cell; shows the confirmation after a + tap.
│   ├── WatchNutrientRowView.swift          # Row: 30pt ProgressRing in the tint, name, "2,000 / 4,000 IU", 34pt green + button.
│   └── WatchLogConfirmationView.swift      # Large ring with the new total, "of 4,000 IU", name, "+1,000 logged" pill in the tint.
├── ViewModels/
│   ├── WatchTodayViewModel.swift           # Today's totals by summing IntakeRecords (same logic as iOS); met count; confirmation.
│   └── WatchPreviewData.swift              # DEBUG-only sample items for previews.
└── nutrx Watch App.entitlements            # App Group + iCloud container matching iOS app.

NutrxWatchWidgets/
├── NutrxWatchWidgetsBundle.swift           # WidgetKit bundle entry point.
├── NutrxComplication.swift                 # Circular, corner, rectangular and inline complications + their provider.
├── Info.plist
└── NutrxWatchWidgets.entitlements
```

### Key facts

- Both watch targets share the existing App Group SwiftData store (`group.nutrx-labs.nutrx`) and CloudKit container (`iCloud.nutrx-labs.nutrx`) — no new data layer
- `ModelContainerFactory`, all Model files and the design system (`Theme.swift`, `Colors.xcassets`, `GoalStatus.swift`) are added to the Watch targets via target membership exceptions (not duplicated) — plus `ProgressRing`, `ContrastColor`, `WidgetSummary` for the app and `SegmentedDayRing`, `StreakService`, `WidgetSummary` for the complications
- **watchOS only reads an asset colour's "Any" appearance** (the Watch is always dark, but asset dark variants are ignored). Tokens that are the same in both (`Brand/*`, `OnForest/*`, `Watch/Cell`, tints, `Text/OnTint`; tint tracks are just a little fainter) are fine; for primary text use the system `.primary` (white), never `Theme.textPrimary`, and pass `badgeBorderColor` to `ProgressRing` (`Watch/Cell` in rows, black on the confirmation) — its default `Surface/Card` is white there
- Rows (DESIGN.md §5.11): ring, status and text from `GoalProgress`, the same as Today, on `Theme.Radius.watchCell` cards. The "Today" + "3/6" header is the first section's header (list rows have a tall minimum height on watchOS; don't set `defaultMinListRowHeight` to 0 — rows disappear)
- Tapping + logs one step, then `WatchLogConfirmationView` covers the list for 1.5s (tap to dismiss) with a VoiceOver announcement; haptic `.click`, or `.success` when that tap met the goal
- The list refreshes on appear and whenever the app becomes active (new day, CloudKit changes)
- Complications use WidgetKit, same API as iOS widgets. Their provider opens the store with `ModelContainerFactory.createForExtension(allowsSave: false)` — never `create()`. Kind IDs never change: `NutrxCircularComplication` (segmented ring + "3/6"), `NutrxCornerComplication` ("3/6" + curved gauge), `NutrxRectangularComplication` ("nutrx · 3/6" + segment bar, one segment per goal up to 12), `NutrxInlineComplication` ("3/6 goals · 10 days"). With no goals, or a store the read-only open can't read (`ComplicationEntry.unavailable`), they show a plain nutrx state (pills glyph / "nutrx"), never a "0/0" that looks like a score
- After logging, `WidgetCenter.shared.reloadAllTimelines()` refreshes complications
- No `WatchConnectivity` / `WCSession` — shared store handles cross-device sync
- Nutrient groups are shown with section headers on the Watch, matching the iPhone. Headers hidden when only General group exists.
- Explicitly out of scope: custom amount entry (step-only), nutrient creation/editing, history browsing, settings

---

## Siri & App Shortcuts

Expose `LogNutrientIntent` (already used for widgets) to Siri and the Shortcuts app. Primary use case: a multi-nutrient morning routine shortcut that logs several nutrients with specific amounts in one tap.

### Intent design

`LogNutrientIntent` gains two parameters:

- **`nutrient: NutrientEntity`** — resolves by name, never by UUID. Conforming to `AppEntity` with an `EntityQuery` that fetches from the App Group SwiftData store (same container as widgets via `ModelContainerFactory`). The Shortcuts UI shows a picker populated from the user's nutrient list. Disambiguation is handled automatically by the framework if names conflict.
- **`amount: Double?`** — optional. If `nil` → log one step increment (preserves existing widget behavior). If set → log that exact amount.

### `perform()` implementation

```swift
func perform() async throws -> some IntentResult {
    let container = ModelContainerFactory.shared
    let context = ModelContext(container)
    // resolve nutrient from entity ID
    // let logAmount = amount ?? nutrient.step
    // insert IntakeRecord(nutrient:, amount: logAmount, date: Date())
    // try context.save()
    // WidgetCenter.shared.reloadAllTimelines()
    return .result()
}
```

### Key rules

- `NutrientEntity.EntityQuery` must use the App Group store — **not** the main app's in-process container. Same pattern as widget `TimelineProvider`.
- Never expose raw UUIDs in the Shortcuts UI or suggested phrases.
- Suggested phrase per nutrient: `"Log [nutrient name]"` — donate via `PredictableIntent` or `ShortcutsLink`.
- Settings → Siri & Shortcuts: per-nutrient "Add to Siri" button using `SiriTipView` or `ShortcutsLink`.

### File placement

```
Shared/Intents/
  LogNutrientIntent.swift     ← already exists, extend with amount param + EntityQuery
  NutrientEntity.swift        ← new: AppEntity + EntityQuery conformance
Features/Settings/Views/
  SiriShortcutsView.swift     ← new: per-nutrient "Add to Siri" list
```

`NutrientEntity` and `LogNutrientIntent` must have target membership in both `nutrx` and `NutrxWidgetsExtension` (same as today — widgets depend on `LogNutrientIntent`). Verify target membership hasn't drifted before implementing.

---

## Onboarding

Redesigned in phase 7 (DESIGN.md §5.8). Shown on first launch. Two steps:

1. **Welcome** (`OnboardingWelcomeView`) — full-bleed `Brand/Forest` in both appearances: the brand mark (`BrandMark` image asset — the app icon's "n+" extracted as a template image, tinted `Brand/Green`; never redraw the logo in code), "Track what you take. **Nothing else.**", three benefits, "Get started" (`Brand/Green`, `Text/OnTint`). Scrolls only when large text doesn't fit.
2. **First nutrient** (`OnboardingFirstNutrientView`) — back, 2-step progress, **Skip**; "What do you want to track first?"; a 2-column grid (1 column at accessibility sizes) of `StartingPoint`s and a dashed **Something else** (opens the blank `NutrientFormView`). Picking a starting point fills an editable draft and shows its goal fields above the button, empty: daily goal (or minimum / maximum for a range) and each-tap step. **Start tracking** (chip-grey while disabled) is enabled once they're valid and creates it in General via `insertNutrient` — nothing is created until then.

Starting points are pre-fills, not a preset list: Vitamin D, Magnesium, Omega-3, Water, Protein (a range), Creatine — name, unit, goal type, tint and symbol from the DESIGN.md table. **They carry no amounts:** nutrx doesn't recommend intakes, so the user types the goal and step. Don't add suggested numbers back.

Personal info is no longer asked for: finishing (Start tracking, Something else, or Skip) creates an empty `UserProfile` with `onboardingCompleted = true`; name, birthday, weight and height are edited later from Profile, where every field is optional. Completion is tracked via `UserProfile.onboardingCompleted`. On a new device with iCloud data, onboarding is skipped if a completed profile syncs within 3 seconds.

---

## Nutrient Configuration

Users create and manage their own nutrients. No preset list — fully user-defined. Each nutrient has: **name**, **unit**, **step** (increment per +/− tap), **daily target**, a **tint** and **SF Symbol**, and optional **notes**. Nutrients can be reordered via drag-and-drop. Order in My Nutrients = order on Today screen.

**My Nutrients** (DESIGN.md §5.6): large title, toolbar + (filled forest circle) and profile. Groups are inset cards with uppercase headers and a count (headers hidden when only General exists; every nutrient is listed — collapsing is a Today thing). Row: icon tile, name, goal-type tag ("AT LEAST" / "AT MOST" / "BETWEEN") + target, bell if it has reminders, chevron → analytics. Swipe right = edit, swipe left = delete, long press = Edit / Move to Group / Delete, drag to reorder. A dashed **New group** button ends the list.

Each nutrient supports zero or more **dose reminders** — times of day that fire local notifications. Logging a nutrient silences the rest of **today's** reminders for it (today's total above 0); later days are untouched. Reminders can be configured both during nutrient creation (inline in the form) and via the "Reminders" section in the Edit Nutrient form. Notification permission is requested on first reminder add if not yet granted.

---

## Today Tab – Core Logging UX

The central feature (DESIGN.md §5.1). Large "Today" title with the date as the navigation subtitle, 44pt profile avatar top-right, `Surface/Ground` background.

- **Day-score card** (`DayScoreCard`) on top: segmented ring ("3/6 goals met"), headline ("Halfway there — 3 to go"; "N to go" never counts a goal over its limit, and with only over-limit goals left it reads "1 over limit": `DayScore.toGo` / `overLimit`), flame streak chip when streaks are on and ≥ 1, and the next reminder still scheduled later today (only when notifications are allowed; refreshed every minute). A nutrient logged today (today's total above 0, from any source) has no more reminders today, and the card follows the same rule as the scheduler (see Notifications). Notification / sync banners render below it on the card style, with a coral bell / blue iCloud icon tile.
- **Groups** with a `GroupHeader` (name, met-count chip, collapse chevron) — hidden when only the system group exists.
- **Nutrient cards** (`NutrientCard`): ring in the nutrient's tint with its symbol (amber near/over a limit, check badge when met), name, "**2,000** / 4,000 IU" ("max 400 mg" for at-most), status line ("2,000 IU to go", "Done", "80 mg left today"). − / + log one step with a light haptic (success when that + meets the goal); − is disabled when a step would take the total below 0. At accessibility text sizes the buttons move to their own row.
- **Tap a card, swipe right, or "Add Exact Amount"** → `LogSheet` (`.medium` / `.large` detents): ring header with today's total, amount stepper (defaults to one step, − / + change it by a step, editable `.decimalPad` field), quick chips ½× / 1× / 2× step and "Fill to goal" (remaining to the target or a range's lower bound; hidden for "at most" and once met), note field, "Log 1,000 IU" button (logs and dismisses), and the "Logged today" list (time, tint dot, signed amount, note) with a trash button that deletes the entry immediately with a haptic.
- **Swipe left** → Edit Nutrient sheet
- **Long press** → context menu: Add Exact Amount, Edit Nutrient, Move to Group
- **Empty state**: `ContentUnavailableView` with an "Add a nutrient" button that opens the new-nutrient form.

Status and colours come from `GoalProgress` (see Nutrient Goal Types). Exceeding a target is allowed.

Intake is computed by summing `IntakeRecord` rows for today's calendar day. No explicit midnight reset needed.

---

## History Tab

Redesigned in phase 6 (DESIGN.md §4.9, §5.4, §5.5). Read-only. Large "History" title with the profile avatar.

- **Streak card** (`StreakCard`, forest): flame, "10 days", "Current streak · every goal met", divider, best streak. Shown when streaks are on and there's a current or best streak.
- **Month calendar** (`MonthCalendar`): 7 columns from `Calendar.current.firstWeekday`. All goals met → `Brand/Green` fill with `Text/OnTint` number; some → green @ 25%; logged but nothing met → no fill with a faint `Surface/Chip` outline (it's tappable); nothing logged → plain; today → 2pt `Control/Primary` ring with a gap around the fill; future → secondary, disabled. Chevrons switch months (previous stops at the first month with data, next at the current month). Refreshes on appear and whenever the app becomes active, so today's ring moves after midnight. Past days with entries push `HistoryDayView`. Cells scale with Dynamic Type but never past their column; weekday letters go single-character and the legend stacks at accessibility sizes.
- **Recent days**: the last 7 completed days with entries — date, a dot per goal (tint if met, `Surface/Chip` if not), "4/6" (`Text/GreenInk` when all met), chevron.
- **Day detail** (`HistoryDayView`): weekday caption + date title (shown in the bar once scrolled), summary card (64pt `SegmentedDayRing` on light, "4 of 6 goals", "Missed Omega-3 and Protein"), then a row per goal: icon tile, "**4,000** / 4,000 IU", 8pt bar in the tint, green check / grey dash. "Also logged" lists nutrients logged that day that didn't count (removed since, or excluded). Tapping a row opens the day's entries (time, tint dot, signed amount, note, total).

**Which nutrients count on a day** (`HistoryLog`) — the same rule as `StreakService`: not deleted, created on or before the day, not excluded that day. A nutrient with nothing logged still counts (missed, unless it's an "at most" goal). A day with nothing logged at all shows no fill, so the calendar's "all goals" days are exactly the streak days. Covered by `HistoryLogTests`, `MonthGridTests`, `HistoryTextTests`.

---

## Nutrient Analytics

Redesigned in phase 5 (DESIGN.md §4.8, §5.3). Tapping a nutrient row in My Nutrients pushes `NutrientAnalyticsView` onto the My Nutrients `NavigationStack`; editing is also available via swipe or the context menu on the row.

- **Header** — 52pt `NutrientIconTile`, name (`.title.bold`), "At least 4,000 IU a day · Morning stack" (group only when it isn't General). The bar shows the name once the header scrolls away. Toolbar **Edit** opens `NutrientFormView`; saving refreshes the stats.
- **Period picker** — native segmented `Picker`: 7 / 30 / 90 days (default 7). Drives the stats and the chart; the heatmap is always the last 4 weeks.
- **Stats + chart card** — `StatTriplet`: Hit rate ("83 %", "5 of 6 days"), Daily avg (unit), Best day (weekday name for 7 days, a date for 30/90; "Peak day" for at-most and range goals, where the highest day isn't the best). Below it `DailyIntakeChart`: one bar per day in the nutrient's tint — met days full tint, missed days tint @ 35% — today as a dashed outline (with a faint fill), and dashed goal rules: "Goal X", "Limit X", or "Min" / "Max" for a range. Goal labels are drawn in the chart overlay because Swift Charts draws later bars over mark annotations.
- **Weekday heatmap card** — `WeekdayHeatmap`: seven squares from `Calendar.current.firstWeekday`, filled by hit rate (100% full tint, ≥ 75% @ 70%, ≥ 50% @ 40%, else 15%), percentage inside in `Text/OnTint` or white — whichever contrasts more with that square's fill (≥ 4.5:1 for every tint and level, light and dark; `ContrastColorTests`), weekday letter below. One sentence when a single weekday is ≥ 25 points below the average and every rated weekday has at least 2 days ("Sundays are your weakest day.") — no advice beyond that.
- **Reminders row** — times ("13:00", "8:00, 20:00", "3 a day" or "None"; `NutrientSummaryText`); opens `NutrientRemindersSheet`.
- **VoiceOver / Audio Graph** — each bar is labelled with its date and real total ("30 Mg, on target"); today reads "… so far" (its bar is drawn at least a sliver tall, but the value is the true total).

**Counting rules** (`AnalyticsSummary`, `WeekdayPattern`): a day's total is the SUM of its `IntakeRecord`s floored at 0, and "met" comes from `GoalProgress.countsAsMet`. Stats count only *completed, tracked* days — today is drawn but not counted until it's over, and days before `Nutrient.createdAt` don't count (same scoping as streaks). No counted days → "—". Best day is the highest total among counted days (earliest wins a tie; nothing logged → none).

`NutrientAnalyticsViewModel` does one manual `ModelContext` fetch of the nutrient's records over max(period, 29) days (no `@Query`), builds the summary, stat text and weekday pattern, and refreshes on period change, edit, and when the screen reappears. All the maths lives in the pure types, covered by `AnalyticsSummaryTests` and `WeekdayPatternTests`.

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

### Status colours and value text

`GoalProgress` (`Shared/Services/GoalStatus.swift`) drives every progress visual — Today and log-sheet rings, widgets, the Watch, History day bars — so there is no per-view colour logic (the old blue/green/orange `NutrientProgressBar` was retired in phase 11):

- **Ring** (`ProgressRing`): the nutrient's tint, or `Status/Amber` when an "at most" goal nears (≥ 75%) or passes its limit, or a range goes over; check badge when met. `ringFraction` maps the total to the target (at least), the limit (at most) or the upper bound (range).
- **Value**: "**2,000** / 4,000 IU" (`currentText` + `goalText`), "**240** max 400 mg" for at most, "**92** / 120–160 g" for a range.
- **Status line** (`remainingText`): "2,000 IU to go" / "Done", "80 mg left today" / "Limit reached" / "40 mg over limit", "28 g to range" / "In range" / "10 g over range" — coloured with `status.textColor` (`Text/GreenInk`, `Text/AmberInk`, secondary).

---

### NutrientFormView — setup UX

Redesigned in phase 4 (DESIGN.md §5.7). Sheet with **Cancel / title / Add (or Save)** in the toolbar, on `Surface/Ground`:

1. **Live preview row** (`NutrientPreviewRow`) — ring in the chosen tint and symbol, the name, "0 / 5 g · +5 g per tap"; updates as you type.
2. **Name + Unit** card (unit isn't auto-capitalised).
3. **Look** — `TintPicker` (8 swatches) and `SymbolPicker` (16 SF Symbols from DESIGN.md §3). New nutrients start on the first tint nobody uses yet (`NutrientTint.suggested(avoiding:)`).
4. **Daily goal** — `GoalTypePicker` cards (At least / At most / Between, each with a tiny bar) replace the segmented control; then "At least, per day" + "Each tap adds" (range: "Minimum, per day" + "Maximum", then "Each tap adds"). A range whose maximum isn't above the minimum shows an inline error and can't be saved.
5. **Group** row (new nutrients only — a dialog listing groups + "New Group…"; edits use Move to Group) and **Reminders** row (saved nutrient → `NutrientRemindersSheet`; new nutrient → `PendingRemindersSheet`, created with it).
6. **Notes**, then **Delete Nutrient** when editing.

`NutrientFormFields` (sections 2–4 + notes, with a slot for rows before notes) is shared with onboarding. Focus (`NutrientFormField`) is owned by the container, which declares the keyboard's Done button at the root of its toolbar — a keyboard toolbar declared inside the scroll view's content caused SwiftUI attribute-graph cycles. The draft's `apply(to:)` / `insertNutrient(into:group:sortOrder:)` (`Shared/Persistence/NutrientDraft+Persistence.swift`) are the only places a draft is written to a nutrient.

---

### Analytics

Hit rate, the chart's met/missed bars and the heatmap all judge a day with `GoalProgress.countsAsMet` (see below), so analytics, Today, History and streaks agree. Goal rules: `.minimum` → "Goal X", `.maximum` → "Limit X", `.range` → "Min" (label below the line) and "Max" (above). Best day is labelled "Peak day" for `.maximum` and `.range`.

### StreakService

`StreakService.compute` must evaluate each nutrient using its `goalType`. See the Streaks section above for the per-type conditions.

### GoalProgress — the shared "met" rule

`GoalProgress` (`Shared/Services/GoalStatus.swift`) owns the per-type conditions above: `StreakService`, History streak days, the analytics hit rate and the Today row all read `countsAsMet` instead of re-implementing them. Comparisons tolerate float drift from summed steps; a range with no `upperBound` behaves like `.minimum`. The redesigned UI also takes `status`, `ringFraction` and `remainingText` from it (DESIGN.md §2). Widgets use it via `NutrientSnapshot.progress` (phase 9) and the Watch app and complications since phase 10.

---

### File changes summary

| File | Change |
|---|---|
| `Models/Nutrient.swift` | Add `goalType: GoalType = .minimum`, `upperBound: Double? = nil` |
| `Shared/Services/GoalStatus.swift` | `GoalProgress`: status, ring fraction, text and `countsAsMet` for all three goal types |
| `Shared/Components/NutrientFormFields.swift` | Goal type picker + conditional `upperBound` field (redesigned in phase 4: cards + live preview row) |
| `Features/Today/ViewModels/TodayViewModel.swift` | No change — totals are still raw sums; status comes from `GoalProgress` |
| `Features/Nutrients/Views/DailyIntakeChart.swift` | Goal rules per type (Goal / Limit / Min + Max) |
| `Features/Nutrients/ViewModels/AnalyticsSummary.swift` | Met days via `GoalProgress.countsAsMet` |
| `Shared/Services/StreakService.swift` | Update per-nutrient completion check for all three goal types |

No new SwiftData models, services, or files required beyond the above edits.

---

## Notifications

All local — no push infrastructure. Two notification types:

1. **Daily check-in reminder** — fires at noon if no intake logged. Opt-in via Settings. Smart one-shot scheduling refreshed on foreground and after every intake action. ID: `daily-checkin-reminder`.
2. **Per-nutrient dose reminders** — configurable times per nutrient, scheduled as **one-off requests per date** for a rolling window (`ReminderSchedule`: up to 14 days, fewer with many reminders so all fit under iOS's 64 pending; the daily check-in takes one more). The rest of today is left out for a nutrient already logged today. `NotificationService.refreshAllNutrientReminders(context:)` is the only scheduler: it rebuilds the set from the data after every log change, on foreground and remote (iCloud) changes, and after reminder or nutrient edits, so logs from the widget, Watch or Siri count from the next sync. Syncs are serialized; requests for deleted nutrients, past times and the old repeating format are removed. Today's "next reminder" line uses the same rule. **Keeping the window rolling:** every sync asks for a background app refresh (`NotificationService.reminderRefreshTaskID`, `BGTaskSchedulerPermittedIdentifiers` + the `fetch` background mode in `Info.plist`, handled by `.backgroundTask(.appRefresh(...))` in `nutrxApp`) about 12 hours out, which runs the same sync. iOS decides when it runs, and it doesn't with Background App Refresh off, so the fallback is opening the app: with neither, reminders run out only after the full window (14 days for a few reminders; a single day only with 60+ reminders a day). IDs: `nutrient-{id}-reminder-{HHmm}-{yyyyMMdd}`. The sync logs "Dose reminders synced: N of M scheduled, K removed" (category `NotificationService`).

Permission flow handles not-asked, granted, and denied states. A one-time notification banner appears on Today after onboarding.

**Reinstall/new-device safety:** iOS resets notification permission on app delete, but CloudKit may sync stale `dailyReminderEnabled` and `hasSeenNotificationBanner` flags. On appear, both TodayView and NotificationsSettingsView check the actual iOS permission status — if `notDetermined`, they reset the synced flags so the banner reappears and the toggle reflects reality.

---

## Nutrient Grouping

Nutrients are organised into named groups. Collapsible sections on Today (with met counts); inset cards with counts on My Nutrients.

- **General group** — system group (`isSystem = true`), always exists, cannot be renamed/deleted. Nutrients with `group = nil` resolve to General at query time.
- **Group management** — Settings → Groups (`ManageGroupsView`). Create, rename, reorder, delete (moves nutrients to General).
- **Move to Group** — via context menu on nutrient rows. Half-sheet with group list and inline "New Group" option.
- Group headers hidden when only General group exists.

---

## Streaks

Daily streak tracking, opt-in via `UserPreferences.streaksEnabled` (default `true`). A streak day is a completed past day where all active non-excluded nutrients met their targets. Today is never counted. `Nutrient.createdAt` scopes each nutrient's streak window.

**Goal type awareness:** `StreakService` must evaluate each nutrient's `goalType` when deciding whether a day counts toward a streak:
- `.minimum` — total ≥ `dailyTarget`
- `.maximum` — total ≤ `dailyTarget`
- `.range` — total ≥ `dailyTarget` AND total ≤ `upperBound`

**UI:** flame streak chip in Today's day-score card (when ≥ 1), summary card in History, streak labels in small/medium widgets. `StreakService.compute(context:) → StreakResult` runs on foreground and after intake actions.

---

## In-App Review Prompt

Uses `SKStoreReviewController` — no custom UI. Triggered after intake actions when any condition is met: streak hits 3/7/14 days, or total intake count crosses 30. Guards: once per app version, 90-day cooldown, account age ≥ 3 days, never on cold launch. Implemented in `ReviewService`.

**Settings → Rate nutrx** doesn't use the system prompt (iOS shows it at most three times a year and never in TestFlight, so a tap could do nothing). It opens the App Store's review page, `ReviewService.writeReviewURL` (`https://apps.apple.com/app/id6760843478?action=write-review`; app ID from App Store Connect), and records the prompt so the automatic one doesn't also ask for this version.

---

## Widgets

Five widget configurations in `NutrxWidgetsExtension`, redesigned in phase 9 (DESIGN.md §5.10). Kind IDs and supported families never change — widgets people have placed would disappear.

| Widget (gallery name) | Kind ID | Families | Content |
|---|---|---|---|
| Today | `NutrxSmallWidget` | `.systemSmall` | Forest card: "Today" + flame streak, `SegmentedDayRing` + "3/6 goals met", "Next: Vitamin D" (first goal that still needs more, in Today order; "1 over limit" or "All done for today" when none) |
| Quick log | `NutrxMediumWidget` | `.systemMedium` (+ small / large) | White rows: `ProgressRing` in the tint, name, "**2,000** / 4,000 IU", interactive + (`LogNutrientIntent`). 3 rows; 2 compact in small, 6 + header in large |
| Goals | `NutrxCircularWidget` | `.accessoryCircular` | Lock Screen capacity gauge with "3/6" |
| Next up | `NutrxRectangularWidget` | `.accessoryRectangular` | Lock Screen: first goal that still needs more — name, value, linear bar; else "1 over limit" or "All done" + "5/6 goals met" |
| Goals and streak | `NutrxInlineWidget` | `.accessoryInline` | "3/6 goals · 10-day streak" |

`NutrientSnapshot` (`WidgetEntry.swift`) carries tint, symbol and goal type and takes status / ring fraction / text from `GoalProgress`; widget text comes from `Shared/Services/WidgetSummary.swift` (tested in `WidgetSummaryTests`). `ProgressRing`, `SegmentedDayRing` and `WidgetSummary` are compiled into the widget target via membership exceptions. In widgets, set rounded numerals as `.font(.title.weight(.bold)).fontDesign(.rounded)` — `Font.system(_:design:weight:)` drops the weight there.

**Infrastructure:** App Group `group.nutrx-labs.nutrx` for shared SwiftData store. `LogNutrientIntent` (AppIntent) for interactive + buttons — target membership must include both app and widget extension. `ModelContainerFactory` shared across both targets. No `@Query` in widgets — manual `ModelContext` fetches in `TimelineProvider`, which opens the store read-only with `ModelContainerFactory.createForExtension(allowsSave: false)`. "Next up" means `GoalProgress.needsMore` (below an "at least" target or a range's lower bound), never an "at most" goal or one over its limit. Widgets refresh on intent completion and app foreground.

---

## iCloud Sync

Automatic CloudKit sync across all Apple devices. On by default, no setup required.

**Key details:**
- Container: `iCloud.nutrx-labs.nutrx`. Falls back to local-only if CloudKit unavailable.
- Entitlements: the app has iCloud + CloudKit; the widget extension has only the App Group. Extensions open the shared store with `ModelContainerFactory.createForExtension()` (no CloudKit, none of `create()`'s upgrade / backup / seeding steps) — `LogNutrientIntent` does this when running in the widget, the widget timeline and Watch complications read-only (`allowsSave: false`), and the app's CloudKit mirroring exports what the widget wrote when the app next runs. Never call `create()` from an extension: without the entitlement the CloudKit setup can crash it, and its one-off upgrade steps key off the extension's own `UserDefaults`.
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

**Pre-Pro Sprint:** Nutrient goal types (min/max/range), data export (CSV), quick-log stacks, Siri & App Shortcuts — see ROADMAP.md for full specs and the Siri & App Shortcuts section below for implementation details

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

Single instance, created empty when onboarding finishes; every field is optional and edited from Profile.

| Field | Type | Notes |
|---|---|---|
| `name` | `String` | Free text; `""` = not set (avatar shows a person symbol) |
| `birthdate` | `Date` | Date only; `Date.distantPast` = not set |
| `weight` | `Double` | In user's chosen unit; 0 = not set |
| `weightUnit` | `String` | `"kg"` or `"lbs"` |
| `height` | `Double` | In user's chosen unit; 0 = not set |
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
| `notes` | `String?` | Shown in the edit form and as the reminder notification body; not on the redesigned Today or My Nutrients rows |
| `group` | `NutrientGroup?` | `nil` → General group |
| `createdAt` | `Date = Date()` | Used by streak computation |
| `goalType` | `GoalType = .minimum` | `.minimum`, `.maximum`, or `.range` — see Nutrient Goal Types section |
| `upperBound` | `Double? = nil` | Only non-nil when `goalType == .range`. `dailyTarget` acts as the lower bound. |
| `tintRaw` | `String = ""` | `""` = never chosen. Read via `tint: NutrientTint`, which falls back to a stable id-derived tint (no migration). |
| `symbolName` | `String = "pills"` | SF Symbol shown in the nutrient's ring and icon tile. |

**Relationships:** → many `IntakeRecord`? (cascade), → many `Exclusion`? (cascade), → many `NutrientReminder`? (cascade), → one `NutrientGroup?` (nullify)

---

### IntakeRecord

Single logging event. Total = SUM of all records for a nutrient on a calendar day.

| Field | Type | Notes |
|---|---|---|
| `nutrient` | `Nutrient` | Relationship |
| `amount` | `Double` | Can be negative (decrements) |
| `date` | `Date` | Full timestamp, use calendar-day comparison for grouping |
| `note` | `String?` | Optional, set in the log sheet |

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

Scheduled dose reminder for a nutrient. Maps to one one-off local notification per date in the rolling window (see Notifications).

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