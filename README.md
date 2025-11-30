# 🌑 DarkChaos 255 - Custom WoW 3.3.5a Server

> **A heavily customized AzerothCore-based WoW 3.3.5a private server with Level 255 cap, custom systems, and modern endgame features.**

[![Discord](https://img.shields.io/badge/Discord-Join%20Us-7289DA?logo=discord)](https://discord.gg/pNddMEMbb2)
[![Contact](https://img.shields.io/badge/Contact-Darkmord1991-blue)](https://github.com/darkmord1991)

**Open for proposals and discussions!** Especially looking for support in client modding.

---

## 📋 Table of Contents

- [Core Features](#-core-features)
- [Custom Systems](#-custom-systems)
- [Client Addons](#-client-addons)
- [Custom Areas](#-custom-areas)
- [Used Modules](#-used-modules)

---

## 🎮 Core Features

| Feature | Description |
|---------|-------------|
| **Level 255 Cap** | Extended level system with custom stats for Players, Creatures, and Pets |
| **All Races/Classes** | Every race can be any class combination |
| **Eluna Scripting** | Full Lua scripting support with AIO |
| **AOE Loot System** | Loot multiple corpses at once with quality filters and auto-skinning, Addon support for settings |
| **Phased Dueling** | Isolated duel phases with cooldown reset and full HP restore |
| **Teleporter NPCs** | Mobile and stationary teleporters with database-driven locations |
| **Complete Vendors** | Vendors for all WotLK items, professions, and trainers |
| **XP Beyond 80** | Custom addon support for XP bar display above level 80 |

---

## ⚔️ Custom Systems

### 🔥 Mythic+ Dungeon System + standard dungeon enhancements
*Retail-inspired endgame dungeon difficulty scaling*

- **Keystone Levels** - Progressive difficulty with scaling HP/damage
- **Affix System** - Weekly rotating affixes (Fortified, Tyrannical, etc.)
- **Death Budget** - Failed runs based on death count penalties
- **50+ Dungeon Profiles** - Full scaling support for all dungeons
- **Spectator Mode** - Watch active Mythic+ runs live
- **Leaderboards** - Competitive rankings and weekly best times
- **Dungeon Extensions** - Heroic dungeons with scaling rewards for vanilla dungeons
- **Mythic Difficulty** - Available for all 5-person dungeons
- **Custom Addon Support** - Client addon for timers and affix display

### 💎 Item Upgrade System
*Comprehensive gear progression with tier-based upgrades*

- **3 Upgrade Tiers** (T1-T2: 226-252 iLvl), T3 heirloom support with secondary stats packages
- **Token Currency** - Earned from dungeons, raids, and PvP
- **Stat Scaling** - stats can be increased on percentage or flat basis (proc support in future)
- **NPC Interface** - Easy-to-use upgrade vendors
- **Addon Support** - Full client addon for upgrade management and check on items and currency

### ⚔️ Hinterland Battleground (HLBG)
*Open-world PvP zone with objective-based gameplay*

- **Zone 47** - Dedicated PvP area in The Hinterlands
- **Resource Victory** - Team-based objective system
- **Auto Raid Group** - Automatically forms a raid group when joining the zone
- **Queue System** - Automated matchmaking with warmup phase
- **Live Stats Addon** - Real-time battle information via HUD
- **Seasonal Support** - Rotating seasons with rewards

### 🏆 Prestige & Seasons System
*Long-term progression and competitive seasons*

- **Prestige Tiers** - Reset and climb with bonuses
- **Seasonal Content** - Time-limited challenges and rewards
- **Leaderboards** - Global rankings across systems
- **Achievements** - Custom achievements and titles
- **Client Addon** - Prestige and seasonal tracking via client addon
- **Prestige Alt System** - Support for alternate characters in prestige tracking with XP boosts

### 🎯 Challenge Modes
*Multiple difficulty modifiers for hardcore players*

| Mode | Description |
|------|-------------|
| **Hardcore** | One death = permanent character death |
| **Semi-Hardcore** | Limited lives per session |
| **Self-Crafted** | Must craft all own gear |
| **Iron Man** | Combined hardcore + self-crafted + restrictions |
| **Slow XP** | Reduced experience gain modes |

### 📜 Dungeon Quest System
*Daily, weekly, and event-based dungeon quests*

- **Daily Quests** - Rotating dungeon objectives
- **Weekly Challenges** - Raid and special content
- **Token Rewards** - Currency for upgrade system
- **Personal Quest Giver** - Follower NPCs for immersion on join in any dungeon

### 🌡️ Hotspot XP System
*Dynamic XP bonus zones*

- **Map Integration** - Visual indicators on world map
- **Rotating Hotspots** - Changing bonus locations
- **Stacking Bonuses** - Combine with other XP modifiers
- **Client Addon** - Real-time hotspot tracking

### 🎁 Item Vault System
*Weekly reward caches based on activity*

- **Mythic+ Vault** - Rewards based on dungeon completion
- **Raid Vault** - Boss-based loot options
- **Seasonal Reset** - Fresh starts each season

---

## 🖥️ Client Addons

All addons are included in `Custom/Client addons needed/`:

| Addon | Purpose |
|-------|---------|
| **DC-ItemUpgrade** | Item upgrade interface and tracking |
| **DC-MythicPlus** | Keystone timer and affix display |
| **DC-HinterlandBG** | HLBG queue and live stats |
| **DC-Seasons** | Seasonal progress and rewards |
| **DC-Leaderboards** | Global rankings display |
| **DC-Hotspot** | XP hotspot map markers |
| **DC-AOESettings** | AOE loot configuration |
| **DC-RestoreXP** | XP bar for levels 80+ |
| **AIO_Client** | Eluna addon communication |
| **DC-AddonProtocol** | Unified addon messaging |

---

## 🗺️ Custom Areas

### Active Zones
- **Hinterland BG** - Scripted OutdoorPvP zone
- **Custom Vendor Jail** - Tier vendor hub
- **Ashzara Crater** - Level 1-80 leveling zone

### In Development
- **Jadeforest** - MoP port (in preparation)
- **Giant Isles** - MoP port (in preparation)
- **Hyjal Extended** - Level 80-100 zone
- **Stratholme Outskirts** - Level 100-130 zone

### Zone Features
- Custom Flightmasters with proper pathing
- Teleporting guards for navigation
- Loot boxes and wandering NPCs
- Progressive quest lines

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
- **Communication:** AIO Protocol + DC Addon Protocol
- **Database:** MySQL with custom tables
- **Configuration:** Extensive `darkchaos-custom.conf` options

---

## 📄 License

This project builds upon AzerothCore (AGPL-3.0). Custom DC systems are proprietary.

---

*Last Updated: November 2025*

