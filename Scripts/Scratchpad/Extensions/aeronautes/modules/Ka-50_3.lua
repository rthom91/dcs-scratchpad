--[[
	Ka-50 Black Shark

	Functions:
		start - starts the helicopter
		setup - cockpit config after autostart
		night - set night lighting
]]

wpseq({ enable = true, cur = 1, diff = 1, route = 't' })

local ft = {}

ft.scratchpadFormats = {
	DDM = { precision = 1, lonDegreesWidth = 3, showNegative = true },
}
ft.order = { 'start', 'setup', 'night' }

-- =================
-- setup
-- =================

ft.setup = function()
	ttn('', { device = devices.NAVLIGHT_SYSTEM, action = device_commands.Button_4 })
	ttf('', { device = devices.NAVLIGHT_SYSTEM, action = device_commands.Button_4 })
	ttn('', { device = devices.NAVLIGHT_SYSTEM, action = device_commands.Button_2 })
	ttf('', { device = devices.NAVLIGHT_SYSTEM, action = device_commands.Button_2 })

	ttf('Tip Lights')
	ttf('Anticollision Light')
	ttn('Manual/Auto weapon system control switch')
	ttn('Master Arm')
	tt('Dangerous RALT set rotary', { value = -1 })
end

-- =================
-- start
-- =================

ft.start = function(arg)
	local valid = {
		reng = 'reng',
		leng = 'leng',
		posteng = 'posteng',
		apudown = 'apudown',
	}
	arg = valid[arg] or ''

	local dbl = 0

	if arg == '' then
		ft.T1 = DCS.getRealTime()

		ttn('ABRIS Power')
		ttn('', { device = devices.CPT_MECH, action = device_commands.Button_18 })

		ttn('', { device = devices.ELEC_INTERFACE, action = device_commands.Button_4 })
		ttn('', { device = devices.ELEC_INTERFACE, action = device_commands.Button_3 })
		ttf('', { device = devices.ELEC_INTERFACE, action = device_commands.Button_4 })
		ttn('', { device = devices.ELEC_INTERFACE, action = device_commands.Button_6 })
		ttn('', { device = devices.ELEC_INTERFACE, action = device_commands.Button_5 })
		ttf('', { device = devices.ELEC_INTERFACE, action = device_commands.Button_6 })
		ttn('DC/AC inverter')

		ttf('', { device = devices.CPT_MECH, action = device_commands.Button_2 })
		ttf('', { device = devices.CPT_MECH, action = device_commands.Button_3 })
		ttn('K-041 Targeting-navigation system power switch')
		ttn('INU Heater switch')
		ttn('INU Power switch')

		ttn('Forward fuel tank pumps')
		ttn('Rear fuel tank pumps')
		ttn('Inner external fuel tanks pumps')
		ttn('Outer external fuel tanks pumps')
		ttn('', { device = devices.FUELSYS_INTERFACE, action = device_commands.Button_8 })
		ttn('', { device = devices.FUELSYS_INTERFACE, action = device_commands.Button_8 })
		ttn('', { device = devices.FUELSYS_INTERFACE, action = device_commands.Button_9 })
		ttn('', { device = devices.FUELSYS_INTERFACE, action = device_commands.Button_6 })
		ttn('', { device = devices.FUELSYS_INTERFACE, action = device_commands.Button_6 })
		ttn('', { device = devices.FUELSYS_INTERFACE, action = device_commands.Button_7 })
		ttn('Fuelmeter power')
		ttn('', { device = devices.FUELSYS_INTERFACE, action = device_commands.Button_10 })
		ttn('', { device = devices.FUELSYS_INTERFACE, action = device_commands.Button_10 })

		ttn('', { device = devices.ENGINE_INTERFACE, action = device_commands.Button_1 })
		ttn('', { device = devices.ENGINE_INTERFACE, action = device_commands.Button_1 })
		ttn('', { device = devices.ENGINE_INTERFACE, action = device_commands.Button_2 })
		ttn('', { device = devices.ENGINE_INTERFACE, action = device_commands.Button_3 })
		ttn('', { device = devices.ENGINE_INTERFACE, action = device_commands.Button_3 })
		ttn('', { device = devices.ENGINE_INTERFACE, action = device_commands.Button_4 })

		ttf('Rotor brake')
		Export.LoSetCommand(2004, 0)

		ttf('Engine Startup/Crank/False Start selector')
		tt('', { device = devices.ENGINE_INTERFACE, action = device_commands.Button_8, value = 0.3 })
		tt('', { device = devices.ENGINE_INTERFACE, action = device_commands.Button_8, value = 0 })
		ttn('Start-up selected engine button')

		tt('', { device = devices.ENGINE_INTERFACE, action = device_commands.Button_8, value = 0.1 })
		ttn('Start-up selected engine button')

		ft.start('leng')

	elseif arg == 'leng' then
		local info = Export.LoGetEngineInfo()
		if not info or not info.RPM then
			press('', { delay = 1, fn = ft.start, arg = 'leng' })
			return
		end
		local rpm = info.RPM
		loglocal('engspool rpm: ' .. rpm.left .. ' : ' .. rpm.right, 4)

		if rpm.left <= 15 then
			loglocal('Left engine APU spool', dbl)
			tt('', { device = devices.ENGINE_INTERFACE, action = device_commands.Button_8, value = 0.1 })
			ttn('Start-up selected engine button')
			press('', { delay = 1, fn = ft.start, arg = 'leng' })
			return
		elseif rpm.left <= 25 then
			loglocal('Left engine cut-off valve', dbl)
			ttn('Left engine cut-off valve')
			press('', { delay = 1, fn = ft.start, arg = 'leng' })
			return
		else
			loglocal('left eng spool done ' .. rpm.left, dbl)
		end

		ft.T2 = DCS.getRealTime()

		ttt('ABRIS Pushbutton 5')
		ttn('Intercom')
		ttn('VHF-1 (R828) power switch')
		ttn('VHF-2 (R-800) power switch')
		ttn('R-800 (VHF-1) Radio channel selector')
		ttn('Radio equipment datalink TLK power switch')
		ttn('Radio equipment datalink UHF TLK power switch')
		ttn('Radio equipment datalink SA-TLF power switch')
		tt('Dangerous RALT set rotary', { value = -1 })

		ttn('', { device = devices.WEAP_INTERFACE, action = device_commands.Button_19 })
		ttn('', { device = devices.WEAP_INTERFACE, action = device_commands.Button_18 })
		ttf('', { device = devices.WEAP_INTERFACE, action = device_commands.Button_19 })

		ttf('Laser standby ON/OFF switch')
		ttn('', { device = devices.FIRE_EXTING_INTERFACE, action = device_commands.Button_6 })
		ttf('', { device = devices.FIRE_EXTING_INTERFACE, action = device_commands.Button_7 })

		tt('', { device = devices.STBY_ADI, action = device_commands.Button_3, value = -1 })
		tt('', { device = devices.STBY_ADI, action = device_commands.Button_3, value = 0.06 })

		ttn('Navigation system power')
		ttn('Ejecting system power')
		ttf('Ejecting system power 1')
		ttf('Ejecting system power 2')
		ttf('Ejecting system power 3')
		ttf('Ejecting system power')

		ttn('AC left generator')
		ttn('AC right generator')
		ttn('', { device = devices.IFF, action = device_commands.Button_1 })
		ttn('', { device = devices.IFF, action = device_commands.Button_1 })
		ttn('', { device = devices.IFF, action = device_commands.Button_2 })

		ttn('', { device = devices.UV_26, action = device_commands.Button_10 })
		ttn('', { device = devices.UV_26, action = device_commands.Button_10 })
		ttn('', { device = devices.UV_26, action = device_commands.Button_12 })
		ttn('LWS Power switch')

		tt('Datalink Master mode', { value = 0.8 })
		ttn('NAV Datalink power')

		ttn('HUD Filter')
		ttn('Manual/Auto weapon system control switch')
		ttn('Master Arm')
		tt('NAV Master modes', { value = 0.3 })

		ft.start('reng')
		return

	elseif arg == 'reng' then
		local info = Export.LoGetEngineInfo()
		if not info or not info.RPM then
			press('', { delay = 1, fn = ft.start, arg = 'reng' })
			return
		end
		local rpm = info.RPM
		loglocal('engspool rpm: ' .. rpm.left .. ' : ' .. rpm.right, 4)

		if rpm.left < 60 then
			press('', { delay = 1, fn = ft.start, arg = 'reng' })
			return
		end

		if rpm.right < 15 then
			loglocal('Right engine APU spool', dbl)
			tt('', { device = devices.ENGINE_INTERFACE, action = device_commands.Button_8, value = 0.2 })
			ttt('Start-up selected engine button', { len = 1 })
			press('', { delay = 1, fn = ft.start, arg = 'reng' })
			return
		else
			loglocal('Right engine cut-off valve', dbl)
			ttf('Start-up selected engine button')
			ttn('Right engine cut-off valve')
			loglocal('Right eng spooled up ', dbl)
		end

		loglocal('reng done, advancing to posteng', 4)
		cancelmacro()
		ft.start('posteng')
		return

	elseif arg == 'posteng' then
		ft.T3 = DCS.getRealTime()
		ft.start('apudown')

	elseif arg == 'apudown' then
		ft.T4 = DCS.getRealTime()

		local info = Export.LoGetEngineInfo()
		if not info or not info.RPM then
			press('', { delay = 1, fn = ft.start, arg = 'apudown' })
			return
		end
		local rpm = info.RPM
		loglocal('engspool rpm: ' .. rpm.left .. ' : ' .. rpm.right, 4)

		if rpm.left < 60 or rpm.right < 60 then
			press('', { delay = 1, fn = ft.start, arg = 'apudown' })
			return
		else
			loglocal('APU shutdown', dbl)
			ttt('Stop APU button')
			ttf('', { device = devices.FUELSYS_INTERFACE, action = device_commands.Button_10 })
			ttn('', { device = devices.FUELSYS_INTERFACE, action = device_commands.Button_11 })
			tt('', { device = devices.ENGINE_INTERFACE, action = device_commands.Button_8, value = 0 })
		end

		ttt('Autopilot Pitch hold')
		ttt('Autopilot Bank hold')
		ttt('Autopilot Heading hold')
		ft.setup()

		loglocal('total time: ' .. DCS.getRealTime() - ft.T1)
		loglocal('leng time: ' .. ft.T2 - ft.T1)
		loglocal('reng time: ' .. ft.T3 - ft.T2)
		loglocal('post time: ' .. DCS.getRealTime() - ft.T3)
	end
end

-- =================
-- night
-- =================

ft.night = function()
	ttn('Lighting cockpit panel switch')
	ttn('Lighting night vision cockpit switch')
	ttn('Lighting ADI and SAI switch')
	tt('HUD Modes Reticle/Night/Day', { value = -1 })

	ttf('Tip Lights')
	ttf('Anticollision Light')

	tt('Lighting night vision cockpit brightness knob', { value = 0.3 })
	tt('Lighting HSI and ADI brightness knob', { value = 0.3 })
	tt('Lighting cockpit panel brightness knob', { value = 0.3 })
	tt('ABRIS Brightness', { value = 0.2 })
	tt('NAV Brightness', { value = 0.2 })

	ttn('', { device = devices.NAVLIGHT_SYSTEM, action = device_commands.Button_4 })
	ttf('', { device = devices.NAVLIGHT_SYSTEM, action = device_commands.Button_4 })
	ttn('', { device = devices.NAVLIGHT_SYSTEM, action = device_commands.Button_2 })
	ttf('', { device = devices.NAVLIGHT_SYSTEM, action = device_commands.Button_2 })
end

-- =================
-- Waypoint / LatLon
-- =================

ft.lt = {
	notes = [[Waypoint input starts at target 1 and increments. The WP type can be changed with wpseq({route=})]],
	coordsType = { format = 'DDM', precision = 1, lonDegreesWidth = 3 },
	wpentry = 'LATeLONe',
	customfn = Moduledir .. 'Ka-50_3.lua',

	prewp = function()
		if wps.enable then
			if wps.cur > -1 then
				press('n' .. wps.route .. wps.cur)
			else
				loglocal('Ka-50 prewp() wps.cur<0: ', net.lua2json(wps))
				return
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
			if wps.cur < 1 then
				wps.cur = 9
			elseif wps.cur > 9 then
				wps.cur = 1
			end
		end
		wps:button()
	end,

	postwp = function()
		press('o')
		wps.update()
	end,
}

-- =================
-- PVI
-- =================

ft.kp = (function()
	local diffiv = 0

	local function pvi(cmd, value)
		value = value or 1
		return tap(cmd, devices.PVI, value, value == 1 and 0 or value, diffiv, diffiv)
	end

	local map = {}

	for i = 0, 9 do
		map[tostring(i)] = pvi(device_commands['Button_' .. (i + 1)])
	end

	map.N = map['0']
	map.E = map['0']
	map.W = map['1']
	map.S = map['1']

	map.e = pvi(device_commands.Button_18)
	map.w = pvi(device_commands.Button_11)
	map.f = pvi(device_commands.Button_13)
	map.a = pvi(device_commands.Button_15)
	map.t = pvi(device_commands.Button_17)
	map.n = pvi(device_commands.Button_26, 0.2)
	map.o = pvi(device_commands.Button_26, 0.3)

	return map
end)()

return ft
