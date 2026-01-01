/*
 * CollectionTitles.cpp - DarkChaos Collection System Titles Module
 *
 * Handles title collection and setting.
 * Part of the split collection system implementation.
 */

#include "CollectionCore.h"

namespace DCCollection
{
    // =======================================================================
    // Title Setting
    // =======================================================================

    void HandleSetTitle(Player* player, uint32 titleId)
    {
        if (!player)
            return;

        if (titleId == 0)
        {
            // Clear title
            player->SetUInt32Value(PLAYER_CHOSEN_TITLE, 0);
            ChatHandler(player->GetSession()).PSendSysMessage("Title cleared.");
            return;
        }

        CharTitlesEntry const* titleEntry = sCharTitlesStore.LookupEntry(titleId);
        if (!titleEntry)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("Invalid title.");
            return;
        }

        // Check if player has this title
        if (!player->HasTitle(titleEntry))
        {
            // Check account-wide collection
            uint32 accountId = player->GetSession() ? player->GetSession()->GetAccountId() : 0;
            if (accountId)
            {
                std::string const& entryCol = GetCharEntryColumn("dc_collection_items");
                if (!entryCol.empty())
                {
                    QueryResult r = CharacterDatabase.Query(
                        "SELECT 1 FROM dc_collection_items "
                        "WHERE account_id = {} AND collection_type = {} AND {} = {} AND unlocked = 1",
                        accountId, static_cast<uint8>(CollectionType::TITLE), entryCol, titleId);

                    if (r)
                    {
                        // Grant title temporarily for this session
                        player->SetTitle(titleEntry, false);
                    }
                    else
                    {
                        ChatHandler(player->GetSession()).PSendSysMessage("You don't have this title in your collection.");
                        return;
                    }
                }
            }
        }

        player->SetUInt32Value(PLAYER_CHOSEN_TITLE, titleEntry->bit_index);
        ChatHandler(player->GetSession()).PSendSysMessage("Title set: %s", titleEntry->nameMale[0]);
    }

    // =======================================================================
    // Title Collection Helpers
    // =======================================================================

    uint32 GetPlayerTitleCount(Player* player)
    {
        if (!player)
            return 0;

        uint32 count = 0;
        for (uint32 i = 0; i < sCharTitlesStore.GetNumRows(); ++i)
        {
            CharTitlesEntry const* entry = sCharTitlesStore.LookupEntry(i);
            if (entry && player->HasTitle(entry))
                ++count;
        }
        return count;
    }

}  // namespace DCCollection
