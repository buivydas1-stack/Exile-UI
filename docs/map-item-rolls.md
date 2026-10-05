# PoE2 Item Info: map items

Checked 2026-10-05 against public patch **0.5.5d**. Pinned RePoE export:
**4.5.5.2**, commit `b818b843337cae43b090b272fd98bbc0fd3a34f3`. These are
separate version systems. The relevant released-patch/source checks from the
WDC audit were reused; the complete ordinary reward pool was recalculated.

Tablets show explicit modifier lines with copied numeric ranges. Implicits,
remaining uses and fixed lines are excluded. The last copied endpoint is
perfect, including reversed and negative ranges. Their exact-perfect rule is
unchanged; green starts at 67% of the span and yellow covers lower rolls.

Waystones show five copied header totals. Harmful affixes remain in Map Info.
The owner selected fixed **ordinary-affix reference maxima**, excluding
Desecrated modifiers, Atlas/tablet effects, area bonuses and enchantments.
Every T1-T15 stone uses the eight-mod reference, irrespective of its actual
modifier count or corruption state. T16 uses a fixed six-mod (3 prefix/3 suffix)
reference, also independent of actual modifier count. Missing/unparsed tier
uses the eight-mod reference. There is no rating against the current affixes.

| Reward | T1-T15: eight-mod reference | T16: six-mod reference | Previous special-inclusive bound |
|---|---:|---:|---:|
| Item Rarity | 112% | 87% | 145% |
| Pack Size | 65% | 51% | 80% |
| Monster Rarity | 103% | 103% | 103% |
| Monster Effectiveness | 86% | 86% | 86% |
| Waystone Drop Chance | 170% | 130% | 190% |

At or above the applicable Waystone reference, the bar is full and white.
The actual copied value remains visible, including values above the reference.
This rule applies only to Waystone reward rows, not tablet/equipment rolls.
Green starts at 67%; lower values are yellow. Settings, equipment/PoE1 behavior
and panel layout remain unchanged.

## Calculation and evidence

`tests/Test-WaystoneRewardPool.ps1 -SnapshotDirectory <pinned RePoE data directory>`
checks all 16 exact base tag sets. Ordinary area prefixes/suffixes with a positive
first matching spawn weight are eligible; zero-weight, unique-generation,
essence-only and Desecrated records are excluded. One contributor per mutually
exclusive group is allowed. For eight mods, take the eight strongest compatible
contributions. Six mods allow only the three strongest prefixes and three
strongest suffixes. Conditional generation weights or overlapping/cross-affix
groups fail the audit for manual review rather than silently stacking them.

The T15 and T16 ordinary pools give identical reward totals at equal affix
budgets. The lower T16 reference reflects the selected crafting route, not
weaker affix rewards. Lower tiers have some non-prefix export records: their
actual ordinary pack/WDC bounds are 63/160 for eight mods and 49/120 for six.
The user requested fixed references, so T1-T15 retain the global eight-mod
reference (65/170), rather than adapting per band.

Compatible high-tier eight-mod witnesses (independent per reward):

- **Item Rarity 112:** Penetrating 16 + Smothering 15 + Profane 15 +
  the Prism 14 + Frostbitten 14 + Erosion 13 + Buffering 13 + Fatigue 12.
- **Pack Size 65:** Exposure 10 + Fleeting 9 + Destructive 9 + Slowing 8 +
  Thunderous 8 + Shocking 7 + Drought 7 + Venomous 7.
- **Monster Rarity 103:** Painful 25 + Tough 23 + Shattering 19 +
  Obstruction 18 + Enduring 18.
- **Monster Effectiveness 86:** Infernal 16 + Enfeebling 16 + Flaming 15 +
  Puncturing 13 + Impacting 13 + the Unwavering 13.
- **WDC 170:** Fleeting 25 + Exposure 25 + Painful 20 + Penetrating 20 +
  Erosion 20 + Enfeebling 20 + Slowing 20 + Smothering 20.

These are derived compatible pool bounds, not typical roll values or measured
probabilities. Excluding Desecration does not prove the maximizing ordinary
combination is common. Each reward has its own optimizing combination; one
stone need not achieve every reference. The owner fixtures independently check
copied header totals and ensure explicit harmful rolls are not read as rewards.

The documented tier-up corruption outcome randomizes modifiers and provides
the normal route from T15 to a corrupted T16. The outcome adding extra modifiers
is separate. This supports the owner's six-mod T16 reference. It does not
establish an exhaustive ban on every hypothetical/legacy eight-mod T16. The UI
will safely rate an exceptional value at/above the selected reference as white.

Sources:

- [GGG 0.3.0](https://www.pathofexile.com/forum/view-thread/3826682): reward-bearing
  affix rework and eight-modifier corruption cap.
- [GGG patch index](https://www.pathofexile.com/forum/view-forum/2212) and
  [0.5.5d](https://www.pathofexile.com/forum/view-thread/4008534): released baseline.
- [PoE2DB ordinary Waystone records](https://poe2db.tw/us/Waystones#WaystonesMods):
  reward contributions; [Desecrated records](https://poe2db.tw/us/Waystones#DesecratedWaystoneMods)
  explain the excluded special-inclusive bounds.
- [Pinned RePoE mods](https://github.com/repoe-fork/poe2/blob/b818b843337cae43b090b272fd98bbc0fd3a34f3/data/mods.json)
  and [bases](https://github.com/repoe-fork/poe2/blob/b818b843337cae43b090b272fd98bbc0fd3a34f3/data/base_items.json):
  eligibility, generation types, ordered weights, groups and all 16 base tag sets.
- [Wiki Waystones](https://www.poe2wiki.net/wiki/Waystone) and
  [corruption rules](https://www.poe2wiki.net/wiki/Corrupted): secondary evidence
  for separate tier-change and additional-affix outcomes; T16 tier-up route.

Future updates should verify released changes and pool eligibility before
changing the fixed references in `Iteminfo_WaystoneRewards`. Tablet copied
ranges remain authoritative and require no static tablet-affix database.