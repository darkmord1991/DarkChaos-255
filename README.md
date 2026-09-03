# 🌑 DarkChaos 255 — Custom WoW 3.3.5a Server

> A heavily customized AzerothCore 3.3.5a server: level 255 cap, retail-inspired endgame systems, downported Cataclysm/MoP/SL content, extra playable races, and a unified custom addon suite.

[![Version](https://img.shields.io/badge/Version-3.1.0--dev-brightgreen)](https://github.com/darkmord1991/DarkChaos-255)
[![Discord](https://img.shields.io/badge/Discord-Join%20Us-7289DA?logo=discord)](https://discord.gg/pNddMEMbb2)
[![Contact](https://img.shields.io/badge/Contact-Darkmord1991-blue)](https://github.com/darkmord1991)

**Open for proposals and discussions** — especially looking for help with client modding.

---

## 📊 At a Glance

| Category | Details |
|----------|---------|
| **Level Cap** | 255, with custom player / creature / pet stat scaling |
| **Classes** | All race/class combinations (ARAC) |
| **Races** | Stock 10 + Worgen, Goblin, Pandaren (both factions), Vulpera, Zandalari Troll, Kul Tiran, Dark Iron Dwarf |
| **Endgame** | Mythic+ (50+ dungeon profiles), Great Vault, Seasons, Group Finder, Leaderboards |
| **Progression** | Item Upgrades (T1–T5), 10 Prestige levels, 9 Challenge modes, account-wide rep/achievements |
| **PvP** | Hinterland BG, Battle for Gilneas, Phased Duels, Cross-Faction BGs |
| **Collections** | Account-wide mounts, pets, titles, toys, transmog wardrobe, heirlooms |
| **Custom Content** | Azshara Crater (1–80), Giant Isles, Guild Housing, downported Cata/MoP/SL zones, raids & dungeons |
| **Scripting** | C++ (`src/server/scripts/DC/`) + Eluna (Lua) |
| **Addons** | 19 DC addons on a shared protocol and unified visual theme |

---

## ⚔️ Custom Systems

All DC gameplay systems live under `src/server/scripts/DC/` and are registered through `dc_script_loader.cpp`.

### 🔥 Mythic+ & Group Finder
Keystone levels with scaling HP/damage, weekly rotating affixes, death budget, 50+ dungeon profiles, and Mythic difficulty for every 5-man. Includes live **spectator mode** (party HP, boss progress, timer), leaderboards, seasonal portals, keystone activation, token vendors, and the Font of Power activation object. The Group Finder covers M+, raid, and world-content groups with live-run and scheduled-run tabs, cross-faction support.

### 💎 Item Upgrades
Five upgrade tiers across three separate currencies. Never branch on the tier id at a spend site — `GetTierCurrency()` owns the mapping.

| Tier | Content | Levels | Currency |
|------|---------|--------|----------|
| **T1** Leveling | Regular items | 6 | DC Item Upgrade Token (300311) |
| **T2** Heroic | Heroic items | 15 | DC Item Upgrade Token (300311) |
| **T3** Heirloom | Heirlooms, scales with player level | 80 | DC Artifact Essence (300312) |
| **T4** Hyjal Progression | Hyjal Frontier leveling gear, +5%/level | 10 | Emberwood Sap (400000) |
| **T5** Hyjal Endgame | Hyjal Frontier endgame gear, +4%/level | 15 | Emberwood Sap (400000) |

Supports percentage/flat stat scaling, proc scaling, T3 heirlooms with secondary-stat packages, seasonal upgrade paths, per-item tier pins via `dc_item_upgrade_item_overrides`, and **transmutation** (tier up/downgrade, currency exchange, synthesis, refinement) via upgrade vendor and curator NPCs. Cataclysm item-set bonuses are backported alongside (`ItemSets/`).

### 🗓️ Seasons & Cross-System Manager
Central season management (time-based / event-based / infinite / manual) with per-player seasonal data, automated start/end/reset callbacks, configurable carryover, and themes. Item Upgrades, HLBG, and Mythic+ all register with it.

The **Cross-System Manager** (`DC/CrossSystem/`) is the shared backbone: EventBus for inter-system events, session context, unified reward distribution, shared cache, spawn resolver, and world-boss management — all fed by player login/logout, level, and death hooks.

### 🎁 Great Vault
Weekly reward caches on three tracks (Raid / M+ / PvP), 3 slots each. Configurable completion thresholds (default 1/4/8), token / gear / both reward modes, item level scaled to the highest completed content, raid progress from instance binds, and automatic generation on weekly reset.

### 🏆 Prestige & Challenge Modes
**Prestige:** 10 levels, reset at 255 for a stacking +1% stat bonus per tier, exclusive titles (178–187), visual auras (800010–800019), optional keep-gear/professions/gold, alt XP bonuses, and world announcements.

**Challenge Modes:** persistent auras, milestone rewards, enforced gear/profession restrictions, and hardcore death markers shown on the world map for 24h.

| Mode | Spell | Mode | Spell |
|------|-------|------|-------|
| Hardcore | 800020 | Quest XP Only | 800026 |
| Semi-Hardcore | 800021 | Slow XP (−50%) | 800024 |
| Self-Crafted | 800022 | Very Slow XP (−75%) | 800025 |
| Item Quality Level | 800023 | Iron Man / Iron Man Plus | 800027 / 800029 |

### 👥 Account-Wide Progression
`Progression/Accountwide/` shares reputation, achievements, and the friends list across every character on an account, backed by a pooled store and a maintenance pass that reconciles drift. Collection grants are account-wide by the same route.

### ⚔️ Hinterland Battleground (HLBG)
Dedicated open-world PvP zone in The Hinterlands (zone 47) with a resource-victory objective system, Queue → Warmup → Active → Ending state machine, battlemaster queueing, auto raid grouping, PvP affixes, AFK detection, faction leaders and scoreboard NPC, seasonal rotation, live HUD via addon, and GM admin commands.

### 📚 Collection System
Account-wide mounts, pets, titles, toys, heirlooms, and a full transmog wardrobe with outfits. Mount count grants stacking speed bonuses (25/50/100/200 mounts → +2/3/4/5%, spells 300510–300513). Includes wishlist, in-game collection shop, and an account-wide sharing toggle. Definitions ship as client-side `.cdbc` tables (`Custom/CDBCs/`) behind a server-driven revision check.

### 🏠 Guild Housing
One private instance per guild with rank-based permissions (`SPAWN`, `DELETE`, `MOVE`, `ADMIN`, `WORKSHOP`), butler and teleporter NPCs, a decoration/placement system with 700+ retail objects, audit logging with undo, and support for multiple house locations.

### 🐉 World Bosses & Rares
Central registration with respawn timers and countdowns, active/engaged state tracking, HP-threshold broadcasts, and live status pushed to clients over the `WRLD` protocol. Giant Isles hosts **Oondasta** (400100), **Thok the Bloodthirsty** (400101), and **Nalak the Storm Lord** (400102). A separate rare-spawn system handles dynamic rares and announcements.

### 📜 Dungeon Quests & Onboarding
Daily, weekly, and event dungeon quests from a single universal NPC with categorized gossip (Daily / Weekly / Dungeon / All), token rewards wired into the upgrade currency, a personal follower quest-giver that accompanies players into dungeons, and per-player completion stats.

A separate **intro quest chain** walks new players through each custom system in turn — teleporters, the flight network, keystone and token vendors, item upgrades, the guild house, and HLBG — so systems are discovered in-game rather than from a wiki.

### 🌡️ Hotspot XP Zones
Grid-based rotating XP bonus zones with DB persistence, configurable durations and eligible zones, in-hotspot objectives, stacking bonuses, per-player entry/expiry tracking (snapshot-backed across relogs), visual markers, and world-map indicators via addon. Bonus effect: spell 800001.

### 🧰 Other DC Systems
Random enchants, fake-player population, AoE loot, beastmaster pet catalog, breaking news, achievements, teleporters, phased duels, quest-navigation and quest-popup helpers, a DungeonEncounter-driven boss tracker, return-to-graveyard, and the GOMove/NPCMove GM tooling.

---

## 🗺️ Custom Areas & Downported Content

### Azshara Crater (1–80)
A full leveling zone on WoW's cancelled battleground terrain (Map 37, Zone 268), built as "Crater Conquest" — start at Valormok and radiate outward to the Temple of Eternity. Eight tiers: Valormok Rim (1–10), Northern Ruins (10–20), Timbermaw Slopes (20–30), Central Valley (30–40), Western Cliffs (40–50), Haldarr Territory (50–60), Dragon Coast (60–70), Temple of Eternity (70–80).

~130 NPCs, 6 mini-dungeons (5 trash + 1 boss each), 4 world bosses, 8 rares, 5 shared faction bases, flightmasters/guards, and a protected road network. Factions: Naga, Satyr (Haldarr/Legashi), Highborne ghosts, Timbermaw furbolgs, and the Blue Dragonflight.

Leveling path: **Azshara Crater (1–80) → Hyjal Frontier (80–130) → Stratholme Valley (130–160)**.

### Giant Isles (Zone 5000)
MoP-inspired zone ported from the Isle of Giants: Dinotamer Camp, Primal Basin, Devilsaur Gorge, Raptor Ridge, Thundering Peaks, Bone Wastes, Ancient Ruins. Daily quest hub with vendors, world-boss daily rotation, dynamic rare spawns, zone invasions, cannon quests, fishing, a war-economy loop, and a water-monster encounter.

### Downported Zones (Cataclysm / MoP / Shadowlands)
- **Mount Hyjal (map 750)** — Cata Hyjal plus retagged Azshara, Darkshore, and Felwood; Cata skyboxes, ambience, taxi network.
- **Molten Front (map 861)** and **Deepholm** — Cata dailies content.
- **Eastern/Western Plaguelands (map 751)** — Cata revamp downport with its own flight masters and cauldron scripts.
- **Hyjal Frontier (80–130)** — the T4/T5 gear band: Emberwood Sap vendor, flightmaster, guards, innkeeper.
- **Jadeforest** and **Battle for Gilneas** — MoP zone port and custom battleground.

### Downported Raids & Dungeons

| Content | Map | Source | Notes |
|---|---|---|---|
| **Blackwing Descent** | — | Cataclysm | 6 boss scripts plus trash/RP |
| **Castle Nathria** | — | Shadowlands | 10 boss scripts, full instance |
| **Naxxramas 40** | 2921 | Classic | 15 boss scripts, art split from stock map 533 |
| **Shadowfang Keep (Cata)** | 825 | Cataclysm | Reworked Silverlaine/Springvale; normal/heroic/mythic |
| **Stratholme (DC)** | 821 | Cataclysm | Portal triggers, own id map |
| **Scholomance (DC)** | 822 | Cataclysm | Own id map |
| **Blackfathom Deeps / Ashenvale** | 820 | Community | Clone off Ashenvale |
| **Timbermaw Hold** | 819 | Community | Raid encounters |
| **Crescent Grove** | 823 | Community | Imported dungeon |
| **Emerald Sanctum** | 824 | Community | Entrance at the moon gate |
| **Karazhan Crypts** | 2875 | Season of Discovery | Registration only, spawns pending |

### Status
- **Active:** Azshara Crater, Giant Isles, Hinterland BG, Guild Housing, Battle for Gilneas, Mount Hyjal, Plaguelands, Molten Front.
- **In progress:** Hyjal Frontier (80–130), Stratholme Valley (130–160), Jadeforest, Karazhan Crypts, and the newer dungeon imports (client assets deployed, spawns/SQL in flight).

---

## 📡 DC Addon Protocol

`src/server/scripts/DC/AddonExtension/` holds ~36 server-side message handlers routing all client↔server traffic through one protocol.

```
Simple: DC|MODULE|OPCODE|DATA1|DATA2|...
JSON:   DC|MODULE|OPCODE|J|{"key":"value",...}
Batch:  DC|BATCH|count|MOD1|op|data|MOD2|op|data|...   (max 10 messages)
```

**Modules:** `CORE` (handshake/version) · `AOE` · `SPEC` · `UPG` · `HLBG` · `DUEL` · `MPLUS` · `PRES` · `SEAS` · `SPOT` · `LBRD` · `WELC` · `GRPF` · `GOMV` · `NPCM` · `TELE` · `EVNT` · `WRLD` · `COLL` · `QOS` · `DECO` · `GRVY` · `QPOP` · `BEAST` · `MPOI` · `QNAV` · `DENC`

Features: chunking around WoW's 255-byte limit, JSON payloads via the `J` flag, batching, capability/version negotiation, rate limiting, per-module/opcode handler registration, metrics (sent/received, cache hits, errors), and optional S2C logging.

---

## 🖥️ Client Addons

Shipped in `Custom/Client addons needed/`. All DC addons share the FelLeather background texture, matching borders, `|cffFFCC00DC|r` gold title prefix, and common style helpers.

| Addon | Ver | Purpose |
|-------|-----|---------|
| **DC-AddonProtocol** | 2.0.0 | Communication library: JSON, request/response tracking, error handling, connection status, per-module wrappers |
| **DC-AddonProtocolUI** | 2.0.0 | Load-on-demand settings / diagnostics / request-log panels (`/dcpanel`, `/dcdiag`, `/dc log`) |
| **DC-MythicPlus** | 1.0.0 | M+ HUD (timer/affixes), Group Finder, Live Runs, Spectator, keystone activation, token vendor, seasonal portals, Great Vault UI |
| **DC-ItemUpgrade** | 2.3 | Upgrade interface with tiers T1–T5, heirlooms, transmutation, client cache |
| **DC-Collection** | 1.0.0 | Mounts, pets, titles, heirlooms, toys, transmog wardrobe + outfits, community tab, wishlist, shop |
| **DC-HinterlandBG** | 1.4.0 | HLBG queue, HUD, live stats, match history, leaderboard adapter, settings |
| **DC-Leaderboards** | 1.4.0 | Unified full-screen leaderboards for all competitive content |
| **DC-Welcome** | 2.1.0 | First-login flow, progress tracking, addon hub, seasons/challenge/prestige UI, FAQ, minimap button, XP bar for 80+ |
| **DC-InfoBar** | 1.0.0 | Modular info bar: season, prestige, keystone, affixes, world boss, events, location, XP/rep, gold, durability, bags, performance, clock |
| **DC-Housing** | 1.0.0 | Guild house decoration placement and editing |
| **DC-Journal** | 1.0 | Encounter Journal / Adventure Guide backport plus the retail-style boss tracker (`DENC`) |
| **DC-JournalData** | 1.0 | Load-on-demand item name/icon fallback table for DC-Journal |
| **DC-Mapupgrades** | 1.2.0 | Hotspot display, world-boss and rare map pins (Astrolabe) |
| **DC-AOESettings** | 1.2.0 | AoE loot panel: quality filters, professions, gold-only mode, server sync |
| **DC-DangerZone** | 1.0.0 | Danger-zone warnings and telegraphs |
| **DC-QOS** | 1.3.1 | Comprehensive QoL suite (below) |
| **DC_DebugUtils** | 1.0.0 | Shared debug logging library (dedup + `/dcdebugstats`) |
| **DC-PortraitCapture** | 1.0 | Dev tool: renders creature display ids full-screen for Encounter Journal boss art |
| **DC-GM** | 23 | Admin addon extending AzerothAdmin with GOMove, DC teleports/commands, linkifier |

Bundled libraries: Ace3, Astrolabe, LibMapData-1.0, BugGrabber/BugSack, GatherMate, WowLua.

### DC-QOS modules
Adapted from Leatrix Plus for 3.3.5a, plus an embedded **WeakAuras** backport: **Tooltips** (item ID/level/upgrade, NPC & spell ID, guild rank, target info, anchoring, tier colors) · **Automation** (repair, sell junk, dismount, accept summon/res, decline duels/invites, quest accept/turn-in, gossip skip, BG release, faster loot, cinematic skip) · **Extended Stats** · **GTFO Alerts** · **Item Score** (Pawn-style weights and upgrade arrows) · **Nameplates Plus** (class colors, threat, cast bars, aura filtering, profiles) · **Quest suite** (map pins, POI data, tracker markers, popups, recurring lookup, navigation) · **World map window** with zone labels and teleport data · **Talent loadout manager** · **Ping system** · plus Action Bars, Bags, Cooldowns, Chat, Interface, Druid fixes, Graphics, Graveyard, Keybinds, Mail, Minimap, Frame Mover, Vendor Plus, Combat Log, Experience, Profiles, and Social enhancements.

---

## 🔧 Technical Stack

- **Core:** AzerothCore 3.3.5a (heavily modified), C++20, CMake, MySQL
- **Scripting:** C++ DC scripts + Eluna (Lua)
- **Comms:** DC Addon Protocol (JSON, chunked, batched)
- **Database:** custom tables under the `dc_*` prefix
- **Config:** `Custom/Config files/darkchaos-custom.conf.dist` (600+ options)
- **Client data:** `Custom/DBCs/` (patched DBCs), `Custom/CSV DBC/` (CSV sources compiled into them), `Custom/CDBCs/` (custom client tables read by the WotLK Extensions DLL), `Custom/Client patches needed/` (Interface, textures, HD models, spells)
- **Testing:** Google Test unit tests in `src/test/`, plus a live-stack protocol e2e suite in `e2e/` (Go, `-tags=e2e`; suites for combat, guild, instances, items, protocol, quests, social, spells)

### DC script layout

```
src/server/scripts/DC/
├── AC/                  # AzerothCore integration (flightmasters, guards, taxi, quest NPCs)
├── AddonExtension/      # ~36 addon protocol handlers (dc_addon_protocol.cpp routes; dc_addon_namespace.h defines modules/opcodes)
├── CrossSystem/         # EventBus, RewardDistributor, SessionContext, world boss manager, shared cache
├── CollectionSystem/    # Mounts, pets, titles, toys, transmog, heirlooms, grants
├── Commands/            # .dc GM commands (cs_dc_*.cpp)
├── MythicPlus/          # M+ scaling, affixes, keystones, vendors, spectator, loot generator
├── ItemUpgrades/        # Gear progression T1–T5 + transmutation
├── ItemSets/            # Cataclysm item-set bonus backport
├── GreatVault/          # Weekly vault (3 tracks, 9 slots)
├── Progression/         # Accountwide/, ChallengeMode/, FirstStart/, Prestige/
├── Seasons/             # Season manager + weekly reset hub
├── HinterlandBG/        # Outdoor PvP battleground
├── GuildHousing/        # Guild instances + decorations
├── GiantIsles/ Jadeforest/ Gilneas/ Deepholm/ MountHyjal/ HyjalFrontier/ Plaguelands/
├── BlackwingDescent/ CastleNathria/ Naxx40/                    # Raid downports
├── BlackfathomAshenvale/ ShadowfangKeepCata/ StratholmeDC/     # Dungeon downports
├── ScholomanceDC/ TimbermawHold/ CrescentGrove/ EmeraldSanctum/
├── DungeonQuests/ Hotspot/ RareSpawns/ RandomEnchants/ QOL/ Races/ Achievements/
├── Spectator/ PhasedDuels/ Teleporters/ GOMove/ FakePlayers/
└── dc_script_loader.cpp # AddDCScripts() — single registration entry point
```

`AddDCScripts()` registers by feature section. Some entries load their own sub-registrations transitively (`AddDCAddonExtensionScripts()`, `AddMythicPlusScripts()`, `AddGuildHouseScripts()`, `AddDCNaxx40Scripts()`, `AddDCShadowfangKeepCataScripts()`, `AddDCStratholmeScripts()`, `AddDCScholomanceScripts()`, `AddSC_ac_hotspots()`) — do not also register their internals directly, or you get duplicate registration paths.

### Modules

```bash
git clone https://github.com/azerothcore/mod-ah-bot.git                  modules/mod-ah-bot
git clone https://github.com/azerothcore/mod-world-chat.git              modules/mod-world-chat
git clone https://github.com/azerothcore/mod-cfbg.git                    modules/mod-cfbg
git clone https://github.com/azerothcore/mod-skip-dk-starting-area.git   modules/mod-skip-dk-starting-area
git clone https://github.com/azerothcore/mod-npc-services.git            modules/mod-npc-services
git clone https://github.com/azerothcore/mod-arac.git                    modules/mod-arac
```

### Companion client project

Much of what the server exposes needs client-side support 3.3.5a does not ship: extra `ChrRaces` handling, `.cdbc` custom tables, downported models and particle emitters, and new UI frames. That half lives in a separate **WotLK Extensions** DLL + client-patch repository; the DBCs, CDBCs, and patch payloads it consumes are staged here under `Custom/`. Help with this side of the project is the most useful contribution you can make.

---

## 📊 Version History

| Version | Date | Highlights |
|---------|------|------------|
| **3.1.0-dev** | 2026 | Pandaren + allied races (Vulpera, Zandalari, Kul Tiran, Dark Iron); item upgrades extended to T4/T5 on Emberwood Sap; account-wide reputation / achievements / friends; Naxxramas 40 and the Cata dungeon downports (SFK 825, Stratholme 821, Scholomance 822) plus Timbermaw Hold, Crescent Grove, Emerald Sanctum; Cata zone downports (Hyjal, Plaguelands, Deepholm, Molten Front); Guild Housing instancing + decorations; Blackwing Descent & Castle Nathria transcodes; DC-Housing, DC-Journal, DC-InfoBar addons; system intro quest chain; live protocol e2e suite |
| **3.0.0** | January 2026 | Collection System, Great Vault, Guild Housing, World Bosses, enhanced M+ |
| **2.5.0** | November 2025 | Item Transmutation, Seasonal Integration, Group Finder |
| **2.0.0** | September 2025 | Mythic+, Prestige, Challenge Modes |
| **1.0.0** | June 2025 | Initial release: Level 255, AoE Loot, HLBG |

## 📄 License

Builds on AzerothCore (AGPL-3.0). Custom DC systems are proprietary.

*Last updated: September 2026*
