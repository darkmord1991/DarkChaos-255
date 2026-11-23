# Worgoblin client deploy — reconstructed from the live archives (2026-08-27)

`Custom/Worgoblin/` (DEPLOY.md, staged `dbc/`, `deploy/*.setfile`) has been deleted a second
time and is **not** in the recycle bin (all `$I*` metadata records scanned, zero hits). This
document is the replacement, rebuilt by reading the deployed state back out of
`K:\WoW_3.3.5a_ 255 Fun\Data`. It lives here because this folder is git-tracked and has
survived both deletions.

## Where everything actually is now (verified by archive probe)

The July layout ("everything worgoblin in patch-9") **no longer holds**. The deploy was
consolidated into the shared pipelines, and patch-9 was repurposed:

| Asset | Live location | Note |
|---|---|---|
| `Character\Worgen\*` models | **patch-7.MPQ** | the HD-character patch absorbed them |
| `Character\Goblin\*` models | **patch-7.MPQ** | shadows the stock Cata goblin in common-2 |
| Race DBCs (`ChrRaces`, `CharSections`, `CharBaseInfo`, …) | **patch-4.MPQ** (root) | |
| Same DBCs, locale shadow | **patch-enGB-3.MPQ** | enGB shadows DBCs — this copy is what the client reads |
| Create-screen GlueXML (`Interface\GlueXML\CharacterCreate.lua/.xml`, `GlueStrings.lua`) | **patch-enGB-3.MPQ** | `MAX_RACES = 12` confirmed in the winning copy |
| Racial icon atlas `Interface\Glues\CharacterCreate\UI-CharacterCreate-Races.blp` | **patch-5.MPQ** | |
| `patch-9.MPQ` | **repurposed** — 11,180 `world\` files (Lordaeron/WMO art for the map-751 build) | contains zero worgoblin files |
| Worgen sound (`Sound\Character\Worgen\…`) | **nowhere** | never deployed (or lost); worgen emotes are silent |

## Consistency state (md5-verified 2026-08-27)

- `ChrRaces.dbc`, `CharBaseInfo.dbc`: **identical** across patch-4, patch-enGB-3,
  `Custom/DBCs/` (staging) and `Server/data/dbc/`. Fully coherent.
- `CharSections.dbc`: patch-4 == enGB-3 == `Custom/DBCs` (21,924 rows, max id **911363** —
  includes the ~11k HD-harvest rows at 900000+). `Server/data/dbc` copy is older (10,988 rows)
  but every shared row matches on all non-string fields, and the server ignores texture
  strings — benign. 17 server-only low-id rows are also benign.

## The deploy recipe (what a new race port must replicate)

1. Character art → a **dedicated patch slot** (Pandaren: patch-I; do not co-tenant).
2. Race DBCs → edit `Custom/DBCs/` (authoritative staging), then deploy the same bytes to
   the root DBC patch (patch-4) **and** mirror into **patch-enGB-3** — the enGB copy wins;
   a stale mirror is what produced "Too many races!" in July.
3. The **Linux worldserver's** dbc dir gets the same DBC edits (server validates race/class/
   appearance at create). `K:\Dark-Chaos\Server\data\dbc` is NOT server truth (user-corrected
   2026-07-09) — hand the user the built files instead; local reads of it are reference-only.
4. GlueXML (`CharacterCreate.lua/.xml`, `GlueStrings.lua`) → **patch-enGB-3 only** (locale
   archive; root copies of GlueXML are not read for enGB clients).
5. Racial icon atlas → patch-5 (or the new race's own patch; atlas coordinates in
   CharacterCreate.lua must match).
6. Rebuild worldserver after `SharedDefines.h` race-enum change; apply the SQL set.
