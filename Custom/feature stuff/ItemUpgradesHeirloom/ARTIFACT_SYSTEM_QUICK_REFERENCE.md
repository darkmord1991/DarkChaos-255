# 📋 ARTIFACT SYSTEM - QUICK REFERENCE GUIDE

**One-page reference for developers implementing the artifact system**

---

## 🎯 CORE CONCEPT

**Hybrid System:** Heirloom Scaling (auto-level) + ItemUpgrade (essence progression) + Enchants (secondary stats)

```
ARTIFACT = Heirloom Item + Tier 5 Upgrade + Dynamic Enchant
```

---

## 📊 KEY NUMBERS

| Metric | Value | Notes |
|--------|-------|-------|
| Artifact Tier | 5 | Highest tier (exclusive to artifacts) |
| Max Upgrade Level | 15 | Final progression point |
| Min Essence Cost | 500 | Upgrade 0→1 |
| Max Essence Cost | 4,000 | Upgrade 14→15 |
| Total to Max | 30,250 | Cumulative cost to level 15 |
| Heirloom Cap | 4.0x | Max multiplier at level 255 |
| Final Stat Bonus | 1.75x | At max upgrade (75% bonus) |
| Item Quality | 7 | HEIRLOOM (required flag) |
| Essence Item ID | 200001 | Currency item entry |
| Base Enchant ID | 80000 | Encodes tier+level |

---

## 🗄️ DATABASE TABLES

### Quick Schema Reference

```sql
-- Create these 3 new tables:
artifact_items              -- Define artifacts
artifact_loot_locations    -- Where to find them
player_artifact_data       -- Progress tracking

-- Modify these existing tables:
dc_item_upgrade_costs      -- Add Tier 5 costs
item_template              -- Create artifact items
spell_bonus_data           -- Enchant multipliers
```

### Essential Queries

```sql
-- Add artifact weapon
INSERT INTO artifact_items VALUES
  (1, 191001, 'WEAPON', 'Worldforged Claymore', '...', 5, 15, 200001, 1);

-- Add tier 5 costs
INSERT INTO dc_item_upgrade_costs VALUES
  (5, 1, 0, 500, 0), (5, 2, 0, 750, 0), ...

-- Check player progress
SELECT * FROM player_artifact_data WHERE player_guid = <guid>;

-- Get artifact metadata
SELECT * FROM artifact_items WHERE is_active = 1;
```

---

## 🔧 C++ INTEGRATION

### Key Files to Create/Modify

```
CREATE: src/server/scripts/DC/Artifacts/ArtifactManager.h
CREATE: src/server/scripts/DC/Artifacts/ArtifactManager.cpp
CREATE: src/server/scripts/DC/Artifacts/ArtifactEquipScript.cpp
MODIFY: src/server/scripts/DC/ItemUpgrades/ItemUpgradeAddonHandler.cpp
```

### Critical Functions

```cpp
// Load artifacts from DB
void ArtifactManager::LoadArtifacts();

// Handle upgrade
bool ArtifactManager::UpgradeArtifact(uint32 player_guid, uint32 artifact_id);

// Apply enchant on equip
void ArtifactManager::ApplyArtifactEnchant(Player* player, Item* item, uint8 level);

// Calculate enchant ID
uint32 CalculateUpgradeEnchantId(uint8 tier_id, uint8 level)
  = 80000 + (tier_id * 100) + level
```

### Script Hooks

```cpp
// Hook when item equipped
void OnPlayerEquip(Player* player, Item* item, ...)
  → Check: Is artifact? Get upgrade_level → Apply enchant

// Hook when item unequipped
void OnPlayerUnequip(Player* player, Item* item, ...)
  → Remove enchant from TEMP_ENCHANTMENT_SLOT

// Hook on character login
void OnPlayerLogin(Player* player)
  → Restore artifact enchants if equipped
```

---

## 🎮 ADDON UI

### Artifact Detection

```lua
local function IsArtifactItem(item)
  return item and item.tier == 5
end
```

### Display Format

```
[ARTIFACT] Worldforged Claymore
├─ Essence Invested: 2,500 / 30,250 (8.3%)
├─ Upgrade Level: 5 / 15
├─ All Stats: +12.5%
├─ Primary Stats: Auto-scaling (player level)
└─ Next Upgrade: 1,500 essence required
```

### Tooltip Enhancement

```lua
-- Show artifact-specific info
if IsArtifactItem(item) then
  tooltip:AddLine("|cffff8000[ARTIFACT]|r", 1.0, 0.5, 0.0)
  tooltip:AddLine(essenceDisplay)
  tooltip:AddLine(upgradeDisplay)
end
```

---

## 🔄 WORKFLOW CHECKLIST

### Database Phase (30 min)

- [ ] Create artifact_items table
- [ ] Create artifact_loot_locations table
- [ ] Create player_artifact_data table
- [ ] Add Tier 5 to dc_item_upgrade_costs
- [ ] Create essence item (200001)
- [ ] Insert sample artifacts

### Code Phase (2 hours)

- [ ] Copy ArtifactManager.h/.cpp
- [ ] Create ArtifactEquipScript.cpp
- [ ] Register scripts in script loader
- [ ] Compile and verify no errors

### Integration Phase (1 hour)

- [ ] Hook ItemUpgrade handler for Tier 5
- [ ] Test essence cost retrieval
- [ ] Verify enchant ID calculation
- [ ] Test enchant application

### Addon Phase (1 hour)

- [ ] Add artifact detection
- [ ] Update tooltip display
- [ ] Add essence cost display
- [ ] Test UI rendering

### Testing Phase (2-3 hours)

- [ ] Loot artifact item
- [ ] Verify heirloom scaling
- [ ] Upgrade and check enchant
- [ ] Level up and recheck stats
- [ ] Balance essence costs

---

## ⚡ STAT CALCULATION QUICK FORMULA

```
FINAL STAT = Base × HeirloomMult × EnchanMult

HeirloomMult = 1.0 + ((level - 80) / 80), max 4.0
EnchanMult = 1.0 + (upgrade_level × 0.025)

EXAMPLES:
Level 100, Upgrade 10:
├─ HeirloomMult = 1.0 + ((100-80)/80) = 1.25x
├─ EnchanMult = 1.0 + (10 × 0.025) = 1.25x
└─ TOTAL = 1.25 × 1.25 = 1.5625x (56.25% bonus)

Level 255, Upgrade 15 (MAX):
├─ HeirloomMult = 4.0x (capped)
├─ EnchanMult = 1.0 + (15 × 0.025) = 1.375x
└─ TOTAL = 4.0 × 1.375 = 5.5x (450% bonus!)
```

---

## 🐛 TROUBLESHOOTING

| Problem | Solution |
|---------|----------|
| Enchant not applying | Check `TEMP_ENCHANTMENT_SLOT` index, verify spell_bonus_data exists |
| Stats not scaling | Verify heirloom flags on item_template, check ScalingStatDistribution |
| Essence not tracked | Ensure item 200001 exists, check currency system |
| UI shows wrong level | Verify upgrade_level stored in DB, check DC_ItemUpgrade addon |
| Artifacts not loading | Run LoadArtifacts() on startup, verify SQL inserts |

---

## 📦 DEPLOYMENT CHECKLIST

- [ ] All SQL executed without errors
- [ ] C++ compiled, no warnings
- [ ] Scripts registered in script loader
- [ ] Addon loads successfully
- [ ] Artifacts load from database
- [ ] Essence currency accessible
- [ ] Loot objects placed in world
- [ ] Test upgrade flow works
- [ ] Heirloom scaling verified
- [ ] Secondary stats applying
- [ ] UI displays correctly
- [ ] Performance acceptable
- [ ] Documentation updated
- [ ] Rollback plan ready

---

## 📞 KEY CONTACTS/REFERENCES

| Component | File | Lines | Function |
|-----------|------|-------|----------|
| Heirloom Scaling | heirloom_scaling_255.cpp | 149-191 | Bag slot scaling |
| ItemUpgrade | ItemUpgradeManager.h | 43-60 | Tier/cost constants |
| Enchants | PlayerStorage.cpp | 4587+ | ApplyEnchantment |
| UI Display | DC-ItemUpgrade Lua | Line X | Tooltip builder |

---

## 🚀 QUICK START (First Artifact)

1. **Create item_template entry (191001)** - Heirloom weapon
2. **Insert artifact_items row** - Define as artifact
3. **Insert artifact_loot_locations** - Place in world
4. **Add Tier 5 costs** - essence_cost column populated
5. **Compile ArtifactManager** - Scripts loaded
6. **Test loot + upgrade** - Verify flow works

**Time: ~1-2 hours for first artifact**

---

## 📈 SCALING EXAMPLES

### Stat Growth Visualization

```
Level 1 Upgrade 0:    1.0x (base)
Level 50 Upgrade 0:   1.31x (heirloom only)
Level 50 Upgrade 15:  1.81x (heirloom + max upgrade)
Level 255 Upgrade 0:  4.0x (heirloom max)
Level 255 Upgrade 15: 5.5x (ultimate power!)
```

### Essence Requirements by Level

```
0→1:   500        6→7:   1,750      12→13: 3,250
1→2:   750        7→8:   2,000      13→14: 3,250
2→3:   1,000      8→9:   2,000      14→15: 3,000
3→4:   1,250      9→10:  2,250      TOTAL: 30,250
4→5:   1,500      10→11: 2,750
5→6:   1,750      11→12: 3,000
```

---

## ✅ SUCCESS CRITERIA

System is ready when:

- ✅ Artifact loads from loot correctly
- ✅ Item stats scale with player level (heirloom)
- ✅ Upgrade increases secondary stats (enchant)
- ✅ Essence currency works
- ✅ Level-up recalculates stats automatically
- ✅ UI displays artifact info
- ✅ Multiple artifacts can be equipped
- ✅ Progress persists on logout/login
- ✅ Max level (15) prevents further upgrades

---

**For detailed documentation, see:**
- `ARTIFACT_SYSTEM_CONCEPT_ANALYSIS.md` - Full design
- `ARTIFACT_SYSTEM_IMPLEMENTATION_ROADMAP.md` - Step-by-step guide
- `ARTIFACT_SYSTEM_VISUAL_ARCHITECTURE.md` - Diagrams
- `ARTIFACT_SYSTEM_EXECUTIVE_SUMMARY.md` - Overview

