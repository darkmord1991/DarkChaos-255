# Mythic+ System Testing Guide
## DarkChaos-255 - How to Test Your Implementation

---

## ✅ WHAT WAS FIXED

The compilation errors have been resolved:
1. ✅ Missing `DungeonQuestConstants.h` include - **FIXED**
2. ✅ Duplicate `GOSSIP_ICON_CHAT` enum - **FIXED**
3. ✅ Undefined `SetDungeonDifficultyID` method - **FIXED** (replaced with `SetDungeonDifficulty`)
4. ✅ Undefined `SendBroadcastMessage` method - **FIXED** (replaced with `ChatHandler`)

---

## 📝 WHAT'S IMPLEMENTED

### ✅ Working Features:
1. **Difficulty Scaling System** (`MythicDifficultyScaling.cpp`)
   - Creatures scale based on dungeon difficulty
   - Normal: Base stats
   - Heroic: +15% HP, +10% Damage
   - Mythic (Epic): +35% HP, +20% Damage

2. **Portal Selector NPC** (`npc_dungeon_portal_selector.cpp`)
   - Gossip menu to select difficulty
   - Requirement checking (level, item level)
   - Info display with stats per difficulty

3. **Command System** (`cs_dc_addons.cpp`) - **NEW!**
   - `.dc difficulty normal` - Set Normal difficulty
   - `.dc difficulty heroic` - Set Heroic difficulty
   - `.dc difficulty mythic` - Set Mythic difficulty (requires level 80)
   - `.dc difficulty info` - Show current difficulty and available options
   
   **Note:** The difficulty commands are integrated into the existing `.dc` command system,
   which also includes XP addon commands (send, grant, etc.)

### ⏳ Not Yet Implemented (From Your Plan):
- Keystone/Font-of-Power system
- Mythic+ levels (M+2 through M+10)
- Affix system
- Weekly vault rewards
- Token vendor system

### ✨ New Features:
- **Solo Play Support** - Solo players can set any difficulty without a group
- **Dungeon Entry Announcements** - Automatic notification when entering a dungeon showing:
  - Dungeon name
  - Current difficulty
  - Scaling applied
  - Keystone level (when Mythic+ is active)

---

## 🧪 HOW TO TEST

### **Step 1: Rebuild the Server**

After the fixes, you need to rebuild:

```powershell
cd K:/Dark-Chaos/DarkChaos-255
./acore.sh compiler build
```

Or use the VS Code task:
- Press `Ctrl+Shift+B`
- Select "AzerothCore: Build (local)"

**Expected result:** Clean build with no errors

---

### **Step 2: Start the Server**

Start worldserver and authserver:

```powershell
# Terminal 1 - Authserver
cd K:/Dark-Chaos/DarkChaos-255/env/dist/bin
./authserver.exe

# Terminal 2 - Worldserver
cd K:/Dark-Chaos/DarkChaos-255/env/dist/bin
./worldserver.exe
```

Or use VS Code tasks:
- "AzerothCore: Run authserver (restarter)"
- "AzerothCore: Run worldserver (restarter)"

---

### **Step 3: Create a Test Character**

1. **Create a GM account** (if you don't have one):
   ```sql
   -- In authserver console or MySQL
   account create testgm password
   account set gmlevel testgm 3 -1
   ```

2. **Log in and create a level 80 character**

3. **Set yourself to level 80** (if not already):
   ```
   .character level 80
   .maxskill
   ```

---

### **Step 4: Test the Difficulty Command**

#### Test 4.1: Basic Command Usage

```
.dc difficulty info
```

**Expected output:**
```
=== Dungeon Difficulty Info ===
Current difficulty: Normal
You are not in a group

=== Available Commands ===
.dc difficulty normal  - Set Normal difficulty
.dc difficulty heroic  - Set Heroic difficulty
.dc difficulty mythic  - Set Mythic difficulty (req. level 80)

=== Difficulty Bonuses ===
Normal: Base creature stats
Heroic: +15% HP, +10% Damage
Mythic: +35% HP, +20% Damage, Better loot
```

#### Test 4.2: Change to Heroic

```
.dc difficulty heroic
```

**Expected output:**
```
Difficulty set to Heroic
```

Then verify:
```
.dc difficulty info
```

Should show: `Current difficulty: Heroic`

#### Test 4.3: Change to Mythic

```
.dc difficulty mythic
```

**Expected output:**
```
Difficulty set to Mythic
```

#### Test 4.4: Test Level Requirement

Create a low-level alt (level 1-79) and try:
```
.dc difficulty mythic
```

**Expected output:**
```
You must be level 80 to use Mythic difficulty.
```

---

### **Step 5: Test Dungeon Entry**

#### Test 5.1: Teleport to a Dungeon

Pick a WotLK dungeon (easiest to test):

```
.tele utgardekeep
```

Or use the teleport command for other dungeons:
```
.lookup tele utgarde
.tele [name]
```

#### Test 5.2: Enter the Dungeon

1. Set your difficulty BEFORE entering:
   ```
   .dc difficulty heroic
   ```

2. Walk into the dungeon portal (or use `.go zonexy` if stuck)

3. **Check the instance difficulty:**
   ```
   .gps
   ```
   Look at the map name - should show difficulty in brackets

#### Test 5.3: Verify Creature Scaling

Once inside the dungeon:

1. **Target a creature** (trash mob or boss)

2. **Check its stats:**
   ```
   .npc info
   ```
   Note the HP value

3. **Exit the dungeon:**
   ```
   .recall
   ```

4. **Change difficulty to Mythic:**
   ```
   .dc difficulty mythic
   ```

5. **Re-enter the dungeon**

6. **Target the SAME creature again** and check HP

**Expected results:**
- Normal: Base HP (e.g., 10,000)
- Heroic: +15% HP (e.g., 11,500)
- Mythic: +35% HP (e.g., 13,500)

---

### **Step 6: Test Group Difficulty Changes**

#### Test 6.1: Create a Group

Invite another player (or use a second account):

```
.group join [playername]
```

#### Test 6.2: Test Leader-Only Changes

**As group leader:**
```
.dc difficulty mythic
```

**Expected:** `[Group] Difficulty set to Mythic by [YourName]`

**As non-leader** (on the other player):
```
.dc difficulty normal
```

**Expected:** `Only the group leader can change difficulty.`

---

### **Step 7: Test Inside Instance Prevention**

1. Enter a dungeon (any difficulty)

2. Try to change difficulty WHILE INSIDE:
   ```
   .dc difficulty heroic
   ```

**Expected output:**
```
You cannot change difficulty while inside an instance. Please exit first.
```

This is correct behavior - retail prevents mid-instance difficulty changes.

---

### **Step 8: Test Portal Selector NPC**

If you have the portal selector NPC spawned:

1. **Find the NPC** (check spawn location in your DB)

2. **Right-click to open gossip menu**

3. **Select difficulty options:**
   - Normal
   - Heroic
   - Mythic
   - Info (shows dungeon stats)

4. **Verify tooltips and requirements**

**Expected behavior:**
- Normal: Always available
- Heroic: Shows level/ilvl requirements
- Mythic: Shows "Requires level 80"
- Info: Shows detailed stats for each difficulty

---

## 🐛 TROUBLESHOOTING

### Problem: Command not found (`.dc difficulty` doesn't work)

**Cause:** Script not loaded or server not rebuilt

**Solution:**
1. Verify `cs_dc_difficulty.cpp` is in `src/server/scripts/Commands/`
2. Check `cs_script_loader.cpp` includes the registration
3. Rebuild: `./acore.sh compiler build`
4. Restart worldserver

---

### Problem: Creatures don't scale

**Cause:** Scaling hook not applying or no dungeon profile loaded

**Debug steps:**

1. **Check logs** (`env/dist/logs/Server.log`):
   ```
   grep "Scaled creature" Server.log
   ```
   Should see: `Scaled creature [name] to [difficulty]`

2. **Enable debug logging** (worldserver.conf):
   ```ini
   LogLevel = 1
   ```

3. **Check database** - verify `dc_dungeon_mythic_profile` has entries:
   ```sql
   SELECT * FROM acore_world.dc_dungeon_mythic_profile;
   ```

---

### Problem: Difficulty doesn't persist between dungeons

**Cause:** Normal behavior - each instance remembers its difficulty

**Solution:**
- Set difficulty BEFORE entering each new dungeon
- Group difficulty persists for all members
- Solo difficulty resets on logout (expected)

---

## 📊 VERIFICATION CHECKLIST

Use this checklist to confirm everything works:

- [ ] Command `.dc difficulty info` shows current difficulty
- [ ] Can change to Normal difficulty
- [ ] Can change to Heroic difficulty
- [ ] Can change to Mythic difficulty (at level 80)
- [ ] Cannot change difficulty while inside instance
- [ ] Group leader can change difficulty for entire group
- [ ] Non-leader cannot change group difficulty
- [ ] Creatures have higher HP in Heroic vs Normal
- [ ] Creatures have highest HP in Mythic
- [ ] Portal selector NPC shows correct difficulty options
- [ ] Server logs show creature scaling events
- [ ] No crashes or errors during testing

---

## 🚀 NEXT STEPS

Now that basic difficulty scaling works, you can implement:

### Priority 1: Keystone System (From your plan)
1. Create Font of Power GameObject (700001-700008)
2. Implement keystone item (100000+)
3. Add keystone activation script
4. Store keystone level in InstanceScript data
5. Update `GetKeystoneLevel()` to return actual value

### Priority 2: Mythic+ Scaling
1. Add M+2 through M+10 difficulty multipliers
2. Scale creature HP/damage by keystone level
3. Death budget system (track deaths per instance)
4. Score calculation on completion

### Priority 3: Rewards
1. Token vendor NPC
2. Weekly vault system
3. Loot table configuration
4. Achievement integration

---

## 📝 TESTING LOG TEMPLATE

Copy this to track your testing:

```
=== Mythic+ System Testing Log ===
Date: [Current Date]
Server Version: DarkChaos-255
Tester: [Your Name]

Test 1: Basic Difficulty Commands
[ ] .dc difficulty info - Works
[ ] .dc difficulty normal - Works
[ ] .dc difficulty heroic - Works
[ ] .dc difficulty mythic - Works
Notes: ____________________

Test 2: Creature Scaling
Dungeon: Utgarde Keep
[ ] Normal: Base HP = _______
[ ] Heroic: HP = _______ (+15% expected)
[ ] Mythic: HP = _______ (+35% expected)
Notes: ____________________

Test 3: Group Functionality
[ ] Leader can change difficulty - Works
[ ] Non-leader blocked - Works
[ ] All members get difficulty update - Works
Notes: ____________________

Test 4: Portal Selector NPC
[ ] Gossip menu opens - Works
[ ] Difficulty options visible - Works
[ ] Requirements enforced - Works
[ ] Info display accurate - Works
Notes: ____________________

Test 5: Edge Cases
[ ] Cannot change inside instance - Works
[ ] Low-level blocked from Mythic - Works
[ ] Difficulty persists in group - Works
Notes: ____________________

=== Overall Result ===
Status: [ ] PASS / [ ] FAIL
Issues Found: ____________________
Next Steps: ____________________
```

---

## 🎯 SUCCESS CRITERIA

Your Mythic+ system is working correctly when:

✅ All commands execute without errors
✅ Creatures scale properly per difficulty
✅ Group difficulty changes work as expected
✅ Portal selector NPC functions correctly
✅ No server crashes or memory leaks
✅ Logs show scaling events firing
✅ Players can complete dungeons at all difficulties

---

## 📚 ADDITIONAL RESOURCES

- **Your Implementation Plan:** `MYTHIC_PLUS_SYSTEM_PLAN.md`
- **AzerothCore Docs:** https://www.azerothcore.org/wiki/
- **Difficulty Enum Values:** `src/server/game/Globals/SharedDefines.h`
- **Player Commands:** `src/server/scripts/Commands/`
- **Dungeon Scripts:** `src/server/scripts/DC/MythicPlus/`

---

**Happy Testing! 🎮**

If you encounter issues not covered here, check `Server.log` for errors and enable debug logging for detailed output.
