param([string]$OutputDirectory = (Join-Path $env:TEMP 'exile-ui-one-chaos-tests'))
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
function Read-Function([string]$Name) {
    $text = [IO.File]::ReadAllText((Join-Path $root 'modules/exchange.ahk'))
    $match = [regex]::Match($text, '(?ms)^' + [regex]::Escape($Name) + '\([^\r\n]*\)\s*\{.*?^\}')
    if (!$match.Success) { throw "Missing function $Name" }
    return $match.Value
}
New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
$harness = @'
#NoEnv
#SingleInstance Off
global vars := {"poe_version": " 2", "economy": {}}, failures := 0, checks := 0, fetches := 0
for _, rate in [20, 52, 100]
{
    vars.economy.currency := {"chaos": rate, "exalted": 1}
    for _, minchange in [0, 10, 50]
    {
        ok := AsyncTradePriceTarget(1, "chaos", minchange, amount, currency, error)
        Check(ok && amount = 30 && currency = "exalted" && error = "", "fixed target for ratio " rate " / reduction " minchange)
    }
}
Check(fetches = 0, "fixed price does not refresh economy")
vars.economy := {}
ok := AsyncTradePriceTarget(1, "chaos", 10, amount, currency, error)
Check(ok && amount = 30 && currency = "exalted", "fixed price works without economy cache")
vars.economy.currency := {"timestamp": ["", "failed"], "chaos": 0, "exalted": 0}
ok := AsyncTradePriceTarget(1, "chaos", 10, amount, currency, error)
Check(ok && amount = 30 && currency = "exalted" && fetches = 0, "failed economy cannot block fixed price")
AsyncTradePriceTarget(10, "chaos", 10, amount, currency, error)
Check(amount = 9 && currency = "chaos", "multi-chaos prices keep percentage reduction")
vars.economy.currency := {"divine": 10000, "chaos": 50, "exalted": 1}
AsyncTradePriceTarget(1, "divine", 10, amount, currency, error)
Check(amount = 180 && currency = "chaos" && fetches = 1, "one-divine conversion keeps economy calculation")
AsyncTradePriceTarget(30, "exalted", 10, amount, currency, error)
Check(amount = 27 && currency = "exalted", "subsequent exalt reductions keep percentage step")
Check(AsyncTradeShouldReclaim(" 2", "sell", 1, "exalted"), "one-exalt reclaim remains")
vars.poe_version := ""
AsyncTradePriceTarget(1, "chaos", 10, amount, currency, error)
Check(amount = 5 && currency = "alt" && fetches = 1, "PoE1 one-chaos conversion remains")
FileAppend, % (failures ? "FAIL: " : "PASS: ") checks " one-chaos pricing checks" Chr(10), *
ExitApp, % failures

Check(condition, label)
{
    global failures, checks
    checks++
    If !condition
    {
        failures++
        FileAppend, % "FAIL: " label Chr(10), *
    }
}
Economy_Update(type := "", minutes := 60)
{
    global fetches
    fetches++
}
'@
foreach ($name in @('AsyncTradePriceTarget', 'AsyncTradePriceStep', 'AsyncTradeShouldReclaim')) {
    $harness += [Environment]::NewLine + (Read-Function $name)
}
$path = Join-Path $OutputDirectory 'one-chaos.ahk'
[IO.File]::WriteAllText($path, $harness, [Text.UTF8Encoding]::new($true))
$output = Join-Path $OutputDirectory 'stdout.txt'
$errors = Join-Path $OutputDirectory 'stderr.txt'
$process = Start-Process -FilePath 'C:/Program Files/AutoHotkey/AutoHotkey.exe' -ArgumentList ('/ErrorStdOut "' + $path + '"') -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput $output -RedirectStandardError $errors
Get-Content -LiteralPath $output
if ($process.ExitCode -ne 0) {
    Get-Content -LiteralPath $errors
    throw "One-chaos pricing checks exited $($process.ExitCode)"
}
if (-not ([IO.File]::ReadAllText($output).StartsWith('PASS:'))) { throw 'No completed pricing check result' }
