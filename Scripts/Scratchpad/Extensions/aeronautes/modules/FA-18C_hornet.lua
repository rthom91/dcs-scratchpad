--[[
	F/A-18C Hornet (Lot 20)

	Functions:
		start - cold start (engines + systems). Set INS to IFA manually when aligned.
		night - night lighting
		stores - TOO mode on A/G pylons
]]

wpseq({ cur = -1, diff = 1 })

local ft = {}

ft.bingo = 2000
ft.scratchpadFormats = {
	DMS = true,
	DDM = { precision = 4 },
	MGRS = true,
}
ft.order = { 'start', 'night', 'stores' }

-- =================
-- Helpers
-- =================

local function mdiButtons()
	local b = {}
	for i = 1, 20 do
		b[i] = MDI_commands['MDI_PB_' .. i]
	end
	return b
end

-- =================
-- Stores / TOO
-- =================

ft.stores = function(indev)
	local dev = indev or devices.MDI_LEFT
	local button = mdiButtons()
	local pylons = { 2, 3, 5, 7, 8 }
	local payload = Export.LoGetPayloadInfo()
	local PL = payload and payload.Stations
	if not PL then
		loglocal('stores: LoGetPayloadInfo returned nil')
		return
	end
	local TOOweapon = {
		['AGM-84D'] = 1,
		['AGM-84E SLAM'] = 2,
		['AGM-84H'] = 3,
		['AGM-154A'] = 4,
		['AGM-154 JSOW'] = 5,
		['GBU-38(V)1/B'] = 6,
		['GBU-31(V)1/B'] = 7,
		['GBU-31(V)2/B'] = 7,
		['GBU-31(V)3/B'] = 8,
		['GBU-31(V)4/B'] = 8,
		['GBU-32(V)2/B'] = 9,
	}
	local wtpyl, toosb, osbctr = {}, {}, 0
	for _, pyl in ipairs(pylons) do
		local st = PL[pyl]
		if st and st.CLSID and #st.CLSID > 0 then
			local w = st.weapon
			local wname = Export.LoGetNameByType(w.level1, w.level2, w.level3, w.level4)
			loglocal('stores wname: ' .. tostring(wname) .. ' CLSID: ' .. st.CLSID)
			osbctr = osbctr + 1
			local wt = TOOweapon[wname]
			if wt then
				if wtpyl[wt] then
					wtpyl[wt].count = wtpyl[wt].count + 1
					toosb[wtpyl[wt].osb] = (toosb[wtpyl[wt].osb] or 0) + 1
				else
					wtpyl[wt] = { name = wname, count = 1, osb = osbctr }
					toosb[osbctr] = 1
				end
			elseif wname == 'AN/AAQ-28 LITENING' then
				osbctr = osbctr - 1
			end
		end
	end
	for osb, count in pairs(toosb) do
		local b = button[5] + osb
		ttt(nil, { device = dev, action = b })
		for _ = 1, count do
			ttt('Left MDI PB 5')
			ttt('Left MDI PB 13')
		end
	end
end

-- =================
-- Cold start
-- =================

ft.start = function(action)
	action = action or ''
	if action == '' then
		tt('Ejection Seat SAFE/ARMED Handle, SAFE/ARMED', { value = -1 })
		tt('Battery Switch, ON/OFF/ORIDE')
		ttn('APU Control Switch, ON/OFF')
		tt('Canopy Control Switch, OPEN/HOLD/CLOSE', { value = -1 })
		tt('Left MDI Brightness Selector Knob, OFF/NIGHT/DAY')
		tt('Right MDI Brightness Selector Knob, OFF/NIGHT/DAY')
		tt('UFC Brightness Control Knob', { value = 0.9 })
		tt('HUD Symbology Brightness Control Knob', { value = 0.9 })
		tt('AMPCD Off/Brightness Control Knob', { value = 0.9 })
		tt('UFC COMM 1 Volume Control Knob', { value = 0.9 })
		tt('UFC COMM 2 Volume Control Knob', { value = 0.9 })
		tt('HMD OFF/BRT Knob', { value = 0.7 })
		ft.start('reng')
	elseif action == 'reng' then
		local info = Export.LoGetEngineInfo()
		if not info or not info.RPM then
			press('', { delay = 1, fn = ft.start, arg = 'reng' })
			return
		end
		local rpm = info.RPM
		loglocal('engspool rpm: ' .. tostring(rpm.left) .. ' : ' .. tostring(rpm.right), 4)
		if rpm.right == 0 then
			tt('Engine Crank Switch, LEFT/OFF/RIGHT', { action = engines_commands.EngineCrankRSw, value = 1 })
			delay(5)
			ttf('Engine Crank Switch, LEFT/OFF/RIGHT', { action = engines_commands.EngineCrankRSw })
			press('', { delay = 1, fn = ft.start, arg = 'reng' })
			return
		elseif rpm.right < 15 then
			press('', { delay = 1, fn = ft.start, arg = 'reng' })
			return
		elseif rpm.right < 50 then
			Export.LoSetCommand(312)
			press('', { delay = 1, fn = ft.start, arg = 'reng' })
			return
		else
			loglocal('rengspool done, advancing to postreng', 4)
			cancelmacro()
			ft.start('postreng')
			return
		end
	elseif action == 'postreng' then
		tt('Bleed Air Knob, R OFF/NORM/L OFF/OFF', { value = 0.3 })
		tt('Bleed Air Knob, R OFF/NORM/L OFF/OFF', { value = 0 })
		tt('Bleed Air Knob, R OFF/NORM/L OFF/OFF', { value = 0.1 })
		delay(0.25)
		tt('Bleed Air Knob, R OFF/NORM/L OFF/OFF', { value = 0.2 })
		push_start_command(0, { device = devices.RADAR, action = RADAR_commands.RADAR_SwitchChange, value = 0.1 })
		ttf('FLAP Switch, AUTO/HALF/FULL')
		tt('Attitude Selector Switch, INS/AUTO/STBY', { value = 0 })
		ttn('OBOGS Control Switch, ON/OFF')
		tt('HMD OFF/BRT Knob', { value = 1 })
		tt('IR Cooling Switch, ORIDE/NORM/OFF', { value = 0.1 })
		tt('DISPENSER Switch, BYPASS/ON/OFF', { value = 0.1 })
		tt('ECM Mode Switch, XMIT/REC/BIT/STBY/OFF', { value = 0.1 })
		ttn('ALR-67 POWER Pushbutton')
		ttf('FLIR Switch, ON/STBY/OFF')
		ttt('UFC Function Selector Pushbutton, IFF')
		tt('UFC Function Selector Pushbutton, ON/OFF')
		delay(0.5)
		ttt('UFC Function Selector Pushbutton, D/L')
		ttt('UFC Function Selector Pushbutton, ON/OFF')
		delay(0.5)
		ttt('UFC Function Selector Pushbutton, D/L')
		ttt('UFC Function Selector Pushbutton, ON/OFF')
		tt('HUD Symbology Brightness Control Knob', { value = 1 })
		tt('AMPCD Off/Brightness Control Knob', { value = 1 })
		ttt('Right MDI PB 10')
		for _ = 1, math.floor(ft.bingo / 100) do
			ttt('IFEI Up Arrow Button')
		end
		ttn('FCS RESET Button')
		delay(1)
		ttf('FCS RESET Button')
		ttt('T/O TRIM Button')
		push_start_command(0, { device = devices.INS, action = INS_commands.INS_SwitchChange, value = 0.2 })
		tt('AMPCD PB 19')
		ft.start('leng')
	elseif action == 'leng' then
		local info = Export.LoGetEngineInfo()
		if not info or not info.RPM then
			press('', { delay = 1, fn = ft.start, arg = 'leng' })
			return
		end
		local rpm = info.RPM
		loglocal('lengspool rpm: ' .. tostring(rpm.left) .. ' : ' .. tostring(rpm.right), 4)
		if rpm.left == 0 then
			tt('Engine Crank Switch, LEFT/OFF/RIGHT', { action = engines_commands.EngineCrankLSw, value = -1 })
			delay(5)
			ttf('Engine Crank Switch, LEFT/OFF/RIGHT', { action = engines_commands.EngineCrankLSw })
			press('', { delay = 1, fn = ft.start, arg = 'leng' })
			return
		elseif rpm.left < 15 then
			press('', { delay = 1, fn = ft.start, arg = 'leng' })
			return
		else
			Export.LoSetCommand(311)
			loglocal('lengspool done, advancing to postleng', 4)
			cancelmacro()
			ft.start('postleng')
			return
		end
	elseif action == 'postleng' then
		ttt('Right MDI PB 18')
		ttt('Right MDI PB 13')
		ttt('Right MDI PB 5')
		ttt('Right MDI PB 7')
		ttt('Right MDI PB 8')
		ttt('Right MDI PB 8')
		ttt('Right MDI PB 10')
		ttt('Right MDI PB 8')
		ttt('Right MDI PB 8')
		ttt('Right MDI PB 8')
		ttt('Right MDI PB 8')
		tt('FORMATION Lights Dimmer Control', { value = 1 })
		tt('POSITION Lights Dimmer Control', { value = 1 })
		ttn('LDG/TAXI LIGHT Switch, ON/OFF')
		ttt('AMPCD PB 3')
		ttt('AMPCD PB 3')
		ttt('AMPCD PB 10')
		ttt('AMPCD PB 19')
		ttt('AMPCD PB 10')
	end
end

-- =================
-- Night lighting
-- =================

ft.night = function(briteval)
	briteval = (type(briteval) == 'number') and briteval or 0.4
	ttf('HUD Symbology Brightness Selector Knob, DAY/NIGHT')
	tt('HMD OFF/BRT Knob', { value = 0.3 })
	tt('UFC Brightness Control Knob', { value = briteval })
	tt('Left MDI Brightness Selector Knob, OFF/NIGHT/DAY', { value = 0.1 })
	tt('Right MDI Brightness Selector Knob, OFF/NIGHT/DAY', { value = 0.1 })
	ttt('AMPCD Night/Day Brightness Selector, NGT', { onvalue = -1 })
	tt('IFEI Brightness Control Knob', { value = briteval })
	tt('CONSOLES Lights Dimmer Control', { value = briteval })
	tt('INST PNL Dimmer Control', { value = briteval })
	ttf('MODE Switch, NVG/NITE/DAY')
	ttn('POSITION Lights Dimmer Control')
	ttn('FORMATION Lights Dimmer Control')
end

-- =================
-- Waypoint / LatLon
-- =================

ft.lt = {
	notes = [[Waypoint input requires HSI DATA menu with precise on center AMPCD.
Default increments from the current waypoint. Control with wpseq({diff=}).]],
	coordsType = { format = 'DDM', precision = 4 },
	wpentry = 'faLAT LON caALT ',
	prewp = function()
		if not wps.enable then return end
		if wps.diff > 0 then
			press('g')
		elseif wps.diff < 0 then
			press('h')
		end
	end,
	updatewp = function(num)
		wps:button()
	end,
	postwp = function()
		wps:button()
	end,
	llconvert = function(result)
		result = result:gsub("[°'\"]", "")
		result = result:gsub("([NEWS]) ", "%1")
		result = result:gsub("[.]", " ")
		return result
	end,
}

-- =================
-- UFC / AMPCD
-- =================

ft.kp = (function()
	local diffiv = 0
	local map = {}
	for i = 0, 9 do
		map[tostring(i)] = tap(UFC_commands['KbdSw' .. i], devices.UFC, 1, 0, diffiv, diffiv)
	end
	map.N = map['2']
	map.E = map['6']
	map.W = map['4']
	map.S = map['8']
	map[' '] = tap(UFC_commands.KbdSwENT, devices.UFC, 1, 0, 0.25, 0.25)
	local opt = 'abcde'
	for i = 1, #opt do
		map[opt:sub(i, i)] = tap(UFC_commands['OptSw' .. i], devices.UFC, 1, 0, 0.25, 0.25)
	end
	map.f = tap(AMPCD_commands.AMPCD_PB_5, devices.AMPCD, 1, 0, 0.25, 0.25)
	map.g = tap(AMPCD_commands.AMPCD_PB_12, devices.AMPCD, 1, 0, 0.25, 0.25)
	map.h = tap(AMPCD_commands.AMPCD_PB_13, devices.AMPCD, 1, 0, 0.25, 0.25)
	map['_'] = { { 0, 99, 1, 0 } }
	return map
end)()

return ft
