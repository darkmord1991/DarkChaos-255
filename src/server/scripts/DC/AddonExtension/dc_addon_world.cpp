/*
 * Dark Chaos - World Content Addon Module Handler (WRLD)
 * ======================================================
 * Minimal aggregator for Hotspots, World Bosses, and Events
 * Returns JSON payloads for DC-InfoBar World tab and emits updates
 */

#include "DCAddonNamespace.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "DBCStores.h"
#include "GameTime.h"
#include "World.h"
#include "WorldState.h"
#include "Log.h"
#include "DatabaseEnv.h"
#include "ObjectMgr.h"

#include <ctime>

// Local includes to reuse hotspot helper functions
extern uint32 GetHotspotXPBonusPercentage();

// Worldstate IDs for Giant Isles invasion (used to detect active invasion state)
// These match values in dc_giant_isles_invasion.cpp
constexpr uint32 WORLD_STATE_INVASION_ACTIVE = 20000;
constexpr uint32 WORLD_STATE_INVASION_WAVE   = 20001;

namespace DCAddon
{
namespace World
{
    constexpr const char* MODULE_WORLD = Module::WORLD;
    constexpr int32 WORLD_SCHEMA_VERSION = 1;

    // Helper: Build hotspots array using existing table
    static JsonValue BuildHotspotArray()
    {
        JsonValue arr; arr.SetArray();

        QueryResult result = WorldDatabase.Query(
            "SELECT id, map_id, zone_id, x, y, z, (expire_time - UNIX_TIMESTAMP()) as dur FROM dc_hotspots_active WHERE expire_time > UNIX_TIMESTAMP()"
        );

        uint32 xpBonus = GetHotspotXPBonusPercentage();

        if (!result)
            return arr;

        do
        {
            uint32 id = (*result)[0].Get<uint32>();
            uint32 mapId = (*result)[1].Get<uint32>();
            uint32 zoneId = (*result)[2].Get<uint32>();
            float x = (*result)[3].Get<float>();
            float y = (*result)[4].Get<float>();
            float z = (*result)[5].Get<float>();
            int64 dur = (*result)[6].Get<int64>();

            // Zone name via DBC
            std::string zoneName = "Unknown Zone";
            if (const AreaTableEntry* area = sAreaTableStore.LookupEntry(zoneId))
            {
                if (area->area_name[0] && area->area_name[0][0])
                    zoneName = area->area_name[0];
            }

            if (dur <= 0) continue;

            JsonValue h; h.SetObject();
            h.Set("id", JsonValue(id));
            h.Set("mapId", JsonValue(mapId));
            h.Set("zoneId", JsonValue(zoneId));
            h.Set("zoneName", JsonValue(zoneName));
            h.Set("x", JsonValue(x));
            h.Set("y", JsonValue(y));
            h.Set("z", JsonValue(z));
            h.Set("timeRemaining", JsonValue(static_cast<uint32>(dur)));
            h.Set("bonusPercent", JsonValue(xpBonus));
            h.Set("name", JsonValue("Hotspot"));
            arr.Push(h);
        } while (result->NextRow());

        return arr;
    }

    // Helper: Build bosses array (minimal - Giant Isles daily rotation)
    static JsonValue BuildBossArray()
    {
        JsonValue arr; arr.SetArray();

        // Simple daily rotation: replicate Giant Isles day-based mapping
        auto GetCurrentDay = []() -> uint8
        {
            time_t rawtime = GameTime::GetGameTime().count();
            struct tm* timeinfo = localtime(&rawtime);
            return static_cast<uint8>(timeinfo->tm_wday);
        };

        uint8 day = GetCurrentDay();

        // Determine seconds until next midnight.
        time_t now = time(nullptr);
        tm nextDayTm = *localtime(&now);
        nextDayTm.tm_hour = 0; nextDayTm.tm_min = 0; nextDayTm.tm_sec = 0; nextDayTm.tm_mday += 1;
        time_t nextMidnight = mktime(&nextDayTm);
        int32 secondsUntilNextMidnight = static_cast<int32>(difftime(nextMidnight, now));
        if (secondsUntilNextMidnight < 0)
            secondsUntilNextMidnight = 0;

        auto BossEntryForDay = [](uint8 d) -> uint32
        {
            // Mon/Thu = Oondasta; Tue/Fri = Thok; Wed/Sat/Sun = Nalak
            switch (d)
            {
                case 0: case 3: case 6: return 400102; // Sun, Wed, Sat
                case 1: case 4: return 400100;         // Mon, Thu
                case 2: case 5: return 400101;         // Tue, Fri
                default: return 400100;
            }
        };

        auto SecondsUntilBossRotation = [&](uint32 bossEntry) -> int32
        {
            for (int offset = 0; offset < 7; ++offset)
            {
                uint8 d = static_cast<uint8>((day + offset) % 7);
                if (BossEntryForDay(d) == bossEntry)
                {
                    if (offset == 0)
                        return 0;
                    // Next occurrence is at midnight of the day it becomes active.
                    return secondsUntilNextMidnight + static_cast<int32>((offset - 1) * 24 * 60 * 60);
                }
            }
            return secondsUntilNextMidnight;
        };

        struct BossDef
        {
            uint32 entry;
            int32 spawnId;
            char const* id;
            char const* name;
            char const* zone;
        };

        // Giant Isles DB spawn ids (requested): Thok=9000189, Oondasta=9000190, Nalak=9000191.
        static constexpr BossDef GIANT_ISLES_BOSSES[] =
        {
            { 400100, 9000190, "oondasta", "Oondasta, King of Dinosaurs", "Devilsaur Gorge" },
            { 400101, 9000189, "thok",     "Thok the Bloodthirsty",     "Raptor Ridge" },
            { 400102, 9000191, "nalak",    "Nalak the Storm Lord",      "Thundering Peaks" },
        };

        auto TryGetRespawnInSeconds = [](ObjectGuid::LowType spawnId, uint32 mapId) -> Optional<int32>
        {
            // In AzerothCore, creature respawns are stored in the characters DB.
            // If a row exists and respawnTime is in the future, the creature is currently dead.
            QueryResult res = CharacterDatabase.Query(
                "SELECT respawnTime FROM creature_respawn WHERE guid = {} AND mapId = {} AND instanceId = 0",
                spawnId, mapId);
            if (!res)
                return {};

            time_t respawnTime = (*res)[0].Get<time_t>();
            time_t nowSec = time(nullptr);
            if (respawnTime <= nowSec)
                return {};

            int64 diff = static_cast<int64>(respawnTime) - static_cast<int64>(nowSec);
            if (diff <= 0)
                return {};

            // Clamp to int32 range for JSON consumers
            if (diff > std::numeric_limits<int32>::max())
                diff = std::numeric_limits<int32>::max();
            return static_cast<int32>(diff);
        };

        for (BossDef const& def : GIANT_ISLES_BOSSES)
        {
            uint32 mapId = 0;
            if (CreatureData const* cData = sObjectMgr->GetCreatureData(def.spawnId))
                mapId = cData->mapid;

            // If the boss is dead, show respawn timer; otherwise show as active.
            Optional<int32> respawnIn = (mapId != 0) ? TryGetRespawnInSeconds(def.spawnId, mapId) : Optional<int32>();

            JsonValue b; b.SetObject();
            b.Set("id", JsonValue(def.id));
            b.Set("entry", JsonValue(static_cast<int32>(def.entry)));
            b.Set("spawnId", JsonValue(def.spawnId));
            b.Set("name", JsonValue(def.name));
            b.Set("zone", JsonValue(def.zone));
            b.Set("mapId", JsonValue(static_cast<int32>(mapId)));

            if (respawnIn)
            {
                b.Set("active", JsonValue(false));
                b.Set("status", JsonValue("spawning"));
                b.Set("spawnIn", JsonValue(*respawnIn));
            }
            else
            {
                b.Set("active", JsonValue(true));
                b.Set("status", JsonValue("active"));
                // Keep spawnIn for clients that expect a countdown even while alive;
                // default to rotation-based value if mapId unknown.
                b.Set("spawnIn", JsonValue(mapId ? static_cast<int32>(0) : SecondsUntilBossRotation(def.entry)));
            }
            arr.Push(b);
        }
        return arr;
    }

    // Helper: Build events array (minimal: Giant Isles invasion)
    static JsonValue BuildEventsArray()
    {
        JsonValue arr; arr.SetArray();

        // If invasion module is present and active, add to array
        // Check world state for Giant Isles invasion
        bool active = (sWorldState->getWorldState(WORLD_STATE_INVASION_ACTIVE) != 0);
        if (active)
        {
            JsonValue e; e.SetObject();
            // Align with the EVNT invasion feed so UI clients can upsert/merge by eventId.
            e.Set("eventId", JsonValue(static_cast<int32>(1405001)));
            e.Set("type", JsonValue("invasion"));
            e.Set("name", JsonValue("Zandalari Invasion"));
            e.Set("zoneName", JsonValue("Seeping Shores"));
            e.Set("zone", JsonValue("Seeping Shores"));
            int32 wave = static_cast<int32>(sWorldState->getWorldState(WORLD_STATE_INVASION_WAVE));
            e.Set("wave", JsonValue(wave));
            e.Set("maxWaves", JsonValue(static_cast<int32>(4)));
            e.Set("state", JsonValue(wave > 0 ? "active" : "warning"));
            e.Set("active", JsonValue(true));
            arr.Push(e);
        }

        return arr;
    }

    // Handler: Client requests world content
    static void HandleGetContent(Player* player, const ParsedMessage& /*msg*/)
    {
        JsonValue hotspots = BuildHotspotArray();
        JsonValue bosses = BuildBossArray();
        JsonValue events = BuildEventsArray();

        JsonMessage response(Module::WORLD, Opcode::World::SMSG_CONTENT);
        response.Set("schemaVersion", JsonValue(WORLD_SCHEMA_VERSION));
        response.Set("serverTime", JsonValue(static_cast<uint32>(time(nullptr))));
        response.Set("hotspots", hotspots);
        response.Set("bosses", bosses);
        response.Set("events", events);
        response.Send(player);

        // Compatibility / robustness:
        // Even with JSON chunking, some clients may fail to reassemble or may miss large snapshots.
        // Send each boss as a small SMSG_UPDATE payload so DC-InfoBar can always populate the list.
        if (bosses.IsArray())
        {
            for (auto const& boss : bosses.AsArray())
            {
                JsonValue one; one.SetArray();
                one.Push(boss);

                JsonMessage upd(Module::WORLD, Opcode::World::SMSG_UPDATE);
                upd.Set("bosses", one);
                upd.Send(player);
            }
        }
    }

    void RegisterHandlers()
    {
        DC_REGISTER_HANDLER(MODULE_WORLD, Opcode::World::CMSG_GET_CONTENT, HandleGetContent);
        LOG_INFO("dc.addon", "World (WRLD) module handlers registered");
    }

} // namespace World
} // namespace DCAddon

void AddSC_dc_addon_world()
{
    DCAddon::World::RegisterHandlers();
}
