-- NameForge raid and party frames (primary name only; these frames are too small for two lines).
--
-- Verified against the Forever UI source:
--  * Raid-style frames (Blizzard_CompactRaidFrames, also used for party when "raid-style party
--    frames" is on) set their name in CompactUnitFrame_UpdateName(frame), the same function the
--    nameplates use (Blizzard_UnitFrame/Shared/CompactUnitFrame.lua). frame.unit is raidN, partyN
--    or player.
--  * Forever's classic party frames (Blizzard_UnitFrame/Camelot/PartyMemberFrame.lua) call
--    UnitFrame_Initialize with self.Name, so UnitFrame_Update(self) sets their name, with
--    self.unit = partyN.
-- Both are post-hooked. FontString:SetText is not a protected call, so this also works in combat.

local _, ns = ...
local Core = ns.Core

local GroupFrames = {}
ns.GroupFrames = GroupFrames

-- Frames we have touched, so a refresh can repaint them without walking Blizzard's containers.
local compactSeen = setmetatable({}, { __mode = "k" })
local partySeen = setmetatable({}, { __mode = "k" })

local function isGroupUnit(unit)
	return type(unit) == "string"
		and (unit:find("^raid%d") ~= nil or unit:find("^party%d") ~= nil or unit == "player")
end

local function applyText(fontString, unit, isCompact)
	local display = Core:GetDisplay(unit)
	if not display then return end
	fontString:SetText(display.primary)
	if display.r then
		if isCompact then
			fontString:SetVertexColor(display.r, display.g, display.b)
		else
			fontString:SetTextColor(display.r, display.g, display.b)
		end
	end
end

-- Hook target for CompactUnitFrame_UpdateName (nameplates are handled in Nameplates.lua).
function GroupFrames.ApplyCompact(frame)
	if not frame or frame:IsForbidden() then return end
	local unit = frame.unit
	if not isGroupUnit(unit) or not frame.name then return end
	compactSeen[frame] = true
	if not frame.name:IsShown() or not Core:IsSurfaceEnabled("group") then return end
	applyText(frame.name, unit, true)
end

-- Hook target for UnitFrame_Update (target and focus are handled in UnitFrames.lua).
function GroupFrames.ApplyParty(frame)
	if not frame or not frame.name then return end
	local unit = frame.unit
	if type(unit) ~= "string" or not unit:find("^party%d") then return end
	partySeen[frame] = true
	if not Core:IsSurfaceEnabled("group") then return end
	applyText(frame.name, unit, false)
end

function GroupFrames.RefreshAll()
	local enabled = Core:IsSurfaceEnabled("group")
	for frame in pairs(compactSeen) do
		if not frame:IsForbidden() and isGroupUnit(frame.unit) and UnitExists(frame.unit) then
			if enabled then
				GroupFrames.ApplyCompact(frame)
			else
				-- Let Blizzard repaint its own name; our hook then sees the surface is off.
				CompactUnitFrame_UpdateName(frame)
			end
		end
	end
	for frame in pairs(partySeen) do
		if frame.unit and UnitExists(frame.unit) then
			if enabled then
				GroupFrames.ApplyParty(frame)
			else
				frame.name:SetText(GetUnitName(frame.unit, true))
			end
		end
	end
end

Core:OnInit(function()
	hooksecurefunc("CompactUnitFrame_UpdateName", GroupFrames.ApplyCompact)
	hooksecurefunc("UnitFrame_Update", GroupFrames.ApplyParty)
	Core:RegisterRefresh(GroupFrames.RefreshAll)
end)
