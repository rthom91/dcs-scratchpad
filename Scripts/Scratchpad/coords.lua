local Terrain = require("terrain")
local lfs = require("lfs")

local MODULES_DIR = lfs.writedir() .. [[Scripts\Scratchpad\Extensions\aeronautes\modules\]]
local DEFAULT_FORMATS = { DMS = true, DDM = true, MGRS = true }
-- Prefixes that fall back to a shared module file when no exact match exists
local PREFIXES = { "A-10C", "F-14", "SA342" }

local function loadModuleFormats(name)
	local path = MODULES_DIR .. name .. ".lua"
	local chunk = loadfile(path)
	if not chunk then
		return nil
	end

	local ok, result = pcall(chunk)
	if not ok or type(result) ~= "table" then
		return nil
	end

	return result.scratchpadFormats
		or (result.lt and result.lt.scratchpadFormats)
		or nil
end

local function getAircraftFormats()
	local ac = DCS.getPlayerUnitType() or ""

	local formats = loadModuleFormats(ac)
	if formats then
		return formats
	end

	for _, prefix in ipairs(PREFIXES) do
		if ac:sub(1, #prefix) == prefix then
			formats = loadModuleFormats(prefix)
			if formats then
				return formats
			end
		end
	end

	return DEFAULT_FORMATS
end

local function roundTo(value, places)
	local factor = 10 ^ places
	return math.floor(value * factor + 0.5) / factor
end

local function splitHemisphere(d, isLat)
	if isLat then
		return math.abs(d), d < 0 and "S" or "N"
	else
		return math.abs(d), d < 0 and "W" or "E"
	end
end

local function formatCoord(format, isLat, d, opts)
	opts = type(opts) == "table" and opts or {}

	local absD, hemi = splitHemisphere(d, isLat)
	local g = math.floor(absD)
	local m = (absD - g) * 60

	local precision = opts.precision or 3
	local useNegative = opts.showNegative == true
	local degreesWidth = (not isLat and opts.lonDegreesWidth) or 2

	local displayG = g
	local displayHemi = hemi
	if useNegative then
		if hemi == "S" or hemi == "W" then
			displayG = -g
		end
		displayHemi = ""
	end

	if format == "DMS" then
		m = math.floor(m)
		local s = absD * 3600 - g * 3600 - m * 60
		s = roundTo(s, precision)

		if s >= 60 - 1e-9 then
			s = 0
			m = m + 1
			if m >= 60 then
				m = 0
				if useNegative and (hemi == "S" or hemi == "W") then
					displayG = displayG - 1
				else
					displayG = displayG + 1
				end
			end
		end

		if useNegative and displayG < 0 then
			degreesWidth = degreesWidth + 1
		end

		local secFmt = "%0" .. (precision + 2) .. "." .. precision .. "f"
		return string.format("%s %0" .. degreesWidth .. "d°%02d'" .. secFmt .. '"', displayHemi, displayG, m, s)

	elseif format == "DDM" then
		m = roundTo(m, precision)
		if m >= 60 - 1e-9 then
			m = 0
			if useNegative and (hemi == "S" or hemi == "W") then
				displayG = displayG - 1
			else
				displayG = displayG + 1
			end
		end

		if useNegative and displayG < 0 then
			degreesWidth = degreesWidth + 1
		end

		local minFmt = "%0" .. (precision + 3) .. "." .. precision .. "f"
		return string.format("%s %0" .. degreesWidth .. "d°" .. minFmt .. "'", displayHemi, displayG, m)

	else
		local signed = (hemi == "S" or hemi == "W") and -absD or absD
		return string.format("%.6f", signed)
	end
end

local function insertCoordinates(app)
	local function log(msg)
		if app and app.log then
			app.log(msg)
		end
	end

	local S = app.state
	local cam = Export.LoGetCameraPosition()
	if not cam or not cam.p then
		if app and app.log then
			app.log("insertCoordinates: no camera position")
		end
		return
	end
	local pos = cam.p

	local ok, alt = pcall(Terrain.GetSurfaceHeightWithSeabed, pos.x, pos.z)
	if not ok then
		if app and app.log then
			app.log("insertCoordinates: GetSurfaceHeightWithSeabed failed: " .. tostring(alt))
		end
		return
	end

	local ok2, lat, lon = pcall(Terrain.convertMetersToLatLon, pos.x, pos.z)
	if not ok2 then
		if app and app.log then
			app.log("insertCoordinates: convertMetersToLatLon failed: " .. tostring(lat))
		end
		return
	end

	local ok3, mgrs = pcall(Terrain.GetMGRScoordinates, pos.x, pos.z)
	if not ok3 then
		mgrs = ""
	end

	local types = getAircraftFormats()
	local lines = {}

	if types.DMS then
		lines[#lines + 1] = formatCoord("DMS", true, lat, types.DMS)
						 .. ", "
						 .. formatCoord("DMS", false, lon, types.DMS)
	end
	if types.DDM then
		lines[#lines + 1] = formatCoord("DDM", true, lat, types.DDM)
						 .. ", "
						 .. formatCoord("DDM", false, lon, types.DDM)
	end
	if types.MGRS then
		lines[#lines + 1] = mgrs
	end
	lines[#lines + 1] = string.format("%.0fm, %.0fft", alt, alt * 3.28084)

	local text = app.text.Text.new()
	text:insertBelow(table.concat(lines, "\n") .. "\n")

	for _, listener in pairs(S.coordListeners or {}) do
		if type(listener) == "function" then
			listener(text, lat, lon, alt)
		end
	end
end

return function(app)
	return {
		format = formatCoord,
		type = getAircraftFormats,
		insert = function()
			insertCoordinates(app)
		end,
	}
end
