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
    struct InstanceInfo
    {
        uint32 guildId = 0;
        uint32 entry = 0;
        uint32 paidCopper = 0;
    };

    // World-thread only.
    std::map<uint32, CatalogEntry> sCatalog;                 // entry -> data
    std::vector<std::string> sCategories;
    std::unordered_map<uint8, uint32> sBudgetCaps;           // level -> cap
    std::unordered_map<uint32, InstanceInfo> sInstances;     // lowguid -> info
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

    // The phase a decoration must spawn in to be visible to the placing
    // player. Real players are phased into their guild house phase, so we
    // use that. A GM testing is standing in their own current phase (often
    // normal phase 1, NOT the guild phase), so spawn where they actually
    // are — otherwise the object lands in an invisible phase.
    uint32 PlacementPhase(Player* player)
    {
        if (IsDecorationGM(player))
            return player->GetPhaseMask();
        return GetGuildPhase(player->GetGuildId());
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

        if (player->GetMapId() != house->map
            || !(player->GetPhaseMask() & GetGuildPhase(guildId)))
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
    sUsedBudget.clear();

    sMaxPlacementRange = sConfigMgr->GetOption<float>(
        "DC.GuildHouse.Decoration.MaxRange", 0.0f);
    sRefundPercent = std::min(100u, sConfigMgr->GetOption<uint32>(
        "DC.GuildHouse.Decoration.RefundPercent", 50));
    sGmBypass = sConfigMgr->GetOption<bool>(
        "DC.GuildHouse.Decoration.GMBypass", true);

    if (!DC::DbSchema::WorldTableExists("dc_guildhouse_decorations")
        || !DC::DbSchema::WorldTableExists("dc_guildhouse_decoration_budgets")
        || !DC::DbSchema::CharacterTableExists("dc_guildhouse_decoration_instances"))
    {
        LOG_ERROR("scripts.dc",
            "GuildHouseDecorations: decoration tables missing - apply "
            "Custom feature SQLs (worlddb/GuildHousing 2026_06_13_* and "
            "chardb/GuildHousing 2026_06_13_*). System disabled.");
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
        "SELECT `go_lowguid`, `guild_id`, `entry`, `paid_copper` "
        "FROM `dc_guildhouse_decoration_instances`"))
    {
        do
        {
            Field* fields = result->Fetch();
            InstanceInfo info;
            uint32 lowguid = fields[0].Get<uint32>();
            info.guildId = fields[1].Get<uint32>();
            info.entry = fields[2].Get<uint32>();
            info.paidCopper = fields[3].Get<uint32>();
            sInstances[lowguid] = info;
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
    float orientation, std::string& error, uint32* outLowguid)
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

    GameObject* object = ::GOMove::SpawnGameObject(player, x, y, z,
        orientation, PlacementPhase(player), entry);
    if (!object)
    {
        error = "Failed to place the decoration.";
        return false;
    }

    player->ModifyMoney(-static_cast<int32>(item->costCopper));

    uint32 const lowguid = object->GetSpawnId();
    InstanceInfo info;
    info.guildId = guildId;
    info.entry = entry;
    info.paidCopper = item->costCopper;
    sInstances[lowguid] = info;
    AddUsedBudget(guildId, item->budgetWeight);

    CharacterDatabase.Execute(
        "INSERT INTO `dc_guildhouse_decoration_instances` "
        "(`go_lowguid`, `guild_id`, `entry`, `placed_by`, `paid_copper`) "
        "VALUES ({}, {}, {}, {}, {})",
        lowguid, guildId, entry, player->GetGUID().GetCounter(),
        item->costCopper);

    GuildHouseManager::LogAction(player, GH_ACTION_SPAWN,
        GH_ENTITY_GAMEOBJECT, entry, lowguid, x, y, z, orientation);

    if (outLowguid)
        *outLowguid = lowguid;
    return true;
}

bool Place(Player* player, uint32 entry, std::string& error,
    uint32* outLowguid)
{
    if (!player)
    {
        error = "Invalid player.";
        return false;
    }

    return PlaceAt(player, entry, player->GetPositionX(),
        player->GetPositionY(), player->GetPositionZ(),
        player->GetOrientation(), error, outLowguid);
}

bool MoveTo(Player* player, uint32 lowguid, float x, float y, float z,
    float orientation, std::string& error)
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

    GameObject* moved = ::GOMove::MoveGameObject(player, x, y, z,
        Position::NormalizeOrientation(orientation),
        PlacementPhase(player), lowguid);
    if (!moved)
    {
        error = "Could not move that decoration (is it nearby?).";
        return false;
    }

    GuildHouseManager::LogAction(player, GH_ACTION_MOVE,
        GH_ENTITY_GAMEOBJECT, info->entry, lowguid, x, y, z, orientation);
    return true;
}

bool MoveHere(Player* player, uint32 lowguid, std::string& error)
{
    if (!player)
    {
        error = "Invalid player.";
        return false;
    }

    return MoveTo(player, lowguid, player->GetPositionX(),
        player->GetPositionY(), player->GetPositionZ(),
        player->GetOrientation(), error);
}

bool Rotate(Player* player, uint32 lowguid, std::string& error)
{
    if (!player)
    {
        error = "Invalid player.";
        return false;
    }

    GameObject* object = ::GOMove::GetGameObject(player, lowguid);
    if (!object)
    {
        error = "Could not find that decoration (is it nearby?).";
        return false;
    }

    return MoveTo(player, lowguid, object->GetPositionX(),
        object->GetPositionY(), object->GetPositionZ(),
        player->GetOrientation(), error);
}

bool Nudge(Player* player, uint32 lowguid, float dx, float dy, float dz,
    float dOrientation, std::string& error)
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

    GameObject* object = ::GOMove::GetGameObject(player, lowguid);
    if (!object)
    {
        error = "Could not find that decoration (is it nearby?).";
        return false;
    }

    return MoveTo(player, lowguid,
        object->GetPositionX() + clampDelta(dx),
        object->GetPositionY() + clampDelta(dy),
        object->GetPositionZ() + clampDelta(dz),
        object->GetOrientation() + dOrientation, error);
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

    uint32 const lowguid = object->GetSpawnId();
    InstanceInfo const* info = nullptr;
    if (!ValidateOwnedDecoration(player, lowguid, info, error))
        return false;

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
        if (CatalogEntry const* item = FindCatalogEntry(info.entry))
            d.name = item->name;

        if (GameObjectData const* gd =
            sObjectMgr->GetGameObjectData(lowguid))
        {
            d.x = gd->posX;
            d.y = gd->posY;
            d.z = gd->posZ;
            d.orientation = gd->orientation;
            d.mapId = gd->mapid;
        }
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

    GameObject* object = ::GOMove::GetGameObject(player, lowguid);
    if (!object)
    {
        error = "Could not find that decoration (is it nearby?).";
        return false;
    }

    uint32 const entry = info->entry;
    uint32 const refund = info->paidCopper * sRefundPercent / 100;

    ::GOMove::DeleteGameObject(object);

    AddUsedBudget(player->GetGuildId(), -static_cast<int32>(WeightOf(entry)));
    sInstances.erase(lowguid);
    CharacterDatabase.Execute(
        "DELETE FROM `dc_guildhouse_decoration_instances` "
        "WHERE `go_lowguid` = {}",
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
}

} // namespace DCGuildHouseDecorations

void AddSC_dc_guildhouse_decorations()
{
    new DCGuildHouseDecorations::npc_guildhouse_decorator();
    new DCGuildHouseDecorations::GuildHouseDecorationsWorldScript();
}
