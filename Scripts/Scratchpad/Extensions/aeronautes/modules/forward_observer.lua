--[[
	Navigation and heading hold functions (in development)

	Functions:
		HH - heading hold mode
		HHCancel - cancel heading hold
		NAV - drive toward a coordinate
]]

local ft = {}

ft.scratchpadFormats = {
	DDM = { lonDegreesWidth = 3 },
	MGRS = true,
}
ft.order = { 'HH', 'HHCancel', 'NAV' }

-- =================
-- Drive toward a hardcoded coordinate
-- =================

ft.NAV = function()
	local function bearing(here, there)
		local deltaL = math.abs(there.Long - here.Long)
		local x = math.cos(there.Lat) * math.sin(deltaL)
		local y = math.cos(here.Lat) * math.sin(there.Lat)
			- math.sin(here.Lat) * math.cos(there.Lat) * math.cos(deltaL)
		local B = math.atan2(x, y)
		return B
	end

	local sd = Export.LoGetSelfData()

	local goal = {
		Lat = 42.873935576143,
		Long = 41.333509159828,
		Alt = 144.11176018344,
	}

	local ber = math.deg(bearing(sd.LatLongAlt, goal))
	local berd = ber < 0 and (360 + ber) or ber

	loglocal('NAV ber: ' .. berd .. ' hdg: ' .. math.deg(sd.Heading))
end

-- =================
-- Heading hold
-- =================

ft.HHflag = false

ft.HH = function()
	local sd = Export.LoGetSelfData()
	local hdg = math.deg(sd.Heading)

	if not ft.HHflag then
		ft.HHflag = true
		ft.HHhdg = hdg
		net.recv_chat('hold this: ' .. ft.HHhdg)
	end

	if ft.HHhdg then
		net.recv_chat('hold: ' .. ft.HHhdg)
		net.recv_chat('Hdg: ' .. hdg, 0)

		local function pid(target, actual)
			local Kp = 1.0
			local err = target - actual
			return Kp * err
		end

		local function turn(dir)
			if dir == 1 then
				Export.LoSetCommand(197)
			elseif dir == 2 then
				Export.LoSetCommand(195)
			end
		end

		local PV = pid(ft.HHhdg, hdg)
		if PV < 0 then
			net.recv_chat('turn left')
			turn(1)
		elseif PV > 0 then
			net.recv_chat('turn right')
			turn(2)
		end
	end
end

-- =================
-- Cancel heading hold
-- =================

ft.HHCancel = function()
	ft.HHflag = false
	ft.HHhdg = nil
end

-- =================
-- Waypoint stubs (JTAC slot placeholder)
-- =================

ft.lt = {
	notes = [[Place holder for JTAC slot]],
	coordsType = { format = 'DDM', lonDegreesWidth = 3 },

	prewp = function(input)
	end,

	updatewp = function(num)
		wps:button()
	end,

	postwp = function()
		wps.update()
	end,

	postload = function()
	end,
}

ft.kp = {}

return ft
