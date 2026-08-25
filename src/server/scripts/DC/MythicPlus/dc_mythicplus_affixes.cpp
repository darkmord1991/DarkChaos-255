/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 */

#include "dc_mythicplus_affixes.h"
#include "DC/CrossSystem/CrossSystemAffixes.h"
#include "Creature.h"
#include "Map.h"
#include "Player.h"
#include "Log.h"
#include "SpellAuras.h"
#include "SpellAuraEffects.h"
#include "SpellMgr.h"

MythicPlusAffixManager* MythicPlusAffixManager::instance()
{
    static MythicPlusAffixManager instance;
    return &instance;
}

void MythicPlusAffixManager::RegisterAffix(std::unique_ptr<IAffixHandler> handler)
{
    std::lock_guard<std::recursive_mutex> guard(_affixMutex);

    if (!handler)
        return;

    AffixType type = handler->GetType();
    _handlers[type] = std::move(handler);
    LOG_INFO("mythic.affixes", "Registered affix handler: {}", _handlers[type]->GetName());
}

bool MythicPlusAffixManager::HasHandler(AffixType affix) const
{
    std::lock_guard<std::recursive_mutex> guard(_affixMutex);

    return affix != AFFIX_NONE && _handlers.find(affix) != _handlers.end();
}

std::string MythicPlusAffixManager::GetAffixName(AffixType affix) const
{
    return DarkChaos::CrossSystem::Affixes::GetName(
        DarkChaos::CrossSystem::SystemId::MythicPlus,
        static_cast<uint32>(affix));
}

std::string MythicPlusAffixManager::GetAffixDescription(AffixType affix) const
{
    return DarkChaos::CrossSystem::Affixes::GetDescription(
        DarkChaos::CrossSystem::SystemId::MythicPlus,
        static_cast<uint32>(affix));
}

void MythicPlusAffixManager::ActivateAffixes(Map* map, std::vector<AffixType> const& affixes, uint8 keystoneLevel)
{
    std::lock_guard<std::recursive_mutex> guard(_affixMutex);

    if (!map)
        return;

    uint64 key = MakeInstanceKey(map);
    auto& state = _instanceStates[key];
    state.activeAffixes = affixes;
    state.keystoneLevel = keystoneLevel;

    for (AffixType affix : affixes)
    {
        auto itr = _handlers.find(affix);
        if (itr != _handlers.end())
        {
            itr->second->OnAffixActivate(map, keystoneLevel);
            LOG_INFO("mythic.affixes", "Activated affix {} on map {} instance {}",
                     itr->second->GetName(), map->GetId(), map->GetInstanceId());
        }
    }
}

void MythicPlusAffixManager::DeactivateAffixes(Map* map)
{
    std::lock_guard<std::recursive_mutex> guard(_affixMutex);

    if (!map)
        return;

    uint64 key = MakeInstanceKey(map);
    auto itr = _instanceStates.find(key);
    if (itr == _instanceStates.end())
        return;

    for (AffixType affix : itr->second.activeAffixes)
    {
        auto handlerItr = _handlers.find(affix);
        if (handlerItr != _handlers.end())
        {
            handlerItr->second->OnAffixDeactivate(map);
        }
    }

    _instanceStates.erase(itr);
}

void MythicPlusAffixManager::OnCreatureDeath(Creature* creature, Unit* killer)
{
    std::lock_guard<std::recursive_mutex> guard(_affixMutex);

    if (!creature)
        return;

    Map* map = creature->GetMap();
    InstanceAffixState* state = GetInstanceState(map);
    if (!state)
        return;

    for (AffixType affix : state->activeAffixes)
    {
        auto itr = _handlers.find(affix);
        if (itr != _handlers.end() && itr->second)
            itr->second->OnCreatureDeath(creature, killer);
    }
}

void MythicPlusAffixManager::OnCreatureDamageDone(Creature* attacker, Unit* victim, uint32& damage)
{
    std::lock_guard<std::recursive_mutex> guard(_affixMutex);

    if (!attacker || !victim)
        return;

    Map* map = attacker->GetMap();
    InstanceAffixState* state = GetInstanceState(map);
    if (!state)
        return;

    for (AffixType affix : state->activeAffixes)
    {
        auto itr = _handlers.find(affix);
        if (itr != _handlers.end() && itr->second)
            itr->second->OnCreatureDamageDone(attacker, victim, damage);
    }
}

void MythicPlusAffixManager::OnCreatureDamageTaken(Creature* victim, Unit* attacker, uint32& damage)
{
    std::lock_guard<std::recursive_mutex> guard(_affixMutex);

    if (!victim || !attacker)
        return;

    Map* map = victim->GetMap();
    InstanceAffixState* state = GetInstanceState(map);
    if (!state)
        return;

    for (AffixType affix : state->activeAffixes)
    {
        auto itr = _handlers.find(affix);
        if (itr != _handlers.end() && itr->second)
            itr->second->OnCreatureDamageTaken(victim, attacker, damage);
    }
}

void MythicPlusAffixManager::OnPlayerDamageTaken(Player* player, Unit* attacker, uint32& damage)
{
    std::lock_guard<std::recursive_mutex> guard(_affixMutex);

    if (!player || !attacker)
        return;

    Map* map = player->GetMap();
    InstanceAffixState* state = GetInstanceState(map);
    if (!state)
        return;

    for (AffixType affix : state->activeAffixes)
    {
        auto itr = _handlers.find(affix);
        if (itr != _handlers.end() && itr->second)
            itr->second->OnPlayerDamageTaken(player, attacker, damage);
    }
}

void MythicPlusAffixManager::OnCreatureSelectLevel(Creature* creature)
{
    std::lock_guard<std::recursive_mutex> guard(_affixMutex);

    if (!creature)
        return;

    Map* map = creature->GetMap();
    InstanceAffixState* state = GetInstanceState(map);
    if (!state)
        return;

    for (AffixType affix : state->activeAffixes)
    {
        auto itr = _handlers.find(affix);
        if (itr != _handlers.end() && itr->second)
            itr->second->OnCreatureSelectLevel(creature);
    }
}

void MythicPlusAffixManager::OnPlayerUpdate(Player* player, uint32 diff)
{
    std::lock_guard<std::recursive_mutex> guard(_affixMutex);

    if (!player)
        return;

    Map* map = player->GetMap();
    InstanceAffixState* state = GetInstanceState(map);
    if (!state)
        return;

    for (AffixType affix : state->activeAffixes)
    {
        auto itr = _handlers.find(affix);
        if (itr != _handlers.end() && itr->second)
            itr->second->OnPlayerUpdate(player, diff);
    }
}

std::vector<AffixType> MythicPlusAffixManager::GetActiveAffixes(Map* map) const
{
    std::lock_guard<std::recursive_mutex> guard(_affixMutex);

    if (!map)
        return {};

    uint64 key = MakeInstanceKey(map);
    auto itr = _instanceStates.find(key);
    return (itr != _instanceStates.end()) ? itr->second.activeAffixes : std::vector<AffixType>{};
}

uint8 MythicPlusAffixManager::GetKeystoneLevel(Map* map) const
{
    std::lock_guard<std::recursive_mutex> guard(_affixMutex);

    if (!map)
        return 0;

    uint64 key = MakeInstanceKey(map);
    auto itr = _instanceStates.find(key);
    return (itr != _instanceStates.end()) ? itr->second.keystoneLevel : 0;
}

uint64 MythicPlusAffixManager::MakeInstanceKey(Map const* map) const
{
    if (!map)
        return 0;

    // Same packing order as MythicPlusRunManager::MakeInstanceKey. The two used
    // to be reversed relative to each other, which worked but made the pair
    // trivially confusable in review.
    return (static_cast<uint64>(map->GetId()) << 32) | uint32(map->GetInstanceId());
}

MythicPlusAffixManager::InstanceAffixState* MythicPlusAffixManager::GetInstanceState(Map* map)
{
    if (!map)
        return nullptr;

    uint64 key = MakeInstanceKey(map);
    auto itr = _instanceStates.find(key);
    return (itr != _instanceStates.end()) ? &itr->second : nullptr;
}
