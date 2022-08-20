/*
    ----
    ---- OUTDOOR PVP - AUTOINVITE v1
    ---- Copyright by Goettersohn 2012
    ----
*/

#ifndef OUTDOOR_PVP_AI_
#define OUTDOOR_PVP_AI_

#include "ObjectGuid.h"
#include "OutdoorPvP.h"
#include "SharedDefines.h"
#include "Util.h"
#include "ZoneScript.h"

using namespace std;

#define OutdoorPvPHPBuffZonesNum 1
const uint32 OutdoorPvPHPBuffZones[OutdoorPvPHPBuffZonesNum] = { 47 }; // Westfall 40 Mapid ;)

class OutdoorPvPAI : public OutdoorPvP
{
   public:
        OutdoorPvPAI();
        
        bool SetupOutdoorPvP();
        bool AddOrSetPlayerToCorrectBfGroup(Player *plr);
        void HandlePlayerEnterZone(Player* plr, uint32 zone);
        void HandlePlayerLeaveZone(Player* plr, uint32 zone);
        Group* GetFreeBfRaid(uint32 TeamId);
        Group* GetGroupPlayer(uint32 guid, uint32 TeamId);

   protected:
	  GuidSet m_Groups[2];
	  PlayerSet m_PlayersInWar[2];
};
#endif