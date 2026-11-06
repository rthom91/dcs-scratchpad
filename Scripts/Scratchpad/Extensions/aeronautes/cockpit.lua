--[[
	Cockpit click helpers and the tooltip trie.
	Loaded into the Apit environment.
]]

function cancelmacro()
	loglocal('cancelmacro')
	domacro.inp = {}
	domacro.idx = 1
	domacro.flag = false
	Spinr:rest()
end

-- Trie Node definition
TrieNode = {}
TrieNode.__index = TrieNode

function TrieNode:new()
	return setmetatable({
		children = {},
		isEndOfWord = false,
		elem = {},
	}, TrieNode)
end

-- Trie definition
Trie = {}
Trie.__index = Trie

function Trie:new()
	return setmetatable({ root = TrieNode:new() }, Trie)
end

-- Insert a key into the Trie. Returns the terminal node, or nil on invalid input.
function Trie:insert(key)
	if type(key) ~= "string" or #key == 0 then
		return nil
	end

	local node = self.root
	for i = 1, #key do
		local char = key:sub(i, i)
		if not node.children[char] then
			node.children[char] = TrieNode:new()
		end
		node = node.children[char]
	end
	node.isEndOfWord = true
	return node
end

function Trie:search(key)
	local node = self.root
	for i = 1, #key do
		local char = key:sub(i, i)
		if not node.children[char] then
			return nil
		end
		node = node.children[char]
	end
	return node
end

-- Helper function to collect all keys from a node
local function collectKeys(node, prefix, results)
	if node.isEndOfWord then
		table.insert(results, prefix)
	end
	for char, child in pairs(node.children) do
		collectKeys(child, prefix .. char, results)
	end
end

-- Returns all keys starting from a given node
function Trie:getAllKeysFromNode(node, prefix)
	local results = {}
	collectKeys(node, prefix or "", results)
	return results
end

-- =================
-- Module discovery
-- =================

local modname2dir = {}

function searchmodules()
	local moddir2name = {}

	local function scandir(dir)
		local total = 0
		for i, _ in lfs.dir(dir) do
			local atr = lfs.attributes(dir .. i)
			if atr and atr.mode == 'directory'
			   and i ~= '.' and i ~= '..' and i ~= 'Flaming Cliffs' then
				moddir2name[i] = { dir = dir .. i }
				total = total + 1
			end
		end
		return total
	end

	local scandirtot = 0
	scandirtot = scandir(lfs.currentdir() .. [[Mods\aircraft\]]) -- DCS install
	scandirtot = scandirtot + scandir(lfs.writedir() .. [[Mods\aircraft\]]) -- Saved Games

	local modnametot = 0
	for i, j in pairs(moddir2name) do
		local fp, res = io.open(j.dir .. [[\entry.lua]])
		if fp then
			for l in fp:lines() do
				local ut = string.match(l, [[^%w+_flyable[(]['"]([^'"]+)]])
				if ut then
					modname2dir[ut] = moddir2name[i]
					modnametot = modnametot + 1
					loglocal('aeronautespit searchmodules: added ' .. ut, 2)
				end
			end
			fp:close()
		else
			loglocal('aeronautes-pit searchmodules open error: ' .. res)
		end
	end

	loglocal('aeronautespit searchmodules found: ' .. scandirtot .. ' named: ' .. modnametot)
end

-- =================
-- Initialization
-- =================

loglocal('aeronautes-pit extension loaded.')

function setupfiles()
	local fqfn = Scratchdir .. Scratchpadfn
	local atr = lfs.attributes(fqfn)
	if atr and atr.mode == 'file' then
		return
	end

	loglocal('apit setupfiles() creating ' .. Scratchpadfn)
	local infile, res = io.open(fqfn, 'w')
	if not infile then
		loglocal('aeronautespit setupfiles() open fail; ' .. res)
		return nil
	end
	infile:close()
end

setupfiles()
searchmodules()

for i, j in pairs(modname2dir) do
	if not LT[i] then
		LT[i] = {}
	end
	LT[i].dirname = j.dir
	loglocal('aeronautespit cycle LT.dirname: ' .. i .. ' = ' .. LT[i].dirname, 2)
end

-- =================
-- Key press / macro insertion
-- =================

function press(inp, param)
	loglocal('press(): ' .. inp, 5)
	if type(inp) ~= 'string' then
		loglocal('aeronautespit press: non string type, ' .. type(inp))
		return
	end

	if param and param.fn then
		loglocal('press() fn ' .. DCS.getRealTime())
		table.insert(domacro.inp, { -1, -1, param.delay, -1, nil })
		table.insert(domacro.inp, { -1, -1, param.delay, -1, param.fn, param.arg })
	end

	for key in string.gmatch(inp, '.') do
		if kp[key] == nil then
			loglocal('upload: press() nil ' .. key, 6)
			return ''
		end
		if type(kp[key][1]) == 'table' then
			local a = kp[key]
			local ctr = 0
			for i, _ in pairs(a) do
				loglocal('press(): insert1 ' .. a[i][1] .. ', ' .. a[i][2], 5)
				table.insert(domacro.inp, a[i])
				ctr = ctr + 1
			end
		else
			loglocal('press(): insert2 key ' .. key, 5)
			table.insert(domacro.inp, kp[key])
		end
	end
	loglocal('press(): exit', 5)
end

function push_stop_command(itval, c)
	loglocal('aeronautespit: push_stop_command() start ' .. net.lua2json(c), 2)
	if c.device and c.action and c.value then
		loglocal('push_stop_command: device ' .. c.device .. ', action ' .. c.action .. ', value ' .. c.value .. ' fn ' .. type(c.fn) .. ' arg: ' .. type(c.arg), 2)
		if not c.len then c.len = itval end
		if not c.fn  then c.fn  = nil   end
		table.insert(domacro.inp, { c.action, c.value, c.len, c.device, c.fn, c.arg })
	end
end

-- =================
-- Tooltip → device/action lookup
-- =================

function TTtoDA(name, parms)
	local tmp = parms or { value = 1.0 }

	loglocal('aeronautespit TTtoDA name: #' .. name .. '#' .. net.lua2json(tmp), 4)
	if type(ttlist[name]) == 'table' then
		for i, j in pairs(ttlist[name]) do
			if not tmp[i] then
				tmp[i] = j
			end
		end
		return tmp
	end

	loglocal('aeronautespit TTtoDA not found: ' .. name)
	return nil
end

-- =================
-- Tooltip-based click helpers
-- =================

function tt(name, params)
	local tmp = params or { value = 1.0 }

	if name and #name > 0 then
		tmp = TTtoDA(name, tmp)
		if not tmp then
			loglocal('tt() unknown name: ' .. name)
			return
		end
	end

	loglocal('tt table: ' .. net.lua2json(tmp), 4)
	push_stop_command(itval, tmp)
end

-- Tooltip on (value = 1)
function ttn(name, params)
	local tmp = params or {}
	tmp.value = 1
	tt(name, tmp)
end

-- Tooltip off (value = 0)
function ttf(name, params)
	local tmp = params or {}
	tmp.value = 0
	tt(name, tmp)
end

-- Tooltip toggle
function ttt(name, params)
	local tmp = params or {}

	tmp.value = tmp.onvalue or 1
	tt(name, tmp)

	tmp.value = tmp.offvalue or 0
	tt(name, tmp)
end

-- =================
-- Delay and low-level click builders
-- =================

function delay(seconds)
	loglocal('delay: ' .. seconds)
	push_stop_command(0, {
		device = -1,
		action = -1,
		value = 0,
		len = seconds,
		fn = function() Spinr:delay() end,
	})
end

function tap(cmd, device, press, release, press_delay, release_delay)
	return {
		{ cmd, press or 1, press_delay or 0, device },
		{ cmd, release or 0, release_delay or 0, device },
	}
end

function click(cmd, device, value, delay)
	return { cmd, value or 1, delay or 0, device }
end

function assign_seq(map, keys, cmd_table, first, device, builder)
	for i = 1, #keys do
		local key = keys:sub(i, i)
		map[key] = builder(cmd_table["Button_" .. (first + i - 1)], device)
	end
end
