param(
    [string]$SourceRoot = (Split-Path $PSScriptRoot),
    [string]$OutputDirectory = (Join-Path $env:TEMP 'exile-ui-amulet-tests')
)
$ErrorActionPreference = 'Stop'
function Read-Function([string]$File, [string]$Name) {
    $text = [IO.File]::ReadAllText((Join-Path $SourceRoot $File))
    $match = [regex]::Match($text, '(?ms)^' + [regex]::Escape($Name) + '\([^\r\n]*\)[^\r\n]*\r?\n\{.*?^\}')
    if (!$match.Success) { throw "Missing function $Name" }
    return $match.Value
}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
# Game clipboard uses LF within modifier groups and CRLF between groups.
$fixture = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'fixtures/anointed-amulet.txt')).Replace("`r", '').Trim()
$groups = [regex]::Matches($fixture, '(?m)^\{[^\n]*\}\n(?:(?!\{|--------)[^\n]+(?:\n|$))+')
foreach ($group in $groups) { $fixture = $fixture.Replace($group.Value, $group.Value.TrimEnd("`n").Replace("`n", [char]1) + "`n") }
$fixture = $fixture.Replace("`n", "`r`n").Replace([string][char]1, "`n")
[IO.File]::WriteAllText((Join-Path $OutputDirectory 'amulet.txt'), $fixture, [Text.UTF8Encoding]::new($true))
$harness = @'
#NoEnv
#NoTrayIcon
#SingleInstance Off
SetBatchLines, -1
global vars := {"iteminfo": {"item": {}}}, settings := {}, checks := 0, failures := 0
FileRead, clip, % A_ScriptDir "\amulet.txt"
vars.iteminfo.clipboard := StrReplace(clip, " — Unscalable Value")
Iteminfo_Mods2()
parsed := vars.iteminfo.clipboard2
Check(vars.iteminfo.item.ilvl = 81, "item level preserved")
Check(StrSplit(parsed, "|").Count() = 7, "enhancement and all six affixes survive")
for _, stat in ["allocates gem enthusiast", "49(45-50)% increased evasion", "+94(85-99) to maximum life", "+50(47-50) to spirit", "+18(17-18)% to all elemental", "12(10-14)% increased critical", "18(15-18)% increased rarity"]
    Check(InStr(parsed, stat), "preserves " stat)
Check(!InStr(parsed, "+10(7-10)"), "ordinary implicit stays excluded")
vars.iteminfo.clipboard := vars.iteminfo.clipboard "`r`n--------`r`n{ Description }`nShould not become an affix"
Iteminfo_Mods2()
Check(vars.iteminfo.clipboard2 = parsed, "trailing item description stays excluded")
vars.iteminfo.clipboard := RegExReplace(vars.iteminfo.clipboard, "\{ Enhancement \}\n[^\r]+\r\n--------\r\n")
Iteminfo_Mods2()
Check(StrSplit(vars.iteminfo.clipboard2, "|").Count() = 6, "unannointed amulet keeps all six affixes")
vars.iteminfo.clipboard := "Item Level: 81`r`n--------`r`n{ Enhancement }`nAllocates Gem Enthusiast`r`n--------`r`n{ Unique Modifier }`n+100 to maximum Life`r`n--------`r`n{ Description }`nShould not become an affix"
Iteminfo_Mods2()
Check(StrSplit(vars.iteminfo.clipboard2, "|").Count() = 2 && InStr(vars.iteminfo.clipboard2, "+100 to maximum life"), "unique affix retained and description excluded")
FileAppend, % failures ? "FAIL: " failures "/" checks " checks`n" : "PASS: " checks " amulet parser checks`n", *
ExitApp, % failures
Check(condition, label)
{
    global checks, failures
    checks++
    if !condition
    {
        failures++
        FileAppend, % "FAIL: " label "`n", *
    }
}
Lang_Trans(key)
{
    static strings := {"items_ilevel": "Item Level:", "items_implicit": "Implicit Modifier", "items_implicit_corrupt": "Corruption Enhancement", "items_prefix": "Prefix Modifier", "items_suffix": "Suffix Modifier", "items_uniquemod": "Unique Modifier"}
    Return strings[key]
}
'@
foreach ($name in @('LLK_StringCase','LLK_PatternMatch')) { $harness += "`r`n" + (Read-Function 'modules/_functions.ahk' $name) }
$harness += "`r`n" + (Read-Function 'modules/item-checker.ahk' 'Iteminfo_Mods2')
$path = Join-Path $OutputDirectory 'amulet-checks.ahk'
[IO.File]::WriteAllText($path, $harness, [Text.UTF8Encoding]::new($true))
$stdout = Join-Path $OutputDirectory 'checks.stdout.txt'
$stderr = Join-Path $OutputDirectory 'checks.stderr.txt'
$process = Start-Process -FilePath 'C:/Program Files/AutoHotkey/AutoHotkey.exe' -ArgumentList @('/ErrorStdOut', ('"' + $path + '"')) -WorkingDirectory $SourceRoot -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
Get-Content -LiteralPath $stdout,$stderr
if ($process.ExitCode) { throw "Amulet checks exited $($process.ExitCode)" }
