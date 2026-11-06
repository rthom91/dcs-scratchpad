local Button = require("Button")
local DialogLoader = require("DialogLoader")
local dxgui = require("dxgui")
local lfs = require("lfs")
local Panel = require("Panel")
local Skin = require("Skin")

return function(app)
	local S = app.state
	S.windowSkinHidden = Skin.windowSkinChatMin()

	local createScratchpadWindow, createCrosshairWindow
	local setVisible, handleResize, handleMove, updateCoordsMode
	local blur, show, hide, saveCurrentPage, updateSaveButton, flushSizeSave

	function setVisible(b)
		S.window:setVisible(b)
	end

	local function panelSize(panel)
		local w, h = panel:getSize()
		if panel._layoutW and (not w or w < panel._layoutW) then
			w = panel._layoutW
		end
		if panel._layoutH and (not h or h < panel._layoutH) then
			h = panel._layoutH
		end
		if panel._isKeyboard and panel._layoutH then
			local keypadOnly = S.config and S.config.showKeypad == true and S.config.showKeyboard ~= true
			if keypadOnly then
				local scale = panel._keypadHeightScale or 1.33
				local base = panel._keypadLayoutH or panel._layoutH
				h = math.floor(base * scale + 0.5)
			else
				h = panel._layoutH
			end
		end
		return w, h
	end

	local function setButtonFontSize(button, fontSize)
		if not button or not button.getSkin then
			return
		end
		local sk = button:getSkin()
		if sk and sk.skinData and sk.skinData.states and sk.skinData.states.released and sk.skinData.states.released[1] and sk.skinData.states.released[1].text then
			sk.skinData.states.released[1].text.fontSize = fontSize
			button:setSkin(sk)
		end
	end

	local function scaleKeyboardToWidth(width)
		local panel = S.keyboardPanel
		if not panel or not panel._scaleChildren or not panel._layoutW or panel._layoutW <= 0 then
			return
		end

		local qwertyOn = S.config and S.config.showKeyboard == true
		local keypadOn = S.config and S.config.showKeypad == true
		local qwertyW = panel._qwertyLayoutW or panel._layoutW
		local totalW = panel._layoutW

		local kpMinX, kpMaxX = math.huge, 0
		for _, child in pairs(panel._scaleChildren) do
			if child.isKeypad and child.x and child.w then
				kpMinX = math.min(kpMinX, child.x)
				kpMaxX = math.max(kpMaxX, child.x + child.w)
			end
		end
		local kpNaturalW = (kpMaxX > kpMinX) and (kpMaxX - kpMinX) or 0

		panel._keypadHeightScale = nil
		if qwertyOn and keypadOn then
			local scale = width / totalW
			for _, child in pairs(panel._scaleChildren) do
				if child.button and child.x and child.w then
					child.button:setVisible(true)
					child.button:setBounds(
						math.floor(child.x * scale + 0.5),
						child.y or 0,
						math.max(1, math.floor(child.w * scale + 0.5)),
						child.h or 32
					)
					-- Normal font when QWERTY is also visible
					if child.isKeypad then
						setButtonFontSize(child.button, child._baseFontSize or 14)
					end
				end
			end
		elseif qwertyOn then
			local scale = width / qwertyW
			for _, child in pairs(panel._scaleChildren) do
				if child.button then
					if child.isKeypad then
						child.button:setVisible(false)
					else
						child.button:setVisible(true)
						if child.x and child.w then
							child.button:setBounds(
								math.floor(child.x * scale + 0.5),
								child.y or 0,
								math.max(1, math.floor(child.w * scale + 0.5)),
								child.h or 32
							)
						end
					end
				end
			end
		elseif keypadOn and kpNaturalW > 0 then
			local widthScale = 1.10
			local targetW = math.floor(width * 0.32 * widthScale)
			local scale = targetW / kpNaturalW
			local offsetX = width - targetW
			local heightScale = 1.33
			panel._keypadHeightScale = heightScale
			for _, child in pairs(panel._scaleChildren) do
				if child.button then
					if child.isKeypad and child.x and child.w then
						child.button:setVisible(true)
						local relX = child.x - kpMinX
						local baseH = child.h or 32
						child.button:setBounds(
							math.floor(offsetX + relX * scale + 0.5),
							math.floor((child.y or 0) * heightScale + 0.5),
							math.max(1, math.floor(child.w * scale + 0.5)),
							math.max(1, math.floor(baseH * heightScale + 0.5))
						)
						local baseFs = child._baseFontSize or 14
						setButtonFontSize(child.button, math.floor(baseFs * 1.05 + 0.5))
					else
						child.button:setVisible(false)
					end
				end
			end
		else
			for _, child in pairs(panel._scaleChildren) do
				if child.button then
					child.button:setVisible(false)
				end
			end
		end
	end

	local function layoutToolbar(width)
		width = width or 260
		local gap = 3
		local x = 0
		local function place(btn, w, y, useGap)
			if not btn then
				return
			end
			btn:setBounds(x, y or 0, w, 20)
			x = x + w + (useGap == nil and gap or useGap)
		end

		place(S.savePageBtn, 55)
		place(S.crosshairCheckbox, 20, 1)
		place(S.insertCoordsBtn, 44)
		place(S.briefingBtn, 60)
		place(S.clearPageBtn, 44)
		place(S.extensionsBtn, 36)

		local right = math.max(width, 420)
		local kpW = 40
		local abcW = 40
		local nlW = 32
		if S.keypadToggleBtn then
			S.keypadToggleBtn:setBounds(right - kpW, 0, kpW, 20)
		end
		if S.keyboardToggleBtn then
			S.keyboardToggleBtn:setBounds(right - kpW - gap - abcW, 0, abcW, 20)
		end
		if S.numLockButton then
			S.numLockButton:setBounds(right - kpW - gap - abcW - gap - nlW, 0, nlW, 20)
		end
	end

	local SIDEBAR_W = 36

	local function layoutSidebar(textH)
		local panel = S.sidebar
		if not panel or not S.window then
			return
		end
		local winX, winY = S.window:getPosition()
		local winW = S.window:getSize()
		local h = math.max(textH or 0, 70)
		panel:setBounds(winX + winW, winY + 20, SIDEBAR_W, h)
		panel:setVisible(not S.isHidden)
		local btnH = 28
		local gap = 4
		local y = 4
		if S.nextButton then
			S.nextButton:setBounds(2, y, SIDEBAR_W - 4, btnH)
			S.nextButton:setVisible(true)
		end
		if S.prevButton then
			S.prevButton:setBounds(2, y + btnH + gap, SIDEBAR_W - 4, btnH)
			S.prevButton:setVisible(true)
		end
		local y2 = y + (btnH + gap) * 2
		if S.addPageBtn then
			S.addPageBtn:setBounds(2, y2, SIDEBAR_W - 4, btnH)
			S.addPageBtn:setVisible(true)
		end
		if S.deletePageBtn then
			S.deletePageBtn:setBounds(2, y2 + btnH + gap, SIDEBAR_W - 4, btnH)
			S.deletePageBtn:setVisible(true)
		end
		local y3 = y2 + (btnH + gap) * 2
		if S.helpBtn then
			S.helpBtn:setBounds(2, y3, SIDEBAR_W - 4, btnH)
			S.helpBtn:setVisible(true)
		end
	end

	local function keyboardEnabled()
		return S.config and S.config.showKeyboard == true
	end

	local function keypadEnabled()
		return S.config and S.config.showKeypad == true
	end

	local function panelCountsForLayout(panel)
		if panel._isKeyboard and not (keyboardEnabled() or keypadEnabled()) then
			return false
		end
		if panel._extId and panel._extEnabled == false then
			return false
		end
		return true
	end

	local function applyKeyboardVisibility()
		local on = keyboardEnabled() or keypadEnabled()
		if S.keyboardPanel then
			S.keyboardPanel:setVisible(on and not S.isHidden)
		end
		if S.keyboardToggleBtn then
			S.keyboardToggleBtn:setText(keyboardEnabled() and "ABC*" or "ABC")
		end
	end

	local function toggleKeyboard()
		if not S.config then
			return
		end
		S.config.showKeyboard = not keyboardEnabled()
		app.config.save()
		applyKeyboardVisibility()
		if S.window and not S.isHidden then
			S._preserveTextHeight = true
			handleResize(S.window)
			S._preserveTextHeight = false
		end
	end

	local function applyKeypadVisibility()
		local on = keypadEnabled()
		if S.keypadToggleBtn then
			S.keypadToggleBtn:setText(on and "123*" or "123")
		end
		applyKeyboardVisibility()
	end

	local function toggleKeypad()
		if not S.config then
			return
		end
		S.config.showKeypad = not keypadEnabled()
		app.config.save()
		applyKeypadVisibility()
		if S.window and not S.isHidden then
			S._preserveTextHeight = true
			handleResize(S.window)
			S._preserveTextHeight = false
		end
	end

	local EDGE_PX = 8
	local MIN_W = 450
	local MIN_H = 180 -- Text area + toolbar
	local TITLE_H = 20
	local MIN_TEXT_H = 180 -- Text area

	local function visiblePanelsHeight()
		local total = 0
		for i = 1, #S.panels do
			local panel = S.panels[i]
			if panelCountsForLayout(panel) then
				local _, h = panelSize(panel)
				total = total + (h or 0)
			end
		end
		return total
	end

	local function minWindowHeight()
		return TITLE_H + MIN_TEXT_H + visiblePanelsHeight()
	end

	local function rememberGeom(x, y, w, h)
		S._winX, S._winY, S._winW, S._winH = x, y, w, h
	end

	local function hitResizeEdge(px, py, winX, winY, winW, winH)
		if px < winX - 2 or px > winX + winW + 2 or py < winY - 2 or py > winY + winH + 2 then
			return nil
		end
		local left = px - winX <= EDGE_PX
		local right = winX + winW - px <= EDGE_PX
		local top = py - winY <= EDGE_PX
		local bottom = winY + winH - py <= EDGE_PX
		if top and left then return "nw" end
		if top and right then return "ne" end
		if bottom and left then return "sw" end
		if bottom and right then return "se" end
		if top then return "n" end
		if bottom then return "s" end
		if left then return "w" end
		if right then return "e" end
		return nil
	end

	local function applyEdgeResize(self, x, y)
		local edge = S._edgeDrag
		if not edge then
			return x, y, self:getSize()
		end
		local w, h = S._anchorW, S._anchorH
		local minH = minWindowHeight()
		if edge:find("n", 1, true) then
			h = S._anchorBottom - y
			if h < minH then
				h = minH
				y = S._anchorBottom - h
			end
		else
			y = S._anchorY
		end
		if edge:find("w", 1, true) then
			w = S._anchorRight - x
			if w < MIN_W then
				w = MIN_W
				x = S._anchorRight - w
			end
		else
			x = S._anchorX
		end
		if edge:find("s", 1, true) then
			local mouseY = y
			y = S._anchorY
			h = mouseY - S._anchorY
			if h < minH then
				h = minH
			end
		end
		if edge:find("e", 1, true) then
			local mouseX = x
			x = S._anchorX
			w = mouseX - S._anchorX
			if w < MIN_W then
				w = MIN_W
			end
		end
		return x, y, w, h
	end

	local function applyOppositeEdgeLock(self, finalW, finalH)
		local x, y = self:getPosition()
		if S._edgeDrag then
			x, y = applyEdgeResize(self, x, y)
		elseif S._winX ~= nil and S._winW ~= nil and math.abs(x - S._winX) > 1 then
			x = S._winX + S._winW - finalW
		elseif S._winY ~= nil and S._winH ~= nil and math.abs(y - S._winY) > 1 then
			y = S._winY + S._winH - finalH
		end
		local screenWidth, screenHeight = dxgui.GetScreenSize()
		if x < 0 then x = 0 end
		if y < 0 then y = 0 end
		if x + finalW > screenWidth then x = screenWidth - finalW end
		if y + finalH > screenHeight then y = screenHeight - finalH end
		self:setPosition(x, y)
		return x, y
	end

	function handleResize(self)
		-- Scratchpad is only minimized, not destroyed. A size callback
		-- while hidden must not force the keyboard/toolbar visible.
		if S.isHidden and not S._layoutWhileHidden then
			return
		end

		local newWidth, newHeight = self:getSize()

		-- prevent too small size that cannot be properly interacted with anymore
		if newWidth < MIN_W then
			newWidth = MIN_W
		end

		local panelsHeight = visiblePanelsHeight()
		local minWinHeight = minWindowHeight()
		if newHeight < minWinHeight then
			newHeight = minWinHeight
		end

		local _, taH = S.textarea:getSize()
		local textH

		if S._preserveTextHeight and taH and taH >= MIN_TEXT_H then
			textH = taH
			newHeight = TITLE_H + textH + panelsHeight
		else
			textH = newHeight - TITLE_H - panelsHeight
			if textH < MIN_TEXT_H then
				newHeight = TITLE_H + MIN_TEXT_H + panelsHeight
				textH = MIN_TEXT_H
			end
		end

		S.textarea:setSize(newWidth, textH)
		layoutSidebar(textH)

		local y = textH
		for i = 1, #S.panels do
			local panel = S.panels[i]
			if panelCountsForLayout(panel) then
				local w, h = panelSize(panel)
				if panel == S.window.Box then
					w = newWidth
					h = 20
					layoutToolbar(newWidth)
				elseif panel._isKeyboard then
					w = newWidth
					scaleKeyboardToWidth(newWidth)
					h = select(2, panelSize(panel))
				end
				panel:setPosition(0, y)
				if w and h and w > 0 and h > 0 then
					panel:setSize(w, h)
				end
				panel:setVisible(not S.isHidden)
				y = y + (h or 0)
			else
				panel:setVisible(false)
			end
		end

		if newWidth < MIN_W then
			newWidth = MIN_W
		end
		local needH = TITLE_H + textH + panelsHeight
		if newHeight < needH then
			newHeight = needH
		end
		if newHeight < MIN_H then
			newHeight = MIN_H
			local extra = newHeight - TITLE_H - panelsHeight - textH
			if extra > 0 then
				textH = textH + extra
				S.textarea:setSize(newWidth, textH)
				layoutSidebar(textH)
			end
		end

		self:setSize(newWidth, newHeight)
		local x, y = applyOppositeEdgeLock(self, newWidth, newHeight)
		rememberGeom(x, y, newWidth, newHeight)
		if S.extensionsBox and S.extensionsBox:getVisible() and S.extensionsBtn then
			local toolbar = S.window and S.window.Box
			local boxX, boxY = 0, 0
			if toolbar and toolbar.getPosition then
				boxX, boxY = toolbar:getPosition()
			end
			local bx, by = S.extensionsBtn:getPosition()
			S.extensionsBox:setPosition((x or 0) + (boxX or 0) + (bx or 0), (y or 0) + (boxY or 0) + (by or 0) + TITLE_H + 24)
		end
		if S.helpBox and S.helpBox:getVisible() and S.helpBtn and S.sidebar then
			local sx, sy = S.sidebar:getPosition()
			local bx, by = S.helpBtn:getPosition()
			S.helpBox:setPosition((sx or 0) + (bx or 0) + SIDEBAR_W + 4, (sy or 0) + (by or 0))
		end
		local prev = S.config.windowSize or {}
		if prev.w ~= newWidth or prev.h ~= newHeight then
			S.config.windowSize = {w = newWidth, h = newHeight}
			S._sizeDirty = true
			S._sizeSaveWait = 1
		end
	end

	function handleMove(self)
		local x, y = self:getPosition()
		local w, h = self:getSize()

		if S._edgeDrag then
			x, y, w, h = applyEdgeResize(self, x, y)
			if S._inEdgeResize then
				self:setPosition(x, y)
				rememberGeom(x, y, w, h)
				layoutSidebar(select(2, S.textarea:getSize()))
				return
			end
			S._inEdgeResize = true
			self:setPosition(x, y)
			self:setSize(w, h)
			handleResize(self)
			S._inEdgeResize = false
			if app.config.setPosition then
				app.config.setPosition({ x = x, y = y })
			end
			return
		end

		-- Top-left edge resize also fires a move. Size change is owned by handleResize so the opposite edge stays put.
		if S._winW and S._winH and (math.abs(w - S._winW) > 1 or math.abs(h - S._winH) > 1) then
			return
		end
		local screenWidth, screenHeight = dxgui.GetScreenSize()

		-- prevent moving the Scratchpad out of the viewport
		if x < 0 then
			x = 0
		end
		if y < 0 then
			y = 0
		end
		if x + w > screenWidth then
			x = screenWidth - w
		end
		if y + h > screenHeight then
			y = screenHeight - h
		end

		self:setPosition(x, y)
		rememberGeom(x, y, w, h)
		layoutSidebar(select(2, S.textarea:getSize()))
		if S.extensionsBox and S.extensionsBox:getVisible() and S.extensionsBtn then
			local toolbar = S.window and S.window.Box
			local boxX, boxY = 0, 0
			if toolbar and toolbar.getPosition then
				boxX, boxY = toolbar:getPosition()
			end
			local bx, by = S.extensionsBtn:getPosition()
			S.extensionsBox:setPosition((x or 0) + (boxX or 0) + (bx or 0), (y or 0) + (boxY or 0) + (by or 0) + TITLE_H + 24)
		end
		if S.helpBox and S.helpBox:getVisible() and S.helpBtn and S.sidebar then
			local sx, sy = S.sidebar:getPosition()
			local bx, by = S.helpBtn:getPosition()
			S.helpBox:setPosition((sx or 0) + (bx or 0) + SIDEBAR_W + 4, (sy or 0) + (by or 0))
		end
		if app.config.setPosition then
			app.config.setPosition({ x = x, y = y })
		end
	end

	function updateCoordsMode()
		local canInsert = S.inMission and Export.LoIsOwnshipExportAllowed()
		if S.crosshairCheckbox then
			S.crosshairCheckbox:setVisible(true)
		end
		if S.insertCoordsBtn then
			S.insertCoordsBtn:setVisible(true)
		end
		if S.crosshairWindow then
			S.crosshairWindow:setVisible(canInsert and S.crosshairCheckbox and S.crosshairCheckbox:getState())
		end
	end

	local function clearPendingNewline()
		S._expectNewlineFrom = nil
		S._expectNewlineFrames = nil
	end

	local function rememberCaret()
		if not S.textarea or S.isHidden or S._expectNewlineFrom ~= nil then
			return
		end
		local line, col = S.textarea:getSelectionNew()
		S._stableLine = line
		S._stableCol = col
	end

	local function flushPendingNewline()
		if S._expectNewlineFrom == nil then
			rememberCaret()
			return
		end
		if not S.textarea then
			return
		end
		local line = S.textarea:getSelectionNew()
		if line ~= nil and line > S._expectNewlineFrom then
			clearPendingNewline()
			rememberCaret()
			return
		end
		S._expectNewlineFrames = (S._expectNewlineFrames or 1) - 1
		if S._expectNewlineFrames > 0 then
			return
		end
		clearPendingNewline()
		app.text.Text.new():insertNewline()
		updateSaveButton(true)
		rememberCaret()
	end

	function updateSaveButton(force)
		if not S.savePageBtn or not S.textarea then
			return
		end
		if not force then
			S._saveBtnTicks = (S._saveBtnTicks or 0) + 1
			if S._saveBtnTicks < 8 then
				return
			end
			S._saveBtnTicks = 0
		end
		local current = S.textarea:getText() or ""
		local dirty = (S.lastSavedText ~= current)
		local label = dirty and "Save" or "Saved"
		if S._saveBtnLabel ~= label then
			S.savePageBtn:setText(label)
			S._saveBtnLabel = label
		end
	end

	function flushSizeSave()
		if not S._sizeDirty then
			return
		end
		S._sizeSaveWait = (S._sizeSaveWait or 0) - 1
		if S._sizeSaveWait > 0 then
			return
		end
		S._sizeDirty = false
		app.config.save()
	end

	function saveCurrentPage()
		if not S.textarea then
			return
		end
		local text = S.textarea:getText()
		app.pages.save(S.currentPage, text, true)
		S.lastSavedText = text
		S._saveBtnTicks = 8
		updateSaveButton(true)
	end

	function blur()
		-- Unfocus only
		if S.textarea then
			S.textarea:setFocused(false)
		end
		app.keyboard.unlock()
		updateSaveButton(true)
	end

	function show()
		if S.window == nil then
			local status, err = pcall(createScratchpadWindow)
			if not status then
				net.log("[Scratchpad] Error creating window: " .. tostring(err))
				return
			end
		end

		if S.window == nil then
			return
		end

		S.window:setVisible(true)
		S.window:setSkin(S.windowDefaultSkin)
		S.textarea:setVisible(true)
		S.window:setHasCursor(true)
		S.isHidden = false
		for _, panel in pairs(S.panels) do
			if panel._isKeyboard then
				panel:setVisible(keyboardEnabled() or keypadEnabled())
			else
				panel:setVisible(true)
			end
		end
		applyKeyboardVisibility()
		applyKeypadVisibility()

		updateCoordsMode()
		if S.insertCoordsBtn then
			S.insertCoordsBtn:setVisible(true)
		end
		if S.crosshairCheckbox then
			S.crosshairCheckbox:setVisible(true)
		end
		if S.sidebar then
			S.sidebar:setVisible(true)
		end
		handleResize(S.window)
	end

	function hide()
		-- Cannot simply hide the window, as this would destroy it
		-- window.setVisible(false)
		S.isHidden = true
		S._edgeDrag = nil
		S._inEdgeResize = nil

		S.window:setSkin(S.windowSkinHidden)
		S.textarea:setVisible(false)
		S.window:setHasCursor(false)
		for _, panel in pairs(S.panels) do
			panel:setVisible(false)
		end
		if S.sidebar then
			S.sidebar:setVisible(false)
		end
		if S.extensionsBox then
			S.extensionsBox:setVisible(false)
		end
		if S.helpBox then
			S.helpBox:setVisible(false)
		end

		saveCurrentPage()
		blur()

		if S.crosshairWindow then
			S.crosshairWindow:setVisible(false)
		end

		if app.config.setPosition then
			local px, py = S.window:getPosition()
			app.config.setPosition({ x = px, y = py })
		end
		if S._sizeDirty then
			S._sizeDirty = false
			S._sizeSaveWait = 0
			app.config.save()
		end
	end

	local function spawnDialog(filename)
		local bases = {
			lfs.writedir() .. "Scripts\\Scratchpad\\Dialogs\\",
			lfs.writedir() .. "Scripts\\Scratchpad\\",
		}
		local lastErr
		for i = 1, #bases do
			local path = bases[i] .. filename
			local ok, dlg = pcall(DialogLoader.spawnDialogFromFile, path)
			if ok and dlg then
				app.log("Loaded dialog " .. path)
				return dlg
			end
			lastErr = dlg
		end
		error("Could not load " .. filename .. ": " .. tostring(lastErr))
	end

	function createCrosshairWindow()
		if S.crosshairWindow ~= nil then
			return
		end

		S.crosshairWindow = spawnDialog("CrosshairWindow.dlg")

		local screenWidth, screenHeight = dxgui.GetScreenSize()
		local x = screenWidth / 2 - 4
		local y = screenHeight / 2 - 4
		S.crosshairWindow:setBounds(math.floor(x), math.floor(y), 8, 8)

		app.log("Crosshair window created.")
	end

	local boundHotkey = nil
	local function toggleHotkey()
		if S.isHidden == true then
			show()
		else
			hide()
		end
	end

	local function applyFontSize()
		if not S.textarea or not S.config then
			return
		end
		local fs = S.config.fontSize
		local skin = S.textarea:getSkin()
		if skin and skin.skinData and skin.skinData.states
			and skin.skinData.states.released
			and skin.skinData.states.released[1]
			and skin.skinData.states.released[1].text then
			skin.skinData.states.released[1].text.fontSize = fs
			S.textarea:setSkin(skin)
		end
	end

	local function rebindHotkey()
		if not S.window then
			return
		end
		local newHotkey = S.config and S.config.hotkey
		if boundHotkey == newHotkey then
			return
		end
		if boundHotkey and boundHotkey ~= "" and boundHotkey ~= "NONE" then
			pcall(function()
				S.window:removeHotKeyCallback(boundHotkey, toggleHotkey)
			end)
		end
		if newHotkey and newHotkey ~= "" and newHotkey ~= "NONE" then
			S.window:addHotKeyCallback(newHotkey, toggleHotkey)
		end
		boundHotkey = newHotkey
	end

	function createScratchpadWindow()
		if S.window ~= nil then
			return
		end

		createCrosshairWindow()

		S.window = spawnDialog("ScratchpadWindow.dlg")

		S.windowDefaultSkin = S.window:getSkin()
		S.textarea = S.window.ScratchpadEditBox
		local box = S.window.Box
		S.crosshairCheckbox = box.ScratchpadCrosshairCheckBox
		S.insertCoordsBtn = box.ScratchpadInsertCoordsButton
		if S.insertCoordsBtn and S.insertCoordsBtn.setText then
			S.insertCoordsBtn:setText("+L/L")
		end
		S.prevButton = box.ScratchpadPrevButton
		S.nextButton = box.ScratchpadNextButton
		local prevButton = S.prevButton
		local nextButton = S.nextButton

		S.sidebar = spawnDialog("SidebarWindow.dlg")
		S.sidebar:setBounds(0, 0, SIDEBAR_W, 70)
		pcall(function() S.sidebar:setText("") end)
		pcall(function() S.sidebar:setHasCursor(true) end)
		pcall(function()
			local sk = S.sidebar:getSkin()
			if sk and sk.skinData and sk.skinData.params then
				sk.skinData.params.headerHeight = 0
				if sk.skinData.skins then
					sk.skinData.skins.header = nil
				end
				S.sidebar:setSkin(sk)
			end
		end)
		-- Use the sidebar dialog's own buttons so the main title bar is untouched.
		if S.sidebar.PagePrevButton then
			S.prevButton = S.sidebar.PagePrevButton
			prevButton = S.prevButton
		end
		if S.sidebar.PageNextButton then
			S.nextButton = S.sidebar.PageNextButton
			nextButton = S.nextButton
		end
		if box.ScratchpadPrevButton then
			box.ScratchpadPrevButton:setVisible(false)
		end
		if box.ScratchpadNextButton then
			box.ScratchpadNextButton:setVisible(false)
		end
		S.sidebar:setVisible(false)

		box._layoutW = 260
		box._layoutH = 20
		box:setBounds(0, 0, 260, 20)
		table.insert(S.panels, box)

		applyFontSize()

		S.textarea:addFocusCallback(
			function(self)
				if self:getFocused() then
					app.keyboard.lock()
					updateSaveButton(true)
				else
					blur()
				end
			end
		)

		function S.textarea:onChange()
			updateSaveButton(true)
		end
		local function flashQwertyButton(btn)
			if not btn or not btn.getSkin or not btn.setSkin then
				return
			end
			local skin = btn:getSkin()
			if not skin or not skin.skinData or not skin.skinData.states then
				return
			end
			local states = skin.skinData.states
			if not states.pressed or not states.released then
				return
			end
			if btn._flashOrig then
				btn._flashUntil = (S._flashFrame or 0) + 10
				return
			end
			btn._flashOrig = states.released
			states.released = states.pressed
			btn:setSkin(skin)
			btn._flashUntil = (S._flashFrame or 0) + 10
			S._flashingButtons = S._flashingButtons or {}
			S._flashingButtons[btn] = true
		end

		local function unicodeChar(unicode)
			if type(unicode) == "number" then
				if unicode > 0 and unicode < 128 then
					return string.char(unicode)
				end
				if unicode > 0 and utf8 and utf8.char then
					local ok, ch = pcall(utf8.char, unicode)
					if ok then
						return ch
					end
				end
				return nil
			end
			if type(unicode) == "string" and unicode ~= "" then
				return unicode
			end
			return nil
		end

		local function isRightModifier(k)
			return k:find("right", 1, true)
				or k:sub(1, 1) == "r" and (k:find("shift", 1, true) or k:find("ctrl", 1, true) or k:find("control", 1, true) or k:find("alt", 1, true) or k:find("win", 1, true) or k:find("meta", 1, true))
				or k:find("_r", 1, true)
				or k:find("gr", 1, true)
		end

		local function modifierButton(map, k)
			local right = isRightModifier(k)
			if k:find("shift", 1, true) then
				return (right and map["shift_r"]) or map["shift"]
			end
			if k:find("caps", 1, true) or k:find("capital", 1, true) then
				return map["caps"]
			end
			if k:find("ctrl", 1, true) or k:find("control", 1, true) then
				return (right and map["ctrl_r"]) or map["ctrl"]
			end
			if k:find("alt", 1, true) then
				return (right and map["alt_r"]) or map["alt"]
			end
			if k:find("win", 1, true) or k:find("meta", 1, true) or k:find("super", 1, true) or k:find("gui", 1, true) then
				return (right and map["win_r"]) or map["win"]
			end
			return nil
		end

		local function isPageUp(k)
			local compact = k:gsub("[%s_%-]", "")
			return compact == "pageup" or compact == "pgup" or compact == "prior"
		end

		local function isPageDown(k)
			local compact = k:gsub("[%s_%-]", "")
			return compact == "pagedown" or compact == "pgdn" or compact == "pgdown" or compact == "next"
		end

		local function keypadKey(k)
			local digit = k:match("^%[(%d)%]$")
				or k:match("kp[_%s%-]?(%d)")
				or k:match("numpad[_%s%-]?(%d)")
				or k:match("num[_%s%-]?(%d)")
				or k:match("keypad[_%s%-]?(%d)")
			if digit then
				return digit
			end
			if k == "[.]" or k == "kp_decimal" or k == "kp_period" or k == "kp_dot" or k == "numpad." or k == "numpad_decimal" or k == "num." then
				return "."
			end
			if k == "[+]" or k == "kp_add" or k == "kp_plus" or k == "numpad+" or k == "numpad_add" or k == "num+" then
				return "+"
			end
			if k == "[*]" or k == "kp_multiply" or k == "kp_mul" or k == "kp_asterisk" or k == "numpad*" or k == "numpad_multiply" or k == "num*" then
				return "*"
			end
			if k == "[/]" or k == "kp_divide" or k == "kp_div" or k == "kp_slash" or k == "numpad/" or k == "numpad_divide" or k == "num/" then
				return "/"
			end
			if k == "[-]" or k == "kp_subtract" or k == "kp_minus" or k == "numpad-" or k == "numpad_subtract" or k == "num-" then
				return "-"
			end
			local compactEnter = k:gsub("[%s_%-%[%]]", "")
			local looksKeypad = k:find("kp", 1, true) or k:find("numpad", 1, true)
				or k:find("keypad", 1, true) or k:sub(1, 1) == "["
			if k == "[enter]" or k == "[return]" or k == "kp_enter" or k == "kp enter"
				or k == "numpad enter" or k == "numpad_enter" or k == "kp_return"
				or k == "numenter" or k == "num enter"
				or compactEnter == "kpenter" or compactEnter == "numpadenter"
				or compactEnter == "keypadenter" or compactEnter == "numenter"
				or (looksKeypad and (compactEnter:find("enter", 1, true) or compactEnter:find("return", 1, true))) then
				return "↩"
			end
			local compact = k:gsub("[%s_%-]", "")
			if compact == "numlock" or compact == "numlk" then
				return nil
			end
			return nil
		end

		local function flashQwertyKey(keyName, unicode)
			local k = string.lower(tostring(keyName or ""))
			-- Page Up/Down flash the sidebar arrows and the keyboard PgUp/PgDn keys.
			if isPageUp(k) then
				if S.nextButton then
					flashQwertyButton(S.nextButton)
				end
				local pg = S.qwertyKeyMap and (S.qwertyKeyMap["pgup"] or S.qwertyKeyMap["pageup"])
				if pg then
					flashQwertyButton(pg)
				end
				if app.pages and app.pages.next then
					app.pages.next()
				end
				return
			end
			if isPageDown(k) then
				if S.prevButton then
					flashQwertyButton(S.prevButton)
				end
				local pg = S.qwertyKeyMap and (S.qwertyKeyMap["pgdn"] or S.qwertyKeyMap["pagedown"])
				if pg then
					flashQwertyButton(pg)
				end
				if app.pages and app.pages.prev then
					app.pages.prev()
				end
				return
			end
			-- Physical numpad keys flash the virtual numpad, not the main row.
			local kpDigit = keypadKey(k)
			local compact = k:gsub("[%s_%-%[%]]", "")
			local isEnterName = compact == "enter" or compact == "return"
				or compact:find("enter", 1, true) or compact:find("return", 1, true)
			local looksKeypad = k:find("kp", 1, true) or k:find("numpad", 1, true)
				or k:find("keypad", 1, true) or k:find("num", 1, true)
				or (k:sub(1, 1) == "[" and k ~= "[" and k ~= "]")

			-- Keypad enter
			if kpDigit == "↩" then
				local kpBtn = S.keypadEnterBtn
				if not kpBtn and S.keypadKeyMap then
					kpBtn = S.keypadKeyMap["↩"] or S.keypadKeyMap["enter"]
				end
				if kpBtn then
					flashQwertyButton(kpBtn)
				end
				return
			end

			-- Specific keypad key (digit, operator, decimal)
			if kpDigit and S.keypadKeyMap then
				local btn = S.keypadKeyMap[kpDigit] or S.keypadKeyMap[string.lower(kpDigit)]
				if btn then
					flashQwertyButton(btn)
					return
				end
			end

			-- Main enter (also flash keypad enter if present)
			if isEnterName then
				local kpBtn = S.keypadEnterBtn
				if not kpBtn and S.keypadKeyMap then
					kpBtn = S.keypadKeyMap["↩"] or S.keypadKeyMap["enter"]
				end
				if kpBtn then
					flashQwertyButton(kpBtn)
				end
				local mainEnter = S.qwertyKeyMap and (S.qwertyKeyMap["enter"] or S.qwertyKeyMap["return"])
				if mainEnter then
					flashQwertyButton(mainEnter)
				end
				return
			end

			-- Don't fall through for unrecognized keypad keys
			if looksKeypad then
				return
			end
			local map = S.qwertyKeyMap
			if not map then
				return
			end
			local btn = map[k]
			if not btn then
				local ch = unicodeChar(unicode)
				if ch then
					btn = map[string.lower(ch)] or map[ch]
				end
			end
			if not btn then
				btn = modifierButton(map, k)
			end
			if btn then
				flashQwertyButton(btn)
			end
		end

		S.textarea:addKeyDownCallback(function(self, keyName, unicode)
			flashQwertyKey(keyName, unicode)
			if keyName == "escape" then
				clearPendingNewline()
				blur()
				return
			end
			local k = string.lower(tostring(keyName or ""))
			local isEnter = k:find("return", 1, true) or k:find("enter", 1, true)
			if not isEnter then
				clearPendingNewline()
				return
			end
			local line, col = self:getSelectionNew()
			local idleAtCol0 = (col == 0 and S._stableCol == 0 and S._stableLine == line)
			if col ~= 0 or idleAtCol0 then
				S._expectNewlineFrom = line
				S._expectNewlineFrames = 3
			end
		end)

		-- setup button and checkbox callbacks
		S.crosshairCheckbox:addChangeCallback(
			function(self)
				updateCoordsMode()
			end
		)
		S.insertCoordsBtn:addMouseUpCallback(
			function(self)
				if not S.crosshairCheckbox or not S.crosshairCheckbox:getState() then
					app.text.Text.new():insertTop("Crosshair not enabled.")
					updateSaveButton(true)
					return
				end
				local unit = DCS.getPlayerUnitType and DCS.getPlayerUnitType() or ""
				if unit == "" then
					app.text.Text.new():insertTop("No module detected. Please load into an aircraft.")
					updateSaveButton(true)
					return
				end
				app.coords.insert()
			end
		)

		prevButton:setVisible(true)
		nextButton:setVisible(true)
		prevButton:addMouseUpCallback(
			function(self)
				app.pages.prev()
				if S.textarea and S.textarea.setFocused then
					S.textarea:setFocused(true)
				end
			end
		)
		nextButton:addMouseUpCallback(
			function(self)
				app.pages.next()
				if S.textarea and S.textarea.setFocused then
					S.textarea:setFocused(true)
				end
			end
		)

		if S.config.hotkeyPrevPage then
			S.window:addHotKeyCallback(
				S.config.hotkeyPrevPage,
				function()
					if S.isHidden == false then
						app.pages.prev()
					end
				end
			)
		end

		if S.config.hotkeyNextPage then
			S.window:addHotKeyCallback(
				S.config.hotkeyNextPage,
				function()
					if S.isHidden == false then
						app.pages.next()
					end
				end
			)
		end

		-- add extensions
		local buttonSkin = prevButton:getSkin()

		local addBtn = Button.new("P+")
		addBtn:setBounds(2, 66, SIDEBAR_W - 4, 28)
		addBtn:setSkin(buttonSkin)
		addBtn:addMouseUpCallback(function()
			app.pages.add()
			if S.textarea and S.textarea.setFocused then
				S.textarea:setFocused(true)
			end
		end)
		S.sidebar:insertWidget(addBtn)
		S.addPageBtn = addBtn

		local delBtn = Button.new("P-")
		delBtn:setBounds(2, 100, SIDEBAR_W - 4, 28)
		delBtn:setSkin(buttonSkin)
		delBtn:addMouseUpCallback(function()
			app.pages.delete()
			if S.textarea and S.textarea.setFocused then
				S.textarea:setFocused(true)
			end
		end)
		S.sidebar:insertWidget(delBtn)
		S.deletePageBtn = delBtn

		local helpBtn = Button.new("?")
		helpBtn:setBounds(2, 134, SIDEBAR_W - 4, 28)
		helpBtn:setSkin(buttonSkin)
		S.sidebar:insertWidget(helpBtn)
		S.helpBtn = helpBtn

		local helpLines = {
			"Help",
			"",
			"Pages",
			"  ← / →    next / previous page",
			"  P+       add page",
			"  P-        delete page",
			"  CLR     clear current page",
			"  Save    save current page",
			"",
			"Tools",
			"  Box      enable/disable coordinate crosshair",
			"  +L/L     insert coordinates from F10 map",
			"  +Brief  insert current mission briefing",
			"  NL       toggle numlock",
			"  ABC     show/hide keyboard",
			"  123     show/hide keypad",
			"  Ext      show/hide extension buttons",
			"",
		}
		local Static = require("Static")
		local Window = require("Window")
		local helpRowH = 16
		local helpW = 320
		local helpH = #helpLines * helpRowH + 8
		local helpWin = Window.new(0, 0, helpW, helpH, "")
		pcall(function()
			helpWin:setText("")
			helpWin:setHasCursor(true)
			helpWin:setDraggable(false)
			helpWin:setResizable(false)
			if helpWin.setTransparentForUserInput then
				helpWin:setTransparentForUserInput(false)
			end
			if helpWin.setZOrder then
				helpWin:setZOrder(1000)
			end
			local sk = Skin.windowSkin and Skin.windowSkin()
			if not sk and S.window and S.window.getSkin then
				sk = S.window:getSkin()
			end
			if sk and sk.skinData then
				if sk.skinData.params then
					sk.skinData.params.headerHeight = 0
				end
				if sk.skinData.skins then
					sk.skinData.skins.header = nil
				end
				local released = sk.skinData.states and sk.skinData.states.released and sk.skinData.states.released[1]
				if released then
					local Bkg = require("Bkg")
					released.bkg = Bkg.solid("0x202020ff")
				end
				helpWin:setSkin(sk)
			end
		end)
		for i, line in ipairs(helpLines) do
			local st = Static.new(line)
			st:setBounds(6, 4 + (i - 1) * helpRowH, helpW - 12, helpRowH)
			helpWin:insertWidget(st)
		end
		helpWin:setVisible(false)
		S.helpBox = helpWin

		helpBtn:addMouseUpCallback(function()
			if not S.helpBox then
				return
			end
			local show = not S.helpBox:getVisible()
			if show and S.helpBtn and S.sidebar then
				local sx, sy = S.sidebar:getPosition()
				local bx, by = S.helpBtn:getPosition()
				S.helpBox:setPosition((sx or 0) + (bx or 0) + SIDEBAR_W + 4, (sy or 0) + (by or 0))
			end
			S.helpBox:setVisible(show)
		end)

		local clrBtn = Button.new("CLR")
		clrBtn:setBounds(240, 0, 50, 20)
		clrBtn:setSkin(buttonSkin)
		clrBtn:addMouseUpCallback(function()
			if S.textarea then
				S.textarea:setText("")
				updateSaveButton(true)
			end
		end)
		box:insertWidget(clrBtn)
		S.clearPageBtn = clrBtn

		local nlBtn = Button.new("NL")
		nlBtn:setBounds(0, 0, 32, 20)
		nlBtn:setSkin(buttonSkin)
		nlBtn:addMouseUpCallback(function()
			if _G.ScratchpadToggleNumLock then
				_G.ScratchpadToggleNumLock()
			end
		end)
		box:insertWidget(nlBtn)
		S.numLockButton = nlBtn

		local briefingBtn = Button.new("+Brief")
		briefingBtn:setBounds(0, 0, 60, 20)
		briefingBtn:setSkin(buttonSkin)
		briefingBtn:addMouseUpCallback(function()
			local desc = DCS.getMissionDescription and DCS.getMissionDescription() or ""
			if desc == "" then
				app.text.Text.new():insertTop("Mission briefing missing or not available.")
				updateSaveButton(true)
				return
			end
			app.text.Text.new():insertTop(desc)
		end)
		box:insertWidget(briefingBtn)
		S.briefingBtn = briefingBtn

		local saveBtn = Button.new("Save")
		saveBtn:setBounds(290, 0, 55, 20)
		saveBtn:setSkin(buttonSkin)
		saveBtn:addMouseUpCallback(function()
			saveCurrentPage()
		end)
		box:insertWidget(saveBtn)
		S.savePageBtn = saveBtn

		layoutToolbar(420)

		for extid, container in pairs(S.extensions) do
			local panel = Panel.new()
			local panelWidth = 0
			local panelHeight = 0
			for idx, child in pairs(container.children) do
				if child.x + child.w > panelWidth then
					panelWidth = child.x + child.w
				end
				if child.y + child.h > panelHeight then
					panelHeight = child.y + child.h
				end

				local button = Button.new(child.title)
				button:setBounds(child.x, child.y, child.w, child.h)
				button:setSkin(buttonSkin)
				-- Store base font size for later adjustment
				local sk = button:getSkin()
				if sk and sk.skinData and sk.skinData.states and sk.skinData.states.released and sk.skinData.states.released[1] and sk.skinData.states.released[1].text then
					child._baseFontSize = sk.skinData.states.released[1].text.fontSize or 14
				else
					child._baseFontSize = 14
				end
				-- Needs to be mouse up for the refocus of the textarea to work
				button:addMouseUpCallback(function(self)
					child.onClick(app.text.Text.new())
				end)
				container.children[idx].button = button
				panel:insertWidget(button)
			end
			panel._layoutW = panelWidth
			panel._layoutH = panelHeight
			panel._scaleChildren = container.children
			panel:setBounds(0, 0, panelWidth, panelHeight)
			panel._extId = extid

			local name = tostring(extid or "")
			if string.find(string.lower(name), "qwerty", 1, true) then
				panel._isKeyboard = true
				S.keyboardPanel = panel
				panel:setVisible(false)
				local qwertyMax = 0
				local keypadMaxH = 0
				local keyMap = {}
				local keyMapX = {}
				for _, child in pairs(container.children) do
					if not child.isKeypad and child.x and child.w then
						qwertyMax = math.max(qwertyMax, child.x + child.w)
					end
					if child.isKeypad and child.y and child.h then
						keypadMaxH = math.max(keypadMaxH, child.y + child.h)
					end
					local title = string.lower(tostring(child.title or ""))
					if title ~= "" and child.button then
						local x = child.x or 0
						-- Main keyboard is to the left of the keypad. Keep the
						-- leftmost button for a title so keypad duplicates lose.
						if keyMapX[title] == nil or x < keyMapX[title] then
							keyMap[title] = child.button
							keyMapX[title] = x
						end
					end
				end
				local aliases = {
					back = "bksp",
					backspace = "bksp",
					enter = "enter",
					["return"] = "enter",
					tab = "tab",
					space = "space",
					left = "←",
					right = "→",
					up = "↑",
					down = "↓",
					home = "home",
					["end"] = "end",
					delete = "del",
					insert = "ins",
					capslock = "caps",
					lshift = "shift",
					rshift = "shift",
					lctrl = "ctrl",
					rctrl = "ctrl",
					lalt = "alt",
					ralt = "alt",
					lwin = "win",
					rwin = "win",
				}
				-- index each character key by its raw character.
				-- only fill gaps, do not replace a button already chosen above.
				for _, child in pairs(container.children) do
					local title = tostring(child.title or "")
					if title ~= "" and child.button and #title == 1 then
						local x = child.x or 0
						local lower = string.lower(title)
						if keyMapX[lower] == nil or x < keyMapX[lower] then
							keyMap[title] = child.button
							keyMap[lower] = child.button
							keyMapX[lower] = x
						end
					end
				end
				for src, dst in pairs(aliases) do
					local target = keyMap[dst] or keyMap[string.lower(dst)]
					if target and not keyMap[src] then
						keyMap[src] = target
					end
				end
				-- Split paired modifiers into left (base) and right (_r) by x position
				local function splitPair(name)
					local buttons = {}
					for _, child in pairs(container.children) do
						if not child.isKeypad and child.button then
							local title = string.lower(tostring(child.title or ""))
							if title == name then
								table.insert(buttons, { x = child.x or 0, btn = child.button })
							end
						end
					end
					table.sort(buttons, function(a, b) return a.x < b.x end)
					if buttons[1] then
						keyMap[name] = buttons[1].btn
					end
					if buttons[2] then
						keyMap[name .. "_r"] = buttons[2].btn
					elseif buttons[1] then
						keyMap[name .. "_r"] = buttons[1].btn
					end
				end
				splitPair("shift")
				splitPair("ctrl")
				splitPair("alt")
				splitPair("win")

				-- Point right-side key names at the right virtual button
				local rightNames = {
					["right shift"] = "shift_r",
					["right ctrl"] = "ctrl_r",
					["right alt"] = "alt_r",
					["right win"] = "win_r",
				}
				for src, dst in pairs(rightNames) do
					if keyMap[dst] then
						keyMap[src] = keyMap[dst]
					end
				end

				-- letters and digits already mapped by title
				S.qwertyKeyMap = keyMap
				local kpMap = {}
				for _, child in pairs(container.children) do
					if child.isKeypad and child.button then
						local title = tostring(child.title or "")
						if title ~= "" then
							kpMap[string.lower(title)] = child.button
						end
						if child.isKeypadEnter or title == "↩" then
							S.keypadEnterBtn = child.button
							kpMap["↩"] = child.button
							kpMap["enter"] = child.button
							kpMap["return"] = child.button
						end
					end
				end
				S.keypadKeyMap = kpMap
				if not S.numLockButton then
					for _, child in pairs(container.children) do
						if child.isNumLock and child.button then
							S.numLockButton = child.button
							break
						end
					end
				end

				local user32
				pcall(function()
					local ffi = require("ffi")
					ffi.cdef[[
						typedef struct {
							unsigned long type;
							unsigned short wVk;
							unsigned short wScan;
							unsigned long dwFlags;
							unsigned long time;
							uintptr_t dwExtraInfo;
							unsigned int pad0;
							uintptr_t pad1;
						} INPUT;
						unsigned int SendInput(unsigned int nInputs, INPUT* pInputs, int cbSize);
					]]
					user32 = ffi.load("user32")
				end)
				local VK_NUMLOCK = 0x90

				_G.ScratchpadToggleNumLock = function()
					local now = os.clock()
					if S._numLockToggleAt and (now - S._numLockToggleAt) < 0.45 then
						return
					end
					S._numLockToggleAt = now
					if not user32 then
						os.execute('powershell -NoProfile -WindowStyle Hidden -Command "(New-Object -ComObject WScript.Shell).SendKeys(\'{NUMLOCK}\')"')
						return
					end
					pcall(function()
						local EXT = 0x0001
						local UP = 0x0002
						local inputs = ffi.new("INPUT[2]")
						inputs[0].type = 1
						inputs[0].wVk = VK_NUMLOCK
						inputs[0].wScan = 0x45
						inputs[0].dwFlags = EXT
						inputs[1].type = 1
						inputs[1].wVk = VK_NUMLOCK
						inputs[1].wScan = 0x45
						inputs[1].dwFlags = EXT + UP
						user32.SendInput(2, inputs, ffi.sizeof(inputs[0]))
					end)
				end

				panel._qwertyLayoutW = qwertyMax > 0 and qwertyMax or panel._layoutW
				panel._keypadLayoutH = keypadMaxH > 0 and keypadMaxH or panel._layoutH
			end

			S.window:insertWidget(panel)
			table.insert(S.panels, panel)
		end

		if S.keyboardPanel then
			local kbBtn = Button.new("ABC")
			kbBtn:setBounds(0, 0, 40, 20)
			kbBtn:setSkin(buttonSkin)
			kbBtn:addMouseUpCallback(function()
				toggleKeyboard()
			end)
			box:insertWidget(kbBtn)
			S.keyboardToggleBtn = kbBtn
			kbBtn:setVisible(true)

			local kpBtn = Button.new("123")
			kpBtn:setBounds(0, 0, 40, 20)
			kpBtn:setSkin(buttonSkin)
			kpBtn:addMouseUpCallback(function()
				toggleKeypad()
			end)
			box:insertWidget(kpBtn)
			S.keypadToggleBtn = kpBtn
			kpBtn:setVisible(true)
		end

		applyKeyboardVisibility()
		applyKeypadVisibility()

		local extIgnore = {
			["ns430"] = true,
		}
		if not S.config.extensionsHidden then
			S.config.extensionsHidden = {}
		end
		local extList = {}
		for _, panel in ipairs(S.panels) do
			if panel._extId and not panel._isKeyboard then
				local label = tostring(panel._extId):gsub("%.lua$", "")
				local ignored = extIgnore[panel._extId] or extIgnore[label] or extIgnore[label .. ".lua"]
				if ignored then
					S.config.extensionsHidden[panel._extId] = true
				elseif not S.config.extensionsHidden[panel._extId] then
					table.insert(extList, { id = panel._extId, label = label, panel = panel })
				end
			end
		end
		table.sort(extList, function(a, b) return a.label < b.label end)
		if next(S.config.extensionsHidden) then
			app.config.save()
		end

		if #extList > 0 then
			local CheckBox = require("CheckBox")
			local Window = require("Window")
			if not S.config.extensionsEnabled then
				S.config.extensionsEnabled = {}
			end

			local rowH = 24
			local boxW = 200
			local boxH = #extList * rowH + 8
			local extWin = Window.new(0, 0, boxW, boxH, "")
			pcall(function()
				extWin:setText("")
				extWin:setHasCursor(true)
				extWin:setDraggable(false)
				extWin:setResizable(false)
				if extWin.setTransparentForUserInput then
					extWin:setTransparentForUserInput(false)
				end
				if extWin.setZOrder then
					extWin:setZOrder(1000)
				end
				local sk = Skin.windowSkin and Skin.windowSkin()
				if not sk and S.window and S.window.getSkin then
					sk = S.window:getSkin()
				end
				if sk and sk.skinData then
					if sk.skinData.params then
						sk.skinData.params.headerHeight = 0
					end
					if sk.skinData.skins then
						sk.skinData.skins.header = nil
					end
					local released = sk.skinData.states and sk.skinData.states.released and sk.skinData.states.released[1]
					if released then
						local Bkg = require("Bkg")
						released.bkg = Bkg.solid("0x202020ff")
					end
					extWin:setSkin(sk)
				end
			end)
			for i, item in ipairs(extList) do
				local enabled = S.config.extensionsEnabled[item.id]
				if enabled == nil then
					enabled = true
				end
				item.panel._extEnabled = enabled

				local cb = CheckBox.new(item.label)
				cb:setBounds(4, 4 + (i - 1) * rowH, boxW - 8, rowH - 2)
				pcall(function()
					local sk = Skin.getSkin("checkBoxSkin")
					if not sk then
						sk = buttonSkin
					end
					if sk then
						cb:setSkin(sk)
					end
				end)
				cb:setState(enabled)
				cb:addChangeCallback(function(self)
					local on = self:getState()
					item.panel._extEnabled = on
					S.config.extensionsEnabled[item.id] = on
					app.config.save()
					if S.window and not S.isHidden then
						S._preserveTextHeight = true
						handleResize(S.window)
						S._preserveTextHeight = false
					end
				end)
				extWin:insertWidget(cb)
			end
			extWin:setVisible(false)
			S.extensionsBox = extWin

			local extBtn = Button.new("Ext")
			extBtn:setBounds(0, 0, 36, 20)
			extBtn:setSkin(buttonSkin)
			extBtn:addMouseUpCallback(function()
				if not S.extensionsBox then
					return
				end
				local show = not S.extensionsBox:getVisible()
				if show then
					local winX, winY = S.window:getPosition()
					local toolbar = S.window and S.window.Box
					local boxX, boxY = 0, 0
					if toolbar and toolbar.getPosition then
						boxX, boxY = toolbar:getPosition()
					end
					local bx, by = S.extensionsBtn and S.extensionsBtn:getPosition() or 0, 0
					S.extensionsBox:setPosition((winX or 0) + (boxX or 0) + (bx or 0), (winY or 0) + (boxY or 0) + (by or 0) + TITLE_H + 24)
				end
				S.extensionsBox:setVisible(show)
			end)
			box:insertWidget(extBtn)
			S.extensionsBtn = extBtn
			layoutToolbar(420)
		end

		if S.window.Box then
			if S.window.Box.setZIndex then
				S.window.Box:setZIndex(50)
			end
			prevButton:setVisible(true)
			nextButton:setVisible(true)
		end

		rebindHotkey()

		-- add insert coordinates hotkey
		if S.config.hotkeyInsertCoordinates then
			S.window:addHotKeyCallback(
				S.config.hotkeyInsertCoordinates,
				function()
					if S.isHidden == false and S.inMission and S.crosshairCheckbox:getState() then
						app.coords.insert()
					end
				end
			)
		end

		-- add reload pages hotkey
		if S.config.hotkeyReloadPages then
			S.window:addHotKeyCallback(
				S.config.hotkeyReloadPages,
				function()
					app.pages.load()
					if S.currentPage ~= nil then
						for _, page in ipairs(S.pages) do
							if page.path == S.currentPage then
								app.pages.loadPage(page)
								return
							end
						end
					end

					-- file not found anymore, restart at the beginning
					S.currentPage = nil
					app.pages.next()
				end
			)
		end

		S.window:addSizeCallback(handleResize)
		S.window:addPositionCallback(handleMove)

		-- remove the focus from the textarea when clicking outside of the Scratchpad
		dxgui.AddMouseCallback("down", function(x, y)
			if S.isHidden or not S.window then
				return
			end
			local winX, winY, winW, winH = S.window:getBounds()
			local edge = hitResizeEdge(x, y, winX, winY, winW, winH)
			if edge then
				S._edgeDrag = edge
				S._anchorX = winX
				S._anchorY = winY
				S._anchorW = winW
				S._anchorH = winH
				S._anchorRight = winX + winW
				S._anchorBottom = winY + winH
				return
			end
			S._edgeDrag = nil
			S._inEdgeResize = nil
			if x < winX or x > (winX + winW) or y < winY or y > (winY + winH) then
				blur()
				if S.extensionsBox and S.extensionsBox:getVisible() then
					local ex, ey = S.extensionsBox:getPosition()
					local ew, eh = S.extensionsBox:getSize()
					local onBox = x >= ex and x <= ex + ew and y >= ey and y <= ey + eh
					if not onBox then
						S.extensionsBox:setVisible(false)
					end
				end
				if S.helpBox and S.helpBox:getVisible() then
					local hx, hy = S.helpBox:getPosition()
					local hw, hh = S.helpBox:getSize()
					local onHelp = x >= hx and x <= hx + hw and y >= hy and y <= hy + hh
					if not onHelp then
						S.helpBox:setVisible(false)
					end
				end
			end
		end)
		pcall(function()
			dxgui.AddMouseCallback("up", function()
				S._edgeDrag = nil
				S._inEdgeResize = nil
			end)
		end)

		-- setup window
		local pos = app.config.getPosition and app.config.getPosition()
		S.window:setBounds(
			pos.x,
			pos.y,
			S.config.windowSize.w,
			S.config.windowSize.h
		)
		rememberGeom(pos.x, pos.y, S.config.windowSize.w, S.config.windowSize.h)
		S.window:setVisible(true)
		S._layoutWhileHidden = true
		handleResize(S.window)
		S._layoutWhileHidden = false
		handleMove(S.window)
		app.pages.next()
		hide()

		app.log("Scratchpad window created.")
	end

	local function tickKeyFlash()
		S._flashFrame = (S._flashFrame or 0) + 1
		local flashing = S._flashingButtons
		if not flashing then
			return
		end
		local frame = S._flashFrame
		for btn in pairs(flashing) do
			if not btn._flashUntil or frame >= btn._flashUntil then
				local skin = btn:getSkin()
				if skin and skin.skinData and skin.skinData.states and btn._flashOrig then
					skin.skinData.states.released = btn._flashOrig
					btn:setSkin(skin)
				end
				btn._flashOrig = nil
				btn._flashUntil = nil
				flashing[btn] = nil
			end
		end
	end

	return {
		create = createScratchpadWindow,
		show = show,
		hide = hide,
		blur = blur,
		save = saveCurrentPage,
		updateSaveButton = updateSaveButton,
		flushSizeSave = flushSizeSave,
		flushPendingNewline = flushPendingNewline,
		tickKeyFlash = tickKeyFlash,
		setVisible = setVisible,
		updateCoordsMode = updateCoordsMode,
		handleResize = handleResize,
		handleMove = handleMove,
		applyFontSize = applyFontSize,
		rebindHotkey = rebindHotkey,
	}
end
