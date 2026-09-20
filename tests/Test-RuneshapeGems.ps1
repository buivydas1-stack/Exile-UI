param([string]$OutputDirectory = (Join-Path $env:TEMP 'exile-ui-gem-tests'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
$text=[IO.File]::ReadAllText((Join-Path $root 'modules/rune-ninja.ahk'))
$functions=@('Runeshape_GemReward','Runeshape_GemQuery','Runeshape_GemEstimate') | ForEach-Object {
 $m=[regex]::Match($text,'(?ms)^'+$_+'\([^\r\n]*\)\s*\{.*?^\}')
 if(!$m.Success){throw "Missing $_"};$m.Value
}
$harness=@'
#NoEnv
#SingleInstance Off
global failures := 0
For _, name in ["Conductive Runes", "Repulsion", "Frostflame Nova", "Fragments Of The Past", "Eternal March", "Detonate Living"]
{
 gem := Runeshape_GemReward("Skill Level 20: " name)
 Check(gem.level = 20 && gem.name = name, "explicit reward " name)
}
Check(!Runeshape_GemReward("Skill: Repulsion"), "no level not guessed")
Check(!Runeshape_GemReward("Support: Concussive Runes"), "support left alone")
Check(!Runeshape_GemReward("Skill Level 200: Repulsion"), "invalid OCR level rejected")
q := Runeshape_GemQuery({"name":"Repulsion", "level":20})
Check(q.query.filters.misc_filters.filters.gem_level.min = 20 && q.query.filters.misc_filters.filters.gem_level.max = 20, "exact level")
Check(q.query.filters.misc_filters.filters.quality.max = 0 && q.query.filters.misc_filters.filters.corrupted.option = "false", "plain gem variants")
rows := []
For i, amount in [10, 11, 12, 13, 9999]
 rows.Push({"listing":{"account":{"name":"seller" i},"price":{"type":"~price","amount":amount,"currency":"exalted"}}})
Check(Runeshape_GemEstimate(rows) = "~12.0 ex", "median ignores high outlier")
rows.Pop()
Check(Runeshape_GemEstimate(rows) = "low data", "four sellers insufficient")
rows.Push(rows.1)
Check(Runeshape_GemEstimate(rows) = "low data", "duplicate sellers not counted")
rows.Push({"listing":{"account":{"name":"other"},"price":{"type":"~b/o","amount":1,"currency":"divine"}}})
Check(Runeshape_GemEstimate(rows) = "low data", "currencies not mixed")
FileAppend, % failures ? "FAIL " failures "`n" : "PASS: parsing, filters, sparse markets, seller deduplication and median`n", *
ExitApp, % failures
Check(value, name)
{
 global failures
 If !value
 {
  failures++
  FileAppend, % "FAIL: " name "`n", *
 }
}
'@
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$file=Join-Path $OutputDirectory 'test.ahk'
[IO.File]::WriteAllText($file,$harness+"`r`n"+($functions -join "`r`n"),[Text.UTF8Encoding]::new($true))
& 'C:/Program Files/AutoHotkey/AutoHotkey.exe' /ErrorStdOut $file | Write-Output
if($LASTEXITCODE -ne 0){throw 'Gem checks failed'}
