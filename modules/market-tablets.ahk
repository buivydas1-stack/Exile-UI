Init_market_tablets()
{
	local
	global vars, settings
	If !vars.poe_version
		Return
	file := "ini 2\market-tablets.ini"
	settings.market_tablets := {"enable": LLK_IniRead(file, "settings", "enable", 1), "phrases": []}
	defaults := "expl map % azmer spirits`na sp contains # map`n#% gold map ex`nexpl map #% shr"
	text := FileExist(file) ? StrReplace(LLK_IniRead(file, "settings", "modifiers"), " `;`;`; ", "`n") : defaults
	For _, phrase in StrSplit(text, "`n", "`r")
		If (phrase := Trim(phrase, " `t"))
			settings.market_tablets.phrases.Push(phrase)
	If !IsObject(vars.market_tablets)
		vars.market_tablets := {}
}

Settings_market_tablets(GUI)
{
	local
	global vars, settings
	Init_market_tablets()
	Gui, %GUI%: Font, bold underline
	Gui, %GUI%: Add, Text, % "Section xs y+" vars.settings.spacing, Tablet exclusions (PoE2 market)
	Gui, %GUI%: Font, norm
	Gui, %GUI%: Add, Checkbox, % "xs HWNDhwnd Checked" settings.market_tablets.enable, Enable long-press Omni for Tablet searches
	vars.hwnd.settings.market_tablets_enable := hwnd
	Gui, %GUI%: Add, Text, % "xs w" settings.general.fWidth * 62, One modifier search per line. Each phrase must return exactly one result.`nTablet must be selected. Other filters are reset; the final search is left ready.`nPress Esc or switch windows to stop.
	text := ""
	For _, phrase in settings.market_tablets.phrases
		text .= (text ? "`n" : "") phrase
	Gui, %GUI%: Add, Edit, % "xs w" settings.general.fWidth * 62 " r6 cBlack HWNDhwnd", % text
	vars.hwnd.settings.market_tablets_edit := hwnd
	Gui, %GUI%: Add, Button, xs gSettings_market_tabletsSave, Save Tablet exclusions
}

Settings_market_tabletsSave()
{
	local
	global vars, settings
	text := LLK_ControlGet(vars.hwnd.settings.market_tablets_edit), phrases := [], seen := {}, cleaned := ""
	For _, phrase in StrSplit(text, "`n", "`r")
	{
		phrase := Trim(phrase, " `t")
		If !phrase
			Continue
		key := LLK_StringCase(phrase)
		If seen.HasKey(key) || InStr(phrase, Chr(34)) || InStr(phrase, " `;`;`; ")
		{
			LLK_ToolTip("Remove duplicate phrases, quotes, or reserved separators", 3,,,, "Red")
			Return
		}
		seen[key] := 1, cleaned .= (cleaned ? " `;`;`; " : "") phrase
	}
	enable := LLK_ControlGet(vars.hwnd.settings.market_tablets_enable)
	If enable && !cleaned
	{
		LLK_ToolTip("Add at least one modifier, or disable Tablet exclusions", 3,,,, "Red")
		Return
	}
	IniWrite, % Chr(34) cleaned Chr(34), ini 2\market-tablets.ini, settings, modifiers
	If ErrorLevel
	{
		LLK_ToolTip("Could not save Tablet exclusions", 3,,,, "Red")
		Return
	}
	IniWrite, % enable, ini 2\market-tablets.ini, settings, enable
	If ErrorLevel
		LLK_ToolTip("Could not save Tablet exclusions", 3,,,, "Red")
	Else
		Init_market_tablets(), LLK_ToolTip("Tablet exclusions saved", 2,,,, "Lime")
}

MarketTablets_Omni()
{
	local
	global vars, settings
	If !vars.poe_version || !settings.market_tablets.enable || vars.client.stream || (settings.general.input_method = 2)
		Return 0
	If vars.market_tablets.busy
		Return 1
	; The existing image-search engine cheaply gates OCR, preserving Omni elsewhere.
	If !MarketTablets_Header()
		Return 0
	While GetKeyState(vars.omnikey.hotkey, "P")
	{
		If (A_TickCount - vars.omnikey.last >= 500)
		{
			KeyWait, % vars.omnikey.hotkey
			If !Blank(vars.omnikey.hotkey2)
				KeyWait, % vars.omnikey.hotkey2
			MarketTablets_Run()
			Return 1
		}
		Sleep 10
	}
	Return 0
}

MarketTablets_Header()
{
	local
	global vars, settings
	static needle, height
	If (height != vars.client.h) || !needle
	{
		If needle
			Gdip_DisposeImage(needle)
		source := Gdip_CreateBitmapFromFile(A_ScriptDir "\img\GUI\market-tablets.bmp")
		If (source <= 0)
			Return 0
		height := vars.client.h, needle := Gdip_ResizeBitmap(source, Round(180*height/1440), Round(31*height/1440), 1)
		Gdip_DisposeImage(source)
	}
	bitmap := Gdip_BitmapFromHWND(vars.hwnd.poe_client, 1)
	If (bitmap <= 0)
		Return 0
	x := settings.general.blackbars ? vars.client.x - vars.monitor.x : 0
	found := Gdip_ImageSearch(bitmap, needle, positions, x + Round(height*0.20), Round(height*0.04), x + Round(height*0.42), Round(height*0.10), 35,, 1, 1) > 0
	Gdip_DisposeImage(bitmap)
	Return found
}

MarketTablets_Ready()
{
	global vars
	Return !vars.market_tablets.cancelled && WinActive("ahk_id " vars.hwnd.poe_client) && !GetKeyState("Esc", "P") && MarketTablets_Header()
}

MarketTablets_Scan()
{
	local
	global vars, json
	If !MarketTablets_Ready()
		Return []
	text := OCR_Start(0, 0, Round(vars.client.h*0.605), Round(vars.client.h*0.80),, "market_tablets")
	If !text || !MarketTablets_Ready()
		Return []
	Try lines := json.Load(text)
	Catch
		Return []
	For _, line in lines
	{
		line.x /= 2, line.y /= 2, line.w /= 2, line.h /= 2
		For _, word in line.words
			word.x /= 2, word.y /= 2, word.w /= 2, word.h /= 2
	}
	Return lines
}

MarketTablets_Key(text)
{
	StringLower, text, text
	Return RegExReplace(text, "[^a-z0-9]")
}

MarketTablets_Find(lines, text, lowest := 0)
{
	local
	key := MarketTablets_Key(text), found := ""
	For _, line in lines
		If (MarketTablets_Key(line.text) = key) && (!found || (lowest && line.y > found.y))
			found := line
	Return found
}

MarketTablets_Input(lines, phrase, button)
{
	local
	global vars
	key := MarketTablets_QueryKey(phrase)
	For _, line in lines
	{
		read := MarketTablets_QueryKey(line.text)
		; A blinking input caret is occasionally recognised as i, l, or 1.
		If (Abs(line.y-button.y) < vars.client.h*0.015) && MarketTablets_QueryMatches(read, key)
			Return line
	}
	; Isolate the field if the whole-panel OCR omitted a word or split the line.
	center := button.y+button.h/2, scale := vars.client.h/1440
	read := MarketTablets_QueryKey(OCR_Start(Round(25*scale), Round(center-15*scale), Round(770*scale), Round(30*scale)))
	If MarketTablets_QueryMatches(read, key)
		Return {"x": 25*scale, "y": center-15*scale, "w": 770*scale, "h": 30*scale}
	Return 0
}

MarketTablets_QueryMatches(read, key)
{
	Return (read = key || read = key "i" || read = key "l" || read = key "1" || StrLen(read) > 10 && StrLen(key)-StrLen(read) = 1 && InStr(key, read) = 1)
}

MarketTablets_QueryKey(text)
{
	StringLower, text, text
	; Short search tokens and punctuation often disappear in OCR; the clipboard supplies them literally.
	text := RegExReplace(text, "[^a-z0-9 ]", " ")
	text := RegExReplace(text, "\b[a-z0-9]{1,2}\b", "")
	Return StrReplace(text, " ")
}

MarketTablets_Result(lines, button)
{
	local
	global vars
	scale := vars.client.h/1440, center := Round(button.y+button.h/2), bitmap := Gdip_BitmapFromHWND(vars.hwnd.poe_client, 1)
	If (bitmap <= 0)
		Return 0
	xOffset := 0
	global settings
	If settings.general.blackbars
		xOffset := vars.client.x-vars.monitor.x
	bounds := MarketTablets_PopupBounds(bitmap, center, scale, xOffset)
	Gdip_DisposeImage(bitmap)
	If !IsObject(bounds)
		Return 0
	y1 := bounds.1, y2 := bounds.2, text := "", row := ""
	For _, line in lines
		If (line.y+line.h/2 > y1) && (line.y+line.h/2 < y2) && (line.x < 580*scale)
		{
			text .= (text ? " " : "") line.text
			If !row || (line.x < row.x)
				row := line.Clone()
		}
	If !row || !MarketTablets_QueryKey(text)
		Return 0
	row.text := text, row.y := y1, row.h := y2-y1
	Return row
}

MarketTablets_PopupBounds(bitmap, center, scale, xOffset := 0)
{
	local
	; Locate the input's straight gold borders, then require a single-row popup on either side.
	Loop, % Round(24*scale)
	{
		If !top && MarketTablets_Border(bitmap, center-A_Index, scale, xOffset)
			top := center-A_Index
		If !bottom && MarketTablets_Border(bitmap, center+A_Index, scale, xOffset)
			bottom := center+A_Index
	}
	If top && bottom
		Loop, % Round(35*scale)
		{
			If (A_Index < 20*scale)
				Continue
			If !endDown && MarketTablets_Border(bitmap, bottom+A_Index, scale, xOffset)
				endDown := bottom+A_Index
			If !endUp && MarketTablets_Border(bitmap, top-A_Index, scale, xOffset)
				endUp := top-A_Index
		}
	If (!endDown && !endUp) || (endDown && endUp)
		Return 0
	y1 := endDown ? bottom+2*scale : endUp+2*scale, y2 := endDown ? endDown-2*scale : top-2*scale
	Return [y1, y2]
}

MarketTablets_Border(bitmap, y, scale, xOffset := 0)
{
	local
	first := ""
	For _, x in [40, 100, 200, 300, 560, 740, 840]
	{
		pixel := Gdip_GetPixel(bitmap, xOffset+Round(x*scale), y)
		r := (pixel >> 16) & 255, g := (pixel >> 8) & 255, b := pixel & 255
		If (r < 25) || (r > 135) || (r < g) || (g < b+5)
			Return 0
		If !IsObject(first)
			first := [r, g, b]
		Else If (Abs(r-first.1) > 8) || (Abs(g-first.2) > 8) || (Abs(b-first.3) > 8)
			Return 0
	}
	Return 1
}

MarketTablets_Category(lines)
{
	local
	global vars
	label := MarketTablets_Find(lines, "item category"), matches := []
	If !label
		Return ""
	For _, line in lines
		For _, word in line.words
			If (word.x > vars.client.h*0.17) && (word.x < vars.client.h*0.27) && (Abs(word.y - label.y) < vars.client.h*0.012)
				matches.Push(word.text)
	If (matches.Count() != 1)
		Return ""
	; An open category dropdown is not proof that the displayed text was selected.
	For _, line in lines
		If (MarketTablets_Key(line.text) = MarketTablets_Key(matches.1)) && (line.x > vars.client.h*0.17) && (line.x < vars.client.h*0.28) && (line.y > label.y+vars.client.h*0.012) && (line.y < label.y+vars.client.h*0.05)
			Return ""
	Return MarketTablets_Key(matches.1)
}

MarketTablets_Click(line)
{
	local
	global vars
	If !IsObject(line) || !MarketTablets_Ready()
		Return 0
	Click, % Round(vars.client.x + line.x + Min(line.w/2, 100*vars.client.h/1440)) " " Round(vars.client.y + line.y + line.h/2)
	MouseMove, % vars.client.x + Round(vars.client.h*0.63), % vars.client.y + Round(vars.client.h*0.15), 0
	Sleep 150
	Return MarketTablets_Ready()
}

MarketTablets_Paste(text)
{
	If !MarketTablets_Ready()
		Return 0
	Clipboard := "", Clipboard := text
	ClipWait, 0.5
	If ErrorLevel
		Return 0
	SendInput, ^a
	Sleep 40
	SendInput, ^v
	Sleep 250
	Return MarketTablets_Ready()
}

MarketTablets_Scroll(bottom := 0)
{
	local
	global vars
	If !MarketTablets_Ready()
		Return 0
	MouseMove, % vars.client.x + Round(vars.client.h*0.56), % vars.client.y + Round(vars.client.h*0.68), 0
	Loop, 40
		Click, % bottom ? "WheelDown" : "WheelUp"
	MouseMove, % vars.client.x + Round(vars.client.h*0.63), % vars.client.y + Round(vars.client.h*0.15), 0
	Sleep 150
	Return MarketTablets_Ready()
}

MarketTablets_Not(lines)
{
	local
	global vars
	For _, line in lines
		If (line.x < vars.client.h*0.07) && RegExMatch(MarketTablets_Key(line.text), "^nota?$")
			Return line
	Return 0
}

MarketTablets_ModRows(lines)
{
	local
	rows := []
	For _, line in lines
	{
		; The italic Explicit prefix commonly reads as Expuc/t and can join the next word.
		text := RegExReplace(line.text, "i)^\s*exp[liu/]+c[liu/]+t\s*", "explicit ")
		If RegExMatch(text, "i)^\s*(explicit|implicit|pseudo|fractured|enchant|desecrated|augment|sanctum)\b")
			line.text := text, rows.Push(line)
	}
	Return rows
}

MarketTablets_SameMod(text, added)
{
	local
	key := MarketTablets_ModKey(text)
	For _, previous in added
	{
		other := MarketTablets_ModKey(previous)
		If (StrLen(key) > 15) && (StrLen(other) > 15) && (InStr(key, other) || InStr(other, key))
			Return 1
	}
	Return 0
}

MarketTablets_ModKey(text)
{
	text := RegExReplace(text, "i)^\s*exp[liu/]+c[liu/]+t\s*", "")
	text := RegExReplace(text, "i)^\s*(explicit|implicit|pseudo|fractured|enchant|desecrated|augment|sanctum)\s*", "")
	text := RegExReplace(text, "i)[0o]\s*/\s*[0o]", "%")
	Return MarketTablets_Key(text)
}

MarketTablets_VerifyMod(row, selected)
{
	local
	global vars
	If MarketTablets_SameMod(row.text, [selected])
		Return 1
	key := MarketTablets_ModKey(row.text), other := MarketTablets_ModKey(selected)
	; The game clips long selected rows at the value fields. OCR can misread
	; the final partial glyph; require a long matching prefix at that edge.
	Return (row.x+row.w > vars.client.h*0.38) && (StrLen(key) > 30) && (StrLen(other) > StrLen(key)) && (InStr(other, SubStr(key, 1, -2)) = 1)
}

MarketTablets_Run()
{
	local
	global vars, settings
	If vars.market_tablets.busy
		Return 0
	If (settings.general.lang_client != "english") || !settings.market_tablets.phrases.Count()
	{
		LLK_ToolTip("Tablet exclusions need English OCR and at least one saved phrase", 3,,,, "Red")
		Return 0
	}
	vars.market_tablets.cancelled := 0, vars.market_tablets.busy := 1, saved_clipboard := ClipboardAll
	Try result := MarketTablets_Apply(settings.market_tablets.phrases)
	Catch error
		result := "Unexpected error; check the market filters manually"
	Clipboard := saved_clipboard, saved_clipboard := "", vars.market_tablets.busy := 0
	If (result != 1)
		LLK_ToolTip(result, 4,,,, "Red")
	Else LLK_ToolTip("Tablet NOT exclusions ready (" settings.market_tablets.phrases.Count() ")", 3,,,, "Lime")
	Return result
}

MarketTablets_Apply(phrases)
{
	local
	global vars
	lines := MarketTablets_Scan()
	If !MarketTablets_Category(lines) && lines.Count()
	{
		MarketTablets_Click({"x": vars.client.h*0.29, "y": vars.client.h*0.055, "w": 30, "h": 30})
		MarketTablets_Scroll(), lines := MarketTablets_Scan()
		If !MarketTablets_Find(lines, "item category") && MarketTablets_Find(lines, "type filters")
			MarketTablets_Click(MarketTablets_Find(lines, "type filters")), lines := MarketTablets_Scan()
	}
	If (MarketTablets_Category(lines) != "tablet")
		Return "Stopped: selected Item Category could not be confirmed as Tablet"
	; A stat dropdown may cover the fixed footer. Dismiss it without changing filters.
	If !MarketTablets_Click({"x": vars.client.h*0.29, "y": vars.client.h*0.055, "w": 30, "h": 30})
		Return "Stopped: market closed or cancelled"
	; Collapsed/disabled sections can retain hidden values. Reset after category confirmation
	; instead of assuming that an apparently empty form has no other filters.
	clear := {"x": vars.client.h*0.523, "y": vars.client.h*0.75, "w": vars.client.h*0.034, "h": vars.client.h*0.034}
	If !MarketTablets_Click(clear)
		Return "Stopped: market closed or cancelled"
	MarketTablets_Scroll(), lines := MarketTablets_Scan()
	If !MarketTablets_Find(lines, "item category")
	{
		If !MarketTablets_Click(MarketTablets_Find(lines, "type filters"))
			Return "Stopped: Type Filters could not be located"
		lines := MarketTablets_Scan()
	}
	If (MarketTablets_Category(lines) != "any") || MarketTablets_ModRows(lines).Count() || MarketTablets_Not(lines)
		Return "Stopped: Clear Filters did not produce a verified empty form"
	category := MarketTablets_Find(lines, "item category")
	category.x := vars.client.h*0.18, category.w := vars.client.h*0.10
	If !MarketTablets_Click(category) || !MarketTablets_Paste("tablet")
		Return "Stopped: could not restore Tablet"
	lines := MarketTablets_Scan(), match := ""
	For _, line in lines
		If (MarketTablets_Key(line.text) = "tablet") && (line.y > category.y+vars.client.h*0.012) && (line.y < category.y+vars.client.h*0.06)
			match := line
	If !MarketTablets_Click(match) || (MarketTablets_Category(lines := MarketTablets_Scan()) != "tablet")
		Return "Stopped: restored Tablet category was not verified"
	MarketTablets_Scroll(1), lines := MarketTablets_Scan()
	If !MarketTablets_Click(MarketTablets_Find(lines, "add stat group"))
		Return "Stopped: Add Stat Group could not be located"
	lines := MarketTablets_Scan(), choice := MarketTablets_Find(lines, "not")
	If !choice || (choice.x < vars.client.h*0.35) || !MarketTablets_Click(choice)
		Return "Stopped: NOT condition could not be located"
	lines := MarketTablets_Scan()
	If !MarketTablets_Not(lines)
		Return "Stopped: NOT group was not verified"
	added := []
	For index, phrase in phrases
	{
		MarketTablets_Scroll(1), lines := MarketTablets_Scan()
		button := MarketTablets_Find(lines, "add stat filter", 1), group := MarketTablets_Find(lines, "add stat group")
		If !button || !group || (button.y >= group.y) || (group.y-button.y > vars.client.h*0.08)
			Return "Stopped at modifier " index ": NOT group's Add Stat Filter could not be located"
		If !MarketTablets_Click(button) || !MarketTablets_Paste(phrase)
			Return "Stopped at modifier " index ": market closed or cancelled"
		lines := MarketTablets_Scan(), input := MarketTablets_Input(lines, phrase, button)
		If !input || (Abs(input.y-button.y) > vars.client.h*0.015)
			Return "Stopped at modifier " index ": pasted search phrase was not verified"
		candidate := MarketTablets_Result(lines, button)
		If !candidate || MarketTablets_SameMod(candidate.text, added)
			Return "Stopped at modifier " index ": phrase must return exactly one new modifier"
		selected := candidate.text
		If !MarketTablets_Click(candidate)
			Return "Stopped: market closed or cancelled"
		MarketTablets_Scroll(1), lines := MarketTablets_Scan()
		If !MarketTablets_Find(lines, "add stat filter", 1) || !MarketTablets_Find(lines, "add stat group")
			Return "Stopped at modifier " index ": modifier selection was not verified"
		verified := 0
		For _, row in lines
			If MarketTablets_VerifyMod(row, selected)
				verified := 1
		If !verified
			Return "Stopped at modifier " index ": added modifier was not verified"
		added.Push(selected)
	}
	Return 1
}
