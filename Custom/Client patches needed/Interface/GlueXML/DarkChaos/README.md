DarkChaos breaking news Glue package notes

Current branch status:
- The canonical, working package on this branch is the root `GlueParent.lua` / `GlueParent.xml` pair under `Interface\GlueXML\`.
- The live probe marker for that path is currently `dc-breakingnews-glueparent-ui-2026-05-09-r4`.
- The files in this `DarkChaos\` subfolder are retained as legacy sidecar reference material. Do not treat the sidecar include path as the primary deployment path unless you are intentionally maintaining the older setup.

Canonical install steps:
1. Build WotLK-Extensions with `CUSTOMPACKETS_PATCH=ON` and `GLUEMGREXTENSION=ON`.
2. Patch the exact `Wow.exe` you launch with `Patcher.exe` and copy `WotLKExtensions.dll` next to `Wow.exe`.
3. Deploy the checked-in root Glue files from this repo to the client:
	- `Interface\GlueXML\GlueParent.lua`
	- `Interface\GlueXML\GlueParent.xml`
4. Keep this `DarkChaos\` folder only as legacy/reference material unless you are explicitly shipping the old sidecar include path as well.

How the current branch reads it:
1. The patched `Wow.exe` loads `WotLKExtensions.dll` at startup.
2. `CGlueMgr` registers the breaking-news Lua functions into the Glue environment.
3. The root `GlueParent.lua` owns the `DCBreakingNews_*` runtime callbacks, UI state, and probe package version.
4. The root `GlueParent.xml` calls `DCBreakingNews_OnUpdate(elapsed)` from the global Glue `OnUpdate` hook.
5. When the server sends packet `1315` during character enumeration, the DLL caches the payload and the GlueParent-side logic renders it once character select is active.

Legacy sidecar notes:
- `DarkChaosBreakingNews.xml`, `DarkChaosBreakingNews.lua`, and `GlueParent.include.txt` reflect the older sidecar include design.
- They are useful as reference material, but the working/probed path on this branch no longer depends on adding `GlueXML\DarkChaos\DarkChaosBreakingNews.xml` as the primary load path.
- If you do keep the sidecar path alive in a custom client build, do not let it drift away from the root `GlueParent.lua` implementation.

Packaging notes:
- The safest body format is a short `simplehtml` fragment using tags like `<p>` and `<br/>` plus WoW color codes.
- The upstream `mod-breaking-news-override` note about escaping `[`, `]`, `'`, and `\` does not apply to this implementation. Here the server sends binary packet cstrings and the client reads them directly, so those characters do not need transport escaping.
- Practical limits in this implementation are: stay within WoW `SimpleHTML` compatibility, avoid embedded NUL bytes, and follow normal config-file quoting rules for `DC.BreakingNews.Title`.

Validation gates:
- Install the `DCPatchApiProbe` addon from the WotLK-Extensions repo and run `/dctest news` after logging through character select.
- Expected success markers include `payload=true`, `glueLoaded=true`, `glueApplied=true`, and a `gluePackage` string matching the deployed GlueParent package version.