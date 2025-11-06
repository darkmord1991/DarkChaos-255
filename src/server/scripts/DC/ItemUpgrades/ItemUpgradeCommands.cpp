#include "ScriptMgr.h"
#include "Chat.h"
#include "Player.h"
#include "DatabaseEnv.h"

class ItemUpgradeCommands : public CommandScript
{
public:
    ItemUpgradeCommands() : CommandScript("ItemUpgradeCommands") { }

    std::vector<ChatCommand> GetCommands() const override
    {
        static std::vector<ChatCommand> dcupgradeCommandTable =
        {
            { "dcupgrade", SEC_PLAYER, true, &HandleItemUpgradeCommand, "" },
        };
        return dcupgradeCommandTable;
    }

    static bool HandleItemUpgradeCommand(ChatHandler* handler, const char* args)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        // Parse arguments
        char* arg1 = strtok((char*)args, " ");
        if (!arg1)
            return false;

        std::string subcommand = arg1;

        // INIT: Get player's current currency
        if (subcommand == "init")
        {
            uint32 playerGuid = player->GetGUIDLow();
            
            QueryResult tokens_result = CharacterDatabase.Query(
                "SELECT amount FROM dc_item_upgrade_currency WHERE player_guid = {} AND currency_type = 1",
                playerGuid
            );
            uint32 tokens = tokens_result ? tokens_result->Fetch()[0].Get<uint32>() : 0;

            QueryResult essence_result = CharacterDatabase.Query(
                "SELECT amount FROM dc_item_upgrade_currency WHERE player_guid = {} AND currency_type = 2",
                playerGuid
            );
            uint32 essence = essence_result ? essence_result->Fetch()[0].Get<uint32>() : 0;

            // Send response as system message
            player->GetSession()->SendNotification(
                "DCUPGRADE_INIT:%u:%u",
                tokens, essence
            );
            return true;
        }

        // QUERY: Get item upgrade info
        else if (subcommand == "query")
        {
            char* bagStr = strtok(nullptr, " ");
            char* slotStr = strtok(nullptr, " ");

            if (!bagStr || !slotStr)
            {
                player->GetSession()->SendNotification("DCUPGRADE_ERROR:Invalid parameters");
                return true;
            }

            uint32 bag = atoi(bagStr);
            uint32 slot = atoi(slotStr);

            Item* item = player->GetItemByPos(bag, slot);
            if (!item)
            {
                player->GetSession()->SendNotification("DCUPGRADE_ERROR:Item not found");
                return true;
            }

            uint32 itemGUID = item->GetGUIDLow();
            uint32 baseItemLevel = item->GetItemLevel(player);

            QueryResult result = CharacterDatabase.Query(
                "SELECT upgrade_level, tier FROM dc_item_upgrade_state WHERE item_guid = {}",
                itemGUID
            );

            uint32 upgradeLevel = 0;
            uint32 tier = 1;

            if (result)
            {
                upgradeLevel = result->Fetch()[0].Get<uint32>();
                tier = result->Fetch()[1].Get<uint32>();
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

            player->GetSession()->SendNotification(
                "DCUPGRADE_QUERY:%u:%u:%u:%u",
                itemGUID, upgradeLevel, tier, baseItemLevel
            );
            return true;
        }

        // PERFORM: Perform upgrade
        else if (subcommand == "perform")
        {
            char* bagStr = strtok(nullptr, " ");
            char* slotStr = strtok(nullptr, " ");
            char* levelStr = strtok(nullptr, " ");

            if (!bagStr || !slotStr || !levelStr)
            {
                player->GetSession()->SendNotification("DCUPGRADE_ERROR:Invalid parameters");
                return true;
            }

            uint32 bag = atoi(bagStr);
            uint32 slot = atoi(slotStr);
            uint32 targetLevel = atoi(levelStr);

            Item* item = player->GetItemByPos(bag, slot);
            if (!item)
            {
                player->GetSession()->SendNotification("DCUPGRADE_ERROR:Item not found");
                return true;
            }

            if (targetLevel > 15)
            {
                player->GetSession()->SendNotification("DCUPGRADE_ERROR:Max level is 15");
                return true;
            }

            uint32 itemGUID = item->GetGUIDLow();
            uint32 playerGuid = player->GetGUIDLow();
            uint32 baseItemLevel = item->GetItemLevel(player);

            // Get current upgrade state
            QueryResult stateResult = CharacterDatabase.Query(
                "SELECT upgrade_level, tier FROM dc_item_upgrade_state WHERE item_guid = {}",
                itemGUID
            );

            uint32 currentLevel = 0;
            uint32 tier = 1;

            if (stateResult)
            {
                currentLevel = stateResult->Fetch()[0].Get<uint32>();
                tier = stateResult->Fetch()[1].Get<uint32>();
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
                player->GetSession()->SendNotification("DCUPGRADE_ERROR:Must upgrade to higher level");
                return true;
            }

            // Get upgrade cost
            QueryResult costResult = WorldDatabase.Query(
                "SELECT upgrade_tokens, artifact_essence FROM dc_item_upgrade_costs WHERE tier = {} AND upgrade_level = {}",
                tier, targetLevel
            );

            if (!costResult)
            {
                player->GetSession()->SendNotification("DCUPGRADE_ERROR:Cost not found");
                return true;
            }

            uint32 tokensNeeded = costResult->Fetch()[0].Get<uint32>();
            uint32 essenceNeeded = costResult->Fetch()[1].Get<uint32>();

            // Check currency
            QueryResult tokenResult = CharacterDatabase.Query(
                "SELECT amount FROM dc_item_upgrade_currency WHERE player_guid = {} AND currency_type = 1",
                playerGuid
            );
            uint32 currentTokens = tokenResult ? tokenResult->Fetch()[0].Get<uint32>() : 0;

            QueryResult essenceResult = CharacterDatabase.Query(
                "SELECT amount FROM dc_item_upgrade_currency WHERE player_guid = {} AND currency_type = 2",
                playerGuid
            );
            uint32 currentEssence = essenceResult ? essenceResult->Fetch()[0].Get<uint32>() : 0;

            if (currentTokens < tokensNeeded)
            {
                player->GetSession()->SendNotification(
                    "DCUPGRADE_ERROR:Need %u tokens, have %u",
                    tokensNeeded, currentTokens
                );
                return true;
            }

            if (currentEssence < essenceNeeded)
            {
                player->GetSession()->SendNotification(
                    "DCUPGRADE_ERROR:Need %u essence, have %u",
                    essenceNeeded, currentEssence
                );
                return true;
            }

            // Deduct currency
            CharacterDatabase.Execute(
                "UPDATE dc_item_upgrade_currency SET amount = amount - {} WHERE player_guid = {} AND currency_type = 1",
                tokensNeeded, playerGuid
            );

            CharacterDatabase.Execute(
                "UPDATE dc_item_upgrade_currency SET amount = amount - {} WHERE player_guid = {} AND currency_type = 2",
                essenceNeeded, playerGuid
            );

            // Update item state
            CharacterDatabase.Execute(
                "INSERT INTO dc_item_upgrade_state (item_guid, player_guid, upgrade_level, tier, tokens_invested) "
                "VALUES ({}, {}, {}, {}, {}) "
                "ON DUPLICATE KEY UPDATE upgrade_level = {}, tokens_invested = tokens_invested + {}",
                itemGUID, playerGuid, targetLevel, tier, tokensNeeded, targetLevel, tokensNeeded
            );

            player->GetSession()->SendNotification(
                "DCUPGRADE_SUCCESS:%u:%u",
                itemGUID, targetLevel
            );
            player->GetSession()->SendNotification("|cff00ff00Item upgraded to level %u!", targetLevel);

            return true;
        }

        return false;
    }
};

void AddSC_ItemUpgradeCommands()
{
    new ItemUpgradeCommands();
}
