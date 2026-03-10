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
