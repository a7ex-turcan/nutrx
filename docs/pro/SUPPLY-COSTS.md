# Supply costs and Add to list — spec (nutrx Pro, #134)

Supply (Pro) already knows a bottle's size and how fast it goes. With an optional **price per bottle** it can also say what a nutrient costs a month, for one nutrient, a stack or everything. When a bottle runs low, **Add to list** puts it on a list of your choice, Apple's Reminders included, through the share sheet. Planned for 2.5.

Decided with the user on 2026-10-23:
- **The share sheet, not EventKit.** iOS has no add-only permission for reminders: adding one directly needs full access to all of the user's reminders. The share sheet needs no permission and stores nothing, and the user picks Reminders, Notes or Messages.
- **Costs in three places:** a nutrient's Supply card, a total for all nutrients, and each stack.
- Screens are built from existing patterns.

---

## 1. The price

- `Nutrient.supplyPrice: Double?`: what one bottle costs, meaning the supply the Supply sheet sets up (servings × each serving). Nil means no price. It's CloudKit-safe as an optional, and the field is `CD_supplyPrice`.
- **Currency:** the user's (`Locale.current.currency`, USD when there's none). Only the number is stored, so changing region shows the same number in the new currency. No conversion, no shops, no links.
- **Set in the Supply sheet:** an optional "Price per bottle" field under the servings, with the currency symbol, a `.decimalPad` keyboard, and an empty placeholder. Stop tracking supply clears it with the rest.

## 2. What it costs a month

`SupplyCost` (pure, next to `SupplySchedule`, tested):

- **A nutrient:** price ÷ bottle amount × daily use × 365 ÷ 12.
  - **Daily use** is supply's own estimate (`SupplyStatus.dailyUse`: the last 14 days' total over the days since the first log in them, once there are at least 3), so a schedule is already in it.
  - **Without that estimate**, it's the goal (the target, or a range's lower bound) times the share of days that are dose days: weekdays n/7, a cycle on/(on + off), times a week n/7, every day 1. That's the same "at your goal of …" fallback as the Supply sheet's sentence.
  - **No cost** when there's no price, no supply set, or no use to go on (no history and an "at most" goal).
- **Totals** add up the nutrients that have a cost and are running: not removed, and their course not ended. They also count those without a price, so the line can say so.
- **Wording**, in `SupplyText`:
  - "About $4 a month"; under 10 in the currency, with cents ("About $3.60 a month").
  - All nutrients: "About $38 a month for 5 nutrients", and "· 2 without a price" when some have supply set but no price.
  - A stack: "This stack costs about $12 a month".
  - Amounts follow the user's locale.

## 3. Where it shows

- **The Supply card** (a nutrient's analytics): the cost under the days left, "About $4 a month". It isn't shown when there's no cost.
- **My Nutrients:** one line at the end of the list, under New group, for Pro users with at least one price set: "About $38 a month for 5 nutrients". It's hidden in Select mode.
- **A stack's detail:** a line under its nutrients, "This stack costs about $12 a month". That's the sum of the monthly costs of the stack's running nutrients with a price, at each one's own usual use, not the stack's amounts, which are per log. It shows "Not counted: 2 without a price" when some have none.

## 4. Add to list

- **On the Supply card,** when the level is low or out: an **Add to list** button (`square.and.arrow.up`) beside Refilled. It opens the system share sheet with one line of text:
  - "Vitamin D: 120 × 1,000 IU", or "Vitamin D" when there's no serving size.
  - Picking Reminders adds it there. The text is plain, so Notes, Messages or Mail work too.
- **On My Nutrients' total line,** when anything is low or out: "2 running low · Add to list" shares one line per nutrient, the same text, in Today's order.
- **The refill notification** keeps its actions (Refilled, Remind me tomorrow). Tapping it already opens the nutrient's Supply card, where Add to list is.
- Nothing is stored and no permission is asked. The share sheet is `ShareLink` (no completion needed).

## 5. Rules it keeps (docs/pro/PLAN.md §0)

- It's all on the device.
- No advice on what or how much to take, and no prices fetched, compared or suggested.
- Nothing free becomes Pro. Supply is already Pro, and costs and Add to list are part of it.
- The paywall's Supply row can say so: "Know when a bottle runs out, and what it costs".

## 6. Build phases (one PR each, in order)

1. **The rule.** `supplyPrice`, `SupplyCost` and its wording, with tests. `Tools/CloudKitSchema/fields.txt` and the development schema with `cktool`. **The production schema needs `CD_supplyPrice` before this merges**, because every merge to `main` uploads a TestFlight build.
2. **Prices and costs.** The Supply sheet's price field, the Supply card's line, My Nutrients' total, a stack's line.
3. **Add to list, and shipping.** The Supply card's button, the total line's share, the paywall's Supply subtitle, a 2.5 What's New entry, and the docs (CLAUDE.md, CHANGELOG, ROADMAP).

Each phase comes with simulator checks and screenshots in its PR, as usual.
