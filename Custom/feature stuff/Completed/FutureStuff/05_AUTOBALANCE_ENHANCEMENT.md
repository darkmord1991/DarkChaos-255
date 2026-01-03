# AutoBalance Enhancement System

**Priority:** S2 - High Priority  
**Effort:** Low (3-5 days)  
**Impact:** High  
**Base:** mod-autobalance (existing)

---

## Overview

mod-autobalance already exists in the AzerothCore ecosystem. This proposal enhances the existing module with Mythic+-specific scaling, funserver considerations, and better tuning for the 255 level cap. The goal is to make dungeons and raids properly challenging regardless of player count.

---

## Why It Fits DarkChaos-255

### Current Situation
- **Problem**: Level 255 with custom gear makes content trivial
- **Problem**: Mythic+ needs consistent difficulty
- **Problem**: Solo/small group play needs scaling
- **Problem**: Raid content becomes zerg-fests

### Value Proposition
- Challenging dungeons regardless of group size
- Enables Mythic+ affix-based scaling
- Solo/duo/trio viable content
- Raids remain mechanically relevant

### Synergies
| System | Integration |
|--------|-------------|
| **Mythic+** | Keystone level multipliers |
| **Solocraft** | Complementary scaling |
| **Seasonal** | Season-specific scaling profiles |
| **Item Upgrade** | Account for upgraded gear power |

---

## Feature Highlights

### Enhanced Scaling Features

1. **Level 255 Stat Adjustments**
   - Custom formulas for high-level scaling
   - Account for stat inflation
   - Prevent one-shots in both directions

2. **Mythic+ Integration**
   - Per-keystone-level multipliers
   - Affix-based additional modifiers
   - Timer-based tuning

3. **Gear Score Detection**
   - Scale based on actual player power
   - Prevent undergearing cheese
   - Smooth difficulty curve

4. **Per-Boss Overrides**
   - Custom tuning for problematic bosses
   - Mechanic preservation (don't skip phases)
   - Lore-appropriate health pools

5. **Dungeon Profiles**
   - Different scaling for different dungeon types
   - Heroic vs Normal vs Mythic modes
   - Holiday dungeon special handling

---

## Technical Implementation

### Configuration Extensions

```cpp
// AutoBalance.conf additions

# Mythic+ Scaling
AutoBalance.MythicPlus.Enable = 1
AutoBalance.MythicPlus.BaseMultiplier = 1.0
AutoBalance.MythicPlus.PerLevelMultiplier = 0.10  # +10% per key level
AutoBalance.MythicPlus.HealthMultiplier = 1.5     # Extra HP for M+
AutoBalance.MythicPlus.DamageMultiplier = 1.2     # Extra damage for M+

# Affix Modifiers (additive to level multiplier)
AutoBalance.MythicPlus.Affix.Fortified.HealthMod = 0.2
AutoBalance.MythicPlus.Affix.Tyrannical.HealthMod = 0.3
AutoBalance.MythicPlus.Affix.Bolstering.HealthMod = 0.0   # Script handles this

# Level 255 Adjustments
AutoBalance.Level255.Enable = 1
AutoBalance.Level255.StatInflationFactor = 5.0   # Stat multiplier vs level 80
AutoBalance.Level255.BaseHealthMultiplier = 3.0  # Base HP boost
AutoBalance.Level255.BaseDamageMultiplier = 2.0  # Base damage boost

# GearScore Integration
AutoBalance.GearScore.Enable = 1
AutoBalance.GearScore.MinimumForScaling = 200    # Don't scale below this
AutoBalance.GearScore.ScalingCurve = "linear"    # linear, exponential, logarithmic
AutoBalance.GearScore.TargetGS = 1000            # Expected "normal" GS

# Per-Dungeon Overrides
AutoBalance.Override.Map.560.HealthMod = 1.2     # Old Hillsbrad needs more HP
AutoBalance.Override.Map.658.HealthMod = 0.9     # Pit of Saron adjust

# Boss Overrides (by creature entry)
AutoBalance.Override.Creature.26723.HealthMod = 1.5      # Keristrasza
AutoBalance.Override.Creature.26723.PreserveMechanics = 1
```

### Database Schema

```sql
-- Per-instance scaling profiles
CREATE TABLE dc_autobalance_profiles (
    map_id INT UNSIGNED PRIMARY KEY,
    instance_name VARCHAR(100),
    base_health_multiplier FLOAT DEFAULT 1.0,
    base_damage_multiplier FLOAT DEFAULT 1.0,
    min_player_count INT DEFAULT 1,
    max_player_count INT DEFAULT 5,
    scaling_type ENUM('linear', 'stepped', 'custom') DEFAULT 'linear',
    mythic_plus_enabled TINYINT DEFAULT 1,
    notes TEXT
);

-- Per-creature overrides
CREATE TABLE dc_autobalance_creature_overrides (
    creature_entry INT UNSIGNED PRIMARY KEY,
    creature_name VARCHAR(100),
    health_multiplier FLOAT DEFAULT 1.0,
    damage_multiplier FLOAT DEFAULT 1.0,
    armor_multiplier FLOAT DEFAULT 1.0,
    preserve_mechanics TINYINT DEFAULT 0,  -- Don't skip phases
    min_health_percent FLOAT DEFAULT 0,    -- Can't go below this
    notes TEXT
);

-- Mythic+ level multipliers
CREATE TABLE dc_mythicplus_scaling (
    keystone_level INT UNSIGNED PRIMARY KEY,
    health_multiplier FLOAT,
    damage_multiplier FLOAT,
    loot_quality_bonus FLOAT DEFAULT 0
);

-- Default M+ scaling data
INSERT INTO dc_mythicplus_scaling VALUES
(1, 1.0, 1.0, 0),
(2, 1.08, 1.05, 0),
(3, 1.17, 1.10, 0.02),
(4, 1.26, 1.15, 0.04),
(5, 1.36, 1.21, 0.06),
(6, 1.47, 1.27, 0.08),
(7, 1.59, 1.34, 0.10),
(8, 1.71, 1.41, 0.12),
(9, 1.85, 1.49, 0.14),
(10, 2.00, 1.57, 0.16),
(11, 2.16, 1.66, 0.18),
(12, 2.33, 1.75, 0.20),
(13, 2.52, 1.85, 0.22),
(14, 2.72, 1.96, 0.24),
(15, 2.94, 2.07, 0.26),
(16, 3.18, 2.19, 0.28),
(17, 3.43, 2.32, 0.30),
(18, 3.71, 2.46, 0.32),
(19, 4.01, 2.60, 0.34),
(20, 4.33, 2.76, 0.36);
```

### C++ Integration

```cpp
// AutoBalance_MythicPlus.cpp

class AutoBalanceMythicPlusHook : public AllCreatureScript
{
public:
    void OnAllCreatureUpdate(Creature* creature, uint32 /*diff*/) override
    {
        if (!creature->GetMap()->IsDungeon())
            return;
            
        // Check if this is a Mythic+ run
        MythicPlusInfo* info = sMythicPlusMgr->GetRunInfo(creature->GetMap());
        if (!info)
            return;
            
        // Apply M+ scaling on top of base AutoBalance
        ApplyMythicPlusScaling(creature, info);
    }
    
private:
    void ApplyMythicPlusScaling(Creature* creature, MythicPlusInfo* info)
    {
        // Get base M+ multiplier
        float healthMod = GetKeystoneLevelMultiplier(info->keystoneLevel, true);
        float damageMod = GetKeystoneLevelMultiplier(info->keystoneLevel, false);
        
        // Apply affix modifiers
        if (info->HasAffix(AFFIX_FORTIFIED) && !creature->IsBoss())
            healthMod *= sConfigMgr->GetFloatDefault(
                "AutoBalance.MythicPlus.Affix.Fortified.HealthMod", 1.2f);
        
        if (info->HasAffix(AFFIX_TYRANNICAL) && creature->IsBoss())
            healthMod *= sConfigMgr->GetFloatDefault(
                "AutoBalance.MythicPlus.Affix.Tyrannical.HealthMod", 1.3f);
        
        // Check for creature override
        CreatureOverride* override = GetCreatureOverride(creature->GetEntry());
        if (override)
        {
            healthMod *= override->healthMultiplier;
            damageMod *= override->damageMultiplier;
        }
        
        // Apply scaling
        ApplyScaling(creature, healthMod, damageMod);
    }
    
    float GetKeystoneLevelMultiplier(uint8 level, bool isHealth)
    {
        auto itr = sAutoBalanceMgr->MythicPlusScaling.find(level);
        if (itr != sAutoBalanceMgr->MythicPlusScaling.end())
            return isHealth ? itr->second.healthMod : itr->second.damageMod;
        
        // Fallback formula for levels beyond table
        float base = isHealth ? 1.08f : 1.05f;
        return std::pow(base, level);
    }
};
```

### GearScore Integration

```cpp
// AutoBalance_GearScore.cpp

class AutoBalanceGearScoreHook : public AllMapScript
{
public:
    void OnPlayerEnterAll(Map* map, Player* player) override
    {
        if (!map->IsDungeon())
            return;
            
        // Calculate group average GearScore
        uint32 totalGS = 0;
        uint32 playerCount = 0;
        
        Map::PlayerList const& players = map->GetPlayers();
        for (auto& itr : players)
        {
            Player* p = itr.GetSource();
            totalGS += CalculateGearScore(p);
            playerCount++;
        }
        
        if (playerCount == 0)
            return;
            
        float avgGS = static_cast<float>(totalGS) / playerCount;
        float targetGS = sConfigMgr->GetFloatDefault(
            "AutoBalance.GearScore.TargetGS", 1000.0f);
        
        // Calculate scaling factor based on GS deviation
        float gsFactor = CalculateGSFactor(avgGS, targetGS);
        
        // Store for creature scaling hooks
        map->SetGearScoreScaling(gsFactor);
    }
    
private:
    uint32 CalculateGearScore(Player* player)
    {
        uint32 totalGS = 0;
        
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        {
            if (Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot))
            {
                // Use item level as base GS contribution
                totalGS += item->GetTemplate()->ItemLevel;
                
                // Add enchant bonus
                if (item->GetEnchantmentId(PERM_ENCHANTMENT_SLOT))
                    totalGS += 10;
                    
                // Add gem bonus
                for (uint8 i = 0; i < MAX_ITEM_PROTO_SOCKETS; ++i)
                {
                    if (item->GetEnchantmentId(EnchantmentSlot(SOCK_ENCHANTMENT_SLOT + i)))
                        totalGS += 5;
                }
            }
        }
        
        return totalGS;
    }
    
    float CalculateGSFactor(float avgGS, float targetGS)
    {
        if (avgGS <= targetGS)
            return 1.0f;  // Don't make things easier
            
        // Linear scaling: 10% harder per 100 GS over target
        float overage = avgGS - targetGS;
        return 1.0f + (overage / 100.0f * 0.10f);
    }
};
```

---

## Configuration Profiles

### Dungeon Profiles

```sql
-- Heroic 5-man dungeons
INSERT INTO dc_autobalance_profiles VALUES
(560, 'Old Hillsbrad', 1.0, 1.0, 1, 5, 'linear', 1, 'Time-walking tuning'),
(565, 'Gruul''s Lair', 1.5, 1.3, 1, 10, 'stepped', 1, '10-man raid'),
(571, 'Utgarde Keep', 0.9, 0.9, 1, 5, 'linear', 1, 'Entry dungeon'),
(574, 'Utgarde Pinnacle', 1.1, 1.0, 1, 5, 'linear', 1, 'End-game dungeon'),
(576, 'The Nexus', 1.0, 1.0, 1, 5, 'linear', 1, 'Standard tuning'),
(578, 'The Oculus', 1.2, 0.8, 1, 5, 'linear', 1, 'Drake mechanics focus'),
(595, 'Culling of Stratholme', 1.1, 1.1, 1, 5, 'linear', 1, 'Timed run'),
(600, 'Drak''Tharon Keep', 1.0, 1.0, 1, 5, 'linear', 1, 'Standard tuning'),
(601, 'Azjol-Nerub', 0.9, 1.0, 1, 5, 'linear', 1, 'Quick dungeon'),
(602, 'Halls of Lightning', 1.1, 1.1, 1, 5, 'linear', 1, 'Harder dungeon'),
(604, 'Gundrak', 1.0, 1.0, 1, 5, 'linear', 1, 'Standard tuning'),
(608, 'Violet Hold', 0.9, 1.0, 1, 5, 'linear', 1, 'Wave-based'),
(619, 'Ahn''kahet', 1.0, 1.0, 1, 5, 'linear', 1, 'Standard tuning'),
(632, 'Forge of Souls', 1.2, 1.1, 1, 5, 'linear', 1, 'ICC dungeon'),
(650, 'Trial of Champion', 1.0, 1.0, 1, 5, 'linear', 1, 'Arena-style'),
(658, 'Pit of Saron', 1.2, 1.2, 1, 5, 'linear', 1, 'ICC dungeon'),
(668, 'Halls of Reflection', 1.3, 1.2, 1, 5, 'linear', 1, 'Hard dungeon');

-- Raids
INSERT INTO dc_autobalance_profiles VALUES
(533, 'Naxxramas', 2.0, 1.5, 1, 25, 'stepped', 0, 'Entry raid'),
(615, 'Obsidian Sanctum', 1.8, 1.5, 1, 25, 'stepped', 0, 'Single boss'),
(616, 'Eye of Eternity', 2.0, 1.6, 1, 25, 'stepped', 0, 'Vehicle fight'),
(624, 'Vault of Archavon', 1.5, 1.3, 1, 25, 'stepped', 0, 'PvP loot raid'),
(603, 'Ulduar', 2.5, 1.8, 1, 25, 'stepped', 0, 'Hard modes'),
(649, 'Trial of Crusader', 2.2, 1.7, 1, 25, 'stepped', 0, 'Tier 9'),
(631, 'Icecrown Citadel', 3.0, 2.0, 1, 25, 'stepped', 0, 'Final raid'),
(724, 'Ruby Sanctum', 2.5, 1.9, 1, 25, 'stepped', 0, 'Bridge raid');
```

### Boss Overrides

```sql
-- Bosses that need special handling
INSERT INTO dc_autobalance_creature_overrides VALUES
-- Lich King (preserve all phases)
(36597, 'The Lich King', 2.0, 1.5, 1.0, 1, 10.0, 'Must preserve phase transitions'),
-- Festergut (tank damage important)
(36626, 'Festergut', 1.5, 1.2, 1.0, 0, 0, 'Stacking mechanic'),
-- Rotface (ooze mechanic)
(36627, 'Rotface', 1.5, 1.0, 1.0, 1, 5.0, 'Ooze spawning timing'),
-- Sindragosa (Frost Tomb mechanic)
(36853, 'Sindragosa', 1.8, 1.3, 1.0, 1, 15.0, 'Ice tomb phase'),
-- Anub'arak (leeching swarm)
(34564, 'Anub''arak', 1.6, 1.4, 1.0, 1, 30.0, 'Phase 3 mechanic'),
-- Yogg-Saron (complex phases)
(33288, 'Yogg-Saron', 2.0, 1.5, 1.0, 1, 5.0, 'Multiple phases'),
-- Mimiron (vehicle phases)
(33350, 'Mimiron', 1.8, 1.3, 1.0, 1, 10.0, 'Phase transitions');
```

---

## Implementation Phases

### Phase 1 (Days 1-2): Configuration
- [ ] Add new config options
- [ ] Create database tables
- [ ] Populate default values
- [ ] Test config loading

### Phase 2 (Days 2-3): M+ Integration
- [ ] Hook into Mythic+ system
- [ ] Implement keystone scaling
- [ ] Add affix modifiers
- [ ] Test scaling curves

### Phase 3 (Days 4-5): GearScore & Polish
- [ ] Implement GearScore detection
- [ ] Add per-boss overrides
- [ ] Fine-tune values through testing
- [ ] Documentation

---

## Testing Requirements

### Scaling Verification
- Test each dungeon with 1, 2, 3, 4, 5 players
- Verify boss mechanics still work
- Check M+ timer feasibility
- Measure DPS requirements

### Edge Cases
- Solo player with max GS
- Full group with low GS
- Mixed GS groups
- High keystone levels (15+)

---

## Existing Resources

### mod-autobalance Features
- Player count scaling
- Level-based adjustments
- Per-map configuration
- Creature stat modification

### What We're Adding
- Mythic+ awareness
- GearScore integration
- Level 255 tuning
- More granular overrides

---

## Estimated Costs

| Resource | Estimate |
|----------|----------|
| Development Time | 3-5 days |
| Configuration Tuning | 1-2 days |
| Testing | 2-3 days |
| Ongoing Maintenance | Low |

---

## Success Metrics

- Dungeon completion times (target range)
- Player death rates (not too low, not too high)
- M+ key depletion rates
- Player feedback on difficulty

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Over-tuning bosses | Start conservative, increase gradually |
| Breaking mechanics | Test all boss phases manually |
| GS gaming | Server-side GS calculation only |
| Performance impact | Cache scaling values per map |

---

**Recommendation:** This is a high-priority enhancement that directly improves the Mythic+ experience. Start with M+ integration, then add GearScore awareness based on player feedback.
