local Input = require("Input")

return function(app)
	local S = app.state

	local function unlockKeyboardInput()
		if S.keyboardLocked then
			DCS.unlockKeyboardInput(true)
			S.keyboardLocked = false
		end
	end

	local function lockKeyboardInput()
		if S.keyboardLocked then
			return
		end

		local keyboardEvents = Input.getDeviceKeys(Input.getKeyboardDeviceName())
		local inputActions = Input.getEnvTable().Actions

		local removeCommandEvents = function(commandEvents)
			for i, commandEvent in ipairs(commandEvents) do
				for j = #keyboardEvents, 1, -1 do
					if keyboardEvents[j] == commandEvent then
						table.remove(keyboardEvents, j)
						break
					end
				end
			end
		end

		removeCommandEvents(Input.getUiLayerCommandKeyboardKeys(inputActions.iCommandChat))
		removeCommandEvents(Input.getUiLayerCommandKeyboardKeys(inputActions.iCommandAllChat))
		removeCommandEvents(Input.getUiLayerCommandKeyboardKeys(inputActions.iCommandFriendlyChat))
		removeCommandEvents(Input.getUiLayerCommandKeyboardKeys(inputActions.iCommandChatShowHide))

		DCS.lockKeyboardInput(keyboardEvents)
		S.keyboardLocked = true
	end

	return {
		lock = lockKeyboardInput,
		unlock = unlockKeyboardInput,
	}
end
