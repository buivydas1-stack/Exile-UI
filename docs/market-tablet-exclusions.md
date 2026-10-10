# Tablet exclusions in the PoE2 market

Open the Exile-UI menu by holding Esc, click the cog, then choose **Search-strings**. Under **Tablet exclusions**, enter one modifier search phrase per line and click **Save Tablet exclusions**. The enable switch and phrases persist in `ini 2/market-tablets.ini`.

With **Item Category: Tablet** selected in the market, hold Omni for at least half a second and release it. The automation confirms Tablet, creates a NOT group, and adds the saved exclusions. It leaves the Search button for you to press. Short Omni presses retain their existing behavior.

An already clean, compact Tablet form keeps its selected category. Clear Filters and Tablet reselection are used only when extra filters, enabled sections, or an unfamiliar form need a reset. If Tablet cannot be confirmed, the automation stops before clearing. It can dismiss open dropdowns, scroll to the category, and expand Type Filters to read it.

Each phrase must return exactly one modifier. The first four additions use quick image checks for the moving Add Stat Filter control and the single-result dropdown, followed by one OCR scan to verify the selected batch. Further additions reuse the preceding verified scan and scroll only when the add controls are out of view. Both dropdown directions are checked; wheel input stays in the left filter pane until the game has consumed it.

Zero results, multiple results, duplicate selections, a changed market layout, or failed verification stop the run. Inspect any partially completed form before searching. Press Esc or switch windows to stop.

The initial phrases are:

```text
expl map % azmer spirits
a sp contains # map
#% gold map ex
expl map #% shr
```

This module uses the existing image-search engine, native Windows OCR worker, clipboard handling, and INI settings. English OCR and keyboard Omni are required. The original implementation was validated live at 2560×1440 with ten exclusions, scrolling, existing filters, and ambiguous searches. The revised batching and conditional reset have automated checks and screenshot checks; their live verification is pending. Other resolutions use client-height scaling; their live layout remains unverified. PoE1 is unaffected.

Run the focused checks with `tests/Test-MarketTablets.ps1`. They cover category confirmation, conditional resets, batching, lowest-control image lookup, dropdown boundaries, clipped modifier verification, Omni routing, cancellation, and settings persistence.
