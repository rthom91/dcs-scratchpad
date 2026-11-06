local lfs = require("lfs")

return function(app)
	local S = app.state

	local function loadExtensions()
		app.log("Loading extensions.")

		local function loadExtension(path, name)
			local f, err = loadfile(path)
			if not f then
				app.log("Error reading file `" .. path .. "`: " .. err)
				return {}
			end

			-- prepare extension panel
			local children = {}
			local extid = name
			S.extensions[extid] = {children = children}

			-- create extension env
			local extEnv = {
				addButton = function(x, y, w, h, title, onClick)
					table.insert(children, {
						x = x,
						y = y,
						w = w,
						h = h,
						title = title,
						onClick = onClick
					})
				end,
				addCoordinateListener = function(listener)
					table.insert(S.coordListeners, listener)
				end,
				formatCoord = app.coords.format,
				log = app.log,
				getSelection = app.text.getSelection,
				switchPage = app.pages.switch,
				switchExtPage = app.pages.switchExt,
				prevPage = app.pages.prev,
				nextPage = app.pages.next,
				extid = extid,
				panel = S.extensions[extid].children,
				isHidden = function()
					return S.isHidden
				end,
				getTextarea = function()
					return S.textarea
				end,
			}
			setmetatable(extEnv, {__index = _G})
			setfenv(f, extEnv)

			local ok, res = pcall(f)
			if not ok then
				app.log("Error executing extension `" .. path .. "`: " .. res)
				return
			end
		end

		local extensionsPath = lfs.writedir() .. [[Scripts\Scratchpad\Extensions\]]
		lfs.mkdir(lfs.writedir() .. [[Scripts\Scratchpad\]])
		lfs.mkdir(extensionsPath)

		for name in lfs.dir(extensionsPath) do
			local path = extensionsPath .. name
			if lfs.attributes(path, "mode") == "file" then
				if name:sub(-4) ~= ".lua" then
					app.log("Ignoring file " .. name .. ", because it does not seem to be an extension.")
				elseif lfs.attributes(path, "size") > 1024 * 1024 then
					app.log("Ignoring file " .. name .. ", because of its file size of more than 1MB.")
				else
					app.log("Found extension " .. path)
					loadExtension(path, name)
				end
			end
		end

		app.log("Extensions loaded.")
	end

	return {
		load = loadExtensions,
	}
end
