# DarkChaos AoE Loot Extensions System

## Overview

The AoE Loot Extensions system enhances the base `ac_aoeloot` module with DarkChaos-specific features including quality filtering, automatic profession gathering, smart loot preferences, Mythic+ bonuses, and detailed statistics tracking.

**File Location:** `src/server/scripts/DC/dc_aoeloot_extensions.cpp`

---

## Feature Highlights

### 🎯 Quality Filtering
- Set minimum item quality threshold (Poor → Legendary)
- Automatically skip items below your preference
- Auto-vendor Poor quality items for instant gold
- Per-player customizable settings

### ⛏️ Profession Integration
- **Auto-Skin:** Automatically skin lootable corpses
- **Auto-Mine:** Gather nearby ore nodes after looting
- **Auto-Herb:** Collect nearby herbs after looting
- Configurable range for profession gathering
- Skill-level checks for gatherable resources

### 🧠 Smart Loot Preferences
- Prioritize items usable by your current spec
- Highlight equippable items
- Flag items that are direct upgrades
- Ignore specific item IDs you don't want

### ⚔️ Mythic+ Integration
- Increased loot range in M+ dungeons (1.5x default)
- Works with MythicPlusRunManager detection
- Configurable multiplier

### 📊 Detailed Statistics
- Total items looted
- Total gold collected
- Poor items auto-vendored
- Gold earned from auto-vendor
- Corpses skinned / nodes mined / herbs gathered
- Upgrades found

### 🔌 Client Addon Communication
- Syncs with `DC-AOESettings` client addon
- Real-time settings updates via `DCAOE` addon messages
- Settings persistence across sessions

---

## Chat Commands

| Command | Permission | Description |
|---------|------------|-------------|
| `.lootpref toggle` | Player | Enable/disable AoE Loot |
| `.lootpref quality <0-6>` | Player | Set minimum item quality (0=Poor to 6=Artifact) |
| `.lootpref skin` | Player | Toggle auto-skinning |
| `.lootpref smart` | Player | Toggle smart loot prioritization |
| `.lootpref ignore <itemId>` | Player | Add item to ignore list |
| `.lootpref unignore <itemId>` | Player | Remove item from ignore list |
| `.lootpref stats` | Player | View your detailed loot statistics |
| `.lootpref reload` | Admin | Reload configuration |

**Shortcut:** `.lp` can be used instead of `.lootpref`

---

## Configuration Options

Located in `darkchaos-custom.conf.dist` under **Section 1: AoE Loot System**

```ini
# Master toggle
AoELoot.Extensions.Enable = 1

# Quality Filtering
AoELoot.Extensions.QualityFilter.Enable = 0
AoELoot.Extensions.QualityFilter.MinQuality = 0    # 0=Poor
AoELoot.Extensions.QualityFilter.MaxQuality = 6    # 6=Artifact
AoELoot.Extensions.QualityFilter.AutoVendorPoor = 0

# Profession Integration
AoELoot.Extensions.Profession.AutoSkin = 1
AoELoot.Extensions.Profession.AutoMine = 1
AoELoot.Extensions.Profession.AutoHerb = 1
AoELoot.Extensions.Profession.Range = 10.0

# Smart Loot
AoELoot.Extensions.SmartLoot.PreferCurrentSpec = 1
AoELoot.Extensions.SmartLoot.PreferEquippable = 1
AoELoot.Extensions.SmartLoot.PrioritizeUpgrades = 1

# Mythic+ Bonus
AoELoot.Extensions.MythicPlus.Bonus = 1
AoELoot.Extensions.MythicPlus.RangeMultiplier = 1.5

# Raid Features
AoELoot.Extensions.Raid.Enable = 1
AoELoot.Extensions.Raid.MaxCorpses = 25

# Statistics
AoELoot.Extensions.TrackDetailedStats = 1
```

---

## SQL Database Tables

### `dc_aoeloot_preferences`
Stores per-player loot preferences.

```sql
CREATE TABLE IF NOT EXISTS `dc_aoeloot_preferences` (
    `player_guid` INT UNSIGNED NOT NULL,
    `aoe_enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `min_quality` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `auto_skin` TINYINT(1) NOT NULL DEFAULT 1,
    `smart_loot` TINYINT(1) NOT NULL DEFAULT 1,
    `auto_vendor_poor` TINYINT(1) NOT NULL DEFAULT 0,
    `ignored_items` TEXT DEFAULT NULL,
    PRIMARY KEY (`player_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### `dc_aoeloot_detailed_stats`
Tracks detailed loot statistics per player.

```sql
CREATE TABLE IF NOT EXISTS `dc_aoeloot_detailed_stats` (
    `player_guid` INT UNSIGNED NOT NULL,
    `total_items` INT UNSIGNED NOT NULL DEFAULT 0,
    `total_gold` INT UNSIGNED NOT NULL DEFAULT 0,
    `poor_vendored` INT UNSIGNED NOT NULL DEFAULT 0,
    `vendor_gold` INT UNSIGNED NOT NULL DEFAULT 0,
    `skinned` INT UNSIGNED NOT NULL DEFAULT 0,
    `mined` INT UNSIGNED NOT NULL DEFAULT 0,
    `herbed` INT UNSIGNED NOT NULL DEFAULT 0,
    `upgrades` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`player_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

---

## Client Addon Integration

### Addon: `DC-AOESettings`

The system communicates with the client addon using the `DCAOE` prefix:

| Message Type | Direction | Format |
|--------------|-----------|--------|
| `GET_SETTINGS` | Client → Server | Request current settings |
| `SETTINGS` | Server → Client | `enabled,minQuality,autoSkin,smartLoot,autoVendor,range` |
| `SAVE_SETTINGS` | Client → Server | Same format as SETTINGS |
| `SAVED` | Server → Client | Confirmation |
| `GET_STATS` | Client → Server | Request loot statistics |
| `STATS` | Server → Client | `totalItems,totalGold,vendorGold,upgrades` |

---

## Architecture

### Key Classes

| Class/Struct | Purpose |
|--------------|---------|
| `AoELootExtConfig` | Configuration singleton with Load() |
| `PlayerLootPreferences` | Per-player settings structure |
| `DetailedLootStats` | Statistics tracking per player |
| `DCAoELootExtPlayerScript` | Login/logout handlers, addon messaging |
| `DCAoELootExtCommandScript` | Chat command handlers |

### Helper Functions

| Function | Purpose |
|----------|---------|
| `IsInMythicPlusDungeon()` | Check if player is in M+ run |
| `IsItemUpgrade()` | Compare item to equipped gear |
| `ShouldAutoVendorItem()` | Check if item should be vendored |
| `CanPlayerSkinCreature()` | Skill check for skinning |
| `AutoSkinCreature()` | Perform automatic skinning |

---

## Integration Points

- **Base ac_aoeloot:** Hooks into core AoE loot system
- **MythicPlus Config:** Checks for M+ bonus range
- **LootMgr:** Generates skinning loot
- **Item Templates:** Quality and upgrade comparisons

---

## Future Improvements

### Short-term
- [ ] Add "loot all then vendor" mode for farming
- [ ] Visual feedback for upgrade items (special sound/glow)
- [ ] Configurable auto-skin delay for animation
- [ ] Per-creature-type ignore lists (e.g., ignore humanoids)

### Medium-term
- [ ] Integration with mail system (auto-mail vendor items)
- [ ] Loot value estimation in statistics
- [ ] Loot sharing with party members (trade range)
- [ ] "Loot wishlist" for specific items

### Long-term
- [ ] Machine learning for smart loot decisions
- [ ] Auction house price integration
- [ ] Cross-character statistics
- [ ] Loot history browser

---

## Quality Level Reference

| Value | Quality | Color |
|-------|---------|-------|
| 0 | Poor | Gray |
| 1 | Common | White |
| 2 | Uncommon | Green |
| 3 | Rare | Blue |
| 4 | Epic | Purple |
| 5 | Legendary | Orange |
| 6 | Artifact | Light Gold |

---

## Notes

- Preferences are loaded on login, saved on logout
- Statistics persist across sessions
- Auto-vendor requires Poor quality check to be enabled
- Profession gathering respects skill requirements
- M+ range bonus stacks with base AoE loot range
- Ignored items list is stored as comma-separated IDs
