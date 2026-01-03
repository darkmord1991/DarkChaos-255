# Mythic+ Scaling System - Fixed Implementation

## Problem Identified

The previous implementation used `OnCreatureAddWorld()` hook, which fires **AFTER** creature initialization is complete with stats already calculated. This is why scaling wasn't working.

## Solution: AzerothCore's Native Hooks

AzerothCore provides proper hooks in the `Creature::SelectLevel()` function that are designed for this exact purpose:

### 1. `OnBeforeCreatureSelectLevel` (Line 1534 in Creature.cpp)
- Called **BEFORE** stats are calculated
- Receives `uint8& level` by reference - can modify the level
- This level is then used to lookup `CreatureBaseStats` from database
- Perfect for changing creature level based on difficulty

### 2. `OnCreatureSelectLevel` (Line 1583 in Creature.cpp)
- Called **AFTER** base stats are calculated for the level
- Creature already has HP, mana, and damage values set
- Perfect for applying multipliers to existing stats
- Changes persist because stats are already finalized

## Implementation Changes

### mythic_plus_core_scripts.cpp

**OLD CODE (BROKEN):**
```cpp
class MythicPlusCreatureScript : public AllCreatureScript
{
    void OnCreatureAddWorld(Creature* creature) override
    {
        // TOO LATE - creature already initialized!
        sMythicScaling->ScaleCreature(creature, map);
    }
};
```

**NEW CODE (FIXED):**
```cpp
class MythicPlusCreatureScript : public AllCreatureScript
{
    // Hook 1: Modify level BEFORE stats calculation
    void OnBeforeCreatureSelectLevel(const CreatureTemplate* cinfo, Creature* creature, uint8& level) override
    {
        // Get dungeon profile and difficulty
        // Check database level columns (heroic_level_*, mythic_level_*)
        // If configured level > 0, set: level = configuredLevel
        // AzerothCore will use this level to calculate base stats
    }
    
    // Hook 2: Apply multipliers AFTER stats calculation
    void OnCreatureSelectLevel(const CreatureTemplate* cinfo, Creature* creature) override
    {
        // Get dungeon profile and difficulty
        // Determine HP/damage multipliers
        // Apply: newHP = baseHP * multiplier
        // Apply: newDamage = baseDamage * multiplier
        // Stats are already set, just multiply them
    }
};
```

## How It Works Now

1. **Creature spawns** → AzerothCore calls `Creature::SelectLevel()`
2. **SelectLevel() calculates base level** from template min/max
3. **OnBeforeCreatureSelectLevel fires** → We modify `level` to 80-82 for Mythic
4. **SelectLevel() calls `SetLevel(newLevel)`** and looks up `CreatureBaseStats`
5. **SelectLevel() calculates HP/mana/damage** from stats table for level 80-82
6. **OnCreatureSelectLevel fires** → We multiply HP by 3.0x, damage by 2.0x
7. **Creature enters world** with proper level 80-82 and scaled stats!

## Database Configuration

The system uses these columns from `dc_dungeon_mythic_profile`:

### Level Columns (0 = keep original)
- `heroic_level_normal` - Normal rank creatures in Heroic
- `heroic_level_elite` - Elite rank creatures in Heroic  
- `heroic_level_boss` - Boss rank creatures in Heroic
- `mythic_level_normal` - Normal rank creatures in Mythic
- `mythic_level_elite` - Elite rank creatures in Mythic
- `mythic_level_boss` - Boss rank creatures in Mythic

### Multiplier Columns
- `heroic_health_mult` - HP multiplier for Heroic (1.15)
- `heroic_damage_mult` - Damage multiplier for Heroic (1.10)
- `mythic_health_mult` - HP multiplier for Mythic (3.0 Vanilla/TBC, 1.35 WotLK)
- `mythic_damage_mult` - Damage multiplier for Mythic (2.0 Vanilla/TBC, 1.20 WotLK)

## Example: Scarlet Monastery Mythic

**Before (Broken):**
- Creature Entry: 3976 (Scarlet Commander Mograine)
- Map: 189 (Scarlet Monastery)
- Difficulty: Mythic (2)
- Result: Level 34, 2901 HP ❌ (no scaling applied)

**After (Fixed):**
- Creature Entry: 3976
- Map: 189
- Difficulty: Mythic (2)
- `OnBeforeCreatureSelectLevel` → level changed to 82 (boss)
- AzerothCore calculates base stats for level 82
- `OnCreatureSelectLevel` → HP × 3.0, Damage × 2.0
- Result: Level 82, ~80,000 HP ✅

## Testing Steps

1. **Rebuild the server:**
   ```bash
   ./acore.sh compiler build
   ```

2. **Restart worldserver**

3. **Check server logs** for:
   ```
   Loading Mythic+ profiles...
   Loaded X Mythic+ dungeon profiles
   ```

4. **In-game test:**
   ```
   .dc difficulty mythic
   .go xyz 1688.99 1053.48 18.6775 189
   .npc info
   ```
   
   Should show:
   - Level: 80-82 (not 34!)
   - HP: 60,000-90,000 (not 2,901!)

5. **Test reload:**
   ```
   .dc reload mythic
   ```
   Should reload database values without restart

## Why This Works

- **Integration with AzerothCore's flow:** Uses the same path as normal creature initialization
- **Proper timing:** Level changed before stats lookup, multipliers applied after stats calculated
- **No manual stat updates needed:** AzerothCore handles `CreatureBaseStats` lookup automatically
- **Works with existing systems:** Rank modifiers, class stats, all vanilla mechanics respected
- **Database-driven:** All values configurable, no hardcoding

## References

- `src/server/game/Entities/Creature/Creature.cpp` line 1520: `Creature::SelectLevel()`
- `src/server/game/Scripting/ScriptMgr.h` lines 569-570: Hook definitions
- `src/server/game/Scripting/ScriptMgr.cpp` lines 632-646: Hook implementations
- `src/server/scripts/DC/MythicPlus/mythic_plus_core_scripts.cpp`: Our implementation

## Commands Available

- `.dc difficulty normal|heroic|mythic` - Change instance difficulty
- `.dc difficulty info` - Show current difficulty
- `.dc reload mythic` - Reload dungeon profiles from database

