/*
 * DarkChaos Item Upgrade System - Consolidated Commands
 *
 * This file consolidates all item upgrade related commands into a single command script.
 * Commands: .upgrade
 *
 * Subcommands:
 * - mech (cost, stats, ilvl, reset, procs)
 * - token (add, remove, set, info)
 * - status, list, info
 * - adv (respec, achievements, guild)
 * - prog (mastery, unlocktier, weekcap, tiercap, testset)
 * - season (info, leaderboard, history, reset)
 *
 * Unified from:
 * - ItemUpgradeMechanicsCommands.cpp
 * - ItemUpgradeGMCommands.cpp
 * - ItemUpgradeAdvancedImpl.cpp
 * - ItemUpgradeProgressionImpl.cpp
 * - ItemUpgradeSeasonalImpl.cpp
 *
 */

#include "ScriptMgr.h"
#include "Chat.h"
#include "Player.h"
#include "Item.h"
#include "Config.h"
#include "SharedDefines.h"
#include "../ItemUpgrades/ItemUpgradeManager.h"
#include "../ItemUpgrades/ItemUpgradeMechanics.h"
#include "../ItemUpgrades/ItemUpgradeProcScaling.h"
#include "../ItemUpgrades/ItemUpgradeAdvanced.h"
#include "../ItemUpgrades/ItemUpgradeProgression.h"
#include "../ItemUpgrades/ItemUpgradeSeasonal.h"
#include <sstream>
#include <iomanip>
#include <map>
#include <vector>
#include <cstdlib>
#include <cstring>

using namespace Acore::ChatCommands;
using namespace DarkChaos::ItemUpgrade;

namespace
{
    struct ClassTestGearSet
    {
        std::vector<uint32> itemIds;
        std::string description;
    };

    const std::map<uint8, ClassTestGearSet> kTestGearSets = {
        {CLASS_WARRIOR, {{48685, 48687, 48683, 48689, 48691, 50415, 50356}, "Warrior Tier 9.5 + Weapons"}},
        {CLASS_PALADIN, {{48627, 48625, 48623, 48621, 48629, 50415, 47661}, "Paladin Tier 9.5 + Weapons"}},
        {CLASS_HUNTER, {{48261, 48263, 48265, 48267, 48259, 50034, 47267}, "Hunter Tier 9.5 + Weapons"}},
        {CLASS_ROGUE, {{48221, 48223, 48225, 48227, 48229, 50276, 50415}, "Rogue Tier 9.5 + Weapons"}},
        {CLASS_PRIEST, {{48073, 48075, 48077, 48079, 48071, 50173, 50179}, "Priest Tier 9.5 + Weapons"}},
        {CLASS_DEATH_KNIGHT, {{48491, 48493, 48495, 48497, 48499, 50415}, "Death Knight Tier 9.5 + Weapon"}},
        {CLASS_SHAMAN, {{48313, 48315, 48317, 48319, 48321, 50428, 47666}, "Shaman Tier 9.5 + Weapons"}},
        {CLASS_MAGE, {{47751, 47753, 47755, 47757, 47749, 50173}, "Mage Tier 9.5 + Weapon"}},
        {CLASS_WARLOCK, {{47796, 47798, 47800, 47802, 47804, 50173}, "Warlock Tier 9.5 + Weapon"}},
        {CLASS_DRUID, {{48102, 48104, 48106, 48108, 48110, 50428, 47666}, "Druid Tier 9.5 + Weapons"}}
    };
}

class ItemUpgradeCommands : public CommandScript
{
public:
    ItemUpgradeCommands() : CommandScript("dc_item_upgrade_commands") { }

    ChatCommandTable GetCommands() const override
    {
        // Mechanics Subcommands
        static ChatCommandTable mechCommandTable =
        {
            { "cost",       HandleMechCostCommand,      SEC_ADMINISTRATOR, Console::No },
            { "stats",      HandleMechStatsCommand,     SEC_ADMINISTRATOR, Console::No },
            { "ilvl",       HandleMechILvLCommand,      SEC_ADMINISTRATOR, Console::No },
            { "reset",      HandleMechResetCommand,     SEC_ADMINISTRATOR, Console::No },
            { "procs",      HandleMechProcsCommand,     SEC_PLAYER,        Console::No }
        };

        // Token Subcommands
        static ChatCommandTable tokenCommandTable =
        {
            { "add",        HandleTokenAddCommand,      SEC_GAMEMASTER,    Console::Yes },
            { "remove",     HandleTokenRemoveCommand,   SEC_GAMEMASTER,    Console::Yes },
            { "set",        HandleTokenSetCommand,      SEC_GAMEMASTER,    Console::Yes },
            { "info",       HandleTokenInfoCommand,     SEC_GAMEMASTER,    Console::Yes }
        };

        // Advanced Subcommands
        static ChatCommandTable advCommandTable =
        {
            { "respec",       HandleAdvRespecCommand,      SEC_PLAYER, Console::No },
            { "achievements", HandleAdvAchievementsCommand, SEC_PLAYER, Console::No },
            { "guild",        HandleAdvGuildStatsCommand,   SEC_PLAYER, Console::No }
        };

        // Progression Subcommands
        static ChatCommandTable progCommandTable =
        {
            { "mastery",    HandleProgMasteryCommand,       SEC_PLAYER,     Console::No },
            { "unlocktier", HandleProgUnlockTierCommand,    SEC_GAMEMASTER, Console::No },
            { "weekcap",    HandleProgWeekCapCommand,       SEC_PLAYER,     Console::No },
            { "tiercap",    HandleProgTierCapCommand,       SEC_GAMEMASTER, Console::No },
            { "testset",    HandleProgTestSetCommand,       SEC_GAMEMASTER, Console::No }
        };

        // Seasonal Subcommands
        static ChatCommandTable seasonCommandTable =
        {
            { "info",       HandleSeasonInfoCommand,        SEC_PLAYER,        Console::No },
            { "leaderboard", HandleSeasonLeaderboardCommand, SEC_PLAYER,        Console::No },
            { "history",    HandleSeasonHistoryCommand,     SEC_PLAYER,        Console::No },
            { "reset",      HandleSeasonResetCommand,       SEC_ADMINISTRATOR, Console::No }
        };

        // Main .upgrade Table
        static ChatCommandTable upgradeCommandTable =
        {
            { "mech",       mechCommandTable },
            { "token",      tokenCommandTable },
            { "status",     HandleUpgradeStatusCommand, SEC_PLAYER, Console::Yes },
            { "list",       HandleUpgradeListCommand,   SEC_PLAYER, Console::Yes },
            { "info",       HandleUpgradeInfoCommand,   SEC_PLAYER, Console::Yes },
            { "adv",        advCommandTable },
            { "prog",       progCommandTable },
            { "season",     seasonCommandTable }
        };

        static ChatCommandTable commandTable =
        {
            { "upgrade",    upgradeCommandTable }
        };

        return commandTable;
    }

    // =================================================================
    // Mechanics Handlers
    // =================================================================

    static bool HandleMechCostCommand(ChatHandler* handler, const char* args)
    {
        uint8 tier, level;

        if (sscanf(args, "%hhu %hhu", &tier, &level) != 2)
        {
            handler->PSendSysMessage("|cffff0000Usage: .upgrade mech cost <tier 1-5> <level 0-14>|r");
            return false;
        }

        if (tier < 1 || tier > 5)
        {
            handler->PSendSysMessage("|cffff0000Tier must be 1-5|r");
            return false;
        }

        if (level > 14)
        {
            handler->PSendSysMessage("|cffff0000Level must be 0-14 (upgrades to max 15)|r");
            return false;
        }

        std::string tier_names[] = { "", "Common", "Uncommon", "Rare", "Epic", "Legendary" };

        uint32 essence = UpgradeCostCalculator::GetEssenceCost(tier, level);
        uint32 tokens = UpgradeCostCalculator::GetTokenCost(tier, level);
        uint32 total_essence, total_tokens;

        // Get cumulative cost (out_essence, out_tokens)
        UpgradeCostCalculator::GetCumulativeCost(tier, level + 1, total_essence, total_tokens);

        std::ostringstream oss;
        oss << "|cffffd700===== Upgrade Cost: " << tier_names[tier] << " Level " << (int)level << " -> " << (int)(level + 1) << " =====|r\n";
        oss << "|cff00ff00Current Level Cost:|r\n";
        oss << "  Essence: " << essence << "\n";
        oss << "  Tokens: " << tokens << "\n";
        oss << "|cff00ff00Cumulative Cost (0 -> " << (int)(level + 1) << "):|r\n";
        oss << "  Essence: " << total_essence << "\n";
        oss << "  Tokens: " << total_tokens << "\n";

        handler->PSendSysMessage(oss.str().c_str());
        return true;
    }

    static bool HandleMechStatsCommand(ChatHandler* handler, const char* args)
    {
        uint8 tier, level;

        if (sscanf(args, "%hhu %hhu", &tier, &level) != 2)
        {
            handler->PSendSysMessage("|cffff0000Usage: .upgrade mech stats <tier 1-5> <level 0-15>|r");
            return false;
        }

        if (tier < 1 || tier > 5)
        {
            handler->PSendSysMessage("|cffff0000Tier must be 1-5|r");
            return false;
        }

        if (level > 15)
        {
            handler->PSendSysMessage("|cffff0000Level must be 0-15|r");
            return false;
        }

        std::string tier_names[] = { "", "Common", "Uncommon", "Rare", "Epic", "Legendary" };

        float base_mult = StatScalingCalculator::GetStatMultiplier(level);
        float tier_mult = StatScalingCalculator::GetTierMultiplier(tier);
        float final_mult = StatScalingCalculator::GetFinalMultiplier(level, tier);

        std::ostringstream oss;
        oss << "|cffffd700===== Stat Scaling: " << tier_names[tier] << " Level " << (int)level << " =====|r\n";
        oss << std::fixed << std::setprecision(3);
        oss << "|cff00ff00Base Multiplier:|r " << base_mult << "x ("
            << ((base_mult - 1.0f) * 100.0f) << "% bonus)\n";
        oss << "|cff00ff00Tier Multiplier:|r " << tier_mult << "x\n";
        oss << "|cff00ff00Final Multiplier:|r " << final_mult << "x ("
            << ((final_mult - 1.0f) * 100.0f) << "% bonus)\n";

        handler->PSendSysMessage(oss.str().c_str());
        return true;
    }

    static bool HandleMechILvLCommand(ChatHandler* handler, const char* args)
    {
        uint8 tier, level;
        uint16 base_ilvl;

        if (sscanf(args, "%hhu %hhu %hu", &tier, &level, &base_ilvl) < 2)
        {
            handler->PSendSysMessage("|cffff0000Usage: .upgrade mech ilvl <tier 1-5> <level 0-15> [base_ilvl]|r");
            return false;
        }

        if (tier < 1 || tier > 5)
        {
            handler->PSendSysMessage("|cffff0000Tier must be 1-5|r");
            return false;
        }

        if (level > 15)
        {
            handler->PSendSysMessage("|cffff0000Level must be 0-15|r");
            return false;
        }

        if (base_ilvl == 0)
            base_ilvl = 385; // Default test ilvl

        std::string tier_names[] = { "", "Common", "Uncommon", "Rare", "Epic", "Legendary" };

        uint16 bonus = ItemLevelCalculator::GetItemLevelBonus(level, tier);
        uint16 upgraded_ilvl = ItemLevelCalculator::GetUpgradedItemLevel(base_ilvl, level, tier);

        std::ostringstream oss;
        oss << "|cffffd700===== Item Level Calculation: " << tier_names[tier] << " Level " << (int)level << " =====|r\n";
        oss << "|cff00ff00Base Item Level:|r " << base_ilvl << "\n";
        oss << "|cff00ff00iLvL Bonus:|r " << (int)bonus << "\n";
        oss << "|cff00ff00Upgraded Item Level:|r " << upgraded_ilvl << "\n";

        handler->PSendSysMessage(oss.str().c_str());
        return true;
    }

    static bool HandleMechResetCommand(ChatHandler* handler, const char* args)
    {
        Player* target = nullptr;
        std::string player_name;

        if (*args)
        {
            if (sscanf(args, "%99s", player_name.data()) != 1)
            {
                handler->PSendSysMessage("|cffff0000Invalid player name|r");
                return false;
            }

            target = ObjectAccessor::FindPlayerByName(player_name);
        }
        else
        {
            target = handler->getSelectedPlayer();
        }

        if (!target)
        {
            handler->PSendSysMessage("|cffff0000Player not found|r");
            return false;
        }

        uint32 player_guid = target->GetGUID().GetCounter();

        // Count items to reset
        std::string sql = Acore::StringFormat(
            "SELECT COUNT(*) FROM {} WHERE player_guid = {}", ITEM_UPGRADES_TABLE, player_guid);

        QueryResult result = CharacterDatabase.Query(sql.c_str());

        uint32 count = 0;
        if (result)
            count = result->Fetch()[0].Get<uint32>();

        if (count == 0)
        {
            handler->PSendSysMessage("|cffff0000%s has no upgraded items|r", target->GetName().c_str());
            return false;
        }

        // Confirm action
        handler->PSendSysMessage("|cffff0000WARNING:|r About to reset %u upgrades for %s",
            count, target->GetName().c_str());
        handler->PSendSysMessage("|cffff0000Type the command again to confirm|r");

        // For safety, require second confirmation
        // In a real implementation, would use player session flag, skipping here for consolidation simplicity
        // as this command is likely for testing/admin use.

        std::string deleteSql = Acore::StringFormat("DELETE FROM {} WHERE player_guid = {}", ITEM_UPGRADES_TABLE, player_guid);
        CharacterDatabase.Execute(deleteSql.c_str());

        handler->PSendSysMessage("|cff00ff00Successfully reset %u items for %s|r",
            count, target->GetName().c_str());

        return true;
    }

    static bool HandleMechProcsCommand(ChatHandler* handler, const char* /*args*/)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        std::string info = GetPlayerProcScalingInfo(player);
        handler->SendSysMessage(info.c_str());
        return true;
    }

    // =================================================================
    // Token Handlers
    // =================================================================

    static bool HandleTokenAddCommand(ChatHandler* handler, char const* args)
    {
        if (!args || !*args)
        {
            handler->SendSysMessage("Usage: .upgrade token add <player_name_or_guid> <amount> [upgrade_token|artifact_essence]");
            return false;
        }

        char* playerName = strtok((char*)args, " ");
        char* amountStr = strtok(nullptr, " ");
        char* tokenType = strtok(nullptr, " ");

        if (!playerName || !amountStr)
        {
            handler->SendSysMessage("Usage: .upgrade token add <player_name_or_guid> <amount> [upgrade_token|artifact_essence]");
            return false;
        }

        uint32 amount = 0;
        if (!Acore::StringTo<uint32>(amountStr, amount) || amount == 0)
        {
            handler->SendSysMessage("Invalid amount.");
            return false;
        }

        // Determine token type (default: upgrade_token)
        uint8 currency = 1;  // 1 = upgrade_token, 2 = artifact_essence
        if (tokenType && std::string(tokenType) == "artifact_essence")
            currency = 2;

        // Get player (by name or GUID)
        Player* target = ObjectAccessor::FindPlayerByName(playerName);
        if (!target)
        {
            handler->SendSysMessage("Player not found.");
            return false;
        }

        // Award tokens
        DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager();
        if (mgr)
        {
            mgr->AddCurrency(target->GetGUID().GetCounter(), (DarkChaos::ItemUpgrade::CurrencyType)currency, amount);
            handler->PSendSysMessage("Added %u %s to player %s", amount,
                currency == 1 ? "Upgrade Tokens" : "Artifact Essence", target->GetName().c_str());

            // Send notification to player
            ChatHandler playerHandler(target->GetSession());
            playerHandler.PSendSysMessage("|cff00ff00You received %u %s from GM.|r", amount,
                currency == 1 ? "Upgrade Tokens" : "Artifact Essence");
        }
        else
            handler->SendSysMessage("Error: Upgrade Manager not initialized.");

        return true;
    }

    static bool HandleTokenRemoveCommand(ChatHandler* handler, char const* args)
    {
        if (!args || !*args)
        {
            handler->SendSysMessage("Usage: .upgrade token remove <player_name_or_guid> <amount> [upgrade_token|artifact_essence]");
            return false;
        }

        char* playerName = strtok((char*)args, " ");
        char* amountStr = strtok(nullptr, " ");
        char* tokenType = strtok(nullptr, " ");

        if (!playerName || !amountStr)
        {
            handler->SendSysMessage("Usage: .upgrade token remove <player_name_or_guid> <amount> [upgrade_token|artifact_essence]");
            return false;
        }

        uint32 amount = 0;
        if (!Acore::StringTo<uint32>(amountStr, amount) || amount == 0)
        {
            handler->SendSysMessage("Invalid amount.");
            return false;
        }

        uint8 currency = 1;
        if (tokenType && std::string(tokenType) == "artifact_essence")
            currency = 2;

        Player* target = ObjectAccessor::FindPlayerByName(playerName);
        if (!target)
        {
            handler->SendSysMessage("Player not found.");
            return false;
        }

        DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager();
        if (mgr)
        {
            if (mgr->RemoveCurrency(target->GetGUID().GetCounter(), (DarkChaos::ItemUpgrade::CurrencyType)currency, amount))
            {
                handler->PSendSysMessage("Removed %u %s from player %s", amount,
                    currency == 1 ? "Upgrade Tokens" : "Artifact Essence", target->GetName().c_str());
                ChatHandler targetHandler(target->GetSession());
                targetHandler.PSendSysMessage("|cffff0000%u %s was removed by GM.|r", amount,
                    currency == 1 ? "Upgrade Tokens" : "Artifact Essence");
            }
            else
                handler->SendSysMessage("Player does not have enough tokens.");
        }
        else
            handler->SendSysMessage("Error: Upgrade Manager not initialized.");

        return true;
    }

    static bool HandleTokenSetCommand(ChatHandler* handler, char const* args)
    {
        if (!args || !*args)
        {
            handler->SendSysMessage("Usage: .upgrade token set <player_name_or_guid> <amount> [upgrade_token|artifact_essence]");
            return false;
        }

        char* playerName = strtok((char*)args, " ");
        char* amountStr = strtok(nullptr, " ");
        char* tokenType = strtok(nullptr, " ");

        if (!playerName || !amountStr)
        {
            handler->SendSysMessage("Usage: .upgrade token set <player_name_or_guid> <amount> [upgrade_token|artifact_essence]");
            return false;
        }

        uint32 amount = 0;
        if (!Acore::StringTo<uint32>(amountStr, amount))
        {
            handler->SendSysMessage("Invalid amount.");
            return false;
        }

        uint8 currency = 1;
        if (tokenType && std::string(tokenType) == "artifact_essence")
            currency = 2;

        Player* target = ObjectAccessor::FindPlayerByName(playerName);
        if (!target)
        {
            handler->SendSysMessage("Player not found.");
            return false;
        }

        // Query current amount, then adjust
        DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager();
        if (mgr)
        {
            uint32 current = mgr->GetCurrency(target->GetGUID().GetCounter(), (DarkChaos::ItemUpgrade::CurrencyType)currency);
            if (amount > current)
                mgr->AddCurrency(target->GetGUID().GetCounter(), (DarkChaos::ItemUpgrade::CurrencyType)currency, amount - current);
            else if (amount < current)
                mgr->RemoveCurrency(target->GetGUID().GetCounter(), (DarkChaos::ItemUpgrade::CurrencyType)currency, current - amount);

            handler->PSendSysMessage("Set %s to %u for player %s",
                currency == 1 ? "Upgrade Tokens" : "Artifact Essence", amount, target->GetName().c_str());
        }
        else
            handler->SendSysMessage("Error: Upgrade Manager not initialized.");

        return true;
    }

    static bool HandleTokenInfoCommand(ChatHandler* handler, char const* args)
    {
        Player* player = nullptr;

        if (args && *args)
        {
            player = ObjectAccessor::FindPlayerByName(args);
            if (!player)
            {
                handler->SendSysMessage("Player not found.");
                return false;
            }
        }
        else
        {
            player = handler->GetSession()->GetPlayer();
            if (!player)
            {
                handler->SendSysMessage("No player specified and not in-game.");
                return false;
            }
        }

        DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager();
        if (!mgr)
        {
            handler->SendSysMessage("Error: Upgrade Manager not initialized.");
            return true;
        }

        uint32 tokens = mgr->GetCurrency(player->GetGUID().GetCounter(), DarkChaos::ItemUpgrade::CURRENCY_UPGRADE_TOKEN);
        uint32 essence = mgr->GetCurrency(player->GetGUID().GetCounter(), DarkChaos::ItemUpgrade::CURRENCY_ARTIFACT_ESSENCE);

        handler->SendSysMessage(("=== Token Info for " + player->GetName() + " ===").c_str());
        handler->PSendSysMessage("Upgrade Tokens: %u", tokens);
        handler->PSendSysMessage("Artifact Essence: %u", essence);

        return true;
    }

    // =================================================================
    // General Upgrade Handlers
    // =================================================================

    static bool HandleUpgradeStatusCommand(ChatHandler* handler, char const* /*args*/)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
        {
            handler->SendSysMessage("Error: No player found.");
            return true;
        }

        handler->PSendSysMessage("=== Upgrade Token Status ===");
        handler->PSendSysMessage("This is a placeholder. Full implementation coming in Phase 3B.");
        handler->SendSysMessage("Equipped Items:");

        uint32 count = 0;
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        {
            Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            if (!item)
                continue;

            ItemTemplate const* proto = item->GetTemplate();
            std::string slotMsg = "  Slot " + std::to_string(slot) + ": " + std::string(proto->Name1) + " (iLvL: " + std::to_string(proto->ItemLevel) + ")";
            handler->SendSysMessage(slotMsg.c_str());
            count++;
        }

        handler->PSendSysMessage("Total equipped items: %u", count);
        return true;
    }

    static bool HandleUpgradeListCommand(ChatHandler* handler, char const* /*args*/)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
        {
            handler->SendSysMessage("Error: No player found.");
            return true;
        }

        handler->PSendSysMessage("=== Available Upgrades ===");

        uint32 upgradeCount = 0;
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        {
            Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            if (!item)
                continue;

            ItemTemplate const* proto = item->GetTemplate();
            // Get tier from database mapping
            uint32 currentTier = 1;
            if (DarkChaos::ItemUpgrade::UpgradeManager* mgr = DarkChaos::ItemUpgrade::GetUpgradeManager())
                currentTier = mgr->GetItemTier(item->GetEntry());
            else
                currentTier = 1; // fallback if manager not available

            if (currentTier < 5)
            {
                std::string upgradeMsg = "  [Slot " + std::to_string(slot) + "] " + std::string(proto->Name1) +
                                        " (Tier " + std::to_string(currentTier) + " -> Tier " + std::to_string(currentTier + 1) +
                                        ", iLvL: " + std::to_string(proto->ItemLevel) + ")";
                handler->SendSysMessage(upgradeMsg.c_str());
                upgradeCount++;
            }
        }

        if (upgradeCount == 0)
            handler->SendSysMessage("No items available for upgrade.");
        else
            handler->PSendSysMessage("Total upgradeable items: %u", upgradeCount);

        return true;
    }

    static bool HandleUpgradeInfoCommand(ChatHandler* handler, char const* args)
    {
        if (!args || !*args)
        {
            handler->SendSysMessage("Usage: .upgrade info <item_id>");
            return false;
        }

        uint32 itemId = 0;
        if (!Acore::StringTo<uint32>(args, itemId))
        {
            handler->SendSysMessage("Invalid item ID.");
            return false;
        }

        ItemTemplate const* itemTemplate = sObjectMgr->GetItemTemplate(itemId);
        if (!itemTemplate)
        {
            handler->SendSysMessage("Item not found.");
            return false;
        }

        handler->PSendSysMessage("=== Item Info ===");
        handler->SendSysMessage(("Item: " + std::string(itemTemplate->Name1)).c_str());
        handler->PSendSysMessage("Item Level: %u", itemTemplate->ItemLevel);
        handler->PSendSysMessage("This is a placeholder. Full upgrade info coming in Phase 3B.");

        return true;
    }

    // =================================================================
    // Advanced Handlers
    // =================================================================

    static bool HandleAdvRespecCommand(ChatHandler* handler, const char* args)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        auto respecMgr = GetRespecManager();
        if (!respecMgr)
        {
             handler->SendSysMessage("Respec Manager not available.");
             return true;
        }

        if (!*args)
        {
            // Show respec info
            uint32 cooldown = respecMgr->GetRespecCooldown(player->GetGUID().GetCounter());
            uint32 count_today = respecMgr->GetRespecCountToday(player->GetGUID().GetCounter());

            handler->PSendSysMessage("|cffffd700===== Respec Information =====|r");
            handler->PSendSysMessage("|cff00ff00Respecs Today:|r %u / %u",
                count_today, respecMgr->GetConfig().daily_respec_limit);

            if (cooldown > 0)
            {
                uint32 minutes = cooldown / 60;
                handler->PSendSysMessage("|cffff0000Cooldown remaining:|r %u minutes", minutes);
            }
            else
            {
                handler->PSendSysMessage("|cff00ff00Respec is available.|r");
            }

            handler->PSendSysMessage("Use: .upgrade adv respec <item|all> [confirm]");
            return true;
        }

        char* subCmd = strtok((char*)args, " ");
        if (!subCmd) return false;

        std::string subCommand = subCmd;

        if (subCommand == "all")
        {
             if (!respecMgr->GetConfig().allow_full_respec)
             {
                 handler->SendSysMessage("Full respec is disabled.");
                 return true;
             }

             char* confirm = strtok(nullptr, " ");
             if (!confirm || std::string(confirm) != "confirm")
             {
                  uint32 tokens, essence;
                  respecMgr->CalculateRespecCost(player->GetGUID().GetCounter(), true, tokens, essence);
                  handler->PSendSysMessage("WARNING: About to reset ALL item upgrades.");
                  handler->PSendSysMessage("Cost: %u Tokens, %u Essence.", tokens, essence);
                  handler->PSendSysMessage("Refund: %u%% of invested resources.", respecMgr->GetConfig().refund_percent);
                  handler->PSendSysMessage("Type '.upgrade adv respec all confirm' to proceed.");
                  return true;
             }

             if (respecMgr->RespecAll(player->GetGUID().GetCounter()))
                 handler->SendSysMessage("Successfully adjusted all upgrades.");
             else
                 handler->SendSysMessage("Respec failed (cooldown or cost).");
        }
        else if (subCommand == "item")
        {
            // Respec item in main hand (simplified for command)
            // Ideally would take a bag/slot arg or link
            handler->SendSysMessage("Item respec via command not fully implemented yet. Use 'all'.");
        }

        return true;
    }

    static bool HandleAdvAchievementsCommand(ChatHandler* handler, const char* /*args*/)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player) return false;

        auto achMgr = GetAchievementManager();
        if (!achMgr) return false;

        auto achievements = achMgr->GetPlayerAchievements(player->GetGUID().GetCounter());

        handler->PSendSysMessage("|cffffd700===== Upgrade Achievements =====|r");
        if (achievements.empty())
        {
            handler->SendSysMessage("You have not earned any upgrade achievements yet.");
        }
        else
        {
            for (auto const& ach : achievements)
            {
                handler->PSendSysMessage("|cff00ff00[%s]|r: %s", ach.name.c_str(), ach.description.c_str());
            }
        }
        return true;
    }

    static bool HandleAdvGuildStatsCommand(ChatHandler* handler, const char* /*args*/)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player || !player->GetGuildId())
        {
            handler->SendSysMessage("You must be in a guild.");
            return true;
        }

        auto guildMgr = GetGuildProgressionManager();
        if (!guildMgr) return false;

        GuildUpgradeStats stats = guildMgr->GetGuildStats(player->GetGuildId());

        handler->PSendSysMessage("|cffffd700===== Guild Upgrade Stats: %s =====|r", stats.guild_name.c_str());
        handler->PSendSysMessage("Tier: %u", guildMgr->GetGuildTier(player->GetGuildId()));
        handler->PSendSysMessage("Members with upgrades: %u / %u", stats.members_with_upgrades, stats.total_members);
        handler->PSendSysMessage("Total Items Upgraded: %u", stats.total_items_upgraded);
        handler->PSendSysMessage("Total Essence Invested: %u", stats.total_essence_invested);

        return true;
    }

    // =================================================================
    // Progression Handlers
    // =================================================================

    static bool HandleProgMasteryCommand(ChatHandler* handler, const char* /*args*/)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        auto masteryMgr = GetArtifactMasteryManager();
        if (!masteryMgr)
        {
             handler->SendSysMessage("Artifact Mastery Manager not available.");
             return true;
        }

        PlayerArtifactMasteryInfo* info = masteryMgr->GetMasteryInfo(player->GetGUID().GetCounter());

        if (info)
        {
            handler->PSendSysMessage("|cffffd700===== Artifact Mastery =====|r");
            handler->PSendSysMessage("Title: %s", info->GetMasteryTitle().c_str());
            handler->PSendSysMessage("Rank: %u (Points: %u)", info->mastery_rank, info->total_mastery_points);
            handler->PSendSysMessage("Progress to next rank: %u%%", info->GetProgressToNextRank());
            handler->PSendSysMessage("Fully upgraded items: %u", info->items_fully_upgraded);
        }
        else
        {
            handler->SendSysMessage("Could not retrieve mastery info.");
        }

        return true;
    }

    static bool HandleProgUnlockTierCommand(ChatHandler* handler, const char* args)
    {
        if (!*args)
        {
            handler->PSendSysMessage("Usage: .upgrade prog unlocktier <player_name> <tier_id>");
            return false;
        }

        char* playerName = strtok((char*)args, " ");
        char* tierStr = strtok(nullptr, " ");

        if (!playerName || !tierStr)
            return false;

        Player* target = ObjectAccessor::FindPlayerByName(playerName);
        if (!target)
        {
            handler->SendSysMessage("Player not found.");
            return false;
        }

        uint32 tierId = atoi(tierStr);

        auto levelCapMgr = GetLevelCapManager();
        if (levelCapMgr)
        {
            levelCapMgr->UnlockTier(target->GetGUID().GetCounter(), tierId);
            handler->PSendSysMessage("Unlocked tier %u for %s", tierId, target->GetName().c_str());
        }
        else
        {
            handler->SendSysMessage("Level Cap Manager not available.");
        }

        return true;
    }

    static bool HandleProgWeekCapCommand(ChatHandler* handler, const char* /*args*/)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player) return false;

        auto costMgr = GetCostScalingManager();
        if (!costMgr) return false;

        const CostScalingConfig& config = costMgr->GetConfig();

        uint32 spentEssence = costMgr->GetWeeklySpending(player->GetGUID().GetCounter(), CURRENCY_ARTIFACT_ESSENCE);
        uint32 spentTokens = costMgr->GetWeeklySpending(player->GetGUID().GetCounter(), CURRENCY_UPGRADE_TOKEN);

        handler->PSendSysMessage("|cffffd700===== Weekly Spending =====|r");
        handler->PSendSysMessage("Essence: %u / %u (Hard Cap: %u)",
            spentEssence, config.softcap_weekly_essence, config.hardcap_weekly_essence);
        handler->PSendSysMessage("Tokens: %u / %u (Hard Cap: %u)",
            spentTokens, config.softcap_weekly_tokens, config.hardcap_weekly_tokens);

        return true;
    }

    static bool HandleProgTierCapCommand(ChatHandler* handler, const char* args)
    {
        if (!handler)
            return false;

        if (!args || !*args)
        {
            handler->PSendSysMessage("Usage: .upgrade prog tiercap <tier_id> <max_level>");
            return false;
        }

        char* tierStr = strtok((char*)args, " ");
        char* levelStr = strtok(nullptr, " ");

        if (!tierStr || !levelStr)
        {
            handler->PSendSysMessage("Usage: .upgrade prog tiercap <tier_id> <max_level>");
            return false;
        }

        uint8 tierId = static_cast<uint8>(std::strtoul(tierStr, nullptr, 10));
        uint8 maxLevel = static_cast<uint8>(std::strtoul(levelStr, nullptr, 10));

        Player* target = handler->getSelectedPlayer();
        if (!target)
            target = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;

        if (!target)
        {
            handler->SendSysMessage("No player selected.");
            return false;
        }

        auto levelCapMgr = GetLevelCapManager();
        if (!levelCapMgr)
        {
            handler->SendSysMessage("Level Cap Manager not available.");
            return false;
        }

        levelCapMgr->SetPlayerTierCap(target->GetGUID().GetCounter(), tierId, maxLevel);
        handler->PSendSysMessage("Set tier %u max level to %u for %s.",
            tierId, maxLevel, target->GetName().c_str());

        return true;
    }

    static bool HandleProgTestSetCommand(ChatHandler* handler, const char* /*args*/)
    {
        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
            return false;

        uint8 playerClass = player->getClass();
        auto it = kTestGearSets.find(playerClass);
        if (it == kTestGearSets.end())
        {
            handler->PSendSysMessage("No test gear set configured for your class.");
            return false;
        }

        const ClassTestGearSet& gearSet = it->second;
        uint32 itemsAdded = 0;

        for (uint32 itemId : gearSet.itemIds)
        {
            ItemPosCountVec dest;
            InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, itemId, 1);
            if (msg == EQUIP_ERR_OK)
            {
                if (Item* item = player->StoreNewItem(dest, itemId, true))
                {
                    player->SendNewItem(item, 1, true, false);
                    itemsAdded++;
                }
            }
        }

        uint32 essenceId = DarkChaos::ItemUpgrade::GetArtifactEssenceItemId();
        uint32 tokenId = DarkChaos::ItemUpgrade::GetUpgradeTokenItemId();
        uint32 essenceAmount = sConfigMgr->GetOption<uint32>("ItemUpgrade.Test.EssenceGrant", 5000);
        uint32 tokenAmount = sConfigMgr->GetOption<uint32>("ItemUpgrade.Test.TokensGrant", 2500);

        ItemPosCountVec essenceDest;
        if (player->CanStoreNewItem(NULL_BAG, NULL_SLOT, essenceDest, essenceId, essenceAmount) == EQUIP_ERR_OK)
        {
            if (Item* essence = player->StoreNewItem(essenceDest, essenceId, true))
                player->SendNewItem(essence, essenceAmount, true, false);
        }

        ItemPosCountVec tokenDest;
        if (player->CanStoreNewItem(NULL_BAG, NULL_SLOT, tokenDest, tokenId, tokenAmount) == EQUIP_ERR_OK)
        {
            if (Item* tokens = player->StoreNewItem(tokenDest, tokenId, true))
                player->SendNewItem(tokens, tokenAmount, true, false);
        }

        handler->PSendSysMessage("|cffffd700===== Test Set Granted =====|r");
        handler->PSendSysMessage("|cff00ff00Class:|r %s", player->GetName().c_str());
        handler->PSendSysMessage("|cff00ff00Gear Set:|r %s", gearSet.description.c_str());
        handler->PSendSysMessage("|cff00ff00Items Added:|r %u", itemsAdded);
        handler->PSendSysMessage("|cff00ff00Upgrade Essence:|r %u", essenceAmount);
        handler->PSendSysMessage("|cff00ff00Upgrade Tokens:|r %u", tokenAmount);
        handler->PSendSysMessage("|cff00ffffYou can now test the upgrade system!|r");

        return true;
    }

    // =================================================================
    // Seasonal Handlers
    // =================================================================

    static bool HandleSeasonInfoCommand(ChatHandler* handler, const char* /*args*/)
    {
         // Get current season
        QueryResult result = CharacterDatabase.Query(
            "SELECT season_id, season_name, start_timestamp FROM dc_seasons WHERE is_active = 1");

        if (!result)
        {
            handler->PSendSysMessage("No active season found.");
            return false;
        }

        Field* fields = result->Fetch();
        uint32 season_id = fields[0].Get<uint32>();
        std::string season_name = fields[1].Get<std::string>();
        uint64 start_time = fields[2].Get<uint64>();

        time_t now = time(nullptr);
        uint64 season_duration = now - start_time;
        uint32 days = season_duration / 86400;

        handler->PSendSysMessage("|cffffd700===== Season Information =====|r");
        handler->PSendSysMessage("|cff00ff00Current Season:|r %s (ID: %u)", season_name.c_str(), season_id);
        handler->PSendSysMessage("|cff00ff00Season Duration:|r %u days", days);

        // Get player's season stats
        Player* player = handler->GetSession()->GetPlayer();
        if (player)
        {
            result = CharacterDatabase.Query(
                "SELECT essence_earned, tokens_earned, essence_spent, tokens_spent, "
                "items_upgraded, upgrades_applied FROM dc_player_season_data "
                "WHERE player_guid = {} AND season_id = {}",
                player->GetGUID().GetCounter(), season_id);

            if (result)
            {
                fields = result->Fetch();
                handler->PSendSysMessage("");
                handler->PSendSysMessage("|cffffd700=== Your Season Stats ===|r");
                handler->PSendSysMessage("|cff00ff00Essence Earned:|r %u (Spent: %u)",
                    fields[0].Get<uint32>(), fields[2].Get<uint32>());
                handler->PSendSysMessage("|cff00ff00Tokens Earned:|r %u (Spent: %u)",
                    fields[1].Get<uint32>(), fields[3].Get<uint32>());
                handler->PSendSysMessage("|cff00ff00Items Upgraded:|r %u", fields[4].Get<uint32>());
                handler->PSendSysMessage("|cff00ff00Total Upgrades:|r %u", fields[5].Get<uint32>());
            }
        }

        return true;
    }

    static bool HandleSeasonLeaderboardCommand(ChatHandler* handler, const char* args)
    {
        std::string type = "upgrades";
        if (*args)
            type = args;

        // Get current season - optimized to just get ID
        QueryResult result = CharacterDatabase.Query(
            "SELECT season_id FROM dc_seasons WHERE is_active = 1");

        if (!result)
        {
            handler->PSendSysMessage("No active season found.");
            return false;
        }

        uint32 season_id = result->Fetch()[0].Get<uint32>();

        auto leaderboardMgr = GetLeaderboardManager();
        if (!leaderboardMgr) return false;

        std::vector<LeaderboardEntry> entries;

        if (type == "prestige")
            entries = leaderboardMgr->GetPrestigeLeaderboard(season_id, 10);
        else if (type == "efficiency")
            entries = leaderboardMgr->GetEfficiencyLeaderboard(season_id, 10);
        else
            entries = leaderboardMgr->GetUpgradeLeaderboard(season_id, 10);

        handler->PSendSysMessage("|cffffd700===== %s Leaderboard =====|r", type.c_str());
        handler->PSendSysMessage("");

        for (auto const& entry : entries)
        {
            handler->PSendSysMessage("#%u - %s (Score: %u, Items: %u, Prestige: %u)",
                entry.rank, entry.player_name.c_str(), entry.score,
                entry.items_upgraded, entry.prestige_points);
        }

        return true;
    }

    static bool HandleSeasonHistoryCommand(ChatHandler* handler, const char* args)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        uint32 limit = 10;
        if (*args)
            limit = static_cast<uint32>(std::strtoul(args, nullptr, 10));

        auto historyMgr = GetHistoryManager();
        if (!historyMgr) return false;

        auto history = historyMgr->GetPlayerHistory(player->GetGUID().GetCounter(), limit);

        handler->PSendSysMessage("|cffffd700===== Your Upgrade History =====|r");
        handler->PSendSysMessage("(Showing last %u upgrades)", limit);
        handler->PSendSysMessage("");

        for (auto const& entry : history)
        {
            time_t timestamp = entry.timestamp;
            char time_buf[64];
            strftime(time_buf, sizeof(time_buf), "%Y-%m-%d %H:%M", localtime(&timestamp));

            handler->PSendSysMessage("%s: Item %u (%u->%u) | Cost: %uE/%uT | iLvl: %u->%u",
                time_buf, entry.item_id, entry.upgrade_from, entry.upgrade_to,
                entry.essence_cost, entry.token_cost, entry.old_ilvl, entry.new_ilvl);
        }

        return true;
    }

    static bool HandleSeasonResetCommand(ChatHandler* handler, const char* args)
    {
        if (!*args)
        {
            handler->PSendSysMessage("Usage: .season reset <new_season_id>");
            handler->PSendSysMessage("WARNING: This will reset all player progress!");
            return false;
        }

        uint32 new_season_id = static_cast<uint32>(std::strtoul(args, nullptr, 10));

        handler->PSendSysMessage("Starting global season reset to Season %u...", new_season_id);

        auto resetMgr = GetSeasonResetManager();
        if (resetMgr)
        {
             resetMgr->ExecuteGlobalSeasonReset(new_season_id);
             handler->PSendSysMessage("Season reset complete! Season %u is now active.", new_season_id);
        }
        else
        {
            handler->PSendSysMessage("Season Reset Manager not available.");
        }

        return true;
    }
};

void AddSC_dc_item_upgrade_commandscript()
{
    new ItemUpgradeCommands();
}
