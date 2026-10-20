-- NameForge entry points for per-character overrides:
--  * a button in the Inspect window's title bar, next to the close button
--  * "Set Display Name" in player right-click menus
--
-- Verified against the Forever UI source:
--  * Blizzard_InspectUI is load-on-demand; InspectFrame inherits ButtonFrameTemplate, which
--    provides InspectFrame.CloseButton, and InspectFrame.unit holds the inspected unit token.
--  * Unit menus are tagged "MENU_UNIT_" .. which (Blizzard_UnitPopupShared/UnitPopupShared.lua),
--    and contextData carries unit, name and surname.

local _, ns = ...
local Core, Theme = ns.Core, ns.Theme
local C = Theme.color

local function openForUnit(unit)
	if unit and UnitExists(unit) and UnitIsPlayer(unit) then
		ns.OverridePopup:Open({ unit = unit })
		return true
	end
	return false
end

-- ---------------------------------------------------------------------------
-- Inspect window button
-- ---------------------------------------------------------------------------

local function createInspectButton()
	if not InspectFrame or not InspectFrame.CloseButton then return end
	local b = CreateFrame("Button", "NameForgeInspectButton", InspectFrame, "BackdropTemplate")
	b:SetSize(22, 22)
	b:SetPoint("RIGHT", InspectFrame.CloseButton, "LEFT", -2, 0)
	b:SetFrameLevel(InspectFrame.CloseButton:GetFrameLevel())
	Theme.Backdrop(b, C.button, C.borderInput)
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", 2, -2)
	icon:SetPoint("BOTTOMRIGHT", -2, 2)
	icon:SetTexture(Theme.ICON)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b:SetScript("OnClick", function()
		if not openForUnit(InspectFrame.unit) then
			Core.Print("Inspect a player first.")
		end
	end)
	b:SetScript("OnEnter", function(self)
		Theme.SetBorder(self, C.gold)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:SetText("NameForge", C.gold[1], C.gold[2], C.gold[3])
		GameTooltip:AddLine("Set how this character's name appears to you.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function(self)
		Theme.SetBorder(self, C.borderInput)
		GameTooltip:Hide()
	end)
end

EventUtil.ContinueOnAddOnLoaded("Blizzard_InspectUI", createInspectButton)

-- ---------------------------------------------------------------------------
-- Right-click unit menus
-- ---------------------------------------------------------------------------

local MENU_TAGS = {
	"MENU_UNIT_PLAYER",
	"MENU_UNIT_TARGET",
	"MENU_UNIT_FOCUS",
	"MENU_UNIT_PARTY",
	"MENU_UNIT_RAID_PLAYER",
	"MENU_UNIT_FRIEND",
}

local function addMenuEntry(_, rootDescription, contextData)
	if not contextData then return end
	local unit = contextData.unit
	if unit and (Core.IsSecret(unit) or not UnitIsPlayer(unit)) then return end
	local first, last = contextData.name, contextData.surname
	if not unit and (not first or Core.IsSecret(first, last)) then return end
	if first and not last then
		-- Chat and roster menus can pass "First Surname" as one string.
		first, last = ns.Data.SplitFullName(first)
	end

	rootDescription:CreateDivider()
	rootDescription:CreateButton("Set Display Name", function()
		if not openForUnit(unit) and first then
			ns.OverridePopup:Open({ first = first, last = last })
		end
	end)
end

Core:OnInit(function()
	for _, tag in ipairs(MENU_TAGS) do
		Menu.ModifyMenu(tag, addMenuEntry)
	end
end)
