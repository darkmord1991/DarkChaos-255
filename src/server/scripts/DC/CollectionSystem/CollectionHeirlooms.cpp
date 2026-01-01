/*
 * CollectionHeirlooms.cpp - DarkChaos Collection System Heirlooms Module
 *
 * Handles heirloom collection and summoning.
 * Part of the split collection system implementation.
 */

#include "CollectionCore.h"
#include "Item.h"

namespace DCCollection
{
    // =======================================================================
    // Heirloom Summoning
    // =======================================================================

    void HandleSummonHeirloom(Player* player, uint32 itemId)
    {
        if (!player)
            return;

        ItemTemplate const* proto = sObjectMgr->GetItemTemplate(itemId);
        if (!proto)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("Invalid heirloom.");
            return;
        }

        // Check if player has this heirloom in collection
        uint32 accountId = player->GetSession() ? player->GetSession()->GetAccountId() : 0;
        if (!accountId)
            return;

        std::string const& entryCol = GetCharEntryColumn("dc_collection_items");
        if (entryCol.empty())
            return;

        QueryResult r = CharacterDatabase.Query(
            "SELECT 1 FROM dc_collection_items "
            "WHERE account_id = {} AND collection_type = {} AND {} = {} AND unlocked = 1",
            accountId, static_cast<uint8>(CollectionType::HEIRLOOM), entryCol, itemId);

        if (!r)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("You don't have this heirloom in your collection.");
            return;
        }

        // Check for free bag space
        ItemPosCountVec dest;
        InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, itemId, 1);
        if (msg != EQUIP_ERR_OK)
        {
            player->SendEquipError(msg, nullptr, nullptr, itemId);
            return;
        }

        // Create the heirloom item
        Item* item = player->StoreNewItem(dest, itemId, true);
        if (item)
        {
            player->SendNewItem(item, 1, true, false);
            ChatHandler(player->GetSession()).PSendSysMessage("Heirloom created: %s", proto->Name1.c_str());
        }
    }

    // =======================================================================
    // Heirloom Detection
    // =======================================================================

    bool IsHeirloomItem(uint32 itemId)
    {
        if (!WorldTableExists("dc_heirloom_definitions"))
            return false;

        QueryResult r = WorldDatabase.Query(
            "SELECT 1 FROM dc_heirloom_definitions WHERE item_id = {} LIMIT 1", itemId);

        return r != nullptr;
    }

}  // namespace DCCollection
