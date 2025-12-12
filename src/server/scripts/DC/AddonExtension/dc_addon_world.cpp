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
        uint32 bossEntry = 0;
        std::string bossName;
        std::string spawnZone;

        // Mon/Thu = Oondasta; Tue/Fri = Thok; Wed/Sat/Sun = Nalak
        switch (day)
        {
            case 0: case 3: case 6: // Sun, Wed, Sat
                bossEntry = 400102; bossName = "Nalak the Storm Lord"; spawnZone = "Thundering Peaks"; break;
            case 1: case 4: // Mon, Thu
                bossEntry = 400100; bossName = "Oondasta, King of Dinosaurs"; spawnZone = "Devilsaur Gorge"; break;
            case 2: case 5: // Tue, Fri
                bossEntry = 400101; bossName = "Thok the Bloodthirsty"; spawnZone = "Raptor Ridge"; break;
            default:
                bossEntry = 400100; bossName = "Oondasta"; spawnZone = "Devilsaur Gorge"; break;
        }

        // Determine time until next rotation (next midnight) to supply spawnIn for the next boss
        time_t now = time(nullptr);
        tm nextDayTm = *localtime(&now);
        nextDayTm.tm_hour = 0; nextDayTm.tm_min = 0; nextDayTm.tm_sec = 0; nextDayTm.tm_mday += 1;
        time_t nextMidnight = mktime(&nextDayTm);
        int32 secondsUntilNextMidnight = static_cast<int32>(difftime(nextMidnight, now));

        auto BossIdFromEntry = [](uint32 entry) -> std::string
        {
            switch (entry)
            {
                case 400100: return "oondasta";
                case 400101: return "thok";
                case 400102: return "nalak";
                default:     return "boss_" + std::to_string(entry);
            }
        };

        JsonValue b; b.SetObject();
        b.Set("id", JsonValue(BossIdFromEntry(bossEntry)));
        b.Set("entry", JsonValue(static_cast<int32>(bossEntry)));
        b.Set("name", JsonValue(bossName));
        b.Set("zone", JsonValue(spawnZone));
        // "active" means currently engaged/visible as alive in the world.
        // Snapshot has no reliable boss-alive tracking, so default to "spawning".
        b.Set("active", JsonValue(false));
        b.Set("status", JsonValue("spawning"));
        b.Set("mapId", JsonValue(static_cast<int32>(0))); // mapId optional
        // spawnIn=0 means "available" (can spawn now) for the rotation boss.
        b.Set("spawnIn", JsonValue(static_cast<int32>(0)));

        // Also populate the next day's boss spawnIn so clients can show Next spawn
        uint8 nextDay = (day + 1) % 7;
        uint32 nextBossEntry = 0;
        std::string nextBossName;
        std::string nextBossZone;
        switch (nextDay)
        {
            case 0: case 3: case 6:
                nextBossEntry = 400102; nextBossName = "Nalak the Storm Lord"; nextBossZone = "Thundering Peaks"; break;
            case 1: case 4:
                nextBossEntry = 400100; nextBossName = "Oondasta, King of Dinosaurs"; nextBossZone = "Devilsaur Gorge"; break;
            case 2: case 5:
                nextBossEntry = 400101; nextBossName = "Thok the Bloodthirsty"; nextBossZone = "Raptor Ridge"; break;
            default:
                nextBossEntry = 400100; nextBossName = "Oondasta"; nextBossZone = "Devilsaur Gorge"; break;
        }
        // Add the next boss as a separate entry with spawnIn
        JsonValue nb; nb.SetObject();
        nb.Set("id", JsonValue(BossIdFromEntry(nextBossEntry)));
        nb.Set("entry", JsonValue(static_cast<int32>(nextBossEntry)));
        nb.Set("name", JsonValue(nextBossName));
        nb.Set("zone", JsonValue(nextBossZone));
        nb.Set("active", JsonValue(false));
        nb.Set("status", JsonValue("spawning"));
        nb.Set("mapId", JsonValue(static_cast<int32>(0)));
        nb.Set("spawnIn", JsonValue(secondsUntilNextMidnight));

        arr.Push(b);
        arr.Push(nb);
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
