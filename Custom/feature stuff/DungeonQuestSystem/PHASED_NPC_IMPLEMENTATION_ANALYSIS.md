# Dungeon Quest System - Phased NPC Implementation Analysis

## Executive Summary

Implementing phased quest NPCs (NPCs that appear only when a player enters a specific dungeon instance) requires **moderate complexity** changes across multiple systems:

- **Server-side code changes**: ~800 lines (Phase system integration, visibility logic, spawning)
- **Database schema changes**: 2 new tables + modifications to creature table
- **Implementation time**: 2-3 weeks for full integration and testing
- **Performance impact**: Minimal (phasing is native to AzerothCore)

---

## 1. What is Phasing?

### Definition
**Phasing** is a WoW mechanic that shows/hides NPCs, objects, and terrain based on conditions. In this case:
- Quest NPC appears **only** when player enters dungeon instance
- NPC disappears when player leaves dungeon or phase ends
- Different phases can show different versions of same NPC

### Common Uses
- Quest progression NPCs (appear after completing quest step 1)
- Instance-specific bosses (only visible in that instance)
- Environmental changes (destroyed buildings, new NPCs)
- Dungeon quest givers (players see different NPC when they enter)

### Related Concepts
- **Instance mapping**: Dungeon dungeons have their own map ID (35, 36, 231, etc.)
- **Phase masks**: Bitwise value determining visibility
- **Visibility zones**: Area triggers that define where phases apply

---

## 2. Current DungeonQuestSystem Architecture

From the analyzed documentation, the current system uses:
- **53 NPC Quest Masters** (IDs: 700000-700052)
- **Custom ID ranges** to avoid conflicts
- **Game teleporter spawning** based on game_tele table
- **Daily/weekly quest rotation**
- **Token system** for rewards

### LIMITATION: No Phasing
The current system spawns NPCs in the **world** (visible everywhere), not just in dungeons.

---

## 3. Required Changes for Phased Implementation

### 3.1 Server Database Schema Changes

#### Table 1: creature_phase (NEW)
```sql
CREATE TABLE IF NOT EXISTS `creature_phase` (
  `CreatureGuid` INT UNSIGNED NOT NULL,
  `Phase` SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (`CreatureGuid`, `Phase`),
  CONSTRAINT `fk_creature_phase_guid` 
    FOREIGN KEY (`CreatureGuid`) REFERENCES `creature` (`guid`)
) COMMENT='Define which phases a creature appears in';
```

**Purpose**: Maps each NPC spawn (by GUID) to visible phases
- **CreatureGuid**: Reference to world.creature.guid
- **Phase**: Phase ID (1-32 supported in 3.3.5a)

**Example**:
```sql
INSERT INTO creature_phase VALUES
(123456, 1),  -- NPC 123456 visible in phase 1 (all world)
(123457, 100),  -- NPC 123457 visible in phase 100 (BRD instance)
(123458, 101);  -- NPC 123458 visible in phase 101 (Stratholme instance)
```

#### Table 2: dungeon_quest_phase_mapping (NEW)
```sql
CREATE TABLE IF NOT EXISTS `dungeon_quest_phase_mapping` (
  `dungeon_id` INT UNSIGNED NOT NULL,
  `dungeon_name` VARCHAR(100) NOT NULL,
  `map_id` INT UNSIGNED NOT NULL,
  `phase_id` SMALLINT UNSIGNED NOT NULL,
  `min_level` TINYINT UNSIGNED NOT NULL DEFAULT 60,
  `max_level` TINYINT UNSIGNED NOT NULL DEFAULT 85,
  `npc_entry` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`dungeon_id`),
  UNIQUE KEY `uk_phase_id` (`phase_id`)
) COMMENT='Map dungeons to phases';
```

**Example Data**:
```sql
INSERT INTO dungeon_quest_phase_mapping VALUES
(1, 'Blackrock Depths', 228, 100, 52, 60, 700001),
(2, 'Stratholme', 329, 101, 60, 70, 700002),
(3, 'Molten Core', 409, 102, 60, 80, 700003),
(4, 'Black Temple', 564, 103, 70, 85, 700004),
-- etc. for all 53 NPCs
```

#### Modification: creature Table
Add phase support (if not already present):
```sql
ALTER TABLE creature ADD COLUMN `phaseId` SMALLINT UNSIGNED DEFAULT 1;
ALTER TABLE creature ADD INDEX `idx_phase` (`phaseId`);
```

---

### 3.2 Server-Side C++ Implementation

#### File 1: src/server/scripts/DC/npc_dungeon_quest_master.cpp (~400 lines)

```cpp
#include "ScriptMgr.h"
#include "CreatureScript.h"
#include "CreatureAI.h"
#include "InstanceScript.h"
#include "Player.h"
#include "Map.h"

// Dungeon quest master NPC script for phased spawning
class npc_dungeon_quest_master : public CreatureScript
{
public:
    npc_dungeon_quest_master() : CreatureScript("npc_dungeon_quest_master") { }

    struct npc_dungeon_quest_masterAI : public ScriptedAI
    {
        npc_dungeon_quest_masterAI(Creature* creature) : ScriptedAI(creature) { }

        // Called when creature enters world
        void MoveInLineOfSight(Unit* who) override
        {
            // Only trigger if it's a player
            if (Player* player = who->ToPlayer())
            {
                // Check if player is in the correct instance
                if (!IsPlayerInDungeonInstance(player))
                    return;

                // Update visibility based on player's instance
                UpdateCreatureVisibility(player);
            }
        }

        // Check if player is in this NPC's dungeon
        bool IsPlayerInDungeonInstance(Player* player)
        {
            Map* playerMap = player->GetMap();
            Map* npcMap = me->GetMap();

            if (playerMap->GetId() != npcMap->GetId())
                return false;

            if (!playerMap->IsRaid() && !playerMap->IsDungeon())
                return false;

            // Check phase compatibility
            uint32 playerPhase = player->GetPhaseMask();
            uint32 creaturePhase = me->GetPhaseMask();

            return (playerPhase & creaturePhase) != 0;
        }

        // Update creature visibility for specific player
        void UpdateCreatureVisibility(Player* player)
        {
            // Create creature spawn packet showing NPC
            WorldPacket data(SMSG_MONSTER_MOVE);
            data << me->GetPackGUID();
            me->BuildMovementPacket(&data);
            player->SendDirectMessage(&data);

            // Update quest giver status
            player->SetQuestObjectivesData();
        }

        // Gossip hello - player clicks on NPC
        bool OnGossipHello(Player* player) override
        {
            if (!IsPlayerInDungeonInstance(player))
            {
                player->GetSession()->SendNotification(
                    "This NPC is only visible within the dungeon instance!");
                return true;
            }

            // Show standard quest gossip
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                "Show me available quests", GOSSIP_SENDER_MAIN, 1);
            SendGossipMenuFor(player, 1, me);
            return true;
        }

        // Handle gossip option selection
        bool OnGossipSelect(Player* player, uint32 sender, uint32 action) override
        {
            if (!IsPlayerInDungeonInstance(player))
                return true;

            ClearGossipMenuFor(player);

            // Load and display quests for this dungeon
            DisplayDungeonQuests(player);

            return true;
        }

        // Display available quests for this dungeon
        void DisplayDungeonQuests(Player* player)
        {
            // Query database for quests available in this dungeon
            // This would be custom quest table with dungeon_id field
            
            Map* map = player->GetMap();
            uint32 mapId = map->GetId();
            
            // Hardcoded for now, but should query database
            if (mapId == 228) // Blackrock Depths
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                    "[Daily] BRD Protectors", GOSSIP_SENDER_MAIN, 10);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                    "[Weekly] Dark Irons of BRD", GOSSIP_SENDER_MAIN, 11);
            }

            SendGossipMenuFor(player, 1, me);
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_dungeon_quest_masterAI(creature);
    }
};

void AddSC_npc_dungeon_quest_master()
{
    new npc_dungeon_quest_master();
}
```

#### File 2: src/server/scripts/DC/phase_dungeon_quest_system.cpp (~350 lines)

```cpp
#include "ScriptMgr.h"
#include "Player.h"
#include "Map.h"
#include "InstanceScript.h"
#include "DatabaseEnv.h"

// Phasing system for dungeon quest NPCs
class DungeonQuestPhaseSystem
{
public:
    static DungeonQuestPhaseSystem* instance()
    {
        static DungeonQuestPhaseSystem inst;
        return &inst;
    }

    // Initialize phase mappings from database
    void LoadPhaseMappings()
    {
        _phaseMappings.clear();
        
        QueryResult result = WorldDatabase.Query(
            "SELECT dungeon_id, map_id, phase_id, npc_entry FROM dungeon_quest_phase_mapping");

        if (!result)
        {
            LOG_ERROR("scripts.dc", "Failed to load dungeon phase mappings");
            return;
        }

        do
        {
            Field* fields = result->Fetch();
            uint32 dungeonId = fields[0].Get<uint32>();
            uint32 mapId = fields[1].Get<uint32>();
            uint32 phaseId = fields[2].Get<uint32>();
            uint32 npcEntry = fields[3].Get<uint32>();

            DungeonPhaseInfo info;
            info.dungeonId = dungeonId;
            info.mapId = mapId;
            info.phaseId = phaseId;
            info.npcEntry = npcEntry;

            _phaseMappings[mapId] = info;

        } while (result->NextRow());

        LOG_INFO("scripts.dc", "Loaded {} dungeon phase mappings", _phaseMappings.size());
    }

    // Update player phase when entering dungeon
    void OnPlayerEnterDungeon(Player* player, uint32 mapId)
    {
        auto it = _phaseMappings.find(mapId);
        if (it == _phaseMappings.end())
            return;

        const DungeonPhaseInfo& info = it->second;
        
        // Set player phase to dungeon phase
        player->SetPhaseMask(1 << (info.phaseId % 32), false);
        
        LOG_INFO("scripts.dc", "Player {} entering dungeon {}, phase set to {}",
            player->GetName(), mapId, info.phaseId);
    }

    // Restore player phase when leaving dungeon
    void OnPlayerLeaveDungeon(Player* player, uint32 mapId)
    {
        auto it = _phaseMappings.find(mapId);
        if (it == _phaseMappings.end())
            return;

        // Reset to default phase (phase 1 = visible everywhere)
        player->SetPhaseMask(1, false);
        
        LOG_INFO("scripts.dc", "Player {} left dungeon, phase reset to default", 
            player->GetName());
    }

    // Get phase info for map
    const DungeonPhaseInfo* GetPhaseInfo(uint32 mapId) const
    {
        auto it = _phaseMappings.find(mapId);
        return (it != _phaseMappings.end()) ? &it->second : nullptr;
    }

private:
    struct DungeonPhaseInfo
    {
        uint32 dungeonId;
        uint32 mapId;
        uint32 phaseId;
        uint32 npcEntry;
    };

    std::unordered_map<uint32, DungeonPhaseInfo> _phaseMappings;
};

// Global accessor
DungeonQuestPhaseSystem* sDungeonQuestPhaseSystem = DungeonQuestPhaseSystem::instance();

// Player script hooks
class PlayerScript_DungeonQuestPhasing : public PlayerScript
{
public:
    PlayerScript_DungeonQuestPhasing() : PlayerScript("PlayerScript_DungeonQuestPhasing") { }

    void OnMapChanged(Player* player) override
    {
        if (!player)
            return;

        Map* map = player->GetMap();
        if (!map)
            return;

        uint32 mapId = map->GetId();

        // Check if entering a dungeon with quest system
        if (map->IsDungeon() || map->IsRaid())
        {
            sDungeonQuestPhaseSystem->OnPlayerEnterDungeon(player, mapId);
        }
        else
        {
            // Leaving dungeon, reset phase
            sDungeonQuestPhaseSystem->OnPlayerLeaveDungeon(player, mapId);
        }
    }

    void OnLogin(Player* player) override
    {
        // Initialize phase system on login
        if (!sDungeonQuestPhaseSystem)
            sDungeonQuestPhaseSystem = DungeonQuestPhaseSystem::instance();
    }
};

void AddSC_DungeonQuestPhasing()
{
    new PlayerScript_DungeonQuestPhasing();
    sDungeonQuestPhaseSystem->LoadPhaseMappings();
}
```

#### File 3: Modifications to dc_script_loader.cpp

```cpp
// Add these lines to AddSC_DC_Scripts() function:
AddSC_npc_dungeon_quest_master();
AddSC_DungeonQuestPhasing();
```

---

### 3.3 Instance Map Script Modifications

For each dungeon with quest NPCs, modify the instance script:

#### Example: Blackrock Depths Instance Script Modifications

```cpp
// In src/server/scripts/EasternKingdoms/BlackrockDepths/

// In instance_blackrock_depths.cpp OnPlayerEnter():
void OnPlayerEnter(Player* player) override
{
    // Set player to dungeon quest phase when entering BRD
    player->SetPhaseMask(1 << 99, false);  // Phase 100 (1 << 99 for bit 99)
    
    // Update quest giver visibility
    player->SetQuestObjectivesData();
}

void OnPlayerLeave(Player* player) override
{
    // Reset phase when leaving
    player->SetPhaseMask(1, false);
}
```

---

## 4. Complexity Assessment

### Code Changes Required

| Component | Lines of Code | Complexity | Time |
|-----------|---------------|-----------|------|
| Phase system core | 350 | Medium | 2-3 days |
| Creature visibility logic | 200 | Medium | 2-3 days |
| Quest NPC script | 150 | Low | 1-2 days |
| Instance script mods | 50 × 10 dungeons | Low | 1 day |
| Database schema | SQL | Low | 1 day |
| Testing & debugging | - | High | 3-5 days |
| **TOTAL** | **~800** | **Medium** | **2-3 weeks** |

### Database Changes

| Table | Change Type | Complexity |
|-------|------------|-----------|
| creature_phase | NEW TABLE | Simple (2 columns) |
| dungeon_quest_phase_mapping | NEW TABLE | Simple (6 columns) |
| creature | ADD COLUMN | Simple (1 column + index) |
| **TOTAL** | **2 new + 1 modified** | **Low** |

### Performance Impact

| Operation | Impact | Severity |
|-----------|--------|----------|
| Phase lookup (per player in dungeon) | +1 hashmap lookup | Negligible |
| Creature visibility check | +1 bitwise AND | Negligible |
| Database queries at startup | 1 query, cached result | Negligible |
| Memory usage (phase mappings) | ~2KB for 53 dungeons | Negligible |
| **TOTAL IMPACT** | **None noticeable** | **Minimal** |

---

## 5. Alternative: Simplified Non-Phased Approach

Instead of implementing full phasing, you could:

### Option A: Instance-Only NPCs (Simpler)
- NPC only spawned in instance map (not in world)
- Query `creature_spawns` filtered by `map_id`
- Pros: Simpler, no phase system needed
- Cons: Cannot use world-based spawns

**SQL**:
```sql
-- Spawn NPC only in Blackrock Depths (map 228)
INSERT INTO creature (guid, id, map, zoneId, areaId, spawnMask, 
  phaseMask, modelid, equipment_id, position_x, position_y, 
  position_z, orientation, spawntimesecs)
VALUES 
(5000001, 700001, 228, 230, 1584, 1, 1, 0, 0, 
 652.5, -120.5, -52.5, 1.57, 300);
```

**Complexity**: Very Low (1 week)
- Just spawn NPCs in correct dungeons
- No phase system needed
- Query by map_id instead

---

## 6. Recommended Implementation Path

### Phase 1: Database Setup (Day 1)
```sql
-- Create tables
CREATE TABLE creature_phase (...);
CREATE TABLE dungeon_quest_phase_mapping (...);

-- Add phase data
INSERT INTO dungeon_quest_phase_mapping VALUES ...;

-- Verify creature table has phase support
ALTER TABLE creature ADD COLUMN phaseId SMALLINT UNSIGNED DEFAULT 1;
```

### Phase 2: Core System (Days 2-4)
```cpp
// Implement DungeonQuestPhaseSystem
// Implement PlayerScript_DungeonQuestPhasing
// Update dc_script_loader.cpp
```

### Phase 3: NPC Implementation (Days 5-6)
```cpp
// Create npc_dungeon_quest_master.cpp
// Implement gossip system
// Add quest giver functionality
```

### Phase 4: Instance Integration (Days 7-9)
```cpp
// Modify each dungeon instance script
// Add OnPlayerEnter/OnPlayerLeave hooks
// Test phase transitions
```

### Phase 5: Testing & Polish (Days 10-14)
- Test phase visibility in each dungeon
- Test quest availability
- Test rewards distribution
- Fix edge cases

---

## 7. Implementation Checklist

### Prerequisites
- [ ] AzerothCore database with character and world schemas
- [ ] C++ compilation environment configured
- [ ] Git repository with custom scripts folder
- [ ] Database backup created

### Database
- [ ] Create `creature_phase` table
- [ ] Create `dungeon_quest_phase_mapping` table
- [ ] Add `phaseId` column to `creature` table
- [ ] Insert dungeon-to-phase mapping data
- [ ] Create indexes for performance

### Server Code
- [ ] Create `phase_dungeon_quest_system.cpp` (350 lines)
- [ ] Create `npc_dungeon_quest_master.cpp` (150 lines)
- [ ] Update `dc_script_loader.cpp` registration
- [ ] Modify 10 dungeon instance scripts (50 lines each)

### Testing
- [ ] Verify NPCs invisible in world
- [ ] Enter BRD, verify NPC visible
- [ ] Talk to NPC, verify dialogue works
- [ ] Accept quest, verify tracking
- [ ] Complete quest, verify rewards
- [ ] Leave dungeon, verify NPC invisible again

### Deployment
- [ ] Compile code without errors
- [ ] Apply database migrations
- [ ] Test on development server
- [ ] Deploy to staging
- [ ] Deploy to production

---

## 8. Code Complexity Breakdown

### Easy (~100 lines)
- [ ] Quest NPC gossip menu
- [ ] Basic phase lookup
- [ ] Instance detection

### Medium (~350 lines)
- [ ] Phase system initialization
- [ ] Visibility update logic
- [ ] Database querying

### Hard (~250 lines)
- [ ] Edge case handling (phasing transitions)
- [ ] Player teleportation between instances
- [ ] Group/raid compatibility

---

## 9. Known Issues & Solutions

### Issue: NPC Visible Everywhere
**Cause**: Phase mask not properly set
**Solution**: Verify `phaseId` in `creature` table, check `OnPlayerEnterDungeon` called

### Issue: Quest Not Available
**Cause**: Quest giver conditions not met
**Solution**: Check `character_queststatus`, verify player level requirements

### Issue: NPC Disappears Upon Zone Change
**Cause**: Phase reset too aggressive
**Solution**: Only reset phase for world zones, keep phase for dungeon-to-dungeon transitions

### Issue: Multiple Players See Different NPCs
**Cause**: Per-player phase masks not synchronized
**Solution**: Use `SetPhaseMask` with `update=false`, then `UpdateVisibility()`

---

## 10. Estimated Effort

### Without Phasing (Simpler)
- **Effort**: 1 week
- **Code lines**: ~200
- **Database changes**: 1 new table
- **Testing**: 2 days
- Spawn NPCs only in instance maps

### With Full Phasing (Recommended)
- **Effort**: 2-3 weeks
- **Code lines**: ~800
- **Database changes**: 2 new tables + 1 modified
- **Testing**: 3-5 days
- Full visibility control, more professional

### Summary

**Recommendation**: Implement **full phasing** for:
- Professional appearance
- Better scalability (50+ dungeons)
- Future-proof architecture
- Easier to maintain

The added complexity is worth it for a 255-level server's extensive dungeon network.

---

## 11. Related Documentation

- **Dungeon Quest System**: See `DungeonQuestSystem/` folder
- **Phase Mask Format**: Bits 0-32, each represents one phase
- **Instance Maps**: AzerothCore wiki → Instance Maps
- **Creature Visibility**: AzerothCore wiki → Creature Visibility
- **DatabaseEnv.h**: Database query references

---

## Conclusion

Phased quest NPCs require moderate effort (~800 lines of C++ code) but provide:
✅ Professional quest system  
✅ Immersive dungeon experience  
✅ Scalable architecture  
✅ Minimal performance impact  
✅ Future-proof design  

**Timeline**: 2-3 weeks for full implementation
**Complexity**: Medium (not trivial, but manageable)
**Recommendation**: Proceed with phased implementation
