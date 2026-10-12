# nutrx redesign — implementation spec

This is the single source of truth for the nutrx visual redesign. Everything in `docs/design/` is a handoff from the design canvas:

| Path | What it is |
|---|---|
| `DESIGN.md` | This spec — tokens, components, screens, behaviour, build order |
| `screens/*.png` | Rendered artboards (@2x). **The visual target.** Compare your SwiftUI previews against these. |
| `source/*.dc.html` | The artboard source. Use it to read exact values (sizes, paddings, colours) when a PNG is ambiguous. It is HTML for a design tool — **never port it, never ship it.** |

The mockups use sample data (Vitamin D, Omega-3, …). Nothing in them is hard-coded content for the app.

---

## 0. Principles (read first)

1. **Branded native.** Still SwiftUI, still iOS 26 / Liquid Glass, still HIG. We add a brand layer (colour, rounded numerals, rings) on top of native components — we do not rebuild system chrome.
2. **Native chrome stays native.** Use the system `TabView` (it is already the floating Liquid Glass bar on iOS 26), `NavigationStack`, `.sheet` + `presentationDetents`, `.toolbar`, `Form` where a form is a form. The tab bar / nav buttons in the mockups illustrate the system look; don't hand-draw them.
3. **The ring is the hero.** Progress is shown as rings everywhere (Today, widgets, Watch, form preview). The old linear `NutrientProgressBar` survives only on History day detail.
4. **Each nutrient has a colour and a symbol** chosen by the user. That tint drives its ring, icon tile and charts. Status colours (green done, amber warning) are separate from tints.
5. **Numbers are rounded.** Every numeric value the user reads (intake, targets, stats, counts) uses `.fontDesign(.rounded)` + `.monospacedDigit()`. Labels and prose stay default SF.
6. **No emoji in UI.** Streak flame = SF Symbol `flame.fill`.
7. Light and dark mode are both first-class (see `02-today-dark.png`). Dynamic Type must work — no fixed font sizes.

---

## 1. Design tokens

Put colours in `nutrx/Assets.xcassets` as named colour sets with **Any / Dark** appearances, then expose them through one file: `Shared/DesignSystem/Theme.swift` (new). Widgets and Watch targets get the same colour sets (add the asset catalog colours to those targets, or a shared catalog via target membership).

### 1.1 Brand & surface colours

| Token (asset name) | Light | Dark | Use |
|---|---|---|---|
| `Brand/Forest` | `#1B3B2D` | `#1B3B2D` | Day-score card, streak card, primary buttons (light), welcome screen |
| `Brand/Green` | `#1EB955` | `#1EB955` | "Done" fills, met segments, check badges. **Fills only — never text on light backgrounds** (contrast 2.6:1) |
| `Brand/GreenSoft` | `#7BE3A0` | `#7BE3A0` | Accents on forest (flame, "Today" label, icon on forest) |
| `Text/GreenInk` | `#137A3A` | `#5BD88A` | Green *text* ("Done", "6/6") |
| `Text/AmberInk` | `#9A5A0C` | `#F0B35A` | Warning text ("80 mg left today") |
| `Text/OnTint` | `#050A07` | `#050A07` | Dark ink on a nutrient-tint fill (heatmap percentages) — used where it out-contrasts white; white otherwise. Keeps every tint × fill level ≥ 4.5:1 |
| `Status/Amber` | `#E08A1E` | `#E08A1E` | Ring colour when nearing / over a limit |
| `Surface/Ground` | `#F2F4EF` | `#0A130E` | Screen background (replaces `systemGroupedBackground` on branded screens) |
| `Surface/Card` | `#FFFFFF` | `#142019` | Cards, list groups, sheets |
| `Surface/Chip` | `#0E1A13` @ 6% | `#FFFFFF` @ 7% | Count chips, goal-type tags, segmented track |
| `Text/Primary` | `#0E1A13` | `#EAF2EC` | |
| `Text/Secondary` | `#56655C` | `#97AA9E` | Secondary text (4.5:1 on Ground) |
| `Line/Hairline` | `#EEF1EC` | `#22332A` | Row separators |
| `Control/GhostBorder` | `#D5DCD3` | `#2C4035` | Border of the − button and dashed "add" buttons |
| `Control/Primary` | `#1B3B2D` | `#1EB955` | Filled + button / primary CTA background |
| `Control/OnPrimary` | `#FFFFFF` | `#0A130E` | Glyph/text on `Control/Primary` |
| `OnForest/Primary` | `#FFFFFF` | `#FFFFFF` | Text on forest |
| `OnForest/Secondary` | `#B7CCBF` | `#B7CCBF` | Secondary text on forest |
| `OnForest/Track` | `#FFFFFF` @ 13% | same | Unmet ring segments on forest |
| `Watch/Cell` | `#1C2620` | `#1C2620` | Watch list row background (watchOS is always dark) |
| `Avatar/Fill` | `#DCE7DF` | `#1B3B2D` | Profile avatar circle in the toolbar |
| `Avatar/Ink` | `#1B3B2D` | `#7BE3A0` | Initial on `Avatar/Fill` |

Set the app `AccentColor` to `Brand/Forest` (light) / `Brand/Green` (dark).

### 1.2 Nutrient tints (user-selectable)

Stored on `Nutrient.tintRaw` (see §3). Each tint has a ring/glyph colour, a tile background and a readable ink for glyphs on the tile. Ring track = tint at 15% (light) / 20% (dark) opacity.

| `NutrientTint` case | Tint | Tile bg (light) | Glyph on tile (light) |
|---|---|---|---|
| `green` | `#1EB955` | `#D9F2E2` | `#1B8A47` |
| `teal` | `#13A39C` | `#D6F1EF` | `#0F8A84` |
| `blue` | `#2F80ED` | `#DCE9FC` | `#2368C9` |
| `indigo` | `#6B5BE0` | `#E6E3FB` | `#5A4BCF` |
| `pink` | `#D9539A` | `#FADDEB` | `#B83D7E` |
| `coral` | `#E2674A` | `#FBE3DD` | `#C64A2F` |
| `amber` | `#E5A500` | `#FCF1D2` | `#B07E00` |
| `brown` | `#9B6A45` | `#F0E6DE` | `#7E5536` |

Dark mode: tile bg = tint @ 18% over `Surface/Card`; glyph = tint itself.

### 1.3 Typography

System fonts only, Dynamic Type styles only.

| Role | SwiftUI |
|---|---|
| Large screen title ("Today") | native `.navigationTitle` with `.large` display mode |
| Caption above title ("MONDAY, 12 OCTOBER") | `.footnote.weight(.semibold)`, uppercase, `tracking(0.6)`, `Text/Secondary` |
| Section header ("Morning stack") | `.headline` |
| Card title (nutrient name) | `.body.weight(.semibold)` |
| Big number (day score "3/6", log-sheet amount) | `.system(.largeTitle, design: .rounded, weight: .bold).monospacedDigit()`; if the layout breaks at huge sizes, cap with `.dynamicTypeSize(...DynamicTypeSize.accessibility2)` on that view only |
| Card value ("2,000") | `.system(.body, design: .rounded, weight: .bold).monospacedDigit()` |
| Value suffix ("/ 4,000 IU") | `.subheadline`, `Text/Secondary` |
| Status line ("2,000 IU to go") | `.caption.weight(.semibold)` + status colour |
| Stats ("83%") | `.system(.title, design: .rounded, weight: .bold)` |

### 1.4 Shape, spacing, elevation

Expose these as constants on `Theme` (e.g. `Theme.Radius.card`, `Theme.Spacing.screenMargin`) — no 16 / 10 / 14 / 22 literals in views.

| Token | Value |
|---|---|
| Card corner radius | 22 (`.continuous`) |
| Hero / streak card radius | 28 |
| Icon tile radius | 12–13 (40–42pt tile) |
| Control radius (text field, full-width primary button, goal-type card) | 16 |
| Tag radius ("AT LEAST" chips) | 6 |
| Settings icon tile radius (32pt tile) | 9 (`Theme.Radius.settingsTile`) |
| App-icon tile radius (About, 88pt) | 20 (`Theme.Radius.appIcon`) |
| Sheet corner radius | system |
| Screen horizontal margin | 16 |
| Gap between cards | 10 |
| Card inner padding | 14 |
| Section spacing | 22 above a group header |
| Card shadow (light only) | `shadow(color: Forest.opacity(0.10), radius: 10, y: 6)` — subtle; none in dark (use a 1pt `white @ 5%` inner stroke instead) |
| Touch targets | ≥ 44×44pt everywhere (the − / + buttons are 44pt circles) |

---

## 2. Status logic (shared, testable)

Create `Shared/Services/GoalStatus.swift` (pure logic, unit-tested) used by Today, widgets, Watch, History and the day score. Replace the duplicated `isComplete` / `isStreakDay` logic in `NutrientRowView`, `HistoryListView` etc.

```swift
enum GoalStatus { case inProgress, met, nearingLimit, overLimit }
struct GoalProgress {
    let status: GoalStatus
    let ringFraction: Double     // 0…1 for drawing
    let remainingText: String    // "2,000 IU to go", "80 mg left today", "28 g to range", "Done"
    let countsAsMet: Bool        // for day score / streaks
}
```

| Goal type | Ring fraction | Status / colour | Status line | Counts as met |
|---|---|---|---|---|
| **At least** (`minimum`) | `current / target` | `< target` → tint; `≥ target` → tint + green check badge | "X to go" → "Done" | `current ≥ target` |
| **At most** (`maximum`) | `current / target` | `< 75%` → tint; `75–100%` → `Status/Amber` ring + amber text; `> target` → amber ring, full | "X left today" / "X over limit" | `current ≤ target` |
| **Between** (`range`) | `current / upper` | `< lower` → tint; in range → tint + check; `> upper` → amber | "X to range" → "In range" → "X over range" | `lower ≤ current ≤ upper` |

Edge cases (so the tests have one answer):
- Below the lower bound of a range is `inProgress` — there is no separate "under" state.
- Thresholds are inclusive as written: exactly `target` on At least is met; exactly 75% on At most is nearing; exactly `target` on At most is nearing (still counts as met), status line "Limit reached".
- `current` is floored at 0 and `ringFraction` is clamped to 0…1.
- A range with no `upperBound` (legacy data) behaves like At least `dailyTarget`.

The colour blends of the old `NutrientProgressBar` (blue→green, yellow→red) go away.

---

## 3. Data model changes

All additive and CloudKit-safe (default values, no unique constraints, no renames).

### `Nutrient`
```swift
var tintRaw: String = ""          // "" = never chosen
var symbolName: String = "pills"
var tint: NutrientTint {
    get { NutrientTint(rawValue: tintRaw) ?? NutrientTint.fallback(for: id) }
    set { tintRaw = newValue.rawValue }
}
```
- **Existing users — no migration, no flag.** A nutrient whose tint was never chosen (`tintRaw == ""`) resolves to a stable tint derived from its `id`: sum of the UUID bytes mod 8, indexed into a **pinned** list (green, teal, blue, indigo, pink, coral, amber, brown) — not `allCases`, so adding or reordering a case later can't recolour anyone, and never `hashValue`, which is reseeded every launch. A phase 1 test pins a fixed UUID to its expected tint. The colour is the same on every device, survives reorders, and their Today screen isn't uniformly green. Nothing is written until the user picks a tint, so a reinstall or a second device can never overwrite a tint the user chose (a "still default?" check can't tell an unassigned nutrient from one deliberately set to green).
- **Symbol picker set** (SF Symbols — verify each in the SF Symbols app for the deployment target): `pills`, `sun.max`, `moon`, `drop`, `fish`, `leaf`, `carrot`, `flame`, `bolt`, `heart`, `dumbbell`, `cup.and.saucer`, `waterbottle`, `cross.vial`, `brain.head.profile`, `figure.run`.
- `NutrientTint` enum lives in `Models/NutrientTint.swift` (pure enum, colours resolved in `Theme.swift`, not in the model).

### Onboarding
`UserProfile` fields (name, birthday, weight, height) stay in the model but **leave onboarding** — they're edited from Profile. Name becomes optional for display (avatar shows the initial, or `person.crop.circle` if empty).

No other model changes. `IntakeRecord.note` is already supported.

---

## 4. Components

New views go in `Shared/Components/` unless noted. Every component gets `#Preview`s in light + dark and at `.accessibility3` Dynamic Type.

### 4.1 `ProgressRing`
Track + arc, round caps, starts at 12 o'clock, animates `ringFraction` with `.easeInOut(0.35)`.
Params: `fraction`, `color`, `trackColor`, `lineWidth`. Sizes used: 52pt/5 (Today card), 56/5 (log sheet), 40/5 (widget/Watch), 34/6 (medium widget).
Optional overlay: SF Symbol in the centre (tint colour, ~22pt), and a **check badge** (20pt green circle, dark checkmark, 2pt card-coloured border) at bottom-right when `status` is met/in range.
Accessibility: one element, label = nutrient name, value = "2,000 of 4,000 IU".

### 4.2 `SegmentedDayRing`
N equal segments (N = active nutrients), ~6pt gap, round caps; met segments `Brand/Green`, unmet `OnForest/Track` (on forest) or `Surface/Chip` (on light). Met segments first. Centre: "3/6" (rounded bold, "/6" in `OnForest/Secondary`) + caption "goals met". If N > 12, draw a single continuous ring instead of segments.

### 4.3 `DayScoreCard` (Today header)
Forest card, radius 28, padding 20: `SegmentedDayRing` (116pt) + text column:
- Title, by state: 0 met → "Let's get started"; some → "Halfway there — N to go" (use "Halfway there" only when 40–60% met, otherwise "N to go"); all → "All done for today".
- Streak chip (only if streaks enabled and streak ≥ 1): `flame.fill` in `GreenSoft` + "10-day streak", pill on white @ 10%.
- Next reminder line (only if one is scheduled later today): `bell` + "Vitamin D at 13:00".
Replaces the emoji streak row. The notification / sync banners stay as they are but render below this card.

### 4.4 `NutrientCard` (Today)
Replaces `NutrientRowView` + `ExpandableNutrientCard` on Today.
`HStack(spacing: 14)`: `ProgressRing` 52pt w/ symbol → `VStack` (name; "**2,000** / 4,000 IU"; status line) → − button (44pt, ghost border; disabled at 0) → + button (44pt, `Control/Primary` fill).
- Tap + / − : unchanged behaviour (one step, light haptic, explicit save).
- **Tap the card body → opens `LogSheet`** (no more inline expand).
- Swipe actions and context menu: keep the existing ones (exact amount, edit, move to group).
- Background `Surface/Card`, radius 22, shadow (light).

### 4.5 `GroupHeader`
"Morning stack" (`.headline`) + count chip ("2/3", rounded) + collapse chevron (44pt hit area). Hidden when only the system group exists (existing rule).

### 4.6 `LogSheet` (Today) — replaces `CustomAmountSheet` + `NutrientIntakeHistoryView` + expand
`.sheet` with `.presentationDetents([.medium, .large])`, drag indicator visible.
1. Header: ring (56pt) + name (`.title2.bold`) + "2,000 of 4,000 IU today" + close button.
2. Amount stepper: − / big rounded amount field (`.decimalPad`) + unit / +. −/+ change by one step. Default amount = one step.
3. Quick chips (single-select): **½× step, 1× step, 2× step, "Fill to goal"**. "Fill to goal" = remaining to target (min goal) / to lower bound (range); hidden for "at most" goals and when already met.
4. Note `TextField` ("e.g. with breakfast").
5. Primary button "Log 1,000 IU" (full width, 56pt, `Control/Primary`).
6. "Logged today" list: time (rounded), tint dot, amount, note (source "Widget"/"Watch" if logged there and you have that info — otherwise just the note), trash button (44pt) to delete the record. Delete immediately with a haptic — no confirmation and no undo toast.

### 4.7 `NutrientIconTile`
Rounded square (40–42pt, radius 12–13), tile bg + glyph colour from §1.2. Used in My Nutrients, History day, onboarding, analytics header.

### 4.8 Stats & charts (Analytics)
- `StatTriplet`: three columns — Hit rate (%), Daily avg, Best day — label `.caption.semibold` secondary, value `.title` rounded bold, sub-caption.
- `DailyIntakeChart`: Swift Charts `BarMark`, bars in tint (met days full tint, missed days tint @ 35%), today as a dashed outline bar, goal as dashed `RuleMark` with "Goal 4,000" annotation. Corner radius 10 on bars.
- `WeekdayHeatmap`: 7 rounded squares (Mon–Sun) filled by 4-week hit rate (100% = tint, ≥75% = tint 70%, ≥50% = 40%, else 15%), percentage inside, weekday letter below. Insight sentence below: if the weakest weekday's hit rate is ≥ 25 points below the average → "Sundays are your weakest day." (no sentence otherwise; never invent advice beyond that — the reminder suggestion in the mockup is optional, ship without it if in doubt).

### 4.9 `MonthCalendar` (History)
7-column grid starting on `Calendar.current.firstWeekday` (the mockup is Monday-first only because of its locale; Sunday-first locales get Sunday-first). Day cell 38pt circle:
all goals met → `Brand/Green` fill, dark number; some met → green @ 25% fill; none / no data → no fill; today → 2pt `Brand/Forest` ring; future → secondary text, disabled. Month switcher with chevrons (next disabled on current month). Legend below. Tapping a past day pushes `HistoryDayView`.

### 4.10 Form pickers (Nutrient form)
- `TintPicker`: 8 circles (34pt), selected = 3pt card-colour gap + 2pt tint ring.
- `SymbolPicker`: grid of 44pt tiles; selected tile uses the tint's tile bg/glyph.
- `GoalTypePicker`: 3 cards (At least / At most / Between), each with a tiny bar illustration; selected = 2pt `Control/Primary` border (forest in light, green in dark — `Brand/Forest` disappears on a dark card). Replaces the segmented `Picker`.
- Live preview row at the top of the form (ring + name + "0 / 5 g · +5 g per tap") that updates as you type.

---

## 5. Screens

Screen → PNG → files affected.

### 5.1 Today — `01-today-light.png`, `02-today-dark.png`
`Features/Today/Views/TodayView.swift`
- Large nav title "Today" with the date as an uppercase caption above (custom `ToolbarItem(placement: .principal)` is not needed — put the caption as the first list row or use `.navigationSubtitle` if suitable on iOS 26; match the PNG as closely as native allows). Profile avatar button top-right (existing `.withProfileMenu()`, restyled as a 44pt circle with the initial).
- `DayScoreCard`, then banners (if any), then groups → `NutrientCard`s.
- Background `Surface/Ground`. Keep `List` (for swipe actions) with `.listStyle(.plain)`, clear row backgrounds, hidden separators, 16pt insets — or a `ScrollView` + `LazyVStack` if swipe actions are re-implemented; prefer keeping `List`.
- Empty state: `ContentUnavailableView` with `leaf` + button "Add a nutrient".

### 5.2 Log sheet — `03-log-sheet.png`
See §4.6. Opened by tapping a card, the leading swipe action, or "Add Exact Amount" in the context menu.

### 5.3 Nutrient analytics — `04-nutrient-analytics.png`
`Features/Nutrients/Views/NutrientAnalyticsView.swift` + the three card files.
Header: `NutrientIconTile` (52pt) + name (`.title.bold`) + "At least 4,000 IU a day · Morning stack". Native back button and an "Edit" toolbar button (opens the form). Segmented `Picker` 7 / 30 / 90 days (native, `.segmented`). Cards: `StatTriplet` + `DailyIntakeChart` in one card, `WeekdayHeatmap` card, a "Reminders" row (opens `NutrientRemindersSheet`).

### 5.4 History — `05-history.png`
`Features/History/Views/HistoryListView.swift`
Streak card (forest): `flame.fill` in a 52pt circle, "10 days" (rounded title), "Current streak · every goal met", divider, "31 Best". Hidden if streaks disabled. Then `MonthCalendar` card, then "Recent days" list: date, row of 8pt dots (one per nutrient in its tint if met, `Surface/Chip` if not), score "6/6" (`GreenInk` if all met), chevron.

### 5.5 History day — `06-history-day.png`
`Features/History/Views/HistoryDayView.swift`
Caption weekday + large date title. Summary card: small `SegmentedDayRing` (64pt, on light) + "4 of 6 goals" + "Missed Omega-3 and Protein". Rows: icon tile, name, "**4,000** / 4,000 IU", 8pt linear bar in tint, status badge (green check / grey dash). Tapping a row opens the existing intake detail sheet (restyled list).

### 5.6 My Nutrients — `07-my-nutrients.png`
`Features/Nutrients/Views/NutrientsListView.swift`
Large title, toolbar: + (primary filled circle) and profile. Groups as inset cards with uppercase section headers + count. Row: `NutrientIconTile`, name, goal-type tag ("AT LEAST" / "AT MOST" / "BETWEEN", `.caption2.bold` in a chip) + target + `bell.fill` if reminders exist, chevron → analytics. Keep reorder, swipe and context actions. Dashed "New group" button at the end (opens the existing group creation).

### 5.7 New / edit nutrient — `08-nutrient-form.png`
`Features/Nutrients/Views/NutrientFormView.swift`, `Shared/Components/NutrientFormFields.swift`
Sheet with Cancel / title / Add (prominent). Live preview row, Name + Unit, "Look" section (`TintPicker` + `SymbolPicker`), "Daily goal" (`GoalTypePicker` + target / upper bound + "Each tap adds"), Group row, Reminders row, Notes. Using `Form` underneath is fine — style the sections to match (rounded inset groups on `Surface/Ground`).

### 5.8 Onboarding — `09-onboarding-welcome.png`, `10-onboarding-first-nutrient.png`
`Features/Onboarding/…`
1. **Welcome** (new): full-bleed forest, brand mark (use the app icon artwork as an image asset — do not redraw the logo in code), headline "Track what you take. **Nothing else.**" (second line `GreenSoft`), three benefit rows, "Get started" button (`Brand/Green` bg, dark text).
2. **First nutrient**: progress bar (2 steps), back, Skip. Title "What do you want to track first?", 2-column grid of starting points + dashed "Something else" (opens the blank form). Selecting a starting point pre-fills goal + step fields at the bottom (editable). "Start tracking" creates the nutrient and finishes onboarding.
- **Starting points are pre-fills, not a preset list** — the user can edit everything, and nothing is created unless they tap Start tracking. Defaults (editable; confirm the numbers before shipping):

| Name | Unit | Goal | Step | Symbol | Tint |
|---|---|---|---|---|---|
| Vitamin D | IU | at least 4,000 | 1,000 | `sun.max` | amber |
| Magnesium | mg | at least 400 | 200 | `pills` | indigo |
| Omega-3 | mg | at least 2,000 | 1,000 | `fish` | teal |
| Water | L | at least 2.5 | 0.25 | `drop` | blue |
| Protein | g | between 120–160 | 20 | `dumbbell` | coral |
| Creatine | g | at least 5 | 5 | `waterbottle` | green |

- Personal info step is removed from onboarding (§3). `OnboardingPersonalInfoView` moves/merges into Profile editing.

### 5.9 Settings — `11-settings.png`
`Features/Settings/Views/SettingsView.swift`
Profile card at top (avatar initial in forest circle, name, "Edit profile" → Profile sheet). Rows with Settings-style coloured icon tiles (white SF Symbol on solid colour, 32pt, radius 9): iCloud Sync (blue), Notifications (coral), Streaks (green), Groups (indigo); second group: Rate nutrx (amber), About (grey). Footer: lock symbol + "Private by design. No accounts, no servers, no tracking. Your data lives on your devices and your iCloud."

### 5.10 Widgets — `12-widgets.png`
`NutrxWidgets/…`
- Small: forest background, `SegmentedDayRing` + "3/6 goals met", "Today" + streak count, "Next: Vitamin D".
- Medium: white, 3 rows (ring 34pt + name + value + interactive + button via `LogNutrientIntent`).
- Lock Screen: circular = ring + "3/6"; rectangular = name, value, linear bar; inline = "3/6 goals · 10-day streak". Lock Screen widgets are monochrome — rely on shape, not colour (use `widgetAccentable` where useful).

### 5.11 Apple Watch — `13-watch.png`
`nutrx Watch App/…`, `NutrxWatchWidgets/…`
List rows on `Watch/Cell` backgrounds: ring 30pt in tint, name, value, + button (`Brand/Green`, dark glyph). Header "Today" (`GreenSoft`) + "3/6". After a tap: confirmation view with a large ring, value, "+1,000 logged" pill in the tint, haptic. Complications: circular segmented ring with "3/6", rectangular "nutrx · 3/6" + 6 segment bar, inline "3/6 goals · 10 days".

---

## 6. Accessibility checklist (every phase)

- All icon-only buttons have `accessibilityLabel` ("Add one step of Vitamin D", "Remove one step…", "Close", "Delete entry").
- Rings: `.accessibilityElement(children: .ignore)` + label/value; the day score reads "3 of 6 goals met".
- Colour is never the only signal: met = check badge, warning = amber **and** status text.
- Green text uses `Text/GreenInk`, never `Brand/Green`.
- Test at the largest accessibility text size: cards may wrap to two lines; the −/+ buttons must stay reachable.
- Reduce Motion: no ring animation, just set the value.

---

## 7. Build order (one phase per session)

Each phase ends with: builds clean (`xcodebuild … build`), previews for new views in light/dark, screenshots compared against the PNGs, `CHANGELOG.md` / `CLAUDE.md` updated (use the `update-docs` skill).

1. **Foundations** — asset-catalog colours (§1), `Theme.swift` (colours + §1.4 spacing/radius constants), `NutrientTint`, model fields (§3), create the `nutrxTests` unit-test target (none exists yet), `GoalStatus` + unit tests (§2), `ProgressRing`, `SegmentedDayRing`, `NutrientIconTile`.
2. **Today** — `DayScoreCard`, `NutrientCard`, `GroupHeader`, TodayView restyle (light + dark).
3. **Log sheet** — `LogSheet`; delete `CustomAmountSheet`, `ExpandableNutrientCard`, `NutrientIntakeHistoryView` once nothing references them.
4. **Nutrient form + My Nutrients** — pickers, live preview, list restyle.
5. **Analytics** — stats, chart, heatmap.
6. **History** — streak card, `MonthCalendar`, recent days, day detail.
7. **Onboarding** — welcome, starting points, move personal info to Profile.
8. **Settings & Profile** restyle.
9. **Widgets** (iOS) — small, medium, Lock Screen.
10. **Watch** app + complications.
11. **Polish** — accessibility pass (§6), Dynamic Type, dark mode, haptics, then retire `NutrientProgressBar` from everywhere except History day detail.

## 8. Out of scope / don't

- Don't port the `.dc.html` source or recreate it with a web view.
- Don't build a custom tab bar or navigation bar.
- Don't add third-party dependencies (fonts, chart libs, animation libs).
- Don't change persistence, sync or notification logic beyond what a step above asks for.
- Don't ship the marketing site changes (`nutrx-labs.github.io`) until the app redesign is released.
