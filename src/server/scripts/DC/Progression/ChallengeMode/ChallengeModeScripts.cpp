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

#include <array>

using namespace Acore::ChatCommands;

namespace
{
    enum class HardcoreDeathSource
    {
        Creature,
        Npc,
        Player,
        Bot,
        Fall,
        Water,
        Environment
    };

    struct HardcoreDeathInfo
    {
        HardcoreDeathSource source = HardcoreDeathSource::Environment;
        uint32 killerEntry = 0;
        std::string killerName = "Environment";
    };

    bool IsBotPlayer(Player* player)
    {
        if (!player)
            return false;

        if (WorldSession* session = player->GetSession())
            return session->IsBot();

        return false;
    }

    template <size_t N>
    char const* PickRandomLine(std::array<char const*, N> const& lines)
    {
        static_assert(N > 0, "PickRandomLine requires at least one line");
        return lines[urand(0, N - 1)];
    }

    std::string BuildSourceLabel(HardcoreDeathInfo const& info)
    {
        switch (info.source)
        {
            case HardcoreDeathSource::Bot:
                return "Bot " + info.killerName;
            case HardcoreDeathSource::Player:
                return "Player " + info.killerName;
            case HardcoreDeathSource::Npc:
                return "NPC " + info.killerName;
            case HardcoreDeathSource::Creature:
                return "Creature " + info.killerName;
            case HardcoreDeathSource::Fall:
                return "Fall damage";
            case HardcoreDeathSource::Water:
                return "Environmental damage (water/fatigue)";
            case HardcoreDeathSource::Environment:
            default:
                return "Environmental damage";
        }
    }

    std::string BuildSourceCategory(HardcoreDeathSource source)
    {
        switch (source)
        {
            case HardcoreDeathSource::Bot:
                return "Bot";
            case HardcoreDeathSource::Player:
                return "Player";
            case HardcoreDeathSource::Npc:
                return "NPC";
            case HardcoreDeathSource::Creature:
                return "Creature";
            case HardcoreDeathSource::Fall:
                return "Fall Damage";
            case HardcoreDeathSource::Water:
                return "Water/Fatigue";
            case HardcoreDeathSource::Environment:
            default:
                return "Environment";
        }
    }

    HardcoreDeathInfo BuildEnvironmentDeathInfo(Player* victim)
    {
        HardcoreDeathInfo info;

        if (!victim)
            return info;

        if (victim->IsFalling())
        {
            info.source = HardcoreDeathSource::Fall;
            info.killerName = "Fall Damage";
            return info;
        }

        if (victim->IsInWater() || victim->HasUnitMovementFlag(MOVEMENTFLAG_SWIMMING))
        {
            info.source = HardcoreDeathSource::Water;
            info.killerName = "Water/Fatigue";
            return info;
        }

        info.source = HardcoreDeathSource::Environment;
        info.killerName = "Environment";
        return info;
    }

    HardcoreDeathInfo BuildCreatureDeathInfo(Creature* killer)
    {
        HardcoreDeathInfo info;

        if (!killer)
        {
            info.source = HardcoreDeathSource::Creature;
            info.killerName = "Unknown";
            return info;
        }

        info.killerEntry = killer->GetEntry();
        info.killerName = killer->GetName();

        if (killer->GetNpcFlags() != 0)
            info.source = HardcoreDeathSource::Npc;
        else
            info.source = HardcoreDeathSource::Creature;

        return info;
    }

    HardcoreDeathInfo BuildPlayerDeathInfo(Player* killer)
    {
        HardcoreDeathInfo info;

        if (!killer)
        {
            info.source = HardcoreDeathSource::Player;
            info.killerName = "Unknown";
            return info;
        }

        info.killerName = killer->GetName();
        info.source = IsBotPlayer(killer) ? HardcoreDeathSource::Bot : HardcoreDeathSource::Player;
        return info;
    }
}

// ==============================================
// DarkChaos-255: HARDCORE CHARACTER LOCKING
// ==============================================
void HandleHardcoreDeath(Player* victim, HardcoreDeathInfo const& deathInfo)
{
    if (!victim)
        return;

    // Mark character as permanently dead
    victim->UpdatePlayerSetting("mod-challenge-modes", HARDCORE_DEAD, 1);
    sChallengeModes->RefreshChallengeAuras(victim);

    // Persist in challenge mode DB tracking (authoritative lock)
    ChallengeModeDatabase::InitializeTracking(victim->GetGUID());
    ChallengeModeDatabase::SyncActiveModesFromSettings(victim);
    std::string sourceLabel = BuildSourceLabel(deathInfo);
    std::string sourceCategory = BuildSourceCategory(deathInfo.source);
    ChallengeModeDatabase::RecordHardcoreDeath(victim->GetGUID(), victim, deathInfo.killerEntry, sourceLabel);
    ChallengeModeDatabase::LockCharacter(victim->GetGUID());

    static constexpr std::array<char const*, 8> kDeathEpitaphs =
    {{
        "Their legend ends here.",
        "A valiant run meets its end.",
        "Another hero returns to the graveyard.",
        "A hard lesson in the art of survival.",
        "Their journey now belongs to memory.",
        "No second life in Hardcore.",
        "A brave soul has fallen.",
        "One life. One fate."
    }};

    static constexpr std::array<char const*, 8> kFinalLines =
    {{
        "The challenge was real. Respect.",
        "Azeroth remembers this run.",
        "Rest now, champion.",
        "This tale ends, but the next begins.",
        "A hard-earned story has closed.",
        "No retries, only memories.",
        "A worthy effort to the very end.",
        "The spirit healer awaits."
    }};

    // Global announcement
    std::ostringstream ss;
    ss << "|cffFF0000[HARDCORE DEATH]|r " << victim->GetName()
       << " has fallen at level " << (uint32)victim->GetLevel() << "! "
       << "Source: " << sourceLabel << ". "
       << PickRandomLine(kDeathEpitaphs);
    sWorldSessionMgr->SendServerMessage(SERVER_MSG_STRING, ss.str());

    // Show final stats to player
    ChatHandler(victim->GetSession()).PSendSysMessage("|cffFF0000========================================|r");
    ChatHandler(victim->GetSession()).PSendSysMessage("|cffFF0000   HARDCORE CHARACTER - DECEASED   |r");
    ChatHandler(victim->GetSession()).PSendSysMessage("|cffFF0000========================================|r");
    ChatHandler(victim->GetSession()).PSendSysMessage("|cffFFFF00Final Level: |cffFF0000%u", (uint32)victim->GetLevel());
    ChatHandler(victim->GetSession()).PSendSysMessage("|cffFFFF00Killed by: |cffFF0000%s", sourceLabel.c_str());
    ChatHandler(victim->GetSession()).PSendSysMessage("|cffFFFF00Death source type: |cffFF0000%s", sourceCategory.c_str());
    ChatHandler(victim->GetSession()).PSendSysMessage("|cffAAAAAA%s|r", PickRandomLine(kFinalLines));
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

        HandleHardcoreDeath(player, BuildEnvironmentDeathInfo(player));
        player->SetPvPDeath(true);
    }

    void OnPlayerKilledByCreature(Creature* killer, Player* victim) override
    {
        if (!sChallengeModes->challengeEnabledForPlayer(SETTING_HARDCORE, victim))
            return;

        HandleHardcoreDeath(victim, BuildCreatureDeathInfo(killer));

        // Make player a permanent ghost (original functionality)
        victim->SetPvPDeath(true);
    }

    void OnPlayerPVPKill(Player* killer, Player* victim) override
    {
        if (!sChallengeModes->challengeEnabledForPlayer(SETTING_HARDCORE, victim))
            return;

        HandleHardcoreDeath(victim, BuildPlayerDeathInfo(killer));

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
    new ChallengeModeAuraManager();
}
