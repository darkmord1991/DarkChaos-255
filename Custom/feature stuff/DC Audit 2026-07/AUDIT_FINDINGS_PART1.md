> Part of the 2026-07 DC audit round. See `AUDIT_MASTER_SUMMARY.md` for the wave log (what was
> actually fixed) and `AUDIT_CrossSystem_Candidates.md` for the centralization backlog. The
> tables below are the raw per-system findings from the review pass; "Verify Verdict" already
> reflects the adversarial re-check. Findings from the **High-confidence action list** near the
> end of this document were applied in Wave 2 unless a wave/task name says otherwise — see the
> master summary's wave log for the exact fix applied to each.

# DC Audit Consolidated Findings — Part 1 (first 16 systems)

Consolidated from a 16-system, multi-agent code-audit workflow (`wf_8589826e-227`) over
`src/server/scripts/DC` (DarkChaos custom AzerothCore 3.3.5 scripts). 139 findings were
raised across 16 per-system reviews; 59 adversarial verify passes were run, covering 44
unique findings directly (15 of which were independently re-verified a second time —
sometimes with disagreeing conclusions, which are called out explicitly below), plus one
more finding (Progression-ChallengeMode's "double-registration" item) that was explicitly
refuted only as a side-effect of a verify pass targeting a related finding. The remaining
94 findings were reviewed but not adversarially verified at all (verify budget/session
limits were hit) — treat their severity/category as the reviewing agent's judgment only.

**How to read the "Verify Verdict" column:** `CONFIRMED` = at least one independent
adversarial pass reproduced the defect from source; `REFUTED` = an adversarial pass could
not reproduce real-world impact; `CONFLICTING (CONFIRMED+REFUTED)` = two passes disagree
outright; `NOT VERIFIED` = reviewed only, no adversarial pass ran. The "Corrected Severity"
column shows the verify pass's revised severity only when it differs from (or disputes)
the original; `—` means the verify pass(es) agreed with the original severity.

## AddonExt-Misc

**Files reviewed:** `AddonExtension/dc_addon_aoeloot.cpp`, `AddonExtension/dc_addon_hotspot.cpp`, `AddonExtension/dc_addon_spectator.cpp`, `AddonExtension/dc_addon_prestige.cpp`, `AddonExtension/dc_addon_prestige_notify.h`, `AddonExtension/dc_addon_teleports.cpp`, `AddonExtension/dc_addon_questflow.cpp`, `AddonExtension/dc_addon_gomove.cpp`, `AddonExtension/dc_addon_npcmove.cpp`, `AddonExtension/dc_addon_decorations.cpp`

**Health note:** The unit is mostly in good shape: aoeloot, teleports, hotspot, prestige and questflow have clearly been hardened — DB reads go async via EnqueueQueryCallback with ObjectGuid re-resolution in the callback, settings caches are mutex-guarded, session dedupe is cleaned up on logout, and the questflow remote accept/complete paths correctly re-gate eligibility server-side so a modified client cannot complete arbitrary quests. GOMove/NPCMove are GM-gated ports of the upstream mover and look faithful. The clear outlier was dc_addon_spectator.cpp (fixed in Wave 2), which contained a real SQL injection (unescaped client string in a HUD-settings INSERT) and blocking/N+1 dc_mplus_dungeons queries on the world thread. Everything else is low-severity cleanup (dead spectator/aoeloot APIs, prestige constant duplication).

| # | Title | File:Line | Severity | Category | Verify Verdict | Corrected Severity | Suggested fix | Status |
|---|---|---|---|---|---|---|---|---|
| 1 | SQL injection: unescaped client string interpolated into spectator HUD-settings INSERT | `AddonExtension/dc_addon_spectator.cpp:155` | HIGH | security | CONFIRMED | — | Allowlist validate `option` or escape before formatting. | **FIXED (Wave 2)** |
| 2 | Blocking DB queries on the world thread in spectator handlers (N+1 in HandleListRuns) | `AddonExtension/dc_addon_spectator.cpp:120` | MEDIUM | performance | CONFIRMED | — | Cache dungeon names instead of per-run queries. | **FIXED (Wave 2)** |
| 3 | Dead code: unused spectator API GetSpectatingRunId and no-op stub BroadcastHUDUpdate | `AddonExtension/dc_addon_spectator.cpp:191` | LOW | dead-code | NOT VERIFIED | | Remove both, or wire BroadcastHUDUpdate into the M+ spectator timer path if HUD sync is actually intended. | deferred |
| 4 | Dead code: unused AOELoot public accessors and stale forward-decl | `AddonExtension/dc_addon_aoeloot.cpp:751` | LOW | dead-code | NOT VERIFIED | | Delete the unused accessors and the stale forward-decl. | deferred |
| 5 | Prestige addon re-declares module id and opcodes that already exist in the shared namespace header | `AddonExtension/dc_addon_prestige.cpp:42` | LOW | duplicate | NOT VERIFIED | | Delete the local MODULE/Opcode declarations and use DCAddon::Module::PRESTIGE / DCAddon::Opcode::Prestige. | deferred |
| 6 | Prestige bonuses array hand-built as a JSON string via snprintf instead of a JsonValue array | `AddonExtension/dc_addon_prestige.cpp:212` | LOW | convention | NOT VERIFIED | | Build a JsonValue array of objects and Set it directly. | deferred |
| 7 | GOMove tele-sync runs a blocking full-table game_tele scan on the world thread | `AddonExtension/dc_addon_gomove.cpp:296` | LOW | performance | NOT VERIFIED | | Use WorldDatabase.AsyncQuery + EnqueueQueryCallback like dc_addon_teleports.cpp. | deferred |

## QOL

**Files reviewed:** `QOL/dc_aoeloot_unified.cpp`, `QOL/dc_looter_pet.cpp`, `QOL/dc_questgiver_status_override.cpp/.h`, `QOL/dc_breaking_news_qol.cpp`, `AddonExtension/dc_addon_aoeloot.cpp`, `CrossSystem/CrossSystemUtilities.h`, `CrossSystem/CrossSystemDbSchema.h`, `dc_script_loader.cpp`

**Health note:** Generally solid and modern: async login/logout DB loads, ObjectGuid-based lookups, guarded callbacks, correct fmt-style logging, clean single-registration wiring (verified no double-registration). Looter-pet and questgiver-override are clean and reused by 4 other NPC scripts. The one genuine gameplay bug (personal AoE-loot filters mutating shared group loot) is fixed. Rest is low-severity dead code, a no-op config flag, a half-wired preset feature set, and centralization-plan duplication.

| # | Title | File:Line | Severity | Category | Verify Verdict | Corrected Severity | Suggested fix | Status |
|---|---|---|---|---|---|---|---|---|
| 8 | Personal AoE-loot filters mutate SHARED group loot before group rolls | `QOL/dc_aoeloot_unified.cpp:1059` | MEDIUM | bug | CONFIRMED | — | Gate personal filters on player->GetGroup() == nullptr like playerMinQuality already is. | **FIXED (Wave 2)** |
| 9 | AoELoot.AutoCreditGold config option is dead — gold is always auto-credited | `QOL/dc_aoeloot_unified.cpp:1210` | LOW | dead-code | NOT VERIFIED | | Honor the config or remove the field. | deferred |
| 10 | Half-wired preset system + commented-out features leave dead code and no-op preferences | `QOL/dc_aoeloot_unified.cpp:401` | LOW | dead-code | NOT VERIFIED | | Product decision: finish or delete. | deferred |
| 11 | Duplicated blocking schema-introspection (GetPreferenceSchemaInfo) in two files | `QOL/dc_aoeloot_unified.cpp:332` | LOW | duplicate | NOT VERIFIED | | Use DC::DbSchema::CharacterColumnExists. | backlog (plan A1) |
| 12 | Local reimplementations of existing DCUtils helpers (timestamp / CSV parse / CSV join) | `QOL/dc_breaking_news_qol.cpp:118` | LOW | duplicate | NOT VERIFIED | | Route through DCUtils helpers. | **FIXED (Wave 3, leaf-utils-dedup)** |
| 13 | Dead null checks on address-of-member Loot pointers | `QOL/dc_aoeloot_unified.cpp:859` | LOW | dead-code | NOT VERIFIED | | Drop the checks. | deferred |
| 14 | Redundant IsAutoComplete branch in questgiver BuildStatus (both branches identical) | `QOL/dc_questgiver_status_override.cpp:146` | LOW | dead-code | NOT VERIFIED | | Collapse into a single else branch. | deferred |

## AddonExt-Protocol

**Files reviewed:** `AddonExtension/dc_addon_protocol.cpp`, `dc_addon_namespace.h`, `dc_addon_extension_loader.cpp`, `dc_addon_world.cpp`, `dc_addon_world_bosses.h`, `CrossSystem/CENTRALIZATION_MIGRATION_PLAN.md`, `CrossSystem/CrossSystemUtilities.h`, `QOL/dc_breaking_news_qol.cpp`

**Health note:** Mature and well-engineered protocol core with correct fixes for classic AzerothCore addon pitfalls. No HIGH-severity crash/dangling-pointer/security issues. Remaining: a bounded blocking DB query, a payload-shape drift, a stale legacy version-check path, and LOW telemetry/cleanup/convention nits.

| # | Title | File:Line | Severity | Category | Verify Verdict | Corrected Severity | Suggested fix | Status |
|---|---|---|---|---|---|---|---|---|
| 15 | Blocking WorldDatabase.Query on the world thread in WRLD content builder | `AddonExtension/dc_addon_world.cpp:127` | MEDIUM | performance | CONFIRMED | LOW/MEDIUM (passes disagree) | Read from HotspotMgr's in-memory grid instead of the DB. | **FIXED (Wave 2, upgraded fix: eliminated the query entirely rather than making it async)** |
| 16 | SMSG_FEATURE_LIST payload shape differs between handshake and feature-query | `AddonExtension/dc_addon_protocol.cpp:2902` | MEDIUM | bug | **CONFLICTING (CONFIRMED+REFUTED)** | LOW | Extract a single BuildFeatureList helper. | **DEFERRED — do not act without re-reading source** |
| 17 | Stale protocol version constant '1.0.0' in version-check path (protocol is 2.0.0) | `AddonExtension/dc_addon_protocol.cpp:2930` | LOW | dead-code | NOT VERIFIED | | Remove obsolete handler or fix the constant. | deferred |
| 18 | avg_response_time_ms running-average double-counts new responses | `AddonExtension/dc_addon_protocol.cpp:2233` | LOW | bug | NOT VERIFIED | | Fix SQL ordering. Telemetry-only. | deferred |
| 19 | s_CompletedRequestTimings not cleared on logout (residual growth) | `AddonExtension/dc_addon_protocol.cpp:3318` | LOW | memory-leak | NOT VERIFIED | | Add erase() in logout cleanup. | deferred |
| 20 | Dead extern declaration of sWorldMapAreaStore | `AddonExtension/dc_addon_world.cpp:39` | LOW | dead-code | NOT VERIFIED | | Remove. | **FIXED (Wave 2, bundled with #15)** |
| 21 | Fragile batch sub-message boundary heuristic can misparse data | `dc_addon_namespace.h:1177` | LOW | bug | NOT VERIFIED | | Encode explicit field count/length prefix. | deferred |
| 22 | Each inbound message is parsed twice (router reparses raw string) | `AddonExtension/dc_addon_protocol.cpp:3628` | LOW | performance | NOT VERIFIED | | Add a Route(Player*, ParsedMessage const&) overload. | deferred |
| 23 | ctype functions called on raw char without unsigned-char cast | `AddonExtension/dc_addon_protocol.cpp:3344` | LOW | convention | NOT VERIFIED | | Cast to unsigned char. | deferred |

## AddonExt-Gameplay

**Files reviewed:** `dc_addon_upgrade.cpp`, `dc_addon_mythicplus.cpp/.h`, `dc_addon_hlbg.cpp/.h`, `dc_addon_seasons.cpp`, `dc_addon_leaderboards.cpp`, `dc_addon_transmutation.cpp/.h`, `src/common/Utilities/StringFormat.h`

**Health note:** Newer files (leaderboards, seasons, vault/HUD paths) are in good shape. Standout problem was dc_addon_hlbg.cpp's legacy stats/leaderboard path building SQL AND JSON with printf specifiers against fmt-based StringFormat — malformed queries and payloads, now fixed. Two Mythic+ handlers were blocking the world thread; fixed to async. ~8 dead push-functions remain (report-only).

| # | Title | File:Line | Severity | Category | Verify Verdict | Corrected Severity | Suggested fix | Status |
|---|---|---|---|---|---|---|---|---|
| 24 | HLBG stats/leaderboard handlers build SQL and JSON with printf specifiers passed to fmt-based StringFormat | `AddonExtension/dc_addon_hlbg.cpp:986` | HIGH | bug | CONFIRMED | MEDIUM/HIGH (passes disagree) | Convert to {} placeholders, JSON-escape player_name. | **FIXED (Wave 2)** |
| 25 | Two live Mythic+ handlers issue synchronous CharacterDatabase.Query() on the world thread | `AddonExtension/dc_addon_mythicplus.cpp:332` | MEDIUM | performance | CONFIRMED | — | Convert to EnqueueQueryCallback/AsyncQuery. | **FIXED (Wave 2)** |
| 26 | Dead Mythic+ addon push-functions (never called anywhere) | `AddonExtension/dc_addon_mythicplus.cpp:1259` | LOW | dead-code | NOT VERIFIED | | Delete or wire up. | deferred |
| 27 | HudCacheMgr per-instance maps grow unbounded (pruned only on ClearCache) | `AddonExtension/dc_addon_mythicplus.cpp:1296` | LOW | memory-leak | NOT VERIFIED | | Add TTL-based eviction in Update(). | deferred |

## AddonExt-Collection

**Files reviewed:** `dc_addon_collection.cpp/.h`, `dc_addon_wardrobe.cpp`, `dc_addon_forms.cpp`, `dc_addon_beastmaster.cpp`, `dc_addon_graveyard.cpp`, `dc_addon_death_markers.cpp/.h`

**Health note:** Large (8.8k + 3.2k lines) but generally well-engineered: cache-backed with TTLs, N+1s de-duped into preloaded maps, ObjectGuid used correctly, mutex-guarded. Standout defect (client-reachable null-deref crash) fixed. Batch-teach shared_ptr self-cycle leak fixed. Forms/Beastmaster/Graveyard/DeathMarkers clean.

| # | Title | File:Line | Severity | Category | Verify Verdict | Corrected Severity | Suggested fix | Status |
|---|---|---|---|---|---|---|---|---|
| 28 | Client-triggerable null-pointer crash: SetTitle(nullptr) to clear active title | `AddonExtension/dc_addon_collection.cpp:6042` | HIGH | bug | CONFIRMED | — | Use SetCurrentTitle(nullptr, true). | **FIXED (Wave 2)** |
| 29 | Memory leak: self-referential shared_ptr cycle in batched spell-teach survives logout | `AddonExtension/dc_addon_collection.cpp:3292` | MEDIUM | memory-leak | CONFIRMED | — | Do not self-capture the tick; use a plain state struct. | **FIXED (Wave 2)** |
| 30 | Blocking GROUP BY query on the world thread on every mount/dismount | `AddonExtension/dc_addon_collection.cpp:4217` | LOW | performance | NOT VERIFIED | | Cache the account mount count. | deferred |
| 31 | Unbounded static per-account maps never pruned (slow leaks) | `AddonExtension/dc_addon_wardrobe.cpp:1976` | LOW | memory-leak | NOT VERIFIED | | Add periodic sweeping. | deferred |
| 32 | Community vote counters incremented without verifying the vote insert succeeded | `AddonExtension/dc_addon_wardrobe.cpp:2019` | LOW | error-handling | NOT VERIFIED | | Gate counter update on insert success. | deferred |
| 33 | Duplicated helper functions within the unit (JSON emitters, FNV-1a) | `AddonExtension/dc_addon_wardrobe.cpp:736` | LOW | duplicate | NOT VERIFIED | | Hoist into a shared internal header. | deferred |

## GuildHousing

**Files reviewed:** all `GuildHousing/*` files.

**Health note:** In good overall health, careful Phase-B migration from shared-phase model to per-guild dungeon instances, obsolete branches documented and removed. No HIGH-severity issues. Main residue: a dead script, a stale include, a large copy-paste pair beginning to drift, a couple of defensive gaps.

| # | Title | File:Line | Severity | Category | Verify Verdict | Corrected Severity | Suggested fix | Status |
|---|---|---|---|---|---|---|---|---|
| 34 | SpawnNPC and SpawnObject are ~130-line near-duplicates that have already drifted | `GuildHousing/dc_guildhouse_butler.cpp:827` | MEDIUM | duplicate | CONFIRMED | LOW | Extract a single shared helper. | deferred (confirmed but downgraded, low priority) |
| 35 | GuildHouseDecorationScaleScript is dead code under the instanced model | `GuildHousing/dc_guildhouse_decorations.cpp:1156` | LOW | dead-code | NOT VERIFIED | | Delete. | deferred |
| 36 | Stale #include of GOMove.h in decorations | `GuildHousing/dc_guildhouse_decorations.cpp:28` | LOW | dead-code | NOT VERIFIED | | Remove. | deferred |
| 37 | Unguarded guild->GetMember(...)->IsRankNotLower() in butler | `GuildHousing/dc_guildhouse_butler.cpp:402` | LOW | error-handling | NOT VERIFIED | | Null-check guild/memberMe. | deferred |
| 38 | Seller NPC issues raw uncached ownership queries instead of the cached GetGuildHouseData | `GuildHousing/dc_guildhouse_npcs.cpp:72` | LOW | performance | NOT VERIFIED | | Route through cache. | deferred |
| — | GuildHousing FormatGold duplicate vs DCUtils::FormatCoins | `dc_guildhouse_decorations.cpp` / `dc_guildhouse_npcs.cpp:611` | LOW | duplicate | — | — | Route through DCUtils::FormatCoins. | **INVESTIGATED (Wave 3), deliberately NOT applied — see master summary** |

## Progression-Prestige+Init

**Files reviewed:** `Progression/Prestige/*`, `Progression/FirstStart/*`, `Progression/Accountwide/*`

**Health note:** Good shape, post-audited: async DB reads, std::call_once caches, prestige token/essence grants routed through the CrossSystem Rewards facade. No dangling pointers, discarded callbacks, injection, or leaks found.

| # | Title | File:Line | Severity | Category | Verify Verdict | Corrected Severity | Suggested fix | Status |
|---|---|---|---|---|---|---|---|---|
| 39 | Challenge stat bonus is stored and announced but never applied to player stats | `Progression/Prestige/dc_prestige_challenges.cpp:451` | MEDIUM | bug | CONFIRMED | — | Wire the accumulated bonus into the prestige stat-mod aura. | **FIXED (Wave 2)** |
| 40 | '%u' printf specifier in fmt-based PSendSysMessage prints literal "%u" | `Progression/FirstStart/dc_firststart.cpp:627` | MEDIUM | bug | CONFIRMED | LOW | Replace with {}. | deferred (confirmed, downgraded to LOW priority) |
| 41 | Dead PlayerScript method OnPlayerJoinedGroup (no matching virtual) | `Progression/Prestige/dc_prestige_challenges.cpp:525` | LOW | dead-code | NOT VERIFIED | | Delete. | deferred |
| 42 | Unreachable dead code after if/else that both return in PerformPrestige | `Progression/Prestige/dc_prestige_system.cpp:339` | LOW | dead-code | NOT VERIFIED | | Move debug log above the branch. | deferred |
| 43 | Unreachable decrement branch in CalculateXPBonus | `Progression/Prestige/dc_prestige_alt_bonus.cpp:166` | LOW | dead-code | NOT VERIFIED | | Remove. | deferred |
| 44 | dc_login_announce broadcasts unconditionally, overlaps FirstStart PlayerAnnounce | `Progression/FirstStart/dc_login_announce.cpp:47` | LOW | duplicate | NOT VERIFIED | | Add config toggle / consolidate. | deferred |
| 45 | Per-tick global mutex lock for every online player in prestige OnPlayerUpdate | `Progression/Prestige/dc_prestige_system.cpp:1030` | LOW | performance | NOT VERIFIED | | Short-circuit with an atomic counter. | deferred |

## BlackwingDescent

**Files reviewed:** all `BlackwingDescent/*` files + `PORT_NOTES.md`.

**Health note:** Generally careful port; no crash-class dangling-pointer or leak bugs. Systemic problem: 6 ported OnSpellCastFinished hooks — PORT_NOTES.md claimed all were empty stubs with relocated logic, but 4 were non-empty and NOT relocated, silently killing real mechanics. 1 of those 4 (Chimaeron) fixed this round with corrected PORT_NOTES; the other 3 remain (Maloriak, blackwing_descent.cpp ×2, Nefarian's End ×2) — report only.

| # | Title | File:Line | Severity | Category | Verify Verdict | Corrected Severity | Suggested fix | Status |
|---|---|---|---|---|---|---|---|---|
| 46 | Chimaeron reads uninitialized _killedPlayerCount member | `BlackwingDescent/boss_chimaeron.cpp:215` | MEDIUM | bug | CONFIRMED | — | Initialize to 0. | **FIXED (Wave 2)** |
| 47 | Chimaeron Feud / Bile-O-Tron knockout mechanic is dead (non-empty OnSpellCastFinished never invoked) | `BlackwingDescent/boss_chimaeron.cpp:240` | MEDIUM | bug | CONFIRMED | — | Relocate to a SpellScript AfterCast hook. | **FIXED (Wave 2)** |
| 48 | Maloriak aberration lifetime cap defeated (increment trapped in dead OnSpellCastFinished) | `BlackwingDescent/boss_maloriak.cpp:340` | MEDIUM | bug | CONFIRMED | LOW | Move increment to a real hook. | deferred (confirmed, downgraded) |
| 49 | Maloriak Reset() does not reset vial-cycle state; stale after a wipe | `BlackwingDescent/boss_maloriak.cpp:255` | MEDIUM | bug | CONFIRMED | — | Reset counters in Reset(). | **FIXED (Wave 2b)** |
| 50 | Two more live mechanics dead in non-empty OnSpellCastFinished hooks | `BlackwingDescent/blackwing_descent.cpp:439` | LOW | bug | NOT VERIFIED | | Relocate to SpellScript hooks. | deferred |
| 51 | Magmaw JustEngagedWith uses break instead of return after EnterEvadeMode | `BlackwingDescent/boss_magmaw.cpp:234` | LOW | bug | NOT VERIFIED | | Replace break with return. | deferred |
| 52 | Magmaw EnterEvadeMode calls summons.DespawnAll() twice | `BlackwingDescent/boss_magmaw.cpp:296` | LOW | duplicate | NOT VERIFIED | | Delete duplicate line. | deferred |
| 53 | Global mutable unordered_map read via non-const operator[] from instance AI | `BlackwingDescent/boss_omnotron_defense_system.cpp:215` | LOW | race-condition | NOT VERIFIED | | Make maps const, use .at(). | deferred |
| 54 | InstanceScript save/load streams a uint8 as a raw char | `BlackwingDescent/instance_blackwing_descent.cpp:493` | LOW | convention | NOT VERIFIED | | Serialize as uint32. | deferred |
| 55 | Atramedes Obnoxious Fiend has a dead EVENT_SAY_INTRO switch case | `BlackwingDescent/boss_atramedes.cpp:632` | LOW | dead-code | NOT VERIFIED | | Remove. | deferred |
| 56 | Maloriak Master Adventurer award calls SetTitle twice | `BlackwingDescent/boss_maloriak.cpp:1254` | LOW | duplicate | NOT VERIFIED | | Remove duplicate call. | deferred |

## Progression-ChallengeMode

**Files reviewed:** all `Progression/ChallengeMode/*` files, `dc_script_loader.cpp`, `Commands/cs_dc_challenge_modes.cpp`.

**Health note:** Functionally coherent, well-written live paths. Main problems: a large dead reward-config/stats-tracking subsystem (deleted this round), missing re-entry guards on 2 of 3 hardcore-death handlers (fixed), and blocking DB queries at death time (fixed).

| # | Title | File:Line | Severity | Category | Verify Verdict | Corrected Severity | Suggested fix | Status |
|---|---|---|---|---|---|---|---|---|
| 57 | Entire reward + stats subsystem is dead code | `Progression/ChallengeMode/dc_challenge_modes_customized.cpp:557` | MEDIUM | dead-code | CONFIRMED | — | Delete (chose delete over wire-up — see master summary). | **FIXED (Wave 2b, deleted)** |
| 58 | Hardcore creature/PVP death handlers lack the HARDCORE_DEAD re-entry guard | `Progression/ChallengeMode/ChallengeModeScripts.cpp:95` | MEDIUM | bug | CONFIRMED | — | Add the same guard OnPlayerJustDied already has. | **FIXED (Wave 2)** |
| 59 | Blocking synchronous DB query on the world thread during hardcore death | `Progression/ChallengeMode/dc_challenge_mode_database.cpp:67` | MEDIUM | performance | CONFIRMED | LOW/MEDIUM (passes disagree) | Compute active-modes in-memory instead of re-querying. | **FIXED (Wave 2)** |
| 60 | Stale forward declaration AddSC_challenge_mode_shrine() for a non-existent file | `Progression/ChallengeMode/dc_challenge_modes.h:145` | LOW | dead-code | NOT VERIFIED | | Remove. | **FIXED (Wave 2b, bundled with #57)** |
| 61 | Reward-config parser extracts level into uint8 reading a single char | `Progression/ChallengeMode/dc_challenge_modes_customized.cpp:568` | LOW | bug | NOT VERIFIED | | N/A — dead code removed with #57. | moot (removed with #57) |
| 62 | Duplicated Iron Man helper logic across three files | `Progression/ChallengeMode/dc_challenge_mode_enforcement.cpp:12` | LOW | duplicate | NOT VERIFIED | | Hoist into one shared helper. | deferred |
| 63 | Inconsistent item-quality restriction text vs enforced behavior | `Progression/ChallengeMode/dc_challenge_mode_enforcement.cpp:37` | LOW | other | NOT VERIFIED | | Reconcile text vs behavior. | deferred |
| 64 | challengeEnabledForPlayer dereferences player without a null check | `Progression/ChallengeMode/dc_challenge_modes_customized.cpp:370` | LOW | error-handling | NOT VERIFIED | | Add null check. | **FIXED (Wave 2b, bundled with #57)** |
| 65 | Login-prevention issues an async DB query on every login for every player | `Progression/ChallengeMode/ChallengeModeScripts.cpp:162` | LOW | performance | NOT VERIFIED | | Gate on cheap in-memory signal first. | deferred |
| 66 | Known double-registration of ChallengeModeScripts | `dc_script_loader.cpp:362` | LOW | duplicate | REFUTED | — | (Registration itself already fixed in Wave 1.) | **FIXED (Wave 1)** — refutation concerned root-cause attribution of #58, not whether the fix was needed |

## GiantIsles

**Files reviewed:** all `GiantIsles/*` files.

**Health note:** Functional, well-structured; ObjectGuids not raw pointers, EventMap/urand used correctly. Most impactful defects: pervasive printf-vs-fmt bug (fixed), and 3 world-boss AIs using a dead TrinityCore-only hook name so world-boss spawn events never fired (fixed). No crashes or dangling-pointer hazards.

| # | Title | File:Line | Severity | Category | Verify Verdict | Corrected Severity | Suggested fix | Status |
|---|---|---|---|---|---|---|---|---|
| 67 | printf-style specifiers passed to fmt-based PSendSysMessage | `GiantIsles/dc_giant_isles_war_economy.cpp:102` | MEDIUM | bug | CONFIRMED | — | Replace with {}. | **FIXED (Wave 2)** |
| 68 | World-boss JustAppeared() is not an AzerothCore hook → OnBossSpawned never fires | `GiantIsles/boss_nalak.cpp:134` | MEDIUM | bug | CONFIRMED | — | Rename to JustRespawned() override. | **FIXED (Wave 2)** |
| 69 | Cannon SpawnShipForPlayer leaks PendingShipSpawn flag on spawn failure | `GiantIsles/dc_giant_isles_cannon_quest.cpp:424` | MEDIUM | error-handling | CONFIRMED | — | Erase the flag on failure. | **FIXED (Wave 2)** |
| 70 | Invasion reward uses player->AddItem with no full-bag fallback | `GiantIsles/dc_giant_isles_invasion.cpp:2294` | MEDIUM | bug | CONFIRMED | — | Route through RewardDistributor::DistributeItem. | **FIXED (Wave 2)** |
| 71 | ShipLastRegisteredHitSec map is never erased → unbounded growth | `GiantIsles/dc_giant_isles_cannon_quest.cpp:99` | LOW | memory-leak | NOT VERIFIED | | Erase on ship despawn/exit. | deferred |
| 72 | Water monster JustDespawned() is not an AC hook | `GiantIsles/dc_giant_isles_water_monster.cpp:315` | LOW | dead-code | NOT VERIFIED | | Send event explicitly on the idle-timeout path. | deferred |
| 73 | Water monster Reset() clears eventSummon before testing it | `GiantIsles/dc_giant_isles_water_monster.cpp:278` | LOW | dead-code | NOT VERIFIED | | Don't reset inside Reset(). | deferred |
| 74 | Blocking WorldDatabase.Query on the world update thread in boss-rotation refresh | `GiantIsles/dc_giant_isles_zone.cpp:263` | LOW | performance | NOT VERIFIED | | Convert to async or preload once. | deferred |
| 75 | Zone random-rare-spawn manager is a placeholder that never spawns anything | `GiantIsles/dc_giant_isles_zone.cpp:580` | LOW | dead-code | NOT VERIFIED | | Product decision: finish or remove. | deferred |
| 76 | go_ancient_stone::CanGameObjectGossipHello is not an override (dead method) | `GiantIsles/dc_giant_isles_water_monster.cpp:94` | LOW | dead-code | NOT VERIFIED | | Delete. | deferred |
| 77 | ForceStartCombat and GetNow* helpers duplicated verbatim across invasion TUs | `GiantIsles/dc_giant_isles_invasion_npcs.cpp:81` | LOW | duplicate | NOT VERIFIED | | Move to shared internal header. | deferred |
| 78 | Raw UNIT_FIELD_FLAGS SetFlag/RemoveFlag used instead of typed helpers | `GiantIsles/dc_giant_isles_water_monster.cpp:179` | LOW | convention | NOT VERIFIED | | Use SetUnitFlag/RemoveUnitFlag. | deferred |
| 79 | Cannon hit dedup window anchored only to the cast path | `GiantIsles/dc_giant_isles_cannon_quest.cpp:683` | LOW | bug | NOT VERIFIED | | Have all 3 hit paths write the dedup timestamp. | deferred |

## AddonExt-Social

**Files reviewed:** `dc_addon_welcome.cpp`, `dc_addon_breaking_news.cpp/.h`, `dc_addon_groupfinder*.cpp/.h`, `dc_addon_matchmaking.cpp/.h`, `dc_addon_duels.cpp`, `dc_addon_qos.cpp`, `dc_addon_extension_loader.cpp`, `CrossSystem/CENTRALIZATION_MIGRATION_PLAN.md`, `CrossSystem/CrossSystemVaultUtils.h`, `CrossSystem/LeaderboardUtils.h`

**Health note:** Generally good shape; careful ObjectGuid usage, async queries, EscapeString in nearly all write paths. Two real problems fixed: one missed EscapeString (SQL injection) and a state-ownership split where write handlers bypassed the read-cache. Remaining items are low-severity.

| # | Title | File:Line | Severity | Category | Verify Verdict | Corrected Severity | Suggested fix | Status |
|---|---|---|---|---|---|---|---|---|
| 80 | SQL injection: client-controlled feature string inserted unescaped | `AddonExtension/dc_addon_welcome.cpp:674` | HIGH | security | CONFIRMED | — | Escape before formatting. | **FIXED (Wave 2)** |
| 81 | Scheduled events/signups created at runtime never appear until server restart | `AddonExtension/dc_addon_groupfinder.cpp:1265` | MEDIUM | bug | CONFIRMED | — | Sync write handlers into the read-cache. | **FIXED (Wave 2)** |
| 82 | Dead manager event methods; two carry a latent LAST_INSERT_ID cross-connection bug | `AddonExtension/dc_addon_groupfinder_mgr.cpp:987` | MEDIUM | dead-code | CONFIRMED | LOW | Delete unused definitions. | **FIXED (Wave 2, bundled with #81 — deleted the dead methods)** |
| 83 | M+ rating requirement is never persisted, so the gate is always inert | `AddonExtension/dc_addon_groupfinder_mgr.cpp:617` | LOW | bug | NOT VERIFIED | | Wire end-to-end or remove. | deferred |
| 84 | Blocking DB query executed while holding the manager mutex | `AddonExtension/dc_addon_groupfinder_mgr.cpp:674` | LOW | performance | NOT VERIFIED | | Pre-load before taking the lock. | deferred |
| 85 | Duel leaderboard JSON hand-built with snprintf and %s | `AddonExtension/dc_addon_duels.cpp:272` | LOW | convention | NOT VERIFIED | | Use JsonValue/StringFormat. | deferred |

## HinterlandBG

**Files reviewed:** all `HinterlandBG/*` files.

**Health note:** Core BattlegroundHLBG in good shape; ObjectGuids, urand/EventMap/TaskScheduler, typed flag helpers, double-fire guards. No dangling-pointer, discarded-callback, or injection issues. Real weaknesses: blocking DB queries, an unreset AFK counter, and dead/duplicate code — all report-only this round except the affix/weather dedup (Wave 3).

| # | Title | File:Line | Severity | Category | Verify Verdict | Corrected Severity | Suggested fix | Status |
|---|---|---|---|---|---|---|---|---|
| 86 | Scoreboard/stats gossip runs multiple blocking synchronous DB queries | `HinterlandBG/hlbg_scoreboard_npc.cpp:248` | MEDIUM | performance | NOT VERIFIED | | Move to async + cache with TTL. | deferred |
| 87 | HLBGPlayerStats::OnPlayerWin uses blocking DirectExecute per winner | `HinterlandBG/hlbg_utils.cpp:68` | MEDIUM | performance | NOT VERIFIED | | Use async prepared statement. | deferred |
| 88 | AFK infraction counter is never reset — leaks state across matches | `HinterlandBG/BattlegroundHLBG.h:141` | MEDIUM | bug | NOT VERIFIED | | Clear in ResetMatchState()/ClearPlayerTracking(). | deferred |
| 89 | Dead code: several unused helpers and constants in hlbg_constants.h | `HinterlandBG/hlbg_constants.h:222` | LOW | dead-code | NOT VERIFIED | | Delete unused helpers/constants. | deferred |
| 90 | Duplicated spell constant and weather-name mapping | `HinterlandBG/BattlegroundHLBG.cpp:33` | LOW | duplicate | NOT VERIFIED | | Use shared constant; collapse weather-name functions. | **PARTIALLY FIXED (Wave 3 — weather-name collapse)** |
| 91 | Thrall/Varian lore NPCs: unreachable event path + copy-paste wrong-zone buff | `HinterlandBG/hlbg_npc_varian.cpp:152` | LOW | dead-code | NOT VERIFIED | | Product decision: delete or fix. | deferred |
| 92 | TryConsumeGossipCooldown static map grows unbounded | `HinterlandBG/hlbg_scoreboard_npc.cpp:53` | LOW | memory-leak | NOT VERIFIED | | Evict stale entries opportunistically. | deferred |
| 93 | HLBGPlayerStats::OnTeamWin is a no-op stub that claims to update wins | `HinterlandBG/hlbg_utils.cpp:73` | LOW | dead-code | NOT VERIFIED | | Implement or remove. | deferred |
| 94 | O(N^2) HUD-metric recomputation in per-player snapshot loops | `HinterlandBG/BattlegroundHLBG.cpp:887` | LOW | performance | NOT VERIFIED | | Compute once, pass to send helper. | deferred |

## Commands

**Files reviewed:** all `Commands/*` files.

**Health note:** Mixed quality: newer/refactored files clean, older consolidated files (`cs_dc_item_upgrade`, `cs_dc_dungeonquests`, `cs_dc_seasonal_rewards`) carried heavy legacy printf-style code silently broken by fmt-based PSendSysMessage, plus 2 world-crash-class bugs and a buffer-overflow/UB. All fixed this round. No dead code found — all 12 AddSC_* entry points registered.

| # | Title | File:Line | Severity | Category | Verify Verdict | Corrected Severity | Suggested fix | Status |
|---|---|---|---|---|---|---|---|---|
| 95 | sscanf writes into an empty std::string's buffer (buffer overflow / UB) | `Commands/cs_dc_item_upgrade.cpp:406` | HIGH | bug | CONFIRMED | — | Use a fixed local buffer. | **FIXED (Wave 2)** |
| 96 | std::stoul on unvalidated args crashes the world server on non-numeric input | `Commands/cs_dc_dungeonquests.cpp:163` | HIGH | error-handling | CONFIRMED | — | Use Acore::StringTo<uint32> with a guard. | **FIXED (Wave 2)** |
| 97 | CompletedAchievement(nullptr) on an invalid achievement id → null-deref crash | `Commands/cs_dc_dungeonquests.cpp:520` | HIGH | bug | CONFIRMED | — | Null-check the lookup first. | **FIXED (Wave 2)** |
| 98 | Unbounded sscanf("%s") into 13-byte stack buffers (stack overflow) | `Commands/cs_dc_dungeonquests.cpp:209` | MEDIUM | security | CONFIRMED | — | Bound the conversion width. | **FIXED (Wave 2)** |
| 99 | Stress-test loop blocks the world thread via sleep_for with uncapped delay/infinite loops | `Commands/cs_dc_stresstest.cpp:8524` | MEDIUM | performance | CONFIRMED | — | Cap sleepMs and loop count. | **FIXED (Wave 2)** |
| 100 | Pervasive printf-style specifiers produce broken output in upgrade commands | `Commands/cs_dc_item_upgrade.cpp:719` | MEDIUM | bug | CONFIRMED | — | Convert to {} placeholders (~63 lines). | **FIXED (Wave 2)** |
| 101 | Entire seasonal-rewards command file uses dead printf specifiers | `Commands/cs_dc_seasonal_rewards.cpp:62` | MEDIUM | bug | CONFIRMED | — | Convert to {} / {:.2f} (22 sites). | **FIXED (Wave 2)** |
| 102 | dcquests admin commands emit literal printf specifiers | `Commands/cs_dc_dungeonquests.cpp:146` | MEDIUM | bug | CONFIRMED | — | Convert to {} placeholders (32 sites). | **FIXED (Wave 2)** |
| 103 | guildhouse: std::stoul unguarded + blocking INSERT with raw float interpolation | `Commands/cs_dc_guildhouse.cpp:326` | LOW | error-handling | NOT VERIFIED | | Use StringTo + prepared statement. | deferred |
| 104 | cs_dc_addons dedupe/difficulty helpers use printf specifiers | `Commands/cs_dc_addons.cpp:203` | LOW | bug | NOT VERIFIED | | Convert to {}. | deferred |
| 105 | challenge_modes prints "50%%" literally | `Commands/cs_dc_challenge_modes.cpp:68` | LOW | convention | NOT VERIFIED | | Use single %. | deferred |
| 106 | Player-invokable seasonal upgrade commands run blocking DB queries | `Commands/cs_dc_item_upgrade.cpp:1230` | LOW | performance | NOT VERIFIED | | Move to async or restrict to GM. | deferred |

## ItemUpgrades

**Files reviewed:** all `ItemUpgrades/*` files + live `acore_chars` schema.

**Health note:** Core upgrade path functional and cached. Carries a large amount of dead/half-wired code. Most seriously: real schema drift — the mastery INSERT on the hot upgrade path targeted nonexistent columns, failing silently on every upgrade. Fixed this round with a companion migration.

| # | Title | File:Line | Severity | Category | Verify Verdict | Corrected Severity | Suggested fix | Status |
|---|---|---|---|---|---|---|---|---|
| 107 | Mastery INSERT on every upgrade targets non-existent columns, omits PK | `ItemUpgrades/ItemUpgradeManager.cpp:615` | HIGH | bug | CONFIRMED | MEDIUM | Rewrite to match deployed schema. | **FIXED (Wave 2b)** |
| 108 | Progression/achievement/leaderboard queries reference columns absent from the mastery table | `ItemUpgrades/ItemUpgradeProgressionImpl.cpp:50` | MEDIUM | bug | CONFIRMED | — | Reconcile column convention / migrate table. | **FIXED (Wave 2b, via migration adding the missing columns)** |
| 109 | go_heirloom_cache: unsynchronized process-global static caches | `ItemUpgrades/go_heirloom_cache.cpp:79` | MEDIUM | race-condition | CONFIRMED | LOW | Guard with a mutex. | deferred (confirmed, downgraded) |
| 110 | Guild stats: average_ilvl_increase populated from the wrong SELECT column | `ItemUpgrades/ItemUpgradeAdvancedImpl.cpp:539` | MEDIUM | bug | CONFIRMED | — | Fix field index / SELECT list. | **FIXED (Wave 2b, bundled with #107/#108)** |
| 111 | Two CommandScript classes defined but never registered | `ItemUpgrades/ItemUpgradeAdvancedImpl.cpp:665` | MEDIUM | dead-code | CONFIRMED | LOW | Delete or register. | deferred (confirmed, downgraded) |
| 112 | TierConversionManager fully dead, incl. a latent tier_difference=0 bug | `ItemUpgrades/ItemUpgradeExchangeImpl.cpp:538` | LOW | dead-code | NOT VERIFIED | | Product decision. | deferred |
| 113 | Transmutation recipe/session machinery dead; queries a non-existent table | `ItemUpgrades/ItemUpgradeExchangeImpl.cpp:34` | LOW | dead-code | NOT VERIFIED | | Strip down to live responsibility. | deferred |
| 114 | Advanced stub managers (Trading/Transmog/Optimization) unused | `ItemUpgrades/ItemUpgradeAdvancedImpl.cpp:217` | LOW | dead-code | NOT VERIFIED | | Product decision. | deferred |
| 115 | ArtifactMastery rank-up/tier-unlock/achievement pipeline never invoked | `ItemUpgrades/ItemUpgradeProgressionImpl.cpp:76` | LOW | dead-code | NOT VERIFIED | | Wire in or remove. | deferred |
| 116 | Divergent cost/ilvl model: formula vs DB-driven cost | `ItemUpgrades/ItemUpgradeMechanicsImpl.cpp:56` | LOW | duplicate | NOT VERIFIED | | Make diagnostics read the DB-backed source. | deferred |
| 117 | Dead helper functions and dead persistence methods | `ItemUpgrades/ItemUpgradeMechanicsImpl.cpp:125` | LOW | dead-code | NOT VERIFIED | | Delete; keep one upsert path. | deferred |
| 118 | Single-item respec bypasses cooldown/daily limit, logs to wrong table | `ItemUpgrades/ItemUpgradeAdvancedImpl.cpp:59` | LOW | bug | NOT VERIFIED | | Gate on CanRespec, fix logging. | deferred |
| 119 | Blocking DB reads reachable from stat-apply/proc hooks on cache miss | `ItemUpgrades/ItemUpgradeManager.cpp:724` | LOW | performance | NOT VERIFIED | | Serve from cache only. | deferred |
| 120 | Vendor/Curator NPCs build an unused greeting string on every gossip open | `ItemUpgrades/ItemUpgradeNPC_Vendor.cpp:42` | LOW | dead-code | NOT VERIFIED | | Remove or surface it. | deferred |

## MythicPlus

**Files reviewed:** all `MythicPlus/*` files.

**Health note:** Broadly well-structured. One genuine use-after-free in the run-fail path, fixed. Dead PlayerScript hook silently dropped run cancellation, fixed. Two divergent reward item-level formulas collapsed to one. Affix handlers keeping per-run state in shared singletons, fixed.

| # | Title | File:Line | Severity | Category | Verify Verdict | Corrected Severity | Suggested fix | Status |
|---|---|---|---|---|---|---|---|---|
| 121 | Use-after-free: HandleFailState erases the instance state then dereferences it | `MythicPlus/dc_mythicplus_run_manager.cpp:1313` | HIGH | bug | CONFIRMED | — | Copy fields to locals before erase; erase last. | **FIXED (Wave 2b)** |
| 122 | Dead PlayerScript hook OnPlayerLeaveWorld — never dispatched | `MythicPlus/dc_mythicplus_core_scripts.cpp:546` | MEDIUM | dead-code | CONFIRMED | — | Move logic to a real hook (OnPlayerLeaveAll). | **FIXED (Wave 2b, bundled with #121)** |
| 123 | Two divergent GetItemLevelForKeystoneLevel formulas | `MythicPlus/dc_mythicplus_run_manager.cpp:3061` | MEDIUM | duplicate | CONFIRMED | — | Delete one, use the canonical constants-table version. | **FIXED (Wave 2b, bundled with #121)** |
| 124 | Affix handlers keep per-run state in shared singletons — concurrent instances clobber each other | `MythicPlus/dc_mythicplus_affix_handlers.cpp:228` | MEDIUM | race-condition | CONFIRMED | — | Key state per-instance like _instanceStates already does. | **FIXED (Wave 3)** |
| 125 | Spectator uses printf specifiers against fmt-based PSendSysMessage | `MythicPlus/dc_mythicplus_spectator.cpp:541` | MEDIUM | convention | CONFIRMED | — | Convert to {}. | **FIXED (Wave 3)** |
| 126 | Dead alternate keystone-progression and stat-writer API | `MythicPlus/dc_mythicplus_run_manager.cpp:1951` | LOW | dead-code | NOT VERIFIED | | Remove or wire up. | deferred |
| 127 | Dead scaling path and stale declarations in difficulty scaling | `MythicPlus/dc_mythicplus_difficulty_scaling.cpp:171` | LOW | dead-code | NOT VERIFIED | | Delete or consolidate. | deferred |
| 128 | Dead code across portal selector, font-of-power, spectator sync/replay APIs | `MythicPlus/dc_mythicplus_spectator.cpp:1171` | LOW | dead-code | NOT VERIFIED | | Wire in or remove. | deferred |
| 129 | SyncHudToSpectator default-inserts an uninitialized SpectateableRun | `MythicPlus/dc_mythicplus_spectator.cpp:1176` | LOW | bug | NOT VERIFIED | | Use find(), give default member initializers. | deferred |
| 130 | Out-of-bounds array read in .spectate stream when mode > 2 | `MythicPlus/dc_mythicplus_spectator.cpp:1602` | LOW | bug | NOT VERIFIED | | Clamp/validate mode. | deferred |

## CrossSystem

**Files reviewed:** all `CrossSystem/*` files.

**Health note:** Architecturally clean; wired parts work correctly. Main problems: a large dead Adapters/DCSystem layer (product decision needed, not fixed), and season-resolution fragmentation (product decision needed). DbSchema exact-match fix and reward-routing fix applied this round.

| # | Title | File:Line | Severity | Category | Verify Verdict | Corrected Severity | Suggested fix | Status |
|---|---|---|---|---|---|---|---|---|
| 131 | Entire Adapters/DCSystem layer is dead code — never instantiated | `CrossSystem/CrossSystemAdapters.h:389` | MEDIUM | dead-code | NOT VERIFIED | | Product decision: wire up or delete. | **DEFERRED — needs product decision** |
| 132 | Two overlapping season resolvers disagree on order, default, and DB column | `CrossSystem/CrossSystemSeasonHelper.h:80` | MEDIUM | bug | NOT VERIFIED | | Collapse to one resolver. | **DEFERRED — needs design decision** |
| 133 | RewardDistributor LoadConfiguration can throw on the boot path from a malformed config row | `CrossSystem/RewardDistributor.cpp:86` | MEDIUM | error-handling | NOT VERIFIED | | Wrap in try/catch with a checked default. | deferred |
| 134 | Canonical DbSchema helper used wildcard-prone SHOW..LIKE instead of exact-match | `CrossSystem/CrossSystemDbSchema.h:35` | LOW | bug | NOT VERIFIED | | Reimplement over information_schema. | **FIXED (Wave 3)** |
| 135 | dc_cross_system_loader.h is entirely unused | `CrossSystem/dc_cross_system_loader.h:17` | LOW | dead-code | NOT VERIFIED | | Delete. | **FIXED (Wave 1)** |
| 136 | EventBus async path and several typed publishers are dead code | `CrossSystem/EventBus.cpp:256` | LOW | dead-code | NOT VERIFIED | | Remove or wire up. | deferred |
| 137 | Nine CrossSystemManager public hooks defined but never invoked | `CrossSystem/CrossSystemManager.cpp:342` | LOW | dead-code | NOT VERIFIED | | Wire in or remove. | deferred |
| 138 | Rewards AwardItemOrSeasonalCurrency non-seasonal path bypasses mail-on-full-bag fix | `CrossSystem/CrossSystemRewards.h:113` | LOW | bug | NOT VERIFIED | | Route through DistributeItem. | **FIXED (Wave 3)** |
| 139 | WorldBossMgr has no synchronization on mutable state touched from AI hooks and world Update | `CrossSystem/CrossSystemWorldBossMgr.cpp:167` | LOW | race-condition | NOT VERIFIED | | Guard maps with a mutex. | deferred |

---

For the cross-cutting/CrossSystem centralization list and the full high-confidence action list
(the source list Wave 2 was built from), see the original workflow output — condensed into
`AUDIT_CrossSystem_Candidates.md` and the wave log in `AUDIT_MASTER_SUMMARY.md`.
