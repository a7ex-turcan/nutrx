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
| iCloud sync (CloudKit + SwiftData) | 🔨 In progress |
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

## MVP 3 — Ecosystem & Sync 🔨

**Goal:** Make nutrx work seamlessly across a user's Apple devices and surface richer historical insight.

---

### iCloud Sync 🔨

**Status:** Specced, in progress

> ⚠️ **Three rules for Claude Code before touching any code:**
>
> 1. **Do the full model audit before touching `ModelContainerFactory`.** A CloudKit-backed container initialised against a schema with invalid fields will fail silently and be extremely hard to debug. Audit first, no exceptions.
> 2. **Test the new-device flow on a real device, not Simulator.** CloudKit behaves materially differently in Simulator — the onboarding-skip logic and banner triggers require a real device with a real iCloud account.
> 3. **The ~3 second loading window for the onboarding-skip check is a hard cap.** Blocking the user indefinitely is worse than occasionally showing onboarding to a returning user.

**Guiding principles:**
- On by default — no setup, no sign-in flow
- User is informed but not burdened — subtle nudges, never blocking
- App always works offline — sync is additive, never a dependency
- Opt-out available in Settings

**What changes:**

*Data layer*
- `ModelContainerFactory` switches to a CloudKit-backed configuration using container `iCloud.nutrx-labs.nutrx`
- Factory handles CloudKit available and unavailable gracefully — app never fails to launch because CloudKit is unreachable
- App Group container URL stays unchanged — widgets continue to work regardless of sync state

*Model audit (prerequisite)*
- Every `@Model` field must have a property-level default or be optional for CloudKit compatibility
- Known fields needing attention: `UserProfile.name`, `weightUnit`, `heightUnit` (default `""`), `UserProfile.weight`, `height` (default `0.0`), all relationship fields need explicit `@Relationship` delete rules
- Full audit of all models required before implementation

*Entitlements (both main app and widget extension)*
- iCloud capability with CloudKit enabled
- Container: `iCloud.nutrx-labs.nutrx`
- Existing App Group entitlement unchanged

*New device / first launch*
- On first launch, wait up to 3 seconds for CloudKit initial sync
- If `UserProfile` with `onboardingCompleted = true` is found → skip onboarding, show sync-restored banner
- If nothing found within 3 seconds → assume new user, proceed with onboarding as normal
- Minimal loading state (spinner) shown during the wait

*Conflict resolution*
- Last-write-wins for all models except `IntakeRecord`
- `IntakeRecord` is append-only — two devices logging simultaneously produces two valid records, both correct
- Soft deletes on `Nutrient` (`isDeleted = true`) handle offline deletion cleanly

**Settings UI — new iCloud Sync section (above Notifications):**

| State | Icon | Title | Toggle | Footer |
|---|---|---|---|---|
| Sync on, available | iCloud | Sync with iCloud | ON | "Your data syncs across all your Apple devices automatically." |
| Sync on, iCloud unavailable | ⚠️ orange | iCloud Unavailable | ON | "Sign in to iCloud in Settings to enable sync." + link to iOS Settings |
| Sync off | iCloud muted | Sync with iCloud | OFF | "Your data is stored on this device only." |

Toggle stored in `UserPreferences.iCloudSyncEnabled` (default `true`). Toggling reinitialises the container. No data deleted in either direction.

**One-time banners (Today screen, styled like existing notification banner):**

- *Sync restored* — shown after new-device restore: "Your nutrx data has been restored from iCloud." Suppressed via `UserPreferences.hasSeenSyncRestoredBanner`.
- *Sync enabled* — shown once after fresh-install onboarding completes: "Your data is syncing to iCloud. Reinstalling won't lose anything. You can turn this off in Settings." Suppressed via `UserPreferences.hasSeenSyncEnabledBanner`.

**App deletion behaviour:**

Deleting the app removes the local store but leaves CloudKit data intact — reinstalling restores everything via the new-device flow. However, if the user chooses "Delete App and Data" when prompted by iOS, the CloudKit container is wiped for all devices. This is an iOS system behaviour nutrx cannot prevent. During implementation, test which CloudKit container configuration triggers this prompt least aggressively, and prefer it. The reinstall-safe banner copy above is intentional — it sets the right expectation before users ever encounter that prompt.

Banners appear one at a time. Notification permission banner takes priority.

**New `UserPreferences` fields:**

| Field | Type | Default |
|---|---|---|
| `iCloudSyncEnabled` | `Bool` | `true` |
| `hasSeenSyncRestoredBanner` | `Bool` | `false` |
| `hasSeenSyncEnabledBanner` | `Bool` | `false` |

**Out of scope for this iteration:** merge conflict UI, per-record sync status, manual sync trigger, two devices completing onboarding independently before syncing.

---

### Analytics & Charts 📋

**Status:** Planned

Weekly and monthly breakdowns of intake per nutrient. Trend lines. "Best day" / "worst day" summaries. Free tier gets last 30 days; Pro tier gets full history charts (first Pro-gated feature).

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