-- EllesmereUI's name tags call this resolver for player, target, focus and
-- other frames in its Unit Frames module. Keep its text layout and coloring.
local _, ns = ...
local Core = ns.Core
local moduleName = "EllesmereUIUnitFrames"
local module
local wasEnabled = false

local function refresh()
	if not module then return end
	local enabled = Core:IsSurfaceEnabled("ellesmereUI")
	if enabled or wasEnabled then
		module.RefreshAllUnitNames()
	end
	wasEnabled = enabled
end

local function attach()
	local modules = EllesmereUI and EllesmereUI._ModuleNS
	local unitFrames = modules and modules[moduleName]
	if module or not unitFrames or type(unitFrames.ResolveUnitNickname) ~= "function"
		or type(unitFrames.RefreshAllUnitNames) ~= "function" then return end

	local resolve = unitFrames.ResolveUnitNickname
	unitFrames.ResolveUnitNickname = function(unit)
		if Core:IsSurfaceEnabled("ellesmereUI") then
			local display = Core:GetDisplay(unit)
			if display then return display.primary end
		end
		return resolve(unit)
	end
	module = unitFrames
	Core:FireRefresh()
end

Core:OnInit(function()
	Core:RegisterRefresh(refresh)
	attach()
	if module then return end

	local loader = CreateFrame("Frame")
	loader:RegisterEvent("ADDON_LOADED")
	loader:SetScript("OnEvent", function(self, _, name)
		if name ~= moduleName then return end
		self:UnregisterEvent("ADDON_LOADED")
		attach()
	end)
end)
