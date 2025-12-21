/*
 * Dark Chaos - Collection System Addon Handler
 * ==============================================
 * 
 * Server-side handler for the DC-Collection addon.
 * Provides retail-like collection management for WoW 3.3.5a.
 * 
 * Features:
 * - Mount collection with speed bonuses
 * - Companion pet collection
 * - Toy box functionality
 * - Heirloom tracking
 * - Title collection
 * - Transmog appearance catalog
 * - Collection shop with currencies
 * - Wishlist system
 * - Delta sync for performance
 * 
 * Message Format:
 * - JSON format: COLL|OPCODE|J|{json}
 * 
 * Copyright (C) 2025 Dark Chaos Development Team
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "WorldSession.h"
#include "Chat.h"
#include "WorldPacket.h"
#include "DatabaseEnv.h"
#include "../AddonExtension/DCAddonNamespace.h"
#include "Config.h"
#include "World.h"
#include "SpellMgr.h"
#include "SpellAuras.h"
#include "Pet.h"
#include <string>
#include <sstream>
#include <unordered_set>
#include <ctime>
#include <functional>

namespace DCCollection
{
    // Module identifier - must match client-side and DCAddonNamespace.h
    constexpr const char* MODULE = DCAddon::Module::COLLECTION;
    
    // =======================================================================
    // Configuration
    // =======================================================================
    namespace Config
    {
        constexpr const char* ENABLED = "DCCollection.Enable";
        constexpr const char* MOUNT_BONUSES_ENABLED = "DCCollection.MountBonuses.Enable";
        constexpr const char* SHOP_ENABLED = "DCCollection.Shop.Enable";
        constexpr const char* WISHLIST_ENABLED = "DCCollection.Wishlist.Enable";
        constexpr const char* WISHLIST_MAX_ITEMS = "DCCollection.Wishlist.MaxItems";
        constexpr const char* SYNC_INTERVAL = "DCCollection.SyncInterval";
    }
    
    // Collection types - matches client-side
    enum class CollectionType : uint8
    {
        MOUNT       = 1,
        PET         = 2,
        TOY         = 3,
        HEIRLOOM    = 4,
        TITLE       = 5,
        TRANSMOG    = 6
    };
    
    // Currency IDs (must match dc_collection_system.sql)
    constexpr uint32 CURRENCY_TOKEN = 1;     // Collection Token
    constexpr uint32 CURRENCY_EMBLEM = 2;    // Collector's Emblem
    
    // Mount speed bonus spell IDs (custom spells in Spell.csv)
    // Range: 300510-300513 (verified free in Spell.csv)
    constexpr uint32 SPELL_MOUNT_SPEED_TIER1 = 300510;  // +1% mount speed (25+ mounts)
    constexpr uint32 SPELL_MOUNT_SPEED_TIER2 = 300511;  // +2% mount speed (50+ mounts)
    constexpr uint32 SPELL_MOUNT_SPEED_TIER3 = 300512;  // +3% mount speed (100+ mounts)
    constexpr uint32 SPELL_MOUNT_SPEED_TIER4 = 300513;  // +5% mount speed (200+ mounts)
    
    // Mount count thresholds for speed bonuses
    constexpr uint32 MOUNT_THRESHOLD_TIER1 = 25;
    constexpr uint32 MOUNT_THRESHOLD_TIER2 = 50;
    constexpr uint32 MOUNT_THRESHOLD_TIER3 = 100;
    constexpr uint32 MOUNT_THRESHOLD_TIER4 = 200;
    
    // =======================================================================
    // Utility Functions
    // =======================================================================
    
    // Generate simple hash for delta sync comparison
    inline uint32 GenerateCollectionHash(const std::vector<uint32>& items)
    {
        uint32 hash = 0;
        for (uint32 item : items)
        {
            hash ^= (item * 2654435761u);  // Knuth's multiplicative hash
            hash = (hash << 13) | (hash >> 19);  // Rotate
        }
        return hash;
    }
    
    // Get player's account ID for account-wide collections
    inline uint32 GetAccountId(Player* player)
    {
        if (!player || !player->GetSession())
            return 0;
        return player->GetSession()->GetAccountId();
    }
    
    // =======================================================================
    // Database Queries
    // =======================================================================
    
    // Load player's collection for a specific type
    std::vector<uint32> LoadPlayerCollection(uint32 accountId, CollectionType type)
    {
        std::vector<uint32> items;
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT entry_id FROM dc_collection_items "
            "WHERE account_id = {} AND collection_type = {} AND unlocked = 1",
            accountId, static_cast<uint8>(type));
        
        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                items.push_back(fields[0].Get<uint32>());
            } while (result->NextRow());
        }
        
        return items;
    }
    
    // Load collection counts for all types
    std::map<CollectionType, uint32> LoadCollectionCounts(uint32 accountId)
    {
        std::map<CollectionType, uint32> counts;
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT collection_type, COUNT(*) FROM dc_collection_items "
            "WHERE account_id = {} AND unlocked = 1 "
            "GROUP BY collection_type",
            accountId);
        
        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                CollectionType type = static_cast<CollectionType>(fields[0].Get<uint8>());
                counts[type] = fields[1].Get<uint32>();
            } while (result->NextRow());
        }
        
        return counts;
    }
    
    // Get total counts for definitions (for % calculations)
    std::map<CollectionType, uint32> LoadTotalDefinitions()
    {
        std::map<CollectionType, uint32> totals;
        
        QueryResult result = WorldDatabase.Query(
            "SELECT collection_type, COUNT(*) FROM dc_collection_definitions "
            "WHERE enabled = 1 "
            "GROUP BY collection_type");
        
        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                CollectionType type = static_cast<CollectionType>(fields[0].Get<uint8>());
                totals[type] = fields[1].Get<uint32>();
            } while (result->NextRow());
        }
        
        return totals;
    }
    
    // Load player currencies
    std::map<uint32, uint32> LoadCurrencies(uint32 accountId)
    {
        std::map<uint32, uint32> currencies;
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT currency_id, amount FROM dc_collection_currency "
            "WHERE account_id = {}",
            accountId);
        
        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                currencies[fields[0].Get<uint32>()] = fields[1].Get<uint32>();
            } while (result->NextRow());
        }
        
        return currencies;
    }
    
    // Load wishlist
    std::vector<std::pair<uint8, uint32>> LoadWishlist(uint32 accountId)
    {
        std::vector<std::pair<uint8, uint32>> wishlist;
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT collection_type, entry_id FROM dc_collection_wishlist "
            "WHERE account_id = {} ORDER BY added_date DESC",
            accountId);
        
        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                wishlist.emplace_back(fields[0].Get<uint8>(), fields[1].Get<uint32>());
            } while (result->NextRow());
        }
        
        return wishlist;
    }
    
    // Check if item is on wishlist
    bool IsOnWishlist(uint32 accountId, CollectionType type, uint32 entryId)
    {
        QueryResult result = CharacterDatabase.Query(
            "SELECT 1 FROM dc_collection_wishlist "
            "WHERE account_id = {} AND collection_type = {} AND entry_id = {}",
            accountId, static_cast<uint8>(type), entryId);
        
        return result != nullptr;
    }
    
    // =======================================================================
    // Mount Speed Bonus Management
    // =======================================================================
    
    void UpdateMountSpeedBonus(Player* player)
    {
        if (!player)
            return;
        
        if (!sConfigMgr->GetOption<bool>(Config::MOUNT_BONUSES_ENABLED, true))
            return;
        
        uint32 accountId = GetAccountId(player);
        if (!accountId)
            return;
        
        // Get mount count
        auto counts = LoadCollectionCounts(accountId);
        uint32 mountCount = counts[CollectionType::MOUNT];
        
        // Remove all existing speed bonuses first
        player->RemoveAurasDueToSpell(SPELL_MOUNT_SPEED_TIER1);
        player->RemoveAurasDueToSpell(SPELL_MOUNT_SPEED_TIER2);
        player->RemoveAurasDueToSpell(SPELL_MOUNT_SPEED_TIER3);
        player->RemoveAurasDueToSpell(SPELL_MOUNT_SPEED_TIER4);
        
        // Apply appropriate tier (only highest)
        if (mountCount >= MOUNT_THRESHOLD_TIER4)
            player->CastSpell(player, SPELL_MOUNT_SPEED_TIER4, true);
        else if (mountCount >= MOUNT_THRESHOLD_TIER3)
            player->CastSpell(player, SPELL_MOUNT_SPEED_TIER3, true);
        else if (mountCount >= MOUNT_THRESHOLD_TIER2)
            player->CastSpell(player, SPELL_MOUNT_SPEED_TIER2, true);
        else if (mountCount >= MOUNT_THRESHOLD_TIER1)
            player->CastSpell(player, SPELL_MOUNT_SPEED_TIER1, true);
    }
    
    // Get current mount speed bonus percentage
    uint8 GetMountSpeedBonusPercent(uint32 mountCount)
    {
        if (mountCount >= MOUNT_THRESHOLD_TIER4)
            return 5;
        else if (mountCount >= MOUNT_THRESHOLD_TIER3)
            return 3;
        else if (mountCount >= MOUNT_THRESHOLD_TIER2)
            return 2;
        else if (mountCount >= MOUNT_THRESHOLD_TIER1)
            return 1;
        return 0;
    }
    
    // Get next mount speed tier threshold
    uint32 GetNextMountThreshold(uint32 mountCount)
    {
        if (mountCount < MOUNT_THRESHOLD_TIER1)
            return MOUNT_THRESHOLD_TIER1;
        else if (mountCount < MOUNT_THRESHOLD_TIER2)
            return MOUNT_THRESHOLD_TIER2;
        else if (mountCount < MOUNT_THRESHOLD_TIER3)
            return MOUNT_THRESHOLD_TIER3;
        else if (mountCount < MOUNT_THRESHOLD_TIER4)
            return MOUNT_THRESHOLD_TIER4;
        return 0;  // Max reached
    }
    
    // =======================================================================
    // Handler Functions - Send Data
    // =======================================================================
    
    void SendHandshakeAck(Player* player, uint32 clientHash)
    {
        if (!player || !player->GetSession())
            return;
        
        uint32 accountId = GetAccountId(player);
        
        // Load all collections and compute server hash
        std::vector<uint32> allItems;
        for (int t = 1; t <= 6; ++t)
        {
            auto items = LoadPlayerCollection(accountId, static_cast<CollectionType>(t));
            allItems.insert(allItems.end(), items.begin(), items.end());
        }
        
        uint32 serverHash = GenerateCollectionHash(allItems);
        bool needsSync = (serverHash != clientHash);
        
        DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_HANDSHAKE_ACK);
        msg.Set("serverHash", serverHash);
        msg.Set("needsSync", needsSync);
        msg.Set("totalItems", static_cast<uint32>(allItems.size()));
        
        msg.Send(player);
    }
    
    void SendFullCollection(Player* player)
    {
        if (!player || !player->GetSession())
            return;
        
        uint32 accountId = GetAccountId(player);
        
        // Build JSON object with all collection types
        DCAddon::JsonValue collections;
        collections.SetObject();
        
        // Load each collection type
        const char* typeNames[] = { "", "mounts", "pets", "toys", "heirlooms", "titles", "transmog" };
        
        for (int t = 1; t <= 6; ++t)
        {
            auto items = LoadPlayerCollection(accountId, static_cast<CollectionType>(t));
            
            DCAddon::JsonValue arr;
            arr.SetArray();
            for (uint32 id : items)
            {
                arr.Push(DCAddon::JsonValue(id));
            }
            collections.Set(typeNames[t], arr);
        }
        
        // Load counts and totals for percentages
        auto counts = LoadCollectionCounts(accountId);
        auto totals = LoadTotalDefinitions();
        
        DCAddon::JsonValue stats;
        stats.SetObject();
        for (int t = 1; t <= 6; ++t)
        {
            CollectionType type = static_cast<CollectionType>(t);
            uint32 owned = counts[type];
            uint32 total = totals[type];
            
            DCAddon::JsonValue typeStat;
            typeStat.SetObject();
            typeStat.Set("owned", owned);
            typeStat.Set("total", total);
            typeStat.Set("percent", total > 0 ? static_cast<double>(owned * 100) / total : 0.0);
            stats.Set(typeNames[t], typeStat);
        }
        
        // Mount speed bonus
        uint32 mountCount = counts[CollectionType::MOUNT];
        DCAddon::JsonValue bonuses;
        bonuses.SetObject();
        bonuses.Set("mountSpeedBonus", GetMountSpeedBonusPercent(mountCount));
        bonuses.Set("nextThreshold", GetNextMountThreshold(mountCount));
        bonuses.Set("mountsToNext", GetNextMountThreshold(mountCount) > 0 ? 
            static_cast<int32>(GetNextMountThreshold(mountCount) - mountCount) : 0);
        
        // Compute hash
        std::vector<uint32> allItems;
        for (int t = 1; t <= 6; ++t)
        {
            auto items = LoadPlayerCollection(accountId, static_cast<CollectionType>(t));
            allItems.insert(allItems.end(), items.begin(), items.end());
        }
        uint32 serverHash = GenerateCollectionHash(allItems);
        
        DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_FULL_COLLECTION);
        msg.Set("collections", collections);
        msg.Set("stats", stats);
        msg.Set("bonuses", bonuses);
        msg.Set("hash", serverHash);
        msg.Set("timestamp", static_cast<uint32>(std::time(nullptr)));
        
        msg.Send(player);
    }
    
    void SendStats(Player* player)
    {
        if (!player || !player->GetSession())
            return;
        
        uint32 accountId = GetAccountId(player);
        auto counts = LoadCollectionCounts(accountId);
        auto totals = LoadTotalDefinitions();
        
        const char* typeNames[] = { "", "mounts", "pets", "toys", "heirlooms", "titles", "transmog" };
        
        DCAddon::JsonValue stats;
        stats.SetObject();
        
        uint32 totalOwned = 0;
        uint32 totalAvailable = 0;
        
        for (int t = 1; t <= 6; ++t)
        {
            CollectionType type = static_cast<CollectionType>(t);
            uint32 owned = counts[type];
            uint32 total = totals[type];
            totalOwned += owned;
            totalAvailable += total;
            
            DCAddon::JsonValue typeStat;
            typeStat.SetObject();
            typeStat.Set("owned", owned);
            typeStat.Set("total", total);
            typeStat.Set("percent", total > 0 ? static_cast<double>(owned * 100) / total : 0.0);
            stats.Set(typeNames[t], typeStat);
        }
        
        stats.Set("totalOwned", totalOwned);
        stats.Set("totalAvailable", totalAvailable);
        stats.Set("totalPercent", totalAvailable > 0 ? 
            static_cast<double>(totalOwned * 100) / totalAvailable : 0.0);
        
        DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_STATS);
        msg.Set("stats", stats);
        
        msg.Send(player);
    }
    
    void SendBonuses(Player* player)
    {
        if (!player || !player->GetSession())
            return;
        
        uint32 accountId = GetAccountId(player);
        auto counts = LoadCollectionCounts(accountId);
        uint32 mountCount = counts[CollectionType::MOUNT];
        
        DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_BONUSES);
        msg.Set("mountSpeedBonus", GetMountSpeedBonusPercent(mountCount));
        msg.Set("mountCount", mountCount);
        msg.Set("nextThreshold", GetNextMountThreshold(mountCount));
        msg.Set("mountsToNext", GetNextMountThreshold(mountCount) > 0 ? 
            static_cast<int32>(GetNextMountThreshold(mountCount) - mountCount) : 0);
        
        // Future bonuses can be added here
        msg.Set("petBonusActive", false);  // Placeholder for pet battle bonus
        msg.Set("toyBonusActive", false);  // Placeholder for toy cooldown reduction
        
        msg.Send(player);
    }
    
    void SendCurrencies(Player* player)
    {
        if (!player || !player->GetSession())
            return;
        
        uint32 accountId = GetAccountId(player);
        auto currencies = LoadCurrencies(accountId);
        
        DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_CURRENCIES);
        msg.Set("tokens", currencies[CURRENCY_TOKEN]);
        msg.Set("emblems", currencies[CURRENCY_EMBLEM]);
        
        msg.Send(player);
    }
    
    void SendShopData(Player* player, const std::string& category)
    {
        if (!player || !player->GetSession())
            return;
        
        if (!sConfigMgr->GetOption<bool>(Config::SHOP_ENABLED, true))
        {
            DCAddon::SendError(player, MODULE, "Shop is currently disabled", 
                DCAddon::ErrorCode::MODULE_DISABLED, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }
        
        uint32 accountId = GetAccountId(player);
        
        // Query shop items based on category
        std::string query = 
            "SELECT id, collection_type, entry_id, price_tokens, price_emblems, "
            "       discount_percent, available_until, stock_remaining, featured "
            "FROM dc_collection_shop "
            "WHERE enabled = 1 AND (available_from IS NULL OR available_from <= NOW()) "
            "  AND (available_until IS NULL OR available_until >= NOW())";
        
        if (!category.empty() && category != "all")
        {
            uint8 typeId = 0;
            if (category == "mounts") typeId = 1;
            else if (category == "pets") typeId = 2;
            else if (category == "toys") typeId = 3;
            else if (category == "heirlooms") typeId = 4;
            else if (category == "titles") typeId = 5;
            else if (category == "transmog") typeId = 6;
            
            if (typeId > 0)
                query += " AND collection_type = " + std::to_string(typeId);
        }
        
        query += " ORDER BY featured DESC, id ASC LIMIT 100";
        
        QueryResult result = WorldDatabase.Query(query);
        
        DCAddon::JsonValue items;
        items.SetArray();
        
        if (result)
        {
            // Get player's owned items to mark as owned
            std::unordered_set<std::string> ownedItems;
            for (int t = 1; t <= 6; ++t)
            {
                auto owned = LoadPlayerCollection(accountId, static_cast<CollectionType>(t));
                for (uint32 id : owned)
                {
                    ownedItems.insert(std::to_string(t) + "_" + std::to_string(id));
                }
            }
            
            do
            {
                Field* fields = result->Fetch();
                
                uint32 shopId = fields[0].Get<uint32>();
                uint8 collType = fields[1].Get<uint8>();
                uint32 entryId = fields[2].Get<uint32>();
                uint32 priceTokens = fields[3].Get<uint32>();
                uint32 priceEmblems = fields[4].Get<uint32>();
                uint8 discount = fields[5].Get<uint8>();
                // fields[6] = available_until (can be null)
                int32 stock = fields[7].IsNull() ? -1 : fields[7].Get<int32>();
                bool featured = fields[8].Get<bool>();
                
                std::string key = std::to_string(collType) + "_" + std::to_string(entryId);
                bool owned = ownedItems.count(key) > 0;
                
                DCAddon::JsonValue item;
                item.SetObject();
                item.Set("shopId", shopId);
                item.Set("type", collType);
                item.Set("entryId", entryId);
                item.Set("priceTokens", priceTokens);
                item.Set("priceEmblems", priceEmblems);
                item.Set("discount", discount);
                item.Set("stock", stock);
                item.Set("featured", featured);
                item.Set("owned", owned);
                
                items.Push(item);
            } while (result->NextRow());
        }
        
        // Get player currencies for display
        auto currencies = LoadCurrencies(accountId);
        
        DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_SHOP_DATA);
        msg.Set("items", items);
        msg.Set("category", category);
        msg.Set("tokens", currencies[CURRENCY_TOKEN]);
        msg.Set("emblems", currencies[CURRENCY_EMBLEM]);
        
        msg.Send(player);
    }
    
    void SendWishlistData(Player* player)
    {
        if (!player || !player->GetSession())
            return;
        
        if (!sConfigMgr->GetOption<bool>(Config::WISHLIST_ENABLED, true))
        {
            DCAddon::SendError(player, MODULE, "Wishlist is currently disabled", 
                DCAddon::ErrorCode::MODULE_DISABLED, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }
        
        uint32 accountId = GetAccountId(player);
        auto wishlist = LoadWishlist(accountId);
        
        DCAddon::JsonValue items;
        items.SetArray();
        
        for (const auto& [type, entryId] : wishlist)
        {
            DCAddon::JsonValue item;
            item.SetObject();
            item.Set("type", type);
            item.Set("entryId", entryId);
            items.Push(item);
        }
        
        uint32 maxItems = sConfigMgr->GetOption<uint32>(Config::WISHLIST_MAX_ITEMS, 25);
        
        DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_WISHLIST_DATA);
        msg.Set("items", items);
        msg.Set("count", static_cast<uint32>(wishlist.size()));
        msg.Set("maxItems", maxItems);
        
        msg.Send(player);
    }
    
    void SendItemLearned(Player* player, CollectionType type, uint32 entryId)
    {
        if (!player || !player->GetSession())
            return;
        
        DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_ITEM_LEARNED);
        msg.Set("type", static_cast<uint8>(type));
        msg.Set("entryId", entryId);
        
        msg.Send(player);
        
        // Check wishlist notification
        uint32 accountId = GetAccountId(player);
        if (IsOnWishlist(accountId, type, entryId))
        {
            DCAddon::JsonMessage wishMsg(MODULE, DCAddon::Opcode::Collection::SMSG_WISHLIST_AVAILABLE);
            wishMsg.Set("type", static_cast<uint8>(type));
            wishMsg.Set("entryId", entryId);
            wishMsg.Set("message", "A wishlist item is now in your collection!");
            wishMsg.Send(player);
            
            // Remove from wishlist
            CharacterDatabase.Execute(
                "DELETE FROM dc_collection_wishlist WHERE account_id = {} AND collection_type = {} AND entry_id = {}",
                accountId, static_cast<uint8>(type), entryId);
        }
    }
    
    // =======================================================================
    // Handler Functions - Process Requests
    // =======================================================================
    
    void HandleBuyItem(Player* player, uint32 shopId)
    {
        if (!player || !player->GetSession())
            return;
        
        if (!sConfigMgr->GetOption<bool>(Config::SHOP_ENABLED, true))
        {
            DCAddon::SendError(player, MODULE, "Shop is currently disabled", 
                DCAddon::ErrorCode::MODULE_DISABLED, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }
        
        uint32 accountId = GetAccountId(player);
        
        // Get shop item details
        QueryResult result = WorldDatabase.Query(
            "SELECT collection_type, entry_id, price_tokens, price_emblems, stock_remaining "
            "FROM dc_collection_shop WHERE id = {} AND enabled = 1",
            shopId);
        
        if (!result)
        {
            DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_PURCHASE_RESULT);
            msg.Set("success", false);
            msg.Set("error", "Item not found or unavailable");
            msg.Send(player);
            return;
        }
        
        Field* fields = result->Fetch();
        uint8 collType = fields[0].Get<uint8>();
        uint32 entryId = fields[1].Get<uint32>();
        uint32 priceTokens = fields[2].Get<uint32>();
        uint32 priceEmblems = fields[3].Get<uint32>();
        int32 stock = fields[4].IsNull() ? -1 : fields[4].Get<int32>();
        
        // Check stock
        if (stock == 0)
        {
            DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_PURCHASE_RESULT);
            msg.Set("success", false);
            msg.Set("error", "Item is out of stock");
            msg.Send(player);
            return;
        }
        
        // Check if already owned
        auto owned = LoadPlayerCollection(accountId, static_cast<CollectionType>(collType));
        if (std::find(owned.begin(), owned.end(), entryId) != owned.end())
        {
            DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_PURCHASE_RESULT);
            msg.Set("success", false);
            msg.Set("error", "You already own this item");
            msg.Send(player);
            return;
        }
        
        // Check currencies
        auto currencies = LoadCurrencies(accountId);
        if (currencies[CURRENCY_TOKEN] < priceTokens || currencies[CURRENCY_EMBLEM] < priceEmblems)
        {
            DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_PURCHASE_RESULT);
            msg.Set("success", false);
            msg.Set("error", "Insufficient currency");
            msg.Send(player);
            return;
        }
        
        // Process purchase - use transaction
        auto trans = CharacterDatabase.BeginTransaction();
        
        // Deduct currencies
        if (priceTokens > 0)
        {
            trans->Append(
                "UPDATE dc_collection_currency SET amount = amount - {} "
                "WHERE account_id = {} AND currency_id = {}",
                priceTokens, accountId, CURRENCY_TOKEN);
        }
        if (priceEmblems > 0)
        {
            trans->Append(
                "UPDATE dc_collection_currency SET amount = amount - {} "
                "WHERE account_id = {} AND currency_id = {}",
                priceEmblems, accountId, CURRENCY_EMBLEM);
        }
        
        // Add to collection
        trans->Append(
            "INSERT INTO dc_collection_items (account_id, collection_type, entry_id, source_type, source_id, unlocked, acquired_date) "
            "VALUES ({}, {}, {}, 'SHOP', {}, 1, NOW()) "
            "ON DUPLICATE KEY UPDATE unlocked = 1, acquired_date = NOW()",
            accountId, collType, entryId, shopId);
        
        // Record purchase
        trans->Append(
            "INSERT INTO dc_collection_shop_purchases (account_id, shop_item_id, character_guid, price_tokens, price_emblems, purchase_date) "
            "VALUES ({}, {}, {}, {}, {}, NOW())",
            accountId, shopId, player->GetGUID().GetCounter(), priceTokens, priceEmblems);
        
        // Update stock if limited
        if (stock > 0)
        {
            WorldDatabase.Execute(
                "UPDATE dc_collection_shop SET stock_remaining = stock_remaining - 1 WHERE id = {}",
                shopId);
        }
        
        CharacterDatabase.CommitTransaction(trans);
        
        // Update mount speed bonus if mount was purchased
        if (collType == static_cast<uint8>(CollectionType::MOUNT))
        {
            UpdateMountSpeedBonus(player);
        }
        
        // Send success response
        auto newCurrencies = LoadCurrencies(accountId);
        
        DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_PURCHASE_RESULT);
        msg.Set("success", true);
        msg.Set("type", collType);
        msg.Set("entryId", entryId);
        msg.Set("tokens", newCurrencies[CURRENCY_TOKEN]);
        msg.Set("emblems", newCurrencies[CURRENCY_EMBLEM]);
        msg.Send(player);
        
        // Send item learned notification
        SendItemLearned(player, static_cast<CollectionType>(collType), entryId);
    }
    
    void HandleAddWishlist(Player* player, uint8 type, uint32 entryId)
    {
        if (!player || !player->GetSession())
            return;
        
        if (!sConfigMgr->GetOption<bool>(Config::WISHLIST_ENABLED, true))
        {
            DCAddon::SendError(player, MODULE, "Wishlist is currently disabled", 
                DCAddon::ErrorCode::MODULE_DISABLED, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }
        
        uint32 accountId = GetAccountId(player);
        uint32 maxItems = sConfigMgr->GetOption<uint32>(Config::WISHLIST_MAX_ITEMS, 25);
        
        // Check current count
        auto wishlist = LoadWishlist(accountId);
        if (wishlist.size() >= maxItems)
        {
            DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_WISHLIST_UPDATED);
            msg.Set("success", false);
            msg.Set("error", "Wishlist is full (max " + std::to_string(maxItems) + " items)");
            msg.Send(player);
            return;
        }
        
        // Check if already on wishlist
        if (IsOnWishlist(accountId, static_cast<CollectionType>(type), entryId))
        {
            DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_WISHLIST_UPDATED);
            msg.Set("success", false);
            msg.Set("error", "Item is already on your wishlist");
            msg.Send(player);
            return;
        }
        
        // Add to wishlist
        CharacterDatabase.Execute(
            "INSERT INTO dc_collection_wishlist (account_id, collection_type, entry_id, added_date) "
            "VALUES ({}, {}, {}, NOW())",
            accountId, type, entryId);
        
        DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_WISHLIST_UPDATED);
        msg.Set("success", true);
        msg.Set("action", "added");
        msg.Set("type", type);
        msg.Set("entryId", entryId);
        msg.Send(player);
    }
    
    void HandleRemoveWishlist(Player* player, uint8 type, uint32 entryId)
    {
        if (!player || !player->GetSession())
            return;
        
        uint32 accountId = GetAccountId(player);
        
        CharacterDatabase.Execute(
            "DELETE FROM dc_collection_wishlist WHERE account_id = {} AND collection_type = {} AND entry_id = {}",
            accountId, type, entryId);
        
        DCAddon::JsonMessage msg(MODULE, DCAddon::Opcode::Collection::SMSG_WISHLIST_UPDATED);
        msg.Set("success", true);
        msg.Set("action", "removed");
        msg.Set("type", type);
        msg.Set("entryId", entryId);
        msg.Send(player);
    }
    
    void HandleSetFavorite(Player* player, uint8 type, uint32 entryId, bool favorite)
    {
        if (!player || !player->GetSession())
            return;
        
        uint32 accountId = GetAccountId(player);
        
        CharacterDatabase.Execute(
            "UPDATE dc_collection_items SET is_favorite = {} "
            "WHERE account_id = {} AND collection_type = {} AND entry_id = {}",
            favorite ? 1 : 0, accountId, type, entryId);
        
        // No response needed, client handles optimistically
    }
    
    // =======================================================================
    // Message Handlers
    // =======================================================================
    
    void HandleHandshake(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!DCAddon::IsJsonMessage(msg))
        {
            SendHandshakeAck(player, 0);
            return;
        }
        
        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        uint32 clientHash = json["hash"].AsUInt32();
        
        SendHandshakeAck(player, clientHash);
    }
    
    void HandleGetFullCollection(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        SendFullCollection(player);
    }
    
    void HandleSyncCollection(Player* player, const DCAddon::ParsedMessage& msg)
    {
        // For delta sync, we just send the full collection for now
        // Future: Implement proper delta sync based on client's last known state
        SendFullCollection(player);
    }
    
    void HandleGetStats(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        SendStats(player);
    }
    
    void HandleGetBonuses(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        SendBonuses(player);
    }
    
    void HandleGetShop(Player* player, const DCAddon::ParsedMessage& msg)
    {
        std::string category = "all";
        
        if (DCAddon::IsJsonMessage(msg))
        {
            DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
            if (json.HasKey("category"))
                category = json["category"].AsString();
        }
        
        SendShopData(player, category);
    }
    
    void HandleBuyItemMessage(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!DCAddon::IsJsonMessage(msg))
        {
            DCAddon::SendError(player, MODULE, "Invalid request format", 
                DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }
        
        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        uint32 shopId = json["shopId"].AsUInt32();
        
        HandleBuyItem(player, shopId);
    }
    
    void HandleGetCurrencies(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        SendCurrencies(player);
    }
    
    void HandleGetWishlist(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        SendWishlistData(player);
    }
    
    void HandleAddWishlistMessage(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!DCAddon::IsJsonMessage(msg))
        {
            DCAddon::SendError(player, MODULE, "Invalid request format", 
                DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }
        
        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        uint8 type = static_cast<uint8>(json["type"].AsUInt32());
        uint32 entryId = json["entryId"].AsUInt32();
        
        HandleAddWishlist(player, type, entryId);
    }
    
    void HandleRemoveWishlistMessage(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!DCAddon::IsJsonMessage(msg))
        {
            DCAddon::SendError(player, MODULE, "Invalid request format", 
                DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Collection::SMSG_ERROR);
            return;
        }
        
        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        uint8 type = static_cast<uint8>(json["type"].AsUInt32());
        uint32 entryId = json["entryId"].AsUInt32();
        
        HandleRemoveWishlist(player, type, entryId);
    }
    
    void HandleSetFavoriteMessage(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!DCAddon::IsJsonMessage(msg))
            return;
        
        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        uint8 type = static_cast<uint8>(json["type"].AsUInt32());
        uint32 entryId = json["entryId"].AsUInt32();
        bool favorite = json["favorite"].AsBool();
        
        HandleSetFavorite(player, type, entryId, favorite);
    }
    
    // =======================================================================
    // Player Event Hooks
    // =======================================================================
    
    class CollectionPlayerScript : public PlayerScript
    {
    public:
        CollectionPlayerScript() : PlayerScript("dc_collection_player") {}
        
        void OnLogin(Player* player) override
        {
            if (!sConfigMgr->GetOption<bool>(Config::ENABLED, true))
                return;
            
            // Apply mount speed bonus on login
            UpdateMountSpeedBonus(player);
        }
        
        void OnLearnSpell(Player* player, uint32 spellId) override
        {
            if (!sConfigMgr->GetOption<bool>(Config::ENABLED, true))
                return;
            
            // Check if this is a mount or pet spell
            // Auto-add to collection if it's a mount/pet
            const SpellInfo* spellInfo = sSpellMgr->GetSpellInfo(spellId);
            if (!spellInfo)
                return;
            
            uint32 accountId = GetAccountId(player);
            if (!accountId)
                return;
            
            // Check for mount effect (SPELL_AURA_MOUNTED)
            bool isMount = false;
            bool isPet = false;
            
            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
            {
                if (spellInfo->Effects[i].ApplyAuraName == SPELL_AURA_MOUNTED)
                {
                    isMount = true;
                    break;
                }
                // Check for companion pet summon
                if (spellInfo->Effects[i].Effect == SPELL_EFFECT_SUMMON &&
                    spellInfo->Effects[i].MiscValueB == 0)  // Non-combat pet
                {
                    // Additional checks could be added here
                    isPet = true;
                }
            }
            
            if (isMount)
            {
                // Add mount to collection
                CharacterDatabase.Execute(
                    "INSERT IGNORE INTO dc_collection_items "
                    "(account_id, collection_type, entry_id, source_type, unlocked, acquired_date) "
                    "VALUES ({}, {}, {}, 'LEARNED', 1, NOW())",
                    accountId, static_cast<uint8>(CollectionType::MOUNT), spellId);
                
                SendItemLearned(player, CollectionType::MOUNT, spellId);
                UpdateMountSpeedBonus(player);
            }
            else if (isPet)
            {
                CharacterDatabase.Execute(
                    "INSERT IGNORE INTO dc_collection_items "
                    "(account_id, collection_type, entry_id, source_type, unlocked, acquired_date) "
                    "VALUES ({}, {}, {}, 'LEARNED', 1, NOW())",
                    accountId, static_cast<uint8>(CollectionType::PET), spellId);
                
                SendItemLearned(player, CollectionType::PET, spellId);
            }
        }
    };
    
    // =======================================================================
    // World Script for Configuration
    // =======================================================================
    
    class CollectionWorldScript : public WorldScript
    {
    public:
        CollectionWorldScript() : WorldScript("dc_collection_world") {}
        
        void OnAfterConfigLoad(bool /*reload*/) override
        {
            // Register module as enabled/disabled based on config
            bool enabled = sConfigMgr->GetOption<bool>(Config::ENABLED, true);
            DCAddon::MessageRouter::Instance().SetModuleEnabled(MODULE, enabled);
            
            if (enabled)
            {
                LOG_INFO("module", "DC-Collection: Module enabled");
            }
        }
    };
    
}  // namespace DCCollection

// =======================================================================
// Script Registration
// =======================================================================

void AddSC_dc_addon_collection()
{
    using namespace DCCollection;
    using namespace DCAddon;
    
    // Register message handlers
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_HANDSHAKE, HandleHandshake);
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_GET_FULL_COLLECTION, HandleGetFullCollection);
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_SYNC_COLLECTION, HandleSyncCollection);
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_GET_STATS, HandleGetStats);
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_GET_BONUSES, HandleGetBonuses);
    
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_GET_SHOP, HandleGetShop);
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_BUY_ITEM, HandleBuyItemMessage);
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_GET_CURRENCIES, HandleGetCurrencies);
    
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_GET_WISHLIST, HandleGetWishlist);
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_ADD_WISHLIST, HandleAddWishlistMessage);
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_REMOVE_WISHLIST, HandleRemoveWishlistMessage);
    
    DC_REGISTER_HANDLER(MODULE, Opcode::Collection::CMSG_SET_FAVORITE, HandleSetFavoriteMessage);
    
    // Register player and world scripts
    new CollectionPlayerScript();
    new CollectionWorldScript();
    
    LOG_INFO("server.loading", ">> Loaded DC-Collection addon handler");
}
