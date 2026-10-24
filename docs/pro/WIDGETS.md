# Pro widgets and controls — spec (nutrx Pro, #138)

Two Control Center controls, a widget for one chosen nutrient and a supply & courses widget, for nutrx Pro. They save a trip into the app for the things Pro users do every day: log a stack, log one nutrient, see what's running out. Built for 2.5, after supply costs (#134).

Decided with the user on 2026-10-24:
- **All three pieces in 2.5**, one PR per phase (§6).
- **Two controls:** Log stack (a stack you pick) and Log nutrient (one step of a nutrient you pick).
- **The one-nutrient widget comes small and as a Lock Screen ring.**

---

## 1. Rules it keeps (docs/pro/PLAN.md §0)

- **Nothing free becomes Pro.** The five widgets that exist (Today, Quick log, Goals, Next up, Goals and streak) stay free and unchanged. Their kind IDs never change.
- **Never a lock.** A free user who adds a Pro widget or control sees what it is, with the PRO chip, and a tap opens the paywall (§5). Nothing is blurred and nothing says "locked".
- **On the device only.** Widgets and controls read the shared App Group store, with nothing fetched. No Health data is involved.
- **No advice.** They show amounts, goals and days left, the way the app does.
- **The entitlement is never stored.** The widget extension asks StoreKit itself (`ProEntitlement.current()`), as the medium widget's running-low line does.

## 2. Controls (Control Center, Lock Screen, Action button)

Two `ControlWidget`s in `NutrxWidgetsExtension`, configurable when added (`AppIntentControlConfiguration`):

| Control | Kind ID | Configured with | Shows | Tap |
|---|---|---|---|---|
| **Log stack** | `NutrxLogStackControl` | a stack (`StackEntity`) | `square.stack.3d.up`, "Morning" / "Log" (a tick and "Logged today" once logged) | logs the stack as Today's Log does (`StackLogging.log`) |
| **Log nutrient** | `NutrxLogNutrientControl` | a nutrient (`NutrientEntity`) | the nutrient's symbol, "Vitamin D" / "+1,000 IU" | logs one step, as the widget's + does |

- **Not configured yet:** iOS asks for the stack or nutrient when the control is added (`promptsForUserConfiguration`). Until one is chosen it reads "Choose a stack" / "Choose a nutrient", and a tap opens the app (Today / My Nutrients): a control can't open its own configuration.
- **The rules are the app's.** Logging goes through `StackLogging` and the same record insert as `LogNutrientIntent`, with the same follow-ups: widget reload and the reminder resync the next time the app runs. A stack with nothing due today logs nothing and says "Nothing due today". A deleted stack or nutrient, or one whose course has ended, no longer resolves through its entity query, so iOS hands the control no pick and it reads "Choose a stack" / "Choose a nutrient" again (seen on the simulator). Between that and a tap, "Removed in nutrx" and "Course ended" cover a pick that's gone, and the tap opens the app (Today for a stack, My Nutrients for a nutrient, where an ended course is under Finished). A stack already logged today reads "Logged today", and a tap opens Today rather than logging it all again: Log again there has Undo, and a control is easy to tap by accident. A nutrient off today under its schedule (#132) reads "Not due today", and a tap opens Today, where a log says it won't count. The words and what a tap does are `ControlText` (pure, tested).
- **Where it runs:** in the widget extension. Each log tap opens its own writable `ModelContainerFactory.createForExtension()` as `LogNutrientIntent` does, never `create()` (CLAUDE.md, iCloud Sync). The app's CloudKit mirroring exports the records the next time it runs, as it does for the widget's +.
- **Free:** the control shows its label with "nutrx Pro", and a tap opens the app on the paywall ("Enjoy nutrx Pro" when the app already knows it's Pro). The control's intent returns `OpenNutrxIntent`, an `OpenIntent` the app performs, which routes like a `nutrx://pro` link. `OpenURLIntent` was the plan, but it takes universal links: with `nutrx://pro` a control opened nothing (phase 2).
- **Entities in the extension:** `StackEntity` and `NutrientEntity` (`Shared/Intents`, app only today) are compiled into the extension too. Their queries keep `@Dependency`: the extension registers a **read-only** `createForExtension(allowsSave: false)` container, opened on first use. They keep the same order and name matching as Siri. The app keeps its own registered container (one store per process). Only the pickers read through it; the log taps write through their own container (above).

## 3. One nutrient widget

`NutrxNutrientWidget`, an `AppIntentConfiguration` with a nutrient parameter (the same `NutrientEntity` query):

- **Small (`systemSmall`):** the nutrient's `ProgressRing` with its symbol, the name, "**2,000** / 4,000 IU" (`GoalProgress`, as Quick log), the status line ("2,000 IU to go", "Done"), and a + button (`LogNutrientIntent`).
  - Not due today under a schedule (#132): "Not today · Next: Sunday", with no +.
  - Its course has ended: "Course ended".
  - Removed: "Removed in nutrx".
- **Lock Screen circular (`accessoryCircular`):** a gauge ring for that nutrient with its symbol, like the Goals widget but for one nutrient. A met goal gets a check.
- **Not configured:** the small size reads "Choose a nutrient", and editing the widget picks one.
- **Tap:** opens that nutrient's analytics (`nutrx://nutrients/<id>`, §5).
- **Free:** the PRO chip, "One nutrient, on your Home Screen", and a tap opens the paywall. The Lock Screen ring shows the nutrx mark.
- **Built (phase 3):** what shows is `NutrientWidgetContent` (pure, tested). As with the controls, a deleted nutrient or an ended course stops resolving through the entity query, so the widget usually reads "Choose a nutrient" again; "Removed in nutrx" and "Course ended" cover a pick that still resolves.

## 4. Supply & courses widget

`NutrxSupplyWidget`, static (nothing to configure). It lists what's running out or ending, soonest first:

- **Supply:** nutrients with supply set and low or out (`SupplySchedule`, the same levels as the Supply card), e.g. "Vitamin D · 6 days left" or "Omega-3 · out".
- **Courses (#99):** running courses within 7 days of their last day, e.g. "Antibiotic · last day" or "Iron · 3 days left" (`CourseText`).
- **Sizes:**

  | Size | Shows |
  |---|---|
  | Small | the soonest two |
  | Medium | up to four, each with its tint tile |
  | Lock Screen rectangular | the soonest one, e.g. "Vitamin D · 6 days" |

- **Nothing due:** "Supply and courses on track", with how many are tracked ("4 bottles, 1 course").
- **Tap:**
  - On the medium size, each row is its own `Link` to that nutrient's analytics.
  - On the small and Lock Screen sizes, the tap opens the first item's analytics, or My Nutrients when nothing is listed.
- **Free:** the PRO chip, "Know when a bottle runs out", and a tap opens the paywall.
- **Ordering** is pure and tested (`SupplyWidgetSummary`): out first, then the fewest days. Supply and courses are interleaved by days left, and a course's last day counts as 0 days.

## 5. Opening the app from them

The widgets already pass `nutrx://today` and the like, but the app has no URL handler, so a tap just opens the app wherever it was. Phase 1 adds one:

- An `onOpenURL` handler goes in `nutrxApp`, and links route through `NotificationRouter`, as notifications do.
- **Links:**
  - `nutrx://today` and `nutrx://nutrients` open those tabs.
  - `nutrx://nutrients/<uuid>` opens that nutrient's analytics, through the same path as a refill reminder, without focusing the Supply card.
  - `nutrx://pro` opens the paywall over Today.
- An unknown link opens Today. The parsing is pure and tested (`AppLink`).
- **`nutrx` is registered as a URL scheme** (`CFBundleURLTypes`). A widget's `widgetURL` and `Link` reach their own app without it. Controls don't use it (they open the app with an `OpenIntent`, §2), but registering it lets `xcrun simctl openurl` test the links. Other apps could open these links too, which only opens a screen.

## 6. Build phases (one PR each, in order)

1. **Groundwork:**
   - the `AppLink` router and `onOpenURL`;
   - `StackEntity` / `NutrientEntity` queries that work in the widget extension (compiled into it, with the extension
     registering its own read-only `createForExtension(allowsSave: false)` container as their `@Dependency`);
   - the `nutrx` URL scheme, tried with `simctl openurl` and a control's `OpenURLIntent`;
   - the Debug `nutrx.debug.widgetsPro` switch (see "Checking widgets and controls" below);
   - tests.
2. **Controls:** Log stack and Log nutrient, with the free variant.
3. **One nutrient widget:** small and the Lock Screen ring.
4. **Supply & courses widget:** `SupplyWidgetSummary` (pure, tested), then small, medium and Lock Screen rectangular.
5. **Shipping:**
   - a new `ProFeature` row, "Widgets and controls" ("Log from Control Center and the Home Screen", `square.grid.2x2`). It's the eighth, so the App Store paywall screenshot (#272) gets retaken with `-screenshotRoute paywall`;
   - a 2.5 What's New item;
   - CHANGELOG, ROADMAP, CLAUDE.md (Widgets section).

Each phase comes with screenshots in its PR: the Home Screen, the Lock Screen and Control Center on nutrx iPhone 17, light and dark, free and Pro.

**Checking widgets and controls:** Lock Screen widgets render transparent in previews (CLAUDE.md, Widgets), so they're checked on a simulator's Lock Screen. Controls are added through Control Center's edit mode. Whether the extension sees the simulator's StoreKit test purchases varies (on iOS 27.0 it saw the app's), so for simulator checks Debug builds of the extension read the App Group default `nutrx.debug.widgetsPro` (phase 1, three states since phase 2; never in Release): YES is Pro, NO is free, unset leaves it to StoreKit. It goes into the App Group container's own plist, not the simulator-wide one: `xcrun simctl spawn <UDID> defaults write "$(xcrun simctl get_app_container <UDID> nutrx-labs.nutrx group.nutrx-labs.nutrx)/Library/Preferences/group.nutrx-labs.nutrx" nutrx.debug.widgetsPro -bool YES`. Each phase's PR says which was checked where.
