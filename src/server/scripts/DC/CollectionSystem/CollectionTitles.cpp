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

    // Duplicate HandleSetTitle removed; implemented in dc_addon_collection.cpp

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
