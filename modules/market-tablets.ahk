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
	Gui, %GUI%: Add, Text, % "xs w" settings.general.fWidth * 62, One modifier search per line. Each phrase must return exactly one result.`nTablet must be selected. Extra filters or an unfamiliar form trigger a reset.`nThe final search is left ready. Press Esc or switch windows to stop.
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

MarketTablets_Scan(clip := "")
{
	local
	global vars, json
	If !MarketTablets_Ready()
		Return []
	If !IsObject(clip)
		clip := {"x": 0, "y": 0, "w": vars.client.h*0.605, "h": vars.client.h*0.80}
	x := Round(clip.x), y := Round(clip.y)
	text := OCR_Start(x, y, Round(clip.w), Round(clip.h),, "market_tablets")
	If !text || !MarketTablets_Ready()
		Return []
	Try lines := json.Load(text)
	Catch
		Return []
	For _, line in lines
	{
		line.x := line.x/2+x, line.y := line.y/2+y, line.w /= 2, line.h /= 2
		For _, word in line.words
			word.x := word.x/2+x, word.y := word.y/2+y, word.w /= 2, word.h /= 2
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
	Sleep 70
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
	Sleep 20
	SendInput, ^v
	Sleep 100
	Return MarketTablets_Ready()
}

MarketTablets_Scroll(bottom := 0, amount := 40)
{
	local
	global vars
	If !MarketTablets_Ready()
		Return 0
	MouseMove, % vars.client.x + Round(vars.client.h*0.25), % vars.client.y + Round(vars.client.h*0.68), 0
	Loop, % amount
	{
		If vars.market_tablets.cancelled || !WinActive("ahk_id " vars.hwnd.poe_client) || GetKeyState("Esc", "P")
			Return 0
		Click, % bottom ? "WheelDown" : "WheelUp"
	}
	; Keep the pointer in the filter pane while the game consumes wheel events.
	Sleep 150
	MouseMove, % vars.client.x + Round(vars.client.h*0.63), % vars.client.y + Round(vars.client.h*0.15), 0
	Return MarketTablets_Ready()
}

MarketTablets_Clean(lines, category := "tablet")
{
	local
	global vars
	scale := vars.client.h/1440
	If (MarketTablets_Category(lines) != category)
		Return 0
	; Recognise the compact empty form, including blank numeric inputs and Any rarity.
	positions := {"type filters": 243, "item category": 288, "item level": 329, "item rarity": 288, "item quality": 329
		, "equipment filters": 373, "requirements": 419, "endgame filters": 466, "miscellaneous": 513
		, "trade filters": 560, "stat filters": 610, "add stat filter": 652, "add stat group": 695}
	For text, y in positions
	{
		line := MarketTablets_Find(lines, text)
		If !line || Abs(line.y-y*scale) > 12*scale
			Return 0
	}
	name := 0, rarity := 0, buttons := groups := 0
	For _, line in lines
	{
		If line.y < 176*scale || line.y > 1070*scale
			Continue
		key := MarketTablets_Key(line.text)
		If RegExMatch(key, "^[a-z]?searchitems$") && line.x < 100*scale
			name := 1
		Else If !RegExMatch(key, "^(typefilters|itemcategory|itemlevel|itemrarity|itemquality|equipmentfilters|requirements|endgamefilters|miscellaneous|tradefilters|statfilters|addstatfilter|addstatgroup|instantbuyout|any|tablet|min|max|v)$")
			Return 0
		If (key = "addstatfilter")
			buttons++
		If (key = "addstatgroup")
			groups++
		For _, word in line.words
			If MarketTablets_Key(word.text) = "any" && word.x > 650*scale && word.x < 790*scale && Abs(word.y-288*scale) < 12*scale
				rarity := 1
	}
	Return name && rarity && buttons = 1 && groups = 1
}

MarketTablets_Needle(name)
{
	local
	global vars
	static needles := {}, height
	If (height != vars.client.h)
	{
		For _, bitmap in needles
			Gdip_DisposeImage(bitmap)
		needles := {}, height := vars.client.h
	}
	If !needles.HasKey(name)
	{
		source := Gdip_CreateBitmapFromFile(A_ScriptDir "\img\GUI\market-tablets-" name ".bmp")
		If (source <= 0)
			Return 0
		needles[name] := Gdip_ResizeBitmap(source, Round(Gdip_GetImageWidth(source)*height/1440), Round(Gdip_GetImageHeight(source)*height/1440), 1)
		Gdip_DisposeImage(source)
	}
	Return needles[name]
}

MarketTablets_SectionsOff(lines, bitmap := 0)
{
	local
	global vars, settings
	needle := MarketTablets_Needle("off"), scale := vars.client.h/1440, owned := !bitmap
	If owned
		bitmap := Gdip_BitmapFromHWND(vars.hwnd.poe_client, 1)
	If !needle || bitmap <= 0
	{
		If owned && bitmap > 0
			Gdip_DisposeImage(bitmap)
		Return 0
	}
	xOffset := settings.general.blackbars ? vars.client.x-vars.monitor.x : 0, empty := MarketTablets_Needle("values")
	; Dark placeholder text is often omitted by OCR. Prove the numeric fields are still blank.
	off := empty && Gdip_ImageSearch(bitmap, empty, matches, xOffset+Round(248*scale), Round(315*scale), xOffset+Round(852*scale), Round(360*scale), 35,, 1, 1) > 0
	For _, text in ["equipment filters", "requirements", "endgame filters", "miscellaneous", "trade filters"]
	{
		line := MarketTablets_Find(lines, text), y := line.y+line.h/2
		If !line || Gdip_ImageSearch(bitmap, needle, matches, xOffset+Round(808*scale), Round(y-22*scale), xOffset+Round(850*scale), Round(y+22*scale), 35,, 1, 1) < 1
			off := 0
	}
	If owned
		Gdip_DisposeImage(bitmap)
	Return off
}

MarketTablets_AddButton(bitmap := 0)
{
	local
	global vars, settings
	needle := MarketTablets_Needle("add"), scale := vars.client.h/1440, owned := !bitmap
	If owned
		bitmap := Gdip_BitmapFromHWND(vars.hwnd.poe_client, 1)
	If !needle || bitmap <= 0
	{
		If owned && bitmap > 0
			Gdip_DisposeImage(bitmap)
		Return 0
	}
	xOffset := settings.general.blackbars ? vars.client.x-vars.monitor.x : 0, button := ""
	If Gdip_ImageSearch(bitmap, needle, matches, xOffset+Round(320*scale), Round(240*scale), xOffset+Round(520*scale), Round(1070*scale), 35,, 1, 0) > 0
		For _, match in StrSplit(matches, "`n")
		{
			point := StrSplit(match, ",")
			If !button || point.2 > button.y
				button := {"x": point.1-xOffset, "y": point.2, "w": 137*scale, "h": 21*scale}
		}
	If owned
		Gdip_DisposeImage(bitmap)
	Return button
}

MarketTablets_FastResult(button)
{
	local
	global vars, settings
	scale := vars.client.h/1440, xOffset := settings.general.blackbars ? vars.client.x-vars.monitor.x : 0
	Loop, 5
	{
		If !MarketTablets_Ready()
			Return 0
		bitmap := Gdip_BitmapFromHWND(vars.hwnd.poe_client, 1)
		If (bitmap <= 0)
			Return 0
		bounds := MarketTablets_PopupBounds(bitmap, Round(button.y+button.h/2), scale, xOffset)
		Gdip_DisposeImage(bitmap)
		If IsObject(bounds)
			Return {"x": 30*scale, "y": bounds.1, "w": 400*scale, "h": bounds.2-bounds.1}
		Sleep 60
	}
	Return 0
}

MarketTablets_NextButton(previous)
{
	local
	global vars
	Loop, 5
	{
		If !MarketTablets_Ready()
			Return 0
		button := MarketTablets_AddButton()
		If button && button.y > previous.y+vars.client.h*0.012
			Return button
		Sleep 40
	}
	Return 0
}

MarketTablets_PhraseMatches(text, phrase)
{
	local
	key := MarketTablets_Key(text), matched := 0
	StringLower, phrase, phrase
	For _, token in StrSplit(RegExReplace(phrase, "[^a-z0-9 ]", " "), " ")
		If StrLen(token) >= 3
		{
			If !InStr(key, token)
				Return 0
			matched++
		}
	Return matched > 0
}

MarketTablets_VerifyBatch(lines, phrases, count, ByRef reason := "")
{
	local
	global vars
	reason := "", scale := vars.client.h/1440
	group := MarketTablets_Not(lines), button := MarketTablets_Find(lines, "add stat filter", 1), rows := [], added := []
	If !group || !button
	{
		reason := "NOT group or add control was not read"
		Return 0
	}
	; OCR sometimes omits the italic modifier type (notably Explicit on Gold).
	; Read the selected text column by position, excluding the value fields.
	For _, line in lines
		If line.y > group.y+group.h && line.y < button.y && line.x < 580*scale
		{
			row := line.Clone(), text := ""
			For _, word in row.words
				If word.x < 580*scale
					text .= (text ? " " : "") word.text
			row.text := text ? text : row.text
			row.text := RegExReplace(row.text, "i)^\s*exp[liu/]+c[liu/]+t\s*", "explicit ")
			position := 1
			While position <= rows.Count() && rows[position].y+rows[position].h/2 < row.y+row.h/2-9*scale
				position++
			previous := rows[position]
			If previous && Abs(previous.y+previous.h/2-row.y-row.h/2) < 9*scale
				previous.text := row.x < previous.x ? row.text " " previous.text : previous.text " " row.text
			Else rows.InsertAt(position, row)
		}
	If rows.Count() != count
	{
		reason := "OCR read " rows.Count() " of " count " selected rows"
		Return 0
	}
	For index, row in rows
	{
		If !MarketTablets_PhraseMatches(row.text, phrases[index])
		{
			reason := "modifier " index " did not match its saved phrase"
			Return 0
		}
		If MarketTablets_SameMod(row.text, added)
		{
			reason := "modifier " index " appears duplicated"
			Return 0
		}
		added.Push(row.text)
	}
	Return added
}

MarketTablets_BottomLines(lines)
{
	local
	global vars
	Loop, 5
	{
		button := MarketTablets_Find(lines, "add stat filter", 1), group := MarketTablets_Find(lines, "add stat group")
		If button && group && button.y < group.y && group.y-button.y < vars.client.h*0.08
			Return lines
		If (A_Index = 5) || !MarketTablets_Scroll(1, 6)
			Return []
		lines := MarketTablets_Scan()
	}
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
	If !MarketTablets_Clean(lines) || !MarketTablets_SectionsOff(lines)
	{
		; A dirty or unrecognised form needs a reset. Leave an already clean Tablet form alone.
		If !MarketTablets_Click({"x": vars.client.h*0.29, "y": vars.client.h*0.055, "w": 30, "h": 30})
			Return "Stopped: market closed or cancelled"
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
		If !MarketTablets_Clean(lines, "any") || !MarketTablets_SectionsOff(lines)
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
	}
	group := MarketTablets_Find(lines, "add stat group")
	If !MarketTablets_Click(group)
		Return "Stopped: Add Stat Group could not be located"
	; The verified empty form fixes this menu's location. Scan only the menu,
	; then only the new group, instead of the entire filter panel twice.
	lines := MarketTablets_Scan({"x": vars.client.h*0.39, "y": group.y-vars.client.h*0.03, "w": vars.client.h*0.205, "h": vars.client.h*0.20})
	choice := MarketTablets_Find(lines, "not")
	If !choice
		choice := MarketTablets_Find(MarketTablets_Scan(), "not")
	If !choice || (choice.x < vars.client.h*0.35) || !MarketTablets_Click(choice)
		Return "Stopped: NOT condition could not be located"
	; Include the previous Stats header: OCR can otherwise omit the short NOT label.
	lines := MarketTablets_Scan({"x": 0, "y": group.y-vars.client.h*0.073, "w": vars.client.h*0.595, "h": vars.client.h*0.174})
	If !MarketTablets_Not(lines)
		lines := MarketTablets_Scan()
	If !MarketTablets_Not(lines)
		Return "Stopped: NOT group was not verified"
	; The first four fit the standard compact form. Locate controls and prove a
	; single result using images, then verify all selected rows in one OCR scan.
	button := MarketTablets_AddButton(), fastCount := button && button.y > MarketTablets_Not(lines).y ? Min(4, phrases.Count()) : 0, added := []
	Loop, % fastCount
	{
		index := A_Index
		If !button || !MarketTablets_Click(button) || !MarketTablets_Paste(phrases[index])
			Return "Stopped at modifier " index ": add control unavailable or cancelled"
		candidate := MarketTablets_FastResult(button)
		If !candidate
			Return "Stopped at modifier " index ": phrase must return exactly one modifier"
		If !MarketTablets_Click(candidate)
			Return "Stopped: market closed or cancelled"
		nextButton := MarketTablets_NextButton(button)
		If !nextButton
			Return "Stopped at modifier " index ": next add control was not verified"
		button := nextButton
	}
	If fastCount
	{
		lines := MarketTablets_BottomLines(MarketTablets_Scan())
		added := MarketTablets_VerifyBatch(lines, phrases, fastCount, reason)
		If !IsObject(added)
			Return "Stopped: " reason
	}
	For index, phrase in phrases
	{
		If (index <= fastCount)
			Continue
		lines := MarketTablets_BottomLines(lines)
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
		lines := MarketTablets_BottomLines(MarketTablets_Scan())
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
