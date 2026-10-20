-- NameForge target and focus frames (primary name only).
--
-- Verified against the Forever UI source (Blizzard_UnitFrame/Mainline/UnitFrame.lua, loaded for
-- Forever via the [Family] TOC entry): UnitFrame_Update(self) sets self.name:SetText(...). We
-- post-hook it and only touch TargetFrame and FocusFrame.

local _, ns = ...
local Core = ns.Core

local UnitFrames = {}
ns.UnitFrames = UnitFrames

local function isOurFrame(frame)
	return frame and (frame == TargetFrame or frame == FocusFrame)
end

function UnitFrames.Apply(frame)
	if not isOurFrame(frame) or not frame.name or not frame.unit then return end
	if not Core:IsSurfaceEnabled("target") then return end
	local display = Core:GetDisplay(frame.unit)
	if not display then return end
	frame.name:SetText(display.primary)
	if display.r then
		frame.name:SetTextColor(display.r, display.g, display.b)
	end
end

function UnitFrames.RefreshAll()
	-- When disabled, ask Blizzard's frame to repaint its own name.
	for _, frame in ipairs({ TargetFrame, FocusFrame }) do
		if frame and frame.unit and UnitExists(frame.unit) then
			if Core:IsSurfaceEnabled("target") then
				UnitFrames.Apply(frame)
			elseif frame.name then
				frame.name:SetText(GetUnitName(frame.unit, true))
				frame.name:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
			end
		end
	end
end

Core:OnInit(function()
	hooksecurefunc("UnitFrame_Update", UnitFrames.Apply)
	Core:RegisterRefresh(UnitFrames.RefreshAll)
end)
