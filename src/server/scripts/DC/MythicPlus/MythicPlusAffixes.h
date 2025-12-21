/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 */

#ifndef MYTHIC_PLUS_AFFIXES_H
#define MYTHIC_PLUS_AFFIXES_H

#include "ObjectGuid.h"
#include "SharedDefines.h"
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

class Creature;
class Map;
class Player;
class Unit;

// Affix spell IDs
constexpr uint32 SPELL_BOLSTERING_AFFIX = 900010;
constexpr uint32 SPELL_NECROTIC_AFFIX = 900020;
constexpr uint32 SPELL_GRIEVOUS_AFFIX = 900030;

// Affix types
enum AffixType : uint8
{
    AFFIX_NONE = 0,
    AFFIX_BOLSTERING = 1,    // Non-boss enemies +20% HP and damage when nearby enemies die
    AFFIX_NECROTIC = 2,      // Melee attacks apply stacking healing reduction
    AFFIX_GRIEVOUS = 3,      // Players below 90% HP take periodic damage
    AFFIX_TYRANNICAL = 4,    // Bosses +40% HP and +15% damage
    AFFIX_FORTIFIED = 5,     // Non-boss enemies +20% HP and +30% damage
    AFFIX_RAGING = 6,        // Enemies +100% damage at low HP, can't be CC'd
    AFFIX_SANGUINE = 7,      // Enemies leave damaging pools on death that heal other enemies
    AFFIX_VOLCANIC = 8,      // Volcanic plumes erupt under distant players
};

// Base affix handler interface
class IAffixHandler
{
public:
    virtual ~IAffixHandler() = default;

    virtual AffixType GetType() const = 0;
    virtual std::string GetName() const = 0;
    virtual std::string GetDescription() const = 0;

    // Lifecycle hooks
    virtual void OnAffixActivate(Map* map, uint8 keystoneLevel) = 0;
    virtual void OnAffixDeactivate(Map* map) = 0;

    // Event hooks
    virtual void OnCreatureDeath(Creature* creature, Unit* killer) = 0;
    virtual void OnCreatureDamageDone(Creature* attacker, Unit* victim, uint32& damage) = 0;
    virtual void OnCreatureDamageTaken(Creature* victim, Unit* attacker, uint32& damage) = 0;
    virtual void OnPlayerDamageTaken(Player* player, Unit* attacker, uint32& damage) = 0;
    virtual void OnCreatureSelectLevel(Creature* creature) = 0;
    virtual void OnPlayerUpdate(Player* player, uint32 diff) = 0;
};

// Affix manager - handles affix registration and event dispatch
class MythicPlusAffixManager
{
public:
    static MythicPlusAffixManager* instance();

    void RegisterAffix(std::unique_ptr<IAffixHandler> handler);
    void ActivateAffixes(Map* map, const std::vector<AffixType>& affixes, uint8 keystoneLevel);
    void DeactivateAffixes(Map* map);

    // Event dispatchers
    void OnCreatureDeath(Creature* creature, Unit* killer);
    void OnCreatureDamageDone(Creature* attacker, Unit* victim, uint32& damage);
    void OnCreatureDamageTaken(Creature* victim, Unit* attacker, uint32& damage);
    void OnPlayerDamageTaken(Player* player, Unit* attacker, uint32& damage);
    void OnCreatureSelectLevel(Creature* creature);
    void OnPlayerUpdate(Player* player, uint32 diff);

    std::vector<AffixType> GetActiveAffixes(Map* map) const;
    uint8 GetKeystoneLevel(Map* map) const;

private:
    MythicPlusAffixManager() = default;

    struct InstanceAffixState
    {
        std::vector<AffixType> activeAffixes;
        uint8 keystoneLevel = 0;
    };

    std::unordered_map<AffixType, std::unique_ptr<IAffixHandler>> _handlers;
    std::unordered_map<uint64, InstanceAffixState> _instanceStates; // Key combines instance + map ID

    uint64 MakeInstanceKey(const Map* map) const;
    InstanceAffixState* GetInstanceState(Map* map);
};

#define sAffixMgr MythicPlusAffixManager::instance()

#endif // MYTHIC_PLUS_AFFIXES_H
