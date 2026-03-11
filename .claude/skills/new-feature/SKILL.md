---
name: new-feature
description: >
  Scaffolds a new tab or major feature for the nutrx iOS app following the
  established project structure. Invoke with /new-feature when asked to add
  a new tab, a new major screen, or a new independently routed feature.
  Creates the correct folder structure, boilerplate View and ViewModel files,
  and wires up the tab if applicable.
---

# New Feature Scaffold for nutrx

## When to Use This Skill

Use when the task is to create:
- A **new tab** in `MainTabView.swift`
- A **new major feature** with its own root view and view model
- Any independently routed screen that doesn't belong to an existing feature folder

Do **not** use for:
- Adding a new view *inside* an existing feature (just create the file in the right `Views/` folder)
- Adding a shared component used across features (put it in `Shared/Components/`)

---

## Step-by-Step Scaffold Procedure

### 1. Confirm the feature name and tab label

Before creating any files, confirm:
- Feature name (PascalCase, e.g. `Insights`)
- Tab label shown to user (e.g. "Insights")
- SF Symbol name for the tab icon (e.g. `"chart.line.uptrend.xyaxis"`)
- Whether this is a new **tab** or just a new routed feature (no tab icon needed)

---

### 2. Create the folder structure

```
nutrx/Features/<FeatureName>/
├── Views/
│   └── <FeatureName>View.swift
└── ViewModels/
    └── <FeatureName>ViewModel.swift
```

No files should be placed directly at `Features/<FeatureName>/` — only inside `Views/` or `ViewModels/`.

---

### 3. ViewModel boilerplate

```swift
import Foundation
import SwiftData

@MainActor
final class <FeatureName>ViewModel: ObservableObject {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // TODO: add published state and methods
}
```

Rules:
- `@MainActor` — all ViewModels in nutrx run on the main actor.
- `ObservableObject` — consumed by views via `@StateObject` or `@ObservedObject`.
- Receives `ModelContext` via init — never creates its own.
- No UI imports (`SwiftUI`) in the ViewModel unless absolutely necessary.

---

### 4. View boilerplate

```swift
import SwiftUI

struct <FeatureName>View: View {

    @StateObject private var viewModel: <FeatureName>ViewModel

    init(modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: <FeatureName>ViewModel(modelContext: modelContext))
    }

    var body: some View {
        NavigationStack {
            Text("<FeatureName> — coming soon")
                .navigationTitle("<Tab Label>")
        }
    }
}
```

Rules:
- Always wrap in `NavigationStack` so the feature owns its own navigation.
- Use `.navigationTitle` for the screen title.
- Keep the view dumb — all logic goes in the ViewModel.

---

### 5. Wire into MainTabView (if it's a new tab)

Open `nutrx/App/MainTabView.swift` and add a new `tabItem` entry:

```swift
<FeatureName>View(modelContext: modelContext)
    .tabItem {
        Label("<Tab Label>", systemImage: "<sf-symbol-name>")
    }
```

nutrx currently has four tabs in this order:
1. Today — `house` (or similar)
2. My Nutrients — `list.bullet`
3. History — `clock.arrow.circlepath`
4. Profile — `person.crop.circle`

New tabs are appended after Profile unless a specific position is requested.

---

## SF Symbol Suggestions by Feature Type

| Feature | Suggested symbol |
|---|---|
| Insights / analytics | `chart.line.uptrend.xyaxis` |
| Goals | `target` |
| Reminders | `bell` |
| Export | `square.and.arrow.up` |
| Settings | `gearshape` |
| Search | `magnifyingglass` |

---

## Checklist Before Finishing

- [ ] `Features/<FeatureName>/Views/<FeatureName>View.swift` created
- [ ] `Features/<FeatureName>/ViewModels/<FeatureName>ViewModel.swift` created
- [ ] No files placed at the root of `Features/<FeatureName>/`
- [ ] ViewModel receives `ModelContext` via init
- [ ] View wraps content in `NavigationStack`
- [ ] If new tab: `MainTabView.swift` updated with correct `tabItem`
- [ ] SF Symbol used for tab icon (no custom assets)
- [ ] No business logic in the View file
- [ ] No UIKit imports
