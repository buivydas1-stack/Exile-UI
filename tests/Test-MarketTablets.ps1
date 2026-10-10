param(
    [string]$OutputDirectory = (Join-Path $env:TEMP 'exile-ui-market-tablet-tests'),
    [string]$SourceDirectory = (Split-Path $PSScriptRoot)
)
$ErrorActionPreference = 'Stop'
function Read-Function([string]$Name) {
    $source = [IO.File]::ReadAllText((Join-Path $SourceDirectory 'modules/market-tablets.ahk'))
    $match = [regex]::Match($source, '(?ms)^' + [regex]::Escape($Name) + '\([^\r\n]*\)[^\r\n]*\r?\n\{.*?^\}')
    if (!$match.Success) { throw "Missing function $Name" }
    $match.Value
}
New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
$harness = @'
#NoEnv
#NoTrayIcon
#SingleInstance Off
SetBatchLines, -1
vars := {"client": {"h": 1440}}, failures := checks := 0
pToken := Gdip_Startup()
label := {"text": "item category", "x": 30, "y": 288, "w": 114, "h": 13, "words": []}
tablet := {"text": "tablet", "x": 261, "y": 287, "w": 52, "h": 13, "words": [{"text": "tablet", "x": 261, "y": 287}]}
arrow := {"text": "v", "x": 399, "y": 288, "words": [{"text": "v", "x": 399, "y": 288}]}
rarity := {"text": "any", "x": 678, "y": 287, "words": [{"text": "any", "x": 678, "y": 287}]}
Check(MarketTablets_Category([label, tablet, arrow, rarity]) = "tablet", "category ignores arrow and rarity")
other := {"text": "any", "x": 261, "y": 287, "words": [{"text": "any", "x": 261, "y": 287}]}
Check(MarketTablets_Category([label, other]) = "any", "non-Tablet remains distinct")
dropdown := {"text": "tablet", "x": 261, "y": 315, "words": [{"text": "tablet", "x": 261, "y": 315}]}
Check(!MarketTablets_Category([label, tablet, dropdown]), "typed unselected category is rejected")
Check(!MarketTablets_Category([tablet]), "category label must be visible")
Check(!MarketTablets_Category([]), "failed OCR is rejected")
Check(MarketTablets_Find([{text:"+ Add Stat Filter",y:800}, {text:"+ Add Stat Filter",y:400}], "add stat filter", 1).y = 800, "lowest add button in unsorted OCR")
for _, phrase in ["expl map % azmer spirits", "a sp contains # map", "#% gold map ex", "expl map #% shr"]
    Check(MarketTablets_QueryMatches(MarketTablets_QueryKey(phrase), MarketTablets_QueryKey(phrase)), "query punctuation: " phrase)
Check(MarketTablets_QueryMatches("explmapazmerspiritsi", "explmapazmerspirits"), "blinking caret accepted")
Check(MarketTablets_QueryMatches("explmapcontainessence", "explmapcontainessences"), "caret-obscured final letter accepted")
Check(!MarketTablets_QueryMatches("explmapcontainshrine", "explmapcontainessences"), "different query rejected")
Check(MarketTablets_SameMod("Explicit Map has #% increased chance to contain Essences", ["Expuc/tMap has #0/0 increased chance to contain Essences"]), "italic prefix and percent OCR variation")
Check(MarketTablets_SameMod("Explicit Map has #% increased chance", ["Explicit Map has #% increased chance to contain Shrines"]), "clipped added row verified")
Check(!MarketTablets_SameMod("Explicit Map contains an additional Shrine", ["Explicit Map has #% increased chance to contain Shrines"]), "different modifiers rejected")
Check(MarketTablets_VerifyMod({text:"explicitmap has #% increased chance to contain a summoning cl", x:31, w:539.5}, "explicitmap has #% increased chance to contain a summoning circle"), "clipped final partial glyph verified at value-field edge")
Check(!MarketTablets_VerifyMod({text:"explicitmap has #% increased chance to contain a summoning cl", x:31, w:300}, "explicitmap has #% increased chance to contain a summoning circle"), "partial glyph fallback requires clipped row edge")
Check(!MarketTablets_VerifyMod({text:"explicitmap has #% increased chance to contain strongboxes", x:31, w:539.5}, "explicitmap has #% increased chance to contain a summoning circle"), "partial glyph fallback rejects different stat")
for _, scale in [1, 0.75]
    for _, direction in [-1, 1]
        for _, rows in [0, 1, 2, 20]
        {
            bitmap := Gdip_CreateBitmap(Round(870*scale), Round(1140*scale))
            graphics := Gdip_GraphicsFromImage(bitmap), pen := Gdip_CreatePen(0xFF645A45, Max(1, scale))
            center := Round(700*scale), top := Round(684*scale), bottom := Round(716*scale)
            Gdip_DrawLine(graphics, pen, 20*scale, top, 846*scale, top)
            Gdip_DrawLine(graphics, pen, 20*scale, bottom, 846*scale, bottom)
            if rows
            {
                edge := Round((direction = 1 ? 716+rows*27 : 684-rows*27)*scale)
                Gdip_DrawLine(graphics, pen, 20*scale, edge, 846*scale, edge)
            }
            bounds := MarketTablets_PopupBounds(bitmap, center, scale)
            Check(IsObject(bounds) = (rows = 1), "popup proof scale=" scale " direction=" direction " rows=" rows)
            Gdip_DeletePen(pen), Gdip_DeleteGraphics(graphics), Gdip_DisposeImage(bitmap)
        }
Gdip_Shutdown(pToken)
vars := {poe_version:" 2", client:{stream:0}, market_tablets:{busy:0}, omnikey:{hotkey:"CapsLock",hotkey2:"",last:A_TickCount-600}}
settings := {market_tablets:{enable:1}, general:{input_method:1}}
testHeld := 0, testHeader := 1, testRuns := 0
Check(!MarketTablets_Omni() && testRuns = 0, "short Omni leaves existing action available")
testHeld := 1
Check(MarketTablets_Omni() && testRuns = 1, "long Omni invokes Tablet automation once")
vars.poe_version := ""
Check(!MarketTablets_Omni() && testRuns = 1, "PoE1 Omni is unaffected")
vars.poe_version := " 2", settings.market_tablets.enable := 0
Check(!MarketTablets_Omni() && testRuns = 1, "disabled feature leaves Omni available")
settings.market_tablets.enable := 1, testHeader := 0
Check(!MarketTablets_Omni() && testRuns = 1, "outside market leaves Omni available")
testHeader := 1, testHeld := 0, vars.market_tablets.cancelled := 0
Check(MarketTablets_Ready(), "visible focused market is ready")
vars.market_tablets.cancelled := 1
Check(!MarketTablets_Ready(), "Escape cancellation remains latched after key release")
vars.market_tablets.cancelled := 0
FileCreateDir, ini 2
FileDelete, ini 2\market-tablets.ini
Init_market_tablets()
Gui, test: Add, Edit, HWNDtestEdit, % "expl map % azmer spirits`na sp contains # map`n#% gold map ex`nexpl map #% shr"
Gui, test: Add, Checkbox, HWNDtestEnable Checked1, Enabled
Gui, test: Default
vars.hwnd := {settings:{market_tablets_edit:testEdit,market_tablets_enable:testEnable}}
Settings_market_tabletsSave(), settings.market_tablets := {}, Init_market_tablets()
Check(settings.market_tablets.enable = 1 && settings.market_tablets.phrases.Count() = 4 && settings.market_tablets.phrases.3 = "#% gold map ex", "saved phrases retain percent and hash across reload")
GuiControl,, % testEnable, 0
Settings_market_tabletsSave(), Init_market_tablets()
Check(settings.market_tablets.enable = 0, "disabled setting persists")
GuiControl,, % testEnable, 1
GuiControl,, % testEdit, duplicate`nduplicate
Settings_market_tabletsSave(), Init_market_tablets()
Check(settings.market_tablets.enable = 0 && settings.market_tablets.phrases.Count() = 4, "duplicate phrases leave saved settings intact")
GuiControl,, % testEdit, % "invalid`""phrase"
Settings_market_tabletsSave(), Init_market_tablets()
Check(settings.market_tablets.phrases.Count() = 4, "invalid INI quote leaves saved settings intact")
GuiControl,, % testEdit,
Settings_market_tabletsSave(), Init_market_tablets()
Check(settings.market_tablets.enable = 0 && settings.market_tablets.phrases.Count() = 4, "empty enabled list leaves saved settings intact")
GuiControl,, % testEdit, % "expl map % azmer spirits`na sp contains # map`n#% gold map ex`nexpl map #% shr"
Settings_market_tabletsSave(), Init_market_tablets()
Gui, test: Destroy
FileAppend, % checks " checks, " failures " failures`n", *
ExitApp, % failures
Test_KeyState(params*)
{
    global testHeld
    Return testHeld
}
MarketTablets_Header()
{
    global testHeader
    Return testHeader
}
MarketTablets_Run()
{
    global testRuns
    testRuns++
}
Test_WinActive(params*)
{
    Return 1
}
Blank(value)
{
    Return value = ""
}
LLK_ToolTip(params*)
{
}
Check(condition, name)
{
    global checks, failures
    checks++
    if !condition
        failures++
    FileAppend, % (condition ? "PASS: " : "FAIL: ") name "`n", *
}
'@
$functions = @('Init_market_tablets','Settings_market_tabletsSave','MarketTablets_Key','MarketTablets_Find','MarketTablets_Category','MarketTablets_QueryKey','MarketTablets_QueryMatches','MarketTablets_SameMod','MarketTablets_ModKey','MarketTablets_VerifyMod','MarketTablets_PopupBounds','MarketTablets_Border')
$harness = '#Include ' + (Join-Path $SourceDirectory 'data/External Functions.ahk') + "`r`n" + $harness
foreach ($name in $functions) { $harness += "`r`n" + (Read-Function $name) }
$harness += "`r`n" + (Read-Function 'MarketTablets_Omni').Replace('GetKeyState(', 'Test_KeyState(')
$harness += "`r`n" + (Read-Function 'MarketTablets_Ready').Replace('GetKeyState(', 'Test_KeyState(').Replace('WinActive(', 'Test_WinActive(')
foreach ($helper in @(@('modules/GUI.ahk','LLK_ControlGet'), @('modules/_functions.ahk','LLK_IniRead'), @('modules/_functions.ahk','LLK_StringCase'))) {
    $helperSource = [IO.File]::ReadAllText((Join-Path $SourceDirectory $helper[0]))
    $helperMatch = [regex]::Match($helperSource, '(?ms)^' + [regex]::Escape($helper[1]) + '\([^\r\n]*\)[^\r\n]*\r?\n\{.*?^\}')
    if (!$helperMatch.Success) { throw "Missing helper $($helper[1])" }
    $harness += "`r`n" + $helperMatch.Value
}
$script = Join-Path $OutputDirectory 'market-tablets-tests.ahk'
[IO.File]::WriteAllText($script, $harness, [Text.UTF8Encoding]::new($true))
$stdout = Join-Path $OutputDirectory 'stdout.txt'
$stderr = Join-Path $OutputDirectory 'stderr.txt'
$test = Start-Process 'C:\Program Files\AutoHotkey\AutoHotkey.exe' -ArgumentList ('/ErrorStdOut "' + $script + '"') -WorkingDirectory $OutputDirectory -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
Get-Content $stdout
Get-Content $stderr
if ($test.ExitCode -ne 0) { throw "Market Tablet tests failed: $($test.ExitCode)" }
