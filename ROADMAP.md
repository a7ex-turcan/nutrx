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

### MVP 3 — Ecosystem & Sync 🔨

| Feature | Status |
|---|---|
| iCloud sync (CloudKit + SwiftData) | ✅ Shipped (v1.6) |
| In-app review prompt | ✅ Shipped (v1.6) |
| Expandable nutrient cards (Today intake breakdown) | ✅ Shipped (v1.7) |
| Analytics & charts (per-nutrient) | ✅ Shipped (v1.8) |
| Apple Health integration (HealthKit write) | 📋 Planned |

### MVP 4 — Pro Tier & AI 📋

| Feature | Status |
|---|---|
| Pro subscription (StoreKit 2) | 📋 Planned |
| Daily AI insights | 📋 Planned |
| Smart target suggestions | 📋 Planned |
| Natural language logging | 📋 Planned |
| Full history charts | 📋 Planned |

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

## MVP 3 — Ecosystem & Sync 🔨

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

**Status:** Planned

Optionally write logged nutrients to HealthKit (e.g. dietary Vitamin C, Magnesium, Calcium). Only nutrients that map to a known HealthKit quantity type can be written — user-defined nutrients without a HealthKit equivalent are not eligible. A mapping layer (automatic name-matching or user-configured) will be needed.

Read from Health (Health → nutrx ongoing sync) is out of scope for MVP3. Considered for a later version as an opt-in, per-nutrient setting.

---

---

## MVP 4 — Pro Tier & AI 📋

**Goal:** Introduce the Pro subscription. Monetise with AI-powered features that are genuinely useful without compromising the free tier.

### Pricing (indicative)
| Option | Price |
|---|---|
| Monthly | $2.99 / month |
| Annual | $19.99 / year |
| Lifetime | $49.99 one-time |

### What's gated behind Pro
All core tracking features remain **free forever**. Pro only unlocks AI-powered extras:

| Feature | Description |
|---|---|
| **Daily insights** | Short natural-language summary of patterns (e.g. "You've been consistently under your Magnesium target on weekdays") |
| **Smart target suggestions** | Based on profile (age, weight) suggest reasonable starting daily targets for common nutrients |
| **Natural language logging** | Type "had a protein shake and two eggs" → app maps it to the user's defined nutrients |
| **Full history charts** | Trend charts beyond 30 days (also gated here if not included in MVP 3 free tier) |

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