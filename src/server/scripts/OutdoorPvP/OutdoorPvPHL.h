
/*
================================================================================
    OutdoorPvPHL.h - Header for Hinterland Outdoor PvP Battleground (zone 47)
================================================================================

    Features & Gameplay Overview (2025):
    -----------------------------------------------------------------------------
    - Zone-wide Alliance vs Horde PvP battleground in Hinterland (zone 47)
    - Automatic group management and raid linking
    - Resource system and permanent resource tracking
    - Periodic broadcasts and worldstate timer updates
    - AFK detection and teleportation
    - Buffs, rewards, and item drops for kills and victory
    - Custom teleportation logic
    - Respawn logic for NPCs and game objects is currently disabled

    Class Structure:
    -----------------------------------------------------------------------------
    - OutdoorPvPHL: Main class, inherits OutdoorPvP
            * Resource counters, timers, and AFK tracking
            * Group management and player linking
            * All battleground event handlers and gameplay logic
            * Worldstate timer broadcast for live match time

    For maintainers: See method comments for details on each gameplay feature.
================================================================================
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
    class OutdoorPvPHL : public OutdoorPvP {
    private:
        // Resource counters for each team
        uint32 _ally_gathered;
        uint32 _horde_gathered;
    uint32 _LastWin; // Tracks last winning team
    uint32 _matchTimer; // Timer for match duration (60 min)
    // Messaging and match state flags
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
    // Finds a non-full raid group for the given team in zone 47
    Group* GetFreeBfRaid(TeamId TeamId);
    // Ensures the player is in the correct raid group for their faction
    bool AddOrSetPlayerToCorrectBfGroup(Player* plr);
    // Returns the group for the given player GUID and team
    Group* GetGroupPlayer(ObjectGuid guid, TeamId TeamId);

    // Resets battleground and permanent resources to initial values
    void HandleReset();

    // Handles honor/arena rewards for a player after a win/kill
    void HandleRewards(Player * player, uint32 honorpointsorarena, bool honor, bool arena, bool both);

    // Main update loop for Hinterland battleground logic
    bool Update(uint32 diff) override;

    // Plays victory/defeat sounds for all players in the zone
    void PlaySounds(bool side);

    public:
    // Constructor: Initializes battleground state, resource counters, timers, and AFK tracking
    OutdoorPvPHL();
    // Setup: Registers the Hinterland zone for OutdoorPvP events
    bool SetupOutdoorPvP() override;
    // Called when a player enters the Hinterland zone
    void HandlePlayerEnterZone(Player* player, uint32 zone) override;
    // Called when a player leaves the Hinterland zone
    void HandlePlayerLeaveZone(Player* player, uint32 zone) override;
    // Broadcasts a win message to all players in the Hinterland zone
    void HandleWinMessage(const char* message);
    // Applies win/lose buffs to a player after the battle
    void HandleBuffs(Player* player, bool loser);
    // Handles logic for when a player kills another player or NPC in the battleground
    void HandleKill(Player* player, Unit* killed) override;
    // Public wrapper for protected HandlePlayerEnterZone
    void PublicHandlePlayerEnterZone(Player* player, uint32 zone) { HandlePlayerEnterZone(player, zone); }
    };
    #endif
