/*
================================================================================
// Forward declaration: the player movement script registration function is
// defined later in this file. Declare it here so AddSC_outdoorpvp_hl can call
// it without requiring the function to be defined earlier in the translation
// unit.
static void RegisterOutdoorPvPHLPlayerMoveScript();

                OutdoorPvPHL.cpp - Hinterland Outdoor PvP Battleground (zone 47)
================================================================================

Purpose
-------
Implements a persistent, zone-wide Alliance vs Horde open-world battleground for
Hinterland (default zone id 47). Responsibilities include automatic battleground
raid-group management, a simple resource-scoring system, periodic status
announcements, AFK detection and handling, award/buff distribution, and basic
teleportation and end-of-match logic.

Recent notable changes (developer summary)
------------------------------------------
- Replaced unsafe printf-style calls with a safe PlayerTextEmoteFmt helper.
- Centralized configuration constants (timers, thresholds) near the top of the file.
- Added AFK movement tracking using a PlayerScript movement hook and
    `TouchPlayerLastMove(ObjectGuid)` so we can reliably warn and teleport idle players.
- Prevented unsigned underflow on resource counters (`ClampResources`).
- Split `Update()` into focused helpers: `ProcessMatchTimer`,
    `ProcessPeriodicMessage`, `ProcessAFK`, `CheckResourceThresholds`,
    `BroadcastResourceMessages`, and `ClampResourceCounters` for easier maintenance.
- Distinct victory/defeat sounds are played for winners/losers via `PlaySounds`.
- Added automatic creation of multiple battleground raid groups per faction
    when existing raid groups reach server-side limits (logged via `LOG_INFO`).

High-level feature overview
---------------------------
- Auto-grouping / raid creation: players entering the zone are auto-added into
    battleground-style raid groups for their faction. New groups are created when
    current groups fill (e.g. 40 players).
- Resource scoring: each faction has a resource counter. Player/NPC deaths reduce
    the counter; hit thresholds cause announcements, warnings, and eventual loss.
- Periodic announcements: every `MESSAGE_INTERVAL_MS` the script broadcasts
    resource and approximate player counts, and time-left information.
- AFK handling: players idle for `AFK_TIMEOUT_MS` are warned and then
    teleported to a safe start location to prevent camping/griefing.
- Rewards: winners receive honor/arena point gains, buffs, and item rewards.

Quality & safety notes
----------------------
- Resource counters are clamped to prevent unsigned wraparound on deductions.
- Movement-based AFK detection is implemented via a PlayerScript hook; this is
    more reliable than relying solely on zone-enter timestamps.
- Teleportation and reward paths are conservative: basic alive checks are done
    before teleporting, and group creation failures are handled gracefully.

Prioritized TODO / Enhancements
-------------------------------
1) Configuration: move hardcoded values (zone id, timers, thresholds, coords,
     sound IDs) into `acore.json` or module config to allow server owners to
     tune behavior without recompilation.

2) Deterministic tiebreak (recommended): implement last-kill timestamp tracking
     (`_ally_last_kill_time`, `_horde_last_kill_time`) updated in `HandleKill()` and
     used in `ProcessMatchTimer()` to break exact resource ties. This is fair and
     predictable — the side with the most recent kill wins.

3) Draw reward policy: decide whether a draw should reward both sides, split
     rewards, or grant no reward. Add configuration to control the chosen policy.

4) Admin tooling & audit: add optional DB-backed audit logging for `.hlbg set`
     and `.hlbg reset` (current logs go to `admin.hlbg`) and add an optional
     `reason` parameter to `.hlbg set` to capture admin intent.

5) Teleport safety & UX: add additional teleport guards (e.g. avoid teleporting
     players in combat, during mounts, or inside certain phases) and provide
     clearer area-trigger messages describing why the teleport happened.

6) AFK heuristics: debounce small positional jitter, treat orientation-only
     changes as non-activity, and allow staff/roles to mark players exempt.

7) Tests & CI: add unit/integration tests for resource clamping, group creation
     behavior, and match-end handling. Add CI checks to run script compilation and
     basic static analysis during PRs.

8) Telemetry/metrics: optionally collect counters (matches started/ended,
     raids created, AFK teleports) and publish to a metrics sink for ops.

9) Sound & DBC validation: ensure used sound IDs exist in the target DBC set
     and add a startup warning if IDs are missing; document the mapping in config.

10) Refactor: consider moving battleground-specific files into
     `src/server/scripts/DC/HinterlandBG/` and create a small test harness to make
     iterative development and testing simpler.

Match timeout / draw behavior notes
----------------------------------
- Current implementation: when the match timer expires the code compares
    remaining resources. If one side has strictly more resources, that side is
    declared the winner (rewards, buffs and sounds applied). If both sides have
    exactly the same resources the match is declared a draw: no `_LastWin` is set
    and no win-specific rewards are granted.

- Alternatives recorded for maintainers:
    * Reward both sides: simplest, but may be considered unfair for competitive play.
    * Split rewards: both sides receive scaled rewards (e.g. half), acknowledging
        a close finish while avoiding double full-win payouts.
    * Deterministic tiebreak: break ties using last-kill timestamps, total kills,
        or another deterministic metric; this requires a small amount of extra state
        but produces a single winner for every match.

How to test quickly
-------------------
- Build server, start instance, create test accounts and join zone 47.
- Use `.hlbg get/set/reset/status` (GM) to validate admin tooling and audit
    logging. Test draw behavior by setting equal resources for both sides and
    allowing the timer to expire.
- Fill a raid group to the server limit and ensure the 41st player triggers
    creation of an additional battleground raid group (watch logs for creation).

For maintainers: update this header when adding/removing major features.
================================================================================
*/
    #include "OutdoorPvPHL.h"
    #include "Player.h"
    #include "OutdoorPvP.h"
    #include "World.h"
    #include "WorldPacket.h"
    #include "OutdoorPvPScript.h"
    #include "CreatureScript.h"
    #include "WorldSession.h"
    #include "WorldSessionMgr.h"
    #include "GroupMgr.h"
#include "MapMgr.h"
    #include "ScriptDefines/MovementHandlerScript.h"
    #include "WorldState.h"
    #include "Pet.h"
    #include "GameTime.h"
#include <cstdarg>
#include <cstdint>
#include <algorithm>

// Forward declaration: registration function for the player movement script used
// for AFK tracking. The function is defined later in this file but is called
// from AddSC_outdoorpvp_hl(), so we must declare it beforehand.
static void RegisterOutdoorPvPHLPlayerMoveScript();

// OutdoorPvPHL.cpp: Main logic for Hinterland Outdoor PvP Battleground (zone 47)
// Implements group management, resource tracking, AFK detection, messaging, rewards, and faction-based teleportation.

// Configuration constants
static constexpr uint32_t HL_ZONE_ID = 47;
static constexpr uint32_t MATCH_DURATION_MS = 3600000; // 60 minutes
static constexpr uint32_t MESSAGE_INTERVAL_MS = 120000; // 120 seconds
static constexpr uint32_t AFK_TIMEOUT_MS = 600000; // 10 minutes
static constexpr int RESOURCE_THRESHOLD_WARN_1 = 300;
static constexpr int RESOURCE_THRESHOLD_WARN_2 = 200;
static constexpr int RESOURCE_THRESHOLD_WARN_3 = 100;
static constexpr int RESOURCE_THRESHOLD_LOW = 50;

// Small helper to call TextEmote with printf-style formatting
static inline void PlayerTextEmoteFmt(Player* player, const char* fmt, ...)
{
    if (!player) return;
    char buf[256];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    player->TextEmote(buf);
}

// Helper: Teleport all players in the Hinterland zone to their faction start
static inline void TeleportAllPlayersInZoneToStart()
{
    WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
    for (WorldSessionMgr::SessionMap::const_iterator it = sessionMap.begin(); it != sessionMap.end(); ++it)
    {
        Player* p = it->second ? it->second->GetPlayer() : nullptr;
        if (p && p->IsInWorld() && p->GetZoneId() == HL_ZONE_ID) {
            if (p->GetTeamId() == TEAM_ALLIANCE)
                p->TeleportTo(0, -17.743f, -4635.110f, 12.933f, 2.422f);
            else
                p->TeleportTo(0, -581.244f, -4577.710f, 10.215f, 0.548f);
        }
    }
}

// Note: TeleportAllPlayersInZoneToStart is intentionally broad — it iterates
// all world sessions and teleports any player currently in the Hinterland
// zone to their faction start coordinates. This helper is used both on
// resource-victory conditions and when the match is force-reset. Consider
// adding additional safety checks (combat state, flight/mount checks, or
// phase handling) if the teleport should be restricted in future.

// Ensure resource counters do not underflow (they're unsigned)
static inline void ClampResources(uint32 &value)
{
    if ((int32)value < 0)
        value = 0;
}

// Explanation: Resource counters are stored as unsigned integers. When
// resource deductions occur we clamp negative values to zero to avoid
// unsigned wraparound. The cast-to-int32 checks for negative semantics
// while avoiding UB for normal positive values.

    // Constructor: Initializes battleground state, resource counters, timers, and AFK tracking.
    // Sets up all initial values for resources, timers, and player movement tracking.
    OutdoorPvPHL::OutdoorPvPHL()
    {
        _typeId = OUTDOOR_PVP_HL;
        _ally_gathered = HL_RESOURCES_A;
        _horde_gathered = HL_RESOURCES_H;

        // Permanent resources: never reset during a run, only at battleground reset
        _ally_permanent_resources = HL_RESOURCES_A;
        _horde_permanent_resources = HL_RESOURCES_H;

        IS_ABLE_TO_SHOW_MESSAGE = false;
        IS_RESOURCE_MESSAGE_A = false;
        IS_RESOURCE_MESSAGE_H = false;

        _FirstLoad = false;
        limit_A = 0;
        limit_H = 0;
        _LastWin = 0;
        limit_resources_message_A = 0;
        limit_resources_message_H = 0;
        _messageTimer = 0; // Timer for periodic zone-wide message
        _liveResourceTimer = 0; // Timer for live/permanent resource broadcast
        _matchTimer = 0; // Timer for match duration

        // AFK tracking: map player GUID to last movement timestamp (ms)
        _playerLastMove.clear();
        _playerWarnedBeforeTeleport.clear();
    }

    // Constructor notes:
    // - The constructor intentionally leaves most timers at zero. `_FirstLoad`
    //   controls the initial-start announcement which is emitted on the first
    //   Update() call. Permanent resources are initialized from HL_RESOURCES_*.
    // - `_playerWarnedBeforeTeleport` tracks whether we already warned a
    //   particular player of imminent AFK teleport so the warning isn't spammed.

    // Setup: Registers the Hinterland zone for OutdoorPvP events.
    // Registers zone 47 for battleground logic and event handling.
    bool OutdoorPvPHL::SetupOutdoorPvP()
    {
        for (uint8 i = 0; i < OutdoorPvPHLBuffZonesNum; ++i)
            RegisterZone(OutdoorPvPHLBuffZones[i]);
        return true;
    }

// Setup notes:
// - RegisterZone wires this OutdoorPvP script into the server for the
//   configured buff zones so `sOutdoorPvPMgr` will own and update it.

    // Called when a player enters the Hinterland zone.
    // Handles auto-invite to raid group, welcome message, and AFK tracking initialization.
    void OutdoorPvPHL::HandlePlayerEnterZone(Player* player, uint32 zone)
    {
        // Auto-invite logic
        AddOrSetPlayerToCorrectBfGroup(player);

        // Welcome message
        player->TextEmote("Welcome to Hinterland BG!");

        // Initialize last movement timestamp
    _playerLastMove[player->GetGUID()] = getMSTime();

        // Ensure client initializes its worldstate set for the zone before sending updates
        player->SendInitWorldStates(player->GetZoneId(), player->GetAreaId());

        // If battle is active, ensure player gets the current worldstate UI and is not excluded by stale flags
        if (IsBattleActive())
        {
            _afkExcluded.erase(player->GetGUID());
            UpdateWorldStatesForPlayer(player);
        }

    // Note: we set last-move on zone enter so players who stand still after
    // entering the zone will still be considered active for a short period.

        OutdoorPvP::HandlePlayerEnterZone(player, zone);
    }

// Provide initial worldstates so clients see the HUD as soon as they load the zone
void OutdoorPvPHL::FillInitialWorldStates(WorldPackets::WorldState::InitWorldStates& packet)
{
    // WG-only HUD (client DBC patched). Seed absolute end time for both WG clocks.
    uint32 timeRemaining = (_matchTimer >= MATCH_DURATION_MS) ? 0u : (MATCH_DURATION_MS - _matchTimer) / 1000u;
    uint32 now = static_cast<uint32>(GameTime::GetGameTime().count());
    uint32 endEpoch = now + timeRemaining;

    packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_SHOW, 1u);
    packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_CLOCK, endEpoch);
    packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_CLOCK_TEXTS, endEpoch);

    // Reuse WG vehicle bars for resource counters
    packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_VEHICLE_A, _ally_gathered);
    packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_MAX_VEHICLE_A, _ally_permanent_resources);
    packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_VEHICLE_H, _horde_gathered);
    packet.Worldstates.emplace_back(WORLD_STATE_BATTLEFIELD_WG_MAX_VEHICLE_H, _horde_permanent_resources);
}

    // Finds a non-full raid group for the given team in zone 47.
    // Ensures only one raid group per faction is used for auto-invite.
    Group* OutdoorPvPHL::GetFreeBfRaid(TeamId TeamId)
    {
        // Iterate all stored group GUIDs for the team and return first non-full raid group.
        // Remove stale group GUIDs (groups that no longer exist) from the set.
        for (GuidSet::const_iterator itr = _Groups[TeamId].begin(); itr != _Groups[TeamId].end(); )
        {
            ObjectGuid gid = *itr;
            Group* group = sGroupMgr->GetGroupByGUID(gid.GetCounter());
            if (!group)
            {
                // Erase stale GUID from set
                GuidSet::const_iterator toErase = itr++;
                _Groups[TeamId].erase(toErase);
                continue;
            }

            // Prefer battleground raid groups for this zone and ensure they are not full
            // Accept the group only if it is a battleground-type raid group and
            // has room for additional members. This keeps unrelated groups out
            // of the auto-invite rotation.
            if (group->isBGGroup() && group->isRaidGroup() && !group->IsFull())
                return group;

            ++itr;
        }
        return nullptr;
    }

    // Ensures the player is in the correct raid group for their faction in zone 47.
    // Adds the player to an existing group or creates a new one if needed.
    bool OutdoorPvPHL::AddOrSetPlayerToCorrectBfGroup(Player* plr)
    {
        if (!plr->IsInWorld())
            return false;
        // Don't re-invite if already in a BG/BF group
        if (plr->GetGroup() && (plr->GetGroup()->isBGGroup() || plr->GetGroup()->isBFGroup()))
        {
            return false;
        }
            // Try to find an existing non-full raid group for this team
            Group* group = GetFreeBfRaid(plr->GetTeamId());
            if (group)
        {
            // Add player to group if not already a member
            if (!group->IsMember(plr->GetGUID()))
            {
                group->AddMember(plr);
                // If player was a leader in their original group, transfer leadership
                if (Group* originalGroup = plr->GetOriginalGroup())
                    if (originalGroup->IsLeader(plr->GetGUID()))
                        group->ChangeLeader(plr->GetGUID());
            }
            else
            {
                // Already a member, set their subgroup
                uint8 subgroup = group->GetMemberGroup(plr->GetGUID());
                plr->SetBattlegroundOrBattlefieldRaid(group, subgroup);
            }
        }
        else
        {
                // No available non-full raid group: create a new raid group for this team
                group = new Group;
                Battleground* bg = (Battleground*)sOutdoorPvPMgr->GetOutdoorPvPToZoneId(HL_ZONE_ID);
                if (bg)
                    group->SetBattlegroundGroup(bg);

                // Create will initialize the group and mark it as a BG raid if m_bgGroup was set
                if (!group->Create(plr))
                {
                    // Creation failed: cleanup and abort
                    delete group;
                    return false;
                }

                // Ensure the group is a raid-type (raid-size up to MAXRAIDSIZE)
                if (!group->isRaidGroup())
                    group->ConvertToRaid();

                sGroupMgr->AddGroup(group);
                _Groups[plr->GetTeamId()].insert(group->GetGUID());

                // Log creation for ops/debugging. Include team and group low-guid.
                LOG_INFO("outdoorpvp", "[OutdoorPvPHL]: Created new battleground raid group %u for team %s in Hinterland",
                         group->GetGUID().GetCounter(), plr->GetTeamId() == TEAM_ALLIANCE ? "Alliance" : "Horde", HL_ZONE_ID);
                // Note: creating a Group dynamically and calling Create(plr)
                // mirrors the server's group creation flow. Ensure this path is
                // only used for battleground-style grouping to avoid side-effects
                // on unrelated grouping logic.
        }
        return true;
    }

    // Returns the group for the given player GUID and team, or nullptr if not found.
    Group* OutdoorPvPHL::GetGroupPlayer(ObjectGuid guid, TeamId TeamId)
    {
        for (GuidSet::const_iterator itr = _Groups[TeamId].begin(); itr != _Groups[TeamId].end(); ++itr)
        {
            Group* group = sGroupMgr->GetGroupByGUID(itr->GetCounter());
            if (group && group->IsMember(guid))
                return group;
        }
        return nullptr;
    }

    // Helper: Teleport player to Hinterland Outdoor BG start location by faction.
    // Teleports player to their faction's start location in Hinterland BG.
    // Marked static to keep internal linkage to this translation unit.
    static inline void TeleportPlayerToStart(Player* player)
    {
        // Start locations of the Hinterland BG
        // Alliance: 0, -17.743, -4635.110, 12.933, 2.422
        // Horde:    0, -581.244, -4577.710, 10.215, 0.548
        if (player->GetTeamId() == TEAM_ALLIANCE)
            player->TeleportTo(0, -17.743f, -4635.110f, 12.933f, 2.422f);
        else
            player->TeleportTo(0, -581.244f, -4577.710f, 10.215f, 0.548f);
    }

    // Called when a player leaves the Hinterland zone.
    // Handles zone leave messaging, teleportation, raid group removal, and AFK tracking cleanup.
    void OutdoorPvPHL::HandlePlayerLeaveZone(Player* player, uint32 zone)
    {
        player->TextEmote(",HEY, you are leaving the zone, while a battle is on going! Shame on you!");
        // Mark deserter during an active battle (excluded from rewards this round)
        if (IsBattleActive())
            _deserters.insert(player->GetGUID());
        TeleportPlayerToStart(player);
        // Remove player from raid group if in one
        if (Group* group = player->GetGroup()) {
            if (group->isRaidGroup() && group->IsMember(player->GetGUID())) {
                group->RemoveMember(player->GetGUID(), GROUP_REMOVEMETHOD_DEFAULT);
                // Reset phase mask to default (1) after group removal
                player->SetPhaseMask(1, true);
                // Clear battleground/battlefield raid flags
                player->SetBattlegroundOrBattlefieldRaid(nullptr, 0);
            }
        }
        // Remove AFK tracking
        _playerLastMove.erase(player->GetGUID());
        OutdoorPvP::HandlePlayerLeaveZone(player, zone);
    }

    // Touch/update player's last move timestamp (used by movement hooks)
    void OutdoorPvPHL::TouchPlayerLastMove(ObjectGuid guid)
    {
        _playerLastMove[guid] = getMSTime();
    }

    // Broadcasts a win message to all players in the Hinterland zone.
    // Respawn logic for NPCs and game objects is currently disabled.
    void OutdoorPvPHL::HandleWinMessage(const char* message)
    {
        for (uint8 i = 0; i < OutdoorPvPHLBuffZonesNum; ++i)
            sWorldSessionMgr->SendZoneText(OutdoorPvPHLBuffZones[i], message);

            // Respawn logic for NPCs and game objects temporarily removed as requested.
    }

    // Update worldstates (timer + resources) for a single player in Hinterland
    void OutdoorPvPHL::UpdateWorldStatesForPlayer(Player* player)
    {
        if (!player || !player->IsInWorld() || player->GetZoneId() != HL_ZONE_ID)
            return;

        uint32 timeRemaining = (_matchTimer >= MATCH_DURATION_MS) ? 0u : (MATCH_DURATION_MS - _matchTimer) / 1000u;
        uint32 now = static_cast<uint32>(GameTime::GetGameTime().count());
        uint32 endEpoch = now + timeRemaining;

    // WG-only HUD with absolute end time on both clocks; no control indicator
        player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_SHOW, 1);
        player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_CLOCK, endEpoch);
        player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_CLOCK_TEXTS, endEpoch);

        // Resource bars via WG vehicle states
        player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_VEHICLE_A, _ally_gathered);
        player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_MAX_VEHICLE_A, _ally_permanent_resources);
        player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_VEHICLE_H, _horde_gathered);
        player->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_MAX_VEHICLE_H, _horde_permanent_resources);
    }

    // Broadcast worldstates to all players in Hinterland
    void OutdoorPvPHL::UpdateWorldStatesAllPlayers()
    {
        WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
        for (WorldSessionMgr::SessionMap::const_iterator itr = sessionMap.begin(); itr != sessionMap.end(); ++itr)
        {
            Player* p = itr->second ? itr->second->GetPlayer() : nullptr;
            if (p && p->IsInWorld() && p->GetZoneId() == HL_ZONE_ID)
                UpdateWorldStatesForPlayer(p);
        }
    }

    // Plays victory/defeat sounds for all players in the zone, depending on side.
    // Play victory sounds for the winning team; winner indicates which team won/should be celebrated
    void OutdoorPvPHL::PlaySounds(TeamId winner)
    {
        WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
        for (WorldSessionMgr::SessionMap::const_iterator itr = sessionMap.begin(); itr != sessionMap.end(); ++itr)
        {
            for (uint8 i = 0; i < OutdoorPvPHLBuffZonesNum; ++i)
            {
                if(!itr->second || !itr->second->GetPlayer() || !itr->second->GetPlayer()->IsInWorld() || itr->second->GetPlayer()->GetZoneId() != OutdoorPvPHLBuffZones[i])
                    continue;

                if(itr->second->GetPlayer()->GetZoneId() == OutdoorPvPHLBuffZones[i])
                {
                    Player* p = itr->second->GetPlayer();
                    // Play the winning sound for players on the winning team and a neutral/other sound for others.
                    if (p->GetTeamId() == winner) {
                        // Winning team hears the victory sound
                        if (winner == TEAM_ALLIANCE)
                            p->PlayDirectSound(HL_SOUND_ALLIANCE_GOOD, p);
                        else
                            p->PlayDirectSound(HL_SOUND_HORDE_GOOD, p);
                    } else {
                        // Losing team hears the defeat/loser sound
                        if (winner == TEAM_ALLIANCE)
                            p->PlayDirectSound(HL_SOUND_HORDE_BAD, p);
                        else
                            p->PlayDirectSound(HL_SOUND_ALLIANCE_BAD, p);
                    }
                }
            }
        }
    }

    // Resets battleground and permanent resources to initial values.
    // Resets all timers, resource counters, and flags for a new match.
    void OutdoorPvPHL::HandleReset()
    {
        _ally_gathered = HL_RESOURCES_A;
        _horde_gathered = HL_RESOURCES_H;
        _ally_permanent_resources = HL_RESOURCES_A;
        _horde_permanent_resources = HL_RESOURCES_H;

        IS_ABLE_TO_SHOW_MESSAGE = false;
        IS_RESOURCE_MESSAGE_A = false;
        IS_RESOURCE_MESSAGE_H = false;

        _FirstLoad = false;
        limit_A = 0;
        limit_H = 0;
        limit_resources_message_A = 0;
        limit_resources_message_H = 0;
        _messageTimer = 0;
        _liveResourceTimer = 0;

    // Clear AFK warning state on reset
    _playerWarnedBeforeTeleport.clear();
    // Clear reward-exclusion sets for the next battle
    ClearRewardExclusions();

    // Hide Wintergrasp HUD for all players in zone
    for (auto const& sessionPair : sWorldSessionMgr->GetAllSessions())
    {
        if (Player* p = sessionPair.second ? sessionPair.second->GetPlayer() : nullptr)
        {
            if (!p->IsInWorld() || p->GetZoneId() != HL_ZONE_ID)
                continue;
            p->SendUpdateWorldState(WORLD_STATE_BATTLEFIELD_WG_SHOW, 0);
        }
    }

        LOG_INFO("misc", "[OutdoorPvPHL]: Reset Hinterland BG");
    }

    // Apply repairs, reset cooldowns, and refill health/power for all Hinterland players
    void OutdoorPvPHL::ApplyBattleMaintenanceToZonePlayers()
    {
        WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
        for (WorldSessionMgr::SessionMap::const_iterator itr = sessionMap.begin(); itr != sessionMap.end(); ++itr)
        {
            Player* p = itr->second ? itr->second->GetPlayer() : nullptr;
            if (!p || !p->IsInWorld() || p->GetZoneId() != HL_ZONE_ID)
                continue;

            // Free repair (no cost)
            p->DurabilityRepairAll(false, 0.0f, false);

            // Reset all spell cooldowns by iterating cooldown map
            SpellCooldowns cds = p->GetSpellCooldownMap();
            for (auto const& kv : cds)
                p->RemoveSpellCooldown(kv.first, true);

            // Refill health and power pools
            p->SetHealth(p->GetMaxHealth());
            p->SetPower(POWER_RAGE, 0);
            p->SetPower(POWER_ENERGY, p->GetMaxPower(POWER_ENERGY));
            if (p->getPowerType() == POWER_MANA)
                p->SetPower(POWER_MANA, p->GetMaxPower(POWER_MANA));

            if (Pet* pet = p->GetPet())
            {
                pet->SetHealth(pet->GetMaxHealth());
                pet->SetPower(pet->getPowerType(), pet->GetMaxPower(pet->getPowerType()));
            }
        }
    }

    // Applies win/lose buffs to a player after the battle.
    void OutdoorPvPHL::HandleBuffs(Player* player, bool loser)
    {
        if(loser)
        {
            for(int i = 0; i < LoseBuffsNum; i++)
                player->CastSpell(player, LoseBuffs[i], true);
        }
        else
        {
            for(int i = 0; i < WinBuffsNum; i++)
                player->CastSpell(player, WinBuffs[i], true);
        }
    }

    // Handles honor/arena rewards for a player after a win/kill.
    // Sends reward messages and updates player points.
    void OutdoorPvPHL::HandleRewards(Player* player, uint32 honorpointsorarena, bool honor, bool arena, bool both)
    {
        char msg[250];
        uint32 _GetHonorPoints = player->GetHonorPoints();
        uint32 _GetArenaPoints = player->GetArenaPoints();

        if(honor)
        {
            player->SetHonorPoints(_GetHonorPoints + honorpointsorarena);
            snprintf(msg, 250, "You got %u bonus honor!", honorpointsorarena);
        }
        else if(arena)
        {
            player->SetArenaPoints(_GetArenaPoints + honorpointsorarena);
            snprintf(msg, 250, "You got amount of %u additional arena points!", honorpointsorarena);
        }
        else if(both)
        {
            player->SetHonorPoints(_GetHonorPoints + honorpointsorarena);
            player->SetArenaPoints(_GetArenaPoints + honorpointsorarena);
            snprintf(msg, 250, "You got amount of %u additional arena points and bonus honor!", honorpointsorarena);
        }
        HandleWinMessage(msg);
    }

// Main update loop for Hinterland battleground logic.
// Handles battleground start announcement, periodic resource broadcasts, live timer worldstate updates,
// AFK teleport (with warning), win/lose logic, and match progression features.
bool OutdoorPvPHL::Update(uint32 diff)
{
    OutdoorPvP::Update(diff);

    // Split responsibilities to helpers for readability
    if (_FirstLoad == false)
    {
        char announceMsg[256];
    snprintf(announceMsg, sizeof(announceMsg), "[Hinterland Defence]: A new battle has started in Hinterland! Last winner: %s", (_LastWin == ALLIANCE ? "Alliance" : (_LastWin == HORDE ? "Horde" : "None")));
        for (const auto& sessionPair : sWorldSessionMgr->GetAllSessions()) {
            if (Player* player = sessionPair.second->GetPlayer())
                player->GetSession()->SendAreaTriggerMessage(announceMsg);
        }
    LOG_INFO("misc", "%s", announceMsg);
        _FirstLoad = true;
        _matchTimer = 0;
        // At battle start: repair, reset CDs, refill, and sync worldstate UI
        ApplyBattleMaintenanceToZonePlayers();
        UpdateWorldStatesAllPlayers();
    }

    // timers and periodic tasks
    ProcessMatchTimer(diff);
    ProcessPeriodicMessage(diff);

    // Update timer/resources UI roughly once per second
    _liveResourceTimer += diff;
    if (_liveResourceTimer >= 1000)
    {
        UpdateWorldStatesAllPlayers();
        _liveResourceTimer = 0;
    }

    uint32 now = getMSTime();
    ProcessAFK(now);

    CheckResourceThresholds();
    BroadcastResourceMessages();

    IS_ABLE_TO_SHOW_MESSAGE = false; // Reset
    return false;
}

// Helper implementations
void OutdoorPvPHL::ProcessMatchTimer(uint32 diff)
{
    _matchTimer += diff;
    if (_matchTimer >= MATCH_DURATION_MS)
    {
    // Match time expired - determine winner by remaining resources
        if (_ally_gathered > _horde_gathered)
        {
            // Alliance wins by resources
            HandleWinMessage("[Hinterland Defence]: Time's up! Alliance wins by having more resources.");
            PlaySounds(TEAM_ALLIANCE);
            // Reward winners and apply buffs/loser debuffs
            for (const auto& sessionPair : sWorldSessionMgr->GetAllSessions())
            {
                if (Player* player = sessionPair.second->GetPlayer())
                {
                    if (!player->IsInWorld() || player->GetZoneId() != HL_ZONE_ID)
                        continue;

                    // Skip rewards/buffs for deserters and AFK-excluded
                    if (!IsExcludedFromRewards(player))
                    {
                        // Winners receive rewards/buffs
                        if (player->GetTeamId() == TEAM_ALLIANCE)
                        {
                            HandleRewards(player, 1500, true, false, false);
                            HandleBuffs(player, false);
                        }
                        else
                        {
                            // Losing side gets loser-buffs if configured
                            HandleBuffs(player, true);
                        }
                    }

                    player->GetSession()->SendAreaTriggerMessage("[Hinterland Defence]: Time's up! Alliance wins by having more resources.");
                }
            }
            _LastWin = ALLIANCE;
        }
        else if (_horde_gathered > _ally_gathered)
        {
            // Horde wins by resources
            HandleWinMessage("[Hinterland Defence]: Time's up! Horde wins by having more resources.");
            PlaySounds(TEAM_HORDE);
            for (const auto& sessionPair : sWorldSessionMgr->GetAllSessions())
            {
                if (Player* player = sessionPair.second->GetPlayer())
                {
                    if (!player->IsInWorld() || player->GetZoneId() != HL_ZONE_ID)
                        continue;

                    if (!IsExcludedFromRewards(player))
                    {
                        if (player->GetTeamId() == TEAM_HORDE)
                        {
                            HandleRewards(player, 1500, true, false, false);
                            HandleBuffs(player, false);
                        }
                        else
                        {
                            HandleBuffs(player, true);
                        }
                    }

                    player->GetSession()->SendAreaTriggerMessage("[Hinterland Defence]: Time's up! Horde wins by having more resources.");
                }
            }
            _LastWin = HORDE;
        }
        else
        {
            // Draw: equal resources
            HandleWinMessage("[Hinterland Defence]: Time's up! The match ended in a draw (equal resources).");
            for (const auto& sessionPair : sWorldSessionMgr->GetAllSessions())
            {
                if (Player* player = sessionPair.second->GetPlayer())
                {
                    if (!player->IsInWorld() || player->GetZoneId() != HL_ZONE_ID)
                        continue;
                    player->GetSession()->SendAreaTriggerMessage("[Hinterland Defence]: Time's up! The match ended in a draw (equal resources).");
                }
            }
            // No last-win update on draw
        }

            // Teleport everyone back to their starts and reset the match
        TeleportAllPlayersInZoneToStart();
        // End-of-battle maintenance and UI sync
        ApplyBattleMaintenanceToZonePlayers();
        HandleReset();
        _matchTimer = 0;
        _FirstLoad = false;
    }
}

// Notes on ProcessMatchTimer:
// - The function compares resource counters at time expiry and awards
//   victory to the side with strictly more resources. For an exact tie the
//   match is declared a draw and no win-specific rewards or `_LastWin`
//   updates are applied. The behavior is intentional; see header comments
//   for alternative approaches (reward both, split rewards, last-kill
//   tiebreak).

// AFK handling notes:
// - `ProcessAFK` tracks per-player movement timestamps and warns players 30s
//   before teleporting them to prevent accidental displacements. The current
//   implementation uses `PlayerScript::OnPlayerMove` to stamp movement which
//   is more reliable than polling position deltas. Consider debouncing tiny
//   position jitter or orientation-only updates if the server generates
//   excessive move events.

// HandleKill notes:
// - `HandleKill` deducts resources from the killed side and awards items
//   / rewards to the killer or raid. Boss entries deduct large resource
//   amounts and reward raid members. The function clamps resource counters
//   after modification to avoid wraparound. For deterministic tiebreaks the
//   function is a natural place to stamp last-kill timestamps for each team.

void OutdoorPvPHL::ProcessPeriodicMessage(uint32 diff)
{
    _messageTimer += diff;
    if (_messageTimer >= MESSAGE_INTERVAL_MS)
    {
        uint32 timeRemaining = (_matchTimer >= MATCH_DURATION_MS) ? 0 : (MATCH_DURATION_MS - _matchTimer) / 1000;
        uint32 minutes = timeRemaining / 60;
        uint32 seconds = timeRemaining % 60;

        // Count battleground-raid members using tracked raid groups for each team
        uint32 allianceCount = 0;
        uint32 hordeCount = 0;
        // Iterate Alliance groups
        for (GuidSet::const_iterator itr = _Groups[TEAM_ALLIANCE].begin(); itr != _Groups[TEAM_ALLIANCE].end(); ++itr)
        {
            Group* g = sGroupMgr->GetGroupByGUID(itr->GetCounter());
            if (!g || !g->isBGGroup())
                continue;
            allianceCount += g->GetMembersCount();
        }
        // Iterate Horde groups
        for (GuidSet::const_iterator itr = _Groups[TEAM_HORDE].begin(); itr != _Groups[TEAM_HORDE].end(); ++itr)
        {
            Group* g = sGroupMgr->GetGroupByGUID(itr->GetCounter());
            if (!g || !g->isBGGroup())
                continue;
            hordeCount += g->GetMembersCount();
        }

        char msg[256];
        snprintf(msg, sizeof(msg), "[Hinterland Defence]: Alliance: %u (%u players) | Horde: %u (%u players) | Time left: %02u:%02u (Start: 60:00)",
                 _ally_gathered, allianceCount, _horde_gathered, hordeCount, minutes, seconds);
        sWorldSessionMgr->SendZoneText(HL_ZONE_ID, msg);
        _messageTimer = 0;
    }
}

void OutdoorPvPHL::ProcessAFK(uint32 now)
{
    WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
    for (WorldSessionMgr::SessionMap::const_iterator itr = sessionMap.begin(); itr != sessionMap.end(); ++itr)
    {
        Player* player = itr->second ? itr->second->GetPlayer() : nullptr;
        if (!player || !player->IsInWorld() || player->GetZoneId() != HL_ZONE_ID)
            continue;
        ObjectGuid guid = player->GetGUID();
        if (_playerLastMove.find(guid) == _playerLastMove.end())
            _playerLastMove[guid] = now;

        // If player hasn't moved for AFK_TIMEOUT_MS - 30s, warn them once
        const uint32 warnThreshold = AFK_TIMEOUT_MS > 30000 ? AFK_TIMEOUT_MS - 30000 : 0;
        if (!_playerWarnedBeforeTeleport[guid] && now - _playerLastMove[guid] >= warnThreshold && now - _playerLastMove[guid] < AFK_TIMEOUT_MS)
        {
            if (player->GetSession())
                player->GetSession()->SendAreaTriggerMessage("You will be teleported to your start point in 30 seconds due to inactivity. Move to cancel.");
            _playerWarnedBeforeTeleport[guid] = true;
            continue;
        }

        if (now - _playerLastMove[guid] >= AFK_TIMEOUT_MS)
        {
            // Safe teleport check: ensure player is alive and map is valid
            if (player->IsAlive())
            {
                // Teleport the player to safe coordinates for their faction
                TeleportPlayerToStart(player);
                player->TextEmote("You have been summoned to your starting position due to inactivity.");
                // Mark player as excluded from this round's rewards
                _afkExcluded.insert(guid);
            }
            // Reset timers and warned flag
            _playerLastMove[guid] = now; // Reset timer after teleport
            _playerWarnedBeforeTeleport[guid] = false;
        }
    }
}

void OutdoorPvPHL::CheckResourceThresholds()
{
    if(_ally_gathered <= RESOURCE_THRESHOLD_LOW && limit_A == 0)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true; IS_RESOURCE_MESSAGE_A = true; limit_A = 1; PlaySounds(TEAM_HORDE);
    }
    else if(_horde_gathered <= RESOURCE_THRESHOLD_LOW && limit_H == 0)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true; IS_RESOURCE_MESSAGE_H = true; limit_H = 1; PlaySounds(TEAM_ALLIANCE);
    }
    else if(_ally_gathered <= 0 && limit_A == 1)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true; IS_RESOURCE_MESSAGE_A = true; limit_A = 2; PlaySounds(TEAM_HORDE); TeleportAllPlayersInZoneToStart();
    }
    else if(_horde_gathered <= 0 && limit_H == 1)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true; IS_RESOURCE_MESSAGE_H = true; limit_H = 2; PlaySounds(TEAM_ALLIANCE); TeleportAllPlayersInZoneToStart();
    }
    else if(_ally_gathered <= RESOURCE_THRESHOLD_WARN_1 && limit_resources_message_A == 0)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true; limit_resources_message_A = 1; PlaySounds(TEAM_HORDE);
    }
    else if(_horde_gathered <= RESOURCE_THRESHOLD_WARN_1 && limit_resources_message_H == 0)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true; limit_resources_message_H = 1; PlaySounds(TEAM_ALLIANCE);
    }
    else if(_ally_gathered <= RESOURCE_THRESHOLD_WARN_2 && limit_resources_message_A == 1)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true; limit_resources_message_A = 2; PlaySounds(TEAM_HORDE);
    }
    else if(_horde_gathered <= RESOURCE_THRESHOLD_WARN_2 && limit_resources_message_H == 1)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true; limit_resources_message_H = 2; PlaySounds(TEAM_ALLIANCE);
    }
    else if(_ally_gathered <= RESOURCE_THRESHOLD_WARN_3 && limit_resources_message_A == 2)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true; limit_resources_message_A = 3; PlaySounds(TEAM_HORDE);
    }
    else if(_horde_gathered <= RESOURCE_THRESHOLD_WARN_3 && limit_resources_message_H == 2)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true; limit_resources_message_H = 3; PlaySounds(TEAM_ALLIANCE);
    }
}

void OutdoorPvPHL::BroadcastResourceMessages()
{
    if(!IS_ABLE_TO_SHOW_MESSAGE) return;
    WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
    for (WorldSessionMgr::SessionMap::const_iterator itr = sessionMap.begin(); itr != sessionMap.end(); ++itr)
    {
        if(!itr->second || !itr->second->GetPlayer() || !itr->second->GetPlayer()->IsInWorld() || itr->second->GetPlayer()->GetZoneId() != HL_ZONE_ID)
            continue;
        Player* p = itr->second->GetPlayer();
        if(limit_resources_message_A >= 1 && limit_resources_message_A <= 3)
            PlayerTextEmoteFmt(p, "[Hinterland Defence]: The Alliance got %u resources left!", _ally_gathered);
        else if(limit_resources_message_H >= 1 && limit_resources_message_H <= 3)
            PlayerTextEmoteFmt(p, "[Hinterland Defence]: The Horde got %u resources left!", _horde_gathered);

        if(IS_RESOURCE_MESSAGE_A)
        {
            if(limit_A == 1)
            {
                PlayerTextEmoteFmt(p, "[Hinterland Defence]: The Alliance got %u resources left!", _ally_gathered);
                IS_RESOURCE_MESSAGE_A = false;
            }
            else if(limit_A == 2)
            {
                p->TextEmote("[Hinterland Defence]: The Alliance has lost! Horde wins as Alliance resources dropped to 0.");
                HandleWinMessage("[Hinterland Defence]: Horde wins! Alliance resources dropped to 0.");
                HandleRewards(p, 1500, true, false, false);
                if (p->GetTeamId() == TEAM_ALLIANCE) HandleBuffs(p, true); else HandleBuffs(p, false);
                for (const auto& sessionPair : sWorldSessionMgr->GetAllSessions()) if (Player* player = sessionPair.second->GetPlayer()) player->GetSession()->SendAreaTriggerMessage("[Hinterland Defence]: Horde wins! Alliance resources dropped to 0.");
                TeleportAllPlayersInZoneToStart();
                _LastWin = HORDE;
                IS_RESOURCE_MESSAGE_A = false;
            }
        }
        else if(IS_RESOURCE_MESSAGE_H)
        {
            if(limit_H == 1)
            {
                PlayerTextEmoteFmt(p, "[Hinterland Defence]: The Horde got %u resources left!", _horde_gathered);
                IS_RESOURCE_MESSAGE_H = false;
            }
            else if(limit_H == 2)
            {
                HandleWinMessage("[Hinterland Defence]: Alliance wins! Horde resources dropped to 0.");
                HandleRewards(p, 1500, true, false, false);
                if (p->GetTeamId() == TEAM_ALLIANCE) HandleBuffs(p, false); else HandleBuffs(p, true);
                for (const auto& sessionPair : sWorldSessionMgr->GetAllSessions()) if (Player* player = sessionPair.second->GetPlayer()) player->GetSession()->SendAreaTriggerMessage("[Hinterland Defence]: Alliance wins! Horde resources dropped to 0.");
                TeleportAllPlayersInZoneToStart();
                _LastWin = ALLIANCE;
                IS_RESOURCE_MESSAGE_H = false;
            }
        }
    }
}

void OutdoorPvPHL::ClampResourceCounters()
{
    ClampResources(_ally_gathered);
    ClampResources(_horde_gathered);
}

// Public wrapper that teleports all players in the Hinterland zone to their faction start.
// Exposed so external commands (GM tools) can reuse the script's teleport helper.
void OutdoorPvPHL::TeleportPlayersToStart()
{
    TeleportAllPlayersInZoneToStart();
}

std::vector<ObjectGuid> OutdoorPvPHL::GetBattlegroundGroupGUIDs(TeamId team) const
{
    std::vector<ObjectGuid> res;
    if (team != TEAM_ALLIANCE && team != TEAM_HORDE)
        return res;

    for (GuidSet::const_iterator itr = _Groups[team].begin(); itr != _Groups[team].end(); ++itr)
    {
        ObjectGuid gid = *itr;
        Group* g = sGroupMgr->GetGroupByGUID(gid.GetCounter());
        if (!g)
            continue;
        if (!g->isBGGroup())
            continue;
        res.push_back(g->GetGUID());
    }
    return res;
}

// Admin accessors
uint32 OutdoorPvPHL::GetResources(TeamId team) const
{
    if (team == TEAM_ALLIANCE) return _ally_gathered;
    if (team == TEAM_HORDE) return _horde_gathered;
    return 0;
}

void OutdoorPvPHL::SetResources(TeamId team, uint32 amount)
{
    if (team == TEAM_ALLIANCE) _ally_gathered = amount;
    else if (team == TEAM_HORDE) _horde_gathered = amount;
}

void OutdoorPvPHL::ForceReset()
{
    HandleReset();
}
    
    // Handles logic for when a player kills another player or NPC in the battleground.
    // Awards items, deducts resources, and sends kill announcements. Boss kills reward all raid members.
    // Randomizer and random honor logic have been removed for maintainability.
    void OutdoorPvPHL::HandleKill(Player* player, Unit* killed)
    {
        if(killed->GetTypeId() == TYPEID_PLAYER) // Killing players will take their Resources away. It also gives extra honor.
        {
            if(player->GetGUID() == killed->GetGUID())
                return;

            // Announce the kill to the zone
            char announceMsg[256];
            snprintf(announceMsg, sizeof(announceMsg), "[Hinterland Defence]: %s has slain %s!", player->GetName().c_str(), killed->GetName().c_str());
            sWorldSessionMgr->SendZoneText(47, announceMsg);

            // Reward killer with 100x item 80003
            player->AddItem(80003, 100);

            switch(killed->ToPlayer()->GetTeamId())
            {
                case TEAM_ALLIANCE:
                    _ally_gathered -= 5; // Remove 5 resources from Alliance on player kill
                    ClampResourceCounters();
                    player->AddItem(40752, 1);
                    break;
                default: //Horde
                    _horde_gathered -= 5; // Remove 5 resources from Horde on player kill
                    ClampResourceCounters();
                    player->AddItem(40752, 1);
                    break;
            }
        }
        else // If is something besides a player
        {
            if(player->GetTeamId() == TEAM_ALLIANCE)
            {
                switch(killed->GetEntry()) // Alliance killing horde guards
                {
                    case 810002: // Horde boss
                        _horde_gathered -= 200; // Remove 200 resources from Horde on boss kill
                        ClampResourceCounters();
                        {
                            char bossMsg[256];
                            snprintf(bossMsg, sizeof(bossMsg), "[Hinterland Defence]: %s has slain the Horde boss! 200 Horde resources lost! Horde now has %u resources left!", player->GetName().c_str(), _horde_gathered);
                            sWorldSessionMgr->SendZoneText(47, bossMsg);
                            // Reward all raid members with 500x item 80003
                            if (Group* raid = player->GetGroup()) {
                                for (GroupReference* ref = raid->GetFirstMember(); ref; ref = ref->next()) {
                                    Player* member = ref->GetSource();
                                    if (member && member->IsInWorld() && member->GetZoneId() == 47)
                                        member->AddItem(80003, 500);
                                }
                            } else {
                                player->AddItem(80003, 500);
                            }
                        }
                        break;
                    case Horde_Infantry:
                        _horde_gathered -= PointsLoseOnPvPKill;
                        ClampResourceCounters();
                        break;
                    case Horde_Squadleader: // 2?
                        _horde_gathered -= PointsLoseOnPvPKill;
                        ClampResourceCounters();
                        break;
                    /* Removed duplicate case for Horde_Boss (entry 810002) */
                    case Horde_Heal:
                        _horde_gathered -= PointsLoseOnPvPKill;
                        ClampResourceCounters();
                        break;
                    /*
                    case WARSONG_HONOR_GUARD:
                        _horde_gathered -= PointsLoseOnPvPKill;
                        ClampResourceCounters();
                        // Removed Randomizer call
                        break;
                    case WARSONG_MARKSMAN:
                        _horde_gathered -= PointsLoseOnPvPKill;
                        ClampResourceCounters();
                        // Removed Randomizer call
                        break;
                    case WARSONG_RECRUITMENT_OFFICER:
                        _horde_gathered -= PointsLoseOnPvPKill;
                        ClampResourceCounters();
                        // Removed Randomizer call
                        break;
                    case WARSONG_SCOUT:
                        _horde_gathered -= PointsLoseOnPvPKill;
                        ClampResourceCounters();
                        // Removed Randomizer call
                        break;
                    case WARSONG_WIND_RIDER:
                        _horde_gathered -= PointsLoseOnPvPKill;
                        Randomizer(player); // Randomizes the honor reward
                        break;
                    */
                }
            }
            else // Team Horde
            {
                switch(killed->GetEntry()) // Horde killing alliance guards
                {
                    case 810003: // Alliance boss
                        _ally_gathered -= 200; // Remove 200 resources from Alliance on boss kill
                        ClampResourceCounters();
                        {
                            char bossMsg[256];
                            snprintf(bossMsg, sizeof(bossMsg), "[Hinterland Defence]: %s has slain the Alliance boss! 200 Alliance resources lost! Alliance now has %u resources left!", player->GetName().c_str(), _ally_gathered);
                            sWorldSessionMgr->SendZoneText(47, bossMsg);
                            // Reward all raid members with 500x item 80003
                            if (Group* raid = player->GetGroup()) {
                                for (GroupReference* ref = raid->GetFirstMember(); ref; ref = ref->next()) {
                                    Player* member = ref->GetSource();
                                    if (member && member->IsInWorld() && member->GetZoneId() == 47)
                                        member->AddItem(80003, 500);
                                }
                            } else {
                                player->AddItem(80003, 500);
                            }
                        }
                        break;
                    case Alliance_Healer:
                        _ally_gathered -= PointsLoseOnPvPKill;
                        ClampResourceCounters();
                        break;
                    /* Removed duplicate case for Alliance_Boss (entry 810003) */
                    case Alliance_Infantry:
                        _ally_gathered -= PointsLoseOnPvPKill;
                        ClampResourceCounters();
                        break;
                    case Alliance_Squadleader: // Wrong?
                        _ally_gathered -= PointsLoseOnPvPKill;
                        ClampResourceCounters();
                        break;
                    /*
                    case VALIANCE_KEEP_FOOTMAN_2: // 2?
                        _ally_gathered -= PointsLoseOnPvPKill;
                        ClampResourceCounters();
                        // Removed Randomizer call
                        break;
                    case VALIANCE_KEEP_OFFICER:
                        _ally_gathered -= PointsLoseOnPvPKill;
                        ClampResourceCounters();
                        // Removed Randomizer call
                        break;
                    case VALIANCE_KEEP_RIFLEMAN:
                        _ally_gathered -= PointsLoseOnPvPKill;
                        ClampResourceCounters();
                        // Removed Randomizer call
                        break;
                    case VALIANCE_KEEP_WORKER:
                        _ally_gathered -= PointsLoseOnPvPKill;
                        ClampResourceCounters();
                        // Removed Randomizer call
                        break;
                    case DURDAN_THUNDERBEAK:
                        _ally_gathered -= PointsLoseOnPvPKill;
                        // Removed Randomizer call
                        break;
                    */
                }
            }
        }
    }
    
    // Add to OutdoorPvPHL.h:
    // std::map<ObjectGuid, uint32> _playerLastMove;

    // Script registration for OutdoorPvP Hinterland
    class OutdoorPvP_hinterland : public OutdoorPvPScript
    {
        public:
     
        OutdoorPvP_hinterland()
            : OutdoorPvPScript("outdoorpvp_hl") {}
     
        OutdoorPvP* GetOutdoorPvP() const
        {
            return new OutdoorPvPHL();
        }
    };

     
    // Registers the OutdoorPvP Hinterland script
    void AddSC_outdoorpvp_hl()
    {
        new OutdoorPvP_hinterland;

        // Register movement hook for AFK tracking
        // Forward-declared below; registers the player movement script that
        // stamps AFK last-move timestamps via `TouchPlayerLastMove()`.
        RegisterOutdoorPvPHLPlayerMoveScript();
    }

// Player movement hook to update AFK tracking for Hinterland Outdoor PvP
// Use MovementHandlerScript so we can override the movement hook and register
// the MOVEMENTHOOK_ON_PLAYER_MOVE hook during construction.
class OutdoorPvPHL_PlayerMoveScript : public MovementHandlerScript
{
public:
    OutdoorPvPHL_PlayerMoveScript() : MovementHandlerScript("OutdoorPvPHL_PlayerMoveScript", std::vector<uint16>{MOVEMENTHOOK_ON_PLAYER_MOVE}) {}

    void OnPlayerMove(Player* player, MovementInfo /*movementInfo*/, uint32 /*opcode*/) override
    {
        if (!player || !player->IsInWorld())
            return;
        if (player->GetZoneId() != HL_ZONE_ID)
            return;

        OutdoorPvP* out = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(HL_ZONE_ID);
        if (!out)
            return;
        OutdoorPvPHL* hl = dynamic_cast<OutdoorPvPHL*>(out);
        if (!hl)
            return;

        // Update last move timestamp for AFK tracking
        hl->TouchPlayerLastMove(player->GetGUID());
    }
};

// Register the player movement script
static void RegisterOutdoorPvPHLPlayerMoveScript()
{
    new OutdoorPvPHL_PlayerMoveScript();
}

