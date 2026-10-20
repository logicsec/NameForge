-- NameForge format strings.
--
-- A format string mixes literal text with tokens:
--   {f} first name   {l} last name   {g} guild   {c} class
--   {r} race         {v} level       {n} nickname
--
-- Square brackets mark an optional segment that is dropped when any token
-- inside it is empty:   "{f} {l}[ - {g}]"  ->  "Ad Astra"  for a guildless player.
-- Doubled characters are literals: [[  ]]  {{  }}
--
-- This file has no WoW API dependencies so it can be unit tested with plain Lua.

local _, ns = ...
if type(ns) ~= "table" then ns = {} end

local Format = {}
ns.Format = Format

Format.MAX_FORMAT_LENGTH = 64
Format.MAX_OUTPUT_CHARS = 48

Format.TOKENS = {
	{ key = "f", label = "First name" },
	{ key = "l", label = "Last name" },
	{ key = "g", label = "Guild" },
	{ key = "c", label = "Class" },
	{ key = "r", label = "Race" },
	{ key = "v", label = "Level" },
	{ key = "n", label = "Nickname" },
}

local VALID = {}
for _, t in ipairs(Format.TOKENS) do VALID[t.key] = true end

-- Parse a format string into a node list.
-- Returns nodes on success, or nil, errorMessage, position on failure.
function Format.Compile(fmt)
	if type(fmt) ~= "string" then
		return nil, "Format must be text", 1
	end
	if #fmt > Format.MAX_FORMAT_LENGTH then
		return nil, ("Format is longer than %d characters"):format(Format.MAX_FORMAT_LENGTH), Format.MAX_FORMAT_LENGTH + 1
	end

	local pos = 1
	local len = #fmt

	local function addText(nodes, s)
		local last = nodes[#nodes]
		if last and last.t == "text" then
			last.s = last.s .. s
		else
			nodes[#nodes + 1] = { t = "text", s = s }
		end
	end

	local parse
	parse = function(depth, openPos)
		local nodes = {}
		while pos <= len do
			local ch = fmt:sub(pos, pos)
			local nx = fmt:sub(pos + 1, pos + 1)
			if (ch == "[" or ch == "]" or ch == "{" or ch == "}") and nx == ch then
				addText(nodes, ch)
				pos = pos + 2
			elseif ch == "[" then
				local start = pos
				pos = pos + 1
				local child, err, errPos = parse(depth + 1, start)
				if not child then return nil, err, errPos end
				nodes[#nodes + 1] = { t = "seg", nodes = child }
			elseif ch == "]" then
				if depth == 0 then
					return nil, "Unexpected ] (write ]] for a literal bracket)", pos
				end
				pos = pos + 1
				return nodes
			elseif ch == "{" then
				local close = fmt:find("}", pos + 1, true)
				if not close then
					return nil, "Unclosed { (write {{ for a literal brace)", pos
				end
				local key = fmt:sub(pos + 1, close - 1):lower()
				if VALID[key] then
					nodes[#nodes + 1] = { t = "tok", k = key }
				else
					-- Unknown tokens stay visible so typos show up in the preview.
					addText(nodes, fmt:sub(pos, close))
				end
				pos = close + 1
			else
				addText(nodes, ch)
				pos = pos + 1
			end
		end
		if depth > 0 then
			return nil, "Unclosed [ (write [[ for a literal bracket)", openPos
		end
		return nodes
	end

	return parse(0, 1)
end

local function renderNodes(nodes, data, out)
	local empty = false
	for i = 1, #nodes do
		local node = nodes[i]
		if node.t == "text" then
			out[#out + 1] = node.s
		elseif node.t == "tok" then
			local v = data[node.k]
			if v == nil or v == "" then
				empty = true
			else
				out[#out + 1] = tostring(v)
			end
		elseif node.t == "seg" then
			local sub = {}
			local subEmpty = renderNodes(node.nodes, data, sub)
			if not subEmpty then
				for j = 1, #sub do out[#out + 1] = sub[j] end
			end
		end
	end
	return empty
end

-- Truncate to a number of UTF-8 characters, adding "..." when cut.
function Format.TruncateUTF8(s, maxChars)
	local count, cut = 0, nil
	for startPos in s:gmatch("()[%z\1-\127\194-\244][\128-\191]*") do
		count = count + 1
		if count == maxChars then
			cut = startPos
		end
		if count > maxChars then
			return s:sub(1, cut - 1) .. "..."
		end
	end
	return s
end

-- Render compiled nodes with a data table keyed by token letter.
-- Returns the final string ("" when everything was empty).
function Format.Render(nodes, data)
	local out = {}
	renderNodes(nodes, data or {}, out)
	local s = table.concat(out)
	s = s:gsub("%s+", " "):match("^%s*(.-)%s*$")
	return Format.TruncateUTF8(s, Format.MAX_OUTPUT_CHARS)
end

-- Convenience: compile and render in one step. Returns string or nil, err.
function Format.Apply(fmt, data)
	local nodes, err = Format.Compile(fmt)
	if not nodes then return nil, err end
	return Format.Render(nodes, data)
end

return Format
