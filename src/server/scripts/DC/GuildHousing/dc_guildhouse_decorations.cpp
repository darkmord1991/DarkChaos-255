/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * Guild House Decorations - Implementation
 * Catalog + budget bookkeeping + validated place/move/remove operations,
 * plus the "Guild House Decorator" gossip NPC as the non-addon UI.
 */

#include "dc_guildhouse_decorations.h"
#include "Chat.h"
#include "Config.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "GameObject.h"
#include "GameTime.h"
#include "GossipDef.h"
#include "Log.h"
#include "Map.h"
#include "Player.h"
#include "ObjectMgr.h"
#include "ScriptedGossip.h"
#include "ScriptMgr.h"
#include "WorldSession.h"
#include "dc_guildhouse.h"
#include "../AddonExtension/dc_addon_namespace.h"
#include "../CrossSystem/CrossSystemDbSchema.h"
#include "../GOMove/GOMove.h"

#include <algorithm>
#include <cmath>
#include <map>
#include <unordered_map>

namespace DCGuildHouseDecorations
{

namespace
{
    // Persistent metadata for a placed decoration (one row of
    // dc_guild_house_instance_spawns, source=DECORATION). Position lives here
    // now (there is no backing world.gameobject row in the instanced model).
    struct InstanceInfo
    {
        uint32 guildId = 0;
        uint32 entry = 0;
        uint32 paidCopper = 0;
        float scale = 1.0f;
        float x = 0.f;
        float y = 0.f;
        float z = 0.f;
        float o = 0.f;
        uint32 mapId = 0;
    };

    // The live, non-persistent in-world GameObject backing a decoration in a
    // currently-loaded instance. instanceId disambiguates objects across the
    // several instances that may be loaded at once.
    struct LiveRef
    {
        ObjectGuid guid;
        uint32 instanceId = 0;
    };

    // World-thread only. The decoration key ("lowguid" in the public API) is the
    // dc_guild_house_instance_spawns row id, not a world spawn id.
    std::map<uint32, CatalogEntry> sCatalog;                 // entry -> data
    std::vector<std::string> sCategories;
    std::unordered_map<uint8, uint32> sBudgetCaps;           // level -> cap
    std::unordered_map<uint32, InstanceInfo> sInstances;     // rowId -> info
    std::unordered_map<uint32, LiveRef> sLive;               // rowId -> live GO
    std::unordered_map<uint32, uint32> sUsedBudget;          // guildId -> used

    float sMaxPlacementRange = 250.0f;
    uint32 sRefundPercent = 50;
    bool sGmBypass = true;

    // GMs may test the decoration system anywhere: house presence/bounds,
    // rank permissions, and cross-guild ownership checks are skipped.
    bool IsDecorationGM(Player* player)
    {
        return sGmBypass && player && player->GetSession()
            && player->GetSession()->GetSecurity() >= SEC_GAMEMASTER;
    }

    // Summon a decoration non-persistently into an instance map (phase 1, no
    // SaveToDB). Returns the live GameObject or nullptr.
    GameObject* SummonDeco(Map* map, InstanceInfo const& info)
    {
        if (!map)
            return nullptr;

        GameObject* go = map->SummonGameObject(
            info.entry, info.x, info.y, info.z, info.o, 0.0f, 0.0f, 0.0f, 0.0f, 0);
        if (go && info.scale > 0.0f && std::fabs(info.scale - 1.0f) > 0.001f)
            go->SetObjectScale(info.scale);
        return go;
    }

    void RegisterLive(uint32 rowId, Map* map, GameObject* go)
    {
        sLive[rowId] = LiveRef{ go->GetGUID(), map->GetInstanceId() };
    }

    // Resolve a decoration's live GameObject, but only if it belongs to the map
    // instance the player is standing in (the editor only acts on the local one).
    GameObject* GetLiveObject(Player* player, uint32 rowId)
    {
        if (!player || !player->GetMap())
            return nullptr;

        auto it = sLive.find(rowId);
        if (it == sLive.end()
            || it->second.instanceId != player->GetMap()->GetInstanceId())
            return nullptr;

        return player->GetMap()->GetGameObject(it->second.guid);
    }

    uint32 WeightOf(uint32 entry)
    {
        auto it = sCatalog.find(entry);
        return it != sCatalog.end() ? it->second.budgetWeight : 1u;
    }

    void AddUsedBudget(uint32 guildId, int32 delta)
    {
        uint32& used = sUsedBudget[guildId];
        if (delta < 0 && used < static_cast<uint32>(-delta))
            used = 0;
        else
            used += delta;
    }

    // Common validation for every decoration operation: the player must be
    // a guild member standing inside their own guild house.
    bool ValidateInHouse(Player* player, GuildHouseData const*& outHouse,
        std::string& error)
    {
        if (!player)
        {
            error = "Invalid player.";
            return false;
        }

        // GM testing bypass: treat the player's position as house grounds
        // (max house level so catalog gating never blocks the test).
        if (IsDecorationGM(player))
        {
            static GuildHouseData gmHouse;
            gmHouse = GuildHouseData(player->GetPhaseMask(),
                player->GetMapId(), player->GetPositionX(),
                player->GetPositionY(), player->GetPositionZ(),
                player->GetOrientation(), 5);
            outHouse = &gmHouse;
            return true;
        }

        uint32 guildId = player->GetGuildId();
        if (!guildId)
        {
            error = "You are not in a guild.";
            return false;
        }

        GuildHouseData const* house =
            GuildHouseManager::GetGuildHouseData(guildId);
        if (!house)
        {
            error = "Your guild does not own a guild house.";
            return false;
        }

        if (!GuildHouseManager::IsInOwnGuildHouse(player))
        {
            error = "You must be inside your guild house.";
            return false;
        }

        // Default policy is map-wide (large plots like full city clones);
        // a radius only applies when MaxRange is configured > 0.
        if (sMaxPlacementRange > 0.f)
        {
            float const dx = player->GetPositionX() - house->posX;
            float const dy = player->GetPositionY() - house->posY;
            if ((dx * dx + dy * dy)
                > sMaxPlacementRange * sMaxPlacementRange)
            {
                error = "You are too far from the guild house grounds.";
                return false;
            }
        }

        outHouse = house;
        return true;
    }

    bool ValidateOwnedDecoration(Player* player, uint32 lowguid,
        InstanceInfo const*& outInfo, std::string& error)
    {
        auto it = sInstances.find(lowguid);
        if (it == sInstances.end()
            || (it->second.guildId != player->GetGuildId()
                && !IsDecorationGM(player)))
        {
            error = "That object is not a decoration of your guild house.";
            return false;
        }

        outInfo = &it->second;
        return true;
    }

    // The TARGET coordinates of a place/move must stay on the house
    // grounds. The map/phase bound comes from ValidateInHouse (objects are
    // spawned on the player's map); coordinates are only constrained when
    // a placement radius is configured.
    bool ValidateTargetPosition(GuildHouseData const* house, float x, float y,
        float z, std::string& error)
    {
        if (sMaxPlacementRange <= 0.f)
            return true;

        float const dx = x - house->posX;
        float const dy = y - house->posY;
        if ((dx * dx + dy * dy)
            > sMaxPlacementRange * sMaxPlacementRange)
        {
            error = "Target position is outside the guild house grounds.";
            return false;
        }

        if (std::fabs(z - house->posZ) > 100.0f)
        {
            error = "Target position is too far above or below the house.";
            return false;
        }

        return true;
    }

    // Each committed move costs two DB writes plus a despawn/respawn, so
    // cap the rate per player.
    bool ConsumeMoveRateLimit(Player* player)
    {
        static std::unordered_map<ObjectGuid, uint64> lastMoveMs;
        uint64 const now =
            static_cast<uint64>(GameTime::GetGameTimeMS().count());
        uint64& last = lastMoveMs[player->GetGUID()];
        if (last && now - last < 500)
            return false;

        last = now;
        return true;
    }
}

void LoadCatalog()
{
    sCatalog.clear();
    sCategories.clear();
    sBudgetCaps.clear();
    sInstances.clear();
    sLive.clear();
    sUsedBudget.clear();

    sMaxPlacementRange = sConfigMgr->GetOption<float>(
        "DC.GuildHouse.Decoration.MaxRange", 0.0f);
    sRefundPercent = std::min(100u, sConfigMgr->GetOption<uint32>(
        "DC.GuildHouse.Decoration.RefundPercent", 50));
    sGmBypass = sConfigMgr->GetOption<bool>(
        "DC.GuildHouse.Decoration.GMBypass", true);

    if (!DC::DbSchema::WorldTableExists("dc_guildhouse_decorations")
        || !DC::DbSchema::WorldTableExists("dc_guildhouse_decoration_budgets")
        || !DC::DbSchema::CharacterTableExists("dc_guild_house_instance_spawns"))
    {
        LOG_ERROR("scripts.dc",
            "GuildHouseDecorations: required tables missing - apply Custom "
            "feature SQLs (worlddb/GuildHousing 2026_06_13_* and chardb/"
            "GuildHousing 2026_06_19_02 dc_guild_house_instance_spawns). "
            "System disabled.");
        return;
    }

    if (QueryResult result = WorldDatabase.Query(
        "SELECT `entry`, `name`, `category`, `cost_copper`, "
        "`min_house_level`, `budget_weight`, `enabled` "
        "FROM `dc_guildhouse_decorations`"))
    {
        do
        {
            Field* fields = result->Fetch();
            CatalogEntry entry;
            entry.entry = fields[0].Get<uint32>();
            entry.name = fields[1].Get<std::string>();
            entry.category = fields[2].Get<std::string>();
            entry.costCopper = fields[3].Get<uint32>();
            entry.minHouseLevel = fields[4].Get<uint8>();
            entry.budgetWeight = fields[5].Get<uint16>();
            entry.enabled = fields[6].Get<bool>();
            if (!entry.enabled)
                continue;

            if (std::find(sCategories.begin(), sCategories.end(),
                entry.category) == sCategories.end())
                sCategories.push_back(entry.category);

            sCatalog[entry.entry] = std::move(entry);
        } while (result->NextRow());
    }
    std::sort(sCategories.begin(), sCategories.end());

    if (QueryResult result = WorldDatabase.Query(
        "SELECT `house_level`, `max_weight` "
        "FROM `dc_guildhouse_decoration_budgets`"))
    {
        do
        {
            Field* fields = result->Fetch();
            sBudgetCaps[fields[0].Get<uint8>()] = fields[1].Get<uint32>();
        } while (result->NextRow());
    }

    if (QueryResult result = CharacterDatabase.Query(
        "SELECT `id`, `guild_id`, `entry`, `paid_copper`, `scale`, "
        "`posX`, `posY`, `posZ`, `orientation` "
        "FROM `dc_guild_house_instance_spawns` WHERE `source` = 'DECORATION'"))
    {
        do
        {
            Field* fields = result->Fetch();
            uint32 rowId = fields[0].Get<uint32>();
            InstanceInfo info;
            info.guildId = fields[1].Get<uint32>();
            info.entry = fields[2].Get<uint32>();
            info.paidCopper = fields[3].Get<uint32>();
            info.scale = fields[4].Get<float>();
            if (info.scale <= 0.f)
                info.scale = 1.0f;
            info.x = fields[5].Get<float>();
            info.y = fields[6].Get<float>();
            info.z = fields[7].Get<float>();
            info.o = fields[8].Get<float>();
            // Decorations are summoned into the owning guild's instance, whose map is whichever
            // guild-house skin the guild chose (1409, 1413, ...). Resolve it from the guild's record
            // so a 1413 guild's decorations are tagged for 1413, not the default 1409.
            GuildHouseData* ghData = GuildHouseManager::GetGuildHouseData(info.guildId);
            info.mapId = (ghData && IsGuildHouseMap(ghData->map)) ? ghData->map : GUILD_HOUSE_MAP_ID;
            sInstances[rowId] = info;
            AddUsedBudget(info.guildId, WeightOf(info.entry));
        } while (result->NextRow());
    }

    LOG_INFO("scripts.dc",
        "GuildHouseDecorations: Loaded {} catalog entries, {} categories, "
        "{} placed instances",
        sCatalog.size(), sCategories.size(), sInstances.size());
}

CatalogEntry const* FindCatalogEntry(uint32 entry)
{
    auto it = sCatalog.find(entry);
    return it != sCatalog.end() ? &it->second : nullptr;
}

std::vector<std::string> const& GetCategories()
{
    return sCategories;
}

std::vector<CatalogEntry const*> GetCatalogPage(std::string const& category,
    uint32 offset, uint32 limit)
{
    std::vector<CatalogEntry const*> page;
    uint32 index = 0;
    for (auto const& [entry, data] : sCatalog)
    {
        (void)entry;
        if (!category.empty() && data.category != category)
            continue;

        if (index++ < offset)
            continue;

        page.push_back(&data);
        if (page.size() >= limit)
            break;
    }
    return page;
}

uint32 GetCatalogSize(std::string const& category)
{
    if (category.empty())
        return static_cast<uint32>(sCatalog.size());

    uint32 count = 0;
    for (auto const& [entry, data] : sCatalog)
    {
        (void)entry;
        if (data.category == category)
            ++count;
    }
    return count;
}

uint32 GetBudgetCap(uint8 houseLevel)
{
    auto it = sBudgetCaps.find(houseLevel);
    if (it != sBudgetCaps.end())
        return it->second;

    // Fall back to the highest configured level at or below houseLevel.
    uint32 cap = 0;
    for (auto const& [level, value] : sBudgetCaps)
        if (level <= houseLevel)
            cap = std::max(cap, value);
    return cap;
}

uint32 GetUsedBudget(uint32 guildId)
{
    auto it = sUsedBudget.find(guildId);
    return it != sUsedBudget.end() ? it->second : 0u;
}

bool IsOwnGuildDecoration(Player* player, uint32 lowguid)
{
    if (!player || !player->GetGuildId())
        return false;

    auto it = sInstances.find(lowguid);
    return it != sInstances.end()
        && it->second.guildId == player->GetGuildId();
}

bool PlaceAt(Player* player, uint32 entry, float x, float y, float z,
    float orientation, std::string& error, uint32* outLowguid,
    uint64* outGuidRaw)
{
    GuildHouseData const* house = nullptr;
    if (!ValidateInHouse(player, house, error))
        return false;

    if (!IsDecorationGM(player)
        && !GuildHouseManager::HasPermission(player, GH_PERM_SPAWN))
    {
        error = "Your guild rank may not place decorations.";
        return false;
    }

    CatalogEntry const* item = FindCatalogEntry(entry);
    if (!item)
    {
        error = "That decoration does not exist.";
        return false;
    }

    if (house->level < item->minHouseLevel)
    {
        error = "Your guild house level is too low for that decoration.";
        return false;
    }

    if (!ValidateTargetPosition(house, x, y, z, error))
        return false;

    uint32 const guildId = player->GetGuildId();
    uint32 const cap = GetBudgetCap(house->level);
    if (GetUsedBudget(guildId) + item->budgetWeight > cap)
    {
        error = "Your guild house decoration budget is exhausted.";
        return false;
    }

    if (!player->HasEnoughMoney(static_cast<int32>(item->costCopper)))
    {
        error = "You do not have enough gold.";
        return false;
    }

    uint32 const lowguid = GuildHouseManager::AllocateContentId();

    InstanceInfo info;
    info.guildId = guildId;
    info.entry = entry;
    info.paidCopper = item->costCopper;
    info.scale = 1.0f;
    info.x = x;
    info.y = y;
    info.z = z;
    info.o = orientation;
    info.mapId = player->GetMapId();

    GameObject* object = SummonDeco(player->GetMap(), info);
    if (!object)
    {
        error = "Failed to place the decoration.";
        return false;
    }

    player->ModifyMoney(-static_cast<int32>(item->costCopper));

    sInstances[lowguid] = info;
    RegisterLive(lowguid, player->GetMap(), object);
    AddUsedBudget(guildId, item->budgetWeight);

    CharacterDatabase.Execute(
        "INSERT INTO `dc_guild_house_instance_spawns` "
        "(`id`, `guild_id`, `spawn_type`, `entry`, `posX`, `posY`, `posZ`, "
        "`orientation`, `scale`, `source`, `paid_copper`, `placed_by`) "
        "VALUES ({}, {}, 'GAMEOBJECT', {}, {}, {}, {}, {}, 1.0, 'DECORATION', {}, {})",
        lowguid, guildId, entry, x, y, z, orientation, item->costCopper,
        player->GetGUID().GetCounter());

    GuildHouseManager::LogAction(player, GH_ACTION_SPAWN,
        GH_ENTITY_GAMEOBJECT, entry, lowguid, x, y, z, orientation);

    if (outLowguid)
        *outLowguid = lowguid;
    // Full client-facing ObjectGuid of the spawned GO (object is still live
    // here). The client resolves the just-placed object by this exact value
    // (OBJECT_FIELD_GUID), so the addon can auto-select it after placing.
    if (outGuidRaw)
        *outGuidRaw = object->GetGUID().GetRawValue();
    return true;
}

bool Place(Player* player, uint32 entry, std::string& error,
    uint32* outLowguid, uint64* outGuidRaw)
{
    if (!player)
    {
        error = "Invalid player.";
        return false;
    }

    return PlaceAt(player, entry, player->GetPositionX(),
        player->GetPositionY(), player->GetPositionZ(),
        player->GetOrientation(), error, outLowguid, outGuidRaw);
}

bool MoveTo(Player* player, uint32 lowguid, float x, float y, float z,
    float orientation, std::string& error, uint64* outGuidRaw)
{
    GuildHouseData const* house = nullptr;
    if (!ValidateInHouse(player, house, error))
        return false;

    if (!IsDecorationGM(player)
        && !GuildHouseManager::HasPermission(player, GH_PERM_MOVE))
    {
        error = "Your guild rank may not move decorations.";
        return false;
    }

    InstanceInfo const* info = nullptr;
    if (!ValidateOwnedDecoration(player, lowguid, info, error))
        return false;

    if (!ValidateTargetPosition(house, x, y, z, error))
        return false;

    if (!ConsumeMoveRateLimit(player))
    {
        error = "You are moving decorations too quickly.";
        return false;
    }

    // Despawn the old live object and re-summon at the new transform. Like the
    // old GOMove path this yields a fresh ObjectGuid (a moved-in-place object is
    // not reliably re-rendered by the 3.3.5 client), handed back for the gizmo.
    if (GameObject* old = GetLiveObject(player, lowguid))
        old->Delete();
    sLive.erase(lowguid);

    InstanceInfo& stored = sInstances[lowguid];
    stored.x = x;
    stored.y = y;
    stored.z = z;
    stored.o = Position::NormalizeOrientation(orientation);

    GameObject* moved = SummonDeco(player->GetMap(), stored);
    if (!moved)
    {
        error = "Could not move that decoration (is it nearby?).";
        return false;
    }

    RegisterLive(lowguid, player->GetMap(), moved);

    CharacterDatabase.Execute(
        "UPDATE `dc_guild_house_instance_spawns` SET `posX` = {}, `posY` = {}, "
        "`posZ` = {}, `orientation` = {} WHERE `id` = {}",
        stored.x, stored.y, stored.z, stored.o, lowguid);

    // Hand back the new live GUID so the client can re-attach its gizmo.
    if (outGuidRaw)
        *outGuidRaw = moved->GetGUID().GetRawValue();

    GuildHouseManager::LogAction(player, GH_ACTION_MOVE,
        GH_ENTITY_GAMEOBJECT, stored.entry, lowguid, x, y, z, orientation);
    return true;
}

bool MoveHere(Player* player, uint32 lowguid, std::string& error,
    uint64* outGuidRaw)
{
    if (!player)
    {
        error = "Invalid player.";
        return false;
    }

    return MoveTo(player, lowguid, player->GetPositionX(),
        player->GetPositionY(), player->GetPositionZ(),
        player->GetOrientation(), error, outGuidRaw);
}

bool Rotate(Player* player, uint32 lowguid, std::string& error,
    uint64* outGuidRaw)
{
    if (!player)
    {
        error = "Invalid player.";
        return false;
    }

    auto it = sInstances.find(lowguid);
    if (it == sInstances.end())
    {
        error = "Could not find that decoration.";
        return false;
    }

    return MoveTo(player, lowguid, it->second.x, it->second.y, it->second.z,
        player->GetOrientation(), error, outGuidRaw);
}

bool Nudge(Player* player, uint32 lowguid, float dx, float dy, float dz,
    float dOrientation, std::string& error, uint64* outGuidRaw)
{
    if (!player)
    {
        error = "Invalid player.";
        return false;
    }

    auto clampDelta = [](float value)
    {
        return std::max(-10.0f, std::min(10.0f, value));
    };

    auto it = sInstances.find(lowguid);
    if (it == sInstances.end())
    {
        error = "Could not find that decoration.";
        return false;
    }

    InstanceInfo const& info = it->second;
    return MoveTo(player, lowguid,
        info.x + clampDelta(dx),
        info.y + clampDelta(dy),
        info.z + clampDelta(dz),
        info.o + dOrientation, error, outGuidRaw);
}

bool SetScale(Player* player, uint32 lowguid, float scale, std::string& error)
{
    GuildHouseData const* house = nullptr;
    if (!ValidateInHouse(player, house, error))
        return false;

    // Scale is a property edit, so it reuses the MOVE permission (it neither
    // spawns nor deletes).
    if (!IsDecorationGM(player)
        && !GuildHouseManager::HasPermission(player, GH_PERM_MOVE))
    {
        error = "Your guild rank may not modify decorations.";
        return false;
    }

    InstanceInfo const* info = nullptr;
    if (!ValidateOwnedDecoration(player, lowguid, info, error))
        return false;

    // Clamp to a sane visual range: too small becomes unclickable, too large
    // can swallow the whole house.
    scale = std::max(0.2f, std::min(5.0f, scale));

    GameObject* object = GetLiveObject(player, lowguid);
    if (!object)
    {
        error = "Could not find that decoration (is it nearby?).";
        return false;
    }

    object->SetObjectScale(scale);
    // A live OBJECT_FIELD_SCALE_X change does not rescale an already-spawned
    // model on clients, so force a despawn/respawn for nearby players; the
    // recreated object is built at the new scale.
    object->DestroyForVisiblePlayers();
    object->UpdateObjectVisibility();

    sInstances[lowguid].scale = scale;
    CharacterDatabase.Execute(
        "UPDATE `dc_guild_house_instance_spawns` SET `scale` = {} WHERE `id` = {}",
        scale, lowguid);

    return true;
}

float GetDecorationScale(uint32 lowguid)
{
    auto it = sInstances.find(lowguid);
    return it != sInstances.end() ? it->second.scale : 1.0f;
}

void LoadIntoInstance(Map* map, uint32 guildId)
{
    if (!map || !guildId)
        return;

    for (auto const& [rowId, info] : sInstances)
    {
        if (info.guildId != guildId)
            continue;

        // Drop any stale live ref before re-summoning into the fresh instance.
        sLive.erase(rowId);
        if (GameObject* go = SummonDeco(map, info))
            RegisterLive(rowId, map, go);
    }
}

bool GetLiveGuidRaw(Player* player, uint32 lowguid, uint64& outRaw)
{
    if (GameObject* go = GetLiveObject(player, lowguid))
    {
        outRaw = go->GetGUID().GetRawValue();
        return true;
    }
    return false;
}

void ForgetGuild(uint32 guildId)
{
    if (!guildId)
        return;

    for (auto it = sInstances.begin(); it != sInstances.end(); )
    {
        if (it->second.guildId == guildId)
        {
            sLive.erase(it->first);
            it = sInstances.erase(it);
        }
        else
        {
            ++it;
        }
    }

    sUsedBudget.erase(guildId);
}

bool GetDecorationTransform(uint32 lowguid, float& x, float& y, float& z,
    float& orientation, float& scale)
{
    auto it = sInstances.find(lowguid);
    if (it == sInstances.end())
        return false;

    x = it->second.x;
    y = it->second.y;
    z = it->second.z;
    orientation = it->second.o;
    scale = it->second.scale;
    return true;
}

bool ResolveSelection(Player* player, uint64 rawGuid, uint32& outLowguid,
    uint32& outEntry, uint32& outPaidCopper, std::string& error)
{
    if (!player || !player->GetMap())
    {
        error = "Invalid player.";
        return false;
    }

    GameObject* object = player->GetMap()->GetGameObject(ObjectGuid(rawGuid));
    if (!object)
    {
        error = "That object could not be found.";
        return false;
    }

    // Decorations are non-persistent (spawn id 0); map the live object back to
    // its row by matching the registered GUID within this map instance.
    uint32 const instanceId = player->GetMap()->GetInstanceId();
    uint32 lowguid = 0;
    for (auto const& [rowId, ref] : sLive)
    {
        if (ref.instanceId == instanceId && ref.guid == object->GetGUID())
        {
            lowguid = rowId;
            break;
        }
    }

    InstanceInfo const* info = nullptr;
    if (!lowguid || !ValidateOwnedDecoration(player, lowguid, info, error))
    {
        if (error.empty())
            error = "That object is not a decoration of your guild house.";
        return false;
    }

    outLowguid = lowguid;
    outEntry = info->entry;
    outPaidCopper = info->paidCopper;
    return true;
}

void ListDecorations(Player* player, std::vector<PlacedDecoration>& out)
{
    if (!player)
        return;

    uint32 const guildId = player->GetGuildId();
    if (!guildId)
        return;

    for (auto const& [lowguid, info] : sInstances)
    {
        if (info.guildId != guildId)
            continue;

        PlacedDecoration d;
        d.lowguid = lowguid;
        d.entry = info.entry;
        d.scale = info.scale;
        d.x = info.x;
        d.y = info.y;
        d.z = info.z;
        d.orientation = info.o;
        d.mapId = info.mapId;
        if (CatalogEntry const* item = FindCatalogEntry(info.entry))
            d.name = item->name;

        out.push_back(d);
    }
}

bool Remove(Player* player, uint32 lowguid, std::string& error,
    uint32* outRefundCopper)
{
    GuildHouseData const* house = nullptr;
    if (!ValidateInHouse(player, house, error))
        return false;

    if (!IsDecorationGM(player)
        && !GuildHouseManager::HasPermission(player, GH_PERM_DELETE))
    {
        error = "Your guild rank may not remove decorations.";
        return false;
    }

    InstanceInfo const* info = nullptr;
    if (!ValidateOwnedDecoration(player, lowguid, info, error))
        return false;

    uint32 const entry = info->entry;
    uint32 const refund = info->paidCopper * sRefundPercent / 100;

    if (GameObject* object = GetLiveObject(player, lowguid))
        object->Delete();

    AddUsedBudget(player->GetGuildId(), -static_cast<int32>(WeightOf(entry)));
    sInstances.erase(lowguid);
    sLive.erase(lowguid);
    CharacterDatabase.Execute(
        "DELETE FROM `dc_guild_house_instance_spawns` WHERE `id` = {}",
        lowguid);

    if (refund)
        player->ModifyMoney(static_cast<int32>(refund));

    GuildHouseManager::LogAction(player, GH_ACTION_DELETE,
        GH_ENTITY_GAMEOBJECT, entry, lowguid, player->GetPositionX(),
        player->GetPositionY(), player->GetPositionZ(),
        player->GetOrientation());

    if (outRefundCopper)
        *outRefundCopper = refund;
    return true;
}

bool RemoveAll(Player* player, std::string& error,
    uint32* outRemovedCount, uint32* outTotalRefund)
{
    GuildHouseData const* house = nullptr;
    if (!ValidateInHouse(player, house, error))
        return false;

    if (!IsDecorationGM(player)
        && !GuildHouseManager::HasPermission(player, GH_PERM_DELETE))
    {
        error = "Your guild rank may not remove decorations.";
        return false;
    }

    uint32 const guildId = player->GetGuildId();
    if (!guildId)
    {
        error = "You are not in a guild.";
        return false;
    }

    std::vector<uint32> toRemove;
    for (auto const& [lowguid, info] : sInstances)
    {
        if (info.guildId == guildId)
            toRemove.push_back(lowguid);
    }

    if (toRemove.empty())
    {
        error = "No decorations to remove.";
        return false;
    }

    uint32 totalRefund = 0;
    uint32 removedCount = 0;

    for (uint32 lowguid : toRemove)
    {
        auto it = sInstances.find(lowguid);
        if (it == sInstances.end())
            continue;

        InstanceInfo const& info = it->second;
        uint32 const entry = info.entry;
        uint32 const refund = info.paidCopper * sRefundPercent / 100;

        if (GameObject* object = GetLiveObject(player, lowguid))
            object->Delete();

        AddUsedBudget(guildId, -static_cast<int32>(WeightOf(entry)));
        sInstances.erase(it);
        sLive.erase(lowguid);

        totalRefund += refund;
        ++removedCount;
    }

    CharacterDatabase.Execute(
        "DELETE FROM `dc_guild_house_instance_spawns` "
        "WHERE `guild_id` = {} AND `source` = 'DECORATION'",
        guildId);

    if (totalRefund)
        player->ModifyMoney(static_cast<int32>(totalRefund));

    GuildHouseManager::LogAction(player, GH_ACTION_DELETE,
        GH_ENTITY_GAMEOBJECT, 0, 0,
        player->GetPositionX(), player->GetPositionY(),
        player->GetPositionZ(), player->GetOrientation());

    if (outRemovedCount)
        *outRemovedCount = removedCount;
    if (outTotalRefund)
        *outTotalRefund = totalRefund;
    return true;
}

// ============================================================
// Decorator NPC - gossip catalog browser (non-addon fallback UI)
// ============================================================
namespace
{
    constexpr uint32 ITEMS_PER_PAGE = 8;

    constexpr uint32 SENDER_ROOT = 1;
    constexpr uint32 SENDER_CATEGORY = 2;   // action = category index
    constexpr uint32 SENDER_ITEM_PAGE = 3;  // action = page
    constexpr uint32 SENDER_BUY = 4;        // action = catalog entry

    struct BrowseState
    {
        std::string category;
        uint32 page = 0;
    };

    std::unordered_map<ObjectGuid, BrowseState> sBrowseStates;

    std::string FormatGold(uint32 copper)
    {
        return std::to_string(copper / 10000) + "g";
    }

    class npc_guildhouse_decorator : public CreatureScript
    {
    public:
        npc_guildhouse_decorator()
            : CreatureScript("npc_guildhouse_decorator") { }

        bool OnGossipHello(Player* player, Creature* creature) override
        {
            // Players with the DC-Housing addon (completed DC handshake)
            // get the full addon UI instead of the gossip fallback.
            DCAddon::SessionCapabilityState capabilityState;
            if (DCAddon::TryGetSessionCapabilityState(player,
                capabilityState))
            {
                DCAddon::JsonValue payload;
                payload.SetObject();
                payload.Set("source", std::string("npc"));
                DCAddon::JsonMessage(DCAddon::Module::DECORATION,
                    DCAddon::Opcode::Decoration::SMSG_OPEN_UI, payload)
                    .Send(player);
                CloseGossipMenuFor(player);
                return true;
            }

            sBrowseStates.erase(player->GetGUID());
            ShowCategories(player, creature);
            return true;
        }

        bool OnGossipSelect(Player* player, Creature* creature,
            uint32 sender, uint32 action) override
        {
            ClearGossipMenuFor(player);

            switch (sender)
            {
                case SENDER_ROOT:
                    ShowCategories(player, creature);
                    return true;
                case SENDER_CATEGORY:
                {
                    auto const& categories = GetCategories();
                    if (action < categories.size())
                    {
                        BrowseState& state = sBrowseStates[player->GetGUID()];
                        state.category = categories[action];
                        state.page = 0;
                    }
                    ShowItems(player, creature);
                    return true;
                }
                case SENDER_ITEM_PAGE:
                {
                    sBrowseStates[player->GetGUID()].page = action;
                    ShowItems(player, creature);
                    return true;
                }
                case SENDER_BUY:
                {
                    std::string error;
                    if (!Place(player, action, error))
                        ChatHandler(player->GetSession()).PSendSysMessage(
                            "|cffff0000[Guild House]|r {}", error);
                    else
                        ChatHandler(player->GetSession()).SendSysMessage(
                            "|cff00ff00[Guild House]|r Decoration placed at "
                            "your position.");
                    ShowItems(player, creature);
                    return true;
                }
            }

            CloseGossipMenuFor(player);
            return true;
        }

    private:
        static void ShowCategories(Player* player, Creature* creature)
        {
            auto const& categories = GetCategories();
            uint32 const cap = GetBudgetCap(
                GuildHouseManager::GetGuildHouseLevel(player->GetGuildId()));
            AddGossipItemFor(player, GOSSIP_ICON_DOT,
                "Budget used: " + std::to_string(
                    GetUsedBudget(player->GetGuildId()))
                    + " / " + std::to_string(cap),
                SENDER_ROOT, 0);

            for (uint32 i = 0; i < categories.size(); ++i)
                AddGossipItemFor(player, GOSSIP_ICON_TRAINER,
                    categories[i] + " ("
                        + std::to_string(GetCatalogSize(categories[i])) + ")",
                    SENDER_CATEGORY, i);

            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature);
        }

        static void ShowItems(Player* player, Creature* creature)
        {
            BrowseState const& state = sBrowseStates[player->GetGUID()];
            uint32 const total = GetCatalogSize(state.category);
            uint32 const pages =
                (total + ITEMS_PER_PAGE - 1) / ITEMS_PER_PAGE;

            AddGossipItemFor(player, GOSSIP_ICON_TALK,
                "<- Back to categories", SENDER_ROOT, 0);

            for (CatalogEntry const* item : GetCatalogPage(state.category,
                state.page * ITEMS_PER_PAGE, ITEMS_PER_PAGE))
            {
                AddGossipItemFor(player, GOSSIP_ICON_VENDOR,
                    item->name + " - " + FormatGold(item->costCopper),
                    SENDER_BUY, item->entry,
                    "Place '" + item->name + "' at your position for "
                        + FormatGold(item->costCopper) + "?",
                    0, false);
            }

            if (state.page > 0)
                AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                    "<- Previous page", SENDER_ITEM_PAGE, state.page - 1);
            if (state.page + 1 < pages)
                AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                    "Next page ->", SENDER_ITEM_PAGE, state.page + 1);

            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature);
        }
    };

    class GuildHouseDecorationsWorldScript : public WorldScript
    {
    public:
        GuildHouseDecorationsWorldScript()
            : WorldScript("GuildHouseDecorationsWorldScript") { }

        void OnStartup() override
        {
            LoadCatalog();
        }
    };

    // Per-instance scale lives in our tracking table, not the core
    // `gameobject` spawn (which has no scale column), so the core spawns every
    // decoration at its template size. Re-apply the saved scale the moment the
    // object enters the world (server restart, or a player loading the guild
    // house grid), before nearby clients first see it.
    class GuildHouseDecorationScaleScript : public AllGameObjectScript
    {
    public:
        GuildHouseDecorationScaleScript()
            : AllGameObjectScript("GuildHouseDecorationScaleScript") { }

        void OnGameObjectAddWorld(GameObject* go) override
        {
            if (!go)
                return;

            uint32 const lowguid = go->GetSpawnId();
            if (!lowguid)
                return;

            auto it = sInstances.find(lowguid);
            if (it == sInstances.end())
                return;

            float const scale = it->second.scale;
            if (std::fabs(scale - 1.0f) > 0.001f
                && std::fabs(go->GetObjectScale() - scale) > 0.001f)
                go->SetObjectScale(scale);
        }
    };
}

} // namespace DCGuildHouseDecorations

void AddSC_dc_guildhouse_decorations()
{
    new DCGuildHouseDecorations::npc_guildhouse_decorator();
    new DCGuildHouseDecorations::GuildHouseDecorationsWorldScript();
    new DCGuildHouseDecorations::GuildHouseDecorationScaleScript();
}
