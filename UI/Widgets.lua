-- NameForge widgets: buttons, checkboxes, edit boxes, option groups and name previews.

local _, ns = ...
local Theme = ns.Theme
local C = Theme.color

local W = {}
ns.Widgets = W

-- ---------------------------------------------------------------------------
-- Button. style: "default" | "primary" | "danger"
-- ---------------------------------------------------------------------------
function W.Button(parent, text, width, height, onClick, style)
	local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
	b:SetSize(width or 100, height or 30)
	b.style = style or "default"
	b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	b.label:SetPoint("CENTER")
	b.label:SetText(text)

	function b:Refresh()
		local active = self.selected or self.style == "primary"
		local border = (self.style == "danger" and C.dangerBorder) or (active and C.gold) or C.borderInput
		Theme.Backdrop(self, active and C.buttonActive or C.button, border)
		local tc = (self.style == "danger" and C.danger) or (active and C.gold) or C.text
		Theme.TextColor(self.label, tc)
		self:SetAlpha(self:IsEnabled() and 1 or 0.45)
	end
	function b:SetSelected(v) self.selected = v; self:Refresh() end

	b:SetScript("OnEnter", function(self)
		if self:IsEnabled() and not self.selected then Theme.SetBorder(self, C.gold) end
		if self.tooltip then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(self.tooltip, 1, 1, 1)
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function(self)
		self:Refresh()
		if self.tooltip then GameTooltip:Hide() end
	end)
	b:SetScript("OnEnable", b.Refresh)
	b:SetScript("OnDisable", b.Refresh)
	if onClick then b:SetScript("OnClick", onClick) end
	b:Refresh()
	return b
end

-- ---------------------------------------------------------------------------
-- Checkbox (square, gold-edged, light check mark)
-- ---------------------------------------------------------------------------
function W.Checkbox(parent, onChange)
	local cb = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
	cb:SetSize(22, 22)
	Theme.Backdrop(cb, C.input, C.borderInput)
	local check = cb:CreateTexture(nil, "OVERLAY")
	check:SetTexture([[Interface\Buttons\UI-CheckBox-Check]])
	check:SetPoint("TOPLEFT", -4, 4)
	check:SetPoint("BOTTOMRIGHT", 4, -4)
	check:SetDesaturated(true)
	check:SetVertexColor(C.text[1], C.text[2], C.text[3])
	cb:SetCheckedTexture(check)
	cb:SetScript("OnClick", function(self)
		if onChange then onChange(self:GetChecked()) end
	end)
	cb:SetScript("OnEnter", function(self) Theme.SetBorder(self, C.gold) end)
	cb:SetScript("OnLeave", function(self) Theme.SetBorder(self, C.borderInput) end)
	return cb
end

-- ---------------------------------------------------------------------------
-- Edit box. onChange(text) fires for user edits only.
-- ---------------------------------------------------------------------------
W.lastFocusedEdit = nil

function W.EditBox(parent, width, onChange, mono)
	local eb = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
	eb:SetSize(width or 240, 30)
	eb:SetAutoFocus(false)
	eb:SetFontObject(mono and "NumberFontNormal" or "ChatFontNormal")
	eb:SetTextInsets(8, 8, 0, 0)
	eb:SetMaxLetters(ns.Format.MAX_FORMAT_LENGTH)
	Theme.Backdrop(eb, C.input, C.borderInput)
	eb:SetScript("OnEscapePressed", eb.ClearFocus)
	eb:SetScript("OnEnterPressed", eb.ClearFocus)
	eb:SetScript("OnEditFocusGained", function(self)
		W.lastFocusedEdit = self
		Theme.SetBorder(self, C.gold)
	end)
	eb:SetScript("OnEditFocusLost", function(self) Theme.SetBorder(self, C.borderInput) end)
	eb:SetScript("OnTextChanged", function(self, userInput)
		if userInput and onChange then onChange(self:GetText()) end
	end)

	-- Placeholder text shown while empty.
	eb.placeholder = eb:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	eb.placeholder:SetPoint("LEFT", 8, 0)
	eb:HookScript("OnTextChanged", function(self)
		self.placeholder:SetShown(self:GetText() == "")
	end)
	function eb:SetPlaceholder(t) self.placeholder:SetText(t or "") end

	function eb:SetEnabledState(enabled)
		self:SetEnabled(enabled)
		self:SetAlpha(enabled and 1 or 0.4)
		if not enabled then self:ClearFocus() end
	end
	return eb
end

-- Insert a token into the focused (or fallback) edit box at the cursor.
function W.InsertToken(fallback, token)
	local eb = W.lastFocusedEdit
	if not eb or not eb:IsVisible() or not eb:IsEnabled() then eb = fallback end
	if not eb then return end
	eb:SetFocus()
	eb:Insert(token)
	local handler = eb:GetScript("OnTextChanged")
	if handler then handler(eb, true) end
end

-- ---------------------------------------------------------------------------
-- Option group: a titled, bordered box of rows (label + description + control)
-- ---------------------------------------------------------------------------
local ROW_H = 54

function W.Group(parent, title, width)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetWidth(width)
	holder.title = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	holder.title:SetPoint("TOPLEFT", 12, 0)
	holder.title:SetText(title)

	local box = CreateFrame("Frame", nil, holder, "BackdropTemplate")
	box:SetPoint("TOPLEFT", 0, -18)
	box:SetPoint("TOPRIGHT", 0, -18)
	Theme.Backdrop(box, C.panel, C.borderDim)
	holder.box = box
	holder.rows = {}

	-- control: a frame already parented to holder.box; anchored on the right.
	function holder:AddRow(label, desc, control)
		local y = -(#self.rows * ROW_H)
		local row = CreateFrame("Frame", nil, self.box)
		row:SetPoint("TOPLEFT", 16, y)
		row:SetPoint("TOPRIGHT", -16, y)
		row:SetHeight(ROW_H)

		row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		row.label:SetPoint("TOPLEFT", 0, -11)
		row.label:SetJustifyH("LEFT")
		row.label:SetText(label)

		row.desc = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.desc:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -4)
		row.desc:SetJustifyH("LEFT")
		Theme.TextColor(row.desc, C.muted)
		row.desc:SetText(desc or "")

		if control then
			control:SetParent(row)
			control:ClearAllPoints()
			control:SetPoint("RIGHT", row, "RIGHT", 0, 0)
			row.label:SetPoint("RIGHT", control, "LEFT", -12, 0)
			row.desc:SetPoint("RIGHT", control, "LEFT", -12, 0)
			row.control = control
		end

		if #self.rows > 0 then
			local sep = Theme.Separator(row)
			sep:SetPoint("TOPLEFT", 0, 0)
			sep:SetPoint("TOPRIGHT", 0, 0)
		end

		self.rows[#self.rows + 1] = row
		local h = #self.rows * ROW_H
		self.box:SetHeight(h)
		self:SetHeight(h + 18)
		return row
	end
	return holder
end

-- ---------------------------------------------------------------------------
-- Name preview: a small nameplate mock with primary, secondary and a health bar
-- ---------------------------------------------------------------------------
function W.Preview(parent, width)
	local p = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	p:SetSize(width or 220, 92)
	Theme.Backdrop(p, C.preview, C.separator)

	p.primary = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	p.primary:SetPoint("TOP", 0, -14)
	p.primary:SetWidth((width or 220) - 16)
	p.primary:SetWordWrap(false)
	p.primary:SetShadowOffset(1, -1)

	p.secondary = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	p.secondary:SetPoint("TOP", p.primary, "BOTTOM", 0, -3)
	p.secondary:SetWidth((width or 220) - 16)
	p.secondary:SetWordWrap(false)
	p.secondary:SetTextColor(0.84, 0.82, 0.76)

	local bar = CreateFrame("Frame", nil, p, "BackdropTemplate")
	bar:SetSize(120, 8)
	bar:SetPoint("TOP", p.secondary, "BOTTOM", 0, -6)
	Theme.Backdrop(bar, { 0.04, 0.05, 0.06 }, { 0, 0, 0 })
	local fill = bar:CreateTexture(nil, "ARTWORK")
	fill:SetColorTexture(C.health[1], C.health[2], C.health[3], 1)
	fill:SetPoint("TOPLEFT", 1, -1)
	fill:SetPoint("BOTTOMLEFT", 1, 1)
	fill:SetWidth(96)

	p.caption = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	p.caption:SetPoint("BOTTOM", 0, 8)
	Theme.TextColor(p.caption, C.muted)

	-- display: result of Core:BuildDisplay (or nil); caption: small label.
	function p:SetDisplay(display, fallbackName, caption)
		if display then
			self.primary:SetText(display.primary)
			if display.r then
				self.primary:SetTextColor(display.r, display.g, display.b)
			else
				self.primary:SetTextColor(0.96, 0.94, 0.89)
			end
			self.secondary:SetText(display.secondary or "")
		else
			self.primary:SetText(fallbackName or "")
			self.primary:SetTextColor(0.96, 0.94, 0.89)
			self.secondary:SetText("")
		end
		self.caption:SetText(caption or "")
	end
	return p
end

-- Error line used under format edit boxes.
function W.ErrorText(parent)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	Theme.TextColor(fs, C.error)
	fs:SetJustifyH("RIGHT")
	return fs
end
