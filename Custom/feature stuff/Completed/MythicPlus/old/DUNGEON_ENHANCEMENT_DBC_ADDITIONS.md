# Dungeon Enhancement System - DBC SQL Additions

## Overview
This document details the DBC entries added to support the Mythic+ Dungeon Enhancement System. These entries have been added to SQL files for conversion to DBC format.

---

## MapDifficulty.sql Additions

**File:** `Custom/CSV DBC/mapdifficulty.sql`

**Total Entries Added: 106** (8 Mythic+ + 98 comprehensive difficulty entries)

### Mythic+ Season 1 Dungeons (IDs 10001-10008)
Added 8 entries for Mythic+ difficulty (difficulty = 5):

| ID    | Map | Difficulty | maxPlayers | difficultyString               | Dungeon Name           |
|-------|-----|------------|------------|--------------------------------|------------------------|
| 10001 | 269 | 5          | 5          | DUNGEON_DIFFICULTY_MYTHIC_PLUS | Black Morass           |
| 10002 | 540 | 5          | 5          | DUNGEON_DIFFICULTY_MYTHIC_PLUS | Shattered Halls        |
| 10003 | 542 | 5          | 5          | DUNGEON_DIFFICULTY_MYTHIC_PLUS | Blood Furnace          |
| 10004 | 543 | 5          | 5          | DUNGEON_DIFFICULTY_MYTHIC_PLUS | Hellfire Ramparts      |
| 10005 | 545 | 5          | 5          | DUNGEON_DIFFICULTY_MYTHIC_PLUS | Steamvault             |
| 10006 | 546 | 5          | 5          | DUNGEON_DIFFICULTY_MYTHIC_PLUS | Underbog               |
| 10007 | 547 | 5          | 5          | DUNGEON_DIFFICULTY_MYTHIC_PLUS | Slave Pens             |
| 10008 | 574 | 5          | 5          | DUNGEON_DIFFICULTY_MYTHIC_PLUS | Utgarde Keep           |

### Complete Difficulty Coverage (IDs 20001-20098)

**98 new entries** covering all Vanilla, TBC, and WotLK content:

#### Vanilla Dungeons (38 entries)
- **19 Dungeons** with both Heroic (difficulty=1) and Mythic (difficulty=5):
  - Ragefire Chasm, Wailing Caverns, Deadmines, Shadowfang Keep
  - Blackfathom Deeps, Stormwind Stockade, Gnomeregan
  - Razorfen Kraul, Scarlet Monastery, Razorfen Downs
  - Uldaman, Zul'Farrak, Maraudon, Sunken Temple
  - Blackrock Depths, Lower Blackrock Spire, Dire Maul
  - Scholomance, Stratholme

#### Vanilla Raids (11 entries)
- **Molten Core, Blackwing Lair, AQ Temple** - Heroic (40-player) + Mythic (10-player)
- **Ruins of AQ, Zul'Gurub** - Heroic (20-player) + Mythic (10-player)
- **Onyxia's Lair** - Mythic only (10-player)

#### TBC Dungeons (16 entries - Mythic only, already have Heroic)
- Hellfire Ramparts, Blood Furnace, Slave Pens, Underbog
- Mana-Tombs, Auchenai Crypts, Sethekk Halls, Shadow Labyrinth
- Old Hillsbrad, Black Morass, Steamvault, Shattered Halls
- Mechanar, Botanica, Arcatraz, Magisters' Terrace

#### TBC Raids (18 entries)
- **Karazhan** - Heroic (10-player) + Mythic (10-player)
- **Gruul's Lair, Magtheridon, SSC, Tempest Keep** - Heroic (25-player) + Mythic (10-player)
- **Mount Hyjal, Black Temple** - Heroic (25-player) + Mythic (10-player)
- **Zul'Aman, Sunwell Plateau** - Heroic + Mythic (10-player)

#### WotLK Dungeons (15 entries - Mythic only, already have Heroic)
- Utgarde Keep, Utgarde Pinnacle, Nexus, Azjol-Nerub
- Ahn'kahet, Drak'Tharon Keep, Violet Hold, Gundrak
- Halls of Stone, Halls of Lightning, Culling of Stratholme
- Trial of the Champion, Forge of Souls, Pit of Saron, Halls of Reflection

### Difficulty Key:
- **0** = Normal
- **1** = Heroic
- **4** = Mythic (WotLK standard)
- **5** = Mythic+ (scaling keystone system)

---

## Spell.sql Additions

**File:** `Custom/CSV DBC/spell.sql`

Added 3 custom spells for Mythic+ affixes:

### Spell ID 800010 - Bolstering
**Type:** Stacking Buff Aura  
**Visual ID:** 6155 (Purple swirl effect)  
**Icon ID:** 2912

**Effects:**
- **Effect 1:** Aura (Type 4) - Increases health by 20%
- **Effect 2:** Aura (Type 137) - Increases damage by 20%
- **Duration:** Permanent (DurationIndex 21)
- **Max Stacks:** 99
- **Description:** "Increases health and damage by 20%. Stacks."

**Technical Details:**
```sql
ID: 800010
Dispel: 0 (Cannot be dispelled)
DurationIndex: 21 (Permanent)
StackAmount: 99
Effect1: 6 (APPLY_AURA)
Effect2: 6 (APPLY_AURA)
EffectApplyAuraName1: 4 (SPELL_AURA_MOD_INCREASE_HEALTH)
EffectApplyAuraName2: 137 (SPELL_AURA_MOD_DAMAGE_PERCENT_DONE)
EffectBasePoints1: 19 (+20%)
EffectBasePoints2: 19 (+20%)
SpellVisual1: 6155
SchoolMask: 1 (Physical)
```

---

### Spell ID 800020 - Necrotic Wound
**Type:** Periodic Damage + Healing Reduction  
**Visual ID:** 5938 (Skull icon)  
**Icon ID:** 2175

**Effects:**
- **Effect 1:** Periodic Shadow Damage (100 damage per tick)
- **Effect 2:** Healing Received Reduction (-50%)
- **Duration:** Permanent (DurationIndex 21)
- **Tick Rate:** Every 3 seconds
- **Max Stacks:** 99
- **Dispel:** Disease (DispelType 1)
- **Description:** "Inflicts Shadow damage every 3 seconds and reduces healing received by 50%. Stacks."

**Technical Details:**
```sql
ID: 800020
Dispel: 1 (Disease)
DurationIndex: 21 (Permanent)
StackAmount: 99
Effect1: 6 (APPLY_AURA)
Effect2: 6 (APPLY_AURA)
EffectApplyAuraName1: 3 (SPELL_AURA_PERIODIC_DAMAGE)
EffectApplyAuraName2: 137 (SPELL_AURA_MOD_HEALING_PCT)
EffectBasePoints1: 99 (100 damage)
EffectBasePoints2: -51 (-50% healing)
EffectAmplitude1: 3000 (3 seconds)
EffectAmplitude2: 3000 (3 seconds)
SpellVisual1: 5938
SchoolMask: 32 (Shadow)
```

---

### Spell ID 800030 - Grievous Wound
**Type:** Periodic % Health Damage  
**Visual ID:** 7391 (Bleeding effect)  
**Icon ID:** 2912

**Effects:**
- **Effect 1:** Periodic Physical Damage (2% max health per tick)
- **Duration:** Permanent (DurationIndex 21)
- **Tick Rate:** Every 2 seconds
- **Max Stacks:** 10
- **Auto-Remove:** When health > 90% (handled by C++ code)
- **Description:** "Inflicts Physical damage equal to 2% of max health every 2 seconds. Stacks up to 10 times. Removed when health is above 90%."

**Technical Details:**
```sql
ID: 800030
Dispel: 0 (Cannot be dispelled)
DurationIndex: 21 (Permanent)
StackAmount: 10
Effect1: 6 (APPLY_AURA)
EffectApplyAuraName1: 3 (SPELL_AURA_PERIODIC_DAMAGE)
EffectBasePoints1: 1 (2% calculated in C++)
EffectAmplitude1: 2000 (2 seconds)
SpellVisual1: 7391
SchoolMask: 1 (Physical)
```

---

## Integration with C++ Code

### Affix Application (AffixManager.cpp)
The spells are applied via `Unit::AddAura()`:

```cpp
// Bolstering - Applied to non-boss enemies
player->CastSpell(creature, 800010, true);

// Necrotic - Applied on melee hit
attacker->CastSpell(victim, 800020, true);

// Grievous - Applied when health < 90%
if (healthPct < 90.0f)
    player->CastSpell(player, 800030, true);
```

### Affix Removal Logic
- **Bolstering:** Removed on creature death
- **Necrotic:** Dispellable as Disease, or cleared at dungeon end
- **Grievous:** Auto-removed in AffixManager::UpdateGrievousWounds() when health > 90%

---

## Conversion to DBC

### Steps to Convert:
1. Execute `mapdifficulty.sql` on your DBC database
2. Execute `spell.sql` on your DBC database
3. Use your DBC converter tool (e.g., `MySQLToWDBX`) to export:
   - `MapDifficulty.dbc`
   - `Spell.dbc`
4. Place converted `.dbc` files in `data/dbc/`
5. Restart server to load new DBC data

### Verification Commands:
```sql
-- Verify MapDifficulty entries
SELECT * FROM mapdifficulty WHERE ID >= 10001 AND ID <= 10008;

-- Verify Spell entries
SELECT ID, SpellName0, SpellDescription0 FROM spell WHERE ID IN (800010, 800020, 800030);
```

---

## Testing Checklist

### MapDifficulty Testing:
- [ ] Server loads without DBC errors
- [ ] Mythic+ dungeons are accessible
- [ ] Difficulty scaling applies correctly
- [ ] 5-player limit enforced

### Spell Testing:
- [ ] Bolstering appears with purple visual on kill
- [ ] Bolstering stacks correctly (+20% per stack)
- [ ] Necrotic Wound shows skull icon
- [ ] Necrotic reduces healing by 50%
- [ ] Necrotic is dispellable as Disease
- [ ] Grievous Wound shows bleeding effect
- [ ] Grievous ticks every 2 seconds for 2% max HP
- [ ] Grievous auto-removes at 90%+ health
- [ ] All spells show correct tooltips in-game

---

## Troubleshooting

### Issue: DBC doesn't load
**Solution:** Verify SQL syntax, ensure no duplicate IDs, check converter tool output

### Issue: Spells don't appear in-game
**Solution:** Confirm spell IDs match C++ code, verify DBC cache cleared, restart server

### Issue: Wrong visual effects
**Solution:** Check SpellVisual1 ID in spell.sql, verify client DBC files match server

### Issue: Stacking not working
**Solution:** Verify StackAmount field, check AttributesEx flags

---

## Related Files

- **C++ Implementation:**
  - `src/server/scripts/DungeonEnhancement/Affixes/AffixManager.cpp`
  - `src/server/scripts/DungeonEnhancement/Affixes/AffixManager.h`

- **Database:**
  - `Custom/CSV DBC/mapdifficulty.sql` (8 entries added)
  - `Custom/CSV DBC/spell.sql` (3 entries added)

- **Documentation:**
  - `Custom/DUNGEON_ENHANCEMENT_COMPLETE.md`
  - This file: `Custom/DUNGEON_ENHANCEMENT_DBC_ADDITIONS.md`

---

## Notes

- **Difficulty ID 5** is custom and must match `DUNGEON_DIFFICULTY_MYTHIC_PLUS` enum in C++ code
- **Spell IDs 800010-800030** are in custom range to avoid conflicts with official spells
- **Visual IDs** are from existing WotLK spell effects for client compatibility
- **EffectBasePoints** values are 1 less than actual (e.g., 19 = +20%)
- **DurationIndex 21** = permanent duration, manually removed by code
- **SchoolMask** determines damage type: 1=Physical, 32=Shadow

---

**Last Updated:** November 13, 2025  
**System Version:** 1.0.0  
**Author:** Dark Chaos Development Team
