# Dark Chaos 255 — Release 0.2.0

**Previous release:** `0.1.5` (2026-05-31) · **This release:** 2026-09-04
**Range:** `0.1.5..HEAD` — 1,126 commits (175 DarkChaos, 642 upstream AzerothCore from 79 contributors, remainder CI automation)

The largest content release so far: **19 new maps registered**, five new dungeons, four new raids,
two new levelling continents, a guild-housing overhaul, and a rewritten collections stack.

---

# Part 1 — Patch Notes (players)

## New Zones

| Zone | Level range | What it is |
|---|---|---|
| **Mount Hyjal (80–130)** | 80–130 | Full Cataclysm Hyjal downport — Nordrassil, the Sanctuary of Malorne, Firelands Forgeworks and the Hyjal Frontier. Flight masters, taxi routes, escort quests, world map and skybox all wired up. |
| **The Molten Front** | 85+ | The Firelands daily hub, imported with its quest chain, curated spawns and portal from Hyjal. |
| **Plaguelands** | 60–80 | A rebuilt Eastern/Western Plaguelands with the Blackhowl garrison, cauldron quest support, flight masters and restored WotLK spell data. |
| **Deepholm** | 82+ | Cataclysm's elemental plane, with vendors and quest layers. |
| **Azshara (Cataclysm)** | levelling / 80+ | The revamped Azshara terrain with the goblin choreography events, plus breadcrumb quests and portals to Azshara Crater. |
| **Darkshore & Felwood (Cataclysm)** | levelling | Post-Shattering versions of both zones with escort quests and restored NPCs. |
| **Giant Isles** | endgame | The War Economy quartermaster, invasion events, the Primal Cook fish exchange and the Hydra Drum summon. |

## New Dungeons & Raids

**Raids**

- **Blackwing Descent** — all six encounters: Magmaw, Omnotron Defense System, Maloriak, Atramedes, Chimaeron and Nefarian's End.
- **Castle Nathria** — the full ten-boss Shadowlands raid, from Shriekwing to Sire Denathrius, including Sun King's Salvation and the Council of Blood. Trash loot, readable page texts and missing item entries all filled in.
- **Timbermaw Hold** — a new custom raid.
- **Naxxramas (40-man)** — the classic raid restored on its own map, gated behind an attunement (configurable, and optionally behind the Stratholme entrance).

**Dungeons**

- **Shadowfang Keep (Cataclysm)** — the revamped version, with Lupine Spectres and walk-through portal triggers.
- **Stratholme (DarkChaos)** and **Scholomance (DarkChaos)** — reworked versions on dedicated maps, with portal triggers between wings.
- **Blackfathom Deeps (Ashenvale)** — the revamped Blackfathom, with its own quest and NPC layers.
- **Crescent Grove** and **Emerald Sanctum** — imported custom dungeons (Emerald Sanctum's entrance sits at the moon gate).
- **Karazhan Crypts** — registered with a teleport entry (see *Known gaps*).

## Progression & Endgame

- **Mythic+ overhaul** — a dedicated in-game panel showing keystone info, per-boss checklists, live session tracking and a HUD, difficulty selection directly in the dungeon queue, ready-check countdowns, improved loot delivery and an end-of-run summary.
- **Great Vault** — weekly vault reward claims now flow through the addon UI.
- **Item Upgrades** — reworked from top to bottom:
  - Tiers 1–10 with per-tier stat-bonus caps read from the database instead of hardcoded values.
  - **Emberwood Sap**, a new Hyjal Frontier zone currency, now pays for tier 4 and tier 5 upgrades (it is *not* affected by the seasonal-currency switch).
  - Refunds now return the correct currency for the tier that was paid.
  - Upgrades are blocked in combat.
- **Heirlooms** — upgrade system and costs reworked, plus new heirloom bag tiers with proper scaling.
- **Item set bonuses** — Cataclysm-era item sets now grant their bonuses.
- **World bosses** — per-player loot lockouts with a configurable grace period, and phase-on-engage support so a boss belongs to the group fighting it.
- **Rest area regeneration** — health and mana regenerate faster in rest areas, with extra areas configurable.
- **Seasons** — seasonal stats and reward queries optimised; a weekly token cap is now enforced.

## Collections & Cosmetics

- **Mounts** — batches 3 through 8 downported from retail, bringing the catalogue to **1,526 collectible mounts**. Passenger seats added for multi-seat mounts, plus dedicated mount vendor NPCs and a catalogue cleanup pass (duplicates removed, missing Acherus mount added, stock display IDs corrected).
- **Pets** — the companion pet roster rebuilt from retail's BattlePetSpecies data, now **1,898 pets**, including colour variants, 1,847 backfilled icons, and rarity re-derived from retail cage quality. Pets can now be dragged onto the action bar, the same as mounts.
- **Shapeshift form customisation** — a new catalogue for druid, shaman and warlock forms and totem skins, with lazy loading and a 3D preview.
- **Weapon enchant visuals** — a wardrobe system for weapon illusions (configurable whitelist of enchant IDs).
- **Beastmaster pet catalogue** — a browsable hunter pet catalogue including secret pets with their own models and stats.
- **Account-wide collections** — collectibles, achievements and reputation now pool across your whole account. Reputation can optionally share across factions.

## Guild Housing

- **Instanced guild houses** — guild houses now run as dynamically managed instances rather than shared world space.
- A second Dalaran guild house map, rebuilt with exact NPC transformations, working well teleporters and Underbelly fix-ups.
- **Decorations** — per-decoration visual scaling, a configurable placement range, a refund policy on removal, a GM bypass and a "reset all decorations" command.

## World & Quality of Life

- **Rare spawns** — rares are now pooled and tracked, with a server announcer when one appears (configurable scope, cooldown and maps).
- **Hotspots** — the dynamic hotspot system now snapshots per-player state and can be limited to specific maps and zones.
- **New-player onboarding** — a welcome quest chain, systems primer, a Hyjal call-to-adventure, a newcomer chat channel, starter seasonal tokens, a mobile teleporter item and automatic starter-guild placement. Intro quests now walk you through Mythic+, item upgrades, heirloom upgrades, guild housing and the teleporters.
- **Quest flow** — automatic quest offer and completion popups, quest-navigation sync, and clearer quest reward text.
- **Map POIs** — flight masters and other server-fed points of interest now show on the world map *and* the minimap, with client-side caching.
- **Death markers** — your corpse location is now marked on the map, plus a retail-style **Return to Graveyard** button.
- **Lootable sparkles** — lootable objects now sparkle the way they do on retail.
- **Boss tracker** — a retail-style objective tracker for dungeon and raid bosses, with difficulty labels and a per-boss checklist during Mythic+ runs.
- **DC-Journal** — a new in-game journal addon.
- **Tooltips** — item comparison in tooltips, optional inline colouring of tooltip values.
- **Login screen** — new Legion-styled main menu skins and textures, with Discord and bug tracker buttons.
- **Spectator mode** — a unified spectator core now backs both arenas and Hinterland BG.

## Races & Characters

- **Allied races** — Vulpera, Zandalari and Kul Tiran now have their racial spells; Kul Tiran and Vulpera have their language skills.
- **Worgen and Goblin** ("Worgoblin") — playable, with character-creation models, ambience and language skills.
- **Pandaren** — character data groundwork.
- Custom-race display IDs widened so high-ID custom models render correctly.

## Fixes

- Looter pet now returns to its owner after a loot walk, and no longer breaks under concurrent map updates.
- Corrected `KillCredit` offset on Noxious Assassin (Plaguelands) and the loot ID offset on Flamewaker Shaman (Castle Nathria).
- Removed a duplicate mount and restored the missing Acherus mount.
- Hyjal: resolved `AIName`/`ScriptName` conflicts, restored missing action lists, creature texts and graduation spells, fixed out-of-bounds objects and flight master defects.
- Fixed quest chain references and added missing quest reward items and vendor stock for Deepholm and Legion Dalaran.
- Model loading now validates headers, and collision extraction no longer writes NaN bounds for geometry-less models.
- Addon message flooding is now throttled, with AntiDOS policies on the custom opcodes.

---

# Part 2 — Deployment Notes (server admins)

## Deployment order

1. **World/character SQL** (see below) — apply before restarting the world server.
2. **DBC + CDBC** rebuild and deploy to the server's `dbc/` directory.
3. **Client patch MPQs** — the patch chain now runs through `patch-H.MPQ`.
4. **Restart the world server.**
5. **Then** hand out the updated client addons. Collection definitions carry a data revision; the server must be up on the new revision before clients pick up the new definitions, or clients will cache stale data.

## Database

**912 new SQL files** under `Custom/Custom feature SQLs/`, dominated by:

| Area | Files |
|---|---|
| HyjalCata | 331 |
| Plaguelands | 89 |
| Retroports (mounts/pets/models) | 49 |
| Deepholm | 47 |
| GuildHousing | 43 |
| BlackwingDescent | 37 |
| CastleNathria | 30 |
| ShadowfangKeepCata | 26 |
| ItemSets | 20 |
| MoltenFront | 19 |
| EmeraldSanctum / TimbermawHold | 18 / 16 |
| Worgoblin / CrescentGrove | 14 / 14 |
| AlliedRaces / Naxx40 / Heirlooms / GiantIsles | 12 / 11 / 11 / 11 |
| Pandaren / CollectionSystem | 10 / 10 |

- 10 new character-DB scripts (account-wide pooling, leaderboards, journal state).
- Apply the `Retroports` batches in filename (date) order — later batches contain repair passes over earlier ones.

## Client data

**19 new map IDs registered** in `Map.dbc`:

| ID | Directory | Name | Spawn status |
|---|---|---|---|
| 646 | Deephome | Deepholm | populated (3,269) |
| 669 | BlackwingDescent | Blackwing Descent | populated (154) |
| 750 | DCMountHyjal | Mount Hyjal (80–130) | populated (19,042) |
| 751 | DCPlaguelands | Plaguelands | populated (14,359) |
| 819 | Timbermaw | Timbermaw Hold | scripts in, **12 spawns only** |
| 820 | Blackfathom | Blackfathom Deeps (Ashenvale) | populated (244) |
| 821 | Stratholme | Stratholme (DarkChaos) | populated (470) |
| 822 | SchoolofNecromancy | Scholomance (DarkChaos) | populated (403) |
| 823 | Grove | Crescent Grove | **12 spawns only** |
| 824 | EmeraldSanctum | Emerald Sanctum | **8 spawns only** |
| 825 | Shadowfang | Shadowfang Keep (Cataclysm) | populated (507) |
| 861 | FirelandsDailies | The Molten Front | populated (1,269) |
| 870 | HawaiiMainLand | Pandaria | **groundwork only (1)** |
| 1413 | guildhousedala2 | GuildHouse Dalaran 2 | populated (1,260) |
| 1451 | LevelZones | Level Zones | **empty** |
| 2296 | 2296 | Castle Nathria | populated (645) |
| 2706 | 2706 | Undermine | **groundwork only** |
| 2875 | 2875 | Karazhan Crypts | **empty** |
| 2921 | 2921 | Naxxramas (40) | populated (1,079) |

- **~80 DBC files** and ~75 CSV sources changed. Notable: `Map`, `MapDifficulty`, `AreaTable`, `AreaTrigger`, `AreaPOI`, `WorldMapArea`, `WorldMapOverlay`, `WorldMapContinent`, `DungeonMap`, `DungeonMapChunk`, `TaxiNodes` / `TaxiPath` / `TaxiPathNode`, `CreatureDisplayInfo`, `CreatureModelData`, `Item`, `ItemDisplayInfo`, `ItemSet`, `ItemExtendedCost`, `Spell`, `SpellItemEnchantment`, `ChrRaces`, `CharSections`, `CharStartOutfit`, the `Light*` family, `SoundAmbience`, `ZoneMusic`, `WMOAreaTable`, `DungeonEncounter`, and the `gt*` scaling tables regenerated for level 255.
- **CDBC** (custom client DBCs) rebuilt — `DCCollectionShop`, `DCCollectionSource`, plus a bumped `dc_client_data_revisions` row.
- **Map/vmap/mmap extraction:** the extractor was fixed this cycle (patch-file loading, `\` vs `/` path handling, missing-liquid-type safety, forward-slash normalisation in libmpq hashes). Re-extract rather than reusing pre-0.1.5 output. **Verify the new map IDs are present in the deployed `maps/`, `vmaps/` and `mmaps/` before going live** — they are not present in the current dev data directory.

## Configuration

**94 new options** in `darkchaos-custom.conf.dist`. Merge into your live `darkchaos-custom.conf`. Groups:

- `DC.AddonProtocol.*` — per-module enable flags (Beastmaster, Decoration, Encounters, Forms, Graveyard, MapPOI, QuestNav, QuestPopups) plus debug toggles.
- `DCFirstStart.*` (19 keys) — welcome quest, systems primer, Hyjal call, newcomer chat, starter guild, starter tokens, mobile teleporter.
- `ItemUpgrade.*` — `Currency.SapId` (default `400000`), `BlockInCombat`, `QuestReward.LevelDivisor`, `Tier1..Tier10.MaxStatBonusPct`.
- `DC.WorldBoss.*` — lockout enable / seconds / grace, phase mask and phase-on-engage.
- `DC.GuildHouse.*` — decoration max range, refund percent, butler refund percent, GM bypass.
- `Hotspots.*` — enabled maps/zones, exclusions, min/max active, visual marker.
- `RareSpawn.Announce.*` — enable, scope, maps, cooldown, min respawn, rare-elite inclusion, addon push.
- `DC.Naxx40.RequireAttunement`, `DC.Naxx40.RequireStratholmeEntrance`.
- `DCCollection.*` / `DCAccountwide.*` / `DCAchievements.*` / `DCReputation.*` / `DCFriends.*` — account-wide pooling, collection pre-warm and display-ID backfill.
- `DC.QoS.TooltipEnrichment.*`, `Rate.Health.RestArea`, `Rate.Mana.RestArea`, `DC.RestAreas.ExtraAreaIds`, `Visibility.ObjectSparkles.Lootables`, `MythicPlus.ReadyCheck*`, `SeasonalRewards.MaxTokensPerWeek`, `HinterlandBG.Affix.*`, `DC.UpdateProfiler.ThresholdMs`.

## Client addons

**Updated — reship these:**

| Addon | 0.1.5 | 0.2.0 |
|---|---|---|
| DC-QOS | 1.2.2-rankfix | **1.3.1-blizzardmounts** |
| DC-Welcome | 2.0.0 | **2.1.0** |

**New — add to the addon bundle:**
`DC-Journal` · `DC-JournalData` · `DC-Housing` · `DC-DangerZone` · `DC-AddonProtocolUI` · `DC-PortraitCapture` · `DC_DebugUtils` · `AzerothAdmin_Models`

**Removed — delete from clients:**
`AIO_Client` (AIO transport is gone; everything is native now) · `Mapster` · `WDM` · `Transmogrification`

> **Before shipping:** several DC addons (`DC-AddonProtocol`, `DC-Collection`, `DC-MythicPlus`, `DC-ItemUpgrade`, `DC-HinterlandBG`, `DC-Mapupgrades`, `DC-GM`) changed substantially but their `## Version:` lines were **not** bumped. Consider bumping them so clients can tell what they are running.

## Core / build

- ~140 new C++ files under `src/server/scripts/DC/`, largest groups: `Naxx40` (28), `CastleNathria` (13), `AddonExtension` (12), `ShadowfangKeepCata` (9), `BlackwingDescent` (9), `ScholomanceDC` (7), `StratholmeDC` (6), `GiantIsles` (6), `MountHyjal` (5).
- `dc_script_loader.cpp` gained ~55 registrations. Naxx40, Shadowfang Keep (Cata), Stratholme and Scholomance register through **wrapper loaders** (`AddDCNaxx40Scripts()` etc.) — do not also declare their internal `AddSC_*` entries.
- **`ScopedUpdateProfiler`** added and threaded through the DC scripts; set `DC.UpdateProfiler.ThresholdMs` to catch world-update spikes.
- `CrossSystemUtilities` replaced by `CrossSystemCommon` — update any out-of-tree code that included the old header.
- `PlayerScript` hook lists are now declared explicitly across the DC tree.
- DC data loading moved to async `QueryCallback` to stop world-thread stalls.
- CMake: tools now link the `game` library via `game-interface`.
- Full rebuild required (DBC layout, script loader and shared header changes).

## Upstream

Synced with AzerothCore master through 2026-08-28 — 642 upstream commits from 79 contributors, including **ACDB 16.0.0** (2026-06-02).

## Known gaps

Registered but **not ready to advertise to players**:

- **Pandaria (870)** — map and world-map art registered, but essentially unpopulated. Client-side asset gaps remain.
- **Undermine (2706)** — groundwork only; a client-side crash in the WotLK Extensions layer is still open on this map.
- **Karazhan Crypts (2875)** and **Level Zones (1451)** — registered, no content.
- **Timbermaw Hold (819)**, **Crescent Grove (823)**, **Emerald Sanctum (824)** — scripts and encounters exist, but the spawn layers are near-empty. These need populating before they are playable.
- **Naxxramas 40 (2921)** — populated server-side; confirm the client map build and extraction are deployed before enabling the portal.
