param(
    [string]$SourceRoot = (Split-Path $PSScriptRoot),
    [string]$OutputDirectory = (Join-Path $env:TEMP 'exile-ui-map-ailment-tests')
)
$ErrorActionPreference = 'Stop'
function Read-Function([string]$File, [string]$Name) {
    $text = [IO.File]::ReadAllText((Join-Path $SourceRoot $File))
    $match = [regex]::Match($text, '(?ms)^' + [regex]::Escape($Name) + '\([^\r\n]*\)[^\r\n]*\r?\n\{.*?^\}')
    if (!$match.Success) { throw "Missing function $Name" }
    return $match.Value
}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures/damned-route.txt') -Destination $OutputDirectory
$harness = @'
#NoEnv
#NoTrayIcon
#SingleInstance Off
SetBatchLines, -1
global vars := {"poe_version": " 2", "mapinfo": {}, "omnikey": {"item": {"rarity": "Rare", "unid": 0}}}
global settings := {"general": {"lang_client": "english"}, "mapinfo": {"IDs": {}}}, db := {}, checks := 0, failures := 0, test_clipboard := ""
DB_Load("mapinfo")
for key, mod in db.mapinfo.mods
    settings.mapinfo.IDs[mod.ID] := {"show": 1, "rank": 0}
FileRead, clip, % A_ScriptDir "\damned-route.txt"
test_clipboard := StrReplace(StrReplace(clip,"`r"),"`n","`r`n")
Check(Mapinfo_Parse2(1) = 1, "Damned Route parses")
Check(vars.mapinfo.active_map.mods = 8 && !Row(0), "all eight affixes are recognized")
Check(Row(44) = "ele ailments: +107%", "singular game wording preserves 107 percent")
Check(vars.mapinfo.active_map.rarity = 27 && vars.mapinfo.active_map.packsize = 20 && vars.mapinfo.active_map.waystones = 115, "reward headers remain unchanged")
settings.mapinfo.IDs[44].rank := 3
Mapinfo_Parse2(0)
Check(Row(44,3) = "ele ailments: +107%", "ranking redraw preserves the modifier and value")
settings.mapinfo.IDs[44].rank := 0
test_clipboard := StrReplace(test_clipboard,"Monster have 107","Monsters have 107")
Mapinfo_Parse2(1)
Check(Row(44) = "ele ailments: +107%" && !Row(0), "plural wording still works")
test_clipboard := StrReplace(test_clipboard,"107(100-119)","119(100-119)")
Mapinfo_Parse2(1)
Check(Row(44) = "ele ailments: +119%", "the maximum copied roll is not truncated")
FileAppend, % failures ? "FAIL: " failures "/" checks " checks`n" : "PASS: " checks " Map Info ailment checks`n", *
ExitApp, % failures
Row(id,rank := 0)
{
    global vars
    for _, category in vars.mapinfo.categories
        for _, row in vars.mapinfo.active_map[category][rank]
            if (row.2 + 0 = id)
                Return row.1
}
Check(condition,label)
{
    global checks,failures
    checks++
    if !condition
    {
        failures++
        FileAppend, % "FAIL: " label "`n", *
    }
}
Lang_Trans(key,index := 1)
{
    static strings := {"items_normal": "Normal", "items_unique": "Unique", "items_unidentified": "Unidentified", "items_unscalable": "Unscalable Value", "system_parenthesis": "(", "items_map_revives": "Revives Available:", "items_map_waystonechance": "Waystone Drop Chance:", "items_mapquantity": "Item Quantity:", "items_maprarity": "Item Rarity:", "items_mappacksize": "Pack Size:", "items_ilevel": "Item Level:"}
    Return strings[key]
}
LLK_ToolTip(args*)
{
}
LLK_Overlay(args*)
{
}
Lang_Match(args*)
{
}
Lang_Trim(args*)
{
}
'@
# Exercise the production Map Info database loader branch without unrelated database dependencies.
$loader = [IO.File]::ReadAllText((Join-Path $SourceRoot 'modules/_functions.ahk'))
$match = [regex]::Match($loader, '(?s)Else If \(database = "mapinfo"\)\s*(\{.*?)(?=\s*Else If \(database = "TLDR"\))')
if (!$match.Success) { throw 'Missing Map Info database loader branch' }
$harness += "`r`nDB_Load(database)`r`n{`r`n`tlocal`r`n`tglobal vars, settings, db`r`n" + $match.Groups[1].Value + "`r`n}"
foreach ($name in @('Blank','LLK_FileRead','LLK_StringRemove','LLK_StringCase','LLK_PatternMatch','LLK_HasVal','LLK_IsType','LLK_InStrCount')) {
    $harness += "`r`n" + (Read-Function 'modules/_functions.ahk' $name)
}
$harness += "`r`n" + (Read-Function 'modules/item-checker.ahk' 'Iteminfo_ModRangeRemove')
$harness += "`r`n" + (Read-Function 'modules/map-info.ahk' 'Mapinfo_Lineparse')
$external = [IO.File]::ReadAllText((Join-Path $SourceRoot 'data/External Functions.ahk'))
$harness += "`r`n" + [regex]::Match($external,'(?ms)^IsNumber\(.*?^\}').Value
# Replace only the clipboard input in the extracted parser: no game input or system clipboard changes.
$parser = (Read-Function 'modules/map-info.ahk' 'Mapinfo_Parse2').Replace('global vars, settings, db','global vars, settings, db, test_clipboard').Replace('Clipboard','test_clipboard')
$harness += "`r`n" + $parser
$path = Join-Path $OutputDirectory 'map-ailment-checks.ahk'
[IO.File]::WriteAllText($path,$harness,[Text.UTF8Encoding]::new($true))
$stdout = Join-Path $OutputDirectory 'checks.stdout.txt'
$stderr = Join-Path $OutputDirectory 'checks.stderr.txt'
$process = Start-Process -FilePath 'C:/Program Files/AutoHotkey/AutoHotkey.exe' -ArgumentList @('/ErrorStdOut',('"'+$path+'"')) -WorkingDirectory $SourceRoot -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
Get-Content -LiteralPath $stdout,$stderr
if ($process.ExitCode) { throw "Map Info ailment checks exited $($process.ExitCode)" }
