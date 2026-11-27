> Part of the 2026-07 DC audit round. See `AUDIT_MASTER_SUMMARY.md` for the wave log and
> `AUDIT_CrossSystem_Candidates.md` for the centralization backlog.

# DC Audit Consolidated Findings — Part 2 (remaining 6 systems + synthesis)

Consolidates the 6 per-system reviews that completed after the original 16-system pass hit a
session limit, plus the 3 workflow-level synthesis outputs. 46 findings were raised across
MountHyjal+HyjalFrontier, CollectionSystem, Hotspot, DungeonQuests, Seasons+GreatVault, and
SmallZones-Bundle; 24 adversarial verify passes ran, covering every MEDIUM/HIGH finding in this
batch. 21 CONFIRMED (3 downgraded to LOW), 3 REFUTED, 22 unverified LOW-severity items.

## MountHyjal+HyjalFrontier

**Files reviewed:** `MountHyjal/zone_mount_hyjal.cpp`, `MountHyjal/zone_molten_front.cpp`, `HyjalFrontier/*`, `dc_script_loader.cpp`

**Health note:** Both MountHyjal files are mechanical Cataclysm-port scripts, clean on core conventions (ObjectGuid, no std::rand/TC_LOG_*, typed helpers). Real cost of the port: a dead 4.3.4-only escort hook causing a soft-lock+leak (fixed), and a pervasive hand-rolled timer idiom used alongside EventMap in ~14 AI classes (fixed). HyjalFrontier is intentional scaffolding — none of its 8 TODOs are bugs.

| # | Title | File:Line | Severity | Category | Verify Verdict | Corrected Severity | Suggested fix | Status |
|---|---|---|---|---|---|---|---|---|
| 1 | Escort-abandon cleanup is dead code: soft-locks the shared quest controller and leaks summoned adds | `MountHyjal/zone_molten_front.cpp:513` | HIGH | bug | CONFIRMED | — | Real distance check + controller reset instead of the nonexistent 4.3.4 hook. | **FIXED (Wave 2b)** |
| 2 | Trivia quiz can repeat the same true/false question back-to-back | `MountHyjal/zone_mount_hyjal.cpp:1759` | LOW | bug | NOT VERIFIED | | Track asked ids and re-roll. | deferred |
| 3 | Hand-rolled tick counters used alongside EventMap in nearly every AI | `MountHyjal/zone_mount_hyjal.cpp:1075` | MEDIUM | convention | CONFIRMED | — | Fold into EventMap events. | **FIXED (Wave 2b, 14 classes converted)** |
| 4 | Several member variables written but never read | `MountHyjal/zone_mount_hyjal.cpp:1705` | LOW | dead-code | NOT VERIFIED | | Remove or wire idle-timeout logic. | deferred |
| 5 | Fully commented-out spell class and its registration left in the file | `MountHyjal/zone_mount_hyjal.cpp:481` | LOW | dead-code | NOT VERIFIED | | Implement or delete. | deferred |
| 6 | GetPlayersInRange / MoveSmoothPath duplicated verbatim across files | `MountHyjal/zone_molten_front.cpp:47` | LOW | duplicate | NOT VERIFIED | | Move to shared DCUtils header. | deferred (backlog) |

## CollectionSystem

**Files reviewed:** `CollectionSystem/*`, `AddonExtension/dc_addon_collection.h/.cpp`, `CrossSystem/CrossSystemDbSchema.h`, `CrossSystem/CrossSystemCache.h`

**Health note:** `CollectionSystem/` is a 611-line shell of what was once the collection implementation — only 8 DB-schema forwarders + wishlist helpers are actually reachable; everything else was independently re-implemented under near-identical names inside `dc_addon_collection.cpp`. No crash/gameplay-breaking bug in code that actually executes — the cost was architectural (ODR-violation risk from a header declaring ~30 functions with no definitions, colliding namespace with the real implementation). Dead declaration block removed this round.

| # | Title | File:Line | Severity | Category | Verify Verdict | Corrected Severity | Suggested fix | Status |
|---|---|---|---|---|---|---|---|---|
| 7 | Mount-speed-bonus logic in CollectionMounts.cpp is dead; a duplicate is what actually runs | `CollectionSystem/CollectionMounts.cpp:38` | MEDIUM | dead-code | CONFIRMED | LOW | Delete or wire in. | deferred (confirmed, downgraded — kept, has a real definition) |
| 8 | PlayerCollectionCache subsystem is entirely unreachable | `CollectionSystem/CollectionCore.cpp:33` | MEDIUM | dead-code | CONFIRMED | LOW | Wire in or delete. | deferred (confirmed, downgraded) |
| 9 | Dead cache's lock pattern lets a struct reference escape the mutex | `CollectionSystem/CollectionCore.cpp:36` | MEDIUM | race-condition | REFUTED | NONE | Not a real race (unordered_map node-based); code unreachable anyway. | **REFUTED — no action** |
| 10 | IsHeirloomItem / GetPlayerTitleCount unused; CollectionPets.cpp empty stub | `CollectionSystem/CollectionHeirlooms.cpp:23` | LOW | dead-code | NOT VERIFIED | | Remove orphans. | deferred |
| 11 | CollectionCore.h declares ~30 functions with no definition anywhere; real bodies live in an unrelated header's same-named namespace | `CollectionSystem/CollectionCore.h:144` | MEDIUM | duplicate | CONFIRMED | — | Delete the dead declarations. | **FIXED (Wave 2b — 33 declarations removed, ODR risk closed)** |
| 12 | Dead global GetCharEntryColumn shadows the real namespaced function | `CollectionSystem/CollectionCore.h:203` | LOW | dead-code | NOT VERIFIED | | Delete the dead global stub. | deferred |
| 13 | CollectionCore.cpp keeps ~10 unused includes from before the file was gutted | `CollectionSystem/CollectionCore.cpp:9` | LOW | convention | NOT VERIFIED | | Trim includes. | deferred |

## Hotspot

**Files reviewed:** `Hotspot/*`, `Commands/cs_dc_hotspot.cpp`, `AddonExtension/dc_addon_hotspot.cpp`, `AddonExtension/dc_addon_world.cpp`

**Health note:** Refactor is largely clean; registration consolidated exactly once, DB schema matches query order, mutex usage consistent, no dangling-pointer risk. Real issues are refactor residue (unused members, a dead config branch). One claimed split-brain data-source finding did NOT hold up under verification — the code already reads the in-memory grid (confirmed independently by the Wave 2 fix on `dc_addon_world.cpp` too).

| # | Title | File:Line | Severity | Category | Verify Verdict | Corrected Severity | Suggested fix | Status |
|---|---|---|---|---|---|---|---|---|
| 14 | Two fully dead private members + one dead public method left over from the refactor | `Hotspot/HotspotMgr.h:43` | LOW | dead-code | NOT VERIFIED | | Delete or implement per-player tracking. | deferred |
| 15 | enabledZonesPerMap consumed but never populated — one whole branch of IsZoneAllowed permanently dead | `Hotspot/HotspotMgr.cpp:59` | MEDIUM | dead-code | CONFIRMED | LOW | Implement or delete; collapse duplicate zone-check functions. | deferred (confirmed, downgraded) |
| 16 | dc_addon_world.cpp rebuilds hotspot list from DB instead of HotspotMgr's in-memory grid | `AddonExtension/dc_addon_world.cpp:123` | MEDIUM | performance | REFUTED | NONE | Refuted — already reads the in-memory grid (also independently fixed in Wave 2). | **REFUTED — no action needed (already correct)** |
| 17 | _playerObjectives entries only cleaned up while player is online — logout leaves a stray record | `Hotspot/HotspotMgr.h:49` | LOW | memory-leak | NOT VERIFIED | | Add OnPlayerLogout cleanup hook. | deferred |
| 18 | Unused includes left over from the refactor | `Hotspot/spell_hotspot_buff_800001.cpp:15` | LOW | dead-code | NOT VERIFIED | | Drop unused includes. | deferred |

## DungeonQuests

**Files reviewed:** all `DungeonQuests/*` files.

**Health note:** Quest-completion/reward/achievement core is solid. Weak spots: three independent hand-rolled global caches shared across MapUpdater worker threads with zero/partial synchronization — 2 of 3 CONFIRMED live races, fixed with mutexes; the third was REFUTED after tracing this fork's actual threading model (packet/command handling is single-threaded and hard-barriered against map updates). Also: a fully dead reset subsystem (deleted), and an implemented-but-unwired difficulty gate (now wired in).

| # | Title | File:Line | Severity | Category | Verify Verdict | Corrected Severity | Suggested fix | Status |
|---|---|---|---|---|---|---|---|---|
| 19 | UniversalQuestMasterCache: writers take the mutex, readers don't — claimed live GM reload race | `DungeonQuests/npc_universal_quest_master.cpp:213` | HIGH | race-condition | REFUTED | NONE | Refuted — AzerothCore's actual scheduling precludes the claimed window. Defensive locking still good practice. | **REFUTED — no action (documented, not fixed)** |
| 20 | g_PlayerStatsCache: global unordered_map mutated from multiple PlayerScript hooks, no synchronization | `DungeonQuests/DungeonQuestHelpers.h:48` | HIGH | race-condition | CONFIRMED | — | Add a mutex around every access. | **FIXED (Wave 2b)** |
| 21 | sQuestMasterFollowers / sDungeonDisplayIdCache: unsynchronized global maps from concurrent map threads | `DungeonQuests/DungeonQuestMasterFollower.cpp:40` | HIGH | race-condition | CONFIRMED | — | Mirror the dc_guildhouse_instance.cpp mutex fix. | **FIXED (Wave 2b)** |
| 22 | Follower NPC orphaned on the old map when a player moves directly between two quest-master dungeons | `DungeonQuests/DungeonQuestMasterFollower.cpp:188` | MEDIUM | memory-leak | CONFIRMED | — | Track (mapId, instanceId, creatureGuid) and despawn via sMapMgr->FindMap before spawning new. | **FIXED (Wave 2b, bundled with #21)** |
| 23 | Daily/weekly reset flow queries three tables nothing ever writes — permanently a no-op | `DungeonQuests/npc_dungeon_quest_daily_weekly.cpp:28` | MEDIUM | dead-code | CONFIRMED | — | Delete entirely (chose delete — see master summary). | **FIXED (Wave 2b, file deleted, registration removed)** |
| 24 | Difficulty-unlock gating (CanAcceptDifficultyQuest) fully defined but never called | `DungeonQuests/DungeonQuestHelpers.h:487` | MEDIUM | dead-code | CONFIRMED | — | Call from OnQuestAccept. | **FIXED (Wave 2b, bundled with #23)** |
| 25 | Redundant blocking query + unconditional debug chat spam on every dungeon entry | `DungeonQuests/DungeonQuestMasterFollower.cpp:227` | MEDIUM | performance | CONFIRMED | — | Reuse the resolved entry; gate debug behind config. | **FIXED (Wave 2b, bundled with #21)** |
| 26 | Dead duplicate stats API in DungeonQuestDB re-implements (uncached) what DungeonQuestHelpers already caches | `DungeonQuests/DungeonQuestSystem.cpp:320` | LOW | duplicate | NOT VERIFIED | | Delete, route through the cached helper. | deferred |
| 27 | Inline quest-range checks duplicate IsDailyQuest/IsWeeklyQuest/IsDungeonQuest helpers | `DungeonQuests/DungeonQuestSystem.cpp:405` | LOW | duplicate | NOT VERIFIED | | Replace with the existing helper calls. | deferred |
| 28 | Large set of unused constants; achievement-range constants don't match IDs actually granted | `DungeonQuests/DungeonQuestConstants.h:67` | LOW | dead-code | NOT VERIFIED | | Wire in or delete; fix the range mismatch. | deferred |

## Seasons+GreatVault

**Files reviewed:** `Seasons/*`, `GreatVault/*`, `CrossSystem/CrossSystemVaultUtils.h`, `CrossSystem/SeasonResolver.h`, `CrossSystem/CrossSystemSeasonHelper.h`, `CrossSystem/RewardDistributor.cpp` (partial)

**Health note:** Weekly-reset boundary plumbing (DCWeeklyResetHub → GreatVault/MythicPlus) is well centralized. Weak spot was `Seasons/`: a currency-reward path silently dropping rewards on a full inventory (fixed), and a season-lifecycle engine that LOOKED entirely dead but turned out to have real registered callbacks silently never firing because the live GM command bypassed it — wired in this round based on grep evidence, not deleted.

| # | Title | File:Line | Severity | Category | Verify Verdict | Corrected Severity | Suggested fix | Status |
|---|---|---|---|---|---|---|---|---|
| 29 | Seasonal token/essence rewards silently lost on a full inventory (no mail fallback) | `Seasons/SeasonalRewardSystem.cpp:248` | HIGH | bug | CONFIRMED | — | Route through RewardDistributor::DistributeItem. | **FIXED (Wave 2b)** |
| 30 | Season lifecycle engine is entirely dead code — registered season-change callbacks never fire in production | `Seasons/SeasonalSystem.cpp:163` | MEDIUM | dead-code | CONFIRMED | — | Wire the live .season setseason command through TransitionSeason (grep proved callbacks exist and are silently starved — chose wire-up over delete). | **FIXED (Wave 2b)** |
| 31 | UpdateSeason escapes against CharacterDatabase but executes on WorldDatabase; skips EnsureInitialized() | `Seasons/SeasonalSystem.cpp:82` | LOW | bug | NOT VERIFIED | | Fix escape target + add guard. | deferred |
| 32 | ResetPlayerSeason archives then deletes via two independent non-transactional Execute() calls | `Seasons/SeasonalRewardSystem.cpp:742` | MEDIUM | error-handling | CONFIRMED | — | Wrap in one transaction. | **FIXED (Wave 2b, bundled with #29)** |
| 33 | dc_weekly_reset_state table re-created every 60-second tick instead of once | `Seasons/DCWeeklyResetHub.cpp:104` | MEDIUM | performance | CONFIRMED | — | Add a static guard. | **FIXED (Wave 2b, bundled with #29)** |
| 34 | DecodeGlobalSlotIndex result computed and discarded; claim-time validation is dead code | `GreatVault/GreatVault.cpp:440` | LOW | dead-code | NOT VERIFIED | | Remove or finish the validation. | deferred |
| 35 | Canonical SECONDS_PER_WEEK constant not used by its own producer file, plus a GreatVault duplicate | `Seasons/DCWeeklyResetHub.cpp:14` | LOW | duplicate | NOT VERIFIED | | Use the constant directly. | **FIXED (Wave 3, C5 sweep — GreatVault.cpp collapsed)** |
| 36 | Needless const_cast<>(this) inside non-const member functions | `Seasons/SeasonalSystem.cpp:153` | LOW | convention | NOT VERIFIED | | Drop the const_cast. | deferred |

## SmallZones-Bundle (Deepholm, Gilneas/BFG, Jadeforest, Races/Worgoblin, AC/, Teleporters, FakePlayers, GOMove, Spectator core, PhasedDuels, Achievements, RandomEnchants)

**Files reviewed:** all files across these 12 small subdirectories.

**Health note:** Mixes very clean, idiomatic code with concrete evidence-backed defects concentrated in two older/ported files. `Gilneas/BattlegroundBFG.cpp` (TrinityCore/SkyFire-era port) had a likely-crashing sprintf type-confusion bug and a world-state bug on its most common code path — both fixed. `Achievements/dc_achievements.cpp` had a real async/sync race despite demonstrating the correct pattern 30 lines later — fixed. The `%u`/`%s`-vs-`{}` mistake appeared independently in 3 unrelated files — all fixed.

| # | Title | File:Line | Severity | Category | Verify Verdict | Corrected Severity | Suggested fix | Status |
|---|---|---|---|---|---|---|---|---|
| 37 | Node-capture broadcast passes a raw LANG id where a resolved string is expected (sprintf type confusion) | `Gilneas/BattlegroundBFG.cpp:117` | HIGH | bug | CONFIRMED | — | Resolve via GetAcoreString first; snprintf. | **FIXED (Wave 2b)** |
| 38 | TryClaimServerFirst races an async INSERT against an immediate blocking SELECT on the world thread | `Achievements/dc_achievements.cpp:287` | MEDIUM | race-condition | CONFIRMED | — | Resolve via async callback, matching CheckPrestigeAchievements 30 lines later. | **FIXED (Wave 2b)** |
| 39 | FillInitialWorldStates never sends occupied-node world states (only contested) | `Gilneas/BattlegroundBFG.cpp:270` | MEDIUM | bug | CONFIRMED | — | Loop all 4 non-neutral states. | **FIXED (Wave 2b, bundled with #37)** |
| 40 | printf-style specifiers passed to fmt-based PSendSysMessage | `PhasedDuels/dc_phased_duels.cpp:1001` | MEDIUM | bug | CONFIRMED | — | Convert to {} (regression vs. correct usage 40 lines earlier). | **FIXED (Wave 2b)** |
| 41 | Same printf-vs-fmt bug repeated in GOMove GM command feedback | `GOMove/GOMoveScripts.cpp:84` | MEDIUM | bug | CONFIRMED | — | Convert 4 sites to {}. | **FIXED (Wave 2b)** |
| 42 | Same printf-vs-fmt bug in the achievement debug command | `Achievements/dc_achievements.cpp:594` | LOW | bug | NOT VERIFIED | | Convert to {}. | **FIXED (Wave 2b, bundled with #38)** |
| 43 | Boss training dummy AI uses hand-rolled millisecond countdown fields instead of EventMap/TaskScheduler | `Jadeforest/jadeforest_training_grounds.cpp:1003` | LOW | convention | NOT VERIFIED | | Replace with EventMap/TaskScheduler. | deferred |
| 44 | Dead if/else branch: both arms of the phase-mask assignment are identical | `Jadeforest/jadeforest_training_grounds.cpp:477` | LOW | dead-code | NOT VERIFIED | | Collapse to one unconditional call. | deferred |
| 45 | Inconsistent thread-safety guard across training-grounds static player-keyed state | `Jadeforest/jadeforest_training_grounds.cpp:136` | LOW | race-condition | NOT VERIFIED | | Guard sibling static maps with the same mutex. | deferred |
| 46 | RecordDuelEnd/HandleDuelReset use the 'startup-only' Execute(fmt, args) overload for per-event writes | `PhasedDuels/dc_phased_duels.cpp:384` | LOW | convention | NOT VERIFIED | | Register PreparedStatements. | deferred |

## Cross-cutting / CrossSystem centralization candidates (Part 2)

See `AUDIT_CrossSystem_Candidates.md` for the consolidated list (Part 1 + Part 2 candidates,
marked against what Wave 3 actually did).

## Synthesis stage output

Three workflow-level synthesis agents ran after all per-system reviews completed.

### synth:ideas — cross-system improvement ideas (7)

1. **CI lint for printf-style specifiers inside fmt-based APIs** (high impact). The exact same
   bug class was independently found by 5+ review units and reached players/GMs as corrupted
   output every time, because the fmt backend silently accepts and drops printf specifiers
   instead of erroring. A one-time grep-based codestyle lint (flag any format-string literal
   containing `%` followed by a conversion letter in `LOG_*`/`PSendSysMessage`/`StringFormat`
   calls) would catch this whole class tree-wide for near-zero cost — **recommended as a
   follow-up to add to `apps/codestyle/codestyle-cpp.py`.**
2. **Standardize the blocking-DB-on-world-thread migration pattern** (high impact). Nearly
   every unit flagged at least one synchronous DB query reached from a hot/player-facing path.
   Most were fixed individually this round; a documented canonical pattern (already implicit in
   `DCAddon::EnqueueQueryCallback`) would prevent regressions.
3. **MythicPlus HandleFailState use-after-free** — called out by the synthesis pass as "the
   single highest-priority fix to come out of the whole review pass." **Fixed this round.**
4. **Decide the fate of half-built/dead feature surfaces, tree-wide** (high impact). A large
   number of units contain fully-configured-but-never-wired features that mislead operators:
   ChallengeMode's reward config (deleted this round), ItemUpgrades' Phase 4B/4C/4D backlog,
   Seasons' lifecycle engine (wired this round), CrossSystem's inert Adapters layer (deferred —
   needs product decision), Hotspot's dead scaffolding, DungeonQuests' dead reset subsystem
   (deleted this round) and unenforced difficulty gate (wired this round), MythicPlus's
   RUN_START-only replay recorder, CollectionSystem's stale duplicate fork (dead declarations
   removed this round). Recommendation: adopt BlackwingDescent's `PORT_NOTES.md` pattern for
   anything left intentionally incomplete.
5. **Audit and lock down global caches touched from non-world-server threads** (high impact).
   DungeonQuests confirmed 2 of 3 suspected races live via the MapUpdater thread pool — both
   fixed this round; the third was refuted after tracing the actual threading model.
6. **Consolidate duplicated leaderboard/stats/season logic into CrossSystem helpers** (medium
   impact) — partially addressed this round (DbSchema, weekly-constant, leaf-utils); the
   HLBG-vs-leaderboards duel-stats divergence and the two-season-resolver split remain
   deferred, both explicitly flagging a behavior decision needed before merging.
7. **Extract recurring copy-paste patterns into shared helpers** (medium impact) — GuildHousing
   gossip-location builder, MountHyjal's "NPC gates a per-player timed event" pattern (×4),
   SmallZones' "server first" claim race pattern, ItemUpgrades' HistoryManager query methods,
   GreatVaultMgr's goto-based track handling, GiantIsles' 3 near-identical boss AI scaffolds,
   BlackwingDescent's repeated target-filter predicates, Collection's ~15 near-identical
   schema-probe helpers. Each is low-risk/high-leverage backlog, not applied this round.

### synth:coverage — completeness-critic pass

Flagged `Progression/Accountwide/` as the highest-priority apparent gap (neither unit name
mentioned it explicitly) — **false alarm**: Part 1's "Progression-Prestige+Init" review unit
did cover all 3 Accountwide files by content, just not by name. Also flagged `Gilneas/` as
"risking being trivialized if folded into SmallZones-Bundle" — this warning **proved
prescient**: that's exactly where this batch's only crash-class defect turned up, though the
actual review pass still caught it despite the bundling. Recommended a dedicated follow-up
pass for: Spectator-Core as its own unit, Gilneas-BFG as its own unit, and extra attention to
`jadeforest_training_grounds.cpp` (1609 of 1822 lines in "Jadeforest") and
`cs_dc_stresstest.cpp` (8922 of 14287 lines in "Commands") in any future round.

### synth:backlog — migration-plan dedup pass

36 items total, deduplicated against `CENTRALIZATION_MIGRATION_PLAN.md` — see
`AUDIT_CrossSystem_Candidates.md` for the consolidated, wave-annotated version.

## Needs-human-judgment / defer list (Part 2)

**Refuted (do not act without re-reading source):**
- `Hotspot/dc_addon_world.cpp:123` — hotspot split-brain claim, refuted (already correct).
- `CollectionSystem/CollectionCore.cpp:36` — cache-lock race claim, refuted (unordered_map
  reference semantics + code is unreachable anyway).
- `DungeonQuests/npc_universal_quest_master.cpp:213` — GM-reload race claim, refuted after
  tracing this fork's actual single-threaded packet/command scheduling.

**Confirmed real but downgraded to LOW (not fixed this round, safe to defer):**
`CollectionSystem/CollectionMounts.cpp:38`, `CollectionSystem/CollectionCore.cpp:33`,
`Hotspot/HotspotMgr.cpp:59`.

**Unverified LOW tail** — see the per-system tables above; every row not marked FIXED is
deferred and safe to triage opportunistically.
