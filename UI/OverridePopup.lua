-- NameForge per-character override popup.
-- Opened from the Inspect window button, the unit right-click menu, /nf target,
-- or the Edit button on the Overrides page.

local _, ns = ...
local Core, Format, Data, Theme, W = ns.Core, ns.Format, ns.Data, ns.Theme, ns.Widgets
local C = Theme.color

local Popup = {}
ns.OverridePopup = Popup

local WIDTH = 460
local INNER_W = WIDTH - 28

local frame
local state = {}   -- { guid, first, last, data, secondaryMode = "global"|"on"|"off" }
local fields = {}

local function modeToValue(mode)
	if mode == "on" then return true elseif mode == "off" then return false end
	return nil
end

local function valueToMode(v)
	if v == true then return "on" elseif v == false then return "off" end
	return "global"
end

local function currentOverride()
	return {
		nickname = fields.nick:GetText(),
		primary = fields.primary:GetText() ~= "" and fields.primary:GetText() or nil,
		secondary = fields.secondary:GetText() ~= "" and fields.secondary:GetText() or nil,
		secondaryEnabled = modeToValue(state.secondaryMode),
	}
end

local function formatsValid()
	local ok = true
	for _, key in ipairs({ "primary", "secondary" }) do
		local text = fields[key]:GetText()
		local row = fields[key .. "Row"]
		local nodes, err = true, nil
		if text ~= "" then nodes, err = Format.Compile(text) end
		if nodes then
			row.desc:SetText("Blank uses global")
			Theme.TextColor(row.desc, C.muted)
		else
			row.desc:SetText(err)
			Theme.TextColor(row.desc, C.error)
			ok = false
		end
	end
	return ok
end

local function refreshPreview()
	formatsValid()
	local data = {}
	local saved = Core:FindOverride(state.guid, state.first, state.last)
	local base = state.data or (saved and Core.OverrideData(saved)) or { f = state.first, l = state.last }
	for k, v in pairs(base) do data[k] = v end
	local o = currentOverride()
	data.n = (o.nickname ~= "" and o.nickname) or nil
	local display = Core:BuildDisplay(data, o)
	frame.preview:SetDisplay(display, state.first)
	for mode, b in pairs(fields.modeButtons) do b:SetSelected(mode == state.secondaryMode) end
	fields.secondary:SetEnabledState(state.secondaryMode ~= "off")
end

local function build()
	frame = CreateFrame("Frame", "NameForgeOverridePopup", UIParent, "BackdropTemplate")
	frame:SetSize(WIDTH, 470)
	frame:SetPoint("CENTER", 120, 40)
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	Theme.Backdrop(frame, C.window, C.border, 0.98)
	frame:Hide()
	tinsert(UISpecialFrames, "NameForgeOverridePopup")

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 18, -14)
	title:SetText("Display Name")

	frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	Theme.TextColor(frame.subtitle, C.muted)

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -6, -8)

	local sep = Theme.Separator(frame)
	sep:SetPoint("TOPLEFT", 0, -56)
	sep:SetPoint("TOPRIGHT", 0, -56)

	local group = W.Group(frame, "Override", INNER_W)
	group:SetPoint("TOPLEFT", 14, -68)

	fields.nick = W.EditBox(group.box, 200, refreshPreview)
	group:AddRow("Nickname", "Available as {n}", fields.nick)

	fields.primary = W.EditBox(group.box, 200, refreshPreview, true)
	fields.primaryRow = group:AddRow("Primary format", "Blank uses global", fields.primary)

	local modeBar = CreateFrame("Frame", nil, group.box)
	modeBar:SetSize(200, 28)
	fields.modeButtons = {}
	local modes = { { "global", "Global" }, { "on", "On" }, { "off", "Off" } }
	for i, m in ipairs(modes) do
		local b = W.Button(modeBar, m[2], 64, 28, function()
			state.secondaryMode = m[1]
			refreshPreview()
		end)
		b:SetPoint("LEFT", (i - 1) * 68, 0)
		fields.modeButtons[m[1]] = b
	end
	group:AddRow("Secondary name", "Follow global, or force on or off", modeBar)

	fields.secondary = W.EditBox(group.box, 200, refreshPreview, true)
	fields.secondaryRow = group:AddRow("Secondary format", "Blank uses global", fields.secondary)

	local pvTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	pvTitle:SetPoint("TOPLEFT", group, "BOTTOMLEFT", 12, -12)
	pvTitle:SetText("Preview")
	frame.preview = W.Preview(frame, INNER_W)
	frame.preview:SetPoint("TOPLEFT", group, "BOTTOMLEFT", 0, -30)
	frame.preview:SetHeight(78)

	local save = W.Button(frame, "Save", 90, 30, function() Popup:Save() end, "primary")
	save:SetPoint("BOTTOMRIGHT", -14, 14)
	local cancel = W.Button(frame, "Cancel", 90, 30, function() frame:Hide() end)
	cancel:SetPoint("RIGHT", save, "LEFT", -8, 0)
	local clear = W.Button(frame, "Clear Override", 130, 30, function()
		Core:ClearOverride(state.guid, state.first, state.last)
		frame:Hide()
		if ns.Options then ns.Options:RefreshOverrides() end
	end, "danger")
	clear:SetPoint("BOTTOMLEFT", 14, 14)
	frame.clear = clear
end

-- target: { unit = token } or { guid, first, last }
function Popup:Open(target)
	if not frame then build() end
	wipe(state)

	if target.unit then
		local data = Data.FromUnit(target.unit)
		if not data then
			Core.Print("That character's name isn't available right now.")
			return
		end
		if data.nameSecret then
			Core.Print("Names are hidden during PvP matches, so overrides can't be set here. Overrides you already have still apply.")
			return
		end
		state.data = data
		state.guid, state.first, state.last = data.guid, data.f, data.l
	else
		state.guid, state.first, state.last = target.guid, target.first, target.last
		if not state.first then return end
	end

	local o = Core:FindOverride(state.guid, state.first, state.last) or {}
	fields.nick:SetText(o.nickname or "")
	fields.primary:SetText(o.primary or "")
	fields.secondary:SetText(o.secondary or "")
	fields.primary:SetPlaceholder(Core.db.global.primary)
	fields.secondary:SetPlaceholder(Core.db.global.secondary)
	state.secondaryMode = valueToMode(o.secondaryEnabled)

	local full = state.last and (state.first .. " " .. state.last) or state.first
	local d = state.data or (o.seen and Core.OverrideData(o))
	if d and d.v then
		local guild = d.g and (" <" .. d.g .. ">") or ""
		frame.subtitle:SetText(("%s%s, Level %s %s %s"):format(full, guild, d.v, d.r or "", d.c or ""))
	else
		frame.subtitle:SetText(full)
	end
	frame.clear:SetEnabled(Core:FindOverride(state.guid, state.first, state.last) ~= nil)

	frame:Show()
	refreshPreview()
end

function Popup:Save()
	if not formatsValid() then return end
	local o = currentOverride()
	o.first, o.last = state.first, state.last
	o.data = state.data
	Core:SetOverride(state.guid, o)
	frame:Hide()
	if ns.Options then ns.Options:RefreshOverrides() end
end
