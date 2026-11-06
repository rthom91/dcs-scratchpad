local lfs = require("lfs")
local Tools = require("tools")
local U = require("me_utilities")
local OptionsData = require("Options.Data")

local DEFAULT_WINDOW_POSITION = { x = 200, y = 200 }
local DEFAULT_WINDOW_SIZE = { w = 500, h = 200 }

return function(app)
	local S = app.state

	local function getOption(name)
		return OptionsData.getPlugin("Scratchpad", name)
	end

	local function setOption(name, value)
		OptionsData.setPlugin("Scratchpad", name, value)
		OptionsData.saveChanges()
	end

	local function applyOptionsToConfig()
		if not S.config then
			S.config = {}
		end

		S.config.fontSize = getOption("fontSize")
		S.config.hotkey = getOption("hotkey")
		S.config.showUpdates = getOption("showUpdates")
		S.config.flashKeys = getOption("flashKeys")
	end

	local function persistableConfig()
		local out = {}
		for k, v in pairs(S.config or {}) do
			if k ~= "fontSize" and k ~= "hotkey" then
				out[k] = v
			end
		end
		return out
	end

	local function saveConfiguration()
		U.saveInFile(persistableConfig(), "config", lfs.writedir() .. "Config/ScratchpadConfig.lua")
	end

	local function getPosition()
		local pos = S.config and S.config.windowPosition
		if pos and pos.x and pos.y then
			return { x = pos.x, y = pos.y }
		end
		return nil
	end

	local function setPosition(value)
		if type(value) == "table" and value.x ~= nil and value.y ~= nil then
			if not S.config then
				S.config = {}
			end
			S.config.windowPosition = { x = value.x, y = value.y }
			saveConfiguration()
		end
	end

	local function loadConfiguration()
		local tbl = Tools.safeDoFile(lfs.writedir() .. "Config/ScratchpadConfig.lua", false)
		if tbl and tbl.config then
			S.config = tbl.config
		else
			app.log("Configuration not found, creating defaults.")
			S.config = {
				windowSize = { w = DEFAULT_WINDOW_SIZE.w, h = DEFAULT_WINDOW_SIZE.h },
				windowPosition = { x = DEFAULT_WINDOW_POSITION.x, y = DEFAULT_WINDOW_POSITION.y },
				showKeyboard = false,
				showKeypad = false,
			}
			saveConfiguration()
		end

		if S.config.showKeyboard == nil then
			S.config.showKeyboard = false
		end

		if S.config.showKeypad == nil then
			S.config.showKeypad = false
		end

		if not S.config.windowPosition or not S.config.windowPosition.x or not S.config.windowPosition.y then
			S.config.windowPosition = { x = DEFAULT_WINDOW_POSITION.x, y = DEFAULT_WINDOW_POSITION.y }
		end

		if not S.config.windowSize or not S.config.windowSize.w or not S.config.windowSize.h then
			S.config.windowSize = { w = DEFAULT_WINDOW_SIZE.w, h = DEFAULT_WINDOW_SIZE.h }
		end

		applyOptionsToConfig()
	end

	local lastFontSize = nil
	local lastHotkey = nil

	local function refreshOptions()
		if not S.config then
			return
		end

		local prevFont = S.config.fontSize
		local prevHotkey = S.config.hotkey
		applyOptionsToConfig()

		if S.config.fontSize ~= prevFont or lastFontSize ~= S.config.fontSize then
			lastFontSize = S.config.fontSize
			if app.window and app.window.applyFontSize then
				app.window.applyFontSize()
			end
		end

		if S.config.hotkey ~= prevHotkey or lastHotkey ~= S.config.hotkey then
			lastHotkey = S.config.hotkey
			if app.window and app.window.rebindHotkey then
				app.window.rebindHotkey()
			end
		end
	end

	local function setFontSize(value)
		if type(value) ~= "number" then
			return
		end
		setOption("fontSize", value)
		refreshOptions()
	end

	local function setHotkey(value)
		if type(value) ~= "string" or value == "" then
			return
		end
		setOption("hotkey", value)
		refreshOptions()
	end

	return {
		load = loadConfiguration,
		save = saveConfiguration,
		getPosition = getPosition,
		setPosition = setPosition,
		refreshOptions = refreshOptions,
		getFontSize = function()
			return S.config and S.config.fontSize
		end,
		setFontSize = setFontSize,
		getHotkey = function()
			return S.config and S.config.hotkey
		end,
		setHotkey = setHotkey,
		getShowUpdates = function()
			return S.config and S.config.showUpdates
		end,
	}
end
