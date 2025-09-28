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
    #include <unordered_map>
    #include <unordered_set>
    #include <string>
    #include <vector>
    #include <map>

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
    // Default match duration used for the status timer (in seconds)
    static constexpr uint32 HL_MATCH_DURATION_SECONDS = 60u * 60u; // 60 minutes

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
    {
        public:            
            OutdoorPvPHL();
            ~OutdoorPvPHL() override; // ensure key function for vtable emission

            bool SetupOutdoorPvP() override;

            /* Handle Player Action */
            void HandlePlayerEnterZone(Player * player, uint32 zone) override;
            void HandlePlayerLeaveZone(Player * player, uint32 zone) override;

            /* Handle Killer Kill */
            void HandleKill(Player * player, Unit * killed) override;
			
            /* Handle Randomizer */
            void Randomizer(Player * player);

            /*Handle Boss
            void BossReward(Player *player);      <- ?
            */

            /* Buffs */
            void HandleBuffs(Player * player, bool loser);

            /* Chat */
            void HandleWinMessage(const char * msg);

            /* Reset */
            void HandleReset();

            /* Rewards */
            void HandleRewards(Player * player, uint32 honorpointsorarena, bool honor, bool arena, bool both);

            /* Updates */
            bool Update(uint32 diff) override;

            /* Sounds */
            void PlaySounds(bool side);

            // Admin/inspection helpers used by commands
            uint32 GetTimeRemainingSeconds() const; // returns 0 if no timer is tracked
            uint32 GetResources(TeamId team) const;
            void SetResources(TeamId team, uint32 amount);
            std::vector<ObjectGuid> GetBattlegroundGroupGUIDs(TeamId team) const;
            void ForceReset();
            void TeleportPlayersToStart();

            // Worldstate HUD helpers (timer/resources like Wintergrasp/AB-style)
            void FillInitialWorldStates(WorldPackets::WorldState::InitWorldStates& packet) override;
            void UpdateWorldStatesForPlayer(Player* player);
            void UpdateWorldStatesAllPlayers();

            // Group auto-invite helpers (battleground-like raid management)
            bool AddOrSetPlayerToCorrectBfGroup(Player* plr);
            // Movement tracking API used by movement handler
            void NotePlayerMovement(Player* player);

        private:
            // helpers
            bool IsMaxLevel(Player* player) const;
            bool IsEligibleForRewards(Player* player) const; // checks deserter only; AFK handled separately
            void Whisper(Player* player, std::string const& msg) const;
            uint8 GetAfkCount(Player* player) const;
            void IncrementAfk(Player* player);
            void ClearAfkState(Player* player);
            void TeleportToCapital(Player* player) const;

            uint32 _ally_gathered;
            uint32 _horde_gathered;
            uint32 _LastWin;
            uint32 _matchEndTime; // absolute epoch seconds when match ends (for status timer)
            bool IS_ABLE_TO_SHOW_MESSAGE;
            bool IS_RESOURCE_MESSAGE_A;
            bool IS_RESOURCE_MESSAGE_H;
            bool _FirstLoad;
            int limit_A;
            int limit_H;
            int limit_resources_message_A;
            int limit_resources_message_H;
            int32 _playersInZone;
        uint32 _npcCheckTimerMs;
        uint32 _afkCheckTimerMs;
        std::unordered_map<uint32, uint8> _afkInfractions; // low GUID -> count
        std::unordered_set<uint32> _afkFlagged; // currently AFK (edge-trigger)
            // Movement-based AFK tracking
            std::map<ObjectGuid, uint32> _playerLastMove; // ms since start
            std::map<ObjectGuid, bool> _playerWarnedBeforeTeleport;
            std::map<ObjectGuid, Position> _playerLastPos;
            // Group management: track battleground raid groups per faction
            std::vector<ObjectGuid> _teamRaidGroups[2];
        // Track when a member of a tracked raid group went offline (epoch seconds)
        std::map<ObjectGuid, uint32> _memberOfflineSince;
    };
    #endif
