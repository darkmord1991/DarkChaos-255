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

    // Duplicate HandleSummonHeirloom removed; implemented in dc_addon_collection.cpp

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
