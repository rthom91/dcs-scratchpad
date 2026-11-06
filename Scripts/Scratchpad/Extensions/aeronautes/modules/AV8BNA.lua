--[[
	AV-8B Harrier

	Functions:
		start - start the jet
		setup - post-start / autostart cockpit setup
		maptoggle - toggle moving map on EHSD
		night - cockpit lighting for night
]]

wpseq({ enable = true, cur = 1, diff = 1 })

local ft = {}

ft.scratchpadFormats = {
	DMS = { precision = 0, lonDegreesWidth = 3 },
	MGRS = true,
}
ft.order = { 'start', 'setup', 'maptoggle', 'night' }

-- =================
-- Toggles moving map on EHSD
-- =================

ft.maptoggle = function()
	ttn('MPCD Left Button 18')
	ttn('MPCD Left Button 2')
	ttn('MPCD Left Button 3')
	ttn('MPCD Left Button 12')
	ttn('MPCD Left Button 3')
end

-- =================
-- Cockpit
-- =================

ft.setup = function()
	tt('Seat Ground Safety Lever')
	tt('Flaps Power Switch', { value = 0.5 })
	tt('RWR Power/Volume Button', { value = 0.5 })
	tt('Decoy Dispenser Control', { value = 0.4 })
	tt('Jammer Control', { value = 0.2 })

	ttt('MPCD Left Button 2')
	tt('Display Brightness Control', { value = 0.9 })
	tt('HUD Off/Brightness Control', { value = 1 })
	tt('Parking Brake Lever')
	ttn('STO Stop Lever')

	tt('Comm 1 Volume Control', { value = 0.7 })
	tt('Comm 2 Volume Control', { value = 0.7 })
	tt('Master Arm Switch')
	tt('DMT Toggle On/Off')

	ttn('FLIR Power Switch')
	tt('INS Mode Knob', { value = 0.4 })
end

-- =================
-- Starts the jet.
-- =================

ft.firstspool = true
ft.startAttempts = 0
ft.maxStartAttempts = 45

ft.start = function(action)
	local valid = {
		engspool = 'engspool',
		posteng = 'posteng',
	}
	action = valid[action] or ''

	if action == '' then
		net.recv_chat('AV8 start, throttle off')
		ft.startAttempts = 0
		ft.firstspool = true

		ttn('Canopy Handle')
		ttn('Oxygen Switch')
		tt('Battery Switch')
		tt('Throttle Cutoff Lever')
		Export.LoSetCommand(2004, 1)

		tt('Fuel Shutoff Lever')
		tt('DECS Switch')
		tt('Master Caution')
		tt('MPCD Left Off/Brightness Control')
		tt('MPCD Right Off/Brightness Control')
		ttt('MPCD Right Button 11')
		tt('Engine Start Switch')
		tt('Parking Brake Lever')

		ft.start('engspool')
		return

	elseif action == 'engspool' then
		ft.startAttempts = ft.startAttempts + 1

		if ft.startAttempts > ft.maxStartAttempts then
			loglocal('AV8 start timed out waiting for RPM', 2)
			return
		end

		local info = Export.LoGetEngineInfo()
		if not info or not info.RPM then
			press('', { delay = 1, fn = ft.start, arg = 'engspool' })
			return
		end
		local rpm = info.RPM
		loglocal(string.format(
			'engspool rpm: %.1f : %.1f (attempt %d)',
			rpm.left or 0, rpm.right or 0, ft.startAttempts
		), 4)

		if rpm.left < 5 then
			press('', { delay = 1, fn = ft.start, arg = 'engspool' })
			return
		elseif rpm.left < 10 then
			if ft.firstspool then
				Export.LoSetCommand(2004, -1)
				ft.firstspool = false
			else
				Export.LoSetCommand(2004, 1)
			end
			press('', { delay = 1, fn = ft.start, arg = 'engspool' })
			return
		else
			ft.start('posteng')
			return
		end

	elseif action == 'posteng' then
		ft.setup()
		tt('Master Caution')
		loglocal('AV8 start complete', 1)
	end
end

-- =================
-- Cockpit night lighting
-- =================

ft.night = function()
	tt('EDP Brightness Control', { value = 0.3 })
	ttn('MPCD Left Display NIGHT Mode')
	ttn('MPCD Right Display NIGHT Mode')
	tt('Instruments Lights', { value = 0.3 })
	tt('Console Lights', { value = 0.3 })
	tt('Annunciator Lights', { value = 0.3 })
	ttn('External Auxiliary Lights Switch')

	ttn('FLIR Power Switch')
	tt('HUD Video Brightness Control', { value = 0.35 })
	tt('HUD Video Contrast Control', { value = 0.55 })
	ttn('HUD Display Mode Switch')
	ttt('', { action = hotas_commands.SSS_CENTER, device = devices.MSC })
end

-- =================
-- Waypoint / LatLon
-- =================

ft.lt = {
	notes = [[Waypoint input requires DATA page. Adds new wp to the list (wp#77).]],
	coordsType = { format = 'DMS', precision = 0, lonDegreesWidth = 3 },
	wpentry = 'LATeLONe#ALTe',

	prewp = function()
		if wps.enable then
			press('P77e@')
		end
	end,
}

-- =================
-- UFC / ODU
-- =================

ft.kp = (function()
	local diffiv = 0
	local map = {}

	for i = 1, 9 do
		map[tostring(i)] = click(ufc_commands['Button_' .. i], devices.UFCCONTROL, 1, diffiv)
	end

	map['0'] = click(ufc_commands.Button_0, devices.UFCCONTROL, 1, diffiv)
	map.e = click(ufc_commands.Button_ENT, devices.UFCCONTROL, 1, diffiv)
	map.N = click(ufc_commands.Button_2, devices.UFCCONTROL, 1, diffiv)
	map.E = click(ufc_commands.Button_6, devices.UFCCONTROL, 1, diffiv)
	map.W = click(ufc_commands.Button_4, devices.UFCCONTROL, 1, diffiv)
	map.S = click(ufc_commands.Button_8, devices.UFCCONTROL, 1, diffiv)
	map.P = click(mpcd_l_commands.Button_19, devices.MPCD_LEFT, 1, diffiv)

	assign_seq(map, '!@#$%', odu_commands, 1, devices.ODUCONTROL, function(cmd)
		return click(cmd, devices.ODUCONTROL, 1, 0.25)
	end)

	return map
end)()

return ft
