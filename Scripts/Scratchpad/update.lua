local os = os
local io = io
local require = require
local string = string
local tostring = tostring
local tonumber = tonumber
local table = table
local pcall = pcall

local lfs = require("lfs")

local CURRENT_VERSION = "1.0.0"
local RELEASES_URL = "https://api.github.com/repos/rkusa/dcs-scratchpad/releases/latest"
local CHECK_DELAY = 10
local RESULT_WAIT = 5

local Update = {}
local Update_mt = { __index = Update }

local function parseVersion(s)
	s = string.match(tostring(s or ""), "(%d+[%d%.]*)") or ""
	local a, b, c = string.match(s, "^(%d+)%.?(%d*)%.?(%d*)")
	return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0
end

local function isNewer(remote, localVer)
	local r1, r2, r3 = parseVersion(remote)
	local l1, l2, l3 = parseVersion(localVer)
	if r1 ~= l1 then return r1 > l1 end
	if r2 ~= l2 then return r2 > l2 end
	return r3 > l3
end

local function extractTag(body)
	if not body or body == "" then
		return nil
	end
	local tag = string.match(body, '"tag_name"%s*:%s*"([^"]+)"')
	if tag and tag ~= "" then
		return tag
	end
	return nil
end

local function logDir()
	local dir = lfs.writedir() .. "Logs\\"
	if lfs.tempdir then
		dir = lfs.tempdir()
		if string.sub(dir, -1) ~= "\\" and string.sub(dir, -1) ~= "/" then
			dir = dir .. "\\"
		end
	end
	return dir
end

local function readFile(path)
	if not path or not io.open then
		return nil
	end
	local f = io.open(path, "rb")
	if not f then
		return nil
	end
	local body = f:read("*a") or ""
	f:close()
	return body
end

local function writeFile(path, body)
	local f = io.open(path, "wb")
	if not f then
		return false
	end
	f:write(body)
	f:close()
	return true
end

local function deleteFile(path)
	if not path then
		return
	end
	pcall(function()
		if os.remove then
			os.remove(path)
		end
	end)
end

local function vbsQuote(s)
	return string.gsub(tostring(s or ""), '"', '""')
end

local function quoteCmd(s)
	return '"' .. string.gsub(tostring(s or ""), '"', "") .. '"'
end

local function spawnWinHttp(outPath, vbsPath)
	local root = os.getenv("SystemRoot") or os.getenv("WINDIR") or "C:\\Windows"
	local wscript = root .. "\\System32\\wscript.exe"
	local vbs = table.concat({
		"On Error Resume Next",
		"Set http = CreateObject(\"WinHttp.WinHttpRequest.5.1\")",
		"If Err.Number <> 0 Then WScript.Quit 2",
		"http.SetTimeouts 3000, 3000, 3000, 3000",
		"http.Open \"GET\", \"" .. vbsQuote(RELEASES_URL) .. "\", False",
		"http.SetRequestHeader \"User-Agent\", \"Scratchpad\"",
		"http.SetRequestHeader \"Accept\", \"application/vnd.github+json\"",
		"http.Send",
		"If Err.Number <> 0 Then WScript.Quit 3",
		"If http.Status <> 200 Then WScript.Quit 4",
		"Set fso = CreateObject(\"Scripting.FileSystemObject\")",
		"Set ts = fso.CreateTextFile(\"" .. vbsQuote(outPath) .. "\", True)",
		"ts.Write http.ResponseText",
		"ts.Close",
		"WScript.Quit 0",
		"",
	}, "\r\n")

	if not writeFile(vbsPath, vbs) then
		return false
	end

	os.execute('start "" /B ' .. quoteCmd(wscript) .. ' //nologo //B ' .. quoteCmd(vbsPath))
	return true
end

function Update:new(app)
	local self = setmetatable({}, Update_mt)
	self.app = app
	self.startedAt = os.time()
	self.done = false
	self.pending = false
	self.pendingSince = 0
	self.outPath = nil
	self.vbsPath = nil
	return self
end

function Update:finish(tag, note)
	self.done = true
	self.pending = false
	deleteFile(self.outPath)
	deleteFile(self.vbsPath)
	self.outPath = nil
	self.vbsPath = nil

	if not tag then
		if self.app and self.app.log then
			self.app.log("Update check: no tag (" .. tostring(note or "offline") .. ").")
		end
		return
	end

	if not isNewer(tag, CURRENT_VERSION) then
		if self.app and self.app.log then
			self.app.log("Update check: up to date (" .. CURRENT_VERSION .. ").")
		end
		return
	end

	local displayTag = string.gsub(tag, "^[vV]", "")

	if self.app and self.app.log then
		self.app.log("Update available: " .. displayTag .. " (installed " .. CURRENT_VERSION .. ")")
	end

	-- Insert simple version notice
	if self.app and self.app.text and self.app.text.Text and self.app.state and self.app.state.textarea then
		local ok, err = pcall(function()
			self.app.text.Text.new():insertTop("Update available: " .. displayTag)
		end)
		if not ok and self.app.log then
			self.app.log("Failed to insert update notice: " .. tostring(err))
		end
	end
end

function Update:tick(now)
	if self.done then
		return
	end

	local config = self.app and self.app.config
	if config and config.getShowUpdates and not config.getShowUpdates() then
		if self.app and self.app.log then
			self.app.log("Update check disabled.")
		end
		self.done = true
		return
	end

	if self.pending then
		local body = readFile(self.outPath)
		local tag = extractTag(body)
		if tag then
			self:finish(tag)
			return
		end
		if now - self.pendingSince >= RESULT_WAIT then
			self:finish(nil, "timed out")
		end
		return
	end

	if now - self.startedAt < CHECK_DELAY then
		return
	end

	if not os.execute then
		if self.app and self.app.log then
			self.app.log("Update check skipped: DCS blocked process execution.")
		end
		self.done = true
		return
	end

	local dir = logDir()
	self.outPath = dir .. "Scratchpad-update-check.json"
	self.vbsPath = dir .. "Scratchpad-update-check.vbs"
	deleteFile(self.outPath)
	deleteFile(self.vbsPath)

	local ok, spawned = pcall(spawnWinHttp, self.outPath, self.vbsPath)
	if not ok or not spawned then
		if self.app and self.app.log then
			self.app.log("Update check failed: " .. tostring(spawned))
		end
		self:finish(nil, "spawn failed")
		return
	end

	self.pending = true
	self.pendingSince = now
end

return Update
