param([string]$OutputDirectory = (Join-Path $env:TEMP 'exile-ui-map-item-tests'))
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
function Read-Function([string]$File, [string]$Name) {
    $text = [IO.File]::ReadAllText((Join-Path $root $File))
    $match = [regex]::Match($text, '(?ms)^' + [regex]::Escape($Name) + '\([^\r\n]*\)[^\r\n]*\r?\n\{.*?^\}')
    if (!$match.Success) { throw "Missing function $Name" }
    return $match.Value
}
New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
foreach ($file in @('tablet-rolls.txt','waystone-rewards.txt')) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('fixtures/' + $file)) -Destination $OutputDirectory }
$harness = @'
#NoEnv
#NoTrayIcon
#SingleInstance Off
SetBatchLines, -1
global vars := {"poe_version": " 2", "hwnd": {}, "omnikey": {"hotkey": "capslock", "start": A_TickCount - 200}}
global settings := {"features": {"iteminfo": 1, "mapinfo": 1}}, failures := 0, checks := 0, held := 1
FileRead, fixtures, % A_ScriptDir "\tablet-rolls.txt"
colors := [["FFFF00", "FFFF00", "00FF00", "00FF00"], ["FFFF00", "FFFF00", "FFFF00"]]
for index, clip in StrSplit(fixtures, "===")
{
    rows := Iteminfo_TabletRows(clip)
    Check(rows.Count() = colors[index].Count(), "tablet " index " skips implicits and fixed affixes")
    for j, row in rows
        Check(Iteminfo_MapRoll(row).color = colors[index][j], "tablet " index " row " j " quality")
}
for _, sample in [["67(0-100)", "00FF00"], ["66.99(0-100)", "FFFF00"], ["100(0-100)", "FFFFFF"], ["30(35-30)", "FFFFFF"], ["-6(-8--6)", "FFFFFF"]]
{
    row := Iteminfo_TabletRows("Item Level: 82`n--------`n{ Prefix Modifier }`n" sample.1).1
    Check(Iteminfo_MapRoll(row).color = sample.2, "boundary " sample.1)
}
FileRead, clip, % A_ScriptDir "\waystone-rewards.txt"
rows := Iteminfo_WaystoneRewards(clip), expected := [15,24,41,13,100]
Check(rows.Count() = 5, "waystone has all five reward rows")
for j, row in rows
    Check(row.ranges.1.current = expected[j] && row.ranges.1.first = 0 && !InStr(row.text,"Monsters have"), "waystone header " j " excludes harmful affixes")
Check(rows.4.text = "Monster Effectiveness: +13(0-86)%", "effectiveness uses the copied header and documented ceiling")
Check(Iteminfo_MapRoll(rows.4).color = "FFFF00", "partial effectiveness receives the ordinary reward rating")
for _, sample in [[57, "FFFF00"], [58, "00FF00"], [86, "FFFFFF"], [87, "00FF00"]]
{
    testclip := StrReplace(clip, "Monster Effectiveness: +13%", "Monster Effectiveness: +" sample.1 "%")
    row := Iteminfo_WaystoneRewards(testclip).4
    Check(row.ranges.1.current = sample.1 && Iteminfo_MapRoll(row).color = sample.2, "effectiveness rating boundary " sample.1)
}
testclip := StrReplace(clip, "Monster Effectiveness: +13% (augmented)", "") "`nMonsters have 95% more Effectiveness"
rows := Iteminfo_WaystoneRewards(testclip)
Check(rows.4.ranges.1.current = 0, "missing effectiveness header stays zero instead of reading explicit affixes")
testclip := StrReplace(clip, "Item Rarity: +15%", "Item Rarity: +25%")
testclip := StrReplace(testclip, "Pack Size: +24%", "Pack Size: +7%")
testclip := StrReplace(testclip, "Monster Rarity: +41%", "Monster Rarity: +43%")
testclip := StrReplace(testclip, "Monster Effectiveness: +13%", "Monster Effectiveness: +29%")
testclip := StrReplace(testclip, "Waystone Drop Chance: +100%", "Waystone Drop Chance: +105%")
rows := Iteminfo_WaystoneRewards(testclip), expected := [25,7,43,29,105]
for j, row in rows
    Check(row.ranges.1.current = expected[j], "Secluded Expedition screenshot header " j)
vars.omnikey.item := {"name": "Cabal Navigation", "itembase": "Waystone", "rarity": "Rare"}
Check(Omni_Context() = "mapiteminfo", "both enabled: waystone hold shows both views")
held := 0
Check(Omni_Context() = "mapinfo", "waystone short press preserves Map Info")
held := 1, vars.omnikey.item := {"name": "Void Directive", "class": "Tablet", "itembase": "Abyss Tablet", "rarity": "Rare"}
Check(Omni_Context() = "mapiteminfo", "tablet hold uses ranged affixes")
vars.omnikey.item := {"name": "Rare Quiver", "itembase": "Broadhead Quiver", "rarity": "Rare"}
Check(Omni_Context() = "iteminfo", "equipment routing is unchanged")
vars.poe_version := "", vars.omnikey.item := {"name": "Strand Map", "itembase": "Strand Map", "rarity": "Rare"}
Check(Omni_Context() = "mapinfo", "PoE1 map routing is unchanged")
vars.omnikey.item.itembase := "Waystone"
Check(!Iteminfo_MapItemKind(vars.omnikey.item), "new map-item support applies only to PoE2")
bounds := {"x": -2560, "y": 0, "w": 2560, "h": 1440}
for _, cursor in [[-1280,720],[-2540,20],[-20,1420]]
{
    p := Iteminfo_MapRollLayout(480,200,600,500,cursor.1,cursor.2,bounds,14)
    Check(p.mx + 600 < p.ix && p.ix + 480 <= 0 && p.mx >= bounds.x, "Map Info stays on the left within the client")
}
FileAppend, % failures ? "FAIL: " failures "/" checks " checks`n" : "PASS: " checks " map-item checks`n", *
ExitApp, % failures
Check(condition, label)
{
    global failures, checks
    checks++
    if !condition
    {
        failures++
        FileAppend, % "FAIL: " label "`n", *
    }
}
Lang_Trans(key, index := 1)
{
    static translations := {"items_ilevel": "Item Level:", "items_waystone": "Waystone", "items_prefix": "Prefix Modifier", "items_suffix": "Suffix Modifier", "items_uniquemod": "Unique Modifier", "items_maprarity": "Item Rarity:", "items_mappacksize": "Pack Size:", "items_map_waystonechance": "Waystone Drop Chance:", "items_normal": "Normal", "items_unique": "Unique", "items_gem": "Gem", "items_mapreward": "Map Reward:"}
    Return translations[key]
}
Test_KeyState(key, mode)
{
    global held
    Return held
}
Iteminfo(mode := 0)
{
}
Stash(check)
{
}
'@
foreach ($name in @('Iteminfo_MapItemKind','Iteminfo_TabletRows','Iteminfo_WaystoneRewards','Iteminfo_MapRoll','Iteminfo_MapRollLayout')) {
    $harness += "`r`n" + (Read-Function 'modules/item-checker.ahk' $name)
}
foreach ($name in @('Blank','LLK_PatternMatch','LLK_HasVal','LLK_HasKey')) {
    $harness += "`r`n" + (Read-Function 'modules/_functions.ahk' $name)
}
$harness += "`r`n" + (Read-Function 'modules/omni-key.ahk' 'Omni_Context').Replace('GetKeyState(', 'Test_KeyState(')
$path = Join-Path $OutputDirectory 'map-item-checks.ahk'
[IO.File]::WriteAllText($path, $harness, [Text.UTF8Encoding]::new($true))
$stdout = Join-Path $OutputDirectory 'checks.stdout.txt'
$stderr = Join-Path $OutputDirectory 'checks.stderr.txt'
$process = Start-Process -FilePath 'C:/Program Files/AutoHotkey/AutoHotkey.exe' -ArgumentList @('/ErrorStdOut', ('"' + $path + '"')) -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
Get-Content -LiteralPath $stdout, $stderr
if ($process.ExitCode) { throw "Map-item checks exited $($process.ExitCode)" }
