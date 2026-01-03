# Mythic+ Quick Reference Card
## DarkChaos-255 - Difficulty Commands

---

## 🎮 PLAYER COMMANDS

### Basic Commands
```
.dc difficulty info         Show current difficulty and options
.dc difficulty normal       Set Normal difficulty
.dc difficulty heroic       Set Heroic difficulty  
.dc difficulty mythic       Set Mythic difficulty (requires level 80)
```

### Examples
```bash
# Check your current difficulty
.dc difficulty info

# Change to Heroic before entering a dungeon
.dc difficulty heroic

# Switch to Mythic for challenging content
.dc difficulty mythic

# Go back to Normal
.dc difficulty normal
```

---

## 📊 DIFFICULTY BONUSES

| Difficulty | HP Bonus | Damage Bonus | Min Level | Min iLvl |
|------------|----------|--------------|-----------|----------|
| **Normal**  | Base     | Base         | Dungeon level | 0 |
| **Heroic**  | +15%     | +10%         | 70 (TBC), 80 (WotLK) | 120-140 |
| **Mythic**  | +35%     | +20%         | 80 | 180 |

---

## 🎯 TESTING WORKFLOW

### Quick Test Sequence
```bash
# 1. Set difficulty
.dc difficulty heroic

# 2. Teleport to dungeon
.tele utgardekeep

# 3. Enter dungeon
# Walk through portal

# 4. Check creature stats
# Target mob → .npc info

# 5. Exit and compare
.recall
.dc difficulty mythic
# Re-enter and compare stats
```

---

## ⚠️ IMPORTANT RULES

1. **Must exit instance** to change difficulty
2. **Only group leader** can change group difficulty
3. **Mythic requires level 80** minimum
4. **Difficulty persists** for your group
5. **Cannot change mid-combat** or in instance

---

## 🐛 COMMON ISSUES

### "Command not found"
→ Server not rebuilt. Run: `./acore.sh compiler build`

### "Cannot change difficulty while inside"
→ Exit instance first with `.recall`

### "Only group leader can change"
→ Correct behavior. Leader uses command, affects whole group

### Creatures not scaling
→ Check logs: `grep "Scaled creature" Server.log`

---

## 📝 GM TESTING COMMANDS

```bash
# Quick setup
.character level 80
.maxskill
.gm fly on
.gm visible off

# Teleport to dungeons
.tele utgardekeep
.tele hallsoflightning
.tele gundrak
.tele hallsofstone

# Check creature stats
.npc info
.creature info

# Debug
.debug play cinematic [id]
.debug play sound [id]
```

---

## 🚀 BUILD & RUN

```powershell
# Build
cd K:/Dark-Chaos/DarkChaos-255
./acore.sh compiler build

# Run
cd env/dist/bin
./worldserver.exe
```

---

## 📋 TEST CHECKLIST

Quick verification:
- [ ] `.dc difficulty info` works
- [ ] Can change to all 3 difficulties
- [ ] Group leader control works
- [ ] Mythic level requirement enforced
- [ ] Creatures scale properly
- [ ] No crashes or errors

---

## 📚 FILES TO CHECK

If something breaks:
- **Logs:** `env/dist/logs/Server.log`
- **Config:** `env/dist/etc/worldserver.conf`
- **Command:** `src/server/scripts/Commands/cs_dc_difficulty.cpp`
- **Scaling:** `src/server/scripts/DC/MythicPlus/MythicDifficultyScaling.cpp`
- **Portal:** `src/server/scripts/DC/MythicPlus/npc_dungeon_portal_selector.cpp`

---

**For full testing guide, see:** `TESTING_GUIDE.md`
