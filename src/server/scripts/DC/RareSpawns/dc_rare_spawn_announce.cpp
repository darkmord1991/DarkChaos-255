/*
 * This file is part of the AzerothCore Project. See AUTHORS file for
 * Copyright information.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Affero General Public License as published by the
 * Free Software Foundation; either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

// Rare respawn announcer for the DC custom continents (map 750 Cata Kalimdor,
// map 37 Azshara Crater).
//
// The core has no OnCreatureRespawn hook, and OnCreatureAddWorld alone is not a
// respawn signal: it also fires on initial map load and every time a grid is
// reloaded because a player walked back into the area. Announcing on that hook
// by itself would spam a rare that nobody killed.
//
// So the announce is armed by a kill and fired by the following add-to-world:
//
//   OnUnitDeath        -> remember the creature_template entry as "pending",
//                         and push a killed status so the map pin goes stale
//   OnCreatureAddWorld -> if pending, chat announce + live status, and disarm
//
// The pending set is keyed on the template ENTRY, not the spawn id, because the
// multi-point rares are pooled (pool ids 133000101+, see
// Custom/Custom feature SQLs/worlddb/RareSpawns/): the rare that comes back is a
// different spawn point from the one that died, so a spawn-id key would never
// match.
//
// Both hooks run on map-update threads, which may be several. The pending set is
// mutex-guarded, and the broadcast itself is queued and drained on the world
// thread in OnUpdate rather than iterating the session list from a map thread.
//
// Alongside the event pushes there is an in-memory registry of every tracked
// rare and whether it is currently up. Kill/respawn pushes alone tell a client
// nothing about a rare that has been standing there since before it logged in,
// so DCAddon::RareSpawns::SendSnapshot() dumps that registry on the world-content
// request (see dc_addon_world.cpp).

#include "Chat.h"
#include "Config.h"
#include "Creature.h"
#include "DBCStores.h"
#include "DBCStructure.h"
#include "DatabaseEnv.h"
#include "GameTime.h"
#include "Log.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SharedDefines.h"
#include "StringConvert.h"
#include "StringFormat.h"
#include "Tokenize.h"
#include "World.h"
#include "WorldSessionMgr.h"
#include "MapMgr.h"
#include "DC/CrossSystem/CrossSystemMapCoords.h"
#include "../AddonExtension/dc_addon_namespace.h"
#include "dc_rare_spawns.h"

#include <algorithm>
#include <cctype>
#include <mutex>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>
#include "dc_update_profiler.h"

namespace
{
    enum RareAnnounceScope : uint32
    {
        RARE_ANNOUNCE_SCOPE_ZONE  = 0,
        RARE_ANNOUNCE_SCOPE_MAP   = 1,
        RARE_ANNOUNCE_SCOPE_WORLD = 2
    };

    struct RareAnnounceConfig
    {
        bool enabled{true};
        bool includeRareElite{true};
        bool addonPush{true};
        uint32 minRespawnSecs{3600};
        uint32 cooldownSecs{600};
        uint32 scope{RARE_ANNOUNCE_SCOPE_ZONE};
        std::unordered_set<uint32> maps;
    };

    RareAnnounceConfig sConfig;

    // Live registry: one record per tracked rare, keyed by creature_template
    // entry (not spawn id, for the same pooling reason as sPendingRespawn).
    struct RareState
    {
        uint32 entry{0};
        std::string name;
        uint32 mapId{0};
        uint32 zoneId{0};
        std::string zoneName;
        float nx{0.0f};
        float ny{0.0f};
        bool hasNormalized{false};
        bool alive{true};
        time_t respawnAt{0};
    };

    // Queued broadcast: the rare's state copied out of the Creature while it is
    // still guaranteed alive on the map thread, plus how to present it.
    struct RareAnnouncement
    {
        RareState state;
        std::string action;
        bool chat{false};
    };

    std::mutex sStateMutex;
    std::unordered_set<uint32> sPendingRespawn;
    std::unordered_map<uint32, time_t> sLastAnnounce;
    std::unordered_map<uint32, RareState> sRares;

    std::mutex sQueueMutex;
    std::vector<RareAnnouncement> sQueue;

    std::vector<uint32> ParseIdList(std::string csv)
    {
        csv.erase(std::remove_if(csv.begin(), csv.end(),
            [](unsigned char c) { return std::isspace(c); }), csv.end());

        std::vector<uint32> ids;
        for (std::string_view token : Acore::Tokenize(csv, ',', false))
            if (Optional<uint32> id = Acore::StringTo<uint32>(token))
                ids.push_back(*id);

        return ids;
    }

    void LoadConfig()
    {
        sConfig.enabled = sConfigMgr->GetOption<bool>("RareSpawn.Announce.Enable", true);
        sConfig.includeRareElite = sConfigMgr->GetOption<bool>("RareSpawn.Announce.IncludeRareElite", true);
        sConfig.addonPush = sConfigMgr->GetOption<bool>("RareSpawn.Announce.AddonPush", true);
        sConfig.minRespawnSecs = sConfigMgr->GetOption<uint32>("RareSpawn.Announce.MinRespawnSecs", 3600);
        sConfig.cooldownSecs = sConfigMgr->GetOption<uint32>("RareSpawn.Announce.Cooldown", 600);
        sConfig.scope = sConfigMgr->GetOption<uint32>("RareSpawn.Announce.Scope", RARE_ANNOUNCE_SCOPE_ZONE);

        if (sConfig.scope > RARE_ANNOUNCE_SCOPE_WORLD)
        {
            LOG_WARN("scripts.dc", "RareSpawn.Announce.Scope = {} is out of range, falling back to zone scope",
                sConfig.scope);
            sConfig.scope = RARE_ANNOUNCE_SCOPE_ZONE;
        }

        sConfig.maps.clear();
        for (uint32 mapId : ParseIdList(sConfigMgr->GetOption<std::string>("RareSpawn.Announce.Maps", "750,37")))
            sConfig.maps.insert(mapId);

        LOG_INFO("scripts.dc", "RareSpawnAnnounce: {}, {} map(s), min respawn {}s, scope {}",
            sConfig.enabled ? "enabled" : "disabled", sConfig.maps.size(), sConfig.minRespawnSecs, sConfig.scope);
    }

    bool IsTrackedRank(uint32 rank)
    {
        if (rank == CREATURE_ELITE_RARE)
            return true;

        return rank == CREATURE_ELITE_RAREELITE && sConfig.includeRareElite;
    }

    // A creature qualifies only if it is a DB spawn (GetSpawnId() != 0) on a
    // configured map, of a tracked rank, whose respawn delay clears the
    // announce threshold. The delay gate is what keeps five-minute filler
    // spawns off the wire even if someone re-imports them.
    bool IsTrackedRare(Creature const* creature)
    {
        if (!creature || !creature->GetSpawnId())
            return false;

        if (sConfig.maps.find(creature->GetMapId()) == sConfig.maps.end())
            return false;

        CreatureTemplate const* tmpl = creature->GetCreatureTemplate();
        if (!tmpl || !IsTrackedRank(tmpl->rank))
            return false;

        return creature->GetRespawnDelay() >= sConfig.minRespawnSecs;
    }

    std::string GetZoneName(uint32 zoneId)
    {
        if (AreaTableEntry const* area = sAreaTableStore.LookupEntry(zoneId))
            if (area->area_name[0])
                return area->area_name[0];

        return "an unknown region";
    }

    // Map pins need zone-normalized 0..1 coordinates, not world coordinates.
    // All six map-750 zones have WorldMapArea rows keyed by area id, so
    // Map2ZoneCoordinates resolves them; Azshara Crater (area 268) is covered by
    // the CustomBounds fallback inside the helper. When neither works the fields
    // are omitted and the client keeps whatever position it had, the same
    // contract the world-boss push uses.
    void FillNormalized(RareState& state, float x, float y)
    {
        state.hasNormalized = DarkChaos::CrossSystem::MapCoords::TryComputeNormalized(
            state.zoneId, x, y, state.nx, state.ny);
    }

    void Enqueue(Creature const* creature, char const* action, bool alive, bool chat)
    {
        RareState state;
        state.entry = creature->GetEntry();
        state.name = creature->GetName();
        state.mapId = creature->GetMapId();
        state.zoneId = creature->GetZoneId();
        state.zoneName = GetZoneName(state.zoneId);
        state.alive = alive;
        state.respawnAt = alive ? 0 : GameTime::GetGameTime().count() + creature->GetRespawnDelay();
        FillNormalized(state, creature->GetPositionX(), creature->GetPositionY());

        {
            std::lock_guard<std::mutex> guard(sStateMutex);

            // Never trade a known-good pin position for an unresolvable one.
            auto stored = sRares.find(state.entry);
            if (!state.hasNormalized && stored != sRares.end() && stored->second.hasNormalized)
            {
                state.nx = stored->second.nx;
                state.ny = stored->second.ny;
                state.hasNormalized = true;
            }

            sRares[state.entry] = state;
        }

        RareAnnouncement announcement;
        announcement.state = std::move(state);
        announcement.action = action;
        announcement.chat = chat;

        std::lock_guard<std::mutex> guard(sQueueMutex);
        sQueue.push_back(std::move(announcement));
    }

    // One JSON shape for the kill push, the respawn push and the login snapshot,
    // so the three can never disagree about a rare.
    //
    // "mapId" carries the ZONE id, not the server map id: DC-Mapupgrades matches
    // server-provided entities by resolving the map the player has open to a zone
    // id (MAP_TO_ZONE / CUSTOM_ZONE_MAPPING) and comparing against this field
    // (Pins.lua EntityMatchesMap). serverMapId rides along for anything that
    // wants the real map.
    DCAddon::JsonValue BuildRecordJson(RareState const& state, std::string const& action)
    {
        DCAddon::JsonValue record;
        record.SetObject();
        record.Set("entry", DCAddon::JsonValue((int32)state.entry));
        record.Set("name", DCAddon::JsonValue(state.name));
        record.Set("mapId", DCAddon::JsonValue((int32)state.zoneId));
        record.Set("serverMapId", DCAddon::JsonValue((int32)state.mapId));
        record.Set("zoneId", DCAddon::JsonValue((int32)state.zoneId));
        record.Set("zone", DCAddon::JsonValue(state.zoneName));
        record.Set("active", DCAddon::JsonValue(state.alive));
        record.Set("status", DCAddon::JsonValue(state.alive ? "active" : "dead"));
        record.Set("action", DCAddon::JsonValue(action));

        if (state.hasNormalized)
        {
            record.Set("nx", DCAddon::JsonValue(state.nx));
            record.Set("ny", DCAddon::JsonValue(state.ny));
        }

        if (!state.alive && state.respawnAt)
        {
            time_t const now = GameTime::GetGameTime().count();
            record.Set("spawnIn", DCAddon::JsonValue(
                state.respawnAt > now ? static_cast<int32>(state.respawnAt - now) : 0));
        }

        return record;
    }

    bool IsInScope(Player const* player, RareState const& state)
    {
        switch (sConfig.scope)
        {
            case RARE_ANNOUNCE_SCOPE_ZONE:
                return player->GetMapId() == state.mapId && player->GetZoneId() == state.zoneId;
            case RARE_ANNOUNCE_SCOPE_MAP:
                return player->GetMapId() == state.mapId;
            default:
                return true;
        }
    }

    void Broadcast(RareAnnouncement const& announcement)
    {
        RareState const& state = announcement.state;

        std::string const text = Acore::StringFormat("|cFFA335EE[Rare]|r {} has respawned in {}!",
            state.name, state.zoneName);

        // WRLD is the module that already owns world bosses, hotspots and rares.
        DCAddon::JsonValue raresJson;
        raresJson.SetArray();
        raresJson.Push(BuildRecordJson(state, announcement.action));

        DCAddon::JsonMessage message(DCAddon::Module::WORLD, DCAddon::Opcode::World::SMSG_UPDATE);
        message.Set("rares", raresJson);

        uint32 recipients = 0;
        for (auto const& session : sWorldSessionMgr->GetAllSessions())
        {
            Player* player = session.second ? session.second->GetPlayer() : nullptr;
            if (!player || !player->IsInWorld())
                continue;

            // The chat line is scope-limited, but the pin update is not: a player
            // with the Ashenvale map open while standing in Felwood still wants
            // the pin to be truthful. Pin state follows the map, chat follows the
            // configured scope.
            bool const inChatScope = announcement.chat && IsInScope(player, state);
            bool const inPinScope = sConfig.addonPush && player->GetMapId() == state.mapId;

            if (!inChatScope && !inPinScope)
                continue;

            if (inChatScope)
                ChatHandler(player->GetSession()).SendSysMessage(text);

            if (inPinScope)
                message.Send(player);

            ++recipients;
        }

        LOG_DEBUG("scripts.dc", "RareSpawnAnnounce: {} (entry {}) {} on map {} zone {}, sent to {} player(s){}",
            state.name, state.entry, announcement.action, state.mapId,
            state.zoneId, recipients, state.hasNormalized ? "" : " (no map position)");
    }

    std::string BuildMapList()
    {
        std::string mapList;
        for (uint32 mapId : sConfig.maps)
        {
            if (!mapList.empty())
                mapList += ',';

            mapList += std::to_string(mapId);
        }

        return mapList;
    }

    // Enumerate every tracked rare once at startup so a client that logs in can
    // be told what is currently up, not just what changes from now on. Assumed
    // alive here; SeedPendingFromRespawnTable() then marks the ones that are down.
    //
    // A pooled rare has several spawn points and only one is live, and which one
    // is not knowable without asking the map (whose grids may not be loaded). The
    // first spawn point wins as the initial pin position; the first respawn event
    // corrects it to the real one.
    void BuildRegistry()
    {
        if (sConfig.maps.empty())
            return;

        QueryResult result = WorldDatabase.Query(
            "SELECT c.id, c.map, c.zoneId, c.position_x, c.position_y, c.position_z, c.spawntimesecs, "
            "ct.rank, ct.name FROM creature c JOIN creature_template ct ON ct.entry = c.id "
            "WHERE c.map IN ({})", BuildMapList());

        if (!result)
            return;

        uint32 tracked = 0;
        uint32 unplaceable = 0;
        do
        {
            Field* fields = result->Fetch();
            // Widths match the column types (creature.map / creature.zoneId are
            // smallint, creature_template.rank is tinyint) so strict-type builds
            // stay quiet.
            uint32 const entry = fields[0].Get<uint32>();
            uint32 const mapId = fields[1].Get<uint16>();
            uint32 zoneId = fields[2].Get<uint16>();
            float const x = fields[3].Get<float>();
            float const y = fields[4].Get<float>();
            float const z = fields[5].Get<float>();
            uint32 const spawnTime = fields[6].Get<uint32>();
            uint32 const rank = fields[7].Get<uint8>();

            if (!IsTrackedRank(rank) || spawnTime < sConfig.minRespawnSecs)
                continue;

            std::lock_guard<std::mutex> guard(sStateMutex);
            if (sRares.find(entry) != sRares.end())
                continue;

            // creature.zoneId is a cached helper column and is 0 on some imports
            // (all of map 37). Resolve it from terrain in that case, but never on
            // a map missing from Map.dbc - CreateBaseMap ASSERTs on those.
            if (!zoneId && sMapStore.LookupEntry(mapId))
                zoneId = sMapMgr->GetZoneId(PHASEMASK_NORMAL, mapId, x, y, z);

            RareState state;
            state.entry = entry;
            state.name = fields[8].Get<std::string>();
            state.mapId = mapId;
            state.zoneId = zoneId;
            state.zoneName = GetZoneName(zoneId);
            state.alive = true;
            state.respawnAt = 0;
            FillNormalized(state, x, y);

            if (!state.hasNormalized)
                ++unplaceable;

            sRares[entry] = std::move(state);
            ++tracked;
        } while (result->NextRow());

        LOG_INFO("scripts.dc", "RareSpawnAnnounce: tracking {} rare(s) across {} map(s), {} without a map position",
            tracked, sConfig.maps.size(), unplaceable);
    }

    // A rare killed before a restart has a row in characters.creature_respawn and
    // will come back after the server is up. Without re-arming from that table the
    // announcement is silently lost for every rare that was down at shutdown, and
    // the login snapshot would claim it is up.
    void SeedPendingFromRespawnTable()
    {
        if (sConfig.maps.empty())
            return;

        QueryResult result = CharacterDatabase.Query(
            "SELECT guid, respawnTime FROM creature_respawn WHERE instanceId = 0 AND mapId IN ({})",
            BuildMapList());

        if (!result)
            return;

        uint32 seeded = 0;
        do
        {
            Field* fields = result->Fetch();
            ObjectGuid::LowType spawnId = fields[0].Get<uint32>();
            time_t const respawnAt = static_cast<time_t>(fields[1].Get<uint32>());

            CreatureData const* data = sObjectMgr->GetCreatureData(spawnId);
            if (!data || data->spawntimesecs < sConfig.minRespawnSecs)
                continue;

            CreatureTemplate const* tmpl = sObjectMgr->GetCreatureTemplate(data->id);
            if (!tmpl || !IsTrackedRank(tmpl->rank))
                continue;

            std::lock_guard<std::mutex> guard(sStateMutex);
            if (sPendingRespawn.insert(data->id).second)
                ++seeded;

            auto stored = sRares.find(data->id);
            if (stored != sRares.end())
            {
                stored->second.alive = false;
                stored->second.respawnAt = respawnAt;
            }
        } while (result->NextRow());

        LOG_INFO("scripts.dc", "RareSpawnAnnounce: re-armed {} rare(s) that were dead at shutdown", seeded);
    }

    class RareSpawnAnnounceUnitScript : public UnitScript
    {
    public:
        RareSpawnAnnounceUnitScript() : UnitScript("RareSpawnAnnounceUnitScript", true, { UNITHOOK_ON_UNIT_DEATH }) { }

        void OnUnitDeath(Unit* unit, Unit* /*killer*/) override
        {
            if (!sConfig.enabled || !unit)
                return;

            Creature const* creature = unit->ToCreature();
            if (!IsTrackedRare(creature))
                return;

            {
                std::lock_guard<std::mutex> guard(sStateMutex);
                sPendingRespawn.insert(creature->GetEntry());
            }

            // Status-only push, no chat line: the pin has to stop claiming the
            // rare is up the moment it dies, otherwise it lies for hours.
            Enqueue(creature, "killed", false, false);
        }
    };

    class RareSpawnAnnounceCreatureScript : public AllCreatureScript
    {
    public:
        RareSpawnAnnounceCreatureScript() : AllCreatureScript("RareSpawnAnnounceCreatureScript") { }

        void OnCreatureAddWorld(Creature* creature) override
        {
            if (!sConfig.enabled)
                return;

            if (!IsTrackedRare(creature))
                return;

            uint32 const entry = creature->GetEntry();
            time_t const now = GameTime::GetGameTime().count();

            {
                std::lock_guard<std::mutex> guard(sStateMutex);

                // Not armed by a kill: initial spawn or a grid reload, stay quiet.
                auto pending = sPendingRespawn.find(entry);
                if (pending == sPendingRespawn.end())
                    return;

                sPendingRespawn.erase(pending);

                auto last = sLastAnnounce.find(entry);
                if (last != sLastAnnounce.end() && now - last->second < static_cast<time_t>(sConfig.cooldownSecs))
                    return;

                sLastAnnounce[entry] = now;
            }

            Enqueue(creature, "respawn", true, true);
        }
    };

    class RareSpawnAnnounceWorldScript : public WorldScript
    {
    public:
        RareSpawnAnnounceWorldScript() : WorldScript("RareSpawnAnnounceWorldScript") { }

        void OnAfterConfigLoad(bool /*reload*/) override
        {
            LoadConfig();
        }

        void OnStartup() override
        {
            LoadConfig();
            if (!sConfig.enabled)
                return;

            BuildRegistry();
            SeedPendingFromRespawnTable();
        }

        void OnUpdate(uint32 /*diff*/) override
        {
            DarkChaos::ScopedUpdateProfiler _prof("RareSpawnAnnounce");
            std::vector<RareAnnouncement> batch;
            {
                std::lock_guard<std::mutex> guard(sQueueMutex);
                if (sQueue.empty())
                    return;

                batch.swap(sQueue);
            }

            for (auto const& announcement : batch)
                Broadcast(announcement);
        }
    };
}

void DCAddon::RareSpawns::SendSnapshot(Player* player)
{
    if (!sConfig.enabled || !sConfig.addonPush || !player || !player->GetSession())
        return;

    uint32 const mapId = player->GetMapId();
    if (sConfig.maps.find(mapId) == sConfig.maps.end())
        return;

    DCAddon::JsonValue raresJson;
    raresJson.SetArray();

    uint32 count = 0;
    {
        std::lock_guard<std::mutex> guard(sStateMutex);
        for (auto const& itr : sRares)
        {
            if (itr.second.mapId != mapId)
                continue;

            raresJson.Push(BuildRecordJson(itr.second, "snapshot"));
            ++count;
        }
    }

    if (!count)
        return;

    DCAddon::JsonMessage message(DCAddon::Module::WORLD, DCAddon::Opcode::World::SMSG_UPDATE);
    message.Set("rares", raresJson);
    message.Send(player);

    LOG_DEBUG("scripts.dc", "RareSpawnAnnounce: sent {} rare(s) on map {} to {}",
        count, mapId, player->GetName());
}

void AddSC_dc_rare_spawn_announce()
{
    new RareSpawnAnnounceUnitScript();
    new RareSpawnAnnounceCreatureScript();
    new RareSpawnAnnounceWorldScript();
}
