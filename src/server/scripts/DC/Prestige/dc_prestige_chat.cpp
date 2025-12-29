/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * Consolidated Prestige Commands
 * All .prestige subcommands in one file
 */

#include "Chat.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "GameTime.h"
#include "Log.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include "dc_prestige_api.h"
#include <sstream>

using namespace Acore::ChatCommands;

// Forward declarations to the system singletons
// (defined in their respective files)
class PrestigeSystem;
class PrestigeChallengeSystem;
class PrestigeAltBonusSystem;

// Challenge types (from dc_prestige_challenges.cpp)
enum PrestigeChallenge : uint8
{
    CHALLENGE_IRON  = 1,
    CHALLENGE_SPEED = 2,
    CHALLENGE_SOLO  = 3,
};

// External singletons
extern PrestigeSystem* sPrestigeSystem;
extern PrestigeChallengeSystem* sPrestigeChallengeSystem;
extern PrestigeAltBonusSystem* sPrestigeAltBonusSystem;

class PrestigeUnifiedCommandScript : public CommandScript
{
public:
    PrestigeUnifiedCommandScript() : CommandScript("PrestigeUnifiedCommandScript") { }

    ChatCommandTable GetCommands() const override
    {
        // Challenge subcommands (.prestige challenge <x>)
        static ChatCommandTable challengeCommandTable =
        {
            { "start",  HandleChallengeStartCommand,  SEC_PLAYER, Console::No },
            { "status", HandleChallengeStatusCommand, SEC_PLAYER, Console::No },
            { "list",   HandleChallengeListCommand,   SEC_PLAYER, Console::No }
        };

        // Alt bonus subcommands (.prestige altbonus <x>)
        static ChatCommandTable altBonusCommandTable =
        {
            { "info", HandleAltBonusInfoCommand, SEC_PLAYER, Console::No }
        };

        // Main prestige command table
        static ChatCommandTable prestigeCommandTable =
        {
            // Core prestige commands
            { "info",      HandlePrestigeInfoCommand,    SEC_PLAYER,        Console::No },
            { "reset",     HandlePrestigeResetCommand,   SEC_PLAYER,        Console::No },
            { "confirm",   HandlePrestigeConfirmCommand, SEC_PLAYER,        Console::No },
            // Subtables
            { "challenge", challengeCommandTable },
            { "altbonus",  altBonusCommandTable },
            // Admin commands
            { "disable",   HandlePrestigeDisableCommand, SEC_ADMINISTRATOR, Console::No },
            { "admin",     HandlePrestigeAdminCommand,   SEC_ADMINISTRATOR, Console::No }
        };

        static ChatCommandTable commandTable =
        {
            { "prestige", prestigeCommandTable }
        };

        return commandTable;
    }

    // ============================================================
    // Core Prestige Commands (from dc_prestige_system.cpp)
    // ============================================================

    static bool HandlePrestigeInfoCommand(ChatHandler* handler, char const* /*args*/)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        if (!PrestigeAPI::IsEnabled())
        {
            handler->SendSysMessage("Prestige system is currently disabled.");
            return true;
        }

        uint32 prestigeLevel = PrestigeAPI::GetPrestigeLevel(player);
        uint32 maxPrestige = PrestigeAPI::GetMaxPrestigeLevel();
        uint32 requiredLevel = PrestigeAPI::GetRequiredLevel();
        uint32 statBonus = prestigeLevel * PrestigeAPI::GetStatBonusPercent();

        handler->PSendSysMessage("=== Prestige System ===");
        handler->PSendSysMessage("Your Prestige Level: {}/{}", prestigeLevel, maxPrestige);
        handler->PSendSysMessage("Current Stat Bonus: {}%", statBonus);
        handler->PSendSysMessage("Required Level to Prestige: {}", requiredLevel);

        if (PrestigeAPI::CanPrestige(player))
        {
            handler->PSendSysMessage("|cFF00FF00You can prestige! Type .prestige reset to begin.|r");
        }
        else if (player->GetLevel() < requiredLevel)
        {
            handler->PSendSysMessage("You need to be level {} to prestige. Current level: {}", requiredLevel, player->GetLevel());
        }
        else if (prestigeLevel >= maxPrestige)
        {
            handler->PSendSysMessage("|cFFFFD700You have reached maximum prestige level!|r");
        }

        return true;
    }

    static bool HandlePrestigeResetCommand(ChatHandler* handler, char const* /*args*/)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        if (!PrestigeAPI::IsEnabled())
        {
            handler->SendSysMessage("Prestige system is currently disabled.");
            return true;
        }

        if (!PrestigeAPI::CanPrestige(player))
        {
            handler->SendSysMessage("You cannot prestige at this time.");
            return true;
        }

        uint32 nextPrestige = PrestigeAPI::GetPrestigeLevel(player) + 1;
        uint32 newBonus = nextPrestige * PrestigeAPI::GetStatBonusPercent();

        handler->PSendSysMessage("|cFFFF0000WARNING: Prestiging will:|r");
        handler->PSendSysMessage("- Reset you to level 1");
        handler->PSendSysMessage("- Grant you Prestige Level {} with {}% permanent stat bonus", nextPrestige, newBonus);
        handler->PSendSysMessage("- Grant you an exclusive title");
        handler->PSendSysMessage("|cFFFFD700Type .prestige confirm to proceed.|r");

        return true;
    }

    static bool HandlePrestigeConfirmCommand(ChatHandler* handler, char const* /*args*/)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        if (!PrestigeAPI::CanPrestige(player))
        {
            handler->SendSysMessage("You cannot prestige at this time.");
            return true;
        }

        if (PrestigeAPI::PerformPrestige(player))
        {
            handler->SendSysMessage("|cFF00FF00Prestige successful!|r");
        }
        else
        {
            handler->SendSysMessage("|cFFFF0000Prestige failed. Check server logs.|r");
        }

        return true;
    }

    static bool HandlePrestigeDisableCommand(ChatHandler* handler, char const* args)
    {
        if (!*args)
        {
            handler->SendSysMessage("Usage: .prestige disable <playername>");
            return true;
        }

        std::string playerName = args;
        Player* target = ObjectAccessor::FindPlayerByName(playerName);

        if (!target)
        {
            handler->PSendSysMessage("Player {} not found.", playerName);
            return true;
        }

        PrestigeAPI::RemovePrestigeBuffs(target);

        handler->PSendSysMessage("Removed prestige buffs from {}.", playerName);
        ChatHandler(target->GetSession()).PSendSysMessage("Your prestige buffs have been removed by a GM.");

        return true;
    }

    static bool HandlePrestigeAdminCommand(ChatHandler* handler, char const* args)
    {
        if (!*args)
            return false;

        std::stringstream ss(args);
        std::string token;
        std::vector<std::string> tokens;
        while (ss >> token)
            tokens.push_back(token);

        if (tokens.empty())
            return false;

        std::string subCommand = tokens[0];

        if (subCommand == "set" && tokens.size() == 3)
        {
            std::string playerName = tokens[1];
            if (Optional<uint32> level = Acore::StringTo<uint32>(tokens[2]))
            {
                Player* target = ObjectAccessor::FindPlayerByName(playerName);
                if (!target)
                {
                    handler->PSendSysMessage("Player {} not found.", playerName);
                    return true;
                }

                uint32 maxLevel = PrestigeAPI::GetMaxPrestigeLevel();
                uint32 clampedLevel = std::min(*level, maxLevel);

                PrestigeAPI::SetPrestigeLevel(target, clampedLevel);

                handler->PSendSysMessage("Set {}'s prestige level to {}.", playerName, clampedLevel);
                ChatHandler(target->GetSession()).PSendSysMessage("Your prestige level has been set to {} by a GM.", clampedLevel);
                return true;
            }
        }

        handler->SendSysMessage("Usage: .prestige admin set <player> <level>");
        return true;
    }

    // ============================================================
    // Challenge Commands (from dc_prestige_challenges.cpp)
    // ============================================================

    static bool HandleChallengeStartCommand(ChatHandler* handler, char const* args)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        if (!PrestigeAPI::IsChallengesEnabled())
        {
            handler->SendSysMessage("Prestige challenges are currently disabled.");
            return true;
        }

        if (!args || strlen(args) == 0)
        {
            handler->SendSysMessage("Usage: .prestige challenge start <iron|speed|solo>");
            return true;
        }

        std::string challengeName(args);
        PrestigeChallenge challengeType;

        if (challengeName == "iron")
            challengeType = CHALLENGE_IRON;
        else if (challengeName == "speed")
            challengeType = CHALLENGE_SPEED;
        else if (challengeName == "solo")
            challengeType = CHALLENGE_SOLO;
        else
        {
            handler->SendSysMessage("Invalid challenge type. Use: iron, speed, or solo");
            return true;
        }

        if (!PrestigeAPI::IsEnabled())
        {
            handler->SendSysMessage("Prestige system is currently disabled.");
            return true;
        }

        uint32 prestigeLevel = PrestigeAPI::GetPrestigeLevel(player);
        if (prestigeLevel == 0)
        {
            handler->SendSysMessage("You must be at least Prestige Level 1 to start prestige challenges.");
            return true;
        }

        if (PrestigeAPI::StartChallenge(player, static_cast<uint8>(challengeType), prestigeLevel))
        {
            handler->PSendSysMessage("|cFF00FF00Challenge started: {}|r",
                PrestigeAPI::GetChallengeName(static_cast<uint8>(challengeType)));
        }
        else
        {
            handler->SendSysMessage("|cFFFF0000Failed to start challenge. You may already have this challenge active.|r");
        }

        return true;
    }

    static bool HandleChallengeStatusCommand(ChatHandler* handler, char const* /*args*/)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        if (!PrestigeAPI::IsChallengesEnabled())
        {
            handler->SendSysMessage("Prestige challenges are currently disabled.");
            return true;
        }

        handler->SendSysMessage("|cFFFFD700=== Active Prestige Challenges ===|r");

        auto activeChallenges = PrestigeAPI::GetActiveChallenges(player);
        if (activeChallenges.empty())
        {
            handler->SendSysMessage("You have no active challenges.");
        }
        else
        {
            for (auto const& challenge : activeChallenges)
            {
                handler->PSendSysMessage("- {} (Prestige Level {})",
                    PrestigeAPI::GetChallengeName(challenge.type), challenge.prestigeLevel);
            }
        }

        // Show total stat bonus
        uint32 totalBonus = PrestigeAPI::GetTotalChallengeStatBonus(player);
        if (totalBonus > 0)
        {
            handler->SendSysMessage("");
            handler->PSendSysMessage("|cFF00FF00Total challenge stat bonus: +{}%|r", totalBonus);
        }

        return true;
    }

    static bool HandleChallengeListCommand(ChatHandler* handler, char const* /*args*/)
    {
        handler->SendSysMessage("|cFFFFD700=== Available Prestige Challenges ===|r");

        handler->SendSysMessage("|cFF00FF00Iron Prestige|r");
        handler->SendSysMessage("  Requirement: Reach level 255 without dying");
        handler->SendSysMessage("  Rewards: Special title, +2% all stats");

        handler->PSendSysMessage("|cFF00FF00Speed Prestige|r");
        handler->SendSysMessage("  Requirement: Reach level 255 in <100 hours");
        handler->SendSysMessage("  Rewards: Special title, +2% all stats");

        handler->SendSysMessage("|cFF00FF00Solo Prestige|r");
        handler->SendSysMessage("  Requirement: Reach level 255 without joining a group");
        handler->SendSysMessage("  Rewards: Special title, +2% all stats");

        handler->SendSysMessage("");
        handler->SendSysMessage("Use |cFFFFFF00.prestige challenge start <type>|r to begin");

        return true;
    }

    // ============================================================
    // Alt Bonus Commands (from dc_prestige_alt_bonus.cpp)
    // ============================================================

    static bool HandleAltBonusInfoCommand(ChatHandler* handler, char const* /*args*/)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        if (!PrestigeAPI::IsAltBonusEnabled())
        {
            handler->SendSysMessage("Alt bonus system is currently disabled.");
            return true;
        }

        uint32 accountId = player->GetSession()->GetAccountId();
        uint32 maxLevelCount = PrestigeAPI::GetAccountMaxLevelCount(accountId);
        uint32 bonusPercent = PrestigeAPI::GetAltBonusPercent(player);

        handler->PSendSysMessage("|cFFFFD700=== Alt-Friendly XP Bonus ===|r");
        handler->PSendSysMessage("Max-level characters on account: |cFF00FF00{}|r", maxLevelCount);

        uint32 maxLevel = 255; // DarkChaos max level
        if (player->GetLevel() >= maxLevel)
        {
            handler->PSendSysMessage("|cFFFFFF00You are max level and do not receive the bonus.|r");
        }
        else
        {
            handler->PSendSysMessage("Current XP bonus: |cFF00FF00{}%|r", bonusPercent);
            handler->PSendSysMessage("(5% per max-level character, max 25%)");
        }

        return true;
    }
};

void AddSC_dc_prestige_chat()
{
    new PrestigeUnifiedCommandScript();
}
