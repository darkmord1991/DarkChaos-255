/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 */

#include "MythicPlusRunManager.h"
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

// Item level calculation based on keystone level (retail-style)
// This function is used across multiple Mythic+ reward systems
uint32 GetItemLevelForKeystoneLevel(uint8 keystoneLevel)
{
    // Base item levels following retail Mythic+ structure
    // M+2: ilvl 200, M+3: 203, M+4: 207, etc.
    if (keystoneLevel < 2)
        return 190; // Mythic 0 baseline
    if (keystoneLevel <= 7)
        return 200 + ((keystoneLevel - 2) * 3); // M+2-7: 200, 203, 207, 210, 213, 216
    if (keystoneLevel <= 10)
        return 216 + ((keystoneLevel - 7) * 4); // M+8-10: 220, 224, 228
    if (keystoneLevel <= 15)
        return 228 + ((keystoneLevel - 10) * 4); // M+11-15: 232, 236, 240, 244, 248
    
    // Beyond M+15: +3 ilvl per level
    return 248 + ((keystoneLevel - 15) * 3);
}

// Universal token that players can exchange for class/spec-appropriate items
constexpr uint32 MYTHIC_VAULT_TOKEN = 101000; // Your existing token item ID

bool MythicPlusRunManager::GenerateVaultRewardPool(ObjectGuid::LowType playerGuid, uint32 seasonId, uint32 weekStart, uint8 highestKeystoneLevel)
{
    if (highestKeystoneLevel == 0)
        return false;
    
    uint32 itemLevel = GetItemLevelForKeystoneLevel(highestKeystoneLevel);
    
    // Clear existing reward pool for this player/week
    CharacterDatabase.DirectExecute("DELETE FROM dc_vault_reward_pool WHERE character_guid = {} AND season_id = {} AND week_start = {}",
                                    playerGuid, seasonId, weekStart);
    
    // Insert token reward option with calculated item level
    // Players can exchange tokens for appropriate gear at this ilvl
    CharacterDatabase.DirectExecute(
        "INSERT INTO dc_vault_reward_pool (character_guid, season_id, week_start, item_id, item_level, slot_index) "
        "VALUES ({}, {}, {}, {}, {}, 0)",
        playerGuid, seasonId, weekStart, MYTHIC_VAULT_TOKEN, itemLevel);
    
    LOG_INFO("mythic.vault", "Generated vault token reward (ilvl {}) for player {} (season {}, week {}, keystone level {})",
             itemLevel, playerGuid, seasonId, weekStart, highestKeystoneLevel);
    
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
