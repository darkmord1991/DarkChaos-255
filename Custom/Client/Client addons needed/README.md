Client addons needed
====================

HinterlandAffixHUD
------------------
A tiny addon that shows the current Hinterland BG affix under the WG-style HUD. It reads a custom worldstate value sent by the server and prints a short label like "Affix: Haste".

Install:
- Copy the `HinterlandAffixHUD` folder to your WoW/Interface/AddOns directory on your client.
- Restart the client or use `/reload`.

Notes:
- Requires the server to send the custom worldstate ID (already integrated as WORLD_STATE_HL_AFFIX_TEXT).
- You can reposition by editing the `SetPoint` line in `HinterlandAffixHUD.lua`.
- Affix names map: 0=None, 1=Haste, 2=Slow, 3=Reduced Healing, 4=Reduced Armor, 5=Boss Enrage.
