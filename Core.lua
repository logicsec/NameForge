-- NameForge core: saved settings, overrides, caching and the refresh bus.

local addonName, ns = ...
local Format = ns.Format

local NameForge = CreateFrame("Frame", "NameForgeCore")
ns.Core = NameForge
_G.NameForge = NameForge

NameForge.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "dev"

local SCHEMA = 1

local DEFAULTS = {
	schema = SCHEMA,
	enabled = true,
	minimap = { hide = false, angle = 220 },
	global = {
		primary = "{f} {l}[ - {g}]",
		secondaryEnabled = false,
		secondary = "{c}",
		classColor = false,
		surfaces = { nameplate = true, tooltip = true, target = true },
	},
	overrides = {},
}
NameForge.DEFAULTS = DEFAULTS

-- ---------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------

local function copyDefaults(src, dst)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			copyDefaults(v, dst[k])
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
	return dst
end

-- True when a value came back secret under Midnight/Forever addon rules.
-- Any secret input means we leave Blizzard's own text alone.
function NameForge.IsSecret(...)
	local issecret = issecretvalue
	if not issecret then return false end
	for i = 1, select("#", ...) do
		if issecret((select(i, ...))) then return true end
	end
	return false
end

function NameForge.Print(msg)
	print("|cfff2c230NameForge|r: " .. tostring(msg))
end

-- Lowercased "first last" used to find overrides when a GUID is unknown.
function NameForge.NameKey(first, last)
	if not first or first == "" then return nil end
	local s = first
	if last and last ~= "" then s = s .. " " .. last end
	return s:lower()
end

-- ---------------------------------------------------------------------------
-- Compiled format cache
-- ---------------------------------------------------------------------------

local compiled = {}

function NameForge.GetCompiled(fmt)
	if fmt == nil then return nil end
	local c = compiled[fmt]
	if c == nil then
		local nodes = Format.Compile(fmt)
		c = nodes or false
		compiled[fmt] = c
	end
	return c or nil
end

-- ---------------------------------------------------------------------------
-- Overrides
-- Overrides are keyed by player GUID when known, otherwise by "N:" .. name key.
-- The name index lets a name-keyed override match once we see the unit.
-- ---------------------------------------------------------------------------

local nameIndex = {}

function NameForge:RebuildNameIndex()
	wipe(nameIndex)
	for key, o in pairs(self.db.overrides) do
		local nk = NameForge.NameKey(o.first, o.last)
		if nk then nameIndex[nk] = key end
	end
end

function NameForge:FindOverride(guid, first, last)
	local o = guid and self.db.overrides[guid]
	if o then return o, guid end
	local nk = NameForge.NameKey(first, last)
	local key = nk and nameIndex[nk]
	if key then
		o = self.db.overrides[key]
		-- Upgrade a name-keyed override to the GUID once we learn it.
		if o and guid and key ~= guid and key:sub(1, 2) == "N:" then
			self.db.overrides[guid] = o
			self.db.overrides[key] = nil
			nameIndex[nk] = guid
			key = guid
		end
		return o, key
	end
	return nil
end

-- Snapshot of the token values last seen for a character, so the Overrides page
-- can show the resulting name on any of your characters, even when they are not nearby.
local SNAPSHOT_KEYS = { "g", "c", "r", "v", "classFile" }

local function snapshotFrom(data)
	if not data then return nil end
	local s = {}
	for _, k in ipairs(SNAPSHOT_KEYS) do s[k] = data[k] end
	return s
end

local function snapshotDiffers(a, b)
	if not a or not b then return true end
	for _, k in ipairs(SNAPSHOT_KEYS) do
		if a[k] ~= b[k] then return true end
	end
	return false
end

-- Refresh an override's snapshot when we see the character with new details.
function NameForge:UpdateSnapshot(override, data)
	if override and data and snapshotDiffers(override.seen, data) then
		override.seen = snapshotFrom(data)
	end
end

-- Token data for an override without a live unit: names plus the last-seen snapshot.
function NameForge.OverrideData(o)
	local data = { f = o.first, l = o.last, n = o.nickname }
	if o.seen then
		for _, k in ipairs(SNAPSHOT_KEYS) do data[k] = o.seen[k] end
	end
	return data
end

-- fields: first, last, nickname, primary, secondary, secondaryEnabled (nil = global),
-- data (optional live token data used for the snapshot)
function NameForge:SetOverride(guid, fields)
	local nk = NameForge.NameKey(fields.first, fields.last)
	local key = guid or (nk and ("N:" .. nk))
	if not key then return false end
	local previous, existingKey = self:FindOverride(guid, fields.first, fields.last)
	if existingKey and existingKey ~= key then
		self.db.overrides[existingKey] = nil
	end
	local o = {
		first = fields.first,
		last = fields.last,
		nickname = (fields.nickname ~= "" and fields.nickname) or nil,
		primary = (fields.primary ~= "" and fields.primary) or nil,
		secondary = (fields.secondary ~= "" and fields.secondary) or nil,
		secondaryEnabled = fields.secondaryEnabled,
		seen = snapshotFrom(fields.data) or (previous and previous.seen),
		updated = time(),
	}
	self.db.overrides[key] = o
	self:RebuildNameIndex()
	self:Invalidate()
	return true
end

function NameForge:ClearOverride(guid, first, last)
	local _, key = self:FindOverride(guid, first, last)
	if key then
		self.db.overrides[key] = nil
		self:RebuildNameIndex()
		self:Invalidate()
		return true
	end
	return false
end

function NameForge:DeleteOverrideByKey(key)
	if self.db.overrides[key] then
		self.db.overrides[key] = nil
		self:RebuildNameIndex()
		self:Invalidate()
	end
end

-- ---------------------------------------------------------------------------
-- Display resolution
-- ---------------------------------------------------------------------------

-- Resolve the effective settings for a character (override field, else global).
function NameForge:ResolveSettings(override)
	local g = self.db.global
	local o = override or {}
	local secondaryEnabled = o.secondaryEnabled
	if secondaryEnabled == nil then secondaryEnabled = g.secondaryEnabled end
	return o.primary or g.primary, secondaryEnabled, o.secondary or g.secondary
end

-- Build display strings from a data table (see Data.lua) without caching.
-- Returns { primary, secondary, r, g, b } or nil to fall back to Blizzard text.
function NameForge:BuildDisplay(data, override)
	local primaryFmt, secondaryEnabled, secondaryFmt = self:ResolveSettings(override)
	local pNodes = NameForge.GetCompiled(primaryFmt)
	if not pNodes then return nil end
	local primary = Format.Render(pNodes, data)
	if primary == "" then return nil end

	local secondary
	if secondaryEnabled then
		local sNodes = NameForge.GetCompiled(secondaryFmt)
		if sNodes then
			secondary = Format.Render(sNodes, data)
			if secondary == "" then secondary = nil end
		end
	end

	local result = { primary = primary, secondary = secondary }
	if self.db.global.classColor and data.classFile then
		local color = C_ClassColor.GetClassColor(data.classFile)
		if color then
			result.r, result.g, result.b = color:GetRGB()
			result.hex = color:GenerateHexColor()
		end
	end
	return result
end

-- Per-GUID cache, cleared whenever settings or unit data change.
local cache = {}

function NameForge:Invalidate(guid)
	if guid then
		cache[guid] = nil
	else
		wipe(cache)
	end
	self:FireRefresh()
end

-- Main entry point for surfaces. Returns a display table or nil.
function NameForge:GetDisplay(unit)
	if not self.db or not self.db.enabled or not unit then return nil end
	local data = ns.Data.FromUnit(unit)
	if not data then return nil end
	local hit = cache[data.guid]
	if hit and hit.sig == data.sig then return hit.display end
	local override = self:FindOverride(data.guid, data.f, data.l)
	data.n = override and override.nickname or nil
	self:UpdateSnapshot(override, data)
	local display = self:BuildDisplay(data, override)
	cache[data.guid] = { sig = data.sig, display = display }
	return display
end

-- ---------------------------------------------------------------------------
-- Refresh bus: surfaces register a function that re-applies names everywhere.
-- ---------------------------------------------------------------------------

local refreshers = {}
local refreshPending = false

function NameForge:RegisterRefresh(fn)
	refreshers[#refreshers + 1] = fn
end

function NameForge:FireRefresh()
	if refreshPending then return end
	refreshPending = true
	C_Timer.After(0, function()
		refreshPending = false
		for i = 1, #refreshers do
			local ok, err = pcall(refreshers[i])
			if not ok then geterrorhandler()(err) end
		end
	end)
end

function NameForge:SetEnabled(enabled)
	self.db.enabled = enabled and true or false
	self:Invalidate()
end

function NameForge:IsSurfaceEnabled(name)
	return self.db and self.db.enabled and self.db.global.surfaces[name]
end

function NameForge:ResetGlobal()
	self.db.global = copyDefaults(DEFAULTS.global, {})
	self:Invalidate()
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

NameForge:RegisterEvent("ADDON_LOADED")
NameForge:RegisterEvent("PLAYER_LOGIN")
NameForge:RegisterEvent("UNIT_NAME_UPDATE")
NameForge:RegisterEvent("PLAYER_GUILD_UPDATE")
NameForge:RegisterEvent("UNIT_LEVEL")

local initCallbacks = {}
function NameForge:OnInit(fn)
	if self.db then fn() else initCallbacks[#initCallbacks + 1] = fn end
end

NameForge:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == addonName then
		NameForgeDB = copyDefaults(DEFAULTS, NameForgeDB or {})
		self.db = NameForgeDB
		self.db.schema = SCHEMA
		self:RebuildNameIndex()
		for i = 1, #initCallbacks do initCallbacks[i]() end
		wipe(initCallbacks)
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_LOGIN" then
		self:Invalidate()
	elseif event == "UNIT_NAME_UPDATE" or event == "PLAYER_GUILD_UPDATE" or event == "UNIT_LEVEL" then
		-- Unit data changed; the per-GUID signature check catches stale entries,
		-- so a refresh pass is enough.
		self:FireRefresh()
	end
end)
