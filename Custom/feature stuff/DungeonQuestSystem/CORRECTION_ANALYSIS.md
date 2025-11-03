# 🔧 DUNGEON QUEST SYSTEM v2.0 - CRITICAL CORRECTIONS NEEDED

## Issue 1: Table Naming Inconsistency ❌

### Problem
Not all custom tables have the `dc_` prefix. Mixed naming:
- ❌ `dungeon_quest_npc` (should be `dc_dungeon_quest_npc`)
- ❌ `dungeon_quest_mapping` (should be `dc_dungeon_quest_mapping`)
- ❌ `player_dungeon_quest_progress` (should be `dc_player_dungeon_quest_progress`)
- ❌ `player_dungeon_achievements` (should be `dc_player_dungeon_achievements`)
- ❌ `expansion_stats` (should be `dc_expansion_stats`)
- ✅ `dc_quest_reward_tokens` (correct)
- ✅ `dc_daily_quest_token_rewards` (correct)

### Solution
All custom tables must be renamed with `dc_` prefix for consistency and to avoid namespace collisions.

### Tables to Rename

| Old Name | New Name |
|----------|----------|
| `dungeon_quest_npc` | `dc_dungeon_quest_npc` |
| `dungeon_quest_mapping` | `dc_dungeon_quest_mapping` |
| `player_dungeon_quest_progress` | `dc_player_dungeon_quest_progress` |
| `dungeon_quest_raid_variants` | `dc_dungeon_quest_raid_variants` |
| `player_dungeon_achievements` | `dc_player_dungeon_achievements` |
| `expansion_stats` | `dc_expansion_stats` |
| `player_dungeon_completion_stats` | `dc_player_dungeon_completion_stats` |
| `player_daily_quest_progress` | `dc_player_daily_quest_progress` |
| `player_weekly_quest_progress` | `dc_player_weekly_quest_progress` |
| `custom_dungeon_quests` | `dc_custom_dungeon_quests` |

---

## Issue 2: CSV/DBC Confusion ❌

### Problem
I created CSV configuration files for server settings, but you meant:
- Extract WorldDB data (creature_template, quest_template, item_template) to CSV format
- These CSVs are used for data extraction/reimport workflows
- Can be converted back to DBC format for client usage

### Solution
Create proper CSV export templates that match the structure of:
- `creature_template` → `dc_creature_template.csv`
- `quest_template` → `dc_quest_template.csv`
- `item_template` → `dc_item_template.csv`
- `creature` → `dc_creature_spawns.csv`

These are **data extracts**, not configuration files.

---

## Issue 3: Quest Assignment to NPCs ❌

### Problem
Current implementation doesn't properly link NPCs to quests for both starting AND completing.

### How It Actually Works in AzerothCore

#### Quest_Template Fields (Latest AC)
```sql
quest_template
├── ID                          -- Quest ID (e.g., 700701)
├── Method                       -- 0 = kill/explore, 2 = item
├── ZoneOrSort                   -- Zone ID
├── QuestLevel                   -- Required level
├── Type                        -- Quest type
├── QuestFlags                  -- Quest flags (important!)
├── RequiredRaces               -- Races that can do quest
├── RequiredSkillId             -- Skill requirement
├── RequiredSkillPoints         -- Skill points needed
├── StartScript                 -- Quest start script (CreatureScript)
├── CompleteScript              -- Quest complete/end script (CreatureScript)
├── SourceSpellID               -- Item quest starter
├── RewardXPDifficulty          -- XP difficulty
├── RewardMoneyDifficulty       -- Gold difficulty
├── RewardSpellCast             -- Spell on quest complete
├── RewardHonor                 -- Honor reward
├── RewardKillingBlows          -- Killing blows reward
├── StartItem                   -- Starting item
└── ... (many more fields)
```

#### Quest Flags That Matter
```cpp
QUEST_FLAGS_NONE                    = 0x00000000
QUEST_FLAGS_STAY_ALIVE              = 0x00000001  // Player must stay alive
QUEST_FLAGS_PARTY_ACCEPT            = 0x00000002  // Party members can accept
QUEST_FLAGS_EXPLORATION             = 0x00000004  // Exploration quest
QUEST_FLAGS_SHARABLE                = 0x00000008  // Quest is sharable
QUEST_FLAGS_HAS_CONDITION           = 0x00000010
QUEST_FLAGS_HIDE_REWARD_POI         = 0x00000020
QUEST_FLAGS_RAID                    = 0x00000040  // Raid quest
QUEST_FLAGS_TBC                     = 0x00000080  // Requires TBC
QUEST_FLAGS_WOTLK                   = 0x00000100  // Requires WotLK
QUEST_FLAGS_DAILY                   = 0x00000800  // Daily quest
QUEST_FLAGS_WEEKLY                  = 0x00001000  // Weekly quest
QUEST_FLAGS_AUTOCOMPLETE            = 0x00002000  // Auto complete
QUEST_FLAGS_DISPLAY_ITEM_IN_TRACKER = 0x00004000
```

#### How Quest Start/End Works

**Option A: Direct NPC Linking (Gossip Menu)**
```sql
-- NPC offers quest through gossip menu
INSERT INTO `gossip_menu_option` 
VALUES 
(700000, 0, 2, 'Start Quest 700701', 0, 1, 700701, 0);
--                                            ↑ quest_id

-- NPC ends quest through gossip menu
INSERT INTO `gossip_menu_option` 
VALUES 
(700000, 1, 2, 'Complete Quest 700701', 0, 1, 700701, 0);
```

**Option B: Script-Based Linking (Modern AzerothCore)**
```cpp
// In C++ script
if (player->GetQuestStatus(700701) == QUEST_STATUS_INCOMPLETE)
{
    // Quest not finished, show quest giver option
    player->ADD_GOSSIP_ITEM(GOSSIP_ICON_CHAT, "Complete Quest", GOSSIP_SENDER_MAIN, 1);
}
else if (player->GetQuestStatus(700701) == QUEST_STATUS_NONE)
{
    // Quest not started, show quest starter
    player->ADD_GOSSIP_ITEM(GOSSIP_ICON_CHAT, "Start Quest", GOSSIP_SENDER_MAIN, 2);
}
```

#### The Actual Linking Table (Optional but Useful)

Instead of relying only on gossip menus, create explicit mapping:

```sql
CREATE TABLE `dc_npc_quest_link` (
    `npc_entry` INT UNSIGNED NOT NULL,           -- NPC entry
    `quest_id` INT UNSIGNED NOT NULL,            -- Quest ID
    `is_starter` TINYINT(1) DEFAULT 1,           -- NPC starts quest
    `is_ender` TINYINT(1) DEFAULT 1,             -- NPC ends quest
    `gossip_menu_id` INT UNSIGNED DEFAULT NULL,  -- Gossip menu (if applicable)
    PRIMARY KEY (`npc_entry`, `quest_id`)
) ENGINE=INNODB DEFAULT CHARSET=utf8mb4;
```

This allows:
1. Easy query to find which NPCs handle which quests
2. Support for both starter AND ender on same NPC
3. Flexible quest assignment system

---

## Issue 4: Latest AzerothCore Compatibility ❌

### Required Verification

**Check Current AC Version:**
```bash
# In your acore.sh or CMakeLists.txt
cat CMakeLists.txt | grep -i "version\|azeroth"
```

**Latest AC Database Conventions:**
1. Use only standard AzerothCore tables for core data
2. Custom tables use `dc_` prefix
3. Script IDs use proper ranges (1000000+)
4. Quest IDs use proper ranges (700000+ for custom)
5. NPC entries use proper ranges (700000+ for custom)
6. All fields match the **current** AC database schema

---

## Correction Plan

### Step 1: Rename All Tables
Add a migration SQL file that renames all tables with `ALTER TABLE ... RENAME TO ...`

### Step 2: Create CSV/DBC Export Templates
Create CSV files with headers matching quest_template, creature_template, etc. columns

### Step 3: Implement Proper Quest Linking
- Option A: Use gossip_menu_option (simpler, compatible)
- Option B: Use script-based linking (more powerful, modern)
- Create `dc_npc_quest_link` table for explicit mapping

### Step 4: Update C++ Scripts
- Implement proper quest status checks
- Handle both start and end scenarios
- Use latest AC CreatureScript APIs

### Step 5: Verify All Schema
- Check quest_template fields exist
- Verify creature_template structure
- Ensure gossip tables are correct
- Test against your AC version

---

## Questions to Clarify

1. **CSV/DBC Purpose**: 
   - Are these for backing up/restoring creature/quest data?
   - Do you need to convert between CSV and DBC formats?
   - Which columns should the CSVs contain?

2. **Quest Linking Preference**:
   - Use gossip_menu_option (simpler, traditional)?
   - Use script-based (more flexible, modern)?
   - Use explicit dc_npc_quest_link table?

3. **AzerothCore Version**:
   - What's your current AC version/revision?
   - Where can I check the exact database schema?

4. **Quest Start/End**:
   - Same NPC for both start and end?
   - Different NPCs for different dungeons?
   - Auto-complete or manual turn-in?

---

## Expected Deliverables (Revised)

### Phase 1B (Corrections)
1. ✅ All tables with `dc_` prefix
2. ✅ Proper CSV export templates (not config)
3. ✅ Correct quest linking mechanism
4. ✅ Updated C++ scripts for latest AC
5. ✅ Revised SQL schema files

### Phase 2: Deployment (After corrections)
1. Database import
2. Script integration
3. Testing
4. Live deployment

---

**Status:** Ready for correction once you clarify the 4 questions above.

Would you like me to:
1. Generate corrected SQL files with `dc_` prefixes?
2. Create CSV templates for creature/quest data export?
3. Implement proper quest linking mechanism?
4. Update all C++ scripts for latest AC?

Or should I wait for clarification on the questions first?
