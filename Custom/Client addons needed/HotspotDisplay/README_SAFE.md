HotspotDisplaySafe

A minimal defensive HotspotDisplay replacement designed to be robust against malformed server messages.

Installation:
- Copy the entire `HotspotDisplay` folder into your client's AddOns directory.
- Enable `Core_safe.lua` in the TOC or rename it to `Core.lua` to replace the original.

Behavior:
- Listens for `CHAT_MSG_ADDON` with prefix "HOTSPOT" and for `CHAT_MSG_SYSTEM` fallback lines starting with `HOTSPOT_ADDON|...`.
- Parses fields defensively and prints a short message to chat when a hotspot is registered.
- Adds a simple minimap pin placeholder (no Astrolabe dependency).

If you want, I can produce a full robust addon with proper world->map coordinate pin placement using Astrolabe (or the modern C_Map APIs) — tell me which client version you target and I will adapt it.