return function(app)
	local S = app.state

	local Text = {}

	function Text.new()
		local c = {}
		setmetatable(c, {__index = Text})
		return c
	end

	function Text:getText()
		return S.textarea:getText()
	end

	local function markUnsaved()
		if app.window and app.window.updateSaveButton then
			app.window.updateSaveButton(true)
		elseif S.savePageBtn then
			S.savePageBtn:setText("Save")
		end
	end

	function Text:setText(text)
		S.textarea:setText(text)
		S.textarea:setSelectionNew(0, 0, 0, 0)
		S.textarea:setFocused(true)
		markUnsaved()
	end

	local function strLen(str)
		local skip = 0
		local len = 0
		for i = 1, #str do
			if skip == 0 then
				local b = str:byte(i)
				len = len + 1
				if b < 128 then
					-- one byte char
				elseif b < 224 then
					-- two byte char
					skip = 1
				elseif b < 240 then
					-- three byte char
					skip = 2
				elseif b < 248 then
					-- four byte char
					skip = 3
				end
			else
				skip = skip - 1
			end
		end
		return len
	end

	local function utf8LenAt(text, i)
		local b = text:byte(i)
		if not b or b < 128 then
			return 1
		elseif b < 224 then
			return 2
		elseif b < 240 then
			return 3
		else
			return 4
		end
	end

	local function visualLineCount()
		local ta = S.textarea
		if ta and ta.getLineCount then
			local ok, n = pcall(function()
				return ta:getLineCount()
			end)
			if ok and type(n) == "number" and n >= 0 then
				return n
			end
		end
		return nil
	end

	local function visualLineLength(line)
		local ta = S.textarea
		local count = visualLineCount()
		if count and line >= count then
			return 0
		end
		if not ta or not ta.getLineTextLength then
			return 0
		end
		local ok, n = pcall(function()
			return ta:getLineTextLength(line)
		end)
		if ok and type(n) == "number" and n >= 0 then
			return n
		end
		return 0
	end

	local function visualLineOrigin(text, line)
		local byte = 1
		local charOff = 0
		local limit = line
		local count = visualLineCount()
		if count and limit > count then
			limit = count
		end
		for i = 0, limit - 1 do
			local vis = visualLineLength(i)
			local consumed = 0
			while consumed < vis and byte <= #text do
				if text:byte(byte) == 10 then
					break
				end
				byte = byte + utf8LenAt(text, byte)
				consumed = consumed + 1
			end
			charOff = charOff + consumed
			if byte <= #text and text:byte(byte) == 10 then
				byte = byte + 1
				charOff = charOff + 1
			end
		end
		return byte, charOff
	end

	local function pointFromVisual(text, line, col)
		local byte, charOff = visualLineOrigin(text, line)
		local vis = visualLineLength(line)
		if col > vis then
			col = vis
		end
		if col < 0 then
			col = 0
		end
		local n = 0
		while n < col and byte <= #text do
			if text:byte(byte) == 10 then
				break
			end
			byte = byte + utf8LenAt(text, byte)
			n = n + 1
		end
		return charOff + n, byte - 1
	end

	local function visualFromLogical(text, charPos)
		if charPos < 0 then
			charPos = 0
		end
		local byte = 1
		local charOff = 0
		local line = 0
		local count = visualLineCount()
		local guard = count or 100000
		if guard < 1 then
			guard = 1
		end
		for _ = 1, guard do
			local vis = visualLineLength(line)
			if charPos <= charOff + vis then
				return line, charPos - charOff
			end
			local consumed = 0
			local startByte = byte
			while consumed < vis and byte <= #text do
				if text:byte(byte) == 10 then
					break
				end
				byte = byte + utf8LenAt(text, byte)
				consumed = consumed + 1
			end
			charOff = charOff + consumed
			if byte <= #text and text:byte(byte) == 10 then
				charOff = charOff + 1
				byte = byte + 1
				if charPos <= charOff then
					return line + 1, 0
				end
			elseif byte == startByte and vis == 0 then
				return line, 0
			end
			line = line + 1
			if count and line >= count then
				return count - 1, visualLineLength(count - 1)
			end
			if byte > #text and charOff >= charPos then
				return line, 0
			end
		end
		return line, 0
	end

	local function getSelection()
		local text = S.textarea:getText() or ""
		local lineStart, indexStart, lineEnd, indexEnd = S.textarea:getSelectionNew()
		lineStart = lineStart or 0
		indexStart = indexStart or 0
		lineEnd = lineEnd or lineStart
		indexEnd = indexEnd or indexStart

		if lineEnd < lineStart or (lineEnd == lineStart and indexEnd < indexStart) then
			lineStart, indexStart, lineEnd, indexEnd = lineEnd, indexEnd, lineStart, indexStart
		end

		local start, startByte = pointFromVisual(text, lineStart, indexStart)
		local end_, endByte = pointFromVisual(text, lineEnd, indexEnd)
		if end_ < start then
			start, end_ = end_, start
			startByte, endByte = endByte, startByte
		end
		return start, end_, startByte, endByte
	end

	local function setSelection(pos, len)
		local text = S.textarea:getText() or ""
		local textLen = strLen(text)
		pos = math.max(0, math.min(pos or 0, textLen))
		local lineStart, indexStart = visualFromLogical(text, pos)
		local lineEnd = lineStart
		local indexEnd = indexStart
		if len and len > 0 then
			local to = math.min(pos + len, textLen)
			lineEnd, indexEnd = visualFromLogical(text, to)
		end
		S.textarea:setSelectionNew(lineStart, indexStart, lineEnd, indexEnd)
	end

	function Text:insert(newText)
		if type(newText) ~= "string" then
			return
		end

		local text = S.textarea:getText()
		local start, end_, startByte, endByte = getSelection()

		S.textarea:setText(
			string.sub(text, 1, startByte) ..
			newText ..
			string.sub(text, endByte + 1, #text)
		)

		setSelection(start + strLen(newText))
		S.textarea:setFocused(true)
		markUnsaved()
	end

	function Text:insertBelow(newText)
		local text = S.textarea:getText()
		local start, end_, startByte, endByte = getSelection()
		local newPos = end_
		local nl = string.byte("\n")
		local skip = 0
		for i = endByte + 1, #text do
			if skip == 0 then
				local b = text:byte(i)
				if b == nl then
					break
				else
					newPos = newPos + 1

					if b < 128 then
						-- one byte char
					elseif b < 224 then
						-- two byte char
						skip = 1
					elseif b < 240 then
						-- three byte char
						skip = 2
					elseif b < 248 then
						-- four byte char
						skip = 3
					end
				end
			else
				skip = skip - 1
			end
		end

		setSelection(newPos)

		newText = "\n" .. newText
		self:insert(newText)
	end

	function Text:insertTop(newText)
		if type(newText) ~= "string" then
			return
		end

		setSelection(0)
		self:insert(newText .. "\n")
	end

	function Text:insertBottom(newText)
		if type(newText) ~= "string" then
			return
		end

		local text = self:getText()
		setSelection(strLen(text))
		if strLen(newText) > 0 then
			self:insert("\n\n" .. newText .. "\n")
		end
	end

	function Text:insertNewline()
		local ta = S.textarea
		if not ta then
			return
		end
		local start = getSelection()
		self:insert("\n")
		local after = getSelection()
		if after <= start then
			local content = ta:getText() or ""
			if content:sub(-1) ~= "\n" then
				content = content .. "\n"
			end
			ta:setText(content .. ".")
			setSelection(strLen(content) + 1)
			self:deleteBackward()
			setSelection(strLen(ta:getText() or ""))
		end
		ta:setFocused(true)
	end

	function Text:deleteBackward()
		local start, end_ = getSelection()

		if start == end_ then
			setSelection(start - 1, 1)
		end
		self:insert("")
	end

	function Text:deleteForward()
		local start, end_ = getSelection()

		if start == end_ then
			setSelection(start, 1)
		end
		self:insert("")
	end

	return {
		Text = Text,
		strLen = strLen,
		getSelection = getSelection,
		setSelection = setSelection,
	}
end
