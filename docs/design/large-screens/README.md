# nutrx — large-screen handoff (iPad, iPhone Duo)

The designer's handoff for #130, from the brief of 2026-10-18. It covers layouts by **window width**, not by device: compact under 704 pt (iPhone and the folded Duo, unchanged), regular from 704 to 999 pt (the unfolded Duo, iPad in portrait, half-screen windows), and wide from 1,000 pt (iPad in landscape, 13″, Mac).

- [`LAYOUT.md`](LAYOUT.md): the designer's layout rules, with every width, gutter, cap and switch point. **Build from this.**
- `screens/*.png`: @2x renders in light and dark. **The visual target.** Prefixes: `Today*`, `Nutrients*`, `History*`, `Settings*`, `LogSheet*`, `Duo*` (folded and unfolded, with scroll and sheet continuity), `TodayAX*` (largest text). Suffixes: `L11` / `L13` for 11″ and 13″ iPad in landscape, `P11` for 11″ in portrait, `Duo` for the unfolded Duo, `Empty` for nothing selected.
- `source/*.dc.html`: design-tool source, for reading exact values only. **Never port or ship it.**

The v2 tokens and components don't change ([`../DESIGN.md`](../DESIGN.md)). Only the layout does.

## Where the build differs from the renders

1. **The Stacks tab stays.** The renders' tab bar shows Today, Nutrients and History. nutrx has four tabs (Stacks since 2.1), and every width keeps all four.
2. **No advice in the weekday pattern.** `NutrientsL13` reads "Sundays are your weakest day — a 10:00 reminder on weekends could help." The app keeps its descriptive sentence only ("Sundays are your weakest day."). nutrx never suggests what to do (docs/pro/PLAN.md §0, rule 3).
3. **History's sidebar keeps Recent days and Your data.** The renders' leading pane has only the streak card, Weekly recaps and the calendar. The build keeps today's "Recent days" list and the "Your data" card (export, report for your doctor) below the calendar, scrolling with it, and keeps the toolbar's Your data menu. Dropping them would remove features.
4. **The selected sidebar row's colour becomes a token.** LAYOUT.md calls it the "tab-on tint". In the source it's Forest @ 10% (light) and Green @ 16% (dark). Phase 3 adds it as `Surface/Selected` in `Colors.xcassets` and `Theme`.
5. **Duo specifics wait for the SDK.** The Duo point sizes, the fold at x = 475.5 and the trailing vertical bar come from the designer's Figma kit and aren't confirmed (LAYOUT.md says to check them). Xcode 27.0 has no Duo simulator. The width-based layouts work on the Duo without this. Centring the gutter on the fold, and the folded and unfolded checks, wait for a Duo simulator and the hinge API.

## Build phases (each one PR, tracked in #130)

1. **Width classes and the readable column:** a width-class environment value (compact / regular / wide from the window width), the 640 pt readable column for Settings, Stacks, forms, onboarding and Pro screens, and the log sheet as a centred form sheet from regular widths up (regular and wide).
2. **Today:** two card columns at regular widths, the side column at wide widths (content capped at 1,120 pt), and stacks as tiles.
3. **My Nutrients:** a split view, with a 340 / 380 pt sidebar and analytics capped at 760 pt (heatmap and Supply side by side from 656 pt).
4. **History:** a split view, with the calendar in the sidebar and the day detail capped at 640 pt, plus the "Pick a day" empty state.
5. **Largest text sizes and continuity:** one column from AX1, and the scroll anchor kept when the width class changes.
6. **The Duo**, once its simulator and SDK exist: the gutter on the fold, the trailing bar, and the folded and unfolded checks.
