-- Run from the repo root:  lua5.1 tests/test_format.lua
-- Tests the format engine in Format.lua, which has no WoW API dependencies.

local ns = {}
local chunk = assert(loadfile("Format.lua"))
chunk("NameForge", ns)
local Format = ns.Format

local passed, failed = 0, 0
local function check(name, got, want)
	if got == want then
		passed = passed + 1
	else
		failed = failed + 1
		print(("FAIL %s\n  got:  %s\n  want: %s"):format(name, tostring(got), tostring(want)))
	end
end

local astra = { f = "Ad", l = "Astra", g = "Solstice", c = "Mage", r = "Gnome", v = "60" }
local orin = { f = "Orin", l = "Vale", c = "Warrior", r = "Human", v = "42" }

-- Spec example
check("spec primary", Format.Apply("{f} {l} - {g}", astra), "Ad Astra - Solstice")
check("class secondary", Format.Apply("{c}", astra), "Mage")

-- Optional segments
check("segment kept", Format.Apply("{f} {l}[ - {g}]", astra), "Ad Astra - Solstice")
check("segment dropped", Format.Apply("{f} {l}[ - {g}]", orin), "Orin Vale")
check("no dangling dash without segment", Format.Apply("{f} {l} - {g}", orin), "Orin Vale -")
check("nested segment", Format.Apply("{f}[ ({n}[ of {g}])]", { f = "Ad", n = "Astra", g = "Solstice" }), "Ad (Astra of Solstice)")
check("nested inner dropped", Format.Apply("{f}[ ({n}[ of {g}])]", { f = "Ad", n = "Astra" }), "Ad (Astra)")

-- Literal text and custom tags (user feedback: "Ret - Tank")
check("custom text", Format.Apply("Ret - Tank", astra), "Ret - Tank")
check("text plus token", Format.Apply("{f} (healer)", astra), "Ad (healer)")
check("nickname", Format.Apply("{n} ({f})", { f = "Ad", n = "Astra" }), "Astra (Ad)")

-- Case and unknown tokens
check("uppercase token", Format.Apply("{F} {L}", astra), "Ad Astra")
check("unknown token literal", Format.Apply("{f} {x}", astra), "Ad {x}")

-- Escapes
check("escaped brackets", Format.Apply("[[{f}]]", astra), "[Ad]")
check("escaped braces", Format.Apply("{{f}}", astra), "{f}")

-- Whitespace cleanup
check("collapse spaces", Format.Apply("  {f}   {l}  ", astra), "Ad Astra")
check("missing last name", Format.Apply("{f} {l}", { f = "Ad" }), "Ad")
check("level token", Format.Apply("{f} ({v})", astra), "Ad (60)")

-- Errors
local nodes, err = Format.Compile("{f} [ - {g}")
check("unclosed bracket fails", nodes, nil)
check("unclosed bracket message", err ~= nil and err:find("Unclosed %[") ~= nil, true)
nodes, err = Format.Compile("{f} ]")
check("stray close bracket fails", nodes, nil)
nodes, err = Format.Compile("{f")
check("unclosed brace fails", nodes, nil)
nodes, err = Format.Compile(string.rep("a", 65))
check("too long fails", nodes, nil)
check("non-string fails", (Format.Compile(nil)), nil)

-- Truncation (48 characters, UTF-8 aware)
local long = string.rep("x", 60)
check("truncate ascii", Format.Apply(long:sub(1, 60):sub(1, 60):sub(1, 64), {}), string.rep("x", 47) .. "...")
local accented = string.rep("é", 50)
local out = Format.Apply("{f}", { f = accented })
check("truncate utf8 keeps whole chars", out, string.rep("é", 47) .. "...")
check("short string untouched", Format.TruncateUTF8("Ad Astra", 48), "Ad Astra")

-- Empty result
check("all empty", Format.Apply("[{g}]", orin), "")

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
