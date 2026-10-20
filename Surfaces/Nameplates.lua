-- NameForge nameplates.
--
-- Verified against the Forever UI source (Blizzard_UnitFrame/Shared/CompactUnitFrame.lua and
-- Blizzard_NamePlates/Blizzard_NamePlateUnitFrame.lua): Blizzard nameplates set their name with
-- CompactUnitFrame_UpdateName(frame), which writes frame.name:SetText(...). We post-hook that
-- function, so Blizzard runs first and we replace the text afterwards. We never assign fields
-- on Blizzard frames and never touch forbidden nameplates (friendly plates inside instances).

local _, ns = ...
local Core = ns.Core

local Nameplates = {}
ns.Nameplates = Nameplates

-- frame -> secondary FontString, kept in our own weak table instead of on Blizzard frames.
local secondaryByFrame = setmetatable({}, { __mode = "k" })
local castHooked = setmetatable({}, { __mode = "k" })

local function isNameplateFrame(frame)
	local unit = frame and frame.unit
	return type(unit) == "string" and unit:find("^nameplate") ~= nil
end

local function hideSecondary(frame)
	local fs = secondaryByFrame[frame]
	if fs then fs:Hide() end
end

local function getSecondary(frame)
	local fs = secondaryByFrame[frame]
	if not fs then
		fs = frame:CreateFontString(nil, "OVERLAY", "SystemFont_NamePlate")
		fs:SetJustifyH("CENTER")
		fs:SetWordWrap(false)
		fs:SetTextColor(0.84, 0.82, 0.76)
		secondaryByFrame[frame] = fs
	end
	return fs
end

local function castBarShown(frame)
	local container = frame.CastBarsContainer
	local castBar = container and container.castBar
	return castBar and castBar:IsShown()
end

local function placeSecondary(frame, fs)
	fs:ClearAllPoints()
	local nameOnly = frame.IsShowOnlyName and frame:IsShowOnlyName()
	if nameOnly or not frame.HealthBarsContainer then
		fs:SetPoint("TOP", frame.name, "BOTTOM", 0, -1)
	else
		fs:SetPoint("TOP", frame.HealthBarsContainer, "BOTTOM", 0, -2)
	end
	local font, size, flags = frame.name:GetFont()
	if font and size and not Core.IsSecret(font, size) then
		fs:SetFont(font, math.max(6, size * 0.85), flags)
	end
end

function Nameplates.Apply(frame)
	if not frame or frame:IsForbidden() or not isNameplateFrame(frame) then return end
	if not frame.name or not frame.name:IsShown() or not Core:IsSurfaceEnabled("nameplate") then
		hideSecondary(frame)
		return
	end

	local display = Core:GetDisplay(frame.unit)
	if not display then
		hideSecondary(frame)
		return
	end

	frame.name:SetText(display.primary)
	if display.r then
		frame.name:SetVertexColor(display.r, display.g, display.b)
	end

	if display.secondary and not castBarShown(frame) then
		local fs = getSecondary(frame)
		placeSecondary(frame, fs)
		fs:SetText(display.secondary)
		fs:Show()
	else
		hideSecondary(frame)
	end

	-- Hide the secondary line while a cast bar occupies the space below the health bar.
	local castBar = frame.CastBarsContainer and frame.CastBarsContainer.castBar
	if castBar and not castHooked[castBar] then
		castHooked[castBar] = true
		castBar:HookScript("OnShow", function() hideSecondary(frame) end)
		castBar:HookScript("OnHide", function() Nameplates.Apply(frame) end)
	end
end

function Nameplates.RefreshAll()
	for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
		local frame = plate.UnitFrame
		if frame and not frame:IsForbidden() then
			if Core:IsSurfaceEnabled("nameplate") then
				Nameplates.Apply(frame)
			else
				-- Let Blizzard repaint its own name; our hook then sees the surface is off.
				hideSecondary(frame)
				CompactUnitFrame_UpdateName(frame)
			end
		end
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
events:SetScript("OnEvent", function(_, _, unit)
	local plate = C_NamePlate.GetNamePlateForUnit(unit)
	local frame = plate and plate.UnitFrame
	if frame and not frame:IsForbidden() then hideSecondary(frame) end
end)

Core:OnInit(function()
	hooksecurefunc("CompactUnitFrame_UpdateName", Nameplates.Apply)
	Core:RegisterRefresh(Nameplates.RefreshAll)
end)
