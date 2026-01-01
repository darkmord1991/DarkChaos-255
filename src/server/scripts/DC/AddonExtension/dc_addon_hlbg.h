#ifndef DC_ADDON_HLBG_H
#define DC_ADDON_HLBG_H

#include "DCAddonNamespace.h"

namespace DCAddon
{
    namespace HLBG
    {
        // Enums and helpers
        enum HLBGStatus : uint8
        {
            STATUS_NONE   = 0,
            STATUS_QUEUED = 1,
            STATUS_PREP   = 2,
            STATUS_ACTIVE = 3,
            STATUS_ENDED  = 4,
        };

        // Function declarations (implementations in dc_addon_hlbg.cpp)
        void SendStatus(Player* player, HLBGStatus status, uint32 mapId, uint32 timeRemaining);
        
        void SendResources(Player* player, uint32 allianceRes, uint32 hordeRes,
                           uint32 allianceBases, uint32 hordeBases);

        void SendQueueUpdate(Player* player, uint8 queueStatus, uint32 position, uint32 estimatedTime,
                             uint32 totalQueued, uint32 allianceQueued, uint32 hordeQueued, 
                             uint32 minPlayers, uint8 state);

        void SendQueueInfo(Player* player);

        void SendTimerSync(Player* player, uint32 elapsedMs, uint32 maxMs);

        void SendTeamScore(Player* player, uint32 allianceScore, uint32 hordeScore,
                           uint32 allianceKills, uint32 hordeKills);

        void SendAffixInfo(Player* player, uint32 affixId1, uint32 affixId2, uint32 affixId3, uint32 seasonId);

        void SendMatchEnd(Player* player, bool victory, uint32 personalScore, uint32 honorGained,
                          uint32 reputationGained, uint32 tokensGained);

    } // namespace HLBG
} // namespace DCAddon

#endif // DC_ADDON_HLBG_H
