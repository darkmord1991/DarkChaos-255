/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Customized for DarkChaos-255 by darkmord1991
 * 
 * ChallengeModeScripts.cpp - Player scripts for Challenge Mode system
 * Split from dc_challenge_modes_customized.cpp
 */

#include "dc_challenge_modes.h"
#include "dc_challenge_mode_database.h"
#include "World.h"
#include "WorldSessionMgr.h"
#include "Chat.h"

using namespace Acore::ChatCommands;

// ==============================================
// DarkChaos-255: HARDCORE CHARACTER LOCKING
// ==============================================
void HandleHardcoreDeath(Player* victim, uint32 killerEntry, std::string const& killerName)
{
    if (!victim)
        return;

    // Mark character as permanently dead
    victim->UpdatePlayerSetting("mod-challenge-modes", HARDCORE_DEAD, 1);
    sChallengeModes->RefreshChallengeAuras(victim);

    // Persist in challenge mode DB tracking (authoritative lock)
    ChallengeModeDatabase::InitializeTracking(victim->GetGUID());
    ChallengeModeDatabase::SyncActiveModesFromSettings(victim);
    ChallengeModeDatabase::RecordHardcoreDeath(victim->GetGUID(), victim, killerEntry, killerName);
    ChallengeModeDatabase::LockCharacter(victim->GetGUID());

    // Global announcement
    std::ostringstream ss;
    ss << "|cffFF0000[HARDCORE DEATH]|r " << victim->GetName()
       << " has fallen at level " << (uint32)victim->GetLevel() << "! "
       << "Killed by " << killerName << ". "
       << "RIP - May they rest in peace.";
    sWorldSessionMgr->SendServerMessage(SERVER_MSG_STRING, ss.str());

    // Show final stats to player
    ChatHandler(victim->GetSession()).PSendSysMessage("|cffFF0000========================================|r");
    ChatHandler(victim->GetSession()).PSendSysMessage("|cffFF0000   HARDCORE CHARACTER - DECEASED   |r");
    ChatHandler(victim->GetSession()).PSendSysMessage("|cffFF0000========================================|r");
    ChatHandler(victim->GetSession()).PSendSysMessage("|cffFFFF00Final Level: |cffFF0000%u", (uint32)victim->GetLevel());
    ChatHandler(victim->GetSession()).PSendSysMessage("|cffFFFF00Killed by: |cffFF0000%s", killerName.c_str());
    ChatHandler(victim->GetSession()).PSendSysMessage("|cffFF0000This character is now PERMANENTLY LOCKED.|r");
    ChatHandler(victim->GetSession()).PSendSysMessage("|cffFF0000You will not be able to log in with this character anymore.|r");
    ChatHandler(victim->GetSession()).PSendSysMessage("|cffFF0000========================================|r");
}

// Hardcore mode player script
class ChallengeMode_Hardcore : public PlayerScript
{
public:
    ChallengeMode_Hardcore() : PlayerScript("ChallengeMode_Hardcore") { }

    void OnPlayerJustDied(Player* player) override
    {
        if (!player)
            return;

        if (!sChallengeModes->challengeEnabledForPlayer(SETTING_HARDCORE, player))
            return;

        // If we already processed the death (e.g., creature/PvP callbacks), don't run twice.
        if (player->GetPlayerSetting("mod-challenge-modes", HARDCORE_DEAD).value == 1)
            return;

        HandleHardcoreDeath(player, 0, "Environment");
        player->SetPvPDeath(true);
    }

    void OnPlayerKilledByCreature(Creature* killer, Player* victim) override
    {
        if (!sChallengeModes->challengeEnabledForPlayer(SETTING_HARDCORE, victim))
            return;

        HandleHardcoreDeath(victim, killer ? killer->GetEntry() : 0, killer ? killer->GetName() : "Unknown");

        // Make player a permanent ghost (original functionality)
        victim->SetPvPDeath(true);
    }

    void OnPlayerPVPKill(Player* killer, Player* victim) override
    {
        if (!sChallengeModes->challengeEnabledForPlayer(SETTING_HARDCORE, victim))
            return;

        HandleHardcoreDeath(victim, 0, killer ? killer->GetName() : "Unknown");

        // Make player a permanent ghost (original functionality)
        victim->SetPvPDeath(true);
    }
};

// ==============================================
// DarkChaos-255: LOGIN PREVENTION
// ==============================================
class ChallengeModes_LoginPrevention : public PlayerScript
{
public:
    ChallengeModes_LoginPrevention() : PlayerScript("ChallengeModes_LoginPrevention") { }

    void OnPlayerLogin(Player* player) override
    {
        if (!player)
            return;

        // Check if character died in hardcore mode (legacy flag) OR is DB-locked (authoritative)
        bool isDeadFlag = player->GetPlayerSetting("mod-challenge-modes", HARDCORE_DEAD).value == 1;
        bool isDbLocked = ChallengeModeDatabase::IsCharacterLocked(player->GetGUID());

        if (isDbLocked && !isDeadFlag)
            player->UpdatePlayerSetting("mod-challenge-modes", HARDCORE_DEAD, 1);

        if (isDeadFlag || isDbLocked)
        {
            // Show death information
            ChatHandler(player->GetSession()).SendSysMessage("|cffFF0000========================================|r");
            ChatHandler(player->GetSession()).SendSysMessage("|cffFF0000   HARDCORE CHARACTER - DECEASED   |r");
            ChatHandler(player->GetSession()).SendSysMessage("|cffFF0000========================================|r");
            ChatHandler(player->GetSession()).PSendSysMessage("This character died in Hardcore mode and is permanently locked.");
            ChatHandler(player->GetSession()).PSendSysMessage("You cannot log in with this character anymore.");
            ChatHandler(player->GetSession()).PSendSysMessage("Please create a new character or choose another one.");
            ChatHandler(player->GetSession()).SendSysMessage("|cffFF0000========================================|r");

            // Kick player after showing message
            player->GetSession()->KickPlayer("Hardcore character is deceased");
            return;
        }
    }
};

// ==============================================
// DarkChaos-255: .CHALLENGE INFO COMMAND
// ==============================================
class ChallengeModes_CommandScript : public CommandScript
{
public:
    ChallengeModes_CommandScript() : CommandScript("ChallengeModes_CommandScript") { }

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

class ChallengeModeAuraManager : public PlayerScript
{
public:
    ChallengeModeAuraManager() : PlayerScript("ChallengeModeAuraManager") { }

    void OnPlayerLogin(Player* player) override
    {
        sChallengeModes->RefreshChallengeAuras(player);
    }
};

// ==============================================
// DarkChaos-255: SCRIPT REGISTRATION
// ==============================================
void AddSC_challenge_mode_scripts()
{
    new ChallengeMode_Hardcore();
    new ChallengeModes_LoginPrevention();
    new ChallengeModes_CommandScript();
    new ChallengeModeAuraManager();
}
