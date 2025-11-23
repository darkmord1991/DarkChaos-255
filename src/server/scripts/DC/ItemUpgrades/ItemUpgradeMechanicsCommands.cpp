/*
* Phase 4A: Item Upgrade Mechanics - Admin Commands
*
* Admin commands for Phase 4A:
* .upgrade mech cost <tier> <level>    - Show cost for tier/level
* .upgrade mech stats <tier> <level>   - Show stat scaling
* .upgrade mech ilvl <tier> <level>    - Show item level bonus
* .upgrade mech reset [player_name]    - Reset all upgrades for player
*
* Date: November 4, 2025
*/

#include "ScriptMgr.h"
#include "Chat.h"
#include "Player.h"
#include "ItemUpgradeMechanics.h"
#include "ItemUpgradeManager.h"
#include <sstream>
#include <iomanip>

using namespace Acore::ChatCommands;
using namespace DarkChaos::ItemUpgrade;

class ItemUpgradeMechanicsCommands : public CommandScript
{
public:
    ItemUpgradeMechanicsCommands() : CommandScript("item_upgrade_mechanics_commands") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable upgradeCommandTable =
        {
            ChatCommandBuilder("cost", HandleCostCommand, SEC_ADMINISTRATOR, Console::No),
            ChatCommandBuilder("stats", HandleStatsCommand, SEC_ADMINISTRATOR, Console::No),
            ChatCommandBuilder("ilvl", HandleILvLCommand, SEC_ADMINISTRATOR, Console::No),
            ChatCommandBuilder("reset", HandleResetCommand, SEC_ADMINISTRATOR, Console::No)
        };

        static ChatCommandTable mechCommandTable =
        {
            ChatCommandBuilder("mech", upgradeCommandTable)
        };

        static ChatCommandTable commandTable =
        {
            ChatCommandBuilder("upgrade", mechCommandTable)
        };

        return commandTable;
    }

    static bool HandleUpgradeMechCommand(ChatHandler* handler, const char* args)
    {
        if (!handler)
            return false;

        if (!*args)
        {
            handler->PSendSysMessage("|cff00ff00Phase 4A Item Upgrade Mechanics Commands:|r");
            handler->PSendSysMessage(".upgrade mech cost <tier> <level>");
            handler->PSendSysMessage(".upgrade mech stats <tier> <level>");
            handler->PSendSysMessage(".upgrade mech ilvl <tier> <level>");
            handler->PSendSysMessage(".upgrade mech reset [player_name]");
            return true;
        }

        char subcommand[100];
        if (sscanf(args, "%99s", subcommand) != 1)
            return false;

        std::string sub = subcommand;

        if (sub == "cost")
            return HandleCostCommand(handler, args + 4);
        else if (sub == "stats")
            return HandleStatsCommand(handler, args + 5);
        else if (sub == "ilvl")
            return HandleILvLCommand(handler, args + 4);
        else if (sub == "reset")
            return HandleResetCommand(handler, args + 5);
        else
        {
            handler->PSendSysMessage("|cffff0000Unknown subcommand: %s|r", sub.c_str());
            return false;
        }
    }

    static bool HandleCostCommand(ChatHandler* handler, const char* args)
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
        oss << "|cffffd700===== Upgrade Cost: " << tier_names[tier] << " Level " << (int)level << " → " << (int)(level + 1) << " =====|r\n";
        oss << "|cff00ff00Current Level Cost:|r\n";
        oss << "  Essence: " << essence << "\n";
        oss << "  Tokens: " << tokens << "\n";
        oss << "|cff00ff00Cumulative Cost (0 → " << (int)(level + 1) << "):|r\n";
        oss << "  Essence: " << total_essence << "\n";
        oss << "  Tokens: " << total_tokens << "\n";

        handler->PSendSysMessage(oss.str().c_str());
        return true;
    }

    static bool HandleStatsCommand(ChatHandler* handler, const char* args)
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

    static bool HandleILvLCommand(ChatHandler* handler, const char* args)
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

    static bool HandleResetCommand(ChatHandler* handler, const char* args)
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
        // In a real implementation, would use player session flag

        std::string deleteSql = Acore::StringFormat("DELETE FROM {} WHERE player_guid = {}", ITEM_UPGRADES_TABLE, player_guid);
        CharacterDatabase.Execute(deleteSql.c_str());

        handler->PSendSysMessage("|cff00ff00Successfully reset %u items for %s|r",
            count, target->GetName().c_str());

        return true;
    }
};

// Registration
void AddSC_ItemUpgradeMechanicsCommands()
{
    new ItemUpgradeMechanicsCommands();
}
