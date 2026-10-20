-- NameForge minimap button and addon compartment entry.
-- Built without external libraries: a round button that can be dragged around the minimap.
-- The addon compartment hooks are declared in the TOC (AddonCompartmentFunc*), which the
-- Forever client reads in Blizzard_Minimap/Mainline/AddonCompartment.lua.

local _, ns = ...
local Core, Theme = ns.Core, ns.Theme
local C = Theme.color

local MinimapButton = {}
ns.MinimapButton = MinimapButton

local button
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local function showTooltip(owner)
	GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
	GameTooltip:SetText("NameForge", C.gold[1], C.gold[2], C.gold[3])
	if Core.db.enabled then
		GameTooltip:AddLine("Enabled", 0.56, 0.82, 0.56)
	else
		GameTooltip:AddLine("Disabled", 0.9, 0.5, 0.45)
	end
	GameTooltip:AddDoubleLine("Primary:", Core.db.global.primary, 0.79, 0.76, 0.71, 1, 1, 1)
	local sec = Core.db.global.secondaryEnabled and Core.db.global.secondary or "off"
	GameTooltip:AddDoubleLine("Secondary:", sec, 0.79, 0.76, 0.71, 1, 1, 1)
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Left-click: open settings", 0.64, 0.61, 0.56)
	GameTooltip:AddLine("Right-click: turn on or off", 0.64, 0.61, 0.56)
	GameTooltip:AddLine("Drag: move around the minimap", 0.64, 0.61, 0.56)
	GameTooltip:Show()
end

local function onClick(mouseButton)
	if mouseButton == "RightButton" then
		Core:SetEnabled(not Core.db.enabled)
		Core.Print(Core.db.enabled and "custom names on." or "custom names off.")
	else
		ns.Options:Toggle()
	end
end

local function updatePosition()
	local angle = math.rad(Core.db.minimap.angle or 220)
	local radius = (Minimap:GetWidth() / 2) + 5
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function onDragUpdate()
	local mx, my = Minimap:GetCenter()
	local scale = Minimap:GetEffectiveScale()
	local cx, cy = GetCursorPosition()
	cx, cy = cx / scale, cy / scale
	Core.db.minimap.angle = math.deg(atan2(cy - my, cx - mx)) % 360
	updatePosition()
end

local function build()
	button = CreateFrame("Button", "NameForgeMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture([[Interface\Minimap\UI-Minimap-ZoomButton-Highlight]])

	local bg = button:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture([[Interface\Minimap\UI-Minimap-Background]])
	bg:SetSize(20, 20)
	bg:SetPoint("TOPLEFT", 7, -5)

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(Theme.ICON)
	icon:SetSize(17, 17)
	icon:SetPoint("TOPLEFT", 7, -6)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local mask = button:CreateMaskTexture()
	mask:SetTexture([[Interface\CharacterFrame\TempPortraitAlphaMask]], "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(icon)
	icon:AddMaskTexture(mask)

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetTexture([[Interface\Minimap\MiniMap-TrackingBorder]])
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")

	button:SetScript("OnClick", function(_, mb) onClick(mb) end)
	button:SetScript("OnEnter", showTooltip)
	button:SetScript("OnLeave", GameTooltip_Hide)
	button:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", onDragUpdate)
	end)
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)
	updatePosition()
end

function MinimapButton:UpdateVisibility()
	if not button then build() end
	button:SetShown(not Core.db.minimap.hide)
end

function MinimapButton:Toggle()
	Core.db.minimap.hide = not Core.db.minimap.hide
	self:UpdateVisibility()
end

Core:OnInit(function()
	MinimapButton:UpdateVisibility()
end)

-- Addon compartment (globals named in the TOC)
function NameForge_OnAddonCompartmentClick(_, mouseButton)
	onClick(mouseButton)
end

function NameForge_OnAddonCompartmentEnter(_, menuButtonFrame)
	showTooltip(menuButtonFrame)
end

function NameForge_OnAddonCompartmentLeave()
	GameTooltip:Hide()
end
