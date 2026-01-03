# Mythic+ Extended Affixes System

**Priority:** S-Tier  
**Effort:** Medium (2-3 weeks)  
**Impact:** Very High  
**Target System:** `src/server/scripts/DC/MythicPlus/`

---

## Current State Analysis

### Existing Affixes (8 total)
```cpp
enum AffixType : uint8
{
    AFFIX_NONE = 0,
    AFFIX_BOLSTERING = 1,    // +20% HP/damage on nearby death
    AFFIX_NECROTIC = 2,      // Stacking healing reduction
    AFFIX_GRIEVOUS = 3,      // Periodic damage below 90% HP
    AFFIX_TYRANNICAL = 4,    // Bosses +40% HP, +15% damage
    AFFIX_FORTIFIED = 5,     // Non-boss +20% HP, +30% damage
    AFFIX_RAGING = 6,        // +100% damage at low HP, immune to CC
    AFFIX_SANGUINE = 7,      // Death pools heal enemies
    AFFIX_VOLCANIC = 8,      // Plumes under distant players
};
```

### Current Architecture
- `IAffixHandler` interface with lifecycle and event hooks
- `MythicPlusAffixManager` singleton for registration/dispatch
- Per-instance affix state tracking
- Keystone level integration

---

## Proposed New Affixes

### Tier 1: Keystone 2+ (Base Affixes)
| Affix | Effect | Implementation |
|-------|--------|----------------|
| **Bursting** | Enemies explode on death, stacking damage | `OnCreatureDeath` + DoT application |
| **Spiteful** | Shades spawn on death, attack random player | `OnCreatureDeath` + creature spawn |
| **Inspiring** | Some enemies buff nearby allies | `OnCreatureSpawn` + aura application |
| **Explosive** | Orbs spawn during combat, must be killed | Periodic `OnCreatureUpdate` + spawn |

### Tier 2: Keystone 7+ (Dungeon Affixes)
| Affix | Effect | Implementation |
|-------|--------|----------------|
| **Quaking** | Periodic AoE centered on players | Player update + damage spell |
| **Storming** | Tornadoes spawn during combat | Combat zone spawn + movement |
| **Prideful** | Manifestations spawn every 20% trash | Progress tracking + boss spawn |
| **Xal'atath's Bargain** | Choose debuff for random buffs | UI choice + random effect |

### Tier 3: Keystone 14+ (Seasonal Affixes)
| Affix | Effect | Implementation |
|-------|--------|----------------|
| **Awakened** | Obelisks skip to mini-boss | GameObject spawn + teleport |
| **Encrypted** | Automa grant buffs when killed | Special creature + buff aura |
| **Shrouded** | Dreadlords disguised as enemies | Creature disguise + reveal |
| **Thundering** | Mark of positive/negative charge | Periodic debuff + collision damage |

---

## Implementation

### New Affix Handler: Bursting
```cpp
class BurstingAffixHandler : public IAffixHandler
{
public:
    AffixType GetType() const override { return AFFIX_BURSTING; }
    std::string GetName() const override { return "Bursting"; }
    std::string GetDescription() const override 
    { 
        return "When enemies die, they burst, dealing damage to all players. Stacks."; 
    }

    void OnAffixActivate(Map* map, uint8 keystoneLevel) override
    {
        _keystoneLevel = keystoneLevel;
        _burstingDamageBase = 2000 + (keystoneLevel * 500); // Scale with key level
    }

    void OnAffixDeactivate(Map* map) override
    {
        // Clear any lingering bursting debuffs
    }

    void OnCreatureDeath(Creature* creature, Unit* killer) override
    {
        if (!creature || creature->IsDungeonBoss())
            return;

        Map* map = creature->GetMap();
        if (!map)
            return;

        // Apply bursting to all players in instance
        map->DoForAllPlayers([this](Player* player)
        {
            if (!player || !player->IsAlive())
                return;

            // Stack bursting debuff
            Aura* existing = player->GetAura(SPELL_BURSTING_DEBUFF);
            if (existing)
            {
                existing->ModStackAmount(1);
                existing->RefreshDuration();
            }
            else
            {
                player->CastSpell(player, SPELL_BURSTING_DEBUFF, true);
            }
        });
    }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        // Bursting damage tick is handled by the aura spell script
    }

private:
    uint8 _keystoneLevel = 0;
    uint32 _burstingDamageBase = 2000;
};
```

### New Affix Handler: Spiteful
```cpp
class SpitefulAffixHandler : public IAffixHandler
{
public:
    AffixType GetType() const override { return AFFIX_SPITEFUL; }
    std::string GetName() const override { return "Spiteful"; }
    std::string GetDescription() const override 
    { 
        return "Fiends spawn from slain enemies and fixate on random players."; 
    }

    void OnCreatureDeath(Creature* creature, Unit* killer) override
    {
        if (!creature || creature->IsDungeonBoss())
            return;

        Map* map = creature->GetMap();
        if (!map)
            return;

        // 30% chance to spawn shade
        if (!roll_chance_f(30.0f))
            return;

        // Spawn spiteful shade at corpse location
        Position pos = creature->GetPosition();
        if (Creature* shade = map->SummonCreature(NPC_SPITEFUL_SHADE, pos))
        {
            // Set shade HP based on keystone level
            uint32 hp = 50000 + (_keystoneLevel * 10000);
            shade->SetMaxHealth(hp);
            shade->SetHealth(hp);

            // Fixate on random player
            if (Player* target = GetRandomPlayerInMap(map))
            {
                shade->AI()->AttackStart(target);
                shade->AddThreat(target, 999999.0f);
                shade->SetInCombatWith(target);
            }

            // Shade despawns after 8 seconds
            shade->DespawnOrUnsummon(8s);
        }
    }

private:
    uint8 _keystoneLevel = 0;
};
```

### New Affix Handler: Explosive
```cpp
class ExplosiveAffixHandler : public IAffixHandler
{
public:
    AffixType GetType() const override { return AFFIX_EXPLOSIVE; }
    std::string GetName() const override { return "Explosive"; }
    std::string GetDescription() const override 
    { 
        return "Explosive orbs spawn during combat and explode if not killed."; 
    }

    void OnAffixActivate(Map* map, uint8 keystoneLevel) override
    {
        _keystoneLevel = keystoneLevel;
        _orbSpawnTimer = 0;
        _orbSpawnInterval = 8000 - (keystoneLevel * 200); // Faster at higher keys
        if (_orbSpawnInterval < 3000)
            _orbSpawnInterval = 3000;
    }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        if (!player->IsInCombat())
            return;

        _orbSpawnTimer += diff;
        if (_orbSpawnTimer < _orbSpawnInterval)
            return;

        _orbSpawnTimer = 0;

        // Find nearby combat and spawn orb
        Map* map = player->GetMap();
        if (!map)
            return;

        // Spawn explosive orb near a random enemy in combat
        Creature* nearestEnemy = GetNearestHostileCreature(player, 40.0f);
        if (!nearestEnemy)
            return;

        Position pos = nearestEnemy->GetRandomNearPosition(5.0f);
        if (Creature* orb = map->SummonCreature(NPC_EXPLOSIVE_ORB, pos))
        {
            // Low HP, must be killed quickly
            uint32 hp = 1000 + (_keystoneLevel * 100);
            orb->SetMaxHealth(hp);
            orb->SetHealth(hp);
            orb->SetUnitFlag(UNIT_FLAG_IMMUNE_TO_NPC);

            // Explode after 6 seconds if not killed
            orb->m_Events.AddEvent(new ExplosiveOrbExplodeEvent(orb, map), 
                orb->m_Events.CalculateTime(6s));
        }
    }

private:
    uint8 _keystoneLevel = 0;
    uint32 _orbSpawnTimer = 0;
    uint32 _orbSpawnInterval = 8000;
};
```

---

## Affix Rotation Configuration

### Database Schema
```sql
-- Affix rotation per season and week
CREATE TABLE dc_mythic_affix_rotation (
    season_id INT UNSIGNED NOT NULL,
    week_number TINYINT UNSIGNED NOT NULL,
    affix_tier1 TINYINT UNSIGNED NOT NULL,  -- Level 2+
    affix_tier2 TINYINT UNSIGNED NOT NULL,  -- Level 7+
    affix_tier3 TINYINT UNSIGNED NOT NULL,  -- Level 14+
    PRIMARY KEY (season_id, week_number)
);

-- Season 1 rotation example
INSERT INTO dc_mythic_affix_rotation VALUES
(1, 1, 4, 1, 10),   -- Tyrannical, Bolstering, Bursting
(1, 2, 5, 2, 11),   -- Fortified, Necrotic, Spiteful
(1, 3, 4, 3, 12),   -- Tyrannical, Grievous, Explosive
(1, 4, 5, 6, 13),   -- Fortified, Raging, Quaking
-- ... 12 week rotation
```

### Runtime Affix Selection
```cpp
std::vector<AffixType> MythicPlusRunManager::GetAffixesForKeystone(uint8 keystoneLevel, uint32 seasonId)
{
    std::vector<AffixType> affixes;
    
    uint32 weekNumber = GetCurrentWeekOfSeason(seasonId);
    
    // Query rotation table
    auto stmt = WorldDatabase.GetPreparedStatement(WORLD_SEL_MYTHIC_AFFIX_ROTATION);
    stmt->SetData(0, seasonId);
    stmt->SetData(1, weekNumber);
    
    if (PreparedQueryResult result = WorldDatabase.Query(stmt))
    {
        Field* fields = result->Fetch();
        
        // Tier 1: Always active at 2+
        if (keystoneLevel >= 2)
            affixes.push_back(static_cast<AffixType>(fields[0].Get<uint8>()));
        
        // Tier 2: Active at 7+
        if (keystoneLevel >= 7)
            affixes.push_back(static_cast<AffixType>(fields[1].Get<uint8>()));
        
        // Tier 3: Active at 14+
        if (keystoneLevel >= 14)
            affixes.push_back(static_cast<AffixType>(fields[2].Get<uint8>()));
    }
    
    return affixes;
}
```

---

## Spells Required

### New Spell IDs (900xxx range)
| Spell ID | Name | Type |
|----------|------|------|
| 900030 | Bursting | Periodic Damage DoT |
| 900031 | Spiteful Fixate | Threat Aura |
| 900032 | Explosive Orb Detonation | AoE Damage |
| 900033 | Quaking | Player-Centered AoE |
| 900034 | Storming | Ground Effect Damage |
| 900035 | Thundering Positive | Mark Debuff |
| 900036 | Thundering Negative | Mark Debuff |
| 900037 | Inspiring | Nearby Enemy Buff |

---

## AIO Addon Display

### Affix Icons in Dungeon
```lua
-- MythicPlusAffixDisplay.lua
local AffixFrame = AIO.AddAddon()

local AFFIX_ICONS = {
    [1] = "Interface\\Icons\\Ability_Warrior_Warbringer",  -- Bolstering
    [2] = "Interface\\Icons\\Ability_Rogue_FeignDeath",    -- Necrotic
    [3] = "Interface\\Icons\\Ability_Warrior_Bloodfrenzy", -- Grievous
    [4] = "Interface\\Icons\\Achievement_Boss_Archimonde", -- Tyrannical
    [5] = "Interface\\Icons\\Ability_Toughness",           -- Fortified
    [6] = "Interface\\Icons\\Ability_Druid_ChallengingRoar", -- Raging
    [7] = "Interface\\Icons\\Spell_Shadow_BloodBoil",      -- Sanguine
    [8] = "Interface\\Icons\\Spell_Shaman_LavaFlow",       -- Volcanic
    [10] = "Interface\\Icons\\Spell_Shadow_UnstableAffliction", -- Bursting
    [11] = "Interface\\Icons\\Ability_Warlock_ShadowFlame", -- Spiteful
    [12] = "Interface\\Icons\\Spell_Fire_FelFlameRing",    -- Explosive
    [13] = "Interface\\Icons\\Spell_Nature_Earthquake",    -- Quaking
}

function AffixFrame:UpdateAffixes(affixList)
    for i = 1, 3 do
        local icon = self.affixIcons[i]
        local affix = affixList[i]
        
        if affix and AFFIX_ICONS[affix] then
            icon:SetTexture(AFFIX_ICONS[affix])
            icon:Show()
        else
            icon:Hide()
        end
    end
end
```

---

## Timeline

| Phase | Duration | Tasks |
|-------|----------|-------|
| Design | 3 days | Finalize affix mechanics, spell IDs |
| Core | 1 week | Implement 4 new affix handlers |
| Spells | 3 days | Create/test affix spells |
| Rotation | 2 days | Database schema, rotation config |
| UI | 2 days | AIO addon affix display |
| Testing | 1 week | Balance testing across key levels |
| **Total** | **~2.5 weeks** | |

---

## Future Affixes (Phase 2)

| Affix | Effect | Complexity |
|-------|--------|------------|
| Infested | Enemies spawn parasites | Medium |
| Awakened | Obelisk mini-bosses | High |
| Encrypted | Automa buffs | Medium |
| Shrouded | Disguised dreadlords | High |
| Incorporeal | Immunity enemies | Low |
| Afflicted | Healing/dispel check | Low |
| Entangling | Root zones | Low |
