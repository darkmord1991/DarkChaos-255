> Part of the 2026-07 DC audit round. Consolidates `DC/CrossSystem/CENTRALIZATION_MIGRATION_PLAN.md`'s
> existing backlog with everything the audit newly surfaced, and marks what Wave 3 actually did.
> See `AUDIT_MASTER_SUMMARY.md` for the overall wave log.

# CrossSystem Centralization Backlog

## Done this round (Wave 3)

| Plan item | What shipped |
|---|---|
| **A1** | `DC::DbSchema`'s 4 helpers rewritten from wildcard `SHOW ... LIKE` to exact-match `information_schema` queries. Call-site migration to `DC::DbSchema` for the two clearest duplicates (`QOL`/`AddonExtension` aoeloot schema probes, `dc_addon_collection.cpp`'s own re-declared helpers) was **not** done this round — see "Still pending" below. |
| **B1** | Deduplicated `CrossSystemWorldBossMgr.cpp`'s same-file duplicate DBC zone-name lookup into one local static helper (kept local, not promoted to a tree-wide `DCUtils::GetZoneName` — that helper doesn't exist yet, see "New, not yet in plan"). |
| **B4** (leaf utils) | 5 files repointed to already-centralized `DCUtils` helpers: `QOL/dc_breaking_news_qol.cpp` (timestamp), `QOL/dc_aoeloot_unified.cpp` (CSV parse/join), `Progression/FirstStart/dc_firststart.cpp` (id-list parse, preserving its 0-drop behavior), `HinterlandBG/BattlegroundHLBG.cpp` (CSV parse), `Commands/cs_dc_hinterland_bg.cpp` + `Commands/cs_dc_addons.cpp` (ToLower, 5 of 6 candidate sites — 1 false positive correctly skipped, see below). |
| **B6** (partial) | Deleted dead `hlbg_constants.h::GetLegacyAffixName`. Collapsed 3 overlapping weather-name tables (`GetWeatherName`, `GetExtendedWeatherName` in `hlbg_constants.h`, and `hlbg_scoreboard_npc.cpp`'s own `GetWeatherDisplayName`) into 1 canonical function with a parameterized out-of-range default. **`GetAffixName` itself was NOT migrated to the CrossSystem registry** — confirmed architecturally blocked, see "Explicitly blocked" below. |
| **C1** | `CrossSystemRewards.h`'s `AwardItemOrSeasonalCurrency` non-seasonal fallback now routes through `RewardDistributor::DistributeItem` (mail-on-full-bag) instead of bare `AddItem`. Also applied the identical fix independently to `Seasons/SeasonalRewardSystem.cpp`'s `AwardCurrency` (Wave 2b) and `GiantIsles/dc_giant_isles_invasion.cpp`'s war-token grant (Wave 2). |
| **C5** | Collapsed 4 duplicate `SECONDS_PER_WEEK`-equivalent literals onto `DarkChaos::Seasons::SECONDS_PER_WEEK`: `CrossSystem/SessionContext.cpp`, `GreatVault/GreatVault.cpp`, `AddonExtension/dc_addon_mythicplus.cpp` (3 separate literals in that one file), and `Seasons/DCWeeklyResetHub.cpp`'s own producer file (which wasn't even using its own exported constant). `dc_addon_welcome.cpp` was checked and found to already be correct (false positive, correctly skipped). |

## Still pending — explicitly blocked or requires a decision, NOT applied

| Item | Why it's blocked |
|---|---|
| **B6 core** — `hlbg_constants.h::GetAffixName` → `CrossSystem::Affixes::GetName` | **Architecturally blocked, confirmed by re-reading the code before dispatching any fix.** `hlbg_constants.h` compiles into the `game` static library (via `BattlegroundHLBG.h`), which cannot include the `CrossSystem/` header chain — the file's own existing comment already documents this. Do not attempt this migration without first restructuring the compile boundary (e.g. extracting affix names into a header with no CrossSystem dependency, or moving `BattlegroundHLBG.h` off the `game` lib). |
| **C3** — two overlapping "single source of truth" season resolvers | `SeasonResolver.h` vs `CrossSystemSeasonHelper.h` disagree on lookup order, config default (1 vs 0), and DB column (`season_state` vs `is_active`). The Seasons+GreatVault review additionally found the dead `SeasonalSystem.cpp` lifecycle engine (now wired, not dead — see Wave 2b) is a root contributor to the resolver sprawl. **Needs a design decision on which resolver + column becomes canonical** before any code changes — not mechanical. |
| **C4** — `RewardDistributor::GetWeeklyCapStatus` stub returns "unlimited" | Raised independently by both the CrossSystem and Seasons+GreatVault reviews. Needs actual weekly-cap design/DB work (what the cap should be, where it's configured), not a mechanical fix. |
| **CrossSystem Adapters/DCSystem layer** — entirely dead (`RegisterAllAdapters` is a no-op, `CrossSystemManager::RegisterSystem` never called) | Needs a product decision: wire the adapters up for real cross-system coordination, or delete the whole DCSystem base + adapter classes + capability/priority enums. Not attempted — a 50/50 call between "finish a feature" and "delete ~400 lines of scaffolding" that isn't this audit's to make. |
| **B2** — HLBG-vs-leaderboards duel/seasonal-stats SQL divergence | `dc_addon_hlbg.cpp` and `dc_addon_leaderboards.cpp` both own overlapping stat-fetch SQL with genuinely diverging winrate math and a `wins>0` filter difference. The migration plan itself flags this needs a behavior decision (which math is "correct") before the two paths can be merged into one `LeaderboardUtils` fetcher — not mechanical. |
| **B3** — generalize 4 hand-rolled account/player-keyed caches into one `DarkChaos::Cache` template | Evaluated as this round's one Wave-4 candidate; **decision: not applied**. All four caches (`Progression/Accountwide` ×3, `Progression/Prestige/dc_prestige_system.cpp`, `DungeonQuests/DungeonQuestHelpers.h`) are individually correct after Wave 2b's targeted mutex fix on the one with a real race. Remaining duplication is pure DRY, not a bug — a generic-template refactor across 5 files carries more risk than benefit right now. Good candidate for a dedicated, narrowly-scoped future pass. |
| **A2** — `DCUtils::MakeLargeGossipText` adoption | Plan already lists ~9 files (AC flightmasters/guard, Jadeforest, HinterlandBG, DungeonQuests, GuildHousing) that hand-roll gossip text formatting instead of using the centralized helper. Not attempted this round (cosmetic/text-formatting only, no bug; large file-count for the value delivered). `DungeonQuests/npc_universal_quest_master.cpp` was newly confirmed as another site needing this by the Part 2 backlog pass. |
| **A3** — `DC::MapCoords::SendPoiMarker` adoption | Plan lists `AC/ac_guard_npc.cpp` and `GuildHousing/dc_dalaran_guard.cpp` as not yet using the shared POI-marker helper. Not attempted (same reasoning as A2). |

## Addon-layer centralization — `DCAddon::Utils` (done, follow-up to this round)

The CrossSystem work above centralizes the *general* C++ scripts. The AddonExtension layer
got the same treatment in a follow-up pass, because it's the biggest subsystem and had its own
cluster of copy-pasted leaf helpers with no shared home. Key finding first: the addon layer
already had *more* shared infrastructure than the C++ scripts did —
- **Client side is already centralized**: `DC-AddonProtocol` (`DCAddonProtocol.lua` +
  `DCCentral.lua`) is a shared Lua library every feature addon depends on (transport, JSON,
  module/opcode registries, capabilities).
- **Server side already had the *machinery***: `dc_addon_namespace.h` (2,435 lines) owns the
  protocol — Module/Opcode registries, `JsonValue`, `Message`/`MessageRouter`, async DB,
  transport negotiation.
- **What was missing** was the server-side *leaf-utility* layer — the addon analog of
  `DCUtils`/`CrossSystemUtilities.h`. Added as **`AddonExtension/dc_addon_utils.h`**
  (`namespace DCAddon::Utils`, header-only, mirroring the `CrossSystemDbSchema.h` inline-static
  pattern — no CMake/loader wiring needed).

Consolidated onto it:
| Helper | Was | Now |
|---|---|---|
| `EscapeSql` | 2 hand-rolled copies that *disagreed* (backslash vs `''`-doubling) in `dc_addon_protocol.cpp`, `QOL/dc_aoeloot_unified.cpp` | one canonical backslash escaper; aoeloot gains the stronger escaping |
| `AppendUnsigned/Signed/Floating JsonNumber` + `AppendJsonKey` | 3 copies (`dc_addon_collection.cpp`, `dc_addon_wardrobe.cpp`, `cs_dc_stresstest.cpp`) | single impl; call sites keep local names as thin forwarders |
| `ClassCanTank`/`ClassCanHeal` (class→role **capability**) | 2 genuine copies (`dc_addon_matchmaking.cpp` + an inline block in `dc_addon_groupfinder.cpp`) | one shared pair |
| `GetDungeonNameByMapId` | 5 ad-hoc lookups across **3 different tables** | one cached helper reading the authoritative **`dc_dungeon_setup`** (50-row superset; name-parity with `dc_mplus_dungeons` verified for the 16 M+ dungeons). Migrated the clean cases (spectator, portal_selector). |
| Prestige `MODULE`/`Opcode` constants | hand-copied literals in `dc_addon_prestige.cpp` | aliased to the canonical `DCAddon::Module::PRESTIGE` / `DCAddon::Opcode::Prestige` (drift-proof) |

Deliberately **left as-is** (not the same problem, would not be behavior-preserving):
- `dc_addon_groupfinder.cpp`'s dungeon cache and `dc_addon_leaderboards.cpp`'s cache do
  double-duty (M+ available-list building + `season_enabled` filtering / season-scoped featured
  set) — not pure name lookups.
- `dc_addon_mythicplus.cpp`'s 3 dungeon-name resolutions are inline SQL `JOIN`s enriching a
  result set, not standalone helper duplication — the JOIN is a legitimate, efficient pattern.
- `GuessLeaderRoleMask` (`groupfinder_mgr`) and `CrossSystemVaultUtils::GetPlayerRoleMask` are
  **current-spec role** (talent/spec based), a genuinely different concept from the static
  **class capability** that was consolidated — merging them would change behavior. Documented
  in the header so the distinction is explicit.

Still open on the addon layer (follow-up backlog): the **client↔server registry drift** (client
`DC.Module`/`DC.Opcode` are hand-copied from the server header and have drifted — client is
missing `NPCMOVE`/`DECORATION`/`GRAVEYARD`/`BEASTMASTER`); and the `N-*` addon items below
(dungeon-name in the remaining double-duty callers, role logic reconciliation, etc.).

## New backlog items surfaced by this audit round (not previously in the plan)

- **N-EscapeSql** — hand-rolled SQL-escape duplicated in exactly 2 files (`dc_addon_protocol.cpp`'s `EscapeSQLString`, `dc_aoeloot_unified.cpp`'s `EscapeSqlString`) — smaller footprint than an earlier "17 files" estimate, which conflated this with files correctly calling the engine's built-in `EscapeString` (those are fine, not duplication). Target: a new `DCUtils::EscapeSql()` sibling to the already-centralized `EscapeJson`/`EscapeFmtBraces`.
- **N-DungeonNameLookup** — dungeon-id→name resolution reimplemented independently in 4 files (`dc_addon_spectator.cpp` — fixed with its own local cache this round; `dc_addon_groupfinder.cpp`, `dc_addon_leaderboards.cpp`, `dc_mythicplus_portal_selector.cpp` — not consolidated). Consolidating into one CrossSystem cached lookup remains open.
- **N-CollectionCache** — `CollectionCore.cpp`'s dead `PlayerCollectionCache` hand-rolls the same shape `DarkChaos::Cache::PlayerCache<V>` already provides — natural B3-family extension if/when B3 is revisited, but the cache itself is unreachable dead code today (see Part 2 findings #8).
- **N-PhaseAllocator** — two independent per-player phase-bit allocators solving the same problem: `Jadeforest/jadeforest_training_grounds.cpp`'s `PERSONAL_PHASE_BITS`/`EnsurePlayerPersonalPhase` vs `PhasedDuels/dc_phased_duels.cpp`'s `FindFreePhase`/`sUsedPhases`. Risk of phase-bit collision if uncoordinated; no shared helper exists yet.
- **N-TeleportMenus** — one-off gossip teleport menus (`Jadeforest/jadeforest_guards.cpp`, `AC/ac_guard_npc.cpp`) duplicate the generic DB-driven `Teleporters/dc_teleporter.cpp`'s hierarchical menu + faction/security filtering + reload command.
- **N-MountHyjalRangeShim** — `GetPlayersInRange`/`MoveSmoothPath` grid-search + spline shims duplicated 3× (MountHyjal ×2) and inlined again in `PhasedDuels/dc_phased_duels.cpp`.
- **N-CapabilityRoleLogic** — class→role capability logic (`ClassCanTank`/`ClassCanHeal` in matchmaking, groupfinder's role-validation block, `GuessLeaderRoleMask`) copied 3× — candidate for a capability-based sibling of `CrossSystemVaultUtils.h`'s `GetPlayerRoleMask`.
- **N-JsonNumberEmitters** — manual JSON-number emitters (`AppendUnsignedJsonNumber`/`AppendSignedJsonNumber`/`AppendFloatingJsonNumber`/`AppendJsonKey`) duplicated across `dc_addon_collection.cpp`, `dc_addon_wardrobe.cpp`, `Commands/cs_dc_stresstest.cpp`.
- **N-CurrencyArgsParsing** — token-type parsing + `strtok` argument split copy-pasted across `HandleTokenAdd`/`Remove`/`Set` in `cs_dc_item_upgrade.cpp` — one `ParseCurrencyArgs` helper would remove the duplication.
- **N-KeystoneItemLevelFormula** — was a real bug (two divergent formulas), fixed in Wave 2b (see Part 1 finding #123). Listed here only because the backlog pass flagged the underlying pattern (a ~60-entry hardcoded `mapId→boss-count` fallback switch in `GetTotalBossesForDungeon`) as a candidate for a data-driven table instead of C++ constants — that part is still open.
- **N-CurrencyPersistenceDup** — `ItemUpgradeManager`'s `AddCurrency`/`RemoveCurrency`/`GetCurrency` reimplement item-as-currency logic that `CrossSystem::CurrencyUtils` already centralizes (the token hooks and exchange path already call `CurrencyUtils::AddCurrencyAndSync`); also two independent upsert implementations of `dc_item_upgrades`.

## Format-string lint (from synth:ideas — the single highest-leverage recommendation)

The exact same printf-vs-fmt mistake (`%u`/`%s`/`%d`/`%.Nf`/`%%` passed to fmt-based
`LOG_*`/`PSendSysMessage`/`Acore::StringFormat`) was independently found and fixed in **at
least 10 files across 5+ review units** this round (`dc_addon_hlbg.cpp`, `GiantIsles` ×4 files,
`Commands` ×4 files, `MythicPlus/dc_mythicplus_spectator.cpp`, `PhasedDuels`, `GOMove`,
`Achievements`). Because fmt silently drops unrecognized specifiers instead of erroring, this
mistake compiles, passes review, and reaches players/GMs as corrupted or blank text every
time. **Recommended follow-up**: add a grep-based check to `apps/codestyle/codestyle-cpp.py`
that flags any format-string literal containing `%` immediately followed by a conversion
letter (`u`,`d`,`s`,`f`,`x`,`X`, etc.) inside a `LOG_*`/`PSendSysMessage`/`SendSysMessage`/
`SendErrorMessage`/`Acore::StringFormat` call — this would catch the whole bug class tree-wide
for near-zero ongoing cost and prevent it recurring in new code.
