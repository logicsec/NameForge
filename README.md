# NameForge

NameForge lets you choose how other characters' names appear to you in **World of Warcraft: Forever**.

Forever gives every character a first name and a last name. The built-in option only switches between the full name and the first name. NameForge replaces that with a format string you control, plus an optional second line, plus per-character overrides with your own nicknames and notes.

```
Primary:    {f} {l}[ - {g}]          ->  Ad Astra - Solstice
Secondary:  {c}                      ->  Mage
Override:   {n} - Tank   (n = Ret)   ->  Ret - Tank
```

Everything you set is personal and account-wide. Nobody else sees your names.

## Features

- **Global format** for every player character, set from the minimap button.
- **Secondary name** line under the primary name, with its own format.
- **Per-character overrides** from the Inspect window, the right-click menu, or `/nf target`. Give someone a nickname, a note, or a completely custom label.
- **Class colors** for the primary name (optional).
- **Live preview** while you type, and validation that blocks broken formats.
- **Surfaces in v1:** Blizzard nameplates, the unit tooltip, the target and focus frames, and Blizzard's raid and party frames.
- **Players only.** NPCs, pets and creatures always keep their normal names.
- Minimap button and addon compartment entry. No external libraries.

## Install

1. Download or clone this repository.
2. Put the folder in the `Interface/AddOns/` folder inside your WoW: Forever game folder, and make sure it is named `NameForge` (it must contain `NameForge.toc` directly).
3. Restart the game or `/reload`, and enable NameForge on the character select screen.

## Format strings

A format string is any text you like, with tokens that get replaced by the character's details.

| Token | Value | Empty when |
| --- | --- | --- |
| `{f}` | First name | never |
| `{l}` | Last name | the client does not supply one |
| `{g}` | Guild name | no guild |
| `{c}` | Class (localized) | never |
| `{r}` | Race (localized) | never |
| `{v}` | Level | never (shows `??` when hidden) |
| `{n}` | Nickname from an override | no nickname set |

Rules:

- **Custom text is allowed anywhere.** `Test {f}` shows `Test Ad`. A string with no tokens at all, such as `Ret - Tank`, is shown exactly as written.
- **Optional parts** go in square brackets. The part is dropped when any token inside it is empty, so `{f} {l}[ - {g}]` shows `Orin Vale` for a guildless player instead of `Orin Vale -`. Brackets can be nested.
- **Reserved characters:** `{ } [ ]` have special meaning. To show one literally, type it twice: `[[` shows `[`, `]]` shows `]`, `{{` shows `{`, `}}` shows `}`.
- Tokens are not case sensitive (`{F}` works). An unknown token such as `{x}` is left visible so typos are easy to spot.
- Extra spaces are collapsed, formats are limited to 64 characters, and names are cut at 48 characters with `...`.

### Examples

| Format | Result |
| --- | --- |
| `{f} {l}` | Ad Astra |
| `{f}` | Ad |
| `{f} {l}[ <{g}>]` | Ad Astra <Solstice> |
| `{l}, {f}` | Astra, Ad |
| `[{n} ]({f})` | Astra (Ad) with a nickname, (Ad) without |
| `{f} [{v} ]{r} {c}` | Ad 60 Gnome Mage |
| `Ret - Tank` | Ret - Tank |

## Overrides

An override changes how one specific character appears, on top of the global format. Any field left blank uses the global setting.

- **Nickname** is available as `{n}` in any format.
- **Primary format** and **secondary format** replace the global ones for that character.
- **Secondary name** can follow the global setting, or be forced on or off.

Open the override popup from:

- the NameForge button in the Inspect window's title bar,
- **Set Display Name** in a player's right-click menu,
- `/nf target` with a player targeted.

### Account-wide

All settings and overrides are saved account-wide. Every override applies no matter which of your characters you log into, and the **Overrides** page shows the same list on all of them.

### The Overrides page

Each row shows:

| Column | Shows |
| --- | --- |
| **Character** | The character's original first and last name (class colored), with their last-seen level, race, class and guild |
| **Shows as** | The name you will actually see for them, primary and secondary, rendered with your current settings |

Hover a row to see the formats behind it (nickname, primary, secondary). **Edit** opens the override popup, and **Delete** removes the override.

So that **Shows as** works for characters who are not nearby (or after you switch characters), NameForge keeps a small snapshot of each overridden character's guild, class, race and level. The snapshot is refreshed whenever you see that character again, so a guild change shows up the next time they are on your screen.

Overrides are stored by character GUID, with the full name kept alongside so an override set from a chat or roster menu (where only the name is known) attaches to the character the first time you see them.

## Slash commands

| Command | Action |
| --- | --- |
| `/nf` or `/nameforge` | Open or close the options window |
| `/nf on`, `/nf off` | Turn custom names on or off |
| `/nf primary <format>` | Set the global primary format |
| `/nf secondary <format>` | Set the global secondary format and turn it on |
| `/nf secondary off` | Turn the secondary name off |
| `/nf target` | Set an override for your current target |
| `/nf minimap` | Show or hide the minimap button |
| `/nf reset` | Reset global settings (overrides are kept) |

Minimap button: left-click opens the options window, right-click turns NameForge on or off, and dragging moves it around the minimap.

## How it works

NameForge was checked against the Forever UI source (the `forever` branch of the community mirror of Blizzard's interface code, build 1.60.1.70450) rather than against retail or classic documentation.

- **Names:** on Forever, `UnitName(unit)` returns the first name and the surname as its two values, and the separator is a space (Blizzard's own `NameUtil` in `Blizzard_FrameXMLUtil/Camelot`). Some menus pass the full name as one string, which NameForge splits.
- **Nameplates:** post-hooks `CompactUnitFrame_UpdateName`, so Blizzard sets the name first and NameForge replaces the text after. The secondary line is NameForge's own font string, kept in NameForge's own table rather than written onto Blizzard's frame. It sits under the health bar (or under the name when only the name is shown) and hides while a cast bar is visible.
- **Tooltip:** `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, ...)` replaces line 1 and adds the secondary name directly under it.
- **Target and focus:** post-hooks `UnitFrame_Update` for `TargetFrame` and `FocusFrame` only.
- **Raid and party frames:** Blizzard's raid-style frames set their name in the same `CompactUnitFrame_UpdateName` the nameplates use, and Forever's classic party frames go through `UnitFrame_Update`. NameForge post-hooks both for `raidN`, `partyN` and `player` units and sets the primary name only (these frames are too small for two lines). `FontString:SetText` is not a protected call, so names stay correct in combat.
- **Players only:** every surface goes through one check, `UnitIsPlayer(unit)`. Anything else is left exactly as Blizzard draws it.
- **Inspect:** the button is added when `Blizzard_InspectUI` loads, next to `InspectFrame.CloseButton`. Right-click entries use `Menu.ModifyMenu` on the `MENU_UNIT_*` tags.
- **Addon restrictions:** Forever uses Midnight's addon rules, including secret values. NameForge checks every value with `issecretvalue`. It never touches forbidden nameplates.

### PvP (battlegrounds and arenas)

Forever's API documentation marks `UnitName` with a rule that applies "in PvP when the queried unit is a player", which most likely means player names can come back as secret values in battlegrounds and arenas. The same documentation only restricts `UnitGUID`, `UnitClass` and `UnitRace` for units that are not player-controlled, so those should stay readable for players.

NameForge keeps names working in PvP with a fallback:

| Situation | What you see |
| --- | --- |
| Names readable (outside matches, open-world PvP) | Your names, exactly as everywhere else |
| Names hidden, character has an override | The override, matched by character ID: nicknames and custom labels like `Ret - Tank` work normally |
| Names hidden, no override | Your global format. The hidden name is joined with your text and displayed, but because a hidden value cannot be inspected, optional `[ ]` parts are kept whenever they contain the name, and long names are not shortened. Spaces in your own text are still tidied. |
| Character ID hidden too | Blizzard's default name (the fallback) |

Overrides cannot be created from a hidden name, so the popup explains this during a match; overrides you already have keep applying. Hidden values are never written to saved settings or the last-seen snapshot.

Showing a hidden name marks that font string as holding secret text, which is how the client tracks secrets. NameForge never reads those font strings back, so this has no effect on NameForge itself.

### Known limitations

- **Forbidden nameplates:** Blizzard can mark some nameplates as forbidden, which means no addon can read or change them. On retail this applies to friendly nameplates inside dungeons and raids. The Forever client has the same mechanism, but which plates it applies to is not confirmed yet (see the launch checklist). NameForge skips only plates that are actually forbidden, so if Forever does not lock friendly plates in instances, your raid members' nameplates will show your names too. Raid frames, tooltips and the target frame are not affected by this either way.
- **Third-party nameplate and raid frame addons** (Plater, Platynator, Cell, VuhDo, Grid2 and others) draw their own names and are not changed yet.
- **Chat sender names** are planned for v2.

## Launch day checklist

The beta closed before this was tested in game. On the launch client, check:

- [ ] `/dump UnitName("target")` on a player returns first name and surname as two values.
- [ ] Nameplates show the primary name, and the secondary line sits cleanly under the health bar.
- [ ] Tooltip line 1 shows the primary name, with the secondary under it.
- [ ] Target and focus frames show the primary name.
- [ ] In a group, Blizzard's party frames and raid-style frames show the primary name, including in combat.
- [ ] Enter a dungeon or raid with friendly nameplates turned on: check whether friendly player nameplates show NameForge names (not forbidden) or Blizzard names (forbidden), and update Known limitations.
- [ ] NPC nameplates and tooltips are unchanged.
- [ ] The Inspect window button appears next to the close button and opens the popup.
- [ ] **Set Display Name** appears in player right-click menus.
- [ ] The minimap icon (`INV_Misc_Note_01`) loads, and the addon compartment entry works.
- [ ] No Lua errors with `/console scriptErrors 1`, including in a battleground.
- [ ] In a battleground, run `/dump issecretvalue(UnitName("target"))` and `/dump issecretvalue(UnitGUID("target"))` on a player and record the results in the PvP section above.
- [ ] In a battleground, an override (nickname or custom label) shows on that player, and the global format shows on everyone else.
- [ ] The TOC interface number (`16001`) matches `select(4, GetBuildInfo())`.

## Development

```
lua5.1 tests/test_format.lua   # format engine unit tests
lua5.1 tests/smoke.lua         # loads the whole addon against a mocked WoW API
```

| Path | Purpose |
| --- | --- |
| `NameForge.toc` | Addon manifest and load order |
| `Format.lua` | Format string parser and renderer (no WoW dependencies) |
| `Core.lua` | Saved settings, overrides, cache and refresh |
| `Data.lua` | Reads token values for a unit, with secret checks |
| `Surfaces/` | Nameplates, tooltip, target and focus frames, raid and party frames |
| `UI/` | Theme, widgets, options window, override popup, Inspect button and menus, minimap button |
| `Slash.lua` | `/nf` commands |
| `tests/` | Offline tests, not shipped |

Saved data lives in the account-wide `NameForgeDB` SavedVariable.

## Roadmap

- Chat sender names
- Support for third-party raid frame addons
- An API for nameplate addons: `NameForge:GetDisplay(unit)` already returns `{ primary, secondary }`
- Import and export of overrides
