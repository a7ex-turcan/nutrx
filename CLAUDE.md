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

## App Store screenshots

- **Demo data:** debug builds launched with `-screenshotDemoData` (`Shared/Persistence/ScreenshotDemoData.swift`, also compiled into the Watch app) replace everything in the store with the redesign-render data set: Morning stack / Through the day, 3/6 goals met today, a 10-day streak, seven weeks of history with Vitamin D missed on Sundays. Example: `xcrun simctl launch <UDID> nutrx-labs.nutrx -screenshotDemoData`. Never in Release. **Only on simulators signed out of iCloud:** the store is CloudKit-backed, so on a signed-in device it wipes that account's development data on every synced device. `ScreenshotDemoDataTests` checks the set still gives a 10-day streak, 3/6 today and a Sunday insight.
- **Capture** on the iPhone 6.9″ (1320×2868), iPad 13″ (2064×2752) and Apple Watch 46mm (416×496) simulators: `xcrun simctl status_bar <UDID> override --time "9:41" …`, en_US region (reboot after changing it, or the clock reads "09:41"), notifications allowed so Today shows its next-reminder line.
- **Compose:** `swift Tools/AppStoreScreenshots/compose.swift Tools/AppStoreScreenshots/panels.json <raw dir> <out dir>`. `panels.json` sets each panel's capture, two-line headline and style (`forest`, or `light` for the dark-mode shot); the output is opaque PNG at the App Store size. `background-forest.jpg` was generated once with gpt-image-2. Watch screenshots go up as plain captures, flattened to JPEG (App Store Connect rejects an alpha channel).
- **Header and search artwork:** `swift Tools/AppStoreScreenshots/compose-header.swift <iPhone capture> <Watch capture> <output.png> [--guides]` makes the universal 5244×2950 creative asset (headline left, Today in an iPhone + the Watch app right, inside the area both the 21:9 header and 3:2 search crops keep; `--guides` draws those crops for review). It redraws the Watch's status-bar clock as 9:41, which the Watch simulator can't override. Background: `background-forest-wide.jpg` (gpt-image-2, once). **Upload through the asset library API:** `post /v1/appAssetLibraryImages` (`category: CREATIVE_ASSETS`, `fileName`, `fileSize`, relationship `assetLibrary` = the app id) returns upload operations; PUT the parts, then `patch` it with `uploaded: true` (no checksum attribute here). Once it reaches `PREPARE_FOR_SUBMISSION`, `post /v1/appAssetLibraryPlacements` once per placement, with `placementType` `PRODUCT_PAGE_HEADER_ASSET` or `APP_STORE_SEARCH_RESULTS_ASSET`, relationships `appStoreVersionLocalization` + `image`. A universal image can back both. Check the result with the Preview on the Header and Search Results tab.
- Screenshots show the real app only — never generated or mocked-up UI.

## Swift Configuration

Notable build settings in the Xcode project:
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — All types default to `@MainActor`
- `SWIFT_APPROACHABLE_CONCURRENCY = YES` — Strict concurrency checking enabled
- SwiftUI previews enabled (`ENABLE_PREVIEWS = YES`)
- Xcode project uses `PBXFileSystemSynchronizedRootGroup` — new files added to the `nutrx/` directory are auto-discovered by Xcode (no manual pbxproj edits needed)

## What is this app?

nutrx is a privacy-first iOS app for tracking daily nutrient intake.
It is intentionally simple, flexible, and fully offline — no accounts, no servers, no ads.
nutrx Pro (in progress, `docs/pro/PLAN.md`) only adds new things around tracking;
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
│   ├── LogStack.swift           # A named set of nutrients with preset amounts, logged in one go (stacks).
│   ├── LogStackEntry.swift      # One nutrient + amount in a LogStack.
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
│   │   │   ├── StacksRow.swift              # Today's "Stacks" header + Edit and the stack cards (sideways, or one full-width card).
│   │   │   ├── LogStackSheet.swift          # Log a stack: per-entry amounts for this time, then the done state with Undo.
│   │   │   ├── RecapTodayCard.swift         # "Your week" (Pro): Sunday 18:00 through Monday, ✕ hides it for that week.
│   │   │   ├── StackSuggestionCard.swift    # "Log several at once" / Make a stack, before any stack exists (3+ nutrients).
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
│   │   │   ├── SupplySheet.swift                # Supply (Pro): servings, each serving, remind me, sentence, Refilled today.
│   │   │   ├── SupplyCard.swift                 # Analytics Supply card: free teaser / Set up / days left, gauge, Refilled.
│   │   │   ├── HealthTrendsCard.swift           # Analytics "With Apple Health" (Pro): findings with two bars, or the state.
│   │   │   ├── ScanLabelEntry.swift             # Scan a label (Pro): entry card + reading note + divider; ScanReviewBanner.
│   │   │   ├── LabelScannerView.swift           # Full-screen VisionKit scanner (or a photo), reading pill, ScanFailCard.
│   │   │   ├── NutrientAnalyticsView.swift      # Per-nutrient analytics, pushed on row tap: header, period picker, stats + chart card, heatmap, Reminders row, Edit.
│   │   │   ├── StatTriplet.swift                # Hit rate / Daily avg / Best day columns (stack at accessibility sizes).
│   │   │   ├── DailyIntakeChart.swift           # Swift Charts bars in the tint, dashed today outline, dashed goal rule(s) + labels.
│   │   │   └── WeekdayHeatmap.swift             # 7 squares by 4-week hit rate + "Sundays are your weakest day."
│   │   └── ViewModels/
│   │       ├── NutrientAnalyticsViewModel.swift # Fetches day totals for the nutrient; exposes goal, summary, stats, weekdayPattern for the selected period.
│   │       ├── AnalyticsSummary.swift           # AnalyticsDay / AnalyticsGoal / AnalyticsSummary — period days, hit rate, average, best day (pure).
│   │       ├── LabelParser.swift                # Scan a label: SupplementLabel + the rule-based reader (pure).
│   │       ├── LabelExtractor.swift             # On-device model (guided generation), checked against the text, parser fallback.
│   │       ├── LabelPrefill.swift               # Fills the new-nutrient draft from a read label; banner and unread hints.
│   │       ├── LabelTextRecognizer.swift        # Vision text recognition, pieces joined into rows.
│   │       ├── LabelScan.swift                  # Photo → label (recognise, extract; nil = couldn't read) + ScanText copy.
│   │       ├── WeekdayPattern.swift             # Per-weekday hit rate over the last 28 days, weakest-day insight, heatmap fill levels (pure).
│   │       ├── HealthTrends.swift               # Health trends (Pro): HealthDay + findings vs sleep, workouts, active energy (pure).
│   │       ├── HealthText.swift                 # "With Apple Health" card copy: findings, bars, basis, states (pure).
│   │       ├── AnalyticsStat.swift              # Formatted stat-triplet text ("83 %", "5 of 6 days", "Peak day").
│   │       └── NutrientSummaryText.swift        # Analytics header goal line + Reminders row summary ("None", "13:00", "3 a day").
│   │
│   ├── History/                 # Tab 3 — read-only log of past days.
│   │   ├── Views/
│   │   │   ├── HistoryListView.swift        # Large title; StreakCard, MonthCalendar card, "Recent days" (dots + score). Taps push HistoryDayView.
│   │   │   ├── StreakCard.swift             # Forest card: flame, "10 days · Current streak", divider, best streak.
│   │   │   ├── MonthCalendar.swift          # Month grid (first weekday from the locale), all / some / none fills, today ring, chevrons, legend.
│   │   │   ├── HistoryDayView.swift         # Weekday + date header, SegmentedDayRing summary, tint-bar rows with met badge, entries sheet.
│   │   │   └── WeeklyRecapView.swift        # Recap (Pro): forest hero, fact cards, earlier weeks, share; first-week state.
│   │   └── ViewModels/
│   │       ├── HistoryViewModel.swift       # Fetches nutrients / intake / exclusions into a HistoryLog; streak; displayed month.
│   │       ├── HistoryLog.swift             # HistoryDay / DayCompletion — which nutrients count on a day and whether they were met (pure).
│   │       ├── MonthGrid.swift              # Month layout: leading blanks, days, weekday symbols (pure).
│   │       ├── HistoryText.swift            # "10 days", "4 of 6 goals", "Missed Omega-3 and Protein".
│   │       ├── WeeklyRecap.swift            # Recap (Pro): a Monday–Sunday week's facts from a HistoryLog (pure).
│   │       ├── RecapText.swift              # Recap copy: range, headline, template summary, cards, notification.
│   │       ├── RecapPhrasing.swift          # On-device rewording of the summary, checked against the facts, cached per week.
│   │       ├── RecapViewModel.swift         # The last 8 weeks' recaps, the running week, summaries (template, then rewording).
│   │       └── RecapSchedule.swift          # Sunday 18:00 recap notification (plan, body), Today card window, settings key.
│   │
│   ├── About/
│   │   └── Views/
│   │       └── AboutView.swift              # Shown inside SettingsView: brand mark, version, three cards.
│   │
│   ├── Settings/
│   │   ├── Views/
│   │   │   ├── SettingsView.swift           # Large title, profile card, icon-tile rows (iCloud Sync, Notifications, Streaks, Groups, Stacks; Export data; Rate nutrx, About) with values, privacy footer.
│   │   │   ├── ICloudSyncSettingsView.swift # Status, sync toggle, Delete iCloud Data.
│   │   │   ├── NotificationsSettingsView.swift # Noon check-in toggle + permission flow.
│   │   │   ├── StreaksSettingsView.swift    # Streaks toggle.
│   │   │   ├── ManageGroupsView.swift       # Create, rename, reorder, delete groups (counts exclude deleted nutrients).
│   │   │   ├── StacksView.swift             # Settings → Stacks: list, reorder, swipe to delete, create; empty state.
│   │   │   ├── StackDetailView.swift        # One stack: name, nutrients with amounts, add / remove / reorder, Siri tip, delete.
│   │   │   ├── ExportDataView.swift         # Settings → Export data: period, entry count, Export CSV → share sheet, done strip.
│   │   │   ├── AppleHealthSettingsView.swift # Settings → Apple Health (Pro): switch, what's read (data found?), privacy, Disconnect.
│   │   │   └── ProSettingsCard.swift        # Settings' nutrx Pro card (free: Learn more → paywall; Pro: status → ProStatusView).
│   │   └── ViewModels/
│   │       └── SettingsSummary.swift        # Row values: "On", "Noon check-in", "No account", group count, profile title.
│   │
│   ├── Pro/                     # nutrx Pro (hidden until phase 4; see nutrx Pro: StoreKit).
│   │   ├── Views/
│   │   │   ├── PaywallView.swift            # The paywall sheet; .proPaywall(isPresented:).
│   │   │   ├── ProWelcomeView.swift         # "Welcome to nutrx Pro" after buying or restoring.
│   │   │   └── ProStatusView.swift          # Pro screen: plan, included features, manage, restore.
│   │   └── ViewModels/
│   │       ├── ProFeature.swift             # The five Pro features; `listed` = shipped ones only.
│   │       └── ProText.swift                # Paywall / status copy (pure).
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
    │   ├── HealthIntroView.swift            # Before the Health permission sheet: what's read, read only; HealthTypesCard, HealthPrivacyNote.
    │   ├── StackPickerSheet.swift           # Stacks a nutrient is in + New Stack… (My Nutrients' Add to Stack…, the new-nutrient form).
    │   ├── CameraView.swift                 # UIImagePickerController wrapper for camera capture.
    │   ├── SyncLoadingView.swift            # Spinner during CloudKit sync wait.
    │   ├── SyncBannerView.swift             # Dismissible iCloud sync banner.
    │   ├── ProfileMenuButton.swift          # 44pt ProfileAvatar with the Edit Profile / Settings menu.
    │   ├── ProfileToolbarModifier.swift     # .withProfileMenu() modifier.
    │   ├── ProBadge.swift                   # PRO chip, ProWordmark, ProRingMotif, ProRingTile.
    │   └── ProGate.swift                    # ProGatedButton: Pro entry points (badge + paywall for free users).
    ├── Persistence/
    │   ├── ModelContainerFactory.swift      # CloudKit-backed config with local fallback; createForExtension() for widgets / complications (no CloudKit).
    │   │                                    # Backs up local store before first CloudKit init to prevent data loss.
    │   │                                    # Singleton deduplication. Logs via os.log.
    │   ├── NutrientDraft+Persistence.swift  # insertNutrient / apply(to:) — the only writers of a draft to a Nutrient.
    │   ├── NutrientGroup+Create.swift       # NutrientGroup.create(named:among:in:) — new user group before General.
    │   ├── PreviewSampleData.swift
    │   └── ScreenshotDemoData.swift         # DEBUG: -screenshotDemoData replaces the store with the App Store demo set.
    ├── Intents/                         # App only. Siri & Shortcuts (see "Siri & App Shortcuts").
    │   ├── LogNutrientShortcutIntent.swift  # "Log Nutrient": nutrient + optional amount; NutrientShortcutLogging.
    │   ├── NutrientEntity.swift         # AppEntity + EntityStringQuery: nutrients by name, in Today's order.
    │   ├── LogStackShortcutIntent.swift # "Log Stack": a stack by name; StackShortcutLogging (+ the Siri tip's phrase).
    │   ├── StackEntity.swift            # AppEntity + EntityStringQuery: stacks by name, in Today's order.
    │   └── NutrxShortcuts.swift         # AppShortcutsProvider: "Log my <nutrient> with nutrx", "Log my <stack> stack with nutrx".
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
        ├── StackLogging.swift               # Stacks: active entries, log (with per-time amounts), undo, add, "done today".
        ├── ExportService.swift              # CSV export: entries for a period, RFC 4180 CSV, file name, temp file.
        ├── ProAccess.swift                  # nutrx Pro: StoreKit 2 entitlement (never stored), products, purchase, restore.
        ├── ProEntitlement.swift             # Pro products + the pure "what unlocks Pro" rule + a StoreKit read (no ProAccess needed; also in the widget).
        ├── SupplySchedule.swift             # Supply: remaining, daily use, days left, level (pure); Nutrient.supplyStatus / refillSupply.
        ├── SupplyText.swift                 # Supply copy: Today hint, analytics card, sheet sentence.
        ├── RefillSchedule.swift             # Refill reminders: when (one per bottle, 10:00), snooze, title/body (pure).
        ├── NotificationHandler.swift        # UNUserNotificationCenterDelegate (refill actions, taps) + NotificationRouter.
        └── ReviewService.swift              # SKStoreReviewController prompt at streak milestones or intake count 30;
                                             # writeReviewURL (App Store review page) for Settings → Rate nutrx.
```

Outside `nutrx/`, besides the other targets: `StoreKit/nutrxPro.storekit` is the local StoreKit configuration (see nutrx Pro: StoreKit), and `Tools/` holds the App Store Connect and screenshot tools.

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
- `ModelContainerFactory`, all Model files and the design system (`Theme.swift`, `Colors.xcassets`, `GoalStatus.swift`) are added to the Watch targets via target membership exceptions (not duplicated) — plus `ProgressRing`, `ContrastColor`, `WidgetSummary`, `ScreenshotDemoData` for the app and `SegmentedDayRing`, `StreakService`, `WidgetSummary` for the complications
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

Built in phase 2 of the Pro plan (free). Everything lives in `Shared/Intents/` and is compiled into the **app only**:

- **`LogNutrientShortcutIntent`** — "Log Nutrient": `nutrient: NutrientEntity` plus an optional `amount: Double?` (empty → one step). Its parameter summary reads "Log 0.5 of Water", or "Log one step of Vitamin D" with Amount under the action's expanded options. A parameter that's in neither the summary nor the expanded options can't be set in the Shortcuts editor. `perform()` uses `NutrientShortcutLogging.log` (testable, no App Intents types) to insert one `IntakeRecord` and save. It then does a + tap's follow-ups (daily reminder, `refreshAllNutrientReminders`, widget reload) and answers "Logged 1,000 IU of Vitamin D. 3,000 of 4,000 IU today." An amount ≤ 0 or a deleted nutrient throws a spoken error.
- **`NutrientEntity` / `NutrientEntityQuery`** — nutrients picked **by name, never by id**: an `EntityStringQuery` that ignores case and accents, puts prefixes first, and suggests non-deleted nutrients in Today's order (group, then within group; General last).
- **`NutrxShortcuts`** (`AppShortcutsProvider`) — "Log \(nutrient) in nutrx", "Log my \(nutrient) with nutrx", "Add \(nutrient) in nutrx", "Log a nutrient in nutrx". No setup needed: they appear in Siri, Spotlight and Shortcuts. The parameters are refreshed with `updateAppShortcutParameters()` whenever the app becomes active.
- **One store:** App Intents run in the app's process. `nutrxApp` registers its `modelContainer` with `AppDependencyManager`, and the intent and query read it through `@Dependency` — never a second `ModelContainerFactory.create()` (two CloudKit-mirrored containers on one store fight).
- **The widget's + button** keeps its own `LogNutrientIntent` (`NutrxWidgets/`, widget extension only, raw id parameter), marked `isDiscoverable = false` so it never shows in Shortcuts.
- **`LogStackShortcutIntent`** — "Log Stack": `stack: StackEntity` ("Log the Morning stack"). `perform()` uses `StackShortcutLogging.log` → `StackLogging.log` (the same records and `lastLoggedAt` as Log on Today), does the same follow-ups, and answers "Logged Morning: 2,000 IU Vitamin D, 1,000 mg Omega-3, and 400 mg Magnesium." A stack that's gone or has nothing to log throws a spoken error. Phrases: "Log my \(stack) stack with nutrx" (first — the Siri tip shows it), "… in nutrx", "Log the \(stack) stack in nutrx", "Log a stack in nutrx".
- **`LogStack.id` and migration:** adding a property with a `UUID()` default to an existing store gives every existing row the *same* value (checked: stacks from a #54 build all got one id). `StackLogging.repairDuplicateIDs` gives duplicates new ids (keeping the oldest stack's). `nutrxApp` runs it at launch, because Siri can launch the app in the background, and whenever the app becomes active, because a synced device can bring duplicates. Any future UUID field on an existing model needs the same.
- **`StackEntity` / `StackEntityQuery`** — stacks by name (`LogStack.id`, a UUID, is only an identifier), suggested in Today's order and only when they have something to log; an empty stack still resolves by id. Stack names change, so `StackShortcutLogging.stacksChanged()` refreshes the phrase parameters after a stack is created, renamed or deleted (Settings → Stacks, the detail screen), besides the refresh when the app becomes active.
- **Siri phrases always name the app**, so the Siri tip says “Log my Morning stack **with nutrx**”, not the design's “Log my Morning stack”.
- Tests: `NutrientShortcutTests`, `StackShortcutTests`. Not built yet: a Settings → Siri screen, and the Watch (the App Shortcuts are the iPhone app's).

---

## Onboarding

Redesigned in phase 7 (DESIGN.md §5.8). Shown on first launch. Two steps:

1. **Welcome** (`OnboardingWelcomeView`) — full-bleed `Brand/Forest` in both appearances: the brand mark (`BrandMark` image asset — the app icon's "n+" extracted as a template image, tinted `Brand/Green`; never redraw the logo in code), "Track what you take. **Nothing else.**", three benefits, "Get started" (`Brand/Green`, `Text/OnTint`). Scrolls only when large text doesn't fit.
2. **First nutrient** (`OnboardingFirstNutrientView`) — back, 2-step progress, **Skip**; "What do you want to track first?"; a 2-column grid (1 column at accessibility sizes) of `StartingPoint`s and a dashed **Something else** (opens the blank `NutrientFormView`). Picking a starting point fills an editable draft and shows its goal fields above the button, empty: daily goal (or minimum / maximum for a range) and each-tap step. **Start tracking** (chip-grey while disabled) is enabled once they're valid and creates it in General via `insertNutrient` — nothing is created until then. The goal fields sit in the screen's bottom inset with the button; while one is focused a **Done** button at the top of that panel hides the number pad. Don't move Done back into a keyboard toolbar: with the fields in the inset it made SwiftUI log attribute-graph cycles on the first keyboard open, and from the third open the panel stopped clearing the floating Done bar, which covered Start tracking (#19). At accessibility sizes the fields stack, and stacked they don't fit in that panel above the keyboard (with a range it hid Back and Skip, then pushed Done under the status bar and Start tracking behind the keys). So there they scroll with the content, right below the picked card, and the panel keeps only Done and Start tracking. Picking a card scrolls its fields into view, and so does focusing a field once the keyboard is up. The one column is a plain `VStack` there: in the lazy grid, the list jumped back to an old position on a pick after scrolling (#40).

Starting points are pre-fills, not a preset list: Vitamin D, Magnesium, Omega-3, Water, Protein (a range), Creatine — name, unit, goal type, tint and symbol from the DESIGN.md table. **They carry no amounts:** nutrx doesn't recommend intakes, so the user types the goal and step. Don't add suggested numbers back.

Personal info is no longer asked for: finishing (Start tracking, Something else, or Skip) creates an empty `UserProfile` with `onboardingCompleted = true`; name, birthday, weight and height are edited later from Profile, where every field is optional. Completion is tracked via `UserProfile.onboardingCompleted`. On a new device with iCloud data, onboarding is skipped if a completed profile syncs within 3 seconds.

---

## Nutrient Configuration

Users create and manage their own nutrients. No preset list — fully user-defined. Each nutrient has: **name**, **unit**, **step** (increment per +/− tap), **daily target**, a **tint** and **SF Symbol**, and optional **notes**. Nutrients can be reordered via drag-and-drop. Order in My Nutrients = order on Today screen.

**My Nutrients** (DESIGN.md §5.6): large title, toolbar + (filled forest circle) and profile. Groups are inset cards with uppercase headers and a count (headers hidden when only General exists; every nutrient is listed — collapsing is a Today thing). Row: icon tile, name, goal-type tag ("AT LEAST" / "AT MOST" / "BETWEEN") + target, bell if it has reminders, chevron → analytics. Swipe right = edit, swipe left = delete, long press = Edit / Move to Group / Delete, drag to reorder. A dashed **New group** button ends the list.

Each nutrient supports zero or more **dose reminders** — times of day that fire local notifications. Logging a nutrient silences the rest of **today's** reminders for it (today's total above 0); later days are untouched. Reminders can be configured both during nutrient creation (inline in the form) and via the "Reminders" section in the Edit Nutrient form. Notification permission is requested on first reminder add if not yet granted.

---

## Stacks

Built in phase 2 of the Pro plan (free). Mockups: `docs/pro/design/1-stacks-export/`.

- **What:** `LogStack` (name, `sortOrder`, `lastLoggedAt`) with ordered `LogStackEntry`s (nutrient + amount, starting at the nutrient's step). Logging a stack inserts one `IntakeRecord` per entry — the same records as a + tap, so totals, streaks, History, widgets and the Watch need nothing new.
- **Rules** (`StackLogging`, tested in `StackLoggingTests`):
  - A stack skips entries whose nutrient is deleted, since a soft-deleted nutrient keeps its entries for history.
  - Zero amounts are skipped.
  - `lastLoggedAt` is set only when something was logged, and "done today" is the same calendar day, from any device.
  - Undo deletes exactly the records that log added and restores the previous `lastLoggedAt`.
  - − / + in a stack move by the nutrient's step and never go below one step.
- **Today:** `StacksRow` sits between the day-score card (and banners) and the first group, with only stacks that have something to log.
  - Several stacks scroll sideways as 176pt cards; a single stack is one full-width card.
  - Logged today: a green check and a ghost "Log again".
  - Edit opens Settings → Stacks in a sheet.
- **Log sheet:** `LogStackSheet` changes amounts for **this time only**; the entry amounts don't change. It logs through `TodayViewModel.logStack`, which does a + tap's follow-ups (reminders, widgets) and the success haptic when an entry meets a goal.
  - The done state shows "+1,000 IU" per row and "Logged 3 nutrients at 08:12", with Undo and Done.
  - "Edit stack" closes the sheet and then opens that stack's detail (chained through the sheet's `onDismiss`, never two sheets at once).
- **Settings:** a Stacks row (teal tile) under Groups.
  - `StacksView` lists stacks in Today's order, with reorder, swipe to delete (with a confirmation; logged entries stay) and + to create one (named in an alert, then opened).
  - `StackDetailView` has the name, the entries with − / +, swipe to remove, drag to reorder, Add nutrient and Delete stack.
    - Delete stack dismisses first and deletes in `onDisappear`, so the view never renders a deleted model.
    - An emptied name falls back to "Stack" on focus loss and on disappear.
- **Finding and filling stacks** (besides Settings → Stacks):
  - **Today** shows `StackSuggestionCard` ("Log several at once", **Make a stack**, ✕) where the Stacks row would be, once there are three or more nutrients and no stack yet, until it's hidden (`@AppStorage("nutrx.hidesStackSuggestion")`; the rule is `StackLogging.suggestsStack`). Make a stack names it in an alert, then opens its detail to add nutrients.
  - **My Nutrients:** long-press → **Add to Stack…** opens `StackPickerSheet` (checklist of stacks + New Stack…); each tap adds the nutrient at one step or takes it out (`StackLogging.toggle`).
  - **New-nutrient form:** a **Stacks** row under Group (not in onboarding) with the same sheet. Choices are kept on the draft (`NutrientDraft.pendingStacks`: existing stacks by id, new ones by name) and applied by `insertNutrient` (`StackLogging.add(_:toStacks:)`), so a new stack is created only when the nutrient is added and Cancel leaves none behind. Scan a label keeps the choices.
  - **New Stack** reads the same everywhere (`StackLogging.newStackMessage`, which suggests an unused name; the field's placeholder is "Stack name" because in an alert it's the field's only accessible name, and a `prompt:` drops the title; Create off while empty), and a name that's already a stack picks or opens that one (`StackLogging.stack(named:in:)`), so there are never two stacks Siri can't tell apart.
- **Siri:** "Log my Morning stack with nutrx" (see Siri & App Shortcuts). The detail screen shows a Siri tip card with that phrase when the stack has something to log; its ✕ hides it on that device for every stack (`@AppStorage("hidesStackSiriTip")`).

## Data Export (CSV)

Built in phase 2 of the Pro plan (free). Mockups: `docs/pro/design/1-stacks-export/export*.png`.

- **Settings → Export data** (grey tile, its own section; Apple Health and the doctor report join it with Pro) pushes `ExportDataView`. It has a document tile with the title, what the file holds, and a period card: All time, Last 30 days or Last 90 days. "Last 30 days" is today and the 29 days before it.
  - The count line reads "**1,284** entries · 6 nutrients · since 2 March 2026", or "No entries in this period", which disables the button.
  - **Export CSV** writes the file and opens the system share sheet. It's a `UIActivityViewController` wrapper, because `ShareLink` has no completion and the done state needs to know the file was sent.
  - Once the file is sent, a green strip shows "Exported N entries" with the file name, and the button reads **Export again**. Changing the period clears it.
- **The file** (`ExportService`, tested in `ExportServiceTests`):
  - One row per `IntakeRecord`, newest first, with the header `date,time,nutrient,amount,unit,note`.
  - Dates are `yyyy-MM-dd` and times are 24-hour `HH:mm`, in the user's time zone.
  - Amounts are plain `en_US_POSIX` numbers with no grouping. Decrements stay negative.
  - The file follows RFC 4180: CRLF line ends, and fields are quoted when they hold a comma, quote or line break. Quoting checks Unicode scalars, because `"\r\n"` is one `Character`.
  - It starts with a UTF-8 BOM for Excel.
  - Names, units and notes that start with `= + - @` get a leading `'`, so a spreadsheet won't run them as formulas. Numbers never do.
  - Nutrients deleted since are included, because it's the user's history.
  - The name is `nutrx-export-YYYY-MM-DD.csv`.
- **No copy stays on the device:** the file goes in its own folder under `tmp/nutrx-export/`, which is removed when the share sheet closes, whether the file was sent, cancelled or swiped away. Each export also clears that parent first, which covers a file left behind when the app was killed with the share sheet up.
- The footnote and the error alert name the device (`UIDevice.current.model`: iPhone or iPad).

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

`NutrientFormFields` (sections 2–4 + notes, with a slot for rows before notes) is used by `NutrientFormView`; onboarding has its own goal fields on the same `NutrientDraft`. Focus (`NutrientFormField`) is owned by the container, which declares the keyboard's Done button at the root of its toolbar — a keyboard toolbar declared inside the scroll view's content caused SwiftUI attribute-graph cycles. That toolbar makes SwiftUI log "Invalid frame dimension" on the sheet's first keyboard open and when it closes with the keyboard up; a bare sheet with one field and the toolbar logs it too, there's no visible effect, and it's left as is (#41). The draft's `apply(to:)` / `insertNutrient(into:group:sortOrder:)` (`Shared/Persistence/NutrientDraft+Persistence.swift`) are the only places a draft is written to a nutrient.

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

All local — no push infrastructure. Four notification types:

1. **Daily check-in reminder** — fires at noon if no intake logged. Opt-in via Settings. Smart one-shot scheduling refreshed on foreground and after every intake action. ID: `daily-checkin-reminder`.
2. **Per-nutrient dose reminders** — configurable times per nutrient, scheduled as **one-off requests per date** for a rolling window (`ReminderSchedule`: up to 14 days, fewer with many reminders so all fit under iOS's 64 pending; the daily check-in takes one more). The rest of today is left out for a nutrient already logged today. `NotificationService.refreshAllNutrientReminders(context:)` is the only scheduler: it rebuilds the set from the data after every log change, on foreground and remote (iCloud) changes, and after reminder or nutrient edits, so logs from the widget, Watch or Siri count from the next sync. Syncs are serialized; requests for deleted nutrients, past times and the old repeating format are removed. Today's "next reminder" line uses the same rule. **Keeping the window rolling:** every sync asks for a background app refresh (`NotificationService.reminderRefreshTaskID`, `BGTaskSchedulerPermittedIdentifiers` + the `fetch` background mode in `Info.plist`, handled by `.backgroundTask(.appRefresh(...))` in `nutrxApp`) about 12 hours out, which runs the same sync. iOS decides when it runs, and it doesn't with Background App Refresh off, so the fallback is opening the app: with neither, reminders run out only after the full window (14 days for a few reminders; a single day only with 60+ reminders a day). IDs: `nutrient-{id}-reminder-{HHmm}-{yyyyMMdd}`. The sync logs "Dose reminders synced: N of M scheduled, K removed" (category `NotificationService`).
3. **Refill reminders** (nutrx Pro, supply): see nutrx Pro: Supply & refills. They're scheduled first; dose reminders share the rest of the budget.
4. **Weekly recap** (nutrx Pro): Sunday 18:00, one slot of the budget; see nutrx Pro: Weekly recap.

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

**Checking Lock Screen widgets (#24):** their `#Preview(as: .accessoryCircular / .accessoryRectangular / .accessoryInline)` previews render fully transparent in preview snapshots (the vibrant Lock Screen material only exists on a real Lock Screen), and a widget extension can only host widget previews, so a plain view preview isn't an option ("The widget extension can only host widget previews."). Check them on a simulator's Lock Screen instead (long-press → Customize → Lock Screen → add the nutrx widgets), in light and dark wallpapers. Home Screen widget previews render normally.

**Infrastructure:** App Group `group.nutrx-labs.nutrx` for shared SwiftData store. `LogNutrientIntent` (AppIntent, widget extension only, hidden from Shortcuts) for interactive + buttons; Siri and Shortcuts use the app's `LogNutrientShortcutIntent`. `ModelContainerFactory` shared across both targets. No `@Query` in widgets — manual `ModelContext` fetches in `TimelineProvider`, which opens the store read-only with `ModelContainerFactory.createForExtension(allowsSave: false)`. "Next up" means `GoalProgress.needsMore` (below an "at least" target or a range's lower bound), never an "at most" goal or one over its limit. Widgets refresh on intent completion and app foreground.

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
- **New models need their CloudKit schema deployed before release:** run a Debug build signed in to iCloud so the new record types (e.g. `LogStack`, `LogStackEntry`) are created in the development environment, then deploy the schema to production in the CloudKit Console. Without it, App Store builds can't sync the new types.

---

## Monetisation

- Free with no ads. **nutrx Pro** is an optional subscription (or lifetime purchase) that only *adds* things around tracking. Nothing that's free today becomes Pro.
- **Being built:** phase 3 of the Pro plan (StoreKit foundation) is the first Pro work. The old "no paywall / StoreKit / AI before MVP 4" guardrail is retired. What stays is in the plan: StoreKit 2 verifies on the device, no receipts or entitlements leave it or go into SwiftData / iCloud, and AI runs on the device only.
- **Pro plan:** `docs/pro/PLAN.md` (agreed 2026-10-14: nutrx Pro, $1.99 / $14.99 with a one-week trial / $29.99 lifetime; designer prompts in `docs/pro/DESIGN-PROMPTS.md`) — supply & refills, label scanning, weekly recap, Apple Health trends and a doctor report; on-device AI only; everything in 2.0 stays free, including stacks and Siri logging. Build it one phase per session.

### nutrx Pro: StoreKit (phase 3)

- **App Store Connect** (created with `Tools/asc` on 2026-10-14):
  - Subscription group **nutrx Pro** (`22477669`): `nutrx.pro.yearly` is level 1 at $14.99 with a one-week free trial; `nutrx.pro.monthly` is level 2 at $1.99. Each has a US price plus Apple's equalized price in the other 174 territories, set one territory at a time (`POST /v1/subscriptionPrices`; the trial is likewise one `subscriptionIntroductoryOffers` call per territory).
  - Non-consumable `nutrx.pro.lifetime` (`6822833390`) at $29.99: a price schedule with a US base, with the other territories equalized automatically.
  - All three are Family Sharing (this can't be turned off), available in every territory and in new ones, with en-US names and descriptions.
  - They show "Missing Metadata" until each has an App Review screenshot of the paywall.
- **`ProAccess`** (`Shared/Services/`, `@Observable`, created in `nutrxApp` and passed down as an environment object):
  - Reads `Transaction.currentEntitlements` at launch and follows `Transaction.updates` from launch, which brings renewals, refunds, Ask to Buy and purchases on other devices.
  - `isPro` / `entitlement` (plan, expiry, family-shared), `loadProducts()`, `purchase(_:)` (verified transactions only, finished straight away; returns `.purchased` / `.pending` / `.cancelled`), and `restore()` (`AppStore.sync()`).
  - The rule is pure, in `ProAccess.entitlement(from:now:)`: revoked, upgraded-away and expired transactions don't count; lifetime beats yearly beats monthly; own purchases beat family-shared ones.
  - **Never stored**: not in SwiftData, iCloud or UserDefaults. It's derived from StoreKit every launch, and no receipt leaves the device.
- **Visible:** `ProAccess.isStoreVisible` is `true` from phase 4 on, now that supply has shipped. It stays a single switch, in case Pro ever has to be hidden again.
- **Paywall** (`Features/Pro/`, docs/pro/design/2-paywall):
  - `PaywallView` is a full-height sheet, presented through `.proPaywall(isPresented:)`. It has a forest header (`ProWordmark`, `ProRingMotif`, close) and the `ProFeature.listed` rows.
  - The three plans are radio cards with prices from StoreKit. Lifetime sits under "or pay once", and yearly carries "1 WEEK FREE" only while `isEligibleForIntroOffer`.
  - The button reads Start free week / Subscribe / Buy lifetime, with the terms under it and "Everything you use today stays free." Restore purchases · Terms (Apple's standard EULA) · Privacy (the website).
  - A purchase or restore that unlocks Pro turns the sheet into `ProWelcomeView` at medium height. Pending, failed and nothing-to-restore show alerts. Offline, the plans area offers Try again.
  - At accessibility sizes the button scrolls with the content.
  - The paywall never claims a store it can't reach, and never says nothing was charged.
  - All copy comes from `ProText`, which is pure and tested in `ProTextTests`.
- **`ProFeature`**: the five Pro features with titles, symbols and tints. **`listed` only includes features where `isShipped` is true**, so the paywall can't advertise an unbuilt feature. Debug builds list all five until one ships, to check the design. Set `isShipped` as each phase lands.
- **Settings:** `ProSettingsCard` sits under the profile card, only when `isStoreVisible` is true.
  - Free: `ProText.tagline(ProFeature.listed)` (shipped features only: "Supply and label scan" now, a plain list for two or three, and "… and more" only from four) with **Learn more**, which opens the paywall.
  - Pro: a check badge and `ProText.shortStatus` ("Yearly · renews Oct 14, 2027", "… free until …", "… ends …", "Lifetime"). It pushes `ProStatusView`.
  - `ProStatusView` has the plan card, the included features, Manage subscription (`manageSubscriptionsSheet`; not for lifetime or family-shared) and Restore purchases.
- **Gate:** `ProGatedButton` (`Shared/Components/ProGate.swift`). For a Pro user it runs the action; for a free user it opens the paywall, and its label gets `showsBadge` for the `ProBadge` chip. Never a lock, blur or wall, and the free version of anything stays.
- **Local testing:** `StoreKit/nutrxPro.storekit` mirrors the products. It's referenced by the nutrx scheme's Run action, so it applies to Xcode runs only, not `simctl launch`, and `ProAccessTests` load it with `SKTestSession(contentsOf:)`.
  - Keep it a *local* config: with `_applicationInternalID` / `_developerTeamID` in its settings, StoreKit treated it as synced and returned App Store Connect's products instead.
  - When resetting scheme churn, check out only the Watch schemes, not `nutrx.xcscheme`.

### nutrx Pro: Supply & refills (phase 4)

The first Pro feature. Mockups: `docs/pro/design/3-supply/`.
- **Model:** four optional fields on `Nutrient`, all CloudKit-safe. `supplyServings` holds the servings when last refilled; nil means supply isn't set. `supplyRefilledAt` is the refill date. `servingAmount` is the units per serving; nil means one step ("each tap adds"), read through `effectiveServingAmount`. `refillReminderDays` defaults to 7.
- **`SupplySchedule`** (`Shared/Services/`) is pure and tested in `SupplyScheduleTests`:
  - remaining = servings × serving − what's been logged since the refill. Decrements count back in, and it never goes below 0 or above a full bottle.
  - Daily use is the last 14 days' total divided by the days since the first log in them, once there are at least 3. It's deliberately not tied to the refill, so refilling doesn't throw the estimate away.
  - Days left = remaining ÷ daily use, rounded down.
  - Levels: `out` (less than a fifth of a serving left, shown even without history), `low` (days left ≤ `refillReminderDays`), `plenty`, and `noHistory`.
  - `Nutrient.supplyStatus()` reads the nutrient's own records; `refillSupply()` restarts the count.
- **Copy:** `SupplyText`, tested in `SupplyTextTests`.
- **Today** (`NutrientCard.supply`) shows a hint only for Pro users, and only when low or out, so the card's height never changes. Low reads "2,000 IU to go · About 6 days left": an amber bottle and the text in AmberInk, on one line. If that doesn't fit beside the buttons, it tries "· 6 days left", then the bottle with "6 days", then the hint alone. At accessibility sizes both wrap on their own lines. Out reads "Out of supply · Refilled?", replacing the goal status. "Refilled?" is its own button (and a VoiceOver "Refilled" action) and asks for confirmation.
- **Nutrient form:** a Supply row after Reminders, for saved nutrients only. Pro opens `SupplySheet`; free shows the PRO chip and opens the paywall.
- **`SupplySheet`:** servings, which can be typed or stepped; each serving, stepped by the nutrient's step and pre-filled with it; and remind-me days. Then the sentence ("That's 120,000 IU — about 60 days at your usual 2,000 IU a day", or "at your goal of…" without history), Refilled today, and Stop tracking supply. The first Save starts the count.
- **Analytics:** a `SupplyCard` under the stats card. Free: the PRO chip, which opens the paywall. Pro, not set: Set up. Set: days left (rounded 34, amber when low), "12 of 120 left", a 12pt gauge (amber when low, the tint otherwise) with a tick at the reminder threshold, the explanation, and Refilled.
- **Demo data** (`-screenshotDemoData`, iOS only): Vitamin D is low, Omega-3 is out and Magnesium has plenty. The bottle sizes are worked out from the demo log.
- **Refill reminders** (`RefillSchedule`, pure and tested in `RefillScheduleTests`; scheduled by `NotificationService`):
  - **Timing:** one per bottle, at 10:00 on the day the estimate reaches `refillReminderDays`, or at the next 10:00 when the supply is already low or out. There's nothing without an estimate.
  - **Never twice for a bottle:** what's been scheduled is remembered per bottle *on this device* (UserDefaults `nutrx.refillReminderStates`, keyed by nutrient id with the refill date). A refill starts a new bottle.
  - **Content:** the title reads "Vitamin D runs out in about a week" (or "in about 3 days", "tomorrow", "has run out"), and the body "About 7 days left at your usual amount. Tap Refilled when you open a new bottle."
  - **Category** `nutrx.refill` has two actions: **Refilled** (runs in the background) and **Remind me tomorrow** (snoozes to 24 hours later).
  - **Budget:** refill reminders come first, and dose reminders share what's left of the 60 (`ReminderSchedule.occurrences(budget:)`).
  - **Pro only:** `NotificationService.supplyRemindersEnabled` is three-state. It's set by `ProAccess.refreshEntitlement()`, and by `NotificationHandler` (through `ProEntitlement.current()`) before an action's resync. While it's still nil, as on a cold background launch from an action or Siri, a sync leaves pending refill reminders and their records alone. The background refresh checks the entitlement first.
  - **Records only for what was added:** a bottle's record is saved only when its request was actually added, or when it has already fired. So a reminder removed before it fired (Pro lapsed, notifications off) can still come later.
  - Each sync logs "Refill reminders: N pending <title> @ <date>; …".
- **`NotificationHandler`** is the app's `UNUserNotificationCenterDelegate`, set in `nutrxApp.init` with the container.
  - It handles the refill actions and shows refill banners while the app is open. Dose and check-in reminders behave as before.
  - A tap sets `NotificationRouter.supplyNutrientID`. `MainTabView` switches to Nutrients, `NutrientsListView` pushes that nutrient (its stack now has a `path`), and the `SupplyCard` focuses itself: a 3pt forest outline (green in dark) with Refilled as the primary button. The focus clears on refill or when the card disappears.
  - To test without waiting until 10:00, run `xcrun simctl push <UDID> nutrx-labs.nutrx payload.json` with `"category":"nutrx.refill"` in `aps` and a top-level `"nutrientID"` (the nutrient's UUID).
- **Widget:** the medium widget swaps its third row for a hairline and "Running low: Vitamin D · 6 days" (an amber bottle; "· out" when out). It names only the supply that runs out soonest (`SupplySchedule.soonest`: out first, then the fewest days).
  - Pro only: the provider asks StoreKit itself through `ProEntitlement.current()`, so nothing is cached from the app.
  - `ProEntitlement.swift` and `SupplySchedule.swift` are compiled into the widget extension.
  - The widget process isn't attached to Xcode's local StoreKit, so in the simulator the line only shows in the "Medium, running low" preview.

### nutrx Pro: Scan a label (phase 5)

Mockups: `docs/pro/design/4-scan-label/`.
- **`LabelTextRecognizer`** runs Vision `RecognizeTextRequest` (accurate, on the device) on an image. It joins pieces on the same row left to right (Vision can split "Vitamin D3 … 1,000 IU" in two), then orders rows top to bottom.
- **`LabelParser`** is the rule-based reader, pure and tested against a corpus of real label texts in `LabelParserTests`:
  - **Name:** above "Supplement Facts" first: a known supplement name, earliest in the line, the longer one on a tie ("Omega-3 Fish Oil" → Omega-3; "Vitamin D3" over "Vitamin D"), else the first short line that isn't boilerplate or a brand ("®", "Labs"…), passing over a possessive line ("Nature's Best") only when another follows ("Women's Multi" alone is the name). Only then a known name inside the facts, so "Sleep Blend" listing melatonin keeps its title. It's title-cased with codes kept (D3, B12, CoQ10).
  - **Numbers** (`numberPattern`, shared with the extractor's check) never start right after a letter, digit or hyphen, so the 12 of "B12 500 mcg" or the 3 of "Omega-3 600 mg" isn't glued to the amount, and thousands group in threes with a comma or a space, never across lines.
  - **Facts panel:** starts at "Supplement Facts" (recognition can drop the space: "SupplementFacts"), else "Amount Per Serving" (`factsHeaderIndex`). Its ingredient rows ("<name> <amount> <unit>") become `SupplementLabel.ingredients`, without nutrition rows (calories, fat, sodium, carbohydrate, sugars, fiber, protein) or footnotes, named the way the form would ("Total Omega-3s" → Omega-3, "Hydrolyzed Bovine Collagen Peptides" → Collagen).
  - **A photo of just the facts panel** (no name above it, the usual back-panel shot): the main ingredient row names it (`mainIngredient`): omega-3 over the fish oil it comes from, else the largest amount by weight (Magnesium 200 mg over Vitamin B6 2.5 mg; Collagen 3 g over Vitamin C 30 mg), nutrition rows only when there's nothing else (a protein powder). Above the facts, sentence-like lines (ending in punctuation, over 48 characters, or starting with Suggested use / Directions / Warning) don't count as a name, so "…foods containing protein…" doesn't, while "Extra Strength Vitamin D3 1000 IU Softgels" still does. "Omega-3s" counts as omega-3.
  - **Amount and unit:** from the facts line for the ingredient the product is named after (`namedAmount`): a line with the name, else one starting with its main word ("Magnesium 200 mg" for Magnesium Glycinate, whose "(as magnesium glycinate)" line has no amount; never just "vitamin"), both as whole words ("vitamin b" isn't "Vitamin B6"). Else the first amount in the facts. IU wins over mcg on the same line. Units are normalised (µg/ug → mcg, iu → IU).
  - The corpus includes four real back-panel photos as on-device recognition read them (`testRealPhoto…`).
  - **Servings:** "Servings per container", else "120 softgels" divided by the serving size.
- **`LabelExtractor`:** with Apple Intelligence (`SystemLanguageModel.default.availability`), `FoundationLabelModel` reads the text with guided generation into `@Generable GeneratedLabel`, prompted with the label text only.
  - Its output is checked: numbers must appear on the label (`numbersOnLabel`), values must be in range, and the unit must be one of IU, mcg, mg or g, written on the label right after the accepted amount (mg for a label in mcg is a 1,000× slip); a dropped amount drops its unit too.
  - Gaps are filled from the parser. Any model error falls back to the parser alone. On a facts-only photo the parser's main ingredient names the product, and a named-ingredient facts line overrides the model's amount (it can pick another ingredient listed first).
  - The model sits behind `LabelExtractor.Model` so tests can stub it (`LabelScanTests`).
  - The simulator can report the model available yet fail to load it (`ModelManagerError 1026`); the real-model test then skips.
- **`LabelPrefill`** fills a `NutrientDraft`: name, unit, step (the amount per serving) and `supplyServings`, plus a known supplement's tint and symbol from `StartingPoint`.
  - It records `scannedFields` (shown as "from label") and `unreadFields` (asked for, with `unreadHint`). The banner reads "Filled from the label. One field needs you." and so on.
  - The goal is never filled, because nutrx doesn't suggest amounts. A scanned bottle size starts supply tracking when the nutrient is added (`insertNutrient`).
  - A known supplement gets its tint and symbol; otherwise the form's look, reminder times and notes stay.
- **Several ingredients on one label:** under the scanned card, **Also on this label** chips ("Vitamin B6 · 2.5 mg") switch the form to that ingredient (`LabelPrefill.switchTo`: name, unit and amount, "from label"; the bottle's servings and the goal stay). After Add, a dialog ("Magnesium added — Also add another ingredient from this label?") offers the rest; picking one keeps the form open on a fresh nutrient from the same bottle and stacks (`LabelPrefill.startNext`), until Done. The draft keeps `labelIngredients`, `addedFromLabel` and `labelIngredientName` (the ingredient picked, whatever the name is edited to). A new stack chosen in the form is joined, not made twice, by the next ingredient (`StackLogging.add(_:toStacks:)` reuses a stack with that name).
- **Entry** (`ScanLabelEntry`): at the top of `NutrientFormView` when the caller passes `offersScan` (My Nutrients' + and Today's empty state: new nutrients only, never onboarding, only while `ProAccess.isStoreVisible`). A 44pt teal tile, "Scan a label", "Fill this in from the bottle", chevron, then "or fill in by hand". It's a `ProGatedButton`: free users see the PRO chip and get the paywall. `ScanText.Reading` picks the note under it: none with Apple Intelligence; "This iPhone reads labels with basic text matching…" without it; "Turn on Apple Intelligence in Settings to read more from labels." when it's turned off, and nothing while the model is still getting ready (`modelPreparing`) (a strip without the design's Settings button: there's no public link to the Apple Intelligence settings, and the app's own settings page would be the wrong place).
- **Scanner** (`LabelScannerView`, full screen, always dark): VisionKit `DataScannerViewController` with text highlights (a UIKit representable; VisionKit has no SwiftUI scanner), glass Cancel and torch (through `AVCaptureDevice`, since VisionKit has no torch control), "Point at the Supplement Facts", a 76pt shutter, a photo-library button, and "Read on your iPhone. Nothing is uploaded." Without live scanning (the simulator, no camera, camera access off) it explains why and offers **Choose a photo** (plus Open Settings when access is off). **The shutter reads the text the scanner is already recognising** (the highlighted pieces, kept by `ScannerHandle` as the scanner's delegate and joined into rows with `LabelTextRecognizer.piece`/`rows`), and also takes a photo (`capturePhoto()`, then Vision, while the scanner is still running) when that misses the name or the amount (`LabelScan.isComplete`), filling the gaps from it (`LabelScan.combined`). A failed photo logs the error (category `LabelScan`) and shows the fail card; on 2.1 (55) a throwing `capturePhoto()` was swallowed and the shutter just froze the frame. Reading shows a "Reading the label…" pill; `LabelScan.read` returning nil opens `ScanFailCard` ("Couldn't read this label" with Try again / Fill in by hand), a bottom card drawn in the scanner rather than a sheet presented over it, so it follows the system appearance and nothing is stacked on the cover. `NSCameraUsageDescription` covers the profile photo and labels. The cover hangs from the form's `NavigationStack`: hung from inside its `ScrollViewReader`, the scanner was rebuilt when the photo picker opened, which closed the picker at once. The photo picker is one `.photosPicker` modifier at the scanner's root. A scanned form can't be swiped away (`interactiveDismissDisabled`); Cancel still closes it.
- **Review** (`draft.wasScanned`): `ScanReviewBanner` (`LabelPrefill.bannerText`, live as fields get filled) with Scan again replaces the entry card. `NutrientFormFields` shows one card with Name, Unit, "Each tap adds (one serving)" and "Supply · servings in the bottle" ("120 softgels"), each with a "from label" tag (`Text/TealInk` on the teal tile; under the value at accessibility sizes) that goes when the user types in it (`NutrientDraft.edited`). `wasScanned` is a stored flag (set by `LabelPrefill` through `markScanned`, cleared by `reset()`), so editing every field doesn't drop the form out of review mid-keystroke. Scan again keeps the goal the user set. Unread rows are amber at 10% with the `unreadHint` in AmberInk. The goal card drops its step field and adds "Set the amount you're aiming for. nutrx doesn't suggest one."
- **Paywall:** without Apple Intelligence, the Scan a label row adds "ⓘ Basic text reading on this iPhone" and the list ends with `ProText.appleIntelligenceNote` ("Apple Intelligence makes label scanning richer. Every Pro feature still works on this iPhone."; recaps join it when they ship).
- **Testing in the simulator:** `xcrun simctl addmedia <UDID> label.jpg`, then Scan a label → Choose a photo.

### nutrx Pro: Weekly recap (phase 6)

Mockups: `docs/pro/design/5-weekly-recap/`.
- **`WeeklyRecap`** (`Features/History/ViewModels/`, pure, `WeeklyRecapTests`) is built from a `HistoryLog`, so a goal counts on a day exactly as in History and for streaks.
  - **Weeks** run Monday to Sunday whatever the locale's first weekday (`weekStart(containing:)`). A week's recap is ready on its Sunday at 18:00 (`releaseDate`, `latestWeek(at:)`). **Only completed days count** (`lastDay` is Sunday, or yesterday while the week runs): on Sunday evening the recap covers Monday to Saturday and picks up Sunday on Monday, so an evening dose not logged yet never reads as missed. `daysLoggedSoFar` includes today, for the first-week state.
  - **Goals:** "31 of 42 goals met" sums each counted day's goals. A day with nothing logged meets nothing, not even an "at most" goal: not opening the app isn't a result. The hero ring has a segment per day, lit for full days (every goal met, the streak rule).
  - **Steadiest:** the best hit rate with at least one day met. **Slipped:** another nutrient's lowest rate below that. **Over limit:** the most days over an "at most" limit or a range's maximum. Ties go to display order.
  - **Day you tend to miss:** over the four weeks ending on `lastDay`, the weekday most often not a full day, when it stands out (missed more than any other weekday, at least twice, on at least half of three or more weeks).
  - **Streak:** consecutive full days through this week's Sunday (or yesterday) and through the Sunday before; left out with Streaks off, or when both are 0.
  - `ScreenshotDemoDataTests` builds the latest recap from the App Store demo set (a perfect week, Sunday as the day you tend to miss).
- **`RecapText`** has every string: range ("5 – 11 October"), headline, ring, the template summary ("You hit Vitamin D 7 of 7 days. Omega-3 slipped on the weekend. Caffeine went over your limit on Monday. Your streak stood at 10 days." — past tense, since a past week's streak isn't today's; a perfect week reads "You met every goal on all 7 days." (the full days, so a nutrient added on Wednesday gives "all 5 days"), several nutrients at 100% "You hit Vitamin D and Omega-3 every day."), the four fact cards, the Today and History lines (each part joined with no-break spaces, so they wrap at the dot, never inside "Vitamin D"), the notification (a numbers-free body when set up before the week's facts are in) and the first-week copy. It describes and never advises.
- **`RecapPhrasing`:** with Apple Intelligence, `FoundationRecapModel` rewords the template summary, prompted with those facts only. The result is used only if every number in it is one of the recap's (`RecapText.factNumbers`, including numbers in names like Omega-3), it contains no advice words, it keeps the steadiest nutrient's name when the template has it, and it's 20–420 characters; spelled-out numbers (one to twenty, once, twice) are checked too; otherwise the template stays. The result, a rewording or the template after a rejection or model error, is kept per week in UserDefaults (`nutrx.recapSummaries`, the last 12 weeks, never synced) and redone only when the facts change, so the recap reads the same each time it's opened.
- **Screen** (`WeeklyRecapView`): large "Weekly recap", share (the range, headline and summary as text). A forest hero with `SegmentedDayRing(met: fullDays, total: 7, caption: "full days")`, the range, "31 of 42 goals met" and the summary (the template at once, the on-device rewording when ready, `RecapViewModel`). Fact cards in two columns (one, without icons, at accessibility sizes; the hero drops its ring there too). "Earlier weeks": the last eight weeks with something in them as mini rings (goals met), selectable. Before any week has data: "Your first recap arrives Sunday" with days logged so far and the explainer.
- **History:** a "Weekly recaps" row under the streak card (indigo calendar tile, `RecapRow`, a `ProGatedButton`): Pro reads "Latest: 5 – 11 October · 31 of 42 goals" (`HistoryViewModel.latestRecap`, computed in `refresh`) and pushes the screen; free shows the PRO chip and "A short summary of each week", and opens the paywall.
- **Today:** `RecapTodayCard` ("Your week", a goals ring, "**31** of 42 goals · Vitamin D steadiest", ✕) right under the day-score card, for Pro users from the recap's Sunday 18:00 through Monday when the week has data: `RecapSchedule.todayCardWeek` (pure, tested) picks the week, `RecapViewModel.recap(forWeek:…)` reads only that week's entries (`HistoryViewModel.loadLog(from:)`). ✕ hides it for that week (`@AppStorage("nutrx.dismissedRecapWeek")`). Tapping opens the recap in a sheet with Done. In Debug builds `simctl spawn <UDID> defaults write nutrx-labs.nutrx nutrx.debug.showRecapCard -bool YES` shows it on any day.
- **Notification** (`RecapSchedule`, scheduled by `NotificationService` with the other reminders): "Your week in nutrx" at the coming Sunday 18:00, for Pro users with Settings → Notifications → **Weekly recap** on (per device, `nutrx.weeklyRecapNotifications`, on by default; the switch shows on only while notifications are allowed, and turning it on asks for permission), once something was logged that week. The sync runs after every log, so it reads only the coming week's entries. The body has the numbers ("You hit 31 of 42 goals. Vitamin D was your steadiest.") only when set up on that Sunday; earlier it reads "See what you hit this week and what slipped." It takes one slot of the 60, and an unknown entitlement keeps a pending one (as for refills). Category `nutrx.recap`: tapping sets `NotificationRouter.showsRecap` (Today → History, which pushes the recap, rebuilt with a new `.id` so it opens on the newest week even over an older one; only while Pro, checking the entitlement first on a cold launch); **Turn off weekly recaps** turns the setting off and resyncs. Shown as a banner while the app is open. Test with `simctl push` and `"category":"nutrx.recap"`.
- **Paywall:** Weekly recap is shipped (tagline "Supply, label scan and recaps"). Without Apple Intelligence its row adds "ⓘ Simpler wording on this iPhone" (`ProText.appleIntelligenceRowNote`), and the list's note names label scanning and recaps.

### nutrx Pro: Trends with Apple Health (phase 7)

Mockups: `docs/pro/design/6-health-trends/`.
- **`HealthDay`:** one day of Apple Health as read: minutes asleep the night after the day, whether there was a workout, active energy (kcal). Read live into memory, never stored in SwiftData or iCloud, never in widgets.
- **`HealthTrends.state`** (pure, `HealthTrendsTests`) over the last 28 completed days:
  - A **paired day** has the nutrient tracked (on or after `createdAt`), something logged in nutrx that day (so a day the app wasn't used isn't 0) and Health data.
  - **States:** `noHealthData` (Health has nothing for the four weeks), `notEnoughData(pairedDays:)` under 14 paired days ("9 of 14 days"), `noPattern(checkedDays:)`, or `findings`.
  - **Sleep:** sleep after days over the threshold vs other days. The threshold is three quarters of an "at most" limit (300 mg of 400, "nearing"), else the goal met (`AnalyticsGoal.isMet`, so a day above a range's maximum isn't "goal met"). It counts when the gap is at least 20 minutes.
  - **Workouts:** intake on workout days vs rest days, counted when the gap is at least 15% of the average intake. Without a workout finding, **active energy**: days at or above the median vs below.
  - Every group needs at least 4 days. Findings come sleep first, at most two.
- **`HealthText`:** "On days Caffeine passes 300 mg, you seem to sleep about 40 minutes less on average.", "On days you work out, you log about 80 mg more Caffeine on average.", the bars' labels and values ("Over 300 mg" 6 h 35 / "Other days" 7 h 15), the basis ("Based on 9 days over 300 mg and 19 days under."), the states, the footer ("Patterns in your own data, not causes. Worked out on this iPhone.", naming the device) and the free teaser. "Seems to", "on average", day counts, and never a cause or advice. Amounts follow the user's locale.
- **HealthKit doesn't tell an app whether read access was granted**, so Settings can't show "Allowed" per type as the mockup does; it shows whether data was found ("Data found" / "No data yet").
- **`HealthReader`** (`Shared/Services/`, app only): `connect()` shows the system sheet (`requestAuthorization(toShare: [], read:)`: sleep analysis, workouts, active energy) and sets the device's switch (`nutrx.healthConnected`, the only thing stored); `recentDays` reads per day through a `Source`. `HealthKitSource`: minutes asleep (core, deep, REM, unspecified) credited to the night before the morning they end, workout start days, daily active-energy sums. The HealthKit entitlement (`com.apple.developer.healthkit`, empty access list) is on the app only; `NSHealthShareUsageDescription` explains the read. In Debug builds `simctl spawn <UDID> defaults write nutrx-labs.nutrx nutrx.debug.healthDemo -bool YES` swaps in a demo source (the simulator's Health store is empty).
- **Analytics card** (`HealthTrendsCard`, below the weekday heatmap; `NutrientAnalyticsViewModel.refreshHealth` on appear): free → the teaser with the PRO chip and "Learn about nutrx Pro"; Pro, not connected → Connect Apple Health (opens `HealthIntroView`); connected → the findings (sentence, two bars in the tint, basis, footer, "Last 28 days") or the state (14-segment progress, no pattern, no Health data). Shown only where HealthKit is available.
- **`HealthIntroView`** (`Shared/Components/`, from the card and Settings): what's read, read only and stays on the device, Continue (the system sheet) / Not now.
- **Settings → Apple Health** (`AppleHealthSettingsView`, a row with Export data; free shows the PRO chip): the switch, what's read with Data found / No data yet, where to change access in the Health app, the privacy note, Disconnect.
- **Privacy tests** (`HealthPrivacyTests`, guideline 5.1.3): no SwiftData model property is about sleep, workouts, energy or health, and the only Health-related UserDefaults key is the switch.
- Health trends are shipped on the paywall (the Settings card's tagline becomes "Supply, label scan, recaps and more").

---

## Out of Scope — Not Yet Built

**MVP 3 (remaining):** Apple Health integration (HealthKit write)

**Pre-Pro Sprint:** done — goal types, data export (CSV), quick-log stacks, and Siri & App Shortcuts (see their sections above)

**nutrx Pro** (`docs/pro/PLAN.md`): StoreKit, supply and label scanning are built; weekly recap, Health trends and the doctor report come next. On-device AI only, no third-party LLM. Streak freeze and a shareable streak card come later, outside the plan.

**Deferred:** Localisation, iPad-specific layout

---

## Data Models

All persistence is handled via SwiftData. Nine model classes. No data is ever sent off-device.

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
| `servingAmount` | `Double? = nil` | Supply (Pro): units per serving; nil = one step |
| `supplyServings` | `Double? = nil` | Supply: servings when last refilled; nil = supply not set |
| `supplyRefilledAt` | `Date? = nil` | Supply: when the bottle was last refilled |
| `refillReminderDays` | `Int = 7` | Supply: remind when this many days are left |

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

### LogStack

A named set of nutrients with preset amounts, logged in one go (see Stacks).

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID = UUID()` | Identifies the stack to Siri and Shortcuts (`StackEntity`) |
| `name` | `String` | "Morning" |
| `sortOrder` | `Int` | Order on Today and in Settings → Stacks |
| `createdAt` | `Date = Date()` | |
| `lastLoggedAt` | `Date?` | Last time it was logged, from any device; drives "done today" |

**Relationships:** → many `LogStackEntry`? (cascade)

---

### LogStackEntry

| Field | Type | Notes |
|---|---|---|
| `stack` | `LogStack?` | Relationship |
| `nutrient` | `Nutrient?` | Relationship. `Nutrient.stackEntries` is the inverse (cascade on hard delete) |
| `amount` | `Double` | Logged each time, in the nutrient's unit; starts at its step |
| `sortOrder` | `Int` | Order within the stack |

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