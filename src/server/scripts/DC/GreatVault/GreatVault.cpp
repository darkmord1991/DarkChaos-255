#include "GreatVault.h"
#include "GreatVaultUtils.h"
#include "DC/MythicPlus/MythicPlusRunManager.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "Item.h"
#include "ItemTemplate.h"
#include "Log.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "StringFormat.h"
#include "ScriptMgr.h"
#include "DC/ItemUpgrades/ItemUpgradeManager.h"
#include <algorithm>
#include <random>
#include <unordered_set>

// Universal token that players can exchange for class/spec-appropriate items
// Default: 300311
// uint32 GetMythicVaultTokenId() - Removed, using shared function

namespace
{
    enum VaultTrack : uint8
    {
        TRACK_RAID  = 0,
        TRACK_MPLUS = 1,
        TRACK_PVP   = 2
    };

    constexpr uint32 SECONDS_PER_WEEK = 7u * 24u * 60u * 60u;

    void DecodeGlobalSlotIndex(uint8 globalSlot, uint8& outTrackId, uint8& outSlotInTrack)
    {
        // 1-3: Raid (Track 0)
        // 4-6: M+ (Track 1)
        // 7-9: PvP (Track 2)
        if (globalSlot >= 1 && globalSlot <= 3)
        {
            outTrackId = TRACK_RAID;
            outSlotInTrack = globalSlot;
        }
        else if (globalSlot >= 4 && globalSlot <= 6)
        {
            outTrackId = TRACK_MPLUS;
            outSlotInTrack = globalSlot - 3;
        }
        else if (globalSlot >= 7 && globalSlot <= 9)
        {
            outTrackId = TRACK_PVP;
            outSlotInTrack = globalSlot - 6;
        }
        else
        {
            outTrackId = 0xFF;
            outSlotInTrack = 0;
        }
    }
}

// Vault reward mode configuration
enum VaultRewardMode
{
    VAULT_MODE_TOKENS = 0,  // Give tokens (current behavior)
    VAULT_MODE_GEAR = 1,    // Give actual gear based on spec (Blizzlike)
    VAULT_MODE_BOTH = 2     // Give both tokens AND gear choices
};

GreatVaultMgr* GreatVaultMgr::instance()
{
    static GreatVaultMgr instance;
    return &instance;
}

uint8 GreatVaultMgr::GetVaultThreshold(uint8 slotIndex) const
{
    switch (slotIndex)
    {
        case 1: return sConfigMgr->GetOption<uint32>("MythicPlus.Vault.Threshold1", 1);
        case 2: return sConfigMgr->GetOption<uint32>("MythicPlus.Vault.Threshold2", 4);
        case 3: return sConfigMgr->GetOption<uint32>("MythicPlus.Vault.Threshold3", 8);
        default: return 255;
    }
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
        // uint32 mapId = (*result)[0].Get<uint32>();
        uint32 completedMask = (*result)[1].Get<uint32>();

        // Count set bits in completedMask
        // This is a rough approximation; ideally we'd filter by map difficulty (Raid)
        // But for now, assume all instance saves in this period count if they are raids.
        // (Refinement needed: check MapEntry for IsRaid())

        // Simple bit counting
        uint32 count = 0;
        while (completedMask > 0) {
            if (completedMask & 1) count++;
            completedMask >>= 1;
        }
        bossesKilled += count;

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
        out.slotKeyLevel[1] = levels[0]; // Highest run
    if (levels.size() >= 4)
        out.slotKeyLevel[2] = levels[3]; // 4th highest run
    if (levels.size() >= 8)
        out.slotKeyLevel[3] = levels[7]; // 8th highest run

    return out;
}

bool GreatVaultMgr::GenerateVaultRewardPool(ObjectGuid::LowType playerGuid, uint32 seasonId, uint32 weekStart)
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

    uint32 classMask = DC::VaultUtils::GetPlayerClassMask(player);
    uint8 roleMask = DC::VaultUtils::GetPlayerRoleMask(player);
    std::string playerSpec = DC::VaultUtils::GetPlayerSpec(player);
    std::string armorType = DC::VaultUtils::GetPlayerArmorType(player);

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
        // Query DB for items matching spec/armor/role and ilvl
        // Note: We use a range for ilvl to allow some variance, or exact match
        std::string sql = Acore::StringFormat(
            "SELECT item_id FROM dc_vault_loot_table "
            "WHERE item_level_min <= {} AND item_level_max >= {} "
            "AND ((class_mask & {}) OR class_mask = 1023) "
            "AND (spec_name = '{}' OR spec_name IS NULL) "
            "AND (armor_type = '{}' OR armor_type = 'Misc') "
            "AND ((role_mask & {}) OR role_mask = 7)",
            targetIlvl, targetIlvl, classMask, playerSpec, armorType, roleMask);

        if (QueryResult result = WorldDatabase.Query(sql))
        {
            do
            {
                candidates.push_back({ (*result)[0].Get<uint32>(), 100 });
            } while (result->NextRow());
        }
        return candidates;
    };

    auto pickWeighted = [&](std::vector<Candidate> const& candidates, std::mt19937& rng, std::unordered_set<uint32>& used) -> uint32
    {
        std::vector<Candidate> available;
        for (auto const& c : candidates)
            if (used.find(c.itemId) == used.end())
                available.push_back(c);

        if (available.empty()) return 0;

        std::uniform_int_distribution<size_t> dist(0, available.size() - 1);
        return available[dist(rng)].itemId;
    };

    std::random_device rd;
    std::mt19937 rng(rd());
    std::unordered_set<uint32> usedItems;

    auto insertReward = [&](uint8 slotIndex, uint32 itemId, uint32 ilvl)
    {
        CharacterDatabase.DirectExecute(
            "INSERT INTO dc_vault_reward_pool (character_guid, season_id, week_start, slot_index, item_id, item_level) "
            "VALUES ({}, {}, {}, {}, {}, {})",
            playerGuid, seasonId, weekStart, slotIndex, itemId, ilvl);
    };

    // Insert up to 9 vault choices (3 tracks x 3 slots), each slot yields ONE reward.
    // Slot indices: 1-3 Raid, 4-6 Mythic+, 7-9 PvP.
    for (uint8 slotInTrack = 1; slotInTrack <= 3; ++slotInTrack)
    {
        // --- RAID TRACK ---
        if (raidBosses >= raidThresholds[slotInTrack])
        {
            uint32 itemId = 0;
            if (rewardMode == VAULT_MODE_TOKENS)
                itemId = DarkChaos::ItemUpgrade::GetUpgradeTokenItemId();
            else
            {
                auto candidates = fetchCandidates(raidItemLevel);
                itemId = pickWeighted(candidates, rng, usedItems);
            }

            if (itemId)
            {
                usedItems.insert(itemId);
                insertReward(slotInTrack, itemId, raidItemLevel);
            }
        }

        // --- MYTHIC+ TRACK ---
        if (mplus.runs >= mplusThresholds[slotInTrack])
        {
            uint8 keyLevel = mplus.slotKeyLevel[slotInTrack];
            // Calculate ilvl based on key level (simplified logic here, should match MythicPlusRewards)
            // For now, just a placeholder formula or fetch from config
            uint32 mplusIlvl = 200 + (keyLevel * 3);

            uint32 itemId = 0;
            if (rewardMode == VAULT_MODE_TOKENS)
                itemId = DarkChaos::ItemUpgrade::GetUpgradeTokenItemId();
            else
            {
                auto candidates = fetchCandidates(mplusIlvl);
                itemId = pickWeighted(candidates, rng, usedItems);
            }

            if (itemId)
            {
                usedItems.insert(itemId);
                insertReward(3 + slotInTrack, itemId, mplusIlvl);
            }
        }

        // --- PVP TRACK ---
        if (pvpWins >= pvpThresholds[slotInTrack])
        {
            uint32 itemId = 0;
            if (rewardMode == VAULT_MODE_TOKENS)
                itemId = DarkChaos::ItemUpgrade::GetUpgradeTokenItemId();
            else
            {
                auto candidates = fetchCandidates(pvpItemLevel);
                itemId = pickWeighted(candidates, rng, usedItems);
            }

            if (itemId)
            {
                usedItems.insert(itemId);
                insertReward(6 + slotInTrack, itemId, pvpItemLevel);
            }
        }
    }

    LOG_INFO("mythic.vault", "Generated weekly vault pool for player {} (season {}, week {}): raidBosses={}, mplusRuns={}, pvpWins={}, rewardMode={}",
        playerGuid, seasonId, weekStart, raidBosses, mplus.runs, pvpWins, uint32(rewardMode));

    return true;
}

std::vector<std::tuple<uint8, uint32, uint32>> GreatVaultMgr::GetVaultRewardPool(ObjectGuid::LowType playerGuid, uint32 seasonId, uint32 weekStart)
{
    std::vector<std::tuple<uint8, uint32, uint32>> rewards; // tuple<slotIndex, itemId, itemLevel>

    QueryResult result = CharacterDatabase.Query(
        "SELECT slot_index, item_id, item_level FROM dc_vault_reward_pool "
        "WHERE character_guid = {} AND season_id = {} AND week_start = {}",
        playerGuid, seasonId, weekStart);

    if (result)
    {
        do
        {
            rewards.emplace_back(
                (*result)[0].Get<uint8>(),
                (*result)[1].Get<uint32>(),
                (*result)[2].Get<uint32>()
            );
        } while (result->NextRow());
    }

    return rewards;
}

bool GreatVaultMgr::ClaimVaultItemReward(Player* player, uint8 slot, uint32 itemId)
{
    if (!player)
        return false;

    if (slot < 1 || slot > 9)
        return false;

    uint32 guidLow = player->GetGUID().GetCounter();
    uint32 seasonId = sMythicRuns->GetCurrentSeasonId();
    uint32 weekStart = sMythicRuns->GetWeekStartTimestamp();

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
        ChatHandler(player->GetSession()).SendSysMessage("You have already claimed a reward from the Great Vault this week.");
        return false;
    }

    // Validate slot is unlocked right now
    uint8 trackId = 0;
    uint8 slotInTrack = 0;
    DecodeGlobalSlotIndex(slot, trackId, slotInTrack);

    // Verify the item is actually in the pool for this slot
    QueryResult poolCheck = CharacterDatabase.Query(
        "SELECT item_id FROM dc_vault_reward_pool WHERE character_guid = {} AND season_id = {} AND week_start = {} AND slot_index = {}",
        guidLow, seasonId, weekStart, slot);

    if (!poolCheck || (*poolCheck)[0].Get<uint32>() != itemId)
    {
        ChatHandler(player->GetSession()).SendSysMessage("Invalid reward selection.");
        return false;
    }

    // Give Item
    ItemPosCountVec dest;
    InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, itemId, 1);
    if (msg == EQUIP_ERR_OK)
    {
        if (Item* item = player->StoreNewItem(dest, itemId, true))
        {
            player->SendNewItem(item, 1, true, false);

            // Mark as claimed
            CharacterDatabase.DirectExecute(
                "UPDATE dc_weekly_vault SET reward_claimed = 1, claimed_slot = {} "
                "WHERE character_guid = {} AND season_id = {} AND week_start = {}",
                slot, guidLow, seasonId, weekStart);

            LOG_INFO("mythic.vault", "Player {} claimed vault reward item {} from slot {}", player->GetName(), itemId, slot);
            return true;
        }
    }
    else
    {
        player->SendEquipError(msg, nullptr, nullptr, itemId);
    }

    return false;
}
