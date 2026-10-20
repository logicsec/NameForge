-- NameForge slash commands: /nameforge and /nf

local _, ns = ...
local Core, Format = ns.Core, ns.Format

local function setFormat(field, text)
	local nodes, err = Format.Compile(text)
	if not nodes then
		Core.Print("That format has a problem: " .. err)
		return
	end
	Core.db.global[field] = text
	Core:Invalidate()
	ns.Options:Refresh()
	Core.Print(field .. " format set to " .. text)
end

local function handler(msg)
	msg = strtrim(msg or "")
	local cmd, rest = msg:match("^(%S+)%s*(.*)$")
	cmd = cmd and cmd:lower()

	if not cmd then
		ns.Options:Toggle()
	elseif cmd == "on" or cmd == "off" then
		Core:SetEnabled(cmd == "on")
		Core.Print(cmd == "on" and "custom names on." or "custom names off.")
	elseif cmd == "primary" then
		if rest == "" then
			Core.Print("Primary format is " .. Core.db.global.primary)
		else
			setFormat("primary", rest)
		end
	elseif cmd == "secondary" then
		if rest == "" then
			Core.Print("Secondary format is " .. (Core.db.global.secondaryEnabled and Core.db.global.secondary or "off"))
		elseif rest:lower() == "off" then
			Core.db.global.secondaryEnabled = false
			Core:Invalidate()
			ns.Options:Refresh()
			Core.Print("secondary name off.")
		else
			Core.db.global.secondaryEnabled = true
			setFormat("secondary", rest)
		end
	elseif cmd == "target" then
		if UnitExists("target") and UnitIsPlayer("target") then
			ns.OverridePopup:Open({ unit = "target" })
		else
			Core.Print("Target a player first.")
		end
	elseif cmd == "minimap" then
		ns.MinimapButton:Toggle()
	elseif cmd == "reset" then
		StaticPopup_Show("NAMEFORGE_RESET")
	else
		Core.Print("Commands: /nf, /nf on, /nf off, /nf primary <format>, /nf secondary <format|off>, /nf target, /nf minimap, /nf reset")
	end
end

SLASH_NAMEFORGE1 = "/nameforge"
SLASH_NAMEFORGE2 = "/nf"
SlashCmdList.NAMEFORGE = handler
