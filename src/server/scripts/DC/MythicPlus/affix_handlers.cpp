/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 */

#include "MythicPlusAffixes.h"
#include "Creature.h"
#include "Map.h"
#include "Player.h"
#include "SpellMgr.h"
#include "SpellAuras.h"
#include "SpellAuraEffects.h"
#include "ObjectAccessor.h"
#include "GridNotifiers.h"
#include "GridNotifiersImpl.h"
#include "CellImpl.h"
#include <cmath>

// ============================================================================
// BOLSTERING AFFIX
// When a non-boss enemy dies, it bolsters nearby allies within 30 yards,
// increasing their health and damage by 20% (stacking).
// ============================================================================
class BolsteringAffixHandler : public IAffixHandler
{
public:
    AffixType GetType() const override { return AFFIX_BOLSTERING; }
    std::string GetName() const override { return "Bolstering"; }
    std::string GetDescription() const override 
    { 
        return "When any non-boss enemy dies, its death cry empowers nearby allies, "
               "increasing their maximum health and damage by 20%."; 
    }
    
    void OnAffixActivate(Map* /*map*/, uint8 /*keystoneLevel*/) override { }
    void OnAffixDeactivate(Map* /*map*/) override { }
    
    void OnCreatureDeath(Creature* creature, Unit* /*killer*/) override
    {
        if (!creature || creature->IsDungeonBoss())
            return;
            
        // Find nearby non-boss creatures and bolster them
        std::list<Creature*> nearbyCreatures;
        Acore::AllWorldObjectsInRange checker(creature, 30.0f);
        Acore::CreatureListSearcher<Acore::AllWorldObjectsInRange> searcher(creature, nearbyCreatures, checker);
        Cell::VisitObjects(creature, searcher, 30.0f);
        
        for (Creature* ally : nearbyCreatures)
        {
            if (!ally || ally == creature || ally->IsDungeonBoss() || ally->isDead())
                continue;
                
            if (!ally->IsHostileTo(creature))
                continue;
                
            // Apply bolster: +20% HP and damage
            uint32 currentMax = ally->GetMaxHealth();
            uint32 newMax = uint32(currentMax * 1.20f);
            ally->SetMaxHealth(newMax);
            ally->SetHealth(std::min(ally->GetHealth() + (newMax - currentMax), newMax));
            
            // Increase damage
            float currentMinDmg = ally->GetFloatValue(UNIT_FIELD_MINDAMAGE);
            float currentMaxDmg = ally->GetFloatValue(UNIT_FIELD_MAXDAMAGE);
            ally->SetBaseWeaponDamage(BASE_ATTACK, MINDAMAGE, currentMinDmg * 1.20f);
            ally->SetBaseWeaponDamage(BASE_ATTACK, MAXDAMAGE, currentMaxDmg * 1.20f);
            
            // Visual: Cast buff spell
            if (SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(SPELL_BOLSTERING_AFFIX))
                ally->CastSpell(ally, SPELL_BOLSTERING_AFFIX, true);
        }
    }
    
    void OnCreatureDamageDone(Creature* /*attacker*/, Unit* /*victim*/, uint32& /*damage*/) override { }
    void OnCreatureDamageTaken(Creature* /*victim*/, Unit* /*attacker*/, uint32& /*damage*/) override { }
    void OnPlayerDamageTaken(Player* /*player*/, Unit* /*attacker*/, uint32& /*damage*/) override { }
    void OnCreatureSelectLevel(Creature* /*creature*/) override { }
    void OnPlayerUpdate(Player* /*player*/, uint32 /*diff*/) override { }
};

// ============================================================================
// NECROTIC AFFIX
// Enemy melee attacks apply a stacking Necrotic Wound debuff that reduces
// healing received and deals damage over time.
// ============================================================================
class NecroticAffixHandler : public IAffixHandler
{
public:
    AffixType GetType() const override { return AFFIX_NECROTIC; }
    std::string GetName() const override { return "Necrotic"; }
    std::string GetDescription() const override 
    { 
        return "All enemies' melee attacks apply a Necrotic Wound, stacking up to 99 times. "
               "Each stack reduces healing received by 1% and deals damage over time."; 
    }
    
    void OnAffixActivate(Map* /*map*/, uint8 /*keystoneLevel*/) override { }
    void OnAffixDeactivate(Map* /*map*/) override { }
    
    void OnCreatureDeath(Creature* /*creature*/, Unit* /*killer*/) override { }
    
    void OnCreatureDamageDone(Creature* attacker, Unit* victim, uint32& /*damage*/) override
    {
        if (!attacker || !victim || !victim->IsPlayer())
            return;
            
        // Only apply on melee attacks
        if (attacker->GetVictim() != victim)
            return;
            
        // Apply Necrotic Wound debuff
        if (SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(SPELL_NECROTIC_AFFIX))
        {
            if (Aura* aura = victim->GetAura(SPELL_NECROTIC_AFFIX))
            {
                // Stack up to 99
                if (aura->GetStackAmount() < 99)
                    aura->ModStackAmount(1);
            }
            else
            {
                attacker->CastSpell(victim, SPELL_NECROTIC_AFFIX, true);
            }
        }
    }
    
    void OnCreatureDamageTaken(Creature* /*victim*/, Unit* /*attacker*/, uint32& /*damage*/) override { }
    void OnPlayerDamageTaken(Player* /*player*/, Unit* /*attacker*/, uint32& /*damage*/) override { }
    void OnCreatureSelectLevel(Creature* /*creature*/) override { }
    void OnPlayerUpdate(Player* /*player*/, uint32 /*diff*/) override { }
};

// ============================================================================
// GRIEVOUS AFFIX
// When injured below 90% health, players suffer increasing stack of Grievous
// Wound, dealing damage every 3 seconds until healed above 90%.
// ============================================================================
class GrievousAffixHandler : public IAffixHandler
{
private:
    std::unordered_map<ObjectGuid, uint32> _playerTimers;
    static constexpr uint32 CHECK_INTERVAL = 3000; // 3 seconds
    
public:
    AffixType GetType() const override { return AFFIX_GRIEVOUS; }
    std::string GetName() const override { return "Grievous"; }
    std::string GetDescription() const override 
    { 
        return "While below 90% health, players are afflicted with Grievous Wound, "
               "dealing increasing damage over time until healed above 90%."; 
    }
    
    void OnAffixActivate(Map* /*map*/, uint8 /*keystoneLevel*/) override 
    {
        _playerTimers.clear();
    }
    
    void OnAffixDeactivate(Map* /*map*/) override 
    {
        _playerTimers.clear();
    }
    
    void OnCreatureDeath(Creature* /*creature*/, Unit* /*killer*/) override { }
    void OnCreatureDamageDone(Creature* /*attacker*/, Unit* /*victim*/, uint32& /*damage*/) override { }
    void OnCreatureDamageTaken(Creature* /*victim*/, Unit* /*attacker*/, uint32& /*damage*/) override { }
    void OnPlayerDamageTaken(Player* /*player*/, Unit* /*attacker*/, uint32& /*damage*/) override { }
    void OnCreatureSelectLevel(Creature* /*creature*/) override { }
    
    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        if (!player || player->isDead())
            return;
            
        ObjectGuid guid = player->GetGUID();
        uint32& timer = _playerTimers[guid];
        
        if (timer > diff)
        {
            timer -= diff;
            return;
        }
        
        timer = CHECK_INTERVAL;
        
        float healthPct = player->GetHealthPct();
        
        // Apply or remove Grievous based on health threshold
        if (healthPct < 90.0f)
        {
            if (SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(SPELL_GRIEVOUS_AFFIX))
            {
                if (Aura* aura = player->GetAura(SPELL_GRIEVOUS_AFFIX))
                {
                    // Increase stacks if still below 90%
                    if (aura->GetStackAmount() < 10)
                        aura->ModStackAmount(1);
                        
                    // Deal damage based on stacks (each stack = 1% max HP per tick)
                    uint32 damagePerStack = player->GetMaxHealth() / 100;
                    uint32 totalDamage = damagePerStack * aura->GetStackAmount();
                    player->DealDamage(player, totalDamage, nullptr, NODAMAGE, SPELL_SCHOOL_MASK_SHADOW, spellInfo, false);
                }
                else
                {
                    player->CastSpell(player, SPELL_GRIEVOUS_AFFIX, true);
                }
            }
        }
        else
        {
            // Remove Grievous when healed above 90%
            player->RemoveAurasDueToSpell(SPELL_GRIEVOUS_AFFIX);
        }
    }
};

// ============================================================================
// TYRANNICAL AFFIX
// Bosses have 40% more health and inflict 15% more damage.
// ============================================================================
class TyrannicalAffixHandler : public IAffixHandler
{
private:
    uint8 _keystoneLevel = 0;
    
public:
    AffixType GetType() const override { return AFFIX_TYRANNICAL; }
    std::string GetName() const override { return "Tyrannical"; }
    std::string GetDescription() const override 
    { 
        return "Boss enemies have 40% more health and inflict 15% more damage."; 
    }
    
    void OnAffixActivate(Map* /*map*/, uint8 keystoneLevel) override 
    {
        _keystoneLevel = keystoneLevel;
    }
    
    void OnAffixDeactivate(Map* /*map*/) override 
    {
        _keystoneLevel = 0;
    }
    
    void OnCreatureDeath(Creature* /*creature*/, Unit* /*killer*/) override { }
    
    void OnCreatureDamageDone(Creature* attacker, Unit* /*victim*/, uint32& damage) override
    {
        if (!attacker || !attacker->IsDungeonBoss())
            return;
            
        // +15% damage
        damage = uint32(damage * 1.15f);
    }
    
    void OnCreatureDamageTaken(Creature* /*victim*/, Unit* /*attacker*/, uint32& /*damage*/) override { }
    void OnPlayerDamageTaken(Player* /*player*/, Unit* /*attacker*/, uint32& /*damage*/) override { }
    
    void OnCreatureSelectLevel(Creature* creature) override
    {
        if (!creature || !creature->IsDungeonBoss())
            return;
            
        // +40% HP for bosses
        uint32 baseHealth = creature->GetMaxHealth();
        uint32 newHealth = uint32(baseHealth * 1.40f);
        creature->SetCreateHealth(newHealth);
        creature->SetMaxHealth(newHealth);
        creature->SetHealth(newHealth);
    }
    
    void OnPlayerUpdate(Player* /*player*/, uint32 /*diff*/) override { }
};

// ============================================================================
// FORTIFIED AFFIX
// Non-boss enemies have 20% more health and inflict 30% more damage.
// ============================================================================
class FortifiedAffixHandler : public IAffixHandler
{
public:
    AffixType GetType() const override { return AFFIX_FORTIFIED; }
    std::string GetName() const override { return "Fortified"; }
    std::string GetDescription() const override 
    { 
        return "Non-boss enemies have 20% more health and inflict 30% more damage."; 
    }
    
    void OnAffixActivate(Map* /*map*/, uint8 /*keystoneLevel*/) override { }
    void OnAffixDeactivate(Map* /*map*/) override { }
    void OnCreatureDeath(Creature* /*creature*/, Unit* /*killer*/) override { }
    
    void OnCreatureDamageDone(Creature* attacker, Unit* /*victim*/, uint32& damage) override
    {
        if (!attacker || attacker->IsDungeonBoss())
            return;
            
        // +30% damage for non-bosses
        damage = uint32(damage * 1.30f);
    }
    
    void OnCreatureDamageTaken(Creature* /*victim*/, Unit* /*attacker*/, uint32& /*damage*/) override { }
    void OnPlayerDamageTaken(Player* /*player*/, Unit* /*attacker*/, uint32& /*damage*/) override { }
    
    void OnCreatureSelectLevel(Creature* creature) override
    {
        if (!creature || creature->IsDungeonBoss())
            return;
            
        // +20% HP for non-bosses
        uint32 baseHealth = creature->GetMaxHealth();
        uint32 newHealth = uint32(baseHealth * 1.20f);
        creature->SetCreateHealth(newHealth);
        creature->SetMaxHealth(newHealth);
        creature->SetHealth(newHealth);
    }
    
    void OnPlayerUpdate(Player* /*player*/, uint32 /*diff*/) override { }
};

// Register all affixes
void RegisterMythicPlusAffixHandlers()
{
    sAffixMgr->RegisterAffix(std::make_unique<BolsteringAffixHandler>());
    sAffixMgr->RegisterAffix(std::make_unique<NecroticAffixHandler>());
    sAffixMgr->RegisterAffix(std::make_unique<GrievousAffixHandler>());
    sAffixMgr->RegisterAffix(std::make_unique<TyrannicalAffixHandler>());
    sAffixMgr->RegisterAffix(std::make_unique<FortifiedAffixHandler>());
}
