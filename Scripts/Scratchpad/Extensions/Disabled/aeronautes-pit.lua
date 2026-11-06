--[[
	Functions:
	Handles cockpit macros, waypoint entry, unit-specific modules,
	and the Scratchpad button UI.
]]

helper = nil

local version = 0.70

local socket = require('socket')
lfs = require('lfs')

-- =================
-- Paths and constants
-- =================

Scratchdir = lfs.writedir() .. [[Scratchpad\ext\]]
Scratchpadfn = 'aeronautes-pit.txt'

local Apitlibsubdir = [[Scripts\Scratchpad\Extensions\aeronautes\]]
Apitlibdir = lfs.writedir() .. Apitlibsubdir

local Modulesubdir = [[Scripts\Scratchpad\Extensions\aeronautes\modules\]]
Moduledir = lfs.writedir() .. Modulesubdir

Globalcustomfile = Moduledir .. 'Globalcustom.lua'

dbglvl = 1
itval = 0.1 -- default input delay between macro steps
unittype = '' -- DCS name for current module
unittab = {} -- table of module-specific functions
kp = {} -- keypad table for wp() / press()
ttlist = {} -- tooltips from clickabledata.lua
ttrie = {} -- trie for tooltips

-- =================
-- Macro execution state
-- =================

domacro = {
	flag = true,
	idx = 1,
	ctr = 0,
	inp = {},
	listeneradded = false,
}

-- =================
-- History buffer
-- =================

Hist = {
	enable = true,
	linenum = 0,
	buf = '',
	add = function(self, msg)
		local date = os.date('*t')
		local dateStr = string.format('%i:%02i:%02i ', date.hour, date.min, date.sec)
		if not msg then
			msg = '""'
		end
		self.buf = self.buf .. dateStr .. msg .. '\n'
		self.linenum = self.linenum + 1
	end,
}

-- =================
-- Logging
-- =================

function loglocal(str, lvl)
	if not lvl then
		lvl = 0
	else
		if type(lvl) == 'table' then
			if type(lvl.debug) == 'number' then
				log('loglocal() setting lvl ' .. dbglvl .. '; ' .. lvl.debug)
				dbglvl = lvl.debug
				return
			end
		elseif type(lvl) ~= 'number' then
			log('loglocal() lvl not number; str: ' .. str)
			return
		end
	end

	if dbglvl > lvl then
		log(str)
		Hist.add(Hist, str)
	end
end

-- =================
-- Spinner animation
-- =================

local panelbytitle = {}

Spinr = {
	frames = { '/', '|', '\\', '-' },
	idx = 1,
	buf = '',

	setPageNotice = function(str)
		if not str then
			str = 'UNSET'
		end

		if panelbytitle and panelbytitle['mod'] then
			panelbytitle['mod'].button:setText(str)
		else
			loglocal('setPageNotice() no panel "mod"', 2)
		end
	end,

	run = function(self)
		if self.idx <= 1 then
			self.idx = #self.frames
		else
			self.idx = self.idx - 1
		end
		self.setPageNotice(self.frames[self.idx])
	end,

	rest = function(self)
		self.idx = 1
		if not unittype then
			self.setPageNotice('NO UNIT')
		else
			self.setPageNotice(string.sub(unittype, 1, 8))
		end
	end,

	delay = function(self)
		self.setPageNotice('D')
	end,
}

-- =================
-- Crosshair / Dot
-- =================

local Dot = {
	dlog = nil,
	vis = false,
}

local function Dotcreate()
	if Dot.dlog ~= nil then
		return
	end

	local path = lfs.writedir() .. "Scripts\\Scratchpad\\Dialogs\\CrosshairWindow.dlg"
	Dot.dlog = DialogLoader.spawnDialogFromFile(path)
	if not Dot.dlog then
		loglocal('Dotcreate: failed to load ' .. path)
		return
	end

	local screenw, screenh = dxgui.GetScreenSize()
	local x = screenw / 2 - 4
	local y = screenh / 2 - 4
	Dot.dlog:setBounds(math.floor(x), math.floor(y), 8, 8)
end

-- =================
-- Utilities
-- =================

local function copytable(src)
	local dst = {}
	for i, j in pairs(src) do
		dst[i] = j
	end
	return dst
end

local function loadlib(name)
	local path = Apitlibdir .. name
	local chunk, err = loadfile(path)
	if not chunk then
		loglocal('apit load failed ' .. path .. ': ' .. tostring(err))
		return
	end
	setfenv(chunk, getfenv(1))
	return chunk()
end

-- =================
-- Waypoint sequence state (MUST exist before cockpit.lua)
-- =================

wpsdefaults = {
	initialize = false,
	enable = true,
	diff = 1,
	cur = -1,
	default = 1,
	route = '',
	menus = '',

	update = function(val)
		if val then
			wps.cur = val
		else
			wps.cur = wps.cur + wps.diff
		end
	end,

	button = function(self)
		loglocal('wps button1 ' .. self.cur)
		if panelbytitle and panelbytitle['WP'] then
			panelbytitle['WP'].button:setText(self.cur)
			loglocal('wps button2 ' .. self.cur)
		end
	end,
}

wps = copytable(wpsdefaults)
LT = {}

-- Now safe to load
loadlib('cockpit.lua')
loadlib('waypoints.lua')

-- =================
-- Safe code loading (apcall)
-- =================

function apcall(p)
	local f, err
	loglocal('enter apcall', 4)

	if p.fn then
		local atr = lfs.attributes(p.fn)
		if atr and atr.mode == 'file' then
			f, err = loadfile(p.fn)
			if not f then
				loglocal('apcall() loadfile failed: ' .. err)
				return nil, err
			end
		else
			loglocal('apcall() not a file ' .. p.fn)
			return nil, err
		end
	elseif p.str then
		f, err = loadstring(p.str)
		if not f then
			loglocal('apcall() loadstring failed: ' .. err)
			return nil, err
		end
	else
		loglocal('apcall() unknown input p: ' .. type(p))
		return nil, err
	end

	local env = {}
	if not p.env then
		loglocal('apcall() p.env nil, default symbols')
		env = {
			push_stop_command = push_stop_command,
			push_start_command = push_start_command,
			prewp = prewp,
			wp = wp,
			wpseq = wpseq,
			press = press,
			tt = tt,
			ttn = ttn,
			ttf = ttf,
			ttt = ttt,
			delay = delay,
			loglocal = loglocal,
			getSelection = getSelection,
			switchPage = switchPage,
			getTextarea = getTextarea,
		}
		setmetatable(env, { __index = _G })
	else
		env = p.env
	end
	setfenv(f, env)

	local ok, res = pcall(f)

	if not ok then
		loglocal('apcall() pcall error ' .. res)
		if p.str then
			loglocal("Error executing macro[first 40]: " .. string.sub(p.str, 1, 40))
		end
	end

	return ok, res
end

-- =================
-- DTC / macro buffer loading
-- =================

function loadDTCBuffer(text)
	if not text or text:match('^%s*$') then
		loglocal('loadDTCBuffer() empty text, skipping')
		return nil
	end

	local chunk = loadstring(text)
	if not chunk then
		loglocal('loadDTCBuffer() not valid Lua, skipping')
		return nil
	end

	loglocal('loaddtcbuffer text len:' .. string.len(text))

	local env = {
		push_stop_command = push_stop_command,
		push_start_command = push_start_command,
		prewp = prewp,
		wp = wp,
		wpseq = wpseq,
		press = press,
		tt = tt,
		ttn = ttn,
		ttf = ttf,
		ttt = ttt,
		delay = delay,
		setitval = function(newval)
			if type(newval) == 'number' then
				itval = newval
			end
		end,
		itval = itval,
		dbglvl = dbglvl,
		kp = kp,
		LT = LT,
		loglocal = loglocal,
		unittab = unittab,
		ttlist = ttlist,
		tttrie = tttrie,
		panel = panel,
		unittype = unittype,
		getinput = getinput,
		getTextarea = getTextarea,
		extid = extid,
		Scratchdir = Scratchdir,
		Scratchpadfn = Scratchpadfn,
	}
	setmetatable(env, { __index = _G })

	local ok, res = apcall({ str = text, env = env })
	if not ok then
		loglocal('loadDTCBuffer() fail pcall')
		return nil
	end

	domacro.flag = true
end

-- =================
-- Custom module / Globalcustom assignment
-- =================

local butts = {}
local buttfn = {}
local buttfnlimit = 8
local buttfnamt = 16
local buttw = 50
local butth = 30

function assignCustom()
	local function doCustom(infn)
		loglocal('aeronautespit: using customfile ' .. infn, 1)

		local ok, res
		local funclist = {}
		local env = {
			push_stop_command = push_stop_command,
			push_start_command = push_start_command,
			prewp = prewp,
			wp = wp,
			wpseq = wpseq,
			press = press,
			tt = tt,
			ttn = ttn,
			ttf = ttf,
			ttt = ttt,
			delay = delay,
			cancelmacro = cancelmacro,
			LT = LT,
			unittype = unittype,
			loglocal = loglocal,
			switchPage = switchPage,
			switchExtPage = switchExtPage,
			extid = extid,
			Scratchdir = Scratchdir,
			Scratchpadfn = Scratchpadfn,
			Apitlibdir = Apitlibdir,
			Apitlibsubdir = Apitlibsubdir,
			Moduledir = Moduledir,
			Modulesubdir = Modulesubdir,
			getTextarea = getTextarea,
			panel = panel,
			wps = wps,
			tap = tap,
			click = click,
			assign_seq = assign_seq,
			ttlist = ttlist,
			tttrie = ttrie,
		}
		setmetatable(env, { __index = _G })

		ok, res = apcall({ fn = infn, env = env })

		if ok then
			if not res then
				loglocal('doCustom() res nil ')
				return
			end

			local fnadded = 0
			if res.order then
				local fname = ''
				for i = 1, #res.order do
					if fnadded >= buttfnlimit then
						loglocal('assignCustom() ordered func limit reached(' .. buttfnlimit .. '), no more funcs added; file: ' .. infn)
						break
					end
					fname = res.order[i]
					if type(res[fname]) == 'function' then
						fnadded = fnadded + 1
						funclist[fnadded] = { name = fname, fn = res[fname] }
					else
						loglocal('doCustom() order name not function: ' .. tostring(fname) .. ', file: ' .. tostring(infn))
					end
				end
			else
				for fname, _ in pairs(res) do
					if fnadded >= buttfnlimit then
						loglocal('assignCustom() ordered func limit reached(' .. buttfnlimit .. '), no more funcs added; file: ' .. infn)
						break
					end
					if type(res[fname]) == 'function' then
						fnadded = fnadded + 1
						funclist[fnadded] = { name = fname, fn = res[fname] }
					end
				end
			end

			if res['init'] and type(res['init']) == 'string' then
				loglocal('assignCustom() running unit init', 4)
				loadDTCBuffer(res['init'])
			end

			return ok, res, funclist
		end
	end

	for i, _ in pairs(buttfn) do
		buttfn[i] = nil
	end

	for _, j in pairs(panel) do
		if string.match(j.title, '^%d+$') then
			j.button:setText(j.title)
			j.button:setVisible(false)
		end
		if not panelbytitle[j.title] then
			panelbytitle[j.title] = j
		end
	end

	local ok, res, funs

	if unittype and unittype ~= '' then
		local infn = Moduledir .. unittype .. '.lua'
		ok, res, funs = doCustom(infn)
		if ok and type(res) == 'table' and type(res.lt) == 'table' then
			if not LT[unittype] then
				LT[unittype] = {}
			end
			local dirname = LT[unittype].dirname
			for k, v in pairs(res.lt) do
				if k ~= 'dirname' or not dirname then
					LT[unittype][k] = v
				end
			end
		end
		if ok and type(res) == 'table' and type(res.kp) == 'table' then
			kp = res.kp
		else
			kp = {}
		end

		if ok then
			for i = 1, #funs do
				buttfn[i] = funs[i].fn
				panelbytitle[tostring(i)].button:setText(funs[i].name)
				panelbytitle[tostring(i)].button:setVisible(true)
			end
		else
			loglocal('assignCustom() not ok infn: ' .. infn)
		end
	else
		loglocal('assignCustom() no unittype, skipping module file')
		kp = {}
	end

	local infn = Globalcustomfile
	ok, res, funs = doCustom(infn)
	if ok then
		local j
		for i = 1, #funs do
			j = i + buttfnlimit
			buttfn[j] = funs[i].fn
			panelbytitle[tostring(j)].button:setText(funs[i].name)
			panelbytitle[tostring(j)].button:setVisible(true)
		end
	else
		loglocal('assignCustom() not ok infn: ' .. infn)
	end

	if panelbytitle['LatLon'] then
		if unittype and LT[unittype] and LT[unittype]['wpentry'] then
			panelbytitle['LatLon'].button:setVisible(true)
		else
			panelbytitle['LatLon'].button:setVisible(false)
		end
	end
end

-- =================
-- Unit initialization
-- =================

function uploadinit()
	cancelmacro()
	loglocal('uploadinit(): begin', 6)

	local newunittype = DCS.getPlayerUnitType()
	if newunittype == unittype then
		if not unittype then
			loglocal('uploadinit(): unittype already nil')
			return false
		else
			loglocal('uploadinit(): unittype already same, ' .. unittype)
			assignCustom()
		end
		return true
	end

	Spinr:rest()
	if unittype then
		loglocal('uploadinit() type ' .. unittype)
	else
		loglocal('uploadinit() unittype nil')
	end
	if newunittype then
		loglocal('uploadinit() newunittype ' .. newunittype)
	else
		loglocal('uploadinit() newunittype nil')
	end
	unittype = newunittype
	if not unittype then
		loglocal('uploadinit() getPlayerUnitType nil, ')
		return false
	end

	if unittype == 'forward_observer' then
		loglocal('uploadinit() exception for forward_observer')
		assignCustom()
		return
	end

	loglocal('cycle thru modules,')
	for i, _ in pairs(LT) do
		if LT[i].dirname then
			loglocal('uploadinit() cycle dir: ' .. LT[i].dirname)
		else
			loglocal('uploadinit() cycle missing dir: ' .. i)
		end
	end

	if not unittype then
		loglocal('aeronautespit uploadinit() unittype nil')
		return false
	end

	if not LT[unittype] or not LT[unittype].dirname then
		loglocal('aeronautespit uploadinit() LT[].dirname undefined for ' .. unittype)
		return false
	end
	local dirname = LT[unittype].dirname

	local function checkfile(fn)
		local atr = lfs.attributes(fn)
		if not atr then
			loglocal('aeronautespit uploadinit() checkfile attributes nil, ' .. fn)
			return false
		end
		return true
	end

	local function checkcockpitfile(moddir, fn)
		local infn = moddir .. [[\Cockpit\Scripts\]] .. fn
		if not checkfile(infn) then
			infn = moddir .. [[\Cockpit\]] .. fn
			if not checkfile(infn) then
				return nil
			else
				return infn
			end
		end
		return infn
	end

	local function checkcockpitdir(moddir, fn)
		local dirn = moddir .. [[\Cockpit\Scripts\]]
		local infn = dirn .. fn
		if not checkfile(infn) then
			loglocal('checkcockpitdir1: ' .. infn)
			dirn = moddir .. [[\Cockpit\]]
			infn = dirn .. fn
			if not checkfile(infn) then
				return nil
			else
				loglocal('checkcockpitdir2: ' .. infn)
				return dirn
			end
		end
		loglocal('checkcockpitdir3: ' .. dirn)
		return dirn
	end

	elements = {}
	_G.LockOn_Options = {}
	_G.LockOn_Options.script_path = checkcockpitdir(dirname, 'clickabledata.lua')

	if not class_type then
		_G.get_option_value = function() return nil end
		_G.get_aircraft_property_or_nil = _G.get_option_value

		dofile(lfs.currentdir() .. [[Scripts\Aircrafts\_Common\Cockpit\clickable_common.lua]])
	end

	local infn = checkcockpitfile(dirname, 'clickabledata.lua')
	if not infn then
		loglocal('aeronautespit uploadinit() file not available, ' .. tostring(infn))
		return
	end
	dofile(infn) -- load devices / command tables

	-- Source parser: extracts the literal string from "hint" or _("hint")
	local infile, res = io.open(infn)
	if not infile then
		loglocal('aeronautespit uploadinit() open file fail; ' .. tostring(res))
		return
	end

	ttlist = {}
	tttrie = Trie:new()
	local count = 0
	local line = infile:read('*line')
	while line do
		local ptr, tt, dev, butn = string.match(line, '^elements%["(.+)"%]%s*=.+%("(.+)"%)%s*,%s*([^,]+),%s*([^,]+)')
		if tt then
			tttrie:insert(tt)
			local tstr = string.match(dev, '[^.]+\.(.+)')
			ttlist[tt] = { device_nm = dev, action_nm = butn, name = ptr }
			if devices and tstr and devices[tstr] then
				ttlist[tt].device = devices[tstr]
			end
			local ct, ca = string.match(butn, '([^.]+)\.(.+)')
			if ct and ca and _G[ct] and _G[ct][ca] then
				ttlist[tt].action = _G[ct][ca]
			end
			count = count + 1
		end
		line = infile:read('*line')
	end
	infile:close()
	loglocal('uploadinit: loaded ' .. count .. ' tooltips from source')

	loglocal('uploadinit() before postload: ' .. net.lua2json(ttlist), 2)
	if type(LT[unittype].postload) == 'function' then
		loglocal('uploadinit() calling postload')
		LT[unittype].postload()
		loglocal('uploadinit() calling postload done')
	end
	loglocal('uploadinit() ttlist: ' .. net.lua2json(ttlist), 6)

	wps = copytable(wpsdefaults)
	assignCustom()
	if panelbytitle and panelbytitle['mod'] then
		panelbytitle['mod'].button:setText(string.sub(unittype, 1, 8))
	end

	if LT[unittype].updatewp then
		wps.update = LT[unittype].updatewp
		wps:button()
	else
		wps.update = wpsdefaults.update
	end

	if not isHidden() then
		if switchPage() == Scratchdir .. Scratchpadfn then
			showCustom(getTextarea())
		end
	end

	return unittype
end

-- =================
-- Selection / input helpers
-- =================

function getCurrentLineOffsets(text, cur)
	local linestart = cur
	local lineend = cur
	local nl = string.byte('\n')

	for i = cur, 0, -1 do
		if text:byte(i) == nl then
			linestart = linestart + 1
			break
		end
		linestart = linestart - 1
		if linestart <= 0 then
			linestart = 1
			break
		end
	end

	for i = cur + 1, #text do
		if text:byte(i) == nl then
			break
		end
		lineend = lineend + 1
	end

	return linestart, lineend
end

local function getinput()
	local TA = getTextarea()
	local txtD = TA:getText()
	local ptr = 0
	local txtN = {}

	local lineStart, indexStart, lineEnd, indexEnd = TA:getSelectionNew()
	if lineStart > lineEnd then
		lineStart, lineEnd = lineEnd, lineStart
		indexStart, indexEnd = indexEnd, indexStart
	end

	for i = 0, lineEnd do
		local len = TA:getLineTextLength(i)
		local rptr = ptr + len
		if rptr > ptr and string.sub(txtD, rptr, rptr) == '\n' then
			rptr = rptr - 1
		end
		if string.sub(txtD, ptr, ptr) == '\n' then
			ptr = ptr + 1
		end
		txtN[i] = string.sub(txtD, ptr, rptr)
		ptr = rptr + 1
	end

	local ret = ''
	if lineStart == lineEnd then
		if indexStart == indexEnd then
			ret = string.sub(txtN[lineStart], 0)
		else
			if indexStart > indexEnd then
				indexStart, indexEnd = indexEnd, indexStart
			end
			ret = string.sub(txtN[lineStart], indexStart, indexEnd)
		end
		return ret
	else
		ret = string.sub(txtN[lineStart], indexStart) .. '\n'
		if lineStart < lineEnd + 1 then
			for i = lineStart + 1, lineEnd - 1 do
				ret = ret .. txtN[i] .. '\n'
			end
		end
		ret = ret .. string.sub(txtN[lineEnd], 1, indexEnd)
		return ret
	end
end

local function handleSelection(TA)
	local sel = getinput()
	local jtest = sel
	jtest = string.gsub(jtest, "[']", '')
	jtest = string.gsub(jtest, '°', ' ')
	local lat, lon = string.match(jtest, '(%u %d%d +%d%d%.%d+), (%u %d+ +%d%d%.%d+)')
	local altm, altft = string.match(jtest, '(%d+)m, +(%d+)ft')

	if lon then
		loglocal('Sel: jtac position detected', 4)
		local cType = coordsType(unittype)
		if cType then
			if cType.precision then
				local delta = 3 - cType.precision
				loglocal('Sel jtac delta: ' .. delta, 4)
				if delta > 0 then
					loglocal('Sel jtac precision: ' .. #lat, 4)
					lat = string.sub(lat, 1, #lat - delta)
					lon = string.sub(lon, 1, #lon - delta)
					loglocal('Sel jtac precision2: ' .. #lat .. ' lat: ' .. lat, 4)
				end
			end
			if cType.lonDegreesWidth then
				local east, londeg, lonmin = string.match(lon, '(%u) (%d+).(%d+%.%d+)')
				local fmtstr = '%s %.' .. cType.lonDegreesWidth .. 'd %s'
				local newlon = string.format(fmtstr, east, londeg, lonmin)
				loglocal(string.format('Sel fmtstr: %s east: %s londeg: %s lonmin: %s, newlon: %s', fmtstr, east, londeg, lonmin, newlon), 4)
				lon = newlon
			end
		end
		lat = string.gsub(lat, '[ .]', '')
		lon = string.gsub(lon, '[ .]', '')
		if not altft then
			altft = '0'
		end

		local acstr = LLtoAC(lat, lon, altft)
		if not acstr then
			loglocal('handleSelection() Sel jtac: LLtoAC returned nil')
			return
		end
		local newstr = "wp('" .. acstr .. "')"
		loglocal('handleSelection() Sel jtac: LL: ' .. lat .. ' , ' .. lon .. ' alt: ' .. altft .. ' , ' .. newstr, 4)
		sel = newstr
	end
	loglocal('addButton Sel: ' .. sel, 3)
	loadDTCBuffer(sel)
end

-- =================
-- Coordinate conversion
-- =================

function convertformatCoords(result)
	if LT[unittype] and LT[unittype].llconvert then
		result = LT[unittype].llconvert(result)
		loglocal('convertformatCoords: llconvert ' .. result, 6)
	else
		result = string.gsub(result, "[Â°'%.\"]", "")
		loglocal('convertformatCoords: no llconvert ' .. result, 6)
	end
	return result
end

function coordsType(unit)
	if LT[unit] and LT[unit].coordsType then
		return LT[unit].coordsType
	end

	loglocal('aeronautespit coordsType: not found in LT, ' .. tostring(unit))
	return nil
end

function formatCoordConv(format, isLat, d, opts)
	local str = ''
	str = convertformatCoords(formatCoord(format, isLat, d, opts))
	loglocal('formatCoordConv: ' .. str)
	return str
end

function LLtoAC(lat, lon, alt)
	if not LT[unittype] or not LT[unittype].wpentry then
		loglocal('LLtoAC: no wpentry for ' .. tostring(unittype))
		return nil
	end
	local wpfmt = LT[unittype].wpentry
	loglocal('LLtoAC ' .. wpfmt .. ' lat: ' .. lat, 6)
	local str = string.gsub(wpfmt, 'LAT', lat)
	str = string.gsub(str, 'LON', lon)
	str = string.gsub(str, 'ALT', alt)
	str = convertformatCoords(str)
	loglocal('LLtoAC str: ' .. str, 6)
	return str
end

function getloc(form)
	if not Export.LoGetCameraPosition then
		loglocal('getloc: no camera export available')
		return nil
	end

	local Terrain = require('terrain')
	local cam = Export.LoGetCameraPosition()
	if not cam or not cam.p then
		loglocal('getloc: no camera position')
		return nil
	end
	local pos = cam.p

	local ok, alt = pcall(Terrain.GetSurfaceHeightWithSeabed, pos.x, pos.z)
	if not ok then
		loglocal('getloc: GetSurfaceHeightWithSeabed failed: ' .. tostring(alt))
		return nil
	end

	local ok2, lat, lon = pcall(Terrain.convertMetersToLatLon, pos.x, pos.z)
	if not ok2 then
		loglocal('getloc: convertMetersToLatLon failed: ' .. tostring(lat))
		return nil
	end

	if form == 'raw' then
		return lat, lon, alt
	end

	local types = coordsType(unittype)
	if types then
		local str = LLtoAC(
			formatCoordConv(types.format, true, lat, types),
			formatCoordConv(types.format, false, lon, types),
			string.format("%.0f", alt * 3.28084)
		)
		return str
	else
		loglocal('getloc() coordsType() returned nil, unittype: ' .. tostring(unittype))
		return nil
	end
end

-- =================
-- showCustom
-- =================

function showCustom(TA)
	if switchExtPage(Scratchdir .. Scratchpadfn) then
		local txt = ''
		local readtxt = ''
		if not LT[unittype] then
			loglocal('showCustom() no LT[unittype]')
			return
		end
		if LT[unittype].notes then
			txt = LT[unittype].notes
		end
		if not TA then
			TA = getTextarea()
		end

		local infn = Moduledir .. unittype .. '.lua'
		if LT[unittype].customfn then
			infn = LT[unittype].customfn
		end
		local infile, res = io.open(infn, 'r')
		if not infile then
			txt = txt .. '\nThis module, ' .. unittype .. ', has no custom file in ' .. Modulesubdir
			loglocal('aeronautespit mod open file fail; non critical' .. res)
		else
			readtxt = infile:read('*all')
			infile:close()
			if not readtxt then
				loglocal('aeronautespit mod read error; ' .. infn)
			else
				txt = txt .. '\n\n-- COPY of ' .. Modulesubdir .. unittype .. '.lua\n' .. readtxt
			end
		end

		TA:setText('')
		local buflen = string.len(txt)
		if buflen > (1024 * 1024) then
			txt = string.sub(txt, 0, (1024 * 1024) - 80)
			txt = txt .. '<<< File too big for scratchpad. Displaying truncated to 1MB >>>'
			loglocal('apit mod buflen > 1MB: ' .. buflen)
		end

		TA:setText(txt)
	end
end

-- =================
-- Button creation
-- =================

function createbuttons()
	local numbutts = 14
	local numrow1 = 7
	local numrow2 = 5
	local rowh = 0

	local buttx = 0
	for i = 1, numrow1 do
		butts[i] = { buttx, rowh, buttw, butth }
		buttx = buttx + buttw
	end

	rowh = rowh + butth
	buttx = 0
	for i = numrow1 + 1, numrow1 + numrow2 do
		butts[i] = { buttx, rowh, buttw, butth }
		buttx = buttx + buttw
	end

	rowh = rowh + butth
	buttx = 0
	buttw = buttw + 20
	for i = numrow1 + numrow2 + 1, numbutts do
		butts[i] = { buttx, rowh, buttw, butth }
		buttx = buttx + buttw
	end

	butts[1][5] = 'LatLon'
	butts[1][6] = function()
		local str = getloc()
		if not str then
			loglocal('LatLon: no terrain / not in mission')
			return
		end
		loglocal('aeronautespit: button LL: ' .. str)
		wp(str)
		domacro.flag = true
	end

	butts[2][5] = 'Sel'
	butts[2][6] = function(TA)
		handleSelection(TA)
	end

	butts[3][5] = 'Buf'
	butts[3][6] = function(TA)
		loadDTCBuffer(TA:getText())
	end

	butts[4][5] = 'Cancel'
	butts[4][6] = cancelmacro

	butts[5][5] = 'WP+'
	butts[5][6] = function()
		if wps.cur then
			wps.update(wps.cur + wps.diff)
		end
	end

	butts[6][5] = 'WP'
	butts[6][6] = function()
		wps.update(wps.default)
	end

	butts[7][5] = 'WP-'
	butts[7][6] = function()
		if wps.cur then
			wps.update(wps.cur - wps.diff)
		end
	end

	butts[8][5] = 'wp'
	butts[8][6] = function(TA)
		local loc = getloc()
		if loc then
			local wpver = 1.0
			local lat, lon, alt = getloc('raw')
			local str = 'wp(' ..
				'{alt=' .. string.format('%.3f', alt) ..
				[[,name='']] ..
				',lat=' .. string.format('%2.8f', lat) ..
				',lon=' .. string.format('%3.8f', lon) ..
				',ver=' .. tostring(wpver) ..
				'})'
			TA:insertBelow(str)
		else
			loglocal('butts wp unknown location format')
		end
	end

	butts[9][5] = 'log'
	butts[9][6] = function(TA)
		if switchExtPage(Scratchdir .. Scratchpadfn) then
			TA:setText('')
			local buflen = string.len(Hist.buf)
			if buflen > (1024 * 1024) then
				loglocal('apit log buflen > 1MB: ' .. buflen)
			end

			local txt = string.sub(Hist.buf, buflen - (1024 * 1024))
			TA:setText(txt)
			TA:insertBottom('')
		end
	end

	butts[10][5] = 'loglvl'
	butts[10][6] = function()
		dbglvl = dbglvl + 1
		if dbglvl > 9 then
			dbglvl = 0
		end
		loglocal('aeronautespit: debug level set: ' .. dbglvl)
		local p = panelbytitle and panelbytitle['loglvl']
		if p and p.button then
			p.button:setText('log:' .. tostring(dbglvl))
		else
			loglocal('loglvl button: panelbytitle[\'loglvl\'] not ready')
		end
	end

	butts[11][5] = 'dot'
	butts[11][6] = function()
		Dot.vis = not Dot.vis
		if Dot.dlog then
			Dot.dlog:setVisible(Dot.vis)
		end
	end

	butts[12][5] = 'help'
	butts[12][6] = function(TA)
		if switchExtPage(Scratchdir .. Scratchpadfn) then
			TA:setText('')
			if not helper then
				loadlib('helper.lua')
			end
			local buflen = string.len(helper or '')
			if buflen > (1024 * 1024) then
				loglocal('apit help buflen > 1MB: ' .. buflen)
			end
			local txt = "version: " .. version .. "\n" .. (helper or "") .. "\nEOF"
			txt = string.sub(txt, buflen - (1024 * 1024))
			TA:setText(txt)
		end
	end

	butts[13][5] = 'mod'
	butts[13][6] = showCustom

	butts[14][5] = 'modload'
	butts[14][6] = function()
		loglocal('aeronautespit: reload click ' .. #LT)
		assignCustom()
		assignCustom(Globalcustomfile)
		showCustom()
	end

	rowh = rowh + butth
	buttw = buttw + 20
	for i = 1, buttfnlimit do
		butts[numbutts + i] = { ((i - 1) * buttw), rowh, buttw, butth, tostring(i) }
		butts[numbutts + i][6] = function(T)
			if buttfn[i] then
				buttfn[i](getinput())
				domacro.flag = true
			end
		end
	end

	rowh = rowh + butth
	local j = 0
	for i = buttfnlimit + 1, buttfnamt do
		butts[numbutts + i] = { (j * buttw), rowh, buttw, butth, tostring(i) }
		j = j + 1
		butts[numbutts + i][6] = function(T)
			if buttfn[i] then
				buttfn[i](getinput())
				domacro.flag = true
			end
		end
	end

	for _, j in pairs(butts) do
		addButton(j[1], j[2], j[3], j[4], j[5], j[6])
	end

	Dotcreate()
end

createbuttons()

-- =================
-- Frame listener (macro playback)
-- =================

local myhandler = {}

function myhandler.onSimulationFrame()
	if domacro.flag == true then
		local now = socket.gettime()
		if now < domacro.ctr then
			return
		end
		if #domacro.inp == 0 then
			domacro.flag = false
			return
		end

		local i = domacro.idx
		local step = domacro.inp[i]
		if not step then
			loglocal('addFrameListener: nil step at idx ' .. tostring(i) .. ', clearing macro')
			domacro.inp = {}
			domacro.idx = 1
			domacro.flag = false
			Spinr:rest()
			return
		end

		loglocal('addFrameListener domacro.inp: ' .. net.lua2json(step), 6)
		local command = step[1]
		local val = step[2]
		local device = step[4]
		loglocal('addFrameListener loop: ' .. i .. ":" .. tostring(device) .. ":" .. tostring(command) .. ":" .. tostring(val) .. ' ' .. socket.gettime(), 6)
		Spinr:run()
		if command == -1 and device == -1 then
			loglocal('addFrameListener potential fn ' .. DCS.getRealTime() .. ' ' .. net.lua2json(step), 6)
			if step[5] then
				loglocal('addFrameListener [5] ' .. DCS.getRealTime(), 6)
				if type(step[5]) == 'function' then
					loglocal('addFrameListener [5] fn ' .. type(step[5]) .. ' ' .. type(step[6]), 6)
					step[5](step[6])
				end
			end
		else
			loglocal('performClickableAction: ' .. tostring(device) .. ' : ' .. tostring(command) .. ' : ' .. tostring(val), 6)

			local dev = Export.GetDevice(device)
			if not dev then
				loglocal('performClickableAction: no device ' .. tostring(device))
			elseif not dev:performClickableAction(command, val) then
				loglocal('performClickableAction: fail')
			end
		end

		local delay = step[3] or 0
		domacro.ctr = socket.gettime() + itval + delay
		loglocal('addFrameListener: time tick ' .. domacro.ctr, 6)
		i = i + 1
		if i > #domacro.inp then
			domacro.inp = {}
			domacro.idx = 1
			domacro.flag = false
			Spinr:rest()
			loglocal('addFrameListener: finished macro ul')
		else
			domacro.idx = i
		end
		loglocal('addFrameListener loop2: i: ' .. i, 6)
	end
end
domacro.listeneradded = true

-- =================
-- Mission / slot callbacks
-- =================

local myid
local simresumeadded = false

function myhandler.onMissionLoadEnd()
	loglocal('missionLoadEndListener start', 3)
	if DCS.isMultiplayer() then
		loglocal('missionLoadEndListener MP', 3)
		myid = net.get_my_player_id()
	else
		loglocal('missionLoadEndListener SP', 3)
		if not uploadinit() then
			if not simresumeadded then
				function myhandler.onSimulationResume()
					uploadinit()
				end
				DCS.setUserCallbacks(myhandler)
				simresumeadded = true
			end
		end
	end
end

function myhandler.onPlayerChangeSlot(id)
	if id == myid then
		uploadinit()
	end
end

loglocal('aeronautes-pit extension version: ' .. version)
DCS.setUserCallbacks(myhandler)
