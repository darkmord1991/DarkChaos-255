HotspotDisplayWrath (3.3.5a)

Installation:
- Copy the `HotspotDisplay` folder into your client's AddOns directory (e.g., World of Warcraft\Interface\AddOns\HotspotDisplay).
- Ensure `Core_wrath.lua` is referenced in the TOC (the repository's TOC already includes it).
- If you use Astrolabe (recommended on Wrath), ensure the Astrolabe addon is installed and enabled in your client.

Usage:
- Start the client and login. The addon prints a loaded message.
- When server spawns a hotspot, the addon listens for CHAT_MSG_ADDON (prefix HOTSPOT) or CHAT_MSG_SYSTEM fallback HOTSPOT_ADDON|... and registers hotspots.
- World map pins and minimap pins are shown approximately; with Astrolabe installed the world map placement is more accurate.

Notes & safety:
- This addon is intentionally defensive: parses fields only when present and avoids nil dereferences.
- If you want a more featureful UI (list window with clickable pins and sorting), I can extend this further for your exact UI requirements.