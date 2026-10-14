# nutrx Pro — design handoff

Mockups for the seven prompts in [`../DESIGN-PROMPTS.md`](../DESIGN-PROMPTS.md), one folder per feature in build order. Each folder has:

- `screens/*.png` — @2x renders. **The visual target.** Light and dark for every screen, plus one key screen at the largest accessibility text size (`largest-text.png`).
- `source/*.dc.html` — design-tool source, for reading exact values only. Never port or ship it.

Everything follows the v2 tokens and components in [`../../design/DESIGN.md`](../../design/DESIGN.md). This file only lists what's **new**. Sample data (Vitamin D, "Morning" stack, prices, dates) is illustrative.

---

## Shared: the Pro badge

The only Pro marker a free user sees. It's never a lock, blur or wall.

| | Light | Dark |
|---|---|---|
| Inline badge (in rows and cards) | text `PRO`, SF Pro Rounded Heavy 10pt, tracking 0.6, padding 4×6, radius 6, background Forest @ 9%, text Forest | Green @ 16%, text `#7BE3A0` |
| Corner badge (toolbar icon buttons) | 9pt, padding 3×4, radius 5, solid Forest, white text, offset −6 / −4 from the button's top-right corner | solid Green, text `#0A130E` |

Tapping anything with a badge opens the paywall sheet. The free version of a screen never hides content; it only adds the badge.

---

## 1 · Stacks & export (free, phase 2) — `1-stacks-export/`

| Screen | States |
|---|---|
| `today` / `today-one` | Stacks row with 3 stacks (one done today) / with 1 stack |
| `log-stack` / `log-stack-done` | Confirmation sheet with editable amounts / after logging |
| `stacks` / `stacks-empty` | Settings → Stacks list / empty state |
| `stack-detail` | Name, nutrients with amounts, Siri tip, delete |
| `export` / `export-done` | Settings → Export data / after export |

**New components**

- **StackCard** (Today): 176pt wide, radius 22, padding 14, gap 10. It has a title (Headline), 24pt tinted icon tiles (radius 7) and a 44pt full-width button. Not done: primary **Log**. Done today: green check badge (20pt) by the title, and the button turns ghost (**Log again**, 1.5pt GhostBorder). The row scrolls horizontally with a 10pt gap and a 16pt inset. With one stack, it becomes a single full-width card: title, tiles, "3 nutrients", and a **Log** pill on the right.
- **Stacks row header:** "Stacks" (Headline) plus **Edit** on the right, which opens Settings → Stacks. It sits between the day-score card and the first group.
- **LogStackSheet** (medium/large detent):
  - Each row: a 44pt ring at the current progress, the name, and "0 / 4,000 IU", then an inline amount stepper. The stepper is a chip-tinted capsule: −, amount (rounded bold 15), + (44pt tall).
  - Footnote: "Changes here apply to this time only. Edit stack".
  - Primary button **Log 3 nutrients** (56pt).
  - After logging, the rings animate to their new value and the met ones get check badges. Each amount turns into "+2,000 IU" in GreenInk. A green status strip says "Logged 3 nutrients at 08:12", with **Undo** (ghost) and **Done** (primary) side by side.
- **Siri tip card:** background Forest @ 6% (dark: Card), radius 20, padding 14. It has a 36pt white tile with a waveform symbol, the title "Say “Log my Morning stack” to Siri", one secondary line, and a dismiss ✕ (32pt).
- **Export:**
  - A document tile (52pt, radius 16), a one-paragraph explanation, and a period picker. The picker is an inset list with a checkmark: All time / Last 30 days / Last 90 days.
  - A count line: "1,284 entries · 6 nutrients · since …".
  - **Export CSV** (primary) opens the share sheet.
  - Done state: a green status strip with the file name, and the button becomes **Export again**.

---

## 2 · Paywall & Pro (phase 3) — `2-paywall/`

| Screen | States |
|---|---|
| `paywall` / `paywall-lifetime` | Yearly selected / lifetime selected |
| `success` | Welcome to Pro (medium sheet) |
| `settings` / `settings-pro` | Free / Pro row in Settings |
| `pro-screen` | Status, included features, manage, restore |
| `locked` | "Scan a label" in New Nutrient for a free user |
| `no-apple-intelligence` | Note styles when Apple Intelligence is missing or off |

**Paywall** (large-detent sheet, built around `SubscriptionStoreView`):

1. **Header:** Forest, padding 26/22/22. It has the ring motif (Green arcs at 30pt stroke, partly offscreen top-right), the "nutrx" wordmark (Rounded Heavy 30) with a `PRO` chip (`#7BE3A0` on Forest text) and one line of copy. Close button: 44pt, white @ 12%.
2. **Feature rows:** 46pt min height, a 34pt tinted tile (radius 10), title (15 semibold) and one line (13 secondary). The five features use tints amber, teal, indigo, coral and blue.
3. **Plan picker:**
   - Radio cards: 56pt min, radius 16, Card background. Selected: 2pt Forest border (dark: Green) and a 22pt radio with a 6pt ring.
   - Yearly carries a `1 WEEK FREE` tag (11pt bold, GreenInk on green tint).
   - Lifetime sits below an "or pay once" divider. It's the non-consumable, separate from the subscription group but styled the same.
4. **Primary button:** **Start free week** / **Subscribe** / **Buy lifetime**, with the price terms in 12pt below it.
5. **Footer:** "Everything you use today stays free." (GreenInk, 13 semibold), then Restore purchases · Terms · Privacy (36pt tall text buttons).

**Settings Pro row:**
- Forest card (radius 22), ring motif, a 44pt tile with the ring symbol in Soft green.
- Free: "Supply, label scan, recaps and more" + **Learn more**.
- Pro: "Yearly · renews 14 Oct 2027" + a check badge.

Pro-only rows elsewhere in Settings (Apple Health, Report) get the inline badge for free users. Stacks and Export data are new free rows.

**Without Apple Intelligence:**
- On the paywall, a 12pt secondary line with ⓘ under the affected rows: "Basic text reading on this iPhone" (Scan), "Simpler wording on this iPhone" (Recap). One summary line: every Pro feature still works.
- At the entry point, a 13pt ⓘ note under the button.
- When Apple Intelligence is turned off, a tinted strip with a **Settings** button.
- Tone: factual, never apologetic. Nothing is ever marked "unavailable", because every Pro feature has a fallback.

---

## 3 · Supply & refills (Pro, phase 4) — `3-supply/`

| Screen | States |
|---|---|
| `supply-form` | Supply sheet over Edit Nutrient |
| `cards` | Today card: plenty · low · out · no history. Analytics card: never set (Pro) · never set (free) · set but no history |
| `analytics` / `analytics-open` | Supply card / opened from the reminder (card focused, **Refilled** primary) |
| `notif` | Banner + long-press actions (Refilled / Remind me tomorrow) |
| `widget` | Medium widget's "Running low" line, light + dark |

**Rules**

- **Today card height never changes.** The supply hint shares the third line with the goal status: "2,000 IU to go · About 6 days left", with the bottle symbol (amber bottle symbol + AmberInk text). When out: "Out of supply · Refilled?", where **Refilled?** is an underlined link. Nothing shows when supply is plenty, unset, or has no history.
- **Supply sheet:** three stepper rows (64pt):
  - Servings in the bottle;
  - Each serving (pre-filled from "each tap adds", hint "Same as “each tap adds”");
  - Remind me (days left).

  Then a computed sentence ("That's 120,000 IU — about 60 days at your usual 2,000 IU a day") and a ghost **Refilled today** button.
- **Analytics supply card:**
  - Days left: Rounded Bold 34 in AmberInk when low.
  - "12 of 120 softgels".
  - A 12pt gauge: fill `#E08A1E` when low (tint otherwise), with a 2pt tick at the reminder threshold.
  - An explanation line, the last refill date, and **Refilled** (ghost; primary when opened from the reminder).
  - Focus state: a 3pt Forest outline (dark: Green).
- **Widget:** a hairline divider, then a 12pt line: amber bottle + "Running low:" (AmberInk) + "Vitamin D · 6 days". It shows only for the soonest-running-out nutrient.

---

## 4 · Scan a label (Pro, phase 5) — `4-scan-label/`

| Screen | States |
|---|---|
| `entry` | "Scan a label" card at the top of New Nutrient (Pro user; free version is `2-paywall/locked`) |
| `scanner` | Live camera, recognised text outlined, instruction pill, shutter, torch, privacy line |
| `reading` | Frozen frame dimmed + "Reading the label…" pill |
| `review` / `review-partial` / `review-no-apple-intelligence` | All fields read / one field unread / fewer fields read |
| `fail` | "Couldn't read this label" sheet over the blurred frame |

**New components**

- **Scan entry card:** a 44pt teal tile with the doc-scanner symbol, the title, "Fill this in from the bottle", and a chevron. Below it is an "or fill in by hand" divider, then the normal form.
- **Recognised-text highlight:** 2pt `#7BE3A0` outline with a 16% fill, radius 5–6, following the text's rotation. Use VisionKit's own highlighting where possible.
- **Camera chrome:** glass buttons (white @ 16%, blur) for Cancel and Torch, an instruction pill (black @ 55%, blur), a 76pt shutter (4pt ring), and the privacy line "Read on your iPhone. Nothing is uploaded." (13pt, white @ 75%).
- **"from label" tag:** 11pt bold teal-ink on a teal tint, with a small scan symbol, aligned right on the field label row. It disappears once the user edits that field.
- **Unread field:** the row background is amber @ ~8%, with an AmberInk hint under the empty field ("Couldn't read the bottle size — it's usually “servings per container”.").
- **Review banner:** a teal-tint strip: "Filled from the label. Check it before adding." with a **Scan again** link. The partial and no-AI states only change the count ("One field needs you" / "Two fields need you").
- **Goal is always empty after a scan,** with the hint "Set the amount you're aiming for. nutrx doesn't suggest one." **Add** stays disabled until name, unit and goal are set.

---

## 5 · Weekly recap (Pro, phase 6) — `5-weekly-recap/`

| Screen | States |
|---|---|
| `notif` | Sunday banner + long press (Open recap / Turn off weekly recaps) |
| `recap` | Forest hero card, four fact cards, eight-week strip |
| `today` | "Your week" card on Sunday/Monday |
| `history` / `history-free` | "Weekly recaps" row for Pro / for a free user |
| `first` | Before a full week exists |

**New components**

- **Recap hero:**
  - Forest, radius 28, padding 18.
  - An 88pt ring with **7 segments, one per day** (lit = every goal met that day), with "5/7 · full days" in the centre.
  - The date range in uppercase 13pt `#9FC2AE`, a headline ("31 of 42 goals met"), and the 3–4 sentence summary in 15/22 `#DCE9E0`.
  - The summary is built from computed facts. The on-device model only phrases them.
- **Fact card** (2×2 grid, gap 10): label (12 secondary), a 28pt tinted tile + value (16 semibold), and a sub-line. Fixed set: Steadiest · Slipped · Day you tend to miss · Streak.
- **Week strip:** eight 60pt cells, each with a 28pt ring (week hit %) and the week's start day. The selected cell has a chip background.
- **"Your week" card** (Today): a 44pt green ring, title, one line, and a dismiss ✕ (hides it until next Sunday). It appears only on Sunday and Monday, under the day-score card.
- **First week:** the hero ring counts days logged so far ("3 · days logged"), titled "Your first recap arrives Sunday". There are no fact cards, plus one explanatory line about privacy.

---

## 6 · Trends with Apple Health (Pro, phase 7) — `6-health-trends/`

| Screen | States |
|---|---|
| `intro` | Explanation before the system permission sheet |
| `settings` | Connected status, what's read, privacy note, disconnect |
| `trends` | "With Apple Health" card in a nutrient's analytics, two findings |
| `states` | Not enough data (9 of 14 days) · No clear pattern · Free teaser |

**New components**

- **Finding:**
  - A sentence in 15/21 with careful wording ("seems to", "on average").
  - A **paired bar**: two rows, each a 96pt label, a 12pt bar and a right-aligned value (Rounded Bold 13). The condition row is in the nutrient's tint; the comparison row uses the same tint at ~45%.
  - The sample size in 12pt secondary.
  - Findings are divided by a hairline.
  - Card footer: "Patterns in your own data, not causes. Worked out on this iPhone."
- **Progress to first trend:** 14 segments (10pt tall, gap 3, radius 3) in coral, plus "9 of 14 days".
- **Privacy note:** a green-tint strip with a lock symbol. Wording: read only, stays on this iPhone, never in iCloud.
- **Free teaser:** the real card frame with the inline Pro badge, one line of copy, two ghost placeholder bars and a "Learn about nutrx Pro" link.

---

## 7 · Report for your doctor (Pro, phase 8) — `7-doctor-report/`

| Screen | States |
|---|---|
| `create` | Sheet: preview thumbnail, period (30 / 90 / custom), nutrients, toggles (name, notes, Apple Health), **Create PDF** → share sheet |
| `entry` | Free user: History toolbar button with corner Pro badge, long-press preview, Settings rows |
| `pdf-cover` / `pdf-page` | A4 cover and a nutrient page |
| `pdf-letter` | US Letter cover |

**PDF spec** (black-and-white-friendly; brand only in the small header mark):

- **Page:** A4 794×1123 px / Letter 816×1056 px at 96 dpi. Margins 72px left and right, ~56–64px top and bottom.
- **Type:** H1 40/46, H2 20–24, body 15–16, captions and footer 12. Text is near-black `#111`; secondary text is never lighter than `#555`. Rules are ≥1px.
- **Cover:**
  - Header (mark + "Intake report", 2px rule).
  - Title, then the period.
  - A definition list: name (optional), nutrients tracked, days with entries.
  - Two outlined stat boxes: overall hit rate and longest streak.
  - A summary table: nutrient · goal · average · hit rate, with numbers right-aligned.
  - A self-reported disclaimer line.
- **Nutrient page:**
  - Title and goal.
  - Three outlined stat boxes: hit rate, average, days logged.
  - A 90-day bar chart, 130px tall: met days `#222`, missed days `#BDBDBD`, a dashed goal line, and month ticks.
  - A one-line caption.
  - A notes table at the end of the report.
- **Footer on every page:** "Generated by nutrx on 14 Oct 2026" left, "page 2 of 4" right, above a 1px rule.
