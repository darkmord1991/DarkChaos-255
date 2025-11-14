# Raid Difficulty System - Fix Explanation

## Problem Summary

The Raid MYTHIC difficulty enum values were changed to avoid collision with Dungeon MYTHIC:
- `RAID_DIFFICULTY_10MAN_MYTHIC` changed from **4** to **6**
- `RAID_DIFFICULTY_25MAN_MYTHIC` changed from **5** to **7**

This caused a mismatch between the difficulty values and the spawn system.

## How Spawning Works

The spawn system stores creatures in "slots" based on difficulty bit positions:

```cpp
// ObjectMgr.cpp - AddCreatureToGrid()
for (uint8 i = 0; mask != 0; i++, mask >>= 1)
{
    if (mask & 1)
    {
        // Stores creature at: _mapObjectGuidsStore[MAKE_PAIR32(mapId, i)]
        CellObjectGuids& cell_guids = _mapObjectGuidsStore[MAKE_PAIR32(data->mapid, i)][gridCoord.GetId()];
        cell_guids.creatures.insert(guid);
    }
}
```

This means:
- **Bit 0** (value 1) = Slot 0 = RAID_DIFFICULTY_10MAN_NORMAL
- **Bit 1** (value 2) = Slot 1 = RAID_DIFFICULTY_25MAN_NORMAL
- **Bit 2** (value 4) = Slot 2 = RAID_DIFFICULTY_10MAN_HEROIC
- **Bit 3** (value 8) = Slot 3 = RAID_DIFFICULTY_25MAN_HEROIC
- **Bit 6** (value 64) = Slot 6 = RAID_DIFFICULTY_10MAN_MYTHIC
- **Bit 7** (value 128) = Slot 7 = RAID_DIFFICULTY_25MAN_MYTHIC

## The Fix (Two Parts)

### Part 1: Code Fix (DBCStores.cpp)

Changed `GetDownscaledMapDifficultyData()` to **ALWAYS** update the difficulty reference when falling back:

```cpp
auto tryFallback = [&](Difficulty fallback) -> MapDifficulty const*
{
    MapDifficulty const* diff = GetMapDifficultyData(mapId, fallback);
    if (diff)
        difficulty = fallback;  // ALWAYS update difficulty for spawning to work
    return diff;
};
```

**Result:** When MYTHIC difficulty (6 or 7) is requested but not found, it falls back to HEROIC (2 or 3) and **updates the difficulty reference** so the spawn system looks in the correct slot.

### Part 2: SQL Documentation Fix

Updated `dc_clone_creature_spawns_for_difficulties.sql` to reflect correct bit values:

**OLD (WRONG):**
```sql
-- Bit 4 = RAID_DIFFICULTY_10MAN_MYTHIC (4)  -- INCORRECT
-- Bit 5 = RAID_DIFFICULTY_25MAN_MYTHIC (5)  -- INCORRECT
-- RAID_ALL = 1 | 2 | 4 | 8 | 16 | 32 = 63
UPDATE `creature` SET `spawnMask` = `spawnMask` | 48  -- WRONG
```

**NEW (CORRECT):**
```sql
-- Bit 6 = RAID_DIFFICULTY_10MAN_MYTHIC (6)  -- CORRECT
-- Bit 7 = RAID_DIFFICULTY_25MAN_MYTHIC (7)  -- CORRECT
-- RAID_ALL = 1 | 2 | 4 | 8 | 64 | 128 = 207
UPDATE `creature` SET `spawnMask` = `spawnMask` | 192  -- CORRECT (64 + 128)
```

## Current State

**With the code fix alone (without running the SQL):**
- ✅ Raids work correctly
- ✅ MYTHIC difficulties fallback to HEROIC
- ✅ Creatures spawn from slots 0-3 (Normal/Heroic)
- ✅ No Mythic-specific spawns possible

**If you also run the updated SQL (spawnMask | 192):**
- ✅ Raids work correctly
- ✅ MYTHIC difficulties fallback to HEROIC (still)
- ✅ Creatures spawn from slots 0-3 (Normal/Heroic)
- ✅ **FUTURE:** Can add Mythic-specific spawns in slots 6-7
- ✅ **FUTURE:** Can have different creatures/phases for Mythic difficulty

## Why Mythic Still Uses Heroic Spawns

The `MapDifficulty.dbc` file **does not have entries** for MYTHIC difficulties (6, 7). This is by design - Mythic difficulties are meant to use the same *map configuration* as Heroic, but with:
- Different scaling (handled by DungeonEnhancement C++ code)
- Potentially different spawns (requires setting spawnMask bits 6/7)
- Different loot tables
- Different mechanics (handled in scripts)

## Recommendations

### For Now (Quick Fix)
- ✅ **Done:** Code fix applied
- ⏭️ **Skip:** SQL updates (not needed yet)
- Result: Everything works, MYTHIC = scaled HEROIC

### For Future (True Mythic Content)
1. Run the updated SQL to set spawnMask bits 6 and 7
2. Clone specific creatures with spawnMask = 64 or 128 (Mythic-only)
3. Implement Mythic-specific mechanics in creature scripts
4. Add Mythic-specific loot tables

Example:
```sql
-- Clone a boss for Mythic-only with different AI
INSERT INTO `creature` 
SELECT guid+1000000, id1, ... , 64 as spawnMask, ...
FROM `creature` 
WHERE guid = [boss_guid] AND map = 631;  -- ICC boss
```

## Verification

Check current spawnMask values:
```sql
-- Should show bits 0-3 for Normal/Heroic
SELECT map, spawnMask, COUNT(*) 
FROM creature 
WHERE map IN (249, 631, 649)  -- Onyxia, ICC, ToC
GROUP BY map, spawnMask;
```

After running the updated SQL:
```sql
-- Should show bits 0-3 AND 6-7 (values include 64, 128, or both)
SELECT map, spawnMask, COUNT(*) 
FROM creature 
WHERE map IN (249, 631, 649)
GROUP BY map, spawnMask;
```

## Summary

**The spawn failure is FIXED** by updating the difficulty reference in the fallback logic. Raids now work correctly with existing spawnMask values (bits 0-3). The SQL update is **optional** and only needed for future Mythic-specific content.
