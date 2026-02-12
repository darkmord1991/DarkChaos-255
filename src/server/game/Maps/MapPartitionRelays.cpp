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
#include "Metric.h"
#include "CreatureAI.h"
#include "DynamicObject.h"
#include "MoveSplineInit.h"
#include "MotionMaster.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "SpellMgr.h"
#include "ThreatMgr.h"
#include "Unit.h"

#include <chrono>
#include <unordered_map>

namespace
{
    constexpr size_t kPartitionRelayLimit = 1024;
    constexpr uint8 kMaxRelayBounces = 3;
    constexpr int64 kSlowPartitionRelayCycleMs = 10;
    thread_local bool sProcessingPartitionRelays = false;
}
bool Map::IsProcessingPartitionRelays() const
{
    return sProcessingPartitionRelays;
}

void Map::ProcessPartitionRelays(uint32 partitionId)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    struct RelayGuard
    {
        RelayGuard() { sProcessingPartitionRelays = true; }
        ~RelayGuard() { sProcessingPartitionRelays = false; }
    } guard;

    // Capture timestamp once for all relay latency measurements in this partition tick
    uint64 const relayNowMs = GameTime::GetGameTimeMS().count();
    auto const relayCycleStart = std::chrono::steady_clock::now();
    bool const emitRelayMetrics = (_updateCounter.load(std::memory_order_relaxed) % 10) == 0;
    std::unordered_map<uint64, Unit*> unitLookupCache;
    unitLookupCache.reserve(128);

    auto GetUnitByGuid = [this, &unitLookupCache](ObjectGuid const& guid) -> Unit*
    {
        if (!guid)
            return nullptr;

        uint64 const rawGuid = guid.GetRawValue();
        auto itr = unitLookupCache.find(rawGuid);
        if (itr != unitLookupCache.end())
            return itr->second;

        Unit* unit = this->GetUnitByGuid(guid);
        unitLookupCache.emplace(rawGuid, unit);
        return unit;
    };

    std::vector<PartitionThreatRelay> threatRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto threatIt = _partitionThreatRelays.find(partitionId);
        if (threatIt != _partitionThreatRelays.end())
        {
            threatRelays.swap(threatIt->second);
            threatIt->second.reserve(std::min<size_t>(threatRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!threatRelays.empty())
    {
        uint64 nowMs = relayNowMs;
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionThreatRelay const& relay : threatRelays)
        {
            Unit* owner = GetUnitByGuid(relay.ownerGuid);
            Unit* victim = GetUnitByGuid(relay.victimGuid);
            if (!owner || !victim)
                continue;

            SpellInfo const* threatSpell = relay.spellId ? sSpellMgr->GetSpellInfo(relay.spellId) : nullptr;
            owner->AddThreat(victim, relay.threat, relay.schoolMask, threatSpell);
            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (emitRelayMetrics && !threatRelays.empty())
        {
            uint64 avgLatency = totalLatency / threatRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "threat"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "threat"));
        }
    }

    std::vector<PartitionThreatActionRelay> threatActionRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto threatActionIt = _partitionThreatActionRelays.find(partitionId);
        if (threatActionIt != _partitionThreatActionRelays.end())
        {
            threatActionRelays.swap(threatActionIt->second);
            threatActionIt->second.reserve(std::min<size_t>(threatActionRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!threatActionRelays.empty())
    {
        uint64 nowMs = relayNowMs;
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionThreatActionRelay const& relay : threatActionRelays)
        {
            Unit* owner = GetUnitByGuid(relay.ownerGuid);
            if (!owner)
                continue;

            if (relay.action == 1)
                owner->GetThreatMgr().ClearAllThreat();
            else if (relay.action == 2)
                owner->GetThreatMgr().ResetAllThreat();

            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (emitRelayMetrics && !threatActionRelays.empty())
        {
            uint64 avgLatency = totalLatency / threatActionRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "threat_action"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "threat_action"));
        }
    }

    std::vector<PartitionProcRelay> procRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto procIt = _partitionProcRelays.find(partitionId);
        if (procIt != _partitionProcRelays.end())
        {
            procRelays.swap(procIt->second);
            procIt->second.reserve(std::min<size_t>(procRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!procRelays.empty())
    {
        uint64 nowMs = relayNowMs;
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionProcRelay const& relay : procRelays)
        {
            Unit* actor = GetUnitByGuid(relay.actorGuid);
            Unit* target = GetUnitByGuid(relay.targetGuid);
            if (!actor || !target)
                continue;

            SpellInfo const* procSpellInfo = relay.procSpellId ? sSpellMgr->GetSpellInfo(relay.procSpellId) : nullptr;
            SpellInfo const* procAuraInfo = relay.procAuraId ? sSpellMgr->GetSpellInfo(relay.procAuraId) : nullptr;
            if (relay.isVictim)
                actor->ProcDamageAndSpellFor(true, target, relay.procFlag, relay.procExtra, relay.attackType, procSpellInfo, relay.amount, procAuraInfo, relay.procAuraEffectIndex, nullptr, nullptr, nullptr, relay.procPhase);
            else
                actor->ProcDamageAndSpellFor(false, target, relay.procFlag, relay.procExtra, relay.attackType, procSpellInfo, relay.amount, procAuraInfo, relay.procAuraEffectIndex, nullptr, nullptr, nullptr, relay.procPhase);
            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (emitRelayMetrics && !procRelays.empty())
        {
            uint64 avgLatency = totalLatency / procRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "proc"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "proc"));
        }
    }

    std::vector<PartitionAuraRelay> auraRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto auraIt = _partitionAuraRelays.find(partitionId);
        if (auraIt != _partitionAuraRelays.end())
        {
            auraRelays.swap(auraIt->second);
            auraIt->second.reserve(std::min<size_t>(auraRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!auraRelays.empty())
    {
        uint64 nowMs = relayNowMs;
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionAuraRelay const& relay : auraRelays)
        {
            Unit* caster = GetUnitByGuid(relay.casterGuid);
            Unit* target = GetUnitByGuid(relay.targetGuid);
            if (!target)
                continue;

            if (relay.apply)
            {
                if (!caster)
                    continue;

                if (target->HasAura(relay.spellId, relay.casterGuid))
                    continue;

                SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(relay.spellId);
                if (!spellInfo)
                    continue;

                caster->AddAura(spellInfo, relay.effMask, target);
            }
            else
            {
                target->RemoveAura(relay.spellId, relay.casterGuid, relay.effMask, relay.removeMode);
            }
            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (emitRelayMetrics && !auraRelays.empty())
        {
            uint64 avgLatency = totalLatency / auraRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "aura"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "aura"));
        }
    }

    std::vector<PartitionPathRelay> pathRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto pathIt = _partitionPathRelays.find(partitionId);
        if (pathIt != _partitionPathRelays.end())
        {
            pathRelays.swap(pathIt->second);
            pathIt->second.reserve(std::min<size_t>(pathRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!pathRelays.empty())
    {
        uint64 nowMs = relayNowMs;
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionPathRelay const& relay : pathRelays)
        {
            Unit* mover = GetUnitByGuid(relay.moverGuid);
            Unit* target = GetUnitByGuid(relay.targetGuid);
            if (!mover || !target || !mover->IsInWorld() || !mover->GetMotionMaster())
                continue;

            uint32 moverPartition = GetPartitionIdForUnit(mover);
            if (moverPartition && moverPartition != partitionId)
            {
                QueuePartitionPathRelay(moverPartition, relay.moverGuid, relay.targetGuid);
                continue;
            }

            mover->GetMotionMaster()->MoveChase(target);
            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (emitRelayMetrics && !pathRelays.empty())
        {
            uint64 avgLatency = totalLatency / pathRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "path"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "path"));
        }
    }

    std::vector<PartitionPointRelay> pointRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto pointIt = _partitionPointRelays.find(partitionId);
        if (pointIt != _partitionPointRelays.end())
        {
            pointRelays.swap(pointIt->second);
            pointIt->second.reserve(std::min<size_t>(pointRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!pointRelays.empty())
    {
        uint64 nowMs = relayNowMs;
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionPointRelay const& relay : pointRelays)
        {
            Unit* mover = GetUnitByGuid(relay.moverGuid);
            if (!mover || !mover->IsInWorld() || !mover->GetMotionMaster())
                continue;

            uint32 moverPartition = GetPartitionIdForUnit(mover);
            if (moverPartition && moverPartition != partitionId)
            {
                QueuePartitionPointRelay(moverPartition, relay.moverGuid, relay.pointId, relay.x, relay.y, relay.z,
                    relay.forcedMovement, relay.speed, relay.orientation, relay.generatePath, relay.forceDestination,
                    relay.slot, relay.hasAnimTier, relay.animTier);
                continue;
            }

            std::optional<AnimTier> animTier;
            if (relay.hasAnimTier)
                animTier = relay.animTier;

            mover->GetMotionMaster()->MovePoint(relay.pointId, relay.x, relay.y, relay.z, relay.forcedMovement, relay.speed, relay.orientation, relay.generatePath, relay.forceDestination, relay.slot, animTier);
            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (emitRelayMetrics && !pointRelays.empty())
        {
            uint64 avgLatency = totalLatency / pointRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "point"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "point"));
        }
    }

    std::vector<PartitionMotionRelay> motionRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto motionIt = _partitionMotionRelays.find(partitionId);
        if (motionIt != _partitionMotionRelays.end())
        {
            motionRelays.swap(motionIt->second);
            motionIt->second.reserve(std::min<size_t>(motionRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!motionRelays.empty())
    {
        uint64 nowMs = relayNowMs;
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionMotionRelay const& relay : motionRelays)
        {
            Unit* mover = GetUnitByGuid(relay.moverGuid);
            if (!mover || !mover->IsInWorld() || !mover->GetMotionMaster())
                continue;

            uint32 moverPartition = GetPartitionIdForUnit(mover);
            if (moverPartition && moverPartition != partitionId)
            {
                QueuePartitionMotionRelay(moverPartition, relay);
                continue;
            }

            switch (relay.action)
            {
                case MOTION_RELAY_JUMP:
                {
                    Unit* target = relay.targetGuid ? GetUnitByGuid(relay.targetGuid) : nullptr;
                    mover->GetMotionMaster()->MoveJump(relay.x, relay.y, relay.z, relay.speedXY, relay.speedZ, relay.id, target);
                    break;
                }
                case MOTION_RELAY_FALL:
                {
                    mover->GetMotionMaster()->MoveFall(relay.id, relay.addFlagForNPC);
                    break;
                }
                case MOTION_RELAY_CHARGE:
                {
                    Movement::PointsArray pathPoints;
                    if (!relay.pathPoints.empty())
                    {
                        pathPoints.assign(relay.pathPoints.begin(), relay.pathPoints.end());
                        mover->GetMotionMaster()->MoveCharge(relay.x, relay.y, relay.z, relay.speed, relay.id, &pathPoints, relay.generatePath, relay.orientation, relay.targetGuid);
                    }
                    else
                    {
                        mover->GetMotionMaster()->MoveCharge(relay.x, relay.y, relay.z, relay.speed, relay.id, nullptr, relay.generatePath, relay.orientation, relay.targetGuid);
                    }
                    break;
                }
                case MOTION_RELAY_CHARGE_PATH:
                {
                    Movement::PointsArray pathPoints;
                    pathPoints.assign(relay.pathPoints.begin(), relay.pathPoints.end());
                    if (pathPoints.empty())
                        break;
                    mover->GetMotionMaster()->MoveCharge(relay.x, relay.y, relay.z, relay.speed, relay.id, nullptr, false, relay.orientation, relay.targetGuid);

                    Movement::MoveSplineInit init(mover);
                    init.MovebyPath(pathPoints);
                    init.SetVelocity(relay.speed);
                    init.Launch();
                    break;
                }
                case MOTION_RELAY_FLEE:
                {
                    Unit* enemy = relay.targetGuid ? GetUnitByGuid(relay.targetGuid) : nullptr;
                    if (enemy)
                        mover->GetMotionMaster()->MoveFleeing(enemy, relay.timeMs);
                    break;
                }
                case MOTION_RELAY_DISTRACT:
                {
                    mover->GetMotionMaster()->MoveDistract(relay.timeMs);
                    break;
                }
                case MOTION_RELAY_BACKWARDS:
                {
                    Unit* target = relay.targetGuid ? GetUnitByGuid(relay.targetGuid) : nullptr;
                    if (target)
                        mover->GetMotionMaster()->MoveBackwards(target, relay.dist);
                    break;
                }
                case MOTION_RELAY_FORWARDS:
                {
                    Unit* target = relay.targetGuid ? GetUnitByGuid(relay.targetGuid) : nullptr;
                    if (target)
                        mover->GetMotionMaster()->MoveForwards(target, relay.dist);
                    break;
                }
                case MOTION_RELAY_CIRCLE:
                {
                    Unit* target = relay.targetGuid ? GetUnitByGuid(relay.targetGuid) : nullptr;
                    if (target)
                        mover->GetMotionMaster()->MoveCircleTarget(target);
                    break;
                }
                case MOTION_RELAY_SPLINE_PATH:
                {
                    Movement::PointsArray pathPoints;
                    pathPoints.assign(relay.pathPoints.begin(), relay.pathPoints.end());
                    if (pathPoints.empty())
                        break;
                    mover->GetMotionMaster()->MoveSplinePath(&pathPoints, relay.forcedMovement);
                    break;
                }
                case MOTION_RELAY_PATH:
                {
                    mover->GetMotionMaster()->MovePath(relay.pathId, relay.forcedMovement, static_cast<PathSource>(relay.pathSource));
                    break;
                }
                case MOTION_RELAY_LAND:
                {
                    mover->GetMotionMaster()->MoveLand(relay.id, relay.x, relay.y, relay.z, relay.speed);
                    break;
                }
                case MOTION_RELAY_TAKEOFF:
                {
                    mover->GetMotionMaster()->MoveTakeoff(relay.id, relay.x, relay.y, relay.z, relay.speed, relay.skipAnimation);
                    break;
                }
                case MOTION_RELAY_KNOCKBACK:
                {
                    mover->GetMotionMaster()->MoveKnockbackFrom(relay.x, relay.y, relay.speedXY, relay.speedZ);
                    break;
                }
                case MOTION_RELAY_STOP:
                {
                    mover->StopMoving();
                    break;
                }
                case MOTION_RELAY_STOP_ON_POS:
                {
                    mover->StopMovingOnCurrentPos();
                    break;
                }
                case MOTION_RELAY_FACE_ORIENTATION:
                {
                    mover->SetFacingTo(relay.orientation);
                    break;
                }
                case MOTION_RELAY_FACE_OBJECT:
                {
                    WorldObject* target = relay.targetGuid ? ObjectAccessor::GetWorldObject(*mover, relay.targetGuid) : nullptr;
                    if (target)
                        mover->SetFacingToObject(target, Milliseconds(relay.timeMs));
                    break;
                }
                case MOTION_RELAY_MONSTER_MOVE:
                {
                    mover->MonsterMoveWithSpeed(relay.x, relay.y, relay.z, relay.speed);
                    break;
                }
                case MOTION_RELAY_TRANSPORT_ENTER:
                {
                    Movement::MoveSplineInit init(mover);
                    init.DisableTransportPathTransformations();
                    init.MoveTo(relay.x, relay.y, relay.z, false, true);
                    init.SetFacing(relay.orientation);
                    init.SetTransportEnter();
                    init.Launch();
                    break;
                }
                case MOTION_RELAY_TRANSPORT_EXIT:
                {
                    Movement::MoveSplineInit init(mover);
                    init.MoveTo(relay.x, relay.y, relay.z);
                    init.SetFacing(relay.orientation);
                    init.SetTransportExit();
                    init.Launch();
                    if (relay.disableSpline)
                        mover->DisableSpline();
                    if (relay.speedXY > 0.0f)
                        mover->KnockbackFrom(relay.srcX, relay.srcY, relay.speedXY, relay.speedZ);
                    if (relay.spellId)
                        mover->CastSpell(mover, relay.spellId, true);
                    break;
                }
                case MOTION_RELAY_PASSENGER_RELOCATE:
                {
                    mover->UpdatePosition(relay.x, relay.y, relay.z, relay.orientation);
                    break;
                }
                case MOTION_RELAY_VEHICLE_TELEPORT_PLAYER:
                {
                    if (Player* player = mover->ToPlayer())
                    {
                        player->SetMover(player);
                        player->NearTeleportTo(relay.x, relay.y, relay.z, relay.orientation, false, true);
                        player->ScheduleDelayedOperation(DELAYED_VEHICLE_TELEPORT);
                    }
                    break;
                }
                default:
                    break;
            }

            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (emitRelayMetrics && !motionRelays.empty())
        {
            uint64 avgLatency = totalLatency / motionRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "motion"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "motion"));
        }
    }

    std::vector<PartitionAssistRelay> assistRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto assistIt = _partitionAssistRelays.find(partitionId);
        if (assistIt != _partitionAssistRelays.end())
        {
            assistRelays.swap(assistIt->second);
            assistIt->second.reserve(std::min<size_t>(assistRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!assistRelays.empty())
    {
        uint64 nowMs = relayNowMs;
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionAssistRelay const& relay : assistRelays)
        {
            Unit* mover = GetUnitByGuid(relay.moverGuid);
            if (!mover || !mover->IsInWorld() || !mover->GetMotionMaster())
                continue;

            uint32 moverPartition = GetPartitionIdForUnit(mover);
            if (moverPartition && moverPartition != partitionId)
            {
                QueuePartitionAssistRelay(moverPartition, relay.moverGuid, relay.x, relay.y, relay.z);
                continue;
            }

            mover->GetMotionMaster()->MoveSeekAssistance(relay.x, relay.y, relay.z);
            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (emitRelayMetrics && !assistRelays.empty())
        {
            uint64 avgLatency = totalLatency / assistRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "assist"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "assist"));
        }
    }

    std::vector<PartitionAssistDistractRelay> distractRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto distractIt = _partitionAssistDistractRelays.find(partitionId);
        if (distractIt != _partitionAssistDistractRelays.end())
        {
            distractRelays.swap(distractIt->second);
            distractIt->second.reserve(std::min<size_t>(distractRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!distractRelays.empty())
    {
        uint64 nowMs = relayNowMs;
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionAssistDistractRelay const& relay : distractRelays)
        {
            Unit* mover = GetUnitByGuid(relay.moverGuid);
            if (!mover || !mover->IsInWorld() || !mover->GetMotionMaster())
                continue;

            uint32 moverPartition = GetPartitionIdForUnit(mover);
            if (moverPartition && moverPartition != partitionId)
            {
                QueuePartitionAssistDistractRelay(moverPartition, relay.moverGuid, relay.timeMs);
                continue;
            }

            mover->GetMotionMaster()->MoveSeekAssistanceDistract(relay.timeMs);
            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (emitRelayMetrics && !distractRelays.empty())
        {
            uint64 avgLatency = totalLatency / distractRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "assist_distract"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "assist_distract"));
        }
    }

    // BUG-1 FIX: Process threat-target-action relays (were previously queued but never consumed)
    std::vector<PartitionThreatTargetActionRelay> threatTargetRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto threatTargetIt = _partitionThreatTargetActionRelays.find(partitionId);
        if (threatTargetIt != _partitionThreatTargetActionRelays.end())
        {
            threatTargetRelays.swap(threatTargetIt->second);
            threatTargetIt->second.reserve(std::min<size_t>(threatTargetRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!threatTargetRelays.empty())
    {
        uint64 nowMs = relayNowMs;
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionThreatTargetActionRelay const& relay : threatTargetRelays)
        {
            Unit* owner = GetUnitByGuid(relay.ownerGuid);
            Unit* target = GetUnitByGuid(relay.targetGuid);
            if (!owner || !target)
                continue;

            if (relay.action == 1) // ClearTarget
                owner->GetThreatMgr().ModifyThreatByPercent(target, -100);
            else if (relay.action == 2) // ResetTarget - set threat to 0 without removing from list
                owner->GetThreatMgr().ResetThreat(target);

            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (emitRelayMetrics && !threatTargetRelays.empty())
        {
            uint64 avgLatency = totalLatency / threatTargetRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "threat_target_action"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "threat_target_action"));
        }
    }

    std::vector<PartitionCombatRelay> combatRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto combatIt = _partitionCombatRelays.find(partitionId);
        if (combatIt != _partitionCombatRelays.end())
        {
            combatRelays.swap(combatIt->second);
            combatIt->second.reserve(std::min<size_t>(combatRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!combatRelays.empty())
    {
        uint64 nowMs = relayNowMs;
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionCombatRelay const& relay : combatRelays)
        {
            Unit* owner = GetUnitByGuid(relay.ownerGuid);
            Unit* victim = GetUnitByGuid(relay.victimGuid);
            if (!owner || !victim)
                continue;

            owner->CombatStart(victim, relay.initialAggro);

            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (emitRelayMetrics && !combatRelays.empty())
        {
            uint64 avgLatency = totalLatency / combatRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "combat"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "combat"));
        }
    }

    std::vector<PartitionLootRelay> lootRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto lootIt = _partitionLootRelays.find(partitionId);
        if (lootIt != _partitionLootRelays.end())
        {
            lootRelays.swap(lootIt->second);
            lootIt->second.reserve(std::min<size_t>(lootRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!lootRelays.empty())
    {
        uint64 nowMs = relayNowMs;
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionLootRelay const& relay : lootRelays)
        {
            Creature* creature = GetCreature(relay.creatureGuid);
            if (!creature)
                continue;

            Unit* unit = relay.unitGuid ? GetUnitByGuid(relay.unitGuid) : nullptr;
            creature->SetLootRecipient(unit, relay.withGroup);

            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (emitRelayMetrics && !lootRelays.empty())
        {
            uint64 avgLatency = totalLatency / lootRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "loot"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "loot"));
        }
    }

    std::vector<PartitionDynObjectRelay> dynObjectRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto dynObjIt = _partitionDynObjectRelays.find(partitionId);
        if (dynObjIt != _partitionDynObjectRelays.end())
        {
            dynObjectRelays.swap(dynObjIt->second);
            dynObjIt->second.reserve(std::min<size_t>(dynObjectRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!dynObjectRelays.empty())
    {
        uint64 nowMs = relayNowMs;
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionDynObjectRelay const& relay : dynObjectRelays)
        {
            DynamicObject* dynObj = GetDynamicObject(relay.dynObjGuid);
            if (!dynObj)
                continue;

            if (relay.action == 1)
                dynObj->Remove();

            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (emitRelayMetrics && !dynObjectRelays.empty())
        {
            uint64 avgLatency = totalLatency / dynObjectRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "dynobject"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "dynobject"));
        }
    }

    std::vector<PartitionMinionRelay> minionRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto minionIt = _partitionMinionRelays.find(partitionId);
        if (minionIt != _partitionMinionRelays.end())
        {
            minionRelays.swap(minionIt->second);
            minionIt->second.reserve(std::min<size_t>(minionRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!minionRelays.empty())
    {
        uint64 nowMs = relayNowMs;
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionMinionRelay const& relay : minionRelays)
        {
            Unit* owner = GetUnitByGuid(relay.ownerGuid);
            Unit* minionUnit = GetUnitByGuid(relay.minionGuid);
            Creature* minionCreature = minionUnit ? minionUnit->ToCreature() : nullptr;
            Minion* minion = (minionCreature && minionCreature->HasUnitTypeMask(UNIT_MASK_MINION)) ? static_cast<Minion*>(minionCreature) : nullptr;
            ASSERT(!minion || dynamic_cast<Minion*>(minionCreature) != nullptr, "UNIT_MASK_MINION set but type is not Minion");
            if (!owner || !minion || !owner->IsInWorld())
                continue;

            uint32 ownerPartition = GetPartitionIdForUnit(owner);
            if (ownerPartition && ownerPartition != partitionId && relay.bounceCount < kMaxRelayBounces)
            {
                PartitionMinionRelay bounced = relay;
                bounced.bounceCount++;
                std::lock_guard<std::mutex> lock(GetRelayLock(ownerPartition));
                _partitionMinionRelays[ownerPartition].push_back(bounced);
                continue;
            }

            owner->SetMinion(minion, relay.apply);

            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (emitRelayMetrics && !minionRelays.empty())
        {
            uint64 avgLatency = totalLatency / minionRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "minion"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "minion"));
        }
    }

    std::vector<PartitionCharmRelay> charmRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto charmIt = _partitionCharmRelays.find(partitionId);
        if (charmIt != _partitionCharmRelays.end())
        {
            charmRelays.swap(charmIt->second);
            charmIt->second.reserve(std::min<size_t>(charmRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!charmRelays.empty())
    {
        uint64 nowMs = relayNowMs;
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionCharmRelay const& relay : charmRelays)
        {
            Unit* charmer = GetUnitByGuid(relay.charmerGuid);
            Unit* target = GetUnitByGuid(relay.targetGuid);
            if (!charmer || !target || !charmer->IsInWorld() || !target->IsInWorld())
                continue;

            uint32 targetPartition = GetPartitionIdForUnit(target);
            if (targetPartition && targetPartition != partitionId && relay.bounceCount < kMaxRelayBounces)
            {
                PartitionCharmRelay bounced = relay;
                bounced.bounceCount++;
                std::lock_guard<std::mutex> lock(GetRelayLock(targetPartition));
                _partitionCharmRelays[targetPartition].push_back(bounced);
                continue;
            }

            if (relay.apply)
            {
                if (relay.auraSpellId && !target->HasAura(relay.auraSpellId, relay.charmerGuid))
                    continue;
                target->SetCharmedBy(charmer, static_cast<CharmType>(relay.charmType), nullptr);
            }
            else
            {
                target->RemoveCharmedBy(charmer);
            }

            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (emitRelayMetrics && !charmRelays.empty())
        {
            uint64 avgLatency = totalLatency / charmRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "charm"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "charm"));
        }
    }

    std::vector<PartitionGameObjectRelay> gameObjectRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto goIt = _partitionGameObjectRelays.find(partitionId);
        if (goIt != _partitionGameObjectRelays.end())
        {
            gameObjectRelays.swap(goIt->second);
            goIt->second.reserve(std::min<size_t>(gameObjectRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!gameObjectRelays.empty())
    {
        uint64 nowMs = relayNowMs;
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionGameObjectRelay const& relay : gameObjectRelays)
        {
            Unit* owner = GetUnitByGuid(relay.ownerGuid);
            if (!owner || !owner->IsInWorld())
                continue;

            uint32 ownerPartition = GetPartitionIdForUnit(owner);
            if (ownerPartition && ownerPartition != partitionId && relay.bounceCount < kMaxRelayBounces)
            {
                PartitionGameObjectRelay bounced = relay;
                bounced.bounceCount++;
                std::lock_guard<std::mutex> lock(GetRelayLock(ownerPartition));
                _partitionGameObjectRelays[ownerPartition].push_back(bounced);
                continue;
            }

            if (relay.action == 1)
            {
                if (relay.gameObjGuid)
                {
                    if (GameObject* go = GetGameObject(relay.gameObjGuid))
                        owner->RemoveGameObject(go, relay.del);
                }
            }
            else if (relay.action == 2)
            {
                owner->RemoveGameObject(relay.spellId, relay.del);
            }
            else if (relay.action == 3)
            {
                owner->RemoveAllGameObjects();
            }

            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (emitRelayMetrics && !gameObjectRelays.empty())
        {
            uint64 avgLatency = totalLatency / gameObjectRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "gameobject"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "gameobject"));
        }
    }

    std::vector<PartitionCombatStateRelay> combatStateRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto combatStateIt = _partitionCombatStateRelays.find(partitionId);
        if (combatStateIt != _partitionCombatStateRelays.end())
        {
            combatStateRelays.swap(combatStateIt->second);
            combatStateIt->second.reserve(std::min<size_t>(combatStateRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!combatStateRelays.empty())
    {
        uint64 nowMs = relayNowMs;
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionCombatStateRelay const& relay : combatStateRelays)
        {
            Unit* unit = GetUnitByGuid(relay.unitGuid);
            if (!unit || !unit->IsInWorld())
                continue;

            uint32 unitPartition = GetPartitionIdForUnit(unit);
            if (unitPartition && unitPartition != partitionId && relay.bounceCount < kMaxRelayBounces)
            {
                PartitionCombatStateRelay bounced = relay;
                bounced.bounceCount++;
                auto& queue = _partitionCombatStateRelays[unitPartition];
                std::lock_guard<std::mutex> lock(GetRelayLock(unitPartition));
                queue.push_back(bounced);
                continue;
            }

            Unit* enemy = relay.enemyGuid ? GetUnitByGuid(relay.enemyGuid) : nullptr;
            unit->SetInCombatState(relay.pvp, enemy, relay.duration);

            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (emitRelayMetrics && !combatStateRelays.empty())
        {
            uint64 avgLatency = totalLatency / combatStateRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "combat_state"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "combat_state"));
        }
    }

    std::vector<PartitionAttackRelay> attackRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto attackIt = _partitionAttackRelays.find(partitionId);
        if (attackIt != _partitionAttackRelays.end())
        {
            attackRelays.swap(attackIt->second);
            attackIt->second.reserve(std::min<size_t>(attackRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!attackRelays.empty())
    {
        uint64 nowMs = relayNowMs;
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionAttackRelay const& relay : attackRelays)
        {
            Unit* attacker = GetUnitByGuid(relay.attackerGuid);
            Unit* victim = GetUnitByGuid(relay.victimGuid);
            if (!attacker || !victim || !attacker->IsInWorld() || !victim->IsInWorld())
                continue;

            uint32 attackerPartition = GetPartitionIdForUnit(attacker);
            if (attackerPartition && attackerPartition != partitionId && relay.bounceCount < kMaxRelayBounces)
            {
                PartitionAttackRelay bounced = relay;
                bounced.bounceCount++;
                std::lock_guard<std::mutex> lock(GetRelayLock(attackerPartition));
                _partitionAttackRelays[attackerPartition].push_back(bounced);
                continue;
            }

            attacker->Attack(victim, relay.meleeAttack);

            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (emitRelayMetrics && !attackRelays.empty())
        {
            uint64 avgLatency = totalLatency / attackRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "attack"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "attack"));
        }
    }

    std::vector<PartitionEvadeRelay> evadeRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto evadeIt = _partitionEvadeRelays.find(partitionId);
        if (evadeIt != _partitionEvadeRelays.end())
        {
            evadeRelays.swap(evadeIt->second);
            evadeIt->second.reserve(std::min<size_t>(evadeRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!evadeRelays.empty())
    {
        uint64 nowMs = relayNowMs;
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionEvadeRelay const& relay : evadeRelays)
        {
            Unit* unit = GetUnitByGuid(relay.unitGuid);
            Creature* creature = unit ? unit->ToCreature() : nullptr;
            if (!creature || !creature->IsAIEnabled || !creature->IsInWorld())
                continue;

            uint32 creaturePartition = GetPartitionIdForUnit(creature);
            if (creaturePartition && creaturePartition != partitionId && relay.bounceCount < kMaxRelayBounces)
            {
                PartitionEvadeRelay bounced = relay;
                bounced.bounceCount++;
                std::lock_guard<std::mutex> lock(GetRelayLock(creaturePartition));
                _partitionEvadeRelays[creaturePartition].push_back(bounced);
                continue;
            }

            creature->AI()->EnterEvadeMode(static_cast<CreatureAI::EvadeReason>(relay.reason));

            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (emitRelayMetrics && !evadeRelays.empty())
        {
            uint64 avgLatency = totalLatency / evadeRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "evade"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "evade"));
        }
    }

    // BUG-2 FIX: Process taunt relays (were previously in dead code in UpdateNonPlayerObjects)
    std::vector<PartitionTauntRelay> tauntRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto tauntIt = _partitionTauntRelays.find(partitionId);
        if (tauntIt != _partitionTauntRelays.end())
        {
            tauntRelays.swap(tauntIt->second);
            tauntIt->second.reserve(std::min<size_t>(tauntRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!tauntRelays.empty())
    {
        uint64 nowMs = relayNowMs;
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionTauntRelay const& relay : tauntRelays)
        {
            Unit* owner = GetUnitByGuid(relay.ownerGuid);
            Unit* taunter = GetUnitByGuid(relay.taunterGuid);
            if (!owner || !taunter)
                continue;

            if (relay.action == 1)
                owner->GetThreatMgr().tauntApply(taunter);
            else if (relay.action == 2)
                owner->GetThreatMgr().tauntFadeOut(taunter);

            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (emitRelayMetrics && !tauntRelays.empty())
        {
            uint64 avgLatency = totalLatency / tauntRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "taunt"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "taunt"));
        }
    }

    int64 const relayCycleMs = std::chrono::duration_cast<Milliseconds>(std::chrono::steady_clock::now() - relayCycleStart).count();
    if (relayCycleMs >= kSlowPartitionRelayCycleMs)
    {
        LOG_WARN("map.partition.slow",
            "Slow partition relay cycle: map={} partition={} cycle_ms={} lookup_cache_size={} emit_metrics={}",
            GetId(), partitionId, relayCycleMs, unitLookupCache.size(), emitRelayMetrics ? 1 : 0);
    }
}


