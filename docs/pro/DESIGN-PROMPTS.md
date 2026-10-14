# nutrx Pro — design prompts

Prompts for the designer, one per feature, in build order (see `PLAN.md` §3). Each is self-contained: paste **the shared brief plus one feature prompt**. Attach the v2 renders from `docs/design/screens/` named in the prompt, so the new screens match what shipped.

When a handoff comes back, add it under `docs/pro/design/<feature>/` (renders + source), the same way as the v2 handoff in `docs/design/`.

---

## Shared brief (paste at the top of every prompt)

> You're designing new screens for **nutrx**, a private iPhone app (with Apple Watch and widgets) for tracking the vitamins, supplements and nutrients people take every day. It has no account, no servers, no ads and no analytics. Data lives on the device and in the user's own iCloud. Brand line: "Track what you take. Nothing else."
>
> **Match the existing v2 design exactly** (renders attached). It's "branded native" iOS 26: system components and Liquid Glass chrome (native tab bar, nav bars, sheets, toolbars), plus a brand layer.
>
> **Colours** (light / dark):
> - Forest `#1B3B2D` (hero cards, primary buttons in light) and Green `#1EB955` (fills, met states, the primary button in dark). **Never use Green for text on light backgrounds.** Green text is `#137A3A` in light and `#5BD88A` in dark.
> - Soft green `#7BE3A0` for accents on forest. Amber `#E08A1E` for warnings; amber text is `#9A5A0C` / `#F0B35A`.
> - Ground `#F2F4EF` / `#0A130E`. Cards `#FFFFFF` / `#142019`. Primary text `#0E1A13` / `#EAF2EC`, secondary `#56655C` / `#97AA9E`. Hairlines `#EEF1EC` / `#22332A`.
> - Each nutrient has a user-chosen tint (green, teal `#13A39C`, blue `#2F80ED`, indigo `#6B5BE0`, pink `#D9539A`, coral `#E2674A`, amber `#E5A500`, brown `#9B6A45`) and an SF Symbol. The tint drives its progress ring and icon tile.
>
> **Type:** SF Pro only, Dynamic Type styles. Every number the user reads is SF Pro Rounded, bold, monospaced digits. Labels and prose use default SF.
>
> **Shapes:**
> - Corner radius: cards 22, hero cards 28, controls 16, icon tiles 12.
> - Screen margin 16, card padding 14, 10 between cards.
> - Light mode cards have a soft forest shadow; dark mode uses a 1pt hairline instead.
> - Touch targets are at least 44pt.
>
> **Rules:**
> - Progress is always a ring.
> - SF Symbols only, no emoji.
> - Design light and dark for every screen, and show one key screen at the largest accessibility text size.
> - No invented health advice anywhere: the app describes what the user logged, never what they should take.
>
> **Pro context:** nutrx Pro is an optional subscription ($1.99/month, $14.99/year with a one-week free trial, or $29.99 lifetime). It adds features around tracking, and **everything that's free today stays free**. Pro should feel like a calm, premium extra: no nagging, no countdowns, no dark patterns. Where a free user meets a Pro feature, show a small, quiet "Pro" badge, never a wall.
>
> **Deliver:** iPhone artboards (393 pt wide) at @2x, light + dark, with the states listed, plus a short note of any new component and its measurements.

---

## 1. Stacks and export (free — phase 2)

Attach: `01-today-light.png`, `02-today-dark.png`, `03-log-sheet.png`, `11-settings.png`.

> Design **quick-log stacks** and **data export**. Both are free features.
>
> A **stack** is a named set of nutrients with preset amounts that the user logs in one go, e.g. "Morning stack: Vitamin D 2,000 IU, Omega-3 1,000 mg, Magnesium 400 mg".
>
> Screens:
> 1. **Today with stacks.** A compact "Stacks" row on Today, below the day-score card and above the groups. It holds one pill or card per stack (name, the nutrients' tint dots or icons, "Log"). Show it with 1 stack and with 3. Show a stack that was already logged today: still tappable, but visibly "done today".
> 2. **Log a stack** (sheet, medium detent). The list of entries with each nutrient's ring, name and the amount about to be logged, editable inline with − / +. Then a full-width "Log 3 nutrients" button. Show the moment after logging (rings fill, success).
> 3. **Settings → Stacks.** List, create, rename, reorder and delete stacks. A stack's detail screen adds nutrients, sets each amount and reorders them. There's an empty state that explains stacks in one sentence.
> 4. **Siri hint.** A subtle "Say 'Log my Morning stack' to Siri" tip on the stack's detail screen.
> 5. **Settings → Export data.** One screen with a short explanation, a date range (All time / last 30 / 90 days) and "Export CSV", which opens the share sheet. Show the success state.

## 2. Paywall and Pro entry points (phase 3)

Attach: `11-settings.png`, `08-nutrient-form.png`, `01-today-light.png`.

> Design the **nutrx Pro paywall** and the places Pro appears.
>
> Pro adds:
> - **supply & refills:** know when a bottle runs out;
> - **scan a label:** add a nutrient from its bottle;
> - **weekly recap:** your week, summarised;
> - **trends with Apple Health:** your intake against your sleep and workouts;
> - **a report for your doctor:** a PDF of any period.
>
> Screens:
> 1. **Paywall** (sheet, large detent). It will be built on Apple's `SubscriptionStoreView`, so design around its structure:
>    - a branded header (forest, with the app's ring motif and "nutrx Pro");
>    - the five features as rows with an SF Symbol and one line each;
>    - the plan picker: monthly $1.99, yearly $14.99 marked "1 week free", and lifetime $29.99 as a separate button;
>    - the primary button "Start free week" / "Subscribe" / "Buy lifetime";
>    - a line "Everything you use today stays free.";
>    - Restore purchases, Terms and Privacy links.
>
>    Show it with yearly selected and with lifetime selected.
> 2. **Purchase success.** A short, warm confirmation ("Welcome to nutrx Pro") that returns to where the user was.
> 3. **Settings row and Pro screen.** A "nutrx Pro" row near the top of Settings. Free state: "Learn more". Pro state: plan + renewal date. The Pro screen shows status, the feature list, Manage subscription and Restore.
> 4. **Locked entry point.** How a Pro feature looks to a free user inside a free screen: the "Scan a label" button in the new-nutrient form with a small "Pro" badge. Tapping it opens the paywall. Keep it quiet: no blur or lock walls.
> 5. **Not available on this iPhone.** A short note style for AI features on devices without Apple Intelligence (shown on the paywall row and at the entry point). Clear, not apologetic.

## 3. Supply & refills (Pro — phase 4)

Attach: `01-today-light.png`, `04-nutrient-analytics.png`, `08-nutrient-form.png`, `12-widgets.png`.

> Design **supply & refills**. The user enters what's in a bottle, logging counts it down, and nutrx says when it's running out.
>
> Example: Vitamin D, 120 softgels of 1,000 IU, about 2 a day, so "about 6 days left".
>
> Screens:
> 1. **Supply in the nutrient form.** A "Supply" row (Pro badge for free users) opening a small sheet. It has "Servings in the bottle" (120), "Each serving" (pre-filled from "each tap adds", e.g. 1,000 IU) and "Remind me when this many days are left" (7). Add a "Refilled today" action.
> 2. **On Today's nutrient card.** A quiet supply hint only when it's low: "About 6 days left" in amber. Out: "Out of supply · Refilled?". Nothing when it's fine. It must fit the existing card without making it taller in the normal case.
> 3. **In analytics.** A supply card: a horizontal gauge of what's left, "About 6 days left at your usual 2,000 IU a day", the last refill date and a "Refilled" button.
> 4. **Refill reminder.** The notification ("Vitamin D runs out in about a week") and where it opens: the supply card with "Refilled" ready.
> 5. **Widget.** A one-line "Running low: Vitamin D · 6 days" treatment for the medium widget.
>
> States: plenty, low, out, never set (free and Pro), and a nutrient with no usage history yet ("estimate after a few days").

## 4. Scan a label (Pro — phase 5)

Attach: `08-nutrient-form.png`, `10-onboarding-first-nutrient.png`.

> Design **scan a label**. The user points the camera at a supplement bottle, and nutrx fills in the new nutrient for them to confirm. Everything happens on the iPhone, and nothing is uploaded; say that in one quiet line.
>
> Screens:
> 1. **Entry point.** A "Scan a label" button at the top of the New Nutrient form (with a Pro badge for free users).
> 2. **Scanner** (full screen). Live camera with recognised text highlighted on the label. A short instruction ("Point at the Supplement Facts"), a shutter or auto-capture, a torch, and Cancel. Use native camera chrome where possible.
> 3. **Reading.** A brief processing state over the frozen frame.
> 4. **Review.** The New Nutrient form pre-filled: name "Vitamin D3", unit "IU", each tap adds 1,000, and supply 120 servings. Each field nutrx filled is marked subtly ("from label") until the user edits it. The goal stays empty, because nutrx never suggests amounts. Show it with one field it couldn't read (left empty, a gentle hint to fill it in).
> 5. **Couldn't read it.** A friendly failure with "Try again" and "Fill in by hand".
> 6. **Without Apple Intelligence.** The same flow works with simpler text matching. Show the review state with fewer fields filled and no other difference.

## 5. Weekly recap (Pro — phase 6)

Attach: `01-today-light.png`, `04-nutrient-analytics.png`, `05-history.png`.

> Design the **weekly recap**: a short Sunday summary of the user's week, written from their own logs. It's descriptive only and never advice.
>
> Example copy: "You hit Vitamin D 6 of 7 days. Omega-3 slipped on the weekend. Caffeine went over your limit on Monday. Your streak is now 10 days."
>
> Screens:
> 1. **Notification.** Sunday evening: "Your week in nutrx". It opens the recap.
> 2. **Recap screen.**
>    - A forest hero card: the week's dates, the share of goals met (a segmented ring like Today's day score), and the 3–4 sentence summary.
>    - Below it, small cards: best nutrient, the one that slipped, the weekday you tend to miss, streak change.
>    - A row of the last 8 weeks (mini rings) to switch weeks.
> 3. **Entry points.** A quiet "Your week" card on Today on Sunday and Monday, and a "Weekly recaps" row in History.
> 4. **First week.** A state for when there isn't a full week yet ("Your first recap arrives Sunday").
> 5. **Free user.** How the History row looks without Pro (Pro badge, opens the paywall).

## 6. Trends with Apple Health (Pro — phase 7)

Attach: `04-nutrient-analytics.png`, `11-settings.png`.

> Design **trends with Apple Health**. With the user's permission, nutrx reads their sleep and workouts (read-only, never stored, never synced) and shows simple relationships with their intake. It always uses careful wording ("seems to", "on average"), never causes and never advice.
>
> Example: "On days you work out, you log 30 g less protein on average (12 workout days)." "On days caffeine passes 300 mg, you sleep about 40 minutes less."
>
> Screens:
> 1. **Settings → Apple Health.** Connect / disconnect, what's read (sleep, workouts, active energy), and a clear privacy note: read only, stays on the iPhone, never in iCloud. Before connecting, an explanation screen leads to the system permission sheet.
> 2. **"With Apple Health" card in a nutrient's analytics.** One or two findings, each with a tiny comparison visual (two bars: workout days vs rest days, or a short paired chart) and the sample size.
> 3. **Not enough data yet.** "Trends appear after about two weeks of logging with Apple Health connected", with progress (e.g. "9 of 14 days").
> 4. **Nothing notable.** "No clear pattern yet" (it's fine to find nothing).
> 5. **Free user.** The card as a quiet teaser with a Pro badge.

## 7. Report for your doctor (Pro — phase 8)

Attach: `04-nutrient-analytics.png`, `06-history-day.png`, `11-settings.png`.

> Design the **report for your doctor**: a clean, printable PDF of a chosen period that the user can share or AirDrop. It's generated on the iPhone.
>
> Screens:
> 1. **Create report** (sheet).
>    - Period: last 30 days / 90 days / custom range.
>    - Which nutrients (all by default).
>    - Toggles: include notes, include Apple Health trends.
>    - A preview thumbnail and "Create PDF", which opens the share sheet.
>
>    Entry point: History toolbar and Settings.
> 2. **The PDF itself** (A4 and US Letter, portrait, black and white–friendly with the brand used sparingly):
>    - a cover summary with name (optional), period, nutrients tracked, overall hit rate and longest streak;
>    - per nutrient: its goal, a daily-totals table or compact bar chart, hit rate and average;
>    - a notes section;
>    - a footer on every page: "Generated by nutrx on 14 Oct 2026 · page 2 of 4".
>
>    Show the cover and one content page. Keep it readable by a doctor in 30 seconds.
> 3. **Free user.** The entry point with a Pro badge.
