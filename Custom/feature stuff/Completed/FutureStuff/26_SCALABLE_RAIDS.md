# Scalable Raid System

**Priority:** C2 (Long-term)  
**Effort:** High (4 weeks)  
**Impact:** High  
**Base:** mod-autobalance + Custom Extensions

---

## Overview

Make existing WotLK raids scale to higher levels (100, 130, 160, 200, 255) with improved rewards. Reuses existing content to provide raid progression at all DarkChaos level ranges.

---

## Why It Fits DarkChaos-255

### Integration Points
| System | Integration |
|--------|-------------|
| **Item Upgrades** | Raid loot feeds upgrades |
| **Mythic+** | Raids as M+ alternative |
| **Seasonal** | Seasonal raid modifiers |
| **Tokens** | Token rewards from raids |
| **Tier Sets** | Custom tier sets per difficulty |

### Benefits
- Massive content reuse
- Raid at every level range
- Familiar encounters
- Progressive difficulty
- Long-term engagement

---

## Raid Scaling Tiers

| Tier | Level Range | Raids Available |
|------|-------------|-----------------|
| T1 | 80 (Original) | All WotLK raids |
| T2 | 100 (Heroic+) | Naxx, OS, VoA |
| T3 | 130 (Mythic) | Naxx, Ulduar, ToC |
| T4 | 160 (Mythic+) | Ulduar, ToC, ICC |
| T5 | 200 (Legendary) | ICC, RS |
| T6 | 255 (Ultimate) | All raids |

---

## Implementation

### Database Schema
```sql
-- Raid difficulty tiers
CREATE TABLE dc_raid_tiers (
    tier_id INT UNSIGNED PRIMARY KEY,
    tier_name VARCHAR(50) NOT NULL,
    min_level TINYINT UNSIGNED NOT NULL,
    max_level TINYINT UNSIGNED NOT NULL,
    hp_multiplier FLOAT DEFAULT 1.0,
    damage_multiplier FLOAT DEFAULT 1.0,
    loot_ilvl_bonus SMALLINT DEFAULT 0,
    token_multiplier FLOAT DEFAULT 1.0
);

-- Raid-tier mappings
CREATE TABLE dc_raid_tier_maps (
    map_id INT UNSIGNED NOT NULL,
    tier_id INT UNSIGNED NOT NULL,
    instance_name VARCHAR(100) NOT NULL,
    enabled BOOLEAN DEFAULT TRUE,
    custom_hp_mod FLOAT DEFAULT NULL,
    custom_dmg_mod FLOAT DEFAULT NULL,
    PRIMARY KEY (map_id, tier_id)
);

-- Custom loot per tier
CREATE TABLE dc_raid_tier_loot (
    loot_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    map_id INT UNSIGNED NOT NULL,
    tier_id INT UNSIGNED NOT NULL,
    boss_entry INT UNSIGNED NOT NULL,
    item_entry INT UNSIGNED NOT NULL,
    drop_chance FLOAT DEFAULT 0.15,
    is_tier_piece BOOLEAN DEFAULT FALSE
);

-- Sample tiers
INSERT INTO dc_raid_tiers VALUES
(1, 'Original', 80, 80, 1.0, 1.0, 0, 1.0),
(2, 'Heroic+', 100, 100, 2.5, 1.8, 30, 1.5),
(3, 'Mythic', 130, 130, 5.0, 2.5, 60, 2.0),
(4, 'Mythic+', 160, 160, 10.0, 4.0, 100, 3.0),
(5, 'Legendary', 200, 200, 25.0, 8.0, 150, 5.0),
(6, 'Ultimate', 255, 255, 50.0, 15.0, 200, 10.0);

-- Sample mappings
INSERT INTO dc_raid_tier_maps (map_id, tier_id, instance_name, enabled) VALUES
(533, 1, 'Naxxramas (Original)', 1),
(533, 2, 'Naxxramas (Heroic+)', 1),
(533, 3, 'Naxxramas (Mythic)', 1),
(603, 1, 'Ulduar (Original)', 1),
(603, 3, 'Ulduar (Mythic)', 1),
(603, 4, 'Ulduar (Mythic+)', 1),
(631, 1, 'Icecrown Citadel (Original)', 1),
(631, 4, 'Icecrown Citadel (Mythic+)', 1),
(631, 5, 'Icecrown Citadel (Legendary)', 1),
(631, 6, 'Icecrown Citadel (Ultimate)', 1);
```

### Raid Scaler (C++)
```cpp
class RaidScaler
{
public:
    static RaidScaler* instance();
    
    // Tier selection
    uint32 GetPlayerTier(Player* player) const;
    RaidTier* GetTier(uint32 tierId) const;
    std::vector<RaidTierMap> GetAvailableRaids(uint32 tierId) const;
    
    // Scaling
    void ApplyCreatureScaling(Creature* creature, uint32 mapId, uint32 tierId);
    float GetHealthMultiplier(uint32 mapId, uint32 tierId) const;
    float GetDamageMultiplier(uint32 mapId, uint32 tierId) const;
    
    // Loot
    void ModifyLoot(Loot* loot, Creature* creature, uint32 tierId);
    uint16 GetLootItemLevel(uint32 mapId, uint32 tierId, uint16 baseIlvl) const;
    
    // Lockouts
    bool HasLockout(Player* player, uint32 mapId, uint32 tierId) const;
    void CreateLockout(Player* player, uint32 mapId, uint32 tierId);
    void ResetLockout(Player* player, uint32 mapId, uint32 tierId);
    
    // Instance creation
    uint32 CreateScaledInstance(uint32 mapId, uint32 tierId);
    
private:
    std::unordered_map<uint32, RaidTier> _tiers;
    std::unordered_map<std::pair<uint32, uint32>, RaidTierMap> _raidMaps;
    
    void LoadTiers();
    void LoadRaidMaps();
    void LoadTierLoot();
};

#define sRaidScaler RaidScaler::instance()
```

### Creature Scaling Hook
```cpp
void RaidScaler::ApplyCreatureScaling(Creature* creature, uint32 mapId, uint32 tierId)
{
    RaidTier* tier = GetTier(tierId);
    if (!tier)
        return;
    
    // Get custom modifiers or use tier defaults
    float hpMod = GetHealthMultiplier(mapId, tierId);
    float dmgMod = GetDamageMultiplier(mapId, tierId);
    
    // Scale health
    uint64 baseHealth = creature->GetMaxHealth();
    uint64 scaledHealth = static_cast<uint64>(baseHealth * hpMod);
    creature->SetMaxHealth(scaledHealth);
    creature->SetHealth(scaledHealth);
    
    // Scale damage (via aura or stat modification)
    creature->ApplySpellImmune(0, IMMUNITY_DAMAGE, SPELL_SCHOOL_MASK_ALL, false);
    
    // Set level
    creature->SetLevel(tier->maxLevel);
    
    // Apply tier-specific buffs
    if (tierId >= 4)
    {
        creature->AddAura(AURA_MYTHIC_FORTITUDE, creature);  // Custom aura
    }
    if (tierId >= 5)
    {
        creature->AddAura(AURA_LEGENDARY_MIGHT, creature);
    }
    
    LOG_DEBUG("RaidScaler", "Scaled creature {} in map {} tier {} - HP: {} -> {}, DMG mod: {}",
              creature->GetEntry(), mapId, tierId, baseHealth, scaledHealth, dmgMod);
}
```

---

## Tier Difficulty

### Scaling Formulas
```
HP = BaseHP × TierMultiplier × (1 + (Level - 80) / 100)
DMG = BaseDMG × TierMultiplier × (1 + (Level - 80) / 150)
Armor = BaseArmor × (1 + (Level - 80) / 200)
```

### Tier Progression
| Tier | HP Mult | DMG Mult | Expected Wipes |
|------|---------|----------|----------------|
| Original | 1.0x | 1.0x | 0-1 |
| Heroic+ | 2.5x | 1.8x | 2-3 |
| Mythic | 5.0x | 2.5x | 5-10 |
| Mythic+ | 10.0x | 4.0x | 10-20 |
| Legendary | 25.0x | 8.0x | 20-50 |
| Ultimate | 50.0x | 15.0x | 50-100 |

---

## Loot System

### Item Level Bonuses
| Tier | Base iLvl | Bonus | Result |
|------|-----------|-------|--------|
| Original | 200-277 | +0 | 200-277 |
| Heroic+ | 200-277 | +30 | 230-307 |
| Mythic | 200-277 | +60 | 260-337 |
| Mythic+ | 200-277 | +100 | 300-377 |
| Legendary | 200-277 | +150 | 350-427 |
| Ultimate | 200-277 | +200 | 400-477 |

### Token Rewards
| Tier | Tokens per Boss | Tokens per Clear |
|------|-----------------|------------------|
| Original | 10 | 50 |
| Heroic+ | 15 | 100 |
| Mythic | 25 | 200 |
| Mythic+ | 40 | 400 |
| Legendary | 75 | 750 |
| Ultimate | 150 | 1500 |

---

## Raid Selection UI

### NPC Interface
```lua
-- Raid Tier Selector NPC
function RaidSelector.OnGossipHello(event, player, creature)
    local playerTier = GetPlayerTier(player)
    
    player:GossipMenuAddItem(0, "Available Tiers:", 1, 0)
    
    for tierId = 1, 6 do
        local tier = GetTierInfo(tierId)
        local raids = GetAvailableRaids(tierId)
        local status = (tierId <= playerTier) and "[Available]" or "[Locked]"
        
        player:GossipMenuAddItem(0, tier.name .. " " .. status, 1, tierId)
    end
    
    player:GossipSendMenu(1, creature)
end

function RaidSelector.OnGossipSelect(event, player, creature, sender, intid, code, menu_id)
    if intid > 0 and intid <= 6 then
        ShowRaidsForTier(player, creature, intid)
    end
end
```

---

## Commands

### Player Commands
```
.raid tiers           - Show available tiers
.raid lockouts        - Show your lockouts
.raid info <raid>     - Show raid info per tier
```

### GM Commands
```
.raid scale <tier>    - Set tier for current instance
.raid reset <p> <map> - Reset player lockout
.raid spawn <map> <t> - Create scaled instance
.raid test <creature> - Test scaling on creature
```

---

## Timeline

| Task | Duration |
|------|----------|
| Database schema | 4 hours |
| RaidScaler core | 5 days |
| Creature scaling | 3 days |
| Loot modifications | 2 days |
| Lockout system | 2 days |
| Tier NPC UI | 1 day |
| Per-raid tuning | 3 days |
| Testing all raids | 5 days |
| **Total** | **~4 weeks** |

---

## Future Enhancements

1. **Mythic Raid Affixes** - Weekly affixes like M+
2. **Raid Achievements** - Per-tier glory achievements
3. **Raid Finder Queue** - Cross-faction raid finder
4. **Timewalking Raids** - Scale down for low-level players
5. **Custom Bosses** - Add bosses to existing raids
