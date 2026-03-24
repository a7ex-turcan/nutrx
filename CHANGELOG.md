# Changelog

All notable changes to nutrx are documented in this file.

---

## v1.4 — 2026-03-24

### Features
- **Home screen widgets** — Three sizes (small, medium, large) showing your daily nutrient progress with interactive + buttons to log directly from the home screen without opening the app.
- **Lock screen widgets** — Circular ring gauge and inline text widget showing daily completion count at a glance.
- **App Group shared data** — Widgets read from the same SwiftData store as the main app via a shared App Group container. Existing data migrates automatically on first launch.

### Improvements
- **Widget refresh** — Widgets update instantly after logging (via + button or in-app) and on every am m
---

## v1.3 — 2026-03-23

### Improvements
- **Completion count in group headers** — Collapsed and expanded group headers now show how many nutrients have reached their daily target (e.g. "2 / 5").
- **Inline group creation** — Create a new group directly from the nutrient form's group picker without leaving the screen.
- **Haptic feedback** — Subtle haptic feedback on +/− buttons for a more tactile logging experience.
- **Tighter group spacing** — Reduced section spacing between groups on the Today screen for a more compact layout.
- **Notes in reminders** — Nutrient reminders now show the nutrient's note as the notification body when one is set.

### Fixes
- Fixed nutrient reminders not firing due to an async race condition in notification scheduling.
- Fixed decimal input not working on devices with comma decimal separators (e.g. entering "0,5" as a step value).
- Fixed number display truncating to 1 decimal place — now shows up to 2 (e.g. "0.25").

---

## v1.2 — 2026-03-21

### Features
- **Nutrient grouping** — Organise nutrients into named groups (e.g. Vitamins, Supplements). Groups are collapsible on both Today and My Nutrients screens, with an aggregate progress bar shown when collapsed.
- **Manage Groups** — New screen in Settings for creating, renaming, reordering, and deleting groups. A system "General" group is created automatically and cannot be removed.
- **Move to Group** — Long-press any nutrient on Today or My Nutrients to move it to a different group.
- **Group picker on create** — When adding a nutrient from My Nutrients, a group picker lets you assign it to a group right away (defaults to General).

---

## v1.1 — 2026-03-21

### Features
- **Per-nutrient dose reminders** — Set multiple daily reminders per nutrient (e.g. Aspirin at 9 AM, noon, and 8 PM). Smart suppression cancels upcoming reminders after you log intake. Managed via a "Reminders" section in the Edit Nutrient form.
- **Nutrient notes** — Optional free-form text field on each nutrient. Shown as a muted line below the nutrient name on the Today card.
- **History monthly section headers** — Day entries grouped under sticky month headers (e.g. "March, 2026") for easier navigation.
- **Swipe actions on Today** — Swipe right to Add Exact Amount, swipe left to Edit Nutrient.
- **Custom amount notes** — Add an optional note when logging an exact amount. Notes are visible in the History intake detail.
- **Settings page** — New Settings screen (profile menu → Settings) with Notifications toggle and About section.
- **Daily check-in reminder** — Opt-in local notification at noon if no intake logged that day. Smart scheduling adjusts based on whether you've already logged.
- **Notification banner** — Dismissible banner on the Today screen prompting users to enable the daily reminder. Shown once after onboarding.

### Fixes
- Fixed SwiftData migration crash when `hasSeenNotificationBanner` was added to `UserPreferences` without a property-level default.
- Fixed notification permission prompt being swallowed when triggered from within a sheet (two-stage alert approach).
- Fixed reminder list not refreshing after adding a new reminder (switched from relationship reads to `@Query`).
- Fixed reminder count in Edit Nutrient form showing stale values (same `@Query` fix).
- Fixed "Add Reminder" button not visible due to wheel DatePicker taking too much space (switched to compact picker).

---

## v1.0 — 2026-03-20

### Features
- **User onboarding** — Two-step flow: personal info (name, birthday, weight, height) then first nutrient creation.
- **User-defined nutrients** — Create custom nutrients with name, unit, step increment, and daily target. No preset list — fully user-defined.
- **Today tab** — Main daily tracking screen with +/− buttons, progress bars, and long-press context menu (Add Exact Amount, Edit Nutrient, Exclude for Today).
- **My Nutrients tab** — Create, edit, soft-delete, and drag-to-reorder nutrients.
- **History tab** — Read-only chronological log of past days with per-nutrient intake detail.
- **Profile** — Editable user profile accessible via the profile menu.
- **About** — App info, privacy philosophy, and how-it-works overview.
- **Fully offline** — All data stored locally via SwiftData. No accounts, no servers, no telemetry.
