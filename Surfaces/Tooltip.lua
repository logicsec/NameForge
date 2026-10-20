-- NameForge unit tooltip.
--
-- Verified against the Forever UI source (Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua and
-- TooltipUtil.lua): TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, fn) runs after
-- Blizzard fills a unit tooltip, and tooltip:GetUnit() returns name, unit, guid.
-- We replace line 1 and add the secondary name directly under it in the same line.

local _, ns = ...
local Core = ns.Core

local Tooltip = {}
ns.Tooltip = Tooltip

local SECONDARY_COLOR = "ffd6d0c2"

function Tooltip.OnUnitTooltip(tooltip)
	if tooltip ~= GameTooltip or not Core:IsSurfaceEnabled("tooltip") then return end
	local _, unit = tooltip:GetUnit()
	if not unit or Core.IsSecret(unit) then return end

	local display = Core:GetDisplay(unit)
	if not display then return end

	local line = tooltip.TextLeft1 or _G["GameTooltipTextLeft1"]
	if not line then return end

	local text = display.primary
	if display.hex then
		text = "|c" .. display.hex .. text .. "|r"
	end
	if display.secondary then
		text = text .. "\n|c" .. SECONDARY_COLOR .. display.secondary .. "|r"
	end
	line:SetText(text)
	tooltip:Show()
end

Core:OnInit(function()
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, Tooltip.OnUnitTooltip)
end)
