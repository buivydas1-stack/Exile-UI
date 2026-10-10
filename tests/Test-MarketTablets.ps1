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
batch := [{text:"NOT",x:31,y:695,h:18},{text:"+ Add Stat Filter",x:351,y:900,h:18}]
texts := ["Explicit Map has #% increased chance to contain Azmeri Spirits","Explicit Map contains # additional Azmeri Spirit","Explicit #% increased Gold found in Map (Gold Piles)","Explicit Map has #% increased chance to contain Shrines"]
for index, text in texts
    batch.Push({text:text,x:31,y:698.5+index*41,w:530,h:18})
batch.Push({text:"+ Add Stat Group",x:607,y:939,w:150,h:18})
Check(MarketTablets_VerifyBatch(batch,phrases,4).Count()=4, "first four verified together in screen order")
goldOmitted := batch.Clone(), goldOmitted[5] := {text:"INCREASED GOLD FOUND IN MAP (GOLD PILES)",x:126,y:822.5,w:338,h:16.5}
Check(MarketTablets_VerifyBatch(goldOmitted,phrases,4).Count()=4, "actual Gold OCR without Explicit prefix still verifies the batch")
goldSplit := goldOmitted.Clone(), goldSplit.Push({text:"EXPLICIT #%",x:31,y:823,w:90,h:13})
Check(MarketTablets_VerifyBatch(goldSplit,phrases,4).Count()=4, "split modifier prefix and text combine into one selected row")
goldWords := goldOmitted.Clone(), goldWords[5] := {text:"INCREASED GOLD FOUND IN MAP MIN MAX",x:126,y:822.5,w:640,h:16.5,words:[{text:"INCREASED GOLD FOUND IN MAP",x:126},{text:"MIN",x:585},{text:"MAX",x:705}]}
Check(MarketTablets_VerifyBatch(goldWords,phrases,4).Count()=4, "value-field words are excluded from the batch text column")
wrong := batch.Clone(), wrong.RemoveAt(6)
Check(!MarketTablets_VerifyBatch(wrong,phrases,4,reason) && reason="OCR read 3 of 4 selected rows", "missing batch row reports the actual OCR count")
wrong := batch.Clone(), wrong[6] := {text:texts.1,x:31,y:894,w:530,h:18}
Check(!MarketTablets_VerifyBatch(wrong,phrases,4), "wrong or duplicate batch modifier stops the run")
wrong := batch.Clone(), wrong[5] := {text:"INCREASED EXPERIENCE GAIN IN MAP",x:126,y:822.5,w:338,h:16.5}
Check(!MarketTablets_VerifyBatch(wrong,phrases,4,reason) && reason="modifier 3 did not match its saved phrase", "missing prefix does not permit a different modifier")
wrong := batch.Clone(), wrong.RemoveAt(2)
Check(!MarketTablets_VerifyBatch(wrong,phrases,4,reason) && reason="NOT group or add control was not read", "missing control reports a specific verification error")
wrong := batch.Clone(), wrong.Push({text:"Unexpected additional stat",x:31,y:715,w:300,h:18})
Check(!MarketTablets_VerifyBatch(wrong,phrases,4), "unexpected text row in the selected group is rejected")
Check(!MarketTablets_PhraseMatches(texts.3,phrases.4), "batch verification rejects a different search result")
choice := [{text:"NOT",x:610,y:720,w:60,h:18}], emptyNot := [{text:"NOT",x:31,y:695,w:60,h:18},{text:"+ Add Stat Filter",x:351,y:738,w:137,h:18},{text:"+ Add Stat Group",x:607,y:781,w:150,h:18}]
testScans := [clean,choice,emptyNot,goldOmitted], testScanCount := testClearCount := testTabletPastes := testButtonCount := testScrollCount := 0, testClips := []
Check(Test_Apply(phrases)=1 && testClearCount=0 && testTabletPastes=0 && testScanCount=4 && testScrollCount=0, "clean first-four run uses four scans, no reset, no scrolling")
Check(testClips[2].w < 300 && testClips[2].h < 300 && testClips[3].h < 260, "group creation uses small menu and group scans")
testScans := [clean,[],choice,[],emptyNot,batch], testScanCount := testClearCount := testTabletPastes := testButtonCount := testScrollCount := 0
Check(Test_Apply(phrases)=1 && testScanCount=6 && testScrollCount=0, "unread cropped menu or group retries a full scan without scrolling")
cleared := []
for _, row in clean
    cleared.Push(row.Clone())
cleared[14] := other
dirty := clean.Clone(), dirty.Push({text:"123",x:270,y:329,words:[]})
testScans := [dirty,cleared,[dropdown],clean,choice,emptyNot,batch], testScanCount := testClearCount := testTabletPastes := testButtonCount := testScrollCount := 0
Check(Test_Apply(phrases)=1 && testClearCount=1 && testTabletPastes=1 && testScrollCount=1, "dirty form resets and restores Tablet once, with no per-modifier scrolling")
fivePhrases := phrases.Clone(), fivePhrases.Push("expl experience gain in map"), five := batch.Clone()
five[2] := {text:"+ Add Stat Filter",x:351,y:941,w:137,h:18}, five[7] := {text:"+ Add Stat Group",x:607,y:980,w:150,h:18}
testResult := {text:"Explicit #% increased Experience Gain in Map",x:31,y:903.5,w:400,h:18}, five.Push(testResult)
testScans := [clean,choice,emptyNot,five], testScanCount := testClearCount := testTabletPastes := testButtonCount := testScrollCount := 0
Check(Test_Apply(fivePhrases)=1 && testScanCount=4 && testClearCount=0 && testScrollCount=0, "five modifiers use one combined verification without scrolling")
sixPhrases := fivePhrases.Clone(), sixPhrases.Push("expl map contains an additional shrine"), six := five.Clone()
six[2] := {text:"+ Add Stat Filter",x:351,y:982,w:137,h:18}, six[7] := {text:"+ Add Stat Group",x:607,y:1021,w:150,h:18}
six.Push({text:"Explicit Map contains an additional Shrine",x:31,y:944.5,w:400,h:18})
testScans := [clean,choice,emptyNot,six], testScanCount := testClearCount := testTabletPastes := testButtonCount := testScrollCount := 0
Check(Test_Apply(sixPhrases)=1 && testScanCount=4 && testScrollCount=0 && testButtonCount=7, "all six additions use images and one batch OCR check")
wrongSix := six.Clone(), wrongSix.RemoveAt(9)
Check(!MarketTablets_VerifyBatch(wrongSix,sixPhrases,6,reason) && reason="OCR read 5 of 6 selected rows", "missing sixth selection is still rejected")
sevenPhrases := sixPhrases.Clone(), sevenPhrases.Push("pseudo total maximum life"), seven := six.Clone()
seven[2] := {text:"+ Add Stat Filter",x:351,y:1023,w:137,h:18}, seven[7] := {text:"+ Add Stat Group",x:607,y:1062,w:150,h:18}
testResult := {text:"Pseudo # total maximum Life",x:31,y:985.5,w:400,h:18}, seven.Push(testResult)
testScans := [clean,choice,emptyNot,six,[],seven], testScanCount := testClearCount := testTabletPastes := testButtonCount := testScrollCount := 0
Check(Test_Apply(sevenPhrases)=1 && testScanCount=6 && testScrollCount=0, "seventh addition keeps the existing individual OCR path")
testNextReady := 1, testNextCount := 0, testNextButtons := [{y:735},{y:735},{y:776}]
Check(Test_NextButtonHelper({y:735}).y=776 && testNextCount=3, "short click delay waits only while the next add control is unchanged")
testNextReady := 0, testNextCount := 0
Check(!Test_NextButtonHelper({y:735}) && testNextCount=0, "cancelled next-control wait performs no capture")
testOCR := [{text:"NOT",x:62,y:40,w:110,h:36,words:[{text:"NOT",x:62,y:40,w:110,h:36}]}]
scanned := Test_ScanHelper({x:562,y:679,w:295,h:158})
Check(scanned.1.x=593 && scanned.1.y=699 && scanned.1.words.1.x=593 && scanned.1.words.1.y=699 && scanned.1.w=55 && scanned.1.h=18, "cropped scan restores both line and word panel coordinates")
Check(testOCRClip.1=562 && testOCRClip.2=679 && testOCRClip.3=295 && testOCRClip.4=158, "cropped scan sends its exact region to the existing OCR worker")
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
testHeld := 1, vars.omnikey.last := A_TickCount-210, testStarted := A_TickCount
Check(MarketTablets_Omni() && testRuns = 1 && testRunHeld = 1 && A_TickCount-testStarted < 150, "200 ms hold starts immediately while Omni is still held")
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
    global testRuns, testHeld, testRunHeld
    testRunHeld := testHeld
    testRuns++
}
Test_KeyWait()
{
    global testHeld
    testHeld := 0
}
Test_WinActive(params*)
{
    Return 1
}
Test_Scan(clip := "")
{
    global testScans, testScanCount, testClips
    testScanCount++
    testClips.Push(clip)
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
Test_NextButton(previous)
{
    Return Test_AddButton()
}
Test_NextReady()
{
    global testNextReady
    Return testNextReady
}
Test_NextAddButton()
{
    global testNextButtons, testNextCount
    testNextCount++
    Return testNextButtons[testNextCount]
}
Test_ScanReady()
{
    Return 1
}
OCR_Start(params*)
{
    global testOCR, testOCRClip, json
    testOCRClip := params
    Return json.dump(testOCR)
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
$functions = @('Init_market_tablets','Settings_market_tabletsSave','MarketTablets_Key','MarketTablets_Find','MarketTablets_Category','MarketTablets_QueryKey','MarketTablets_QueryMatches','MarketTablets_SameMod','MarketTablets_ModKey','MarketTablets_VerifyMod','MarketTablets_PopupBounds','MarketTablets_Border','MarketTablets_Clean','MarketTablets_SectionsOff','MarketTablets_AddButton','MarketTablets_PhraseMatches','MarketTablets_VerifyBatch','MarketTablets_Not')
$harness = '#Include ' + (Join-Path $SourceDirectory 'data/External Functions.ahk') + "`r`n#Include " + (Join-Path $SourceDirectory 'data/JSON.ahk') + "`r`n" + $harness
foreach ($name in $functions) { $harness += "`r`n" + (Read-Function $name) }
$harness += "`r`n" + (Read-Function 'MarketTablets_Needle').Replace('A_ScriptDir', ('"' + $SourceDirectory + '"'))
$flow = (Read-Function 'MarketTablets_Apply').Replace('MarketTablets_Apply(', 'Test_Apply(')
foreach ($action in @('Scan','SectionsOff','Click','Scroll','Paste','AddButton','FastResult','NextButton','BottomLines','Input','Result')) {
    $flow = $flow.Replace(('MarketTablets_' + $action + '('), ('Test_' + $action + '('))
}
$harness += "`r`n" + $flow
$harness += "`r`n" + (Read-Function 'MarketTablets_NextButton').Replace('MarketTablets_NextButton(', 'Test_NextButtonHelper(').Replace('MarketTablets_Ready(', 'Test_NextReady(').Replace('MarketTablets_AddButton(', 'Test_NextAddButton(')
$harness += "`r`n" + (Read-Function 'MarketTablets_Scan').Replace('MarketTablets_Scan(', 'Test_ScanHelper(').Replace('MarketTablets_Ready(', 'Test_ScanReady(')
$omni = (Read-Function 'MarketTablets_Omni').Replace('GetKeyState(', 'Test_KeyState(')
$omni = [regex]::Replace($omni, 'KeyWait, % vars\.omnikey\.hotkey2?', 'Test_KeyWait()')
$harness += "`r`n" + $omni
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
