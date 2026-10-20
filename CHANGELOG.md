# Changelog

## 0.1.0 (unreleased)

First version, written ahead of the WoW: Forever launch on November 4, 2026.

- Format strings with the tokens `{f}` `{l}` `{g}` `{c}` `{r}` `{v}` `{n}`, optional `[ ]` segments, and `[[ ]] {{ }}` escapes.
- Global primary format, optional secondary name, and class colors.
- Per-character overrides (nickname, primary, secondary, secondary on/off) from the Inspect window, the right-click menu, or `/nf target`.
- Names shown on Blizzard nameplates, the unit tooltip, and the target and focus frames.
- Options window with Names, Display, Overrides and About pages, and a live preview.
- Minimap button, addon compartment entry, and `/nf` slash commands.
- Secret-value checks throughout; Blizzard's text is left alone when a value is restricted.
- Offline tests for the format engine and a mocked-API smoke test.
- Overrides page shows each character's original name next to the name you will see ("Shows as"), on every character you log into. Formats appear on hover.
- Overrides keep a last-seen snapshot of guild, class, race and level so results render while the character is not nearby; the snapshot refreshes whenever they are seen.
