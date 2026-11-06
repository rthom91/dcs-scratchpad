--[[
	Mi-24P Hind

	Functions:
		start - starts the helicopter
]]

local ft = {}

ft.scratchpadFormats = {
	DDM = true,
	MGRS = true,
}
ft.order = { 'start' }

-- =================
-- start
-- =================

ft.start = function(arg)
	local valid = {
		reng = 'reng',
		leng = 'leng',
		posteng = 'posteng',
	}
	arg = valid[arg] or ''

	if arg == '' then
		ft.T1 = DCS.getRealTime()

		ttf('Pilot Door Safety Lock, OPEN/CLOSE')

		ttn('Right Battery switch, ON/OFF')
		ttn('Left Battery switch, ON/OFF')
		tt('DC Voltmeter knob', { value = 0.2 })
		ttn('Inverter PO-750A Cover, UP/DOWN')
		ttn('Inverter PO-750A, ON/OFF')
		ttt('All Left CBs ON')
		ttt('All Right CBs ON')
		ttn('Network to Batteries cover, UP/DOWN')
		ttn('Network to Batteries, ON/OFF')

		ttf('Sealing, OPEN/CLOSE')

		ttn('Feed Tank 1 Valve Switch, OPEN/CLOSE')
		ttn('Feed Tank 2 Valve Switch, OPEN/CLOSE')
		ttn('Left Engine Fire Valve Cover, UP/DOWN')
		ttn('Left Engine Fire Valve, OPEN/CLOSE')
		ttf('Left Engine Fire Valve Cover, UP/DOWN')
		ttn('Right Engine Fire Valve Cover, UP/DOWN')
		ttn('Right Engine Fire Valve, OPEN/CLOSE')
		ttf('Right Engine Fire Valve Cover, UP/DOWN')
		ttn('Tank 4 Pump, ON/OFF')
		ttn('Tank 5 Pump, ON/OFF')
		ttn('Tank 1 Pump, ON/OFF')
		ttn('Tank 2 Pump, ON/OFF')

		ttf('Left Engine Stop')
		ttf('Right Engine Stop')
		ttf('Rotor Brake')

		tt('APU Launch Method START/CRANK/FALSE', { value = -1 })
		ttt('APU Start')
		delay(23)
		tt('Engine Launch Method START/CRANK', { value = -1 })
		ttn('Engine Select RIGHT/LEFT')
		ttt('Engine Start')

		ft.start('leng')

	elseif arg == 'leng' then
		local info = Export.LoGetEngineInfo()
		if not info or not info.RPM then
			press('', { delay = 1, fn = ft.start, arg = 'leng' })
			return
		end
		local rpm = info.RPM
		loglocal('engspool rpm: ' .. rpm.left .. ' : ' .. rpm.right, 4)
		local dbl = 0

		if rpm.left == 0 then
			ttt('Engine Start')
			press('', { delay = 1, fn = ft.start, arg = 'leng' })
			return
		elseif rpm.left < 77 then
			ft.T2 = DCS.getRealTime()
			loglocal('leng 2 true ', dbl)
			press('', { delay = 1, fn = ft.start, arg = 'leng' })
			return
		else
			loglocal('left eng spooled up ', dbl)
		end

		ttf('Engine Select RIGHT/LEFT')
		ttt('Engine Start')

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
		local dbl = 0

		if rpm.right == 0 then
			ttt('Engine Start')
			press('', { delay = 1, fn = ft.start, arg = 'reng' })
			return
		elseif rpm.right < 40 then
			loglocal('reng 2 true ', dbl)
			press('', { delay = 1, fn = ft.start, arg = 'reng' })
			return
		else
			loglocal('right eng spooled up ', dbl)
		end

		loglocal('reng done, advancing to posteng', 4)
		cancelmacro()
		ft.start('posteng')
		return

	elseif arg == 'posteng' then
		ft.T3 = DCS.getRealTime()

		ttn('Cabin Unseal Switch, ON/OFF')
		ttn('Blowdown Conditioning Switch, CONDITIONING/OFF/BLOWDOWN')

		ttn('Fire Extinguisher Power ON/OFF')
		ttn('Extinguisher Control Switch EXING/CNTRL')

		ttn('Right Generator switch, ON/OFF')
		ttn('Left Generator switch, ON/OFF')
		ttn('AC Transformer 115v, MAIN/AUTO/BACKUP')
		ttn('AC Transformer 36v, MAIN/AUTO/BACKUP')
		ttn('Left Rectifier switch, ON/OFF')
		ttn('Right Rectifier switch, ON/OFF')

		tt('AC Voltmeter knob', {
			device = devices.ELEC_INTERFACE,
			action = elec_commands.ACGangSwitcher,
			value = 0.6,
		})

		ttn('Switch SPU-8 NET-2 ON/OFF')
		ttn('Switch SPU-8 NET-1 ON/OFF')
		ttn('R-863 ON/OFF')
		ttn('Jadro-1I ON/OFF')
		ttn('R-828 ON/OFF')
		ttn('RV-5 ON/OFF')
		ttn('DISS-15D ON/OFF')
		ttn('Gyro 1 Power, ON/OFF')
		ttn('Gyro 2 Power, ON/OFF')
		ttn("Greben' ON/OFF")
		ttn('RWR Power')
		ttn('Blinker Switch, ON/OFF')
		ttn('IFF Transponder Power Switch, ON/OFF')
		ttn('ARC-U2 switcher On/Off')

		ttt('Cage Gyro 1')
		ttt('Cage Gyro 2')

		ttn('SPUU Power ON/OFF')
		ttt('Autopilot K Channel ON')
		ttt('Autopilot T Channel ON')

		tt('DISS select mode IDK/IDK/IDK/MEM/OPER', { value = 1 })
		ttn('Map Power ON/OFF')
		ttn('Armament Panel Red Lights Switch, ON/OFF')

		ttn('Sight Power ON/OFF')
		tt('Burst Length SHORT/MED/LONG', { action = weapon_commands.Pilot_NPU_CHAIN, value = -1 })
		ttn('Sight distance MANUAL/AUTO')
		ttn('Weapon Control ON/OFF')
		ttn('Cannon Fire Rate SLOW/FAST', { action = weapon_commands.Pilot_TEMP_NPU30 })
		ttn('Sight mode MANUAL/AUTO')
		ttn('Sight mode SYNC/ASYNC')

		ttf('Inverter PO-750A Cover, UP/DOWN')
		ttf('Network to Batteries cover, UP/DOWN')

		ttt('APU Stop')

		push_stop_command(0, { device = devices.RADAR_ALTIMETER, action = ralt_commands.ROTARY, value = -1 })
		push_stop_command(0, { device = devices.RADAR_ALTIMETER, action = ralt_commands.ROTARY, value = -1 })

		loglocal('total time: ' .. DCS.getRealTime() - ft.T1)
		loglocal('leng time: ' .. ft.T2 - ft.T1)
		loglocal('reng time: ' .. ft.T3 - ft.T2)
		loglocal('post time: ' .. DCS.getRealTime() - ft.T3)
	end
end

return ft
