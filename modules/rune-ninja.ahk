Init_Runeshape()
{
	local
	global vars, settings

	If !FileExist("ini" vars.poe_version "\rune-ninja.ini")
	{
		IniWrite, % settings.general.fSize + 2, % "ini" vars.poe_version "\rune-ninja.ini", settings, font-size
		IniWrite, % "1=""ix ,lx §1x ""`n2=""iox ,lox ,i0x ,l0x ,1ox §10x ""`n3=""greatwolfs§greatwolf's""`n4=""ofthe§of the""", % "ini" vars.poe_version "\rune-ninja.ini", autocorrect
	}

	settings.runeshaping := {"autocorrect": []}, ini := IniBatchRead("ini" vars.poe_version "\rune-ninja.ini")
	settings.runeshaping.fSize := ini.settings["font-size"]
	LLK_FontDimensions(settings.runeshaping.fSize, fHeight, fWidth), settings.runeshaping.fWidth := fWidth, settings.runeshaping.fHeight := fHeight
	settings.runeshaping.debug := (!Blank(check := ini.settings["enable trouble-shooting"]) ? check : 0)
	settings.runeshaping.colors_default := {"high": "00FF00", "stack": "FFFF00", "unknown": "FF8000"}
	settings.runeshaping.hold_ctrl := (!Blank(check := ini.settings["hold down ctrl-key"]) ? check : 0)
	index := LLK_HasVal(vars.imagesearch.search, "runeshaping", 1)
	If !Blank(index)
		If (settings.general.input_method = 2)
			vars.imagesearch.search[index] := "runeshaping2"
		Else vars.imagesearch.search[index] := "runeshaping"

	For key, val in settings.runeshaping.colors_default
		settings.runeshaping["color_" key] := (!Blank(check := ini.settings["color " key]) ? check : val)

	For index, val in ini.autocorrect
		settings.runeshaping.autocorrect[index] := StrSplit(val, "§")
	If !LLK_HasVal(settings.runeshaping.autocorrect, "greatwolfs", 1,,, 1)
		settings.runeshaping.autocorrect.InsertAt(3, ["greatwolfs", "greatwolf's"])
	If !LLK_HasVal(settings.runeshaping.autocorrect, "ofthe", 1,,, 1)
		settings.runeshaping.autocorrect.InsertAt(4, ["ofthe", "of the"])
}

Runeshape_OCR()
{
	local
	global vars, settings, JSON

	start := A_TickCount, cont := (settings.general.input_method = 2), vars.runeshaping := {"text": []}
	x := Round(vars.client.h * (cont ? 19/120 : 1/8)), y := Round(vars.client.h * (cont ? 23/96 : 11/80)), w := Round(vars.client.h * (cont ? 25/72 : 17/45)), h := Round(vars.client.h * 0.52)

	text := OCR_Start(x, y, w, h, (settings.runeshaping.debug ? "ALT" : ""), "runeshaping", (cont ? ["controller"] : ""))
	If !text
		Return

	While InStr(text, "  ")
		text := StrReplace(text, "  ", " ")
	Loop, Parse, text, % "`n", % "`r`t' "
	{
		line := A_LoopField, object := {}
		For index, array in settings.runeshaping.autocorrect
			Loop, Parse, % array.1, % ","
				line := StrReplace(line, A_LoopField, array.2,, 1)
		If RegexMatch(line, "i)\[1\]$")
			object.tier := 1, line := StrReplace(line, " [1]")
		If RegexMatch(line, "i)\d{1,2}x\s")
			object.stack := SubStr(line, 1, InStr(line, "x") - 1), line := SubStr(line, InStr(line, "x ") + 2)
		Else If InStr(line, "x ")
			object.stack := "?", line := SubStr(line, InStr(line, "x ") + 2)
		object.line := line, vars.runeshaping.text.Push(object)
	}
	Runeshape_GUI()
}

Runeshape_Price(price, stack, liquidity, timestamp, league, expected_league)
{
	local
	; Volume/value estimates item units, not distinct trades or available sell orders.
	; Do not promote thin markets to the green highest-value recommendation.
	If !IsNumber(price) || (price <= 0) || !IsNumber(timestamp) || (league != expected_league) || (LLK_TimeElapsed(timestamp) > 60)
		Return "???"
	values := StrSplit(liquidity, ",", " ")
	If !IsNumber(values.1) || (values.1 <= 0) || !IsNumber(values.2) || (values.2 < 0)
		Return "???"
	If (values.2 / values.1 < Max(10, stack))
		Return "low vol"
	Return price * stack
}

Runeshape_GUI()
{
	local
	global vars, settings
	static toggle := 0

	toggle := !toggle, GUI := vars.lootfilter.GUI := "runeshaping" toggle
	Gui, %GUI%: New, % "-DPIScale +LastFound -Caption +AlwaysOnTop +ToolWindow +E0x02000000 +E0x00080000 HWNDhwnd_runeshaping"
	Gui, %GUI%: Font, % "s" settings.runeshaping.fSize " cWhite", % vars.system.font
	Gui, %GUI%: Margin, 0, 0
	Gui, %GUI%: Color, % "Purple"
	WinSet, TransColor, Purple

	dBox := Round(vars.client.h * (2/45)) - 4, dBox2 := Round(vars.client.h * (3/40)) - 4, text := vars.runeshaping.text, prices := [], max_price := 0, liquidity := {}, minWidth := 8
	vars.hwnd.runeshaping := {"main": hwnd_runeshaping}

	For index, object in text
	{
		If vars.poe_version && (gem := Runeshape_GemReward(object.line))
		{
			league := settings.general.league, league := vars.leagues[league.1].trade[league.3]
			minWidth := 14, object.gemKey := league "|" gem.name "|" gem.level
			prices.Push(Runeshape_GemPrice(gem, league, object.gemKey))
			Continue
		}
		If RegexMatch(object.line, "thaumaturgic.flux.\(|\sore$")
			check := "expedition", Economy_Update(check)
		Else If RegExMatch(object.line, "i)uncut.*gem.\(")
			check := "uncutgems", Economy_Update(check)

		If (check_economy := LLK_HasVal(vars.economy.names, object.line)) || (check := LLK_HasKey(vars.stash, object.line,,,, 1))
		{
			If check_economy
			{
				ID := check_economy, check := LLK_HasKey(vars.economy, ID,,, 1, 1)
				For index, val in check
					If (val != "names")
						check := val
			}
			Else ID := vars.stash[check][object.line].ID
			check := (InStr(check, "runes") ? "runes" : (InStr(check, "currency") ? "currency" : check))
			Economy_Update(check)
			stack := (IsNumber(object.stack) ? object.stack : 1)
			If vars.poe_version
			{
				If !liquidity.HasKey(check)
				{
					ini := IniBatchRead("data\global\[stash-ninja] prices" vars.poe_version ".ini", check " liquidity")
					liquidity[check] := ini[check " liquidity"]
				}
				price := Runeshape_Price(vars.economy[check][ID], stack, liquidity[check][ID], liquidity[check].timestamp, liquidity[check].league, vars.economy[check].league)
			}
			Else price := vars.economy[check][ID] * stack
			If IsNumber(price)
				price := Round(price, 1), max_price := Max(max_price, price)
			Else If (price != "low vol")
				price := "???"
			prices.Push(price)
		}
		Else prices.Push("???")
		check := ""
	}

	For index, price in prices
	{
		hText := (text[index].tier ? dBox2 : dBox), fHeight := settings.runeshaping.fHeight, offset := (fHeight >= hText ? 0 : hText//2 - fHeight//2)
		Gui, %GUI%: Add, Text, % "HWNDpriceHwnd x0 y" (index = 1 ? offset : "+" offset + 4) " w" settings.runeshaping.fWidth * Max(minWidth, StrLen(StrReplace(Round(max_price, (max_price >= 1000 ? 0 : 1)), ".")) + 1) " 0x200 Right Border BackgroundTrans" (fHeight >= hText ? " h" hText : ""), % " " (IsNumber(price) ? Round(price, (price >= 1000 ? 0 : 1)) : price) " "
		text[index].priceHwnd := priceHwnd
		color := (!IsNumber(price) ? settings.runeshaping.color_unknown : (!IsNumber(text[index].stack) ? settings.runeshaping.color_stack : (price = max_price ? settings.runeshaping.color_high : "White")))
		Gui, %GUI%: Add, Progress, % "Disabled xp yp wp hp Border cBlack Background" color, 100
		Gui, %GUI%: Add, Text, % "Hidden xp yp-" offset " w2 h" hText
	}
	Gui, %GUI%: Show, % "NA x" vars.client.x + (Round(vars.client.h//2 * 1.01)) " y" vars.client.y + Round(vars.client.h * (settings.general.input_method = 2 ? 11/45 : 5/36))
	LLK_Overlay(hwnd_runeshaping, "show",, GUI)
}

; Exact-level skill rewards use trade asking prices, never currency-exchange rankings.
Runeshape_GemReward(line)
{
 local
 static names := {"conductive runes": "Conductive Runes", "repulsion": "Repulsion", "frostflame nova": "Frostflame Nova", "fragments of the past": "Fragments of the Past", "eternal march": "Eternal March", "detonate living": "Detonate Living"}
 If !RegExMatch(line, "i)^skill\s+level\s+(\d{1,2})\s*:\s*([a-z][a-z '’\-]+)$", match)
  Return 0
 If (match1 < 1 || match1 > 40)
  Return 0
 name := Trim(match2)
 Return {"name": names.HasKey(name) ? names[name] : name, "level": match1 + 0}
}

Runeshape_GemPrice(gem, league, key)
{
 local
 global vars
 If !IsObject(vars.runeshapeGems)
  vars.runeshapeGems := {"cache": {}, "queue": [], "pending": {}, "next": 0}
 state := vars.runeshapeGems
 If (league = "")
  Return "no league"
 If state.cache.HasKey(key) && (A_TickCount - state.cache[key].time < 900000)
  Return state.cache[key].text
 If !state.pending.HasKey(key)
  state.queue.Push({"gem": gem, "league": league, "key": key}), state.pending[key] := 1
 SetTimer, Runeshape_GemTick, 500
 Return "checking..."
}

Runeshape_GemQuery(gem)
{
 local
 ; Plain reward gems: exact level, zero quality, uncorrupted. Do not mix premium variants.
 Return {"query": {"status": {"option": "online"}, "type": gem.name, "filters": {"misc_filters": {"filters": {"gem_level": {"min": gem.level, "max": gem.level}, "quality": {"min": 0, "max": 0}, "corrupted": {"option": "false"}}}}}, "sort": {"price": "asc"}}
}

Runeshape_GemEstimate(results)
{
 local
 sellers := {}, groups := {}
 For _, entry in results
 {
  seller := entry.listing.account.name, price := entry.listing.price
  If (seller = "" || sellers.HasKey(seller) || price.amount <= 0 || price.type != "~price" && price.type != "~b/o")
   Continue
  currency := price.currency
  If !InStr("|exalted|divine|chaos|", "|" currency "|")
   Continue
  sellers[seller] := 1
  If !groups.HasKey(currency)
   groups[currency] := []
  groups[currency].Push(price.amount)
 }
 best := [], unit := ""
 For currency, values in groups
  If (values.Count() > best.Count())
   best := values, unit := currency
 If (best.Count() < 5)
  Return "low data"
 numbers := ""
 For _, value in best
  numbers .= value "`n"
 Sort, numbers, N
 sorted := StrSplit(Trim(numbers, "`n"), "`n"), n := sorted.Count()
 median := Mod(n, 2) ? sorted[(n + 1)//2] : (sorted[n//2] + sorted[n//2 + 1])/2
 Return "~" Round(median, 1) " " (unit = "exalted" ? "ex" : unit = "divine" ? "div" : "c")
}

Runeshape_GemTick()
{
 local
 global vars, settings, JSON
 state := vars.runeshapeGems
 If !IsObject(state)
  Return
 If state.request
 {
  Try done := state.request.WaitForResponse(0)
  Catch error
   done := 1
  If !done && A_TickCount - state.started < 15000
   Return
  status := 0, response := ""
  Try status := state.request.Status
  Try response := state.request.ResponseText
  retry := 0
  Try retry := state.request.GetResponseHeader("Retry-After") + 0
  ; Respect server limit windows, including requests from other tools on this IP.
  Try
  {
   limits := StrSplit(state.request.GetResponseHeader("X-Rate-Limit-Ip"), ",")
   usage := StrSplit(state.request.GetResponseHeader("X-Rate-Limit-Ip-State"), ",")
   For index, limit in limits
   {
    cap := StrSplit(limit, ":"), used := StrSplit(usage[index], ":")
    If (used.1 >= cap.1 - 1)
     retry := Max(retry, cap.2, used.3)
   }
  }
  If !done
   Try state.request.Abort()
  state.request := "", state.next := A_TickCount + Max(12000, retry * 1000)
  data := ""
  Try data := JSON.Load(response)
  If (status != 200 || !IsObject(data) || data.error)
  {
   state.next := A_TickCount + Max(60000, retry * 1000)
   Runeshape_GemFinish(status = 429 ? "rate limited" : "unavailable")
   Return
  }
  If (state.phase = "search")
  {
   If !data.result.Count()
    Runeshape_GemFinish("no listings")
   Else
   {
    ids := ""
    For index, id in data.result
    {
     If (index > 10)
      Break
     ids .= (ids = "" ? "" : ",") id
    }
    state.fetchURL := "https://www.pathofexile.com/api/trade2/fetch/" ids "?query=" data.id
    state.phase := "fetch"
   }
  }
  Else Runeshape_GemFinish(Runeshape_GemEstimate(data.result))
  Return
 }
 If (A_TickCount < state.next)
  Return
 If !state.current
 {
  If !state.queue.Count()
  {
   SetTimer, Runeshape_GemTick, Off
   Return
  }
  ; Do not continue sending a screenful of searches after the panel is closed.
  If !WinExist("ahk_id " vars.hwnd.runeshaping.main)
   Return
  state.current := state.queue.RemoveAt(1), state.phase := "search"
  visible := 0
  For _, row in vars.runeshaping.text
   If (row.gemKey = state.current.key)
    visible := 1
  If !visible
  {
   state.pending.Delete(state.current.key), state.current := ""
   Return
  }
 }
 current := state.current
 league := settings.general.league, league := vars.leagues[league.1].trade[league.3]
 If (league != current.league)
 {
  Runeshape_GemFinish("league changed")
  Return
 }
 Try
 {
  request := ComObjCreate("WinHttp.WinHttpRequest.5.1")
  request.SetTimeouts(5000, 5000, 5000, 10000)
  url := state.phase = "search" ? "https://www.pathofexile.com/api/trade2/search/poe2/" StrReplace(current.league, " ", "%20") : state.fetchURL
  request.Open(state.phase = "search" ? "POST" : "GET", url, true)
  request.SetRequestHeader("Content-Type", "application/json")
  request.SetRequestHeader("User-Agent", "Exile-UI/RuneshapeGemPrices (github.com/buivydas1-stack/Exile-UI)")
  request.Send(state.phase = "search" ? JSON.Dump(Runeshape_GemQuery(current.gem)) : "")
  state.request := request, state.started := A_TickCount
 }
 Catch error
 {
  state.next := A_TickCount + 60000
  Runeshape_GemFinish("unavailable")
 }
}

Runeshape_GemFinish(text)
{
 local
 global vars
 state := vars.runeshapeGems, key := state.current.key
 state.cache[key] := {"time": A_TickCount, "text": text}, state.pending.Delete(key), state.current := ""
 For _, row in vars.runeshaping.text
  If (row.gemKey = key && row.priceHwnd && WinExist("ahk_id " vars.hwnd.runeshaping.main))
   GuiControl,, % row.priceHwnd, % " " text " "
}
