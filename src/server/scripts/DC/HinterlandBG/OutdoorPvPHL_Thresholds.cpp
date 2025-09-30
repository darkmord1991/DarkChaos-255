// -----------------------------------------------------------------------------
// OutdoorPvPHL_Thresholds.cpp
// -----------------------------------------------------------------------------
// Resource threshold announcements and win shouts:
// - Emits emote-style notices at 300/200/100 and 50/0 thresholds per team.
// - On depletion (0 resources), announces zone + optional world message and
//   applies rewards/buffs via legacy APIs.
// -----------------------------------------------------------------------------
#include "HinterlandBG.h"
#include "Chat.h"
#include "WorldSessionMgr.h"
#include <cstdio>

// Periodic announcement tick for resource thresholds and depletion.
void OutdoorPvPHL::_tickThresholdAnnouncements()
{
    if (_lockEnabled && _isLocked)
        return;
    if(_ally_gathered <= 50 && limit_A == 0)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true;
        IS_RESOURCE_MESSAGE_A = true;
        limit_A = 1;
        PlaySounds(false);
    }
    else if(_horde_gathered <= 50 && limit_H == 0)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true;
        IS_RESOURCE_MESSAGE_H = true;
        limit_H = 1;
        PlaySounds(true);
    }
    else if(_ally_gathered <= 0 && limit_A == 1)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true;
        IS_RESOURCE_MESSAGE_A = true;
        limit_A = 2;
        PlaySounds(false);
    }
    else if(_horde_gathered <= 0 && limit_H == 1)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true;
        IS_RESOURCE_MESSAGE_H = true;
        limit_H = 2;
        PlaySounds(true);
    }
    else if(_ally_gathered <= 300 && limit_resources_message_A == 0)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true;
        limit_resources_message_A = 1;
        PlaySounds(false);
    }
    else if(_horde_gathered <= 300 && limit_resources_message_H == 0)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true;
        limit_resources_message_H = 1;
        PlaySounds(true);
    }
    else if(_ally_gathered <= 200 && limit_resources_message_A == 1)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true;
        limit_resources_message_A = 2;
        PlaySounds(false);
    }
    else if(_horde_gathered <= 200 && limit_resources_message_H == 1)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true;
        limit_resources_message_H = 2;
        PlaySounds(true);
    }
    else if(_ally_gathered <= 100 && limit_resources_message_A == 2)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true;
        limit_resources_message_A = 3;
        PlaySounds(false);
    }
    else if(_horde_gathered <= 100 && limit_resources_message_H == 2)
    {
        IS_ABLE_TO_SHOW_MESSAGE = true;
        limit_resources_message_H = 3;
        PlaySounds(true);
    }

    if(IS_ABLE_TO_SHOW_MESSAGE == true)
    {
        WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
        for (WorldSessionMgr::SessionMap::const_iterator itr = sessionMap.begin(); itr != sessionMap.end(); ++itr)
        {
            if(!itr->second || !itr->second->GetPlayer() || !itr->second->GetPlayer()->IsInWorld() ||
                itr->second->GetPlayer()->GetZoneId() != 47)
                continue;

            if(itr->second->GetPlayer()->GetZoneId() == 47)
            {
                if(limit_resources_message_A == 1 || limit_resources_message_A == 2 || limit_resources_message_A == 3)
                {
                    char line[160];
                    snprintf(line, sizeof(line), "|cff1e90ff[Hinterland Defence]: The Alliance has resources left! (Alliance=%u, Horde=%u)|r", (unsigned)_ally_gathered, (unsigned)_horde_gathered);
                    itr->second->GetPlayer()->TextEmote((GetBgChatPrefix() + std::string(line)).c_str());
                }
                else if(limit_resources_message_H == 1 || limit_resources_message_H == 2 || limit_resources_message_H == 3)
                {
                    char line[160];
                    snprintf(line, sizeof(line), "|cffff0000[Hinterland Defence]: The Horde has resources left! (Alliance=%u, Horde=%u)|r", (unsigned)_ally_gathered, (unsigned)_horde_gathered);
                    itr->second->GetPlayer()->TextEmote((GetBgChatPrefix() + std::string(line)).c_str());
                }

                if(IS_RESOURCE_MESSAGE_A == true)
                {
                    if(limit_A == 1)
                    {
                        char line[160];
                        snprintf(line, sizeof(line), "|cff1e90ff[Hinterland Defence]: The Alliance has resources left! (Alliance=%u, Horde=%u)|r", (unsigned)_ally_gathered, (unsigned)_horde_gathered);
                        itr->second->GetPlayer()->TextEmote((GetBgChatPrefix() + std::string(line)).c_str());
                        IS_RESOURCE_MESSAGE_A = false;
                    }
                    else if(limit_A == 2)
                    {
                        char line[200];
                        snprintf(line, sizeof(line), "|cff1e90ff[Hinterland Defence]: The Alliance has no more resources left! (Alliance=%u, Horde=%u)|r |cffff0000Horde wins!|r", (unsigned)_ally_gathered, (unsigned)_horde_gathered);
                        itr->second->GetPlayer()->TextEmote((GetBgChatPrefix() + std::string(line)).c_str());
                        if (_worldAnnounceOnDepletion)
                        {
                            char announce[200];
                            snprintf(announce, sizeof(announce), "[Hinterland BG] Horde victory by depletion! Final score: Alliance %u — Horde %u", (unsigned)_ally_gathered, (unsigned)_horde_gathered);
                            ChatHandler(nullptr).SendGlobalSysMessage(announce);
                        }
                        HandleWinMessage("|cffff0000For the HORDE!|r");
                        HandleRewards(itr->second->GetPlayer(), _rewardMatchHonorDepletion, true, false, false);
                        switch(itr->second->GetPlayer()->GetTeamId())
                        {
                            case TEAM_ALLIANCE:
                                HandleBuffs(itr->second->GetPlayer(), true);
                                break;
                            default:
                                HandleBuffs(itr->second->GetPlayer(), false);
                                break;
                        }
                        _LastWin = HORDE;
                        _recordWinner(TEAM_HORDE);
                        // Schedule lock/reset processing in Update()
                        _pendingLockFromDepletion = true;
                        _pendingDepletionWinner = TEAM_HORDE;
                        IS_RESOURCE_MESSAGE_A = false;
                    }
                }
                else if(IS_RESOURCE_MESSAGE_H == true)
                {
                    if(limit_H == 1)
                    {
                        char line[160];
                        snprintf(line, sizeof(line), "|cffff0000[Hinterland Defence]: The Horde has resources left! (Alliance=%u, Horde=%u)|r", (unsigned)_ally_gathered, (unsigned)_horde_gathered);
                        itr->second->GetPlayer()->TextEmote((GetBgChatPrefix() + std::string(line)).c_str());
                        IS_RESOURCE_MESSAGE_H = false;
                    }
                    else if(limit_H == 2)
                    {
                        char line[200];
                        snprintf(line, sizeof(line), "|cffff0000[Hinterland Defence]: The Horde has no more resources left! (Alliance=%u, Horde=%u)|r |cff1e90ffAlliance wins!|r", (unsigned)_ally_gathered, (unsigned)_horde_gathered);
                        itr->second->GetPlayer()->TextEmote((GetBgChatPrefix() + std::string(line)).c_str());
                        if (_worldAnnounceOnDepletion)
                        {
                            char announce[200];
                            snprintf(announce, sizeof(announce), "[Hinterland BG] Alliance victory by depletion! Final score: Alliance %u — Horde %u", (unsigned)_ally_gathered, (unsigned)_horde_gathered);
                            ChatHandler(nullptr).SendGlobalSysMessage(announce);
                        }
                        HandleWinMessage("|cff1e90ffFor the Alliance!|r");
                        HandleRewards(itr->second->GetPlayer(), _rewardMatchHonorDepletion, true, false, false);
                        switch(itr->second->GetPlayer()->GetTeamId())
                        {
                            case TEAM_ALLIANCE:
                                HandleBuffs(itr->second->GetPlayer(), false);
                                break;
                            default:
                                HandleBuffs(itr->second->GetPlayer(), true);
                                break;
                        }
                        _LastWin = ALLIANCE;
                        _recordWinner(TEAM_ALLIANCE);
                        _pendingLockFromDepletion = true;
                        _pendingDepletionWinner = TEAM_ALLIANCE;
                        IS_RESOURCE_MESSAGE_H = false;
                    }
                }
            }
        }
    }

    IS_ABLE_TO_SHOW_MESSAGE = false;
}
