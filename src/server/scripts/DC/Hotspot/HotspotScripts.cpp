#include "HotspotMgr.h"
#include "HotspotDefines.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "GameTime.h"
#include "DataMap.h"
#include "dc_update_profiler.h"

// Per-player poll throttle, stored on the player object so it dies with it.
struct HotspotCheckTimer : public DataMap::Base
{
    uint32 elapsed = 0;
};

class HotspotsWorldScript : public WorldScript
{
public:
    HotspotsWorldScript() : WorldScript("HotspotsWorldScript") { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        sHotspotMgr->LoadConfig();
    }

    void OnStartup() override
    {
        sHotspotMgr->LoadConfig();

        // Load unconditionally: if Hotspots start disabled and are switched on
        // later with .hotspot reload, the id counter and spawn pool must
        // already reflect what is in the tables. Nothing acts on the loaded
        // data while disabled - OnUpdate and the player hooks all bail out.
        sHotspotMgr->LoadFromDB();
        sHotspotMgr->LoadSpawnPointsFromDB();

        if (sHotspotsConfig.enabled)
            sHotspotMgr->RecreateHotspotVisualMarkers();

        // Population is maintained lazily by OnUpdate: CleanupExpiredHotspots
        // refills toward minActive (one per cycle) once the spawn pool has
        // eligible points, so startup never bursts disk loads.
    }

    void OnUpdate(uint32 /*diff*/) override
    {
        DarkChaos::ScopedUpdateProfiler _prof("Hotspots");
        if (!sHotspotsConfig.enabled) return;

        time_t now = GameTime::GetGameTime().count();
        static time_t sLastCleanup = 0;
        if (now - sLastCleanup >= 10)
        {
            sLastCleanup = now;
            sHotspotMgr->CleanupExpiredHotspots();
        }

        // Background spawn-point discovery: throttled, bounded disk I/O per call.
        static time_t sLastDiscovery = 0;
        if (now - sLastDiscovery >= 5)
        {
            sLastDiscovery = now;
            sHotspotMgr->RefillSpawnPool();
        }

        static time_t sLastSpawnCheck = 0;
        if (now - sLastSpawnCheck >= (sHotspotsConfig.respawnDelay * 60))
        {
            sLastSpawnCheck = now;
            sHotspotMgr->SpawnHotspot();
        }
    }
};

class HotspotsPlayerScript : public PlayerScript
{
public:
    HotspotsPlayerScript() : PlayerScript("HotspotsPlayerScript") { }

    void OnPlayerLogin(Player* player) override
    {
        if (sHotspotsConfig.enabled)
            sHotspotMgr->CheckPlayerHotspotStatus(player);
    }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        if (!sHotspotsConfig.enabled || !player) return;

        auto* timer = player->CustomData.GetDefault<HotspotCheckTimer>("dc_hotspot_check");
        timer->elapsed += diff;
        if (timer->elapsed < 2000) return;
        timer->elapsed = 0;
        sHotspotMgr->CheckPlayerHotspotStatus(player);
    }

    void OnPlayerResurrect(Player* player, float, bool&) override
    {
        if (sHotspotsConfig.enabled) sHotspotMgr->CheckPlayerHotspotStatus(player);
    }

    // Per-player maps are keyed by ObjectGuid and are otherwise only pruned
    // when the hotspot they reference expires; drop them at logout so they do
    // not accumulate across a long uptime.
    void OnPlayerLogout(Player* player) override
    {
        sHotspotMgr->OnPlayerLogout(player);
    }
};

class HotspotsPlayerGainXP : public PlayerScript
{
public:
    HotspotsPlayerGainXP() : PlayerScript("HotspotsPlayerGainXP") { }

    void OnPlayerGiveXP(Player* player, uint32& amount, Unit* victim, uint8 source) override
    {
        (void)source;
        sHotspotMgr->OnPlayerGiveXP(player, amount, victim);
    }
};

void AddSC_HotspotScripts()
{
    new HotspotsWorldScript();
    new HotspotsPlayerScript();
    new HotspotsPlayerGainXP();
}
