--[[
	Route Tool / Grayflag utilities

	Functions: presetwp, RTlist, RTload, RTshow, ammo, globalfile
		(GFdrop / GFload added dynamically for CTLD helis)
	## presetfix - DEPRECATED
		Sets correct altitude for waypoints of the currently loaded theater.
		Only changes altitudes set at 2000 m (DCS default). Not needed for
		routes created with presetwp.
	## presetwp - used on Grayflag servers. Given an objective name,
		produces additions to the Route Tool preset file. DCS only reads
		'Saved Games\DCS\Config\RouteToolPresets' after the mission loads
		when joining a server. Updates won't appear until the next join.
		The script merges additions; back up your presets if desired.
		Alternatively delete the theater file in RouteToolPresets or use
		the Route Tool F10 menu to delete individual routes.
		To use: highlight the objective name in Scratchpad, then click the
		presetwp button. Messages appear in in-game chat. Leave and rejoin
		the server to see the new presets. If nothing is highlighted, the
		entire line is used as the objective name (line must contain only
		the name). On Grayflag servers you can also highlight names from
		an F10 'update' label via the aeronautes-msg extension.
	## RTlist - clears and displays available routes from the current
				Route Tool presets file in the aeronautes-pit buffer.
	## RTload - takes a Route Tool preset route name from Scratchpad and
				enters it into the aircraft nav system if available.
	## RTshow - shows the selected route in the Scratchpad buffer.
	## globalfile - shows the contents of Globalcustom.lua.
	## ammo - display the ammo count for any mounted weapons.
	## GFdrop - CTLD menu item for crate drop on Grayflag server.
	## GFload - CTLD menu item for crate load on Grayflag server.
]]

local ft = {}

ft.order = { 'presetwp', 'RTlist', 'RTload', 'RTshow', 'ammo', 'globalfile' }

-- =================
-- Helpers
-- =================

local function getPresetFn()
	if not _current_mission or not _current_mission.mission or not _current_mission.mission.theatre then
		loglocal('getPresetFn: no current mission / theatre')
		return nil
	end
	return lfs.writedir() .. [[Config\RouteToolPresets\]] .. _current_mission.mission.theatre .. '.lua'
end

local function copytable(src)
	local dst = {}
	for i, j in pairs(src) do
		dst[i] = j
	end
	return dst
end

local function bsearch(tbl, len, value, cmpf)
	local left = 1
	local right = len + 1
	local mid

	while left < right do
		mid = left + math.floor((right - left) / 2)
		-- loglocal('BSEARCH: ' .. value .. ' left: ' .. left .. ', ' .. mid .. ', ' .. right .. net.lua2json(tbl[mid]))
		if cmpf(tbl[mid], value) then
			left = mid + 1
		else
			right = mid
		end
	end
	return left
end

local function boundingbox(verts)
	local bbox = {
		minx = math.huge, miny = math.huge,
		maxx = -math.huge, maxy = -math.huge,
	}

	for _, v in pairs(verts) do
		bbox.minx = math.min(bbox.minx, v.x)
		bbox.maxx = math.max(bbox.maxx, v.x)
		bbox.miny = math.min(bbox.miny, v.y)
		bbox.maxy = math.max(bbox.maxy, v.y)
	end
	return bbox
end

local function hypot(a, b)
	return math.sqrt((a.x - b.x)^2 + (a.y - b.y)^2)
end

local function pointInPolygon(pt, verts)
	local n = #verts
	if n < 3 then return false end
	local x, y = pt.x, pt.y
	local inside = false
	local j = n
	for i = 1, n do
		local vi, vj = verts[i], verts[j]
		local yi, yj = vi.y, vj.y
		if ((yi > y) ~= (yj > y)) then
			local xi, xj = vi.x, vj.x
			if x < (xj - xi) * (y - yi) / (yj - yi) + xi then
				inside = not inside
			end
		end
		j = i
	end
	return inside
end

local function umsg(str)
	loglocal('Globalcustom: ' .. str)
	net.recv_chat(str)
end

local function showtext(txt)
	if not txt then
		loglocal('showtext: txt nil', 2)
		return
	end
	if switchExtPage(Scratchdir .. Scratchpadfn) then
		if not TA then
			TA = getTextarea()
		end

		TA:setText('')
		-- Hardcoded 1 MB file limit from Scratchpad
		local buflen = string.len(txt)
		if buflen > (1024 * 1024) then
			txt = string.sub(txt, 0, (1024 * 1024) - 80)
			txt = txt .. '<<< File too big for scratchpad. Display truncated to 1MB >>>'
			loglocal('apit mod buflen > 1MB: ' .. buflen)
		end

		TA:setText(txt)
	end
end

local function trim(s)
	if type(s) == 'string' then
		return s:match'^%s*(.*%S)' or ''
	else
		return s
	end
end

local function showbuf(str)
	if switchExtPage(Scratchdir .. Scratchpadfn) then
		if str then
			TA:setText('')
			-- Hardcoded 1 MB file limit from Scratchpad
			local buflen = string.len(str)
			local txt = string.sub(str, buflen - (1024 * 1024))
			TA:setText(txt)
			TA:insertBottom('')
		end
	end
end

-- =================
-- Preset file I/O
-- =================

function readpresets(input)
	local atr = lfs.attributes(getPresetFn() or "")
	if atr and atr.mode == 'file' then
		local pfn = getPresetFn()
		if pfn then dofile(pfn) end
	end
	if not presets then
		loglocal('readpresets: presets not assigned from ' .. (getPresetFn() or "?"))
		return
	end
	return presets
end

local pfile
function writepresets(presets)
	local err
	pfile, err = io.open(getPresetFn() or "", 'w+')
	if err then
		umsg('Error opening file, err: ' .. err)
		return
	end

	local function fout(str)
		-- loglocal(str)
		pfile:write(str)
	end

	-- Order routes alphabetically in the theater preset file.
	-- Currently DCS does not honor this ordering in the dropdown list.
	local presort = {}
	for i, _ in pairs(presets) do
		table.insert(presort, i)
	end
	table.sort(presort)

	fout('presets =\n{\n')
	for i = 1, #presort do
		loglocal(i .. ' SORT: ' .. presort[i], 4)
		local rtname = presort[i]
		local rtnode = presets[rtname]
		fout('	["' .. rtname .. '"] =\n	{\n')
		for wpnum = 1, #rtnode do
			fout('		[' .. wpnum .. '] =\n		{\n')
			for key, value in pairs(rtnode[wpnum]) do
				if type(value) == 'string' then
					fout('			["' .. key .. '"] = "' .. value .. '",\n')
				else
					fout('			["' .. key .. '"] = ' .. tostring(value) .. ',\n')
				end
			end
			fout('		}, -- end of [' .. wpnum .. ']\n')
		end
		fout('	}, -- end of ["' .. rtname .. '"]\n')
	end
	fout('} -- end of presets')
	pfile:flush()
	pfile:close()

	umsg('DCS only reads the presets file on mission load. You must leave/rejoin the server to see presets in the F10 Route Tool')
end

-- =================
-- Creates Route Tool presets from Grayflag-style objectives / CAP zones.
-- =================

ft.presetwp = function(input)
	if not _current_mission or not _current_mission.mission then
		umsg('presetwp: no mission loaded')
		return
	end
	input = trim(input)
	if not input then
		umsg('No objective name supplied. You must highlight the objective name in scratchpad. "' .. tostring(input) .. '"')
		return
	end

	local objs = {}
	local caps = {}
	local allqrfs = {}
	local forcewplimit = 9
	local objstypes = { obj = 1, qrf = 1, supply = 1 }

	for _, i in pairs(_current_mission.mission.triggers.zones) do
		local zone = { name = i.name, x = i.x, y = i.y, zoneid = i.zoneId }
		loglocal('Zone read: ' .. net.lua2json(zone), 7)
		if i.properties and i.properties[1] and i.properties[1]['key'] then
			for _, j in pairs(i.properties) do
				zone[j.key] = trim(j.value)
			end
		end
		if i.verticies then
			zone['verticies'] = copytable(i.verticies)
		end

		if objstypes[zone.type] then
			table.insert(objs, zone)
		elseif string.sub(zone.name, 1, 3) == 'CAP' then
			table.insert(caps, zone)
		end
	end
	table.sort(caps, function(a, b) return a.x < b.x end)
	loglocal('caps:' .. #caps .. ' objs: ' .. #objs, 2)

	local objlist = {}
	loglocal('input: #' .. input .. '#', 4)
	for _, j in pairs(objs) do
		loglocal('Obj.str #' .. j.str .. '# name: ' .. j.name, 7)
		if j.str == input then
			table.insert(objlist, j)
		end
	end
	loglocal('objlist: ' .. net.lua2json(objlist), 4)

	if #objlist == 0 then
		umsg('Objective not found: #' .. input .. '# ' .. #objlist)
		return
	end
	if #objlist > 1 then
		umsg('Multiple objectives found: ' .. input .. ' (' .. #objlist .. ')')
	end

	-- Load current presets file
	local atr = lfs.attributes(getPresetFn() or "")
	if atr and atr.mode == 'file' then
		local pfn = getPresetFn()
		if pfn then dofile(pfn) end
	end
	if not presets then
		presets = {}
	end

	for _, obtgt in pairs(objlist) do
		loglocal('OBJ: ' .. net.lua2json(obtgt), 4)
		if not obtgt.verticies then
			loglocal('Globalcustom: no verticies for obj: ' .. obtgt.name)
		else
			local bb = boundingbox(obtgt.verticies)
			loglocal('BB: ' .. net.lua2json(bb), 4)

			-- findwp requires wplist be sorted by x
			local function findwp(obj, wplist)
				-- DCS x axis is vertical, y horizontal
				local minx = bsearch(wplist, #wplist, bb.minx, function(a, b) return a.x < b end)
				local maxx = bsearch(wplist, #wplist, bb.maxx, function(a, b) return a.x < b end)
				loglocal('RESX: ' .. minx .. ' , ' .. maxx, 4)
				local xrng = {}

				for i = minx, maxx do
					table.insert(xrng, wplist[i])
				end
				table.sort(xrng, function(a, b) return a.y < b.y end)

				local miny = bsearch(xrng, #xrng, bb.miny, function(a, b) return a.y < b end)
				local maxy = bsearch(xrng, #xrng, bb.maxy, function(a, b) return a.y < b end)
				loglocal('RESY: ' .. miny .. ' , ' .. maxy, 4)
				for i = miny, maxy do
					loglocal(i .. ' BBOXED result: ' .. net.lua2json(xrng[i]), 4)
				end

				-- wplist in obj test (even-odd ray cast)
				local objwp = {}
				for i = miny, maxy do
					if pointInPolygon(xrng[i], obj.verticies) then
						loglocal('Inside poly inserting ' .. net.lua2json(xrng[i]), 4)
						table.insert(objwp, xrng[i])
					else
						loglocal('OUTSIDE POLY, passing ' .. net.lua2json(xrng[i]), 4)
					end
				end
				return objwp
			end

			local function getstatics()
				local qrfs = {}
				local qrfcats = { Warehouses = 1, Fortifications = 1 }

				for _, i in pairs(_current_mission.mission.coalition.red.country) do
					loglocal('Country: ' .. i.name, 4)
					if i.static and i.static.group then
						for _, j in pairs(i.static.group) do
							if qrfcats[j.units[1].category] then
								loglocal('getstatics name: ' .. j.name .. ' cat: ' .. (j.units[1].category) .. ' type: ' .. (j.units[1].type), 6)
								table.insert(qrfs, { name = j.name, x = j.x, y = j.y, type = j.units[1].type })
							end
						end
					end
				end
				table.sort(qrfs, function(a, b) return a.x < b.x end)
				loglocal('QRFS: ' .. #qrfs, 4)
				return qrfs
			end

			local objwp = {}
			if obtgt.type == 'obj' then
				objwp = findwp(obtgt, caps)
			else
				if #allqrfs == 0 then
					allqrfs = getstatics()
					if #allqrfs == 0 then
						umsg('presetwp unable to find statics for QRF, failing')
						loglocal('presetwp getstatics returned 0')
						return
					end
				end
				objwp = findwp(obtgt, allqrfs)
			end

			if #objwp == 0 then
				umsg('Objective waypoints size zero, no presets designated, ' .. input .. ' (' .. obtgt.name .. ')')
				return
			end

			local route = {}
			for i = 1, #objwp do
				route[i] = i
			end
			local minrt = { r = {}, d = math.huge }

			local dtab = {}
			local dC = {}
			for i = 1, #objwp do
				dtab[i] = {}
				dC[i] = {}
				for j = 1, #objwp do
					dtab[i][j] = hypot(objwp[i], objwp[j])
					--[[
					if j ~= i then
						table.insert(dC[i], { v = j, cost = dtab[i][j] })
					end
					--]]
				end
				--[[
				table.sort(dC[i], function(a, b) return a.cost < b.cost end)
				--]]
			end
			for i = 1, #dtab do
				loglocal('dtab: ' .. i .. ': ' .. net.lua2json(dtab[i]), 4)
			end
			forcewplimit = 9
			local selfdata = Export.LoGetSelfData() or { Position = { x = 0, z = 0 } }
			local selfpos = { x = selfdata.Position.x, y = selfdata.Position.z }
			loglocal('selfdata: ' .. net.lua2json(selfdata.Position), 4)
			local basedist = {}
			for i = 1, #route do
				basedist[i] = hypot(selfpos, objwp[i])
			end

			local function routedist(r)
				local dist = 0
				local tot = 1
				for i = 1, #r - 1 do
					dist = dist + dtab[r[i]][r[i + 1]]
					-- Too much log: loglocal('routedist: ' .. r[i] .. '->' .. r[i + 1] .. ': ' .. dtab[r[i]][r[i + 1]], 6)
				end
				loglocal(tot .. ' route: ' .. net.lua2json(r) .. ' dist: ' .. dist, 6)
				tot = tot + 1
				return dist
			end

			if #objwp < forcewplimit then
				-- Brute-force search min route if fewer than 9 waypoints

				local function permgen(a, n)
					if n == 0 then
						coroutine.yield(a)
					else
						for i = 1, n do
							a[n], a[i] = a[i], a[n]
							permgen(a, n - 1)
							a[n], a[i] = a[i], a[n]
						end
					end
				end

				local function perm(a)
					loglocal('perm: ' .. net.lua2json(a), 6)
					return coroutine.wrap(function() permgen(a, #a) end)
				end

				for p in perm(route) do
					-- rtd = routedist(p) + basedist[p[1]] + basedist[p[#route]] -- for shortest roundtrip
					local rtd = routedist(p) + basedist[p[1]] -- for closest first zone

					-- Enabling the following log for wp > 7 or more may take a long time
					loglocal('presetwp check route: ' .. net.lua2json(p) .. ' dist: ' .. rtd, 8)
					if rtd < minrt.d then
						minrt.d = rtd
						minrt.r = copytable(p)
						loglocal('presetwp set min: ' .. net.lua2json(minrt), 6)
					end
				end
			else
				-- #wp > 8: nearest neighbor

				local function NN(route)
					local Q = {}
					for i = 1, #route do
						Q[i] = {}
						for j = 1, #route do
							if j ~= i then
								table.insert(Q[i], { v = j, cost = dtab[i][j] })
							end
						end
						table.sort(Q[i], function(a, b) return a.cost < b.cost end)
						loglocal('Q[' .. i .. ']: ' .. net.lua2json(Q[i]), 4)
					end

					local closestcap = 0
					local dist = math.huge
					for i = 1, #basedist do
						if basedist[i] < dist then
							closestcap = i
							dist = basedist[i]
							-- loglocal('closest: ' .. closestcap .. ' basedist: ' .. net.lua2json(basedist))
						end
					end
					loglocal('FIN closest: ' .. closestcap .. ' basedist: ' .. net.lua2json(basedist), 4)

					local rt = { closestcap }
					local tour = { d = math.huge, rt = {} }
					for h = 1, #route do
						rt = { h }
						dist = 0
						local Qn = copytable(Q)
						for i = 1, #route - 1 do
							for j = 1, #Qn[rt[i]] do
								local shortest = Qn[rt[i]][j]
								-- loglocal('shortest: ' .. net.lua2json(shortest))
								if Qn[shortest.v] then
									rt[i + 1] = shortest.v
									dist = dist + shortest.cost
									Qn[rt[i]] = nil
									break
								end
							end
						end
						loglocal(h .. ' Tour: ' .. dist .. ' rt: ' .. net.lua2json(rt), 4)
						-- dist = dist + dtab[rt[1]][rt[#rt]]
						-- dist = dist + basedist[h]
						loglocal('Complete route: ' .. dist, 4)
						if dist < tour.d then
							tour = { d = dist, rt = rt }
							loglocal('Found smaller: ' .. h .. ' + ' .. basedist[h] .. ' = ' .. dist + basedist[h], 4)
						end
					end
					return tour.d, tour.rt
				end
				minrt.d, minrt.r = NN(route)
				loglocal('NN: ' .. net.lua2json(minrt), 4)

				local function mst(route)
					-- Prim's (incomplete / unused)
					local C = {}
					local E = {}
					local F = {}
					local Q = {}
					for i = 1, #route do
						C[i] = math.huge
						E[i] = 0
						Q[i] = {}
						for j = 1, #route do
							if j ~= i then
								table.insert(Q[i], { v = j, cost = dtab[i][j] })
							end
						end
						table.sort(Q[i], function(a, b) return a.cost < b.cost end)
						loglocal('Q[' .. i .. ']: ' .. net.lua2json(Q[i]))
					end

					local v = 1
					local Fidx = 1
					-- while #Q > 0 do
					F[Fidx] = v
					local tmp = Q[v]
					table.remove(Q[v])
					for w = 1, #tmp do
						if tmp[w].cost < C[v] then
							C[w] = tmp[w].cost
							E[w] = { v, w }
						end
					end
					-- end
					loglocal(net.lua2json({ C, E, F, Q }))
				end
				-- mst(route)
			end
			loglocal('presetwp minrt: ' .. net.lua2json(minrt), 6)

			local rt = DCS.getMissionName() .. '-v' .. _current_mission.mission.version .. '-'
			if obtgt.lat then
				rt = rt .. 'Lat' .. obtgt.lat .. '-'
			end
			rt = rt .. obtgt.str
			if #objlist > 1 then
				rt = rt .. '-' .. obtgt.name
			end

			local etatot = 900
			if not presets[rt] then
				presets[rt] = {}
			end
			local pretmp = {
				alt = 0,
				type = 'Turning Point',
				ETA = etatot,
				ETA_locked = true,
				y = 0,
				x = 0,
				name = '',
				speed_locked = false,
				alt_type = 'BARO',
				action = 'Turning Point',
			}

			for idx = 1, #minrt.r do
				local wp = minrt.r[idx]
				loglocal('route wp: ' .. wp .. ' ; ' .. net.lua2json(objwp[wp]), 6)
				presets[rt][idx] = copytable(pretmp)
				presets[rt][idx].name = objwp[wp].str
				presets[rt][idx].x = objwp[wp].x
				presets[rt][idx].y = objwp[wp].y
				presets[rt][idx].alt = Export.LoGetAltitude(objwp[wp].x, objwp[wp].y)
				if idx > 1 then
					local prevwp = minrt.r[idx - 1]
					presets[rt][idx].ETA = etatot + math.sqrt((objwp[prevwp].x - objwp[wp].x)^2 + (objwp[prevwp].y - objwp[wp].y)^2) / 70
					etatot = presets[rt][idx].ETA
					loglocal('ETA: ' .. presets[rt][idx].ETA, 6)
				end
			end
			umsg(#objwp .. ' wps created for ' .. rt)
			loglocal('presetwp: preset created ' .. net.lua2json(presets[rt][1]), 6)
		end
	end

	-- Write new presets
	writepresets(presets)
end

-- =================
-- presetfix (DEPRECATED)
-- =================
--[[
ft.presetfix = function(input)
	loglocal('presetfix call', 2)
	readpresets()
	if not presets then
		loglocal('presetfix: presets not assigned' .. (getPresetFn() or "?"))
		return 0
	end

	for rtname, rtnode in pairs(presets) do
		loglocal('presetfix rt: ' .. rtname, 6)
		for wpnum, wp in pairs(rtnode) do
			if not wp.name then
				wp.name = ''
			end
			loglocal('presetfix current wp: ' .. wp.name .. ' alt: ' .. wp.alt, 6)
			if wp.alt == 2000 then
				wp.alt = Export.LoGetAltitude(wp.x, wp.y)
				loglocal('presetfix New alt: ' .. wp.alt, 6)
			end
		end
	end
	writepresets(presets)
end
--]]

ft.RTlist = function(input)
	if not _current_mission or not _current_mission.mission then
		umsg('RTlist: no mission loaded')
		return
	end
	input = trim(input)
	loglocal('RTlist call: #' .. input .. '#', 2)

	local txt = ''
	local rtlist = {}

	readpresets()
	if not presets then
		umsg('RTlist: no presets loaded')
		return
	end
	for i, _ in pairs(presets) do
		table.insert(rtlist, i)
	end
	table.sort(rtlist)
	for i = 1, #rtlist do
		txt = txt .. rtlist[i] .. '\n'
	end

	showtext(txt)
end

ft.RTload = function(input)
	if not _current_mission or not _current_mission.mission then
		umsg('RTload: no mission loaded')
		return
	end
	input = trim(input)
	loglocal('RTload call: #' .. input .. '#', 2)

	if not presets or not presets[input] then
		umsg('RTload route not found, ' .. input)
		return
	end

	local rt = presets[input]
	for i = 1, #rt do
		loglocal('RTload: i: ' .. i .. ' latlong ' ..
				 net.lua2json(Export.LoLoCoordinatesToGeoCoordinates(rt[i].x, rt[i].y)), 4)
		wp(rt[i])
	end
end

ft.RTshow = function(input)
	if not _current_mission or not _current_mission.mission then
		umsg('RTshow: no mission loaded')
		return
	end
	input = trim(input)
	loglocal('RTshow call: #' .. input .. '#', 2)

	if not presets or not presets[input] then
		umsg('RTshow route not found, ' .. input)
		return
	end

	local rt = presets[input]
	local txt = '["' .. input .. '"] =\n{\n'
	for i = 1, #rt do
		txt = txt .. '	[' .. i .. '] =\n	{\n'
		for key, value in pairs(rt[i]) do
			if type(value) == 'string' then
				txt = txt .. '		["' .. key .. '"] = "' .. value .. '",\n'
			else
				txt = txt .. '		["' .. key .. '"] = ' .. tostring(value) .. ',\n'
			end
		end
		txt = txt .. '	}, -- end of [' .. i .. ']\n'
	end

	txt = txt .. '}, -- end of [' .. input .. ']\n'
	showbuf(txt)
end

-- =================
-- CTLD helpers (Grayflag)
-- =================

local CTLDunit = {
	['CH-47Fbl1'] = 1,
	['Mi-24P'] = 1,
	['Mi-8MT'] = 1,
	['UH-1H'] = 1,
	['UH-60L'] = 1,
}

if CTLDunit[unittype] then
	ft.GFdrop = function()
		Export.LoSetCommand(179) -- comm
		Export.LoSetCommand(975) -- F10
		Export.LoSetCommand(966) -- F1
		Export.LoSetCommand(971) -- F6
		Export.LoSetCommand(968) -- F3
	end
	table.insert(ft.order, 'GFdrop')

	ft.GFload = function()
		Export.LoSetCommand(179) -- comm
		Export.LoSetCommand(975) -- F10
		Export.LoSetCommand(966) -- F1
		Export.LoSetCommand(971) -- F6
		Export.LoSetCommand(966) -- F1
	end
	table.insert(ft.order, 'GFload')
end

ft.ammo = function()
	local ok, info = pcall(Export.LoGetPayloadInfo)
	if not ok or not info or not info.Stations then
		loglocal('ft[ammo] LoGetPayloadInfo failed or no Stations')
		return
	end
	local pl = info.Stations
	if not pl then
		loglocal('ft[ammo] LoGetPayloadInfo returned nil')
		return
	end

	for _, j in pairs(pl) do
		if j.wstype then
			if j.CLSID and j.count then
				local info = j.CLSID .. ': ' .. j.count
				net.recv_chat(info)
				loglocal(info)
			else
				loglocal('ft[ammo] err: no CLSID/count for wstype: ' .. j.wstype)
			end
		end
	end
end

ft.globalfile = function(input)
	loglocal('globalfile call', 2)
	if switchExtPage(Scratchdir .. Scratchpadfn) then
		local txt = ''
		local readtxt = ''
		if not TA then
			TA = getTextarea()
		end

		local infn = (Moduledir or Apitlibdir) .. 'Globalcustom.lua'
		local infile, res
		infile, res = io.open(infn, 'r')
		if not infile then
			txt = txt .. '\nGlobalcustom.lua file not found in ' .. (Modulesubdir or Apitlibsubdir)
			loglocal('aeronautespit Globalcustom.lua open file fail; non critical' .. res)
			return
		else
			readtxt = infile:read('*all')
			infile:close()
			if not readtxt then
				loglocal('aeronautespit Globalcustom.lua read error; ' .. infn)
			else
				txt = txt .. '-- COPY of ' .. (Modulesubdir or Apitlibsubdir) .. 'Globalcustom.lua\n' .. readtxt
			end
		end

		TA:setText('')
		-- Hardcoded 1 MB file limit from Scratchpad
		local buflen = string.len(txt)
		if buflen > (1024 * 1024) then
			txt = string.sub(txt, 0, (1024 * 1024) - 80)
			txt = txt .. '<<< File too big for scratchpad. Displaying truncated to 1MB >>>'
			loglocal('apit mod buflen > 1MB: ' .. buflen)
		end

		TA:setText(txt)
	end
end

return ft
