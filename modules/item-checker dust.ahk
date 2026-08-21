Iteminfo_DustConstants()
{
	local
	static constants := {"minimum_item_level": 65, "maximum_item_level": 84, "item_level_steps": 20
	, "unique_multiplier": 125, "quality_bonus_per_percent": 0.02
	, "corruption_implicit_bonus": 0.5, "influence_bonus": 0.5
	, "duration_base_units": 4, "duration_unique_units": 8, "duration_unit_floor_seconds": 9
	, "duration_low_level_scale": 0.4, "duration_low_level_offset": 9.5, "duration_ilvl84_unit_seconds": 89.375
	, "mod_value_base": 3.9843314, "mod_value_growth": 1.050192, "mod_value_offset": 0.30418}

	Return constants
}

Iteminfo_DustItemLevelFactor(item_level)
{
	local

	constants := Iteminfo_DustConstants()
	Return Max(1, Min(item_level, constants.maximum_item_level) - constants.minimum_item_level + 1)
}

EstimateDust(item)
{
	local
	global db

	result := {"supported": 0, "approximate": 1, "matched_mods": 0, "unmatched_mods": 0}
	If item.unid
	{
		result.reason := "unidentified"
		Return result
	}
	If (item.rarity = Lang_Trans("items_normal"))
	{
		result.reason := "normal items have no supported dust contribution"
		Return result
	}

	constants := Iteminfo_DustConstants(), item_level_factor := Iteminfo_DustItemLevelFactor(item.ilvl)
	; Items without a quality line leave this field blank, which propagates through AHK v1 arithmetic instead of behaving as zero.
	quality := IsNumber(item.quality) ? item.quality : 0
	increased := 1 + (quality * constants.quality_bonus_per_percent) + (item.dust_corruption_implicits * constants.corruption_implicit_bonus) + (item.dust_influences * constants.influence_bonus)
	If (item.rarity = Lang_Trans("items_unique"))
	{
		If !IsObject(db.item_dust)
			DB_Load("item_dust")
		name := StrReplace(StrReplace(item.name, "foulborn "), "&&", "&")
		If !db.item_dust.HasKey(name)
		{
			result.reason := "unique not present in local dust table"
			Return result
		}
		; In 3.29.3 maximum-rank live samples, unique yield is base * 125 * ilvl-factor. Bonuses are additive.
		result.value := Round(db.item_dust[name] * constants.unique_multiplier * item_level_factor * increased)
		result.supported := 1, result.approximate := 0, result.item_level_factor := item_level_factor
		Return result
	}

	If !LLK_PatternMatch(item.rarity, "", [Lang_Trans("items_magic"), Lang_Trans("items_rare")],,, 0)
	{
		result.reason := "unsupported rarity"
		Return result
	}

	base_value := 0
	For index, mod in item.dust_mods
		If IsNumber(mod.level)
			base_value += Iteminfo_DustModValue(mod.level), result.matched_mods += 1
		Else result.unmatched_mods += 1
	If !result.matched_mods
	{
		result.reason := "no explicit modifiers matched"
		Return result
	}

	; Rare/magic values are additive by modifier generation-level. Rarity itself adds no multiplier.
	result.value := Round(base_value * item_level_factor * increased)
	result.supported := 1, result.item_level_factor := item_level_factor
	Return result
}

EstimateDisenchantTime(item)
{
	local

	; Calibrated from 3.29.3 samples with six maximum-rank workers. Magic/rare duration adds one unit per explicit mod.
	constants := Iteminfo_DustConstants(), unique := (item.rarity = Lang_Trans("items_unique"))
	units := unique ? constants.duration_unique_units : constants.duration_base_units + (IsObject(item.dust_mods) ? item.dust_mods.Count() : 0)
	Return {"seconds": Max(1, Ceil(units * Iteminfo_DisenchantUnitSeconds(item.ilvl))), "units": units, "approximate": 1}
}

Iteminfo_DisenchantUnitSeconds(item_level)
{
	local

	constants := Iteminfo_DustConstants()
	low_level_seconds := Max(constants.duration_unit_floor_seconds, item_level * constants.duration_low_level_scale - constants.duration_low_level_offset)
	high_level_seconds := constants.duration_ilvl84_unit_seconds * Iteminfo_DustItemLevelFactor(item_level) / constants.item_level_steps
	Return Max(low_level_seconds, high_level_seconds)
}

CalculateDustPerHour(dust, seconds)
{
	local

	Return (seconds > 0) ? Round(dust * 3600 / seconds) : 0
}

CalculateDustPerSlot(dust, slots)
{
	local

	Return (slots > 0) ? Round(dust / slots) : 0
}

Iteminfo_DustSlots(item)
{
	local
	global db
	; Inventory cells by item class, with base-specific footprint exceptions from current PoE1 base-item data.
	static default_slots := {1: 1, 2: 1, 3: 6, 4: 8, 5: 2, 6: 6, 7: 4, 8: 8, 9: 4, 10: 3, 11: 3, 12: 2
	, 13: 2, 14: 2, 15: 2, 16: 4, 17: 2, 18: 4, 19: 1, 20: 1, 21: 1, 22: 1, 23: 6, 24: 6
	, 25: 8, 26: 6, 27: 1, 28: 4, 29: 8, 30: 8, 31: 6, 32: 4, 33: 8, 34: 2, 35: 3}
	static three_slot_bases := "|Rusted Hatchet|Ancestral Club|Barbed Club|Driftwood Club|Petrified Club|Spiked Club|Tenderizer|Tribal Club|Driftwood Sceptre|Copper Sword|Corsair Sword|Cutlass|Gemstone Sword|Rusted Sword|Sabre|Variscite Blade|"
	static four_slot_bases := "|Gnarled Branch|Corroded Blade|"
	static short_bows := "|Crude Bow|Ethereal Bow|Grove Bow|Short Bow|Thicket Bow|"

	If !IsObject(item) || !item.itembase || !IsObject(db.item_bases)
		Return 0
	class_id := db.item_bases._bases[item.itembase]
	If !default_slots.HasKey(class_id)
		Return 0

	If InStr(three_slot_bases, "|" item.itembase "|", 0)
		Return 3
	If InStr(four_slot_bases, "|" item.itembase "|", 0)
		Return 4
	If (class_id = 8) && InStr(short_bows, "|" item.itembase "|", 0)
		Return 6
	If (class_id = 28)
	{
		If InStr(item.itembase, "Round Shield") || InStr(item.itembase, "Kite Shield")
			Return 6
		If InStr("|Exhausting Spirit Shield|Subsuming Spirit Shield|Transfer-attuned Spirit Shield|", "|" item.itembase "|", 0)
			Return 6
		If InStr(item.itembase, "Tower Shield")
			Return InStr("|Exothermic Tower Shield|Heat-attuned Tower Shield|Magmatic Tower Shield|", "|" item.itembase "|", 0) ? 6 : 8
	}
	Return default_slots[class_id]
}

Iteminfo_DustColor(value, metric, tier_colors)
{
	local

	thresholds := (metric = "slot") ? [4000, 8000, 20000] : [50000, 60000, 100000]
	If (value < thresholds.1)
		Return {"background": tier_colors.6, "text": "White"}
	If (value < thresholds.2)
		Return {"background": tier_colors.4, "text": "Black"}
	If (value < thresholds.3)
		Return {"background": tier_colors.1, "text": "Black"}
	Return {"background": "White", "text": "Black"}
}

FormatDustPerHour(value)
{
	local

	If (value < 1000)
		Return Round(value)
	If (value < 10000)
		Return RegExReplace(Format("{:0.1f}", value / 1000), "\.0$") "k"
	If (value < 1000000)
		Return Round(value / 1000) "k"
	If (value < 10000000)
		Return RegExReplace(Format("{:0.1f}", value / 1000000), "\.0$") "m"
	Return Round(value / 1000000) "m"
}

Iteminfo_DustModValue(level)
{
	local

	; Live samples show an exponential curve by modifier generation-level, not displayed tier or roll.
	constants := Iteminfo_DustConstants()
	Return constants.mod_value_base * (constants.mod_value_growth ** level) + constants.mod_value_offset
}

Iteminfo_DustCraftLevel(rank)
{
	local

	; Crafting-bench data is not present in item mods.json. This rank fallback is calibrated to the measured rank-3 accuracy craft.
	Return Min(84, Max(1, rank * 24 - 4))
}

Iteminfo_DustMods(item)
{
	local
	global vars

	mods := []
	Loop, Parse, % vars.iteminfo.clipboard2, |
	{
		If !A_LoopField
			Continue
		name := SubStr(A_LoopField, InStr(A_LoopField, """",,, 1) + 1, InStr(A_LoopField, """",,, 2) - InStr(A_LoopField, """",,, 1) - 1)
		crafted := InStr(A_LoopField, "master crafted") ? 1 : 0
		rank := RegExMatch(A_LoopField, "i)\(rank:\s*(\d+)\)", match) ? match1 : ""
		level := Iteminfo_ModLevel(A_LoopField, item)
		If crafted && !IsNumber(level) && IsNumber(rank)
			level := Iteminfo_DustCraftLevel(rank)
		mods.Push({"name": name, "level": level, "crafted": crafted, "rank": rank})
	}
	Return mods
}
