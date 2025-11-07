#include "ScriptMgr.h"
#include "Chat.h"
#include "Player.h"
#include "Item.h"
#include "DatabaseEnv.h"
#include "Config.h"
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
    // Helper: send response to addon via SYSTEM chat; optionally echo to SAY when debug is enabled
    static void SendAddonResponse(Player* player, std::string const& msg)
    {
        if (!player)
            return;

        ChatHandler(player->GetSession()).SendSysMessage(msg.c_str());

        // Optional debug echo to SAY (visible in world) controlled by config
        bool debugToSay = sConfigMgr->GetOption<bool>("ItemUpgrade.DebugToSay", false);
        if (debugToSay)
            player->Say(msg, LANG_UNIVERSAL);
    }
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
            SendAddonResponse(player, "DCUPGRADE_ERROR:No command specified");
            return true;
        }

        // INIT: Get player's current currency (item count)
        if (subcommand == "init")
        {
            uint32 tokens = player->GetItemCount(tokenId);
            uint32 essence = player->GetItemCount(essenceId);

            // Send response via SYSTEM chat (addon listens to CHAT_MSG_SYSTEM)
            std::ostringstream ss;
            ss << "DCUPGRADE_INIT:" << tokens << ":" << essence;
            SendAddonResponse(player, ss.str());
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
                SendAddonResponse(player, "DCUPGRADE_ERROR:Invalid parameters");
                return true;
            }

            Item* item = player->GetItemByPos(bag, slot);
            if (!item)
            {
                SendAddonResponse(player, "DCUPGRADE_ERROR:Item not found");
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

            // Send response via SYSTEM chat
            std::ostringstream ss;
            ss << "DCUPGRADE_QUERY:" << itemGUID << ":" << upgradeLevel << ":" << tier << ":" << baseItemLevel;
            SendAddonResponse(player, ss.str());
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
                SendAddonResponse(player, "DCUPGRADE_ERROR:Invalid parameters");
                return true;
            }

            Item* item = player->GetItemByPos(bag, slot);
            if (!item)
            {
                SendAddonResponse(player, "DCUPGRADE_ERROR:Item not found");
                return true;
            }

            if (targetLevel > 15)
            {
                SendAddonResponse(player, "DCUPGRADE_ERROR:Max level is 15");
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
                SendAddonResponse(player, "DCUPGRADE_ERROR:Must upgrade to higher level");
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
                SendAddonResponse(player, ss.str());
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
                SendAddonResponse(player, ss.str());
                return true;
            }

            if (currentEssence < essenceNeeded)
            {
                std::ostringstream ss;
                ss << "DCUPGRADE_ERROR:Need " << essenceNeeded << " essence, have " << currentEssence;
                SendAddonResponse(player, ss.str());
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

            // Send success response via SYSTEM chat
            std::ostringstream successMsg;
            successMsg << "DCUPGRADE_SUCCESS:" << itemGUID << ":" << targetLevel;
            SendAddonResponse(player, successMsg.str());

            return true;
        }

        return false;
    }
};

void AddSC_ItemUpgradeCommands()
{
    new ItemUpgradeAddonCommands();
}
