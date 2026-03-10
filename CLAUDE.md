# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Nutrx** is a native iOS/iPadOS SwiftUI application. Bundle ID: `nutrx-labs.nutrx`.

- **Language**: Swift 5.0
- **UI Framework**: SwiftUI
- **iOS Deployment Target**: 26.2
- **Built with**: Xcode 26.3

## Build & Run

Open in Xcode:
```bash
open nutrx.xcodeproj
```

Build from command line:
```bash
xcodebuild -scheme nutrx -configuration Debug
xcodebuild -scheme nutrx -configuration Release
```

Run tests:
```bash
xcodebuild test -scheme nutrx -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Architecture

Standard SwiftUI app structure:

- **`nutrx/nutrxApp.swift`** — `@main` entry point, defines the root `WindowGroup` scene
- **`nutrx/ContentView.swift`** — Root view rendered into the window
- **`nutrx/Assets.xcassets/`** — App icon, accent color, and other asset catalogs

## Swift Configuration

Notable build settings in the Xcode project:
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — All types default to `@MainActor`
- `SWIFT_APPROACHABLE_CONCURRENCY = YES` — Strict concurrency checking enabled
- SwiftUI previews enabled (`ENABLE_PREVIEWS = YES`)


## What is this app?

nutrx is a privacy-first iOS app for tracking daily nutrient intake.
It is intentionally simple, flexible, and fully offline — no accounts, no servers, no ads.
A Pro plan is planned for the future but will only gate AI-powered extras;
all core tracking features remain free forever.

---

## Core Philosophy

- **Private by design** – all data lives exclusively on the user's device (SwiftData). Nothing is ever sent to an external server. There is no backend, no analytics, no telemetry.
- **User-defined everything** – there is no hardcoded list of nutrients. Users define exactly what they want to track, how it's measured, and in what increments.
- **Zero friction daily use** – logging an intake should take seconds. The UI must prioritise speed and clarity over feature density.
- **Apple-native feel** – follow Apple HIG throughout. Use SF Symbols, system fonts, and native components. Aim for an app that feels like it could ship with iOS.

---

## Platform & Tech Stack

- **Platform:** iOS (native Swift / SwiftUI)
- **Persistence:** SwiftData (Apple's current recommended local persistence layer)
- **Networking:** None — the app is fully offline
- **Minimum iOS target:** Latest stable iOS (always target the most recent release)
- **Bundle ID convention:** com.nutrx.app

---

## App Structure – Tab Navigation

The app has four tabs:

| Tab | Purpose |
|---|---|
| **Today** | The main daily tracking screen |
| **My Nutrients** | Create, edit, delete, and reorder custom nutrients |
| **History** | Browse past daily intake logs |
| **Profile** | View and edit the user's personal info |

---

## Onboarding

Onboarding is **mandatory** on first launch. It must be completed before the user can access the main app. It collects:

- **Name**
- **Date of birth**
- **Current weight** + **unit preference** – the user types their weight and selects their preferred unit (kg or lbs). This preference is stored and used throughout the app wherever weight is displayed.
- **Gender**

After the onboarding, the user is prompted to **create their first nutrient** so the Today screen is never empty on first use. An empty app on first open is a bad experience and must be avoided.

These fields are stored locally (SwiftData) and are editable later from the Profile tab.

---

## Nutrient Configuration

Users create and manage their own nutrients. There is no preset or suggested list — the slate is completely blank.

Each nutrient has:

- **Name** – free text (e.g. "Vitamin D", "Caffeine", "Omega-3")
- **Unit** – user-defined string (e.g. "mg", "g", "IU", "ml", "cups")
- **Step** – the increment used when tapping + or − on the Today screen (e.g. 0.5, 1, 100). Must be a positive number.
- **Daily target** – the goal for the day, expressed in the nutrient's own unit. Shown as the "full" value of the progress bar on the Today screen. Required.

Nutrients can be reordered, edited, and deleted from the **My Nutrients** tab. Order is set by the user via **drag-and-drop** and is fully manual — no automatic sorting. The order defined in My Nutrients is the exact order nutrients appear on the Today screen. It never changes unless the user explicitly reorders them.

---

## Today Tab – Core Logging UX

This is the central feature and main selling point of the app.

Each nutrient is displayed as a **row** containing:
- The nutrient name and unit
- A **progress bar** showing current intake vs. daily target
- A **− button** on the left
- A **+ button** on the right

### Tap behaviour
- Tapping **+** increases the logged intake by the nutrient's configured step amount.
- Tapping **−** decreases the logged intake by the step amount (floor at 0, never go negative).

### Long press on the progress bar
Long pressing the progress bar opens a **context menu / bottom sheet** with the following options:
- **Edit step amount** – opens a small focused sheet showing **only the step field** for that nutrient (not the full edit form). The user updates the value and confirms. The change is permanent and persists going forward. This is intentionally lightweight — the user is mid-logging and should not be taken to the full My Nutrients edit screen.
- **Enter custom amount** – opens a number input; the entered value is **added** to the current intake (not a replacement). e.g. if 200mg is already logged and the user enters 150, the new total is 350mg.
- **Exclude for today** – hides this nutrient from today's view without deleting it (it comes back tomorrow)
- *(further options may be added in future iterations)*

### Visual states
- Progress bar fills as intake approaches the daily target.
- When the target is reached or exceeded, show a distinct visual state (e.g. filled colour, checkmark, or subtle animation).
- Exceeding a target should be allowed and visually indicated (e.g. the bar overflows or changes colour) — some nutrients have soft targets.

---

## Daily Reset Logic

- At **midnight**, all daily intake values reset to 0.
- In practice, the reset is checked **when the app is foregrounded** (not via a background task). If the stored date of the last session is before today's date, trigger the reset.
- Resets are **non-destructive** — before zeroing out, the previous day's data is saved to the History store.
- If a nutrient is marked "excluded for today", that exclusion is also reset at midnight (the nutrient reappears the next day by default).

---

## History Tab

- Displays a **chronological list of past days**, most recent first.
- Each entry shows the date and the intake logged for each nutrient that day.
- Read-only — the user cannot edit past entries.
- History is stored locally via SwiftData and is never deleted automatically.

---

## Monetisation

- The app is **free with no ads**.
- A **Pro tier** is planned for a future release. It will only unlock AI-powered features (e.g. insights, personalised recommendations based on profile data). All tracking features remain free forever.
- Do not build any paywall or in-app purchase infrastructure for the MVP.

---

## Out of Scope for MVP

The following features are explicitly **deferred** and should not be built or scaffolded yet:

- Push notifications / reminders
- Home screen widgets
- Pro / in-app purchase
- AI features
- Data export
- iCloud sync

---

## Code & Architecture Guidelines

- Use **SwiftUI** throughout — no UIKit unless absolutely unavoidable.
- Use **SwiftData** for all persistence (user profile, nutrients, daily logs, history).
- Follow **MVVM** — keep views dumb, push logic into view models or model layer.
- Use **Swift concurrency** (async/await) — no Combine or callbacks unless SwiftData requires it.
- Keep features modular: each tab should live in its own folder/group.
- No third-party dependencies for the MVP — use only Apple frameworks.
- Prefer **SF Symbols** for all icons.
- All user-facing strings should be in English for MVP (no localisation infrastructure needed yet).
- Write code that is **readable over clever** — Claude Code will be iterating on this frequently.
