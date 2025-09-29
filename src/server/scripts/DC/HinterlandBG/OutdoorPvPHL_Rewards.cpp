#include "OutdoorPvP/OutdoorPvPHL.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "World.h"
#include "SharedDefines.h"

namespace
{
    // Honor amounts (tune as needed)
    constexpr uint32 HONOR_WIN_DEPLETION = 120;   // winner when resources depleted
    constexpr uint32 HONOR_WIN_EXPIRY    = 70;    // winner on time expiry / tiebreaker
    constexpr uint32 HONOR_LOSE_GENERIC  = 20;    // consolation for the losing side
}

void OutdoorPvPHL::HandleRewards(TeamId winner)
{
    if (winner != TEAM_ALLIANCE && winner != TEAM_HORDE)
        return;

    TeamId loser = (winner == TEAM_ALLIANCE) ? TEAM_HORDE : TEAM_ALLIANCE;

    // Pick amounts by win condition.
    const uint32 winHonor  = _winConditionWasDepletion ? HONOR_WIN_DEPLETION : HONOR_WIN_EXPIRY;
    const uint32 loseHonor = HONOR_LOSE_GENERIC;

    auto rewardTeam = [&](TeamId team, uint32 honor)
    {
        if (honor == 0)
            return;

        // OutdoorPvP base tracks participating players by team.
        for (auto const& guid : m_players[team])
        {
            if (Player* plr = ObjectAccessor::FindPlayer(guid))
                plr->RewardHonor(nullptr, 0, float(honor));
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

    if (_winConditionWasDepletion)
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
