# DarkChaos-255 Feature Analysis: Effort & Available Modules
**Detailed Analysis with Effort Ratings and AzerothCore Module Links**

*Last Updated: November 1, 2025*

---

## Rating System

### Effort Scale (1-10)
- **1-2**: Trivial - Hours to days
- **3-4**: Easy - Days to 1 week
- **5-6**: Moderate - 1-2 weeks
- **7-8**: Complex - 2-4 weeks
- **9-10**: Very Complex - 1-3 months

### Module Availability
- ✅ **Module Exists** - Direct implementation available
- 🟡 **Partial Module** - Requires modification
- 🔧 **Framework Exists** - Foundation available, custom work needed
- ❌ **No Module** - Build from scratch

---

## Server-Side Only Features

### 🟢 High Priority - Quick Wins

#### 1. Dynamic World Events System
**Effort: 4/10** ⏱️ ~1 week  
**Module Status:** 🔧 Framework Exists

**Available Modules:**
- **[mod-weekendbonus](https://github.com/azerothcore/mod-weekendbonus)** - Weekend XP/rep bonuses
  - Can be extended for rotating events
  - Already has bonus multiplier system
- **[mod-server-auto-shutdown](https://github.com/azerothcore/mod-server-auto-shutdown)** - Time-based automation
  - Event scheduling framework

**What You Need to Build:**
- Event rotation scheduler
- Multiple event types (XP, tokens, invasions)
- Server-wide announcements
- Database configuration

**Recommended Approach:**
```cpp
// Extend mod-weekendbonus with:
- Multi-event support
- Token bonus events
- Rare spawn triggers
- Zone-specific events
```

---

#### 2. Prestige System for Level 255
**Effort: 6/10** ⏱️ ~2 weeks  
**Module Status:** ❌ No Module (Custom Implementation)

**Similar Modules (for reference):**
- **[mod-individual-progression](https://github.com/ZhengPeiRu21/mod-individual-progression)** - 170★
  - Individual player progression tracking
  - Could adapt progression mechanics
  
**What You Need to Build:**
- Prestige level storage (character DB)
- Level reset functionality
- Stat bonus application
- Prestige vendor system
- Title/reward grants

**Implementation Notes:**
- Hook into `Player::GiveLevel()` for reset detection
- Use `Player::SetLevel(1)` with prestige flag
- Apply stat modifiers in `Player::UpdateStats()`
- Store in custom table: `character_prestige`

**Complexity Factors:**
- Gear handling during reset (+1 effort)
- Achievement preservation (+1 effort)
- Guild/reputation handling (+1 effort)

---

#### 3. Advanced Token System
**Effort: 5/10** ⏱️ ~1.5 weeks  
**Module Status:** 🟡 Partial Module

**Available Modules:**
- **[mod-currency](https://github.com/FrostedDev/mod-currency)** - Custom currency system
  - Multi-currency support
  - Database storage
  - Vendor integration
  
**What You Need to Build:**
- Token types (bronze, silver, gold, prestige, cosmetic)
- Token gain hooks (quests, dungeons, BGs)
- Token vendors with price configuration
- Token trade/mail restrictions (optional)

**Recommended Approach:**
```bash
git clone https://github.com/FrostedDev/mod-currency modules/mod-currency
# Modify to support 5 token types
# Add token gains to dungeon/BG hooks
# Create token vendor NPCs
```

---

#### 4. Scalable Raid System
**Effort: 7/10** ⏱️ ~3 weeks  
**Module Status:** 🔧 Framework Exists

**Available Modules:**
- **[mod-autobalance](https://github.com/azerothcore/mod-autobalance)** - 126★
  - Scales dungeons/raids to group size
  - HP/damage multipliers
  - Loot scaling
- **[mod-zone-difficulty](https://github.com/azerothcore/mod-zone-difficulty)** - Already integrated
  - Zone-based difficulty scaling
- **[mod-challenge-modes](https://github.com/ZhengPeiRu21/mod-challenge-modes)** - 53★
  - Custom difficulty modifiers
  - Time challenges

**What You Need to Build:**
- Additional difficulty levels (Heroic 100, 130, 160, Mythic 200, 255)
- Loot table multipliers per tier
- Separate lockout tracking
- Stat scaling formulas per tier

**Recommended Approach:**
```cpp
// Extend mod-autobalance with:
- Level-based difficulty selection
- Custom loot tables per tier
- Separate instance IDs for each tier
```

**Complexity Factors:**
- Mechanics tuning per difficulty (+2 effort)
- Loot table creation (+1 effort)
- Testing all raids × all difficulties (+2 effort)

---

#### 5. World Boss System
**Effort: 5/10** ⏱️ ~1.5 weeks  
**Module Status:** 🔧 Framework Exists

**Available Modules:**
- **[mod-autobalance](https://github.com/azerothcore/mod-autobalance)** - Boss scaling
- **[mod-progression-system](https://github.com/tkn963/mod-progression-system)** - World boss lockouts

**What You Need to Build:**
- Spawn timer system (6-24 hours)
- Server-wide announcements
- Loot tables per boss
- Boss scripts (mechanics)
- Respawn tracking database

**Recommended Approach:**
```sql
-- Use existing creature_template
-- Add custom spawn_timers table
-- Hook WorldScript::OnCreatureKill for respawn logic
-- Use SMSG_NOTIFICATION for announcements
```

---

#### 6. Achievement System Expansion
**Effort: 6/10** ⏱️ ~2 weeks  
**Module Status:** 🔧 Framework Exists (Core)

**Core Support:**
- Achievement system already in AzerothCore
- Can add custom achievements via `achievement_reward` table

**What You Need to Build:**
- Custom achievement definitions (SQL)
- Criteria scripts for custom content
- Reward items/titles
- Server-first tracking (optional)

**Recommended Approach:**
```sql
-- Add to achievement_criteria_data
INSERT INTO achievement_criteria_data (criteria_id, type, value1, value2) VALUES
(50000, 11, 38, 0); -- Map check for Azshara Crater

-- Add achievements to achievement_reward
INSERT INTO achievement_reward (ID, TitleA, TitleH, ItemID) VALUES
(50000, 200, 200, 50000); -- Azshara Explorer title + reward
```

**Module Reference:**
- **[mod-achievement-vendor](https://github.com/talamortis/mod-achievement-vendor)** - Sell items for achievement points

---

#### 7. Automated Tournament System
**Effort: 8/10** ⏱️ ~4 weeks  
**Module Status:** ❌ No Module

**Similar Modules:**
- **[mod-1v1-arena](https://github.com/azerothcore/mod-1v1-arena)** - 1v1 arena framework
  - Queue system
  - Rating system
  - Could be extended

**What You Need to Build:**
- Tournament scheduler
- Bracket generator (single/double elimination)
- Spectator system (phasing or special instance)
- Automated match creation
- Prize distribution
- Leaderboard tracking

**Complexity Factors:**
- Bracket algorithm (+2 effort)
- Observer mode implementation (+3 effort)
- Anti-cheat for tournaments (+1 effort)

---

#### 8. Dynamic Difficulty Scaling
**Effort: 4/10** ⏱️ ~1 week  
**Module Status:** ✅ Module Exists

**Available Modules:**
- **[mod-autobalance](https://github.com/azerothcore/mod-autobalance)** - 126★ **RECOMMENDED**
  - Already scales to group size (1-5 players)
  - Configurable multipliers
  - Works for dungeons and raids
  - Active development

**Implementation:**
```bash
git clone https://github.com/azerothcore/mod-autobalance modules/mod-autobalance
# Configure in worldserver.conf
AutoBalance.Enable = 1
AutoBalance.InflectionPoint = 2.5  # Balance point
AutoBalance.InflectionPointRaid = 10
```

**Additional Configuration Needed:**
- Adjust reward scaling (modify loot tables)
- Set per-zone difficulty curves
- Hard mode toggles (custom addition)

---

### 🟡 Medium Priority - Core Enhancements

#### 9. Mentor/Apprentice System
**Effort: 5/10** ⏱️ ~1.5 weeks  
**Module Status:** 🟡 Partial Module

**Available Modules:**
- **[mod-recruitafriend](https://github.com/azerothcore/mod-recruitafriend)** - RAF system
  - Grouped XP bonuses
  - Reward tracking
  - Could be adapted for mentorship

**What You Need to Build:**
- Mentor registration (level 200+ requirement)
- Apprentice linking
- Level scaling (scale mentor down)
- Bonus rewards for mentor
- Achievement tracking

**Recommended Approach:**
```cpp
// Extend mod-recruitafriend with:
- Level requirement check
- Mentor scaling (use DungeonDifficulties)
- Token rewards for mentors
```

---

#### 10. Guild Advancement System
**Effort: 7/10** ⏱️ ~3 weeks  
**Module Status:** 🔧 Framework Exists

**Available Modules:**
- **[mod-guild-funds](https://github.com/azerothcore/mod-guild-funds)** - Guild bank enhancements
- **[mod-guild-progression](https://github.com/Winfidonarleyan/mod-guild-progression)** - Guild XP tracking

**What You Need to Build:**
- Guild XP formula
- Level-based perks (25 levels)
- Perk database and application
- Guild achievement integration
- Guild vs Guild event system

**Complexity Factors:**
- Perk balance testing (+2 effort)
- GvG event scripting (+2 effort)
- Guild bank expansion (+1 effort)

---

#### 11. Professions to 600+
**Effort: 8/10** ⏱️ ~4 weeks  
**Module Status:** ❌ No Module

**What You Need to Build:**
- Extend skill cap beyond 450
- Create 150+ custom recipes (50 per tier: T11, T12, T13+)
- Add gathering nodes to custom zones
- Create profession quests
- Balance crafted gear with raid gear

**Database Work:**
```sql
-- Modify skill_line_ability cap
-- Add custom recipes to npc_trainer
-- Create item_template entries for crafted items
-- Add gameobject spawns for nodes
```

**Complexity Factors:**
- Recipe design and balance (+3 effort)
- Gathering node placement (+1 effort)
- Item stat balance (+2 effort)

---

#### 12. Bounty/Contract System
**Effort: 4/10** ⏱️ ~1 week  
**Module Status:** 🟡 Partial Module

**Available Modules:**
- **[mod-daily-quests](https://github.com/azerothcore/mod-daily-quests)** - Daily quest system
  - Can be adapted for contracts
- **[mod-bounty-hunter](https://github.com/Kitzunu/mod-bounty-hunter)** - PvP bounty system
  - Kill tracking
  - Reward distribution

**What You Need to Build:**
- Contract board NPC/UI
- Daily/weekly rotation
- Multiple contract types (PvP, PvE, gathering)
- Progress tracking
- Reward claims

**Recommended Approach:**
```cpp
// Combine elements from both modules
// Add contract types to database
// Hook into kill/completion events
// Automated reset daily/weekly
```

---

#### 13. Reputation System Overhaul
**Effort: 6/10** ⏱️ ~2 weeks  
**Module Status:** 🔧 Framework Exists (Core)

**Core Support:**
- Reputation system fully functional in core
- Can add custom factions via `Faction.dbc` (client) or SQL hacks (server-only with limitations)

**What You Need to Build:**
- Custom faction definitions (4-5 factions)
- Reputation gain hooks (quests, kills, dungeons)
- Faction vendors with tiered rewards
- Tabards for each faction
- Achievement integration

**Recommended Approach:**
```sql
-- Add factions to faction.dbc (client edit) OR
-- Use existing faction IDs and repurpose them
-- Create reputation reward vendors
-- Add rep gains to creature_onkill_reputation
```

---

#### 14. Cross-Faction Grouping Enhancements
**Effort: 2/10** ⏱️ ~2 days  
**Module Status:** ✅ Module Exists

**Available Modules:**
- **[mod-cfbg](https://github.com/azerothcore/mod-cfbg)** - Already integrated! ✅
  - Cross-faction battlegrounds
  - Mercenary system
  
**What You Need to Do:**
- Extend CFBG to dungeons and raids
- Configuration update

**Implementation:**
```cpp
// In mod-cfbg, extend to:
sLFGMgr->EnableCrossFaction(true);  // Dungeons
sGroupMgr->AllowCrossFaction(true);  // Manual groups
```

**Effort Reduction:**
- Module already integrated (-6 effort from original estimate)
- Just needs configuration and testing

---

#### 15. Smart Loot System
**Effort: 7/10** ⏱️ ~3 weeks  
**Module Status:** 🟡 Partial Module

**Available Modules:**
- **[mod-group-loot](https://github.com/azerothcore/mod-group-loot)** - Loot distribution system
- **[mod-autobalance](https://github.com/azerothcore/mod-autobalance)** - Has loot scaling

**What You Need to Build:**
- Personal loot rolls (separate from group loot)
- Spec detection and item filtering
- Bonus roll system (token-based)
- Duplicate item protection
- Loot trading timer (2 hours)

**Complexity Factors:**
- Spec-appropriate filtering algorithm (+2 effort)
- Loot trading restrictions (+1 effort)
- Bonus roll UI/system (+2 effort)

---

### 🔵 Low Priority - Nice to Have

#### 16. Seasonal Leaderboards
**Effort: 5/10** ⏱️ ~1.5 weeks  
**Module Status:** 🔧 Framework Exists

**Available Modules:**
- **[mod-leaderboards](https://github.com/azerothcore/mod-leaderboards)** - Basic leaderboard tracking

**What You Need to Build:**
- Seasonal reset system
- Multiple stat categories
- Top 100 tracking per category
- Reward distribution
- Web display (optional)

---

#### 17. Pet Battle System (3.3.5a version)
**Effort: 10/10** ⏱️ ~3 months  
**Module Status:** ❌ No Module

**Warning:** Extremely complex, not recommended unless you have dedicated resources.

**What You Need to Build:**
- Entire pet combat system from scratch
- Pet abilities and stats
- Turn-based combat engine
- Pet collection database
- Pet leveling system
- PvP pet battles

**Complexity Factors:**
- New combat system (+4 effort)
- Pet AI (+3 effort)
- Balance testing (+2 effort)

**Recommendation:** **Skip this** - Focus on higher ROI features

---

#### 18. Archaeology/Relic System
**Effort: 8/10** ⏱️ ~4 weeks  
**Module Status:** ❌ No Module

**What You Need to Build:**
- Dig site spawning system
- Fragment collection mechanic
- Artifact solver system
- Reward database
- New profession skill

**Complexity Factors:**
- Dig site mechanics (+3 effort)
- Rare artifact RNG (+1 effort)
- Client integration for dig sites (+2 effort)

---

#### 19. Heroic+ Dungeon System (Mythic+ for 3.3.5a)
**Effort: 3/10** ⏱️ ~1 week  
**Module Status:** ✅ Module Exists

**Available Modules:**
- **[mod-mythic-plus](https://github.com/silviu20092/mod-mythic-plus)** - Already integrated! ✅
  - Keystone system
  - Affixes
  - Scaling difficulty
  - Leaderboards

**What You Need to Do:**
- Configure keystones for custom dungeons
- Add custom affixes (optional)
- Set reward tables
- Enable leaderboards

**Implementation:**
```bash
# Already in modules/mod-mythic-plus
# Configure in worldserver.conf
MythicPlus.Enable = 1
MythicPlus.MaxLevel = 20
# Add custom dungeon IDs to keystone pool
```

---

#### 20. Garrison/Player Housing Lite
**Effort: 9/10** ⏱️ ~2 months  
**Module Status:** 🔧 Framework Exists

**Available Modules:**
- **[mod-phasing](https://github.com/azerothcore/mod-phasing)** - Phasing system
  - Instanced player areas
  - Object visibility control

**What You Need to Build:**
- Instanced room system
- Trophy/decoration placement
- Functional NPC spawns (bank, vendor, etc.)
- Upgrade system
- Visitor permission system

**Complexity Factors:**
- Phasing implementation (+3 effort)
- Object placement system (+3 effort)
- Upgrade progression (+2 effort)

---

## Server + Client Features

### 🟢 High Priority - Maximum Impact

#### 21. Custom Races (Model Swaps)
**Effort: 9/10** ⏱️ ~2 months  
**Module Status:** 🟡 Partial Module

**Available Modules:**
- **[mod-arac](https://github.com/heyitsbench/mod-arac)** - 50★ Already integrated! ✅
  - All Races All Classes
  - Race template framework
  - Character creation hooks

**What You Need to Build:**
**Server:**
- Race stat modifiers
- Racial abilities (new spells)
- Starting zone assignments
- Racial mount assignments

**Client:**
- ChrRaces.dbc edits (add new race IDs)
- CharBaseInfo.dbc (racial stats)
- Model paths (use existing models)
- Starting cinematics
- Racial mount displays

**Recommended Races:**
1. **Vrykul** - Use human male model scaled up
2. **High Elf** - Use blood elf model, alliance
3. **Mag'har Orc** - Use orc model, brown skin
4. **Taunka** - Use tauren model, different horns

**Complexity Factors:**
- DBC editing per race (+2 effort per race)
- Racial abilities scripting (+2 effort)
- Starting zone setup (+1 effort per race)
- Testing and balance (+2 effort)

**Total Effort:** 9/10 for 2 races, 10/10 for 4 races

---

#### 22. Custom Class Specializations (4th spec)
**Effort: 10/10** ⏱️ ~3 months  
**Module Status:** ❌ No Module (Extremely Complex)

**Warning:** This is one of the most complex features possible. **Not recommended without a dedicated team.**

**What You Need to Build:**
**Server:**
- New talent trees (81 talents per spec)
- Spec-specific spells (30-50 per spec)
- Stat priorities and scaling
- Spec switching functionality
- Balance tuning

**Client:**
- TalentTab.dbc entries (new tabs)
- Spell.dbc entries (all new spells)
- Icon files (spell icons)
- Talent frame UI modifications
- Spell tooltip modifications

**Per-Class Work (×10 classes):**
- Design 4th spec identity (tank/heal/DPS role)
- Create talent tree layout
- Script 30-50 spells
- Balance test against existing specs
- Create visual effects (optional)

**Complexity Factors:**
- Spell scripting per spec (+4 effort)
- Talent tree design (+3 effort)
- Balance testing (+5 effort)
- Client DBC work (+3 effort)
- UI modifications (+2 effort)

**Recommendation:** Start with **2-3 classes** (6-7 effort each) rather than all 10.

**Suggested Priority Classes:**
1. **Shaman** - Tank spec (most requested)
2. **Warlock** - Demon tank spec
3. **Priest** - Void DPS spec

---

#### 23. Flying in Azshara Crater/Hyjal
**Effort: 3/10** ⏱️ ~1 week  
**Module Status:** 🔧 Framework Exists (Core)

**What You Need to Do:**
**Server:**
- Enable flying flag for maps 37 (Azshara Crater) and 1 (Hyjal subzone)
- Configure no-fly zones (optional)

**Client:**
- Map.dbc flag modifications (CanFly flag)
- ADT header flags (if needed)

**Implementation:**
```sql
-- Server-side map flags
UPDATE map_template SET flying_enabled = 1 WHERE entry IN (37, 1);

-- Client: Map.dbc
-- Set flag 0x100 (Can Fly) for map IDs 37 and 1
```

**Complexity Factors:**
- Very simple if zones already have ADT data
- +2 effort if need to add sky collision/barriers

---

#### 24. New Level 255 Zones (3-5 zones)
**Effort: 10/10 per zone** ⏱️ ~2-3 months per zone  
**Module Status:** ❌ No Module (Custom Content)

**What You Need to Build per Zone:**

**Server:**
- 50-100 quests per zone
- 50+ creature spawns
- 2-3 dungeon instances
- 3-5 world bosses
- Quest chains and storylines
- Loot tables
- Reputation faction

**Client:**
- Map.dbc entry
- AreaTable.dbc (zone and subzone names)
- WorldMapArea.dbc (minimap)
- LoadingScreen.dbc (loading screen)
- ADT terrain files (can reuse/modify existing zones)
- Minimap textures
- Music (optional)

**Zone Creation Options:**

**Option A: Reuse Existing Zones** (Effort: 6/10)
- Copy existing zone ADTs (e.g., Wintergrasp, Storm Peaks)
- Modify spawn tables
- Create new quests
- Faster, but less unique

**Option B: New Zone Areas** (Effort: 10/10)
- Requires ADT editing (Taliis, Noggit)
- New terrain height maps
- New textures and models
- Completely custom

**Recommended Zones for Level 170-255:**

1. **Emerald Sanctum** (170-185) - Reuse Moonglade/Grizzly Hills ADTs
2. **Titan Foundry** (185-200) - Reuse Ulduar exterior ADTs
3. **Void Wastes** (200-220) - Reuse Icecrown ADTs, darker
4. **Elemental Conflux** (220-240) - Reuse Vortex Pinnacle/Throne of Four Winds areas
5. **Nexus of Eternity** (240-255) - Reuse Nexus ADTs, cosmic theme

**Complexity Factors:**
- ADT terrain work (+4 effort if new, +1 if reuse)
- Quest design and scripting (+3 effort)
- NPC placement and balance (+2 effort)
- Dungeon creation (+3 effort per dungeon)
- Client file packaging (+1 effort)

**Total Effort Estimate:**
- **Per zone (reusing ADTs):** 6-7/10 = ~1 month
- **Per zone (new ADTs):** 10/10 = ~2-3 months

**Recommendation:** Start with **2 zones** using reused ADTs (3 months total)

---

#### 25. Custom Battleground: Battle for Gilneas
**Effort: 8/10** ⏱️ ~1 month  
**Module Status:** 🔧 Framework Exists (Zone exists)

**What You Need to Build:**
**Server:**
- BG script (objectives, scoring, win conditions)
- Capture point scripts
- Spawn points (15v15)
- Reward tables
- Queue integration
- Leaderboards

**Client:**
- BattlemasterList.dbc entry
- Map.dbc (zone already exists as map)
- Loading screen
- BG map icons

**Complexity Factors:**
- Zone already exists (Gilneas) - reuse ADTs (-2 effort)
- BG script complexity (+3 effort)
- Balance testing (+2 effort)
- Multi-bracket support (+1 effort)

**Similar Module:**
- Study Hinterlands BG implementation for reference

---

#### 26. Transmogrification Enhancement
**Effort: 5/10** ⏱️ ~1.5 weeks  
**Module Status:** ✅ Module Exists (Enhanced version needed)

**Available Modules:**
- **[mod-transmog](https://github.com/azerothcore/mod-transmog)** - 151★ Already integrated! ✅
  - Basic transmog functionality
  - Item appearance storage

**What You Need to Build:**
**Server:**
- Account-wide appearance database
- Collection tracking
- Set completion tracking
- Outfit save/load (10+ slots)
- Appearance source search

**Client:**
- Collection UI addon
- Outfit manager addon
- Appearance preview

**Recommended Approach:**
```bash
# Extend mod-transmog with:
- Account-wide unlocks (modify DB structure)
- Outfit save system (new DB table)
- Collection search (addon + server query)
```

**Complexity Factors:**
- Account-wide tracking (+2 effort)
- Addon UI development (+2 effort)
- Database optimization (+1 effort)

---

#### 27. Mount Collection System
**Effort: 4/10** ⏱️ ~1 week  
**Module Status:** 🔧 Framework Exists

**Available Modules:**
- **[mod-learn-spells](https://github.com/azerothcore/mod-learn-spells)** - Spell learning system
  - Can be adapted for mount spells

**What You Need to Build:**
**Server:**
- Account-wide mount unlocks
- Mount achievement tracking
- 200+ new mount items/spells

**Client:**
- Mount journal addon
- Summon random mount functionality

**Recommended Approach:**
```lua
-- Create addon similar to retail mount journal
-- Store mounts in account_data table
-- Hook into spell learning for account-wide unlock
```

**New Mount Sources:**
- T11/T12/T13 raid mounts (15 mounts)
- World boss rare drops (10 mounts)
- Achievement mounts (20 mounts)
- Reputation mounts (20 mounts)
- Token vendor mounts (30 mounts)
- Profession-crafted mounts (10 mounts)
- Prestige mounts (10 mounts)

---

#### 28. Custom Dungeon: Crystal Depths
**Effort: 8/10** ⏱️ ~1 month  
**Module Status:** ❌ No Module

**What You Need to Build:**
**Server:**
- 5 boss scripts (mechanics, abilities, AI)
- Trash mob scripts
- Loot tables (T13 equivalent)
- Heroic difficulty scaling
- Achievement integration

**Client:**
- Map.dbc entry (instance map ID)
- DungeonMap.dbc (entrance location)
- ADT files (can reuse Nexus or similar)
- Loading screen
- Minimap texture

**Complexity Factors:**
- Boss mechanic scripting (+4 effort)
- Instance map creation (+2 effort if reusing, +5 if new)
- Loot balance (+1 effort)
- Testing and tuning (+1 effort)

---

#### 29. Weather/Day-Night Cycle Enhancements
**Effort: 4/10** ⏱️ ~1 week  
**Module Status:** 🔧 Framework Exists (Core)

**Core Support:**
- Weather system already in AzerothCore
- Day/night cycle functional

**What You Need to Build:**
**Server:**
- Weather effect hooks (buff/debuff application)
- Night-time mob scaling
- Weather-based spawn events

**Client:**
- Addon for enhanced visuals (optional)

**Implementation:**
```cpp
// Hook into WeatherUpdate event
// Apply zone-wide auras based on weather
// Modify creature_template stats for night spawns
```

---

### 🟡 Medium Priority - Quality of Life

#### 30-36. Various QoL Features
**Effort: 3-5/10 each** ⏱️ ~1 week each

**Available Modules:**
- **[mod-pocket-portal](https://github.com/azerothcore/mod-pocket-portal)** - Appearance tab inspiration
- **[mod-mailbox-anywhere](https://github.com/azerothcore/mod-mailbox-anywhere)** - Mail enhancements
- **[mod-lfg-solo](https://github.com/azerothcore/mod-lfg-solo)** - LFG improvements
- **[mod-stoabrogga](https://github.com/azerothcore/mod-stoabrogga)** - Void storage

Most of these are **addon-based** implementations with minimal server support.

---

## Client-Side Only Features

### 🟢 High Priority - Addon Enhancements

#### 37. Complete UI Overhaul Suite
**Effort: 7/10** ⏱️ ~3 weeks  
**Module Status:** ✅ Existing Addons (Adapt)

**Available Base Addons:**
- **ElvUI** (for WotLK) - Complete UI replacement
  - Can be customized and rebranded
  - Already feature-complete
  
**What You Need to Do:**
- Fork ElvUI for WotLK
- Rebrand to "DarkChaos UI"
- Add server-specific features
- Pre-configure for optimal settings
- Package with client

**Effort Reduction:**
- Using ElvUI base: 3/10 effort (just customization)
- Building from scratch: 10/10 effort

**Recommendation:** Use ElvUI as base

---

#### 38. DPS/Healing Meter Integration
**Effort: 3/10** ⏱️ ~1 week  
**Module Status:** ✅ Existing Addons

**Available Addons:**
- **Skada** - Lightweight damage meter
- **Recount** - Full-featured meter
- **Details!** (if ported to 3.3.5a)

**What You Need to Do:**
- Choose base meter (Skada recommended)
- Add server leaderboard integration (if server supports)
- Pre-configure and package

---

#### 39. Enhanced Quest Helper
**Effort: 2/10** ⏱️ ~3 days  
**Module Status:** ✅ Existing Addon

**Available Addons:**
- **Questie** - Quest tracking and waypoints for WotLK
  - Already feature-complete
  - Open source

**What You Need to Do:**
- Add custom quest database for DC quests
- Configure for server zones
- Package with client

---

#### 40. Server Information Panel
**Effort: 4/10** ⏱️ ~1 week  
**Module Status:** 🔧 Framework Exists

**What You Need to Build:**
- Addon UI frame
- Server API for stats (population, events)
- News/announcement feed
- World boss timer integration
- BG queue status

**Recommended Approach:**
```lua
-- Create addon with:
- Minimap button
- Info panel frame
- Server data API calls (addon message events)
```

---

#### 41. Profession Helper
**Effort: 5/10** ⏱️ ~1.5 weeks  
**Module Status:** ✅ Existing Addons

**Available Addons:**
- **Ackis Recipe List** - Recipe tracking
- **TradeSkillMaster** (TSM) - Profession suite

**What You Need to Do:**
- Add custom recipe database
- Configure for server professions
- Pre-package

---

#### 42. Raid/Dungeon Assist Tool
**Effort: 6/10** ⏱️ ~2 weeks  
**Module Status:** ✅ Existing Addons

**Available Addons:**
- **Deadly Boss Mods (DBM)** for WotLK
- **BigWigs** for WotLK

**What You Need to Do:**
- Add custom boss modules for:
  - Custom dungeons
  - Scaled raids
  - World bosses
  - Hinterlands BG events

**Recommended Approach:**
```lua
-- Create DBM module for custom content
-- Follow DBM API for timer bars and warnings
```

---

#### 43-50. Additional Client Features
**Effort: 2-5/10 each** ⏱️ ~1 week each

Most are **existing addons** that need minor customization:
- **Auto-Vendor:** Scrap addon
- **Equipment Manager:** Outfitter addon
- **Auction House:** Auctionator addon
- **Pet Journal:** Custom addon (moderate effort)
- **Reputation Tracker:** _NPCScan addon concept
- **Name Plates:** TidyPlates addon
- **Tooltip Enhancements:** TipTac addon
- **Screenshot Tool:** Custom addon (low effort)

---

## Module Installation Summary

### ✅ Already Integrated Modules
1. **mod-transmog** - Transmogrification
2. **mod-cfbg** - Cross-Faction BG
3. **mod-arac** - All Races All Classes
4. **mod-zone-difficulty** - Zone scaling
5. **mod-mythic-plus** - Keystone dungeons
6. **mod-challenge-modes** - Challenge mode dungeons
7. **mod-eluna** - Lua scripting

### 🟢 Recommended Module Additions

**High Priority:**
```bash
# Auto-balance for scaling content
git clone https://github.com/azerothcore/mod-autobalance modules/mod-autobalance

# Currency system for tokens
git clone https://github.com/FrostedDev/mod-currency modules/mod-currency

# Weekend/event bonuses
git clone https://github.com/azerothcore/mod-weekendbonus modules/mod-weekendbonus

# 1v1 Arena (base for tournaments)
git clone https://github.com/azerothcore/mod-1v1-arena modules/mod-1v1-arena

# Individual progression (base for prestige)
git clone https://github.com/ZhengPeiRu21/mod-individual-progression modules/mod-individual-progression
```

**Medium Priority:**
```bash
# Recruit-a-friend (base for mentor system)
git clone https://github.com/azerothcore/mod-recruitafriend modules/mod-recruitafriend

# Group loot enhancements
git clone https://github.com/azerothcore/mod-group-loot modules/mod-group-loot

# Leaderboards
git clone https://github.com/azerothcore/mod-leaderboards modules/mod-leaderboards

# Guild progression
git clone https://github.com/Winfidonarleyan/mod-guild-progression modules/mod-guild-progression
```

---

## Effort vs Impact Matrix

### 🎯 Best ROI (Low Effort, High Impact)

| Feature | Effort | Impact | Module Status | Time |
|---------|--------|--------|---------------|------|
| Auto-Balance (Scaling) | 2/10 | Very High | ✅ Exists | 2 days |
| Dynamic Events | 4/10 | High | 🔧 Framework | 1 week |
| Enhanced Quest Helper | 2/10 | High | ✅ Exists | 3 days |
| DPS Meters | 3/10 | Medium-High | ✅ Exists | 1 week |
| CFBG Extensions | 2/10 | High | ✅ Exists | 2 days |
| Flying in Custom Zones | 3/10 | High | 🔧 Core | 1 week |
| Token System | 5/10 | Very High | 🟡 Partial | 1.5 weeks |
| Server Info Panel | 4/10 | Medium | 🔧 Framework | 1 week |

**Total Time for Top 8 ROI Features: ~6 weeks**

---

### ⚡ Quick Wins (1 week or less)

1. **Auto-Balance** (2 days) - Module ready
2. **CFBG Extensions** (2 days) - Module ready
3. **Enhanced Quest Helper** (3 days) - Addon ready
4. **Flying Enablement** (1 week) - Simple DBC edit
5. **DPS Meters** (1 week) - Addon ready
6. **Dynamic Events** (1 week) - Extend weekend bonus
7. **Server Info Panel** (1 week) - New addon

---

### 🚀 Maximum Impact Features (Worth the effort)

| Feature | Effort | Impact | Time | Priority |
|---------|--------|--------|------|----------|
| Prestige System | 6/10 | Very High | 2 weeks | #1 |
| Token System | 5/10 | Very High | 1.5 weeks | #2 |
| New Zones (reusing ADTs) | 6/10 | Very High | 1 month/zone | #3 |
| Scalable Raids | 7/10 | Very High | 3 weeks | #4 |
| UI Suite (ElvUI base) | 3/10 | High | 1 week | #5 |
| World Boss System | 5/10 | High | 1.5 weeks | #6 |

---

### ❌ Features to Avoid (Low ROI)

| Feature | Effort | Impact | Reason to Skip |
|---------|--------|--------|----------------|
| Pet Battle System | 10/10 | Low | Too complex, low demand |
| Custom Class Specs (all 10) | 10/10 | High | Start with 2-3 classes instead |
| Archaeology | 8/10 | Low | Low player engagement |
| Player Housing Full | 9/10 | Medium | Better to do housing lite |
| Garrison System | 9/10 | Medium | Too WoD-specific |

---

## Recommended Implementation Order

### Month 1: Foundation & Quick Wins
**Total Effort: ~20 points**
1. Install mod-autobalance (Effort: 2) ⏱️ 2 days
2. Install mod-currency (Effort: 2) ⏱️ 2 days
3. Setup Dynamic Events (Effort: 4) ⏱️ 1 week
4. Package Enhanced Quest Helper (Effort: 2) ⏱️ 3 days
5. Enable Flying in Custom Zones (Effort: 3) ⏱️ 1 week
6. Setup DPS Meters (Effort: 3) ⏱️ 1 week
7. Create Server Info Panel (Effort: 4) ⏱️ 1 week

### Month 2: Core Systems
**Total Effort: ~25 points**
1. Build Prestige System (Effort: 6) ⏱️ 2 weeks
2. Expand Token System (Effort: 5) ⏱️ 1.5 weeks
3. Build World Boss System (Effort: 5) ⏱️ 1.5 weeks
4. Setup UI Suite (ElvUI base) (Effort: 3) ⏱️ 1 week
5. Create Achievement Expansion (Effort: 6) ⏱️ 2 weeks

### Month 3: Content & Features
**Total Effort: ~30 points**
1. Build Scalable Raid System (Effort: 7) ⏱️ 3 weeks
2. Create First New Zone (reusing ADTs) (Effort: 6) ⏱️ 3-4 weeks
3. Reputation System Overhaul (Effort: 6) ⏱️ 2 weeks
4. Smart Loot System (Effort: 7) ⏱️ 3 weeks
5. Boss Mods for Custom Content (Effort: 6) ⏱️ 2 weeks

### Month 4-6: Major Content
**Total Effort: ~40 points**
1. Create 2-3 Additional Zones (Effort: 6 each) ⏱️ 3 months
2. Custom Dungeon: Crystal Depths (Effort: 8) ⏱️ 1 month
3. Professions to 600+ (Effort: 8) ⏱️ 1 month
4. Guild Advancement System (Effort: 7) ⏱️ 3 weeks
5. Transmog Enhancement (Effort: 5) ⏱️ 1.5 weeks

### Month 7-12: Advanced Features (Optional)
**Only pursue if earlier phases successful**
1. Custom Races (2 races) (Effort: 9) ⏱️ 2 months
2. Custom Class Specs (2-3 classes) (Effort: 7 each) ⏱️ 2-3 months
3. Custom BG: Battle for Gilneas (Effort: 8) ⏱️ 1 month
4. Tournament System (Effort: 8) ⏱️ 1 month

---

## Budget Estimation (If Hiring Developers)

### Developer Rates (Estimated)
- **Junior C++ Developer:** $20-40/hour
- **Senior C++ Developer:** $50-100/hour
- **Lua Scripter:** $15-30/hour
- **DBC/Client Editor:** $25-50/hour
- **3D Modeler/Level Designer:** $30-60/hour
- **Addon Developer:** $20-40/hour

### Cost Estimates for Top Features

**Prestige System** (2 weeks, senior dev)
- Cost: $4,000 - $8,000

**Token System** (1.5 weeks, junior dev)
- Cost: $1,200 - $2,400

**New Zone** (1 month, team of 3)
- Senior dev (quest scripts): $8,000-$16,000
- Level designer (ADT work): $4,800-$9,600
- Lua scripter (NPC scripts): $2,400-$4,800
- **Total per zone:** $15,200 - $30,400

**Scalable Raid System** (3 weeks, senior dev)
- Cost: $6,000 - $12,000

**Custom Race** (2 months, team of 2)
- Senior dev (server-side): $16,000-$32,000
- DBC editor (client-side): $8,000-$16,000
- **Total per race:** $24,000 - $48,000

---

## DIY vs Module vs Hire Decision Matrix

### When to Use Existing Modules
- Feature exists with 80%+ functionality match
- Active community support
- Compatible with current codebase
- **Examples:** mod-autobalance, mod-transmog, mod-cfbg

### When to Build Custom
- No suitable module exists
- Module exists but too outdated/broken
- Unique server-specific requirements
- **Examples:** Prestige system, Token economy, Custom zones

### When to Hire/Commission
- Feature is critical but too complex
- Your team lacks specific expertise (DBC editing, 3D modeling)
- Time-sensitive implementation
- **Examples:** Custom races, New zones with terrain, Custom class specs

---

## Final Recommendations

### Top 5 Features to Implement First

**1. mod-autobalance** (2 days)
- Already exists, just install
- Immediate value for all dungeons/raids
- **ROI: 10/10**

**2. Prestige System** (2 weeks)
- Solves endgame retention
- Unique to your server
- **ROI: 9/10**

**3. Advanced Token System** (1.5 weeks)
- Use mod-currency as base
- Creates entire economy loop
- **ROI: 9/10**

**4. Dynamic World Events** (1 week)
- Use mod-weekendbonus as base
- Easy to implement, high engagement
- **ROI: 8/10**

**5. New Zone (Reusing ADTs)** (1 month)
- Fills 170-185 content gap
- Custom content differentiator
- **ROI: 8/10**

### Features to Skip

1. **Pet Battle System** - 10/10 effort, low demand
2. **Full Player Housing** - 9/10 effort, better alternatives
3. **Archaeology** - 8/10 effort, niche appeal
4. **All 10 Class Specs at Once** - Focus on 2-3 first

---

**Total Development Time Estimate:**
- **Essential Features (Months 1-3):** 3 months
- **Major Content (Months 4-6):** 3 months
- **Advanced Features (Months 7-12):** 6 months (optional)

**Minimum Viable Product:** 3 months with focus on top 15 features

---

*This analysis includes all 50 proposed features with effort ratings, module availability, and implementation recommendations.*
