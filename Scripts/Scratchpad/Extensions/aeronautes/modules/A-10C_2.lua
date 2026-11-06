--[[
	A-10C Warthog II

	Functions:
		start - cold-start cockpit items
		setup - radios, HARS, Scorpion, lighting, misc
]]

wpseq({ cur = 3, diff = 1 })

local ft = {}

ft.scratchpadFormats = {
	DDM = true,
	MGRS = true,
}
ft.order = { 'start', 'setup' }

-- =================
-- Cold start
-- =================

ft.start = function()
	tt('Canopy Open/Hold/Close', { value = 0.5 })
	delay(1.5)
	ttf('Canopy Open/Hold/Close')

	ttn('Seat Arm Handle')

	ttn('HARS Fast Erect')
	tt('HARS SLAVE-DG mode')
	tt('HARS N/S toggle switch')
	tt('HARS MAG VAR', { value = 0 })

	ttf('Emergency Brake')

	tt('Intercom volume', { value = 0.6 })
	tt('Selector switch', { value = 0.2 })

	ttf('Extend boarding ladder cover')
end

-- =================
-- Setup
-- =================

ft.setup = function()
	tt('Volume', { device = devices.VHF_AM_RADIO, value = 0.7 })
	tt('Frequency Mode Dial', { device = devices.VHF_AM_RADIO, value = 0.1 })
	tt('Squelch / TONE', { device = devices.VHF_AM_RADIO })

	tt('Volume', { device = devices.VHF_FM_RADIO, value = 0.7 })
	tt('Frequency Mode Dial', { device = devices.VHF_FM_RADIO, value = 0.1 })
	tt('Squelch / TONE', { device = devices.VHF_FM_RADIO })

	ttn('ARC-210, brightness increase')
	tt('ARC-210, lower FSK')

	ttn('Zeroise Cover')
	tt('Power switch', { device = devices.KY_58 })
	tt('Mode switch', { device = devices.KY_58, value = 0.1 })

	ttn('HARS Push-To-Sync')
	tt('HARS Latitude Dial', { value = 0.5 })

	tt('Scorpion HMCS Power', { value = 1 })

	tt('IFF antenna switch', { value = 0.5 })
	tt('UHF antenna switch', { value = 0.5 })
	tt('Adjust Display Brightness', { device = devices.AN_ALR69V, value = 0.7 })

	ttn('Toggle Mirrors')
	ttn('Push to set')
	ttf('Anti-G suit valve test button')

	tt('Function control toggle switch', { value = 0.1 })
end

-- =================
-- Waypoint / LatLon
-- =================

ft.lt = {
	notes = [[Waypoint input requires WAYPT menu, L/L mode. Default to LSK 7 to increment wp number]],
	coordsType = { format = 'DDM', precision = 3, lonDegreesWidth = 3 },
	wpentry = 'LAT#LON$ALT@',
	customfn = Moduledir .. 'A-10C_2.lua',

	prewp = function(arg)
		if not wps.enable then return end
		press('&')
		if wps.diff > 0 and arg and arg.name and #arg.name > 0 then
			local name = string.lower(
				string.gsub(string.sub(arg.name, 1, 12), '[^%a%d%./ ]', '')
			)
			press(name .. '%')
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
				wps.cur = 2050
			elseif wps.cur > 2050 then
				wps.cur = 1
			end
		end
		wps:button()
	end,

	postwp = function()
		wps.update()
	end,

	llconvert = function(result)
		result = string.gsub(result, "[°'\" .]", "")
		return string.lower(result)
	end,
}

-- =================
-- CDU
-- =================

ft.kp = (function()
	local diffiv = 0
	local dev = devices.CDU
	local function cdu(cmd)
		return tap(cmd, dev, 1, 0, diffiv, diffiv)
	end
	local map = {}
	assign_seq(map, '1234567890./', device_commands, 15, dev, cdu)
	assign_seq(map, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', device_commands, 27, dev, cdu)
	assign_seq(map, '!@#$%^&*', device_commands, 1, dev, cdu)
	map[' '] = cdu(device_commands.Button_57)
	return map
end)()

return ft
