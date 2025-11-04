# Implementation Reference & Artifact System

**Date:** November 4, 2025  
**System:** DarkChaos Item Upgrade - Phase 1 Complete

---

## 🎯 Naming Conventions

### Database Tables (All use `dc_` prefix)

**World Database (`acore_world`):**
- `dc_item_upgrade_tiers` - Tier definitions
- `dc_item_upgrade_costs` - Upgrade token costs
- `dc_item_templates_upgrade` - Item mappings
- `dc_chaos_artifact_items` - Chaos artifact definitions (manually spawned by user)

**Character Database (`acore_characters`):**
- `dc_player_upgrade_tokens` - Player currency tracking
- `dc_player_item_upgrades` - Item upgrade state
- `dc_upgrade_transaction_log` - Audit trail
- `dc_player_artifact_discoveries` - Achievement tracking

### Currency Types
- `upgrade_token` - Used for T1-T4 (stored as ENUM in DB)
- `artifact_essence` - Used for T5 only (stored as ENUM in DB)

### C++ Namespaces
```cpp
namespace DarkChaos::ItemUpgrade
{
    class UpgradeManager
    class UpgradeManagerImpl
    
    enum UpgradeTier { TIER_LEVELING, TIER_HEROIC, TIER_RAID, TIER_MYTHIC, TIER_ARTIFACT }
    enum CurrencyType { CURRENCY_UPGRADE_TOKEN, CURRENCY_ARTIFACT_ESSENCE }
}
```

### Item IDs (Proposed)
- `50001` - Upgrade Token (quest item)
- `50002` - Artifact Essence (quest item)
- `50000-59999` - Tier 1 items (leveling)
- `60000-69999` - Tier 2 items (heroic)
- `70000-79999` - Tier 3 items (raid)
- `80000-89999` - Tier 4 items (mythic)
- `90000-99999` - Tier 5 items (artifacts)

### Folder Structure

```
Custom/Custom feature SQLs/
├─ chardb/ItemUpgrades/
│  └─ dc_item_upgrade_characters_schema.sql
└─ worlddb/ItemUpgrades/
   ├─ dc_item_upgrade_schema.sql
   ├─ dc_tier_configuration.sql
   └─ [Phase 2: Item generation files]

src/server/scripts/DC/ItemUpgrades/
├─ ItemUpgradeManager.h
├─ ItemUpgradeManager.cpp
└─ [Phase 2+: NPC, command, UI handlers]
```

---

## 🏆 Chaos Artifact System

### What Are Chaos Artifacts?

Chaos Artifacts are **special cosmetic prestige items** that players discover throughout the world. They:
- Use a separate currency (`artifact_essence`) for upgrades
- Have higher stat scaling (1.75 vs 1.5 multiplier)
- Provide cosmetic variants
- Are **manually spawned by you** as game objects

### Artifact Categories

**1. Zone Artifacts (56 total)**
- Scattered across 8 zones
- 7 artifacts per zone
- Players explore and find them
- One-time discovery per player

**2. Dungeon/Raid Artifacts (20 total)**
- Hidden in dungeon/raid instances
- Boss drops or hidden locations
- Higher rarity cosmetics
- Requires group content

**3. Cosmetic Variants (34 total)**
- Color variants
- Effect variants
- Gender-specific appearances
- Account-wide transmog

**Total: 110 artifacts per season**

### Example Artifact Setup

```sql
-- Example artifact entry
INSERT INTO dc_chaos_artifact_items 
(artifact_id, artifact_name, item_id, cosmetic_variant, rarity, location_name, location_type, essence_cost, season)
VALUES
(1, 'Artifact of Stormwind', 90001, 0, 4, 'Stormwind', 'zone', 250, 1),
(2, 'Twilight Artifact', 90002, 0, 4, 'Hinterlands', 'zone', 250, 1),
(3, 'Variant: Red Finish', 90001, 1, 4, 'Stormwind', 'zone', 250, 1);
```

### How to Spawn Artifacts

**You will manually create game objects for these. Example:**

```sql
-- Create a game object for an artifact
INSERT INTO gameobject (guid, id, map, spawnMask, position_x, position_y, position_z, orientation, rotation0, rotation1, rotation2, rotation3, spawntimesecs, animprogress, state)
VALUES 
(next_guid, object_id, 0, 1, 1000.5, 2000.5, 50.0, 0, 0, 0, 0, 1, 300, 0, 1);

-- Link to artifact through trigger or custom script
```

**Triggering Artifact Discovery:**
```cpp
// When player loots artifact object
sUpgradeManager()->DiscoverArtifact(player_guid, artifact_id);
sUpgradeManager()->AddCurrency(player_guid, CURRENCY_ARTIFACT_ESSENCE, 5, season);
// Plus achievement check if applicable
```

---

## 💾 Database Quick Reference

### Token System (2-Token Economy)

```sql
-- View player's tokens
SELECT player_guid, currency_type, amount 
FROM dc_player_upgrade_tokens 
WHERE player_guid = 1 AND season = 1;

-- Add tokens to player
INSERT INTO dc_player_upgrade_tokens VALUES (1, 'upgrade_token', 100, 1, NOW())
ON DUPLICATE KEY UPDATE amount = amount + 100;

-- Check total token cost for season
SELECT 
  tier_id,
  SUM(token_cost) as total_tokens_needed
FROM dc_item_upgrade_costs
GROUP BY tier_id;

-- Expected output:
-- Tier 1: 50 tokens total
-- Tier 2: 150 tokens total  
-- Tier 3: 375 tokens total
-- Tier 4: 750 tokens total
-- Tier 5: 0 tokens (uses essence)
```

### Item Tracking

```sql
-- View all upgrades for a player
SELECT 
  diu.item_guid,
  diu.tier_id,
  diu.upgrade_level,
  diu.tokens_invested,
  diu.stat_multiplier
FROM dc_player_item_upgrades diu
WHERE diu.player_guid = 1
ORDER BY diu.tier_id, diu.upgrade_level DESC;

-- Find max-upgraded items
SELECT * FROM dc_player_item_upgrades 
WHERE upgrade_level = 5;

-- Count items by tier for player
SELECT tier_id, COUNT(*) as count
FROM dc_player_item_upgrades
WHERE player_guid = 1
GROUP BY tier_id;
```

### Artifact Tracking

```sql
-- View all discovered artifacts for player
SELECT 
  pa.artifact_name,
  pa.location_type,
  pad.discovered_at
FROM dc_player_artifact_discoveries pad
JOIN dc_chaos_artifact_items pa ON pad.artifact_id = pa.artifact_id
WHERE pad.player_guid = 1
ORDER BY pad.discovered_at DESC;

-- Count by location
SELECT 
  pa.location_type,
  COUNT(*) as discovered_count
FROM dc_player_artifact_discoveries pad
JOIN dc_chaos_artifact_items pa ON pad.artifact_id = pa.artifact_id
WHERE pad.player_guid = 1
GROUP BY pa.location_type;
```

---

## 🔧 C++ API Reference

### Core Functions

```cpp
// Upgrade item
bool success = sUpgradeManager()->UpgradeItem(player_guid, item_guid);

// Manage currency
sUpgradeManager()->AddCurrency(player_guid, CURRENCY_UPGRADE_TOKEN, 100, season);
uint32 amount = sUpgradeManager()->GetCurrency(player_guid, CURRENCY_UPGRADE_TOKEN, season);
bool deducted = sUpgradeManager()->RemoveCurrency(player_guid, CURRENCY_UPGRADE_TOKEN, 50, season);

// Item state
ItemUpgradeState* state = sUpgradeManager()->GetItemUpgradeState(item_guid);
float multiplier = sUpgradeManager()->GetStatMultiplier(item_guid);
uint16 new_ilvl = sUpgradeManager()->GetUpgradedItemLevel(item_guid, base_ilvl);

// Costs
uint32 token_cost = sUpgradeManager()->GetUpgradeCost(tier_id, upgrade_level);
uint32 essence_cost = sUpgradeManager()->GetEssenceCost(tier_id, upgrade_level);

// Artifacts
bool discovered = sUpgradeManager()->DiscoverArtifact(player_guid, artifact_id);
PrestigeArtifact* artifact = sUpgradeManager()->GetArtifact(artifact_id);

// Database
sUpgradeManager()->LoadUpgradeData(season);
sUpgradeManager()->SaveItemUpgrade(item_guid);
```

---

## 📊 Data Flow Diagram

```
Player attempts upgrade
        ↓
Check currency (dc_player_upgrade_tokens)
        ↓
If insufficient → Fail and return
        ↓
Deduct tokens (UPDATE dc_player_upgrade_tokens)
        ↓
Update item state (INSERT/UPDATE dc_player_item_upgrades)
        ↓
Log transaction (INSERT dc_upgrade_transaction_log)
        ↓
Success + notify player
```

---

## 🎮 Planned NPC Interactions (Phase 3+)

### Upgrade Vendor NPC
```cpp
// NPC: "Upgrade Master"
// Dialog options:
1. "Upgrade my item" → Shows upgrade menu
2. "How does upgrading work?" → Explains system
3. "Tell me about artifacts" → Explains artifacts
4. "What are my tokens?" → Shows currency status
```

### Artifact Tracker NPC
```cpp
// NPC: "Artifact Curator"
// Dialog options:
1. "Show discovered artifacts" → Lists found artifacts
2. "Where do I find artifacts?" → Shows location hints
3. "Upgrade my artifact" → Similar to upgrade vendor
```

---

## ⚙️ Configuration Points

### Adjustable Values

```sql
-- Token costs (in dc_item_upgrade_costs)
-- Modify token_cost per tier/level

-- Artifact essence costs (in dc_item_upgrade_costs)
-- Modify essence_cost for tier 5

-- iLvL increases (in dc_item_upgrade_costs)
-- Modify ilvl_increase per upgrade

-- Tier activation (in dc_item_upgrade_tiers)
-- Set is_artifact = 1 for tier 5
```

### Dynamic Adjustments (No restart needed)

```cpp
// Modify costs in-memory
// Will be read from DB next load cycle
// Or implement cache invalidation
```

---

## 📝 Important Notes

### Prestige Artifact Naming
- Uses table: `dc_chaos_artifact_items`
- Field: `artifact_name` for display
- Field: `location_type` for categorization (zone/dungeon/raid/world)
- You create the actual game objects manually
- System tracks player discoveries

### Token Economy
- No weekly caps (simpler)
- All content gives same token type
- Higher tier = higher cost (natural gate)
- Easy to adjust drop rates if needed

### Cosmetic Variants
- One base item ID per artifact
- Multiple cosmetic_variant numbers (0, 1, 2, etc.)
- Each variant is a separate database row
- Player can collect all variants for transmog

### Season System
- All data keyed by season
- Season 2 items separate from Season 1
- Previous season items become cosmetic
- Easy to add new seasons

---

## ✅ Phase 1 Checklist

- [x] Database schema created (8 tables)
- [x] Tier configuration inserted
- [x] C++ interface designed
- [x] Implementation stubbed
- [x] Folder structure established
- [x] Naming conventions defined
- [x] Documentation complete

---

## 📖 Next: Execute SQL and Compile

1. Run Phase 1 SQL files
2. Verify table creation
3. Compile C++ code
4. Test database connectivity
5. Begin Phase 2 (item generation)

