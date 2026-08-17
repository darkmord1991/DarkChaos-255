/*
 * Seasonal Reward System - GM Commands
 *
 * Admin commands for managing seasonal rewards
 *
 * Author: DarkChaos Development Team
 * Date: November 22, 2025
 */

#include "DC/Seasons/SeasonalRewardSystem.h"
#include "DC/Seasons/SeasonalSystem.h"
#include "ScriptMgr.h"
#include "Chat.h"
#include "Player.h"
#include "ObjectAccessor.h"

using namespace DarkChaos::SeasonalRewards;
using namespace Acore::ChatCommands;

class SeasonalRewardCommands : public CommandScript
{
public:
    SeasonalRewardCommands() : CommandScript("SeasonalRewardCommands") {}

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable seasonCommandTable =
        {
            { "reload",     HandleSeasonReloadCommand,      SEC_ADMINISTRATOR, Console::No },
            { "info",       HandleSeasonInfoCommand,        SEC_GAMEMASTER,    Console::No },
            { "stats",      HandleSeasonStatsCommand,       SEC_GAMEMASTER,    Console::No },
            { "award",      HandleSeasonAwardCommand,       SEC_ADMINISTRATOR, Console::No },
            { "reset",      HandleSeasonResetCommand,       SEC_ADMINISTRATOR, Console::No },
            { "setseason",  HandleSeasonSetSeasonCommand,   SEC_ADMINISTRATOR, Console::No },
            { "multiplier", HandleSeasonMultiplierCommand,  SEC_ADMINISTRATOR, Console::No },
            { "chest",      HandleSeasonChestCommand,       SEC_PLAYER,        Console::No }
        };

        static ChatCommandTable commandTable =
        {
            { "season", seasonCommandTable }
        };

        return commandTable;
    }

    // .season reload
    static bool HandleSeasonReloadCommand(ChatHandler* handler)
    {
        handler->SendSysMessage("Reloading seasonal reward configuration...");
        sSeasonalRewards->ReloadConfiguration();
        handler->PSendSysMessage("Configuration reloaded! Active season: {}",
            sSeasonalRewards->GetConfig().activeSeason);
        return true;
    }

    // .season info
    static bool HandleSeasonInfoCommand(ChatHandler* handler)
    {
        const SeasonalConfig& config = sSeasonalRewards->GetConfig();

        handler->SendSysMessage("=== Seasonal Reward System Info ===");
        handler->PSendSysMessage("Enabled: {}", config.enabled ? "Yes" : "No");
        handler->PSendSysMessage("Active Season: {}", config.activeSeason);
        handler->PSendSysMessage("Token Item: {}, Essence Item: {}",
            config.tokenItemId, config.essenceItemId);
        handler->PSendSysMessage("Weekly Caps: {} tokens, {} essence",
            config.weeklyTokenCap == 0 ? 999999 : config.weeklyTokenCap,
            config.weeklyEssenceCap == 0 ? 999999 : config.weeklyEssenceCap);
        handler->PSendSysMessage("Multipliers: Quest={:.2f}, Creature={:.2f}, WorldBoss={:.2f}, Event={:.2f}",
            config.questMultiplier, config.creatureMultiplier,
            config.worldBossMultiplier, config.eventBossMultiplier);
        handler->PSendSysMessage("Weekly Reset: Day {} (0=Sun), Hour {}",
            config.resetDay, config.resetHour);

        return true;
    }

    // .season stats [player]
    static bool HandleSeasonStatsCommand(ChatHandler* handler, Optional<PlayerIdentifier> target)
    {
        Player* player = target ? target->GetConnectedPlayer() : handler->getSelectedPlayerOrSelf();

        if (!player)
        {
            handler->SendSysMessage("No player selected.");
            return false;
        }

        PlayerSeasonStats* stats = sSeasonalRewards->GetPlayerStats(player->GetGUID().GetCounter());

        if (!stats)
        {
            handler->PSendSysMessage("No seasonal stats found for {}", player->GetName().c_str());
            return true;
        }

        handler->PSendSysMessage("=== Seasonal Stats for {} ===", player->GetName().c_str());
        handler->PSendSysMessage("Season ID: {}", stats->seasonId);
        handler->PSendSysMessage("Total Earned: {} tokens, {} essence",
            stats->seasonalTokensEarned, stats->seasonalEssenceEarned);
        handler->PSendSysMessage("Weekly Earned: {} tokens, {} essence",
            stats->weeklyTokensEarned, stats->weeklyEssenceEarned);
        handler->PSendSysMessage("Activities: {} quests, {} creatures, {} dungeon bosses, {} world bosses",
            stats->questsCompleted, stats->creaturesKilled,
            stats->dungeonBossesKilled, stats->worldBossesKilled);
        handler->PSendSysMessage("Prestige Level: {}", stats->prestigeLevel);

        return true;
    }

    // .season award <player> <tokens> <essence>
    static bool HandleSeasonAwardCommand(ChatHandler* handler, PlayerIdentifier target,
        uint32 tokens, uint32 essence)
    {
        Player* player = target.GetConnectedPlayer();

        if (!player)
        {
            handler->SendSysMessage("Player not found or offline.");
            return false;
        }

        if (tokens == 0 && essence == 0)
        {
            handler->SendSysMessage("Must award at least some tokens or essence.");
            return false;
        }

        bool success = sSeasonalRewards->AwardBoth(player, tokens, essence, "GM Award", 0);

        if (success)
        {
            handler->PSendSysMessage("Awarded {} tokens and {} essence to {}",
                tokens, essence, player->GetName().c_str());
            return true;
        }
        else
        {
            handler->SendSysMessage("Failed to award rewards (inventory full?).");
            return false;
        }
    }

    // .season reset <player>
    static bool HandleSeasonResetCommand(ChatHandler* handler, PlayerIdentifier target)
    {
        Player* player = target.GetConnectedPlayer();

        if (!player)
        {
            handler->SendSysMessage("Player not found or offline.");
            return false;
        }

        handler->PSendSysMessage("Resetting seasonal data for {}...", player->GetName().c_str());
        sSeasonalRewards->ResetPlayerSeason(player);
        handler->SendSysMessage("Season data has been archived and reset.");

        return true;
    }

    // .season setseason <id>
    static bool HandleSeasonSetSeasonCommand(ChatHandler* handler, uint32 seasonId)
    {
        handler->PSendSysMessage("Changing active season to {}...", seasonId);

        // Route through the generic seasonal engine so registered systems (item upgrades,
        // seasonal rewards itself, ...) get their on_season_event/on_player_season_change
        // callbacks fired instead of silently missing the transition.
        uint32 oldSeasonId = sSeasonalRewards->GetConfig().activeSeason;
        bool transitioned = false;
        if (DarkChaos::Seasonal::SeasonalManager* seasonalMgr = DarkChaos::Seasonal::GetSeasonalManager())
            transitioned = seasonalMgr->TransitionSeason(oldSeasonId, seasonId);

        if (!transitioned)
            sSeasonalRewards->SetActiveSeason(seasonId);

        handler->SendSysMessage("Active season changed! This change is temporary until config is updated.");

        return true;
    }

    // .season multiplier <type> <value>
    static bool HandleSeasonMultiplierCommand(ChatHandler* handler, std::string type, float value)
    {
        if (value < 0.1f || value > 10.0f)
        {
            handler->SendSysMessage("Multiplier must be between 0.1 and 10.0");
            return false;
        }

        std::transform(type.begin(), type.end(), type.begin(), ::tolower);

        if (type != "quest" && type != "creature" && type != "worldboss" && type != "event")
        {
            handler->SendSysMessage("Invalid multiplier type. Use: quest, creature, worldboss, or event");
            return false;
        }

        sSeasonalRewards->SetMultiplier(type, value);
        handler->PSendSysMessage("Set {} multiplier to {:.2f}", type.c_str(), value);

        return true;
    }

    // .season chest
    static bool HandleSeasonChestCommand(ChatHandler* handler)
    {
        Player* player = handler->GetSession()->GetPlayer();

        if (!player)
            return false;

        WeeklyChest* chest = sSeasonalRewards->GetWeeklyChest(player);

        if (!chest)
        {
            handler->SendSysMessage("You have no weekly chest available.");
            return true;
        }

        if (chest->collected)
        {
            handler->SendSysMessage("You have already collected this week's chest.");
            return true;
        }

        handler->PSendSysMessage("=== Weekly Chest ===");
        handler->PSendSysMessage("Slots Unlocked: {} / 3", chest->slotsUnlocked);

        if (chest->slotsUnlocked >= 1)
            handler->PSendSysMessage("Slot 1: {} tokens, {} essence",
                chest->slot1Tokens, chest->slot1Essence);
        if (chest->slotsUnlocked >= 2)
            handler->PSendSysMessage("Slot 2: {} tokens, {} essence",
                chest->slot2Tokens, chest->slot2Essence);
        if (chest->slotsUnlocked >= 3)
            handler->PSendSysMessage("Slot 3: {} tokens, {} essence",
                chest->slot3Tokens, chest->slot3Essence);

        handler->SendSysMessage("Type |cffffcc00.season chest collect|r to claim your rewards!");

        return true;
    }
};

// =====================================================================
// Registration
// =====================================================================

void AddSC_dc_seasonal_rewards_commandscript()
{
    new SeasonalRewardCommands();
}
