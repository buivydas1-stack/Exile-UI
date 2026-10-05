# PoE2 Item Info: map items

Checked 2026-10-05 against public patch **0.5.5d**. The pinned RePoE export is
**4.5.5.2**, commit `b818b843337cae43b090b272fd98bbc0fd3a34f3`; these version
numbers belong to different systems.

Tablets show explicit modifier lines with copied numeric ranges. Implicits,
remaining uses and fixed/unscalable lines are excluded. The last copied endpoint
is perfect, including reversed and negative ranges. White means exactly perfect;
green starts at 67% of the span; yellow covers lower rolls.

Waystones show Item Rarity, Pack Size, Monster Rarity, Monster Effectiveness
and Waystone Drop Chance from the copied header. Each row starts at zero. WDC uses a fixed 170% ordinary-affix ceiling for every Waystone; the other
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

| Reward | Ordinary affixes + corruption | Including one Desecrated affix |
|---|---:|---:|
| Item Rarity | 112% | 145% |
| Pack Size | 65% | 80% |
| Monster Rarity | 103% | 103% |
| Monster Effectiveness | 86% | 86% |
| Waystone Drop Chance (eight slots) | 170% | 190% |

These are global ceilings across Waystone tiers, not a separate maximum for
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

## Fixed WDC display

The owner selected a fixed **170% ordinary-affix maximum** on 2026-10-05.
Every Waystone uses this same display range, regardless of tier, modifier count,
corruption or Desecration. The table above records theoretical pool bounds;
190% includes the special Desecrated case and is not the selected UI maximum.
The WDC display is an ordinary-affix reference, not a claim that 170% is the
absolute ceiling for all possible Waystones.

Values above 170% preserve the actual copied value and fill the bar without
being marked perfect. The 190% case is covered by the functional checks.
Other reward rows and PoE1 behavior are unchanged.

Future updates should check the released patch, reward stats, groups and
Desecration/corruption rules before changing the five constants in
`Iteminfo_WaystoneRewards`. Clipboard numeric ranges remain authoritative for
tablets and require no static tablet-affix database.