#NoEnv
#SingleInstance Force
SetWorkingDir, %A_ScriptDir%\..

global db := {"item_dust": {"Willowgift": 10.5}}
global dust_test_failures := 0
global vars := {"iteminfo": {}}

unique := {"rarity": "unique", "ilvl": 85, "name": "Willowgift", "quality": 0
, "dust_corruption_implicits": 0, "dust_influences": 0, "dust_mods": []}
result := EstimateDust(unique)
DustTest_Near("unique dust", result.value, 26250, 0)
DustTest_Near("unique duration", EstimateDisenchantTime(unique).seconds, 715, 0)

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
