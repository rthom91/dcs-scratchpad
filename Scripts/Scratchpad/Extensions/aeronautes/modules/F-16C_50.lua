--[[
	F-16C Block 50

	Functions:
		start - engine start + stored heading alignment
		setup - modern systems configuration (preferred)
		WIP-mfd - incomplete MFD page helper
		DEPREC-fence - legacy full fence sequence
]]

wpseq({ menus = 'r4', cur = -1, diff = 1 })

local ft = {}

ft.scratchpadFormats = {
	DDM = { lonDegreesWidth = 3 },
	MGRS = true,
}
ft.order = { 'start', 'setup', 'WIP-mfd', 'DEPREC-fence' }

-- =================
-- Helpers
-- =================

local function osbButtons()
	local b = {}
	for i = 1, 20 do
		b[i] = mfd_commands['OSB_' .. i]
	end
	return b
end

local function pressUfc(cmd, value)
	push_stop_command(0, { device = devices.UFC, action = cmd, value = value or 1.0 })
end

local function pressRelUfc(cmd)
	pressUfc(cmd, 1.0)
	pressUfc(cmd, -1.0)
end

local function pressOSB(mfd, osb, times)
	times = times or 1
	for _ = 1, times do
		push_stop_command(0, { device = mfd, action = osb, value = 1.0 })
	end
end

-- =================
-- Cold start
-- =================

ft.start = function(action)
	action = action or ''
	if action == '' then
		ttn('MAIN PWR Switch, MAIN PWR/BATT/OFF')
		tt('JFS Switch, START 1/OFF/START 2', { value = -1 })
		tt('Canopy Switch, OPEN/HOLD/CLOSE(momentarily)', { value = -1 })
		delay(5)
		ttf('Canopy Switch, OPEN/HOLD/CLOSE(momentarily)')
		ttn('Canopy Handle, UP/DOWN')
		tt('Ejection Safety Lever, ARMED/LOCKED')
		ttn('LEFT HDPT Switch, ON/OFF')
		ttn('RIGHT HDPT Switch, ON/OFF')
		ttn('FCR Switch, FCR/OFF')
		tt('MMC Switch, MMC/OFF')
		tt('ST STA Switch, ST STA/OFF')
		tt('MFD Switch, MFD/OFF')
		tt('UFC Switch, UFC/OFF')
		tt('GPS Switch, GPS/OFF')
		tt('MIDS LVT Knob, ZERO/OFF/ON', { value = 1 })
		ft.start('engspool')
	elseif action == 'engspool' then
		local info = Export.LoGetEngineInfo()
		if not info or not info.RPM then
			press('', { delay = 1, fn = ft.start, arg = 'engspool' })
			return
		end
		local rpm = info.RPM
		loglocal('engspool rpm: ' .. rpm.left .. ' : ' .. rpm.right, 4)
		if rpm.left < 21 then
			loglocal('engspool 1 true ' .. DCS.getRealTime(), 4)
			press('', { delay = 1, fn = ft.start, arg = 'engspool' })
			return
		else
			Export.LoSetCommand(311)
			loglocal('engspool done, advancing to posteng', 4)
			cancelmacro()
			ft.start('posteng')
			return
		end
	elseif action == 'posteng' then
		tt('INS Knob, OFF/STOR HDG/NORM/NAV/CAL/INFLT ALIGN/ATT', { value = 0.1 })
		tt('ICP HUD Symbology Intensity Knob', { value = 1 })
	end
end

-- =================
-- Modern setup (preferred over DEPREC-fence)
-- =================

ft.setup = function()
	tt('IFF MASTER Knob, OFF/STBY/LOW/NORM/EMER', { value = 0.3 })
	tt('MASTER Switch, OFF/ALL/A-C/FORM/NORM', { value = 0.1 })
	ttn('ECM Power Switch')
	tt('ECM XMIT Switch', { value = -1 })
	for i = 1, 6 do
		ttn('ECM ' .. i .. ' Button')
	end
	ttn('RWR Indicator Control POWER Button')
	ttn('RWR Indicator Control SEARCH Button')
	ttn('RWR Indicator Control MODE Button')
	ttn('RWR 555 Switch, ON/OFF')
	ttn('JMR Source Switch, ON/OFF')
	ttn('CH Expendable Category Switch, ON/OFF')
	ttn('FL Expendable Category Switch, ON/OFF')
	tt('MODE Knob, OFF/STBY/MAN/SEMI/AUTO/BYP', { value = 0.2 })
	tt('HMCS SYMBOLOGY INT Knob', { value = 0.8 })
	ttn('LANDING TAXI LIGHTS Switch, LANDING/OFF/TAXI')
	ttf('ILS Power Knob')
	ttf('TACAN Knob')
	ttn('MASTER ARM Switch, MASTER ARM/OFF/SIMULATE')
	ttf('LASER ARM Switch, ARM/OFF')
	ttf('RF Switch, SILENT/QUIET/NORM')
	-- Bullseye enable
	press('L080')
	-- HMCS pit unblank
	press('L0cd0r')
	ttn('LEFT HDPT Switch, ON/OFF')
	ttn('RIGHT HDPT Switch, ON/OFF')
	ttn('FCR Switch, FCR/OFF')
	ttn('RDR ALT Switch, RDR ALT/STBY/OFF')
	-- Fuel gauge to centerline
	push_stop_command(0, { device = devices.FUEL_INTERFACE, action = fuel_commands.FuelQtySelSw, value = 0.5 })
	-- Uncage SAI
	push_stop_command(0, { device = devices.SAI, action = sai_commands.cage, value = -1 })
	push_stop_command(0, { device = devices.SAI, action = sai_commands.cage, value = 0 })
	-- Temp workaround for no datalink bug
	press('Le11r')
end

-- =================
-- WIP MFD page helper (incomplete)
-- =================

ft['WIP-mfd'] = function()
	local OSB = osbButtons()
	local menu = {
		BLANK = { 1 }, HAD = { 2 }, SMS = { 6 }, HSD = { 7 },
		DTE = { 8 }, TEST = { 9 }, FLCS = { 10 }, WPN = { 18 },
		TGP = { 19 }, FCR = { 20 },
	}
	-- TODO: drive page programming with OSB / menu
end

-- =================
-- Legacy fence sequence (still functional)
-- =================

ft['DEPREC-fence'] = function()
	local dt = 0
	local dt_mto = 0
	local function set_mfd_page(mfd, osb)
		pressOSB(mfd, osb, 2)
	end
	local function clear_mfd_page(mfd, osb)
		set_mfd_page(mfd, osb)
		pressOSB(mfd, mfd_commands.OSB_1)
	end
	tt('ICP HUD Symbology Intensity Knob', { value = 1 })
	push_stop_command(2.0, { message = _('FENCE IN IS RUNNING'), message_timeout = start_sequence_time })
	-- IFF
	push_stop_command(dt, { message = _('- IFF MASTER KNOB'), message_timeout = dt_mto })
	push_stop_command(dt, { device = devices.IFF_CONTROL_PANEL, action = iff_commands.MasterKnob, value = 0.3 })
	-- External lights
	push_stop_command(dt, { message = _('- External lights covert'), message_timeout = dt_mto })
	push_stop_command(dt, { device = devices.EXTLIGHTS_SYSTEM, action = extlights_commands.Master, value = 0.1 })
	-- ECM
	push_stop_command(dt, { message = _('- ENABLE ECM'), message_timeout = 1 + dt_mto })
	push_stop_command(dt, { device = devices.ECM_INTERFACE, action = ecm_commands.PwrSw, value = 1.0 })
	push_stop_command(dt, { device = devices.ECM_INTERFACE, action = ecm_commands.XmitSw, value = -1.0 })
	local ecmBtns = { 'OneBtn', 'TwoBtn', 'ThreeBtn', 'FourBtn', 'FiveBtn', 'SixBtn' }
	for i = 1, 6 do
		push_stop_command(dt, { device = devices.ECM_INTERFACE, action = ecm_commands[ecmBtns[i]], value = 1.0 })
	end
	-- RWR / CMDS
	push_stop_command(dt, { message = _('- ENABLE RWR AND CMDS'), message_timeout = 1 + dt_mto })
	push_stop_command(dt, { device = devices.RWR, action = rwr_commands.Power, value = 1.0 })
	push_stop_command(dt, { device = devices.RWR, action = rwr_commands.Search, value = 1.0 })
	push_stop_command(dt, { device = devices.RWR, action = rwr_commands.Mode, value = 1.0 })
	push_stop_command(dt, { device = devices.CMDS, action = cmds_commands.RwrSrc, value = 1.0 })
	push_stop_command(dt, { device = devices.CMDS, action = cmds_commands.JmrSrc, value = 1.0 })
	push_stop_command(dt, { device = devices.CMDS, action = cmds_commands.ChExp, value = 1.0 })
	push_stop_command(dt, { device = devices.CMDS, action = cmds_commands.FlExp, value = 1.0 })
	push_stop_command(dt, { device = devices.CMDS, action = cmds_commands.Mode, value = 0.2 })
	-- HMCS
	push_stop_command(dt, { message = _('- HMCS SYMBOLOGY INT POWER KNOB - INT'), message_timeout = dt_mto })
	push_stop_command(dt, { device = devices.HMCS, action = hmcs_commands.IntKnob, value = 0.8 })
	-- Landing lights
	push_stop_command(dt, { message = _('- LANDING LIGHTS'), message_timeout = dt_mto })
	push_stop_command(dt, { device = devices.EXTLIGHTS_SYSTEM, action = extlights_commands.LandingTaxi, value = 1.0 })
	-- Volumes off
	push_stop_command(dt, { message = _('- ILS VOL OFF'), message_timeout = dt_mto })
	push_stop_command(dt, { device = devices.INTERCOM, action = intercom_commands.ILS_PowerKnob, value = 0.0 })
	push_stop_command(dt, { message = _('- TACAN VOL OFF'), message_timeout = dt_mto })
	push_stop_command(dt, { device = devices.INTERCOM, action = intercom_commands.TACAN_Knob, value = 0.0 })
	-- Armament
	push_stop_command(dt, { message = _('- ARMAMENT SWITCH'), message_timeout = dt_mto })
	push_stop_command(dt, { device = devices.MMC, action = mmc_commands.MasterArmSw, value = 1.0 })
	push_stop_command(dt, { device = devices.SMS, action = sms_commands.LaserSw, value = 1.0 })
	push_stop_command(dt, { device = devices.UFC, action = ufc_commands.RF_Sw, value = 1.0 })
	-- MFD setup
	push_stop_command(dt, { message = _('- SET UP MFDS'), message_timeout = 1 + dt_mto })
	-- Dogfight override
	push_stop_command(dt, { device = devices.HOTAS, action = hotas_commands.THROTTLE_DOG_FIGHT, value = 1.0 })
	pressOSB(devices.MFD_RIGHT, mfd_commands.OSB_13, 2)
	pressOSB(devices.MFD_RIGHT, mfd_commands.OSB_7)
	pressOSB(devices.MFD_RIGHT, mfd_commands.OSB_2)
	pressOSB(devices.MFD_RIGHT, mfd_commands.OSB_6)
	pressOSB(devices.MFD_RIGHT, mfd_commands.OSB_12, 2)
	pressOSB(devices.MFD_RIGHT, mfd_commands.OSB_19)
	pressOSB(devices.MFD_RIGHT, mfd_commands.OSB_13)
	-- Missile override
	push_stop_command(dt, { device = devices.HOTAS, action = hotas_commands.THROTTLE_DOG_FIGHT, value = -1.0 })
	pressOSB(devices.MFD_RIGHT, mfd_commands.OSB_13, 2)
	pressOSB(devices.MFD_RIGHT, mfd_commands.OSB_7)
	pressOSB(devices.MFD_RIGHT, mfd_commands.OSB_12, 2)
	pressOSB(devices.MFD_RIGHT, mfd_commands.OSB_19)
	pressOSB(devices.MFD_RIGHT, mfd_commands.OSB_13)
	-- Az/range
	pressOSB(devices.MFD_LEFT, mfd_commands.OSB_18)
	pressOSB(devices.MFD_LEFT, mfd_commands.OSB_20)
	-- Exit overrides
	push_stop_command(dt, { device = devices.HOTAS, action = hotas_commands.THROTTLE_DOG_FIGHT, value = 0.0 })
	-- Clear NAV pages
	push_stop_command(dt, { message = _('- CLEAR NAV MFD'), message_timeout = 1 + dt_mto })
	clear_mfd_page(devices.MFD_LEFT, mfd_commands.OSB_12)
	clear_mfd_page(devices.MFD_LEFT, mfd_commands.OSB_13)
	pressOSB(devices.MFD_LEFT, mfd_commands.OSB_14)
	pressOSB(devices.MFD_LEFT, mfd_commands.OSB_18)
	pressOSB(devices.MFD_LEFT, mfd_commands.OSB_20)
	-- Clear AA pages
	push_stop_command(dt, { message = _('- CLEAR AA MFD'), message_timeout = 1 + dt_mto })
	pressRelUfc(ufc_commands.AA)
	clear_mfd_page(devices.MFD_LEFT, mfd_commands.OSB_12)
	clear_mfd_page(devices.MFD_LEFT, mfd_commands.OSB_13)
	pressOSB(devices.MFD_LEFT, mfd_commands.OSB_14)
	-- Clear AG pages
	push_stop_command(dt, { message = _('- CLEAR AG MFD'), message_timeout = 1 + dt_mto })
	pressRelUfc(ufc_commands.AG)
	pressOSB(devices.MFD_LEFT, mfd_commands.OSB_14, 2)
	pressOSB(devices.MFD_LEFT, mfd_commands.OSB_1)
	pressOSB(devices.MFD_LEFT, mfd_commands.OSB_13, 2)
	pressOSB(devices.MFD_LEFT, mfd_commands.OSB_2)
	pressOSB(devices.MFD_LEFT, mfd_commands.OSB_12, 2)
	pressOSB(devices.MFD_LEFT, mfd_commands.OSB_19)
	-- WPN page
	pressOSB(devices.MFD_RIGHT, mfd_commands.OSB_12, 2)
	pressOSB(devices.MFD_RIGHT, mfd_commands.OSB_18)
	pressRelUfc(ufc_commands.AG)
	-- Bullseye
	push_stop_command(dt, { message = _('- ENABLE BULLSEYE'), message_timeout = 1 + dt_mto })
	pressUfc(ufc_commands.LIST)
	pressUfc(ufc_commands.DIG0_M_SEL)
	pressUfc(ufc_commands.DIG8_FIX)
	pressUfc(ufc_commands.DIG0_M_SEL)
	-- HMCS pit unblank
	push_stop_command(dt, { message = _('- DISABLE HMCS PIT BLANK '), message_timeout = 1 + dt_mto })
	pressUfc(ufc_commands.LIST)
	pressUfc(ufc_commands.DIG0_M_SEL)
	pressUfc(ufc_commands.RCL)
	push_stop_command(dt, { device = devices.UFC, action = ufc_commands.DCS_DOWN, value = -1.0 })
	pressUfc(ufc_commands.DIG0_M_SEL)
	-- Return ICP
	push_stop_command(dt, { device = devices.UFC, action = ufc_commands.DCS_RTN, value = -1.0 })
	push_stop_command(dt, { device = devices.UFC, action = ufc_commands.DCS_RTN, value = 0.0 })
	-- Power hardpoints / FCR
	push_stop_command(dt, { message = _('- POWER INTAKE HARDPOINTS'), message_timeout = 1 + dt_mto })
	push_stop_command(dt, { device = devices.SMS, action = sms_commands.LeftHDPT, value = 1.0 })
	push_stop_command(dt, { device = devices.SMS, action = sms_commands.RightHDPT, value = 1.0 })
	push_stop_command(dt, { device = devices.FCR, action = fcr_commands.PwrSw, value = 1.0 })
	-- Fuel qty centerline + stick hide
	push_stop_command(dt, { message = _('- CENTERLINE FUEL GAUGE'), message_timeout = 1 + dt_mto })
	push_stop_command(dt, { device = devices.FUEL_INTERFACE, action = fuel_commands.FuelQtySelSw, value = 0.5 })
	push_stop_command(dt, { device = devices.CPT_MECH, action = cpt_commands.StickHide, value = 1.0 })
	push_stop_command(dt, { message = _('FENCE IN COMPLETE'), message_timeout = std_message_timeout })
end

-- =================
-- Waypoint / LatLon
-- =================

ft.lt = {
	notes = [[Waypoint input]],
	coordsType = { format = 'DDM', lonDegreesWidth = 3 },
	menus = 'r4',
	wpentry = 'LATedLONedALTe',
	prewp = function()
		if not wps.enable then return end
		if wps.menus ~= '' then
			loglocal('F16 prewp(): menus press() ' .. wps.menus, 3)
			press(wps.menus)
		end
		if wps.cur > 0 then
			press(tostring(wps.cur) .. 'edd')
		else
			if wps.diff > 0 then
				press('pdd')
			elseif wps.diff < 0 then
				press('mdd')
			end
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
			wps.cur = 699
		elseif wps.cur > 699 then
			wps.cur = 1
		end
		wps:button()
	end,
	postwp = function()
		press('dd')
		wps.update()
	end,
}

-- =================
-- UFC
-- =================

ft.kp = (function()
	local diffiv = 0
	local dev = devices.UFC
	return {
		['0'] = click(ufc_commands.DIG0_M_SEL, dev, 1, diffiv),
		['1'] = click(ufc_commands.DIG1_T_ILS, dev, 1, diffiv),
		['2'] = click(ufc_commands.DIG2_ALOW, dev, 1, diffiv),
		['3'] = click(ufc_commands.DIG3, dev, 1, diffiv),
		['4'] = click(ufc_commands.DIG4_STPT, dev, 1, diffiv),
		['5'] = click(ufc_commands.DIG5_CRUS, dev, 1, diffiv),
		['6'] = click(ufc_commands.DIG6_TIME, dev, 1, diffiv),
		['7'] = click(ufc_commands.DIG7_MARK, dev, 1, diffiv),
		['8'] = click(ufc_commands.DIG8_FIX, dev, 1, diffiv),
		['9'] = click(ufc_commands.DIG9_A_CAL, dev, 1, diffiv),
		N = click(ufc_commands.DIG2_ALOW, dev, 1, diffiv),
		E = click(ufc_commands.DIG6_TIME, dev, 1, diffiv),
		W = click(ufc_commands.DIG4_STPT, dev, 1, diffiv),
		S = click(ufc_commands.DIG8_FIX, dev, 1, diffiv),
		L = click(ufc_commands.LIST, dev, 1, diffiv),
		e = click(ufc_commands.ENTR, dev, 1, diffiv),
		c = click(ufc_commands.RCL, dev, 1, diffiv),
		p = click(ufc_commands.DED_INC, dev, 1, diffiv),
		m = click(ufc_commands.DED_DEC, dev, 1, diffiv),
		r = tap(ufc_commands.DCS_RTN, dev, -1, 0, diffiv, diffiv),
		s = tap(ufc_commands.DCS_SEQ, dev, -1, 0, diffiv, diffiv),
		u = tap(ufc_commands.DCS_UP, dev, 1, 0, diffiv, 0),
		d = tap(ufc_commands.DCS_DOWN, dev, -1, 0, diffiv, 0),
	}
end)()

return ft
