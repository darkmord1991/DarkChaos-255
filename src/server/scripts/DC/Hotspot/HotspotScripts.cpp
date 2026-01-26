#include "HotspotMgr.h"
#include "HotspotDefines.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "GameTime.h"

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
        if (sHotspotsConfig.enabled)
        {
            sHotspotMgr->LoadFromDB();
            sHotspotMgr->RecreateHotspotVisualMarkers();

            // Initial population
             if (sHotspotsConfig.minActive > 0 && sHotspotMgr->GetGrid().Count() < sHotspotsConfig.minActive)
             {
                 uint32 diff = sHotspotsConfig.minActive - (uint32)sHotspotMgr->GetGrid().Count();
                 for(uint32 i=0; i<diff; ++i) sHotspotMgr->SpawnHotspot();
             }
        }
    }

    void OnUpdate(uint32 /*diff*/) override
    {
        if (!sHotspotsConfig.enabled) return;

        time_t now = GameTime::GetGameTime().count();
        static time_t sLastCleanup = 0;
        if (now - sLastCleanup >= 10)
        {
            sLastCleanup = now;
            sHotspotMgr->CleanupExpiredHotspots();
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

    void OnPlayerUpdate(Player* player, uint32 /*diff*/) override
    {
        if (!sHotspotsConfig.enabled || !player) return;

        // Poll every 2s (borrowed from legacy logic)
        // Ideally we'd optimize this to not use gettime every update or use a timer in player aux
        // But following original logic:
        if (player->GetSession() && (GameTime::GetGameTime().count() % 2 == 0))
        {
             // Simple throttling: valid every second, checks count.
             // Better: static maps.
             static std::unordered_map<ObjectGuid, time_t> _lastCheck;
             time_t now = GameTime::GetGameTime().count();
             if (now - _lastCheck[player->GetGUID()] >= 2)
             {
                 _lastCheck[player->GetGUID()] = now;
                 sHotspotMgr->CheckPlayerHotspotStatus(player);
             }
        }
    }

    void OnPlayerResurrect(Player* player, float, bool) override
    {
        if (sHotspotsConfig.enabled) sHotspotMgr->CheckPlayerHotspotStatus(player);
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
