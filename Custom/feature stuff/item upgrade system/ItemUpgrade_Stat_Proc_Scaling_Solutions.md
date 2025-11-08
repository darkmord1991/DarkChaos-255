# Item Upgrade System - Stat & Proc Scaling Implementation Solutions

**Date:** November 8, 2025  
**Status:** Stat scaling and proc scaling currently disabled (prevents crashes)  
**Goal:** Provide feasible implementation approaches for AzerothCore

---

## Problem Summary

### Current Issues:
1. **Stat Scaling:** Modifying const `ItemTemplate` data crashes the server
2. **Proc Scaling:** AzerothCore lacks direct `OnSpellDamage`/`OnSpellHeal` hooks

### What Works Now:
✅ Item upgrade tracking (level, tier, costs)  
✅ Database persistence  
✅ GM commands (`.upgrade token`)  
✅ Addon communication (`.dcupgrade`)  
✅ Currency management  
✅ Tier progression  
⚠️ **Stat scaling disabled** (needs implementation)  
⚠️ **Proc scaling disabled** (needs implementation)

---

## Solution 1: Item Enchantment-Based Stat Scaling (RECOMMENDED)

### Approach:
Use AzerothCore's enchantment system to add bonus stats to upgraded items.

### Advantages:
- ✅ Safe - doesn't modify shared template data
- ✅ Native support - uses existing game systems
- ✅ Client displays correctly (shows green bonus stats)
- ✅ Easy to remove/update
- ✅ Works with all item slots

### Implementation:

```cpp
// In ItemUpgradeStatApplication.cpp

#include "SpellMgr.h"

// Define custom enchantment IDs for upgrade bonuses (add to world DB)
#define ENCHANT_UPGRADE_TIER1_LEVEL5   80001
#define ENCHANT_UPGRADE_TIER1_LEVEL10  80002
#define ENCHANT_UPGRADE_TIER1_LEVEL15  80003
// ... define for each tier + level combo

void ApplyUpgradeStatsViaEnchant(Player* player, Item* item)
{
    if (!player || !item)
        return;
    
    uint32 item_guid = item->GetGUID().GetCounter();
    UpgradeManager* mgr = GetUpgradeManager();
    if (!mgr)
        return;
    
    ItemUpgradeState* state = mgr->GetItemUpgradeState(item_guid);
    if (!state || state->upgrade_level == 0)
        return;
    
    // Remove any existing upgrade enchant
    for (EnchantmentSlot slot = PERM_ENCHANTMENT_SLOT; slot < MAX_INSPECTED_ENCHANTMENT_SLOT; slot++)
    {
        if (item->GetEnchantmentId(slot) >= 80000 && item->GetEnchantmentId(slot) < 90000)
        {
            player->ApplyEnchantment(item, slot, false);
            item->ClearEnchantment(slot);
        }
    }
    
    // Calculate which enchant to apply based on tier + level
    uint32 enchant_id = CalculateUpgradeEnchantId(state->tier_id, state->upgrade_level);
    
    // Apply new enchant to TEMP_ENCHANTMENT_SLOT
    item->SetEnchantment(TEMP_ENCHANTMENT_SLOT, enchant_id, 0, 0);
    player->ApplyEnchantment(item, TEMP_ENCHANTMENT_SLOT, true);
    
    LOG_DEBUG("scripts", "ItemUpgrade: Applied enchant {} (tier {}, level {}) to item {}", 
             enchant_id, state->tier_id, state->upgrade_level, item_guid);
}

uint32 CalculateUpgradeEnchantId(uint8 tier_id, uint8 upgrade_level)
{
    // Map tier + level to enchant ID
    // Base ID: 80000 + (tier * 100) + level
    return 80000 + (tier_id * 100) + upgrade_level;
}
```

### Database Setup:

```sql
-- Example: Tier 1, Level 5 enchant (+12.5% stats)
-- Adds +10 to all primary stats (Str, Agi, Sta, Int, Spi)
INSERT INTO item_enchantment_template (ench, chance, description) VALUES 
(80105, 100, 'Item Upgrade: Tier 1 Level 5 (+12.5%)');

-- Define stat bonuses in item_enchantment_template
-- Each enchant entry grants specific stat increases
-- Scale the bonuses based on tier + level multipliers

-- You'll need ~75 enchant entries (5 tiers × 15 levels)
```

**Pros:** Most compatible, visually correct, easy to maintain  
**Cons:** Requires database entries for each tier/level combo

---

## Solution 2: UnitScript Hook-Based Damage Scaling (RECOMMENDED)

### Approach:
Hook into `ModifySpellDamageTaken`, `ModifyMeleeDamage`, and `ModifyHealReceived` to scale proc effects.

### Available Hooks (from ScriptMgr.h):
```cpp
void OnDamage(Unit* attacker, Unit* victim, uint32& damage);
void ModifyMeleeDamage(Unit* target, Unit* attacker, uint32& damage);
void ModifySpellDamageTaken(Unit* target, Unit* attacker, int32& damage, SpellInfo const* spellInfo);
void ModifyHealReceived(Unit* target, Unit* healer, uint32& addHealth, SpellInfo const* spellInfo);
```

### Implementation:

```cpp
// In ItemUpgradeProcScaling.cpp

class ItemUpgradeProcDamageHook : public UnitScript
{
public:
    ItemUpgradeProcDamageHook() : UnitScript("ItemUpgradeProcDamageHook") {}
    
    // Hook spell damage
    void ModifySpellDamageTaken(Unit* target, Unit* attacker, int32& damage, SpellInfo const* spellInfo) override
    {
        if (!attacker || !spellInfo || damage <= 0)
            return;
        
        Player* player = attacker->ToPlayer();
        if (!player)
            return;
        
        // Check if this spell is a proc from an upgraded item
        if (IsItemProcSpell(spellInfo->Id))
        {
            float multiplier = GetPlayerItemProcMultiplier(player);
            if (multiplier > 1.0f)
            {
                damage = static_cast<int32>(damage * multiplier);
                LOG_DEBUG("scripts", "ItemUpgrade: Scaled spell {} damage by {:.2f}x ({}->{})", 
                         spellInfo->Id, multiplier, damage / multiplier, damage);
            }
        }
    }
    
    // Hook melee damage (for weapon procs)
    void ModifyMeleeDamage(Unit* target, Unit* attacker, uint32& damage) override
    {
        if (!attacker || damage == 0)
            return;
        
        Player* player = attacker->ToPlayer();
        if (!player)
            return;
        
        // Get average weapon proc multiplier
        float multiplier = GetPlayerWeaponProcMultiplier(player);
        if (multiplier > 1.0f)
        {
            damage = static_cast<uint32>(damage * multiplier);
        }
    }
    
    // Hook healing (for healing procs)
    void ModifyHealReceived(Unit* target, Unit* healer, uint32& addHealth, SpellInfo const* spellInfo) override
    {
        if (!healer || !spellInfo || addHealth == 0)
            return;
        
        Player* player = healer->ToPlayer();
        if (!player)
            return;
        
        if (IsItemProcSpell(spellInfo->Id))
        {
            float multiplier = GetPlayerItemProcMultiplier(player);
            if (multiplier > 1.0f)
            {
                addHealth = static_cast<uint32>(addHealth * multiplier);
            }
        }
    }
    
private:
    float GetPlayerItemProcMultiplier(Player* player)
    {
        if (!player)
            return 1.0f;
        
        // Calculate average multiplier from all equipped upgraded items
        float total_multiplier = 0.0f;
        uint32 upgraded_items = 0;
        
        UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager();
        if (!mgr)
            return 1.0f;
        
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        {
            Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            if (!item)
                continue;
            
            ItemUpgradeState* state = mgr->GetItemUpgradeState(item->GetGUID().GetCounter());
            if (state && state->upgrade_level > 0)
            {
                total_multiplier += state->stat_multiplier;
                upgraded_items++;
            }
        }
        
        if (upgraded_items == 0)
            return 1.0f;
        
        // Return average multiplier
        return total_multiplier / upgraded_items;
    }
    
    float GetPlayerWeaponProcMultiplier(Player* player)
    {
        if (!player)
            return 1.0f;
        
        // Get multiplier from main-hand and off-hand weapons
        float mh_mult = 1.0f;
        float oh_mult = 1.0f;
        
        UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager();
        if (!mgr)
            return 1.0f;
        
        Item* mainhand = player->GetItemByPos(INVENTORY_SLOT_BAG_0, EQUIPMENT_SLOT_MAINHAND);
        if (mainhand)
        {
            ItemUpgradeState* state = mgr->GetItemUpgradeState(mainhand->GetGUID().GetCounter());
            if (state && state->upgrade_level > 0)
                mh_mult = state->stat_multiplier;
        }
        
        Item* offhand = player->GetItemByPos(INVENTORY_SLOT_BAG_0, EQUIPMENT_SLOT_OFFHAND);
        if (offhand)
        {
            ItemUpgradeState* state = mgr->GetItemUpgradeState(offhand->GetGUID().GetCounter());
            if (state && state->upgrade_level > 0)
                oh_mult = state->stat_multiplier;
        }
        
        // Return average of both weapons
        return (mh_mult + oh_mult) / 2.0f;
    }
    
    bool IsItemProcSpell(uint32 spell_id)
    {
        // Check if spell is a known item proc
        // Use the database mapping we built earlier
        static std::unordered_set<uint32> proc_spells;
        
        // Lazy load from database
        if (proc_spells.empty())
        {
            QueryResult result = WorldDatabase.Query("SELECT spell_id FROM dc_item_proc_spells");
            if (result)
            {
                do {
                    proc_spells.insert((*result)[0].Get<uint32>());
                } while (result->NextRow());
            }
        }
        
        return proc_spells.find(spell_id) != proc_spells.end();
    }
};

void AddSC_ItemUpgradeProcScaling()
{
    new ItemUpgradeProcDamageHook();
}
```

**Pros:** Works with existing AzerothCore hooks, scales ALL damage/healing from procs  
**Cons:** Affects all spells (need to filter proc spells correctly)

---

## Solution 3: Aura-Based Stat Scaling

### Approach:
Apply invisible auras to players that grant stat bonuses based on equipped upgraded items.

### Implementation:

```cpp
// Create custom spell auras (one per tier/level combo)
// Example: Spell 900001 = "Item Upgrade Bonus: Tier 1 Level 5"
//   - SPELL_AURA_MOD_STAT (all stats +12.5%)
//   - SPELL_AURA_MOD_DAMAGE_DONE (+12.5%)
//   - SPELL_AURA_MOD_HEALING_DONE (+12.5%)

void OnPlayerEquip(Player* player, Item* item, uint8 /*bag*/, uint8 /*slot*/, bool /*update*/) override
{
    if (!player || !item)
        return;
    
    // Remove all upgrade auras
    RemoveAllUpgradeAuras(player);
    
    // Recalculate and apply new auras based on all equipped items
    RecalculateUpgradeAuras(player);
}

void RecalculateUpgradeAuras(Player* player)
{
    // Scan all equipment slots
    // Determine highest tier/level combo
    // Apply corresponding aura
    
    uint8 max_tier = 0;
    uint8 max_level = 0;
    
    UpgradeManager* mgr = GetUpgradeManager();
    if (!mgr)
        return;
    
    for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
    {
        Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
        if (!item)
            continue;
        
        ItemUpgradeState* state = mgr->GetItemUpgradeState(item->GetGUID().GetCounter());
        if (state)
        {
            if (state->tier_id > max_tier || 
               (state->tier_id == max_tier && state->upgrade_level > max_level))
            {
                max_tier = state->tier_id;
                max_level = state->upgrade_level;
            }
        }
    }
    
    if (max_level > 0)
    {
        uint32 spell_id = 900000 + (max_tier * 100) + max_level;
        player->CastSpell(player, spell_id, true);
    }
}
```

**Pros:** Uses native aura system, clean implementation  
**Cons:** Requires creating ~75 spell entries in world database

---

## Solution 4: Hybrid Approach (BEST FOR PRODUCTION)

### Recommended Combination:
1. **Stat Scaling:** Use **Solution 1 (Enchantments)** for base stats
2. **Proc Scaling:** Use **Solution 2 (UnitScript Hooks)** for proc damage

### Why This Works:
- Enchantments handle visible stats (Str, Agi, Sta, etc.)
- UnitScript hooks handle dynamic proc scaling
- No template modification needed
- Client displays correctly
- Minimal database entries

### Implementation Steps:

1. **Create enchantment entries** (one-time database setup)
2. **Replace `ItemUpgradeStatApplication.cpp`** with enchant-based system
3. **Replace `ItemUpgradeProcScaling.cpp`** with UnitScript hook system
4. **Test thoroughly** with various item types

---

## Comparison Table

| Solution | Complexity | Performance | Compatibility | Maintainability |
|----------|-----------|-------------|---------------|-----------------|
| Enchantments | Medium | Excellent | Excellent | Good |
| UnitScript Hooks | Low | Good | Excellent | Excellent |
| Aura-Based | High | Good | Good | Medium |
| Hybrid | Medium | Excellent | Excellent | Excellent |

---

## Next Steps

### Immediate Actions:
1. Choose implementation approach (recommend: Hybrid)
2. Create database entries for enchantments
3. Implement enchant-based stat scaling
4. Implement UnitScript hook-based proc scaling
5. Test with various item types and upgrade levels

### Database Schema Additions:

```sql
-- Enchantment entries for stat scaling
CREATE TABLE IF NOT EXISTS `dc_item_upgrade_enchants` (
  `enchant_id` INT UNSIGNED NOT NULL PRIMARY KEY,
  `tier_id` TINYINT UNSIGNED NOT NULL,
  `upgrade_level` TINYINT UNSIGNED NOT NULL,
  `stat_multiplier` FLOAT NOT NULL,
  `description` VARCHAR(255),
  INDEX `idx_tier_level` (`tier_id`, `upgrade_level`)
);

-- Proc spell mapping (for proc scaling detection)
CREATE TABLE IF NOT EXISTS `dc_item_proc_spells` (
  `spell_id` INT UNSIGNED NOT NULL PRIMARY KEY,
  `item_id` INT UNSIGNED NOT NULL,
  `proc_type` VARCHAR(50) COMMENT 'damage/healing/buff',
  INDEX `idx_item` (`item_id`)
);
```

---

## Conclusion

**Recommended Approach:** Hybrid (Enchantments + UnitScript Hooks)

**Estimated Implementation Time:**
- Enchantment system: 2-3 hours
- UnitScript hooks: 1-2 hours  
- Database setup: 1 hour
- Testing: 2-3 hours
- **Total: 6-9 hours**

**Benefits:**
✅ Safe - no template modification  
✅ Performant - uses native systems  
✅ Maintainable - clean, documented code  
✅ Scalable - easy to add new tiers/levels  
✅ Client-correct - proper visual display  

---

**Author:** GitHub Copilot  
**Date:** November 8, 2025  
**Version:** 1.0
