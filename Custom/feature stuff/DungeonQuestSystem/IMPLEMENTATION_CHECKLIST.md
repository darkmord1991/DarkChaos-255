# DarkChaos Dungeon Quest System - Complete Implementation Checklist

## ✅ COMPLETED PHASES

### Phase 1: Initial Code Generation (v1.0)
- [x] Quest template SQL generation
- [x] NPC linking SQL generation
- [x] Token reward system SQL
- [x] NPC quest handler script generation

### Phase 1B: Corrections & Refactoring (v2.0)
- [x] Fixed quest linking tables (creature_questrelation → creature_queststarter/questender)
- [x] Deleted deprecated v1.0 SQL files
- [x] Consolidated documentation (10 files → 2 essential + 4 reference)
- [x] Organized file structure in Custom/Custom feature SQLs/

### Phase 2: C++ Preparation & Compilation
- [x] Command script file created (cs_dc_dungeonquests.cpp - 1000+ lines)
- [x] 10 admin subcommands implemented with full documentation
- [x] Debug logging system configured
- [x] Database integration patterns established
- [x] Token distribution logic implemented
- [x] Achievement/title system integration
- [x] Script loader integrated (cs_script_loader.cpp modified)
- [x] **C++ COMPILATION SUCCESSFUL - ZERO ERRORS** ✅

---

## ⏳ REMAINING PHASES

### Phase 3A: DBC Modification - Item Tokens

**Objective**: Create/update DBC entries for 5 token items

**Reference Data** (from `dc_items_tokens.csv`):
```
Token Explorer   (700001): Quality 2, Vendor Price 5000
Token Specialist (700002): Quality 3, Vendor Price 10000
Token Legendary  (700003): Quality 4, Vendor Price 25000
Token Challenge  (700004): Quality 4, Vendor Price 25000
Token Speedrunner(700005): Quality 4, Vendor Price 25000
```

**Required Actions**:
- [ ] Locate item DBC source files in `Custom/DBCs/` or extract location
- [ ] Add/update item entries for token IDs 700001-700005
- [ ] Set appropriate:
  - [ ] Item class/subclass
  - [ ] Quality (2=uncommon, 3=rare, 4=epic)
  - [ ] Vendor price
  - [ ] Item model/display ID
  - [ ] Max stack count (suggest 999)
- [ ] Verify no ID conflicts with existing items
- [ ] Generate/compile DBC files

**Deliverables**:
- [ ] Updated item.dbc (or extract new DBC)
- [ ] Verification that items show in client item list

---

### Phase 3B: DBC Modification - Achievements

**Objective**: Create/update DBC entries for 35+ achievements

**Reference Data** (from `dc_achievements.csv`):
- Range: 700001-700403
- Categories: exploration (15), tier_classic (5), tier_tbc (5), tier_wotlk (5), speed (5), daily (5), weekly (5), tokens (20+)
- Each has: name, description, category, icon, reward_title_id, reward_item_id

**Required Actions**:
- [ ] Locate achievement DBC source files
- [ ] Add/update achievement entries 700001-700403
- [ ] Configure for each:
  - [ ] Achievement name
  - [ ] Description
  - [ ] Icon ID
  - [ ] Category (exploration, combat, quest, etc.)
  - [ ] Reward title link (if applicable)
  - [ ] Reward item link (if applicable)
- [ ] Verify achievement progression criteria
- [ ] Set faction-neutral where appropriate
- [ ] Generate/compile DBC files

**Deliverables**:
- [ ] Updated achievement.dbc (or extract new DBC)
- [ ] Verification that achievements appear in Achievement UI

---

### Phase 3C: DBC Modification - Titles

**Objective**: Create/update DBC entries for 15 titles

**Reference Data** (from `dc_titles.csv`):
- Range: 1000-1102
- Format: Male format "X the [Title]", Female format "[Title] X"
- Linked to achievements (e.g., 700001 achievement = 1000 title)

**Required Actions**:
- [ ] Locate character titles DBC source
- [ ] Add/update title entries 1000-1102
- [ ] Set for each:
  - [ ] Male title format string
  - [ ] Female title format string
  - [ ] Bit position in title mask
  - [ ] Associated achievement (if any)
- [ ] Verify format strings work with player names
- [ ] Test title display on male/female characters
- [ ] Generate/compile DBC files

**Deliverables**:
- [ ] Updated CharTitles.dbc (or extract new DBC)
- [ ] Verification that titles appear in title list in-game

---

### Phase 3D: DBC Compilation & Client Testing

**Objective**: Compile all DBC changes and verify client visibility

**Required Actions**:
- [ ] Use DarkChaos-255 DBC compilation tools (extract/update process)
- [ ] Verify no DBC corruption
- [ ] Update client patch or data files as needed
- [ ] Test on dev client:
  - [ ] Can see new items in vendor
  - [ ] Can see new achievements in achievement panel
  - [ ] Can see new titles in title selection
- [ ] Log any client-side errors/warnings

**Tools/References**:
- Check: `apps/extractor/` directory for DBC tools
- Reference: `Custom/DBCs/` structure
- Reference: `Custom/CSV DBC/` CSV→DBC conversion scripts

**Deliverables**:
- [ ] Compiled DBC files ready for client
- [ ] Client test report (items/achievements/titles visible)

---

### Phase 4: SQL Deployment

**Objective**: Deploy 4 SQL files to world database in correct order

**Files to Deploy** (in this order):
1. `DC_DUNGEON_QUEST_SCHEMA_v2.sql` - Creates custom tables
2. `DC_DUNGEON_QUEST_CREATURES_v2.sql` - Creates NPC templates & linking
3. `DC_DUNGEON_QUEST_TEMPLATES_v2.sql` - Creates quest definitions
4. `DC_DUNGEON_QUEST_TOKEN_REWARDS_v2.sql` - Configures token rewards

**Deployment Steps**:
- [ ] Backup current world database
- [ ] Execute SQL 1: Schema creation
  - [ ] Verify `dc_quest_reward_tokens` table exists
  - [ ] Verify `dc_daily_quest_token_rewards` table exists
  - [ ] Verify `dc_weekly_quest_token_rewards` table exists
  - [ ] Verify `dc_npc_quest_link` table exists
- [ ] Execute SQL 2: Creatures
  - [ ] Verify creature templates 700000-700052 created (53 NPCs)
  - [ ] Verify quest linking in creature_queststarter
  - [ ] Verify quest linking in creature_questender
  - [ ] Check spawn locations (Orgrimmar, Shattrath, Dalaran)
- [ ] Execute SQL 3: Quests
  - [ ] Verify quest templates 700101-700104 (daily)
  - [ ] Verify quest templates 700201-700204 (weekly)
  - [ ] Verify quest templates 700701-700999 (dungeons)
  - [ ] Verify quest flags (0x0800 for daily, 0x1000 for weekly)
- [ ] Execute SQL 4: Rewards
  - [ ] Verify token configuration in custom tables
  - [ ] Verify reward mappings

**Deliverables**:
- [ ] All 4 SQL files deployed successfully
- [ ] Database tables verified with row counts
- [ ] Quest data verified in quest_template
- [ ] NPC linkage verified in creature_queststarter/questender

---

### Phase 5A: In-Game Testing - Basic Functionality

**Objective**: Verify quest system works end-to-end

**Test Cases**:

1. **Quest Visibility** ✓ TO TEST
   - [ ] Log in with admin character
   - [ ] Run: `.dcquests list daily`
   - [ ] Verify 4 daily quests appear
   - [ ] Run: `.dcquests list weekly`
   - [ ] Verify 4 weekly quests appear
   - [ ] Run: `.dcquests list dungeon`
   - [ ] Verify 8+ dungeon quests appear

2. **Quest Acceptance** ✓ TO TEST
   - [ ] Find quest NPC (700000-700052)
   - [ ] Accept daily quest
   - [ ] Verify quest appears in quest log
   - [ ] Accept weekly quest
   - [ ] Accept dungeon quest
   - [ ] Verify all show active quests

3. **Quest Progress** ✓ TO TEST
   - [ ] Complete quest objectives
   - [ ] Return to NPC to turn in quest
   - [ ] Run: `.dcquests progress <player_name>`
   - [ ] Verify quest completion registered

4. **Token Rewards** ✓ TO TEST
   - [ ] Complete a quest
   - [ ] Verify tokens awarded
   - [ ] Run: `.dcquests give-token <player_name> 700001`
   - [ ] Verify token received in inventory
   - [ ] Check item properties (vendor price, quality, etc.)

5. **Achievement System** ✓ TO TEST
   - [ ] Run: `.dcquests achievement <player_name> 700001`
   - [ ] Verify achievement awarded in UI
   - [ ] Check achievement reward (title, item, etc.)
   - [ ] Award multiple achievements

6. **Title System** ✓ TO TEST
   - [ ] Run: `.dcquests title <player_name> 1000`
   - [ ] Verify title appears in title list
   - [ ] Test title display on character
   - [ ] Award multiple titles

**Pass/Fail Criteria**:
- [ ] All quests visible via `.dcquests list`
- [ ] Quests can be accepted from NPC
- [ ] Quests show in quest log
- [ ] Quest completion registers
- [ ] Tokens award correctly
- [ ] Achievements award correctly
- [ ] Titles award correctly

---

### Phase 5B: Admin Command Testing

**Objective**: Verify all admin commands work correctly

**Commands to Test**:

1. **Help Command** ✓ TO TEST
   ```
   .dcquests help
   ```
   - [ ] Lists all 10 subcommands
   - [ ] Shows command syntax

2. **List Command** ✓ TO TEST
   ```
   .dcquests list daily
   .dcquests list weekly
   .dcquests list dungeon
   .dcquests list all
   ```
   - [ ] Each returns appropriate quests
   - [ ] Quest IDs display correctly

3. **Info Command** ✓ TO TEST
   ```
   .dcquests info 700101
   .dcquests info 700201
   .dcquests info 700701
   ```
   - [ ] Shows quest details from database
   - [ ] Displays title, description, rewards

4. **Give-Token Command** ✓ TO TEST
   ```
   .dcquests give-token PlayerName 700001
   .dcquests give-token PlayerName 700002 10
   ```
   - [ ] Token appears in player inventory
   - [ ] Quantity correct when specified
   - [ ] Error if invalid token ID

5. **Reward Command** ✓ TO TEST
   ```
   .dcquests reward PlayerName 700101
   ```
   - [ ] Simulates quest reward
   - [ ] Verifies reward logic works
   - [ ] Checks token distribution

6. **Progress Command** ✓ TO TEST
   ```
   .dcquests progress PlayerName
   .dcquests progress PlayerName 700101
   ```
   - [ ] Shows active quests
   - [ ] Shows quest status/progress
   - [ ] Shows completed quests

7. **Reset Command** ✓ TO TEST
   ```
   .dcquests reset PlayerName 700101
   ```
   - [ ] Resets specific quest
   - [ ] Removes from quest log
   - [ ] Can be re-accepted

8. **Debug Command** ✓ TO TEST
   ```
   .dcquests debug on
   .dcquests debug off
   ```
   - [ ] Enables debug logging
   - [ ] Debug output appears in console
   - [ ] Can be toggled on/off

9. **Achievement Command** ✓ TO TEST
   ```
   .dcquests achievement PlayerName 700001
   ```
   - [ ] Awards achievement
   - [ ] Shows in achievement UI
   - [ ] No errors on award

10. **Title Command** ✓ TO TEST
    ```
    .dcquests title PlayerName 1000
    ```
    - [ ] Awards title
    - [ ] Shows in title list
    - [ ] Can be selected

**Pass/Fail Criteria**:
- [ ] All 10 commands execute without error
- [ ] Commands show appropriate feedback to admin
- [ ] Commands work with all required parameters
- [ ] Security enforced (admin-only)
- [ ] Database integration working
- [ ] Debug mode produces useful output

---

### Phase 5C: Debug Mode Testing

**Objective**: Verify debug logging is functional

**Test Cases**:
- [ ] Enable debug: `.dcquests debug on`
- [ ] Run each command type
- [ ] Verify console output shows:
  - [ ] Command name and player
  - [ ] Parameters passed
  - [ ] Database query results
  - [ ] Action results (success/fail)
  - [ ] Timing information (optional)
- [ ] Disable debug: `.dcquests debug off`
- [ ] Verify console output stops

**Expected Output Format**:
```
[DC:DungeonQuests] Command: list - Type: daily
[DC:DungeonQuests] Database query returned 4 results
[DC:DungeonQuests] Quest 700101: "Daily Quest 1"
...
```

---

### Phase 5D: Edge Cases & Error Handling

**Objective**: Verify robust error handling

**Test Scenarios**:

1. **Invalid Quest ID** ✓ TO TEST
   ```
   .dcquests info 999999
   ```
   - [ ] Shows error message
   - [ ] Doesn't crash

2. **Invalid Player Name** ✓ TO TEST
   ```
   .dcquests give-token NonExistentPlayer 700001
   ```
   - [ ] Shows error message
   - [ ] Suggests similar names (if possible)

3. **Offline Player** ✓ TO TEST
   ```
   .dcquests give-token OfflinePlayer 700001
   ```
   - [ ] Shows appropriate message
   - [ ] Doesn't break system

4. **Full Inventory** ✓ TO TEST
   ```
   .dcquests give-token FullInventoryPlayer 700001 999
   ```
   - [ ] Handles gracefully
   - [ ] Partial award or error message
   - [ ] Inventory not corrupted

5. **Invalid Token ID** ✓ TO TEST
   ```
   .dcquests give-token PlayerName 999999
   ```
   - [ ] Shows error
   - [ ] Lists valid token IDs

6. **Invalid Achievement ID** ✓ TO TEST
   ```
   .dcquests achievement PlayerName 999999
   ```
   - [ ] Shows error
   - [ ] Doesn't award false achievement

7. **Invalid Title ID** ✓ TO TEST
   ```
   .dcquests title PlayerName 999999
   ```
   - [ ] Shows error
   - [ ] Doesn't assign invalid title

**Pass/Fail Criteria**:
- [ ] All error cases handled gracefully
- [ ] No console errors or crashes
- [ ] User receives helpful error messages
- [ ] System remains stable after errors

---

## 📊 PROGRESS SUMMARY

| Phase | Status | Tasks | Completion |
|-------|--------|-------|-----------|
| 1     | ✅ DONE | Initial generation | 100% |
| 1B    | ✅ DONE | Corrections & refactoring | 100% |
| 2     | ✅ DONE | C++ prep & compilation | 100% |
| 3A    | ⏳ PENDING | DBC items | 0% |
| 3B    | ⏳ PENDING | DBC achievements | 0% |
| 3C    | ⏳ PENDING | DBC titles | 0% |
| 3D    | ⏳ PENDING | DBC compilation | 0% |
| 4     | ⏳ PENDING | SQL deployment | 0% |
| 5A    | ⏳ PENDING | Basic testing | 0% |
| 5B    | ⏳ PENDING | Command testing | 0% |
| 5C    | ⏳ PENDING | Debug testing | 0% |
| 5D    | ⏳ PENDING | Error handling | 0% |

**Overall Completion**: 25% (3 of 12 phases complete)

---

## 🎯 IMMEDIATE NEXT STEPS

1. **Phase 3A**: Begin DBC modification for tokens
   - Locate DBC source files in `Custom/DBCs/`
   - Update/create items for 700001-700005
   - Reference `Custom/CSV DBC/DC_Dungeon_Quests/dc_items_tokens.csv`

2. **Phase 3B**: Update DBC for achievements
   - Update/create achievements for 700001-700403
   - Reference `Custom/CSV DBC/DC_Dungeon_Quests/dc_achievements.csv`

3. **Phase 3C**: Update DBC for titles
   - Update/create titles for 1000-1102
   - Reference `Custom/CSV DBC/DC_Dungeon_Quests/dc_titles.csv`

---

## 📁 REFERENCE FILES

**C++ Files**:
- `src/server/scripts/Commands/cs_dc_dungeonquests.cpp` ✅ CREATED
- `src/server/scripts/Commands/cs_script_loader.cpp` ✅ MODIFIED

**SQL Files**:
- `Custom/Custom feature SQLs/worlddb/DC_DUNGEON_QUEST_SCHEMA_v2.sql`
- `Custom/Custom feature SQLs/worlddb/DC_DUNGEON_QUEST_CREATURES_v2.sql`
- `Custom/Custom feature SQLs/worlddb/DC_DUNGEON_QUEST_TEMPLATES_v2.sql`
- `Custom/Custom feature SQLs/worlddb/DC_DUNGEON_QUEST_TOKEN_REWARDS_v2.sql`

**CSV/DBC References**:
- `Custom/CSV DBC/DC_Dungeon_Quests/dc_items_tokens.csv`
- `Custom/CSV DBC/DC_Dungeon_Quests/dc_achievements.csv`
- `Custom/CSV DBC/DC_Dungeon_Quests/dc_titles.csv`
- `Custom/CSV DBC/DC_Dungeon_Quests/dc_dungeon_npcs.csv`

**Documentation**:
- `Custom/Custom feature SQLs/START_HERE.md`
- `Custom/Custom feature SQLs/DC_DUNGEON_QUEST_DEPLOYMENT.md`
- `Custom/Custom feature SQLs/PHASE_2_COMPLETE.md` ✅ NEW

---

*Status: Phase 2 Complete - Awaiting Phase 3 (DBC Modifications)*
*Next Review: After DBC files are updated*
