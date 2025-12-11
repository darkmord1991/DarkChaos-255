/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 */

#include "MythicPlusRunManager.h"
#include "MythicPlusRewards.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "Item.h"
#include "ItemTemplate.h"
#include "Log.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "StringFormat.h"
#include <algorithm>
#include <random>
#include <tuple>
#include <unordered_set>
#include <vector>

// Universal token that players can exchange for class/spec-appropriate items
constexpr uint32 MYTHIC_VAULT_TOKEN = 101000; // Your existing token item ID

namespace
{
    enum VaultTrack : uint8
    {
        TRACK_RAID  = 0,
        TRACK_MPLUS = 1,
        TRACK_PVP   = 2
    };

    constexpr uint32 SECONDS_PER_WEEK = 7u * 24u * 60u * 60u;

    uint8 MakeGlobalSlotIndex(uint8 trackId, uint8 slotInTrack) // slotInTrack: 1..3
    {
        return static_cast<uint8>(trackId * 3 + slotInTrack);
    }

    void DecodeGlobalSlotIndex(uint8 globalSlot, uint8& outTrackId, uint8& outSlotInTrack)
    {
        // globalSlot is 1..9
        uint8 idx = static_cast<uint8>(globalSlot - 1);
        outTrackId = idx / 3;
        outSlotInTrack = static_cast<uint8>((idx % 3) + 1);
    }

    uint32 CountBits32(uint32 value)
    {
        uint32 count = 0;
        while (value)
        {
            value &= (value - 1);
            ++count;
        }
        return count;
    }
}

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
    uint8 primaryTree = player->GetMostPointsTalentTree(); // Returns 0, 1, or 2
    
    // Map class + tree index to spec name (must match dc_vault_loot_table.spec_name)
    switch (classId)
    {
        case CLASS_WARRIOR:
            if (primaryTree == 0) return "Arms";
            if (primaryTree == 1) return "Fury";
            return "Protection";
        case CLASS_PALADIN:
            if (primaryTree == 0) return "Holy";
            if (primaryTree == 1) return "Protection";
            return "Retribution";
        case CLASS_HUNTER:
            if (primaryTree == 0) return "Beast Mastery";
            if (primaryTree == 1) return "Marksmanship";
            return "Survival";
        case CLASS_ROGUE:
            if (primaryTree == 0) return "Assassination";
            if (primaryTree == 1) return "Combat";
            return "Subtlety";
        case CLASS_PRIEST:
            if (primaryTree == 0) return "Discipline";
            if (primaryTree == 1) return "Holy";
            return "Shadow";
        case CLASS_DEATH_KNIGHT:
            if (primaryTree == 0) return "Blood";
            if (primaryTree == 1) return "Frost";
            return "Unholy";
        case CLASS_SHAMAN:
            if (primaryTree == 0) return "Elemental";
            if (primaryTree == 1) return "Enhancement";
            return "Restoration";
        case CLASS_MAGE:
            if (primaryTree == 0) return "Arcane";
            if (primaryTree == 1) return "Fire";
            return "Frost";
        case CLASS_WARLOCK:
            if (primaryTree == 0) return "Affliction";
            if (primaryTree == 1) return "Demonology";
            return "Destruction";
        case CLASS_DRUID:
            if (primaryTree == 0) return "Balance";
            if (primaryTree == 1) return "Feral";
            return "Restoration";
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

uint32 GetPlayerClassMask(Player* player)
{
    if (!player)
        return 0;

    switch (player->getClass())
    {
        case CLASS_WARRIOR:      return 1;
        case CLASS_PALADIN:      return 2;
        case CLASS_HUNTER:       return 4;
        case CLASS_ROGUE:        return 8;
        case CLASS_PRIEST:       return 16;
        case CLASS_DEATH_KNIGHT: return 32;
        case CLASS_SHAMAN:       return 64;
        case CLASS_DRUID:        return 128;
        case CLASS_MAGE:         return 256;
        case CLASS_WARLOCK:      return 512;
        default:                 return 0;
    }
}

uint8 GetPlayerRoleMask(Player* player)
{
    if (!player)
        return 7;

    std::string spec = GetPlayerSpec(player);
    // Role mask: 1=Tank, 2=Healer, 4=DPS, 7=All
    if (spec == "Protection" || spec == "Blood")
        return 1;
    if (spec == "Holy" || spec == "Discipline" || spec == "Restoration")
        return 2;
    if (spec == "Feral")
        return 5; // Tank + DPS
    return 4;
}

uint32 GetRaidBossProgressForWeek(ObjectGuid::LowType playerGuid, uint32 weekStart)
{
    uint32 weekEnd = weekStart + SECONDS_PER_WEEK;

    // Use instance binds + instance.completedEncounters bitmask to approximate raid boss kills.
    QueryResult result = CharacterDatabase.Query(
        "SELECT i.map, i.completedEncounters, i.resettime "
        "FROM character_instance ci "
        "JOIN instance i ON i.id = ci.instance "
        "WHERE ci.guid = {} AND i.resettime >= {} AND i.resettime < {}",
        playerGuid, weekStart, weekEnd);

    if (!result)
        return 0;

    uint32 bossesKilled = 0;
    do
    {
        Field* fields = result->Fetch();
        uint32 mapId = fields[0].Get<uint32>();
        uint32 completedEncounters = fields[1].Get<uint32>();

        MapEntry const* mapEntry = sMapStore.LookupEntry(mapId);
        if (!mapEntry || !mapEntry->IsRaid())
            continue;

        bossesKilled += CountBits32(completedEncounters);
    } while (result->NextRow());

    return bossesKilled;
}

uint32 GetPvpWinsForWeek(ObjectGuid::LowType playerGuid, uint32 weekStart)
{
    uint32 weekEnd = weekStart + SECONDS_PER_WEEK;

    QueryResult result = CharacterDatabase.Query(
        "SELECT COUNT(*) FROM pvpstats_players p "
        "JOIN pvpstats_battlegrounds b ON b.id = p.battleground_id "
        "WHERE p.character_guid = {} AND p.winner = 1 "
        "AND b.date >= FROM_UNIXTIME({}) AND b.date < FROM_UNIXTIME({})",
        playerGuid, weekStart, weekEnd);

    if (!result)
        return 0;

    return (*result)[0].Get<uint32>();
}

struct WeeklyMPlusSummary
{
    uint8 runs = 0;
    uint8 slotKeyLevel[4] = { 0, 0, 0, 0 }; // 1..3
};

WeeklyMPlusSummary GetMPlusSummaryForWeek(ObjectGuid::LowType playerGuid, uint32 seasonId, uint32 weekStart)
{
    WeeklyMPlusSummary out;
    uint32 weekEnd = weekStart + SECONDS_PER_WEEK;

    QueryResult result = CharacterDatabase.Query(
        "SELECT keystone_level FROM dc_mplus_runs "
        "WHERE character_guid = {} AND season_id = {} AND success = 1 "
        "AND completed_at >= FROM_UNIXTIME({}) AND completed_at < FROM_UNIXTIME({}) "
        "ORDER BY keystone_level DESC LIMIT 8",
        playerGuid, seasonId, weekStart, weekEnd);

    if (!result)
        return out;

    std::vector<uint8> levels;
    do
    {
        levels.push_back((*result)[0].Get<uint8>());
    } while (result->NextRow());

    out.runs = static_cast<uint8>(levels.size());
    if (levels.size() >= 1)
        out.slotKeyLevel[1] = levels[0];
    if (levels.size() >= 4)
        out.slotKeyLevel[2] = levels[3];
    if (levels.size() >= 8)
        out.slotKeyLevel[3] = levels[7];

    return out;
}

bool MythicPlusRunManager::GenerateVaultRewardPool(ObjectGuid::LowType playerGuid, uint32 seasonId, uint32 weekStart)
{
    // Compute weekly progress for all 3 tracks
    WeeklyMPlusSummary mplus = GetMPlusSummaryForWeek(playerGuid, seasonId, weekStart);
    uint32 raidBosses = GetRaidBossProgressForWeek(playerGuid, weekStart);
    uint32 pvpWins = GetPvpWinsForWeek(playerGuid, weekStart);

    // Get config for vault reward mode
    VaultRewardMode rewardMode = static_cast<VaultRewardMode>(sConfigMgr->GetOption<uint32>("MythicPlus.Vault.RewardMode", VAULT_MODE_TOKENS));
    
    // Clear existing reward pool for this player/week
    CharacterDatabase.DirectExecute("DELETE FROM dc_vault_reward_pool WHERE character_guid = {} AND season_id = {} AND week_start = {}",
                                    playerGuid, seasonId, weekStart);
    
    // Get player info for spec-based loot
    Player* player = ObjectAccessor::FindPlayerByLowGUID(playerGuid);

    uint32 classMask = GetPlayerClassMask(player);
    uint8 roleMask = GetPlayerRoleMask(player);
    std::string playerSpec = GetPlayerSpec(player);
    std::string armorType = GetPlayerArmorType(player);

    uint8 mplusThresholds[4] = { 0, GetVaultThreshold(1), GetVaultThreshold(2), GetVaultThreshold(3) };
    uint8 raidThresholds[4] =
    {
        0,
        static_cast<uint8>(sConfigMgr->GetOption<uint32>("MythicPlus.Vault.Raid.Threshold1", 2)),
        static_cast<uint8>(sConfigMgr->GetOption<uint32>("MythicPlus.Vault.Raid.Threshold2", 4)),
        static_cast<uint8>(sConfigMgr->GetOption<uint32>("MythicPlus.Vault.Raid.Threshold3", 6))
    };

    uint8 pvpThresholds[4] =
    {
        0,
        static_cast<uint8>(sConfigMgr->GetOption<uint32>("MythicPlus.Vault.PvP.Threshold1", 1)),
        static_cast<uint8>(sConfigMgr->GetOption<uint32>("MythicPlus.Vault.PvP.Threshold2", 4)),
        static_cast<uint8>(sConfigMgr->GetOption<uint32>("MythicPlus.Vault.PvP.Threshold3", 8))
    };

    uint32 raidItemLevel = sConfigMgr->GetOption<uint32>("MythicPlus.Vault.Raid.ItemLevel", 264);
    uint32 pvpItemLevel = sConfigMgr->GetOption<uint32>("MythicPlus.Vault.PvP.ItemLevel", 264);

    struct Candidate
    {
        uint32 itemId;
        uint16 weight;
    };

    auto fetchCandidates = [&](uint32 targetIlvl) -> std::vector<Candidate>
    {
        std::vector<Candidate> candidates;
        if (!player || !targetIlvl)
            return candidates;

        std::string query = Acore::StringFormat(
            "SELECT item_id, weight FROM dc_vault_loot_table "
            "WHERE (class_mask = 0 OR (class_mask & {}) != 0) "
            "AND (spec_name IS NULL OR spec_name = '{}') "
            "AND ((role_mask & {}) != 0) "
            "AND (armor_type = 'Misc' OR armor_type = '{}') "
            "AND item_level_min <= {} AND item_level_max >= {} "
            "LIMIT 500",
            classMask, playerSpec, uint32(roleMask), armorType, targetIlvl, targetIlvl);

        if (QueryResult result = WorldDatabase.Query(query.c_str()))
        {
            do
            {
                Field* fields = result->Fetch();
                candidates.push_back({ fields[0].Get<uint32>(), fields[1].Get<uint16>() });
            } while (result->NextRow());
        }

        return candidates;
    };

    auto pickWeighted = [&](std::vector<Candidate> const& candidates, std::mt19937& rng, std::unordered_set<uint32>& used) -> uint32
    {
        if (candidates.empty())
            return 0;

        uint32 totalWeight = 0;
        for (Candidate const& c : candidates)
            totalWeight += std::max<uint16>(c.weight, 1);

        std::uniform_int_distribution<uint32> dist(1, std::max<uint32>(totalWeight, 1));

        for (uint32 attempt = 0; attempt < 50; ++attempt)
        {
            uint32 roll = dist(rng);
            uint32 running = 0;
            for (Candidate const& c : candidates)
            {
                running += std::max<uint16>(c.weight, 1);
                if (roll <= running)
                {
                    if (!used.count(c.itemId))
                    {
                        used.insert(c.itemId);
                        return c.itemId;
                    }
                    break;
                }
            }
        }

        // Fallback: first unused
        for (Candidate const& c : candidates)
        {
            if (!used.count(c.itemId))
            {
                used.insert(c.itemId);
                return c.itemId;
            }
        }
        return 0;
    };

    std::random_device rd;
    std::mt19937 rng(rd());
    std::unordered_set<uint32> usedItems;

    auto insertReward = [&](uint8 slotIndex, uint32 itemId, uint32 ilvl)
    {
        CharacterDatabase.DirectExecute(
            "INSERT INTO dc_vault_reward_pool (character_guid, season_id, week_start, item_id, item_level, slot_index) "
            "VALUES ({}, {}, {}, {}, {}, {})",
            playerGuid, seasonId, weekStart, itemId, ilvl, slotIndex);
    };
    
    // Insert up to 9 vault choices (3 tracks x 3 slots), each slot yields ONE reward.
    // Slot indices: 1-3 Raid, 4-6 Mythic+, 7-9 PvP.
    for (uint8 slotInTrack = 1; slotInTrack <= 3; ++slotInTrack)
    {
        // RAID
        if (raidBosses >= raidThresholds[slotInTrack])
        {
            uint8 globalSlot = MakeGlobalSlotIndex(TRACK_RAID, slotInTrack);
            uint32 targetIlvl = raidItemLevel;
            if (rewardMode == VAULT_MODE_TOKENS || !player)
            {
                insertReward(globalSlot, MYTHIC_VAULT_TOKEN, targetIlvl);
            }
            else
            {
                auto candidates = fetchCandidates(targetIlvl);
                uint32 itemId = pickWeighted(candidates, rng, usedItems);
                if (!itemId)
                    insertReward(globalSlot, MYTHIC_VAULT_TOKEN, targetIlvl);
                else
                    insertReward(globalSlot, itemId, targetIlvl);
            }
        }

        // MYTHIC+
        if (mplus.runs >= mplusThresholds[slotInTrack])
        {
            uint8 globalSlot = MakeGlobalSlotIndex(TRACK_MPLUS, slotInTrack);
            uint8 keyLevel = mplus.slotKeyLevel[slotInTrack];
            if (!keyLevel)
                keyLevel = 2;
            uint32 targetIlvl = GetItemLevelForKeystoneLevel(keyLevel);

            if (rewardMode == VAULT_MODE_TOKENS || !player)
            {
                insertReward(globalSlot, MYTHIC_VAULT_TOKEN, targetIlvl);
            }
            else
            {
                auto candidates = fetchCandidates(targetIlvl);
                uint32 itemId = pickWeighted(candidates, rng, usedItems);
                if (!itemId)
                    insertReward(globalSlot, MYTHIC_VAULT_TOKEN, targetIlvl);
                else
                    insertReward(globalSlot, itemId, targetIlvl);
            }
        }

        // PVP
        if (pvpWins >= pvpThresholds[slotInTrack])
        {
            uint8 globalSlot = MakeGlobalSlotIndex(TRACK_PVP, slotInTrack);
            uint32 targetIlvl = pvpItemLevel;
            if (rewardMode == VAULT_MODE_TOKENS || !player)
            {
                insertReward(globalSlot, MYTHIC_VAULT_TOKEN, targetIlvl);
            }
            else
            {
                auto candidates = fetchCandidates(targetIlvl);
                uint32 itemId = pickWeighted(candidates, rng, usedItems);
                if (!itemId)
                    insertReward(globalSlot, MYTHIC_VAULT_TOKEN, targetIlvl);
                else
                    insertReward(globalSlot, itemId, targetIlvl);
            }
        }
    }

    LOG_INFO("mythic.vault", "Generated weekly vault pool for player {} (season {}, week {}): raidBosses={}, mplusRuns={}, pvpWins={}, rewardMode={}",
        playerGuid, seasonId, weekStart, raidBosses, mplus.runs, pvpWins, uint32(rewardMode));
    
    return true;
}

std::vector<std::tuple<uint8, uint32, uint32>> MythicPlusRunManager::GetVaultRewardPool(ObjectGuid::LowType playerGuid, uint32 seasonId, uint32 weekStart)
{
    std::vector<std::tuple<uint8, uint32, uint32>> rewards; // tuple<slotIndex, itemId, itemLevel>
    
    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_MPLUS_VAULT_REWARDS);
    stmt->SetData(0, playerGuid);
    stmt->SetData(1, seasonId);
    stmt->SetData(2, weekStart);
    
    if (PreparedQueryResult result = CharacterDatabase.Query(stmt))
    {
        do
        {
            Field* fields = result->Fetch();
            uint8 slotIndex = fields[0].Get<uint8>();
            uint32 itemId = fields[1].Get<uint32>();
            uint32 itemLevel = fields[2].Get<uint32>();
            rewards.emplace_back(slotIndex, itemId, itemLevel);
        } while (result->NextRow());
    }
    
    return rewards;
}

bool MythicPlusRunManager::ClaimVaultItemReward(Player* player, uint8 slot, uint32 itemId)
{
    if (!player)
        return false;

    if (slot < 1 || slot > 9)
    {
        SendVaultError(player, "Invalid slot selection.");
        return false;
    }
        
    uint32 guidLow = player->GetGUID().GetCounter();
    uint32 seasonId = GetCurrentSeasonId();
    uint32 weekStart = GetWeekStartTimestamp();

    // Ensure weekly vault row exists so claim state is consistent even if player only does Raid/PvP.
    CharacterDatabase.DirectExecute(
        "INSERT IGNORE INTO dc_weekly_vault (character_guid, season_id, week_start) VALUES ({}, {}, {})",
        guidLow, seasonId, weekStart);

    // Check claim state
    QueryResult claimRow = CharacterDatabase.Query(
        "SELECT reward_claimed FROM dc_weekly_vault WHERE character_guid = {} AND season_id = {} AND week_start = {}",
        guidLow, seasonId, weekStart);
    if (claimRow && (*claimRow)[0].Get<bool>())
    {
        SendVaultError(player, "You have already claimed your weekly vault reward.");
        return false;
    }

    // Validate slot is unlocked right now
    uint8 trackId = 0;
    uint8 slotInTrack = 0;
    DecodeGlobalSlotIndex(slot, trackId, slotInTrack);

    bool unlocked = false;
    if (trackId == TRACK_MPLUS)
    {
        WeeklyMPlusSummary mplus = GetMPlusSummaryForWeek(guidLow, seasonId, weekStart);
        unlocked = (mplus.runs >= GetVaultThreshold(slotInTrack));
    }
    else if (trackId == TRACK_RAID)
    {
        uint32 raidBosses = GetRaidBossProgressForWeek(guidLow, weekStart);
        uint32 threshold = sConfigMgr->GetOption<uint32>(
            slotInTrack == 1 ? "MythicPlus.Vault.Raid.Threshold1" : (slotInTrack == 2 ? "MythicPlus.Vault.Raid.Threshold2" : "MythicPlus.Vault.Raid.Threshold3"),
            slotInTrack == 1 ? 2u : (slotInTrack == 2 ? 4u : 6u));
        unlocked = (raidBosses >= threshold);
    }
    else if (trackId == TRACK_PVP)
    {
        uint32 pvpWins = GetPvpWinsForWeek(guidLow, weekStart);
        uint32 threshold = sConfigMgr->GetOption<uint32>(
            slotInTrack == 1 ? "MythicPlus.Vault.PvP.Threshold1" : (slotInTrack == 2 ? "MythicPlus.Vault.PvP.Threshold2" : "MythicPlus.Vault.PvP.Threshold3"),
            slotInTrack == 1 ? 1u : (slotInTrack == 2 ? 4u : 8u));
        unlocked = (pvpWins >= threshold);
    }

    if (!unlocked)
    {
        SendVaultError(player, "This slot is not unlocked.");
        return false;
    }
    
    // Verify the item is in the player's reward pool
    auto rewards = GetVaultRewardPool(guidLow, seasonId, weekStart);
    bool validReward = false;
    uint32 itemLevel = 0;

    for (auto const& [slotIndex, rewardItemId, rewardItemLevel] : rewards)
    {
        if (slotIndex == slot && rewardItemId == itemId)
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

    VaultRewardMode rewardMode = static_cast<VaultRewardMode>(sConfigMgr->GetOption<uint32>("MythicPlus.Vault.RewardMode", VAULT_MODE_TOKENS));

    bool isToken = (itemId == MYTHIC_VAULT_TOKEN) || (rewardMode == VAULT_MODE_TOKENS);

    // Validate template
    ItemTemplate const* itemTemplate = sObjectMgr->GetItemTemplate(itemId);
    if (!itemTemplate)
    {
        SendVaultError(player, "Item template not found.");
        return false;
    }

    uint32 countToGive = 1;
    if (isToken)
    {
        // Base: 10 tokens, +1 per 10 ilvl above 190
        countToGive = 10 + std::max(0, static_cast<int32>((itemLevel - 190) / 10));
    }

    ItemPosCountVec dest;
    uint8 msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, itemId, countToGive);

    if (msg == EQUIP_ERR_OK)
    {
        if (Item* newItem = player->StoreNewItem(dest, itemId, true))
            player->SendNewItem(newItem, countToGive, true, false);
    }
    else
    {
        player->SendItemRetrievalMail(itemId, countToGive);
        ChatHandler(player->GetSession()).SendSysMessage("|cff00ff00[Mythic+]|r Inventory full; your vault reward was mailed.");
    }

    // Log the claim to database
    CharacterDatabase.DirectExecute(
        "UPDATE dc_weekly_vault SET reward_claimed = 1, claimed_slot = {}, claimed_item_id = {}, claimed_tokens = {}, claimed_at = UNIX_TIMESTAMP() "
        "WHERE character_guid = {} AND season_id = {} AND week_start = {}",
        slot, itemId, (isToken ? countToGive : 0), guidLow, seasonId, weekStart);

    CharacterDatabase.DirectExecute(
        "UPDATE dc_vault_reward_pool SET claimed = 1, claimed_at = UNIX_TIMESTAMP() "
        "WHERE character_guid = {} AND season_id = {} AND week_start = {} AND slot_index = {} AND item_id = {}",
        guidLow, seasonId, weekStart, slot, itemId);

    if (isToken)
        ChatHandler(player->GetSession()).PSendSysMessage("|cff00ff00[Mythic+]|r You claimed %u tokens (ilvl %u equivalent).", countToGive, itemLevel);
    else
        ChatHandler(player->GetSession()).SendSysMessage("|cff00ff00[Mythic+]|r You claimed your Great Vault reward.");

    LOG_INFO("mythic.vault", "Player {} claimed vault reward: slot={}, itemId={}, count={}, ilvl={}, season={}, week={}",
        guidLow, uint32(slot), itemId, countToGive, itemLevel, seasonId, weekStart);

    return true;
}
