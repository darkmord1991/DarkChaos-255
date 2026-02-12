/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include "Map.h"

#include "GameTime.h"
#include "Log.h"

#include <utility>

namespace
{
    constexpr size_t kPartitionRelayLimit = 1024;
    thread_local std::unordered_map<Map const*, uint32> sActivePartitionContext;

    template <typename QueueMap, typename Relay>
    void EnqueuePartitionRelay(Map& map, uint32 partitionId, QueueMap& relayMap, Relay&& relay, char const* relayType)
    {
        std::lock_guard<std::mutex> lock(map.GetRelayLock(partitionId));
        auto& queue = relayMap[partitionId];
        if (queue.size() >= kPartitionRelayLimit)
        {
            LOG_WARN("maps.partition", "Map {} partition {} {} relay queue full ({}), dropping relay", map.GetId(), partitionId, relayType, kPartitionRelayLimit);
            return;
        }

        queue.push_back(std::forward<Relay>(relay));
    }
}

void Map::QueuePartitionThreatRelay(uint32 partitionId, ObjectGuid const& ownerGuid, ObjectGuid const& victimGuid, float threat, SpellSchoolMask schoolMask, uint32 spellId)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    PartitionThreatRelay relay;
    relay.ownerGuid = ownerGuid;
    relay.victimGuid = victimGuid;
    relay.threat = threat;
    relay.schoolMask = schoolMask;
    relay.spellId = spellId;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    EnqueuePartitionRelay(*this, partitionId, _partitionThreatRelays, relay, "threat");
}

void Map::QueuePartitionThreatClearAll(uint32 partitionId, ObjectGuid const& ownerGuid)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    PartitionThreatActionRelay relay;
    relay.ownerGuid = ownerGuid;
    relay.action = 1;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    EnqueuePartitionRelay(*this, partitionId, _partitionThreatActionRelays, relay, "threat-action");
}

void Map::QueuePartitionThreatResetAll(uint32 partitionId, ObjectGuid const& ownerGuid)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    PartitionThreatActionRelay relay;
    relay.ownerGuid = ownerGuid;
    relay.action = 2;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    EnqueuePartitionRelay(*this, partitionId, _partitionThreatActionRelays, relay, "threat-action");
}

void Map::QueuePartitionThreatTargetClear(uint32 partitionId, ObjectGuid const& ownerGuid, ObjectGuid const& targetGuid)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    PartitionThreatTargetActionRelay relay;
    relay.ownerGuid = ownerGuid;
    relay.targetGuid = targetGuid;
    relay.action = 1;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    EnqueuePartitionRelay(*this, partitionId, _partitionThreatTargetActionRelays, relay, "threat-target");
}

void Map::QueuePartitionThreatTargetReset(uint32 partitionId, ObjectGuid const& ownerGuid, ObjectGuid const& targetGuid)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    PartitionThreatTargetActionRelay relay;
    relay.ownerGuid = ownerGuid;
    relay.targetGuid = targetGuid;
    relay.action = 2;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    EnqueuePartitionRelay(*this, partitionId, _partitionThreatTargetActionRelays, relay, "threat-target");
}

void Map::QueuePartitionCombatRelay(uint32 partitionId, ObjectGuid const& ownerGuid, ObjectGuid const& victimGuid, bool initialAggro)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    PartitionCombatRelay relay;
    relay.ownerGuid = ownerGuid;
    relay.victimGuid = victimGuid;
    relay.initialAggro = initialAggro;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    EnqueuePartitionRelay(*this, partitionId, _partitionCombatRelays, relay, "combat");
}

void Map::QueuePartitionLootRelay(uint32 partitionId, ObjectGuid const& creatureGuid, ObjectGuid const& unitGuid, bool withGroup)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    PartitionLootRelay relay;
    relay.creatureGuid = creatureGuid;
    relay.unitGuid = unitGuid;
    relay.withGroup = withGroup;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    EnqueuePartitionRelay(*this, partitionId, _partitionLootRelays, relay, "loot");
}

void Map::QueuePartitionDynObjectRelay(uint32 partitionId, ObjectGuid const& dynObjGuid, uint8 action)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    PartitionDynObjectRelay relay;
    relay.dynObjGuid = dynObjGuid;
    relay.action = action;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    EnqueuePartitionRelay(*this, partitionId, _partitionDynObjectRelays, relay, "dynobject");
}

void Map::QueuePartitionMinionRelay(uint32 partitionId, ObjectGuid const& ownerGuid, ObjectGuid const& minionGuid, bool apply)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    PartitionMinionRelay relay;
    relay.ownerGuid = ownerGuid;
    relay.minionGuid = minionGuid;
    relay.apply = apply;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    EnqueuePartitionRelay(*this, partitionId, _partitionMinionRelays, relay, "minion");
}

void Map::QueuePartitionCharmRelay(uint32 partitionId, ObjectGuid const& charmerGuid, ObjectGuid const& targetGuid, uint8 charmType, uint32 auraSpellId, bool apply)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    PartitionCharmRelay relay;
    relay.charmerGuid = charmerGuid;
    relay.targetGuid = targetGuid;
    relay.charmType = charmType;
    relay.auraSpellId = auraSpellId;
    relay.apply = apply;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    EnqueuePartitionRelay(*this, partitionId, _partitionCharmRelays, relay, "charm");
}

void Map::QueuePartitionGameObjectRelay(uint32 partitionId, ObjectGuid const& ownerGuid, ObjectGuid const& gameObjGuid, uint32 spellId, bool del, uint8 action)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    PartitionGameObjectRelay relay;
    relay.ownerGuid = ownerGuid;
    relay.gameObjGuid = gameObjGuid;
    relay.spellId = spellId;
    relay.del = del;
    relay.action = action;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    EnqueuePartitionRelay(*this, partitionId, _partitionGameObjectRelays, relay, "gameobject");
}

void Map::QueuePartitionCombatStateRelay(uint32 partitionId, ObjectGuid const& unitGuid, ObjectGuid const& enemyGuid, bool pvp, uint32 duration)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    PartitionCombatStateRelay relay;
    relay.unitGuid = unitGuid;
    relay.enemyGuid = enemyGuid;
    relay.pvp = pvp;
    relay.duration = duration;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    EnqueuePartitionRelay(*this, partitionId, _partitionCombatStateRelays, relay, "combat-state");
}

void Map::QueuePartitionAttackRelay(uint32 partitionId, ObjectGuid const& attackerGuid, ObjectGuid const& victimGuid, bool meleeAttack)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    PartitionAttackRelay relay;
    relay.attackerGuid = attackerGuid;
    relay.victimGuid = victimGuid;
    relay.meleeAttack = meleeAttack;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    EnqueuePartitionRelay(*this, partitionId, _partitionAttackRelays, relay, "attack");
}

void Map::QueuePartitionEvadeRelay(uint32 partitionId, ObjectGuid const& unitGuid, uint8 reason)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    PartitionEvadeRelay relay;
    relay.unitGuid = unitGuid;
    relay.reason = reason;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    EnqueuePartitionRelay(*this, partitionId, _partitionEvadeRelays, relay, "evade");
}

void Map::QueuePartitionTauntApply(uint32 partitionId, ObjectGuid const& ownerGuid, ObjectGuid const& taunterGuid)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    PartitionTauntRelay relay;
    relay.ownerGuid = ownerGuid;
    relay.taunterGuid = taunterGuid;
    relay.action = 1;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    EnqueuePartitionRelay(*this, partitionId, _partitionTauntRelays, relay, "taunt");
}

void Map::QueuePartitionTauntFade(uint32 partitionId, ObjectGuid const& ownerGuid, ObjectGuid const& taunterGuid)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    PartitionTauntRelay relay;
    relay.ownerGuid = ownerGuid;
    relay.taunterGuid = taunterGuid;
    relay.action = 2;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    EnqueuePartitionRelay(*this, partitionId, _partitionTauntRelays, relay, "taunt");
}

void Map::QueuePartitionMotionRelay(uint32 partitionId, PartitionMotionRelay const& relay)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    EnqueuePartitionRelay(*this, partitionId, _partitionMotionRelays, relay, "motion");
}

void Map::QueuePartitionMotionRelay(uint32 partitionId, PartitionMotionRelay&& relay)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    EnqueuePartitionRelay(*this, partitionId, _partitionMotionRelays, std::move(relay), "motion");
}

void Map::QueuePartitionProcRelay(uint32 partitionId, ObjectGuid const& actorGuid, ObjectGuid const& targetGuid, bool isVictim, uint32 procFlag, uint32 procExtra, uint32 amount, WeaponAttackType attackType, uint32 procSpellId, uint32 procAuraId, int8 procAuraEffectIndex, uint32 procPhase)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    if (!procFlag)
        return;

    PartitionProcRelay relay;
    relay.actorGuid = actorGuid;
    relay.targetGuid = targetGuid;
    relay.isVictim = isVictim;
    relay.procFlag = procFlag;
    relay.procExtra = procExtra;
    relay.amount = amount;
    relay.attackType = attackType;
    relay.procSpellId = procSpellId;
    relay.procAuraId = procAuraId;
    relay.procAuraEffectIndex = procAuraEffectIndex;
    relay.procPhase = procPhase;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    EnqueuePartitionRelay(*this, partitionId, _partitionProcRelays, relay, "proc");
}

void Map::QueuePartitionAuraRelay(uint32 partitionId, ObjectGuid const& casterGuid, ObjectGuid const& targetGuid, uint32 spellId, uint8 effMask, bool apply, AuraRemoveMode removeMode)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    PartitionAuraRelay relay;
    relay.casterGuid = casterGuid;
    relay.targetGuid = targetGuid;
    relay.spellId = spellId;
    relay.effMask = effMask;
    relay.apply = apply;
    relay.removeMode = removeMode;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    EnqueuePartitionRelay(*this, partitionId, _partitionAuraRelays, relay, "aura");
}

void Map::QueuePartitionPathRelay(uint32 partitionId, ObjectGuid const& moverGuid, ObjectGuid const& targetGuid)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    PartitionPathRelay relay;
    relay.moverGuid = moverGuid;
    relay.targetGuid = targetGuid;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    EnqueuePartitionRelay(*this, partitionId, _partitionPathRelays, relay, "path");
}

void Map::QueuePartitionPointRelay(uint32 partitionId, ObjectGuid const& moverGuid, uint32 pointId, float x, float y, float z, ForcedMovement forcedMovement, float speed, float orientation, bool generatePath, bool forceDestination, MovementSlot slot, bool hasAnimTier, AnimTier animTier)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    PartitionPointRelay relay;
    relay.moverGuid = moverGuid;
    relay.pointId = pointId;
    relay.x = x;
    relay.y = y;
    relay.z = z;
    relay.forcedMovement = forcedMovement;
    relay.speed = speed;
    relay.orientation = orientation;
    relay.generatePath = generatePath;
    relay.forceDestination = forceDestination;
    relay.slot = slot;
    relay.hasAnimTier = hasAnimTier;
    relay.animTier = animTier;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    EnqueuePartitionRelay(*this, partitionId, _partitionPointRelays, relay, "point");
}

void Map::QueuePartitionAssistRelay(uint32 partitionId, ObjectGuid const& moverGuid, float x, float y, float z)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    PartitionAssistRelay relay;
    relay.moverGuid = moverGuid;
    relay.x = x;
    relay.y = y;
    relay.z = z;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    EnqueuePartitionRelay(*this, partitionId, _partitionAssistRelays, relay, "assist");
}

void Map::QueuePartitionAssistDistractRelay(uint32 partitionId, ObjectGuid const& moverGuid, uint32 timeMs)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    PartitionAssistDistractRelay relay;
    relay.moverGuid = moverGuid;
    relay.timeMs = timeMs;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    EnqueuePartitionRelay(*this, partitionId, _partitionAssistDistractRelays, relay, "assist-distract");
}

uint32 Map::GetActivePartitionContext() const
{
    auto it = sActivePartitionContext.find(this);
    if (it == sActivePartitionContext.end())
        return 0;
    return it->second;
}

std::mutex& Map::GetRelayLock(uint32 partitionId)
{
    return _relayLocks[partitionId % kRelayLockStripes];
}

void Map::SetActivePartitionContext(uint32 partitionId)
{
    if (partitionId == 0)
    {
        sActivePartitionContext.erase(this);
        return;
    }

    sActivePartitionContext[this] = partitionId;
}
