param([string]$OutputDirectory = (Join-Path $env:TEMP 'exile-ui-pricing-tests'))
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
function Read-Function([string]$File, [string]$Name) {
    $text = [IO.File]::ReadAllText((Join-Path $root $File))
    $match = [regex]::Match($text, '(?ms)^' + [regex]::Escape($Name) + '\([^\r\n]*\)\s*\{.*?^\}')
    if (!$match.Success) { throw "Missing function $Name" }
    return $match.Value
}
New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
$harness = @'
#NoEnv
#SingleInstance Off
global vars := {"poe_version": " 2"}, failures := 0
for _, example in [[10, 5], [6, 5], [5, 1], [2, 1]]
{
    ok := AsyncTradePriceTarget(example.1, "exalted", 10, amount, currency, error)
    Check(ok && amount = example.2 && currency = "exalted", "low exalt boundary " example.1)
}
AsyncTradePriceTarget(11, "exalted", 10, amount, currency, error)
Check(amount = 10 && currency = "exalted", "above ten keeps percentage step")
Check(AsyncTradeShouldReclaim(" 2", "sell", 1, "exalted"), "one exalt still reclaimed")
Check(!AsyncTradeShouldReclaim(" 2", "sell", 2, "exalted"), "two exalts not reclaimed")
vars.poe_version := ""
AsyncTradePriceTarget(5, "chaos", 10, amount, currency, error)
Check(amount = 4 && currency = "chaos", "PoE1 unaffected")
AsyncTradePriceTarget(5, "alt", 10, amount, currency, error)
Check(amount = 3 && currency = "alt", "PoE1 custom step preserved")
now := A_NowUTC, old := now
EnvAdd, old, -61, minutes
Check(Runeshape_Price(10000, 1, "100, 100", now, "current", "current") = "low vol", "single-unit outlier rejected")
Check(Runeshape_Price(10, 10, "1, 10", now, "current", "current") = 100, "liquid stack priced")
Check(Runeshape_Price(10, 20, "1, 10", now, "current", "current") = "low vol", "stack exceeds observed volume")
Check(Runeshape_Price(10, 1, "1, 100", old, "current", "current") = "???", "stale rejected")
Check(Runeshape_Price(10, 1, "1, 100", now, "old", "current") = "???", "wrong league rejected")
Check(Runeshape_Price(10, 1, "1, ", now, "current", "current") = "???", "missing volume rejected")
Check(Runeshape_Price(0, 1, "0, 100", now, "current", "current") = "???", "zero price rejected")
Check(Runeshape_Price(10, 1, "1, 0", now, "current", "current") = "low vol", "zero volume rejected")
FileAppend, % failures ? "FAIL: " failures " pricing checks`n" : "PASS: 16 pricing checks`n", *
ExitApp, % failures

Check(condition, label)
{
    global failures
    If !condition
    {
        failures++
        FileAppend, % "FAIL: " label "`n", *
    }
}
Economy_Update(type := "", minutes := 60)
{
    Throw Exception("Unexpected network request in pricing unit checks")
}
'@
foreach ($entry in @(
    @('modules/exchange.ahk', 'AsyncTradePriceTarget'),
    @('modules/exchange.ahk', 'AsyncTradePriceStep'),
    @('modules/exchange.ahk', 'AsyncTradeShouldReclaim'),
    @('modules/rune-ninja.ahk', 'Runeshape_Price'),
    @('modules/_functions.ahk', 'LLK_TimeElapsed'),
    @('data/External Functions.ahk', 'IsNumber')
)) { $harness += "`r`n" + (Read-Function $entry[0] $entry[1]) }
$path = Join-Path $OutputDirectory 'pricing.ahk'
[IO.File]::WriteAllText($path, $harness, [Text.UTF8Encoding]::new($true))
& 'C:/Program Files/AutoHotkey/AutoHotkey.exe' /ErrorStdOut $path
if ($LASTEXITCODE) { throw "Pricing checks exited $LASTEXITCODE" }

$cacheHarness = @'
#NoEnv
#SingleInstance Off
global vars, settings, cached, fetches := 0, failures := 0
stamp := A_NowUTC
EnvAdd, stamp, -40, minutes
vars := {"poe_version": " 2", "economy": {}, "stash": {"runes": {"timestamp": stamp, "league": "current"}}, "leagues": {"sc": {"trade": {"rites": "current"}}}}
settings := {"general": {"league": ["sc", "trade", "rites"]}}
cached := {"runes": {"timestamp": stamp, "league": "current", "adept-rune": "1, 20, 0.1"}, "runes names": {"adept-rune": "Adept Rune"}}
Economy_Update("runes")
Check(vars.economy.runes.timestamp = stamp, "source timestamp is not renewed or overwritten by INI metadata")
Check(vars.economy.runes.league = "current" && vars.economy.runes["adept-rune"] = 20, "league and exalt price loaded")
Economy_Update("runes")
Check(fetches = 0, "fresh same-league cache needs no fetch")
vars.economy.runes.league := "old", vars.stash.runes.league := "old"
Economy_Update("runes")
Check(fetches = 1 && vars.economy.runes.timestamp.2 = "failed", "failed refresh cannot reuse wrong-league cache")
Economy_Update("runes")
Check(fetches = 1, "failed requests retain retry backoff")
FileAppend, % failures ? "FAIL: " failures " cache checks`n" : "PASS: 5 cache checks`n", *
ExitApp, % failures
Check(condition, label)
{
    global failures
    If !condition
    {
        failures++
        FileAppend, % "FAIL: " label "`n", *
    }
}
IniBatchRead(file, section)
{
    global cached
    Return cached
}
Stash_PriceFetch(type)
{
    global fetches
    fetches++
    Return 0
}
LLK_ToolTip(args*)
{
}
Lang_Trans(args*)
{
}
LLK_Overlay(args*)
{
}
'@
foreach ($entry in @(
    @('Exile UI.ahk', 'Economy_Update'),
    @('modules/_functions.ahk', 'LLK_TimeElapsed'),
    @('data/External Functions.ahk', 'IsNumber')
)) { $cacheHarness += "`r`n" + (Read-Function $entry[0] $entry[1]) }
$path = Join-Path $OutputDirectory 'cache.ahk'
[IO.File]::WriteAllText($path, $cacheHarness, [Text.UTF8Encoding]::new($true))
& 'C:/Program Files/AutoHotkey/AutoHotkey.exe' /ErrorStdOut $path
if ($LASTEXITCODE) { throw "Cache checks exited $LASTEXITCODE" }
