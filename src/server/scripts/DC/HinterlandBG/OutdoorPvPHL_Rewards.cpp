#include "HinterlandBG.h"            // DC wrapper to the canonical OutdoorPvPHL
#include "ObjectAccessor.h"
#include "Player.h"
#include "World.h"
#include "SharedDefines.h"

// Honor amounts are now driven by config fields on OutdoorPvPHL; no local constants needed.

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
            sWorld->SendWorldText(
                LANG_SYSTEMMESSAGE,
                "Hinterland BG: %s win by resource depletion! Final score A:%u H:%u",
                winner == TEAM_ALLIANCE ? "Alliance" : "Horde", _ally_gathered, _horde_gathered);
        }
    }
    else
    {
        if (_worldAnnounceOnExpiry)
        {
            sWorld->SendWorldText(
                LANG_SYSTEMMESSAGE,
                "Hinterland BG: %s win by tiebreaker at expiry! Final score A:%u H:%u",
                winner == TEAM_ALLIANCE ? "Alliance" : "Horde", _ally_gathered, _horde_gathered);
        }
    }
}
