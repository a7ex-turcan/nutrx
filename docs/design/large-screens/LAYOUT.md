# nutrx — large-screen layout rules

The v2 visual system doesn't change: same tokens, cards, rings and radii. Only the layout changes. Every number is in points. Artboards are drawn in points, and `screens@2x/` holds the 2x exports.

## Canvases

| Canvas | Size (pt) | Width class |
|---|---|---|
| iPad 11″ portrait | 834 × 1210 | Regular |
| iPad 11″ landscape | 1210 × 834 | Wide |
| iPad 13″ landscape | 1376 × 1032 | Wide |
| iPhone Duo unfolded (inner, flat) | 951 × 669 | Regular |
| iPhone Duo folded (outer) | 466 × 678 | Compact |

The iPad sizes are the 11″ and 13″ iPad Pro panels (2420 × 1668 and 2752 × 2064 px at 2x).
For the Duo, Apple's HIG says the outer display is compact width and the inner display is regular width, and that toolbars and tab bars sit vertically on the trailing edge on the outer display and on the inner display in landscape. It gives no point sizes. Apple's Design Resources page lists only the Duo bezel and the iOS 27 UI kits. The point sizes here (466 × 678, 951 × 669, fold at x = 475.5, trailing bar inset 84 = 24 + 48 + 12, 20 pt opposite margin) are as reported from the iOS 27 Figma kit 27.1.0. **Check them against Apple's kit before you build.**

## Width classes and where layouts switch

Decide on the **content width** the view gets, not on the device.

- **Compact, under 704 pt of window width:** the iPhone layout, unchanged. On the folded Duo the system moves the tab bar to a vertical glass bar on the trailing edge. That leaves a 362 pt content column, the same width as on iPhone.
- **Regular, 704–999 pt:** two columns of nutrient cards, plus split views.
- **Wide, 1000 pt and up:** the same layouts with more air: 40 pt margins, 20 pt gutters, and Today moves to its side column.

The 704 pt switch comes from the cards themselves. Two columns need at least 2 × 320 + 16 = 656 pt of content, plus 24 pt margins on each side. The 320 pt figure is the narrowest a nutrient card can be with its ring, two-line text and both 44 pt buttons. Below that, use one column.

## Today

- **Regular:** 24 pt margins and a 16 pt gutter. The day-score card, the "Stacks" header and the stacks span both columns at the top. Stack cards become equal-width tiles, 3 per row, instead of a scrolling row. Group headers span both columns. Cards fill in reading order, left to right and then down.
- **Wide (recommended: side column):** the content is capped at **1120 pt** and centred, with margins of at least 40 pt. On the left is a **360 pt** column holding the day-score card and the stacks as a vertical list (the existing one-stack row card). On the right are two card columns, 20 pt gutter between the card columns and 24 pt between the side column and the cards. At 1120 pt each card column is 358 pt.
  - Why it beats the top band: the hero card keeps its iPhone proportions instead of stretching into an empty 1100 pt banner, and the stacks and the score stay visible while you scroll and log. The top-band option is drawn next to it for comparison.
- **Duo unfolded:** the regular layout with the column gutter **centred on the fold**: the columns are 443.5 and 379.5 pt, with a 24 pt gutter. The tab bar is the vertical trailing bar.
- **Logging doesn't change:** +/− on the card, and tapping the card opens the log sheet. On regular and wide widths the sheet is a **centred form sheet**, 540 pt wide, its height capped at 640 pt, with 38 pt corners and a dimmed backdrop. Its header stays horizontal, which matches the Duo rule for centred sheets.

## My Nutrients → analytics (split view)

- **Sidebar:** **340 pt** on regular widths and **380 pt** on wide ones. It shows the current grouped rows without chevrons, and the selected row gets the tab-on tint. On the Duo the sidebar runs to the fold (475.5 pt).
- **Detail:** 24 pt padding on regular widths, 40 pt on wide ones, and content capped at **760 pt**, centred in the detail pane. When the detail is 656 pt or wider, the weekday heatmap and Supply cards sit side by side. Otherwise they stack.
- **Chart:** 170 pt tall, or 240 pt on wide widths. It never goes past the 760 pt cap.
- **Empty state:** a centred icon tile with "Select a nutrient" and one line of text.

## History (split view)

- **Leading pane:** the same sidebar widths and fold rule. It holds the title, the streak card, Weekly recaps and the month calendar. The selected day is a filled Forest dot with a 2 pt halo. Today keeps its outline.
- **Day detail:** capped at **640 pt** and centred. It shows the summary ring card and the goal rows. With no day selected, it shows "Pick a day".

## Everything else: the readable column

Settings, Stacks, forms, onboarding and Pro screens aren't redesigned. Their content sits in **one centred column, at most 640 pt wide**, with margins of at least 24 pt (40 on wide). Toolbars and Done buttons stay at the window edges and aren't capped. On the Duo, Done moves into the vertical trailing toolbar. The Settings artboards carry a 640 pt column guide.

## Largest text sizes

Two-column layouts drop to one column at **AX1** (the first accessibility size), whatever the width. From AX1, Today, the heatmap and Supply pair, and the History detail use the 640 pt readable column. Nutrient cards then stack: the ring and text on top, a full-width −/+ button row below with 64 pt targets. On regular widths under 1000 pt, split views also collapse to a stack from AX1. The tab bar keeps its size and relies on the Large Content Viewer.

## Unfolding mid-task (Duo)

- **Scroll position:** keep the first visible group or card as the anchor (`scrollPosition(id:)`, stored in `@SceneStorage`). After the reflow from one column to two, that same item is at the top.
- **Open log sheet:** it stays open, with the typed amount and the note kept. It turns from a bottom sheet into a centred form sheet, and the background Today screen keeps its scroll anchor.
- Changing from one column to two is the only layout change. No screen swaps tabs or pushes or pops a view when it unfolds.
