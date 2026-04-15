# Changelog

All notable changes to nutrx are documented in this file.

---

## v1.10 — 2026-04-15

### Features
- **Apple Watch companion app** — A focused wrist companion for logging intake. Shows today's active nutrients with goal-type-aware progress bars and a + button on each row to log one step increment. Reads from the same shared SwiftData store as the iPhone app via the existing App Group — no extra setup, data appears automatically.
- **Watch complications** — WidgetKit-based complications for the Watch face: circular ring gauge, corner count, and inline text showing "X / Y on target" at a glance. Refresh after every log tap.

### Improvements
- **Faster first launch on a brand-new install** — Skip the 3-second CloudKit sync wait when the app has never launched on this device before and there's no prior iCloud data to restore. Onboarding appears instantly.

### Fixes
- **Reminder suppression re-firing notifications** — Fixed dose reminders firing again later the same day after being suppressed by a logged intake.
- **History flame badges ignoring goal types** — Fixed the flame streak indicators on History days using minimum-only logic. They now correctly respect each nutrient's goal type (minimum / maximum / range), matching the rest of the app.

---

## v1.9 — 2026-04-03

### Features
- **Nutrient goal types** — Each nutrient can now be configured as "At least" (minimum), "At most" (maximum), or "Between" (range). Progress bars, analytics charts, streaks, and widgets all adapt to the selected goal type.
- **Goal type picker in nutrient form** — Segmented control with plain-English labels, a dynamic caption explaining the behavior, and a live mini progress bar preview so you see the exact colors before saving.
- **Range target fields** — When "Between" is selected, Minimum and Maximum fields appear side by side for quick entry.

### Improvements
- **Gradual color transitions** — Progress bars and chart bars now blend colors smoothly: blue→green for minimum nutrients, orange→red for maximum, and yellow→red when exceeding limits — instead of abrupt color switches.
- **Visible overflow on progress bars** — Maximum and range progress bars scale the limit tick mark to 85% of the bar width, so exceeding the limit is immediately obvious as the fill extends past the mark.
- **Collapsed intake history** — Expanded nutrient cards on Today now show only the 5 most recent entries by default, with a "Show all" link when there are more. Keeps the screen manageable on heavy logging days.

---

## v1.8 — 2026-04-01

### Features
- **Per-nutrient analytics** — Tap any nutrient in My Nutrients to see a dedicated analytics screen with three cards: a daily intake bar chart (7D/30D/90D), period stats (hit rate, daily average, target), and day-of-week patterns (4-week averages with strongest day highlighted).
- **Profile picture** — Set a profile photo from your library or camera in Edit Profile. Your photo appears in the navigation bar across all tabs.

### Improvements
- **Save dismisses profile sheet** — Tapping Save in Edit Profile now closes the sheet immediately instead of showing a toast.
- **Edit button removed from My Nutrients** — Tap navigates to analytics; editing remains available via swipe-left and context menu.

### Fixes
- **Duplicate nutrient reminders** — Fixed multiple notifications firing at the same time for a single reminder. Notification IDs now use the stable nutrient UUID instead of SwiftData's internal identifier, which could change across app launches and CloudKit syncs. Orphaned notifications from the old format are cleaned up automatically.

---

## v1.7 — 2026-04-01

### Features
- **Expandable nutrient cards** — Tap any nutrient card on the Today screen to see a chronological breakdown of every intake logged for that nutrient today, including times, amounts, and notes.
- **Reminders during nutrient creation** — Set dose reminders while creating a new nutrient, making the feature more discoverable. Notification permission is requested gracefully on first use.

### Improvements
- **Log button in expanded cards** — A quick-access + button at the bottom of expanded nutrient cards opens the exact amount sheet, encouraging logging directly from the breakdown view.
- **Nutrient row summary in My Nutrients** — Each nutrient now shows daily target, reminder count, and step increment as three icon-labeled columns for better scannability and reminder discoverability. Nutrient notes are displayed inline next to the name.
- **Keyboard dismiss after onboarding nutrient** — The keyboard now hides after adding a nutrient during onboarding so the Get Started button is visible.
- **Empty group delete confirmation** — Deleting a group with no nutrients now shows a simpler confirmation without mentioning "0 nutrients will be moved".

---

## v1.6 — 2026-03-26

### Features
- **iCloud sync** — Your data now syncs automatically across all your Apple devices via CloudKit. On by default, no setup required. Works offline — sync is additive, never a dependency.
- **New-device restore** — Reinstalling the app or setting up a new device restores all your data from iCloud automatically, skipping onboarding.
- **Sync banners** — One-time banners on the Today screen inform you when data is restored from iCloud or when sync is active on a fresh install.
- **iCloud Sync settings** — New Settings → iCloud Sync page showing sync status, a toggle to enable/disable sync, and a "Delete iCloud Data" option to permanently remove your data from iCloud while keeping local data intact.

### Improvements
- **In-app review prompt** — Automatically invites engaged users to rate the app at natural high points (streak milestones or 30 total intake logs) using Apple's native review dialog. No custom UI — once per version, 90-day cooldown.
- **CloudKit-compatible models** — All data models updated with property-level defaults and optional relationships for CloudKit compatibility.
- **Singleton deduplication** — Automatic deduplication of system records (General group, user profile, preferences) when syncing across multiple devices.
- **Live sync refresh** — Today screen automatically refreshes when CloudKit imports remote data, so changes from other devices appear without switching tabs.
- **Immediate persistence** — Intake records are explicitly saved to disk after every +/− tap, ensuring data survives app termination and reaches CloudKit faster.

### Fixes
- **Data preserved on CloudKit upgrade** — Existing local data is backed up before the first CloudKit-enabled launch and migrated into the new store if needed. Prevents data loss when updating from a pre-sync build (e.g. via TestFlight).
- **Nutrient reordering on tap** — Fixed nutrients shuffling position after tapping +/− by updating totals in-place instead of re-fetching from SwiftData.
- **Stable nutrient sort** — Added tiebreaker to nutrient sorting so items with the same group sort order maintain a consistent position.
- **Notification permission reset after reinstall** — Fixed stale notification flags synced from iCloud causing the daily reminder toggle and banner to show incorrect state after reinstalling the app or setting up a new device.

---

## v1.5 — 2026-03-26

### Features
- **Streaks & consistency tracking** — Track your daily completion streak across Today, History, and widgets. A streak day is any past day where all active nutrients met their targets, respecting exclusions and creation dates.
- **Streak summary in History** — Current streak and best streak shown in a summary card at the top of the History tab, with flame indicators on individual streak days.
- **Streak in widgets** — Small and medium home screen widgets show your current streak count when active.
- **Streaks settings page** — Dedicated Settings → Streaks page with a "Track streaks" toggle (on by default). Designed for future streak-related settings.

### Improvements
- **Tighter Settings layout** — Settings items grouped into fewer sections for a more compact, standard iOS look.
- **Hidden group headers when only General** — If no custom groups are defined, group headers are hidden on Today and My Nutrients for a cleaner, minimal look.

---

## v1.4 — 2026-03-24

### Features
- **Home screen widgets** — Three sizes (small, medium, large) showing your daily nutrient progress with interactive + buttons to log directly from the home screen without opening the app.
- **Lock screen widgets** — Circular ring gauge and inline text widget showing daily completion count at a glance.
- **App Group shared data** — Widgets read from the same SwiftData store as the main app via a shared App Group container. Existing data migrates automatically on first launch.

### Improvements
- **Widget refresh** — Widgets update instantly after logging (via + button or in-app) and on every app foreground.
- **Date in navigation bar** — The Today screen now shows the current date (e.g. "Tuesday, 24 March") instead of a static "Today" title.

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
