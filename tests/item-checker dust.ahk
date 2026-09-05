#NoEnv
#SingleInstance Force
SetWorkingDir, %A_ScriptDir%\..

global db := {"item_dust": {"Willowgift": 10.5}, "item_bases": {"_bases": {"Agate Amulet": "1", "Heavy Belt": "5"
, "Haunted Bascinet": "18", "Convoking Wand": "35", "Tomahawk": "3", "Rusted Hatchet": "3", "Crude Bow": "8"
, "Imperial Bow": "8", "Gnarled Branch": "29", "Wyrmbone Rapier": "32", "Corroded Blade": "33"
, "Titanium Spirit Shield": "28", "Archon Kite Shield": "28", "Cedar Tower Shield": "28", "Exhausting Spirit Shield": "28"}}}
global dust_test_failures := 0
global vars := {"iteminfo": {}}

unique := {"rarity": "unique", "ilvl": 85, "name": "Willowgift", "quality": 0
, "dust_corruption_implicits": 0, "dust_influences": 0, "dust_mods": []}
result := EstimateDust(unique)
DustTest_Near("unique dust", result.value, 26250, 0)
DustTest_Near("unique duration", EstimateDisenchantTime(unique).seconds, 715, 0)

jewel_classes := ["Jewels", "Abyss Jewels", "Cluster Jewels", "Charm Jewels", "base jewels"]
For index, class in jewel_classes
{
	jewel := {"class": class, "rarity": "rare", "ilvl": 85, "quality": 0, "dust_corruption_implicits": 0
	, "dust_influences": 0, "dust_mods": [{"level": 72}]}
	result := EstimateDust(jewel)
	DustTest_Equal("jewel unsupported " class, result.supported, 0)
	DustTest_Equal("jewel reason " class, result.reason, "jewels cannot be disenchanted")
}

levels := [72, 23, 23, 21, 1, 81]
expected_dust := [2579, 2821, 3063, 3277, 3363, 7367]
expected_seconds := [425, 510, 595, 680, 765, 850]
mods := []
Loop, 6
{
	index := A_Index
	If (index = 6)
		mods.InsertAt(4, {"level": levels[index]})
	Else mods.Push({"level": levels[index]})
	item := {"rarity": (index <= 2 ? "magic" : "rare"), "ilvl": 83, "quality": 0
	, "dust_corruption_implicits": 0, "dust_influences": 0, "dust_mods": mods.Clone()}
	DustTest_Near("controlled dust " index, EstimateDust(item).value, expected_dust[index], 8)
	DustTest_Near("controlled duration " index, EstimateDisenchantTime(item).seconds, expected_seconds[index], 0)
}

item := {"rarity": "rare", "ilvl": 85, "quality": 0, "dust_corruption_implicits": 0
, "dust_influences": 0, "dust_mods": [{"level": Iteminfo_DustCraftLevel(3)}]}
DustTest_Near("rank-3 craft contribution", EstimateDust(item).value, 2235, 5)

vars.iteminfo.clipboard2 := "|{ Master Crafted Suffix Modifier ""of Craft"" (Rank: 3) - Attack } +261 to Accuracy Rating"
crafted_mods := Iteminfo_DustMods({})
DustTest_Near("crafted mod count", crafted_mods.Count(), 1, 0)
DustTest_Near("crafted mod rank", crafted_mods[1].rank, 3, 0)
DustTest_Near("crafted mod level fallback", crafted_mods[1].level, 68, 0)
DustTest_Near("crafted mod flag", crafted_mods[1].crafted, 1, 0)

base := {"rarity": "rare", "ilvl": 85, "quality": 0, "dust_corruption_implicits": 0
, "dust_influences": 1, "dust_mods": [{"level": 72}]}
quality := base.Clone(), quality.quality := 20
DustTest_Near("quality plus influence", EstimateDust(quality).value / EstimateDust(base).value, 1.9 / 1.5, 0.001)

base.dust_influences := 0
corrupted := base.Clone(), corrupted.dust_corruption_implicits := 1
DustTest_Near("corruption implicit", EstimateDust(corrupted).value / EstimateDust(base).value, 1.5, 0.001)

tier_colors := ["00FF00", "006600", "FFFF00", "FF8000", "FF3333", "990000", "00FFFF"], tier_colors[0] := "3399ff"
hour_color_cases := [[0, "990000", "White"], [40000, "990000", "White"], [49999, "990000", "White"]
, [50000, "FF8000", "Black"], [59999, "FF8000", "Black"], [60000, "00FF00", "Black"]
, [99999, "00FF00", "Black"], [100000, "White", "Black"], [150000, "White", "Black"]]
For index, test in hour_color_cases
{
	color := Iteminfo_DustColor(test[1], tier_colors)
	DustTest_Equal("dust hour color background " index, color.background, test[2])
	DustTest_Equal("dust hour color text " index, color.text, test[3])
}

DustTest_Near("dust per slot", CalculateDustPerSlot(60000, 8), 7500, 0)
slot_cases := [["Agate Amulet", 1], ["Heavy Belt", 2], ["Haunted Bascinet", 4], ["Convoking Wand", 3]
, ["Tomahawk", 6], ["Rusted Hatchet", 3], ["Crude Bow", 6], ["Imperial Bow", 8], ["Gnarled Branch", 4]
, ["Wyrmbone Rapier", 4], ["Corroded Blade", 4], ["Titanium Spirit Shield", 4], ["Archon Kite Shield", 6]
, ["Cedar Tower Shield", 8], ["Exhausting Spirit Shield", 6]]
For index, test in slot_cases
	DustTest_Near("dust slots " test[1], Iteminfo_DustSlots({"itembase": test[1]}), test[2], 0)
DustTest_Near("dust slots unknown", Iteminfo_DustSlots({"itembase": "Unknown Base"}), 0, 0)

duration_cases := [[72, 4, 286], [68, 4, 143], [64, 4, 129], [63, 4, 126], [62, 1, 77], [56, 2, 78], [41, 5, 81]]
For index, test in duration_cases
{
	mods := []
	Loop, % test[2]
		mods.Push({"level": 1})
	item := {"rarity": (test[2] <= 2 ? "magic" : "rare"), "ilvl": test[1], "dust_mods": mods}
	DustTest_Near("duration fixture " index, EstimateDisenchantTime(item).seconds, test[3], 0)
}

If dust_test_failures
{
	FileAppend, % "FAILURES=" dust_test_failures "`n", *
	ExitApp, %dust_test_failures%
}
FileAppend, PASS`n, *
ExitApp, 0

DustTest_Near(label, actual, expected, tolerance)
{
	global dust_test_failures
	If (Abs(actual - expected) <= tolerance)
		Return
	dust_test_failures += 1
	FileAppend, % "FAIL " label ": actual=" actual " expected=" expected " tolerance=" tolerance "`n", *
}

DustTest_Equal(label, actual, expected)
{
	global dust_test_failures
	If (actual = expected)
		Return
	dust_test_failures += 1
	FileAppend, % "FAIL " label ": actual=" actual " expected=" expected "`n", *
}

Lang_Trans(key)
{
	static translations := {"items_normal": "normal", "items_magic": "magic", "items_rare": "rare", "items_unique": "unique"}
	Return translations[key]
}

LLK_PatternMatch(haystack, needle := "", patterns := "", p4 := "", p5 := "", p6 := "")
{
	For index, pattern in patterns
		If (haystack = pattern)
			Return 1
	Return 0
}

IsNumber(value)
{
	Return RegExMatch(value, "^-?(?:\d+\.?\d*|\.\d+)$")
}

DB_Load(name)
{
}

Iteminfo_ModLevel(affix, item)
{
}

#Include %A_ScriptDir%\..\modules\item-checker dust.ahk
