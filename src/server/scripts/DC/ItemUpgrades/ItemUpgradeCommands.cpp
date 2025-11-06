#include "ScriptMgr.h"
#include "Chat.h"
#include "Player.h"
#include "Item.h"
#include "DatabaseEnv.h"
#include <sstream>

using Acore::ChatCommands::ChatCommandBuilder;
using Acore::ChatCommands::Console;

class ItemUpgradeCommands : public CommandScript
{
public:
    ItemUpgradeCommands() : CommandScript("ItemUpgradeCommands") { }

    [[nodiscard]] std::vector<ChatCommandBuilder> GetCommands() const override
    {
        static const std::vector<ChatCommandBuilder> dcupgradeCommandTable =
        {
            ChatCommandBuilder("dcupgrade", HandleItemUpgradeCommand, 0, Console::No),
        };
        return dcupgradeCommandTable;
    }

private:
    static bool HandleItemUpgradeCommand(ChatHandler* handler, const char* args)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        // Parse arguments
        std::string argStr = args ? args : "";
        std::string::size_type spacePos = argStr.find(' ');
        std::string subcommand = spacePos != std::string::npos ? argStr.substr(0, spacePos) : argStr;
        
        if (subcommand.empty())
            return false;

        // INIT: Get player's current currency
        if (subcommand == "init")
        {
            uint32 playerGuid = player->GetGUID().GetCounter();
            
            QueryResult tokens_result = CharacterDatabase.Query(
                "SELECT amount FROM dc_item_upgrade_currency WHERE player_guid = %u AND currency_type = 1",
                playerGuid
            );
            uint32 tokens = tokens_result ? (*tokens_result)[0].Get<uint32>() : 0;

            QueryResult essence_result = CharacterDatabase.Query(
                "SELECT amount FROM dc_item_upgrade_currency WHERE player_guid = %u AND currency_type = 2",
                playerGuid
            );
            uint32 essence = essence_result ? (*essence_result)[0].Get<uint32>() : 0;

            // Send response as system message
            handler->PSendSysMessage("DCUPGRADE_INIT:%u:%u", tokens, essence);
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
                handler->PSendSysMessage("DCUPGRADE_ERROR:Invalid parameters");
                return true;
            }

            Item* item = player->GetItemByPos(bag, slot);
            if (!item)
            {
                handler->PSendSysMessage("DCUPGRADE_ERROR:Item not found");
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

            handler->PSendSysMessage("DCUPGRADE_QUERY:%u:%u:%u:%u", itemGUID, upgradeLevel, tier, baseItemLevel);
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
                handler->PSendSysMessage("DCUPGRADE_ERROR:Invalid parameters");
                return true;
            }

            Item* item = player->GetItemByPos(bag, slot);
            if (!item)
            {
                handler->PSendSysMessage("DCUPGRADE_ERROR:Item not found");
                return true;
            }

            if (targetLevel > 15)
            {
                handler->PSendSysMessage("DCUPGRADE_ERROR:Max level is 15");
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
                handler->PSendSysMessage("DCUPGRADE_ERROR:Must upgrade to higher level");
                return true;
            }

            // Get upgrade cost
            QueryResult costResult = WorldDatabase.Query(
                "SELECT upgrade_tokens, artifact_essence FROM dc_item_upgrade_costs WHERE tier = %u AND upgrade_level = %u",
                tier, targetLevel
            );

            if (!costResult)
            {
                handler->PSendSysMessage("DCUPGRADE_ERROR:Cost not found");
                return true;
            }

            uint32 tokensNeeded = (*costResult)[0].Get<uint32>();
            uint32 essenceNeeded = (*costResult)[1].Get<uint32>();

            // Check currency
            QueryResult tokenResult = CharacterDatabase.Query(
                "SELECT amount FROM dc_item_upgrade_currency WHERE player_guid = %u AND currency_type = 1",
                playerGuid
            );
            uint32 currentTokens = tokenResult ? (*tokenResult)[0].Get<uint32>() : 0;

            QueryResult essenceResult = CharacterDatabase.Query(
                "SELECT amount FROM dc_item_upgrade_currency WHERE player_guid = %u AND currency_type = 2",
                playerGuid
            );
            uint32 currentEssence = essenceResult ? (*essenceResult)[0].Get<uint32>() : 0;

            if (currentTokens < tokensNeeded)
            {
                handler->PSendSysMessage("DCUPGRADE_ERROR:Need %u tokens, have %u", tokensNeeded, currentTokens);
                return true;
            }

            if (currentEssence < essenceNeeded)
            {
                handler->PSendSysMessage("DCUPGRADE_ERROR:Need %u essence, have %u", essenceNeeded, currentEssence);
                return true;
            }

            // Deduct currency
            CharacterDatabase.Execute(
                "UPDATE dc_item_upgrade_currency SET amount = amount - %u WHERE player_guid = %u AND currency_type = 1",
                tokensNeeded, playerGuid
            );

            CharacterDatabase.Execute(
                "UPDATE dc_item_upgrade_currency SET amount = amount - %u WHERE player_guid = %u AND currency_type = 2",
                essenceNeeded, playerGuid
            );

            // Update item state
            CharacterDatabase.Execute(
                "INSERT INTO dc_item_upgrade_state (item_guid, player_guid, upgrade_level, tier, tokens_invested) "
                "VALUES (%u, %u, %u, %u, %u) "
                "ON DUPLICATE KEY UPDATE upgrade_level = %u, tokens_invested = tokens_invested + %u",
                itemGUID, playerGuid, targetLevel, tier, tokensNeeded, targetLevel, tokensNeeded
            );

            handler->PSendSysMessage("DCUPGRADE_SUCCESS:%u:%u", itemGUID, targetLevel);
            handler->PSendSysMessage("|cff00ff00Item upgraded to level %u!", targetLevel);

            return true;
        }

        return false;
    }
};

void AddSC_ItemUpgradeCommands()
{
    new ItemUpgradeCommands();
}
