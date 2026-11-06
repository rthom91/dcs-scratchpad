--[[
	F-15E Strike Eagle

	Functions:
		start - cold start (engines + basic systems). Set INS to NAV manually when ready.
		mpd - program MPD/MPCD pages (edit screens table)
		A/Gload - program A/G Combat Weapon Load from current pylons
		night - night lighting
		day - day lighting
		route - cycle waypoint routes
]]

wpseq({ enable = true, cur = 1, diff = 1, route = '.B', menus = 'mlj' })

local ft = {}

ft.scratchpadFormats = {
	DDM = { precision = 3, lonDegreesWidth = 3 },
	MGRS = true,
}
ft.order = { 'start', 'mpd', 'A/Gload', 'night', 'day', 'route' }

-- =================
-- Helpers
-- =================

local function osbButtons()
	local b = {}
	for i = 1, 20 do
		b[i] = mfdg_commands['Button_' .. string.format('%02d', i)]
	end
	return b
end

local function powerOn(dev)
	ttt('Power Switch', { device = dev })
	ttt('Power Switch', { device = dev, onvalue = -1 })
end

local function findRouteButton()
	for i = 14, 23 do
		local entry = panel[i]
		if entry and entry.button then
			local txt = entry.button:getText() or ''
			if txt:sub(1, 5) == 'route' then
				return entry.button
			end
		end
	end
end

-- =================
-- MPD / MPCD page configuration
-- Edit this table to change default pages and master-mode assignments.
-- =================

local screens = {
	[devices.MPD_FLEFT] = {
		{ 'TEWS', 'NAV' },
		{ 'A/G RDR', 'A/G' },
		{ 'A/A RDR', 'A/A' },
	},
	[devices.MPCD_FCENTER] = {
		{ 'TSD', 'NAV' },
		{ 'HSI', 'A/G' },
	},
	[devices.MPD_FRIGHT] = {
		{ 'HSI', 'NAV' },
		{ 'SMRT WPNS', 'A/G' },
		{ 'TPOD', 'A/A' },
	},
	-- WSO
	[devices.MPCD_RLEFT] = {
		{ 'ADI', 'NAV' },
		{ 'ARMT', 'A/G' },
		{ 'HSI', 'A/A' },
	},
	[devices.MPD_RLEFT] = {
		{ 'ADI', 'NAV' },
		{ 'ARMT', 'A/G' },
		{ 'HSI', 'A/A' },
	},
	[devices.MPD_RRIGHT] = {
		{ 'ADI', 'NAV' },
		{ 'ARMT', 'A/G' },
		{ 'HSI', 'A/A' },
	},
	[devices.MPCD_RRIGHT] = {
		{ 'ADI', 'NAV' },
		{ 'ARMT', 'A/G' },
		{ 'HSI', 'A/A' },
	},
}
ft.screens = screens

local PAGE_MENU = {
	ADI = { 1 },
	ARMT = { 2 },
	HSI = { 3 },
	TF = { 4 },
	TSD = { 5 },
	SIT = { 8 },
	TPOD = { 12 },
	TEWS = { 13 },
	['A/G RDR'] = { 14 },
	['A/A RDR'] = { 15 },
	VTRS = { 16 },
	HUD = { 17 },
	ENG = { 18 },
	EVENT = { 19 },
	BIT = { 20 },
	['WIND MODEL'] = { 6, 11, 1, 6 },
	['A/G DLVRY'] = { 6, 11, 2, 6 },
	IFF = { 6, 11, 3, 6 },
	['DATA FRAME'] = { 6, 11, 5, 6 },
	JTIDS = { 6, 11, 13, 6 },
	['SMRT WPNS'] = { 11, 14 },
	['HUD PROG'] = { 6, 11, 17, 6 },
	['MC DTM'] = { 6, 11, 19, 6 },
	['SNSR MGMT'] = { 6, 11, 11, 1, 6 },
	['HMD-P'] = { 6, 11, 11, 8, 6 },
	['HMD-W'] = { 6, 11, 11, 9, 6 },
	['SP ENTRY'] = { 6, 11, 11, 13, 6 },
	['WDL COMM'] = { 6, 11, 11, 14, 6 },
	['VID 8'] = { 6, 11, 11, 16, 6 },
	['VID RC'] = { 6, 11, 11, 17, 6 },
	['VID 5'] = { 6, 6, 11, 11, 18, 6 },
	['VID LC'] = { 6, 11, 11, 19, 6 },
	['VID 2'] = { 6, 11, 11, 20, 6 },
}
local MODE_MENU = {
	['A/A'] = { 7 },
	['A/G'] = { 7, 7 },
	NAV = { 7, 7, 7 },
}
ft.mpd = function()
	local osb = osbButtons()
	local lastDev
	for dev = devices.MPD_FLEFT, devices.MPCD_RRIGHT do
		local screen = screens[dev]
		if screen then
			lastDev = dev
			powerOn(dev)
			for _, entry in ipairs(screen) do
				local pageName, mode = entry[1], entry[2]
				ttt('Power Switch', { device = dev, action = osb[6] })
				local pageBtns = PAGE_MENU[pageName]
				if pageBtns then
					for _, btn in ipairs(pageBtns) do
						ttt('Power Switch', { device = dev, action = osb[btn] })
					end
				end
				if type(mode) == 'string' and #mode == 3 and MODE_MENU[mode] then
					for _, btn in ipairs(MODE_MENU[mode]) do
						ttt('Power Switch', { device = dev, action = osb[btn] })
					end
					if pageBtns then
						ttt('Power Switch', { device = dev, action = osb[pageBtns[#pageBtns]] })
					end
					ttt('Power Switch', { device = dev, action = osb[6] })
				end
			end
		end
	end
	if lastDev then
		ttt('Power Switch', { device = lastDev, action = osb[6] })
	end
end

-- =================
-- Cold start
-- =================

ft.firstspool = true
ft.start = function(action)
	action = action or ''
	if action == '' then
		ft.T1 = DCS.getRealTime()
		ttn('Parking Brake Switch')
		tt('MIC Switch', { action = micsctrl_commands.mic_sw, value = 0.5 })
		tt('MIC Switch', { value = 0.5 })
		tt('Oxygen Supply/Mode Control Switch', { action = oxyctrl_commands.oxy_pbg_on_off_sw, value = 0.5 })
		tt('Left Generator')
		tt('Right Generator')
		tt('Left Engine Control Switch')
		tt('Right Engine Control Switch')
		tt('Left Engine Master Switch Cover'); delay(0.1)
		tt('Left Engine Master Switch'); ttf('Left Engine Master Switch Cover')
		tt('Right Engine Master Switch Cover'); delay(0.1)
		tt('Right Engine Master Switch'); ttf('Right Engine Master Switch Cover')
		tt('Jet Starter')
		tt('Air Conditiong Auto/Manual/Off')
		tt('Air Conditiong Max/Norm/Min', { value = -1 })
		ttf('Fuel Control: Conformal Tanks')
		ttf('Left Inlet Ramp Switch')
		ttf('Right Inlet Ramp Switch')
		tt('Yaw CAS Switch, when ON (LMB) RESET/(RMB) OFF')
		tt('Roll CAS Switch, when ON (LMB) RESET/(RMB) OFF')
		tt('Pitch CAS Switch, when ON (LMB) RESET/(RMB) OFF')
		tt('JFS Control Handle, (LMB)PULL/(RMB)ROTATE')
		-- WSO
		tt('Oxygen Supply/Mode Control Switch', { action = oxyctrl_commands.wso_oxy_pbg_on_off_sw, value = 0.5 })
		ttn('ICS ON/OFF Switch')
		ttn('RWR ON/OFF Switch')
		ttn('EWWS ON/OFF Switch')
		tt('CMD Operational Mode OFF/STBY/MAN/SEMI/AUTO', { value = 0.6 })
		tt('TGP Power Switch OFF/STBY/ON', { value = 1 })
		tt('RWR/ICS Mode Switch COMBAT/TRNG')
		tt('ECM PODS Mode Switch XMIT/STBY')
		tt('ICS Operational Mode Switch STBY/AUTO/MAN')
		ttn('Seat Arm Handle', { action = misc_commands.seat_arm_handle_rc })
		ttn('Seat Arm Handle', { action = misc_commands.seat_arm_handle })
		tt('Canopy Handle', { value = 0.5 })
		-- Turn on all MFDs
		local mfdDevices = {
			devices.MPD_FLEFT,
			devices.MPD_FRIGHT,
			devices.MPCD_FCENTER,
			devices.MPCD_RLEFT,
			devices.MPD_RLEFT,
			devices.MPD_RRIGHT,
			devices.MPCD_RRIGHT,
		}
		for _, dev in ipairs(mfdDevices) do
			tt('Power Switch', { device = dev, value = -1 })
			tt('Power Switch', { device = dev, value = 0 })
		end
		ttn('UFC LCD Brightness', { device = devices.UFCCTRL_FRONT })
		ttn('UFC LCD Brightness', { device = devices.UFCCTRL_REAR })
		ttt('Left UHF Preset Channel Selector', { device = devices.UFCCTRL_FRONT })
		ttn('Right UHF Preset Channel Selector', { device = devices.UFCCTRL_FRONT })
		ttn('HUD Brightness Control')
		tt('UHF Radio 1 Volume', { value = 1 })
		tt('UHF Radio 2 Volume', { value = 1 })
		tt('Terrain Follow Radar Switch', { value = 0.5 })
		ttn('Radar Altitude Switch')
		tt('INS Knob', { value = 0.25 })
		tt('Radar Mode Selector', { value = 0.25 })
		tt('Nav FLIR Switch', { value = 0.5 })
		tt('Fuel Totalizer Selector')
		for _ = 1, 20 do ttn('Bingo Selection') end
		ttt('T/O Trim Button')
		ttn('Canopy Handle')
		ttn('Flaps Control Switch')
		ttt('Right Throttle Finger Lift')
		ft.start('engspool')
	elseif action == 'engspool' then
		local info = Export.LoGetEngineInfo()
		if not info or not info.RPM then
			press('', { delay = 1, fn = ft.start, arg = 'engspool' })
			return
		end
		local rpm = info.RPM
		loglocal('engspool rpm: ' .. rpm.left .. ' : ' .. rpm.right, 4)
		if rpm.right < 21 then
			loglocal('engspool 1 true ' .. DCS.getRealTime(), 4)
			press('', { delay = 1, fn = ft.start, arg = 'engspool' })
			return
		elseif rpm.right < 50 then
			loglocal('engspool 2 true ', 4)
			if ft.firstspool then
				Export.LoSetCommand(2006, -1)
				ft.firstspool = false
			else
				Export.LoSetCommand(2006, 1)
			end
			press('', { delay = 1, fn = ft.start, arg = 'engspool' })
			return
		elseif rpm.left == 0 then
			ttt('Left Throttle Finger Lift')
			press('', { delay = 1, fn = ft.start, arg = 'engspool' })
			ft.firstspool = true
			return
		elseif rpm.left < 21 then
			press('', { delay = 1, fn = ft.start, arg = 'engspool' })
			return
		elseif rpm.left < 50 then
			if ft.firstspool then
				Export.LoSetCommand(2005, -1)
				ft.firstspool = false
			else
				Export.LoSetCommand(2005, 1)
			end
			press('', { delay = 1, fn = ft.start, arg = 'engspool' })
			return
		else
			loglocal('engspool done, advancing to posteng', 4)
			cancelmacro()
			ft.start('posteng')
			return
		end
	elseif action == 'posteng' then
		ttt('Data Key', { device = devices.UFCCTRL_FRONT })
		ttt('NAV Master Mode Selector')
	end
end

-- =================
-- A/G Combat Weapon Load
-- =================

local AG_MENU = {
	['MXU-648'] = { 1, 5 },
	['CBU-87'] = { 3, 1 },
	['Mk20 Rockeye'] = { 3, 3 },
	['CBU-97'] = { 3, 4 },
	['Mk-82 SnakeEye'] = { 4, 1 },
	['Mk-82'] = { 4, 2 },
	['BDU-50LD'] = { 4, 2 },
	['Mk-84'] = { 4, 3 },
	Mk_84AIR_TP = { 4, 12 },
	Mk_84AIR_GP = { 4, 12 },
	Mk_82AIR_T = { 4, 13 },
	['Mk-82AIR'] = { 4, 13 },
	['BDU-50HD'] = { 4, 13 },
	Durandal = { 4, 14 },
	['GBU-12'] = { 5, 1 },
	['LGB-50LGB'] = { 5, 1 },
	['GBU-10'] = { 5, 3 },
	['GBU-24A/B Paveway III'] = { 5, 13 },
	['AGM-65D Maverick'] = { 6, 1 },
	['AGM-65H Maverick'] = { 6, 2 },
	['AGM-65G Maverick'] = { 6, 3 },
	['AGM-65K Maverick'] = { 6, 4 },
}
local PYLON_TO_OSB = { [2] = 20, [4] = 19, [8] = 18, [12] = 17, [14] = 16 }
local AG_PYLONS = { 2, 4, 8, 12, 14 }
ft['A/Gload'] = function(indev)
	local dev = (type(indev) == 'number') and indev or devices.MPD_FRIGHT
	local osb = osbButtons()
	local payload = Export.LoGetPayloadInfo()
	local pl = payload and payload.Stations
	if not pl then
		loglocal('A/Gload: LoGetPayloadInfo returned nil')
		return
	end
	powerOn(dev)
	ttt('Push Button 2', { device = dev })
	ttt('Push Button 11', { device = dev })
	ttt('Push Button 7', { device = dev })
	local byPage = {}
	for _, pyl in ipairs(AG_PYLONS) do
		local station = pl[pyl]
		if station and #station.CLSID > 0 then
			local w = station.weapon
			local name = Export.LoGetNameByType(w.level1, w.level2, w.level3, w.level4)
			local entry = AG_MENU[name]
			if entry then
				local page = entry[1]
				byPage[page] = byPage[page] or {}
				table.insert(byPage[page], { entry[2], PYLON_TO_OSB[pyl] })
			else
				loglocal('A/Gload: unsupported weapon ' .. tostring(name))
			end
		end
	end
	for page = 1, 5 do
		local list = byPage[page]
		if list then
			for _, act in ipairs(list) do
				ttt(nil, { device = dev, action = osb[act[1]] })
				ttt(nil, { device = dev, action = osb[act[2]] })
			end
		end
		ttt('Push Button 10', { device = dev })
	end
	ttt('Push Button 10', { device = dev })
end

-- =================
-- Lighting
-- =================

ft.night = function()
	tt('Console Lights', { action = intlt_commands.console_lt_knob, value = 0.5 })
	ttf('Day/Night Mode Selector')
	tt('UFC LCD Brightness', { device = devices.UFCCTRL_FRONT, value = 0.3 })
	ttf('HUD DAY/AUTO/NIGHT Mode Selector')
	tt('HUD Brightness Control', { value = 0.3 })
	ttn('Landing/Taxi Light Switch')
	ttn('Nav FLIR Switch')
	tt('HUD Contrast Control', { value = 0.83 })
	tt('HUD Video Brightness Control', { value = 0.3 })
end
ft.day = function()
	tt('Console Lights', { action = intlt_commands.console_lt_knob, value = 0 })
	ttn('Day/Night Mode Selector')
	tt('UFC LCD Brightness', { device = devices.UFCCTRL_FRONT, value = 1 })
	ttn('HUD DAY/AUTO/NIGHT Mode Selector')
	tt('HUD Brightness Control', { value = 1 })
	ttf('Landing/Taxi Light Switch')
	ttf('Nav FLIR Switch')
	tt('HUD Contrast Control', { value = 0 })
	tt('HUD Video Brightness Control', { value = 0 })
end

-- =================
-- Route cycling
-- =================

local function routeLabel(route)
	return 'route' .. (route or '')
end
local function updateRouteLabel()
	local btn = findRouteButton()
	if btn then
		local w = wpseq()
		btn:setText(routeLabel(w.route))
	end
end
updateRouteLabel()
ft.route = function()
	local nextroute = LT[unittype] and LT[unittype].nextroute
	if not nextroute then return end
	local btn = findRouteButton()
	if not btn then
		loglocal('F-15E route() button not found')
		return
	end
	local w = wpseq()
	w.route = nextroute[w.route] or '.A'
	btn:setText(routeLabel(w.route))
	wpseq(w)
end

-- =================
-- Waypoint / LatLon
-- =================

ft.lt = {
	notes = [[Waypoint input requires UFC be in point data submenu. WP sequencing supported.]],
	coordsType = { format = 'DDM', precision = 3, lonDegreesWidth = 3 },
	wpentry = 'LATbLONcALTg',
	nextroute = { ['.A'] = '.B', ['.B'] = '.C', ['.C'] = 'Base', Base = '.A' },
	prewp = function()
		if not wps.enable then return end
		if wps.menus ~= '' then
			loglocal('F15 prewp(): menus press() ' .. wps.menus, 3)
			press(wps.menus)
		end
		if wps.cur > 0 then
			local tmp = tostring(wps.cur)
			if wps.route then
				if wps.route == 'Base' then
					tmp = 'Ba'
				else
					tmp = tmp .. wps.route .. 'a'
				end
			end
			loglocal('F15 prewp(): cur press() ' .. tmp, 3)
			press(tmp)
		else
			loglocal('F15 prewp(): cur < 0 ', 3)
		end
	end,
	updatewp = function(num)
		if not (wps.enable and wps.cur ~= -1) then return end
		if type(num) == 'number' then
			wps.cur = num
		else
			wps.cur = wps.cur + wps.diff
		end
		if wps.cur < 1 then
			wps.cur = 99
		elseif wps.cur > 99 then
			wps.cur = 1
		end
		wps:button()
	end,
	postwp = function()
		wps.update()
	end,
	llconvert = function(result)
		result = result:gsub("[°'\".]", "")
		result = result:gsub("([NEWS]) ", "%1")
		return result
	end,
}

-- =================
-- UFC
-- =================

ft.kp = (function()
	local diffiv = 0
	local dev = devices.UFCCTRL_FRONT
	local function ufc(cmd, press_delay)
		return tap(cmd, dev, 1, 0, press_delay or diffiv, diffiv)
	end
	local function shifted(cmd)
		return {
			{ ufc_commands.UFC_SHF, 1, diffiv, dev },
			{ ufc_commands.UFC_SHF, 0, diffiv, dev },
			{ cmd, 1, diffiv, dev },
			{ cmd, 0, diffiv, dev },
		}
	end
	local map = {}
	local keys = {
		['0'] = ufc_commands.UFC_KEY__0,
		['1'] = ufc_commands.UFC_KEY_A1,
		['2'] = ufc_commands.UFC_KEY_N2,
		['3'] = ufc_commands.UFC_KEY_B3,
		['4'] = ufc_commands.UFC_KEY_W4,
		['5'] = ufc_commands.UFC_KEY_M5,
		['6'] = ufc_commands.UFC_KEY_E6,
		['8'] = ufc_commands.UFC_KEY_S8,
		['9'] = ufc_commands.UFC_KEY_C9,
	}
	for k, cmd in pairs(keys) do
		map[k] = ufc(cmd)
	end
	map['7'] = ufc(ufc_commands.UFC_KEY__7, 0.20)
	local shift_keys = {
		N = ufc_commands.UFC_KEY_N2,
		E = ufc_commands.UFC_KEY_E6,
		W = ufc_commands.UFC_KEY_W4,
		S = ufc_commands.UFC_KEY_S8,
		A = ufc_commands.UFC_KEY_A1,
		B = ufc_commands.UFC_KEY_B3,
		C = ufc_commands.UFC_KEY_C9,
		M = ufc_commands.UFC_KEY_M5,
	}
	for k, cmd in pairs(shift_keys) do
		map[k] = shifted(cmd)
	end
	local pb = 'abcdefghij'
	local pb_cmds = {
		ufc_commands.UFC_PB_1,
		ufc_commands.UFC_PB_2,
		ufc_commands.UFC_PB_3,
		ufc_commands.UFC_PB_4,
		ufc_commands.UFC_PB_5,
		ufc_commands.UFC_PB_6,
		ufc_commands.UFC_PB_7,
		ufc_commands.UFC_PB_8,
		ufc_commands.UFC_PB_9,
		ufc_commands.UFC_PB_0,
	}
	for i = 1, #pb do
		map[pb:sub(i, i)] = ufc(pb_cmds[i])
	end
	map.k = ufc(ufc_commands.UFC_CLEAR)
	map.l = ufc(ufc_commands.UFC_DATA)
	map.m = ufc(ufc_commands.UFC_MENU)
	map.p = ufc(ufc_commands.UFC_A_P)
	map['^'] = ufc(ufc_commands.UFC_SHF)
	map['.'] = ufc(ufc_commands.UFC_DOT)
	map[' '] = { 0, 0, diffiv, dev }
	map['_'] = { { 0, 99, diffiv, 0 } }
	return map
end)()

return ft
