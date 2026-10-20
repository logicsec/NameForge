-- NameForge options window (opened from the minimap button, addon compartment or /nf).

local _, ns = ...
local Core, Format, Data, Theme, W = ns.Core, ns.Format, ns.Data, ns.Theme, ns.Widgets
local C = Theme.color

local Options = {}
ns.Options = Options

local WIDTH, HEIGHT = 868, 600
local SIDEBAR_W = 196
local CONTENT_INNER_W = WIDTH - 14 - SIDEBAR_W - 12 - 14 - 28

local frame
local pages = {}
local catButtons = {}
local current = "names"

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function validateInto(row, text, defaultDesc)
	local nodes, err = Format.Compile(text)
	if nodes then
		row.desc:SetText(defaultDesc)
		Theme.TextColor(row.desc, C.muted)
		return true
	end
	row.desc:SetText(err)
	Theme.TextColor(row.desc, C.error)
	return false
end

local function buildPreviewDisplay(sample)
	local data = {}
	for k, v in pairs(sample) do data[k] = v end
	return Core:BuildDisplay(data, nil)
end

-- ---------------------------------------------------------------------------
-- Names page
-- ---------------------------------------------------------------------------

local PRIMARY_DESC = "Shown on nameplates, tooltips and the target frame"
local SECONDARY_DESC = "Uses the same tokens as the primary name"

local function buildNamesPage(parent)
	local page = CreateFrame("Frame", nil, parent)
	page:SetAllPoints()

	local group = W.Group(page, "Name Format", CONTENT_INNER_W)
	group:SetPoint("TOPLEFT", 0, 0)

	local primaryEdit, secondaryEdit, previews
	local function refreshPreview()
		local samples = { Data.PlayerSample(), Data.SAMPLES[2] }
		for i, p in ipairs(previews) do
			local s = samples[i]
			p:SetDisplay(buildPreviewDisplay(s), s.f, s.caption)
		end
	end
	page.refreshPreview = refreshPreview

	-- Primary format
	local primaryRow
	primaryEdit = W.EditBox(group.box, 260, function(text)
		if validateInto(primaryRow, text, PRIMARY_DESC) and text ~= "" then
			Core.db.global.primary = text
			Core:Invalidate()
			refreshPreview()
		end
	end, true)
	primaryRow = group:AddRow("Primary name", PRIMARY_DESC, primaryEdit)

	-- Token buttons
	local tokenBar = CreateFrame("Frame", nil, group.box)
	tokenBar:SetSize(260, 26)
	local x = 0
	for i = #Format.TOKENS, 1, -1 do
		local t = Format.TOKENS[i]
		local b = W.Button(tokenBar, "{" .. t.key .. "}", 34, 26, function()
			W.InsertToken(primaryEdit, "{" .. t.key .. "}")
		end)
		b.label:SetFontObject("GameFontNormalSmall")
		Theme.TextColor(b.label, C.gold)
		b.tooltip = t.label
		b:SetPoint("RIGHT", tokenBar, "RIGHT", -x, 0)
		x = x + 37
	end
	group:AddRow("Insert token", "Optional parts go in [ ]. { } [ ] are reserved: type [[ or {{ for one", tokenBar)

	-- Secondary toggle
	local secCheck = W.Checkbox(group.box, function(checked)
		Core.db.global.secondaryEnabled = checked and true or false
		secondaryEdit:SetEnabledState(checked)
		Core:Invalidate()
		refreshPreview()
	end)
	group:AddRow("Show secondary name", "Adds a second, smaller line below the primary name", secCheck)

	-- Secondary format
	local secondaryRow
	secondaryEdit = W.EditBox(group.box, 260, function(text)
		if validateInto(secondaryRow, text, SECONDARY_DESC) then
			Core.db.global.secondary = text
			Core:Invalidate()
			refreshPreview()
		end
	end, true)
	secondaryRow = group:AddRow("Secondary format", SECONDARY_DESC, secondaryEdit)

	-- Class color
	local colorCheck = W.Checkbox(group.box, function(checked)
		Core.db.global.classColor = checked and true or false
		Core:Invalidate()
		refreshPreview()
	end)
	group:AddRow("Color by class", "Tint the primary name with the character's class color", colorCheck)

	-- Preview
	local pv = CreateFrame("Frame", nil, page)
	pv:SetPoint("TOPLEFT", group, "BOTTOMLEFT", 0, -14)
	pv:SetSize(CONTENT_INNER_W, 130)
	local pvTitle = pv:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	pvTitle:SetPoint("TOPLEFT", 12, 0)
	pvTitle:SetText("Preview")
	local pvBox = CreateFrame("Frame", nil, pv, "BackdropTemplate")
	pvBox:SetPoint("TOPLEFT", 0, -18)
	pvBox:SetPoint("BOTTOMRIGHT")
	Theme.Backdrop(pvBox, C.panel, C.borderDim)
	local pw = (CONTENT_INNER_W - 36) / 2
	previews = { W.Preview(pvBox, pw), W.Preview(pvBox, pw) }
	previews[1]:SetPoint("TOPLEFT", 12, -12)
	previews[2]:SetPoint("TOPRIGHT", -12, -12)

	function page:Refresh()
		local g = Core.db.global
		primaryEdit:SetText(g.primary)
		validateInto(primaryRow, g.primary, PRIMARY_DESC)
		secondaryEdit:SetText(g.secondary)
		validateInto(secondaryRow, g.secondary, SECONDARY_DESC)
		secCheck:SetChecked(g.secondaryEnabled)
		secondaryEdit:SetEnabledState(g.secondaryEnabled)
		colorCheck:SetChecked(g.classColor)
		refreshPreview()
	end
	return page
end

-- ---------------------------------------------------------------------------
-- Display page
-- ---------------------------------------------------------------------------

local SURFACES = {
	{ key = "nameplate", label = "Nameplates", desc = "Primary and secondary name on Blizzard nameplates" },
	{ key = "tooltip", label = "Unit tooltip", desc = "Replaces the first line and adds the secondary name under it" },
	{ key = "target", label = "Target and focus frames", desc = "Primary name only" },
}

local function buildDisplayPage(parent)
	local page = CreateFrame("Frame", nil, parent)
	page:SetAllPoints()
	local group = W.Group(page, "Where Names Change", CONTENT_INNER_W)
	group:SetPoint("TOPLEFT", 0, 0)

	local checks = {}
	for _, s in ipairs(SURFACES) do
		local cb = W.Checkbox(group.box, function(checked)
			Core.db.global.surfaces[s.key] = checked and true or false
			Core:Invalidate()
		end)
		checks[s.key] = cb
		group:AddRow(s.label, s.desc, cb)
	end
	local chat = W.Checkbox(group.box)
	chat:Disable()
	chat:SetAlpha(0.4)
	local chatRow = group:AddRow("Chat sender names", "Planned for a later version", chat)
	Theme.TextColor(chatRow.label, C.muted)

	function page:Refresh()
		for key, cb in pairs(checks) do cb:SetChecked(Core.db.global.surfaces[key]) end
	end
	return page
end

-- ---------------------------------------------------------------------------
-- Overrides page
-- ---------------------------------------------------------------------------

local function describeOverride(o)
	local parts = {}
	if o.nickname then parts[#parts + 1] = "Nickname: " .. o.nickname end
	parts[#parts + 1] = "Primary: " .. (o.primary or "global")
	local sec
	if o.secondaryEnabled == false then
		sec = "off"
	else
		sec = o.secondary or "global"
		if o.secondaryEnabled == true then sec = sec .. " (on)" end
	end
	parts[#parts + 1] = "Secondary: " .. sec
	return table.concat(parts, "   ")
end

local function buildOverridesPage(parent)
	local page = CreateFrame("Frame", nil, parent)
	page:SetAllPoints()

	local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 12, 0)
	title:SetText("Character Overrides")

	local box = CreateFrame("Frame", nil, page, "BackdropTemplate")
	box:SetPoint("TOPLEFT", 0, -18)
	box:SetPoint("BOTTOMRIGHT", 0, 28)
	Theme.Backdrop(box, C.panel, C.borderDim)

	local hint = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("BOTTOMLEFT", 12, 8)
	Theme.TextColor(hint, C.muted)
	hint:SetText("Add an override from the Inspect window, the unit right-click menu, or /nf target.")

	local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 8, -6)
	scroll:SetPoint("BOTTOMRIGHT", -28, 6)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(CONTENT_INNER_W - 40, 10)
	scroll:SetScrollChild(child)

	local empty = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	empty:SetPoint("CENTER")
	Theme.TextColor(empty, C.muted)
	empty:SetText("No overrides yet.")

	local rows = {}
	local ROW_H = 54

	local function getRow(i)
		local row = rows[i]
		if row then return row end
		row = CreateFrame("Frame", nil, child)
		row:SetHeight(ROW_H)
		row:SetPoint("TOPLEFT", 8, -(i - 1) * ROW_H)
		row:SetPoint("TOPRIGHT", -8, -(i - 1) * ROW_H)
		row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		row.name:SetPoint("TOPLEFT", 0, -10)
		row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.detail:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
		Theme.TextColor(row.detail, C.muted)
		row.delete = W.Button(row, "Delete", 70, 28, nil, "danger")
		row.delete:SetPoint("RIGHT", 0, 0)
		row.edit = W.Button(row, "Edit", 60, 28)
		row.edit:SetPoint("RIGHT", row.delete, "LEFT", -8, 0)
		row.detail:SetPoint("RIGHT", row.edit, "LEFT", -12, 0)
		row.detail:SetJustifyH("LEFT")
		row.detail:SetWordWrap(false)
		if i > 1 then
			local sep = Theme.Separator(row)
			sep:SetPoint("TOPLEFT")
			sep:SetPoint("TOPRIGHT")
		end
		rows[i] = row
		return row
	end

	function page:Refresh()
		local list = {}
		for key, o in pairs(Core.db.overrides) do
			list[#list + 1] = { key = key, o = o, sort = Core.NameKey(o.first, o.last) or key }
		end
		table.sort(list, function(a, b) return a.sort < b.sort end)
		for i, item in ipairs(list) do
			local row = getRow(i)
			local o = item.o
			row.name:SetText(o.last and (o.first .. " " .. o.last) or (o.first or "?"))
			row.detail:SetText(describeOverride(o))
			row.edit:SetScript("OnClick", function()
				ns.OverridePopup:Open({ guid = item.key:sub(1, 2) ~= "N:" and item.key or nil, first = o.first, last = o.last })
			end)
			row.delete:SetScript("OnClick", function()
				Core:DeleteOverrideByKey(item.key)
				page:Refresh()
			end)
			row:Show()
		end
		for i = #list + 1, #rows do rows[i]:Hide() end
		child:SetHeight(math.max(10, #list * ROW_H))
		empty:SetShown(#list == 0)
	end
	return page
end

-- ---------------------------------------------------------------------------
-- About page
-- ---------------------------------------------------------------------------

local COMMANDS = {
	{ "/nf", "Open or close this window" },
	{ "/nf on   /nf off", "Turn custom names on or off" },
	{ "/nf primary <format>", "Set the global primary format" },
	{ "/nf secondary <format | off>", "Set or turn off the global secondary format" },
	{ "/nf target", "Set an override for your current target" },
	{ "/nf minimap", "Show or hide the minimap button" },
}

local function buildAboutPage(parent)
	local page = CreateFrame("Frame", nil, parent)
	page:SetAllPoints()
	local group = W.Group(page, "Slash Commands", CONTENT_INNER_W)
	group:SetPoint("TOPLEFT", 0, 0)
	for _, c in ipairs(COMMANDS) do
		local row = group:AddRow(c[1], c[2])
		Theme.TextColor(row.label, C.gold)
	end
	local ver = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	ver:SetPoint("TOPLEFT", group, "BOTTOMLEFT", 12, -14)
	Theme.TextColor(ver, C.muted)
	ver:SetText("NameForge " .. Core.version .. ". Tokens: {f} first  {l} last  {g} guild  {c} class  {r} race  {v} level  {n} nickname")
	function page:Refresh() end
	return page
end

-- ---------------------------------------------------------------------------
-- Window
-- ---------------------------------------------------------------------------

local CATEGORIES = {
	{ id = "names", label = "Names", title = "Names", build = buildNamesPage },
	{ id = "display", label = "Display", title = "Display", build = buildDisplayPage },
	{ id = "overrides", label = "Overrides", title = "Overrides", build = buildOverridesPage },
	{ id = "about", label = "About & Help", title = "About & Help", build = buildAboutPage },
}

StaticPopupDialogs["NAMEFORGE_RESET"] = {
	text = "Reset NameForge's global settings? Your character overrides are kept.",
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		Core:ResetGlobal()
		Options:Refresh()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

local function select_(id)
	current = id
	for _, cat in ipairs(CATEGORIES) do
		local b = catButtons[cat.id]
		b:SetSelected(cat.id == id)
		pages[cat.id]:SetShown(cat.id == id)
		if cat.id == id then
			frame.contentTitle:SetText(cat.title)
			pages[cat.id]:Refresh()
		end
	end
end

local function build()
	frame = CreateFrame("Frame", "NameForgeOptionsFrame", UIParent, "BackdropTemplate")
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	Theme.Backdrop(frame, C.window, C.border, 0.97)
	frame:Hide()
	tinsert(UISpecialFrames, "NameForgeOptionsFrame")

	-- Title bar (drag to move)
	local titleBar = CreateFrame("Frame", nil, frame)
	titleBar:SetPoint("TOPLEFT")
	titleBar:SetPoint("TOPRIGHT")
	titleBar:SetHeight(64)
	titleBar:EnableMouse(true)
	titleBar:RegisterForDrag("LeftButton")
	titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
	titleBar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
	local titleSep = Theme.Separator(titleBar)
	titleSep:SetPoint("BOTTOMLEFT")
	titleSep:SetPoint("BOTTOMRIGHT")

	local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	title:SetPoint("LEFT", 78, 0)
	title:SetText("NameForge  |cff8a6d2b·|r  Options")
	Theme.TextColor(title, C.gold)

	-- Emblem in the top-left corner
	local emblem = CreateFrame("Frame", nil, frame)
	emblem:SetSize(64, 64)
	emblem:SetPoint("TOPLEFT", -12, 12)
	emblem:SetFrameLevel(frame:GetFrameLevel() + 10)
	local ring = emblem:CreateTexture(nil, "BACKGROUND")
	ring:SetAllPoints()
	ring:SetColorTexture(C.borderInput[1], C.borderInput[2], C.borderInput[3], 1)
	local ringMask = emblem:CreateMaskTexture()
	ringMask:SetTexture([[Interface\CharacterFrame\TempPortraitAlphaMask]], "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	ringMask:SetAllPoints(ring)
	ring:AddMaskTexture(ringMask)
	local icon = emblem:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", 4, -4)
	icon:SetPoint("BOTTOMRIGHT", -4, 4)
	icon:SetTexture(Theme.ICON)
	local iconMask = emblem:CreateMaskTexture()
	iconMask:SetTexture([[Interface\CharacterFrame\TempPortraitAlphaMask]], "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	iconMask:SetAllPoints(icon)
	icon:AddMaskTexture(iconMask)

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -8, -16)

	-- Sidebar
	local sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	sidebar:SetPoint("TOPLEFT", 14, -76)
	sidebar:SetPoint("BOTTOMLEFT", 14, 14)
	sidebar:SetWidth(SIDEBAR_W)
	Theme.Backdrop(sidebar, C.panel, C.borderDim)
	local catTitle = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	catTitle:SetPoint("TOPLEFT", 12, -14)
	catTitle:SetText("Category")

	for i, cat in ipairs(CATEGORIES) do
		local b = W.Button(sidebar, cat.label, SIDEBAR_W - 20, 38, function() select_(cat.id) end)
		b.label:ClearAllPoints()
		b.label:SetPoint("LEFT", 12, 0)
		b:SetPoint("TOPLEFT", 10, -40 - (i - 1) * 44)
		catButtons[cat.id] = b
	end

	-- Content panel
	local content = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 12, 0)
	content:SetPoint("BOTTOMRIGHT", -14, 14)
	Theme.Backdrop(content, C.panel, C.borderDim)

	frame.contentTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	frame.contentTitle:SetPoint("TOPLEFT", 14, -16)

	local reset = W.Button(content, "Reset Settings", 140, 30, function()
		StaticPopup_Show("NAMEFORGE_RESET")
	end)
	reset:SetPoint("TOPRIGHT", -14, -10)

	local body = CreateFrame("Frame", nil, content)
	body:SetPoint("TOPLEFT", 14, -50)
	body:SetPoint("BOTTOMRIGHT", -14, 14)

	for _, cat in ipairs(CATEGORIES) do
		pages[cat.id] = cat.build(body)
		pages[cat.id]:Hide()
	end

	frame:SetScript("OnShow", function() select_(current) end)
end

function Options:Toggle()
	if not frame then build() end
	frame:SetShown(not frame:IsShown())
end

function Options:Open(category)
	if not frame then build() end
	if category then current = category end
	frame:Show()
	select_(current)
end

function Options:Refresh()
	if frame and frame:IsShown() then select_(current) end
end

function Options:RefreshOverrides()
	if frame and frame:IsShown() and current == "overrides" then pages.overrides:Refresh() end
end
