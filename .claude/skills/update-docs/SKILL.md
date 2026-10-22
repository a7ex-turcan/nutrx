---
name: update-docs
description: >
  Update CHANGELOG.md, ROADMAP.md, and CLAUDE.md to reflect recent changes.
  Use after shipping features, fixes, or improvements — especially before
  or after a version bump. Invoke with /update-docs.
---

# Update Project Documentation

Update the three living documentation files — `CHANGELOG.md`, `ROADMAP.md`, and `CLAUDE.md` — to reflect what has changed since they were last updated.

## Procedure

### 1. Gather context

- Read the current `CHANGELOG.md`, `ROADMAP.md`, and `CLAUDE.md`.
- Run `git log --oneline` to identify commits since the last changelog entry date.
- If the project's `MARKETING_VERSION` has already shipped (it's the last release in the changelog), it moves to the next patch in step 5. That isn't a question for the user, and a "no" below doesn't skip it.
- Otherwise ask the user whether the version should be bumped. If yes, ask which segment (major / minor / patch) or let them specify the new version string. If no, add entries under the existing latest version.

### 2. Update CHANGELOG.md

- If bumping the version, insert a new `## vX.Y — YYYY-MM-DD` section above the previous release. Use today's date.
- Group changes under `### Features`, `### Improvements`, and/or `### Fixes` as appropriate. Only include headings that have entries.
- Each entry is a single bullet: **bold short label** — one-sentence description.
- Keep wording concise and user-facing (describe *what changed for the user*, not implementation details).
- Do not alter existing version sections.

### 3. Update ROADMAP.md

- In the **Feature Tracker** table for the relevant MVP, mark newly shipped items as `✅ Shipped (vX.Y)`.
- If a new feature was shipped that isn't listed in the roadmap, add a row for it in the appropriate MVP section.
- In the detailed section below the tracker, update the status line to `**Status:** Shipped in vX.Y` and collapse lengthy specs into a brief summary if they were previously written as a plan.
- Do not touch sections for future MVPs unless something was explicitly pulled forward or deferred.

### 4. Update CLAUDE.md

- Update the **Project Directory Structure** tree if new files or folders were added.
- Update feature descriptions (Today tab, Nutrients, History, Settings, etc.) to reflect new behaviour, new UI elements, or changed interactions.
- Update the **Data Models** section if fields were added, removed, or changed.
- Do not add implementation details that are better left in code comments — CLAUDE.md describes *what the app does*, not *how the code works*.

### 5. Version bump (when requested, and always right after a release)

- Update `MARKETING_VERSION` in `nutrx.xcodeproj/project.pbxproj`: it appears eight times (Debug and Release for the app, the widgets, the Watch app and its complications), and all of them move together. Use `replace_all`; the test target's own version stays as it is.
- **Right after a release ships**, bump to the next patch in the same PR that dates the changelog, even if nobody asked: Xcode Cloud uploads every push to `main`, and a build with a version that has already shipped is refused and emails the user (CLAUDE.md, under Last release).

### 6. Present a summary

Before committing, show the user a brief summary of what was updated across the three files so they can sanity-check. Wait for confirmation or adjustments before committing.
