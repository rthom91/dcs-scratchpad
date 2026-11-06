--[[
	Anubis C-130 Hercules (DEPRECATED)

	Prerequisite:
	https://github.com/aeronautes/Hercules-6.8.2-macrofix/archive/refs/heads/main.zip
	Install the macrofix into your Herc mod directory, e.g.:
	Saved Games\DCS\Mods\aircraft\Hercules ver 6.8.2

	Functions:
		start - Recommend running first. Right-click APU switch to RUN before starting.
				  Uses ground elec/air + APU. Start engines before rearming/fueling.
				  Not fully hands-off: right-click (RMB) each Engine Start dial once
				  Bleed Air Pressure reads 40. Hold RMB until the green light illuminates.
				  Safe to have 3 green start lights at once. Script requests air/power
				  disconnect once engines 1 & 2 reach 5 RPM. APU bleed air cannot sustain
				  4 engines cranking simultaneously.
		takeoff - Set pilot CNI TOLD INDEX to takeoff data (markers on HUD)
		landing - Set pilot CNI TOLD INDEX to landing data (markers on HUD);
				  TOLD Index flap setting at 100%
		night - Internal/external lighting for night flying
		pylon - Chat + Scratchpad.log: required speed for pylon turn at current altitude
		cannon - Increment Select Cannon Station switch (toggle guns)
]]

wpseq({ enable = true, cur = 1, diff = 1 })

local ft = {}

ft.scratchpadFormats = {
	DDM = { precision = 3, lonDegreesWidth = 3 },
}
ft.order = { 'start', 'takeoff', 'landing', 'night', 'pylon', 'cannon' }

--[[
	Attempts at clicking engine start twice:
	ICommandMenuItem1			  966
	ICommandMenuItemPrev		   1886
	iCommandToggleCommandMenu	  179
	iCommand_UILayer_MouseLeftButton  2501
	iCommand_UILayer_MouseRightButton 2502
	iCommandCockpitClickModeOnOff  363
]]

-- =================
-- Required speed for pylon turn at current altitude
-- H = v² / 11.3 (v in knots); H = v² * 15 (v in mph)
-- =================

ft.pylon = function()
	local agl = Export.LoGetAltitudeAboveGroundLevel() * 3.28
	local kts = math.sqrt(agl * 11.3)
	net.recv_chat(kts)
	loglocal('agl(ft): ' .. agl .. ', kts: ' .. kts)
end

-- =================
-- Increment Select Cannon Station switch
-- =================

ft.cannon = function()
	tt('Select Cannon Station', { value = 0.2 })
end

-- =================
-- Internal and external lighting for night
-- =================

ft.night = function()
	ttf('Left Landing Lights Extend/Hold/Retract')
	ttf('Right Landing Lights Extend/Hold/Retract')
	tt('Left Landing Lights On/Off', { value = -1 })
	tt('Right Landing Lights On/Off', { value = -1 })
	tt('Taxi Lights On/Off', { value = -1 })

	-- Unshade HUD
	tt('Display Master Brighness Control', {
		device = devices.Radios_control,
		action = devaction.PILOT_hud_contrast_control,
		value = 1,
	})

	-- Reset to dimmest value
	for _ = 1, 15 do
		ttn('', { device = devices.Radios_control, action = devaction.Pilot_Display_Master_Brighness_Control })
		ttn('Display Master Brighness Control')
	end

	-- Set night brightness
	for _ = 1, 6 do
		ttf('', { device = devices.Radios_control, action = devaction.Pilot_Display_Master_Brighness_Control })
		ttf('Display Master Brighness Control')

		tt('', { device = devices.Radios_control, action = devaction.Fwd_Cargo_Lighting_Dome_Brightness_Control,	 value = -1 })
		tt('', { device = devices.Radios_control, action = devaction.Aft_Cargo_Lighting_Dome_Brightness_Control,	 value = -1 })
		tt('', { device = devices.Radios_control, action = devaction.Aft_Cargo_Lighting_Ramp_Dome_Brightness_Control, value = -1 })
	end

	tt('Jump Platform Light', { value = -1 })
	tt('Ramp Loading Light', { value = -1 })
end

-- =================
-- start
-- Uses ground elec/air. Engines should be started in reverse numerical order (primarily engines 1 or 2 last)
-- =================

ft.start = function(action)
	local valid = {
		engspool = 'engspool',
		posteng = 'posteng',
	}
	action = valid[action] or ''

	if action == '' then
		-- Ground crew elec/air on
		tt('External power / APU', { value = -1 })
		Export.LoSetCommand(179) -- comm menu
		Export.LoSetCommand(973) -- F8
		Export.LoSetCommand(967) -- F2 power
		Export.LoSetCommand(966) -- F1
		Export.LoSetCommand(179) -- comm menu
		Export.LoSetCommand(973) -- F8
		Export.LoSetCommand(969) -- F4 air
		Export.LoSetCommand(966) -- F1

		ttn('Battery')
		ttn('APU Stop/Run/Start') -- should click APU Run before starting

		tt('Aux Hydraulic pump', { value = -1 })
		ttn('Flightdeck Window Open/Close', { action = devaction.Flightdeck_Windows_Toggle })
		ttn('Crew Entrance Door Open/Close')
		ttn('', { device = devices.Radios_control, action = devaction.Paratroop_Doors_Toggle })
		tt('Flap Lever', { value = -1 })
		tt('Flap Lever', { value = -1, len = 10 })

		--[[
		ttn('Engine 1 Motor/Stop/Run/Start')
		ttn('Engine 2 Motor/Stop/Run/Start')
		ttn('Engine 3 Motor/Stop/Run/Start')
		ttn('Engine 4 Motor/Stop/Run/Start', { len = 10 })
		--]]

		tt('HUD Combiner Latch', { action = devaction.PILOT_hud_combiner_latch, value = -1 })
		ttn('Hud Press Contrast Rotate Brighness', { action = devaction.PILOT_hud_contrast_control })

		-- Put RWR on HDD1
		ttn('AMU SelectKey 5', { action = devaction.pilot_AMU001_SelectKey_005 })
		ttn('AMU SelectKey 7', { action = devaction.pilot_AMU001_SelectKey_007 })
		ttn('AMU SelectKey 1', { action = devaction.pilot_AMU002_SelectKey_001 })
		ttn('AMU SelectKey 6', { action = devaction.pilot_AMU001_SelectKey_006 })
		ttn('AMU SelectKey 6', { action = devaction.pilot_AMU002_SelectKey_006 })

		press('w') -- set copilot CNI to NAV

		-- Set pilot CNI to INDEX T/O
		ttn('CNI MU INDEX Select', { action = devaction.pilot_CNI_MU_INDEX })
		ttn('CNI MU SelectKey 2', { action = devaction.pilot_CNI_MU_SelectKey_002 })
		ttn('CNI MU SelectKey 12', { action = devaction.pilot_CNI_MU_SelectKey_012 })

		-- ttn('CNI MU NAV CTRL Select', { action = devaction.pilot_CNI_MU_NAV_CTRL })
		-- press('w')
		--[[ Set WP to #10 for less buggy behavior
		for i = 1, 9 do
			press('g')
		end
		--]]

		-- AC-130 battle station setup
		tt('Battle Station Power', { action = devaction.Battle_Station_Power, value = -1 })
		tt('Guard Master Arm Switch', { action = devaction.Master_Arm_Switch_Guard, value = -1 })
		tt('Master Arm Switch', { action = devaction.Master_Arm_Switch, value = -1 })
		tt('Select Cannon Station', { action = devaction.Cannon_Station_Select, value = -1 })

		-- engspool waits for engines 1 & 2, then disconnects externals.
		-- Start engines 1 & 2 after 3 & 4.
		ft.start('engspool')

	elseif action == 'engspool' then
		local info = Export.LoGetEngineInfo()
		if not info or not info.RPM then
			press('', { delay = 1, fn = ft.start, arg = 'engspool' })
			return
		end
		local rpm = info.RPM
		loglocal('engspool rpm: ' .. rpm.left .. ' : ' .. rpm.right, 4)
		ttt('Bleed Air Switch APU')

		if not (rpm.left > 5 and rpm.right > 5) then
			loglocal('engspool 1 true ' .. DCS.getRealTime(), 4)
			press('', { delay = 1, fn = ft.start, arg = 'engspool' })
		else
			loglocal('engspool done, advancing to posteng', 4)
			cancelmacro()
			ft.start('posteng')
			return
		end

	elseif action == 'posteng' then
		-- Ground crew elec/air off
		tt('External power / APU', { value = 1 })
		Export.LoSetCommand(179) -- comm menu
		Export.LoSetCommand(973) -- F8
		Export.LoSetCommand(967) -- F2 power
		Export.LoSetCommand(967) -- F2
		Export.LoSetCommand(179) -- comm menu
		Export.LoSetCommand(973) -- F8
		Export.LoSetCommand(969) -- F4 air
		Export.LoSetCommand(967) -- F2
	end
end

-- =================
-- takeoff / landing TOLD
-- =================

ft.takeoff = function()
	ttn('CNI MU INDEX Select', { action = devaction.pilot_CNI_MU_INDEX })
	ttn('CNI MU SelectKey 2', { action = devaction.pilot_CNI_MU_SelectKey_002 })
	ttn('CNI MU SelectKey 12', { action = devaction.pilot_CNI_MU_SelectKey_012 })
end

ft.landing = function()
	ttn('CNI MU INDEX Select', { action = devaction.pilot_CNI_MU_INDEX })
	ttn('CNI MU SelectKey 3', { action = devaction.pilot_CNI_MU_SelectKey_003 })
	ttn('CNI MU SelectKey 12', { action = devaction.pilot_CNI_MU_SelectKey_012 })
	ttn('CNI MU SelectKey 12', { action = devaction.pilot_CNI_MU_SelectKey_010 })
	ttn('CNI MU SelectKey 12', { action = devaction.pilot_CNI_MU_SelectKey_010 })
end

-- =================
-- Utility functions
-- =================

function mapgoto(new)
	local a = Export.LoGetCameraPosition()
	a.p.x = new.x
	a.p.z = new.z
	Export.LoSetCameraPosition(a)
end

function findbase(base)
	Export.LoSetCommand(15)
	local bases = Export.LoGetWorldObjects('airdromes')
	local k = {}
	for i, _ in pairs(bases) do
		table.insert(k, i)
	end
	table.sort(k)

	if type(base) == 'number' then
		if bases[k[base]] then
			-- loglocal(net.lua2json(bases[k[base]]))
			return bases[k[base]]
		end

		local j = base
		while bases[k[j]].Name == 'woRunWay' do
			j = j + 1
		end
		loglocal('RWY: ' .. bases[k[j]].Name)

	elseif type(base) == 'string' then
		for i, j in pairs(bases) do
			if j.Name == base then
				loglocal('found base: ' .. base)
				loglocal(net.lua2json(bases[i]))
				return bases[i - 1]
			end
		end
	end
end

function L2DDM(L)
	-- TODO
end

function showpos()
	local a = Export.LoGetCameraPosition()
	local b = Export.LoLoCoordinatesToGeoCoordinates(a.x, a.z)
	loglocal(net.lua2json(formatCoord({ format = 'DDM', lonDegreeWidth = 3 }, false, b.longitude, '')))
end

-- showpos()
-- loglocal(table_dump(DCS))

function dumptable(Tab, opt)
	loglocal('TABLE: ')
	local t = {}
	for i, j in pairs(Tab) do
		if opt and type(j) == opt then
			table.insert(t, i)
		else
			table.insert(t, i)
		end
	end
	table.sort(t)
	return t
end

-- for i, j in pairs(dumptable(Gui)) do
--	 loglocal(j)
-- end
-- loglocal(net.lua2json(dumptable(DCS, 'function')))

-- mapgoto(findbase('Muwaffaq Salti').Position)

-- =================
-- Waypoint entry
-- =================

ft.lt = {
	notes = [[Waypoint input sets the current point. No sequencing implemented.]],
	coordsType = { format = 'DDM', precision = 3, lonDegreesWidth = 3 },
	wpentry = 'LATeLONf',

	prewp = function()
		press('w') -- nav ctrl
		if wps.enable and wps.cur > -1 then
			-- CNI only allows direct wp input to 20; need INC for 20–49
			if wps.cur < 21 then
				press(tostring(wps.cur) .. 'a')
			else
				press('20a' .. string.rep('g', wps.cur - 20))
			end
		end
	end,

	updatewp = function(num)
		if wps.enable and wps.cur ~= -1 then
			if type(num) == 'number' then
				wps.cur = num
			else
				wps.cur = wps.cur + wps.diff
			end
			-- wp0 ignored for now
			if wps.cur < 1 then
				wps.cur = 49
			elseif wps.cur > 49 then
				wps.cur = 1
			end
		end
		wps:button()
	end,

	postwp = function(arg)
		if wps.cur > -1 then
			if arg and arg.name and #arg.name > 0 then
				local ident = string.upper(
					string.gsub(string.sub(arg.name, 1, 8), '[^%a%d%.%-%_%/]', '')
				)
				press(ident .. 'b')
			end
		end
		press('gh') -- inc/dec to activate in AFCS
		wps.update()
	end,

	postload = function()
		-- Remap for community Herc cockpit Lua interface
		for i, j in pairs(ttlist) do
			ttlist[i].device = devices.Radios_control
			local act = string.gsub(j.action_nm, '([^%.]+%.)', '')
			ttlist[i].action = devaction[act]
		end
	end,
}

-- =================
-- Copilot CNI keymap
-- =================

ft.kp = (function()
	local diffiv = 0
	local dev = devices.Radios_control
	local map = {}

	-- Digits 0–9
	for i = 0, 9 do
		map[tostring(i)] = click(devaction['copilot_CNI_MU_KBD_' .. i], dev, 1, diffiv)
	end

	-- Letters A–Z
	for i = 1, 26 do
		local letter = string.char(64 + i)
		map[letter] = click(devaction['copilot_CNI_MU_KBD_' .. letter], dev, 1, diffiv)
	end

	-- Special characters
	map['.'] = click(devaction.copilot_CNI_MU_KBD_dot, dev, 1, diffiv)
	map['-'] = click(devaction.copilot_CNI_MU_KBD_plusmin, dev, 1, diffiv)
	map['_'] = click(devaction.copilot_CNI_MU_KBD_UNDERSCORE, dev, 1, diffiv)
	map['/'] = click(devaction.copilot_CNI_MU_KBD_FORWARDSLASH, dev, 1, diffiv)

	-- Select keys
	local selects = {
		a = 1, b = 2, e = 5, f = 6, g = 7, h = 8, l = 12,
	}
	for key, n in pairs(selects) do
		map[key] = click(devaction[string.format('copilot_CNI_MU_SelectKey_%03d', n)], dev, 1, diffiv)
	end

	map.w = click(devaction.copilot_CNI_MU_NAV_CTRL, dev, 1, diffiv) -- NAV CTRL
	map.x = click(devaction.copilot_CNI_MU_INDEX, dev, 1, diffiv) -- INDEX

	return map
end)()

return ft
