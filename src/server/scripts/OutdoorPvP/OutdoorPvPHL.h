/*
    .__      .___.                
    [__)  .    |   _ ._ _ ._ _   .
    [__)\_|    |  (_)[ | )[ | )\_|
            ._|                    ._|
    
            Was for Omni-WoW
            Now: Released - 5/4/2012
*/

    #ifndef OUTDOOR_PVP_HL_
    #define OUTDOOR_PVP_HL_
    #include "OutdoorPvP.h"
    #include "OutdoorPvPMgr.h"
    #include "Chat.h"
	#include "Player.h"
    #include "ObjectGuid.h"
    #include "SharedDefines.h"
    #include "Util.h"
    #include "ZoneScript.h"
    #include "WorldStateDefines.h"
    #include "WorldSession.h"
    #include "WorldSessionMgr.h"

    using namespace std;

    const uint8 PointsLoseOnPvPKill = 5;
    
    const uint8 OutdoorPvPHLBuffZonesNum = 1;
    const uint32 OutdoorPvPHLBuffZones[OutdoorPvPHLBuffZonesNum] = { 47 };

    const uint8 WinBuffsNum                 = 4;
    const uint8 LoseBuffsNum                = 2;
    const uint32 WinBuffs[WinBuffsNum]      = { 39233, 23693, 53899, 62213 }; // Whoever wins, gets these buffs
    const uint32 LoseBuffs[LoseBuffsNum]    = { 23948, 40079}; // Whoever loses, gets this buff.

    const uint32 HL_RESOURCES_A         = 450;
    const uint32 HL_RESOURCES_H         = 450;

    enum Sounds
    {
        HL_SOUND_ALLIANCE_GOOD  = 8173,
        HL_SOUND_HORDE_GOOD     = 8213,
    };

    enum AllianceNpcs
    {
            Alliance_Healer = 600005,
			Alliance_Boss = 810003,         // updated DC-WoW
			Alliance_Infantry = 810000,     // updated DC-WoW
			Alliance_Squadleader = 600011,
    };

    enum HordeNpcs
    {
            Horde_Heal = 600004,
			Horde_Squadleader = 600008,
			Horde_Infantry = 810001,        // updated DC-WoW
			Horde_Boss = 810002,            // updated DC-WoW
    };

/* OutdoorPvPHL Related */
    class OutdoorPvPHL : public OutdoorPvP
        private:
            uint32 _ally_gathered;
            uint32 _horde_gathered;
            uint32 _LastWin;
            bool IS_ABLE_TO_SHOW_MESSAGE;
            bool IS_RESOURCE_MESSAGE_A;
            bool IS_RESOURCE_MESSAGE_H;
            bool _FirstLoad;
            int limit_A;
            int limit_H;
            int limit_resources_message_A;
            int limit_resources_message_H;
            uint32 _messageTimer; // Timer for periodic message

            // Permanent resources for each team (never reset during a run, only at battleground reset)
            uint32 _ally_permanent_resources;
            uint32 _horde_permanent_resources;

            // Timer for live/permanent resource broadcast (5s interval)
            uint32 _liveResourceTimer;

            // AFK tracking: map player GUID to last movement timestamp (ms)
            std::map<ObjectGuid, uint32> _playerLastMove;

            // Group management
            GuidSet _Groups[2];
            uint32 _BattleId;
            GuidUnorderedSet _PlayersInWar[2];
            Group* GetFreeBfRaid(TeamId TeamId);
            bool AddOrSetPlayerToCorrectBfGroup(Player* plr);
            Group* GetGroupPlayer(ObjectGuid guid, TeamId TeamId);

            /* Reset */
            void HandleReset();

            /* Rewards */
            void HandleRewards(Player * player, uint32 honorpointsorarena, bool honor, bool arena, bool both);

            /* Updates */
            bool Update(uint32 diff) override;

            /* Sounds */
            void PlaySounds(bool side);

        private:
            uint32 _ally_gathered;
            uint32 _horde_gathered;
            uint32 _LastWin;
            bool IS_ABLE_TO_SHOW_MESSAGE;
            bool IS_RESOURCE_MESSAGE_A;
            bool IS_RESOURCE_MESSAGE_H;
            bool _FirstLoad;
            int limit_A;
            int limit_H;
            int limit_resources_message_A;
            int limit_resources_message_H;
            uint32 _messageTimer; // Timer for periodic message

            // Permanent resources for each team (never reset during a run, only at battleground reset)
            uint32 _ally_permanent_resources;
            uint32 _horde_permanent_resources;

            // Timer for live/permanent resource broadcast (5s interval)
            uint32 _liveResourceTimer;

            // Group management
            GuidSet _Groups[2];
            uint32 _BattleId;
            GuidUnorderedSet _PlayersInWar[2];
            Group* GetFreeBfRaid(TeamId TeamId);
            bool AddOrSetPlayerToCorrectBfGroup(Player* plr);
            Group* GetGroupPlayer(ObjectGuid guid, TeamId TeamId);

        public:
            // Public wrapper for protected HandlePlayerEnterZone
            void PublicHandlePlayerEnterZone(Player* player, uint32 zone) { HandlePlayerEnterZone(player, zone); }
    };
    #endif
