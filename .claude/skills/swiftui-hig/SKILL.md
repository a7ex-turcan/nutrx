---
name: swiftui-hig
description: >
  Apple HIG and SwiftUI best practices for the nutrx iOS app. Use when
  building or reviewing any SwiftUI view — covers native components, SF
  Symbols, typography, spacing, colour, interaction patterns, and
  accessibility basics. The goal is an app that feels like it could ship
  with iOS.
---

# SwiftUI & Apple HIG Guidelines for nutrx

> The visual design (tokens, components, screens) is specified in
> `docs/design/DESIGN.md`, with target renders in `docs/design/screens/`.
> This skill covers *how* to build natively; DESIGN.md covers *what it looks like*.

## Core Principle

Every screen should feel native. If a custom component can be replaced with a
system control, prefer the system control. Users already know how native
components behave — don't make them relearn.

---

## Components — Always Prefer System Controls

| Use case | Use this |
|---|---|
| List of items | `List` |
| Editable form fields | `Form` with `Section` |
| Toggle / boolean input | `Toggle` |
| Numeric stepper | Custom row with − / + buttons (nutrx pattern) or `Stepper` |
| Date / time input | `DatePicker` |
| Bottom sheet | `.sheet` modifier with `presentationDetents` |
| Context options on long press | `.contextMenu` or custom sheet (nutrx uses sheet for Today) |
| Navigation between screens | `NavigationStack` / `NavigationLink` |
| Tab bar | `TabView` with `.tabItem` |
| Confirmation dialogs | `.confirmationDialog` |
| Alerts | `.alert` |
| Loading / progress | `ProgressView` |

---

## SF Symbols — Always Use for Icons

Never use custom image assets where an SF Symbol exists.

```swift
// ✅ CORRECT
Image(systemName: "plus.circle.fill")
Image(systemName: "minus.circle.fill")
Image(systemName: "checkmark.circle.fill")
Image(systemName: "ellipsis.circle")
Image(systemName: "person.crop.circle")
Image(systemName: "clock.arrow.circlepath")
Image(systemName: "chart.bar")

// ❌ WRONG
Image("custom_plus_icon")
```

Apply `.symbolRenderingMode` and `.foregroundStyle` for colour variants.
Use `.imageScale(.large)` / `.imageScale(.small)` to size symbols contextually.

---

## Typography — System Fonts Only

Never hardcode font names or sizes. Always use the Dynamic Type system:

```swift
// ✅ CORRECT
Text("Vitamin D").font(.headline)
Text("1,200 mg").font(.title2.bold())
Text("of 2,000 mg daily").font(.caption).foregroundStyle(.secondary)

// ❌ WRONG
Text("Vitamin D").font(.system(size: 17, weight: .semibold))
```

Common styles in nutrx:
- Nutrient name: `.headline`
- Current intake value: `.title2.bold()`
- Unit / secondary info: `.subheadline` or `.caption` with `.foregroundStyle(.secondary)`
- Section headers in forms: automatic via `Form` + `Section(header:)`

---

## Colour — Brand Tokens + Semantic Colours

nutrx has a brand layer (see `docs/design/DESIGN.md` §1). Colours come from
**named colour sets in the asset catalog** (with Any/Dark appearances),
exposed through `Shared/DesignSystem/Theme.swift`. Never write hex values or
`Color(red:green:blue:)` in view code — reference the token.

```swift
// ✅ CORRECT — brand / semantic tokens
.background(Theme.surfaceGround)          // Surface/Ground
.foregroundStyle(Theme.textSecondary)      // Text/Secondary
.tint(Theme.controlPrimary)
.foregroundStyle(nutrient.tint.color)      // user-chosen nutrient tint
.foregroundStyle(.primary)                 // system semantics still fine for plain text

// ❌ WRONG
.foregroundStyle(Color(hex: "#1B3B2D"))    // hex in a view
.foregroundStyle(.green)                   // ad-hoc status colour — use GoalStatus + Theme
```

Rules:
- `Brand/Green` (#1EB955) is for fills, rings and badges only. Green **text** uses `Text/GreenInk`.
- Status colours come from `GoalStatus` (DESIGN.md §2): met → green check badge, nearing/over a limit → `Status/Amber` ring + `Text/AmberInk` text. Never signal status with colour alone.
- Each nutrient's ring, icon tile and chart use its `NutrientTint`.
- Plain system UI (forms, toolbars, alerts) keeps system semantic colours.

---

## Spacing & Layout

Use SwiftUI's built-in spacing values rather than hardcoded numbers:

```swift
// ✅ CORRECT — uses natural stack spacing
VStack(spacing: 8) { }
HStack(spacing: 16) { }
.padding()             // system default (~16pt)
.padding(.horizontal)
.padding(.vertical, 12)

// ❌ WRONG — arbitrary magic numbers without reason
.padding(.top, 23)
```

Align with iOS standard row height (~44pt touch target minimum for interactive elements).

---

## Interaction Patterns

### Buttons
Use `Button` with a clear label. Destructive actions use `.destructive` role:

```swift
Button("Delete", role: .destructive) { viewModel.delete() }
```

Touch targets should be at least 44×44pt. Use `.contentShape(Rectangle())` if needed to expand a small icon's hit area.

### Tap, long press
On Today, tapping a nutrient card opens the `LogSheet` (exact amount, note,
today's entries); the − / + buttons log one step. Long press shows the
`.contextMenu` (Add Exact Amount, Edit, Move to Group).

### Swipe actions
For lists (My Nutrients, History), use `.swipeActions` — it's the native iOS pattern for list-item actions:

```swift
.swipeActions(edge: .trailing) {
    Button("Delete", role: .destructive) { viewModel.softDelete(nutrient) }
}
```

---

## Sheets & Navigation

- Use `.sheet` for supplementary tasks (edit step, custom amount, new nutrient form).
- Use `NavigationStack` + `NavigationLink` for drill-down (History list → History day detail).
- Use `.presentationDetents([.medium, .large])` for bottom sheets that don't need full screen.
- Use `.presentationDragIndicator(.visible)` on sheets to signal dismissibility.

```swift
.sheet(isPresented: $showEditStep) {
    EditStepSheet(nutrient: nutrient)
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.visible)
}
```

---

## Forms (Nutrient Create / Edit / Profile)

Use `Form` with `Section` to match the Settings-style layout iOS users expect:

```swift
Form {
    Section("Nutrient Details") {
        TextField("Name", text: $name)
        TextField("Unit (e.g. mg, IU)", text: $unit)
    }
    Section("Tracking") {
        TextField("Step", value: $step, format: .number)
        TextField("Daily Target", value: $dailyTarget, format: .number)
    }
}
```

Use `.keyboardType(.decimalPad)` on numeric fields. Use `.onSubmit` or a toolbar Done button to dismiss the keyboard.

---

## Accessibility Basics

- All interactive elements must have `.accessibilityLabel` if the visual label is ambiguous (e.g. icon-only buttons).
- Rings and progress bars: use `.accessibilityValue` to announce current / target values.
- Respect Dynamic Type — never clamp font sizes.
- Support both light and dark mode via the asset-catalog tokens (covered above); check every new view in both.

```swift
Button {
    viewModel.increment(nutrient)
} label: {
    Image(systemName: "plus.circle.fill")
}
.accessibilityLabel("Increase \(nutrient.name)")
```

---

## Animation

Keep animations subtle and purposeful — don't animate for animation's sake.

```swift
// ✅ Progress bar fill change
withAnimation(.easeInOut(duration: 0.2)) {
    progressValue = newValue
}

// ✅ Sheet presentation — handled automatically by SwiftUI

// ❌ Don't add spring animations to every state change
```

Use `.animation(.default, value: someValue)` to scope animations to specific state changes.

---

## What NOT to Do

- ❌ No UIKit (`UIViewController`, `UITableView`, etc.) unless absolutely no SwiftUI equivalent exists.
- ❌ No custom navigation bars built from scratch — use `NavigationStack` + `.toolbar`.
- ❌ No hex colours, font sizes, or spacing/radius magic numbers in view code — use `Theme` tokens (colours, `Theme.Spacing`, `Theme.Radius` from DESIGN.md §1.4) and Dynamic Type styles (numbers: `.fontDesign(.rounded)` + `.monospacedDigit()`).
- ❌ No emoji as UI glyphs (streak = `flame.fill`).
- ❌ No custom tab bar — use SwiftUI `TabView`.
- ❌ No loading spinners for local SwiftData operations (they're synchronous enough).
