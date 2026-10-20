-- NameForge data: reads the values behind each token for a unit.
--
-- Verified against the Forever UI source (Blizzard_FrameXMLUtil/Camelot/NameUtil.lua):
-- UnitName(unit) returns first name and surname as its two values, and the
-- display separator between them is a space. When regional unique names are on,
-- the first value can also arrive as "First Surname" in one string, so we split it.

local _, ns = ...
local Core = ns.Core

local Data = {}
ns.Data = Data

local IsSecret = Core.IsSecret

-- Split a combined "First Surname" string at the first space.
function Data.SplitFullName(name)
	if not name then return nil end
	local first, last = name:match("^(%S+)%s+(.+)$")
	if first then return first, last end
	return name, nil
end

-- Returns a data table for a player unit, or nil when the unit is not a player
-- or any value is secret (the caller then leaves Blizzard's text alone).
function Data.FromUnit(unit)
	if not UnitIsPlayer(unit) then return nil end

	local first, last = UnitName(unit)
	local guid = UnitGUID(unit)
	if IsSecret(first, last, guid) or not first or not guid then return nil end
	if not last or last == "" then
		first, last = Data.SplitFullName(first)
	end

	local guild = GetGuildInfo(unit)
	local className, classFile = UnitClass(unit)
	local race = UnitRace(unit)
	local level = UnitLevel(unit)
	if IsSecret(guild, className, classFile, race, level) then return nil end

	local levelText
	if type(level) == "number" and level > 0 then
		levelText = tostring(level)
	else
		levelText = "??"
	end

	local data = {
		guid = guid,
		f = first,
		l = last,
		g = guild,
		c = className,
		r = race,
		v = levelText,
		classFile = classFile,
	}
	-- Signature for the per-GUID cache: changes when any token value changes.
	data.sig = table.concat({ first, last or "", guild or "", className or "", race or "", levelText }, "\031")
	return data
end

-- Sample data for previews (settings window, override popup).
Data.SAMPLES = {
	{ f = "Ad", l = "Astra", g = "Solstice", c = "Mage", r = "Gnome", v = "60", classFile = "MAGE", caption = "Guilded player" },
	{ f = "Orin", l = "Vale", g = nil, c = "Warrior", r = "Human", v = "42", classFile = "WARRIOR", caption = "Guildless player" },
}

-- Your own character as preview data, falling back to the first sample.
function Data.PlayerSample()
	local d = Data.FromUnit("player")
	if d then
		d.caption = "You"
		return d
	end
	return Data.SAMPLES[1]
end
