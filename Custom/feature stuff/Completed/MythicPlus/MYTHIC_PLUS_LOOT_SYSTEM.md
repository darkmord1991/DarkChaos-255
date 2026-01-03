# Mythic+ Boss Loot System

## Overview

The Mythic+ boss loot system provides **retail-like spec-based rewards** for completing Mythic+ dungeons. Each boss kill generates items appropriate for participating players' classes and specializations.

## Features

### Spec-Based Loot Generation
- ✅ Automatically filters items by player's class, spec, and armor type
- ✅ Uses existing `dc_vault_loot_table` with 308+ items
- ✅ Respects role-based restrictions (Tank/Healer/DPS)
- ✅ Item level scales with keystone level (retail formula)

### Item Level Scaling
**Formula:**
```
Keystone Level 1-10:  Base + (Level × 3)
Keystone Level 11+:   Base + (30) + ((Level - 10) × 4)
```

**Example (Base ilvl 226):**
- +2 Key: 232 ilvl
- +5 Key: 241 ilvl
- +10 Key: 256 ilvl
- +15 Key: 276 ilvl
- +20 Key: 296 ilvl

### Loot Distribution
- **Normal Bosses:** 1 item per kill
- **Final Boss:** 2 items per kill
- Personal loot style (each player eligible for their spec)
- Items added to boss loot table (lootable from corpse)

## Database Integration

### Loot Table Structure
Uses existing `dc_vault_loot_table`:
```sql
CREATE TABLE dc_vault_loot_table (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    item_id INT UNSIGNED NOT NULL,
    class_mask INT UNSIGNED DEFAULT 1023,  -- Bitmask for classes
    spec_name VARCHAR(50) DEFAULT NULL,     -- Spec restriction
    armor_type VARCHAR(20) DEFAULT 'Misc',  -- Plate/Mail/Leather/Cloth
    role_mask TINYINT UNSIGNED DEFAULT 7,   -- Tank/Healer/DPS (1/2/4)
    item_level_min INT UNSIGNED DEFAULT 200,
    item_level_max INT UNSIGNED DEFAULT 300
);
```

### Boss Tracking
Uses core `instance_encounters` table:
```sql
SELECT COUNT(*) FROM instance_encounters WHERE mapId = ?
```

Fallback to hardcoded boss counts if table empty.

## Configuration

### worldserver.conf / mythicplus.conf
```ini
# Enable boss loot generation
MythicPlus.BossLoot.Enabled = 1

# Base item level for M+0
MythicPlus.BaseItemLevel = 226

# Loot mode (0=Personal, 1=Group)
MythicPlus.LootMode = 0
```

## Implementation Details

### Code Files
1. **MythicPlusLootGenerator.cpp** - Core loot generation logic
2. **MythicPlusRunManager.cpp** - Integration with boss death handler
3. **vault_rewards.cpp** - Spec detection and filtering (reused)

### Key Functions

#### `GenerateBossLoot(Creature* boss, Map* map, InstanceState* state)`
Main entry point called on each boss death. Handles:
- Keystone level to item level conversion
- Player eligibility checking
- Spec/class/role filtering
- Item generation and addition to loot

#### `GetPlayerSpecForLoot(Player* player)`
Returns player's talent spec:
- Warriors: Arms, Fury, Protection
- Paladins: Holy, Protection, Retribution
- Death Knights: Blood, Frost, Unholy
- Etc. (all 10 classes supported)

#### `GetPlayerArmorTypeForLoot(Player* player)`
Returns armor class:
- Plate: Warrior, Paladin, DK
- Mail: Hunter, Shaman
- Leather: Rogue, Druid
- Cloth: Priest, Mage, Warlock

#### `GetPlayerRoleMask(Player* player)`
Returns role bitmask:
- 1 = Tank
- 2 = Healer
- 4 = DPS
- 5 = Tank + DPS (Feral Druid)
- 7 = Universal

#### `GetItemLevelForKeystoneLevel(uint8 level)`
Calculates target item level using retail formula.

#### `GetTotalBossesForDungeon(uint32 mapId)`
Queries `instance_encounters` table, falls back to hardcoded values.

## SQL Migration

### Fix Missing Column Error
```sql
-- Add missing 'last_updated' column to dc_player_keystones
ALTER TABLE dc_player_keystones 
ADD COLUMN last_updated INT UNSIGNED NOT NULL DEFAULT 0 
COMMENT 'Unix timestamp of last keystone update' 
AFTER expires_on;

UPDATE dc_player_keystones 
SET last_updated = UNIX_TIMESTAMP() 
WHERE last_updated = 0;
```

## Player Experience

### Boss Kill Flow
1. Boss dies in Mythic+ dungeon
2. System calculates item level based on keystone level
3. Randomly selects eligible players (1 for normal boss, 2 for final boss)
4. Queries `dc_vault_loot_table` filtering by:
   - Player's class (class_mask)
   - Player's spec (spec_name)
   - Player's armor type (armor_type)
   - Player's role (role_mask)
   - Target item level range
5. Adds item to boss loot table
6. Sends notification to player
7. Player loots item from boss corpse

### Chat Notifications
```
[Mythic+] Boss defeated: Ingvar the Plunderer (3/4)
[Mythic+] Ingvar the Plunderer dropped: [Bracers of the Dark Mother] (ilvl 241)
```

## Testing Checklist

- [ ] Verify spec detection works for all 10 classes
- [ ] Confirm armor type filtering (Plate/Mail/Leather/Cloth)
- [ ] Test item level scaling formula (compare to retail)
- [ ] Verify role-based restrictions (Tank/Healer/DPS items)
- [ ] Test normal boss loot (1 item)
- [ ] Test final boss loot (2 items)
- [ ] Confirm items appear in boss loot window
- [ ] Verify SQL migration fixes crash
- [ ] Test with empty `dc_vault_loot_table`
- [ ] Test fallback boss count system

## Troubleshooting

### No Items Generated
**Symptom:** Boss dies but no loot appears  
**Causes:**
1. `MythicPlus.BossLoot.Enabled` is disabled
2. `dc_vault_loot_table` is empty
3. No items match player's class/spec/ilvl range

**Solutions:**
1. Enable in config: `MythicPlus.BossLoot.Enabled = 1`
2. Populate loot table with appropriate items
3. Check logs for filtering mismatches

### SQL Error: Unknown column 'last_updated'
**Symptom:** Server crashes after boss death with SQL error  
**Solution:** Apply SQL migration:
```bash
mysql -u root -p world < data/sql/updates/db_world/2025_01_XX_add_last_updated_column.sql
```

### Wrong Item Level
**Symptom:** Items have incorrect ilvl  
**Causes:**
1. `MythicPlus.BaseItemLevel` config wrong
2. Item scaling not applied

**Solutions:**
1. Check config value (default: 226)
2. Verify scaling formula in logs

### Items for Wrong Spec
**Symptom:** Player receives gear for different spec  
**Causes:**
1. Spec detection incorrect
2. `dc_vault_loot_table` has wrong spec_name values
3. Player using hybrid spec (Feral = Tank + DPS)

**Solutions:**
1. Check `GetPlayerSpecForLoot()` return value
2. Verify table spec_name matches: "Arms", "Holy", "Blood", etc.
3. Ensure role_mask includes both roles for hybrids

## Future Enhancements

- [ ] Add group loot mode (tradeable items)
- [ ] Implement bonus roll system
- [ ] Add weekly chest integration
- [ ] Support for tier sets
- [ ] Duplicate item protection
- [ ] Item level upgrade system
- [ ] Valor point equivalent

## References

- **Retail M+ Loot:** https://wowpedia.fandom.com/wiki/Mythic_Plus
- **Item Level Scaling:** https://www.wowhead.com/guides/mythic-plus-dungeons
- **Spec Detection:** Based on AzerothCore talent tree system
- **Loot Tables:** Custom DarkChaos-255 implementation
