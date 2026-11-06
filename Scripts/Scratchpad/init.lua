local M = {}

local function newState()
	return {
		window = nil,
		windowDefaultSkin = nil,
		windowSkinHidden = nil,
		logFile = nil,
		config = nil,
		panels = {},
		textarea = nil,
		crosshairCheckbox = nil,
		insertCoordsBtn = nil,
		isHidden = true,
		keyboardLocked = false,
		inMission = false,
		currentPage = nil,
		pagesCount = 0,
		pages = {},
		crosshairWindow = nil,
		extensions = {},
		coordListeners = {},
		windowCreateFailed = false,
		windowCreateAttempts = 0,
	}
end

function M.start()
	M.state = newState()
	require("Scratchpad.log")(M)
	M.text = require("Scratchpad.text")(M)
	M.config = require("Scratchpad.config")(M)
	M.pages = require("Scratchpad.pages")(M)
	M.coords = require("Scratchpad.coords")(M)
	M.keyboard = require("Scratchpad.keyboard")(M)
	M.extensions = require("Scratchpad.extensions")(M)
	M.window = require("Scratchpad.window")(M)
	return M
end

return M
