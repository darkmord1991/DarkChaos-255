// -----------------------------------------------------------------------------
// OutdoorPvPHL_StateMachine.cpp
// -----------------------------------------------------------------------------
// Finite state machine for HLBG to manage battleground lifecycle
// States: Warmup → InProgress → Paused → Finished → Cleanup
// -----------------------------------------------------------------------------
#include "HinterlandBG.h"
#include "Chat.h"

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

    BGState oldState = _bgState;
    _bgState = newState;
    
    LOG_INFO("outdoorpvp.hl", "[HL] State transition: {} -> {}", 
        static_cast<uint32>(oldState), static_cast<uint32>(newState));

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
    
    // Announce warmup phase
    BroadcastToZone("Hinterland BG: Warmup phase started! Join now to participate.");
    
    // Reset battle statistics
    _playerScores.clear();
    _playerHKBaseline.clear();
    
    // Enable queue system notifications
    _queueEnabled = true;
}

void OutdoorPvPHL::UpdateWarmupState(uint32 diff)
{
    if (_warmupTimeRemaining <= diff)
    {
        // Warmup finished, start battle
        TransitionToState(BG_STATE_IN_PROGRESS);
    }
    else
    {
        _warmupTimeRemaining -= diff;
        
        // Send periodic warmup notifications
        uint32 remainingSeconds = _warmupTimeRemaining / IN_MILLISECONDS;
        if (remainingSeconds == 60 || remainingSeconds == 30 || remainingSeconds == 10)
        {
            BroadcastToZone("Hinterland BG warmup: {} seconds remaining!", remainingSeconds);
        }
    }
}

void OutdoorPvPHL::EnterInProgressState()
{
    // Set match timer
    _matchStartTime = NowSec();
    _matchEndTime = _matchStartTime + _matchDurationSeconds;
    
    // Disable queue (battle in progress)
    _queueEnabled = false;
    
    // Announce battle start
    BroadcastToZone("Hinterland BG: Battle has begun! Current affix: {}", GetAffixName(_activeAffix));
    
    // Apply affix effects if enabled
    if (_affixEnabled)
    {
        _applyAffixEffects();
        if (_affixWeatherEnabled)
            ApplyAffixWeather();
    }
}

void OutdoorPvPHL::UpdateInProgressState(uint32 diff)
{
    // Check for battle end conditions
    if (_ally_gathered == 0)
    {
        _recordWinner(TEAM_HORDE);
        TransitionToState(BG_STATE_FINISHED);
        return;
    }
    
    if (_horde_gathered == 0)
    {
        _recordWinner(TEAM_ALLIANCE);
        TransitionToState(BG_STATE_FINISHED);
        return;
    }
    
    // Check for timer expiry
    if (NowSec() >= _matchEndTime)
    {
        // Determine winner by resources
        if (_ally_gathered > _horde_gathered)
            _recordWinner(TEAM_ALLIANCE);
        else if (_horde_gathered > _ally_gathered)
            _recordWinner(TEAM_HORDE);
        else
            _recordWinner(TEAM_NEUTRAL); // Draw
            
        TransitionToState(BG_STATE_FINISHED);
        return;
    }
    
    // Update affix rotation if enabled
    if (_affixEnabled && _affixPeriodSec > 0)
    {
        if (_affixTimerMs <= diff)
        {
            RotateAffix();
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
        BroadcastToZone("Hinterland BG: {} wins!", winner == TEAM_ALLIANCE ? "Alliance" : "Horde");
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
    // Reset to warmup for next battle
    HandleReset();
    TransitionToState(BG_STATE_WARMUP);
}

void OutdoorPvPHL::UpdateCleanupState(uint32 /*diff*/)
{
    // In cleanup state, we're waiting for next battle
    // Process the queue system to check if we should start warmup
    ProcessQueueSystem();
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
            _recordWinner(winner);
        TransitionToState(BG_STATE_FINISHED);
    }
}

const char* OutdoorPvPHL::GetAffixName(AffixType affix) const
{
    switch (affix)
    {
        case AFFIX_HASTE_BUFF: return "Haste";
        case AFFIX_SLOW: return "Slow";
        case AFFIX_REDUCED_HEALING: return "Reduced Healing";
        case AFFIX_REDUCED_ARMOR: return "Reduced Armor";
        case AFFIX_BOSS_ENRAGE: return "Boss Enrage";
        default: return "None";
    }
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