param([string]$OutputDirectory = (Join-Path $env:TEMP 'exile-ui-waystone-tests'))
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
function Read-Function([string]$File, [string]$Name) {
    $text = [IO.File]::ReadAllText((Join-Path $root $File))
    $match = [regex]::Match($text, '(?ms)^' + [regex]::Escape($Name) + '\([^\r\n]*\)[^\r\n]*\r?\n\{.*?^\}')
    if (!$match.Success) { throw "Missing function $Name" }
    return $match.Value
}
New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures/waystone-rolls.txt') -Destination $OutputDirectory
$harness = @'
#NoEnv
#NoTrayIcon
#SingleInstance Off
SetBatchLines, -1
global vars := {"poe_version": " 2", "hwnd": {}, "omnikey": {"hotkey": "capslock", "start": A_TickCount - 200}}
global settings := {"features": {"iteminfo": 1, "mapinfo": 1}}, failures := 0, checks := 0, held := 1
FileRead, fixtures, % A_ScriptDir "\waystone-rolls.txt"
counts := [8, 5, 6, 9]
colors := [["FFFFFF", "00FF00", "FFFF00", "FFFFFF", "00FF00", "FFFF00", "FFFF00", "FFFF00"]
, ["FFFF00", "FFFF00", "FFFF00", "FFFF00", "FFFF00"]
, ["FFFF00", "FFFF00", "FFFF00", "FFFF00", "FFFF00", "FFFFFF"]
, ["FFFF00", "FFFF00", "FFFF00", "FFFF00", "FFFF00", "FFFF00", "FFFF00", "FFFF00", "FFFF00"]]
for index, clip in StrSplit(fixtures, "===")
{
    rows := Iteminfo_WaystoneRows(clip)
    Check(rows.Count() = counts[index], "fixture " index " has only ranged modifier lines")
    for j, row in rows
        Check(Iteminfo_WaystoneRoll(row).color = colors[index][j], "fixture " index " row " j " color")
    Check(Iteminfo_WaystoneRows(StrReplace(clip, "`r")).Count() = counts[index], "LF/mixed newline fixture " index)
}
for _, sample in [["67(0-100)", "00FF00"], ["66.99(0-100)", "FFFF00"], ["99.99(0-100)", "00FF00"]
, ["100(0-100)", "FFFFFF"], ["30(35-30)", "FFFFFF"], ["35(35-30)", "FFFF00"]
, ["-6(-8--6)", "FFFFFF"], ["-8(-8--6)", "FFFF00"], ["0.5(0.1-0.5)", "FFFFFF"], ["5(5-5)", "FFFFFF"]]
{
    row := Iteminfo_WaystoneRows("Item Level: 82`n--------`n{ Prefix Modifier }`n" sample.1).1
    Check(Iteminfo_WaystoneRoll(row).color = sample.2, "boundary " sample.1)
}
Check(Iteminfo_WaystoneRows("Item Level: 82`n{ Prefix Modifier }`n12(1-10)% damage").Count() = 0, "out-of-range values are not rated")
Check(Iteminfo_WaystoneRows("Item Level: 82`n--------`nMonsters have 25% more Life").Count() = 0, "plain copy has no fabricated range")
Check(Iteminfo_WaystoneRows("Item Level: 82`n{ Prefix Modifier }`n1(1-2)% damage`n--------`n10(1-10)% footer").Count() = 1, "footer is excluded")
vars.omnikey.item := {"name": "Arcane Path", "itembase": "Waystone", "rarity": "Rare"}
Check(Omni_Context() = "waystoneinfo", "both modules enabled: hold shows roll view")
held := 0
Check(Omni_Context() = "mapinfo", "both enabled: short press preserves Map Info")
held := 1, settings.features.mapinfo := 0
Check(Omni_Context() = "waystoneinfo", "Item Info only: hold shows rolls")
settings.features.iteminfo := 0, settings.features.mapinfo := 1
Check(Omni_Context() = "mapinfo", "Map Info only preserves routing")
settings.features.iteminfo := 1, vars.omnikey.item := {"name": "Rare Quiver", "itembase": "Broadhead Quiver", "rarity": "Rare"}
Check(Omni_Context() = "iteminfo", "equipment routing is unchanged")
vars.poe_version := "", vars.omnikey.item := {"name": "Strand Map", "itembase": "Strand Map", "rarity": "Rare"}
Check(Omni_Context() = "mapinfo", "PoE1 map routing is unchanged")
vars.omnikey.item.itembase := "Waystone"
Check(!Iteminfo_IsWaystone(vars.omnikey.item), "waystone support never applies to PoE1")
bounds := {"x": -2560, "y": 0, "w": 2560, "h": 1440}
for _, cursor in [[-2540, 20], [-1280, 720], [-20, 1420], [-20, 20], [-2540, 1420]]
{
    p := Iteminfo_WaystoneLayout(480, 400, 600, 500, cursor.1, cursor.2, bounds, 14)
    Check(IsObject(p), "panel layout exists")
    Check(p.ix >= bounds.x && p.mx >= bounds.x && p.iy >= 0 && p.my >= 0
    && p.ix + 480 <= 0 && p.mx + 600 <= 0 && p.iy + 400 <= 1440 && p.my + 500 <= 1440, "both panels remain in client bounds")
    Check(p.ix + 480 <= p.mx || p.mx + 600 <= p.ix || p.iy + 400 <= p.my || p.my + 500 <= p.iy, "panels do not overlap")
    id := (p.ix + 240 - cursor.1)**2 + (p.iy + 200 - cursor.2)**2
    md := (p.mx + 300 - cursor.1)**2 + (p.my + 250 - cursor.2)**2
    Check(id < md, "Item Info is closer to cursor")
}
p := Iteminfo_WaystoneLayout(480, 300, 600, 400, 400, 450, {"x": 0, "y": 0, "w": 800, "h": 1000}, 14)
Check(p.iy + 300 <= p.my || p.my + 400 <= p.iy, "narrow clients use vertical stacking")
FileAppend, % failures ? "FAIL: " failures "/" checks " checks`n" : "PASS: " checks " waystone checks`n", *
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
    static translations := {"items_ilevel": "Item Level:", "items_waystone": "Waystone", "items_normal": "Normal", "items_unique": "Unique", "items_gem": "Gem", "items_mapreward": "Map Reward:"}
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
foreach ($name in @('Iteminfo_IsWaystone','Iteminfo_WaystoneRows','Iteminfo_WaystoneRoll','Iteminfo_WaystoneLayout')) {
    $harness += "`r`n" + (Read-Function 'modules/item-checker.ahk' $name)
}
foreach ($name in @('Blank','LLK_PatternMatch','LLK_HasVal','LLK_HasKey')) {
    $harness += "`r`n" + (Read-Function 'modules/_functions.ahk' $name)
}
$harness += "`r`n" + (Read-Function 'modules/omni-key.ahk' 'Omni_Context').Replace('GetKeyState(', 'Test_KeyState(')
$path = Join-Path $OutputDirectory 'waystone-checks.ahk'
[IO.File]::WriteAllText($path, $harness, [Text.UTF8Encoding]::new($true))
$stdout = Join-Path $OutputDirectory 'checks.stdout.txt'
$stderr = Join-Path $OutputDirectory 'checks.stderr.txt'
$process = Start-Process -FilePath 'C:/Program Files/AutoHotkey/AutoHotkey.exe' -ArgumentList @('/ErrorStdOut', ('"' + $path + '"')) -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
Get-Content -LiteralPath $stdout, $stderr
if ($process.ExitCode) { throw "Waystone checks exited $($process.ExitCode)" }
