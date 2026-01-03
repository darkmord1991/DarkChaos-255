# Testing Legacy Dungeons (Vanilla/TBC) with Heroic/Mythic Modes
## DarkChaos-255 - How to Test Dungeons That Never Had Heroic/Mythic

---

## 🎯 UNDERSTANDING THE SYSTEM

Your Mythic+ system works by **reusing existing difficulty IDs** at runtime:
- **Normal (0)** = Base difficulty (all dungeons have this)
- **Heroic (1)** = WotLK heroic difficulty, reused for all dungeons
- **Mythic (Epic/2)** = WotLK 10-man raid difficulty, reused for all dungeons

**The scaling happens server-side in C++**, not through DBC files. This means:
- ✅ You can set ANY dungeon to Heroic/Mythic
- ✅ Creatures scale automatically via `MythicDifficultyScaling.cpp`
- ✅ No DBC editing or client patches needed
- ✅ Works for Vanilla/TBC dungeons that never had heroic modes

---

## 📋 QUICK TEST PROCEDURE

### Step 1: Set Your Difficulty BEFORE Entering

```bash
# Example: Testing Scarlet Monastery (Vanilla dungeon, never had heroic)
.dc difficulty heroic        # Set Heroic mode
.tele scarletmonastery       # Teleport to entrance
# Walk through portal
```

**Important:** The difficulty flag is set when you **create** the instance, not after you're inside.

### Step 2: Verify Scaling

Once inside:

```bash
# Target any trash mob
.npc info

# Note the HP value, then exit
.recall

# Change difficulty and re-enter
.dc difficulty mythic
.tele scarletmonastery

# Target the SAME mob and compare HP
.npc info
```

**Expected Results:**
- Normal: Base HP (e.g., 5,000)
- Heroic: +15% HP (e.g., 5,750)
- Mythic: +35% HP (e.g., 6,750)

---

## 🗺️ RECOMMENDED TEST DUNGEONS

### Vanilla Dungeons (Never Had Heroic)
These are perfect for testing because they prove the system works on legacy content:

| Dungeon | Teleport Command | Min Level | Notes |
|---------|------------------|-----------|-------|
| Scarlet Monastery | `.tele scarletmonastery` | 30 | Multiple wings, easy to test |
| Gnomeregan | `.tele gnomeregan` | 24 | Good for Elite mob testing |
| Stratholme | `.tele stratholme` | 55 | End-game Vanilla content |
| Scholomance | `.tele scholomance` | 55 | Many elite mobs |
| Blackrock Depths | `.tele blackrockdepths` | 52 | Large dungeon with bosses |

### TBC Dungeons (Had Heroic, Testing Mythic)
These prove Mythic scaling works on dungeons that already had Heroic:

| Dungeon | Teleport Command | Min Level | Notes |
|---------|------------------|-----------|-------|
| Hellfire Ramparts | `.tele hellfireramparts` | 60 | Short, easy to test |
| Blood Furnace | `.tele bloodfurnace` | 61 | 3 bosses |
| Slave Pens | `.tele slavepens` | 62 | Water dungeon |
| Shadow Labyrinth | `.tele shadowlabyrinth` | 70 | End-game TBC |

### WotLK Dungeons (Native Heroic Support)
These should work out-of-the-box since they already have Heroic mode:

| Dungeon | Teleport Command | Min Level | Notes |
|---------|------------------|-----------|-------|
| Utgarde Keep | `.tele utgardekeep` | 68 | First WotLK dungeon |
| Nexus | `.tele nexus` | 71 | Multiple bosses |
| Azjol-Nerub | `.tele azjolnerub` | 72 | Short dungeon |
| Halls of Lightning | `.tele hallsoflightning` | 80 | Endgame content |

---

## 🧪 DETAILED TEST SCENARIOS

### Test 1: Vanilla Dungeon (Never Had Heroic)

**Goal:** Prove that Scarlet Monastery scales properly

```bash
# 1. Set level 80 for full access
.character level 80
.maxskill

# 2. Test Normal mode
.dc difficulty normal
.dc difficulty info          # Verify: "Current difficulty: Normal"
.tele scarletmonastery

# Inside the dungeon:
# - Target "Scarlet Crusader" (entry 3301)
.npc info
# Note HP: Let's say it's 5,000 HP

# 3. Exit and test Heroic
.recall
.dc difficulty heroic
.dc difficulty info          # Verify: "Current difficulty: Heroic"
.tele scarletmonastery

# Target the same "Scarlet Crusader"
.npc info
# Expected: ~5,750 HP (+15%)

# 4. Exit and test Mythic
.recall
.dc difficulty mythic
.dc difficulty info          # Verify: "Current difficulty: Mythic"
.tele scarletmonastery

# Target the same mob
.npc info
# Expected: ~6,750 HP (+35%)
```

**Success Criteria:**
- ✅ Each difficulty creates a separate instance
- ✅ HP increases match expected multipliers
- ✅ No crashes or errors
- ✅ Damage output also increases (test by letting mob hit you)

---

### Test 2: Boss Scaling Verification

**Goal:** Confirm bosses scale more than trash

```bash
.dc difficulty mythic
.tele stratholme

# 1. Target a trash mob
# Example: Skeletal Guardian (entry 10390)
.npc info
# Note HP (e.g., 8,000)

# 2. Target a boss
# Example: Baron Rivendare (entry 10440)
.npc info
# Note HP (should be significantly higher, e.g., 50,000+)

# 3. Check creature rank
# Bosses should be rank 3 (Boss/Elite Boss)
```

**Expected Results:**
- Trash mobs: Rank 0-1 (Normal/Elite)
- Bosses: Rank 3 (Boss)
- Boss HP >> Trash HP (10x-20x higher)

---

### Test 3: TBC Dungeon with Existing Heroic

**Goal:** Verify Mythic works on dungeons that already have Heroic

```bash
# 1. Test Normal
.dc difficulty normal
.tele hellfireramparts
# Check mob HP

# 2. Test Heroic (TBC native)
.recall
.dc difficulty heroic
.tele hellfireramparts
# HP should be higher

# 3. Test Mythic (custom)
.recall
.dc difficulty mythic
.tele hellfireramparts
# HP should be highest
```

**Success Criteria:**
- ✅ Normal < Heroic < Mythic (HP progression)
- ✅ No conflicts between native Heroic and custom Mythic
- ✅ TBC Heroic mechanics still work (if any)

---

### Test 4: Group Difficulty Testing

**Goal:** Confirm group leader can set difficulty for entire party

```bash
# Player 1 (Leader):
.group leader
.dc difficulty mythic
.dc difficulty info          # Should show "Group leader: Yes"

# Player 2 (Member):
.dc difficulty info          # Should show "Current difficulty: Mythic"
.dc difficulty normal        # Should fail: "Only group leader can change"

# Both players enter dungeon
.tele utgardekeep

# Both players should see Mythic-scaled mobs
```

---

## 🔍 DEBUGGING TIPS

### Issue: Mobs Don't Scale

**Check 1: Verify difficulty is set**
```bash
.dc difficulty info
```
Should show your current difficulty

**Check 2: Check server logs**
```bash
# In Server.log, search for:
grep "Scaled creature" Server.log
```
Should see lines like:
```
Scaled creature [Scarlet Crusader] to Mythic (multiplier: 1.35)
```

**Check 3: Verify profile exists**
```sql
-- Check if dungeon has a profile
SELECT * FROM acore_world.dc_dungeon_mythic_profile 
WHERE map_id = 189;  -- Scarlet Monastery
```

If no profile exists, the dungeon won't scale. Add one:
```sql
INSERT INTO dc_dungeon_mythic_profile 
(map_id, name, heroic_enabled, mythic_enabled, expansion) 
VALUES (189, 'Scarlet Monastery', 1, 1, 0);
```

### Issue: Wrong Scaling Multiplier

Check `MythicDifficultyScaling.cpp` line ~147:
```cpp
case DUNGEON_DIFFICULTY_HEROIC:
    multiplier = 1.15f;  // +15% HP/damage
    break;
case DUNGEON_DIFFICULTY_EPIC:  // Mythic
    multiplier = 1.35f;  // +35% HP/damage
    break;
```

### Issue: Can't Enter Dungeon

**Error: "Transfer Aborted: Difficulty Unavailable"**

**Solution:** Some dungeons don't have Heroic/Mythic entries in `MapDifficulty.dbc`

**Fix:** Add GM permission bypass:
```bash
.gm on
.tele [dungeon]
```

Or add MapDifficulty entries (requires DBC editing - see your plan document §2.8.4)

---

## 📊 TESTING CHECKLIST

Use this to track your testing progress:

```
=== Vanilla Dungeons (No Native Heroic) ===
[ ] Scarlet Monastery - Normal works
[ ] Scarlet Monastery - Heroic scales (+15%)
[ ] Scarlet Monastery - Mythic scales (+35%)
[ ] Gnomeregan - All difficulties work
[ ] Stratholme - Boss scaling verified

=== TBC Dungeons (Native Heroic) ===
[ ] Hellfire Ramparts - Normal works
[ ] Hellfire Ramparts - Heroic works (native)
[ ] Hellfire Ramparts - Mythic works (custom)
[ ] Shadow Labyrinth - All difficulties

=== WotLK Dungeons (Should Work OOTB) ===
[ ] Utgarde Keep - All difficulties
[ ] Halls of Lightning - All difficulties
[ ] Gundrak - All difficulties

=== Group Testing ===
[ ] Leader can set difficulty
[ ] Members inherit difficulty
[ ] Non-leaders blocked from changing
[ ] Difficulty persists for group

=== Edge Cases ===
[ ] Cannot change inside instance
[ ] Level 79 blocked from Mythic
[ ] Scaling works after server restart
[ ] Multiple groups can run different difficulties simultaneously
```

---

## 🎮 COMMON TELEPORT COMMANDS

Quick reference for testing:

```bash
# Vanilla
.tele deadmines | .tele wailingcaverns | .tele shadowfangkeep
.tele blackfathomdeeps | .tele razorfenkraul | .tele razorfendowns
.tele uldaman | .tele zulfarrak | .tele maruadon
.tele templediremaul | .tele blackrockdepths | .tele blackrockspire
.tele stratholme | .tele scholomance

# TBC
.tele hellfireramparts | .tele bloodfurnace | .tele shatteredhalls
.tele slavepens | .tele underbog | .tele steamvault
.tele manatombs | .tele auchenaicoils | .tele sethekhalls
.tele shadowlabyrinth | .tele oldhibernalcavern | .tele botanica
.tele mechanar | .tele arcatraz | .tele magistersutterrace

# WotLK
.tele utgardekeep | .tele utgardepinnacle | .tele nexus
.tele oculus | .tele ankahet | .tele azjolnerub
.tele draktharonkeep | .tele violethold | .tele gundrak
.tele hallsofstone | .tele hallsoflightning | .tele cullingofstratholme
.tele trialofthechampion | .tele forgeofssouls | .tele pitofsaron
```

---

## 🚀 NEXT STEPS AFTER TESTING

Once you confirm scaling works:

1. **Populate Database**
   - Add profiles for all dungeons to `dc_dungeon_mythic_profile`
   - Set expansion flags correctly (0=Vanilla, 1=TBC, 2=WotLK)

2. **Implement Keystone System** (from your plan)
   - Font of Power GameObject
   - Keystone items (M+2 through M+10)
   - Death budget tracking

3. **Add Loot Tables**
   - Token rewards per difficulty
   - Scaled item level drops
   - Weekly vault system

4. **Create Portal Selector NPCs**
   - Place at dungeon entrances
   - Gossip menu for difficulty selection
   - Requirement checking (level, ilvl)

---

## 🎯 EXPECTED BEHAVIOR SUMMARY

**What SHOULD Happen:**
- ✅ Any dungeon can be set to Heroic/Mythic via command
- ✅ Creatures scale automatically when entering
- ✅ Vanilla/TBC dungeons work just like WotLK dungeons
- ✅ No client modifications needed
- ✅ Multiple groups can run different difficulties simultaneously

**What WON'T Happen (Yet):**
- ❌ Keystones (not implemented)
- ❌ Mythic+ levels 2-10 (not implemented)
- ❌ Affixes (not implemented)
- ❌ Death budget system (not implemented)
- ❌ Weekly vault rewards (not implemented)

---

**Ready to test?** Start with Scarlet Monastery on Heroic mode - it's quick, easy to navigate, and proves the system works on legacy content! 🎮
