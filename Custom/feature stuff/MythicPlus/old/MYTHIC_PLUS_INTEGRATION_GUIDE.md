# Mythic+ System Integration Guide
## Aligning with Existing DarkChaos Architecture

This document outlines how the Mythic+ system integrates with existing DarkChaos infrastructure, ensuring consistency and maintainability.

---

## NPC ID Allocation

### Current DarkChaos NPCs:
- **300313**: Item Upgrade Vendor (`ItemUpgradeNPC_Vendor.cpp`)
- **300314**: Artifact Curator (`ItemUpgradeNPC_Curator.cpp`)

### New Mythic+ NPCs:
- **300315**: Mythic+ Dungeon Teleporter (Main entry point for dungeon content)
- **300316**: Mythic Raid Teleporter (Main entry point for raid content)
- **300317**: Mythic+ Token Vendor (Reward exchange NPC)

**Pattern**: All custom DarkChaos NPCs use 1900xx ID range

---

## Database Architecture

### Naming Convention:
All tables use `dc_*` prefix to separate from core AzerothCore tables.

**Existing Systems:**
```sql
dc_player_upgrade_tokens      -- ItemUpgrades token tracking
dc_player_artifact_discoveries -- ItemUpgrades artifact system
dc_item_upgrade_synthesis_recipes -- ItemUpgrades crafting
```

**New Mythic+ Tables:**
```sql
dc_mythic_seasons              -- Season tracking and configuration
dc_mythic_dungeons_config      -- Dungeon difficulty settings
dc_mythic_raid_config          -- Raid difficulty settings
dc_mythic_affixes              -- Affix definitions
dc_mythic_player_rating        -- Player rating per season
dc_mythic_run_history          -- Run completion tracking
dc_mythic_achievements         -- Seasonal achievement tracking
dc_mythic_vault_rewards        -- Weekly vault system
dc_mythic_tokens               -- Token currency (follows upgrade tokens pattern)
```

### Query Pattern (from ItemUpgradeCurator.cpp):
```cpp
// Standard pattern for database queries
try {
    QueryResult result = CharacterDatabase.Query(
        "SELECT column1, column2 FROM dc_table_name WHERE player_guid = {}",
        player->GetGUID().GetCounter()
    );
    
    if (result) {
        // Process result
        uint32 value = result->Fetch()[0].Get<uint32>();
    } else {
        // Handle no results
    }
}
catch (...) {
    LOG_WARN("module", "Database query failed for player {}", player->GetGUID().ToString());
    // Display error to player
    AddGossipItemFor(player, GOSSIP_ICON_CHAT,
        "Database not configured. Import SQL files first.",
        GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF);
}
```

---

## Gossip Menu System

### Pattern (from ItemUpgradeCurator.cpp):

**OnGossipHello Structure:**
```cpp
bool OnGossipHello(Player* player, Creature* creature) override
{
    ClearGossipMenuFor(player);
    
    try {
        // 1. Query player data
        QueryResult result = CharacterDatabase.Query(...);
        
        // 2. Build greeting with color-coded stats
        std::string greeting = "Welcome!\n"
            + "|cff00ff00Stat1:|r " + std::to_string(value1) + "\n"
            + "|cffff9900Stat2:|r " + std::to_string(value2);
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, greeting, 
            GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF);
        
        // 3. Add menu options
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Option 1",
            GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 1);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Option 2",
            GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 2);
    }
    catch (...) {
        // Error handling
    }
    
    // 4. Send gossip menu
    player->PlayerTalkClass->SendGossipMenu(1, creature->GetGUID());
    return true;
}
```

**OnGossipSelect Structure:**
```cpp
bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
{
    ClearGossipMenuFor(player);
    
    switch (action)
    {
        case GOSSIP_ACTION_INFO_DEF + 1:
            // Handle option 1
            ShowSubmenu1(player, creature);
            break;
            
        case GOSSIP_ACTION_INFO_DEF + 2:
            // Handle option 2
            ShowSubmenu2(player, creature);
            break;
            
        case GOSSIP_ACTION_INFO_DEF + 20: // Standard "Back" action
            OnGossipHello(player, creature);
            break;
            
        default:
            CloseGossipMenuFor(player);
            break;
    }
    
    return true;
}
```

### Action ID Convention:
- `GOSSIP_ACTION_INFO_DEF`: Base action ID (display only)
- `GOSSIP_ACTION_INFO_DEF + 1-19`: Menu options
- `GOSSIP_ACTION_INFO_DEF + 20`: Back button (standard)
- `GOSSIP_ACTION_INFO_DEF + 21-99`: Submenu options

### Color Codes (Standard WoW):
```cpp
"|cff00ff00"  // Green (positive stats, success)
"|cffff9900"  // Orange (neutral info, warnings)
"|cffff0000"  // Red (errors, requirements not met)
"|cffffffff"  // White (default text)
"|r"          // Reset color
```

---

## Achievement System Integration

### Existing Infrastructure:
- `dc_achievements.cpp` - Custom achievement handling
- `character_achievement` - Standard AC table for achievements
- `AchievementMgr` - AC achievement manager

### Mythic+ Achievement Pattern:
```cpp
// In MythicPlusManager.cpp or similar
void AwardMythicPlusAchievement(Player* player, uint32 achievementId)
{
    // Use standard AC achievement system
    if (!player->HasAchieved(achievementId))
    {
        player->CompletedAchievement(sAchievementStore.LookupEntry(achievementId));
        
        // Optional: Track in custom table for seasonal data
        CharacterDatabase.Execute(
            "INSERT INTO dc_mythic_achievements (player_guid, achievement_id, season_id, earned_date) "
            "VALUES ({}, {}, {}, NOW())",
            player->GetGUID().GetCounter(), achievementId, currentSeasonId
        );
    }
}
```

### Achievement ID Ranges (Avoid Conflicts):
- Core WoW achievements: 1-5000
- ItemUpgrades achievements: 90000-90099
- **Mythic+ achievements: 90100-90199** (Dungeons)
- **Mythic Raid achievements: 90200-90299** (Raids)

---

## Token/Currency System

### Pattern (from dc_player_upgrade_tokens):

**Token Storage:**
```sql
CREATE TABLE dc_mythic_tokens (
    player_guid BIGINT NOT NULL,
    token_type VARCHAR(50) NOT NULL,  -- 'mythic_plus_tokens', 'vault_tokens'
    amount INT DEFAULT 0,
    last_updated DATETIME,
    PRIMARY KEY (player_guid, token_type)
);
```

**Token Management Functions:**
```cpp
// Add tokens
void AddMythicTokens(Player* player, uint32 amount, const std::string& tokenType)
{
    CharacterDatabase.Execute(
        "INSERT INTO dc_mythic_tokens (player_guid, token_type, amount, last_updated) "
        "VALUES ({}, '{}', {}, NOW()) "
        "ON DUPLICATE KEY UPDATE amount = amount + {}, last_updated = NOW()",
        player->GetGUID().GetCounter(), tokenType, amount, amount
    );
}

// Check token balance
uint32 GetMythicTokens(Player* player, const std::string& tokenType)
{
    QueryResult result = CharacterDatabase.Query(
        "SELECT amount FROM dc_mythic_tokens WHERE player_guid = {} AND token_type = '{}'",
        player->GetGUID().GetCounter(), tokenType
    );
    
    return result ? result->Fetch()[0].Get<uint32>() : 0;
}

// Spend tokens
bool SpendMythicTokens(Player* player, uint32 amount, const std::string& tokenType)
{
    uint32 current = GetMythicTokens(player, tokenType);
    if (current < amount)
        return false;
    
    CharacterDatabase.Execute(
        "UPDATE dc_mythic_tokens SET amount = amount - {}, last_updated = NOW() "
        "WHERE player_guid = {} AND token_type = '{}'",
        amount, player->GetGUID().GetCounter(), tokenType
    );
    
    return true;
}
```

---

## Quest System Integration (DungeonQuests Patterns)

### Weekly Reset Logic (from DungeonQuests):

**Pattern:**
```cpp
// In MythicPlusManager.cpp
class MythicPlusWeeklyReset : public PlayerScript
{
public:
    MythicPlusWeeklyReset() : PlayerScript("MythicPlusWeeklyReset") { }

    void OnLogin(Player* player) override
    {
        // Check if weekly reset occurred
        uint32 lastReset = player->GetUInt32Value(PLAYER_FIELD_CUSTOM_MYTHIC_WEEKLY_RESET);
        uint32 currentWeek = GetCurrentWeekNumber();
        
        if (lastReset != currentWeek)
        {
            // Reset weekly vault
            CharacterDatabase.Execute(
                "UPDATE dc_mythic_vault_rewards SET claimed = 0 WHERE player_guid = {}",
                player->GetGUID().GetCounter()
            );
            
            player->SetUInt32Value(PLAYER_FIELD_CUSTOM_MYTHIC_WEEKLY_RESET, currentWeek);
        }
    }
};
```

### Seasonal Reset (Similar to Quest Rotation):
```cpp
void StartNewSeason(uint32 newSeasonId)
{
    // Mark previous season as inactive
    CharacterDatabase.Execute("UPDATE dc_mythic_seasons SET active = 0");
    
    // Activate new season
    CharacterDatabase.Execute(
        "UPDATE dc_mythic_seasons SET active = 1 WHERE season_id = {}",
        newSeasonId
    );
    
    // Archive previous season ratings
    CharacterDatabase.Execute(
        "UPDATE dc_mythic_player_rating SET archived = 1 WHERE season_id < {}",
        newSeasonId
    );
}
```

---

## File Structure

### Script Organization:
```
src/server/scripts/DC/
├── ItemUpgrades/
│   ├── ItemUpgradeNPC_Vendor.cpp       (NPC 300313)
│   ├── ItemUpgradeNPC_Curator.cpp      (NPC 300314)
│   └── ...
├── DungeonQuests/
│   ├── npc_dungeon_quest_master.cpp
│   └── ...
├── MythicPlus/                          (NEW)
│   ├── npc_mythic_plus_dungeon_teleporter.cpp  (NPC 300315)
│   ├── npc_mythic_raid_teleporter.cpp         (NPC 300316)
│   ├── npc_mythic_plus_token_vendor.cpp       (NPC 300317)
│   ├── MythicPlusManager.cpp
│   ├── MythicDifficultyScaling.cpp
│   ├── MythicPlusConstants.h
│   └── MythicPlusHelpers.h
```

### Database Schema Files:
```
data/sql/custom/
├── ItemUpgrade_Schema_WORLD.sql
├── DungeonQuests_Schema_WORLD.sql
└── MythicPlus_Schema_WORLD.sql        (NEW)
```

---

## Error Handling Patterns

### From ItemUpgradeCurator.cpp:

**Database Query Errors:**
```cpp
try {
    QueryResult result = CharacterDatabase.Query(...);
    // Process result
}
catch (const std::exception& e) {
    LOG_WARN("mythicplus", "Query failed: {}", e.what());
    AddGossipItemFor(player, GOSSIP_ICON_CHAT,
        "Database not configured. Import SQL files first.",
        GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF);
}
catch (...) {
    LOG_WARN("mythicplus", "Unknown error in database query");
    CloseGossipMenuFor(player);
}
```

**Player Action Validation:**
```cpp
// Check requirements before teleporting
if (player->IsInCombat())
{
    ChatHandler(player->GetSession()).PSendSysMessage("Cannot teleport while in combat!");
    CloseGossipMenuFor(player);
    return true;
}

if (player->GetLevel() < minLevel)
{
    ChatHandler(player->GetSession()).PSendSysMessage("You must be level {} to enter!", minLevel);
    CloseGossipMenuFor(player);
    return true;
}
```

---

## Best Practices Summary

### 1. NPC Implementation:
- ✅ Follow Curator pattern for Gossip menus
- ✅ Use GOSSIP_ACTION_INFO_DEF + offset for actions
- ✅ Always include "Back" button at +20
- ✅ try-catch for all database queries
- ✅ Color-code text for readability

### 2. Database Design:
- ✅ Use `dc_*` prefix for all tables
- ✅ Foreign keys where applicable
- ✅ Indexes on frequently queried columns
- ✅ Use CharacterDatabase for player data
- ✅ Use WorldDatabase for config data

### 3. Achievement Integration:
- ✅ Use standard AC achievement system
- ✅ Custom tracking in dc_mythic_achievements for seasonal data
- ✅ Avoid ID conflicts with existing achievements

### 4. Token/Currency:
- ✅ Follow dc_player_upgrade_tokens pattern
- ✅ Use INSERT ... ON DUPLICATE KEY UPDATE
- ✅ Track last_updated for debugging

### 5. Code Organization:
- ✅ Separate files per NPC
- ✅ Shared logic in Manager/Helper classes
- ✅ Constants in header files
- ✅ Use namespaces (e.g., `namespace MythicPlus`)

---

## Testing Checklist

- [ ] NPCs spawn correctly in cities
- [ ] Gossip menus display without errors
- [ ] Database queries handle missing tables gracefully
- [ ] Player stats display correctly in menus
- [ ] Teleportation works to all configured dungeons/raids
- [ ] Token rewards granted on completion
- [ ] Achievements unlock properly
- [ ] Weekly resets function correctly
- [ ] Seasonal transitions work without data loss
- [ ] Error messages are user-friendly

---

## References

**Existing Code to Review:**
- `src/server/scripts/DC/ItemUpgrades/ItemUpgradeNPC_Curator.cpp` - Gossip menu pattern
- `src/server/scripts/DC/ItemUpgrades/ItemUpgradeNPC_Vendor.cpp` - Token vendor pattern
- `src/server/scripts/DC/DungeonQuests/npc_dungeon_quest_master.cpp` - Quest giver pattern
- `data/sql/custom/ItemUpgrade_Schema_WORLD.sql` - Database schema examples

**Documentation:**
- `Documentation/MYTHIC_PLUS_SYSTEM_PLAN.md` - Full system implementation plan
- `src/server/scripts/DC/ItemUpgrades/README.md` - ItemUpgrades system overview (if exists)

---

*Last Updated: [Current Date]*
*Prepared for: DarkChaos-255 Server*
