// -----------------------------------------------------------------------------
// OutdoorPvPHL_StateMachine.cpp
// -----------------------------------------------------------------------------
// Finite state machine for HLBG to manage battleground lifecycle
// States: Warmup → InProgress → Paused → Finished → Cleanup
// -----------------------------------------------------------------------------
#include "HinterlandBG.h"
#include "Chat.h"
#include "HinterlandBGConstants.h"
#include "ObjectAccessor.h"

using namespace HinterlandBGConstants;

void OutdoorPvPHL::UpdateStateMachine(uint32 diff)
{
    switch (_bgState)
    {
        case BG_STATE_WARMUP:
            UpdateWarmupState(diff);
            break;
        case BG_STATE_IN_PROGRESS:
            UpdateInProgressState(diff);
            break;
        case BG_STATE_PAUSED:
            UpdatePausedState(diff);
            break;
        case BG_STATE_FINISHED:
            UpdateFinishedState(diff);
            break;
        case BG_STATE_CLEANUP:
            UpdateCleanupState(diff);
            break;
        default:
            LOG_ERROR("outdoorpvp.hl", "[HL] Unknown BG state: {}", static_cast<uint32>(_bgState));
            _bgState = BG_STATE_WARMUP;
            break;
    }
}

void OutdoorPvPHL::TransitionToState(BGState newState)
{
    if (_bgState == newState)
        return;

    // Server-side warmup gate: do not start warmup unless at least one player has actually
    // joined (in-zone) OR at least one queued player is currently connected.
    // This prevents empty warmup/in-progress cycles after timer expiry or server restarts.
    if (newState == BG_STATE_WARMUP)
    {
        bool hasInZonePlayers = (_playersInZone > 0);
        bool hasConnectedQueued = false;
        for (QueueEntry const& entry : _queuedPlayers)
        {
            if (ObjectAccessor::FindConnectedPlayer(entry.playerGuid))
            {
                hasConnectedQueued = true;
                break;
            }
        }

        if (!hasInZonePlayers && !hasConnectedQueued)
        {
            LOG_INFO("outdoorpvp.hl", "[HL] Warmup blocked (no players joined). Staying in cleanup.");
            _bgState = BG_STATE_CLEANUP;
            _matchStartTime = 0;
            _matchEndTime = NowSec();
            return;
        }
    }

    BGState oldState = _bgState;
    _bgState = newState;

    LOG_INFO("outdoorpvp.hl", "[HL] State transition: {} -> {}",
        static_cast<uint32>(oldState), static_cast<uint32>(newState));

    // Persist state to database for crash recovery
    _persistState();

    // State entry actions
    switch (newState)
    {
        case BG_STATE_WARMUP:
            EnterWarmupState();
            break;
        case BG_STATE_IN_PROGRESS:
            EnterInProgressState();
            break;
        case BG_STATE_PAUSED:
            EnterPausedState();
            break;
        case BG_STATE_FINISHED:
            EnterFinishedState();
            break;
        case BG_STATE_CLEANUP:
            EnterCleanupState();
            break;
    }
}

void OutdoorPvPHL::EnterWarmupState()
{
    // Set warmup timer (configurable, default 2 minutes)
    _warmupTimeRemaining = _warmupDurationSeconds * IN_MILLISECONDS;
    // During warmup, the HUD clock should represent the warmup countdown.
    // We reuse _matchEndTime as the HUD end-epoch (GetHudEndEpoch()).
    _matchStartTime = 0;
    _matchEndTime = NowSec() + _warmupDurationSeconds;

    // Announce warmup phase
    BroadcastToZone("Hinterland BG: Warmup phase started! Join now to participate.");

    // Reset battle statistics
    _playerScores.clear();
    _playerHKBaseline.clear();

    // Teleport any players who queued for the next match, then consume the queue.
    if (!_queuedPlayers.empty())
    {
        TeleportQueuedPlayers();
        ClearQueue();
    }

    // HUD worldstates removed - now handled by addon
    // UpdateWorldStatesAllPlayers();
}

void OutdoorPvPHL::UpdateWarmupState(uint32 diff)
{
    // If everyone left during warmup, abort back to cleanup instead of starting an empty match.
    // Give a short grace window so queued teleports can populate the zone.
    uint32 warmupTotalMs = _warmupDurationSeconds * IN_MILLISECONDS;
    uint32 warmupElapsedMs = (warmupTotalMs > _warmupTimeRemaining) ? (warmupTotalMs - _warmupTimeRemaining) : 0u;
    if (_playersInZone == 0 && warmupElapsedMs >= 5000)
    {
        TransitionToState(BG_STATE_CLEANUP);
        return;
    }

    if (_warmupTimeRemaining <= diff)
    {
        // Warmup finished, start battle (only if someone is still present)
        if (_playersInZone > 0)
            TransitionToState(BG_STATE_IN_PROGRESS);
        else
            TransitionToState(BG_STATE_CLEANUP);
    }
    else
    {
        _warmupTimeRemaining -= diff;

        // Send periodic warmup notifications
        uint32 remainingSeconds = _warmupTimeRemaining / IN_MILLISECONDS;
        if (remainingSeconds == 60 || remainingSeconds == 30 || remainingSeconds == 10)
        {
            BroadcastToZone("Hinterland BG warmup: %u seconds remaining!", remainingSeconds);
        }
    }
}

void OutdoorPvPHL::EnterInProgressState()
{
    // Set match timer
    _matchStartTime = NowSec();
    _matchEndTime = _matchStartTime + _matchDurationSeconds;

    // Announce battle start
    BroadcastToZone("Hinterland BG: Battle has begun! Current affix: %s", GetAffixName(_activeAffix));

    // Apply affix effects if enabled
    if (_affixEnabled)
    {
        _applyAffixEffects();
        if (_affixWeatherEnabled)
            ApplyAffixWeather();
    }

    // HUD worldstates removed - now handled by addon
    // UpdateWorldStatesAllPlayers();
}

void OutdoorPvPHL::UpdateInProgressState(uint32 diff)
{
    // Check for battle end conditions
    if (_ally_gathered == 0)
    {
        if (!_winnerRecorded)
            _recordWinner(TEAM_HORDE);
        TransitionToState(BG_STATE_FINISHED);
        return;
    }

    if (_horde_gathered == 0)
    {
        if (!_winnerRecorded)
            _recordWinner(TEAM_ALLIANCE);
        TransitionToState(BG_STATE_FINISHED);
        return;
    }

    // Check for timer expiry
    if (NowSec() >= _matchEndTime)
    {
        // Determine winner by resources
        if (_ally_gathered > _horde_gathered)
        {
            if (!_winnerRecorded)
                _recordWinner(TEAM_ALLIANCE);
        }
        else if (_horde_gathered > _ally_gathered)
        {
            if (!_winnerRecorded)
                _recordWinner(TEAM_HORDE);
        }
        else
        {
            if (!_winnerRecorded)
                _recordWinner(TEAM_NEUTRAL); // Draw
        }

        TransitionToState(BG_STATE_FINISHED);
        return;
    }

    // Update affix rotation if enabled
    if (_affixEnabled && _affixPeriodSec > 0)
    {
        if (_affixTimerMs <= diff)
        {
            // Use the internal affix selector declared in the class
            _selectAffixForNewBattle();
            _affixTimerMs = _affixPeriodSec * IN_MILLISECONDS;
        }
        else
        {
            _affixTimerMs -= diff;
        }
    }
}

void OutdoorPvPHL::EnterPausedState()
{
    BroadcastToZone("Hinterland BG: Battle paused by administrator.");
    // Store pause time to adjust match end time when resumed
    _pauseStartTime = NowSec();
}

void OutdoorPvPHL::UpdatePausedState(uint32 /*diff*/)
{
    // Wait for admin command to resume or reset
    // No automatic transitions from paused state
}

void OutdoorPvPHL::EnterFinishedState()
{
    // Clear affix effects
    if (_affixEnabled)
        _clearAffixEffects();

    // Award rewards
    TeamId winner = GetLastWinnerTeamId();
    if (winner != TEAM_NEUTRAL)
    {
        BroadcastToZone("Hinterland BG: %s wins!", winner == TEAM_ALLIANCE ? "Alliance" : "Horde");
        HandleRewards(winner);
    }
    else
    {
        BroadcastToZone("Hinterland BG: Battle ends in a draw!");
    }

    // Start cleanup timer (5 seconds)
    _cleanupTimeRemaining = 5000;
}

void OutdoorPvPHL::UpdateFinishedState(uint32 diff)
{
    if (_cleanupTimeRemaining <= diff)
    {
        TransitionToState(BG_STATE_CLEANUP);
    }
    else
    {
        _cleanupTimeRemaining -= diff;
    }
}

void OutdoorPvPHL::EnterCleanupState()
{
    // Cleanup: reset the zone state and wait for players/queue to trigger warmup.
    // Warmup is the between-matches preparation window.
    HandleReset();
    // Ensure we don't show a full match countdown while idling in cleanup.
    _matchStartTime = 0;
    _matchEndTime = NowSec();
}

void OutdoorPvPHL::UpdateCleanupState(uint32 /*diff*/)
{
    // In cleanup state, we're waiting for next battle
    // Process the queue system to check if we should start warmup
    ProcessQueueSystem();

    // Also allow warmup to start as soon as at least one player is present in-zone.
    // This keeps the battleground from running empty, while still starting promptly
    // once someone joins.
    if (_bgState == BG_STATE_CLEANUP && _playersInZone > 0)
        TransitionToState(BG_STATE_WARMUP);
}

// Admin commands for state management
void OutdoorPvPHL::PauseBattle()
{
    if (_bgState == BG_STATE_IN_PROGRESS)
    {
        TransitionToState(BG_STATE_PAUSED);
    }
}

void OutdoorPvPHL::ResumeBattle()
{
    if (_bgState == BG_STATE_PAUSED)
    {
        // Adjust match end time by pause duration
        uint32 pauseDuration = NowSec() - _pauseStartTime;
        _matchEndTime += pauseDuration;
        TransitionToState(BG_STATE_IN_PROGRESS);
    }
}

void OutdoorPvPHL::ForceFinishBattle(TeamId winner)
{
    if (_bgState == BG_STATE_IN_PROGRESS || _bgState == BG_STATE_PAUSED)
    {
        if (winner != TEAM_NEUTRAL)
            if (!_winnerRecorded) _recordWinner(winner);
        TransitionToState(BG_STATE_FINISHED);
    }
}

const char* OutdoorPvPHL::GetAffixName(AffixType affix) const
{
    return HinterlandBGConstants::GetAffixName(static_cast<uint8>(affix));
}

void OutdoorPvPHL::BroadcastToZone(const char* format, ...)
{
    va_list args;
    va_start(args, format);
    char buffer[512];
    vsnprintf(buffer, sizeof(buffer), format, args);
    va_end(args);

    if (Map* m = GetMap())
    {
        std::string msg = GetBgChatPrefix() + buffer;
        m->SendZoneText(OutdoorPvPHLBuffZones[0], msg.c_str());
    }
}

// ============================================================================
// State Persistence for Crash Recovery
// ============================================================================

void OutdoorPvPHL::_persistState() const
{
    // Persist current BG state to database. On server restart, LoadPersistedBGState
    // can restore partial battles (e.g. IN_PROGRESS) and handle gracefully.
    // Key: zone_id, Values: state, alliance_score, horde_score, time_remaining

    CharacterDatabase.Execute(
        "REPLACE INTO dc_hlbg_state (zone_id, bg_state, alliance_score, horde_score, "
        "match_time_remaining_ms, warmup_time_remaining_ms, affix_id, updated_at) "
        "VALUES ({}, {}, {}, {}, {}, {}, {}, NOW())",
        OutdoorPvPHLBuffZones[0],
        static_cast<uint8>(_bgState),
        limit_A,
        limit_H,
        (GetTimeRemainingSeconds() * 1000),
        _warmupTimeRemaining,
        static_cast<uint8>(_activeAffix)
    );
}

void OutdoorPvPHL::LoadPersistedBGState()
{
    // Load persisted state on server startup. If a battle was in progress,
    // we can either resume or gracefully transition to cleanup.

    QueryResult result = CharacterDatabase.Query(
        "SELECT bg_state, alliance_score, horde_score, match_time_remaining_ms, "
        "warmup_time_remaining_ms, affix_id, UNIX_TIMESTAMP(updated_at) as updated_ts "
        "FROM dc_hlbg_state WHERE zone_id = {} LIMIT 1",
        OutdoorPvPHLBuffZones[0]
    );

    if (!result)
    {
        LOG_INFO("outdoorpvp.hl", "[HL] No persisted state found, starting fresh in CLEANUP");
        _bgState = BG_STATE_CLEANUP;
        return;
    }

    Field* fields = result->Fetch();
    BGState savedState = static_cast<BGState>(fields[0].Get<uint8>());
    uint32 savedAllianceScore = fields[1].Get<uint32>();
    uint32 savedHordeScore = fields[2].Get<uint32>();
    uint32 savedMatchTime = fields[3].Get<uint32>();
    uint32 savedWarmupTime = fields[4].Get<uint32>();
    uint8 savedAffix = fields[5].Get<uint8>();
    uint32 savedTimestamp = fields[6].Get<uint32>();

    uint32 now = static_cast<uint32>(GameTime::GetGameTime().count());
    uint32 elapsed = now - savedTimestamp;

    LOG_INFO("outdoorpvp.hl", "[HL] Loading persisted state: {} (saved {}s ago)",
        static_cast<uint32>(savedState), elapsed);

    // Handle edge cases based on saved state
    switch (savedState)
    {
        case BG_STATE_IN_PROGRESS:
        {
            // If battle was in progress but more than 5 minutes elapsed, abandon it
            if (elapsed > 300)
            {
                LOG_INFO("outdoorpvp.hl", "[HL] Battle expired during downtime, transitioning to CLEANUP");
                _bgState = BG_STATE_CLEANUP;
                HandleReset();
            }
            else
            {
                // Resume battle with adjusted time
                _allianceScore = savedAllianceScore;
                _hordeScore = savedHordeScore;
                _matchTimeRemaining = (savedMatchTime > elapsed * 1000) ? savedMatchTime - elapsed * 1000 : 0;
                _activeAffix = static_cast<AffixType>(savedAffix);
                _bgState = BG_STATE_IN_PROGRESS;
                LOG_INFO("outdoorpvp.hl", "[HL] Resuming battle with {} ms remaining", _matchTimeRemaining);
            }
            break;
        }
        case BG_STATE_WARMUP:
        {
            // If warmup, check if it should have expired
            if (elapsed * 1000 >= savedWarmupTime)
            {
                LOG_INFO("outdoorpvp.hl", "[HL] Warmup expired during downtime, resetting to CLEANUP");
                _bgState = BG_STATE_CLEANUP;
            }
            else
            {
                _warmupTimeRemaining = savedWarmupTime - elapsed * 1000;
                _bgState = BG_STATE_WARMUP;
            }
            break;
        }
        case BG_STATE_FINISHED:
        case BG_STATE_PAUSED:
        {
            // These states should transition to cleanup on restart
            LOG_INFO("outdoorpvp.hl", "[HL] Saved state {} after restart, going to CLEANUP", static_cast<uint32>(savedState));
            _bgState = BG_STATE_CLEANUP;
            HandleReset();
            break;
        }
        case BG_STATE_CLEANUP:
        default:
        {
            _bgState = BG_STATE_CLEANUP;
            break;
        }
    }
}
