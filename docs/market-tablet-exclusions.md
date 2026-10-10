# Tablet exclusions in the PoE2 market

Open the Exile-UI menu by holding Esc, click the cog, then choose **Search-strings**. Under **Tablet exclusions**, enter one modifier search phrase per line and click **Save Tablet exclusions**. The enable switch and phrases persist in `ini 2/market-tablets.ini`.

With **Item Category: Tablet** selected in the market, hold Omni for at least half a second and release it. The automation confirms Tablet, clears the form, restores Tablet, creates a NOT group, and adds the saved exclusions. It leaves the Search button for you to press. Short Omni presses retain their existing behavior.

The reset is deliberate: collapsed or disabled sections can retain filters that an initial screenshot cannot prove empty. If Tablet cannot be confirmed, the automation stops before clearing. It can dismiss open dropdowns, scroll to the category, and expand Type Filters to read it.

Each phrase must return exactly one modifier. Zero results, multiple results, duplicate selections, a changed market layout, or failed OCR stop the run with the affected modifier number. Inspect any partially completed form before searching. Press Esc or switch windows to stop. Long lists are handled by locating the lowest Add Stat Filter control again after scrolling; clicks do not depend on a fixed row count. Both dropdown directions are checked.

The initial phrases are:

```text
expl map % azmer spirits
a sp contains # map
#% gold map ex
expl map #% shr
```

This module uses the existing image-search engine, native Windows OCR worker, clipboard handling, and INI settings. English OCR and keyboard Omni are required. Live validation used the supplied 2560×1440 market layout, including ten exclusions, scrolling, existing filters, and ambiguous searches. Other resolutions use the existing client-height scaling; their live layout remains unverified. PoE1 is unaffected.

Run the focused checks with `tests/Test-MarketTablets.ps1`. They cover category confirmation, unselected category text, dropdown boundaries, clipped modifier verification, Omni routing, cancellation, and settings persistence.
