# Tablet exclusions in the PoE2 market

Open the Exile-UI menu by holding Esc, click the cog, then choose **Search-strings**. Under **Tablet exclusions**, enter one modifier search phrase per line and click **Save Tablet exclusions**. The enable switch and phrases persist in `ini 2/market-tablets.ini`.

With **Item Category: Tablet** selected in the market, hold Omni for 0.2 seconds. The automation starts while the key is still held, confirms Tablet, creates a NOT group, and adds the saved exclusions. It runs once per press and leaves the Search button for you to press. Short Omni presses retain their existing behavior.

An already clean, compact Tablet form keeps its selected category. Clear Filters and Tablet reselection are used only when extra filters, enabled sections, or an unfamiliar form need a reset. If Tablet cannot be confirmed, the automation stops before clearing. It can dismiss open dropdowns, scroll to the category, and expand Type Filters to read it.

Each phrase must return exactly one modifier. Up to six additions use quick image checks for the moving Add Stat Filter control and the single-result dropdown, followed by one OCR scan to verify the selected batch. Further additions reuse the preceding verified scan and scroll only when the add controls are out of view. Both dropdown directions are checked; wheel input stays in the left filter pane until the game has consumed it.

Group creation scans only the condition menu and new group, with a full-panel fallback if either is unreadable. Click pauses are 20 ms; pasting waits 5 ms after selecting the input and 30 ms after pasting. Image checks retry more frequently while keeping their previous overall wait allowance. Batch verification reads the selected text column, so a missing italic Explicit prefix on the Gold modifier does not discard that row. A failed check reports the unread row count or modifier number.

Zero results, multiple results, duplicate selections, a changed market layout, or failed verification stop the run. Inspect any partially completed form before searching. Press Esc or switch windows to stop.

The initial phrases are:

```text
expl map % azmer spirits
a sp contains # map
#% gold map ex
expl map #% shr
```

This module uses the existing image-search engine, native Windows OCR worker, clipboard handling, and INI settings. English OCR and keyboard Omni are required. The original implementation was validated live at 2560×1440 with ten exclusions, scrolling, existing filters, and ambiguous searches. The user confirmed that the corrected four-modifier batch, 0.2-second hold trigger, settings Save button, Item Info display, and a six-exclusion list work. The faster six-modifier batch passed 81 automated checks and both script compilations; the user confirmed it works in the active installation. Other resolutions use client-height scaling; their live layout remains unverified. PoE1 is unaffected.

Run the focused checks with `tests/Test-MarketTablets.ps1`. They cover category confirmation, conditional resets, batching, lowest-control image lookup, dropdown boundaries, clipped modifier verification, Omni routing, cancellation, and settings persistence.
