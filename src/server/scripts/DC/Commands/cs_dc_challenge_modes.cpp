/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Customized for DarkChaos-255 by darkmord1991
 *
 * cs_dc_challenge_modes.cpp - Commands for Challenge Mode system
 * Separated from ChallengeModeScripts.cpp for consistency with cs_dc_* pattern
 */

#include "ScriptMgr.h"
#include "Chat.h"
#include "CommandScript.h"
#include "Player.h"
#include "DC/Progression/ChallengeMode/dc_challenge_modes.h"

using namespace Acore::ChatCommands;

class dc_challenge_modes_commandscript : public CommandScript
{
public:
    dc_challenge_modes_commandscript() : CommandScript("dc_challenge_modes_commandscript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable commandTable =
        {
            { "challenge", HandleChallengeInfoCommand, SEC_PLAYER, Console::No }
        };
        return commandTable;
    }

    static bool HandleChallengeInfoCommand(ChatHandler* handler, char const* /*args*/)
    {
        Player* player = handler->GetSession()->GetPlayer();

        handler->PSendSysMessage("|cff00ff00========================================|r");
        handler->PSendSysMessage("|cff00ff00   ACTIVE CHALLENGE MODES|r");
        handler->PSendSysMessage("|cff00ff00========================================|r");

        bool hasAnyChallenges = false;

        // Check each challenge type
        if (sChallengeModes->challengeEnabledForPlayer(SETTING_HARDCORE, player))
        {
            handler->PSendSysMessage("|cffFF0000[HARDCORE]|r Active - One life only!");
            hasAnyChallenges = true;
        }

        if (sChallengeModes->challengeEnabledForPlayer(SETTING_SEMI_HARDCORE, player))
        {
            handler->PSendSysMessage("|cffFF8800[SEMI-HARDCORE]|r Active - Death = Gear loss");
            hasAnyChallenges = true;
        }

        if (sChallengeModes->challengeEnabledForPlayer(SETTING_SELF_CRAFTED, player))
        {
            handler->PSendSysMessage("|cff00ffff[SELF-CRAFTED]|r Active - Crafted gear only");
            hasAnyChallenges = true;
        }

        if (sChallengeModes->challengeEnabledForPlayer(SETTING_ITEM_QUALITY_LEVEL, player))
        {
            handler->PSendSysMessage("|cffaaaaaa[ITEM QUALITY]|r Active - White/gray only");
            hasAnyChallenges = true;
        }

        if (sChallengeModes->challengeEnabledForPlayer(SETTING_SLOW_XP_GAIN, player))
        {
            handler->PSendSysMessage("|cff8888ff[SLOW XP]|r Active - 50%% XP rate");
            hasAnyChallenges = true;
        }

        if (sChallengeModes->challengeEnabledForPlayer(SETTING_VERY_SLOW_XP_GAIN, player))
        {
            handler->PSendSysMessage("|cff4444ff[VERY SLOW XP]|r Active - 25%% XP rate");
            hasAnyChallenges = true;
        }

        if (sChallengeModes->challengeEnabledForPlayer(SETTING_QUEST_XP_ONLY, player))
        {
            handler->PSendSysMessage("|cff00ff88[QUEST XP ONLY]|r Active - Quests only");
            hasAnyChallenges = true;
        }

        if (sChallengeModes->challengeEnabledForPlayer(SETTING_IRON_MAN, player))
        {
            handler->PSendSysMessage("|cffFFD700[IRON MAN]|r Active - Ultimate challenge!");
            hasAnyChallenges = true;
        }

        if (!hasAnyChallenges)
        {
            handler->PSendSysMessage("No active challenge modes.");
            handler->PSendSysMessage("Visit a Challenge Shrine to begin your journey!");
        }

        handler->PSendSysMessage("|cff00ff00========================================|r");

        return true;
    }
};

void AddSC_dc_challenge_modes_commandscript()
{
    new dc_challenge_modes_commandscript();
}
