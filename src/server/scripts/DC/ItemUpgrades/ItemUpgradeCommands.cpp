#include "ScriptMgr.h"
#include "Chat.h"
#include "Player.h"
#include "Item.h"
#include "DatabaseEnv.h"
#include <sstream>

using Acore::ChatCommands::ChatCommandBuilder;
using Acore::ChatCommands::Console;

class ItemUpgradeAddonCommands : public CommandScript
{
public:
    ItemUpgradeAddonCommands() : CommandScript("ItemUpgradeAddonCommands") { }

    [[nodiscard]] std::vector<ChatCommandBuilder> GetCommands() const override
    {
        static const std::vector<ChatCommandBuilder> dcupgradeCommandTable =
        {
            ChatCommandBuilder("dcupgrade", HandleDCUpgradeCommand, 0, Console::No),
        };
        return dcupgradeCommandTable;
    }

private:
    static bool HandleDCUpgradeCommand(ChatHandler* handler, const char* args)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        // Get currency item IDs from config
        uint32 essenceId = sConfigMgr->GetOption<uint32>("ItemUpgrade.Currency.EssenceId", 100998);
        uint32 tokenId = sConfigMgr->GetOption<uint32>("ItemUpgrade.Currency.TokenId", 100999);

        // Parse arguments
        std::string argStr = args ? args : "";
        std::string::size_type spacePos = argStr.find(' ');
        std::string subcommand = spacePos != std::string::npos ? argStr.substr(0, spacePos) : argStr;
        
        if (subcommand.empty())
        {
            player->Say("DCUPGRADE_ERROR:No command specified", LANG_UNIVERSAL);
            return true;
        }

        // INIT: Get player's current currency (item count)
        if (subcommand == "init")
        {
            uint32 tokens = player->GetItemCount(tokenId);
            uint32 essence = player->GetItemCount(essenceId);

            // Send response via SAY chat (addon listens to CHAT_MSG_SAY)
            std::ostringstream ss;
            ss << "DCUPGRADE_INIT:" << tokens << ":" << essence;
            player->Say(ss.str(), LANG_UNIVERSAL);
            return true;
        }

        // QUERY: Get item upgrade info
        else if (subcommand == "query")
        {
            std::string remainingArgs = spacePos != std::string::npos ? argStr.substr(spacePos + 1) : "";
            std::istringstream iss(remainingArgs);
            uint32 bag, slot;
            
            if (!(iss >> bag >> slot))
            {
                player->Say("DCUPGRADE_ERROR:Invalid parameters", LANG_UNIVERSAL);
                return true;
            }

            Item* item = player->GetItemByPos(bag, slot);
            if (!item)
            {
                player->Say("DCUPGRADE_ERROR:Item not found", LANG_UNIVERSAL);
                return true;
            }

            uint32 itemGUID = item->GetGUID().GetCounter();
            uint32 baseItemLevel = item->GetTemplate()->ItemLevel;

            QueryResult result = CharacterDatabase.Query(
                "SELECT upgrade_level, tier FROM dc_item_upgrade_state WHERE item_guid = %u",
                itemGUID
            );

            uint32 upgradeLevel = 0;
            uint32 tier = 1;

            if (result)
            {
                upgradeLevel = (*result)[0].Get<uint32>();
                tier = (*result)[1].Get<uint32>();
            }
            else
            {
                // Calculate tier based on item level
                if (baseItemLevel >= 450) tier = 5;
                else if (baseItemLevel >= 400) tier = 4;
                else if (baseItemLevel >= 350) tier = 3;
                else if (baseItemLevel >= 300) tier = 2;
                else tier = 1;
            }

            // Send response via SAY chat
            std::ostringstream ss;
            ss << "DCUPGRADE_QUERY:" << itemGUID << ":" << upgradeLevel << ":" << tier << ":" << baseItemLevel;
            player->Say(ss.str(), LANG_UNIVERSAL);
            return true;
        }

        // PERFORM: Perform upgrade
        else if (subcommand == "perform")
        {
            std::string remainingArgs = spacePos != std::string::npos ? argStr.substr(spacePos + 1) : "";
            std::istringstream iss(remainingArgs);
            uint32 bag, slot, targetLevel;
            
            if (!(iss >> bag >> slot >> targetLevel))
            {
                player->Say("DCUPGRADE_ERROR:Invalid parameters", LANG_UNIVERSAL);
                return true;
            }

            Item* item = player->GetItemByPos(bag, slot);
            if (!item)
            {
                player->Say("DCUPGRADE_ERROR:Item not found", LANG_UNIVERSAL);
                return true;
            }

            if (targetLevel > 15)
            {
                player->Say("DCUPGRADE_ERROR:Max level is 15", LANG_UNIVERSAL);
                return true;
            }

            uint32 itemGUID = item->GetGUID().GetCounter();
            uint32 playerGuid = player->GetGUID().GetCounter();
            uint32 baseItemLevel = item->GetTemplate()->ItemLevel;

            // Get current upgrade state
            QueryResult stateResult = CharacterDatabase.Query(
                "SELECT upgrade_level, tier FROM dc_item_upgrade_state WHERE item_guid = %u",
                itemGUID
            );

            uint32 currentLevel = 0;
            uint32 tier = 1;

            if (stateResult)
            {
                currentLevel = (*stateResult)[0].Get<uint32>();
                tier = (*stateResult)[1].Get<uint32>();
            }
            else
            {
                if (baseItemLevel >= 450) tier = 5;
                else if (baseItemLevel >= 400) tier = 4;
                else if (baseItemLevel >= 350) tier = 3;
                else if (baseItemLevel >= 300) tier = 2;
                else tier = 1;
            }

            if (targetLevel <= currentLevel)
            {
                player->Say("DCUPGRADE_ERROR:Must upgrade to higher level", LANG_UNIVERSAL);
                return true;
            }

            // Get upgrade cost
            QueryResult costResult = WorldDatabase.Query(
                "SELECT token_cost, essence_cost FROM dc_item_upgrade_costs WHERE tier = %u AND upgrade_level = %u",
                tier, targetLevel
            );

            if (!costResult)
            {
                std::ostringstream ss;
                ss << "DCUPGRADE_ERROR:Cost not found for tier " << tier << " level " << targetLevel;
                player->Say(ss.str(), LANG_UNIVERSAL);
                return true;
            }

            uint32 tokensNeeded = (*costResult)[0].Get<uint32>();
            uint32 essenceNeeded = (*costResult)[1].Get<uint32>();

            // Check inventory for currency items (using item-based system)
            uint32 currentTokens = player->GetItemCount(tokenId);
            uint32 currentEssence = player->GetItemCount(essenceId);

            if (currentTokens < tokensNeeded)
            {
                std::ostringstream ss;
                ss << "DCUPGRADE_ERROR:Need " << tokensNeeded << " tokens, have " << currentTokens;
                player->Say(ss.str(), LANG_UNIVERSAL);
                return true;
            }

            if (currentEssence < essenceNeeded)
            {
                std::ostringstream ss;
                ss << "DCUPGRADE_ERROR:Need " << essenceNeeded << " essence, have " << currentEssence;
                player->Say(ss.str(), LANG_UNIVERSAL);
                return true;
            }

            // Deduct currency items from inventory
            player->DestroyItemCount(tokenId, tokensNeeded, true);
            player->DestroyItemCount(essenceId, essenceNeeded, true);

            // Update item state
            CharacterDatabase.Execute(
                "INSERT INTO dc_item_upgrade_state (item_guid, player_guid, upgrade_level, tier, tokens_invested) "
                "VALUES (%u, %u, %u, %u, %u) "
                "ON DUPLICATE KEY UPDATE upgrade_level = %u, tokens_invested = tokens_invested + %u",
                itemGUID, playerGuid, targetLevel, tier, tokensNeeded, targetLevel, tokensNeeded
            );

            // Send success response via SAY chat
            std::ostringstream successMsg;
            successMsg << "DCUPGRADE_SUCCESS:" << itemGUID << ":" << targetLevel;
            player->Say(successMsg.str(), LANG_UNIVERSAL);

            return true;
        }

        return false;
    }
};

void AddSC_ItemUpgradeCommands()
{
    new ItemUpgradeAddonCommands();
}
