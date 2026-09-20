# Rune Ninja skill rewards (PoE2)

Rows explicitly containing `Skill Level N: Name` get a background official-trade lookup in the overlay's selected league. Level-less skills and support rewards are not guessed. The ordinary currency/exchange path is unchanged.

Queries request online, uncorrupted, zero-quality gems of the exact level. These are asking prices, not completed sales. The first ten cheapest listings are sampled; repeated sellers are counted once. At least five distinct sellers in one supported currency are required. The median in that currency is displayed as `~12.0 ex`, `~1.0 div`, or `~5.0 c`. Currencies are not converted or mixed. Gem estimates are not green highest-value recommendations. Socket counts are not inferred from reward text; searches do not constrain them.

`low data` means the sample is too sparse; `no listings`, `unavailable`, and `rate limited` remain explicit. A whole screen can take a few minutes to populate. Requests are sequential, at least twelve seconds apart, and honor Retry-After and IP limit windows. Results are cached in memory for fifteen minutes per league/name/level. New searches pause while the panel is closed; obsolete queued rows are skipped. No login cookies are read or stored.

Run `tests/Test-RuneshapeGems.ps1` for isolated parser, query and estimator checks. Compile both overlay scripts after changes. A public API search/fetch was also verified through the asynchronous AutoHotkey pipeline; in-game OCR/layout still requires observation on the reward panel.
