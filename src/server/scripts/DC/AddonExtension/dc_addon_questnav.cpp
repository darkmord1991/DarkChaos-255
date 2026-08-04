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

    static void HandleKillEntries(Player* player, ParsedMessage const& msg)
    {
        if (!player || !IsEnabled() || !IsJsonMessage(msg))
            return;

        JsonValue req = GetJsonData(msg);
        if (!req.IsObject() || !req.HasKey("q") || !req["q"].IsNumber())
            return;

        uint32 questId = req["q"].AsUInt32();
        Quest const* quest = sObjectMgr->GetQuestTemplate(questId);

        JsonMessage reply(Module::QUEST_NAV, Opcode::QuestNav::SMSG_KILL_ENTRIES);
        reply.Set("q", questId);

        JsonValue list;
        list.SetArray();
        if (quest)
            for (uint32 entry : ResolveKillEntries(quest))
                list.Push(JsonValue(entry));
        reply.Set("e", list);

        reply.Send(player);
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

    // First spawn position of each wanted creature/gameobject entry. Single
    // pass over the spawn stores (same access pattern as MPOI's BuildPOIList,
    // but only on the rare resolve request).
    static std::vector<SpawnPoint> FindSpawns(std::vector<uint32> const& creatureEntries,
        std::vector<uint32> const& goEntries)
    {
        std::vector<SpawnPoint> spawns;

        auto wanted = [](std::vector<uint32> const& list, uint32 entry)
        {
            return std::find(list.begin(), list.end(), entry) != list.end();
        };

        if (!creatureEntries.empty())
        {
            for (auto const& [spawnId, data] : sObjectMgr->GetAllCreatureData())
            {
                if (spawns.size() >= MAX_SPAWNS_PER_LIST)
                    break;
                if (!wanted(creatureEntries, data.id))
                    continue;

                spawns.push_back({ data.mapid, data.posX, data.posY, data.posZ, "npc" });
            }
        }

        if (!goEntries.empty())
        {
            for (auto const& [spawnId, data] : sObjectMgr->GetAllGOData())
            {
                if (spawns.size() >= MAX_SPAWNS_PER_LIST)
                    break;
                if (!wanted(goEntries, data.id))
                    continue;

                spawns.push_back({ data.mapid, data.posX, data.posY, data.posZ, "object" });
            }
        }

        return spawns;
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

    // Quest giver / turn-in entries for a quest, scanned from the relation
    // multimaps (they are keyed entry -> quest, so a reverse lookup walks
    // them; fine for a rare, change-gated request).
    static void CollectRelationEntries(QuestRelations const* relations, uint32 questId,
        std::vector<uint32>& outEntries)
    {
        for (auto const& [entry, relQuestId] : *relations)
            if (relQuestId == questId && outEntries.size() < MAX_SPAWNS_PER_LIST)
                outEntries.push_back(entry);
    }

    static void HandleResolveQuest(Player* player, ParsedMessage const& msg)
    {
        if (!player || !IsEnabled() || !IsJsonMessage(msg))
            return;

        JsonValue req = GetJsonData(msg);
        if (!req.IsObject() || !req.HasKey("q") || !req["q"].IsNumber())
            return;

        uint32 questId = req["q"].AsUInt32();
        Quest const* quest = sObjectMgr->GetQuestTemplate(questId);

        JsonMessage reply(Module::QUEST_NAV, Opcode::QuestNav::SMSG_QUEST_COORDS);
        reply.Set("q", questId);

        if (!quest)
        {
            reply.Set("o", JsonValue()).Set("s", JsonValue()).Set("r", JsonValue());
            reply.Send(player);
            return;
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
                double bestDistSq = -1.0;
                if (!killEntries.empty())
                {
                    for (auto const& [spawnId, data] : sObjectMgr->GetAllCreatureData())
                    {
                        if (data.mapid != poi.MapId)
                            continue;
                        if (std::find(killEntries.begin(), killEntries.end(), data.id) == killEntries.end())
                            continue;

                        double dx = data.posX - cx;
                        double dy = data.posY - cy;
                        double distSq = dx * dx + dy * dy;
                        if (bestDistSq < 0.0 || distSq < bestDistSq)
                        {
                            bestDistSq = distSq;
                            bestZ = data.posZ;
                        }
                    }
                }
                if (bestDistSq >= 0.0)
                    obj.Set("z", JsonValue(static_cast<double>(bestZ)));

                objectives.Push(std::move(obj));
            }
        }
        reply.Set("o", objectives);

        // Starters and enders from the quest relations + spawn stores.
        std::vector<uint32> starterCreatures;
        std::vector<uint32> starterGOs;
        CollectRelationEntries(sObjectMgr->GetCreatureQuestRelationMap(), questId, starterCreatures);
        CollectRelationEntries(sObjectMgr->GetGOQuestRelationMap(), questId, starterGOs);
        reply.Set("s", SpawnListJson(FindSpawns(starterCreatures, starterGOs)));

        std::vector<uint32> enderCreatures;
        std::vector<uint32> enderGOs;
        CollectRelationEntries(sObjectMgr->GetCreatureQuestInvolvedRelationMap(), questId, enderCreatures);
        CollectRelationEntries(sObjectMgr->GetGOQuestInvolvedRelationMap(), questId, enderGOs);
        reply.Set("r", SpawnListJson(FindSpawns(enderCreatures, enderGOs)));

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
} // namespace QuestNav
} // namespace DCAddon

void AddSC_dc_addon_questnav()
{
    DCAddon::QuestNav::RegisterQuestNavHandlers();
}
