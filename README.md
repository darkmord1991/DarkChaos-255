# 🌑 DarkChaos 255 - Custom WoW 3.3.5a Server

> **A heavily customized AzerothCore-based WoW 3.3.5a private server with Level 255 cap, custom systems, and modern retail-inspired endgame features.**

[![Version](https://img.shields.io/badge/Version-3.0.0-brightgreen)](https://github.com/darkmord1991/DarkChaos-255)
[![Discord](https://img.shields.io/badge/Discord-Join%20Us-7289DA?logo=discord)](https://discord.gg/pNddMEMbb2)
[![Contact](https://img.shields.io/badge/Contact-Darkmord1991-blue)](https://github.com/darkmord1991)

**Open for proposals and discussions!** Especially looking for support in client modding.

---

## 📋 Table of Contents

- [Project Highlights](#-project-highlights)
- [Custom Systems](#-custom-systems)
  - [Mythic+ & Group Finder System](#-mythic--group-finder-system)
  - [Item Upgrade System](#-item-upgrade-system)
  - [Seasonal System & Cross-System Integration](#-seasonal-system--cross-system-integration)
  - [Great Vault System](#-great-vault-system)
  - [Prestige & Challenge Modes](#-prestige--challenge-modes)
  - [Hinterland Battleground](#️-hinterland-battleground-hlbg)
  - [Collection System](#-collection-system)
  - [Guild Housing System](#-guild-housing-system)
  - [World Boss System](#-world-boss-system)
  - [Dungeon Quest System](#-dungeon-quest-system)
  - [Hotspot XP System](#️-hotspot-xp-system)
- [DC Addon Protocol & Communication](#-dc-addon-protocol--communication)
- [Client Addons](#️-client-addons)
- [Custom Areas](#️-custom-areas)
- [Used Modules](#-used-modules)
- [Technical Stack](#-technical-stack)

---

## 🎮 Project Highlights

### 🌟 What Makes DarkChaos 255 Unique

<table>
<tr>
<td width="50%">

#### 🎯 Retail-Inspired Endgame
- **Mythic+ Keystones** with 50+ dungeon profiles
- **Great Vault** weekly reward system (9 slots)
- **Seasonal Content** with leaderboards & rewards
- **Group Finder** for M+, Raids, and World Content

</td>
<td width="50%">

#### ⚔️ Hardcore Progression
- **Level 255 Cap** with custom stat scaling
- **10 Prestige Levels** with permanent bonuses
- **9 Challenge Modes** (Hardcore, Iron Man, etc.)
- **Item Upgrade System** with transmutation

</td>
</tr>
<tr>
<td>

#### 🗺️ Custom Content
- **3 Custom Zones** (Azshara Crater 1-80, Giant Isles, Jadeforest)
- **World Bosses** (Oondasta, Thok, Nalak)
- **Hinterland Battleground** open-world PvP
- **Guild Housing** with phase isolation

</td>
<td>

#### 🖥️ Unified Addon Suite
- **15+ DC Addons** with consistent visual design
- **DC-QOS** comprehensive QoL (Leatrix Plus-style)
- **Real-time Server Sync** via JSON protocol
- **Full GM Tooling** with GOMove integration

</td>
</tr>
</table>

### 📊 At a Glance

| Category | Details |
|----------|---------|
| **Level Cap** | 255 with custom player/creature/pet scaling |
| **Classes** | All race/class combinations enabled (ARAC) |
| **Dungeons** | 50+ M+ profiles, Mythic difficulty for all 5-mans |
| **PvP** | Hinterland BG, Phased Dueling, Cross-Faction BGs |
| **Progression** | Prestige resets, Challenge modes, Seasonal content |
| **Collections** | Account-wide mounts, pets, titles, transmog, heirlooms |
| **Scripting** | C++ (DC Scripts) + Eluna (Lua) + AIO Protocol |
| **Addons** | 15+ custom addons with unified FelLeather UI theme |

---

## ⚔️ Custom Systems

### 🔥 Mythic+ & Group Finder System
*Retail-inspired endgame dungeon difficulty scaling with integrated group formation*

#### Mythic+ Features
- **Keystone Levels** - Progressive difficulty with scaling HP/damage
- **Affix System** - Weekly rotating affixes (Fortified, Tyrannical, Bolstering, Sanguine, etc.)
- **Death Budget** - Failed runs based on death count penalties
- **50+ Dungeon Profiles** - Full scaling support for all WotLK dungeons
- **Spectator Mode** - Watch active Mythic+ runs live with real-time party HP, boss progress, and timer
- **Leaderboards** - Competitive rankings and weekly best times
- **Dungeon Extensions** - Heroic dungeons with scaling rewards for vanilla dungeons
- **Mythic Difficulty** - Available for all 5-person dungeons
- **Font of Power** - Dungeon starting GameObject for key activation
- **Token Vendors** - Mythic token exchange NPCs
- **Seasonal Portal Frame** - Season-specific dungeon portals

#### Group Finder Features
- **Mythic+ Groups** - Find and create groups for M+ runs with keystone level display
- **Raid Groups** - Form raid parties for weekly content
- **World Content** - World boss and event groups
- **Live Runs Tab** - View currently active runs with real-time progress
- **Scheduled Runs** - Plan future group activities
- **Cross-Faction Support** - Form groups regardless of faction

### 💎 Item Upgrade System
*Comprehensive gear progression with tier-based upgrades*

- **3 Upgrade Tiers** (T1-T3: 226-252+ iLvl)
- **Heirloom Support** - T3 heirlooms with secondary stats packages
- **Token & Essence Currency** - Dual currency earned from dungeons, raids, and PvP
- **Stat Scaling** - Percentage or flat stat increases
- **Proc Scaling** - Item proc effects scale with upgrade level
- **Item Transmutation** - Convert items between tiers, exchange currencies, synthesize rare items
  - Tier Downgrade/Upgrade - Convert between upgrade levels
  - Currency Exchange - Trade tokens for essence or vice versa
  - Synthesis - Combine multiple items into rare outputs
  - Refinement - Improve material quality
- **Seasonal Upgrades** - Season-specific upgrade paths
- **NPC Interface** - Upgrade vendor and curator NPCs
- **Quest Reward Hooks** - Automatic token rewards from quests

### 🗓️ Seasonal System & Cross-System Integration
*Centralized season management for all game systems*

#### Seasonal System Features
- **Season Types** - Time-based, Event-based, Infinite, or Manual seasons
- **Season States** - Inactive, Active, Transitioning, Maintenance
- **System Registration** - Item Upgrades, HLBG, M+, Mythic all integrate with seasons
- **Player Data Tracking** - Per-player seasonal data with join timestamps
- **Season Transitions** - Automated callbacks for season start/end/reset events
- **Carryover System** - Configurable progress carryover between seasons
- **Theme Support** - Season-specific themes with banners and custom properties

#### Cross-System Manager
The Cross-System Manager coordinates all DC custom systems:

- **EventBus** - Publish/subscribe event system for inter-system communication
- **Session Manager** - Player session context across all systems
- **Reward Distributor** - Unified reward distribution from any system
- **System Registration** - Each system registers capabilities (rewards, progression, weekly/seasonal content)
- **World Script Hooks** - Player login/logout, level changes, deaths propagated to all systems
- **DC Cache** - Shared caching layer for performance
- **Spawn Resolver** - Dynamic NPC/GO spawning utilities

### 🎁 Great Vault System
*Weekly reward caches based on activity (Retail-inspired)*

- **3 Reward Tracks** - Raid, Mythic+, and PvP tracks
- **9 Total Slots** - 3 slots per track (1-3 Raid, 4-6 M+, 7-9 PvP)
- **Thresholds** - Configurable completion thresholds (default: 1/4/8 completions)
- **Reward Modes**:
  - Token Mode - Receive universal tokens for vendor exchange
  - Gear Mode - Blizzlike spec-appropriate gear
  - Both Mode - Tokens AND gear choices
- **Item Level Scaling** - Rewards scale with highest completed content
- **Raid Progress Tracking** - Boss kills counted via instance binds
- **Weekly Reset Integration** - Automatic vault generation on reset
- **NPC Interface** - Dedicated vault claim NPC with slot selection

### 🏆 Prestige & Challenge Modes
*Long-term progression and hardcore difficulty modifiers*

#### Prestige System
- **10 Prestige Levels** - Reset at level 255 with permanent bonuses
- **1% Stat Bonus Per Prestige** - Stacking permanent stat increases
- **Exclusive Titles** - Unique titles for each prestige tier (titles 178-187)
- **Prestige Spells** - Visual auras for each prestige level (800010-800019)
- **Keep Options** - Choose to keep gear, professions, and gold on prestige
- **Alt Bonus System** - XP boosts for alternate characters based on main's prestige
- **World Announcements** - Server-wide prestige achievement messages
- **Config Validation** - Robust configuration with error logging

#### Challenge Modes
| Mode | Spell ID | Description |
|------|----------|-------------|
| **Hardcore** | 800020 | One death = permanent character death |
| **Semi-Hardcore** | 800021 | Limited lives per session |
| **Self-Crafted** | 800022 | Must craft all own gear |
| **Item Quality Level** | 800023 | Restricted gear quality |
| **Slow XP** | 800024 | 50% reduced experience gain |
| **Very Slow XP** | 800025 | 75% reduced experience gain |
| **Quest XP Only** | 800026 | Experience only from quests |
| **Iron Man** | 800027 | Hardcore + self-crafted + restrictions |
| **Iron Man Plus** | 800029 | Ultimate challenge with maximum restrictions |

#### Challenge Mode Features
- **Visual Auras** - Distinct persistent spell auras for each mode
- **Milestone Rewards** - Titles, achievements, talent points, items at specific levels
- **Equipment Restrictions** - Enforced gear and profession limitations
- **Database Persistence** - Challenge mode state stored in DB with enforcement hooks
- **Death Markers** - Hardcore deaths displayed on world map for 24 hours

### ⚔️ Hinterland Battleground (HLBG)
*Open-world PvP zone with objective-based gameplay*

- **Zone 47** - Dedicated PvP area in The Hinterlands
- **Resource Victory** - Team-based objective system with score thresholds
- **State Machine** - Queue → Warmup → Active → Ending phases
- **Auto Raid Group** - Automatically forms raid groups when joining
- **Queue System** - Battlemaster NPCs for automated matchmaking
- **Affix Support** - PvP affixes for added challenge variety
- **AFK Detection** - Automatic removal of inactive players
- **Performance Optimization** - Dedicated performance monitoring and reset workers
- **Faction Leaders** - Thrall and Varian Wrynn as zone NPCs
- **Scoreboard NPC** - In-zone score tracking and display
- **Live Stats HUD** - Real-time battle information via client addon
- **Seasonal Integration** - Rotating seasons with exclusive rewards
- **Admin Commands** - GM tools for zone management

### 📚 Collection System
*Account-wide collectibles with retail-inspired features*

- **Mount Collection** - Account-wide mount tracking with speed bonuses
  - Tier 1 (+2% speed): 25+ mounts (Spell 300510)
  - Tier 2 (+3% speed): 50+ mounts (Spell 300511)
  - Tier 3 (+4% speed): 100+ mounts (Spell 300512)
  - Tier 4 (+5% speed): 200+ mounts (Spell 300513)
- **Pet Collection** - Companion pet tracking and management
- **Title Collection** - Unified title management
- **Heirloom System** - Account-wide heirloom tracking with scaling
- **Toy Collection** - Fun items collection
- **Transmog System** - Appearance collection with full wardrobe UI
- **Wishlist Feature** - Track desired collectibles
- **Shop Integration** - In-game collection shop
- **Account-Wide Toggle** - Enable/disable account-wide sharing

### 🏠 Guild Housing System
*Private guild instances with customization*

- **Phase-Based Isolation** - Each guild has unique power-of-2 phase (up to 27 concurrent houses)
  - Formula: `(1 << (4 + (guildId - 1) % 27))` for bits 4-30
- **Spawn Management** - Guild members can spawn NPCs and GameObjects
- **Permission System** - Rank-based permissions:
  - `GH_PERM_SPAWN` (1) - Spawn entities
  - `GH_PERM_DELETE` (2) - Delete entities
  - `GH_PERM_MOVE` (4) - Move entities
  - `GH_PERM_ADMIN` (8) - Full admin control
  - `GH_PERM_WORKSHOP` (16) - Workshop access
- **Butler NPC** - Guild house service NPC (Entry 500030+)
- **Teleporter NPC** - Quick travel to guild house
- **Audit Logging** - Track all changes with undo capability
- **Multiple Locations** - Support for different guild house maps via location IDs

### 🐉 World Boss System
*Centralized world boss event management*

- **Boss Registration** - Dynamic boss spawning with display names, zones, and respawn timers
- **Respawn Timers** - Configurable respawn with countdown (default 30 min)
- **State Tracking** - Active/inactive/engaged status monitoring
- **HP Threshold Broadcasts** - Alerts at specific health percentages
- **WRLD Addon Protocol** - Real-time boss status broadcasts
- **Update Ticking** - Automatic respawn timer management via world script hooks

#### Implemented World Bosses (Giant Isles)
| Boss | Entry | Zone | Features |
|------|-------|------|----------|
| **Oondasta** | 400100 | Devilsaur Gorge | King of Dinosaurs |
| **Thok** | 400101 | Raptor Ridge | The Bloodthirsty |
| **Nalak** | 400102 | Thundering Peaks | Storm Lord |

### 📜 Dungeon Quest System
*Enhanced daily, weekly, and event-based dungeon quests*

- **Daily Quests** - Rotating dungeon objectives with categorization
- **Weekly Challenges** - Raid and special content quests
- **Token Rewards** - Currency integration with upgrade system via TokenConfigManager
- **Personal Quest Giver** - Follower NPC that accompanies players in dungeons
- **Quest Phasing** - Proper phasing for quest objectives
- **Enhanced UX** - Categorized gossip menus (Daily/Weekly/Dungeon/All)
- **Player Statistics** - Track completion progress
- **Standard AC Integration** - Uses `creature_questrelation`, `creature_involvedrelation` tables

### 🌡️ Hotspot XP System
*Dynamic XP bonus zones*

- **Grid-Based System** - Efficient spatial hotspot management via HotspotGrid
- **Map Integration** - Visual indicators on world map via client addon
- **Rotating Hotspots** - Changing bonus locations with configurable duration
- **Stacking Bonuses** - Combine with other XP modifiers
- **Zone Restrictions** - Configurable zones for hotspot spawning
- **Objective System** - Complete objectives within hotspots for bonuses
- **Per-Player Tracking** - Entry time, last XP gain, expiry management
- **Visual Markers** - Recreatable hotspot visual indicators
- **DB Persistence** - Hotspots saved and loaded from database
- **Hotspot Buff** - Custom spell (800001) for XP bonus effect

---

## 📡 DC Addon Protocol & Communication

### AddonExtension System
The `AddonExtension` folder contains **30+ server-side addon message handlers** that process all client-server communication:

#### Protocol Format
```
Simple: DC|MODULE|OPCODE|DATA1|DATA2|...
JSON:   DC|MODULE|OPCODE|J|{"key":"value",...}
```

#### Registered Modules
| Module | Code | Purpose |
|--------|------|---------|
| AOE Loot | `AOE` | AoE loot settings sync |
| Spectator | `SPEC` | M+ spectator system |
| Upgrade | `UPG` | Item upgrade operations |
| Hinterland BG | `HLBG` | HLBG queue and stats |
| Phased Duels | `DUEL` | Duel system messaging |
| Mythic Plus | `MPLUS` | M+ runs and affixes |
| Prestige | `PRES` | Prestige system |
| Seasonal | `SEAS` | Season data |
| Core | `CORE` | Handshake, version check |
| Hotspot | `SPOT` | XP hotspot zones |
| Leaderboard | `LBRD` | Unified leaderboards |
| Welcome | `WELC` | First-start system |
| Group Finder | `GRPF` | M+ and raid finder |
| GOMove | `GOMV` | Object mover system |
| Teleports | `TELE` | Teleport requests |
| Events | `EVNT` | Dynamic events |
| World | `WRLD` | World bosses, rares |
| Collection | `COLL` | Mounts, pets, transmog |
| QoS | `QOS` | Quality of life settings |

#### Protocol Features
- **Message Chunking** - Large messages split for WoW's 255-byte limit
- **JSON Support** - Complex data via JSON with `J` flag
- **Rate Limiting** - Configurable message rate limits
- **Metrics Tracking** - Messages sent/received, cache hits, errors
- **Handler Registration** - Per-module/opcode handler registration
- **S2C Logging** - Optional server-to-client message logging

---

## 🖥️ Client Addons

All DC addons are included in `Custom/Client addons needed/` and feature a **unified visual design** with:
- **FelLeather Background Texture** - Consistent dark textured backgrounds
- **Matching Border Styles** - Unified UI borders across all DC addons
- **Color-Coded Titles** - `|cffFFCC00DC|r` gold prefix for all addon titles
- **Shared Style Functions** - `ApplyLeaderboardsStyle()` applied to all frames

### Core Communication
| Addon | Version | Purpose |
|-------|---------|---------|
| **DC-AddonProtocol** | 2.0.0 | Unified communication library with JSON support, request/response tracking, error handling, debug panel with JSON editor, connection status monitoring, and module wrappers (DC.AOE, DC.Upgrade, DC.Spectator, etc.) |

### Gameplay Systems
| Addon | Version | Purpose |
|-------|---------|---------|
| **DC-ItemUpgrade** | 2.3 | Item upgrade interface with tier management, heirloom support, transmutation, and cache system |
| **DC-MythicPlus** | 1.0.0 | Complete M+ addon: HUD with timer/affixes, Group Finder (M+/Raid/World tabs), Live Runs viewer, Spectator mode, Keystone Activation, Token Vendor, Seasonal Portals, Great Vault UI |
| **DC-HinterlandBG** | 1.4.0 | HLBG queue system, modern HUD, live stats, match history, leaderboard adapter, settings panel, AIO integration |
| **DC-Collection** | 1.0.0 | Full collection UI: Mounts, Pets, Titles, Heirlooms, Toys, Transmog wardrobe with outfit system, community tab, achievement tracking, wishlist, shop integration |
| **DC-Leaderboards** | 1.4.0 | Unified full-screen leaderboard system with separate quality columns for all competitive content |

### UI & Quality of Life
| Addon | Version | Purpose |
|-------|---------|---------|
| **DC-Welcome** | 2.0.0 | First-login welcome frame, progress tracking, addons hub, seasons tracker, challenge/prestige UI, FAQ panel, minimap button, integrated RestoreXP (XP bar for 80+), TitleFix, and NPC tooltips |
| **DC-InfoBar** | 1.0.0 | Server info bar with modular plugin system: Season, Prestige, Keystone, Affixes, World Boss, Events, Location, XP/Rep, Gold, Durability, Bags, Performance, Clock, Launchers |
| **DC-AOESettings** | 1.2.0 | AOE loot configuration panel with quality filters, profession integration, gold-only mode, and server sync |
| **DC-Mapupgrades** | 1.2.0 | XP hotspots display via Astrolabe integration, custom map pins for world bosses and rares, options panel |

### DC-QOS (Quality of Service) - Comprehensive QoL Suite
**Version 1.2.0** - Adapted from Leatrix Plus for WoW 3.3.5a with DarkChaos enhancements

| Module | Features |
|--------|----------|
| **Tooltips** | Item ID/Level/Upgrade info display, NPC ID, Spell ID, Guild Rank, Target info, cursor anchoring, scale adjustment, combat hiding, tier color coding |
| **Automation** | Auto repair (personal/guild), auto sell junk, auto dismount, auto accept summon/resurrect, auto decline duels/guild invites, auto quest accept/turn-in, auto stand, gossip skip, BG release, BoP confirm, faster loot, cinematic skip |
| **Extended Stats** | Full character stats panel: Movement speed, Melee (AP/Hit/Crit/Haste/Expertise/ArPen/Miss), Ranged (same), Spell (Power/Pen/Hit/Crit/Haste/Miss), Defense (Armor/Defense/Dodge/Parry/Block/Resilience), Regen (MP5) |
| **GTFO Alerts** | Audio/visual warnings for standing in bad, high/low damage alerts, fail alerts, friendly fire detection, configurable volume and cooldown, known bad spells database |
| **Item Score** | Pawn-style item scoring, upgrade arrows, stat weights per class/spec, comparison tooltips, color-coded upgrades/downgrades/sidegrades |
| **Nameplates Plus** | Class colors, health percent, target highlight, threat colors, cast bars with interrupt indicator, debuff display, aura filtering (whitelist/blacklist/priority), range fade, profile system |
| **Bag Enhancements** | Bag organization and display improvements |
| **Cooldowns** | Cooldown text on action buttons with configurable size/duration threshold |
| **Chat** | Channel name hiding, timestamp options, social button toggle, sticky channels, class name shortening |
| **Interface** | Combat plates toggle, auto quest watch, quest level text, gryphon hiding, world map options |
| **Druid Fix** | Druid-specific UI fixes for 3.3.5a |
| **Mail** | Mail UI enhancements |
| **Frame Mover** | Drag and reposition UI frames |
| **Vendor Plus** | Enhanced vendor interface |
| **Combat Log** | Combat log enhancements |
| **Social Enhancements** | Friends list and social UI improvements |

### Administration
| Addon | Version | Purpose |
|-------|---------|---------|
| **DC-GM** | 3.3.5 | Combined admin addon extending AzerothAdmin with DC-specific features |

#### DC-GM Extensions (Beyond Standard AzerothAdmin)
- **GOMove Integration** - Full GameObject manipulation via GOMV protocol:
  - Real-time GO movement with distance display
  - Spawn/delete GameObjects
  - Phase support for phased objects
  - Map button for quick access
  - DC-styled UI with FelLeather backgrounds
- **DC Teleports** - Custom `DCTeleports.lua` with DarkChaos locations
- **DC Commands** - Extended `Commands/DC.lua` for DC-specific operations
- **Linkifier Module** - Enhanced link handling in chat
- **Unified Styling** - All frames use DC visual theme

### Development
| Addon | Version | Purpose |
|-------|---------|---------|
| **DC-Template** | 1.0 | Starting point template for new DC addon development with protocol integration |

---

## 🗺️ Custom Areas

### Azshara Crater (Level 1-80)
*Full leveling zone built on WoW's cancelled battleground terrain*

#### Zone Overview
- **Location** - Forlorn Ridge area of southern Azshara (Map 37, Zone 268)
- **Progression** - Azshara Crater (1-80) → Hyjal Summit (80-130) → Stratholme (130-160)
- **Design** - "Crater Conquest" - Start at Valormok, radiate outward to Temple of Eternity

#### 8 Leveling Tiers
| Zone | Levels | Location | Base |
|------|--------|----------|------|
| Valormok Rim | 1-10 | Southwest | ★ Valormok (Start) |
| Northern Ruins | 10-20 | Northeast | Northern Checkpoint |
| Timbermaw Slopes | 20-30 | Eastern | Eastern Outpost |
| Central Valley | 30-40 | Center | ★ Ton'ma Stronghold |
| Western Cliffs | 40-50 | West | — |
| Haldarr Territory | 50-60 | Central-South | — |
| Dragon Coast | 60-70 | East Coast | — |
| Temple of Eternity | 70-80 | Southeast | ★ Temple Approach |

#### Content Summary
- **~130 Unique NPCs** using existing WotLK creature entry IDs
- **5 Mini-Dungeons** with 5 trash + 1 boss each (Zin-Azshari, Timbermaw Deep, Spitelash Depths, Fel Pit, Sanctum of the Highborne)
- **4 World Bosses** - One per major tier
- **5 Combined Faction Bases** - Both Alliance and Horde welcome
- **8 Zone Rares** - Using existing rare NPCs
- **Safe Road System** - Protected path connecting all bases

#### Inhabitant Factions
| Faction | Role | Theme |
|---------|------|-------|
| Naga | Primary antagonists | Servants of Queen Azshara |
| Satyr (Haldarr/Legashi) | Demonic corrupted elves | Shadow & fel magic |
| Highborne Ghosts | Undead threat | Arcane magic & tragedy |
| Timbermaw Furbolgs | Neutral to friendly | Nature guardians |
| Blue Dragonflight | Elite enemies | Arcane protectors |

### Giant Isles
*MoP-inspired custom zone with world bosses*

- **Zone ID 5000** - Custom zone ported from Pandaria's Isle of Giants
- **Subzones** - Dinotamer Camp, Primal Basin, Devilsaur Gorge, Raptor Ridge, Thundering Peaks, Bone Wastes, Ancient Ruins

#### World Bosses
| Boss | Entry | Zone Area | Description |
|------|-------|-----------|-------------|
| Oondasta | 400100 | Devilsaur Gorge | King of Dinosaurs |
| Thok | 400101 | Raptor Ridge | The Bloodthirsty |
| Nalak | 400102 | Thundering Peaks | Storm Lord |

#### Features
- **Zone Announcements** - Welcome messages on entry
- **Daily Rotation** - World boss daily spawn system
- **Rare Spawns** - Dynamic rare spawning (30-90 min timers, 30 min despawn)
- **Invasion Events** - Zone-wide invasion encounters
- **Cannon Quests** - Interactive cannon gameplay
- **Water Monster** - Unique aquatic encounter
- **Special NPCs** - Elder Zuljin, Witch Doctor, Rokhan

#### Rare Elites
- Static: Primal Direhorn (400050), Chaos Rex (400051), Ancient Primordial (400052), Savage Matriarch (400053), Alpha Raptor (400054)
- Dynamic: Bonecrusher (400055), Gorespine (400056), Venomfang (400057), Skyscreamer (400058), Gulrok (400059)

### Other Zones

#### Active
- **Hinterland BG (Zone 47)** - Scripted OutdoorPvP zone with full queue system
- **Custom Vendor Jail** - Tier vendor hub
- **Battle for Gilneas** - Custom battleground port (BattlegroundBFG)

#### In Development
- **Jadeforest** - MoP port with training grounds, custom flightmasters, and guards
- **Hyjal Extended** - Level 80-130 zone
- **Stratholme Outskirts** - Level 130-160 zone

---

## 📦 Used Modules

```bash
# Core Modules
git clone https://github.com/azerothcore/mod-ah-bot.git modules/mod-ah-bot
git clone https://github.com/azerothcore/mod-learn-spells.git modules/mod-learn-spells
git clone https://github.com/azerothcore/mod-world-chat.git modules/mod-world-chat
git clone https://github.com/azerothcore/mod-cfbg.git modules/mod-cfbg
git clone https://github.com/azerothcore/mod-skip-dk-starting-area.git modules/mod-skip-dk-starting-area
git clone https://github.com/azerothcore/mod-npc-services.git modules/mod-npc-services
git clone https://github.com/azerothcore/mod-instance-reset.git modules/mod-instance-reset
git clone https://github.com/azerothcore/mod-arac.git modules/mod-arac
git clone https://github.com/azerothcore/mod-ale.git modules/mod-ale
git clone https://github.com/Brian-Aldridge/mod-customlogin.git modules/mod-customlogin
```

---

## 🔧 Technical Stack

- **Core:** AzerothCore 3.3.5a (heavily modified)
- **Scripting:** C++ (DC Scripts) + Eluna (Lua)
- **Communication:** AIO Protocol + DC Addon Protocol (JSON-based, chunked messaging)
- **Database:** MySQL with extensive custom tables (`dc_*` prefix)
- **Configuration:** `darkchaos-custom.conf` with 100+ configurable options

### DC Script Architecture
```
src/server/scripts/DC/
├── AC/                    # AzerothCore integration (flightmasters, guards, quest NPCs)
├── Achievements/          # Custom achievement handlers
├── AddonExtension/        # 30+ server-side addon message handlers
│   ├── dc_addon_protocol.cpp      # Core protocol routing
│   ├── dc_addon_namespace.h       # Module/opcode definitions
│   ├── dc_addon_*.cpp             # Per-module handlers
├── CollectionSystem/      # Mount, pet, title, transmog collections
├── Commands/              # Custom GM commands (cs_dc_*.cpp)
├── CrossSystem/           # Shared utilities
│   ├── CrossSystemManager.*       # Central coordinator
│   ├── EventBus.*                 # Inter-system events
│   ├── RewardDistributor.*        # Unified rewards
│   ├── SessionContext.*           # Player sessions
│   ├── WorldBossMgr.*             # World boss management
├── DungeonQuests/         # Daily/weekly dungeon quest system
├── GiantIsles/            # Custom zone with world bosses
├── Gilneas/               # Battle for Gilneas BG
├── GOMove/                # GameObject manipulation system
├── GreatVault/            # Weekly reward vault (3 tracks, 9 slots)
├── GuildHousing/          # Guild instance system
├── HinterlandBG/          # Outdoor PvP battleground (20+ files)
├── Hotspot/               # Dynamic XP bonus zones
├── ItemUpgrades/          # Gear progression (25+ files)
├── Jadeforest/            # MoP zone port
├── MythicPlus/            # M+ dungeon scaling (20+ files)
├── PhasedDuels/           # Isolated duel phases
├── Progression/           # Challenge modes, Prestige, First start
│   ├── ChallengeMode/     # Hardcore, Iron Man, etc.
│   ├── FirstStart/        # New player experience
│   ├── Prestige/          # Prestige system with alt bonuses
├── Seasons/               # Seasonal system management
└── Teleporters/           # Teleporter NPC system
```

---

## 📄 License

This project builds upon AzerothCore (AGPL-3.0). Custom DC systems are proprietary.

---

## 📊 Version History

| Version | Date | Highlights |
|---------|------|------------|
| **3.0.0** | January 2026 | Collection System, Great Vault, Guild Housing, World Bosses, Enhanced M+ |
| **2.5.0** | November 2025 | Item Transmutation, Seasonal Integration, Group Finder |
| **2.0.0** | September 2025 | Mythic+ System, Prestige System, Challenge Modes |
| **1.0.0** | June 2025 | Initial release with Level 255, AOE Loot, HLBG |

---

*Last Updated: January 2026*

