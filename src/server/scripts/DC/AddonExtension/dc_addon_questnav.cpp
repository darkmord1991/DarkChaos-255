/*
 * Dark Chaos - Quest Navigation Data Addon Handler (QNAV)
 * =======================================================
 *
 * Server side of the retail-style quest navigation extras driven by the
 * WotLKExtensions client DLL and the DC-QOS addon:
 *
 * 1. Kill-entry resolution (CMSG_KILL_ENTRIES): resolves the creatures a
 *    supertracked quest wants killed or looted, so the client can draw
 *    native selection circles on them. Three sources, mirroring how the
 *    quest actually plays:
 *      - RequiredNpcOrGo1-4 > 0 (direct creature kill/interaction objectives)
 *      - ItemDrop1-4 -> creature_loot_template (creatures dropping source items)
 *      - RequiredItemId1-6 -> creature_loot_template (creatures dropping the
 *        required quest items - the classic "collect X bandanas" convention)
 *    The set follows the quest's CURRENT status: once the quest is complete
 *    the rings move to its creature quest enders (creature_questinvolvedrelation),
 *    and the server pushes that swap the moment the status flips (the addon
 *    keys its cache by quest AND status, so no re-request is needed). Reward
 *    or abandon pushes an invalidation so a re-accepted repeatable quest is
 *    resolved fresh.
 *
 * 2. Live coordinate resolve (CMSG_RESOLVE_QUEST): on-demand fallback for
 *    quests missing from the generated QuestMapData.lua (new content added
 *    after the last generator run). Returns quest POI centroids, starter and
 *    ender spawn positions as raw world coordinates; the addon converts them
 *    with its MapAreaSizes bounds, exactly like MPOI service pins.
 *
 * Both requests are change-gated on the client (sent only when the
 * supertracked quest changes / a lookup misses), so traffic stays rare.
 *
 * Copyright (C) 2026 Dark Chaos Development Team
 */

#include "dc_addon_namespace.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "GameTime.h"
#include "Log.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "QuestDef.h"
#include "ScriptMgr.h"

#include <algorithm>
#include <unordered_map>
#include <vector>

namespace DCAddon
{
namespace QuestNav
{
    constexpr size_t MAX_KILL_ENTRIES = 8;
    constexpr size_t MAX_SPAWNS_PER_LIST = 8;

    static bool IsEnabled()
    {
        return sConfigMgr->GetOption<bool>("DC.AddonProtocol.QuestNav.Enable", true);
    }

    // ------------------------------------------------------------------------
    // item -> creature entries reverse index over creature_loot_template.
    // Built once on first use (world thread), immutable afterwards - the loot
    // table is static world data. Reference-loot indirection is deliberately
    // not followed: quest items sit in the creature's own loot rows.
    // ------------------------------------------------------------------------
    static std::unordered_map<uint32, std::vector<uint32>> const& GetLootSourceIndex()
    {
        static std::unordered_map<uint32, std::vector<uint32>> const index = []()
        {
            std::unordered_map<uint32, std::vector<uint32>> map;
            QueryResult result = WorldDatabase.Query("SELECT Entry, Item FROM creature_loot_template WHERE Item > 0");
            if (result)
            {
                do
                {
                    Field* fields = result->Fetch();
                    uint32 entry = fields[0].Get<uint32>();
                    uint32 item = fields[1].Get<uint32>();
                    std::vector<uint32>& sources = map[item];
                    if (std::find(sources.begin(), sources.end(), entry) == sources.end())
                        sources.push_back(entry);
                } while (result->NextRow());
            }

            LOG_INFO("dc.addon", "QuestNav (QNAV): indexed loot sources for {} items", map.size());
            return map;
        }();
        return index;
    }

    static void PushUnique(std::vector<uint32>& entries, uint32 entry)
    {
        if (!entry || entries.size() >= MAX_KILL_ENTRIES)
            return;
        if (std::find(entries.begin(), entries.end(), entry) == entries.end())
            entries.push_back(entry);
    }

    static void PushLootSources(std::vector<uint32>& entries, uint32 itemId)
    {
        if (!itemId)
            return;

        auto const& index = GetLootSourceIndex();
        auto it = index.find(itemId);
        if (it == index.end())
            return;

        for (uint32 entry : it->second)
            PushUnique(entries, entry);
    }

    // Kill/loot-source creature entries for a quest, in objective order:
    // direct kill targets first, then item-drop sources.
    static std::vector<uint32> ResolveKillEntries(Quest const* quest)
    {
        std::vector<uint32> entries;

        for (uint8 i = 0; i < QUEST_OBJECTIVES_COUNT; ++i)
            if (quest->RequiredNpcOrGo[i] > 0) // > 0 creature, < 0 gameobject
                PushUnique(entries, static_cast<uint32>(quest->RequiredNpcOrGo[i]));

        for (uint8 i = 0; i < QUEST_SOURCE_ITEM_IDS_COUNT; ++i)
            PushLootSources(entries, quest->ItemDrop[i]);

        for (uint8 i = 0; i < QUEST_ITEM_OBJECTIVES_COUNT; ++i)
            PushLootSources(entries, quest->RequiredItemId[i]);

        return entries;
    }

    // ------------------------------------------------------------------------
    // quest -> entry reverse indexes over the four relation multimaps (keyed
    // entry -> quest): creature/gameobject starters and enders. Built once on
    // first use (world thread), immutable afterwards - static world data. The
    // ring set below only uses creature enders (rings render on units only);
    // the live resolve uses all four, and used to walk each multimap per
    // request to find them.
    // ------------------------------------------------------------------------
    using QuestEntryIndex = std::unordered_map<uint32, std::vector<uint32>>;

    struct RelationIndexes
    {
        QuestEntryIndex creatureStarters;
        QuestEntryIndex goStarters;
        QuestEntryIndex creatureEnders;
        QuestEntryIndex goEnders;
    };

    static void IndexRelations(QuestRelations const* relations, QuestEntryIndex& out)
    {
        if (!relations)
            return;

        for (auto const& [entry, questId] : *relations)
        {
            std::vector<uint32>& entries = out[questId];
            if (std::find(entries.begin(), entries.end(), entry) == entries.end())
                entries.push_back(entry);
        }
    }

    static RelationIndexes const& GetRelationIndexes()
    {
        static RelationIndexes const indexes = []()
        {
            RelationIndexes built;
            IndexRelations(sObjectMgr->GetCreatureQuestRelationMap(), built.creatureStarters);
            IndexRelations(sObjectMgr->GetGOQuestRelationMap(), built.goStarters);
            IndexRelations(sObjectMgr->GetCreatureQuestInvolvedRelationMap(), built.creatureEnders);
            IndexRelations(sObjectMgr->GetGOQuestInvolvedRelationMap(), built.goEnders);

            LOG_INFO("dc.addon", "QuestNav (QNAV): indexed creature quest enders for {} quests",
                built.creatureEnders.size());
            return built;
        }();
        return indexes;
    }

    static QuestEntryIndex const& GetTurnInIndex()
    {
        return GetRelationIndexes().creatureEnders;
    }

    static std::vector<uint32> ResolveTurnInEntries(uint32 questId)
    {
        std::vector<uint32> entries;

        auto const& index = GetTurnInIndex();
        auto it = index.find(questId);
        if (it != index.end())
            for (uint32 entry : it->second)
                PushUnique(entries, entry);

        return entries;
    }

    // Ring set for the quest's CURRENT state: kill/loot sources while the
    // objectives are open, the creature quest enders once it is complete,
    // nothing otherwise (not in the log, rewarded, failed).
    static std::vector<uint32> EntriesForStatus(Quest const* quest, QuestStatus status)
    {
        if (!quest)
            return {};
        if (status == QUEST_STATUS_COMPLETE)
            return ResolveTurnInEntries(quest->GetQuestId());
        if (status == QUEST_STATUS_INCOMPLETE)
            return ResolveKillEntries(quest);
        return {};
    }

    // SMSG_KILL_ENTRIES {q, c, e:[...]}: c=1 marks the turn-in set so the
    // addon caches kill and turn-in rings under separate (quest, status) keys.
    static void SendKillEntries(Player* player, uint32 questId, QuestStatus status)
    {
        Quest const* quest = sObjectMgr->GetQuestTemplate(questId);
        bool const turnIn = quest && status == QUEST_STATUS_COMPLETE;

        JsonMessage reply(Module::QUEST_NAV, Opcode::QuestNav::SMSG_KILL_ENTRIES);
        reply.Set("q", questId);
        reply.Set("c", turnIn ? uint32(1) : uint32(0));

        JsonValue list;
        list.SetArray();
        for (uint32 entry : EntriesForStatus(quest, status))
            list.Push(JsonValue(entry));
        reply.Set("e", list);

        reply.Send(player);
    }

    // SMSG_KILL_ENTRIES {q, x:1}: the quest left the log (rewarded or
    // abandoned). The addon drops both cached sets for it.
    static void SendInvalidate(Player* player, uint32 questId)
    {
        JsonMessage reply(Module::QUEST_NAV, Opcode::QuestNav::SMSG_KILL_ENTRIES);
        reply.Set("q", questId);
        reply.Set("x", uint32(1));
        reply.Send(player);
    }

    static void HandleKillEntries(Player* player, ParsedMessage const& msg)
    {
        if (!player || !IsEnabled() || !IsJsonMessage(msg))
            return;

        JsonValue req = GetJsonData(msg);
        if (!req.IsObject() || !req.HasKey("q") || !req["q"].IsNumber())
            return;

        uint32 questId = req["q"].AsUInt32();
        SendKillEntries(player, questId, player->GetQuestStatus(questId));
    }

    // ------------------------------------------------------------------------
    // Live coordinate resolve
    // ------------------------------------------------------------------------

    struct SpawnPoint
    {
        uint32 mapId = 0;
        float x = 0.0f;
        float y = 0.0f;
        float z = 0.0f;
        char const* kind = "npc"; // "npc" | "object"
    };

    // Floor between two resolve requests from one player. The client already
    // spaces QNAV requests 2s apart, so this only ever stops a crafted flood.
    constexpr uint64 RESOLVE_COOLDOWN_MS = 1000;
    // Encoded replies kept at most; the cache is dropped whole past this.
    constexpr size_t MAX_CACHED_RESOLVES = 4096;

    // ------------------------------------------------------------------------
    // entry -> spawn ids over the creature and gameobject spawn stores. Built
    // once on first use (world thread). The resolve request used to walk all
    // ~195k creature spawns once per quest POI and again per starter/ender
    // list. Spawn ids rather than positions: a spawn deleted at runtime then
    // resolves to nothing instead of a stale point, and one added after the
    // build is simply not offered - fine for a navigation hint.
    // ------------------------------------------------------------------------
    struct SpawnIndex
    {
        std::unordered_map<uint32, std::vector<ObjectGuid::LowType>> creatures;
        std::unordered_map<uint32, std::vector<ObjectGuid::LowType>> gameObjects;
    };

    static SpawnIndex const& GetSpawnIndex()
    {
        static SpawnIndex const index = []()
        {
            SpawnIndex built;
            for (auto const& [spawnId, data] : sObjectMgr->GetAllCreatureData())
                built.creatures[data.id].push_back(spawnId);
            for (auto const& [spawnId, data] : sObjectMgr->GetAllGOData())
                built.gameObjects[data.id].push_back(spawnId);

            LOG_INFO("dc.addon", "QuestNav (QNAV): indexed spawns of {} creature and {} gameobject entries",
                built.creatures.size(), built.gameObjects.size());
            return built;
        }();
        return index;
    }

    static SpawnData const* LookupSpawn(ObjectGuid::LowType spawnId, bool creature)
    {
        if (creature)
            return sObjectMgr->GetCreatureData(spawnId);
        return sObjectMgr->GetGameObjectData(spawnId);
    }

    // Up to MAX_SPAWNS_PER_LIST spawn positions for the wanted entries: the
    // first spawn of each entry, then further spawns while room is left.
    static std::vector<SpawnPoint> FindSpawns(std::vector<uint32> const& creatureEntries,
        std::vector<uint32> const& goEntries)
    {
        std::vector<SpawnPoint> spawns;
        SpawnIndex const& index = GetSpawnIndex();

        struct Source
        {
            std::vector<ObjectGuid::LowType> const* spawnIds;
            bool creature;
        };

        std::vector<Source> sources;
        auto addSources = [&sources](std::vector<uint32> const& entries,
            std::unordered_map<uint32, std::vector<ObjectGuid::LowType>> const& byEntry, bool creature)
        {
            for (uint32 entry : entries)
                if (auto it = byEntry.find(entry); it != byEntry.end())
                    sources.push_back({ &it->second, creature });
        };
        addSources(creatureEntries, index.creatures, true);
        addSources(goEntries, index.gameObjects, false);

        // Round r takes the r-th spawn of every entry that has one.
        for (size_t round = 0; spawns.size() < MAX_SPAWNS_PER_LIST; ++round)
        {
            bool anyLeft = false;
            for (Source const& source : sources)
            {
                if (spawns.size() >= MAX_SPAWNS_PER_LIST)
                    break;
                if (round >= source.spawnIds->size())
                    continue;

                anyLeft = true;
                if (SpawnData const* data = LookupSpawn((*source.spawnIds)[round], source.creature))
                    spawns.push_back({ data->mapid, data->posX, data->posY, data->posZ,
                        source.creature ? "npc" : "object" });
            }

            if (!anyLeft)
                break;
        }

        return spawns;
    }

    // Z of the kill-target spawn on `mapId` nearest to (x, y), if any.
    static bool FindNearestKillTargetZ(std::vector<uint32> const& killEntries, uint32 mapId,
        double x, double y, float& outZ)
    {
        SpawnIndex const& index = GetSpawnIndex();
        double bestDistSq = -1.0;
        for (uint32 entry : killEntries)
        {
            auto it = index.creatures.find(entry);
            if (it == index.creatures.end())
                continue;

            for (ObjectGuid::LowType spawnId : it->second)
            {
                CreatureData const* data = sObjectMgr->GetCreatureData(spawnId);
                if (!data || data->mapid != mapId)
                    continue;

                double dx = data->posX - x;
                double dy = data->posY - y;
                double distSq = dx * dx + dy * dy;
                if (bestDistSq < 0.0 || distSq < bestDistSq)
                {
                    bestDistSq = distSq;
                    outZ = data->posZ;
                }
            }
        }

        return bestDistSq >= 0.0;
    }

    static JsonValue SpawnListJson(std::vector<SpawnPoint> const& spawns)
    {
        JsonValue list;
        list.SetArray();
        for (SpawnPoint const& spawn : spawns)
        {
            JsonValue obj;
            obj.SetObject();
            obj.Set("m", JsonValue(spawn.mapId));
            obj.Set("x", JsonValue(static_cast<double>(spawn.x)));
            obj.Set("y", JsonValue(static_cast<double>(spawn.y)));
            obj.Set("z", JsonValue(static_cast<double>(spawn.z)));
            obj.Set("k", JsonValue(spawn.kind));
            list.Push(std::move(obj));
        }
        return list;
    }

    // Quest giver / turn-in entries for a quest, from the relation indexes.
    static std::vector<uint32> RelationEntries(QuestEntryIndex const& index, uint32 questId)
    {
        std::vector<uint32> entries;
        if (auto it = index.find(questId); it != index.end())
            for (uint32 entry : it->second)
                if (entries.size() < MAX_SPAWNS_PER_LIST)
                    entries.push_back(entry);
        return entries;
    }

    // The full SMSG_QUEST_COORDS body for a quest. Depends on static world
    // data only, so it is built once per quest and served from the cache.
    static std::string BuildQuestCoords(uint32 questId, Quest const* quest)
    {
        JsonValue body;
        body.SetObject();
        body.Set("q", JsonValue(questId));

        if (!quest)
        {
            body.Set("o", JsonValue());
            body.Set("s", JsonValue());
            body.Set("r", JsonValue());
            return body.Encode();
        }

        // Objectives: quest POI centroids (raw world coordinates in 3.3.5).
        // Z comes from a kill-target spawn on the same map when one exists;
        // otherwise it is omitted and the client DLL's terrain trace fills it.
        std::vector<uint32> killEntries;
        for (uint8 i = 0; i < QUEST_OBJECTIVES_COUNT; ++i)
            if (quest->RequiredNpcOrGo[i] > 0)
                killEntries.push_back(static_cast<uint32>(quest->RequiredNpcOrGo[i]));

        JsonValue objectives;
        objectives.SetArray();
        if (QuestPOIVector const* pois = sObjectMgr->GetQuestPOIVector(questId))
        {
            for (QuestPOI const& poi : *pois)
            {
                if (poi.points.empty() || poi.ObjectiveIndex < 0)
                    continue;

                double cx = 0.0;
                double cy = 0.0;
                for (QuestPOIPoint const& point : poi.points)
                {
                    cx += point.x;
                    cy += point.y;
                }
                cx /= static_cast<double>(poi.points.size());
                cy /= static_cast<double>(poi.points.size());

                JsonValue obj;
                obj.SetObject();
                obj.Set("m", JsonValue(poi.MapId));
                obj.Set("x", JsonValue(cx));
                obj.Set("y", JsonValue(cy));
                obj.Set("i", JsonValue(poi.ObjectiveIndex));

                // Nearest kill-target spawn on the same map supplies real Z.
                float bestZ = 0.0f;
                if (FindNearestKillTargetZ(killEntries, poi.MapId, cx, cy, bestZ))
                    obj.Set("z", JsonValue(static_cast<double>(bestZ)));

                objectives.Push(std::move(obj));
            }
        }
        body.Set("o", std::move(objectives));

        // Starters and enders from the quest relations + spawn stores.
        RelationIndexes const& relations = GetRelationIndexes();
        body.Set("s", SpawnListJson(FindSpawns(RelationEntries(relations.creatureStarters, questId),
            RelationEntries(relations.goStarters, questId))));
        body.Set("r", SpawnListJson(FindSpawns(RelationEntries(relations.creatureEnders, questId),
            RelationEntries(relations.goEnders, questId))));

        return body.Encode();
    }

    // World thread only (addon handlers and the logout hook).
    static std::unordered_map<uint32, std::string> sResolveCache;
    static std::unordered_map<ObjectGuid::LowType, uint64> sLastResolveMs;

    static void HandleResolveQuest(Player* player, ParsedMessage const& msg)
    {
        if (!player || !IsEnabled() || !IsJsonMessage(msg))
            return;

        JsonValue req = GetJsonData(msg);
        if (!req.IsObject() || !req.HasKey("q") || !req["q"].IsNumber())
            return;

        uint64 const nowMs = GameTime::GetGameTimeMS().count();
        uint64& lastMs = sLastResolveMs[player->GetGUID().GetCounter()];
        if (lastMs && nowMs - lastMs < RESOLVE_COOLDOWN_MS)
            return;
        lastMs = nowMs;

        // The client only resolves quests it is navigating to, i.e. quests in
        // its log. Anything else gets the same empty answer as an unknown id,
        // which keeps a client from walking the whole quest table through here.
        uint32 questId = req["q"].AsUInt32();
        Quest const* quest = player->FindQuestSlot(questId) < MAX_QUEST_LOG_SIZE
            ? sObjectMgr->GetQuestTemplate(questId) : nullptr;

        JsonMessage reply(Module::QUEST_NAV, Opcode::QuestNav::SMSG_QUEST_COORDS);
        if (!quest)
        {
            reply.SetPreEncodedJson(BuildQuestCoords(questId, nullptr));
            reply.Send(player);
            return;
        }

        auto cached = sResolveCache.find(questId);
        if (cached == sResolveCache.end())
        {
            if (sResolveCache.size() >= MAX_CACHED_RESOLVES)
                sResolveCache.clear();
            cached = sResolveCache.emplace(questId, BuildQuestCoords(questId, quest)).first;
        }

        reply.SetPreEncodedJson(cached->second);
        reply.Send(player);
    }

    void RegisterQuestNavHandlers()
    {
        // QNAV is intentionally not part of the central module table in
        // dc_addon_protocol.cpp, so it enables itself with the router here
        // (same self-contained pattern as DC-Graveyard/DC-QuestFlow).
        bool const enabled = IsEnabled();

        MessageRouter::Instance().SetModuleEnabled(Module::QUEST_NAV, enabled);
        if (!enabled)
            return;

        DC_REGISTER_HANDLER(Module::QUEST_NAV, Opcode::QuestNav::CMSG_KILL_ENTRIES, HandleKillEntries);
        DC_REGISTER_HANDLER(Module::QUEST_NAV, Opcode::QuestNav::CMSG_RESOLVE_QUEST, HandleResolveQuest);
    }

    static void ForgetPlayer(ObjectGuid::LowType guidLow)
    {
        sLastResolveMs.erase(guidLow);
    }
} // namespace QuestNav
} // namespace DCAddon

// Status pushes: the addon keys its ring cache by (quest, status), so a
// status change must reach it without waiting for a rate-capped re-request.
class DCQuestNavPlayerScript : public PlayerScript
{
public:
    DCQuestNavPlayerScript() : PlayerScript("DCQuestNavPlayerScript",
        { PLAYERHOOK_ON_BEFORE_QUEST_COMPLETE, PLAYERHOOK_ON_PLAYER_COMPLETE_QUEST, PLAYERHOOK_ON_QUEST_ABANDON,
          PLAYERHOOK_ON_LOGOUT }) { }

    void OnPlayerLogout(Player* player) override
    {
        if (player)
            DCAddon::QuestNav::ForgetPlayer(player->GetGUID().GetCounter());
    }

    // Fires inside Player::CompleteQuest BEFORE the status flips to COMPLETE,
    // so the turn-in set is resolved explicitly rather than via GetQuestStatus.
    bool OnPlayerBeforeQuestComplete(Player* player, uint32 questId) override
    {
        if (player && DCAddon::QuestNav::IsEnabled())
            DCAddon::QuestNav::SendKillEntries(player, questId, QUEST_STATUS_COMPLETE);
        return true;
    }

    // Reward taken: the quest leaves the log.
    void OnPlayerCompleteQuest(Player* player, Quest const* quest) override
    {
        if (player && quest && DCAddon::QuestNav::IsEnabled())
            DCAddon::QuestNav::SendInvalidate(player, quest->GetQuestId());
    }

    void OnPlayerQuestAbandon(Player* player, uint32 questId) override
    {
        if (player && DCAddon::QuestNav::IsEnabled())
            DCAddon::QuestNav::SendInvalidate(player, questId);
    }
};

void AddSC_dc_addon_questnav()
{
    DCAddon::QuestNav::RegisterQuestNavHandlers();
    new DCQuestNavPlayerScript();
}
