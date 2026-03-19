---
name: nutrx-architecture
description: >
  File placement rules, MVVM boundaries, and structural conventions for the
  nutrx iOS project. Use whenever creating a new file, adding a feature, 
  refactoring existing code, or deciding where a new type should live.
---

# nutrx Architecture Rules

## Project Root

All Swift source lives under `nutrx/`. The Xcode project is named `nutrx`.
Bundle ID: `nutrx-labs.nutrx`.

---

## Directory Structure

```
nutrx/
├── nutrxApp.swift          # @main only — bootstraps container, routes to Onboarding or TabView
├── ContentView.swift       # Root switch: OnboardingFlow vs MainTabView
├── App/
│   └── MainTabView.swift   # TabView shell — wires tabs to feature root views
├── Models/                 # SwiftData models ONLY — no UI, no logic
├── Features/               # One subfolder per feature/tab
│   ├── Onboarding/
│   ├── Today/
│   ├── Nutrients/
│   ├── History/
│   └── Profile/
└── Shared/
    ├── Extensions/         # Date, Double, String helpers
    ├── Components/         # Views used in 2+ features
    └── Persistence/        # ModelContainerFactory
```

---

## File Placement — Decision Rules

Apply these in order. The first matching rule wins.

| What you're creating | Where it goes |
|---|---|
| New SwiftData model (`@Model` class) | `Models/` |
| New view used in **one** feature only | `Features/<FeatureName>/Views/` |
| New view used in **two or more** features | `Shared/Components/` |
| New ViewModel | `Features/<FeatureName>/ViewModels/` |
| Date / number / string extension | `Shared/Extensions/` |
| New tab / major feature | New folder under `Features/` with `Views/` and `ViewModels/` subfolders |
| App-wide config or factory | `App/` or `Shared/Persistence/` |

### Hard rules — never break these
- ❌ No files at the root of `Features/` — everything must be inside a named feature folder.
- ❌ No business logic in view files. If a view needs more than layout + user input forwarding, that logic belongs in the ViewModel.
- ❌ No SwiftData models defined outside `Models/`.
- ❌ No inline `ModelContainer` instantiation — always use `ModelContainerFactory`.

---

## MVVM Boundaries

### Views are responsible for:
- Layout and rendering
- Reading from the ViewModel (`@ObservedObject` / `@StateObject`)
- Forwarding user actions to the ViewModel (button taps, text input, etc.)
- Navigation (sheet presentation, NavigationLink)

### Views are NOT responsible for:
- Fetching or filtering data
- Writing to SwiftData directly
- Business rules (e.g. "floor at 0", "soft delete", "reset check")
- Date arithmetic or formatting beyond passing to a helper

### ViewModels are responsible for:
- All SwiftData queries and writes
- Business logic (intake calculation, reset check, exclusion logic, reorder)
- Preparing display-ready state for the view to consume
- Calling `Date+Calendar` and `Double+Formatting` helpers

---

## Feature Anatomy

Every feature folder follows this exact structure — no exceptions:

```
Features/<Name>/
├── Views/
│   └── <Name>View.swift       # Root view for the tab / feature
└── ViewModels/
    └── <Name>ViewModel.swift  # Corresponding ViewModel
```

Additional views for a feature go into `Views/`. Additional ViewModels (rare) go into `ViewModels/`.

---

## Existing Features Reference

| Feature | Root View | ViewModel |
|---|---|---|
| Onboarding | `OnboardingFlow.swift` | `OnboardingViewModel.swift` |
| Today (Tab 1) | `TodayView.swift` | `TodayViewModel.swift` |
| Nutrients (Tab 2) | `NutrientsListView.swift` | `NutrientsViewModel.swift` |
| History (Tab 3) | `HistoryListView.swift` | `HistoryViewModel.swift` |
| Profile (Tab 4) | `ProfileView.swift` | `ProfileViewModel.swift` |

---

## Shared Utilities Reference

| File | Purpose |
|---|---|
| `Date+Calendar.swift` | `isToday`, `isSameDay(_:)`, `startOfDay` — use for all date comparisons |
| `Double+Formatting.swift` | Consistent number display (strip trailing zeros) |
| `PrimaryButton.swift` | Reusable styled button — use in onboarding and forms |
| `ModelContainerFactory.swift` | Single source of truth for SwiftData container setup |

---

## Code Style Rules

- **SwiftUI throughout** — no UIKit unless absolutely unavoidable.
- **Swift concurrency (async/await)** — no Combine, no callbacks, unless SwiftData forces it.
- **SF Symbols** for all icons — no custom image assets for icons.
- **No third-party dependencies** for MVP — Apple frameworks only.
- **Readable over clever** — this codebase is iterated on frequently by Claude Code; optimise for clarity.
- All user-facing strings in **English** — no localisation infrastructure for MVP.

---

## Out of Scope for MVP — Do Not Build or Scaffold

- Push notifications / reminders
- Home screen widgets
- Pro tier / in-app purchase / paywall
- AI features
- Data export
- iCloud sync / CloudKit
