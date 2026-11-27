# HD Character Model Replacement — Root Cause & Ascension Comparison (2026-07-02)

Research triggered by: undead players broken at char select, worgen NPCs with white heads /
missing torsos, **every** NPC A-posing and floating instead of walking (video
`Bildschirmaufnahme 2026-07-02 092134.mp4`).

## TL;DR

Last night's `creature_hyjal_plague` retroport batch packed **raw retail 12.0.7 character models
(MD21, version 274)** into `patch-5.MPQ` at the **stock playable-race paths**
(`character\scourge\male\scourgemale.m2`, `humanmale`, `orcmale`, `trollmale`, `dwarfmale`,
`nightelfmale`, `bloodelfmale`, `scourgefemale` + `_hd`/`_sdr` variants, `.skel`/`.bone` files).
The WarcraftXL *modern-m2* transform makes them render at all — but it was built for **static
housing doodads**: it calls `ZeroBoneLookup()` on every MD21, which re-points all skinned geometry
at the root bone. That alone guarantees the global T-pose/float. Modern texture types and geoset
semantics are untranslated, producing the white/missing parts. Ascension does **none** of this at
runtime — every model in their client is a genuine offline-converted WotLK v264 file.

## Symptom → root cause

| Symptom | Cause |
|---|---|
| Every NPC/player A-posed, floating while moving | `wxl-modern-m2` applies `md21::ZeroBoneLookup` (root-bone skinning, intended to stop static-doodad shadows swinging) to every MD21; animation "compaction" only masks blend time and remaps ids > 505 — no track/bone conversion |
| Undead (players) broken | Stock `Character\Scourge\Male\ScourgeMale.m2` overridden by retail v274 MD21 (7.5 MB vs stock ~1.4 MB) |
| White worgen head, white fluffy undead wrists | Texture slots with modern types **15/16/17/18/19** (and char-composite types 1/8 with no CharSections coverage) — the 3.3.5 client only knows types 0–13, unresolved slots sample white |
| Central worgen body missing | Modern geoset variants driven by retail ChrCustomization; the LK client's hardcoded geoset-group logic (+CharSections/CharHairGeosets) never enables them |
| Breakage varies with Model Detail slider | Only `*00.skin` shipped; LK character models need skin profiles 00–03 |
| `_hd` models can never work | They reference external `.skel` (`scourgemale_hd.skel`) — Legion 7.3+ format, no LK support |

Evidence (parsed binaries):

- user `scourgemale.m2` = **MD21 chunked, v274**, chunks `TXAC AFID LDV1 SFID TXID`, texture slots
  all pathless (types 0/1/2/6/15/16/17/18).
- user `worgenmale.m2` = flattened MD20 (host-transformed), version stamped `0x40000108`
  (264 | 0x40000000 marker), keyBoneLookup=287 (modern), textures type 11/8/2/15–19 + three inlined
  fdid BLPs, skin `boneCountMax=0`.
- user `humanmale.m2` = MD21 v274, 17 MB (all retail customization geosets).
- Source staging: `K:\Dark-Chaos\retailextracts\creature_hyjal_plague\character\{bloodelf,dwarf,
  foresttroll,human,nightelf,orc,scourge,troll}` — raw casc output, never converted. Humanoid
  creature displays resolve to `character\` model paths, and the packer wrote them into patch-5
  verbatim, overriding stock playable-race files.
- Pre-rebuild `patch-5.MPQ.pre-mpq-patch.bak` (01.07 13:04) contains **no** playable-race models —
  the override is new as of the 02.07 01:17 build.
- Worgen/pandaren (from the earlier legiondala-char-fix, see `k:\tmp\legiondala-char-fix\
  README_PACKAGING.md`) are a separate, half-finished down-bake: new paths + CMD rows 500960–63,
  correct approach, but textures/geosets/bones not finished (white head / missing torso / T-pose).

## How Ascension actually does it (measured from `K:\ascension_live`)

Parsed their patches directly (`patch-CHA` characters, `patch-C[A-Z]` creatures A–Z, `patch-Q`
char textures, `patch-M/S/T` DBCs, `patch-TA/TW/TM/U` items, `patch-N` spells, `patch-W*` world):

1. **Everything is offline-converted, genuine WotLK v264.** Their classic-path
   `ScourgeMale.M2` (1.4 MB, WoD-style HD), their modern `scourgemale2.m2` (7.7 MB, 349 seqs,
   239 bones) and their `worgenmale.m2` (Cata source) all parse as clean v264: LK sequence flags
   (0x20 inline / plain external), LK 27-entry keyBoneLookup on classic models, skins with
   `boneCountMax=53` (the LK bone-palette cap), geoset ids remapped into LK groups (≤ 1802),
   texture types only 0/1/2/6/8. **No runtime M2 conversion exists in their client.**
2. **Fur/eye textures are baked to hardcoded type-0 paths** — e.g. worgen carries
   `WORGANMALESKIN_R.BLP` inline, modern scourge carries `scourgemale_hd_<fdid>.blp` — so
   creature-style usage renders textured without CharSections (this is why their worgen heads
   aren't white).
3. **Every model ships its external `.anim` set** with exactly matching basenames
   (patch-CHA alone: 66 M2 + 8,017 `.anim` + 40,911 BLP). Classic-path char models ship skins
   00–03; modern ones ship 00 (their client pins the profile).
4. **Dual model trees + HD DBC overlay.** Classic stock paths hold WoD-style HD conversions
   (drop-in compatible with stock CharSections). Modern models live at NEW paths
   (`Character\<Race>2\...\<race><gender>2.m2`). A parallel DBC set —
   `HDCharSections.dbc` (25,544 rows, WoD `_Extra` textures), `HDCharHairGeosets`,
   `HDCharacterFacialHairStyles`, `HDCreatureModelData` (545 rows re-pointing classic creatures to
   remodeled `basilisk2/gnoll3/kobold2/...` files), `HDCreatureDisplayInfo(+Extra)`,
   `HDHelmetGeosetVisData` — is swapped in by their **patched client** (Extensions.dll; launcher
   HD toggle). They also backported Cata's `CreatureDisplayInfoGeosetData.dbc`.
5. Base DBCs are massively extended: CreatureModelData 35,486 rows, CharSections 42,354 rows,
   AnimationData 1,792 rows (modern anim ids added instead of remapped away).

Bottom line: the HD-toggle plumbing needs their client patches, but the *models* work because they
are fully LK-native files — that part carries over to any 3.3.5 client.

## Recommended path for DC

Unbreak now:

1. **Strip the playable-race trees out of patch-5** (`character\bloodelf|dwarf|human|nightelf|
   orc|scourge|troll\**` and the `foresttroll` raw dump), or restore
   `patch-5.MPQ.pre-mpq-patch.bak` after diffing what else the 02.07 build added. Players return
   to stock models immediately.
2. **Blocklist stock `Character\<PlayableRace>\` paths in the packer/extractor** so no retroport
   batch can ever override them again. Character-model humanoid NPCs must not pull their model
   files; they take the Extra route below.
3. Re-do the Hyjal/Plaguelands humanoid NPCs the already-proven way (see
   `README_PACKAGING.md`): stock 3.3.5 char models + `CreatureDisplayInfoExtra` rows + pre-baked
   body BLPs (aspect-aware bake remap already solved there — square pass-through, 2:1 modern crop
   + CharSections face rebuild).

Finish the worgen/pandaren NPCs (map 1413):

4. Prefer the **Cata-era worgen/pandaren models** as conversion sources (v272, no `.skel`,
   classic texture types/geosets; Ascension itself uses the Cata worgen. Source available locally
   in `MPQ extracts CATA bis SL`). Bake head/fur to type-0 textures, force body geosets to LK
   defaults, convert bones/sequences fully, and **do not run ZeroBoneLookup on them**.

If/when real HD player models are wanted:

5. **Offline conversion only** (Ascension-proven). Tier 1: WoD-style HD models at stock paths —
   CharSections-compatible, works on an unmodified client; ship skins 00–03 and keep stock
   Char* DBCs. Tier 2 (modern models with new customization) = the Ascension architecture:
   `<Race>2` tree + HD DBC overlay + client-side DBC swap in WarcraftXL — a significant project
   (geoset-data backport, DBC store swap hooks, extended AnimationData).
6. Gate `wxl-modern-m2` by path/model class: static world/doodad models only. `ZeroBoneLookup`
   must never touch models with animated bones. Consider refusing (pass-through-fail) `character\`
   paths entirely so a bad payload shows up as invisible instead of half-broken.
7. Hygiene: never ship `.skel`/`.bone`/`_sdr`/`_lod*` retail junk in MPQs; always ship the full
   `.anim` set matching the final model basename.

## Executed 2026-07-02 (same day, follow-up session)

1. **Surgical archive fix** (new tool `wow.export-main/tools/mpq_stormlib_remove.py`):
   patch-5: deleted the 10,161 night-batch files, restored 340 clobbered good files from
   `.pre-mpq-patch.bak`, replayed the 4 afternoon fix runs (all byte-verified). patch-6: deleted 581,
   restored 210. A full-archive M2 scan then removed 46 raw-MD21 **stock-path hijacks** that predated
   the backup (all taxi gryphon variants, wolf, doomguard, felguard, druid flight forms, all shaman
   totems, spells\metamorphosis) plus 121 `.skel`/`.bone` junk — stock models return from the base
   MPQs. Remaining known debt: **196 raw MD21 pet/mount models at custom paths in patch-5**
   (invisible/broken until offline-converted; list = scan output).
2. **Packer guard** (`mpq_stormlib_patch.py`): refuses writes into the 12 stock
   `Character\<Race>\` trees and `.skel/.bone/_sdr/_lod` junk unless `--unsafe`.
3. **Transform gate** (`wxl-modern-m2` shared + host + offline tool, rebuilt & deployed):
   `PathAllowsReshape` refuses `character\` paths entirely (fail-visible); `PathAllowsZeroBoneLookup`
   restricts bone-lookup zeroing to `world\` paths — never again on anything animated.
4. **Hyjal/EPL humanoid NPCs** (`Custom/tools/hyjal_epl_chars/fix_epl_hyjal_char_displays.py`):
   the 31 night-batch displays rewired onto the per-race stock-path CreatureModelData entries
   (501001–501044) + Cata `CreatureDisplayInfoExtra` rows (26 appended, empty BakeName = runtime
   composite; 5 keep their round-3 pre-bakes). Dead `_hd` model rows 501600–501615 dropped.
   All three DBCs recompiled (csv2wdbc) → patch-4 + server dbc.
5. **Worgen/pandaren**: replaced the flattened-DF models with **Ascension's converted Cata/MoP
   models** (2,293 files: 4 × v264 M2 + skins + full `.anim` sets + textures, LOD skins 01–03
   duplicated from 00) at the same paths, and wired `ExtendedDisplayInfoID` for all 15 map-1413
   displays (Extra rows + bakes already existed). CreatureDisplayInfo.dbc redeployed.

Still open: in-game verification pass; re-do the removed Hyjal/EPL *creature* models (firehawk,
Maiev, …) and world doodads through the proper offline converter; convert the 196 raw pet/mount
models; real pre-bakes for any composite NPC that tests white (needed-list:
`K:/tmp/dc_baked_textures_needed.txt`); optional MPQEditor compact of patch-5 (~0.9 GB dead blocks).

## Reference: Ascension patch map (for future archaeology)

| Patch | Content |
|---|---|
| patch-A | interface art, shaders (.bls), login M2s |
| patch-B | signed FrameXML/lua overrides (.sig/.pub) |
| patch-CHA | HD character models (66 M2, 8k anim, 41k BLP; classic paths + `<Race>2` tree) |
| patch-C[A-Z] | HD creature models, alphabetical by folder |
| patch-Q | additional character section textures (31k BLP) |
| patch-M / S / T | DBC sets (288 / 48 / 1 — later letter wins) |
| patch-N | spell visuals (28k files) |
| patch-O | sound + textures |
| patch-R | HD tilesets/textures (15k BLP) |
| patch-TA/TW/TM/U | item models (weapons etc.) |
| patch-V | more creatures (+ `.bone` files — their client tolerates modern aux formats) |
| patch-WA/WB*/WC*/Z | world: ADT/WMO/doodads |
| patch-P | encrypted (protection/anticheat payload) |

Analysis scripts kept in this session's scratchpad (`mpq_survey.py`, `mpq_extract.py`,
`m2_inspect.py`, `dbc_peek.py`) — trivially recreatable with `mpyq`; extracted samples under
`samples\{user,userbak,asc}`.

---

## Correction + completion (2026-07-02, evening): white NPCs = missing baked textures

The "Executed 2026-07-02" section above wired the Hyjal/EPL humanoid displays to stock char
models + Cata `CreatureDisplayInfoExtra` rows with an **empty BakeName**, on the belief that the
3.3.5 client composites NPC bodies at runtime from CharSections. **That belief is wrong.** The
client composites PLAYERS only; an NPC's body texture comes exclusively from
`BakeName -> Textures\BakedNpcTextures\<name>.blp`, and an empty BakeName renders an untextured
white body. Blizzard's own data proves it: the only stock Extra rows with an empty BakeName are
Male Ghost / Female Ghost — white-on-purpose. Confirmed live the same evening (the whole batch
rendered as white "ghosts" on maps 750 and 751 once the day's crash fixes finally let the zones
load at all).

**Fix (deployed + user-confirmed):** all 298 batch Extra rows (293 normal-race + 5 worgen)
resolved to their original Cata BakeNames (`CreatureDisplayExtra-<ID>.blp` — every one present in
`K:\Cata`'s art.MPQ; BLP2 DXT1 256x256, drop-in for 3.3.5, zero conversion). Packed to patch-4 at
`Textures\BakedNpcTextures\`, BakeName set in `CreatureDisplayInfoExtra.csv` (+ both
`.additions.csv` copies synced), dbc recompiled and deployed to patch-4 + server dbc. Covers
Hyjal 750 (143 templates / 1,263 spawns) and Plaguelands 751 (137 / 5,150) in one pass.
Ascension cross-check: their patches ship 20k+ `BakedNpcTextures` files — nobody runtime-composites.

**Durable tooling:** `Custom/tools/npc_bakes/harvest_cata_npc_bakes.py` (find empty-BakeName rows
-> resolve via Cata dbc -> extract BLPs via StormLib -> setfile + CSV apply; rows that are empty
in Cata too, e.g. ghosts, are correctly skipped). `fix_epl_hyjal_char_displays.py` corrected to
carry BakeName through on append so a re-run can no longer regress this.

**Related same-evening work:** the Hyjal login crash was a client engine bug (41 methods reading
`this+0x10` with no null check when a texture layer's ground-effect ID has no
`GroundEffectTexture` row — fixed via Wraith `NullThisGuard` detours). The 16 of 81 missing
ground-effect IDs with authentic Cata data were restored end-to-end: rows added to
`GroundEffectTexture.csv` (the 39 referenced `GroundEffectDoodad` rows already existed with legacy
`.mdl` names the client auto-remaps to `.m2`), models baked MD21->MD20 via wxl-baker from retail
`world/nodxt/detail/` and packed to patch-6 at `World\NoDXT\Detail\`, dbc recompiled -> patch-4 +
server. The Wraith `wxl-modern-groundeffect` host module injects the same rows at serve time but
skips IDs present in the base file, so it is now a no-op safety net. The remaining 65 missing
ground-effect IDs have no known source (absent from both 4.3.4 and current retail) and stay bare.
