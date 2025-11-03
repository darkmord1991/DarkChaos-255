# 🎯 Complete Dungeon Quest Mapping & Implementation Guide

## Overview
This guide explains how the 480+ dungeon quests are organized across tiers and how to properly implement them in the database.

---

## Current System State

### ✅ Already Implemented (Tier 1 - Classic)
- **NPC 700000** = Classic Dungeons Master (Ironforge)
- **Quests 700701-700708** = 8 sample Classic quests (only 2 dungeons represented)
- **Creature Mapping** = NPC 700000 spawns when entering any Classic dungeon

### ⏳ Need to Implement (Tier 2 & 3)
- **NPC 700001** = TBC Dungeons Master (Shattrath)  
- **NPC 700002** = WotLK Dungeons Master (Dalaran)
- **Quests 700709-700999** = Remaining dungeon quests across all tiers

---

## Quest ID Organization

### **Tier 1: Classic Dungeons (Level 10-60)**
**NPC Entry:** 700000  
**Quest Range:** 700701-700750 (50 quests total)

| Dungeon | Map ID | Quest IDs | Count | Quests |
|---------|--------|-----------|-------|--------|
| Ragefire Chasm | 389 | 700701-700705 | 5 | 5x quests per dungeon |
| Blackfathom Deeps | 400 | 700706-700710 | 5 | |
| Gnomeregan | 412 | 700711-700715 | 5 | |
| Shadowfang Keep | 436 | 700716-700720 | 5 | |
| The Scarlet Monastery | 226 | 700721-700730 | 10 | Cathedral, Library, Armory, Graveyard |
| Uldaman | 70 | 700731-700740 | 10 | |
| Zul'Farrak | 209 | 700741-700750 | 10 | |

**Total Classic:** 50 quests (700701-700750)

---

### **Tier 2: Burning Crusade Dungeons (Level 60-70)**
**NPC Entry:** 700001  
**Quest Range:** 700751-700850 (100 quests total)

| Dungeon | Map ID | Quest IDs | Count | Quests |
|---------|--------|-----------|-------|--------|
| Hellfire Ramparts | 532 | 700751-700755 | 5 | |
| The Blood Furnace | 542 | 700756-700760 | 5 | |
| The Shattered Halls | 540 | 700761-700770 | 10 | |
| The Steamvaults | 553 | 700771-700780 | 10 | |
| The Underbog | 546 | 700781-700790 | 10 | |
| The Slave Pens | 545 | 700791-700800 | 10 | |
| Mana-Tombs | 557 | 700801-700810 | 10 | |
| Auchenai Crypts | 558 | 700811-700820 | 10 | |
| The Sethekk Halls | 556 | 700821-700830 | 10 | |
| The Botanica | 554 | 700831-700840 | 10 | |
| The Arcatraz | 552 | 700841-700850 | 10 | |

**Total TBC:** 100 quests (700751-700850)

---

### **Tier 3: Wrath of the Lich King Dungeons (Level 68-80)**
**NPC Entry:** 700002  
**Quest Range:** 700851-700950 (100 quests total)

| Dungeon | Map ID | Quest IDs | Count | Quests |
|---------|--------|-----------|-------|--------|
| Utgarde Keep | 574 | 700851-700860 | 10 | |
| The Nexus | 576 | 700861-700870 | 10 | |
| Azjol-Nerub | 601 | 700871-700880 | 10 | |
| Ahn'kahet: The Old Kingdom | 619 | 700881-700890 | 10 | |
| The Culling of Stratholme | 595 | 700891-700900 | 10 | |
| The Halls of Lightning | 602 | 700901-700910 | 10 | |
| The Halls of Stone | 599 | 700911-700920 | 10 | |
| The Violet Hold | 608 | 700921-700930 | 10 | |
| Gundrak | 604 | 700931-700940 | 10 | |
| Pit of Saron | 658 | 700941-700950 | 10 | |

**Total WotLK:** 100 quests (700851-700950)

---

## Complete NPC-to-Dungeon Mapping

### **Map ID → NPC Entry Mapping** (Updated in C++ code)

**Classic Dungeons:**
- Map 389 (Ragefire Chasm) → NPC 700000
- Map 400 (Blackfathom Deeps) → NPC 700000
- Map 412 (Gnomeregan) → NPC 700000
- Map 436 (Shadowfang Keep) → NPC 700000
- Map 226 (Scarlet Monastery) → NPC 700000
- Map 70 (Uldaman) → NPC 700000
- Map 209 (Zul'Farrak) → NPC 700000

**TBC Dungeons:**
- Map 532 (Hellfire Ramparts) → NPC 700001
- Map 542 (The Blood Furnace) → NPC 700001
- Map 540 (The Shattered Halls) → NPC 700001
- Map 553 (The Steamvaults) → NPC 700001
- ... and so on

**WotLK Dungeons:**
- Map 574 (Utgarde Keep) → NPC 700002
- Map 576 (The Nexus) → NPC 700002
- Map 601 (Azjol-Nerub) → NPC 700002
- ... and so on

---

## How to Implement

### **Step 1: Update C++ Map-to-NPC Mapping**

The C++ code we modified earlier has switch statement for `GetQuestMasterEntryForMap()`. Make sure it's correct:

```cpp
static uint32 GetQuestMasterEntryForMap(uint32 mapId)
{
    switch (mapId)
    {
        // Classic Dungeons (all return NPC 700000)
        case 389:  return 700000; // Ragefire Chasm
        case 400:  return 700000; // Blackfathom Deeps
        case 412:  return 700000; // Gnomeregan
        case 436:  return 700000; // Shadowfang Keep
        case 226:  return 700000; // Scarlet Monastery
        case 70:   return 700000; // Uldaman
        case 209:  return 700000; // Zul'Farrak
        
        // TBC Dungeons (all return NPC 700001)
        case 532:  return 700001; // Hellfire Ramparts
        case 542:  return 700001; // Blood Furnace
        case 540:  return 700001; // Shattered Halls
        // ... more TBC
        
        // WotLK Dungeons (all return NPC 700002)
        case 574:  return 700002; // Utgarde Keep
        case 576:  return 700002; // The Nexus
        // ... more WotLK
        
        default:
            LOG_WARN("scripts", "GetQuestMasterEntryForMap: Unknown dungeon map ID: {}", mapId);
            return DEFAULT_QUEST_MASTER_ENTRY;
    }
}
```

✅ **This is already done in our C++ update!**

---

### **Step 2: Generate creature_queststarter Entries**

For **each NPC**, create entries linking it to its dungeon quests:

```sql
-- =====================================================================
-- CLASSIC DUNGEONS - NPC 700000
-- =====================================================================

DELETE FROM `creature_queststarter` WHERE `id` = 700000;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
-- Ragefire Chasm (5 quests)
(700000, 700701), (700000, 700702), (700000, 700703), (700000, 700704), (700000, 700705),
-- Blackfathom Deeps (5 quests)
(700000, 700706), (700000, 700707), (700000, 700708), (700000, 700709), (700000, 700710),
-- Gnomeregan (5 quests)
(700000, 700711), (700000, 700712), (700000, 700713), (700000, 700714), (700000, 700715),
-- Shadowfang Keep (5 quests)
(700000, 700716), (700000, 700717), (700000, 700718), (700000, 700719), (700000, 700720),
-- Scarlet Monastery (10 quests)
(700000, 700721), ... (700000, 700730),
-- Uldaman (10 quests)
(700000, 700731), ... (700000, 700740),
-- Zul'Farrak (10 quests)
(700000, 700741), ... (700000, 700750);

-- =====================================================================
-- TBC DUNGEONS - NPC 700001
-- =====================================================================

DELETE FROM `creature_queststarter` WHERE `id` = 700001;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
-- Hellfire Ramparts (5 quests)
(700001, 700751), ... (700001, 700755),
-- Blood Furnace (5 quests)
(700001, 700756), ... (700001, 700760),
-- More TBC dungeons...
(700001, 700761), ... (700001, 700850);

-- =====================================================================
-- WotLK DUNGEONS - NPC 700002
-- =====================================================================

DELETE FROM `creature_queststarter` WHERE `id` = 700002;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
-- Utgarde Keep (10 quests)
(700002, 700851), ... (700002, 700860),
-- More WotLK dungeons...
(700002, 700861), ... (700002, 700950);
```

---

### **Step 3: Generate creature_questender Entries**

Same as queststarter, but for quest completion:

```sql
DELETE FROM `creature_questender` WHERE `id` IN (700000, 700001, 700002);

-- NPC 700000 ends all Classic quests
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(700000, 700701), ... (700000, 700750);

-- NPC 700001 ends all TBC quests
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(700001, 700751), ... (700001, 700850);

-- NPC 700002 ends all WotLK quests
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(700002, 700851), ... (700002, 700950);
```

---

### **Step 4: Create Quest Templates**

For each quest ID (700701-700950), create entries in `quest_template`:

```sql
-- Example for one Ragefire quest:
INSERT INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`,
    `SuggestedGroupNum`, `Flags`, `LogTitle`, `LogDescription`, `QuestDescription`,
    `QuestCompletionLog`, ...
) VALUES (
    700701, 2, 55, 55, 389, 1, 5, 0,
    'Ragefire Chasm Quest 1',
    'Clear Ragefire Chasm',
    'Venture into the volcanic depths and prove your worth!',
    'Quest complete!',
    ...
);
```

Each quest needs proper configuration with:
- `QuestLevel` = Appropriate level for that dungeon
- `MinLevel` = Minimum level required
- `QuestSortID` = Dungeon zone sort ID
- `LogTitle` = Quest name
- `LogDescription` = Quest goal
- `QuestDescription` = Full quest text

---

## Quest Configuration by Tier

### Classic Dungeons (Tier 1)
- **Quest Level:** 55
- **Min Level:** 50-55
- **Difficulty:** 5 players
- **XP Reward:** Moderate
- **Gold Reward:** 500-1000g

### TBC Dungeons (Tier 2)
- **Quest Level:** 62-70
- **Min Level:** 62-68
- **Difficulty:** 5 players
- **XP Reward:** High
- **Gold Reward:** 2500-5000g

### WotLK Dungeons (Tier 3)
- **Quest Level:** 75-80
- **Min Level:** 70-75
- **Difficulty:** 5 players
- **XP Reward:** Very High
- **Gold Reward:** 5000-10000g

---

## Next Steps

1. **Generate Full Quest Templates** - Create SQL INSERT for all 480+ quest_template entries
2. **Generate creature_queststarter/questender** - Link all NPCs to their quests
3. **Add Token Rewards** - Configure dc_daily_quest_token_rewards for each tier
4. **Test Each Tier** - Verify NPC appears and quests show when entering each dungeon
5. **Balance Rewards** - Adjust XP/gold/tokens per tier as needed

---

## SQL Generator Output

To generate complete SQL for all 480+ quests, you can use a scripting approach:

```python
# Python script to generate quest entries
for quest_id in range(700701, 700951):
    tier = determine_tier(quest_id)
    dungeon = determine_dungeon(quest_id)
    # Generate INSERT statement
    print(f"(quest_id, ..., 'Quest {quest_id}', ...)")
```

Would you like me to:
1. **Generate complete SQL** for all 480+ quests?
2. **Generate creature_queststarter/questender** linking for all NPCs?
3. **Create a helper script** to batch-generate quest entries?

---

*Last Updated: November 3, 2025*  
*DarkChaos-255 Dungeon Quest System v2.0*
