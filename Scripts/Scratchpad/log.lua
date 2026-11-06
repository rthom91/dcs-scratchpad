local lfs = require("lfs")

return function(app)
	local S = app.state
	S.logFile = io.open(lfs.writedir() .. [[Logs\Scratchpad.log]], "w")

	local function log(str)
		if not str then
			return
		end

		if S.logFile then
			S.logFile:write("[" .. os.date("%H:%M:%S") .. "] " .. str .. "\r\n")
			S.logFile:flush()
		end
	end

	app.log = log
	return log
end
