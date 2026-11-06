--[[
	CH-47F Chinook

	Functions:
		setup - post-start / autostart cockpit setup
		night - reduce MFD and console brightness
]]

wpseq({ cur = 1, diff = 1 })

local ft = {}

ft.scratchpadFormats = {
	DDM = { precision = 3, lonDegreesWidth = 3 },
	MGRS = true,
}
ft.order = { 'setup', 'night' }

-- =================
-- Setup - Settings applied after start or autostart
-- =================

ft.setup = function()
	ttn('', { device = devices.CDU_RIGHT, action = device_commands.Button_64 })

	press('!#~')

	ttn('', { device = devices.AN_ALE47, action = device_commands.Button_5 })
	ttn('', { device = devices.AN_ALE47, action = device_commands.Button_7 })
end

-- =================
-- Night - Reduce MFD and canted console brightness
-- =================

ft.night = function()
	local mfds = {
		devices.MFD_COPILOT_OUTBOARD,
		devices.MFD_COPILOT_INBOARD,
		devices.MFD_CENTER,
		devices.MFD_PILOT_INBOARD,
		devices.MFD_PILOT_OUTBOARD,
	}

	for _, device in pairs(mfds) do
		tt('', { device = device, action = device_commands.Button_33, value = 1 })
		tt('', { device = device, action = device_commands.Button_33, value = 0.5 })
	end

	tt('', { device = devices.CANTED_CONSOLE, action = device_commands.Button_38, value = 0.2 })
	tt('', { device = devices.CANTED_CONSOLE, action = device_commands.Button_41, value = 0.2 })
end

-- =================
-- Waypoint / LatLon
-- =================

ft.lt = {
	notes = 'LatLon requires right CDU on IDX > PROC/PATT > ACP LIST > ACP page',
	dirname = lfs.currentdir() .. [[Mods\aircraft\CH-47F]],
	coordsType = { format = 'DDM', precision = 3, lonDegreesWidth = 3 },
	wpentry = '<LATLON!ALT#',

	llconvert = function(result)
		result = string.gsub(result, "[°'\"]", "")
		result = string.gsub(result, "([NEWS]) ", "%1")
		return result
	end,

	prewp = function()
		if wps.cur > 0 then
			press(tostring(wps.cur) .. '!')
		else
			press('?')
		end
	end,

	updatewp = function(num)
		if wps.enable and wps.cur ~= -1 then
			if type(num) == 'number' then
				wps.cur = num
			else
				wps.cur = wps.cur + wps.diff
			end

			if wps.cur > 100 then
				wps.cur = 1
			elseif wps.cur < 1 then
				wps.cur = 100
			end
		end
		wps:button()
	end,

	postwp = function(arg)
		if wps.cur > 0 then
			local ident = ''
			if arg and arg.name and #arg.name > 0 then
				ident = string.upper(
					string.gsub(string.sub(arg.name, 1, 9), '[^%a%d]', '')
				)
			else
				ident = string.char(string.byte('A') + wps.cur - 1)
			end
			press('/' .. ident .. '@')
		end
		wps.update()
	end,
}

-- =================
-- Right CDU
-- =================

ft.kp = (function()
	local diffiv = 0
	local map = {}

	local function cdu(cmd)
		return tap(cmd, devices.CDU_RIGHT, 1, 0, diffiv, diffiv)
	end

	assign_seq(map, '0123456789', device_commands, 10, devices.CDU_RIGHT, cdu)
	assign_seq(map, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', device_commands, 23, devices.CDU_RIGHT, cdu)

	map['.'] = cdu(device_commands.Button_20)
	map['/'] = cdu(device_commands.Button_21)
	map['?'] = cdu(device_commands.Button_6)
	map['<'] = cdu(device_commands.Button_8)

	local lskChars = '!@#$%^&*()`~'
	for i = 1, #lskChars do
		map[lskChars:sub(i, i)] = cdu(device_commands['Button_' .. (49 + i)])
	end

	return map
end)()

return ft
