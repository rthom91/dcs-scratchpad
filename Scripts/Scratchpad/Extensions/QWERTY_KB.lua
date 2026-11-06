local KEY_W = 36
local KEY_H = 32
local GAP = 2
local ORIGIN_X = 0
local ORIGIN_Y = 0

local caps = false
local shiftMode = 0
local ctrl = false
local alt = false
local win = false
local overtype = false
local keyWidgets = {}

local rows = {
	{
		{ "`", "~" }, { "1", "!" }, { "2", "@" }, { "3", "#" }, { "4", "$" },
		{ "5", "%" }, { "6", "^" }, { "7", "&" }, { "8", "*" }, { "9", "(" },
		{ "0", ")" }, { "-", "_" }, { "=", "+" },
		{ id = "bksp", label = "Bksp", w = 2 },
	},
	{
		{ id = "tab", label = "Tab", w = 1.6 },
		{ "q" }, { "w" }, { "e" }, { "r" }, { "t" }, { "y" }, { "u" }, { "i" }, { "o" }, { "p" },
		{ "[", "{" }, { "]", "}" }, { "\\", "|", w = 1.4 },
	},
	{
		{ id = "caps", label = "Caps", w = 1.96 },
		{ "a" }, { "s" }, { "d" }, { "f" }, { "g" }, { "h" }, { "j" }, { "k" }, { "l" },
		{ ";", ":" }, { "'", "\"" },
		{ id = "enter", label = "Enter", w = 2.3 },
	},
	{
		{ id = "shift", label = "Shift", w = 2.55 },
		{ "z" }, { "x" }, { "c" }, { "v" }, { "b" }, { "n" }, { "m" },
		{ ",", "<" }, { ".", ">", w = 1.167 }, { "/", "?" },
		{ id = "shift2", label = "Shift", w = 2.55 },
	},
	{
		{ id = "ctrl", label = "Ctrl", w = 1.575 },
		{ id = "win", label = "Win", w = 1.6 },
		{ id = "alt", label = "Alt", w = 1.37 },
		{ id = "space", label = "Space", w = 6.31 },
		{ id = "alt2", label = "Alt", w = 1.37 },
		{ id = "win2", label = "Win", w = 1.6, stretch = false },
		{ id = "ctrl2", label = "Ctrl", w = 1.575 },
	},
	{
		{ id = "home", label = "Home", w = 2.55 },
		{ id = "end", label = "End", w = 1.6 },
		{ id = "left", label = "←", w = 1.02 },
		{ id = "up", label = "↑", w = 1.02 },
		{ id = "down", label = "↓", w = 1.02 },
		{ id = "right", label = "→", w = 1.03 },
		{ id = "ins", label = "Ins", w = 1.45 },
		{ id = "del", label = "Del", w = 1.45 },
		{ id = "pgup", label = "PgUp", w = 2.15 },
		{ id = "pgdn", label = "PgDn", w = 2.15, stretch = false },
	},
}

local function isLetter(ch)
	return type(ch) == "string" and #ch == 1 and ch:match("%a") ~= nil
end

local function shiftActive()
	return shiftMode > 0
end

local function currentChar(spec)
	if spec.id then
		return nil
	end
	local lower = spec[1]
	local upper = spec[2]
	if isLetter(lower) then
		if caps ~= shiftActive() then
			return lower:upper()
		end
		return lower:lower()
	end
	if shiftActive() and upper then
		return upper
	end
	return lower
end

local function buttonOf(item)
	return item.child and item.child.button
end

local function refreshLabels()
	for _, item in ipairs(keyWidgets) do
		local btn = buttonOf(item)
		if btn then
			local spec = item.spec
			if spec.id == "caps" then
				btn:setText(caps and "CAPS" or "Caps")
			elseif spec.id == "shift" or spec.id == "shift2" then
				if shiftMode == 2 then
					btn:setText("SHIFT*")
				elseif shiftMode == 1 then
					btn:setText("SHIFT")
				else
					btn:setText("Shift")
				end
			elseif spec.id == "ctrl" or spec.id == "ctrl2" then
				btn:setText(ctrl and "CTRL" or "Ctrl")
			elseif spec.id == "alt" or spec.id == "alt2" then
				btn:setText(alt and "ALT" or "Alt")
			elseif spec.id == "win" or spec.id == "win2" then
				btn:setText(win and "WIN" or "Win")
			elseif spec.id == "ins" then
				btn:setText(overtype and "OVR" or "Ins")
			elseif not spec.id then
				btn:setText(currentChar(spec))
			end
		end
	end
end

local function consumeSticky()
	local changed = false
	if shiftMode == 1 then
		shiftMode = 0
		changed = true
	end
	if ctrl then
		ctrl = false
		changed = true
	end
	if alt then
		alt = false
		changed = true
	end
	if win then
		win = false
		changed = true
	end
	if changed then
		refreshLabels()
	end
end

local function caret()
	local ta = getTextarea and getTextarea()
	if not ta then
		return nil
	end
	local l1, i1, l2, i2 = ta:getSelectionNew()
	if l2 < l1 or (l2 == l1 and i2 < i1) then
		l1, i1, l2, i2 = l2, i2, l1, i1
	end
	return ta, l1, i1, l2, i2
end

local function hasSelection(ta)
	if not ta then
		return false
	end
	local l1, i1, l2, i2 = ta:getSelectionNew()
	return not (l1 == l2 and i1 == i2)
end

local function lineLen(ta, line)
	local ok, len = pcall(function()
		return ta:getLineTextLength(line)
	end)
	if ok and type(len) == "number" then
		return len
	end
	return 0
end

local function lastLineIndex(ta)
	local t = ta:getText() or ""
	local n = 0
	for i = 1, #t do
		if t:byte(i) == 10 then
			n = n + 1
		end
	end
	return n
end

local function lineString(ta, line)
	local t = ta:getText() or ""
	local n = 0
	local start = 1
	for i = 1, #t do
		if t:byte(i) == 10 then
			if n == line then
				return t:sub(start, i - 1)
			end
			n = n + 1
			start = i + 1
		end
	end
	if n == line then
		return t:sub(start)
	end
	return ""
end

local function setCaret(ta, line, idx)
	if line < 0 then
		line = 0
	end
	local last = lastLineIndex(ta)
	if line > last then
		line = last
	end
	local len = lineLen(ta, line)
	if idx < 0 then
		idx = 0
	end
	if idx > len then
		idx = len
	end
	ta:setSelectionNew(line, idx, line, idx)
	ta:setFocused(true)
end

local function moveBy(dx, dy)
	local ta, line, idx = caret()
	if not ta then
		return
	end
	line = line + (dy or 0)
	if line < 0 then
		line = 0
		idx = 0
	end
	local last = lastLineIndex(ta)
	if line > last then
		line = last
		idx = lineLen(ta, line)
	end
	idx = idx + (dx or 0)
	if dx < 0 and idx < 0 then
		if line > 0 then
			line = line - 1
			idx = lineLen(ta, line)
		else
			idx = 0
		end
	elseif dx > 0 then
		local len = lineLen(ta, line)
		if idx > len then
			if line < last then
				line = line + 1
				idx = 0
			else
				idx = len
			end
		end
	end
	setCaret(ta, line, idx)
end

local function isWordChar(ch)
	return type(ch) == "string" and ch:match("[%w_]") ~= nil
end

local function moveWord(dir)
	local ta, line, idx = caret()
	if not ta then
		return
	end
	local last = lastLineIndex(ta)
	if dir > 0 then
		local s = lineString(ta, line)
		local len = #s
		if idx >= len then
			if line < last then
				setCaret(ta, line + 1, 0)
			end
			return
		end
		while idx < len and isWordChar(s:sub(idx + 1, idx + 1)) do
			idx = idx + 1
		end
		while idx < len and not isWordChar(s:sub(idx + 1, idx + 1)) do
			idx = idx + 1
		end
		setCaret(ta, line, idx)
	else
		if idx <= 0 then
			if line > 0 then
				setCaret(ta, line - 1, lineLen(ta, line - 1))
			end
			return
		end
		local s = lineString(ta, line)
		while idx > 0 and not isWordChar(s:sub(idx, idx)) do
			idx = idx - 1
		end
		while idx > 0 and isWordChar(s:sub(idx, idx)) do
			idx = idx - 1
		end
		setCaret(ta, line, idx)
	end
end

local function selectAll(ta)
	if not ta then
		return
	end
	local last = lastLineIndex(ta)
	ta:setSelectionNew(0, 0, last, lineLen(ta, last))
	ta:setFocused(true)
end

local function deleteWord(text, dir)
	local ta, line, idx = caret()
	if not ta then
		if dir < 0 then
			text:deleteBackward()
		elseif text.deleteForward then
			text:deleteForward()
		end
		return
	end
	local sl, si = line, idx
	moveWord(dir)
	local _, el, ei = caret()
	if dir < 0 then
		ta:setSelectionNew(el, ei, sl, si)
	else
		ta:setSelectionNew(sl, si, el, ei)
	end
	text:insert("")
end

local function deleteCurrentLine(text)
	local ta, line = caret()
	if not ta then
		return
	end
	local last = lastLineIndex(ta)
	if last == 0 then
		text:setText("")
		return
	end
	if line < last then
		ta:setSelectionNew(line, 0, line + 1, 0)
	else
		local prevLen = 0
		if line > 0 then
			prevLen = lineLen(ta, line - 1)
			ta:setSelectionNew(line - 1, prevLen, line, lineLen(ta, line))
		else
			ta:setSelectionNew(line, 0, line, lineLen(ta, line))
		end
	end
	text:insert("")
end

local function deleteToEndOfLine(text)
	local ta, line, idx = caret()
	if not ta then
		return
	end
	local len = lineLen(ta, line)
	if idx >= len then
		if text.deleteForward then
			text:deleteForward()
		end
		return
	end
	ta:setSelectionNew(line, idx, line, len)
	text:insert("")
end

local function handle(spec, text)
	local id = spec.id

	if id == "caps" then
		caps = not caps
		refreshLabels()
		return
	elseif id == "shift" or id == "shift2" then
		shiftMode = (shiftMode + 1) % 3
		refreshLabels()
		return
	elseif id == "ctrl" or id == "ctrl2" then
		ctrl = not ctrl
		refreshLabels()
		return
	elseif id == "alt" or id == "alt2" then
		alt = not alt
		refreshLabels()
		return
	elseif id == "win" or id == "win2" then
		win = not win
		refreshLabels()
		return
	elseif id == "ins" then
		overtype = not overtype
		refreshLabels()
		return
	end

	local ta = getTextarea and getTextarea()

	if id == "bksp" then
		if ctrl then
			deleteWord(text, -1)
		elseif alt then
			deleteCurrentLine(text)
		else
			text:deleteBackward()
		end
		consumeSticky()
		return
	elseif id == "del" then
		if ctrl then
			deleteWord(text, 1)
		elseif alt then
			deleteToEndOfLine(text)
		elseif text.deleteForward then
			text:deleteForward()
		else
			text:deleteBackward()
		end
		consumeSticky()
		return
	elseif id == "enter" or id == "nl" then
		if text.insertNewline then
			text:insertNewline()
		else
			text:insert("\n")
		end
		consumeSticky()
		return
	elseif id == "tab" then
		text:insert("\t")
		consumeSticky()
		return
	elseif id == "space" then
		text:insert(" ")
		consumeSticky()
		return
	elseif id == "clr" then
		text:setText("")
		consumeSticky()
		return
	elseif id == "left" then
		if ctrl or alt then
			moveWord(-1)
		elseif win then
			local cta, line = caret()
			if cta then
				setCaret(cta, line, 0)
			end
		else
			moveBy(-1, 0)
		end
		consumeSticky()
		return
	elseif id == "right" then
		if ctrl or alt then
			moveWord(1)
		elseif win then
			local cta, line = caret()
			if cta then
				setCaret(cta, line, lineLen(cta, line))
			end
		else
			moveBy(1, 0)
		end
		consumeSticky()
		return
	elseif id == "up" then
		if ctrl or win then
			moveBy(0, -10)
		else
			moveBy(0, -1)
		end
		consumeSticky()
		return
	elseif id == "down" then
		if ctrl or win then
			moveBy(0, 10)
		else
			moveBy(0, 1)
		end
		consumeSticky()
		return
	elseif id == "pgup" then
		moveBy(0, -10)
		consumeSticky()
		return
	elseif id == "pgdn" then
		moveBy(0, 10)
		consumeSticky()
		return
	elseif id == "home" then
		local cta, line = caret()
		if cta then
			if ctrl or alt or win then
				setCaret(cta, 0, 0)
			else
				setCaret(cta, line, 0)
			end
		end
		consumeSticky()
		return
	elseif id == "end" then
		local cta, line = caret()
		if cta then
			if ctrl or alt or win then
				local last = lastLineIndex(cta)
				setCaret(cta, last, lineLen(cta, last))
			else
				setCaret(cta, line, lineLen(cta, line))
			end
		end
		consumeSticky()
		return
	elseif id == "prevpage" then
		if ctrl then
			moveBy(0, -10)
		elseif prevPage then
			prevPage()
		end
		consumeSticky()
		return
	elseif id == "nextpage" then
		if ctrl then
			moveBy(0, 10)
		elseif nextPage then
			nextPage()
		end
		consumeSticky()
		return
	end

	local ch = currentChar(spec) or spec[1] or ""
	if ctrl and (ch == "a" or ch == "A") then
		if ta then
			selectAll(ta)
		end
		consumeSticky()
		return
	end

	if overtype and ta and not hasSelection(ta) then
		local _, line, idx = caret()
		if line and idx < lineLen(ta, line) then
			ta:setSelectionNew(line, idx, line, idx + 1)
		end
	end
	text:insert(ch)
	consumeSticky()
end

local TARGET_W = 566

local y = ORIGIN_Y
for _, row in ipairs(rows) do
	local x = ORIGIN_X
	for i, spec in ipairs(row) do
		local units = spec.w or 1
		local w = math.floor(units * KEY_W)
		local remain = TARGET_W - x
		if i == #row and spec.stretch ~= false then
			w = math.max(1, remain)
		elseif w > remain then
			w = math.max(1, remain)
		end
		local title = spec.label or spec[1]
		addButton(x, y, w, KEY_H, title, function(text)
			handle(spec, text)
		end)
		table.insert(keyWidgets, {
			spec = spec,
			child = panel[#panel],
		})
		x = x + w + GAP
	end
	y = y + KEY_H + GAP
end

local KP_W = 37
local KP_H = 29
local KP_GAP = 2
local kpStartX = TARGET_W + 8

local function addKp(x, y, w, h, title, onClick)
	addButton(x, y, w, h, title, onClick)
	if panel[#panel] then
		panel[#panel].isKeypad = true
	end
end

local function insertChar(ch)
	return function(text)
		text:insert(ch)
	end
end

local row = {}
for i = 0, 4 do
	row[i] = ORIGIN_Y + i * (KP_H + KP_GAP)
end
local wide = math.floor(KP_W * 1.7)
local tall = KP_H * 2 + KP_GAP
local row1W = wide + 4 * KP_W + 4 * KP_GAP

local function placeRow(y, labels, handlers, count)
	local gaps = (count - 1) * KP_GAP
	local wEach = math.floor((row1W - gaps) / count)
	local x = kpStartX
	for i = 1, count do
		local w = wEach
		if i == count then
			w = kpStartX + row1W - x
		end
		addKp(x, y, w, KP_H, labels[i], handlers[i])
		x = x + w + KP_GAP
	end
end

placeRow(row[0], {"°", "/", "*", "+", "-"}, {
	insertChar("°"), insertChar("/"), insertChar("*"), insertChar("+"), insertChar("-"),
}, 5)
placeRow(row[1], {"7", "8", "9", "N", "S"}, {
	insertChar("7"), insertChar("8"), insertChar("9"), insertChar("N"), insertChar("S"),
}, 5)
placeRow(row[2], {"4", "5", "6", "W", "E"}, {
	insertChar("4"), insertChar("5"), insertChar("6"), insertChar("W"), insertChar("E"),
}, 5)

local gaps = 4 * KP_GAP
local colW = math.floor((row1W - gaps) / 5)
local cols = {}
local colX = kpStartX
for i = 1, 5 do
	local w = colW
	if i == 5 then
		w = kpStartX + row1W - colX
	end
	cols[i] = { x = colX, w = w }
	colX = colX + w + KP_GAP
end

for i = 1, 3 do
	addKp(cols[i].x, row[3], cols[i].w, KP_H, tostring(i), insertChar(tostring(i)))
end

addKp(cols[4].x, row[3], cols[4].w, KP_H, ".", insertChar("."))
addKp(cols[5].x, row[3], cols[5].w, tall, "↩", function(text)
	if text.insertNewline then
		text:insertNewline()
	else
		text:insert("\n")
	end
end)
if panel[#panel] then
	panel[#panel].isKeypadEnter = true
end

local bsW = math.floor(wide * 0.95)
local botEnd = cols[5].x - KP_GAP
local remain = botEnd - kpStartX - bsW - KP_GAP
local each = math.floor((remain - KP_GAP) / 2)
local zeroX = kpStartX + bsW + KP_GAP
local spaceX = zeroX + each + KP_GAP
local spaceW = botEnd - spaceX
addKp(kpStartX, row[4], bsW, KP_H, "⌫", function(text)
	text:deleteBackward()
end)
addKp(zeroX, row[4], each, KP_H, "0", insertChar("0"))
addKp(spaceX, row[4], spaceW, KP_H, "␣", insertChar(" "))

log("QWERTY loaded.")
