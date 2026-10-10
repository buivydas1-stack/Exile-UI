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
clean := []
for text, y in {"type filters":243,"item category":288,"item level":329,"item rarity":288,"item quality":329,"equipment filters":373,"requirements":419,"endgame filters":466,"miscellaneous":513,"trade filters":560,"stat filters":610,"add stat filter":652,"add stat group":695}
    clean.Push({text:text,x:30,y:y,w:150,h:18,words:[]})
clean.Push(tablet), clean.Push(rarity), clean.Push({text:"p search items",x:39,y:185,w:164,h:24,words:[]})
Check(MarketTablets_Clean(clean), "clean Tablet form keeps its existing category")
dirty := clean.Clone(), dirty.Push({text:"123",x:270,y:329,words:[]})
Check(!MarketTablets_Clean(dirty), "numeric filter needs reset")
dirty := clean.Clone(), dirty.Push({text:"rare",x:678,y:287,words:[]})
Check(!MarketTablets_Clean(dirty), "non-default rarity needs reset")
dirty := clean.Clone(), dirty.Push({text:"NOT",x:31,y:695,words:[]})
Check(!MarketTablets_Clean(dirty), "existing stat group needs reset")
dirty := clean.Clone(), dirty.Push({text:"gold",x:39,y:185,words:[]})
Check(!MarketTablets_Clean(dirty), "item name filter needs reset")
dirty := clean.Clone(), dirty.Push({text:"explicit map contains an additional shrine",x:31,y:733,words:[]})
Check(!MarketTablets_Clean(dirty), "existing modifier needs reset")
dirty := clean.Clone(), dirty.Push({text:"unexpected",x:30,y:430,words:[]})
Check(!MarketTablets_Clean(dirty), "unfamiliar form needs reset")
Check(!MarketTablets_Clean([]), "failed OCR cannot skip reset checks")
bitmap := Gdip_CreateBitmap(870,1140), graphics := Gdip_GraphicsFromImage(bitmap)
emptyValues := MarketTablets_Needle("values"), Gdip_DrawImage(graphics,emptyValues,250,318,597,37)
needle := MarketTablets_Needle("off")
for _, text in ["equipment filters","requirements","endgame filters","miscellaneous","trade filters"]
{
    line := MarketTablets_Find(clean,text)
    Gdip_DrawImage(graphics,needle,818,line.y+line.h/2-11.5,20,23)
}
Check(MarketTablets_SectionsOff(clean,bitmap), "inactive collapsed sections preserve clean form")
pen := Gdip_CreatePen(0xFFFFFFFF,4), line := MarketTablets_Find(clean,"trade filters")
Gdip_DrawLine(graphics,pen,823,line.y+5,832,line.y+14)
Check(!MarketTablets_SectionsOff(clean,bitmap), "active collapsed section needs reset")
Gdip_DeletePen(pen), Gdip_DeleteGraphics(graphics), Gdip_DisposeImage(bitmap)
bitmap := Gdip_CreateBitmap(870,1140), graphics := Gdip_GraphicsFromImage(bitmap)
Gdip_DrawImage(graphics,emptyValues,250,318,597,37)
for _, text in ["equipment filters","requirements","endgame filters","miscellaneous","trade filters"]
{
    line := MarketTablets_Find(clean,text)
    Gdip_DrawImage(graphics,needle,818,line.y+line.h/2-11.5,20,23)
}
pen := Gdip_CreatePen(0xFFFFFFFF,4), Gdip_DrawLine(graphics,pen,280,325,280,342)
Check(!MarketTablets_SectionsOff(clean,bitmap), "unread numeric value cannot pass clean-form image check")
Gdip_DeletePen(pen), Gdip_DeleteGraphics(graphics), Gdip_DisposeImage(bitmap)
bitmap := Gdip_CreateBitmap(870,1140), graphics := Gdip_GraphicsFromImage(bitmap), needle := MarketTablets_Needle("add")
Gdip_DrawImage(graphics,needle,350,649,137,21), Gdip_DrawImage(graphics,needle,350,899,137,21)
Check(Abs(MarketTablets_AddButton(bitmap).y-899)<3, "image lookup chooses NOT group's lowest add control")
Gdip_DeleteGraphics(graphics), Gdip_DisposeImage(bitmap)
phrases := ["expl map % azmer spirits","a sp contains # map","#% gold map ex","expl map #% shr"]
batch := [{text:"NOT",x:31,y:695},{text:"+ Add Stat Filter",x:351,y:900}]
texts := ["Explicit Map has #% increased chance to contain Azmeri Spirits","Explicit Map contains # additional Azmeri Spirit","Explicit #% increased Gold found in Map (Gold Piles)","Explicit Map has #% increased chance to contain Shrines"]
for index, text in texts
    batch.Push({text:text,x:31,y:730+index*41,w:530,h:18})
batch.Push({text:"+ Add Stat Group",x:607,y:939,w:150,h:18})
Check(MarketTablets_VerifyBatch(batch,phrases,4).Count()=4, "first four verified together in screen order")
wrong := batch.Clone(), wrong.RemoveAt(6)
Check(!MarketTablets_VerifyBatch(wrong,phrases,4), "missing batch row stops the run")
wrong := batch.Clone(), wrong[6] := {text:texts.1,x:31,y:894,w:530,h:18}
Check(!MarketTablets_VerifyBatch(wrong,phrases,4), "wrong or duplicate batch modifier stops the run")
Check(!MarketTablets_PhraseMatches(texts.3,phrases.4), "batch verification rejects a different search result")
choice := [{text:"NOT",x:610,y:720,w:60,h:18}], emptyNot := [{text:"NOT",x:31,y:695,w:60,h:18},{text:"+ Add Stat Filter",x:351,y:738,w:137,h:18},{text:"+ Add Stat Group",x:607,y:781,w:150,h:18}]
testScans := [clean,choice,emptyNot,batch], testScanCount := testClearCount := testTabletPastes := testButtonCount := testScrollCount := 0
Check(Test_Apply(phrases)=1 && testClearCount=0 && testTabletPastes=0 && testScanCount=4 && testScrollCount=0, "clean first-four run uses four scans, no reset, no scrolling")
cleared := []
for _, row in clean
    cleared.Push(row.Clone())
cleared[14] := other
dirty := clean.Clone(), dirty.Push({text:"123",x:270,y:329,words:[]})
testScans := [dirty,cleared,[dropdown],clean,choice,emptyNot,batch], testScanCount := testClearCount := testTabletPastes := testButtonCount := testScrollCount := 0
Check(Test_Apply(phrases)=1 && testClearCount=1 && testTabletPastes=1 && testScrollCount=1, "dirty form resets and restores Tablet once, with no per-modifier scrolling")
fivePhrases := phrases.Clone(), fivePhrases.Push("expl experience gain in map"), five := batch.Clone()
five[2] := {text:"+ Add Stat Filter",x:351,y:941,w:137,h:18}, five[7] := {text:"+ Add Stat Group",x:607,y:980,w:150,h:18}
testResult := {text:"Explicit #% increased Experience Gain in Map",x:31,y:935,w:400,h:18}, five.Push(testResult)
testScans := [clean,choice,emptyNot,batch,[],five], testScanCount := testClearCount := testTabletPastes := testButtonCount := testScrollCount := 0
Check(Test_Apply(fivePhrases)=1 && testScanCount=6 && testClearCount=0 && testScrollCount=0, "fifth modifier uses normal verification and reuses the batch scan")
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
Test_Scan()
{
    global testScans, testScanCount
    testScanCount++
    Return testScans[testScanCount]
}
Test_SectionsOff(params*)
{
    Return 1
}
Test_Click(line)
{
    global testClearCount
    If line.y > 1000
        testClearCount++
    Return IsObject(line)
}
Test_Scroll(params*)
{
    global testScrollCount
    testScrollCount++
    Return 1
}
Test_Paste(text)
{
    global testTabletPastes
    If (text="tablet")
        testTabletPastes++
    Return 1
}
Test_AddButton()
{
    global testButtonCount
    testButtonCount++
    Return {x:350,y:735+(testButtonCount-1)*41,w:137,h:21}
}
Test_FastResult(button)
{
    Return {x:31,y:button.y+30,w:400,h:23}
}
Test_BottomLines(lines)
{
    Return lines
}
Test_Input(lines,phrase,button)
{
    Return button
}
Test_Result(params*)
{
    global testResult
    Return testResult
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
$functions = @('Init_market_tablets','Settings_market_tabletsSave','MarketTablets_Key','MarketTablets_Find','MarketTablets_Category','MarketTablets_QueryKey','MarketTablets_QueryMatches','MarketTablets_SameMod','MarketTablets_ModKey','MarketTablets_VerifyMod','MarketTablets_PopupBounds','MarketTablets_Border','MarketTablets_Clean','MarketTablets_SectionsOff','MarketTablets_AddButton','MarketTablets_PhraseMatches','MarketTablets_VerifyBatch','MarketTablets_ModRows','MarketTablets_Not')
$harness = '#Include ' + (Join-Path $SourceDirectory 'data/External Functions.ahk') + "`r`n" + $harness
foreach ($name in $functions) { $harness += "`r`n" + (Read-Function $name) }
$harness += "`r`n" + (Read-Function 'MarketTablets_Needle').Replace('A_ScriptDir', ('"' + $SourceDirectory + '"'))
$flow = (Read-Function 'MarketTablets_Apply').Replace('MarketTablets_Apply(', 'Test_Apply(')
foreach ($action in @('Scan','SectionsOff','Click','Scroll','Paste','AddButton','FastResult','BottomLines','Input','Result')) {
    $flow = $flow.Replace(('MarketTablets_' + $action + '('), ('Test_' + $action + '('))
}
$harness += "`r`n" + $flow
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
