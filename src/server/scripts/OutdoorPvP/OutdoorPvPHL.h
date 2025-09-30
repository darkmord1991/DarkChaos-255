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
    #include "Time/GameTime.h"
    #include <unordered_map>
    #include <unordered_set>
    #include <string>
    #include <vector>
    #include <map>
    #include "Position.h"


    /*
     * Hinterland BG — Feature Overview (2025-09-29)
     * ------------------------------------------------
     * Core gameplay and systems implemented by this OutdoorPvP script:
     * - Participation gate:
     *   - Only max-level players can join; under-max are teleported to capitals
     *     (Alliance → Stormwind, Horde → Orgrimmar) with a whisper.
     * - Joiner UX:
     *   - Private whisper on zone enter with a gold welcome and the current standing
     *     (Alliance/Horde resources, colored names).
    * - Worldstate HUD (Wintergrasp-style):
     *   - Sends required WG worldstates (SHOW, ACTIVE, ATTACKER/DEFENDER, CONTROL, ICON_ACTIVE,
     *     CLOCK, CLOCK_TEXTS, VEHICLE counters as resources, MAX values) and refreshes periodically
     *     to keep timer/resources visible in Hinterlands.
    * - Match window:
    *   - 60-minute duration tracked as an absolute end time for the clock; on expiry the BG auto-resets and restarts.
    *     Auto-reset sequence: Teleport in-zone players to faction start GYs, then respawn NPCs/GOs and refresh HUD.
    * - Status broadcasting:
    *   - Optional zone-wide status broadcast every N seconds (configurable); matches the .hlbg status output.
     *   - Messages are branded with a clickable battleground-style item link prefix
     *     (GetBgChatPrefix) for consistent chat visuals.
     * - AFK/deserter policy:
     *   - Deserters receive no rewards.
     *   - Movement- and /afk-based detection; warn after 120s idle, action at 180s.
     *   - First AFK infraction: no rewards and teleport to team start graveyard; repeated AFK:
     *     teleport to capital; all AFKs deny rewards. GMs are exempt from AFK checks and penalties.
     * - Group management (BG-like raids):
     *   - Auto-create/join per-faction raids, track and prune groups, remove offline >45s,
     *     disband empties. When a 2-person raid becomes 1, keep the remaining player in a new
     *     raid so they are not dropped from BG context.
    * - Reset/teleport helpers:
    *   - Admin reset and auto-reset on timer expiry respawn NPCs/GOs, refresh HUD/timer, and (by default)
    *     teleport players in-zone to their faction start graveyards with a confirmation message.
    *   - Respawn iteration uses per-map object-store visitors (MapStoredObjectTypesContainer); this avoids
    *     relying on global HashMapHolder<Creature/GameObject> containers which are not instantiated on this core.
     * - Resource thresholds and alerts:
     *   - Emote-style notices at 300/200/100 and when a side hits 50 and 0; win shouts are colored.
     * - Diagnostics for NPCs missing after empty zone:
     *   - When zone empties, start a ~60s timer and log; on first join after that window, log a
     *     reminder to verify NPC presence.
     *
     * Enhancements / TODO
     * --------------------
     * 1) Configurables in worldserver.conf:
     *    - AFK warn/action thresholds; match duration; enable/disable periodic status broadcasts.
     * 2) HUD alternatives:
     *    - Option to switch to AB-style resource worldstates if WG HUD ever conflicts on clients.
     * 3) Messaging:
     *    - Localize messages; make item link and colors configurable; optional prefix in whispers.
     * 4) Teleports:
     *    - Move capital/start coordinates to config or DB; optional flight path to starts.
     * 5) Rewards:
     *    - Balance values, add configurable reward tables, add draw/tie logic customization.
     * 6) Admin/ops:
     *    - Add commands to toggle AFK gating, pause timer, or force HUD refresh.
     * 7) Observability:
     *    - Add metrics/counters (joins, AFKs, resets, wins) and structured logs.
     * 8) Tests:
     *    - Scripted unit-style tests for timers and state transitions where possible.
     */

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

            // Public affix enum (used by DC helper sources and tests)
            // Declared early so it is visible to all subsequent member declarations
            enum AffixType { AFFIX_NONE=0, AFFIX_HASTE_BUFF=1, AFFIX_SLOW=2, AFFIX_REDUCED_HEALING=3, AFFIX_REDUCED_ARMOR=4, AFFIX_BOSS_ENRAGE=5 };

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
            // Resets resources, clears AFK state, respawns all creatures and gameobjects in the Hinterlands,
            // seeds a fresh match end time based on configuration, updates the HUD for all in-zone players,
            // and schedules an immediate status broadcast on the next update tick.
            void HandleReset();

            /* Rewards */
            void HandleRewards(Player * player, uint32 honorpointsorarena, bool honor, bool arena, bool both);
            // DC extension: match-end helpers by winning team (implemented in DC/HinterlandBG/OutdoorPvPHL_Rewards.cpp)
            void HandleRewards(TeamId winner);
            void HandleBuffs(TeamId winner);
            void HandleWinMessage(TeamId winner);

            /* Updates */
            // Main periodic tick. Handles:
            // - Auto-reset when the match timer expires (teleport to start GYs then HandleReset)
            // - AFK detection and policy enforcement
            // - BG-like raid lifecycle maintenance
            // - Periodic HUD refresh and optional status broadcasts
            bool Update(uint32 diff) override;

            /* Sounds */
            void PlaySounds(bool side);

            // Admin/inspection helpers used by commands
            uint32 GetTimeRemainingSeconds() const; // returns 0 if no timer is tracked
            uint32 GetResources(TeamId team) const;
            void SetResources(TeamId team, uint32 amount);
            // Return a const reference to avoid copying large vectors on status queries
            std::vector<ObjectGuid> const& GetBattlegroundGroupGUIDs(TeamId team) const;
            void ForceReset();
            void TeleportPlayersToStart(); // sends players to faction base locations
            void TeleportToTeamBase(Player* player) const; // helper used by resets/AFK
            // Iterate all players currently in the Hinterlands and apply a functor
            template <typename Func>
            void ForEachPlayerInZone(Func f)
            {
                uint32 const zoneId = OutdoorPvPHLBuffZones[0];
                WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
                for (auto const& it : sessionMap)
                {
                    Player* p = it.second ? it.second->GetPlayer() : nullptr;
                    if (!p || !p->IsInWorld() || p->GetZoneId() != zoneId)
                        continue;
                    f(p);
                }
            }

            // Worldstate HUD helpers (timer/resources like Wintergrasp/AB-style)
            void FillInitialWorldStates(WorldPackets::WorldState::InitWorldStates& packet) override;
            void UpdateWorldStatesForPlayer(Player* player);
            void UpdateWorldStatesAllPlayers();
            // Affix worldstate helper (optional label via worldstate value)
            void UpdateAffixWorldstateForPlayer(Player* player);
            void UpdateAffixWorldstateAll();

            // Group auto-invite helpers (battleground-like raid management)
            bool AddOrSetPlayerToCorrectBfGroup(Player* plr);
            // Movement tracking API used by movement handler
            void NotePlayerMovement(Player* player);
            // Periodic status broadcast (matches .hlbg status output)
            void BroadcastStatusToZone();
            // Chat cosmetics: clickable item link prefix for BG notifications
            std::string GetBgChatPrefix() const;
            // Config loader
            void LoadConfig();
            // Save and restore persistent state across restarts (resources, timers, lock)
            void SaveRequiredWorldStates() const;
            // Classification queries (safe accessors so helpers outside the class don't need private access)
            bool IsBossNpcEntry(uint32 entry) const;

        private:
            // Test shim: grant unit tests limited access to private members/helpers
            friend class OutdoorPvPHL_TestAccess;
                // Small helper to get current epoch seconds
                static inline uint32 NowSec()
                {
                    return static_cast<uint32>(GameTime::GetGameTime().count());
                }
            // HUD: compute end-epoch for WG-like timer display; show lock countdown when locked
            inline uint32 GetHudEndEpoch() const {
                uint32 now = NowSec();
                if (_lockEnabled && _isLocked && _lockUntilEpoch > now)
                    return _lockUntilEpoch;
                if (_matchEndTime > now)
                    return _matchEndTime;
                return now;
            }
            // Optional worldstate for affix label/code (client addon can render a label)
            static constexpr uint32 WORLD_STATE_HL_AFFIX_TEXT = 0xDD1010;
            // helpers
            bool IsMaxLevel(Player* player) const;
            bool IsEligibleForRewards(Player* player) const; // checks deserter only; AFK handled separately
            void Whisper(Player* player, std::string const& msg) const;
            uint8 GetAfkCount(Player* player) const;
            void IncrementAfk(Player* player);
            void ClearAfkState(Player* player);
            void TeleportToCapital(Player* player) const;
            // Update() helpers
            // 1) End-of-timer processing: optional tiebreak winner announcement/rewards, optional teleport-to-bases, reset match
            // Returns true if the tick was consumed (reset executed), so Update() should early-return.
            bool _tickTimerExpiry();
            // 2) Logs diagnostics around empty-zone windows to help spot missing NPCs after long emptiness
            void _tickEmptyZoneDiagnostics(uint32 diff);
            // 3) Maintain battleground-like raid groups: prune offline, keep last member in a valid raid, remove empties
            void _tickRaidLifecycle();
            // 4) AFK tracking and policy enforcement (movement-based and chat /afk), with GM exemptions
            void _tickAFK(uint32 diff);
            // 5) Periodic HUD refresh so clients always see timer/resources
            void _tickHudRefresh(uint32 diff);
            // 6) Optional periodic status broadcast to the zone (mirrors .hlbg status)
            void _tickStatusBroadcast(uint32 diff);
            // 7) Resource threshold announcements, win shouts, depletion world announcements, and related flag handling
            void _tickThresholdAnnouncements();
            // 8) Optional affix system (zone-wide buffs/debuffs and optional weather)
            void _tickAffix(uint32 diff);
            void _applyAffixEffects();
            void _clearAffixEffects();
            void _setAffixWeather();
            // Affix mapping helpers
            uint32 GetPlayerSpellForAffix(AffixType a) const;
            uint32 GetNpcSpellForAffix(AffixType a) const;
            void   ApplyAffixWeather();
            // 9) Optional lock window between matches (if enabled in config)
            // Returns true if the tick was consumed (e.g., lock expired and reset executed),
            // otherwise returns true as a signal to early-return from Update while locked.
            bool _tickLock(uint32 /*diff*/);
            // 10) Affix helpers for battle-start randomization and category queries
            void _selectAffixForNewBattle();
            inline bool _isBadAffix() const { return _activeAffix == AFFIX_SLOW || _activeAffix == AFFIX_REDUCED_HEALING || _activeAffix == AFFIX_REDUCED_ARMOR || _activeAffix == AFFIX_BOSS_ENRAGE; }
            void _persistState() const; // helper that checks toggle and calls SaveRequiredWorldStates

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
    uint32 _hudRefreshTimerMs;
        uint32 _statusBroadcastTimerMs;
        bool _zoneWasEmpty; // track empty-zone periods to help diagnose NPC despawn window
    // Configurable settings (loaded from hinterlandbg.conf)
    uint32 _matchDurationSeconds;
    uint32 _afkWarnSeconds;
    uint32 _afkTeleportSeconds;
    bool   _statusBroadcastEnabled;
    uint32 _statusBroadcastPeriodMs;
    bool   _autoResetTeleport;    // teleport players to starts on auto-reset (default true)
    bool   _expiryUseTiebreaker;  // declare winner at expiry by higher resources (default true)
    uint32 _initialResourcesAlliance;
    uint32 _initialResourcesHorde;
            // Configurable base locations used for resets/AFK returns
            struct HLBase { uint32 map; float x; float y; float z; float o; };
            HLBase _baseAlliance;
            HLBase _baseHorde;
    uint32 _rewardMatchHonor;               // legacy default
    uint32 _rewardMatchHonorDepletion;      // when win happens by enemy reaching 0
    uint32 _rewardMatchHonorTiebreaker;     // when win happens via timer-expiry tiebreaker
    uint32 _rewardMatchHonorLoser;          // consolation for losing team
    std::vector<uint32> _killHonorValues; // CSV-configured
    uint32 _rewardKillItemId;
    uint32 _rewardKillItemCount;
    bool   _worldAnnounceOnExpiry;          // send world announcement with final scores at expiry
    bool   _worldAnnounceOnDepletion;       // send world announcement when a side reaches 0 resources
    // Configurable NPC reward entries (up to ~10 per team) and token item
    std::vector<uint32> _npcRewardEntriesAlliance;
    std::vector<uint32> _npcRewardEntriesHorde;
    uint32 _rewardNpcTokenItemId;
    uint32 _rewardNpcTokenCount;
    // Optional per-NPC token counts (entry -> count), per opposite team
    std::unordered_map<uint32, uint32> _npcRewardCountsAlliance; // rewarded when Horde kills these Alliance entries
    std::unordered_map<uint32, uint32> _npcRewardCountsHorde;    // rewarded when Alliance kills these Horde entries
    // Configurable NPC classification for resource loss logic
    std::unordered_set<uint32> _npcBossEntriesAlliance;   // alliance NPC entries considered bosses
    std::unordered_set<uint32> _npcBossEntriesHorde;      // horde NPC entries considered bosses
    std::unordered_set<uint32> _npcNormalEntriesAlliance; // alliance NPC entries considered normal
    std::unordered_set<uint32> _npcNormalEntriesHorde;    // horde NPC entries considered normal
    // Configurable resource loss amounts
    uint32 _resourcesLossPlayerKill;   // e.g., 5
    uint32 _resourcesLossNpcNormal;    // e.g., 5
    uint32 _resourcesLossNpcBoss;      // e.g., 200
    // Persistence and lock configuration
    bool   _persistenceEnabled;        // save/restore match state across restarts
    bool   _lockEnabled;               // enable lock window after win
    uint32 _lockDurationSeconds;       // lock duration
    uint32 _lockDurationExpirySec;     // optional override for expiry lock duration
    uint32 _lockDurationDepletionSec;  // optional override for depletion lock duration
    bool   _isLocked;                  // currently locked
    uint32 _lockUntilEpoch;            // unix epoch when lock ends
    bool   _pendingLockFromDepletion = false; // schedule lock/reset after resource depletion
    TeamId _pendingDepletionWinner = TEAM_NEUTRAL;
    // Per-kill feedback spells (optional)
    uint32 _killSpellOnPlayerKillAlliance;
    uint32 _killSpellOnPlayerKillHorde;
    uint32 _killSpellOnNpcKill;
    // Affix system (optional)
    bool   _affixEnabled;
    bool   _affixWeatherEnabled;
    uint32 _affixPeriodSec;
    uint32 _affixTimerMs;
    AffixType _activeAffix;
    uint32 _affixNextChangeEpoch; // persistence of next rotation time
    // Affix spell IDs
    uint32 _affixSpellHaste;
    uint32 _affixSpellSlow;
    uint32 _affixSpellReducedHealing;
    uint32 _affixSpellReducedArmor;
    uint32 _affixSpellBossEnrage;
    uint32 _affixSpellBadWeatherNpcBuff; // optional NPC buff applied during "bad" affixes
    bool   _affixRandomOnStart;          // pick random affix at battle start
    bool   _affixAnnounce;               // announce affix changes in zone
    bool   _affixWorldstateEnabled;      // send affix code as worldstate
    // Per-affix granular config (override single-spell/weather defaults when non-zero)
    uint32 _affixPlayerSpell[6] = {0};   // index by AffixType
    uint32 _affixNpcSpell[6]    = {0};
    uint32 _affixWeatherType[6] = {0};   // WeatherType per affix
    float  _affixWeatherIntensity[6] = {0.0f};
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
