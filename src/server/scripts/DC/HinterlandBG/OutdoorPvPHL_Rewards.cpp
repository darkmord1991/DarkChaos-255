#include "OutdoorPvP/OutdoorPvPHL.h"
#include "WorldSessionMgr.h"

void OutdoorPvPHL::HandleRewards(TeamId winner)
{
    // Applies victory rewards based on win condition; uses split rewards for depletion vs tiebreaker expiry when configured.
    auto grant = [&](Player* p)
    {
        if (!p) return;
        if (winner == TEAM_NEUTRAL) return;
        if (p->GetTeamId() != winner) return;
        if (_winConditionWasDepletion)
        {
            if (_rewardDepletionHonor > 0)
                p->RewardHonor(nullptr, 1, _rewardDepletionHonor);
            if (_rewardDepletionItemId && _rewardDepletionItemCount)
                p->AddItem(_rewardDepletionItemId, _rewardDepletionItemCount);
        }
        else
        {
            if (_rewardTiebreakHonor > 0)
                p->RewardHonor(nullptr, 1, _rewardTiebreakHonor);
            if (_rewardTiebreakItemId && _rewardTiebreakItemCount)
                p->AddItem(_rewardTiebreakItemId, _rewardTiebreakItemCount);
        }
    };

    ForEachPlayerInZone(grant);
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
            sWorld->SendWorldText(LANG_SYSTEMMESSAGE, "Hinterland BG: %s win by resource depletion! Final score A:%u H:%u", winner == TEAM_ALLIANCE ? "Alliance" : "Horde", _ally_gathered, _horde_gathered);
        }
    }
    else
    {
        if (_worldAnnounceOnExpiry)
        {
            sWorld->SendWorldText(LANG_SYSTEMMESSAGE, "Hinterland BG: %s win by tiebreaker at expiry! Final score A:%u H:%u", winner == TEAM_ALLIANCE ? "Alliance" : "Horde", _ally_gathered, _horde_gathered);
        }
    }
}
