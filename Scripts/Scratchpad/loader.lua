local function loadScratchpad()
	local lfs = require("lfs")

	local rawSetUserCallbacks = DCS.setUserCallbacks
	local callbackChain = {}

	local function composeCallbacks()
		local names = {}
		for _, handler in ipairs(callbackChain) do
			for key, value in pairs(handler) do
				if type(value) == "function" then
					names[key] = true
				end
			end
		end
		local composed = {}
		for name in pairs(names) do
			composed[name] = function(...)
				for _, handler in ipairs(callbackChain) do
					local fn = handler[name]
					if type(fn) == "function" then
						local ok, err = pcall(fn, ...)
						if not ok then
							net.log("[Scratchpad] " .. tostring(name) .. " error: " .. tostring(err))
						end
					end
				end
			end
		end
		rawSetUserCallbacks(composed)
	end

	function DCS.setUserCallbacks(handler)
		if type(handler) ~= "table" then
			rawSetUserCallbacks(handler)
			return
		end
		for i, existing in ipairs(callbackChain) do
			if existing == handler then
				callbackChain[i] = handler
				composeCallbacks()
				return
			end
		end
		table.insert(callbackChain, handler)
		composeCallbacks()
	end

	package.path = lfs.writedir() .. "Scripts\\?.lua;"
		.. package.path
		.. ";.\\Scripts\\?.lua;.\\Scripts\\UI\\?.lua;"

	local modules = {
		"Scratchpad.config",
		"Scratchpad.coords",
		"Scratchpad.extensions",
		"Scratchpad.init",
		"Scratchpad.keyboard",
		"Scratchpad.log",
		"Scratchpad.pages",
		"Scratchpad.text",
		"Scratchpad.update",
		"Scratchpad.window",
	}
	for _, name in ipairs(modules) do
		package.loaded[name] = nil
	end

	local app = require("Scratchpad.init").start()
	local Update = require("Scratchpad.update")
	local updater = Update:new(app)

	local handler = {}
	local lastTick = 0
	local TICK_INTERVAL = 1

	function handler.onSimulationFrame()
		if app.state.config == nil then
			app.config.load()
			app.pages.load()
			app.extensions.load()
		end

		if not app.state.window and not app.state.windowCreateFailed then
			app.log("Creating Scratchpad window.")
			local ok, err = pcall(app.window.create)
			if not ok then
				app.state.windowCreateAttempts = (app.state.windowCreateAttempts or 0) + 1
				net.log("[Scratchpad] Failed to create window ("
					.. tostring(app.state.windowCreateAttempts) .. "/3): " .. tostring(err))
				if app.state.windowCreateAttempts >= 3 then
					app.state.windowCreateFailed = true
					net.log("[Scratchpad] Giving up window create. Check Scripts\\Scratchpad\\Dialogs\\*.dlg")
				end
			elseif not app.state.window then
				app.state.windowCreateFailed = true
				net.log("[Scratchpad] Window creation failed.")
			end
		end

		local now = os.time()
		if now - lastTick >= TICK_INTERVAL then
			lastTick = now
			if app.config.refreshOptions then
				app.config.refreshOptions()
			end
			if updater and updater.tick then
				updater:tick(now)
			end
			if app.state.window and not app.state.isHidden then
				if app.window.updateSaveButton then
					app.window.updateSaveButton(true)
				end
				if app.window.flushSizeSave then
					app.window.flushSizeSave()
				end
			end
		end

		if app.state.window and not app.state.isHidden then
			if app.window.flushPendingNewline then
				app.window.flushPendingNewline()
			end
			if app.window.tickKeyFlash then
				app.window.tickKeyFlash()
			end
		end
	end

	function handler.onMissionLoadEnd()
		app.state.inMission = true
		if app.state.crosshairCheckbox then
			app.window.updateCoordsMode()
		end
	end

	function handler.onSimulationStop()
		app.state.inMission = false
		if app.state.crosshairCheckbox then
			app.state.crosshairCheckbox:setState(false)
		end
		if app.state.window then
			if app.window.save then
				app.window.save()
			end
			app.window.hide()
		end
	end

	DCS.setUserCallbacks(handler)
	net.log("[Scratchpad] Loaded.")
end

local status, err = pcall(loadScratchpad)
if not status then
	net.log("[Scratchpad] Load error: " .. tostring(err))
end
