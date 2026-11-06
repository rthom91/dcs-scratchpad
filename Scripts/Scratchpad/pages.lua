local lfs = require("lfs")

return function(app)
	local S = app.state

	local function updateNativeTitle(index, total)
		if S.window then
			S.window:setText("Scratchpad (Page " .. tostring(index) .. "/" .. tostring(total) .. ")")
		end
	end

	local function updateExtTitle(name)
		if S.window then
			S.window:setText("Scratchpad (" .. name .. ")")
		end
	end

	local function loadPage(page)
		app.log("Loading page " .. page.path)
		local file, err = io.open(page.path, "r")
		local content = ""
		if err then
			app.log("Page file missing, creating: " .. page.path)
			local base = lfs.writedir() .. [[Scratchpad\]]
			local pagesDir = base .. [[pages\]]
			lfs.mkdir(base)
			lfs.mkdir(pagesDir)
			local created = io.open(page.path, "w")
			if created then
				created:write("")
				created:close()
			end
		else
			content = file:read("*all") or ""
			file:close()
		end
		if S.textarea then
			S.textarea:setText(content)
		end
		S.lastSavedText = content
		S._saveBtnLabel = "Saved"
		if S.savePageBtn then
			S.savePageBtn:setText("Saved")
		end
		S.currentPage = page.path
		S.currentNativePath = page.path
		S.currentExtIndex = nil

		local index = 1
		for i, p in ipairs(S.pages) do
			if p.path == page.path then
				index = i
				break
			end
		end
		local total = S.pagesCount
		if type(total) ~= "number" or total < 1 then
			total = #S.pages
		end
		if total < 1 then
			total = 1
		end
		updateNativeTitle(index, total)
	end

	local function loadExt(path, name)
		app.log("Loading ext page " .. path)
		local file, err = io.open(path, "r")
		local content = ""
		if err then
			app.log("Ext page missing, creating: " .. path)
			local base = lfs.writedir() .. [[Scratchpad\]]
			local extDir = base .. [[ext\]]
			lfs.mkdir(base)
			lfs.mkdir(extDir)
			local created = io.open(path, "w")
			if created then
				created:write("")
				created:close()
			end
		else
			content = file:read("*all") or ""
			file:close()
		end
		if S.textarea then
			S.textarea:setText(content)
		end
		S.lastSavedText = content
		S._saveBtnLabel = "Saved"
		if S.savePageBtn then
			S.savePageBtn:setText("Saved")
		end
		S.currentPage = path
		updateExtTitle(name)
	end

	local function savePage(path, content, override)
		if path == nil then
			return
		end

		app.log("Saving page " .. path)
		local base = lfs.writedir() .. [[Scratchpad\]]
		lfs.mkdir(base)
		local mode = "a"
		if override then
			mode = "w"
		end
		local file, err = io.open(path, mode)
		if err then
			app.log("Error writing file: " .. path)
		else
			file:write(content)
			file:flush()
			file:close()
		end
	end

	local function getNativeIndex()
		if not S.currentNativePath then
			return 1
		end
		for i, p in ipairs(S.pages) do
			if p.path == S.currentNativePath then
				return i
			end
		end
		return 1
	end

	local function ensureCurrentPage()
		if S.currentPage == nil and S.pages[1] then
			loadPage(S.pages[1])
			return true
		end
		return false
	end

	local function nextPage()
		if S.pagesCount < 1 then
			ensureCurrentPage()
			return
		end

		if ensureCurrentPage() then
			return
		end

		if S.currentPage then
			savePage(S.currentPage, S.textarea:getText(), true)
		end

		local idx = getNativeIndex()
		local ins = S.insertions[S.currentNativePath] or {}

		if S.currentExtIndex == nil then
			-- on native
			if #ins > 0 then
				S.currentExtIndex = 1
				loadExt(ins[1].path, ins[1].name)
			else
				local nextIdx = idx + 1
				if nextIdx > S.pagesCount then
					nextIdx = 1
				end
				loadPage(S.pages[nextIdx])
			end
		else
			-- on ext
			if S.currentExtIndex < #ins then
				S.currentExtIndex = S.currentExtIndex + 1
				loadExt(ins[S.currentExtIndex].path, ins[S.currentExtIndex].name)
			else
				local nextIdx = idx + 1
				if nextIdx > S.pagesCount then
					nextIdx = 1
				end
				loadPage(S.pages[nextIdx])
			end
		end
	end

	local function prevPage()
		if S.pagesCount < 1 then
			ensureCurrentPage()
			return
		end

		if ensureCurrentPage() then
			return
		end

		if S.currentPage then
			savePage(S.currentPage, S.textarea:getText(), true)
		end

		local idx = getNativeIndex()
		local ins = S.insertions[S.currentNativePath] or {}

		if S.currentExtIndex == nil then
			-- on native, go to previous native's last insertion or previous native
			local prevIdx = idx - 1
			if prevIdx < 1 then
				prevIdx = S.pagesCount
			end
			local prevPath = S.pages[prevIdx].path
			local prevIns = S.insertions[prevPath] or {}
			if #prevIns > 0 then
				S.currentNativePath = prevPath
				S.currentExtIndex = #prevIns
				loadExt(prevIns[S.currentExtIndex].path, prevIns[S.currentExtIndex].name)
			else
				loadPage(S.pages[prevIdx])
			end
		else
			-- on ext
			if S.currentExtIndex > 1 then
				S.currentExtIndex = S.currentExtIndex - 1
				loadExt(ins[S.currentExtIndex].path, ins[S.currentExtIndex].name)
			else
				-- back to the anchoring native page
				local page = nil
				for _, p in ipairs(S.pages) do
					if p.path == S.currentNativePath then
						page = p
						break
					end
				end
				if page then
					loadPage(page)
				end
			end
		end
	end

	local function switchPage(pname)
		if pname == nil then
			return S.currentPage
		end

		local found = nil
		for _, page in ipairs(S.pages) do
			if page.path == pname then
				found = page
			end
		end
		if found then
			if S.currentPage ~= pname then
				if S.currentPage then
					savePage(S.currentPage, S.textarea:getText(), true)
				end
				loadPage(found)
			end
			return found
		else
			app.log("switchPage() could not find: " .. pname)
			return nil
		end
	end

	local function switchExt(path)
		if path == nil then
			return S.currentPage
		end

		local anchor = S.currentNativePath
		if not anchor and S.pages[1] then
			anchor = S.pages[1].path
			S.currentNativePath = anchor
		end
		if not anchor then
			app.log("switchExt() no native page to anchor to")
			return nil
		end

		local name = path:match("([^\\]+)$") or "ext"
		if not S.insertions[anchor] then
			S.insertions[anchor] = {}
		end
		local ins = S.insertions[anchor]
		local pos = nil
		for i, e in ipairs(ins) do
			if e.path == path then
				pos = i
				break
			end
		end
		if not pos then
			table.insert(ins, { path = path, name = name })
			pos = #ins
		end

		if S.currentPage then
			savePage(S.currentPage, S.textarea:getText(), true)
		end
		S.currentExtIndex = pos
		loadExt(path, name)
		return true
	end

	local function loadPages()
		S.pages = {}
		S.pagesCount = 0
		S.insertions = {}
		S.currentNativePath = nil
		S.currentExtIndex = nil
		local base = lfs.writedir() .. [[Scratchpad\]]
		local dirPath = base .. [[pages\]]
		local extDir = base .. [[ext\]]
		lfs.mkdir(base)
		lfs.mkdir(dirPath)
		lfs.mkdir(extDir)

		local ignored = 0
		-- scan scratchpad dir for pages
		for name in lfs.dir(dirPath) do
			local path = dirPath .. name
			if lfs.attributes(path, "mode") == "file" then
				if name:sub(-4) ~= ".txt" then
					ignored = ignored + 1
				elseif lfs.attributes(path, "size") > 1024 * 1024 then
					ignored = ignored + 1
				else
					table.insert(
						S.pages,
						{
							name = name:sub(1, -5),
							path = path
						}
					)
					S.pagesCount = S.pagesCount + 1
				end
			end
		end

		table.sort(S.pages, function(a, b)
			return a.name < b.name
		end)

		-- there are no pages yet, create one
		if S.pagesCount == 0 then
			local path = dirPath .. [[0001.txt]]
			savePage(path, "", true)
			table.insert(
				S.pages,
				{
					name = "0001",
					path = path
				}
			)
			S.pagesCount = S.pagesCount + 1
			app.log("Created default page 0001.txt")
		end

		local msg = "Found " .. S.pagesCount .. " page" .. (S.pagesCount == 1 and "" or "s")
		if ignored > 0 then
			msg = msg .. " (" .. ignored .. " ignored)"
		end
		app.log(msg)
	end

	local function nextFreeName()
		local used = {}
		for _, page in ipairs(S.pages) do
			used[page.name] = true
		end
		local n = 1
		while n < 10000 do
			local name = string.format("%04d", n)
			if not used[name] then
				return name
			end
			n = n + 1
		end
		return tostring(os.time())
	end

	local function addPage()
		if S.textarea and S.currentPage then
			savePage(S.currentPage, S.textarea:getText(), true)
		end

		local base = lfs.writedir() .. [[Scratchpad\]]
		local dirPath = base .. [[pages\]]
		lfs.mkdir(base)
		lfs.mkdir(dirPath)
		local name = nextFreeName()
		local path = dirPath .. name .. ".txt"
		local file, err = io.open(path, "w")
		if not file then
			app.log("Error creating page: " .. tostring(err))
			return
		end
		file:write("")
		file:close()
		app.log("Created page " .. path)

		loadPages()
		for _, page in ipairs(S.pages) do
			if page.path == path then
				loadPage(page)
				return
			end
		end
		if S.pagesCount > 0 then
			loadPage(S.pages[S.pagesCount])
		end
	end

	local function deletePage()
		if S.pagesCount <= 1 then
			if S.textarea then
				S.textarea:setText("")
			end
			if S.currentPage then
				savePage(S.currentPage, "", true)
			end
			if S.pages[1] then
				loadPage(S.pages[1])
			end
			app.log("Last page cleared, not removed.")
			return
		end

		local removePath = S.currentPage
		local removeIndex = 1
		for i, page in ipairs(S.pages) do
			if page.path == removePath then
				removeIndex = i
				break
			end
		end

		if removePath then
			os.remove(removePath)
			app.log("Deleted page " .. removePath)
		end

		loadPages()

		if S.pagesCount == 0 then
			addPage()
			return
		end

		local idx = removeIndex
		if idx > S.pagesCount then
			idx = S.pagesCount
		end
		if idx < 1 then
			idx = 1
		end
		loadPage(S.pages[idx])
	end

	return {
		load = loadPages,
		loadPage = loadPage,
		save = savePage,
		next = nextPage,
		prev = prevPage,
		switch = switchPage,
		switchExt = switchExt,
		add = addPage,
		delete = deletePage,
	}
end
