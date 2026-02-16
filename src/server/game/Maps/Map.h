/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef ACORE_MAP_H
#define ACORE_MAP_H

#include "Cell.h"
#include "DBCStructure.h"
#include "DataMap.h"
#include "Define.h"
#include "DynamicTree.h"
#include "EventProcessor.h"
#include "G3D/Vector3.h"
#include "GameObjectModel.h"
#include "GridDefines.h"
#include "GridRefMgr.h"
#include "MapGridManager.h"
#include "MapRefMgr.h"
#include "ObjectDefines.h"
#include "ObjectGuid.h"
#include "PathGenerator.h"
#include "Position.h"
#include "SharedDefines.h"
#include "Timer.h"
#include "GridTerrainData.h"
#include <atomic>
#include <array>
#include <deque>
#include <list>
#include <memory>
#include <mutex>
#include <shared_mutex>
#include <vector>

class Unit;
class WorldPacket;
class InstanceScript;
class Group;
class InstanceSave;
class Object;
class Weather;
class WorldObject;
class TempSummon;
class Player;
class CreatureGroup;
struct ScriptInfo;
struct ScriptAction;
struct Position;
class Battleground;
class MapInstanced;
class InstanceMap;
class BattlegroundMap;
class Transport;
class StaticTransport;
class MotionTransport;
class PathGenerator;
class WorldSession;
struct CellObjectGuids;
enum AuraRemoveMode : uint8;
enum WeaponAttackType : uint8;
enum MovementSlot : uint8;
enum ForcedMovement : uint8;
enum class PathSource;
enum class AnimTier : uint8;

enum WeatherState : uint32;

namespace VMAP
{
    enum class ModelIgnoreFlags : uint32;
}

namespace Acore
{
    struct ObjectUpdater;
    struct LargeObjectUpdater;
}

struct ScriptAction
{
    ObjectGuid sourceGUID;
    ObjectGuid targetGUID;
    ObjectGuid ownerGUID;                                   // owner of source if source is item
    ScriptInfo const* script;                               // pointer to static script data
};

#define DEFAULT_HEIGHT_SEARCH     50.0f                     // default search distance to find height at nearby locations
#define MIN_UNLOAD_DELAY      1                             // immediate unload
#define UPDATABLE_OBJECT_LIST_RECHECK_TIMER 30 * IN_MILLISECONDS // Time to recheck update object list

struct PositionFullTerrainStatus
{
    PositionFullTerrainStatus()  = default;
    uint32 areaId{0};
    float floorZ{INVALID_HEIGHT};
    bool outdoors{false};
    LiquidData liquidInfo;
};

enum LineOfSightChecks
{
    LINEOFSIGHT_CHECK_VMAP          = 0x1, // check static floor layout data
    LINEOFSIGHT_CHECK_GOBJECT_WMO   = 0x2, // check dynamic game object data (wmo models)
    LINEOFSIGHT_CHECK_GOBJECT_M2    = 0x4, // check dynamic game object data (m2 models)

    LINEOFSIGHT_CHECK_GOBJECT_ALL   = LINEOFSIGHT_CHECK_GOBJECT_WMO | LINEOFSIGHT_CHECK_GOBJECT_M2,

    LINEOFSIGHT_ALL_CHECKS          = LINEOFSIGHT_CHECK_VMAP | LINEOFSIGHT_CHECK_GOBJECT_ALL
};

// GCC have alternative #pragma pack(N) syntax and old gcc version not support pack(push, N), also any gcc version not support it at some platform
#if defined(__GNUC__)
#pragma pack(1)
#else
#pragma pack(push, 1)
#endif

struct InstanceTemplate
{
    uint32 Parent;
    uint32 ScriptId;
    bool AllowMount;
};

enum LevelRequirementVsMode
{
    LEVELREQUIREMENT_HEROIC = 70
};

struct ZoneDynamicInfo
{
    ZoneDynamicInfo();

    uint32 MusicId;
    std::unique_ptr<Weather> DefaultWeather;
    WeatherState WeatherId;
    float WeatherGrade;
    uint32 OverrideLightId;
    uint32 LightFadeInTime;
};

#if defined(__GNUC__)
#pragma pack()
#else
#pragma pack(pop)
#endif

typedef std::map<uint32/*leaderDBGUID*/, CreatureGroup*>        CreatureGroupHolderType;
typedef std::unordered_map<uint32 /*zoneId*/, ZoneDynamicInfo> ZoneDynamicInfoMap;
typedef std::unordered_set<Transport*> TransportsContainer;
typedef std::unordered_set<WorldObject*> ZoneWideVisibleWorldObjectsSet;
typedef std::unordered_map<uint32 /*ZoneId*/, ZoneWideVisibleWorldObjectsSet> ZoneWideVisibleWorldObjectsMap;

enum EncounterCreditType : uint8
{
    ENCOUNTER_CREDIT_KILL_CREATURE  = 0,
    ENCOUNTER_CREDIT_CAST_SPELL     = 1,
};

class Map : public GridRefMgr<MapGridType>
{
    friend class MapReference;
    friend class GridObjectLoader;
public:
    struct PartitionMotionRelay;
    Map(uint32 id, uint32 InstanceId, uint8 SpawnMode, Map* _parent = nullptr);
    ~Map() override;

    [[nodiscard]] MapEntry const* GetEntry() const { return i_mapEntry; }

    // currently unused for normal maps
    bool CanUnload(uint32 diff)
    {
        if (!m_unloadTimer || Events.HasEvents())
            return false;

        if (m_unloadTimer <= diff)
            return true;

        m_unloadTimer -= diff;
        return false;
    }

    virtual bool AddPlayerToMap(Player*);
    virtual void RemovePlayerFromMap(Player*, bool);
    virtual void AfterPlayerUnlinkFromMap();
    template<class T> bool AddToMap(T*, bool checkTransport = false);
    template<class T> void RemoveFromMap(T*, bool);

    void MarkNearbyCellsOf(WorldObject* obj);

    virtual void Update(const uint32, const uint32, bool thread = true);

    [[nodiscard]] float GetVisibilityRange() const { return m_VisibleDistance; }
    void SetVisibilityRange(float range) { m_VisibleDistance = range; }
    bool IsPartitioned() const { return _isPartitioned; }
    void SetPartitioned(bool value) { _isPartitioned = value; }
    bool UseParallelPartitions() const { return _useParallelPartitions; }
    void SetUseParallelPartitions(bool value) { _useParallelPartitions = value; }
    bool SchedulePartitionUpdates(uint32 t_diff, uint32 s_diff);
    void OnCreateMap();
    //function for setting up visibility distance for maps on per-type/per-Id basis
    virtual void InitVisibilityDistance();

    void PlayerRelocation(Player*, float x, float y, float z, float o);
    void CreatureRelocation(Creature* creature, float x, float y, float z, float o);
    void GameObjectRelocation(GameObject* go, float x, float y, float z, float o);
    void DynamicObjectRelocation(DynamicObject* go, float x, float y, float z, float o);

    uint32 GetPartitionIdForUnit(Unit const* unit) const;
    bool TryGetRelayTargetPartition(Unit const* unit, uint32& relayPartitionId) const;
    uint32 GetActivePartitionContext() const;
    void SetActivePartitionContext(uint32 partitionId);
    bool IsProcessingPartitionRelays() const;
    void QueuePartitionThreatRelay(uint32 partitionId, ObjectGuid const& ownerGuid, ObjectGuid const& victimGuid, float threat, SpellSchoolMask schoolMask, uint32 spellId);
    void QueuePartitionThreatClearAll(uint32 partitionId, ObjectGuid const& ownerGuid);
    void QueuePartitionThreatResetAll(uint32 partitionId, ObjectGuid const& ownerGuid);
    void QueuePartitionThreatTargetClear(uint32 partitionId, ObjectGuid const& ownerGuid, ObjectGuid const& targetGuid);
    void QueuePartitionThreatTargetReset(uint32 partitionId, ObjectGuid const& ownerGuid, ObjectGuid const& targetGuid);
    void QueuePartitionCombatRelay(uint32 partitionId, ObjectGuid const& ownerGuid, ObjectGuid const& victimGuid, bool initialAggro);
    void QueuePartitionLootRelay(uint32 partitionId, ObjectGuid const& creatureGuid, ObjectGuid const& unitGuid, bool withGroup);
    void QueuePartitionDynObjectRelay(uint32 partitionId, ObjectGuid const& dynObjGuid, uint8 action);
    void QueuePartitionMinionRelay(uint32 partitionId, ObjectGuid const& ownerGuid, ObjectGuid const& minionGuid, bool apply);
    void QueuePartitionCharmRelay(uint32 partitionId, ObjectGuid const& charmerGuid, ObjectGuid const& targetGuid, uint8 charmType, uint32 auraSpellId, bool apply);
    void QueuePartitionGameObjectRelay(uint32 partitionId, ObjectGuid const& ownerGuid, ObjectGuid const& gameObjGuid, uint32 spellId, bool del, uint8 action);
    void QueuePartitionCombatStateRelay(uint32 partitionId, ObjectGuid const& unitGuid, ObjectGuid const& enemyGuid, bool pvp, uint32 duration);
    void QueuePartitionAttackRelay(uint32 partitionId, ObjectGuid const& attackerGuid, ObjectGuid const& victimGuid, bool meleeAttack);
    void QueuePartitionEvadeRelay(uint32 partitionId, ObjectGuid const& unitGuid, uint8 reason);
    void QueuePartitionTauntApply(uint32 partitionId, ObjectGuid const& ownerGuid, ObjectGuid const& taunterGuid);
    void QueuePartitionTauntFade(uint32 partitionId, ObjectGuid const& ownerGuid, ObjectGuid const& taunterGuid);
    void QueuePartitionMotionRelay(uint32 partitionId, PartitionMotionRelay const& relay);
    void QueuePartitionMotionRelay(uint32 partitionId, PartitionMotionRelay&& relay);
    void QueuePartitionProcRelay(uint32 partitionId, ObjectGuid const& actorGuid, ObjectGuid const& targetGuid, bool isVictim, uint32 procFlag, uint32 procExtra, uint32 amount, WeaponAttackType attackType, uint32 procSpellId, uint32 procAuraId, int8 procAuraEffectIndex, uint32 procPhase);
    void QueuePartitionAuraRelay(uint32 partitionId, ObjectGuid const& casterGuid, ObjectGuid const& targetGuid, uint32 spellId, uint8 effMask, bool apply, AuraRemoveMode removeMode);
    void QueuePartitionPathRelay(uint32 partitionId, ObjectGuid const& moverGuid, ObjectGuid const& targetGuid);
    void QueuePartitionPointRelay(uint32 partitionId, ObjectGuid const& moverGuid, uint32 pointId, float x, float y, float z, ForcedMovement forcedMovement, float speed, float orientation, bool generatePath, bool forceDestination, MovementSlot slot, bool hasAnimTier, AnimTier animTier);
    void QueuePartitionAssistRelay(uint32 partitionId, ObjectGuid const& moverGuid, float x, float y, float z);
    void QueuePartitionAssistDistractRelay(uint32 partitionId, ObjectGuid const& moverGuid, uint32 timeMs);

    void VisitAllObjectStores(std::function<void(MapStoredObjectTypesContainer&)> const& visitor);

    template<class T, class CONTAINER> void Visit(const Cell& cell, TypeContainerVisitor<T, CONTAINER>& visitor);

    bool IsGridLoaded(GridCoord const& gridCoord) const;
    bool IsGridLoaded(float x, float y) const
    {
        return IsGridLoaded(Acore::ComputeGridCoord(x, y));
    }
    bool IsGridCreated(GridCoord const& gridCoord) const;
    bool IsGridCreated(float x, float y) const
    {
        return IsGridCreated(Acore::ComputeGridCoord(x, y));
    }

    void LoadGrid(float x, float y);
    void LoadAllGrids();
    void LoadGridsInRange(Position const& center, float radius);
    void QueueGridPreloadInRange(Position const& center, float radius);
    void PreloadGridObjectGuids(uint32 gridId);
    std::shared_ptr<CellObjectGuids> GetPreloadedGridObjectGuids(uint32 gridId) const;
    void ClearPreloadedGridObjectGuids(uint32 gridId);
    bool UnloadGrid(MapGridType& grid);
    virtual void UnloadAll();

    std::shared_ptr<GridTerrainData> GetGridTerrainDataSharedPtr(GridCoord const& gridCoord);
    std::shared_ptr<GridTerrainData> GetGridTerrainData(GridCoord const& gridCoord);
    std::shared_ptr<GridTerrainData> GetGridTerrainData(float x, float y);

    [[nodiscard]] uint32 GetId() const { return i_mapEntry->MapID; }

    [[nodiscard]] Map const* GetParent() const { return m_parentMap; }

    // pussywizard: movemaps, mmaps
    [[nodiscard]] std::shared_mutex& GetMMapLock() const { return *(const_cast<std::shared_mutex*>(&MMapLock)); }
    std::lock_guard<std::recursive_mutex> AcquireGridObjectReadLock() const { return std::lock_guard<std::recursive_mutex>(_gridObjectLock); }
    std::lock_guard<std::recursive_mutex> AcquireGridObjectWriteLock() { return std::lock_guard<std::recursive_mutex>(_gridObjectLock); }
    // pussywizard: delayed visibility - thread-safe access
    void AddToDelayedVisibility(ObjectGuid guid)
    {
        if (!guid)
            return;
        std::lock_guard<std::mutex> lock(_delayedVisibilityLock);
        _objectsForDelayedVisibility.push_back(guid);
    }
    void HandleDelayedVisibility();

    // some calls like isInWater should not use vmaps due to processor power
    // can return INVALID_HEIGHT if under z+2 z coord not found height
    [[nodiscard]] float GetHeight(float x, float y, float z, bool checkVMap = true, float maxSearchDist = DEFAULT_HEIGHT_SEARCH) const;
    [[nodiscard]] float GetGridHeight(float x, float y) const;
    [[nodiscard]] float GetMinHeight(float x, float y) const;
    Transport* GetTransportForPos(uint32 phase, float x, float y, float z, WorldObject* worldobject = nullptr);

    void GetFullTerrainStatusForPosition(uint32 phaseMask, float x, float y, float z, float collisionHeight, PositionFullTerrainStatus& data, Optional<uint8> reqLiquidType = {});
    LiquidData const GetLiquidData(uint32 phaseMask, float x, float y, float z, float collisionHeight, Optional<uint8> ReqLiquidType);

    [[nodiscard]] bool GetAreaInfo(uint32 phaseMask, float x, float y, float z, uint32& mogpflags, int32& adtId, int32& rootId, int32& groupId) const;
    [[nodiscard]] uint32 GetAreaId(uint32 phaseMask, float x, float y, float z) const;
    [[nodiscard]] uint32 GetZoneId(uint32 phaseMask, float x, float y, float z) const;
    void GetZoneAndAreaId(uint32 phaseMask, uint32& zoneid, uint32& areaid, float x, float y, float z) const;

    [[nodiscard]] float GetWaterLevel(float x, float y) const;
    [[nodiscard]] bool IsInWater(uint32 phaseMask, float x, float y, float z, float collisionHeight) const;
    [[nodiscard]] bool IsUnderWater(uint32 phaseMask, float x, float y, float z, float collisionHeight) const;
    [[nodiscard]] bool HasEnoughWater(WorldObject const* searcher, float x, float y, float z) const;
    [[nodiscard]] bool HasEnoughWater(WorldObject const* searcher, LiquidData const& liquidData) const;

    void MoveAllCreaturesInMoveList();
    void MoveAllGameObjectsInMoveList();
    void MoveAllDynamicObjectsInMoveList();
    void RemoveAllObjectsInRemoveList();
    virtual void RemoveAllPlayers();

    [[nodiscard]] uint32 GetInstanceId() const { return i_InstanceId; }
    [[nodiscard]] uint8 GetSpawnMode() const { return (i_spawnMode); }

    enum EnterState
    {
        CAN_ENTER = 0,
        CANNOT_ENTER_ALREADY_IN_MAP = 1, // Player is already in the map
        CANNOT_ENTER_NO_ENTRY, // No map entry was found for the target map ID
        CANNOT_ENTER_UNINSTANCED_DUNGEON, // No instance template was found for dungeon map
        CANNOT_ENTER_DIFFICULTY_UNAVAILABLE, // Requested instance difficulty is not available for target map
        CANNOT_ENTER_NOT_IN_RAID, // Target instance is a raid instance and the player is not in a raid group
        CANNOT_ENTER_CORPSE_IN_DIFFERENT_INSTANCE, // Player is dead and their corpse is not in target instance
        CANNOT_ENTER_INSTANCE_BIND_MISMATCH, // Player's permanent instance save is not compatible with their group's current instance bind
        CANNOT_ENTER_TOO_MANY_INSTANCES, // Player has entered too many instances recently
        CANNOT_ENTER_MAX_PLAYERS, // Target map already has the maximum number of players allowed
        CANNOT_ENTER_ZONE_IN_COMBAT, // A boss encounter is currently in progress on the target map
        CANNOT_ENTER_UNSPECIFIED_REASON
    };

    virtual EnterState CannotEnter(Player* /*player*/, bool /*loginCheck = false*/) { return CAN_ENTER; }

    [[nodiscard]] const char* GetMapName() const;

    // have meaning only for instanced map (that have set real difficulty)
    [[nodiscard]] Difficulty GetDifficulty() const { return Difficulty(GetSpawnMode()); }
    [[nodiscard]] bool IsRegularDifficulty() const { return GetDifficulty() == REGULAR_DIFFICULTY; }
    [[nodiscard]] MapDifficulty const* GetMapDifficulty() const;

    [[nodiscard]] bool Instanceable() const { return i_mapEntry && i_mapEntry->Instanceable(); }
    [[nodiscard]] bool IsDungeon() const { return i_mapEntry && i_mapEntry->IsDungeon(); }
    [[nodiscard]] bool IsNonRaidDungeon() const { return i_mapEntry && i_mapEntry->IsNonRaidDungeon(); }
    [[nodiscard]] bool IsRaid() const { return i_mapEntry && i_mapEntry->IsRaid(); }
    [[nodiscard]] bool IsRaidOrHeroicDungeon() const { return IsRaid() || i_spawnMode > DUNGEON_DIFFICULTY_NORMAL; }
    [[nodiscard]] bool IsHeroic() const { return IsRaid() ? i_spawnMode >= RAID_DIFFICULTY_10MAN_HEROIC : i_spawnMode >= DUNGEON_DIFFICULTY_HEROIC; }
    [[nodiscard]] bool Is25ManRaid() const { return IsRaid() && i_spawnMode & RAID_DIFFICULTY_MASK_25MAN; }   // since 25man difficulties are 1 and 3, we can check them like that
    [[nodiscard]] bool IsBattleground() const { return i_mapEntry && i_mapEntry->IsBattleground(); }
    [[nodiscard]] bool IsBattleArena() const { return i_mapEntry && i_mapEntry->IsBattleArena(); }
    [[nodiscard]] bool IsBattlegroundOrArena() const { return i_mapEntry && i_mapEntry->IsBattlegroundOrArena(); }
    [[nodiscard]] bool IsWorldMap() const { return i_mapEntry && i_mapEntry->IsWorldMap(); }

    bool GetEntrancePos(int32& mapid, float& x, float& y)
    {
        if (!i_mapEntry)
            return false;
        return i_mapEntry->GetEntrancePos(mapid, x, y);
    }

    void AddObjectToRemoveList(WorldObject* obj);
    virtual void DelayedUpdate(const uint32 diff);

    void FlushPendingUpdateListAdds();

    void resetMarkedCells()
    {
        for (auto& word : _markedCells)
            word.store(0, std::memory_order_relaxed);
    }

    bool isCellMarked(uint32 pCellId)
    {
        size_t wordIndex = pCellId / kMarkedCellWordBits;
        size_t bitIndex = pCellId % kMarkedCellWordBits;
        if (wordIndex >= _markedCells.size())
            return false;
        uint64 mask = uint64(1) << bitIndex;
        return (_markedCells[wordIndex].load(std::memory_order_relaxed) & mask) != 0;
    }

    void markCell(uint32 pCellId)
    {
        size_t wordIndex = pCellId / kMarkedCellWordBits;
        size_t bitIndex = pCellId % kMarkedCellWordBits;
        if (wordIndex >= _markedCells.size())
            return;
        uint64 mask = uint64(1) << bitIndex;
        _markedCells[wordIndex].fetch_or(mask, std::memory_order_relaxed);
    }

    [[nodiscard]] bool HavePlayers() const { return !m_mapRefMgr.IsEmpty(); }
    [[nodiscard]] uint32 GetPlayersCountExceptGMs() const;

    void SendToPlayers(WorldPacket const* data) const;

    typedef MapRefMgr PlayerList;
    [[nodiscard]] PlayerList const& GetPlayers() const { return m_mapRefMgr; }

    //per-map script storage
    void ScriptsStart(std::map<uint32, std::multimap<uint32, ScriptInfo> > const& scripts, uint32 id, Object* source, Object* target);
    void ScriptCommandStart(ScriptInfo const& script, uint32 delay, Object* source, Object* target);

    CreatureGroupHolderType CreatureGroupHolder;

    void UpdateIteratorBack(Player* player);

    TempSummon* SummonCreature(uint32 entry, Position const& pos, SummonPropertiesEntry const* properties = nullptr, uint32 duration = 0, WorldObject* summoner = nullptr, uint32 spellId = 0, uint32 vehId = 0, bool visibleBySummonerOnly = false);
    GameObject* SummonGameObject(uint32 entry, float x, float y, float z, float ang, float rotation0, float rotation1, float rotation2, float rotation3, uint32 respawnTime, bool checkTransport = true);
    GameObject* SummonGameObject(uint32 entry, Position const& pos, float rotation0 = 0.0f, float rotation1 = 0.0f, float rotation2 = 0.0f, float rotation3 = 0.0f, uint32 respawnTime = 100, bool checkTransport = true);
    void SummonCreatureGroup(uint8 group, std::list<TempSummon*>* list = nullptr);
    void SummonGameObjectGroup(uint8 group, std::list<GameObject*>* list = nullptr);

    Corpse* GetCorpse(ObjectGuid const& guid);
    Creature* GetCreature(ObjectGuid const& guid);
    Creature* GetCreature(ObjectGuid const& guid) const;
    GameObject* GetGameObject(ObjectGuid const& guid);
    Transport* GetTransport(ObjectGuid const& guid);
    DynamicObject* GetDynamicObject(ObjectGuid const& guid);
    Pet* GetPet(ObjectGuid const& guid);
    Pet* GetPet(ObjectGuid const& guid) const;

    MapStoredObjectTypesContainer& GetObjectsStore() { return _objectsStore; }

    template<class T>
    void InsertObjectStore(ObjectGuid const& guid, T* obj)
    {
        std::unique_lock<std::shared_mutex> lock(_objectsStoreLock);
        _objectsStore.Insert<T>(guid, obj);
    }

    template<class T>
    void RemoveObjectStore(ObjectGuid const& guid)
    {
        std::unique_lock<std::shared_mutex> lock(_objectsStoreLock);
        _objectsStore.Remove<T>(guid);
    }

    template<class T>
    T* FindObjectStore(ObjectGuid const& guid) const
    {
        std::shared_lock<std::shared_mutex> lock(_objectsStoreLock);
        return _objectsStore.Find<T>(guid);
    }

    typedef std::unordered_multimap<ObjectGuid::LowType, Creature*> CreatureBySpawnIdContainer;
    std::vector<Creature*> GetCreaturesBySpawnId(ObjectGuid::LowType spawnId) const;
    std::vector<std::pair<ObjectGuid::LowType, Creature*>> GetCreatureBySpawnIdStoreSnapshot() const;
    void AddCreatureToSpawnIdStore(ObjectGuid::LowType spawnId, Creature* creature);
    void RemoveCreatureFromSpawnIdStore(ObjectGuid::LowType spawnId, Creature* creature);

    typedef std::unordered_multimap<ObjectGuid::LowType, GameObject*> GameObjectBySpawnIdContainer;
    std::vector<GameObject*> GetGameObjectsBySpawnId(ObjectGuid::LowType spawnId) const;
    std::vector<std::pair<ObjectGuid::LowType, GameObject*>> GetGameObjectBySpawnIdStoreSnapshot() const;
    void AddGameObjectToSpawnIdStore(ObjectGuid::LowType spawnId, GameObject* gameObject);
    void RemoveGameObjectFromSpawnIdStore(ObjectGuid::LowType spawnId, GameObject* gameObject);

    [[nodiscard]] std::unordered_set<Corpse*> const* GetCorpsesInGrid(uint32 gridId) const
    {
        auto itr = _corpsesByGrid.find(gridId);
        if (itr != _corpsesByGrid.end())
            return &itr->second;

        return nullptr;
    }

    [[nodiscard]] Corpse* GetCorpseByPlayer(ObjectGuid const& ownerGuid) const
    {
        auto itr = _corpsesByPlayer.find(ownerGuid);
        if (itr != _corpsesByPlayer.end())
            return itr->second;

        return nullptr;
    }

    MapInstanced* ToMapInstanced() { if (Instanceable())  return reinterpret_cast<MapInstanced*>(this); else return nullptr;  }
    [[nodiscard]] MapInstanced const* ToMapInstanced() const { if (Instanceable())  return (const MapInstanced*)((MapInstanced*)this); else return nullptr;  }

    InstanceMap* ToInstanceMap() { if (IsDungeon())  return reinterpret_cast<InstanceMap*>(this); else return nullptr;  }
    [[nodiscard]] InstanceMap const* ToInstanceMap() const { if (IsDungeon())  return (const InstanceMap*)((InstanceMap*)this); else return nullptr;  }

    BattlegroundMap* ToBattlegroundMap() { if (IsBattlegroundOrArena()) return reinterpret_cast<BattlegroundMap*>(this); else return nullptr;  }
    [[nodiscard]] BattlegroundMap const* ToBattlegroundMap() const { if (IsBattlegroundOrArena()) return reinterpret_cast<BattlegroundMap const*>(this); return nullptr; }

    float GetWaterOrGroundLevel(uint32 phasemask, float x, float y, float z, float* ground = nullptr, bool swim = false, float collisionHeight = DEFAULT_COLLISION_HEIGHT) const;
    [[nodiscard]] float GetHeight(uint32 phasemask, float x, float y, float z, bool vmap = true, float maxSearchDist = DEFAULT_HEIGHT_SEARCH) const;
    [[nodiscard]] bool isInLineOfSight(float x1, float y1, float z1, float x2, float y2, float z2, uint32 phasemask, LineOfSightChecks checks, VMAP::ModelIgnoreFlags ignoreFlags) const;
    bool CanReachPositionAndGetValidCoords(WorldObject const* source, PathGenerator *path, float &destX, float &destY, float &destZ, bool failOnCollision = true, bool failOnSlopes = true) const;
    bool CanReachPositionAndGetValidCoords(WorldObject const* source, float &destX, float &destY, float &destZ, bool failOnCollision = true, bool failOnSlopes = true) const;
    bool CanReachPositionAndGetValidCoords(WorldObject const* source, float startX, float startY, float startZ, float &destX, float &destY, float &destZ, bool failOnCollision = true, bool failOnSlopes = true) const;
    bool CheckCollisionAndGetValidCoords(WorldObject const* source, float startX, float startY, float startZ, float &destX, float &destY, float &destZ, bool failOnCollision = true) const;
    void Balance() { std::unique_lock<std::shared_mutex> lock(_dynamicTreeLock); _dynamicTree.balance(); }
    void RemoveGameObjectModel(const GameObjectModel& model) { std::unique_lock<std::shared_mutex> lock(_dynamicTreeLock); _dynamicTree.remove(model); }
    void InsertGameObjectModel(const GameObjectModel& model) { std::unique_lock<std::shared_mutex> lock(_dynamicTreeLock); _dynamicTree.insert(model); }
    [[nodiscard]] bool ContainsGameObjectModel(const GameObjectModel& model) const { std::shared_lock<std::shared_mutex> lock(_dynamicTreeLock); return _dynamicTree.contains(model);}
    [[nodiscard]] DynamicMapTree const& GetDynamicMapTree() const { return _dynamicTree; }
    bool GetObjectHitPos(uint32 phasemask, float x1, float y1, float z1, float x2, float y2, float z2, float& rx, float& ry, float& rz, float modifyDist);
    [[nodiscard]] float GetGameObjectFloor(uint32 phasemask, float x, float y, float z, float maxSearchDist = DEFAULT_HEIGHT_SEARCH) const
    {
        std::shared_lock<std::shared_mutex> lock(_dynamicTreeLock);
        return _dynamicTree.getHeight(x, y, z, maxSearchDist, phasemask);
    }
    /*
        RESPAWN TIMES
    */
    [[nodiscard]] time_t GetLinkedRespawnTime(ObjectGuid guid) const;
    [[nodiscard]] time_t GetCreatureRespawnTime(ObjectGuid::LowType dbGuid) const
    {
        std::lock_guard<std::mutex> lock(_respawnTimesLock);
        std::unordered_map<ObjectGuid::LowType /*dbGUID*/, time_t>::const_iterator itr = _creatureRespawnTimes.find(dbGuid);
        if (itr != _creatureRespawnTimes.end())
            return itr->second;

        return time_t(0);
    }

    [[nodiscard]] time_t GetGORespawnTime(ObjectGuid::LowType dbGuid) const
    {
        std::lock_guard<std::mutex> lock(_respawnTimesLock);
        std::unordered_map<ObjectGuid::LowType /*dbGUID*/, time_t>::const_iterator itr = _goRespawnTimes.find(dbGuid);
        if (itr != _goRespawnTimes.end())
            return itr->second;

        return time_t(0);
    }

    void SaveCreatureRespawnTime(ObjectGuid::LowType dbGuid, time_t& respawnTime);
    void RemoveCreatureRespawnTime(ObjectGuid::LowType dbGuid);
    void SaveGORespawnTime(ObjectGuid::LowType dbGuid, time_t& respawnTime);
    void RemoveGORespawnTime(ObjectGuid::LowType dbGuid);
    void LoadRespawnTimes();
    void DeleteRespawnTimes();
    [[nodiscard]] time_t GetInstanceResetPeriod() const { return _instanceResetPeriod; }

    void UpdatePlayerZoneStats(uint32 oldZone, uint32 newZone);
    [[nodiscard]] uint32 ApplyDynamicModeRespawnScaling(WorldObject const* obj, uint32 respawnDelay) const;

    EventProcessor Events;

    void ScheduleCreatureRespawn(ObjectGuid /*creatureGuid*/, Milliseconds /*respawnTimer*/, Position pos = Position());

    void LoadCorpseData();
    void DeleteCorpseData();
    void AddCorpse(Corpse* corpse);
    void RemoveCorpse(Corpse* corpse);
    Corpse* ConvertCorpseToBones(ObjectGuid const& ownerGuid, bool insignia = false);
    void RemoveOldCorpses();

    static void DeleteRespawnTimesInDB(uint16 mapId, uint32 instanceId);

    bool SendZoneMessage(uint32 zone, WorldPacket const* packet, WorldSession const* self = nullptr, TeamId teamId = TEAM_NEUTRAL) const;
    void SendZoneText(uint32 zoneId, char const* text, WorldSession const* self = nullptr, TeamId teamId = TEAM_NEUTRAL) const;

    void SendInitTransports(Player* player);
    void SendRemoveTransports(Player* player);
    void SendZoneDynamicInfo(uint32 zoneId, Player* player) const;
    void SendZoneWeather(uint32 zoneId, Player* player) const;
    void SendZoneWeather(ZoneDynamicInfo const& zoneDynamicInfo, Player* player) const;
    void SendInitSelf(Player* player);

    void UpdateWeather(uint32 const diff);
    void UpdateExpiredCorpses(uint32 const diff);

    void PlayDirectSoundToMap(uint32 soundId, uint32 zoneId = 0);
    void SetZoneMusic(uint32 zoneId, uint32 musicId);
    Weather* GetOrGenerateZoneDefaultWeather(uint32 zoneId);
    void SetZoneWeather(uint32 zoneId, WeatherState weatherId, float weatherGrade);
    void SetZoneOverrideLight(uint32 zoneId, uint32 lightId, Milliseconds fadeInTime);

    // Checks encounter state at kill/spellcast, originally in InstanceScript however not every map has instance script :(
    void UpdateEncounterState(EncounterCreditType type, uint32 creditEntry, Unit* source);
    void LogEncounterFinished(EncounterCreditType type, uint32 creditEntry);

    // Do whatever you want to all the players in map [including GameMasters], i.e.: param exec = [&](Player* p) { p->Whatever(); }
    void DoForAllPlayers(std::function<void(Player*)> exec);

    void EnsureGridCreated(GridCoord const& gridCoord);
    [[nodiscard]] bool AllTransportsEmpty() const; // pussywizard
    void AllTransportsRemovePassengers(); // pussywizard
    [[nodiscard]] TransportsContainer const& GetAllTransports() const { return _transports; }

    DataMap CustomData;

    template<HighGuid high>
    inline ObjectGuid::LowType GenerateLowGuid()
    {
        static_assert(ObjectGuidTraits<high>::MapSpecific, "Only map specific guid can be generated in Map context");
        return GetGuidSequenceGenerator<high>().Generate();
    }

    void AddUpdateObject(Object* obj)
    {
        std::lock_guard<std::mutex> lock(_updateObjectsLock);
        _updateObjects.insert(obj);
    }

    void RemoveUpdateObject(Object* obj)
    {
        std::lock_guard<std::mutex> lock(_updateObjectsLock);
        _updateObjects.erase(obj);
    }

    size_t GetUpdatableObjectsCount() const { return _updatableObjectList.size(); }

    virtual std::string GetDebugInfo() const;

    uint32 GetCreatedGridsCount();
    uint32 GetLoadedGridsCount();
    uint32 GetCreatedCellsInGridCount(uint16 const x, uint16 const y);
    uint32 GetCreatedCellsInMapCount();

    void AddObjectToPendingUpdateList(WorldObject* obj);
    void RemoveObjectFromMapUpdateList(WorldObject* obj);

    typedef std::vector<WorldObject*> UpdatableObjectList;
    typedef std::vector<WorldObject*> PendingAddUpdatableObjectList;
    typedef std::unordered_map<uint32, UpdatableObjectList> PartitionedUpdatableObjectLists;

    struct PartitionThreatRelay
    {
        ObjectGuid ownerGuid;
        ObjectGuid victimGuid;
        float threat = 0.0f;
        SpellSchoolMask schoolMask = SPELL_SCHOOL_MASK_NORMAL;
        uint32 spellId = 0;
        uint64 queuedMs = 0;
    };

    struct PartitionThreatActionRelay
    {
        ObjectGuid ownerGuid;
        uint8 action = 0; // 1 = ClearAll, 2 = ResetAll
        uint64 queuedMs = 0;
    };

    struct PartitionThreatTargetActionRelay
    {
        ObjectGuid ownerGuid;
        ObjectGuid targetGuid;
        uint8 action = 0; // 1 = ClearTarget, 2 = ResetTarget
        uint64 queuedMs = 0;
    };

    struct PartitionTauntRelay
    {
        ObjectGuid ownerGuid;
        ObjectGuid taunterGuid;
        uint8 action = 0; // 1 = Apply, 2 = Fade
        uint64 queuedMs = 0;
    };

    enum PartitionMotionRelayAction : uint8
    {
        MOTION_RELAY_JUMP = 1,
        MOTION_RELAY_FALL = 2,
        MOTION_RELAY_CHARGE = 3,
        MOTION_RELAY_CHARGE_PATH = 4,
        MOTION_RELAY_FLEE = 5,
        MOTION_RELAY_DISTRACT = 6,
        MOTION_RELAY_BACKWARDS = 7,
        MOTION_RELAY_FORWARDS = 8,
        MOTION_RELAY_CIRCLE = 9,
        MOTION_RELAY_SPLINE_PATH = 10,
        MOTION_RELAY_PATH = 11,
        MOTION_RELAY_LAND = 12,
        MOTION_RELAY_TAKEOFF = 13,
        MOTION_RELAY_KNOCKBACK = 14,
        MOTION_RELAY_STOP = 15,
        MOTION_RELAY_STOP_ON_POS = 16,
        MOTION_RELAY_FACE_ORIENTATION = 17,
        MOTION_RELAY_FACE_OBJECT = 18,
        MOTION_RELAY_MONSTER_MOVE = 19,
        MOTION_RELAY_TRANSPORT_ENTER = 20,
        MOTION_RELAY_TRANSPORT_EXIT = 21,
        MOTION_RELAY_PASSENGER_RELOCATE = 22,
        MOTION_RELAY_VEHICLE_TELEPORT_PLAYER = 23
    };

    struct PartitionMotionRelay
    {
        ObjectGuid moverGuid;
        ObjectGuid targetGuid;
        uint8 action = 0;
        uint32 id = 0;
        uint32 timeMs = 0;
        uint32 pathId = 0;
        uint8 pathSource = 0;
        float x = 0.0f;
        float y = 0.0f;
        float z = 0.0f;
        float srcX = 0.0f;
        float srcY = 0.0f;
        float speedXY = 0.0f;
        float speedZ = 0.0f;
        float speed = 0.0f;
        float orientation = 0.0f;
        float dist = 0.0f;
        ForcedMovement forcedMovement = static_cast<ForcedMovement>(0);
        bool skipAnimation = false;
        bool addFlagForNPC = false;
        bool generatePath = false;
        std::vector<G3D::Vector3> pathPoints;
        uint32 spellId = 0;
        bool disableSpline = false;
        uint64 queuedMs = 0;
        uint8 bounceCount = 0;
    };

    struct PartitionCombatRelay
    {
        ObjectGuid ownerGuid;
        ObjectGuid victimGuid;
        bool initialAggro = false;
        uint64 queuedMs = 0;
    };

    struct PartitionLootRelay
    {
        ObjectGuid creatureGuid;
        ObjectGuid unitGuid;
        bool withGroup = false;
        uint64 queuedMs = 0;
    };

    struct PartitionDynObjectRelay
    {
        ObjectGuid dynObjGuid;
        uint8 action = 0; // 1 = Remove
        uint64 queuedMs = 0;
    };

    struct PartitionMinionRelay
    {
        ObjectGuid ownerGuid;
        ObjectGuid minionGuid;
        bool apply = false;
        uint64 queuedMs = 0;
        uint8 bounceCount = 0;
    };

    struct PartitionCharmRelay
    {
        ObjectGuid charmerGuid;
        ObjectGuid targetGuid;
        uint8 charmType = 0;
        uint32 auraSpellId = 0;
        bool apply = false;
        uint64 queuedMs = 0;
        uint8 bounceCount = 0;
    };

    struct PartitionGameObjectRelay
    {
        ObjectGuid ownerGuid;
        ObjectGuid gameObjGuid;
        uint32 spellId = 0;
        bool del = false;
        uint8 action = 0; // 1 = Remove, 2 = RemoveBySpell, 3 = RemoveAll
        uint64 queuedMs = 0;
        uint8 bounceCount = 0;
    };

    struct PartitionCombatStateRelay
    {
        ObjectGuid unitGuid;
        ObjectGuid enemyGuid;
        bool pvp = false;
        uint32 duration = 0;
        uint64 queuedMs = 0;
        uint8 bounceCount = 0;
    };

    struct PartitionAttackRelay
    {
        ObjectGuid attackerGuid;
        ObjectGuid victimGuid;
        bool meleeAttack = false;
        uint64 queuedMs = 0;
        uint8 bounceCount = 0;
    };

    struct PartitionEvadeRelay
    {
        ObjectGuid unitGuid;
        uint8 reason = 0;
        uint64 queuedMs = 0;
        uint8 bounceCount = 0;
    };

    struct PartitionProcRelay
    {
        ObjectGuid actorGuid;
        ObjectGuid targetGuid;
        uint32 procFlag = 0;
        uint32 procExtra = 0;
        uint32 amount = 0;
        WeaponAttackType attackType = static_cast<WeaponAttackType>(0);
        uint32 procSpellId = 0;
        uint32 procAuraId = 0;
        int8 procAuraEffectIndex = -1;
        uint32 procPhase = 0;
        bool isVictim = false;
        uint64 queuedMs = 0;
    };

    struct PartitionAuraRelay
    {
        ObjectGuid casterGuid;
        ObjectGuid targetGuid;
        uint32 spellId = 0;
        uint8 effMask = 0;
        bool apply = true;
        AuraRemoveMode removeMode = static_cast<AuraRemoveMode>(0);
        uint64 queuedMs = 0;
    };

    struct PartitionPathRelay
    {
        ObjectGuid moverGuid;
        ObjectGuid targetGuid;
        uint64 queuedMs = 0;
        uint8 bounceCount = 0;
    };

    struct PartitionPointRelay
    {
        ObjectGuid moverGuid;
        uint32 pointId = 0;
        float x = 0.0f;
        float y = 0.0f;
        float z = 0.0f;
        ForcedMovement forcedMovement = static_cast<ForcedMovement>(0);
        float speed = 0.0f;
        float orientation = 0.0f;
        bool generatePath = true;
        bool forceDestination = true;
        MovementSlot slot = static_cast<MovementSlot>(0);
        bool hasAnimTier = false;
        AnimTier animTier = static_cast<AnimTier>(0);
        uint64 queuedMs = 0;
        uint8 bounceCount = 0;
    };

    struct PartitionAssistRelay
    {
        ObjectGuid moverGuid;
        float x = 0.0f;
        float y = 0.0f;
        float z = 0.0f;
        uint64 queuedMs = 0;
        uint8 bounceCount = 0;
    };

    struct PartitionAssistDistractRelay
    {
        ObjectGuid moverGuid;
        uint32 timeMs = 0;
        uint64 queuedMs = 0;
        uint8 bounceCount = 0;
    };

    void AddToPartitionedUpdateList(WorldObject* obj);
    void RemoveFromPartitionedUpdateList(WorldObject* obj);
    void RemoveFromPartitionedUpdateListNoLock(WorldObject* obj);
    void QueuePartitionedUpdateListRemoval(WorldObject* obj);
    void ApplyQueuedPartitionedRemovals();
    void UpdatePartitionedOwnership(WorldObject* obj);
    void ApplyQueuedPartitionedOwnershipUpdates();
    void CollectPartitionedUpdatableGuids(uint32 partitionId, std::vector<std::pair<ObjectGuid, uint8>>& out);
    void CollectPartitionedUpdatableObjects(uint32 partitionId, std::vector<WorldObject*>& out);
    void RegisterPartitionedObject(WorldObject* obj);
    void UnregisterPartitionedObject(WorldObject* obj);
    void UpdatePartitionedObjectStore(WorldObject* obj);
    void RebuildPartitionedObjectAssignments();
    template<class T> T* FindPartitionedObject(ObjectGuid const& guid);
    void BuildPartitionPlayerBuckets();
    void SetPartitionPlayerBuckets(std::vector<std::vector<Player*>> const& buckets);
    void ClearPartitionPlayerBuckets();
    // Valid until ClearPartitionPlayerBuckets() is called after partition workers complete.
    std::vector<Player*> const* GetPartitionPlayerBucket(uint32 partitionId) const;
    bool ShouldMarkNearbyCells() const;
    uint32 GetUpdateCounter() const;
    void PreparePartitionObjectUpdateBudget(uint32 partitionCount, uint32 tDiff);
    void GetPartitionObjectUpdateWindow(uint32 partitionId, uint32 totalObjects, uint32& startIndex, uint32& objectCount);
    void ProcessPartitionRelays(uint32 partitionId);
    void QueueDeferredVisibilityUpdate(ObjectGuid const& guid);
    void ProcessDeferredVisibilityUpdates();
    void QueueDeferredPlayerRelocation(ObjectGuid const& playerGuid, float x, float y, float z, float o);
    void ProcessDeferredPlayerRelocations();
    bool HasPendingPartitionRelayWork(uint32 partitionId);
    void MarkPartitionRelayWorkPending(uint32 partitionId);
    bool ShouldDeferNonPlayerVisibility(WorldObject const* obj) const;
    void PushDeferNonPlayerVisibility();
    void PopDeferNonPlayerVisibility();

    class VisibilityDeferGuard
    {
    public:
        explicit VisibilityDeferGuard(Map& map);
        ~VisibilityDeferGuard();

    private:
        Map& _map;
        bool _active;
    };
    std::shared_lock<std::shared_mutex> AcquirePartitionedUpdateListReadLock() const { return std::shared_lock<std::shared_mutex>(_partitionedUpdateListLock); }
    std::unique_lock<std::shared_mutex> AcquirePartitionedUpdateListWriteLock() { return std::unique_lock<std::shared_mutex>(_partitionedUpdateListLock); }
    Unit* GetUnitByGuid(ObjectGuid const& guid) const;

    void AddWorldObjectToFarVisibleMap(WorldObject* obj);
    void RemoveWorldObjectFromFarVisibleMap(WorldObject* obj);
    void AddWorldObjectToZoneWideVisibleMap(uint32 zoneId, WorldObject* obj);
    void RemoveWorldObjectFromZoneWideVisibleMap(uint32 zoneId, WorldObject* obj);
    ZoneWideVisibleWorldObjectsSet const* GetZoneWideVisibleWorldObjectsForZone(uint32 zoneId) const;
    ZoneWideVisibleWorldObjectsSet GetZoneWideVisibleWorldObjectsForZoneCopy(uint32 zoneId) const;
    void GetZoneWideVisibleWorldObjectsForZoneSnapshot(uint32 zoneId, std::vector<WorldObject*>& out) const;

    void LoadLayerClonesInRange(Player* player, float radius);
    void ClearLoadedLayer(uint32 layerId);
    void MarkGridLayerLoaded(uint16 gridX, uint16 gridY, uint32 layerId);

    [[nodiscard]] uint32 GetPlayerCountInZone(uint32 zoneId) const
    {
        std::lock_guard<std::mutex> lock(_zonePlayerCountLock);
        if (auto const& it = _zonePlayerCountMap.find(zoneId); it != _zonePlayerCountMap.end())
            return it->second;

        return 0;
    };

private:

    template<class T> void InitializeObject(T* obj);
    void AddCreatureToMoveList(Creature* c);
    void RemoveCreatureFromMoveList(Creature* c);
    void AddGameObjectToMoveList(GameObject* go);
    void RemoveGameObjectFromMoveList(GameObject* go);
    void AddDynamicObjectToMoveList(DynamicObject* go);
    void RemoveDynamicObjectFromMoveList(DynamicObject* go);

    std::mutex _moveListLock;
    std::vector<Creature*> _creaturesToMove;
    std::vector<GameObject*> _gameObjectsToMove;
    std::vector<DynamicObject*> _dynamicObjectsToMove;

    std::mutex _pendingUpdateListLock;

    struct PendingPartitionOwnershipUpdate
    {
        ObjectGuid guid;
        TypeID typeId = TYPEID_OBJECT;
    };

    struct PendingPartitionRemovalUpdate
    {
        ObjectGuid guid;
        TypeID typeId = TYPEID_OBJECT;
    };

    void QueuePartitionedOwnershipUpdate(ObjectGuid const& guid, TypeID typeId);
    void UpdatePartitionedOwnershipNoLock(WorldObject* obj);
    void RemoveFromPartitionedUpdateListByGuidNoLock(ObjectGuid const& guid, TypeID typeId, size_t maxRemovals = 64);
    std::mutex _pendingPartitionOwnershipLock;
    std::vector<PendingPartitionOwnershipUpdate> _pendingPartitionOwnershipUpdates;

    std::mutex _pendingPartitionRemovalLock;
    std::vector<PendingPartitionRemovalUpdate> _pendingPartitionRemovals;

    bool EnsureGridLoaded(Cell const& cell);
    void EnsureGridLayerLoaded(Cell const& cell, uint32 layerId);
    MapGridType* GetMapGrid(uint16 const x, uint16 const y);

    void ScriptsProcess();

    void SendObjectUpdates();

protected:
    // Type specific code for add/remove to/from grid
    template<class T>
    void AddToGrid(T* object, Cell const& cell);

    std::mutex Lock;
    std::shared_mutex MMapLock;
    mutable std::recursive_mutex _gridObjectLock;

    MapGridManager _mapGridManager;
    mutable std::mutex _preloadedGridGuidsLock;
    std::unordered_map<uint32, std::shared_ptr<CellObjectGuids>> _preloadedGridGuids;
    MapEntry const* i_mapEntry;
    uint8 i_spawnMode;
    uint32 i_InstanceId;
    uint32 m_unloadTimer;
    float m_VisibleDistance;
    bool _isPartitioned = false;
    bool _partitionLogShown = false;
    bool _useParallelPartitions = false;
    DynamicMapTree _dynamicTree;
    mutable std::shared_mutex _dynamicTreeLock;
    time_t _instanceResetPeriod; // pussywizard

    MapRefMgr m_mapRefMgr;
    MapRefMgr::iterator m_mapRefIter;

    TransportsContainer _transports;
    TransportsContainer::iterator _transportsUpdateIter;

private:
    Player* _GetScriptPlayerSourceOrTarget(Object* source, Object* target, const ScriptInfo* scriptInfo) const;
    Creature* _GetScriptCreatureSourceOrTarget(Object* source, Object* target, const ScriptInfo* scriptInfo, bool bReverse = false) const;
    Unit* _GetScriptUnit(Object* obj, bool isSource, const ScriptInfo* scriptInfo) const;
    Player* _GetScriptPlayer(Object* obj, bool isSource, const ScriptInfo* scriptInfo) const;
    Creature* _GetScriptCreature(Object* obj, bool isSource, const ScriptInfo* scriptInfo) const;
    WorldObject* _GetScriptWorldObject(Object* obj, bool isSource, const ScriptInfo* scriptInfo) const;
    void _ScriptProcessDoor(Object* source, Object* target, const ScriptInfo* scriptInfo) const;
    GameObject* _FindGameObject(WorldObject* pWorldObject, ObjectGuid::LowType guid) const;
    std::mutex& GetRelayLock(uint32 partitionId);
    //used for fast base_map (e.g. MapInstanced class object) search for
    //InstanceMaps and BattlegroundMaps...
    Map* m_parentMap;

    static constexpr size_t kMarkedCellWordBits = 64;
    static constexpr size_t kMarkedCellCount = TOTAL_NUMBER_OF_CELLS_PER_MAP * TOTAL_NUMBER_OF_CELLS_PER_MAP;
    static constexpr size_t kMarkedCellWordCount = (kMarkedCellCount + kMarkedCellWordBits - 1) / kMarkedCellWordBits;
    std::vector<std::atomic<uint64_t>> _markedCells;

    std::atomic<bool> i_scriptLock;
    std::unordered_set<WorldObject*> i_objectsToRemove;
    mutable std::mutex _objectsToRemoveLock;

    mutable std::mutex _delayedVisibilityLock;
    std::vector<ObjectGuid> _objectsForDelayedVisibility;

    PartitionedUpdatableObjectLists _partitionedUpdatableObjectLists;
    mutable std::shared_mutex _partitionedUpdateListLock;
    struct PartitionedUpdatableEntry
    {
        uint32 partitionId = 0;
        size_t index = 0;
        ObjectGuid guid = ObjectGuid::Empty;
            uint8 typeId = 0;
    };
    std::unordered_map<WorldObject*, PartitionedUpdatableEntry> _partitionedUpdatableIndex;
    std::unordered_map<uint32, MapStoredObjectTypesContainer> _partitionedObjectsStore;
    mutable std::shared_mutex _partitionedObjectStoreLock; // Protects _partitionedObjectsStore and _partitionedObjectIndex
    std::atomic<uint64> _partitionedObjectStoreWriter{0};
    mutable std::shared_mutex _partitionPlayerBucketsLock;
    std::vector<std::vector<Player*>> _partitionPlayerBuckets;
    bool _partitionPlayerBucketsReady = false;
    std::unordered_map<ObjectGuid, uint32> _partitionedObjectIndex;
    static constexpr size_t kRelayLockStripes = 1;
    std::array<std::mutex, kRelayLockStripes> _relayLocks;
    std::mutex _partitionRelayPendingLock;
    std::unordered_set<uint32> _partitionsWithRelayWork;
    std::unordered_map<uint32, std::deque<PartitionThreatRelay>> _partitionThreatRelays;
    std::unordered_map<uint32, std::deque<PartitionThreatActionRelay>> _partitionThreatActionRelays;
    std::unordered_map<uint32, std::deque<PartitionThreatTargetActionRelay>> _partitionThreatTargetActionRelays;
    std::unordered_map<uint32, std::deque<PartitionTauntRelay>> _partitionTauntRelays;
    std::unordered_map<uint32, std::deque<PartitionCombatRelay>> _partitionCombatRelays;
    std::unordered_map<uint32, std::deque<PartitionLootRelay>> _partitionLootRelays;
    std::unordered_map<uint32, std::deque<PartitionDynObjectRelay>> _partitionDynObjectRelays;
    std::unordered_map<uint32, std::deque<PartitionMinionRelay>> _partitionMinionRelays;
    std::unordered_map<uint32, std::deque<PartitionCharmRelay>> _partitionCharmRelays;
    std::unordered_map<uint32, std::deque<PartitionGameObjectRelay>> _partitionGameObjectRelays;
    std::unordered_map<uint32, std::deque<PartitionCombatStateRelay>> _partitionCombatStateRelays;
    std::unordered_map<uint32, std::deque<PartitionAttackRelay>> _partitionAttackRelays;
    std::unordered_map<uint32, std::deque<PartitionEvadeRelay>> _partitionEvadeRelays;
    std::unordered_map<uint32, std::deque<PartitionMotionRelay>> _partitionMotionRelays;
    std::unordered_map<uint32, std::deque<PartitionProcRelay>> _partitionProcRelays;
    std::unordered_map<uint32, std::deque<PartitionAuraRelay>> _partitionAuraRelays;
    std::unordered_map<uint32, std::deque<PartitionPathRelay>> _partitionPathRelays;
    std::unordered_map<uint32, std::deque<PartitionPointRelay>> _partitionPointRelays;
    std::unordered_map<uint32, std::deque<PartitionAssistRelay>> _partitionAssistRelays;
    std::unordered_map<uint32, std::deque<PartitionAssistDistractRelay>> _partitionAssistDistractRelays;

        std::atomic<bool> _markNearbyCellsThisTick{false};

    typedef std::multimap<time_t, ScriptAction> ScriptScheduleMap;
    ScriptScheduleMap m_scriptSchedule;
        mutable std::mutex _scriptScheduleLock;

    template<class T>
    void DeleteFromWorld(T*);

    void UpdateNonPlayerObjects(uint32 const diff);

    void _AddObjectToUpdateList(WorldObject* obj);
    void _RemoveObjectFromUpdateList(WorldObject* obj);

    std::unordered_map<ObjectGuid::LowType /*dbGUID*/, time_t> _creatureRespawnTimes;
    std::unordered_map<ObjectGuid::LowType /*dbGUID*/, time_t> _goRespawnTimes;
    mutable std::mutex _respawnTimesLock;

    std::unordered_map<uint32, uint32> _zonePlayerCountMap;
    mutable std::mutex _zonePlayerCountLock;

    std::mutex _deferredVisibilityLock;
    std::unordered_set<ObjectGuid> _deferredVisibilitySet;
    std::deque<ObjectGuid> _deferredVisibilityUpdates;

    struct DeferredPlayerRelocation
    {
        ObjectGuid playerGuid;
        float x = 0.0f;
        float y = 0.0f;
        float z = 0.0f;
        float o = 0.0f;
    };

    std::mutex _deferredPlayerRelocationLock;
    std::unordered_map<ObjectGuid, DeferredPlayerRelocation> _deferredPlayerRelocations;
    std::deque<ObjectGuid> _deferredPlayerRelocationOrder;
    uint64 _nextDeferredPlayerRelocationLogAtMs = 0;
    uint64 _nextSlowDelayedVisibilityLogAtMs = 0;

    bool _partitionUpdatesInProgress = false;
    uint32 _partitionUpdatesTotal = 0;
    uint32 _partitionUpdatesScheduled = 0;
    uint32 _partitionUpdatesMaxInFlight = 1;
    uint64 _partitionUpdatesStartMs = 0;
    std::vector<uint32> _partitionPrioritySchedule;
    std::vector<uint32> _partitionDeferredSchedule;
    std::mutex _partitionObjectBudgetLock;
    std::vector<uint32> _partitionObjectUpdateCursor;
    uint32 _partitionObjectUpdateBudget = 0;
    bool _partitionObjectUpdateCarryOver = true;
    std::atomic<uint32> _partitionUpdatesCompleted{0};
    std::atomic<uint32> _partitionUpdateGeneration{0};
    std::atomic<uint64> _partitionCycleQueueWaitTotalMs{0};
    std::atomic<uint64> _partitionCycleRunTotalMs{0};
    std::atomic<uint64> _partitionCycleMaxRunMs{0};
    std::atomic<uint64> _partitionCycleMaxQueueWaitMs{0};
    std::atomic<uint64> _partitionCycleFirstTaskStartMs{0};
    std::atomic<uint64> _partitionCycleLastTaskEndMs{0};
    uint64 _nextSlowPartitionLogAtMs = 0;
    uint32 _lastPartitionCycleMaxRunMs = 0;
    uint32 _lastPartitionCycleMaxQueueWaitMs = 0;

    std::atomic<uint32> _updateCounter{0};
    uint32 _pendingDynamicTreeDiff = 0;
    uint32 _adaptiveSessionStrideTicks = 2;
    size_t _adaptiveDeferredVisibilityBudget = 512;
    size_t _adaptiveObjectUpdateBudget = 2048;
    uint32 _adaptivePartitionInFlightLimit = 4;
    std::mutex _gridLayerLock;
    std::unordered_map<uint32, std::unordered_set<uint32>> _gridLoadedLayers;

    ZoneDynamicInfoMap _zoneDynamicInfo;
    IntervalTimer _weatherUpdateTimer;
    uint32 _defaultLight;

    IntervalTimer _corpseUpdateTimer;

    template<HighGuid high>
    inline ObjectGuidGeneratorBase& GetGuidSequenceGenerator()
    {
        auto itr = _guidGenerators.find(high);
        if (itr == _guidGenerators.end())
            itr = _guidGenerators.insert(std::make_pair(high, std::unique_ptr<ObjectGuidGenerator<high>>(new ObjectGuidGenerator<high>()))).first;

        return *itr->second;
    }

    std::map<HighGuid, std::unique_ptr<ObjectGuidGeneratorBase>> _guidGenerators;
    MapStoredObjectTypesContainer _objectsStore;
    mutable std::shared_mutex _objectsStoreLock;
    CreatureBySpawnIdContainer _creatureBySpawnIdStore;
    GameObjectBySpawnIdContainer _gameobjectBySpawnIdStore;
    mutable std::shared_mutex _spawnIdStoreLock;
    std::unordered_map<uint32/*gridId*/, std::unordered_set<Corpse*>> _corpsesByGrid;
    std::unordered_map<ObjectGuid, Corpse*> _corpsesByPlayer;
    std::unordered_set<Corpse*> _corpseBones;

    mutable std::mutex _updateObjectsLock;
    std::unordered_set<Object*> _updateObjects;

    mutable std::mutex _updatableObjectListLock;
    UpdatableObjectList _updatableObjectList;
    PendingAddUpdatableObjectList _pendingAddUpdatableObjectList;
    IntervalTimer _updatableObjectListRecheckTimer;
    ZoneWideVisibleWorldObjectsMap _zoneWideVisibleWorldObjectsMap;
    mutable std::shared_mutex _zoneWideVisibleLock;
};

enum InstanceResetMethod
{
    INSTANCE_RESET_ALL,                 // reset all option under portrait, resets only normal 5-mans
    INSTANCE_RESET_CHANGE_DIFFICULTY,   // on changing difficulty
    INSTANCE_RESET_GLOBAL,              // global id reset
    INSTANCE_RESET_GROUP_JOIN,          // on joining group
    INSTANCE_RESET_GROUP_LEAVE          // on leaving group
};

class InstanceMap : public Map
{
public:
    InstanceMap(uint32 id, uint32 InstanceId, uint8 SpawnMode, Map* _parent);
    ~InstanceMap() override;
    bool AddPlayerToMap(Player*) override;
    void RemovePlayerFromMap(Player*, bool) override;
    void AfterPlayerUnlinkFromMap() override;
    void Update(const uint32, const uint32, bool thread = true) override;
    void CreateInstanceScript(bool load, std::string data, uint32 completedEncounterMask);
    bool Reset(uint8 method, GuidList* globalSkipList = nullptr);
    [[nodiscard]] uint32 GetScriptId() const { return i_script_id; }
    [[nodiscard]] std::string const& GetScriptName() const;
    [[nodiscard]] InstanceScript* GetInstanceScript() { return instance_data; }
    [[nodiscard]] InstanceScript const* GetInstanceScript() const { return instance_data; }
    void PermBindAllPlayers();
    void UnloadAll() override;
    EnterState CannotEnter(Player* player, bool loginCheck = false) override;
    void SendResetWarnings(uint32 timeLeft) const;

    [[nodiscard]] uint32 GetMaxPlayers() const;
    [[nodiscard]] uint32 GetMaxResetDelay() const;

    void InitVisibilityDistance() override;

    std::string GetDebugInfo() const override;

private:
    bool m_resetAfterUnload;
    bool m_unloadWhenEmpty;
    InstanceScript* instance_data;
    uint32 i_script_id;
};

class BattlegroundMap : public Map
{
public:
    BattlegroundMap(uint32 id, uint32 InstanceId, Map* _parent, uint8 spawnMode);
    ~BattlegroundMap() override;

    bool AddPlayerToMap(Player*) override;
    void RemovePlayerFromMap(Player*, bool) override;
    EnterState CannotEnter(Player* player, bool loginCheck = false) override;
    void SetUnload();
    //void UnloadAll(bool pForce);
    void RemoveAllPlayers() override;

    void InitVisibilityDistance() override;
    Battleground* GetBG() { return m_bg; }
    void SetBG(Battleground* bg) { m_bg = bg; }
private:
    Battleground* m_bg;
};

template<class T, class CONTAINER>
inline void Map::Visit(Cell const& cell, TypeContainerVisitor<T, CONTAINER>& visitor)
{
    auto gridLock = AcquireGridObjectReadLock();
    uint32 const grid_x = cell.GridX();
    uint32 const grid_y = cell.GridY();

    // If grid is not loaded, nothing to visit.
    if (!IsGridLoaded(GridCoord(grid_x, grid_y)))
        return;

    GetMapGrid(grid_x, grid_y)->VisitCell(cell.CellX(), cell.CellY(), visitor);
}

#endif
