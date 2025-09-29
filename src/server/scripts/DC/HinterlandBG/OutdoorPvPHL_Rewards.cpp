#include "HinterlandBG.h"            // DC wrapper to the canonical OutdoorPvPHL
#include "ObjectAccessor.h"
#include "Player.h"
#include "World.h"
#include "WorldSessionMgr.h"
#include "SharedDefines.h"

// Honor amounts are now driven by config fields on OutdoorPvPHL; no local constants needed.

// Legacy per-player reward entrypoint kept for compatibility with calls in OutdoorPvPHL.cpp
// honorpointsorarena: amount to grant (used for honor in this core);
// honor/arena/both: original flags from older script versions. We grant honor when (honor || both) is set.
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

void OutdoorPvPHL::HandleBuffs(TeamId /*winner*/)
{
    // Placeholder: existing buff logic remains in main file if any; this stub keeps the symbol during split.
}

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
                _ally_gathered -= PointsLoseOnPvPKill;
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
                _horde_gathered -= PointsLoseOnPvPKill;
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

        if (player->GetTeamId() == TEAM_ALLIANCE)
        {
            switch (entry) // Alliance killing horde guards
            {
                case Horde_Infantry:
                    _horde_gathered -= PointsLoseOnPvPKill;
                    Randomizer(player); // Randomizes the honor reward
                    break;
                case Horde_Squadleader: // 2?
                    _horde_gathered -= PointsLoseOnPvPKill;
                    Randomizer(player); // Randomizes the honor reward
                    break;
                case Horde_Boss:
                    _horde_gathered -= PointsLoseOnPvPKill;
                    /*BossReward(player); */
                    break;
                case Horde_Heal:
                    _horde_gathered -= PointsLoseOnPvPKill;
                    Randomizer(player); // Randomizes the honor reward
                    break;
            }
        }
        else // Team Horde
        {
            switch (entry) // Horde killing alliance guards
            {
                case Alliance_Healer:
                    _ally_gathered -= PointsLoseOnPvPKill;
                    Randomizer(player); // Randomizes the honor reward
                    break;
                case Alliance_Boss:
                    _ally_gathered -= PointsLoseOnPvPKill;
                    /*BossReward(player); <- NEU? */
                    break;
                case Alliance_Infantry:
                    _ally_gathered -= PointsLoseOnPvPKill;
                    Randomizer(player); // Randomizes the honor reward
                    break;
                case Alliance_Squadleader: // Wrong?
                    _ally_gathered -= PointsLoseOnPvPKill;
                    Randomizer(player); // Randomizes the honor reward
                    break;
            }
        }
        // Update HUD for all participants after resource change
        UpdateWorldStatesAllPlayers();
    }
}
