# Supply costs and Add to list — spec (nutrx Pro, #134)

Supply (Pro) already knows a bottle's size and how fast it goes. With an optional **price per bottle** it can also say what a nutrient costs a month, for one nutrient, a stack or everything. When a bottle runs low, **Add to list** puts it on a list of your choice, Apple's Reminders included, through the share sheet. Built for 2.5 (spec #265, phases #266, #267 and the Add to list PR).

Decided with the user on 2026-10-23:
- **The share sheet, not EventKit.** iOS has no add-only permission for reminders: adding one directly needs full access to all of the user's reminders. The share sheet needs no permission and stores nothing, and the user picks Reminders, Notes or Messages.
- **Costs in three places:** a nutrient's Supply card, a total for all nutrients, and each stack.
- Screens are built from existing patterns.

---

## 1. The price

- `Nutrient.supplyPrice: Double?`: what one bottle costs, meaning the supply the Supply sheet sets up (servings × each serving). Nil means no price. It's CloudKit-safe as an optional, and the field is `CD_supplyPrice`.
- **Currency:** the user's (`Locale.current.currency`, USD when there's none). Only the number is stored, so changing region shows the same number in the new currency. No conversion, no shops, no links.
- **Set in the Supply sheet:** an optional "Price per bottle" row, last in the card (after Remind me: the bottle comes first, then the extra), a capsule the steppers' width with the currency symbol, a `.decimalPad` keyboard and the placeholder "None". Stop tracking supply clears it with the rest.

## 2. What it costs a month

`SupplyCost` (pure, next to `SupplySchedule`, tested):

- **A nutrient:** price ÷ bottle amount × daily use × 365 ÷ 12.
  - **Daily use** is supply's own estimate (`SupplyStatus.dailyUse`: the last 14 days' total over the days since the first log in them, once there are at least 3), so a schedule is already in it.
  - **Without that estimate**, it's the goal (the target, or a range's lower bound) times the share of days that are dose days, from the schedule piece in effect today: weekdays n/7, a cycle on/(on + off), times a week n/7, every day 1. The Supply sheet's "at your goal of …" sentence uses the plain target today (`SupplySheet.sentence`); phase 2 moves it onto this daily amount, so the sheet's "about 60 days" and the card's cost agree.
  - **No cost** when there's no price, no supply set, or no use to go on (no history and an "at most" goal).
- **Totals** add up the nutrients that have a cost and are running: not removed, and their course not ended. They also count those without a price, so the line can say so.
- **Wording**, in `SupplyText`:
  - "About $4 a month". Under 10 in the currency, it uses the currency's own minor units ("About $3.60 a month", "About ¥480 a month"); from 10, whole amounts.
  - All nutrients: "About $38 a month for 5 nutrients".
  - A stack: "This stack costs about $12 a month".
  - Either adds "· 2 without a price" when some of its nutrients have supply set but no price.
  - Amounts follow the user's locale.

## 3. Where it shows

- **The Supply card** (a nutrient's analytics): the cost under the days left, "About $4 a month". It isn't shown when there's no cost.
- **My Nutrients:** one line at the end of the list, under New group, for Pro users, once at least one nutrient has a cost: "About $38 a month for 5 nutrients". A priced "at most" nutrient with no history has no cost yet, so it doesn't bring the line. It's hidden in Select mode. The running-low share (§4) shows on that line, or on its own when there's no cost to show.
- **A stack's detail:** a line under its nutrients, "This stack costs about $12 a month · 1 without a price". That's the sum of the monthly costs of the stack's running nutrients with a cost, at each one's own usual use, not the stack's amounts, which are per log. **Stacks are free, so free users see nothing here**: no line and no PRO chip. The stack screen stays as it is for them.

## 4. Add to list

- **On the Supply card,** when the level is low or out: an **Add to list** button (`square.and.arrow.up`) beside Refilled. It opens the system share sheet with that nutrient's line (below). Picking Reminders adds it there. The text is plain, so Notes, Messages or Mail work too.
- **On My Nutrients,** when anything is low or out: "2 running low · Add to list" shares one line per nutrient, the same text, in My Nutrients' order. It sits under the total line, or on its own for a Pro user who tracks supply without prices.
- **The text:** "Vitamin D: 120 × 1,000 IU", the bottle's servings and each serving (`effectiveServingAmount`, so there's always one). It's just "Vitamin D" when the nutrient has no unit, where "120 × 1" would read oddly.
- **The refill notification** keeps its actions (Refilled, Remind me tomorrow). Tapping it already opens the nutrient's Supply card, where Add to list is.
- Nothing is stored and no permission is asked. The share sheet is `ShareLink` (no completion needed).

## 5. Rules it keeps (docs/pro/PLAN.md §0)

- It's all on the device.
- No advice on what or how much to take, and no prices fetched, compared or suggested.
- Nothing free becomes Pro. Supply is already Pro, and costs and Add to list are part of it.
- The paywall's Supply row can say so: "Know when a bottle runs out, and what it costs".
- **If Pro lapses:** prices stay stored, like the rest of the supply setup. The cost lines and Add to list hide with the rest of Supply: the Supply card goes back to its free teaser, and My Nutrients and stacks show nothing.

## 6. Build phases (one PR each, in order)

1. **The rule.** `supplyPrice`, `SupplyCost` and its wording, with tests. `Tools/CloudKitSchema/fields.txt` and the development schema with `cktool`. **The production schema needs `CD_supplyPrice` before this merges**, because every merge to `main` uploads a TestFlight build. It was deployed to production on 2026-10-24.
2. **Prices and costs.** The Supply sheet's price field and its sentence on `SupplyCost`'s daily amount, the Supply card's line, My Nutrients' total, a stack's line.
3. **Add to list, and shipping.** The Supply card's button, the total line's share, the paywall's Supply subtitle, a 2.5 What's New entry, and the docs (CLAUDE.md, CHANGELOG, ROADMAP).

Each phase comes with simulator checks and screenshots in its PR, as usual.
