# CrossSystem Centralization — Migration Plan

**Scope:** consolidate duplicated / cross-cutting code in `src/server/scripts/DC/*`
into the central `DC/CrossSystem` shared layer.

**Source:** multi-agent audit of all 25 DC subsystems (32 scanners + 7 cross-cutting
duplication sweeps, adversarially verified). The architecture is already sound —
CrossSystem owns the heavy machinery (Manager, EventBus, RewardDistributor,
SessionContext) and a mature helper set. The remaining work is **drift** (private
copies of central helpers), **bypass** (reward grants going around RewardDistributor),
and a few **gaps** (things reinvented N times with no canonical home).

This document covers the work **not yet done**. The low-risk mechanical wave and the
two real bugs were already applied (see "Already completed" below).

---

## Already completed (mechanical wave + bugs) — for reference

| Change | Files | Notes |
|--------|-------|-------|
| **Bug — DistributeItem silent reward loss** | `CrossSystem/RewardDistributor.cpp` | Full-bag branch now mails via `Player::SendItemRetrievalMail` and returns `true` (was `LOG_WARN` + `return false`). |
| **Bug — thread-unsafe `std::localtime`** | `CrossSystem/CrossSystemUtilities.h` (+ `AddonExtension/dc_addon_hlbg.cpp`, `Commands/cs_dc_item_upgrade.cpp`) | Added `DCUtils::FormatLocalTimestamp` (wraps thread-safe `Acore::Time::TimeBreakdown`); repointed the two strftime formatting sites. |
| **EscapeJson drift** | run_manager, font_of_power, phased_duels, hlbg_native_broadcast, dc_addon_hlbg, cs_dc_stresstest | 6 private copies now forward to `DCUtils::EscapeJson` (single source; fixes divergent control-char escaping). |
| **EscapeFmtBraces drift** | `ItemUpgrades/ItemUpgradeManager.cpp`, `ItemUpgrades/ItemUpgradeMechanicsImpl.cpp` | Deleted 2 copies; call `DCUtils::EscapeFmtBraces`. |
| **Dead code** | deleted `Hotspot/HotspotCore.h`; removed `Mechanics_GetCurrentSeason` | Orphaned header (no includers) + `[[maybe_unused]]` dead function. |

> Note on bug #3 (from the audit): "FirstStart `ParseIdList` drops id 0" is **not a bug**.
> FirstStart drops 0 because 0 is never a valid spell/achievement id; Hotspot keeps 0
> because map 0 (Eastern Kingdoms) is valid. The difference is context-appropriate.
> A shared parser must keep 0 (general case); FirstStart's callers don't care. See B4.

---

## A. Gaps — create a new shared helper (no canonical home today)

### A1. `DC::DbSchema` table/column existence helpers — **HIGH impact, medium effort**

The single most pervasive DB duplication in the tree: a `SELECT 1 FROM
information_schema.{TABLES,COLUMNS} WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=… LIMIT 1`
guard reimplemented 12–22× across 6+ subsystems, **with dangerous drift**:
- most use exact-match `information_schema`,
- `CollectionSystem/CollectionCore.cpp` uses `SHOW TABLES LIKE` / `SHOW COLUMNS FROM`
  (treats `_` and `%` as wildcards — subtly wrong),
- the `%s`/`ostringstream` variants (`cs_dc_stresstest.cpp`, guildhouse) are
  SQL-injection-shaped if ever fed an untrusted name.

**Target:** new `DC::DbSchema` (a.k.a. `DCUtils::DBSchema`) in `CrossSystemUtilities.h`
(small `.cpp` or header-only over `DatabaseEnv`), 4 functions:
```cpp
bool WorldTableExists(std::string_view table);
bool WorldColumnExists(std::string_view table, std::string_view column);
bool CharacterTableExists(std::string_view table);
bool CharacterColumnExists(std::string_view table, std::string_view column);
```
Lift `CollectionCore.h`'s clean 4-function shape as canonical, but standardize on
**exact-match `information_schema`** (drop the `SHOW … LIKE` wildcard form). Depends
only on `DatabaseEnv` (already a CrossSystem dep) → no layering break.

**Call sites to migrate (representative):**
`AddonExtension/dc_addon_protocol.cpp:110`, `dc_addon_breaking_news.cpp:52`,
`dc_addon_welcome.cpp:57`, `dc_addon_hlbg.cpp:134`, `dc_addon_aoeloot.cpp:121`;
`CollectionSystem/CollectionCore.cpp:133`; `GuildHousing/dc_guildhouse_manager.cpp:17`,
`dc_guildhouse_butler.cpp:109`, `dc_guildhouse_decorations.cpp:203`;
`GiantIsles/dc_giant_isles_zone.cpp:252`; `Commands/cs_dc_stresstest.cpp:758`;
`QOL/dc_breaking_news_qol.cpp:282`, `dc_aoeloot_unified.cpp:342`.

**Keep local:** the thin domain wrappers (`HasDeliveryLogTable`,
`HasGuildHouseLevelColumn`, `SpawnPresetsHaveMetadataColumns`, …) and their per-site
memoization — only the generic query core moves. `SpawnPresetsHaveMetadataColumns`
needs a multi-column / expected-count overload (or split into N single-column checks).

### A2. `DCUtils::MakeLargeGossipText` — **medium impact, low effort**

The body `return "|T" + icon + ":40:40:-18|t " + text;` is byte-identical across **9
files in 7 subsystems**, encoding a shared client-side inline-icon size convention with
zero engine coupling.

**Target:** add `inline std::string MakeLargeGossipText(std::string const& icon, std::string const& text)`
to `CrossSystemUtilities.h` (next to `GetQualityColor`/`FormatCoins`).

**Sites:** `AC/ac_flightmasters.cpp:50`, `AC/ac_guard_npc.cpp:124`,
`Jadeforest/jadeforest_flightmaster.cpp:30`, `Jadeforest/jadeforest_guards.cpp:67`,
`HinterlandBG/hlbg_scoreboard_npc.cpp:74`, `hlbg_npc_battlemaster.cpp`,
`DungeonQuests/npc_universal_quest_master.cpp`, `GuildHousing/dc_guildhouse_butler.cpp:45`,
`dc_dalaran_guard.cpp:58`. (Several are class statics → convert call sites to the free
function.) **Keep local:** icon-pre-bound variants like `MakeFlightText`.

### A3. `DC::MapCoords::SendPoiMarker` — **low impact, low effort**

Byte-identical anonymous-namespace `SendPoiMarker(player,x,y,icon,flags,importance,name)`
building an ad-hoc `SMSG_GOSSIP_POI` packet in two unrelated guard NPCs
(`AC/ac_guard_npc.cpp:102`, `GuildHousing/dc_dalaran_guard.cpp:36`). Depends only on
engine-public types → no leak. **Not** redundant with engine `PlayerMenu::SendPointOfInterest`
(that requires a DB-backed `points_of_interest` row; this sends arbitrary coords).

**Target:** `inline DC::MapCoords::SendPoiMarker` in `CrossSystemMapCoords.h`. Keep the
per-caller POI data structs local.

---

## B. Drift / dedup into existing helpers (medium effort)

### B1. Map/zone bounds + name lookups — **medium impact**
- Merge the 3 missing custom-zone rows (Azshara Crater 268, Stratholme Valley 6000,
  Hyjal Frontier 6100) into `CrossSystemMapCoords.h`'s `CustomBounds[]` so all 4 DC
  custom zones share one source. **⚠ Isles 5006 is already duplicated** between
  `HotspotMgr.cpp:357` and `CrossSystemMapCoords.h:64` **in transposed field order** —
  reconcile carefully (verify which order is correct against live minimap pins before
  collapsing). Keep Hotspot's inverse `TryGetZoneWorldBox` but derive it from the shared table.
- Add `DCUtils::GetZoneName(uint32)` / `GetMapName(uint32)` (DBC-backed
  `sAreaTableStore`/`sMapStore` with fallback) and dedup the ~10 open-coded lookups —
  **including the two inside `CrossSystemWorldBossMgr.cpp:219/308`**.
- Fold `AddonExtension/dc_addon_qos.cpp:2765` `ResolveNpcTooltipSpawnData` onto
  `DC::SpawnResolver::ResolveCreature` (add a `spawntimesecs` field to `ResolvedPosition`).

### B2. Leaderboard rank/fetch primitives — **medium impact**
- Add header-only `LeaderboardUtils::ComputeRank(table, metricCol, keyCol, keyVal, extraWhere)`
  and route the 3 scalar `rank = COUNT(*)+1 WHERE metric > (subquery)` reads:
  `ItemUpgrades/ItemUpgradeProgressionImpl.cpp:153`, `ItemUpgradeSeasonalImpl.cpp:441`,
  `AddonExtension/dc_addon_leaderboards.cpp:1297`. (Leave bulk `REPLACE…SELECT` cache writes alone.)
- The duplicate `GetClassNameFromId` / `GetArmorTypeForClass` copies in
  `cs_dc_stresstest.cpp:2455` and `dc_mythicplus_token_vendor.cpp:178` fold cleanly into
  the existing `LeaderboardUtils`/`VaultUtils` helpers now (low risk — verify byte-identical first).
- **⚠ Behavior decision:** the two duel-leaderboard fetchers
  (`dc_addon_duels.cpp:162` vs `dc_addon_leaderboards.cpp:943`) have **divergent winrate
  math and a `wins>0` filter difference**. Pick the correct behavior *before* extracting a
  shared `FetchDuelRows`.

### B3. Hand-rolled per-player caches → `DarkChaos::Cache` — **medium impact**
- Replace `DungeonQuests/DungeonQuestHelpers.h` `g_PlayerStatsCache` and
  `AddonExtension/dc_addon_welcome.cpp` `sCachedProgressPayloads` with
  `DarkChaos::Cache::PlayerCache<V>` (domain value structs stay as template args).
  **`sCachedProgressPayloads` has an unbounded-growth leak** (never evicted) —
  `PlayerCache::OnPlayerLogout` closes it. **⚠** `PlayerCache` uses 1-second granularity;
  welcome's sub-second TTL + context-key revalidation must stay at the call site (or extend
  `TTLCache` with ms TTL).
- Extract a generic account-keyed `AccountPoolCache<V>` + a tagged `ScopedReentrancyGuard`
  into `CrossSystemCache.h`/`CrossSystemUtilities.h` for the 3 `Progression/Accountwide`
  files (achievements/reputation/friendlist). Keep per-domain DDL + merge rules local.

### B4. Leaf-utility cluster → `DCUtils` — **low impact, low risk**
Add to `DCUtils` and repoint (each repoint is mechanical but verify per-site):
- `PopCount32` (C++20 `std::popcount` wrapper) — `GreatVault/GreatVault.cpp:114`,
  `dc_addon_mythicplus.cpp:154,513`.
- `ToUpper` / `ToLower` — `RandomEnchants/dc_random_enchants.cpp:213` + ~10 ad-hoc
  `std::transform` sites.
- `JoinStringList` — `QOL/dc_aoeloot_unified.cpp:255`, `dc_addon_aoeloot.cpp:102`.
- `ParseUInt32List` — thin wrapper over `Acore::Tokenize` + `Acore::StringTo<uint32>`
  (model on `HotspotMgr.cpp:89`, **keeps id 0**). Repoint `HotspotMgr` and (optionally)
  `FirstStart/dc_firststart.cpp:174` — but FirstStart's spell-id callers must continue to
  ignore 0 (filter at the call site if switching to the keep-0 helper). Do **not** lift
  FirstStart's stringstream/stoul/try-catch body.

### B5. Duplicate `FormatCoins` / `GetQualityName` deletion — **low impact**
`QOL/dc_aoeloot_unified.cpp:469` (`FormatCoins`) and `:481` (`GetQualityName`) duplicate
`DCUtils` helpers at `CrossSystemUtilities.h:134`/`96`. **⚠** the QOL `FormatCoins` uses
**verbose wording** vs DCUtils' abbreviated `g/s/c` output — if the AoE-loot chat wording
must be preserved, add a `FormatCoinsVerbose` variant rather than silently changing output.

### B6. Affix name table → CrossSystem registry — **low impact**
Reimplement `HinterlandBG/hlbg_constants.h:182` `GetAffixName`/`GetLegacyAffixName` to
delegate to `DarkChaos::CrossSystem::Affixes::GetName(SystemId::HLBG, code)`, keeping the
wrapper signatures so call sites are untouched. **⚠ Verified caveat:** the registry's
`legacyName` field stores gameplay-effect aliases (Haste/Slow/…), so `GetLegacyAffixName`
must map to `Affixes::GetName` (display), **not** `GetLegacyName`.

---

## C. Bypass — route through existing facades (medium effort)

### C1. Seasonal token/essence grants bypass the Rewards facade — **medium impact**
`Progression/Prestige/dc_prestige_system.cpp:356` and
`Progression/FirstStart/dc_firststart.cpp:589` resolve the seasonal currency item then
grant via bare `player->AddItem`, bypassing multiplier stacking, weekly-cap enforcement,
central transaction logging, and the addon currency-UI refresh.

**Fix:** route through `Rewards::AwardItemOrSeasonalCurrency` (facade already exists;
`SystemId::Prestige=4`/`SystemId::Welcome=11` and the matching EventTypes exist;
`DungeonQuests` already does this at `DungeonQuestSystem.cpp:510`). The facade
auto-detects token/essence vs custom item. **⚠** keep the existing bag-space pre-checks
and reconcile the `awardedTokens`/`awardedEssence` accounting + player messaging with the
distributor's possibly cap-reduced return amount (not a blind 1:1 swap). **Do NOT** convert
HLBG kill-reward or GiantIsles war-token (400456) grants — those are bespoke content
currencies and correctly stay out of the seasonal pipeline.

### C2. Route the scalar give-item-or-mail sites through `DistributeItem` — **medium impact**
Now that `DistributeItem` mails on a full bag (done), route the open-coded give-or-mail
sites through it: `MythicPlus/dc_mythicplus_loot_generator.cpp:32`,
`GreatVault/GreatVault.cpp:461`, `GiantIsles/dc_giant_isles_fishing.cpp:82`. (GreatVault
and GiantIsles fishing previously only `SendEquipError` on a full bag — i.e. silently
dropped the reward; routing through `DistributeItem` fixes that too.) **⚠** AoeLoot's
batched-`MailDraft` + `randomPropertyId` path and M+'s per-map token delivery stay partly
custom — see C4.

### C3. Inconsistent season-id resolution — **low effort, medium impact**
Replace the inline `SELECT season_id FROM dc_seasons WHERE is_active=1` in
`Commands/cs_dc_item_upgrade.cpp:1227` with the cached `SeasonResolver.h` /
`CrossSystemSeasonHelper.h` resolver (the file already includes them and uses them
elsewhere). The inline `is_active=1` path **ignores the `DarkChaos.ActiveSeasonID` admin
override**, so it can report a different season than every other system. **⚠ Also reconcile
the default-id mismatch between the two CrossSystem resolvers:** `CrossSystemSeasonHelper`
defaults to `0`, `SeasonResolver` defaults to `1`. Leave `SeasonalManager`'s own internal
config reads alone (it is the upstream source).

### C4. Un-stub `RewardDistributor::GetWeeklyCapStatus` + delegate M+ multiplier math — **medium impact**
- `RewardDistributor::GetWeeklyCapStatus` (`RewardDistributor.cpp:459`) currently returns
  "unlimited". Delegate to a read-only `SeasonalRewardManager` earned-this-week accessor so
  pre-checks/previews reflect real remaining caps.
- For M+ `AwardTokens` (`dc_mythicplus_run_manager.cpp:1444`), keep the M+ delivery shell
  (per-dungeon token item, participant loop) but delegate the difficulty/keystone multiplier
  math to `RewardDistributor::GetDifficultyMultiplier`/`GetKeystoneMultiplier` and log via
  the central transaction log. Full facade routing is blocked until `DistributeItem` can
  express a caller-supplied per-map delivery item (consider an overload).

### C5. Weekly-reset boundary — delegate to the Seasons hub — **low effort**
`Seasons/SeasonalRewardSystem.cpp:432` `GetCurrentWeekTimestamp` is line-for-line identical
to `DCWeeklyResetHub`'s `GetVaultWeekStartTimestamp` and reads the same config keys; it is
the lone holdout (M+ already delegates). Replace the body with
`return static_cast<time_t>(DarkChaos::Seasons::GetVaultWeekStartTimestamp());`.
Separately, export `SECONDS_PER_WEEK` + `GetPreviousWeekStart()`/`GetWeekEnd()` **from the
Seasons hub** and collapse the ~5 local `604800` constants (`GreatVault.cpp:33/425`,
`dc_addon_mythicplus.cpp:44/501`, `dc_addon_welcome.cpp:719`, `SessionContext.cpp:239`).
**⚠ Keep week-time in `Seasons`, NOT CrossSystem** — promoting it would fragment one domain
concept across two layers (consumers already include the hub transitively).

---

## D. Deliberately NOT moved (scope guard)

- **JSON `DCAddon::JsonValue` builder** + the **WRLD/EVNT all-session broadcast loop** →
  belong in the **AddonExtension transport layer** (`dc_addon_namespace.h`), not CrossSystem
  (CrossSystem depends on AddonExtension, not the reverse — moving would invert layering).
- **Spectator save/restore + eligibility** (`SaveOrigin`/`TeleportNearTarget`/`RestoreOrigin`
  + shared `CanEnterSpectate` checks) duplicated across M+/HLBG/PhasedDuels → extract into
  the existing `DC/Spectator/dc_spectator_core.{h,cpp}`, **not** CrossSystem (which has zero
  spectator concern by design). Keep per-system gates + visibility strategy in callers.
- **M+ creature scaling** (`MythicDifficultyScaling::ScaleCreature`) → intra-M+ duplication;
  consolidate inside MythicPlus. Not cross-cutting; touches M+-internal types.
- **HLBG/duel/seasonal leaderboard SQL + wire shapes** → only the generic core (Entry +
  JSON builders + `GetClassNameFromId`, already central) is shared; per-addon serialization
  contracts stay put.
- **Group iteration / connected-player lookup** → the engine already provides
  `Group::DoForAllMembers` and `ObjectAccessor::FindPlayerByLowGUID`; fix in place, don't
  add a DC clone.

---

## Suggested sequencing

1. **C2** (route give-or-mail sites — completes the data-loss fix end-to-end) + **C5**
   (weekly-reset delegate — one-line, removes a guaranteed-drift copy).
2. **A1** (DbSchema — highest-volume dup, clear win) and **A2/A3** (gossip + POI helpers — quick).
3. **B6 / B5 / B2 class-name folds** (low-risk dedups with the noted caveats).
4. **C1 / C3** (reward-facade routing + season resolver — needs the accounting/default-id decisions).
5. **B1 / B3 / C4** (map-coords reconciliation, caches, weekly caps — most involved; each has a ⚠ decision).

**⚠ = behavior decision required before coding** (won't be a blind find-replace).
