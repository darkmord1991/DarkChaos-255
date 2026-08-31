#include "GreatVault.h"
#include "DC/CrossSystem/CrossSystemVaultUtils.h"
#include "DC/MythicPlus/dc_mythicplus_constants.h"
#include "DC/MythicPlus/dc_mythicplus_run_manager.h"
#include "DC/Seasons/DCWeeklyResetHub.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "Chat.h"
#include "DBCStores.h"
#include "GameTime.h"
#include "Item.h"
#include "ItemTemplate.h"
#include "Log.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "Random.h"
#include "SharedDefines.h"
#include "StringFormat.h"
#include "ScriptMgr.h"
#include "DC/ItemUpgrades/ItemUpgradeManager.h"
#include "DC/CrossSystem/RewardDistributor.h"
#include "DC/CrossSystem/CrossSystemCommon.h"
#include "ObjectGuid.h"
#include <algorithm>
#include <unordered_set>

// Universal token that players can exchange for class/spec-appropriate items
// Resolved from ItemUpgrade/CrossSystem config helpers.
// uint32 GetMythicVaultTokenId() - Removed, using shared function

namespace
{
    enum VaultTrack : uint8
    {
        TRACK_RAID  = 0,
        TRACK_MPLUS = 1,
        TRACK_PVP   = 2
    };

    using DarkChaos::Seasons::SECONDS_PER_WEEK;

    // Chat needs a real |Hitem:...|h link, not coloured plain text, or the
    // player cannot shift-click or hover what the vault just handed them.
    std::string BuildVaultItemLink(ItemTemplate const* itemTemplate)
    {
        if (!itemTemplate)
            return "[unknown item]";

        uint32 color = ItemQualityColors[std::min<uint32>(itemTemplate->Quality, MAX_ITEM_QUALITY - 1)];
        return Acore::StringFormat("|c{:08x}|Hitem:{}:0:0:0:0:0:0:0:0|h[{}]|h|r",
                                   color, itemTemplate->ItemId, itemTemplate->Name1);
    }

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

        bossesKilled += DCUtils::PopCount32(completedMask);

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

    // IMPORTANT (retail-like behavior): do NOT reroll existing rewards.
    // Only generate missing rewards for newly-unlocked slots.

    // Get player info for spec-based loot. If the player is offline, fall back
    // to tokens-only to avoid null-dependent spec/class logic.
    Player* player = ObjectAccessor::FindPlayerByLowGUID(playerGuid);
    if (!player && rewardMode != VAULT_MODE_TOKENS)
    {
        LOG_WARN("mythic.vault", "GreatVault: Player {} is offline; forcing tokens-only reward mode for pool generation", playerGuid);
        rewardMode = VAULT_MODE_TOKENS;
    }

    uint32 classMask = DarkChaos::CrossSystem::VaultUtils::GetPlayerClassMask(player);
    uint8 roleMask = DarkChaos::CrossSystem::VaultUtils::GetPlayerRoleMask(player);
    std::string playerSpec = DarkChaos::CrossSystem::VaultUtils::GetPlayerSpec(player);
    std::string armorType = DarkChaos::CrossSystem::VaultUtils::GetPlayerArmorType(player);

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
                uint32 candidateId = (*result)[0].Get<uint32>();

                // dc_vault_loot_table is hand-maintained and holds entries that
                // no longer exist in item_template. Dropping them here keeps a
                // reward the player can never receive out of the pool.
                if (!sObjectMgr->GetItemTemplate(candidateId))
                {
                    LOG_ERROR("mythic.vault", "dc_vault_loot_table references unknown item {}; skipped", candidateId);
                    continue;
                }

                candidates.push_back({ candidateId, 100 });
            } while (result->NextRow());
        }
        return candidates;
    };

    auto pickWeighted = [&](std::vector<Candidate> const& candidates, std::unordered_set<uint32>& used) -> uint32
    {
        std::vector<Candidate> available;
        for (auto const& c : candidates)
            if (used.find(c.itemId) == used.end())
                available.push_back(c);

        if (available.empty()) return 0;

        return available[urand(0, static_cast<uint32>(available.size() - 1))].itemId;
    };

    std::unordered_set<uint32> usedItems;

    std::unordered_set<uint8> existingSlots;
    if (QueryResult existing = CharacterDatabase.Query(
        "SELECT slot_index, item_id FROM dc_vault_reward_pool WHERE character_guid = {} AND season_id = {} AND week_start = {}",
        playerGuid, seasonId, weekStart))
    {
        do
        {
            uint8 slotIndex = (*existing)[0].Get<uint8>();
            uint32 itemId = (*existing)[1].Get<uint32>();
            existingSlots.insert(slotIndex);
            if (itemId)
                usedItems.insert(itemId);
        } while (existing->NextRow());
    }

    auto insertReward = [&](uint8 slotIndex, uint32 itemId, uint32 tierIlvl)
    {
        // Store the item's own level, not the tier target. dc_vault_loot_table's
        // item_level_min is a tier label rather than a real item level (the
        // "239" tier holds ilvl 213 gear), and the panel shows whatever is
        // stored here - so using the target makes the vault advertise a level
        // the reward does not have. Rewards with no meaningful level of their
        // own (upgrade tokens) keep the tier figure.
        uint32 ilvl = tierIlvl;
        if (ItemTemplate const* proto = sObjectMgr->GetItemTemplate(itemId))
        {
            if ((proto->Class == ITEM_CLASS_ARMOR || proto->Class == ITEM_CLASS_WEAPON) && proto->ItemLevel > 0)
                ilvl = proto->ItemLevel;
        }

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
            uint8 globalSlot = slotInTrack;
            if (existingSlots.find(globalSlot) != existingSlots.end())
                goto mythic_track;

            uint32 itemId = 0;
            if (rewardMode == VAULT_MODE_TOKENS)
                itemId = DarkChaos::ItemUpgrade::GetUpgradeTokenItemId();
            else
            {
                auto candidates = fetchCandidates(raidItemLevel);
                itemId = pickWeighted(candidates, usedItems);
                if (!itemId)
                    itemId = DarkChaos::ItemUpgrade::GetUpgradeTokenItemId();
            }

            if (itemId)
            {
                usedItems.insert(itemId);
                insertReward(globalSlot, itemId, raidItemLevel);
            }
        }

mythic_track:
        // --- MYTHIC+ TRACK ---
        if (mplus.runs >= mplusThresholds[slotInTrack])
        {
            uint8 globalSlot = static_cast<uint8>(3 + slotInTrack);
            if (existingSlots.find(globalSlot) != existingSlots.end())
                goto pvp_track;

            uint8 keyLevel = mplus.slotKeyLevel[slotInTrack];
            // Canonical keystone -> item level mapping (239/252/264/277+), the
            // same one dungeon loot uses. The old placeholder (200 + key * 3)
            // landed below dc_vault_loot_table's lowest band for every key
            // under +13, so every M+ slot silently fell back to a token.
            uint32 mplusIlvl = MythicPlusConstants::GetItemLevelForKeystoneLevel(keyLevel);

            uint32 itemId = 0;
            if (rewardMode == VAULT_MODE_TOKENS)
                itemId = DarkChaos::ItemUpgrade::GetUpgradeTokenItemId();
            else
            {
                auto candidates = fetchCandidates(mplusIlvl);
                itemId = pickWeighted(candidates, usedItems);
                if (!itemId)
                {
                    LOG_WARN("mythic.vault", "GreatVault: no M+ loot candidate for player {} at ilvl {} (key {}, spec '{}', armor '{}'); falling back to a token",
                        playerGuid, mplusIlvl, keyLevel, playerSpec, armorType);
                    itemId = DarkChaos::ItemUpgrade::GetUpgradeTokenItemId();
                }
            }

            if (itemId)
            {
                usedItems.insert(itemId);
                insertReward(globalSlot, itemId, mplusIlvl);
            }
        }

pvp_track:
        // --- PVP TRACK ---
        if (pvpWins >= pvpThresholds[slotInTrack])
        {
            uint8 globalSlot = static_cast<uint8>(6 + slotInTrack);
            if (existingSlots.find(globalSlot) != existingSlots.end())
                continue;

            uint32 itemId = 0;
            if (rewardMode == VAULT_MODE_TOKENS)
                itemId = DarkChaos::ItemUpgrade::GetUpgradeTokenItemId();
            else
            {
                auto candidates = fetchCandidates(pvpItemLevel);
                itemId = pickWeighted(candidates, usedItems);
                if (!itemId)
                    itemId = DarkChaos::ItemUpgrade::GetUpgradeTokenItemId();
            }

            if (itemId)
            {
                usedItems.insert(itemId);
                insertReward(globalSlot, itemId, pvpItemLevel);
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
    // Retail-like grace window: claim LAST week's rewards during the current week.
    uint32 currentWeekStart = sMythicRuns->GetWeekStartTimestamp();
    uint32 weekStart = currentWeekStart >= SECONDS_PER_WEEK ? (currentWeekStart - SECONDS_PER_WEEK) : 0;
    if (weekStart == 0)
        return false;

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
        ChatHandler(player->GetSession()).SendSysMessage("You have already claimed your Great Vault reward.");
        return false;
    }

    // Validate slot is unlocked right now
    [[maybe_unused]] uint8 trackId = 0;
    [[maybe_unused]] uint8 slotInTrack = 0;
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

    ItemTemplate const* itemTemplate = sObjectMgr->GetItemTemplate(itemId);
    if (!itemTemplate)
    {
        // The pool holds an entry that no longer exists in item_template.
        // Refuse rather than burning the player's one claim on nothing.
        LOG_ERROR("mythic.vault", "Vault slot {} for player {} holds unknown item {}; claim refused",
            slot, guidLow, itemId);
        ChatHandler(player->GetSession()).SendSysMessage("That reward is no longer available. Please contact a game master.");
        return false;
    }

    // Give item; DistributeItem mails it if bags are full (no silent data loss).
    if (!DarkChaos::CrossSystem::GetRewardDistributor()->DistributeItem(
            player, itemId, 1, DarkChaos::CrossSystem::SystemId::None, "vault_claim"))
    {
        ChatHandler(player->GetSession()).SendSysMessage("Could not deliver your Great Vault reward. Please try again.");
        return false;
    }

    // Name what was handed over. A stackable reward (upgrade tokens) merges
    // into an existing stack, so without this the player sees no visible
    // change and assumes the claim failed.
    ChatHandler(player->GetSession()).PSendSysMessage("Great Vault reward: {} received.",
        BuildVaultItemLink(itemTemplate));

    // Mark as claimed regardless of whether the item was stored or mailed.
    uint64 now = static_cast<uint64>(GameTime::GetGameTime().count());
    CharacterDatabase.DirectExecute(
        "UPDATE dc_weekly_vault SET reward_claimed = 1, claimed_slot = {}, claimed_item_id = {}, claimed_at = NOW() "
        "WHERE character_guid = {} AND season_id = {} AND week_start = {}",
        slot, itemId, guidLow, seasonId, weekStart);

    CharacterDatabase.DirectExecute(
        "UPDATE dc_vault_reward_pool SET claimed = 1, claimed_at = {} "
        "WHERE character_guid = {} AND season_id = {} AND week_start = {} AND slot_index = {}",
        now, guidLow, seasonId, weekStart, slot);

    LOG_INFO("mythic.vault", "Player {} claimed vault reward item {} from slot {}", player->GetName(), itemId, slot);
    return true;
}
