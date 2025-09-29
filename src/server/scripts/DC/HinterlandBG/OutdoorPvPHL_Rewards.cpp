// -----------------------------------------------------------------------------
// OutdoorPvPHL_Rewards.cpp
// -----------------------------------------------------------------------------
// Rewards and combat helpers:
// - Legacy per-player HandleRewards/HandleBuffs compatibility APIs.
// - Team-based end-of-match rewards with optional token grant.
// - Randomizer(): assigns variable honor on applicable kills.
// - HandleKill(): player and NPC kill handling with HUD refresh.
// -----------------------------------------------------------------------------
#include "HinterlandBG.h"            // DC wrapper to the canonical OutdoorPvPHL
#include "ObjectAccessor.h"
#include "Player.h"
#include "World.h"
#include "WorldSessionMgr.h"
#include "SharedDefines.h"
#include <algorithm>
#include <cstdio>

// Resource adjustments are configurable via hinterlandbg.conf

// Honor amounts are now driven by config fields on OutdoorPvPHL; no local constants needed.

// Legacy per-player reward entrypoint kept for compatibility with calls in OutdoorPvPHL.cpp
// honorpointsorarena: amount to grant (used for honor in this core);
// honor/arena/both: original flags from older script versions. We grant honor when (honor || both) is set.
// Legacy per-player reward entrypoint used by older code paths.
void OutdoorPvPHL::HandleRewards(Player* player, uint32 honorpointsorarena, bool honor, bool /*arena*/, bool both)
{
    if (!player)
        return;
    // Deny rewards for deserters or AFK (unless GM); callers already check in most paths, but be defensive
    if (!IsEligibleForRewards(player))
        return;
    if (!player->IsGameMaster() && GetAfkCount(player) >= 1)
    {
        Whisper(player, "|cffff0000AFK penalty: you receive no rewards.|r");
        return;
    }

    if ((honor || both) && honorpointsorarena > 0)
        player->RewardHonor(nullptr, 0, float(honorpointsorarena));
}

// Legacy per-player buff application (winner/loser) used by OutdoorPvPHL.cpp
// Legacy per-player buff application based on win/lose state.
void OutdoorPvPHL::HandleBuffs(Player* player, bool loser)
{
    if (!player)
        return;

    if (loser)
    {
        for (uint8 i = 0; i < LoseBuffsNum; ++i)
            player->AddAura(LoseBuffs[i], player);
    }
    else
    {
        for (uint8 i = 0; i < WinBuffsNum; ++i)
            player->AddAura(WinBuffs[i], player);
    }
}

// Grant match-end rewards based on winning team; optional token to winners.
void OutdoorPvPHL::HandleRewards(TeamId winner)
{
    if (winner != TEAM_ALLIANCE && winner != TEAM_HORDE)
        return;

    TeamId loser = (winner == TEAM_ALLIANCE) ? TEAM_HORDE : TEAM_ALLIANCE;

    // Pick amounts by win condition.
    // Infer depletion when the loser reached 0 resources.
    bool depletion = (winner == TEAM_ALLIANCE) ? (_horde_gathered == 0) : (_ally_gathered == 0);
    const uint32 winHonor  = depletion ? _rewardMatchHonorDepletion : _rewardMatchHonorTiebreaker;
    const uint32 loseHonor = _rewardMatchHonorLoser;

    auto rewardTeam = [&](TeamId team, uint32 honor)
    {
        if (honor == 0)
            return;

        // OutdoorPvP base tracks participating players by team.
        for (auto const& guid : _players[team])
        {
            if (Player* plr = ObjectAccessor::FindPlayer(guid))
            {
                plr->RewardHonor(nullptr, 0, float(honor));
                // Optional: token reward for match participation/victory
                if (_rewardNpcTokenItemId && _rewardNpcTokenCount && team == winner)
                    plr->AddItem(_rewardNpcTokenItemId, _rewardNpcTokenCount);
            }
        }
    };

    rewardTeam(winner, winHonor);
    rewardTeam(loser,  loseHonor);
}

// Team-wide buff application hook (placeholder if needed by future logic).
void OutdoorPvPHL::HandleBuffs(TeamId /*winner*/)
{
    // Placeholder: existing buff logic remains in main file if any; this stub keeps the symbol during split.
}

// Global server-announcement helper for final scores; controlled via config.
void OutdoorPvPHL::HandleWinMessage(TeamId winner)
{
    // Broadcast a world announcement when configured, with final scores.
    if (winner == TEAM_NEUTRAL)
        return;

    // Infer again for messages
    bool depletion = (winner == TEAM_ALLIANCE) ? (_horde_gathered == 0) : (_ally_gathered == 0);
    if (depletion)
    {
        if (_worldAnnounceOnDepletion)
        {
            char msg[256];
            snprintf(msg, sizeof(msg), "Hinterland BG: %s win by resource depletion! Final score A:%u H:%u",
                     winner == TEAM_ALLIANCE ? "Alliance" : "Horde", _ally_gathered, _horde_gathered);
            sWorldSessionMgr->SendServerMessage(SERVER_MSG_STRING, msg);
        }
    }
    else
    {
        if (_worldAnnounceOnExpiry)
        {
            char msg[256];
            snprintf(msg, sizeof(msg), "Hinterland BG: %s win by tiebreaker at expiry! Final score A:%u H:%u",
                     winner == TEAM_ALLIANCE ? "Alliance" : "Horde", _ally_gathered, _horde_gathered);
            sWorldSessionMgr->SendServerMessage(SERVER_MSG_STRING, msg);
        }
    }
}

// marks the height of honour given for each NPC kill
// Assign a random honor amount for a kill using KillHonorValues config.
void OutdoorPvPHL::Randomizer(Player* player)
{
    switch (urand(0, 4))
    {
        case 0:
        {
            uint32 v = (_killHonorValues.size() > 0 ? _killHonorValues[0] : 17);
            HandleRewards(player, v, true, false, false);
        }
        break;
        case 1:
        {
            uint32 v = (_killHonorValues.size() > 1 ? _killHonorValues[1] : 11);
            HandleRewards(player, v, true, false, false);
        }
        break;
        case 2:
        {
            uint32 v = (_killHonorValues.size() > 2 ? _killHonorValues[2] : 19);
            HandleRewards(player, v, true, false, false);
        }
        break;
        case 3:
        {
            uint32 v = (_killHonorValues.size() > 3 ? _killHonorValues[3] : 22);
            HandleRewards(player, v, true, false, false);
        }
        break;
    }
}

// Handle kills affecting BG resources and rewards; refresh HUD afterwards.
void OutdoorPvPHL::HandleKill(Player* player, Unit* killed)
{
    if (!player || !killed)
        return;

    if (killed->GetTypeId() == TYPEID_PLAYER) // Killing players will take their Resources away. It also gives extra honor.
    {
        // prevent self-kill manipulation and ensure victim differs from killer
        if (player->GetGUID() == killed->GetGUID())
            return;

        switch (killed->ToPlayer()->GetTeamId())
        {
            case TEAM_ALLIANCE:
                _ally_gathered -= _resourcesLossPlayerKill;
                if (IsEligibleForRewards(player))
                {
                    if (!player->IsGameMaster() && GetAfkCount(player) >= 1)
                    {
                        Whisper(player, "|cffff0000AFK penalty: no rewards for kills.|r");
                    }
                    else
                    {
                        player->AddItem(40752, 1);
                        Randomizer(player);
                        if (_rewardKillItemId && _rewardKillItemCount)
                            player->AddItem(_rewardKillItemId, _rewardKillItemCount);
                    }
                }
                break;
            default: // Horde
                _horde_gathered -= _resourcesLossPlayerKill;
                if (IsEligibleForRewards(player))
                {
                    if (!player->IsGameMaster() && GetAfkCount(player) >= 1)
                    {
                        Whisper(player, "|cffff0000AFK penalty: no rewards for kills.|r");
                    }
                    else
                    {
                        Randomizer(player);
                        if (_rewardKillItemId && _rewardKillItemCount)
                            player->AddItem(_rewardKillItemId, _rewardKillItemCount);
                    }
                }
                break;
        }
        // Update HUD for all participants after resource change
        UpdateWorldStatesAllPlayers();
    }
    else // If is something besides a player
    {
        uint32 entry = killed->GetEntry();
        // Configured NPC token rewards (up to 10 entries per team via config)
        if (player->GetTeamId() == TEAM_ALLIANCE)
        {
            if (!_npcRewardEntriesHorde.empty() && std::find(_npcRewardEntriesHorde.begin(), _npcRewardEntriesHorde.end(), entry) != _npcRewardEntriesHorde.end())
            {
                if (_rewardNpcTokenItemId)
                {
                    uint32 count = _rewardNpcTokenCount;
                    auto itc = _npcRewardCountsHorde.find(entry);
                    if (itc != _npcRewardCountsHorde.end())
                        count = itc->second;
                    if (count)
                    {
                        player->AddItem(_rewardNpcTokenItemId, count);
                        Whisper(player, "You received " + std::to_string(count) + " token(s) for defeating a marked enemy NPC.");
                    }
                }
            }
        }
        else // TEAM_HORDE
        {
            if (!_npcRewardEntriesAlliance.empty() && std::find(_npcRewardEntriesAlliance.begin(), _npcRewardEntriesAlliance.end(), entry) != _npcRewardEntriesAlliance.end())
            {
                if (_rewardNpcTokenItemId)
                {
                    uint32 count = _rewardNpcTokenCount;
                    auto itc = _npcRewardCountsAlliance.find(entry);
                    if (itc != _npcRewardCountsAlliance.end())
                        count = itc->second;
                    if (count)
                    {
                        player->AddItem(_rewardNpcTokenItemId, count);
                        Whisper(player, "You received " + std::to_string(count) + " token(s) for defeating a marked enemy NPC.");
                    }
                }
            }
        }

        auto applyLoss = [&](TeamId victimTeam)
        {
            // Determine normal vs boss by victim team classification sets
            bool isBoss = false;
            bool isNormal = false;
            if (victimTeam == TEAM_HORDE)
            {
                isBoss   = _npcBossEntriesHorde.count(entry) > 0;
                isNormal = _npcNormalEntriesHorde.count(entry) > 0;
                if (isBoss)
                    _horde_gathered = (_horde_gathered > _resourcesLossNpcBoss) ? (_horde_gathered - _resourcesLossNpcBoss) : 0u;
                else if (isNormal)
                    _horde_gathered = (_horde_gathered > _resourcesLossNpcNormal) ? (_horde_gathered - _resourcesLossNpcNormal) : 0u;
            }
            else if (victimTeam == TEAM_ALLIANCE)
            {
                isBoss   = _npcBossEntriesAlliance.count(entry) > 0;
                isNormal = _npcNormalEntriesAlliance.count(entry) > 0;
                if (isBoss)
                    _ally_gathered = (_ally_gathered > _resourcesLossNpcBoss) ? (_ally_gathered - _resourcesLossNpcBoss) : 0u;
                else if (isNormal)
                    _ally_gathered = (_ally_gathered > _resourcesLossNpcNormal) ? (_ally_gathered - _resourcesLossNpcNormal) : 0u;
            }
            // Award random honor when a configured NPC type is killed
            if (isBoss || isNormal)
                Randomizer(player);
        };

        // Decide victim team by entry (Alliance list vs Horde list)
        if (_npcBossEntriesHorde.count(entry) || _npcNormalEntriesHorde.count(entry))
            applyLoss(TEAM_HORDE);
        else if (_npcBossEntriesAlliance.count(entry) || _npcNormalEntriesAlliance.count(entry))
            applyLoss(TEAM_ALLIANCE);
        // Update HUD for all participants after resource change
        UpdateWorldStatesAllPlayers();
    }
}
