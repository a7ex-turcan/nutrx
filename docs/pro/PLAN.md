# nutrx Pro — implementation plan

Status: **shipped** with 2.1 on 2026-10-16 (agreed 2026-10-14; decisions in §2). What's left outside the plan is tracked as GitHub issues (#125, #126). Replaces the "MVP 4 — Pro Tier & AI" section of `ROADMAP.md`.

Build **one phase per session**, each through its own PR, the same way the v2 redesign followed `docs/design/DESIGN.md` §7.

---

## 0. Principles (read first)

1. **Everything nutrx does today stays free, forever.** That covers tracking, widgets, the Watch, history, analytics and iCloud sync. The website and support FAQ promise that "logging, history, and everything you use daily will never be gated", so **CSV export, Siri and stacks (phase 2) are free too** when they ship. Pro only adds new things around tracking.
2. **No servers, no exceptions.** All AI runs on the device (Apple's Foundation Models framework). Nothing is sent to us or to any AI company. This replaces the old roadmap's "third-party LLM API" idea, which would break the privacy promise.
3. **No advice.** nutrx doesn't suggest amounts. Pro features say *what happened* ("Omega-3 slips on weekends"), never *what to take*. That rules out the old "smart target suggestions" and any interaction checks. It also keeps us inside App Review's health-claims rule (guideline 1.4.1).
4. **No chat box.** AI shows up as features that use the user's own data and save them taps. That's the answer to "why not just ask ChatGPT": it doesn't have your logs, it can't act in the app, and it's not private.
5. **Health data never goes to iCloud.** Apple Health data is read live and never saved into the synced store (guideline 5.1.3).
6. **Graceful without Apple Intelligence.** The on-device model needs an Apple Intelligence device (iPhone 15 Pro or later) with it turned on. Every AI feature needs a non-AI path, or must be clearly marked as unavailable. We never charge for something the device can't run.

---

## 1. What Pro is

| Feature | What it does | AI? |
|---|---|---|
| **Supply & refills** | Enter what's in the bottle; logging counts it down; "Vitamin D runs out in about 6 days" and a refill reminder. | No |
| **Scan a label** | Point the camera at a supplement label; the name, unit, amount per serving and servings per container fill in the nutrient form (and supply). | On-device |
| **Weekly recap** | A Sunday summary of the week from your own logs: what you hit, what slipped, which day. Descriptive only. | On-device phrasing of computed facts |
| **Health trends** | With Apple Health: relationships between your intake and sleep or workouts ("on training days you're 30 g short on protein"). | No (statistics) |
| **Report for your doctor** | A clean PDF of a chosen period: goals, daily totals, hit rates, notes. | No |

**Free, built before the paywall** (groundwork that also makes Pro better): Siri & App Shortcuts, quick-log stacks, CSV export.

**Later, not in this plan:** streak freeze and a shareable streak card (from the old roadmap). They're engagement features and can come after launch, once we see what Pro users ask for.

### Pricing (D3, D4)

| Option | Price |
|---|---|
| Monthly | $1.99 |
| Yearly | $14.99 |
| Lifetime | $29.99 |

A lifetime option matters here: privacy-minded users tend to dislike subscriptions. The yearly plan has a free one-week trial.

---

## 2. Decisions (2026-10-14)

| # | Decision | Agreed |
|---|---|---|
| D1 | Validate with a vote first? | **No.** Phase 1 is skipped. |
| D2 | Name | **nutrx Pro** |
| D3 | Prices | **$1.99 / month, $14.99 / year, $29.99 lifetime** |
| D4 | Trial | **One week, on the yearly plan only** |
| D5 | Order of Pro features | **Supply → Scan → Recap → Health → Report.** Supply has no AI, so it's the safest first paid feature to launch StoreKit with. Scan feeds supply (it reads the bottle size). Recap and Health need a few weeks of data. The report is the least likely to sell Pro on its own. |
| D6 | Design | **Mockups from the designer** before each feature's phase. The prompts are in [`DESIGN-PROMPTS.md`](DESIGN-PROMPTS.md); the handoff for all seven is in [`design/`](design/README.md) (renders are the visual target, sources for exact values only). |

---

## 3. Build order (one phase per session)

Every phase ends with: builds clean, unit tests for all logic, previews for new views (light/dark), a real simulator run of the changed flows, `CHANGELOG.md` / `CLAUDE.md` updated, and a PR through the watcher.

### Phase 1 — Validate — *skipped (D1)*

- **Vote page:** a page on the nutrx website listing the Pro candidates. Readers tick the ones they'd pay for and send the form through the existing Formspree endpoint. It's static and keeps no data in the app.
- **Link to it** from the app's What's New / Settings ("Help shape nutrx Pro") and from the newsletter.
- **Decide D5** from the results.

### Phase 2 — Free groundwork: Siri, stacks, export

These ship to everyone and carry the model changes we want before Pro.

- **Siri & App Shortcuts** (`ROADMAP.md` Pre-Pro §5):
  - `NutrientEntity` (`AppEntity`, `EntityQuery` on the App Group store, resolved by name).
  - `LogNutrientIntent` gains `nutrient` and an optional `amount`. The widget path keeps working.
  - An `AppShortcutsProvider` with "Log [nutrient]".
- **Stacks** (`ROADMAP.md` Pre-Pro §4):
  - Models: `LogStack` and `LogStackEntry`. They're CloudKit-safe (optional relationships, property defaults, no unique constraints).
  - A Stacks row on Today, a confirmation sheet with editable amounts, and Settings → Stacks.
  - `LogStackIntent`, so "log my morning stack" works from Siri and the Watch.
- **CSV export** (`ROADMAP.md` Pre-Pro §3): Settings → Export Data, through the share sheet.
- **Tests:** stack logging, entity queries by name, CSV escaping.

### Phase 3 — StoreKit foundation (no feature yet)

- **First:** retire the StoreKit / AI guardrail in CLAUDE.md and AGENTS.md (see phase 9, "CLAUDE.md and AGENTS.md"), so this phase doesn't conflict with it.
- **App Store Connect:** a subscription group "nutrx Pro" with monthly and yearly plans, plus a non-consumable lifetime purchase. The user creates these in the web UI, or with the API if asked. Add a `.storekit` configuration file for local testing.
- **`ProAccess`** (`Shared/Services/`): an `@Observable` that reads `Transaction.currentEntitlements` at launch and listens to `Transaction.updates`. It exposes `isPro`, calls `AppStore.sync()` for Restore Purchases, and handles family sharing.
  - No receipts leave the device. StoreKit 2 verifies on the device.
  - The entitlement is never stored in SwiftData or iCloud. It's derived from StoreKit every launch.
- **Paywall:** use `SubscriptionStoreView` (system, App Review-friendly, handles the trial, terms and restore) styled with the brand, with a lifetime button next to it. It lists exactly what Pro adds and repeats that everything else stays free.
- **Gate:** `.proGated()`. A Pro feature's entry point shows the small "Pro" badge from the handoff (never a lock, blur or wall) and opens the paywall. The UI never hides the free version of anything.
- **Settings:** a "nutrx Pro" row (status, manage subscription, restore).
- **Tests:** `StoreKitTest` sessions for buying, expiry, refund, restore and lifetime.
- **Not shipped on its own:** this phase merges, but stays hidden behind a flag until phase 4 lands.

### Phase 4 — Supply & refills (first Pro feature, ship with phase 3)

- **Model:** add optional fields to `Nutrient` (CloudKit-safe defaults):
  - `servingAmount` (units per serving, e.g. 1,000 IU). It defaults to `step`, since "each tap adds" is one serving for most supplements. The Supply row shows it pre-filled and only asks again if a serving differs from a tap.
  - `supplyServings` (servings when last refilled);
  - `supplyRefilledAt`;
  - `refillReminderDays` (e.g. 7).
- **Maths** (`SupplySchedule`, a pure type with tests):
  - remaining = servings × serving amount − logged since refill;
  - days left = remaining ÷ average daily use over the last 14 days (or the goal if there's no history);
  - partial servings, deletes and negative records are handled.
- **UI:**
  - Today cards: "about 6 days left" when at or under the threshold.
  - The nutrient form gets a "Supply" row.
  - Analytics gets a supply card.
  - A "Refilled" action resets the count.
- **Notifications:** one refill reminder per nutrient. It counts against `ReminderSchedule.budget` (60 of iOS's 64 pending), so the budget maths takes these into account first.
- **Widget:** the next nutrient running out, as a line in the medium widget.

### Phase 5 — Scan a label (Pro, on-device AI)

- **Capture:** VisionKit `DataScannerViewController` (live text), or a photo. Vision text recognition runs on the device.
- **Extract:** Foundation Models with guided generation into a `@Generable struct SupplementLabel { name, unit, amountPerServing, servingsPerContainer }`, prompted with the recognised text only. If the model isn't available (`SystemLanguageModel.default.availability`), a rule-based parser (regex for "1000 IU", "120 softgels") fills in what it can.
- **Prefill:** a `NutrientDraft` (name, unit, step = amount per serving), plus supply (phase 4). The user always confirms in the normal form. Nothing is created automatically.
- **Entry point:** "Scan a label" in the new-nutrient form only. Not in onboarding: a new user shouldn't meet a Pro badge or a paywall before logging anything. For free users the form shows the option with a small Pro badge, and tapping it opens the paywall.
- **Tests:** a corpus of real label texts covers both the parser and the model output mapping. The model is mocked in unit tests.

### Phase 6 — Weekly recap (Pro, on-device phrasing)

- **Facts first:** `WeeklyRecap` is a pure type built from the same rules as analytics (`GoalProgress.countsAsMet`, `WeekdayPattern`). It holds hit rates, the best and weakest nutrient, the weakest weekday, streak change and over-limit days.
- **Phrasing:** Foundation Models turns the facts into 3–4 short sentences, with a strict instruction to describe and never advise. Its output is checked: every number in the text must exist in the facts, or the template wording is used. A template version also runs on devices without the model.
- **Delivery:** a Sunday-evening local notification (budgeted with the others), plus a Recap screen with the last 8 weeks, opened from Today and History.
- **Tests:** fact building over fixed fixtures, the number-check guard and the templates.

### Phase 7 — Health trends (Pro, Apple Health)

- **Permissions:** HealthKit read-only for sleep analysis, workouts and active energy. Usage strings go in `Info.plist`, and the HealthKit entitlement is added for the app only.
- **Engine:** `HealthTrends` is a pure type that pairs each day's intake with that day's (or that night's) Health data. It reports simple differences ("on workout days: protein −30 g on average"), only with at least 14 paired days and a minimum effect size. It says "seems to", never claims causes, and never advises.
- **Privacy:** Health data is read live into memory, never stored in SwiftData or iCloud (guideline 5.1.3), and never shown in widgets.
- **UI:** a "With Apple Health" card in each nutrient's analytics, plus a Settings → Apple Health page to connect or disconnect.
- **Optional, free:** HealthKit *write* for nutrients that map to dietary types (`ROADMAP.md` MVP 3) could ship in the same phase.

### Phase 8 — Report for your doctor (Pro)

- **Build:** a PDF from SwiftUI views with `ImageRenderer`. It has a period picker (30/90 days or custom) and covers each nutrient's goal, daily totals, hit rate and notes, plus optional trends. `ImageRenderer` renders one view per page, so the report splits its content into page-sized views itself (a summary page, then a fixed number of days per page), each drawn into its own page of one PDF context.
- **Share:** through the share sheet. Nothing is stored or sent by the app.
- **Tests:** pagination and a snapshot of a fixture report.

### Phase 9 — Launch

- **App Store Connect:** subscription display names, descriptions, the review screenshot of the paywall, prices for D3, and the trial for D4.
- **App Review notes:** Health permission use, that the AI runs on the device, and how to reach the paywall.
- **Store listing:**
  - The description and What's New get a Pro section, keeping "everything else free".
  - Screenshots: one Pro panel, made with `Tools/AppStoreScreenshots`.
- **Website:**
  - a Pro section on the homepage and features page;
  - the FAQ "Is nutrx free?" updated;
  - the privacy policy covering Apple Health (read-only, never leaves the device, never in iCloud) and on-device AI.
- **CLAUDE.md and AGENTS.md:** the "Monetisation" section rewritten from this plan. The "Do not build StoreKit / AI before MVP 4" guardrail is retired in both files, and AGENTS.md stops naming the Pre-Pro sprint as next. Do this at the start of phase 3, so its StoreKit work doesn't conflict with the guardrail.

### After launch

Pro features added after 2.1 have their own spec: courses in 2.2 (#99, in CLAUDE.md), and **schedules for 2.4 in [`SCHEDULES.md`](SCHEDULES.md)** (#132): set weekdays, every few days, on / off cycles and times a week. **Supply costs and Add to list for 2.5 are in [`SUPPLY-COSTS.md`](SUPPLY-COSTS.md)** (#134).

---

## 4. Risks

| Risk | Mitigation |
|---|---|
| Too few people want to pay | A low price, a lifetime option and a trial; supply (useful from day one) leads; watch conversions after launch before building further. |
| AI features on devices without Apple Intelligence | A non-AI path for each, an explicit "needs Apple Intelligence" note on the paywall, and no charge for what can't run. |
| App Review: subscriptions need ongoing value (3.1.2) | Supply, recap and trends keep working week after week; the paywall states exactly what Pro adds. |
| App Review: health claims (1.4.1) | Descriptive only, minimum sample sizes, "seems to" wording, no advice anywhere. |
| Health data in iCloud (5.1.3) | Read live, never persisted. Covered by a test that the model types hold no Health values. |
| The notification budget (64 pending) | Refill and recap notifications are counted inside `ReminderSchedule.budget`. |
| Breaking the free promise by accident | A checklist item in every PR: nothing that was free becomes gated. |

---

## 5. Out of scope

- Any server, account, analytics or third-party SDK.
- Cloud AI of any kind.
- Recommending amounts, interactions or any medical guidance.
- Gating anything that's free in 2.0.
