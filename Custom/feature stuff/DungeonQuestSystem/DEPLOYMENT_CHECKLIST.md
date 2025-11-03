#!/usr/bin/env markdown
# DEPLOYMENT CHECKLIST v2.0
# Dungeon Quest NPC System - Phase 2 Ready

## PRE-DEPLOYMENT (Today)

### 1. Review Documentation
- [ ] Read QUICK_REFERENCE_GUIDE.md (5 min)
- [ ] Read DEPLOYMENT_GUIDE_v2_CORRECTED.md (30 min)
- [ ] Understand the corrections in COMPREHENSIVE_CORRECTION_GUIDE.md (optional)

### 2. Verify Files Exist
- [ ] DC_DUNGEON_QUEST_SCHEMA_v2.sql exists
- [ ] DC_DUNGEON_QUEST_CREATURES_v2.sql exists
- [ ] DC_DUNGEON_QUEST_TEMPLATES_v2.sql exists
- [ ] DC_DUNGEON_QUEST_TOKEN_REWARDS_v2.sql exists
- [ ] npc_dungeon_quest_master_v2.cpp exists

### 3. Prepare Environment
- [ ] Have MySQL/MariaDB admin access
- [ ] Know your MySQL password
- [ ] Have terminal/shell access ready
- [ ] Know your AzerothCore build directory path

---

## DEPLOYMENT PHASE (2-3 hours)

### Phase 2A: Database Backup

#### Step 1: Create Backup
- [ ] Execute backup command:
  ```bash
  mysqldump -u root -p world > backup_$(date +%Y%m%d_%H%M%S).sql
  ```
- [ ] Verify backup file created (should be 50-500 MB)
- [ ] Store backup in safe location

#### Step 2: Verify Backup
- [ ] Check file size is reasonable
- [ ] Verify file contains SQL statements
- [ ] Note the backup filename for recovery reference

---

### Phase 2B: Schema Import

#### Step 1: Import Schema
- [ ] Execute schema import:
  ```bash
  mysql -u root -p world < DC_DUNGEON_QUEST_SCHEMA_v2.sql
  ```
- [ ] No errors in output

#### Step 2: Verify Tables Created
- [ ] Execute verification:
  ```bash
  mysql -u root -p world -e "SHOW TABLES LIKE 'dc_%';"
  ```
- [ ] Output shows 4 tables:
  - [ ] dc_quest_reward_tokens
  - [ ] dc_daily_quest_token_rewards
  - [ ] dc_weekly_quest_token_rewards
  - [ ] dc_npc_quest_link (optional)

---

### Phase 2C: Creatures & Linking Import

#### Step 1: Import Creatures
- [ ] Execute creatures import:
  ```bash
  mysql -u root -p world < DC_DUNGEON_QUEST_CREATURES_v2.sql
  ```
- [ ] No errors in output

#### Step 2: Verify Creatures
- [ ] Execute verification:
  ```bash
  mysql -u root -p world -e "SELECT COUNT(*) FROM creature_template WHERE entry >= 700000 AND entry <= 700099;"
  ```
- [ ] Output shows: 53

#### Step 3: Verify Quest Linking
- [ ] Execute verification:
  ```bash
  mysql -u root -p world -e "SELECT COUNT(*) FROM creature_questrelation WHERE id >= 700000;"
  ```
- [ ] Output shows: 8+ entries

---

### Phase 2D: Quest Templates Import

#### Step 1: Import Quests
- [ ] Execute quests import:
  ```bash
  mysql -u root -p world < DC_DUNGEON_QUEST_TEMPLATES_v2.sql
  ```
- [ ] No errors in output

#### Step 2: Verify Quests
- [ ] Execute verification:
  ```bash
  mysql -u root -p world -e "SELECT COUNT(*) FROM quest_template WHERE ID >= 700101;"
  ```
- [ ] Output shows: 16+ entries

#### Step 3: Verify Daily Quest Flags
- [ ] Execute verification:
  ```bash
  mysql -u root -p world -e "SELECT ID, Flags FROM quest_template WHERE ID >= 700101 AND ID <= 700104;"
  ```
- [ ] All daily quests have Flags = 0x0800 (2048)

#### Step 4: Verify Weekly Quest Flags
- [ ] Execute verification:
  ```bash
  mysql -u root -p world -e "SELECT ID, Flags FROM quest_template WHERE ID >= 700201 AND ID <= 700204;"
  ```
- [ ] All weekly quests have Flags = 0x1000 (4096)

---

### Phase 2E: Token Rewards Import

#### Step 1: Import Token Rewards
- [ ] Execute token rewards import:
  ```bash
  mysql -u root -p world < DC_DUNGEON_QUEST_TOKEN_REWARDS_v2.sql
  ```
- [ ] No errors in output

#### Step 2: Verify Tokens
- [ ] Execute verification:
  ```bash
  mysql -u root -p world -e "SELECT COUNT(*) FROM dc_quest_reward_tokens;"
  ```
- [ ] Output shows: 5

#### Step 3: Verify Daily Rewards
- [ ] Execute verification:
  ```bash
  mysql -u root -p world -e "SELECT COUNT(*) FROM dc_daily_quest_token_rewards;"
  ```
- [ ] Output shows: 4+ entries

---

### Phase 2F: Script Integration

#### Step 1: Copy Script
- [ ] Copy npc_dungeon_quest_master_v2.cpp to:
  ```
  src/server/scripts/Custom/DC/npc_dungeon_quest_master_v2.cpp
  ```
- [ ] Directory exists (create if needed)
- [ ] File copied successfully

#### Step 2: Verify Script Location
- [ ] File exists: `src/server/scripts/Custom/DC/npc_dungeon_quest_master_v2.cpp`
- [ ] File size is ~25 KB
- [ ] File contains proper C++ code

#### Step 3: Build AzerothCore
- [ ] Execute build command:
  ```bash
  ./acore.sh compiler build
  ```
- [ ] Build completes without errors
- [ ] No compilation warnings related to DC scripts

---

### Phase 2G: Server Testing

#### Step 1: Start World Server
- [ ] Execute worldserver startup
- [ ] Server starts without errors
- [ ] No crash on startup

#### Step 2: Check Logs
- [ ] Review worldserver logs:
  ```bash
  tail -f logs/server.log | grep -i "dungeon\|quest\|token"
  ```
- [ ] No error messages related to DC quests
- [ ] No missing creature or quest entries

#### Step 3: Verify NPC Spawns
- [ ] In-game: Check Orgrimmar for quest master NPC (entry 700000)
- [ ] NPC is visible
- [ ] NPC has proper model and name

---

## TESTING PHASE (2-3 hours)

### Phase 3A: In-Game Functionality

#### Step 1: Quest Master Interaction
- [ ] Player approaches NPC 700000
- [ ] Gossip menu appears
- [ ] Quest list shows available quests

#### Step 2: Quest Acceptance
- [ ] Accept daily quest (ID 700101)
- [ ] Quest appears in quest log
- [ ] Quest objectives display

#### Step 3: Quest Completion
- [ ] Complete quest objectives
- [ ] Quest completion works
- [ ] Completion dialogue appears

#### Step 4: Token Reward
- [ ] Receive token item (ID 700001)
- [ ] Token appears in inventory
- [ ] Correct quantity (should be 1+ based on db)

#### Step 5: Achievement Award
- [ ] Achievement points update
- [ ] Character sheet reflects achievement

---

### Phase 3B: Daily Quest Reset Testing

#### Step 1: Set Server Time
- [ ] Restart server with quest reset time tomorrow
- [ ] OR use admin command to advance time

#### Step 2: Wait for Reset
- [ ] Wait for quest reset timer to expire
- [ ] Check if daily quest resets

#### Step 3: Verify Reset
- [ ] Quest becomes available again
- [ ] Can accept quest again
- [ ] Rewards can be claimed again

---

### Phase 3C: Weekly Quest Reset Testing

#### Step 1: Accept Weekly Quest
- [ ] Accept weekly quest (ID 700201)
- [ ] Complete weekly quest

#### Step 2: Verify Reset Time
- [ ] Check when quest resets (should be 7 days)
- [ ] Verify reset happens on schedule

---

### Phase 3D: Error Testing

#### Step 1: Check Logs for Errors
- [ ] Search logs for "ERROR"
- [ ] Search logs for "CRITICAL"
- [ ] Search logs for "FAIL"
- [ ] No relevant errors found

#### Step 2: Check Database Integrity
- [ ] Run:
  ```bash
  mysql -u root -p world -e "CHECK TABLE dc_quest_reward_tokens;"
  ```
- [ ] All tables OK

---

## POST-DEPLOYMENT (Ongoing)

### Daily Monitoring
- [ ] Check server logs for errors
- [ ] Monitor quest completion rates
- [ ] Monitor token distribution
- [ ] Check player feedback

### Weekly Tasks
- [ ] Verify daily quest resets work
- [ ] Check token reward multipliers are correct
- [ ] Review quest difficulty and feedback

### Performance Monitoring
- [ ] Monitor database query performance
- [ ] Check server CPU/memory usage
- [ ] Track quest completion statistics

---

## ROLLBACK PLAN (If Needed)

### If Something Goes Wrong

#### Option 1: Rollback Before Script
- [ ] Execute:
  ```bash
  mysql -u root -p world < backup_YYYYMMDD.sql
  ```
- [ ] Server restarts
- [ ] Previous state restored

#### Option 2: Keep v2.0, Fix Issues
- [ ] Identify the specific issue
- [ ] Reference DEPLOYMENT_GUIDE_v2_CORRECTED.md troubleshooting
- [ ] Apply fix and rebuild

---

## SUCCESS CRITERIA

### All of These Must Be True

- [x] 4 dc_* tables exist in database
- [x] 53 quest master NPCs created
- [x] Quest linking in creature_questrelation works
- [x] C++ script compiles without errors
- [x] World server starts successfully
- [x] NPC spawns in game
- [x] Can accept quests from NPC
- [x] Can complete quests
- [x] Tokens are awarded
- [x] Achievements update
- [x] Daily quests reset after 24 hours
- [x] Weekly quests reset after 7 days
- [x] No errors in server logs
- [x] Players report positive feedback

---

## COMMON ISSUES & FIXES

### Issue: "Table already exists"
**Solution:** This is OK if you're updating. Old tables are replaced.

### Issue: "MySQL connection error"
**Solution:** Verify MySQL password is correct, MySQL server is running

### Issue: "Script fails to compile"
**Solution:** Ensure C++ file is in correct directory, rebuild clean

### Issue: "NPC doesn't spawn"
**Solution:** Check creature spawn table, verify NPC entry in database

### Issue: "Quests don't link to NPC"
**Solution:** Verify creature_questrelation entries, check quest IDs match

### Issue: "Tokens not awarded"
**Solution:** Check dc_daily_quest_token_rewards table, verify item IDs

---

## DOCUMENTATION REFERENCE

| Issue | Reference |
|-------|-----------|
| Need deployment help | DEPLOYMENT_GUIDE_v2_CORRECTED.md |
| Need quick reference | QUICK_REFERENCE_GUIDE.md |
| Need to understand changes | COMPREHENSIVE_CORRECTION_GUIDE.md |
| Need file locations | FINAL_FILE_MANIFEST.md |
| Need troubleshooting | DEPLOYMENT_GUIDE_v2_CORRECTED.md (Section 6) |

---

## SIGN-OFF

### Deployment Completed By
- Name: ________________
- Date: ________________
- Time: ________________

### Verification By
- Name: ________________
- Date: ________________
- Time: ________________

### Notes
```
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________
```

---

## FINAL STATUS

- [ ] Phase 2A: Database Backup - COMPLETE
- [ ] Phase 2B: Schema Import - COMPLETE
- [ ] Phase 2C: Creatures Import - COMPLETE
- [ ] Phase 2D: Quests Import - COMPLETE
- [ ] Phase 2E: Rewards Import - COMPLETE
- [ ] Phase 2F: Script Integration - COMPLETE
- [ ] Phase 2G: Server Testing - COMPLETE
- [ ] Phase 3A: In-Game Testing - COMPLETE
- [ ] Phase 3B: Daily Reset Testing - COMPLETE
- [ ] Phase 3C: Weekly Reset Testing - COMPLETE
- [ ] Phase 3D: Error Testing - COMPLETE

### OVERALL STATUS: __ READY FOR PRODUCTION

---

**Questions?** Refer to DEPLOYMENT_GUIDE_v2_CORRECTED.md

**Version:** 2.0 | **Date:** November 2, 2025 | **Status:** Ready for Deployment
