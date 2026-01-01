# DC ItemUpgrades System Evaluation
## 2026 Improvements Analysis

**Files Analyzed:** 26 files (380KB+ total)
**Last Analyzed:** January 1, 2026

---

## System Overview

The ItemUpgrades system provides a comprehensive item progression system with tier-based upgrades, transmutation, and seasonal integration.

### Core Components
| File | Size | Purpose |
|------|------|---------|
| `ItemUpgradeManager.cpp` | 49KB | Core upgrade logic, currency management |
| `ItemUpgradeAdvanced.h` | 16KB | Spec optimization, transmog, achievements |
| `ItemUpgradeProgression.h` | 17KB | Tier config, level caps, cost scaling |
| `ItemUpgradeSeasonal.h` | 18KB | Season-specific bonuses |
| `ItemUpgradeTransmutationImpl.cpp` | 37KB | Item transmutation system |

---

## 🔴 Issues Found

### 1. **Memory Leak in State Cache**
`GetItemUpgradeState` creates new states but never cleans up:
```cpp
static std::unordered_map<uint32, ItemUpgradeState> item_state_cache;
// No cleanup on item deletion or player logout
```
**Recommendation:** Add cleanup on item deletion event and periodic garbage collection.

### 2. **Race Condition in Currency Operations**
```cpp
bool RemoveCurrency(uint32 player_guid, CurrencyType currency, uint32 amount, uint32 season)
{
    uint32 current = GetCurrency(player_guid, currency, season);
    if (current < amount) return false;
    // Race: Another thread could modify between check and update
    stmt->SetData(1, current - amount);
}
```
**Recommendation:** Use database transactions or atomic operations.

### 3. **Tier 6 (Heirloom) Hardcoded Special Cases**
```cpp
if (state.tier_id == TIER_HEIRLOOM)
    max_mult = STAT_MULTIPLIER_MAX_HEIRLOOM;
```
Spread across multiple files. 
**Recommendation:** Centralize tier-specific logic in TierDefinition.

### 4. **Duplicate Stat Calculation Logic**
Found in both:
- `ItemUpgradeManager.cpp::GetStatMultiplier`
- `ItemUpgradeAdvancedImpl.cpp::CalculateStatBonus`

**Recommendation:** Single source of truth in ItemUpgradeManager.

---

## 🟡 Improvements Suggested

### 1. **Upgrade Preview System**
Add preview of stats before upgrade:
```cpp
struct UpgradePreview {
    float currentMultiplier;
    float newMultiplier;
    uint16 currentIlvl;
    uint16 newIlvl;
    std::map<uint32, int32> statChanges;
};
UpgradePreview PreviewUpgrade(uint32 itemGuid);
```

### 2. **Bulk Upgrade Support**
Allow upgrading multiple items at once with discount:
- 5+ items: 5% token discount
- 10+ items: 10% token discount

### 3. **Upgrade Path Visualization**
Send complete tier progression to addon:
```
Tier 1 (0-10) → Tier 2 (0-8) → Tier 3 (0-6) → Tier 4 (0-4) → Tier 5 (0-3)
```

### 4. **Downgrade/Refund System**
Allow partial refund when resetting upgrades:
- 50% token refund
- 25% essence refund
- Requires confirmation dialog

### 5. **Upgrade Enchants Preservation**
Currently enchants are lost on transmutation. Add option to preserve.

---

## 🟢 Extensions Recommended

### 1. **Set Bonus System**
Bonus for upgrading complete gear sets:
```cpp
struct SetBonus {
    uint32 setId;
    uint8 piecesRequired;
    float bonusMultiplier;
    uint32 bonusSpell; // Optional aura
};
```

### 2. **Upgrade Achievements**
- First Tier 5 item
- 10 max-level upgrades
- All slots at Tier 3+
- Season completion (all gear at seasonal tier)

### 3. **Guild Upgrade Buffs**
Guild perks that provide upgrade discounts:
- Guild Level 5: 2% discount
- Guild Level 10: 5% discount
- Guild Level 15: 10% discount

### 4. **Item Upgrade Trading**
Allow trading upgrade levels between items of same tier.

### 5. **Upgrade Leaderboard**
Track total upgrade investment per player.

---

## 📊 Technical Upgrades

### Database Schema Optimization
Current schema missing indexes:
```sql
-- Add these indexes
ALTER TABLE dc_item_upgrade_state 
ADD INDEX idx_owner (owner_guid),
ADD INDEX idx_tier (tier_id);

ALTER TABLE dc_item_upgrade_currency
ADD INDEX idx_player_season (player_guid, season_id);
```

### Performance Metrics

| Operation | Current | Target |
|-----------|---------|--------|
| GetItemUpgradeState | ~5ms | <1ms |
| UpgradeItem | ~50ms | <20ms |
| GetCurrency | ~3ms | <1ms |

### Recommended Caching Strategy
```cpp
class UpgradeCache {
    LRUCache<uint32, ItemUpgradeState> itemCache{10000};
    LRUCache<uint64, uint32> currencyCache{5000}; // (guid<<32|season|currency) -> amount
    
    void InvalidatePlayer(uint32 playerGuid);
    void InvalidateItem(uint32 itemGuid);
};
```

---

## Integration Points

| System | Integration Type | Quality |
|--------|-----------------|---------|
| Seasons | Currency bonuses | ⭐⭐⭐⭐⭐ |
| MythicPlus | Reward upgrades | ⭐⭐⭐⭐⭐ |
| GreatVault | Tier upgrades | ⭐⭐⭐⭐ |
| AddonExtension | Full UI support | ⭐⭐⭐⭐⭐ |
| CollectionSystem | Transmog unlock | ⭐⭐⭐ |
| Prestige | Bonus multipliers | ⭐⭐⭐ |

---

## Priority Actions

1. **CRITICAL:** Fix currency race condition
2. **HIGH:** Add item state cache cleanup
3. **HIGH:** Centralize tier-specific logic
4. **MEDIUM:** Add database indexes
5. **MEDIUM:** Implement upgrade preview
6. **LOW:** Set bonus system
