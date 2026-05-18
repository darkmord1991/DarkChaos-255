/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * Mythic+ Boss Loot Generation System
 * Generates spec-appropriate loot for Mythic+ dungeons (retail-like)
 */

#include "dc_mythicplus_run_manager.h"
#include "Chat.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "Group.h"
#include "Item.h"
#include "ItemTemplate.h"
#include "Log.h"
#include "LootMgr.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "SharedDefines.h"
#include "StringFormat.h"
#include <algorithm>
#include <array>
#include <random>
#include <vector>

#include "DC/CrossSystem/CrossSystemVaultUtils.h"

namespace
{
bool GivePersonalLoot(Player* player, uint32 itemId, uint32 count = 1)
{
    if (!player)
        return false;

    ItemPosCountVec dest;
    InventoryResult storeResult = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, itemId, count);
    if (storeResult == EQUIP_ERR_OK)
    {
        if (Item* item = player->StoreNewItem(dest, itemId, true))
            player->SendNewItem(item, count, true, false);
        return true;
    }

    player->SendItemRetrievalMail(itemId, count);
    ChatHandler(player->GetSession()).SendSysMessage("|cff00ff00[Mythic+]|r Inventory full, loot mailed.");
    return true;
}

struct LootQueryStage
{
    bool filterClass;
    bool filterSpec;
    bool filterArmor;
    bool filterRole;
};

bool TrySelectLootItem(Player* player, uint32 targetItemLevel, uint32& outItemId)
{
    if (!player)
        return false;

    uint8 classId = player->getClass();
    if (classId == 0)
        return false;

    uint32 classMask = DarkChaos::CrossSystem::VaultUtils::GetPlayerClassMask(player);
    if (classMask == 0) classMask = 1u << (classId - 1);

    std::string spec = DarkChaos::CrossSystem::VaultUtils::GetPlayerSpec(player);
    std::string armor = DarkChaos::CrossSystem::VaultUtils::GetPlayerArmorType(player);
    uint8 roleMask = DarkChaos::CrossSystem::VaultUtils::GetPlayerRoleMask(player);

    WorldDatabase.EscapeString(spec);
    WorldDatabase.EscapeString(armor);

    static constexpr std::array<LootQueryStage, 5> stages = {{
        { true,  true,  true,  true  },
        { true,  false, true,  true  },
        { true,  false, false, true  },
        { true,  false, false, false },
        { false, false, false, false }
    }};

    for (const LootQueryStage& stage : stages)
    {
        std::string sql =
            "SELECT v.item_id FROM dc_vault_loot_table v "
            "INNER JOIN item_template it ON it.entry = v.item_id "
            "WHERE it.Quality >= 2 AND it.name NOT LIKE 'NPC Equip %'";

        if (stage.filterClass)
            sql += Acore::StringFormat(" AND ((v.class_mask & {}) OR v.class_mask = 1023)", classMask);
        if (stage.filterSpec)
            sql += Acore::StringFormat(" AND (v.spec_name = '{}' OR v.spec_name IS NULL)", spec);
        if (stage.filterArmor)
            sql += Acore::StringFormat(" AND (v.armor_type = '{}' OR v.armor_type = 'Misc')", armor);
        if (stage.filterRole)
            sql += Acore::StringFormat(" AND ((v.role_mask & {}) OR v.role_mask = 7)", roleMask);

        sql += Acore::StringFormat(
            " AND v.item_level_min <= {} AND v.item_level_max >= {} ORDER BY RAND() LIMIT 1",
            targetItemLevel, targetItemLevel);

        if (QueryResult result = WorldDatabase.Query(sql))
        {
            outItemId = result->Fetch()[0].Get<uint32>();
            return true;
        }
    }

    return false;
}
}

// MythicPlusRunManager is at global scope, not in a namespace
void MythicPlusRunManager::GenerateBossLoot(Creature* boss, Map* map, InstanceState* state)
{
    if (!boss || !map || !state)
        return;

    if (state->keystoneLevel == 0)
        return;

    if (!sConfigMgr->GetOption<bool>("MythicPlus.BossLoot.Enabled", true))
        return;

    bool rewardsAtRunEndOnly =
        sConfigMgr->GetOption<bool>("MythicPlus.RewardsAtRunEndOnly", true);
    if (rewardsAtRunEndOnly && !state->completed)
        return;

    bool suppressNativeLoot = ShouldSuppressLoot(boss);
    boss->SetLootRecipient(nullptr);
    boss->loot.clear();
    boss->loot.gold = 0;
    boss->ResetLootMode();
    boss->RemoveDynamicFlag(UNIT_DYNFLAG_LOOTABLE);

    if (suppressNativeLoot)
    {
        LOG_DEBUG("mythic.loot", "Suppressed native loot for {} (entry {}) in Mythic+ run {}", boss->GetName(), boss->GetEntry(), state->instanceId);
    }

    bool isFinalBoss = IsFinalBossEncounter(state, boss);
    if (isFinalBoss)
    {
        if (state->finalBossLootGranted)
        {
            LOG_DEBUG("mythic.loot", "Final boss loot already granted for instance {}", state->instanceId);
            return;
        }
    }

    uint32 lootTrackingId = boss->GetSpawnId();
    if (!lootTrackingId)
        lootTrackingId = boss->GetEntry();

    if (!state->lootGrantedBosses.insert(lootTrackingId).second)
    {
        LOG_DEBUG("mythic.loot", "Loot already generated for boss {} (entry {}) in instance {}",
                  boss->GetName(), boss->GetEntry(), state->instanceId);
        return;
    }

    if (isFinalBoss)
        state->finalBossLootGranted = true;

    std::vector<Player*> participants;
    Map::PlayerList const& players = map->GetPlayers();
    for (auto const& ref : players)
    {
        if (Player* player = ref.GetSource())
        {
            if (state->participants.find(player->GetGUID().GetCounter()) != state->participants.end())
                participants.push_back(player);
        }
    }

    if (participants.empty())
    {
        LOG_WARN("mythic.loot", "No eligible players present to receive loot for map {} instance {}", state->mapId, state->instanceId);
        return;
    }

    uint32 targetItemLevel = GetItemLevelForKeystoneLevel(state->keystoneLevel);

    // Randomize selection order so winners are unpredictable
    std::vector<Player*> shuffled = participants;
    std::random_device rd;
    std::mt19937 gen(rd());
    std::shuffle(shuffled.begin(), shuffled.end(), gen);

    uint32 desiredCount = isFinalBoss
        ? std::min<uint32>(
            sConfigMgr->GetOption<uint32>("MythicPlus.FinalBossItems", 2),
            5)
        : std::min<uint32>(
            sConfigMgr->GetOption<uint32>("MythicPlus.BossItems", 1),
            5);

    if (rewardsAtRunEndOnly)
    {
        uint32 regularBossItems = std::min<uint32>(
            sConfigMgr->GetOption<uint32>("MythicPlus.BossItems", 1),
            5);
        uint32 finalBossItems = std::min<uint32>(
            sConfigMgr->GetOption<uint32>("MythicPlus.FinalBossItems", 2),
            5);

        uint32 totalBossRewards = 0;
        uint32 finalBossRewards = 0;

        if (!state->bossKillStamps.empty())
        {
            for (auto const& stamp : state->bossKillStamps)
            {
                ++totalBossRewards;
                if (IsFinalBoss(state->mapId, stamp.first))
                    ++finalBossRewards;
            }

            if (finalBossRewards == 0 && isFinalBoss)
                finalBossRewards = 1;
        }
        else
        {
            totalBossRewards = std::max<uint32>(1, state->bossesKilled);
            finalBossRewards = isFinalBoss ? 1u : 0u;
        }

        if (finalBossRewards > totalBossRewards)
            finalBossRewards = totalBossRewards;

        uint32 regularBossRewards = totalBossRewards - finalBossRewards;
        desiredCount =
            (regularBossRewards * regularBossItems) +
            (finalBossRewards * finalBossItems);

        constexpr uint32 kRunEndRewardSafetyCap = 100;
        if (desiredCount > kRunEndRewardSafetyCap)
        {
            LOG_WARN("mythic.loot", "Run-end reward count {} exceeded safety cap {} for map {} instance {}",
                     desiredCount, kRunEndRewardSafetyCap, state->mapId,
                     state->instanceId);
            desiredCount = kRunEndRewardSafetyCap;
        }
    }

    desiredCount = std::max<uint32>(1, desiredCount);
    uint32 itemsRequested = desiredCount;
    uint32 itemsGenerated = 0;

    LOG_INFO("mythic.loot", "Boss {} preparing {} spec-tailored item{} (M+{}, final: {}, rewardsAtRunEndOnly: {}). Eligible players: {}",
             boss->GetName(), itemsRequested, itemsRequested == 1 ? "" : "s",
             state->keystoneLevel, isFinalBoss ? "yes" : "no",
             rewardsAtRunEndOnly ? "yes" : "no", participants.size());

    uint32 attempts = 0;
    uint32 maxAttempts = std::max<uint32>(itemsRequested * 4, shuffled.size());
    while (itemsGenerated < itemsRequested && attempts < maxAttempts)
    {
        Player* player = shuffled[attempts % shuffled.size()];
        ++attempts;

        if (!player)
            continue;

        uint32 itemId = 0;
        if (!TrySelectLootItem(player, targetItemLevel, itemId))
        {
            LOG_WARN("mythic.loot", "No eligible items found for {} (class {}, ilvl {})", player->GetName(), player->getClass(), targetItemLevel);
            continue;
        }
        ItemTemplate const* itemTemplate = sObjectMgr->GetItemTemplate(itemId);
        if (!itemTemplate)
        {
            LOG_ERROR("mythic.loot", "Invalid item template {} referenced for Mythic+ loot", itemId);
            continue;
        }

        if (!GivePersonalLoot(player, itemId))
        {
            LOG_WARN("mythic.loot", "Failed to deliver loot item {} to player {}", itemId, player->GetName());
            continue;
        }

        ++itemsGenerated;

        LOG_INFO("mythic.loot", "Delivered loot item {} ({}) to player {} (ilvl {})", itemId, itemTemplate->Name1, player->GetName(), targetItemLevel);

        ChatHandler(player->GetSession()).SendSysMessage(
            Acore::StringFormat("|cff00ff00[Mythic+]|r Run completion reward: |cff0070dd[{}]|r (ilvl {})",
                                 itemTemplate->Name1, targetItemLevel));
    }

    if (!itemsGenerated)
    {
        LOG_WARN("mythic.loot", "Mythic+ run generated no loot for map {} instance {}",
                 state->mapId, state->instanceId);
    }
}
