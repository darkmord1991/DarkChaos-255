/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 */

#include "dc_mythicplus_affixes.h"
#include "dc_mythicplus_run_manager.h"
#include "Chat.h"
#include "Creature.h"
#include "GameTime.h"
#include "Map.h"
#include "Player.h"
#include "SpellMgr.h"
#include "SpellAuras.h"
#include "SpellAuraEffects.h"
#include "ObjectAccessor.h"
#include "GridNotifiers.h"
#include "GridNotifiersImpl.h"
#include "CellImpl.h"
#include <algorithm>
#include <cmath>
#include <unordered_set>
#include <vector>

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
        if (!creature || sMythicRuns->IsBossCreature(creature))
            return;

        // Find nearby non-boss creatures and bolster them
        std::list<Creature*> nearbyCreatures;
        Acore::AllWorldObjectsInRange checker(creature, 30.0f);
        Acore::CreatureListSearcher<Acore::AllWorldObjectsInRange> searcher(creature, nearbyCreatures, checker);
        Cell::VisitObjects(creature, searcher, 30.0f);

        for (Creature* ally : nearbyCreatures)
        {
            if (!ally || ally == creature || sMythicRuns->IsBossCreature(ally) || ally->isDead())
                continue;

            if (!ally->IsFriendlyTo(creature))
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
            if (sSpellMgr->GetSpellInfo(SPELL_BOLSTERING_AFFIX))
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
        if (sSpellMgr->GetSpellInfo(SPELL_NECROTIC_AFFIX))
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
    std::unordered_map<uint64 /* instanceKey */, std::unordered_map<ObjectGuid, uint32>> _playerTimers;
    static constexpr uint32 CHECK_INTERVAL = 3000; // 3 seconds

public:
    AffixType GetType() const override { return AFFIX_GRIEVOUS; }
    std::string GetName() const override { return "Grievous"; }
    std::string GetDescription() const override
    {
        return "While below 90% health, players are afflicted with Grievous Wound, "
               "dealing increasing damage over time until healed above 90%.";
    }

    void OnAffixActivate(Map* map, uint8 /*keystoneLevel*/) override
    {
        _playerTimers.erase(sAffixMgr->MakeInstanceKey(map));
    }

    void OnAffixDeactivate(Map* map) override
    {
        _playerTimers.erase(sAffixMgr->MakeInstanceKey(map));
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

        Map* map = player->GetMap();
        if (!map)
            return;

        ObjectGuid guid = player->GetGUID();
        uint32& timer = _playerTimers[sAffixMgr->MakeInstanceKey(map)][guid];

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
                    // Increase stacks if still below 10
                    if (aura->GetStackAmount() < 10)
                        aura->ModStackAmount(1);

                    // Deal damage based on stacks (each stack = 1% max HP per tick)
                    uint32 damagePerStack = player->GetMaxHealth() / 100;
                    uint32 totalDamage = damagePerStack * aura->GetStackAmount();
                    Unit::DealDamage(player, player, totalDamage, nullptr, NODAMAGE, SPELL_SCHOOL_MASK_SHADOW, spellInfo, false);
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
public:
    AffixType GetType() const override { return AFFIX_TYRANNICAL; }
    std::string GetName() const override { return "Tyrannical"; }
    std::string GetDescription() const override
    {
        return "Boss enemies have 40% more health and inflict 15% more damage.";
    }

    void OnAffixActivate(Map* /*map*/, uint8 /*keystoneLevel*/) override { }
    void OnAffixDeactivate(Map* /*map*/) override { }

    void OnCreatureDeath(Creature* /*creature*/, Unit* /*killer*/) override { }

    void OnCreatureDamageDone(Creature* attacker, Unit* /*victim*/, uint32& damage) override
    {
        if (!attacker || !sMythicRuns->IsBossCreature(attacker))
            return;

        // +15% damage
        damage = uint32(damage * 1.15f);
    }

    void OnCreatureDamageTaken(Creature* /*victim*/, Unit* /*attacker*/, uint32& /*damage*/) override { }
    void OnPlayerDamageTaken(Player* /*player*/, Unit* /*attacker*/, uint32& /*damage*/) override { }

    void OnCreatureSelectLevel(Creature* creature) override
    {
        if (!creature || !sMythicRuns->IsBossCreature(creature))
            return;

        // No dedupe set here on purpose. SelectLevel resets health to base
        // before this hook runs, so applying the multiplier every time is both
        // correct and idempotent. The old per-instance GUID set made this a
        // one-shot, and ApplyKeystoneScaling re-runs SelectLevel twice during
        // activation - so the affix bonus was applied, then wiped by the reset,
        // then skipped on the way back. Tyrannical bosses ended up with exactly
        // the health they would have had without the affix.
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
        if (!attacker || sMythicRuns->IsBossCreature(attacker))
            return;

        // +30% damage for non-bosses
        damage = uint32(damage * 1.30f);
    }

    void OnCreatureDamageTaken(Creature* /*victim*/, Unit* /*attacker*/, uint32& /*damage*/) override { }
    void OnPlayerDamageTaken(Player* /*player*/, Unit* /*attacker*/, uint32& /*damage*/) override { }

    void OnCreatureSelectLevel(Creature* creature) override
    {
        if (!creature || sMythicRuns->IsBossCreature(creature))
            return;

        // Idempotent per SelectLevel call - see the note in TyrannicalAffixHandler
        // for why the per-instance dedupe set had to go.
        uint32 baseHealth = creature->GetMaxHealth();
        uint32 newHealth = uint32(baseHealth * 1.20f);
        creature->SetCreateHealth(newHealth);
        creature->SetMaxHealth(newHealth);
        creature->SetHealth(newHealth);
    }

    void OnPlayerUpdate(Player* /*player*/, uint32 /*diff*/) override { }
};

// ============================================================================
// RAGING AFFIX
// Enemies enrage below 30% health, dealing 100% extra damage and shrugging off
// crowd control until they die.
// ============================================================================
class RagingAffixHandler : public IAffixHandler
{
private:
    static constexpr float ENRAGE_HEALTH_PCT = 30.0f;
    static constexpr float ENRAGE_DAMAGE_MULT = 2.0f;

public:
    AffixType GetType() const override { return AFFIX_RAGING; }
    std::string GetName() const override { return "Raging"; }
    std::string GetDescription() const override
    {
        return "Non-boss enemies enrage below 30% health, dealing 100% additional "
               "damage and becoming immune to crowd control until defeated.";
    }

    void OnAffixActivate(Map* /*map*/, uint8 /*keystoneLevel*/) override { }
    void OnAffixDeactivate(Map* /*map*/) override { }
    void OnCreatureDeath(Creature* /*creature*/, Unit* /*killer*/) override { }

    void OnCreatureDamageDone(Creature* attacker, Unit* /*victim*/, uint32& damage) override
    {
        if (!attacker || !attacker->IsAlive())
            return;

        // Bosses are Tyrannical's business; Raging is a trash affix.
        if (sMythicRuns->IsBossCreature(attacker))
            return;

        if (attacker->GetHealthPct() >= ENRAGE_HEALTH_PCT)
            return;

        damage = uint32(damage * ENRAGE_DAMAGE_MULT);
    }

    void OnCreatureDamageTaken(Creature* victim, Unit* /*attacker*/, uint32& /*damage*/) override
    {
        if (!victim || !victim->IsAlive())
            return;

        if (sMythicRuns->IsBossCreature(victim))
            return;

        if (victim->GetHealthPct() >= ENRAGE_HEALTH_PCT)
            return;

        // Break and refuse crowd control for the rest of the fight. Applied on
        // damage taken so it engages the moment the enemy is pushed below the
        // threshold, without needing a per-creature tick.
        if (victim->HasUnitState(UNIT_STATE_STUNNED | UNIT_STATE_CONFUSED | UNIT_STATE_FLEEING))
        {
            victim->RemoveAurasByType(SPELL_AURA_MOD_STUN);
            victim->RemoveAurasByType(SPELL_AURA_MOD_CONFUSE);
            victim->RemoveAurasByType(SPELL_AURA_MOD_FEAR);
        }

        victim->ApplySpellImmune(0, IMMUNITY_STATE, SPELL_AURA_MOD_STUN, true);
        victim->ApplySpellImmune(0, IMMUNITY_STATE, SPELL_AURA_MOD_CONFUSE, true);
        victim->ApplySpellImmune(0, IMMUNITY_STATE, SPELL_AURA_MOD_FEAR, true);
    }

    void OnPlayerDamageTaken(Player* /*player*/, Unit* /*attacker*/, uint32& /*damage*/) override { }
    void OnCreatureSelectLevel(Creature* /*creature*/) override { }
    void OnPlayerUpdate(Player* /*player*/, uint32 /*diff*/) override { }
};

// ============================================================================
// SANGUINE AFFIX
// Slain non-boss enemies leave a pool of blood that damages players standing
// in it and heals enemies who walk through.
// ============================================================================
class SanguineAffixHandler : public IAffixHandler
{
private:
    struct SanguinePool
    {
        float x = 0.0f;
        float y = 0.0f;
        float z = 0.0f;
        uint64 expiresAt = 0;
    };

    // Keyed per instance so concurrent runs of the same dungeon cannot see each
    // other's pools.
    std::unordered_map<uint64 /* instanceKey */, std::vector<SanguinePool>> _pools;
    std::unordered_map<uint64 /* instanceKey */, uint32> _tickAccumulator;

    static constexpr float POOL_RADIUS = 5.0f;
    static constexpr uint32 POOL_DURATION_SECONDS = 12;
    static constexpr uint32 TICK_INTERVAL_MS = 1000;
    static constexpr float PLAYER_DAMAGE_PCT = 3.0f;   // of max health, per tick
    static constexpr float CREATURE_HEAL_PCT = 5.0f;   // of max health, per tick

    void PruneExpired(std::vector<SanguinePool>& pools, uint64 now) const
    {
        pools.erase(std::remove_if(pools.begin(), pools.end(),
            [now](SanguinePool const& pool) { return pool.expiresAt <= now; }),
            pools.end());
    }

public:
    AffixType GetType() const override { return AFFIX_SANGUINE; }
    std::string GetName() const override { return "Sanguine"; }
    std::string GetDescription() const override
    {
        return "Slain enemies leave behind a pool of blood that damages players "
               "who stand in it and heals their allies.";
    }

    void OnAffixActivate(Map* map, uint8 /*keystoneLevel*/) override
    {
        uint64 key = sAffixMgr->MakeInstanceKey(map);
        _pools.erase(key);
        _tickAccumulator.erase(key);
    }

    void OnAffixDeactivate(Map* map) override
    {
        uint64 key = sAffixMgr->MakeInstanceKey(map);
        _pools.erase(key);
        _tickAccumulator.erase(key);
    }

    void OnCreatureDeath(Creature* creature, Unit* /*killer*/) override
    {
        if (!creature || sMythicRuns->IsBossCreature(creature))
            return;

        Map* map = creature->GetMap();
        if (!map)
            return;

        SanguinePool pool;
        pool.x = creature->GetPositionX();
        pool.y = creature->GetPositionY();
        pool.z = creature->GetPositionZ();
        pool.expiresAt = GameTime::GetGameTime().count() + POOL_DURATION_SECONDS;

        _pools[sAffixMgr->MakeInstanceKey(map)].push_back(pool);
    }

    void OnCreatureDamageDone(Creature* /*attacker*/, Unit* /*victim*/, uint32& /*damage*/) override { }
    void OnCreatureDamageTaken(Creature* /*victim*/, Unit* /*attacker*/, uint32& /*damage*/) override { }
    void OnPlayerDamageTaken(Player* /*player*/, Unit* /*attacker*/, uint32& /*damage*/) override { }
    void OnCreatureSelectLevel(Creature* /*creature*/) override { }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        if (!player || !player->IsAlive())
            return;

        Map* map = player->GetMap();
        if (!map)
            return;

        uint64 key = sAffixMgr->MakeInstanceKey(map);
        auto poolItr = _pools.find(key);
        if (poolItr == _pools.end() || poolItr->second.empty())
            return;

        // One shared accumulator per instance rather than per player, so the
        // pool ticks at a fixed rate no matter how many players are inside it.
        uint32& accumulator = _tickAccumulator[key];
        accumulator += diff;
        if (accumulator < TICK_INTERVAL_MS)
            return;
        accumulator = 0;

        uint64 now = GameTime::GetGameTime().count();
        PruneExpired(poolItr->second, now);
        if (poolItr->second.empty())
            return;

        for (SanguinePool const& pool : poolItr->second)
        {
            if (!player->IsWithinDist3d(pool.x, pool.y, pool.z, POOL_RADIUS))
                continue;

            uint32 damage = uint32(player->GetMaxHealth() * (PLAYER_DAMAGE_PCT / 100.0f));
            if (damage)
            {
                Unit::DealDamage(player, player, damage, nullptr, NODAMAGE,
                    SPELL_SCHOOL_MASK_SHADOW, nullptr, false);
            }

            // Heal enemies sharing the pool.
            std::list<Creature*> nearby;
            Acore::AllWorldObjectsInRange checker(player, POOL_RADIUS);
            Acore::CreatureListSearcher<Acore::AllWorldObjectsInRange> searcher(player, nearby, checker);
            Cell::VisitObjects(player, searcher, POOL_RADIUS);

            for (Creature* ally : nearby)
            {
                if (!ally || !ally->IsAlive() || ally->IsControlledByPlayer())
                    continue;

                if (!ally->IsHostileToPlayers())
                    continue;

                uint32 heal = uint32(ally->GetMaxHealth() * (CREATURE_HEAL_PCT / 100.0f));
                if (heal)
                    ally->SetHealth(std::min<uint32>(ally->GetHealth() + heal, ally->GetMaxHealth()));
            }

            break; // One pool's worth of damage per tick is enough.
        }
    }
};

// ============================================================================
// VOLCANIC AFFIX
// Volcanic plumes erupt beneath players who stay at range, knocking them up and
// dealing damage. Punishes standing still at distance.
// ============================================================================
class VolcanicAffixHandler : public IAffixHandler
{
private:
    std::unordered_map<uint64 /* instanceKey */, std::unordered_map<ObjectGuid, uint32>> _playerTimers;

    static constexpr uint32 CHECK_INTERVAL_MS = 8000;
    static constexpr float MIN_RANGE_FROM_ENEMY = 10.0f;
    static constexpr float SEARCH_RANGE = 40.0f;
    static constexpr float DAMAGE_PCT = 12.0f; // of max health

public:
    AffixType GetType() const override { return AFFIX_VOLCANIC; }
    std::string GetName() const override { return "Volcanic"; }
    std::string GetDescription() const override
    {
        return "While in combat, volcanic plumes erupt beneath distant players, "
               "dealing heavy fire damage.";
    }

    void OnAffixActivate(Map* map, uint8 /*keystoneLevel*/) override
    {
        _playerTimers.erase(sAffixMgr->MakeInstanceKey(map));
    }

    void OnAffixDeactivate(Map* map) override
    {
        _playerTimers.erase(sAffixMgr->MakeInstanceKey(map));
    }

    void OnCreatureDeath(Creature* /*creature*/, Unit* /*killer*/) override { }
    void OnCreatureDamageDone(Creature* /*attacker*/, Unit* /*victim*/, uint32& /*damage*/) override { }
    void OnCreatureDamageTaken(Creature* /*victim*/, Unit* /*attacker*/, uint32& /*damage*/) override { }
    void OnPlayerDamageTaken(Player* /*player*/, Unit* /*attacker*/, uint32& /*damage*/) override { }
    void OnCreatureSelectLevel(Creature* /*creature*/) override { }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        if (!player || !player->IsAlive() || !player->IsInCombat())
            return;

        Map* map = player->GetMap();
        if (!map)
            return;

        uint32& timer = _playerTimers[sAffixMgr->MakeInstanceKey(map)][player->GetGUID()];
        if (timer > diff)
        {
            timer -= diff;
            return;
        }
        timer = CHECK_INTERVAL_MS;

        // Only players holding range are targeted - melee standing on the enemy
        // are exempt, which is what makes this a positioning affix.
        std::list<Creature*> nearby;
        Acore::AllWorldObjectsInRange checker(player, SEARCH_RANGE);
        Acore::CreatureListSearcher<Acore::AllWorldObjectsInRange> searcher(player, nearby, checker);
        Cell::VisitObjects(player, searcher, SEARCH_RANGE);

        bool hasDistantEnemy = false;
        for (Creature* enemy : nearby)
        {
            if (!enemy || !enemy->IsAlive() || !enemy->IsInCombat())
                continue;

            if (enemy->IsControlledByPlayer() || !enemy->IsHostileToPlayers())
                continue;

            if (player->IsWithinDist(enemy, MIN_RANGE_FROM_ENEMY))
                return; // In melee of something - safe.

            hasDistantEnemy = true;
        }

        if (!hasDistantEnemy)
            return;

        uint32 damage = uint32(player->GetMaxHealth() * (DAMAGE_PCT / 100.0f));
        if (!damage)
            return;

        Unit::DealDamage(player, player, damage, nullptr, NODAMAGE,
            SPELL_SCHOOL_MASK_FIRE, nullptr, false);

        if (player->GetSession())
        {
            ChatHandler(player->GetSession()).SendSysMessage(
                "|cffff4400[Volcanic]|r A plume erupts beneath you!");
        }
    }
};

// Register all affixes
void RegisterMythicPlusAffixHandlers()
{
    sAffixMgr->RegisterAffix(std::make_unique<BolsteringAffixHandler>());
    sAffixMgr->RegisterAffix(std::make_unique<NecroticAffixHandler>());
    sAffixMgr->RegisterAffix(std::make_unique<GrievousAffixHandler>());
    sAffixMgr->RegisterAffix(std::make_unique<TyrannicalAffixHandler>());
    sAffixMgr->RegisterAffix(std::make_unique<FortifiedAffixHandler>());
    sAffixMgr->RegisterAffix(std::make_unique<RagingAffixHandler>());
    sAffixMgr->RegisterAffix(std::make_unique<SanguineAffixHandler>());
    sAffixMgr->RegisterAffix(std::make_unique<VolcanicAffixHandler>());
}
