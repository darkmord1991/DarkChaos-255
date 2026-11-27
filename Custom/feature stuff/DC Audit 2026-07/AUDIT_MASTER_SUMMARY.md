# DC Scripts Deep Audit — 2026-07 Round

Full review of `src/server/scripts/DC` (~30 subsystems, ~150k LOC): 22 review units covered by
a 99-agent multi-stage workflow (per-system review → adversarial verify → synthesis), followed
by four fix waves applied directly to the tree. This round supersedes the January 2026
`Custom/feature stuff/Completed/2026 improvements/EVAL_*` set where they overlap — several of
those findings (Hotspot monolith, HLBG pre-cutover layout, Seasons pre-HLBG-cleanup) were
already resolved by commits since then and are not re-litigated here.

## Headline numbers

- **185 findings** raised across 22 review units (139 in the first pass, 46 in a second pass
  covering 6 units that hit a session limit on the first run).
- **83 adversarial verify passes** ran against MEDIUM/HIGH findings; **64 CONFIRMED**, 4
  REFUTED/conflicting (do not act on those without re-reading source — see per-system docs),
  the rest downgraded or left as reviewer judgment.
- **42 fix tasks applied** across 4 waves (below), touching ~55 files, including 2 potential
  crash bugs, 1 SQL-injection-class defect, 1 use-after-free, 4 confirmed race conditions, and
  a live-economy DB schema bug.
- **1 file deleted outright** (confirmed 100%-dead daily/weekly reset subsystem), **2 dead
  headers/declarations removed**, **~30 dead function declarations removed** from one header.
- **Build verified**: `scripts`+`game` static libs compile clean (RelWithDebInfo) after every
  wave; loader integrity check clean (no duplicate/dead/conflicting registrations) after every
  wave; full C++ and SQL codestyle linters pass on the final tree.

## Wave log

### Wave 1 — registration & dead code (zero risk)
| Fix | File |
|---|---|
| Removed duplicate `AddSC_challenge_mode_scripts()` registration (was firing every hardcore-death/login hook twice) | `Progression/ChallengeMode/dc_challenge_modes_customized.cpp`, `dc_script_loader.cpp` |
| Deleted dead loader header (`AddDCCrossSystemScripts()`, never included/called — ODR hazard) | `CrossSystem/dc_cross_system_loader.h` (deleted) |
| Removed orphan `AddSC_mythic_plus_commands()` declaration (no definition anywhere) | `MythicPlus/dc_mythicplus_loader.cpp` |
| Reconciled `CMakeLists.txt` inventory (12 files missing from the documentation-only source lists: BlackwingDescent ×8, MountHyjal ×2, Deepholm, Races, `dc_downport_taxi.cpp`, 3 AddonExtension files) | `CMakeLists.txt` |

### Wave 2 — confirmed bug fixes, first 16 systems (22 tasks)
Systems: AddonExt-Misc, QOL, AddonExt-Protocol, AddonExt-Gameplay, AddonExt-Collection,
GuildHousing, Progression-Prestige+Init, BlackwingDescent, Progression-ChallengeMode,
GiantIsles, AddonExt-Social, HinterlandBG, Commands, ItemUpgrades, MythicPlus, CrossSystem.

Highlights (full list in per-system docs):
- **HIGH security**: SQL injection in spectator HUD-option write (`dc_addon_spectator.cpp`) and
  in the welcome/FAQ feature-seen tracker (`dc_addon_welcome.cpp`) — both closed with
  allowlist/escape fixes.
- **HIGH bug**: client-triggerable null-deref crash clearing an active title
  (`dc_addon_collection.cpp`, `SetTitle(nullptr)` → `SetCurrentTitle(nullptr, true)`).
- **HIGH bug (world-crash class)**: `cs_dc_dungeonquests.cpp` had an uncaught `std::stoul` crash
  and a null-achievement-pointer crash reachable from GM commands, plus an unbounded `sscanf`
  stack-buffer overflow; `cs_dc_item_upgrade.cpp` had an `sscanf` write into an empty
  `std::string`'s buffer (UB). All fixed.
- **HIGH bug**: `dc_addon_hlbg.cpp`'s seasonal leaderboard/stats handlers built both SQL and
  JSON with printf specifiers against this fork's fmt-based formatter — queries and payloads
  were silently malformed. Converted ~28+ call sites to `{}`.
- **HIGH bug**: live artifact-mastery INSERT (`ItemUpgradeManager.cpp`) targeted a nonexistent
  `season` column and omitted the required `artifact_id` PK component — failed on every upgrade,
  silently dropping the mastery award. Fixed to match the live schema, plus a companion
  migration (`data/sql/updates/pending_db_characters/`) adding 6 columns three other files
  in the same subsystem already assumed existed.
- **MEDIUM→HIGH performance/correctness**: blocking world-thread DB queries converted to async
  in `dc_addon_world.cpp`, `dc_addon_mythicplus.cpp`; N+1 dungeon-name lookups cached in
  `dc_addon_spectator.cpp`; a group-loot-corruption bug where personal AoE-loot filters mutated
  shared group loot (`dc_aoeloot_unified.cpp`).
- Double-registration false-positive independently confirmed via defensive re-entry guards
  added to `ChallengeModeScripts.cpp`'s two other hardcore-death hook paths.

### Wave 2b — confirmed bug fixes, remaining 6 systems (9 tasks)
Systems: MountHyjal+HyjalFrontier, CollectionSystem, Hotspot (no fixes needed — its one
MEDIUM finding was refuted on verify), DungeonQuests, Seasons+GreatVault, SmallZones-Bundle.

Highlights:
- **HIGH bug**: `Gilneas/BattlegroundBFG.cpp` node-capture broadcast passed a raw `LANG_*` id
  into a `%s` sprintf slot expecting a resolved string — an all-but-guaranteed crash on every
  node capture in this battleground, one of its most common events. Fixed to resolve via
  `GetAcoreString` first and switched `sprintf`→`snprintf`.
  Same file: joining/backfilled players never saw "occupied" node icons (world-state loop
  bounded to 3 states instead of 4) — fixed.
- **HIGH bug**: `MountHyjal/zone_molten_front.cpp` escort quests relied on a Cataclysm-only
  `ScriptedEscortAI` hook that doesn't exist in this 3.3.5 fork — abandoning an escort never
  despawned summoned adds or reset the shared world-controller (soft-lock + leak). Replaced
  across 3 escort classes with a real distance-check pattern already used elsewhere in the file.
- **2 confirmed race conditions**: `DungeonQuests` had two global caches
  (`g_PlayerStatsCache`, `sQuestMasterFollowers`/`sDungeonDisplayIdCache`) mutated from
  concurrent MapUpdater worker threads with zero synchronization — both mutex-guarded now
  (mirroring the existing `dc_guildhouse_instance.cpp` fix for the same pattern). A third
  suspected race (`UniversalQuestMasterCache`) was adversarially REFUTED after tracing this
  fork's actual threading model (packet handling is single-threaded and hard-barriered against
  map updates) — left as-is, documented rather than "fixed."
- **HIGH bug**: `Seasons/SeasonalRewardSystem.cpp`'s `AwardCurrency` silently dropped seasonal
  token/essence rewards on a full inventory (no mail fallback) — routed through
  `RewardDistributor::DistributeItem` like the sibling `GreatVault` path.
- **Design-decision finding, resolved by evidence**: `SeasonalSystem.cpp`'s season
  lifecycle/event engine looked dead (zero call sites for `TransitionSeason` etc.), but grep
  proved two other subsystems (`ItemUpgradeSeasonalImpl.cpp`, `SeasonalRewardScripts.cpp`)
  register real callbacks on it that silently never fired because `.season setseason` bypassed
  the engine entirely. Wired the GM command through `TransitionSeason` (with a fallback to the
  old direct call if the engine can't resolve the season ids) instead of deleting the "dead"
  code — the grep evidence showed it wasn't actually dead, just disconnected.
- **Confirmed race + async fix**: `Achievements/dc_achievements.cpp`'s "server first" claim
  raced a blocking world-thread query against its own `INSERT IGNORE`; converted to the async
  pattern the same file already demonstrates 30 lines later.
- Also fixed: orphaned quest-master follower NPCs on direct dungeon-to-dungeon transfers;
  unenforced difficulty-gate (`CanAcceptDifficultyQuest` wired into `OnQuestAccept`); a
  100%-confirmed-dead daily/weekly reset subsystem **deleted outright**
  (`npc_dungeon_quest_daily_weekly.cpp` — queried 3 tables nothing ever wrote to); a
  `CREATE TABLE` DDL statement that ran on every 60-second tick instead of once; non-transactional
  archive+delete in season reset; 4 more printf→fmt sweeps (GOMove, PhasedDuels, Achievements).

### Wave 3 — CrossSystem centralization (7 tasks)
Scoped to items the plan document already tracked (A1/B1/B5/B6/C1/C5) plus one genuinely
verified-safe adjacent cleanup, **after independently re-verifying each target still applied**
(one planned item — migrating `hlbg_constants.h`'s affix table to the CrossSystem registry —
was found to be architecturally blocked: that header compiles into the `game` static library,
which cannot include the `CrossSystem/` chain, exactly as its own code comment already
documented; that specific sub-item was skipped and the comment left intact).

| Item | Fix |
|---|---|
| A1 | `DC::DbSchema`'s 4 helpers rewritten from wildcard `SHOW ... LIKE` to exact-match `information_schema` queries, per the migration plan's own stated intent |
| B1 | Deduplicated a same-file duplicate DBC zone-name lookup in `CrossSystemWorldBossMgr.cpp` into one local helper |
| B6 (partial) | Deleted dead `GetLegacyAffixName`; collapsed 3 overlapping weather-name tables (2 in `hlbg_constants.h`, 1 in `hlbg_scoreboard_npc.cpp`) into 1 canonical function with a parameterized default |
| C1 | `CrossSystemRewards.h`'s non-seasonal item-grant path now routes through `RewardDistributor::DistributeItem` (mail-on-full-bag) instead of a bare `AddItem` |
| C5 | Collapsed 4 duplicate `SECONDS_PER_WEEK`-equivalent literals (`SessionContext.cpp`, `GreatVault.cpp`, `dc_addon_mythicplus.cpp`, + the Seasons fix above) onto the canonical `DarkChaos::Seasons::SECONDS_PER_WEEK` |
| B4 (leaf utils) | 5 more files repointed to already-centralized `DCUtils` helpers (`FormatLocalTimestamp`, `ParseUInt32List`, `JoinStringList`, `ToLower`), preserving each call site's original edge-case behavior (e.g. id-0 filtering) |
| B5 (judgment call, not applied) | GuildHousing's `FormatGold` duplicate was investigated and **deliberately left as-is** — the live decoration/location cost data is 100% round-gold values today, so switching to the centralized `DCUtils::FormatCoins` would visibly regress player-facing text with redundant "0s 0c" noise; documented for a future revisit if non-round pricing is ever added |

### Wave 4 — larger refactors: evaluated, deferred
The one candidate that met Wave 4's bar (confirmed value, behavior-preserving, no DB/gameplay
redesign) was **B3: generalizing 4 independently hand-rolled account/player-keyed caches**
(`Progression/Accountwide`'s 3 files, `Progression/Prestige/dc_prestige_system.cpp`, and
`DungeonQuests/DungeonQuestHelpers.h`'s `g_PlayerStatsCache`) into one shared
`DarkChaos::Cache` template. **Decision: not applied.** All four caches are already
individually correct after Wave 2b's targeted mutex fix on the one that had a real race; the
remaining duplication is a pure DRY/maintainability improvement, not a live bug, and a
generic-template refactor touching 5 files in a working caching subsystem carries more risk
than benefit at this point in the pass. Recorded in `AUDIT_CrossSystem_Candidates.md` as a
backlog item for a dedicated future pass instead.

## Verification

- **C++ codestyle** (`apps/codestyle/codestyle-cpp.py`): clean after every wave (per-file during
  fix application, full-tree at the end).
- **SQL codestyle** (`apps/codestyle/codestyle-sql.py`): clean (the script's own final
  checkmark print throws an unrelated Windows-console Unicode error *after* all real checks
  already reported "Passed" — cosmetic, not a check failure).
- **Loader integrity** (`dc_check_script_loader_integrity`): 0 duplicate load calls, 0 dead
  declarations, 0 transitive conflicts — checked after Wave 1 and again after the final wave.
- **Full build** (`scripts` + `game` static libs, RelWithDebInfo, MSVC/Visual Studio 17 2022):
  compiled clean after Wave 2, and after Wave 2b+3 **two real compile errors surfaced and were
  fixed**:
  1. `CrossSystemRewards.h`'s new C1 fallback path compared `Player::AddItem(...)` (which
     returns `bool` in this fork, not `Item*`) against `nullptr` — fixed to use the bool
     directly.
  2. Deleting `npc_dungeon_quest_daily_weekly.cpp` left a stale reference in the MSVC project
     file, since the parent build's glob-based source collection is only re-evaluated at CMake
     configure time, not at build time — fixed by re-running `cmake .` to regenerate the
     project, then rebuilding clean.
  Final rebuild after both fixes: clean, 0 errors.

## What's deliberately NOT fixed (see per-system docs + `AUDIT_CrossSystem_Candidates.md`)

- **BlackwingDescent's remaining `PORT_NOTES.md`-documented stubs** (vehicle passenger logic,
  Onyxia elevator visuals, feat-tracking neutralization) — accepted, out of scope.
- **4 REFUTED/conflicting findings** — do not act without re-reading source; see per-system
  notes (`AddonExt-Protocol`'s SMSG_FEATURE_LIST drift, `Progression-ChallengeMode`'s
  double-registration root-cause dispute, `CollectionSystem`'s cache-lock claim,
  `DungeonQuests`' `UniversalQuestMasterCache` race claim).
- **2 architectural product decisions** requiring a call from the project owner, not a
  mechanical fix: (1) `CrossSystem`'s entire Adapters/DCSystem layer is dead — wire it up or
  delete it; (2) two overlapping "single source of truth" season resolvers
  (`SeasonResolver.h` vs `CrossSystemSeasonHelper.h`) disagree on order/default/DB column —
  pick one.
- **~120 LOW-severity items** (dead code, minor convention drift, unused includes, small
  duplication) reviewed but not adversarially verified — full list in per-system docs, safe to
  triage opportunistically but none block anything.
- **`RewardDistributor::GetWeeklyCapStatus`** still stubbed to "unlimited" (C4) — needs actual
  weekly-cap design/DB work, not a mechanical fix.

## Per-system detail

See the companion files in this folder:
- `AUDIT_FINDINGS_PART1.md` — full findings tables for the first 16 review units
- `AUDIT_FINDINGS_PART2.md` — full findings tables for the remaining 6 review units, plus the
  3 workflow synthesis outputs (cross-system improvement ideas, a completeness-critic pass, and
  the migration-plan dedup pass)
- `AUDIT_CrossSystem_Candidates.md` — the consolidated centralization backlog (plan items +
  newly-found), marked done/deferred against this round's work
