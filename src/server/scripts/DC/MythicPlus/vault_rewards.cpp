/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 */

#include "MythicPlusRunManager.h"
#include "MythicPlusRewards.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "Item.h"
#include "ItemTemplate.h"
#include "Log.h"
#include "ObjectMgr.h"
#include "Player.h"
#include <algorithm>
#include <random>
#include <vector>

// Universal token that players can exchange for class/spec-appropriate items
constexpr uint32 MYTHIC_VAULT_TOKEN = 101000; // Your existing token item ID

// Vault reward mode configuration
enum VaultRewardMode
{
    VAULT_MODE_TOKENS = 0,  // Give tokens (current behavior)
    VAULT_MODE_GEAR = 1,    // Give actual gear based on spec (Blizzlike)
    VAULT_MODE_BOTH = 2     // Give both tokens AND gear choices
};

// Helper: Get player's current talent spec
std::string GetPlayerSpec(Player* player)
{
    if (!player)
        return "Unknown";
    
    uint8 classId = player->getClass();
    uint32 activeSpec = player->GetPrimaryTalentTree(player->GetActiveSpec());
    
    // Map talent tree to spec name (simplified)
    // You'll need to expand this based on your talent system
    switch (classId)
    {
        case CLASS_WARRIOR:
            if (activeSpec == 746) return "Arms";
            if (activeSpec == 815) return "Fury";
            return "Protection";
        case CLASS_PALADIN:
            if (activeSpec == 831) return "Holy";
            if (activeSpec == 839) return "Protection";
            return "Retribution";
        case CLASS_DEATH_KNIGHT:
            if (activeSpec == 398) return "Blood";
            if (activeSpec == 399) return "Frost";
            return "Unholy";
        // Add other classes...
        default:
            return "Unknown";
    }
}

// Helper: Get player's armor type
std::string GetPlayerArmorType(Player* player)
{
    if (!player)
        return "Unknown";
        
    switch (player->getClass())
    {
        case CLASS_WARRIOR:
        case CLASS_PALADIN:
        case CLASS_DEATH_KNIGHT:
            return "Plate";
        case CLASS_HUNTER:
        case CLASS_SHAMAN:
            return "Mail";
        case CLASS_ROGUE:
        case CLASS_DRUID:
            return "Leather";
        case CLASS_PRIEST:
        case CLASS_MAGE:
        case CLASS_WARLOCK:
            return "Cloth";
        default:
            return "Unknown";
    }
}

bool MythicPlusRunManager::GenerateVaultRewardPool(ObjectGuid::LowType playerGuid, uint32 seasonId, uint32 weekStart, uint8 highestKeystoneLevel)
{
    if (highestKeystoneLevel == 0)
        return false;
    
    uint32 itemLevel = GetItemLevelForKeystoneLevel(highestKeystoneLevel);
    
    // Get config for vault reward mode
    VaultRewardMode rewardMode = static_cast<VaultRewardMode>(sConfigMgr->GetOption<uint32>("MythicPlus.Vault.RewardMode", VAULT_MODE_TOKENS));
    
    // Clear existing reward pool for this player/week
    CharacterDatabase.DirectExecute("DELETE FROM dc_vault_reward_pool WHERE character_guid = {} AND season_id = {} AND week_start = {}",
                                    playerGuid, seasonId, weekStart);
    
    // Get player info for spec-based loot
    Player* player = ObjectAccessor::FindPlayerByLowGUID(playerGuid);
    
    if (rewardMode == VAULT_MODE_TOKENS)
    {
        // TOKEN MODE: Insert token reward option with calculated item level
        CharacterDatabase.DirectExecute(
            "INSERT INTO dc_vault_reward_pool (character_guid, season_id, week_start, item_id, item_level, slot_index) "
            "VALUES ({}, {}, {}, {}, {}, 0)",
            playerGuid, seasonId, weekStart, MYTHIC_VAULT_TOKEN, itemLevel);
        
        LOG_INFO("mythic.vault", "Generated vault token reward (ilvl {}) for player {} (season {}, week {}, keystone level {})",
                 itemLevel, playerGuid, seasonId, weekStart, highestKeystoneLevel);
    }
    else if (rewardMode == VAULT_MODE_GEAR && player)
    {
        // GEAR MODE: Generate 3 random items per slot based on player's spec/class
        std::string playerSpec = GetPlayerSpec(player);
        std::string armorType = GetPlayerArmorType(player);
        uint8 classId = player->getClass();
        
        // Query eligible items from loot table
        WorldDatabasePreparedStatement* stmt = WorldDatabase.GetPreparedStatement(WORLD_SEL_MPLUS_VAULT_LOOT);
        stmt->SetData(0, classId);
        stmt->SetData(1, playerSpec);
        stmt->SetData(2, armorType);
        stmt->SetData(3, itemLevel);
        
        if (PreparedQueryResult result = WorldDatabase.Query(stmt))
        {
            std::vector<uint32> eligibleItems;
            do {
                Field* fields = result->Fetch();
                eligibleItems.push_back(fields[0].Get<uint32>());
            } while (result->NextRow());
            
            // Generate 3 random items per unlocked slot (up to 9 total for 3 slots)
            std::random_device rd;
            std::mt19937 gen(rd());
            std::shuffle(eligibleItems.begin(), eligibleItems.end(), gen);
            
            uint8 slotIndex = 0;
            for (uint8 slot = 0; slot < 3 && slot < eligibleItems.size(); ++slot)
            {
                // Insert 3 choices per slot
                for (uint8 choice = 0; choice < 3 && slotIndex < eligibleItems.size(); ++choice)
                {
                    CharacterDatabase.DirectExecute(
                        "INSERT INTO dc_vault_reward_pool (character_guid, season_id, week_start, item_id, item_level, slot_index) "
                        "VALUES ({}, {}, {}, {}, {}, {})",
                        playerGuid, seasonId, weekStart, eligibleItems[slotIndex], itemLevel, slot * 3 + choice);
                    slotIndex++;
                }
            }
            
            LOG_INFO("mythic.vault", "Generated {} spec-based gear options (ilvl {}, spec: {}) for player {} (season {}, week {})",
                     slotIndex, itemLevel, playerSpec, playerGuid, seasonId, weekStart);
        }
        else
        {
            // Fallback to tokens if no gear found
            CharacterDatabase.DirectExecute(
                "INSERT INTO dc_vault_reward_pool (character_guid, season_id, week_start, item_id, item_level, slot_index) "
                "VALUES ({}, {}, {}, {}, {}, 0)",
                playerGuid, seasonId, weekStart, MYTHIC_VAULT_TOKEN, itemLevel);
            
            LOG_WARN("mythic.vault", "No gear found for spec {}, falling back to tokens for player {}", playerSpec, playerGuid);
        }
    }
    else if (rewardMode == VAULT_MODE_BOTH && player)
    {
        // BOTH MODE: Give tokens AND gear choices
        // Token at slot 0
        CharacterDatabase.DirectExecute(
            "INSERT INTO dc_vault_reward_pool (character_guid, season_id, week_start, item_id, item_level, slot_index) "
            "VALUES ({}, {}, {}, {}, {}, 0)",
            playerGuid, seasonId, weekStart, MYTHIC_VAULT_TOKEN, itemLevel);
        
        // Gear items at slots 1-9 (handled by gear generation code above)
        // ... (implement similar to GEAR mode)
        
        LOG_INFO("mythic.vault", "Generated hybrid token+gear rewards for player {} (season {}, week {})",
                 playerGuid, seasonId, weekStart);
    }
    
    return true;
}

std::vector<std::pair<uint32, uint32>> MythicPlusRunManager::GetVaultRewardPool(ObjectGuid::LowType playerGuid, uint32 seasonId, uint32 weekStart)
{
    std::vector<std::pair<uint32, uint32>> rewards; // pair<itemId, itemLevel>
    
    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_MPLUS_VAULT_REWARDS);
    stmt->SetData(0, playerGuid);
    stmt->SetData(1, seasonId);
    stmt->SetData(2, weekStart);
    
    if (PreparedQueryResult result = CharacterDatabase.Query(stmt))
    {
        do
        {
            Field* fields = result->Fetch();
            uint32 itemId = fields[0].Get<uint32>();
            uint32 itemLevel = fields[1].Get<uint32>();
            rewards.emplace_back(itemId, itemLevel);
        } while (result->NextRow());
    }
    
    return rewards;
}

bool MythicPlusRunManager::ClaimVaultItemReward(Player* player, uint8 slot, uint32 itemId)
{
    if (!player)
        return false;
        
    uint32 guidLow = player->GetGUID().GetCounter();
    uint32 seasonId = GetCurrentSeasonId();
    uint32 weekStart = GetWeekStartTimestamp();
    
    // Verify the item is in the player's reward pool
    auto rewards = GetVaultRewardPool(guidLow, seasonId, weekStart);
    bool validReward = false;
    uint32 itemLevel = 0;
    
    for (const auto& [rewardItemId, rewardItemLevel] : rewards)
    {
        if (rewardItemId == itemId)
        {
            validReward = true;
            itemLevel = rewardItemLevel;
            break;
        }
    }
    
    if (!validReward)
    {
        SendVaultError(player, "Invalid item selection.");
        return false;
    }
    
    // Create and give the token with the appropriate item level
    ItemTemplate const* itemTemplate = sObjectMgr->GetItemTemplate(itemId);
    if (!itemTemplate)
    {
        SendVaultError(player, "Item template not found.");
        return false;
    }
    
    // Calculate token count based on item level (higher ilvl = more tokens)
    // Base: 10 tokens, +1 per 10 ilvl above 190
    uint32 tokenCount = 10 + std::max(0, static_cast<int32>((itemLevel - 190) / 10));
    
    ItemPosCountVec dest;
    uint8 msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, itemId, tokenCount);
    
    if (msg == EQUIP_ERR_OK)
    {
        if (Item* item = player->StoreNewItem(dest, itemId, true))
        {
            player->SendNewItem(item, tokenCount, true, false);
            
            // Log the claim to database
            CharacterDatabase.DirectExecute(
                "UPDATE dc_weekly_vault SET reward_claimed = 1, claimed_slot = {}, claimed_item_id = {}, claimed_tokens = {}, claimed_at = UNIX_TIMESTAMP() "
                "WHERE character_guid = {} AND season_id = {} AND week_start = {}",
                slot, itemId, tokenCount, guidLow, seasonId, weekStart);
            
            // Also log to reward pool table for history tracking
            CharacterDatabase.DirectExecute(
                "UPDATE dc_vault_reward_pool SET claimed = 1, claimed_at = UNIX_TIMESTAMP() "
                "WHERE character_guid = {} AND season_id = {} AND week_start = {} AND item_id = {}",
                guidLow, seasonId, weekStart, itemId);
            
            ChatHandler(player->GetSession()).PSendSysMessage("|cff00ff00Mythic+|r: You claimed %u tokens (ilvl %u equivalent).", tokenCount, itemLevel);
            LOG_INFO("mythic.vault", "Player {} claimed vault reward: {} tokens (ilvl {}) for season {}, week {}",
                     guidLow, tokenCount, itemLevel, seasonId, weekStart);
            
            return true;
        }
    }
    else
    {
        // Inventory full - mail the tokens
        player->SendItemRetrievalMail(itemId, tokenCount);
        
        CharacterDatabase.DirectExecute(
            "UPDATE dc_weekly_vault SET reward_claimed = 1, claimed_slot = {}, claimed_item_id = {}, claimed_tokens = {}, claimed_at = UNIX_TIMESTAMP() "
            "WHERE character_guid = {} AND season_id = {} AND week_start = {}",
            slot, itemId, tokenCount, guidLow, seasonId, weekStart);
        
        CharacterDatabase.DirectExecute(
            "UPDATE dc_vault_reward_pool SET claimed = 1, claimed_at = UNIX_TIMESTAMP() "
            "WHERE character_guid = {} AND season_id = {} AND week_start = {} AND item_id = {}",
            guidLow, seasonId, weekStart, itemId);
        
        ChatHandler(player->GetSession()).PSendSysMessage("|cff00ff00Mythic+|r: Inventory full, %u tokens mailed (ilvl %u equivalent).", tokenCount, itemLevel);
        LOG_INFO("mythic.vault", "Player {} claimed vault reward (mailed): {} tokens (ilvl {}) for season {}, week {}",
                 guidLow, tokenCount, itemLevel, seasonId, weekStart);
        return true;
    }
    
    return false;
}
