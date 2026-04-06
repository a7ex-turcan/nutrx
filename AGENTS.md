# Repository Guidelines

## Project Structure & Module Organization
`nutrx/` contains the main iOS app. Keep feature code under `nutrx/Features/<Feature>/Views` and `ViewModels`, shared UI in `nutrx/Shared/Components`, services in `nutrx/Shared/Services`, persistence helpers in `nutrx/Shared/Persistence`, and SwiftData models in `nutrx/Models`. `nutrx/nutrxApp.swift`, `nutrx/ContentView.swift`, and `App/MainTabView.swift` bootstrap the app shell. `NutrxWidgets/` contains the widget extension. New files under `nutrx/` are auto-discovered by Xcode, so avoid manual `.pbxproj` edits.

## Build, Test, and Development Commands
Use Xcode 26.3+ for local development.

- `open nutrx.xcodeproj` opens the project in Xcode.
- `xcodebuild -scheme nutrx -configuration Debug -destination 'generic/platform=iOS' build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO` performs a CLI build without signing.
- `xcodebuild test -scheme nutrx -destination 'platform=iOS Simulator,name=iPhone 16'` is the expected simulator test command once a test target exists.

## Coding Style & Naming Conventions
Follow SwiftUI and Swift 5 conventions: 4-space indentation, one top-level type per file, `UpperCamelCase` for types, and `lowerCamelCase` for properties and methods. Use `async`/`await`; avoid Combine unless required. The project defaults to `@MainActor` and enables strict concurrency checking, so keep cross-actor access explicit. Put business logic in view models or services, not SwiftUI view bodies.

## Testing Guidelines
There is no committed XCTest target yet. Add new tests in a dedicated test bundle, preferably mirroring the app structure by feature or service area. Prioritize view-model, SwiftData, and notification behavior over snapshot-heavy UI tests. Name tests by behavior, for example `TodayViewModelTests.swift` with methods like `testIncrementAddsRecord()`.

## Commit & Pull Request Guidelines
Recent commits use short, imperative summaries such as `Add gradual color transitions to progress bars and chart bars`. Keep commits focused and descriptive. Pull requests should include a concise summary, linked issue or roadmap item, screenshots for UI changes, and the device/simulator or command used for verification. Call out schema changes, widget updates, notification behavior, or CloudKit migration risk.

## Data, Sync, and Privacy Rules
This app is privacy-first, offline-first, and intentionally has no ads, analytics, or general backend. CloudKit sync is additive, so SwiftData models must stay CloudKit-safe: use property-level defaults, prefer optional relationship arrays, and avoid `@Attribute(.unique)`. Changes touching `ModelContainerFactory`, widgets, entitlements, notifications, or sync banners should explain migration and fallback behavior in the PR.

## Product Guardrails
Preserve the existing navigation model: Today, My Nutrients, and History are the only tabs; Profile, Settings, and About are accessed via the shared `.withProfileMenu()` flow. Roadmap work currently closest to shipping is in the Pre-Pro sprint: CSV export, quick-log stacks, and Siri/App Shortcuts. Do not introduce paywalls, StoreKit, AI integrations, or raw-data network sync outside explicit MVP 4 work.
