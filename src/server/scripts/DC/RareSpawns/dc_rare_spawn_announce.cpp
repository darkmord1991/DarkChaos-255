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
#include "DC/CrossSystem/CrossSystemMapCoords.h"
#include "../AddonExtension/dc_addon_namespace.h"

#include <algorithm>
#include <cctype>
#include <mutex>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

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

    // Queued broadcast: everything the world thread needs, copied out of the
    // Creature while it is still guaranteed alive on the map thread.
    struct RareAnnouncement
    {
        uint32 entry{0};
        uint32 spawnId{0};
        std::string name;
        uint32 serverMapId{0};
        uint32 zoneId{0};
        uint32 areaId{0};
        std::string zoneName;
        float x{0.0f};
        float y{0.0f};
        float z{0.0f};
        float nx{0.0f};
        float ny{0.0f};
        bool hasNormalized{false};
        bool active{false};
        uint32 respawnIn{0};
        std::string action;
        bool chat{false};
    };

    std::mutex sStateMutex;
    std::unordered_set<uint32> sPendingRespawn;
    std::unordered_map<uint32, time_t> sLastAnnounce;

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

    void Enqueue(Creature const* creature, char const* action, bool active, bool chat)
    {
        RareAnnouncement announcement;
        announcement.entry = creature->GetEntry();
        announcement.spawnId = creature->GetSpawnId();
        announcement.name = creature->GetName();
        announcement.serverMapId = creature->GetMapId();
        announcement.zoneId = creature->GetZoneId();
        announcement.areaId = creature->GetAreaId();
        announcement.zoneName = GetZoneName(announcement.zoneId);
        announcement.x = creature->GetPositionX();
        announcement.y = creature->GetPositionY();
        announcement.z = creature->GetPositionZ();
        announcement.active = active;
        announcement.respawnIn = active ? 0 : creature->GetRespawnDelay();
        announcement.action = action;
        announcement.chat = chat;

        // Map pins need zone-normalized 0..1 coordinates, not world coordinates.
        // All six map-750 zones have WorldMapArea rows keyed by area id, so
        // Map2ZoneCoordinates resolves them; Azshara Crater (area 268) is covered
        // by the CustomBounds fallback inside the helper. If neither works the
        // fields are omitted and the client keeps whatever position it had, the
        // same contract the world-boss push uses.
        announcement.hasNormalized = DarkChaos::CrossSystem::MapCoords::TryComputeNormalized(
            announcement.zoneId, announcement.x, announcement.y, announcement.nx, announcement.ny);

        std::lock_guard<std::mutex> guard(sQueueMutex);
        sQueue.push_back(std::move(announcement));
    }

    bool IsInScope(Player const* player, RareAnnouncement const& announcement)
    {
        switch (sConfig.scope)
        {
            case RARE_ANNOUNCE_SCOPE_ZONE:
                return player->GetMapId() == announcement.serverMapId && player->GetZoneId() == announcement.zoneId;
            case RARE_ANNOUNCE_SCOPE_MAP:
                return player->GetMapId() == announcement.serverMapId;
            default:
                return true;
        }
    }

    void Broadcast(RareAnnouncement const& announcement)
    {
        std::string const text = Acore::StringFormat("|cFFA335EE[Rare]|r {} has respawned in {}!",
            announcement.name, announcement.zoneName);

        // WRLD is the module that already owns world bosses, hotspots and rares.
        //
        // "mapId" carries the ZONE id, not the server map id: DC-Mapupgrades
        // matches server-provided entities by looking up MAP_TO_ZONE /
        // CUSTOM_ZONE_MAPPING for the map the player has open and comparing the
        // result against this field (Pins.lua EntityMatchesMap). serverMapId is
        // sent alongside for anything that wants the real map.
        DCAddon::JsonValue record;
        record.SetObject();
        record.Set("entry", DCAddon::JsonValue((int32)announcement.entry));
        record.Set("spawnId", DCAddon::JsonValue((int32)announcement.spawnId));
        record.Set("name", DCAddon::JsonValue(announcement.name));
        record.Set("mapId", DCAddon::JsonValue((int32)announcement.zoneId));
        record.Set("serverMapId", DCAddon::JsonValue((int32)announcement.serverMapId));
        record.Set("zoneId", DCAddon::JsonValue((int32)announcement.zoneId));
        record.Set("areaId", DCAddon::JsonValue((int32)announcement.areaId));
        record.Set("zone", DCAddon::JsonValue(announcement.zoneName));
        record.Set("x", DCAddon::JsonValue(announcement.x));
        record.Set("y", DCAddon::JsonValue(announcement.y));
        record.Set("z", DCAddon::JsonValue(announcement.z));
        record.Set("active", DCAddon::JsonValue(announcement.active));
        record.Set("status", DCAddon::JsonValue(announcement.active ? "active" : "dead"));
        record.Set("action", DCAddon::JsonValue(announcement.action));

        if (announcement.hasNormalized)
        {
            record.Set("nx", DCAddon::JsonValue(announcement.nx));
            record.Set("ny", DCAddon::JsonValue(announcement.ny));
        }

        if (announcement.respawnIn)
            record.Set("spawnIn", DCAddon::JsonValue((int32)announcement.respawnIn));

        DCAddon::JsonValue raresJson;
        raresJson.SetArray();
        raresJson.Push(record);

        DCAddon::JsonMessage message(DCAddon::Module::WORLD, DCAddon::Opcode::World::SMSG_UPDATE);
        message.Set("rares", raresJson);

        uint32 recipients = 0;
        for (auto const& session : sWorldSessionMgr->GetAllSessions())
        {
            Player* player = session.second ? session.second->GetPlayer() : nullptr;
            if (!player || !player->IsInWorld())
                continue;

            if (!IsInScope(player, announcement))
                continue;

            if (announcement.chat)
                ChatHandler(player->GetSession()).SendSysMessage(text);

            if (sConfig.addonPush)
                message.Send(player);

            ++recipients;
        }

        LOG_DEBUG("scripts.dc", "RareSpawnAnnounce: {} (entry {}) {} on map {} zone {}, sent to {} player(s){}",
            announcement.name, announcement.entry, announcement.action, announcement.serverMapId,
            announcement.zoneId, recipients, announcement.hasNormalized ? "" : " (no map position)");
    }

    // A rare killed before a restart has a row in characters.creature_respawn and
    // will come back after the server is up. Without re-arming from that table the
    // announcement is silently lost for every rare that was down at shutdown.
    void SeedPendingFromRespawnTable()
    {
        if (sConfig.maps.empty())
            return;

        std::string mapList;
        for (uint32 mapId : sConfig.maps)
        {
            if (!mapList.empty())
                mapList += ',';

            mapList += std::to_string(mapId);
        }

        QueryResult result = CharacterDatabase.Query(
            "SELECT guid FROM creature_respawn WHERE instanceId = 0 AND mapId IN ({})", mapList);

        if (!result)
            return;

        uint32 seeded = 0;
        do
        {
            ObjectGuid::LowType spawnId = (*result)[0].Get<uint32>();
            CreatureData const* data = sObjectMgr->GetCreatureData(spawnId);
            if (!data || data->spawntimesecs < sConfig.minRespawnSecs)
                continue;

            CreatureTemplate const* tmpl = sObjectMgr->GetCreatureTemplate(data->id);
            if (!tmpl || !IsTrackedRank(tmpl->rank))
                continue;

            std::lock_guard<std::mutex> guard(sStateMutex);
            if (sPendingRespawn.insert(data->id).second)
                ++seeded;
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
            if (sConfig.enabled)
                SeedPendingFromRespawnTable();
        }

        void OnUpdate(uint32 /*diff*/) override
        {
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

void AddSC_dc_rare_spawn_announce()
{
    new RareSpawnAnnounceUnitScript();
    new RareSpawnAnnounceCreatureScript();
    new RareSpawnAnnounceWorldScript();
}
