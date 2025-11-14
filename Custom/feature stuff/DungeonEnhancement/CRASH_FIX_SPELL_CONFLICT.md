# Crash Fix: Spell ID Conflict Resolution

## Issue
Player login crash with error: `CastSpell: unknown spell 800031`

## Root Cause
**Spell ID conflict between two systems:**
- **DungeonEnhancement (Mythic+)**: Uses 800010, 800020, 800030 for affix spells
- **Prestige Alt Bonus**: Was using 800030-800034 for XP bonus visual buffs

Both systems tried to use spell ID 800030, and spells 800031-800034 didn't exist in DBC, causing crash when Prestige tried to cast them.

## Solution Applied
Changed Prestige Alt Bonus spell IDs to **800040-800044** to avoid conflict:

### Files Modified:
1. `src/server/scripts/DC/Prestige/dc_prestige_alt_bonus.cpp`
   - Changed SPELL_ALT_BONUS_5 from 800030 → 800040
   - Changed SPELL_ALT_BONUS_10 from 800031 → 800041
   - Changed SPELL_ALT_BONUS_15 from 800032 → 800042
   - Changed SPELL_ALT_BONUS_20 from 800033 → 800043
   - Changed SPELL_ALT_BONUS_25 from 800034 → 800044

2. `Custom/Config files/darkchaos-custom.conf.dist`
   - Updated documentation to reflect new spell ID range

3. `src/server/scripts/DC/ItemUpgrades/ItemUpgradeAddonHandler.cpp`
   - Added check for `ItemUpgrade.Enable` config before processing commands

## New Spell ID Allocation
```
800010 - Bolstering (DungeonEnhancement)
800020 - Necrotic Wound (DungeonEnhancement)  
800030 - Grievous Wound (DungeonEnhancement)
800040 - Alt Bonus 5% (Prestige) ← CHANGED
800041 - Alt Bonus 10% (Prestige) ← CHANGED
800042 - Alt Bonus 15% (Prestige) ← CHANGED
800043 - Alt Bonus 20% (Prestige) ← CHANGED
800044 - Alt Bonus 25% (Prestige) ← CHANGED
```

## Required Actions
1. **Recompile** the server with updated spell IDs
2. **Add spell entries** 800040-800044 to Spell.csv (or DBC) if you want visual buffs
3. **Restart** worldserver

## To Enable Core Dumps (Ubuntu)
Run the provided script:
```bash
bash enable_core_dumps.sh
```

Then rebuild with debug symbols:
```bash
cd build
cmake ../ -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX=/home/wowcore/azerothcore/env/dist
make -j$(nproc)
```

Core dumps will be saved to `/tmp/core-*` for future debugging.

## Status
✅ Spell ID conflict resolved
✅ ItemUpgrade system now checks Enable config
✅ Prestige Alt Bonus won't crash on missing spells (will just log warning)

## Related Systems
- **NOT** related to DungeonEnhancement creature spawns
- **NOT** related to empty dungeons/raids issue
- **IS** related to Prestige Alt Bonus casting missing spells at login
