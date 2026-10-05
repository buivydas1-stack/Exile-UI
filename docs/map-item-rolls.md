# PoE2 Item Info: map items

Checked 2026-10-05 against public patch **0.5.5d**. The pinned RePoE export is
**4.5.5.2**, commit `b818b843337cae43b090b272fd98bbc0fd3a34f3`; these version
numbers belong to different systems.

Tablets show explicit modifier lines with copied numeric ranges. Implicits,
remaining uses and fixed/unscalable lines are excluded. The last copied endpoint
is perfect, including reversed and negative ranges. White means exactly perfect;
green starts at 67% of the span; yellow covers lower rolls.

Waystones show Item Rarity, Pack Size, Monster Rarity, Monster Effectiveness
and Waystone Drop Chance from the copied header. Each row starts at zero. WDC
uses a tier- and affix-count-specific pool bound as described below; the other
four rewards retain their independent global ceilings. Harmful affixes remain in Map Info. Equipment parsing, settings
and colours are unchanged. Both panels can coexist, with Map Info in the left
column; this also applies after its modifier rankings redraw the panel.

## Reward ceiling calculation

These are **derived affix-pool ceilings**, not separately verified in-game drops.
Use up to eight affixes, one ordinary modifier per mutually exclusive group,
and at most one special Desecrated modifier. Do not impose the ordinary three
prefix/three suffix limit on Vaal outcomes. Treat prefix/suffix allocation as
unrestricted within the eight-affix cap for the corruption pool bound; the
maxima below need no more than five of either type. The official notes establish
the eight-mod total cap, but do not specify the complete distribution rules.
This calculation does not establish every outcome's
crafting probability or prove that each maximizing combination is obtainable.

| Reward | Ordinary affixes + corruption | Including one Desecrated affix (used by UI) |
|---|---:|---:|
| Item Rarity | 112% | 145% |
| Pack Size | 65% | 80% |
| Monster Rarity | 103% | 103% |
| Monster Effectiveness | 86% | 86% |
| Waystone Drop Chance (eight slots) | 170% | 190% |

Except for WDC, these are global ceilings across Waystone tiers, not a separate maximum for
each tier, rarity or actual set of affixes. They exclude Atlas, tablets, area
corruption and other bonuses applied when opening a map, and do not rate
enchantment bonuses separately. One stone need not reach all five ceilings.
Copied values above a ceiling retain their actual text and fill the bar, but
are not labelled perfect; the ceiling must then be reviewed.

Maximizing contributors in the current pool:

- **Item Rarity 145:** of Deceleration 45 + Penetrating 16 + Profane 15 +
  of Smothering 15 + Frostbitten 14 + of the Prism 14 + of Buffering 13 +
  of Erosion 13.
- **Pack Size 80:** of Grasping 22 + of Exposure 10 + Fleeting 9 +
  Destructive 9 + Thunderous 8 + of Slowing 8 + Venomous 7 + of Drought 7.
- **Monster Rarity 103:** Painful 25 + Tough 23 + Shattering 19 +
  of Enduring 18 + of Obstruction 18.
- **Monster Effectiveness 86:** Infernal 16 + of Enfeebling 16 +
  Flaming (of Flames at low tiers) 15 + Puncturing 13 + Impacting 13 +
  of the Unwavering 13. These occupy six separate groups, with three prefixes
  and three suffixes; no exported Desecrated affix adds this reward stat.
- **Waystone Drop Chance 190:** of Cycling 40 + Fleeting 25 + of Exposure 25 +
  Painful 20 + Penetrating 20 + of Erosion 20 + of Enfeebling 20 + of Slowing 20.

The owner's Cabal Navigation clipboard independently matches the fixed
ordinary-affix contributions: rarity 15, pack size 9+7+8=24, monster rarity
23+18=41, effectiveness 13, drop chance 15+10+10+15+20+10+20=100. Changing a
harmful numeric
roll within the same affix does not change these fixed reward contributions.

Monster Effectiveness raises monster toughness as well as experience and item
quantity rewards. It is evaluated as its own header value; it is not added to
Item Rarity, Pack Size or Monster Rarity. The owner’s Secluded Expedition
screenshot supplies a second header check: effectiveness 16+13=29, with
rarity 25, pack size 7, monster rarity 43 and drop chance 105.

Sources:

- [PoE2DB Monster Effectiveness](https://poe2db.tw/us/Monster_Effectiveness):
  toughness, experience and item quantity effects.
- [GGG 0.3.0 patch notes](https://www.pathofexile.com/forum/view-thread/3826682):
  reward-bearing affix rework, Well of Souls waystone support and eight-modifier
  corruption limit.
- [PoE2DB Waystone records](https://poe2db.tw/us/Waystones#WaystonesMods) and
  [Desecrated Waystone records](https://poe2db.tw/us/Waystones#DesecratedWaystoneMods):
  current reward stat values, cross-checked against the pinned export.
- [Pinned RePoE mods](https://github.com/repoe-fork/poe2/blob/b818b843337cae43b090b272fd98bbc0fd3a34f3/data/mods.json):
  exact ordinary base-tag eligibility and mutually exclusive groups.
- [GGG 0.5.5c](https://www.pathofexile.com/forum/view-thread/4006357) and
  [0.5.5d](https://www.pathofexile.com/forum/view-thread/4008534): no relevant
  modifier-range changes after the pinned export date.
- [Wiki corruption rules](https://www.poe2wiki.net/wiki/Corrupted): ordinary
  affix limits can be bypassed; the additional-mod outcome retains existing
  prefixes/suffixes and adds zero to four modifiers up to the eight-mod cap.
  This is secondary mechanics evidence, separate from GGG's documented cap.

## WDC pool and item-state handling

`data/global/waystone wdc 2.json` is generated by
`tools/Export-WaystoneWdc.ps1 -SnapshotDirectory <pinned RePoE data directory>`.
It contains only area/Desecrated prefix or suffix records with positive ordered
spawn weights for the applicable Waystone base tags, excluding essence-only
records. First matching tag wins, including a zero weight. Unique generation
records are excluded even when their reward stats are present in the export.
The source master ref was checked on 2026-10-05 and still matched the pinned
commit above. This does not map the internal export number to the public patch.

The runtime maximizes WDC across mutually exclusive groups, with at most one
Desecrated affix. Normal stones retain the three-prefix/three-suffix constraint;
corrupted stones use the eight-slot pool bound described above. Advanced copied
prefix/suffix headers supply the slot count. Special modifier names or a copied
Desecrated marker enable the special pool. Implicit/enchantment blocks do not
consume affix slots. The ceiling compares possible replacements within that
item's tier/count/special class, rather than rating its harmful numeric rolls.

| Ordinary high-tier Waystone | WDC bound |
|---|---:|
| Six mods, uncorrupted (3 prefixes + 3 suffixes) | 130% |
| Seven mods, corrupted | 150% |
| Eight mods, corrupted | 170% |

Those classes permit bounds of 150%, 170% and 190% respectively when one
Desecrated affix is included. In particular, Cycling's 40% has a separate
`MapAbyssDamageCycle` group and a positive map spawn weight: it is not an
ordinary affix, nor is it contradicted by the lack of market listings at 165%.
The ordinary eight-slot witness is Fleeting 25 + Painful 20 + Penetrating 20
+ Exposure 25 + Enfeebling 20 + Slowing 20 + Erosion 20 + Smothering 20.
All eight groups are distinct; replacing a 20% suffix with Cycling yields 190%.
These witnesses establish compatible data combinations, not observed crafts
or a measured rarity. The seven-mod owner fixture itself has four prefixes and
three suffixes, disproving an ordinary three-per-type limit for all corruptions;
it does not independently prove a five-suffix maximizing outcome.

Low/medium tiers exclude their non-prefix Fleeting records and have lower
ordinary pool bounds (six mods: 120%). Missing advanced headers retain the
conservative eight-slot special bound; the UI cannot infer absent item state.
Extra Projectiles/Splitting records have zero eligible spawn weight. The old
`of Giants`/MapWorlds records do not contribute to this Waystone pool. The
current Tough life modifier remains eligible and contributes 15% WDC.

Future updates should check the released patch, reward stats, groups and
Desecration/corruption rules before regenerating WDC data or changing the four
other constants in `Iteminfo_WaystoneRewards`. Clipboard numeric ranges remain authoritative for
tablets and require no static tablet-affix database.
