/*
 * Dark Chaos - Collection System Addon Shared Header
 * ====================================================
 *
 * Shared definitions between Collection and Wardrobe modules.
 */

#ifndef DC_ADDON_COLLECTION_H
#define DC_ADDON_COLLECTION_H


#include "dc_addon_namespace.h"
#include <vector>
#include <string>
#include <map>
#include <unordered_set>

class Player;
class ItemTemplate;

#include <string>
#include <map>

namespace DCCollection
{
    // Module identifier
    constexpr const char* MODULE = "COLL";

    // Collection types
    enum class CollectionType : uint8
    {
        MOUNT       = 1,
        PET         = 2,
        TOY         = 3,
        HEIRLOOM    = 4,
        TITLE       = 5,
        TRANSMOG    = 6,
        ITEM_SET    = 7
    };

    // Shared Helpers (Implemented in dc_addon_collection.cpp)
    uint32 GetAccountId(Player* player);
    std::string const& GetCharEntryColumn(std::string const& tableName);
    bool WorldTableExists(std::string const& tableName);
    std::vector<uint32> LoadPlayerCollection(uint32 accountId, CollectionType type);
    bool HasCollectionItem(uint32 accountId, CollectionType type, uint32 entryId);

    // Transmog Structures
    struct TransmogAppearanceVariant
    {
        uint32 canonicalItemId = 0;
        uint32 displayId = 0;
        uint32 inventoryType = 0;
        uint32 itemClass = 0;
        uint32 itemSubClass = 0;
        uint32 quality = 0;
        uint32 itemLevel = 0;
        std::string name;
        std::vector<uint32> itemIds;
    };

    // Transmog Helpers (Implemented in dc_addon_wardrobe.cpp)
    std::vector<std::string> const& GetTransmogAppearanceVariantKeysCached();
    uint32 GetTransmogDefinitionsSyncVersionCached();
    std::map<uint32, std::vector<TransmogAppearanceVariant>> const& GetTransmogAppearanceIndexCached();
    bool HasTransmogAppearanceUnlocked(uint32 accountId, uint32 displayId);
    bool IsAppearanceCompatible(uint8 slot, ItemTemplate const* proto, TransmogAppearanceVariant const& variant);
    TransmogAppearanceVariant const* FindBestVariantForSlot(uint32 displayId, uint8 slot, ItemTemplate const* proto);
    void UnlockTransmogAppearance(Player* player, ItemTemplate const* proto, std::string const& source);
    void InvalidateAccountUnlockedTransmogAppearances(uint32 accountId);

    // Additional Transmog Helpers
    uint8 VisualSlotToEquipmentSlot(uint32 visualSlot);
    std::vector<uint32> GetInvTypesForVisualSlot(uint32 visualSlot);
    std::vector<uint32> GetCollectedAppearancesForSlot(Player* player, uint32 visualSlot, std::string const& searchFilter);
    void SendTransmogSlotItemsResponse(Player* player, uint32 visualSlot, uint32 page, std::vector<uint32> const& matchingItemIds, std::string const& searchFilter = "");
    void SendTransmogState(Player* player); // Needed by SetTransmog
}

#endif // DC_ADDON_COLLECTION_H
