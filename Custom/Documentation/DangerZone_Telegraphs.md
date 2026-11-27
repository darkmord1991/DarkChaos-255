# Danger-Zone Telegraphs (client-side AoE ground indicators)

Client-side, data-driven ground-AoE telegraphs for the DC client. When a unit
casts a spell that matches a **DangerZoneVisualProfile**, the client draws a
danger indicator at the cast's target location. Ported (conceptually) from
dusk-tswow's `DangerZoneVisuals`, but re-architected for DC's client (which runs
the **WarcraftXL** modern-render backport — see step 3).

Everything lives in the **WotLKExtensions** client DLL
(`K:\Dark-Chaos\dc-wotlkextensions\WotLK-Extensions\WotLKExtensions`).

## Status

| Step | What | State |
|---|---|---|
| 1 | Typed `DangerZoneVisualProfile` CDBC (def + loader + Lua getter) | ✅ done, deployed |
| 2 | Spell-packet reader (identify matching casts, log) | ✅ done, deployed, verified |
| 3 | Render the telegraph at the cast location | ✅ done — Lua projected ring (`DC-DangerZone` addon) |
| 4 | Retail-style textured decals, inside-zone warning, options panel | ✅ done 2026-09-14 — `DC-DangerZone` 2.0 (see "Addon 2.0" below) |

## Data model — DangerZoneVisualProfile CDBC

Typed CDBC, mirroring the `DCMythicPlusAffix` pattern. Gated behind
`DANGERZONEVISUALPROFILE_DBC` (CMake option; **keep OFF until the `.cdbc` is
packed** — `CDBC::LoadDB` fatally crashes the client on a missing file).

- Row struct: `DangerZoneVisualProfileRow` in `src/Data/Structs.hpp` (15 columns,
  60-byte rows). Column order **must** match the `.cdbc`:
  `id, schoolMask, shapeMask, flags, modelPath(str), modelRadius, radiusScale,
  zOffset, minDurationMs, maxDurationMs, red, green, blue, alpha, debugSpellId`.
- Def class: `src/CDBCMgr/CDBCDefs/DangerZoneVisualProfile.{hpp,cpp}`.
- DataContainer wiring: `Load/Unload/GetRow/GetRows/Revision` +
  `m_dangerZoneVisualProfileCDBC` singleton.
- Load call (the safety gate): `CDBCMgr::Load()` under
  `#if DANGERZONEVISUALPROFILE_DBC`.
- Lua getter: `GetDangerZoneVisualProfiles()` → array of profile rows (empty until
  loaded). Registered unconditionally; returns `{}` when the CDBC is off.

### Authoring the `.cdbc`

Generator: `scratchpad/gen_dangerzone_cdbc.py` (WDBC format: `'WDBC'`, numRows,
numFields=15, rowSize=60, stringTableSize, rows, string table). The test file
keys `debugSpellId` to the **high-rank** ids a Mage actually casts (each spell
RANK is a distinct id — rank-1 133/116 never fire at level cap): Blizzard
`42938`/`42940` (ground-targeted → dest ring), Frostbolt `42842`, Fireball
`10151`. `modelPath` empty (unused by the Lua render).

Canonical source + staging (packed into **patch-4.MPQ** like the other CDBCs):
- `Custom\CDBCs\DangerZoneVisualProfile.cdbc`
- `Custom\CDBCs\DangerZoneVisualProfile.cdbc` (deployed to patch-4)

Matching is by `debugSpellId` for now (exact spell id). Production would match by
`schoolMask`/`shapeMask` (needs a Spell.dbc school lookup) instead.

## Step 2 — packet reader

`src/Client/DangerZoneVisuals.cpp`, gated behind `DANGERZONE_PATCH`.

- MinHook prologue detour on the stock spell-launch handler **`0x80FEE0`** (DC also
  wraps it as `CNetClient::PacketGroupSpellLaunch`, confirming the address).
- Reads the cast **non-destructively** (saves/restores `CDataStore::m_read`;
  fixed-prefix parse of two packed GUIDs + castId + spellId via the client's own
  `0x76DC20` reader — no variable-length loops, no OOB risk), then **always calls
  the original handler**, so spell processing is untouched.
- If the cast's `spellId` matches a profile's `debugSpellId`, writes
  `[DangerZone] SPELL_GO spellId=… matched profile id=…` to the DLL log
  (`K:\WoW_3.3.5a_ 255 Fun\DLL_Logs\<timestamp>.txt`).

MinHook is vendored (`Wraith/deps/minhook`) and pulled into the build when
`CHILDCLIPPING_PATCH OR DANGERZONE_PATCH` (see CMakeLists). `__cdecl` target →
`__cdecl` detour, MinHook trampoline as the original.

### Verified

`GetDangerZoneVisualProfiles()` returns `2` with both flags on and the `.cdbc`
packed; no crash. (Log-line confirmation of a live cast: pending.)

## Step 3 — render (Lua projected ring)

### Why NOT dusk-tswow's M2 render, and NOT WarcraftXL

- **dusk-tswow's stock-M2 render would crash this client.** It writes `flags |= 0x8000`
  at `model+0x10` and a 64-byte matrix at `model+0xB4` and calls stock render funcs
  (`CM2Scene_CreateModel 0x81F8F0`, `RenderModelCreateWorldObject 0x781A10`,
  `World_ObjectUpdateRaw 0x780240`). DC's client runs **WarcraftXL**, a modern-M2
  backport with a **different model layout** (`Wraith/src/offsets/game/M2.hpp`:
  `M2Model.flags` @ 0x08, `header` @ 0x150, `pathStem` @ 0x3C — dusk-tswow's `+0xB4`
  write lands in WarcraftXL's `pathStem`). Blind port → corruption → crash (the
  shelved-ChildClipping failure class).
- **WarcraftXL can't be driven from WotLKExtensions.** A source survey confirmed:
  `wxl-modern-groundeffect` is only terrain grass/clutter (a DBC transform in the
  64-bit asset host, no runtime API); `WarcraftXL.dll` exports only a no-op anchor,
  no scene/model/decal API, no shared interface, and its only IPC is a client-side
  file-serving channel. Rendering via WarcraftXL would mean writing a new module
  *inside* WarcraftXL.dll — a 2-project effort with raw M2-spawn RE. Rejected.

### Chosen approach — project the world circle to screen (safe, no render RE)

The DLL never touches the render engine. Instead it hands the active telegraphs to
Lua, and a Lua addon draws the ring by projecting the AoE circle's world-space
circumference to screen with the **proven** `ConvertCoordsToScreenSpace` native
(the same one the ping system uses). Perspective-anchored to the ground, zero
crash surface, no WarcraftXL conflict.

**DLL (`DangerZoneVisuals.cpp`, `DANGERZONE_PATCH`):** on a matching cast, resolve
the caster's live world position via `ClientServices::GetObjectPtr(guid,
TYPEMASK_UNIT|PLAYER)` + `m_movementInfo->m_position` (the nav/tooltip code's
pattern) and buffer a zone `{spellId, x,y,z, radius, rgba, expireTick}` (deduped by
caster^spell, capped at 32, `GetTickCount`-timed). Radius = `modelRadius*radiusScale`
clamped to [5,60] yd; duration = `maxDurationMs` or 5 s default. Exposed via the
`GetActiveDangerZones()` native → array of
`{spellId, x, y, z, radius, r, g, b, a, remaining}` (expired dropped on read).
> v1 uses the CASTER position (minimal, OOB-safe parse). Ground-targeted
> (dest-location) AoE would need the full `SpellCastTargets` parse — a future
> enhancement.

**Addon v1 (superseded by 2.0 below, kept as the "classic" style):** an `OnUpdate`
(~33 Hz) polls `GetActiveDangerZones()`; for each of up to 4 zones it projects 32
points around the world circle via `ConvertCoordsToScreenSpace` (culling points
behind the view plane by depth), converts to UIParent-center offsets exactly like
`PingSystem.ResolveWorldScreenOffsets`, and places additive dots along the ring,
tinted by the profile color and faded over the last 1.5 s. `/dz on|off|status`.

## Addon 2.0 — retail-style decals (2026-09-14)

`Custom\Client addons needed\DC-DangerZone` was rewritten as three files
(`Core.lua`, `Render.lua`, `Options.lua`) plus a `Textures\` folder. It still
needs nothing from the DLL beyond `GetActiveDangerZones()`,
`ConvertCoordsToScreenSpace()` and (for the inside warning)
`ResolveEntityPositionByGUID()`.

### How a textured ground decal is drawn in pure Lua

A UI texture is always an axis-aligned rectangle on screen, so the ground square
around a zone (a trapezoid in perspective) cannot be one texture. `Render.lua`
draws it as a stack of **camera-aligned strips**:

1. At the zone centre, project `C`, `C+x̂` and `C+ŷ` to find the world direction
   that projects horizontally (camera-right, `r`) and its perpendicular
   (camera-forward, `f`). Points along `r` share a depth, so lines along `r`
   are exactly horizontal on screen (the camera never rolls).
2. Cut the square `C ± R·r ± R·f` into K strips across `f` (6 / 10 / 16 by the
   quality setting). Each strip's near and far edges project to horizontal
   lines, so its bounding box is a plain rectangle.
3. Use the 8-argument `SetTexCoord` to map the texture onto that rectangle so
   the strip's four projected corners land on the right texels (exact at the
   corners; the error inside a thin strip is invisible). Corners of the
   rectangle that lie outside the trapezoid sample outside the square — which
   is why the shipped textures are padded (next section).
4. Strips whose corners fall behind the camera are skipped individually, so a
   zone half behind the camera still shows its near half. If no strip projects
   at all the classic dotted ring is drawn instead.

Layers per zone (separate frames, ascending frame level): fill → progress disc
(grows from the centre as `remaining/total` runs out) → edge ring → animated
overlay (reticle/swirl, spins at `spinSpeed`) → classic dots → countdown label.

### Textures

`Textures\dz_*.blp` are **retail spell decals** extracted from the CASC client
(`spells/t_vfx_ring_aurad`, `spells/8fx_ringthick_a`,
`spells/whitering_double_soft`, `spells/whitering_glow`,
`spells/8fx_targetground_mask`, `spells/t_vfx_swirl64_a`) and re-encoded by
`Textures\build_dz_textures.py`: the visible content is cropped to its bbox and
scaled so the circle's outer edge sits exactly at `[0.15, 0.85]` of a 512×512
DXT5 BLP2 with full mips. The addon maps the world square `[-R, R]` onto that
`[MARGIN, 1-MARGIN]` range, so the ring lands on the true radius and any
out-of-square sampling hits transparent margin instead of wrapping into
visible texels. `TEXTURE_MARGIN` in `Core.lua` must match `MARGIN` in the
script. To add a texture: extract with
`node tools/casc-extract.js get --install <retail root> --id <FileDataID>`,
then `python build_dz_textures.py <outdir> name=<source.blp>`.

A profile's `modelPath` may name a `.blp`/`.tga` instead of an M2; the addon
then uses it as that spell's fill texture (padded convention only for paths
inside `Interface\AddOns\DC-DangerZone\`, edge-to-edge otherwise).
`maxDurationMs` is the total used for the progress disc.

### Settings and commands

`DCDangerZoneDB` (per character) holds: `enabled`, `style`
(`retail`/`classic`/`both`), `fillTexture` (`glow`/`disc`/`none`),
`edgeTexture` (`ring`/`double`/`none`), `spinner` (`reticle`/`swirl`/`none`),
`spinSpeed`, `fillOpacity`, `edgeOpacity`, `spinnerOpacity`, `additive`,
`quality` (1–3), `maxZones`, `showTimer`, `showProgress`, `warnInside`,
`warnSound`, `warnFlash`, `fadeSeconds`, `fadeInSeconds`. All are exposed under
Interface → AddOns → **DC DangerZone**.

`/dz` (or `/dangerzone`): `on|off|status|config|reload`, `style <name>`,
`test [radius] [seconds]` (spawns a Lua-only test zone at your feet — no
matched spell needed), `clear`.

While the player's 2D distance to a zone centre is within its radius the edge
pulses, the `LowHealth` full-screen vignette flashes and the raid-warning sound
plays (once per entry, then every 2.5 s). The driver polls the native at 10 Hz
when idle and 40 Hz while zones are active.

Regression test: `Custom\Client addons needed\_tests\test_dangerzone.lua`
(`sh run.sh` from `_tests`).

## CMake flags

| Flag | Default | Effect |
|---|---|---|
| `DANGERZONEVISUALPROFILE_DBC` | OFF | Loads `DangerZoneVisualProfile.cdbc` (needs the file packed, else fatal) |
| `DANGERZONE_PATCH` | OFF | Installs the spell-packet reader detour (step 2) |

## Activation / test

1. Pack `DangerZoneVisualProfile.cdbc` into `patch-4.MPQ` (`mpq_stormlib_pack.py`).
2. Rebuild with both flags on + deploy:
   `cmake -DDANGERZONEVISUALPROFILE_DBC=ON -DDANGERZONE_PATCH=ON <build>` →
   `cmake --build <build> --config RelWithDebInfo --target copy_files --parallel`.
3. Sync the **`DC-DangerZone`** addon (`Custom\Client addons needed\DC-DangerZone`)
   into the client's `Interface\AddOns\` and enable it (the render layer; include the `Textures\` folder).
4. Full client restart (MinHook installs at process start; not via `/reload`).
5. Verify:
   - `/run print(#GetDangerZoneVisualProfiles())` → `2` (CDBC loaded).
   - `/dz status` → `native=yes`.
   - Cast **Blizzard** (ground-targeted) → an icy **ground ring** appears at the
     **targeted impact** (dest location) for ~5 s and fades; cast **Frostbolt** /
     **Fireball** → a ring at the caster. `[DangerZone] matched …` lands in the newest
     `DLL_Logs\*.txt`, and `/run print(#GetActiveDangerZones())` is `>0` briefly after
     casting.
   - Profiles are keyed by exact per-rank `debugSpellId`; re-key the `.cdbc` to
     whatever spells you want to telegraph (a real deployment would list all ranks
     or match by school/shape instead of `debugSpellId`).

⚠️ Order matters: pack the `.cdbc` **before** enabling `DANGERZONEVISUALPROFILE_DBC`.
