-- NameForge theme: colors and backdrop helpers matching the approved mockups
-- (warm dark panels, thin gold borders, gold headings).

local _, ns = ...

local Theme = {}
ns.Theme = Theme

local function rgb(hex)
	return {
		tonumber(hex:sub(1, 2), 16) / 255,
		tonumber(hex:sub(3, 4), 16) / 255,
		tonumber(hex:sub(5, 6), 16) / 255,
	}
end

Theme.color = {
	window = rgb("17130e"),
	panel = rgb("1d1812"),
	input = rgb("0f0c09"),
	button = rgb("1a1510"),
	buttonActive = rgb("2a2112"),
	border = rgb("8a6d2b"),
	borderDim = rgb("6b5526"),
	borderInput = rgb("a08a5c"),
	separator = rgb("2e2618"),
	gold = rgb("f2c230"),
	text = rgb("e6e1d6"),
	muted = rgb("8e877a"),
	danger = rgb("e6a29a"),
	dangerBorder = rgb("7a3a30"),
	error = rgb("ff6b5e"),
	preview = rgb("12100c"),
	health = rgb("3fa34d"),
}

Theme.ICON = [[Interface\Icons\INV_Misc_Note_01]]
local WHITE = [[Interface\Buttons\WHITE8X8]]

-- Apply a 1px border backdrop. Frame must inherit BackdropTemplate.
function Theme.Backdrop(frame, bg, border, alpha)
	frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
	bg = bg or Theme.color.panel
	border = border or Theme.color.borderDim
	frame:SetBackdropColor(bg[1], bg[2], bg[3], alpha or 1)
	frame:SetBackdropBorderColor(border[1], border[2], border[3], 1)
end

function Theme.SetBorder(frame, border)
	frame:SetBackdropBorderColor(border[1], border[2], border[3], 1)
end

function Theme.SetBg(frame, bg)
	frame:SetBackdropColor(bg[1], bg[2], bg[3], 1)
end

function Theme.TextColor(fs, c)
	fs:SetTextColor(c[1], c[2], c[3])
end

function Theme.Separator(parent)
	local t = parent:CreateTexture(nil, "ARTWORK")
	t:SetColorTexture(Theme.color.separator[1], Theme.color.separator[2], Theme.color.separator[3], 1)
	t:SetHeight(1)
	return t
end
