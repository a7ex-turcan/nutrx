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

### MVP 2 — Retention & Reach 🔨

| Feature | Status |
|---|---|
| Per-nutrient dose reminders | ✅ Shipped (v1.1) |
| Nutrient notes | ✅ Shipped (v1.1) |
| Home screen & lock screen widgets | 📋 Planned |
| History monthly section headers | 📋 Planned |
| Streaks & consistency tracking | 📋 Planned |
| Nutrient grouping / categories | 📋 Planned |

### MVP 3 — Ecosystem & Sync 📋

| Feature | Status |
|---|---|
| iCloud sync (CloudKit + SwiftData) | 📋 Planned |
| Analytics & charts | 📋 Planned |
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

## MVP 2 — Retention & Reach 🔨

**Goal:** Make the core loop stickier. Give users more reasons to open the app daily and more surfaces where the app is visible.

**Sequencing:** Features are listed in recommended build order. Complete Tier 1 before moving to Tier 2.

---

### Tier 1 — High Value, Ship First

#### 1. Per-Nutrient Dose Reminders ✅
**Status:** Shipped in v1.1

Each nutrient can have zero, one, or multiple dose reminders. Each reminder fires daily at a configured time. Smart suppression cancels upcoming reminders after the user logs intake. Configured via a "Reminders" section in the Edit Nutrient form, opening `NutrientRemindersSheet`. Model: `NutrientReminder`. Notification IDs: `nutrient-{id}-reminder-{HHmm}`.

---

#### 2. Home Screen & Lock Screen Widgets
**Why:** A glanceable widget is the highest daily touchpoint outside the app itself. Users who add widgets retain far better.

- **Small widget:** Ring or bar showing overall daily completion (X of Y nutrients on target)
- **Medium widget:** Per-nutrient progress bars for the top nutrients (user-configurable)
- **Lock screen widget:** Compact view — e.g. a single nutrient's progress or overall completion count
- Widgets are read-only — tapping opens the app to the Today tab
- Data sourced from SwiftData via a shared App Group container (required for WidgetKit)
- Implementation: `WidgetKit` framework

> ⚠️ **Technical note for Claude Code:** Widgets require a separate WidgetKit extension target and a shared `App Group` entitlement so the widget can read the SwiftData store. The App Group identifier should be `group.nutrx-labs.nutrx`. The main app and widget extension must both use this group.

---

### Tier 2 — Meaningful UX Improvements

#### 4. Nutrient Notes ✅
**Status:** Shipped in v1.1

Optional free-form text field on `Nutrient` (`notes: String? = nil`). Editable in Create/Edit Nutrient form. Shown as a muted single line below the nutrient name on the Today card when non-empty.

---

#### 5. History Tab — Monthly Section Headers
**Why:** As history accumulates, a flat list becomes hard to navigate. Month headers provide orientation without adding a new navigation level.

- The existing day-entry list gains sticky section headers, one per month (e.g. "March 2026", "February 2026")
- No new drill-down level — tapping a day entry still opens the same `HistoryDayView` as before
- Most recent month appears at the top; entries within each month remain sorted most-recent-first
- No new SwiftData model or query changes needed — purely a grouping change in `HistoryViewModel` and `HistoryListView`

---

#### 6. Streaks & Consistency Tracking
**Why:** Simple, motivating, zero infrastructure cost. Encourages daily use without being gamified or annoying.

- A nutrient "hit" is defined as reaching or exceeding its daily target
- Track the current streak (consecutive days where all tracked nutrients were hit)
- Display the streak count on the Today screen (subtle — e.g. below the date header)
- Also show a "best streak" all-time record
- Streaks are computed from existing `IntakeRecord` SwiftData — no new model required
- If the user missed a day, streak resets to 0

---

#### 7. Nutrient Grouping / Categories
**Why:** As users add more nutrients (10, 15, 20+), the Today screen becomes unwieldy. Groups let users organise without deleting.

- Users can create named groups (e.g. "Vitamins", "Minerals", "Supplements", "Other")
- Nutrients are assigned to a group (optional — unassigned nutrients appear in a default "General" group)
- Today screen and My Nutrients screen display nutrients grouped with collapsible sections
- Reordering works within and across groups
- New SwiftData model: `NutrientGroup` (name, sortOrder)
- `Nutrient` gets a new optional relationship: `group: NutrientGroup?`

---

### Settings Screen (already exists from MVP 1)

The Settings screen is accessible via the profile menu. It already contains the daily check-in reminder toggle from MVP 1. MVP 2 adds to it:

**Added in MVP 2:**
- Global notifications permission prompt (requests `UNUserNotificationCenter` authorisation on first enable — shared by both notification systems)
- **Per-Nutrient Reminders** — a note directing users to configure these inside each nutrient's edit screen. No per-nutrient configuration lives in Settings.

**Reserved for future versions:**
- iCloud sync toggle (MVP 3)
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

## MVP 3 — Ecosystem & Sync 📋

**Goal:** Make nutrx work across a user's Apple devices and surface richer historical insight.

- **iCloud sync** via CloudKit + SwiftData. Users' data seamlessly available on all their devices. No account required — uses their existing Apple ID.
- **Analytics & charts** — weekly and monthly breakdowns of intake per nutrient. Trend lines. "Best day", "worst day" summaries. Free tier gets last 30 days; Pro tier gets full history charts (first Pro-gated feature).
- **Apple Health integration** — optionally write logged nutrients to HealthKit (e.g. dietary Vitamin C, Magnesium). Read-only import not planned yet.

> ⚠️ **iCloud sync technical note for Claude Code:** SwiftData + CloudKit sync requires the `NSPersistentCloudKitContainer` model container configuration and the `iCloud` + `CloudKit` entitlements. Schema migrations must be handled carefully — every `@Model` field must have a default value or be optional to support sync across app versions.

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