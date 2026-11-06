--[[
	OH-58D Kiowa

	Functions:
		setup - misc cockpit setup after autostart
		start - start sequence (throttle should be at max if bound to an axis)
]]

wpseq({ enable = true, cur = 1, diff = 1 })

local ft = {}

ft.scratchpadFormats = {
	DDM = { precision = 2, lonDegreesWidth = 3 },
	MGRS = true,
}
ft.order = { 'start', 'setup' }

-- =================
-- setup
-- =================

ft.setup = function()
	ttf('MMS Laser Power Switch')
	ttf('Master Switch')
	tt('MMS Mode Selector', { value = 0.6 })
	tt('Transmit Selector Switch', { value = 0.3 })
	tt('Radio Select Switch 2/4', { value = 0.2 })
	ttn('Select Switch')
	ttn('Select Switch')
	ttn('Select Switch')
	tt('Line Address Key B2')
	tt('Line Address Key B1', { device = devices.RMFD })

	Export.LoSetCommand(7)
	ttn('', { device = devices.COMMON, action = device_commands.Button_2 })
	ttn('', { device = devices.COMMON, action = device_commands.Button_5 })
	ttn('', { device = devices.COMMON, action = device_commands.Button_1 })
	ttn('', { device = devices.COMMON, action = device_commands.Button_5 })
end

-- =================
-- start
-- =================

ft.start = function(action)
	local valid = {
		engspool = 'engspool',
		posteng = 'posteng',
	}
	action = valid[action] or ''

	if action == '' then
		net.recv_chat('Begin start')

		ttf('Essential Bus Run/Start Switch')
		ttn('FADEC Circuit Breaker Switch')
		ttn('Ignition Circuit Breaker Switch')
		ttn('Ignition Keylock Switch')
		ttn('Battery 1 Switch')
		ttt('Acknowledge/Recall Switch', { onvalue = -1 })

		ttn('', { device = devices.FUEL, action = device_commands.Button_5 })
		ttn('Start Switch')

		ft.start('engspool')

	elseif action == 'engspool' then
		local info = Export.LoGetEngineInfo()
		if not info or not info.RPM then
			press('', { delay = 1, fn = ft.start, arg = 'engspool' })
			return
		end
		local rpm = info.RPM
		loglocal('engspool rpm: ' .. rpm.left .. ' : ' .. rpm.right, 4)

		if rpm.left < 63 then
			loglocal('engspool 1 true ' .. DCS.getRealTime(), 4)
			if rpm.left > 1 then
				ttf('Start Switch')
				ttn('', { device = devices.FUEL, action = device_commands.Button_6 })
			end
			ttt('Acknowledge/Recall Switch', { onvalue = -1 })
			press('', { delay = 1, fn = ft.start, arg = 'engspool' })
		else
			loglocal('engspool done, advancing to posteng', 4)
			cancelmacro()
			ft.start('posteng')
			return
		end

	elseif action == 'posteng' then
		ttn('DC Generator Switch')
		ttn('AC Generator Switch')
		ttn('Essential Bus Run/Start Switch')
		ttn('Fuel Boost Switch')

		ttn('Power Switch')
		ttn('Pitch/Roll Engage Switch')
		ttn('Yaw Engage Switch')
		ttn('BIT/Reset Switch')
		ttn('Radar Warning Circuit Breaker Switch')
		ttn('CMWS Circuit Breaker Switch')

		ttn('On/Off/Test Knob')
		ttn('Arm/Safe Switch')
		ttn('Auto/Bypass Switch')

		ft.setup()
		net.recv_chat('End start. Wait for NAV align')
	end
end

-- =================
-- Waypoint / LatLon
-- =================

ft.lt = {
	notes = [[Waypoint input requires the New WP page and LatLon mode. Store MFD button automatically increments current wp number.]],
	coordsType = { format = 'DDM', precision = 2, lonDegreesWidth = 3 },
	wpentry = '@~LAT_#~LON_$~ALT_',

	prewp = function(arg)
		if arg and arg.name and #arg.name > 0 then
			local ident = string.upper(
				string.gsub(string.sub(arg.name, 1, 5), '[^%a%d%-%.]', '')
			)
			ident = string.sub(tostring(wps.cur) .. ident, 1, 6)
			press('!~' .. ident .. '_')
		end
	end,

	updatewp = function(num)
		if wps.enable and wps.cur ~= -1 then
			wps.cur = wps.cur + wps.diff
			if wps.cur > 99 then
				wps.cur = 1
			elseif wps.cur < 1 then
				wps.cur = 99
			end
		end
		wps:button()
	end,

	postwp = function()
		press(')')
		wps.update()
	end,
}

-- =================
-- MFK / RMFD
-- =================

ft.kp = (function()
	local diffiv = 0

	local function mfk(cmd)
		return tap(cmd, devices.MFK, 1, 0, diffiv, diffiv)
	end

	local function rmfd(cmd)
		return tap(cmd, devices.RMFD, 1, 0, diffiv, diffiv)
	end

	local map = {}

	assign_seq(map, '1234567890', device_commands, 6, devices.MFK, mfk)
	assign_seq(map, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', device_commands, 25, devices.MFK, mfk)

	map['~'] = mfk(device_commands.Button_17)
	map['_'] = mfk(device_commands.Button_23)

	assign_seq(map, '!@#$%', device_commands, 1, devices.RMFD, rmfd)
	assign_seq(map, '^&*()', device_commands, 13, devices.RMFD, rmfd)

	return map
end)()

return ft
