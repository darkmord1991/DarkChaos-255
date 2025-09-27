
/*
================================================================================
        OutdoorPvPHL.h - Header for Hinterland Outdoor PvP Battleground (zone 47)
================================================================================

        Purpose
        -------
        Header declarations and constants for the Hinterland (zone 47) Outdoor PvP
        battleground implementation. Declares the `OutdoorPvPHL` class and related
        configuration values, sound IDs, and NPC enums used by the implementation.

        Recent changes summary
        ----------------------
        - Added explicit loser sound IDs and changed PlaySounds signature to accept
            a `TeamId` winner value for clearer semantics.
        - Introduced TouchPlayerLastMove(ObjectGuid) public API so a PlayerScript
            can update AFK timestamps when players move.
        - Added helper method declarations to split the Update logic into focused
            responsibilities (timers, AFK, message broadcasting, resource checks).
        - The code now supports automatic creation of multiple battleground raid
            groups per faction when existing raid groups fill up to 40 players.

        Public contract (short)
        -----------------------
        - Inputs: player enters/leaves zone, players move, kills occur, periodic
            server tick via Update(diff).
        - Outputs: zone-wide messages, worldstate timer updates, teleportation,
            buff/honor/item rewards, sound playback, and group management changes.
        - Error modes: group creation failures are checked and handled (returns
            false), resource counters are clamped to avoid underflow.

        Important notes for maintainers
        --------------------------------
        - `MAXRAIDSIZE` and `MAXGROUPSIZE` are defined in `Group.h` (40 and 5)
            and are used to determine group fullness. The script creates additional
            battleground raid groups per faction when needed.
        - Keep sound IDs and coordinates in sync with your DBC and server config.

        TODO / Enhancements (summary)
        ------------------------------
        - Move config values to a central configuration file (`acore.json` or
            module config) to allow runtime tuning.
        - Use `_Groups[team]` to compute exact battleground-raid membership in
            periodic announcements (more accurate than counting all players in zone).
        - Add admin commands to query and manage battleground state (resources,
            raid groups, resets).
        - Consider persisting permanent resource counters to DB if state should
            survive server restarts between matches.

        See `OutdoorPvPHL.cpp` for implementation details and helper responsibilities.
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
    #include <unordered_set>

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
        HL_SOUND_ALLIANCE_BAD   = 8174, // loser/defeat sound (example ID)
        HL_SOUND_HORDE_BAD      = 8214, // loser/defeat sound (example ID)
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
    // Track whether a player has already received the AFK teleport warning
        std::map<ObjectGuid, bool> _playerWarnedBeforeTeleport;

    // Reward exclusion tracking for current match
        GuidUnorderedSet _afkExcluded;    // players teleported due to AFK get no rewards
        GuidUnorderedSet _deserters;      // players who left the zone during an active battle get no rewards

    // Group management
    GuidSet _Groups[2];
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

    // Plays victory/defeat sounds for all players in the zone (winner indicates which team won)
    void PlaySounds(TeamId winner);

    // Helper functions split out of Update for clarity
    void ProcessMatchTimer(uint32 diff);
    void ProcessPeriodicMessage(uint32 diff);
    void ProcessAFK(uint32 now);
    void CheckResourceThresholds();
    void BroadcastResourceMessages();
    void ClampResourceCounters();

    // Worldstate UI helpers (timer/resources like Wintergrasp/AB-style)
    void UpdateWorldStatesForPlayer(Player* player);
    void UpdateWorldStatesAllPlayers();

    // Battle lifecycle helpers
    void ApplyBattleMaintenanceToZonePlayers(); // repair, reset cooldowns, refill health/power for all players in zone
    inline bool IsBattleActive() const { return _FirstLoad; } // active after start announcement until reset
    inline bool IsExcludedFromRewards(Player* p) const { return p && (_afkExcluded.find(p->GetGUID()) != _afkExcluded.end() || _deserters.find(p->GetGUID()) != _deserters.end()); }
    void ClearRewardExclusions() { _afkExcluded.clear(); _deserters.clear(); }

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
    // Update last movement timestamp for AFK tracking (called from PlayerScript movement hook)
    void TouchPlayerLastMove(ObjectGuid guid);
    // Return battleground raid group GUIDs tracked for the given team
    std::vector<ObjectGuid> GetBattlegroundGroupGUIDs(TeamId team) const;
    // Admin helpers: inspect and modify resource counters and force a reset
    uint32 GetResources(TeamId team) const;
    void SetResources(TeamId team, uint32 amount);
    void ForceReset();
    // Teleport all players in the Hinterland zone to their faction start
    void TeleportPlayersToStart();
    };
    #endif
