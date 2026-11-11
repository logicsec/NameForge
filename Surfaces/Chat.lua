-- Change the sender label before Blizzard builds the clickable player link.
local _, ns = ...
local Core, Data = ns.Core, ns.Data
local IsSecret = Core.IsSecret

local playerChat = {
	CHAT_MSG_SAY = true, CHAT_MSG_YELL = true, CHAT_MSG_EMOTE = true,
	CHAT_MSG_WHISPER = true, CHAT_MSG_WHISPER_INFORM = true,
	CHAT_MSG_GUILD = true, CHAT_MSG_OFFICER = true,
	CHAT_MSG_PARTY = true, CHAT_MSG_PARTY_LEADER = true,
	CHAT_MSG_RAID = true, CHAT_MSG_RAID_LEADER = true, CHAT_MSG_RAID_WARNING = true,
	CHAT_MSG_INSTANCE_CHAT = true, CHAT_MSG_INSTANCE_CHAT_LEADER = true,
	CHAT_MSG_CHANNEL = true,
}

local function formatSender(event, decorated, sender, guid, discord)
	if IsSecret(event, decorated, sender, guid, discord) or not playerChat[event] then return end
	if type(decorated) ~= "string" or type(sender) ~= "string" or sender == "" then return end
	if type(guid) ~= "string" or guid:sub(1, 7) ~= "Player-" then return end
	if discord and (IsSecret(discord.userID) or (discord.userID and discord.userID ~= 0)) then return end

	local unit = UnitTokenFromGUID and UnitTokenFromGUID(guid)
	local data
	if not IsSecret(unit) and unit then data = Data.FromUnit(unit) end
	if data and data.secret then return end
	if data and data.guid ~= guid then data = nil end

	local first, last = Data.SplitFullName(sender:match("^[^-]+"))
	if not first then return end
	if data then first, last = data.f, data.l end
	local override = Core:FindOverride(guid, first, last)
	if data then
		Core:UpdateSnapshot(override, data)
	else
		data = override and Core.OverrideData(override) or {}
		data.f, data.l = first, last
		if GetPlayerInfoByGUID then
			local class, classFile, race = GetPlayerInfoByGUID(guid)
			if not IsSecret(class, classFile, race) then
				data.c, data.classFile, data.r = class or data.c, classFile or data.classFile, race or data.r
			end
		end
	end
	data.n = override and override.nickname
	local display = Core:BuildDisplay(data, override)
	if not display or display.secret then return end

	-- Keep Blizzard's class colors and icons around the original sender label.
	local visible = Ambiguate and Ambiguate(sender, event == "CHAT_MSG_GUILD" and "guild" or "none") or sender
	if IsSecret(visible) or type(visible) ~= "string" or visible == "" then return end
	local firstByte, lastByte = decorated:find(visible, 1, true)
	if not firstByte then return end
	local label = display.primary:gsub("|", "||")
	if display.hex and not decorated:find("|c", 1, true) then
		label = "|c" .. display.hex .. label .. "|r"
	end
	return decorated:sub(1, firstByte - 1) .. label .. decorated:sub(lastByte + 1)
end

local function filterSender(event, decorated, _, sender, _, _, _, _, _, _, _, _, _, guid, _, _, discord)
	if not Core:IsSurfaceEnabled("chat") then return end
	local ok, label = pcall(formatSender, event, decorated, sender, guid, discord)
	if ok then return label end
end

if ChatFrameUtil and ChatFrameUtil.AddSenderNameFilter then
	ChatFrameUtil.AddSenderNameFilter(filterSender)
end
