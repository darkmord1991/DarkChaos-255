## I need help in every area to work on more topics and issues - especially scripting and Client changes
## It would be great to have someone doing some wild stuff with map modifications in Ashzara Crater and the other level Areas for a more Classic+ feeling
## I am always open for proposals and discussions
## Please contact me via Github or Discord (Darkmord1991)

---

## DarkChaos Custom Systems

## General WoW stuff:

* Level 255 stats for Players, Creatures, Pets
* Remove of hardcoded Level limit in Azerothcore
* Teleporter NPCs (mobile + standard one, same scripts used from DB Table based on LUA scripts)
* Vendors for every kind of WOTLK item
* Vendors and trainers for every profession

### 🎮 Mythic+ System
Advanced endgame difficulty system for dungeons with scaling, affixes, and progression mechanics.

**Features:**
- Multiple difficulty levels (Normal, Heroic, Mythic, Mythic+)
- Dynamic creature scaling (HP/Damage multipliers based on keystone level)
- Affix system (weekly rotating server-wide affixes or per-run selection)
- Death budget system (failed runs with death penalties)
- Keystone item system (consumable progression items)
- Difficulty-based loot drops
- Portal difficulty selector NPC
- Full scaling profile support for 50+ dungeons
- Retail-like entry barrier with 10-second countdown
- Font of Power activation system

### 💰 Item Upgrade System (Phase 4 - Complete)
Comprehensive progression system for upgrading gear with multiple tiers and difficulty-based progression.

**Features:**
- 5 upgrade tiers (T1-T5: 226-252 iLvl)
- 15 upgrade levels per tier (total 75 upgrade paths)
- Hybrid stat scaling (Enchantment-based + proc damage/healing)
- Universal token currency system
- Difficulty-based upgrade paths:
  - HLBG: 3 tokens per win
  - Heroic Dungeons: 5 tokens
  - Mythic Dungeons: 8 tokens
  - Raids: 10-20 tokens
- Prestige progression system
- Seasonal content support
- Artifact mastery system
- Tier conversion/transmutation
- Guild progression tracking
- Loadout customization
- Leaderboard rankings
- NPC-based upgrade interface


### 🏛️ Hinterland Battleground (HLBG)
Open-world PvP battleground with team-based objectives and progression.

**Features:**
- Zone 47 Hinterland as dedicated PvP zone
- Resource-based victory system
- Two faction teams (Alliance vs Horde)
- Queue system with warmup phase
- Raid group auto-invite per faction
- Team resource management
- Auto-level check
- Audit logging for admin actions
- Interface addon with live stats
- Battle history tracking
- Seasonal system support
- Affix/Weather system (prepared)
- Worldstates for current state

### 🎯 Challenge Modes
Multiple difficulty modifiers for challenging gameplay experiences.

**Available Modes:**
- **Hardcore Mode** - One death = character dead
- **Semi-Hardcore Mode** - Multiple lives with limited deaths
- **Self-Crafted Mode** - Must craft all own gear
- **Item Quality Restrictions** - Limited to green rarity or better
- **Slow XP Mode** - Reduced experience gain
- **Very Slow XP Mode** - Minimal experience gain
- **Quest XP Only Mode** - No mob experience
- **Iron Man Mode** - Combined hardcore + self-crafted + restrictions

### 📜 Dungeon Quest System
Comprehensive quest system for dungeons with daily/weekly/event quests.

**Features:**
- Daily dungeon quests
- Weekly raid/challenge quests
- Dungeon-specific event quests
- Quest token rewards
- Achievement integration
- Title rewards
- Quest progress tracking
- Personal quest giver followers (DungeonQuestSystem)
- Quest reward system (items, currency, achievements)
- Quest reset and history

**Related Database:**
- Quest types: Daily (700101-700104), Weekly (700201-700204), Events (700701+)
- Token types: Explorer, Specialist, Legendary, Challenge, SpeedRunner (700001-700005)
- Achievement tracking per quest

### ⚙️ DarkChaos XP Addon System
Dual-layer XP tracking system with addon support.

**Features:**
- Real-time XP sync to addon
- Deduplication system (prevents duplicate XP rewards)
- Force-send capability (GM tool)
- Per-character XP state tracking
- Level-based XP thresholds
- Admin XP granting tools

### 🏅 Prestige System
End-game progression allowing players to reset at higher tiers.

**Features:**
- Multiple prestige tiers (with challenges)
- Prestige challenges (speed runs, hardcore, solo)
- Challenge tracking and completion
- Speed run time limits
- Challenge rewards and cosmetics
- Per-tier stat scaling
- Prestige levels and badges

---

### 🎁 Item Vault System
Seasonal loot distribution for top-tier content.

**Features:**
- Mythic+ vault rewards
- Raid vault integration
- Mythic+ 2-4 vault slots
- Mythic+ 5-8 vault slots
- Mythic+ 9+ vault slots
- Difficulty-based reward tiers
- Seasonal reset

---

## General Features

### Level 255 System
- Full support for levels 1-255
- Custom creature scaling per zone
- Custom zone difficulty configurations
- Quest and quest giver support across all levels

### Custom Content
- Custom zones with proper scaling
- Custom item sets (T11 Level 100, T12 Level 130)
- Custom dungeons with blizzlike setups
- Custom NPCs and services

### Teleporter Systems
- Mobile teleporters
- Static teleporter NPCs
- Database-driven teleportation
- Zone access control

### Service NPCs
- Vendors for all professions
- Transmog services
- Pet vendor
- Various services accessible throughout the world

---

## Custom areas:

* Hinterland BG - Scripted OutdoorPvP Area
* Ashzara Crater Level Area 1-80
* Custom Tier Vendor Jail
## Custom Level Areas:
* Ashzara Crater - Level 1 - 80 - spawns and preps done, more quests to be done
* Hyjal - Level 80 - 130 - start area prepared
* Strathholme dungeon outside - Level 130 - 160
* Flightmasters to be implemented for more immersion (Ashzara Crater already done)
* Teleporting guards for easier access

## HinterlandBG Features:
* Several commands (for reset, status)
* Interface Addon via .hlbg or /hlbg or via the PvP panel (still WIP, little buggy -> reading history data from CharDB, Stats, Queue start, etc.)
* Worldstates for current state
* lots of stuff configurable via config
* Queue system for the warmup phase
* Affix/Weather system prepared
* Season system prepared
* Auto check for level
* Autoinvite to raid group per faction
* and much more

## used modules
* git clone https://github.com/azerothcore/mod-ah-bot.git modules/mod-ah-bot
* git clone https://github.com/azerothcore/mod-duel-reset.git modules/mod-duel-reset
* git clone https://github.com/azerothcore/mod-learn-spells.git modules/mod-learn-spells
* git clone https://github.com/azerothcore/mod-world-chat.git modules/mod-world-chat
* git clone https://github.com/azerothcore/mod-cfbg.git modules/mod-cfbg
* git clone https://github.com/azerothcore/mod-skip-dk-starting-area.git modules/mod-skip-dk-starting-area
* git clone https://github.com/azerothcore/mod-npc-services.git modules/mod-npc-services
* git clone https://github.com/azerothcore/mod-instance-reset.git modules/mod-instance-reset
* git clone https://github.com/azerothcore/mod-arac.git modules/mod-arac
* git clone https://github.com/azerothcore/mod-anticheat.git modules/mod-anticheat
* git clone https://github.com/azerothcore/mod-eluna.git modules/mod-eluna
* git clone https://github.com/Brian-Aldridge/mod-customlogin.git modules/mod-customlogin

