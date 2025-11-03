# Dungeon Quest Master - Version Comparison & Recommendation

## Overview

Two versions of the dungeon quest master NPC script exist in `src/server/scripts/DC/DungeonQuests/`:

1. **npc_dungeon_quest_master.cpp** - Custom implementation with gossip menus
2. **npc_dungeon_quest_master_v2.cpp** - AzerothCore standards-compliant implementation

This document analyzes both versions and provides recommendations.

---

## Version 1: npc_dungeon_quest_master.cpp

### Architecture
- **Custom gossip menu system** with multi-level navigation
- **Manual quest handling** via `AddQuest()` API
- **Custom tracking** separate from AzerothCore's built-in systems

### Features
✅ User-friendly multi-level gossip menus:
   - Main menu → Category selection (Daily/Weekly/Dungeon)
   - Sub-menus for each quest type
   - Rewards info screen
   
✅ Quest validation:
   - Level requirement checking
   - Quest status verification
   
✅ Clear code structure with separate methods for each menu

### Implementation Details
```cpp
// Gossip menu structure:
Main Menu
├── Dungeon Quests → ShowDungeonQuestsMenu()
├── Daily Challenges → ShowDailyQuestsMenu()
├── Weekly Trials → ShowWeeklyQuestsMenu()
├── Rewards Info → ShowRewardsInfo()
└── Exit

// Quest acceptance flow:
Player clicks quest → HandleQuestSelection()
→ Quest validation → player->AddQuest(quest, npc)
```

### Pros
✅ **Better user experience** - Clear menu navigation, categorized quests
✅ **Self-documenting** - Rewards info built into gossip
✅ **Flexible** - Easy to add custom quest selection logic
✅ **Player-friendly** - No need to scroll through long quest lists

### Cons
❌ **Duplicates AC functionality** - Gossip menus already exist in AC
❌ **Database disconnect** - Doesn't use `creature_questrelation` table
❌ **Maintenance overhead** - Quest IDs hardcoded in script
❌ **Less efficient** - More code = more compilation time
❌ **Breaks standards** - Doesn't follow AC quest system patterns

### Use Cases
- Servers with **custom quest distribution** logic
- Need for **complex quest selection** based on player state
- **Highly curated** quest experience with guided navigation

---

## Version 2: npc_dungeon_quest_master_v2.cpp

### Architecture
- **Standard AzerothCore quest API** integration
- **Database-driven** quest assignment via `creature_questrelation`/`creature_involvedrelation`
- **Automatic gossip generation** by AC core

### Features
✅ Uses standard AC database tables:
   - `creature_questrelation` - Quest starters
   - `creature_involvedrelation` - Quest enders (creature_questender in newer AC)
   - `character_queststatus` - Auto-managed by AC
   - `character_achievement` - Auto-managed by AC

✅ Minimal code - AC handles:
   - Gossip menu generation
   - Quest acceptance UI
   - Quest completion UI
   - Daily/weekly reset timers
   - Quest status tracking

✅ Token reward system in `OnQuestReward()` hook:
   - Queries `dc_daily_quest_token_rewards` table
   - Queries `dc_weekly_quest_token_rewards` table
   - Awards tokens via `player->AddItem()`

✅ Achievement integration:
   - Tracks total quest completions
   - Awards achievements at milestones (1, 10, 50 quests)

### Implementation Details
```cpp
// Quest flow (all automatic via AC core):
1. Player interacts with NPC
2. AC queries creature_questrelation → Shows available quests
3. Player accepts quest → AC handles quest status
4. Player completes objectives → AC updates character_queststatus
5. Player returns to NPC → AC queries creature_involvedrelation
6. Player completes quest → OnQuestReward() hook fires
7. Script awards tokens + achievements
```

### Pros
✅ **Standards-compliant** - Follows AC architecture patterns
✅ **Database-driven** - Quest assignment via SQL, not hardcoded
✅ **Minimal code** - ~300 lines vs ~200 lines (but more reusable)
✅ **Better performance** - AC core is optimized for quest handling
✅ **Easier maintenance** - Add quests via SQL, not C++ recompilation
✅ **Automatic UI** - AC generates proper quest acceptance/completion dialogs
✅ **Built-in features** - Daily/weekly flags, quest chains, prerequisites

### Cons
❌ **Less user-friendly discovery** - No categorized menu system
❌ **Generic UI** - Standard AC quest list (can be long)
❌ **Limited customization** - Harder to add complex selection logic

### Use Cases
- **Production servers** following AC standards
- **Large quest catalogs** (630+ quests) managed via database
- Need for **AC's built-in features** (quest chains, prerequisites, etc.)
- **Long-term maintainability** preferred over custom UX

---

## Comparison Table

| Feature | Version 1 (Custom Gossip) | Version 2 (AC Standard) |
|---------|---------------------------|-------------------------|
| **Code Size** | ~200 lines | ~300 lines (with reward logic) |
| **Gossip Menu** | Custom multi-level | AC auto-generated |
| **Quest Storage** | Hardcoded IDs | Database tables |
| **Quest Assignment** | `player->AddQuest()` | AC core automatic |
| **Daily/Weekly Reset** | Manual tracking needed | AC flags (QuestType) |
| **Token Rewards** | Not implemented | ✅ Database-driven |
| **Achievements** | Not implemented | ✅ Milestone tracking |
| **Maintenance** | Recompile for changes | SQL updates only |
| **AC Standards** | ❌ Custom approach | ✅ Follows patterns |
| **User Experience** | ✅ Better navigation | ⚠️ Generic AC UI |
| **Performance** | ⚠️ More overhead | ✅ AC optimized |
| **Future-proof** | ❌ May break | ✅ AC updates compatible |

---

## Recommendation

### ⭐ **USE VERSION 2 (npc_dungeon_quest_master_v2.cpp)** ⭐

**Primary Reasons:**
1. **Standards Compliance** - Follows AzerothCore architecture
2. **Database-Driven** - 630+ quests managed via SQL, not hardcoded
3. **Token Rewards** - Already implemented with database integration
4. **Achievement System** - Already implemented with milestone tracking
5. **Maintainability** - Add/modify quests via SQL without recompilation
6. **Future-Proof** - Compatible with AC updates and patches

### Action Plan

#### ✅ **Keep:**
- `npc_dungeon_quest_master_v2.cpp` - Rename to `npc_dungeon_quest_master.cpp`
- `DungeonQuestSystem.cpp` - Core quest completion handler
- `npc_dungeon_quest_daily_weekly.cpp` - Daily/weekly specific logic

#### ❌ **Remove:**
- `npc_dungeon_quest_master.cpp` (old version) - Delete or archive

#### 🔄 **Migrate:**
If you want the **better UX from Version 1**, consider hybrid approach:
- Keep Version 2 as the core implementation
- Add optional gossip menu wrapper that:
  - Shows categorized quest lists
  - Filters quests by type (daily/weekly/dungeon)
  - Still uses AC's quest acceptance system under the hood

### Hybrid Approach (Best of Both Worlds)

Create a new wrapper script that enhances Version 2:

```cpp
// Enhanced gossip menu that works WITH AC quest system
bool OnGossipHello(Player* player, Creature* creature) override
{
    // Show custom menu
    AddGossipItemFor(player, 0, "Show Daily Quests", GOSSIP_SENDER_MAIN, 1);
    AddGossipItemFor(player, 0, "Show Weekly Quests", GOSSIP_SENDER_MAIN, 2);
    AddGossipItemFor(player, 0, "Show All Quests", GOSSIP_SENDER_MAIN, 3);
    SendGossipMenuFor(player, 1, creature->GetGUID());
    return true;
}

bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
{
    if (action == 3) {
        // Show ALL quests (standard AC behavior)
        player->PrepareGossipMenu(creature);
        player->SendPreparedGossip(creature);
    } else {
        // Filter quests by type (daily/weekly)
        // But still use AC's quest acceptance system
        ShowFilteredQuests(player, creature, action);
    }
    return true;
}
```

This gives you:
- ✅ Better UX (categorized menus)
- ✅ AC standards compliance
- ✅ Database-driven quest management
- ✅ Token rewards & achievements

---

## Database Setup for Version 2

To use Version 2, ensure these tables are populated:

### 1. Quest Starters
```sql
-- Link NPCs to quests they start
INSERT INTO creature_questrelation (id, quest)
VALUES
(700000, 700101),  -- Daily Quest 1
(700000, 700102),  -- Daily Quest 2
(700000, 700201),  -- Weekly Quest 1
(700001, 700701);  -- Dungeon Quest 1
```

### 2. Quest Enders
```sql
-- Link NPCs to quests they complete
INSERT INTO creature_questender (id, quest)
VALUES
(700000, 700101),
(700000, 700102),
(700000, 700201),
(700001, 700701);
```

### 3. Token Rewards
```sql
-- Already created in DC_DUNGEON_QUEST_REWARDS_TOKENS.sql
SELECT * FROM dc_daily_quest_token_rewards;
SELECT * FROM dc_weekly_quest_token_rewards;
```

---

## Migration Steps

### Step 1: Backup Current Implementation
```bash
cd "C:\Users\flori\Desktop\WoW Server\Azeroth Fork\DarkChaos-255"
mkdir "Custom\Old Scripts\DungeonQuests_v1_backup"
copy "src\server\scripts\DC\DungeonQuests\npc_dungeon_quest_master.cpp" "Custom\Old Scripts\DungeonQuests_v1_backup\"
```

### Step 2: Remove Old Version from Build
Edit `DC/CMakeLists.txt`:
```cmake
# Remove this line:
DungeonQuests/npc_dungeon_quest_master.cpp

# Keep only:
set(SCRIPTS_DC_DungeonQuests
    DungeonQuests/DungeonQuestSystem.cpp
    DungeonQuests/npc_dungeon_quest_master_v2.cpp
    DungeonQuests/npc_dungeon_quest_daily_weekly.cpp
)
```

### Step 3: Rename v2 to Main Version
```bash
cd "src\server\scripts\DC\DungeonQuests"
del npc_dungeon_quest_master.cpp
ren npc_dungeon_quest_master_v2.cpp npc_dungeon_quest_master.cpp
```

Update CMakeLists.txt:
```cmake
set(SCRIPTS_DC_DungeonQuests
    DungeonQuests/DungeonQuestSystem.cpp
    DungeonQuests/npc_dungeon_quest_master.cpp  # Now uses v2 implementation
    DungeonQuests/npc_dungeon_quest_daily_weekly.cpp
)
```

### Step 4: Update Script Loader
Verify `DC/dc_script_loader.cpp` has:
```cpp
void AddSC_npc_dungeon_quest_master();  // This now uses v2 implementation
void AddSC_DungeonQuestSystem();

void AddDCScripts()
{
    AddSC_npc_dungeon_quest_master();
    AddSC_DungeonQuestSystem();
    // ... other scripts
}
```

### Step 5: Rebuild Server
```bash
./acore.sh compiler build
```

### Step 6: Verify Database
```sql
-- Check quest starters are configured
SELECT cr.id AS npc_id, cr.quest AS quest_id, qt.Title
FROM creature_questrelation cr
JOIN quest_template qt ON cr.quest = qt.ID
WHERE cr.quest BETWEEN 700101 AND 700999;

-- Check quest enders are configured  
SELECT ce.id AS npc_id, ce.quest AS quest_id, qt.Title
FROM creature_questender ce
JOIN quest_template qt ON ce.quest = qt.ID
WHERE ce.quest BETWEEN 700101 AND 700999;
```

---

## Testing Checklist

After migration to Version 2:

### ✅ Quest Acceptance
- [ ] NPCs show available quests in gossip menu
- [ ] Daily quests (700101-700104) appear for eligible NPCs
- [ ] Weekly quests (700201-700204) appear for eligible NPCs
- [ ] Dungeon quests (700701-700999) appear for eligible NPCs

### ✅ Quest Completion
- [ ] Complete a daily quest → Receive tokens
- [ ] Complete a weekly quest → Receive tokens
- [ ] Complete a dungeon quest → Progress tracked

### ✅ Token Rewards
- [ ] Check `dc_daily_quest_token_rewards` table is queried
- [ ] Tokens appear in player inventory
- [ ] Token count matches database configuration

### ✅ Achievements
- [ ] First dungeon quest → Achievement 40001 awarded
- [ ] 10 dungeon quests → Achievement 40002 awarded
- [ ] 50 dungeon quests → Achievement 40003 awarded

### ✅ Daily/Weekly Reset
- [ ] Daily quests reset at configured hour (4 AM default)
- [ ] Weekly quests reset on configured day (Wednesday default)
- [ ] `character_queststatus` table updated correctly

---

## Conclusion

**Version 2 (AC standards-compliant)** is the recommended implementation because:

1. ✅ **Production-ready** - Follows AzerothCore best practices
2. ✅ **Scalable** - 630+ quests managed via database
3. ✅ **Feature-complete** - Tokens, achievements, tracking implemented
4. ✅ **Maintainable** - Add quests via SQL, not C++ recompilation
5. ✅ **Future-proof** - Compatible with AC updates

**Version 1 (custom gossip)** should only be kept if:
- You need **highly custom quest selection logic**
- You prefer **curated UX** over database flexibility
- You're willing to **maintain hardcoded quest lists**

For DarkChaos-255 with 630+ dungeon quests, **Version 2 is the clear choice**.

---

## Next Steps

1. ✅ **Migrate to Version 2** using steps above
2. 🔄 **Optionally add hybrid gossip wrapper** for better UX
3. ✅ **Populate database tables** (creature_questrelation, creature_questender)
4. ✅ **Test thoroughly** using checklist above
5. ✅ **Document for users** - Add to server wiki/readme

---

*Generated: November 3, 2025*  
*Author: GitHub Copilot*  
*Project: DarkChaos-255 Dungeon Quest System Integration*
