local Terrain = require("terrain")
local aircraft = require("Scratchpad.units")

local DEFAULT = {
	{ format = "METRIC" },
	{ format = "DMS", precision = 0 },
	{ format = "DMS", precision = 3 },
	{ format = "DDM", precision = 3 },
	{ format = "DDM", precision = 4 },
	{ format = "MGRS" },
}

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

-- format: "DMS" | "DDM" | "DD"
-- opts: precision, lonDegreesWidth, showNegative
-- showNegative = true  -> civilian signed degrees, no hemisphere letter
-- showNegative = false -> military hemisphere letter (N/S/E/W)
local function formatCoord(format, isLat, d, opts)
	opts = type(opts) == "table" and opts or {}

	local absD, hemi = splitHemisphere(d, isLat)
	local g = math.floor(absD)
	local m = (absD - g) * 60

	local precision = opts.precision or 3
	if precision < 0 then
		precision = 0
	end
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

	-- Lua %0Nd counts the sign. Pad so digit count stays stable.
	local function widthFor(deg)
		if useNegative and deg < 0 then
			return degreesWidth + 1
		end
		return degreesWidth
	end

	-- No leading space when the hemisphere letter is omitted.
	local function hemiSep()
		if displayHemi == "" then
			return ""
		end
		return " "
	end

	local fmt = string.upper(tostring(format or "DD"))

	if fmt == "DMS" then
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

		-- Width must count the decimal point, or single-digit seconds lose the leading zero.
		local secWidth = precision == 0 and 2 or (precision + 3)
		local secFmt = "%0" .. secWidth .. "." .. precision .. "f"
		return string.format(
			"%s%s%0" .. widthFor(displayG) .. "d°%02d'" .. secFmt .. '"',
			displayHemi, hemiSep(), displayG, m, s
		)

	elseif fmt == "DDM" then
		m = roundTo(m, precision)
		if m >= 60 - 1e-9 then
			m = 0
			if useNegative and (hemi == "S" or hemi == "W") then
				displayG = displayG - 1
			else
				displayG = displayG + 1
			end
		end

		local minFmt = "%0" .. (precision + 3) .. "." .. precision .. "f"
		return string.format(
			"%s%s%0" .. widthFor(displayG) .. "d°" .. minFmt .. "'",
			displayHemi, hemiSep(), displayG, m
		)

	else
		-- DD: civilian signed decimal degrees.
		local signed = (hemi == "S" or hemi == "W") and -absD or absD
		local places = opts.precision or 6
		if places < 0 then
			places = 0
		end
		return string.format("%." .. places .. "f", signed)
	end
end


local function formatsFor(ac)
	return aircraft[ac] or DEFAULT
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
		log("insertCoordinates: no camera position")
		return
	end
	local pos = cam.p

	local ok, alt = pcall(Terrain.GetSurfaceHeightWithSeabed, pos.x, pos.z)
	if not ok then
		log("insertCoordinates: GetSurfaceHeightWithSeabed failed: " .. tostring(alt))
		return
	end

	local ok2, lat, lon = pcall(Terrain.convertMetersToLatLon, pos.x, pos.z)
	if not ok2 then
		log("insertCoordinates: convertMetersToLatLon failed: " .. tostring(lat))
		return
	end

	local ok3, mgrs = pcall(Terrain.GetMGRScoordinates, pos.x, pos.z)
	if not ok3 then
		mgrs = ""
	end

	local types = formatsFor(DCS.getPlayerUnitType() or "")
	local lines = {}

	for _, spec in ipairs(types) do
		local fmt = spec.format
		if fmt == "METRIC" then
			lines[#lines + 1] = string.format(
				"X%+09d Z%+09d",
				math.floor(pos.x + 0.5),
				math.floor(pos.z + 0.5)
			)
		elseif fmt == "MGRS" then
			if mgrs and mgrs ~= "" then
				local digits = spec.precision or 10
				if digits == 6 or digits == 8 then
					local grid, e, n = mgrs:match("^(.+)%s+(%d%d%d%d%d)%s+(%d%d%d%d%d)$")
					if grid and e and n then
						local take = (digits == 6) and 3 or 4
						lines[#lines + 1] = grid .. " " .. e:sub(1, take) .. " " .. n:sub(1, take)
					else
						lines[#lines + 1] = mgrs
					end
				else
					lines[#lines + 1] = mgrs
				end
			end
		else
			lines[#lines + 1] = formatCoord(fmt, true, lat, spec)
				.. ", "
				.. formatCoord(fmt, false, lon, spec)
		end
	end
	lines[#lines + 1] = string.format("%.0fm / %.0fft", alt, alt * 3.28084)

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
		insert = function()
			insertCoordinates(app)
		end,
	}
end
