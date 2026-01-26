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
    bool CharacterTableExists(std::string const& tableName);
    bool CharacterColumnExists(std::string const& tableName, std::string const& columnName);
    bool WorldTableExists(std::string const& tableName);
    bool WorldColumnExists(std::string const& tableName, std::string const& columnName);
    std::string const& GetWorldEntryColumn(std::string const& tableName);
    std::string const& GetWishlistIdColumn();
    bool WishlistCollectionTypeIsEnum();
    std::string WishlistTypeToString(uint8 type);
    uint8 WishlistTypeFromString(std::string const& type);
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
    void UnlockTransmogAppearance(Player* player, ItemTemplate const* proto, std::string const& source, bool notifyPlayer = true);
    void InvalidateAccountUnlockedTransmogAppearances(uint32 accountId);

    // Session notification helpers (encapsulate per-translation-unit storage)
    void ClearSessionNotifiedAppearances(uint32 guid);
    void EraseSessionNotifiedAppearances(uint32 guid);

    // Additional Transmog Helpers
    uint8 VisualSlotToEquipmentSlot(uint32 visualSlot);
    std::vector<uint32> GetInvTypesForVisualSlot(uint32 visualSlot);
    std::vector<uint32> GetCollectedAppearancesForSlot(Player* player, uint32 visualSlot, std::string const& searchFilter);
    void SendTransmogSlotItemsResponse(Player* player, uint32 visualSlot, uint32 page, std::vector<uint32> const& matchingItemIds, std::string const& searchFilter = "");
    bool IsBetterTransmogRepresentative(uint32 newEntry, bool newIsNonCustom, uint32 newQuality, uint32 newItemLevel,
        uint32 oldEntry, bool oldIsNonCustom, uint32 oldQuality, uint32 oldItemLevel);
    TransmogAppearanceVariant const* FindAnyVariant(uint32 displayId);
    void SendTransmogState(Player* player); // Needed by SetTransmog

    // Cache helpers (implemented in dc_addon_collection.cpp)
    // Allows other modules to invalidate the per-character transmog cache when DB rows change.
    void InvalidateCharacterTransmogCache(uint32 guid);
}

#endif // DC_ADDON_COLLECTION_H
