-- Smoke test: loads every addon file (in TOC order) against a small mock of the WoW API,
-- fires the load events, renders names for mock units and builds every window.
-- It catches runtime errors (nil access, bad calls) that a syntax check cannot.
-- Run from the repo root:  lua5.1 tests/smoke.lua

-- ---------------------------------------------------------------------------
-- Generic widget mock
-- ---------------------------------------------------------------------------
local Widget = {}
Widget.__index = function(self, k)
	local v = rawget(Widget, k)
	if v ~= nil then return v end
	-- Unknown widget methods (capitalized, like the real API) are no-ops so the test
	-- focuses on our own logic. Unknown fields stay nil, as on real frames.
	if type(k) == "string" and k:find("^%u") then return function() end end
	return nil
end

local function newWidget(kind, name, parent)
	local w = setmetatable({ _kind = kind, _shown = true, _scripts = {}, _text = "", _parent = parent }, Widget)
	if name then _G[name] = w end
	return w
end

function Widget:SetText(t) self._text = t end
function Widget:GetText() return self._text end
function Widget:Show() self._shown = true end
function Widget:Hide() self._shown = false end
function Widget:SetShown(v) self._shown = not not v end
function Widget:IsShown() return self._shown end
function Widget:IsVisible() return self._shown end
function Widget:IsEnabled() return self._enabled ~= false end
function Widget:SetEnabled(v) self._enabled = not not v end
function Widget:Enable() self._enabled = true end
function Widget:Disable() self._enabled = false end
function Widget:IsForbidden() return false end
function Widget:GetWidth() return 140 end
function Widget:GetHeight() return 30 end
function Widget:GetCenter() return 100, 100 end
function Widget:GetEffectiveScale() return 1 end
function Widget:GetFrameLevel() return 1 end
function Widget:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
function Widget:GetChecked() return self._checked end
function Widget:SetChecked(v) self._checked = v end
function Widget:SetScript(k, fn) self._scripts[k] = fn end
function Widget:GetScript(k) return self._scripts[k] end
function Widget:HookScript(k, fn) self._scripts[k] = fn end
function Widget:Insert(t) self._text = self._text .. t end
function Widget:CreateFontString(name) return newWidget("FontString", name, self) end
function Widget:CreateTexture(name) return newWidget("Texture", name, self) end
function Widget:CreateMaskTexture(name) return newWidget("MaskTexture", name, self) end
function Widget:RegisterEvent(e) local ev = rawget(self, "_events") or {}; rawset(self, "_events", ev); ev[e] = true end
function Widget:SetSelected(v) self.selected = v end

local allFrames = {}
function CreateFrame(kind, name, parent, template)
	local f = newWidget(kind, name, parent)
	allFrames[#allFrames + 1] = f
	return f
end

local function fire(event, ...)
	for _, f in ipairs(allFrames) do
		local ev = rawget(f, "_events")
		if ev and ev[event] and f._scripts.OnEvent then
			f._scripts.OnEvent(f, event, ...)
		end
	end
end

-- ---------------------------------------------------------------------------
-- API mocks
-- ---------------------------------------------------------------------------
UIParent = newWidget("Frame", "UIParent")
Minimap = newWidget("Frame", "Minimap")
GameTooltip = newWidget("GameTooltip", "GameTooltip")
GameTooltip.TextLeft1 = newWidget("FontString")
TargetFrame = newWidget("Button", "TargetFrame")
TargetFrame.name = newWidget("FontString")
TargetFrame.unit = "target"
FocusFrame = newWidget("Button", "FocusFrame")
UISpecialFrames = {}
StaticPopupDialogs = {}
SlashCmdList = {}
YES, NO = "Yes", "No"
NORMAL_FONT_COLOR = { GetRGB = function() return 1, 0.82, 0 end }
Enum = { TooltipDataType = { Unit = 2 } }

function wipe(t) for k in pairs(t) do t[k] = nil end return t end
tinsert = table.insert
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function time() return 1792500000 end
function geterrorhandler() return function(e) error(e, 2) end end
function issecretvalue() return false end
function GetCursorPosition() return 150, 150 end
function GameTooltip_Hide() end
function StaticPopup_Show() end

C_AddOns = { GetAddOnMetadata = function() return "0.1.0" end }
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function runTimers() local t = timers; timers = {}; for _, fn in ipairs(t) do fn() end end

C_ClassColor = { GetClassColor = function(classFile)
	return { GetRGB = function() return 0.25, 0.78, 0.92 end, GenerateHexColor = function() return "ff3fc7eb" end }
end }

local hooks = {}
function hooksecurefunc(name, fn) hooks[name] = fn end

local tooltipPostCalls = {}
TooltipDataProcessor = { AddTooltipPostCall = function(t, fn) tooltipPostCalls[#tooltipPostCalls + 1] = fn end }

local menuMods = {}
Menu = { ModifyMenu = function(tag, fn) menuMods[tag] = fn end }

EventUtil = { ContinueOnAddOnLoaded = function(name, fn) EventUtil._pending = fn end }

-- Units
local UNITS = {
	player = { "Nick", "Knight", "Player-1-AAA", "Aleya", "Warrior", "WARRIOR", "Human", 60 },
	target = { "Ad", "Astra", "Player-1-BBB", "Solstice", "Mage", "MAGE", "Gnome", 60 },
	nameplate1 = { "Orin", "Vale", "Player-1-CCC", nil, "Warrior", "WARRIOR", "Human", 42 },
	nameplate2 = { "Sela Thornwick", nil, "Player-1-DDD", nil, "Rogue", "ROGUE", "Night Elf", -1 },
}
local function u(unit) return UNITS[unit] end
function UnitIsPlayer(unit) return u(unit) ~= nil end
function UnitExists(unit) return u(unit) ~= nil end
function UnitName(unit) local d = u(unit); if d then return d[1], d[2] end end
function UnitGUID(unit) local d = u(unit); return d and d[3] end
function GetGuildInfo(unit) local d = u(unit); return d and d[4] end
function UnitClass(unit) local d = u(unit); if d then return d[5], d[6] end end
function UnitRace(unit) local d = u(unit); return d and d[7] end
function UnitLevel(unit) local d = u(unit); return d and d[8] end
function GetUnitName(unit) local d = u(unit); return d and d[1] end
function UnitIsUnit(a, b) return a == b end

local plates = {}
for _, unit in ipairs({ "nameplate1", "nameplate2" }) do
	local uf = newWidget("Button")
	uf.unit = unit
	uf.name = newWidget("FontString")
	uf.HealthBarsContainer = newWidget("Frame")
	uf.CastBarsContainer = newWidget("Frame")
	uf.CastBarsContainer.castBar = newWidget("StatusBar")
	uf.CastBarsContainer.castBar._shown = false
	plates[#plates + 1] = { UnitFrame = uf }
end
C_NamePlate = {
	GetNamePlates = function() return plates end,
	GetNamePlateForUnit = function(unit) for _, p in ipairs(plates) do if p.UnitFrame.unit == unit then return p end end end,
}
function CompactUnitFrame_UpdateName(frame) if hooks.CompactUnitFrame_UpdateName then hooks.CompactUnitFrame_UpdateName(frame) end end

-- ---------------------------------------------------------------------------
-- Load addon files in TOC order
-- ---------------------------------------------------------------------------
local ns = {}
local files = {}
for line in io.lines("NameForge.toc") do
	if line ~= "" and not line:find("^##") then files[#files + 1] = (line:gsub("\\", "/")) end
end
for _, file in ipairs(files) do
	local chunk = assert(loadfile(file))
	chunk("NameForge", ns)
end

local passed, failed = 0, 0
local function check(name, got, want)
	if got == want then passed = passed + 1 else
		failed = failed + 1
		print(("FAIL %s\n  got:  %s\n  want: %s"):format(name, tostring(got), tostring(want)))
	end
end

-- ---------------------------------------------------------------------------
-- Scenarios
-- ---------------------------------------------------------------------------
fire("ADDON_LOADED", "NameForge")
fire("PLAYER_LOGIN")
runTimers()
local Core = ns.Core
check("db created", type(NameForgeDB), "table")
check("hook installed", type(hooks.CompactUnitFrame_UpdateName), "function")
check("unit frame hook installed", type(hooks.UnitFrame_Update), "function")
check("tooltip post call registered", #tooltipPostCalls, 1)
check("menu modified", type(menuMods.MENU_UNIT_PLAYER), "function")

-- Default format on nameplates
for _, p in ipairs(plates) do CompactUnitFrame_UpdateName(p.UnitFrame) end
check("guildless default", plates[1].UnitFrame.name:GetText(), "Orin Vale")
check("combined name split", plates[2].UnitFrame.name:GetText(), "Sela Thornwick")

-- Spec example: primary + secondary
NameForgeDB.global.primary = "{f} {l} - {g}"
NameForgeDB.global.secondaryEnabled = true
NameForgeDB.global.secondary = "{c}"
Core:Invalidate()
runTimers()
local d = Core:GetDisplay("target")
check("spec primary", d and d.primary, "Ad Astra - Solstice")
check("spec secondary", d and d.secondary, "Mage")
check("level unknown", ns.Data.FromUnit("nameplate2").v, "??")

-- Override with nickname and custom text
Core:SetOverride("Player-1-BBB", { first = "Ad", last = "Astra", nickname = "Astra", primary = "{n} - Tank", secondaryEnabled = false })
runTimers()
d = Core:GetDisplay("target")
check("override primary", d and d.primary, "Astra - Tank")
check("override secondary off", d and d.secondary, nil)

-- Name-keyed override upgrades to GUID
Core:SetOverride(nil, { first = "Orin", last = "Vale", primary = "Ret - Tank" })
d = Core:GetDisplay("nameplate1")
check("name-keyed override", d and d.primary, "Ret - Tank")
check("upgraded to guid", NameForgeDB.overrides["Player-1-CCC"] ~= nil, true)
check("name key removed", NameForgeDB.overrides["N:orin vale"], nil)

-- Tooltip
tooltipPostCalls[1](GameTooltip)
GameTooltip.GetUnit = function() return "Ad", "target", "Player-1-BBB" end
tooltipPostCalls[1](GameTooltip)
check("tooltip line 1", GameTooltip.TextLeft1:GetText(), "Astra - Tank")

-- Target frame
hooks.UnitFrame_Update(TargetFrame)
check("target frame", TargetFrame.name:GetText(), "Astra - Tank")

-- Class color
NameForgeDB.global.classColor = true
Core:Invalidate()
d = Core:GetDisplay("nameplate2")
check("class color hex", d and d.hex, "ff3fc7eb")

-- Disabled leaves Blizzard text alone
Core:SetEnabled(false)
check("disabled returns nil", Core:GetDisplay("target"), nil)
Core:SetEnabled(true)

-- Secret values: fall back
issecretvalue = function(v) return v == "Ad" end
Core:Invalidate()
check("secret falls back", Core:GetDisplay("target"), nil)
issecretvalue = function() return false end

-- Build every window
ns.Options:Open("names")
ns.Options:Open("display")
ns.Options:Open("overrides")
ns.Options:Open("about")
ns.OverridePopup:Open({ unit = "target" })
ns.OverridePopup:Save()
ns.OverridePopup:Open({ first = "Brann", last = "Holloway" })
InspectFrame = newWidget("Frame", "InspectFrame")
InspectFrame.CloseButton = newWidget("Button")
EventUtil._pending()
check("inspect button created", _G.NameForgeInspectButton ~= nil, true)

-- Menu entry with chat-style combined name
local created = {}
local root = { CreateDivider = function() end, CreateButton = function(_, text, fn) created[#created + 1] = { text, fn } end }
menuMods.MENU_UNIT_FRIEND(nil, root, { name = "Sela Thornwick" })
check("menu entry added", created[1] and created[1][1], "Set Display Name")
created[1][2]()

-- Slash commands
SlashCmdList.NAMEFORGE("primary {f}")
check("slash primary", NameForgeDB.global.primary, "{f}")
SlashCmdList.NAMEFORGE("primary {f")
check("slash rejects bad format", NameForgeDB.global.primary, "{f}")
SlashCmdList.NAMEFORGE("secondary off")
check("slash secondary off", NameForgeDB.global.secondaryEnabled, false)
SlashCmdList.NAMEFORGE("off")
check("slash off", NameForgeDB.enabled, false)
SlashCmdList.NAMEFORGE("on")
SlashCmdList.NAMEFORGE("minimap")
SlashCmdList.NAMEFORGE("target")
SlashCmdList.NAMEFORGE("help")
runTimers()

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
