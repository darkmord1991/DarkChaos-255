Client addons needed
====================

HinterlandAffixHUD
------------------
A tiny addon that shows the current Hinterland BG affix (and weather) near the WG-style HUD. It reads a custom worldstate value sent by the server and falls back to parsing server announcements.

Install:
- Copy the `HinterlandAffixHUD` folder to your WoW/Interface/AddOns directory on your client.
- Restart the client or use `/reload`.

Usage:
- /hlaffix dump — list current worldstates (helps identify the right ID)
- /hlaffix id <number|0xHEX> — set the affix worldstate ID (default 0xDD1010)
- /hlaffix hide on|off — hide/show Blizzard’s WG-style HUD (so the addon “replaces” it visually)

Notes:
- Requires the server to send the custom worldstate ID and announcements (Affix/Weather lines) for best results.
- You can reposition by editing the `SetPoint` line in `HinterlandAffixHUD.lua`.
- Affix names map: 0=None, 1=Haste, 2=Slow, 3=Reduced Healing, 4=Reduced Armor, 5=Boss Enrage.
