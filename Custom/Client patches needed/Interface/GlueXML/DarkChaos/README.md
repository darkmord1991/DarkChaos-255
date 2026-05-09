DarkChaos breaking news GlueXML package

What this package does:
- Loads a tiny GlueXML driver on the login and character-select side.
- Polls the WotLK-Extensions glue Lua exports for the latest breaking-news payload.
- Pushes the received title and body into the stock `ServerAlertFrame` once the character-select screen is visible.

Files in this folder:
- `DarkChaosBreakingNews.xml`: additive GlueXML include that loads the Lua driver and a tiny update ticker.
- `DarkChaosBreakingNews.lua`: character-select consumer for the `SMSG_BREAKING_NEWS` packet data exposed by WotLK-Extensions.
- `GlueParent.include.txt`: one-line include snippet for `GlueParent.xml`.

Client install steps:
1. Build WotLK-Extensions with `CUSTOMPACKETS_PATCH=ON` and `GLUEMGREXTENSION=ON`.
2. Patch the exact `Wow.exe` you launch with `Patcher.exe` and copy `WotLKExtensions.dll` next to `Wow.exe`.
3. Ship this folder into the client under the exact internal path `Interface\GlueXML\DarkChaos\`.
4. Extract or patch the client's `Interface\GlueXML\GlueParent.xml` and add the include from `GlueParent.include.txt` as a top-level child of the root `Ui` element, directly after the existing `GlueParent.lua` script line.
5. Do not edit `GlueParent.lua` for this step. `GlueParent.lua` is only the Lua script referenced by `GlueParent.xml`.

How the client reads it:
1. The patched `Wow.exe` loads `WotLKExtensions.dll` at startup.
2. `CGlueMgr` registers the breaking-news Lua functions into the GlueXML environment.
3. Your modified `GlueParent.xml` includes `GlueXML\DarkChaos\DarkChaosBreakingNews.xml` as a top-level `Include` under the root `Ui` node.
4. The XML loads `DarkChaosBreakingNews.lua`, which polls `HasBreakingNews()` while the character-select screen is shown.
5. When the server sends packet `1315` during character enumeration, the DLL caches the payload and the Lua driver renders it into `ServerAlertFrame`.

Packaging notes:
- The client still uses normal Blizzard GlueXML loading rules. The patcher only unlocks custom Glue XML edits; it does not auto-load this file for you.
- Because of that, one explicit include in `GlueParent.xml` is still required.
- If you extracted `GlueParent.lua` and do not see any include list, that is expected. The include list lives in `GlueParent.xml`, not in `GlueParent.lua`.
- The safest body format is a short `simplehtml` fragment using tags like `<p>` and `<br/>` plus WoW color codes.