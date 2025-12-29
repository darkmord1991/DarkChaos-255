# WOTLK+ Feature Concepts & Implementation Details

**Document:** Feature Specifications for Dark Chaos 255  
**Created:** December 27, 2025  
**Purpose:** Detailed implementation guidance for top WOTLK+ features

---

## Table of Contents

1. [Tier S Features: New Races & Classes](#tier-s-features-new-races--classes)
2. [Tier S Features: New Zones & Content](#tier-s-features-new-zones--content)
3. [Tier A Features: Systems & QoL](#tier-a-features-systems--qol)
4. [Tier B Features: Expansion Systems](#tier-b-features-expansion-systems)
5. [Community Requests: Most Discussed Topics](#community-requests-most-discussed-topics)
6. [Client Patching Guide](#client-patching-guide)

---

## Tier S Features: New Races & Classes

### New Race Option 1: Vrykul (Neutral → Faction Choice)

**Concept:** Vrykul as a hero race that can join either faction at level 10.

| Attribute | Details |
|-----------|---------|
| **Starting Zone** | Howling Fjord (repurposed area) |
| **Starting Level** | 1 (or hero start at 55 like DK) |
| **Classes** | Warrior, Hunter, Shaman, Death Knight |
| **Racial Traits** | Giant's Strength (+15 Str), Viking Endurance (+5% HP), Battle Cry (AOE damage), Frost Resistance (+10) |
| **Faction Choice** | Level 10 quest to join Alliance or Horde |

**Client Requirements:**
- ChrRaces.dbc entry
- CharacterFacialHairStyles.dbc (hair/beard options)
- CreatureDisplayInfo.dbc (character model references)
- M2/skin files for character customization
- Starting zone quests and NPCs
- WorldMapArea.dbc for starting zone

**Server Requirements:**
- Race scripts for faction selection
- Starting quest chains
- Racial ability spells
- Level scaling for starting area

**Effort Estimate:** 3-4 months (major undertaking)

---

### New Race Option 2: High Elves (Alliance)

**Concept:** Like Turtle WoW, add High Elves as playable Alliance race.

| Attribute | Details |
|-----------|---------|
| **Starting Zone** | Quel'Thalas (modified) or new zone |
| **Classes** | Warrior, Hunter, Rogue, Priest, Mage, Paladin |
| **Racial Traits** | Arcane Affinity (+10 Arcane Resist), Bow Specialization (+5), Meditation (resource regen) |
| **Visual** | Night Elf model with blue/gold tint, alternate ears |

**Why This Works:**
- Highly requested by community
- Blood Elf model exists in 3.3.5a (easier to adapt)
- Fits Warcraft lore (Allerian Stronghold, Quel'Lithien Lodge)

---

### New Race Option 3: Ogres (Horde)

**Concept:** Ogres join the Horde as a playable race.

| Attribute | Details |
|-----------|---------|
| **Starting Zone** | Dustwallow Marsh or Dire Maul area |
| **Classes** | Warrior, Mage, Shaman, Warlock |
| **Racial Traits** | Two-Headed (optional second head model), Thick Skin (+Armor), Brute Force (+AP), Slow and Steady (-5% movement, +10% HP) |

**Technical Notes:**
- Ogre models exist in game
- Challenge: Armor fitting on ogre body type
- May require custom armor models

---

### New Class Concept: Runemaster

**Concept:** A hybrid class using runes for combat, similar to Season of Discovery's rune system.

| Attribute | Details |
|-----------|---------|
| **Armor** | Leather or Mail |
| **Roles** | DPS, Tank, Support |
| **Resource** | Rune Power (like runic power but faster) |
| **Specializations** | Battle Runes (melee), Inscription (caster), Wardkeeper (tank) |
| **Starting Level** | 1 (any race) or Hero Class at 55 |

**Why NOT Recommended:**
- Extreme balance implications
- All gear needs new stat weights
- Talents from scratch
- May alienate existing players

**Alternative:** Add "Runemaster" as a prestige path or specialization system rather than full class.

---

## Tier S Features: New Zones & Content

### Zone Concept 1: Frost Wastes (Level 170-195)

**Location:** Northern Storm Peaks (unused terrain)

| Subzone | Level | Theme | Key NPCs |
|---------|-------|-------|----------|
| Frozen Harbor | 170-175 | Expedition camp, starting hub | Explorers League, Goblins |
| Frostbite Valley | 175-180 | Frost giant territory | Frost Giant faction (hostile → neutral) |
| Crystal Caverns | 180-185 | Crystalline formations | Titan watchers |
| Ancient Titan Dig | 185-190 | Archaeology theme | Bronze dragonflight |
| Summit of Storms | 190-195 | Storm magic, final area | Storm lords |

**Key Features:**
- Frost Giant faction with reputation
- Storm magic mechanic (weather affects combat)
- Vehicle content (war machines)
- 2 world bosses
- 1 dungeon: Crystal Depths

**Quest Storyline:**
Players investigate ancient titan technology frozen in glaciers. Frost giants serve a corrupted keeper, and players must either defeat or redeem them.

---

### Zone Concept 2: Arcane Reaches (Level 220-240)

**Location:** Deep Crystalsong Forest / Under Dalaran

| Subzone | Level | Theme | Key NPCs |
|---------|-------|-------|----------|
| Verdant Approach | 220-225 | Forest entrance | Kirin Tor researchers |
| Arcane Scar | 225-230 | Corrupted magic zone | Corrupted mages |
| Crystal Gardens | 230-235 | Beautiful but deadly | Crystalline creatures |
| The Nexus Wound | 235-240 | Portal instability | Blue dragonflight |

**Key Features:**
- Arcane corruption debuff mechanic
- Portal puzzles (phased content)
- Dalaran faction quests
- 2 world bosses
- 1 dungeon: Titan Workshop

**Quest Storyline:**
The destruction of the Nexus has left a wound in reality. Players explore with Kirin Tor to seal portals and prevent an invasion from the Twisting Nether.

---

### Zone Concept 3: The Sundered Isles (Level 195-220)

**Location:** New islands between Eastern Kingdoms and Kalimdor

| Island | Level | Theme |
|--------|-------|-------|
| Plunder Isle | 195-200 | Pirate haven |
| Kezan Refuge | 200-210 | Goblin tech |
| Naga Depths | 210-220 | Underwater content |

**Why This Zone:**
- Pirates are popular theme
- Goblins content appeals to many
- Underwater combat is underused
- Can reuse existing Cataclysm-era designs

---

### Dungeon Concept: The Forgotten Depths (Level 200)

**Location:** Under Crystalsong Forest

| Boss | Mechanics | Loot Theme |
|------|-----------|------------|
| **Arcane Guardian** | Arcane bombs, mirror images | Tank weapons |
| **Corrupted Researcher** | Mind control, spell reflection | Caster gear |
| **Crystal Colossus** | Ground pound, shatter phase | Melee DPS |
| **Keeper Malachar** | Multi-phase, titan technology | Best loot |

**Mythic+ Potential:**
- Arcane explosion affix
- Crystal shard spawns
- Timer: 28 minutes

---

### Raid Concept: Citadel of Storms (T14, Level 200)

**Location:** Summit of Storms (Frost Wastes)

| Boss | Difficulty | Mechanics Preview |
|------|------------|-------------------|
| **Stormwarden** | Easy | Lightning chains, ground AoE |
| **Twin Tempests** | Medium | Council fight, wind phases |
| **Keeper Thorim (Corrupted)** | Medium | Arena gauntlet, hammer strikes |
| **The Thunder King** | Hard | Multi-phase, adds, enrage |
| **Ul'thor, Voice of the Storm** | Final | All elements, soft enrage |

**Size:** 10/25-man  
**Loot:** T14 set pieces, weapons, trinkets

---

## Tier A Features: Systems & QoL

### World Boss Implementation Details

**Spawn System:**

```lua
-- Eluna example: World Boss Scheduler
local BOSS_GORTHAK = 300001  -- Creature entry

local function ScheduleWorldBoss()
    -- Spawn every 8 hours with 2 hour variance
    local nextSpawn = os.time() + (8 * 3600) + math.random(-7200, 7200)
    
    CreateLuaEvent(function()
        SpawnWorldBoss(BOSS_GORTHAK, 571, 6000, 4000, 400)  -- Icecrown
        WorldAnnounce("WORLD BOSS: Gorthak the Destroyer has emerged in Icecrown!")
    end, (nextSpawn - os.time()) * 1000, 1)
end
```

**Loot Distribution:**
- Personal loot based on contribution
- Minimum 2% contribution for loot eligibility
- Boss drops 3-5 items per kill
- Mounts: 0.1% drop chance
- Seasonal cosmetics during events

**Recommended Bosses:**

| Boss | Location | Theme | Unique Mechanic |
|------|----------|-------|-----------------|
| Gorthak | Icecrown | Death | Raise fallen players as adds |
| Pyrrhus | Searing Gorge | Fire | Growing fire zones |
| The Forgotten | Silithus | Void | Mind control, tentacles |
| Hakkar Reborn | STV | Troll | Blood siphon |
| Netherwing Prime | Netherstorm | Dragon | Flight phases |

---

### Guild Housing Detailed Implementation

**Base Map Options:**
1. **Karazhan Lower Levels** - Already instanced, atmospheric
2. **Stratholme (Cleared)** - Large, modifiable
3. **Custom Instance** - Purpose-built (requires client patch)

**Upgrade Tree:**

```
Guild Hall Level 1 (Base)
├── Trophy Room (Displays guild achievements)
├── Vault (Extra bank tabs)
├── Armory (View top gear)
└── Portal Room
    ├── Major Cities Portals
    └── Raid Entrance Portals

Guild Hall Level 2 (Cost: 10,000g + 500 tokens)
├── Training Dummies (DPS meters)
├── Arena Ring (Guild duels)
├── Profession Stations
└── War Room (Calendar, planning)

Guild Hall Level 3 (Cost: 50,000g + 2000 tokens)
├── Pet/Mount Display
├── Garden/Stable
├── Seasonal Decorations
└── Guild Vendor (Exclusive items)

Guild Hall Level 4 (Cost: 100,000g + 5000 tokens)
├── Teleporter to Guild Hall (item)
├── Guild Summon (mass teleport)
├── Reputation Boost (+10%)
└── XP Boost (+5%)
```

---

### Profession Overhaul Specifics

**New Endgame Recipes (Per Profession):**

**Blacksmithing:**
| Recipe | Materials | Result |
|--------|-----------|--------|
| Titansteel Destroyer | 10 Titansteel, 5 Runed Orb | 2H Sword, ilvl 245 |
| Eternal Breastplate | 8 Titansteel, 4 Frozen Orb | Plate Chest, ilvl 240 |
| Socket Punch | 2 Titanium Bar, 1 Eternal Earth | Add socket to item |

**Alchemy:**
| Recipe | Materials | Result |
|--------|-----------|--------|
| Flask of Endless Power | 5 Frost Lotus, 3 Lichbloom | +500 spellpower 4hr |
| Potion of Epic Proportions | 3 Icethorn, 2 Pygmy Oil | +3000 HP instant |
| Transmute: Titan Essence | 10 Saronite, 1 Titanium | Craft material |

**Engineering:**
| Recipe | Materials | Result |
|--------|-----------|--------|
| Permanent Nitro Boosts | 10 Titansteel, Goblin Tech | No fail belt tinker |
| Portable Mailbox | 5 Titansteel, 10 Frostweave | Reusable mail access |
| Repair Bot 5000 | 20 Saronite, 5 Eternal Fire | Better repair bot |

---

### Timewalking Implementation

**Scaling Formula:**

```cpp
// Player stats scaled to target level
float GetTimewalkingScale(Player* player, uint32 targetLevel) {
    uint32 playerLevel = player->GetLevel();
    if (playerLevel <= targetLevel) return 1.0f;
    
    // Base scaling: linear reduction
    float baseScale = (float)targetLevel / (float)playerLevel;
    
    // Gear normalization
    float gearScale = 1.0f;
    uint32 avgIlvl = player->GetAverageItemLevel();
    if (avgIlvl > targetLevel * 2) {
        gearScale = (float)(targetLevel * 2) / (float)avgIlvl;
    }
    
    return baseScale * gearScale * 0.9f; // 90% efficiency
}
```

**Dungeon Pool:**

| Expansion | Dungeons | Target Level |
|-----------|----------|--------------|
| Classic | RFC, DM, WC, SFK, SM, Ulda, BRD, Scholo, Strat | 60 |
| TBC | Ramps, BF, SP, MT, AC, SH, SL, MgT | 70 |
| WotLK | UK, Nexus, AN, DTK, VH, GD, HoS, HoL, CoS, Occ, UP, ToC, PoS, HoR, FoS | 80 |

**Reward Currency:**
- Timewalking Badges (separate from existing tokens)
- Vendor with mounts, pets, transmog
- Badge-to-Token conversion at poor rate

---

## Tier B Features: Expansion Systems

### Endless Dungeon / Roguelike System

**Core Concept:** Procedurally generated dungeon floors with temporary power-ups.

**Floor Structure:**
```
Floor 1-5:   Easy (Normal difficulty)
Floor 6-10:  Medium (Heroic difficulty)
Floor 11-15: Hard (Mythic 0)
Floor 16-20: Extreme (Mythic 5+)
Floor 21+:   Infinite scaling
```

**Rune System (Temporary Powers):**

| Rune | Type | Effect |
|------|------|--------|
| Rune of Vampirism | Common | 2% lifesteal |
| Rune of Swiftness | Common | +10% movement |
| Rune of Power | Uncommon | +5% damage |
| Rune of Giants | Rare | +20% HP, +10% size |
| Rune of Annihilation | Epic | +25% damage, -10% HP |
| Rune of the Titan | Legendary | +15% all stats |

**Checkpoint System:**
- Every 5 floors = checkpoint
- Can restart from last checkpoint
- Lose runes on death (keep at checkpoint)

**Rewards:**
- Essence currency (scales with floor)
- Unique transmog per floor milestone
- Leaderboard ranking
- Seasonal rewards

---

### Mentor System

**Concept:** Experienced players mentor new players for mutual benefit.

**How It Works:**
1. Mentor registers (Level 255, 30+ days played)
2. Apprentice requests mentor (Level 1-100)
3. Pairing gives bonuses to both

**Bonuses:**

| Benefit | Mentor | Apprentice |
|---------|--------|------------|
| XP | +10% when grouped | +20% always |
| Rep | +5% when grouped | +10% always |
| Tokens | 5 per apprentice level | Normal |
| Title | "The Mentor" | "Apprentice of X" |
| Mount | After 5 graduates | After reaching 255 |

---

## Community Requests: Most Discussed Topics

### From Reddit /r/wowservers Analysis

**Top 10 Requested Features (2024-2025):**

1. **New Races** - Every thread mentions this
2. **Guild Housing** - Second most requested
3. **Cross-Faction Everything** - Guilds, mail, AH
4. **Transmog Wardrobe** - Account-wide saves
5. **Pet Collection System** - Like retail
6. **Mount Collection** - Account-wide
7. **Dual Spec Improvements** - Free, instant
8. **Barbershop Expansion** - More options
9. **Mythic+** - You have this!
10. **Player Housing** - After guild housing

### From Private Server Forums

**Most Appreciated Features:**
- AoE loot (you have)
- Transmog (you have)
- RDF improvements
- Cross-faction BG (you have)
- Instant mail
- Reduced hearthstone CD
- Flying in all zones

**Most Controversial:**
- Pay-to-win shops
- Increased rates (some want 1x, some want 10x)
- Class balance changes
- Custom classes
- Level boosts

---

## Client Patching Guide

### File Types Needed

| File Type | Purpose | Location |
|-----------|---------|----------|
| `.dbc` | Database files (items, spells, etc.) | DBFilesClient\ |
| `.adt` | Map terrain tiles | World\Maps\ |
| `.wmo` | World model objects (buildings) | World\WMO\ |
| `.m2` | Character/creature models | Character\, Creature\ |
| `.blp` | Textures | Interface\, Textures\ |
| `.lua` / `.xml` | UI code | Interface\FrameXML\ |

### DBC Files Commonly Modified

| DBC File | Purpose |
|----------|---------|
| ChrRaces.dbc | New races |
| Spell.dbc | New spells/abilities |
| ItemDisplayInfo.dbc | New item visuals |
| CreatureDisplayInfo.dbc | New creature models |
| AreaTable.dbc | New zones |
| WorldMapArea.dbc | Map UI for zones |
| CharacterFacialHairStyles.dbc | Character customization |
| LoadingScreens.dbc | Zone loading screens |

### Distribution Methods

**Option 1: Custom Launcher**
- Downloads patches automatically
- Verifies file integrity
- Easy updates
- Requires development

**Option 2: MPQ Patch**
- Single file distribution
- Place in Data folder
- Manual process
- Name: `patch-X.MPQ` (X > 9)

**Option 3: Loose Files**
- Individual files in Data folder
- No compression
- Easy to modify
- Larger download

### Recommended: Hybrid Approach

```
1. Launcher checks for updates
2. Downloads patch-Z.MPQ (custom content)
3. Launcher manages Interface addons (AIO)
4. Server handles most logic
```

---

## Summary: Priority Implementation Order

### Month 1-2
1. ✅ World Boss System
2. ✅ Weekend Events
3. ✅ Daily Login Rewards
4. ✅ Achievement Shop

### Month 3-4
5. ✅ Guild Housing (basic)
6. ✅ Talent Loadouts
7. ✅ Mentor System

### Month 5-6
8. ✅ Profession Overhaul
9. ✅ Timewalking (Classic pool)

### Month 7-9
10. ⚠️ Custom Zone: Frost Wastes (client patch)
11. ⚠️ New Dungeon

### Month 10-12
12. ⚠️ Custom Zone: Arcane Reaches
13. ⚠️ First Custom Raid

### Year 2+
14. ❌ New Race (if population justifies)
15. ❌ Player Housing
16. ❌ Additional raids/zones

---

*This document provides detailed specifications for implementing WOTLK+ features on Dark Chaos 255. Features marked ✅ are server-side only, ⚠️ require client patches, and ❌ are high-complexity long-term goals.*
