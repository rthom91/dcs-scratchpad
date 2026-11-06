--[[
	Waypoint sequencer and coordinate entry.
	Loaded into the Apit environment.
]]

-- =================
-- Hooks called around waypoint entry
-- =================

function prewp(input)
	loglocal('prewp() unittype: ' .. tostring(unittype), 3)
	if not LT[unittype] then
		loglocal('prewp() no LT[unittype]')
		return
	end
	if LT[unittype].prewp then
		LT[unittype].prewp(input)
	end
	loglocal('prewp 2: ', 3)
end

-- Called during the middle of lat/long entry
function midwp(wpstr)
	loglocal('midwp: ', 6)
	if not LT[unittype] then
		loglocal('midwp() no LT[unittype]')
		return wpstr
	end
	if LT[unittype].midwp then
		return LT[unittype].midwp(wpstr)
	end
	loglocal('midwp 2: not defined', 6)
	return wpstr
end

-- Called after lat/long has been entered
function postwp(arg)
	loglocal('postwp: ' .. net.lua2json(arg), 3)
	if not LT[unittype] then
		loglocal('postwp() no LT[unittype]')
		return
	end
	if LT[unittype].postwp then
		return LT[unittype].postwp(arg)
	end
	loglocal('postwp 2: not defined', 6)
	return
end

-- =================
-- Waypoint sequence configuration
-- =================

function wpseq(param)
	if param ~= nil then
		loglocal('wpseq: ' .. net.lua2json(param), 3)
		for i, j in pairs(param) do
			if wps[i] ~= nil then
				if type(wps[i]) == type(param[i]) then
					loglocal('wpseq set: ' .. i, 5)
					wps[i] = param[i]
				else
					loglocal('wpseq type mismatch: ' .. i .. '-' .. type(wps[i]) .. '-' .. type(param[i]))
				end
			else
				loglocal('wpseq wps key not found: ' .. i)
			end
		end
		if wps.initialize then
			wps = copytable(wpsdefaults)
		end
	end

	wps:button()
	if wps ~= nil then
		loglocal('wpseq end: ' .. net.lua2json(wps), 5)
		return wps
	else
		loglocal('wpseq() wps is nil')
	end
end

-- =================
-- Internal entry helper
-- =================

local function enterwp(keystr)
	loglocal('enterwp() inp: ' .. keystr, 3)
	local result = convertformatCoords(keystr)
	result = midwp(result)
	result = string.gsub(result, '.', press)
	return result .. '\n'
end

-- =================
-- Waypoint entry interface
-- =================

function wp(inp)
	if type(inp) == 'string' then
		loglocal('wp() inp: ' .. inp, 3)
		prewp(inp)
		local result = enterwp(inp)
		postwp(inp)
		return result .. '\n'

	elseif type(inp) == 'table' then
		loglocal('wp() inp table:' .. net.lua2json(inp), 3)
		local pos = inp

		if inp.x and inp.y then
			-- Support Route Tool / preset table format
			local p = Export.LoLoCoordinatesToGeoCoordinates(inp.x, inp.y)
			pos.latitude = p.latitude
			pos.longitude = p.longitude
		elseif inp.lat and inp.lon then
			-- Support module-neutral lat/lon
			pos.latitude = inp.lat
			pos.longitude = inp.lon
		else
			loglocal('Error wp() inp table missing x/y; lat/lon: ' .. net.lua2json(inp))
			return
		end

		if inp.alt then
			pos.alt = inp.alt
		else
			pos.alt = 0
			loglocal('wp() inp.alt nil')
		end

		loglocal('wp() pos table:' .. net.lua2json(pos), 3)

		local types = coordsType(unittype)
		if types then
			local acstr = LLtoAC(
				formatCoordConv(types.format, true, pos.latitude, types),
				formatCoordConv(types.format, false, pos.longitude, types),
				string.format("%.0f", pos.alt * 3.28084)
			)
			if not acstr then
				loglocal('wp() LLtoAC returned nil, unittype: ' .. tostring(unittype))
				return nil
			end
			prewp(pos)
			enterwp(acstr)
			postwp(pos)
		else
			loglocal('Error wp() coordsType returned nil, unittype: ' .. unittype)
			return nil
		end

	else
		loglocal('wp() unhandled arg type: ' .. type(inp))
	end
end
