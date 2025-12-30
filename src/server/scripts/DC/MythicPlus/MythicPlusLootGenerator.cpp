/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * Mythic+ Boss Loot Generation System
 * Generates spec-appropriate loot for Mythic+ dungeons (retail-like)
 */

#include "MythicPlusRunManager.h"
#include "MythicPlusRewards.h"
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
#include <array>
#include <random>
#include <vector>

#include "DC/CrossSystem/DCVaultUtils.h"

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

    uint32 classMask = DC::VaultUtils::GetPlayerClassMask(player);
    if (classMask == 0) classMask = 1u << (classId - 1);

    std::string spec = DC::VaultUtils::GetPlayerSpec(player);
    std::string armor = DC::VaultUtils::GetPlayerArmorType(player);
    uint8 roleMask = DC::VaultUtils::GetPlayerRoleMask(player);

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
        std::string sql = "SELECT item_id FROM dc_vault_loot_table WHERE 1=1";

        if (stage.filterClass)
            sql += Acore::StringFormat(" AND ((class_mask & {}) OR class_mask = 1023)", classMask);
        if (stage.filterSpec)
            sql += Acore::StringFormat(" AND (spec_name = '{}' OR spec_name IS NULL)", spec);
        if (stage.filterArmor)
            sql += Acore::StringFormat(" AND (armor_type = '{}' OR armor_type = 'Misc')", armor);
        if (stage.filterRole)
            sql += Acore::StringFormat(" AND ((role_mask & {}) OR role_mask = 7)", roleMask);

        sql += Acore::StringFormat(" AND item_level_min <= {} AND item_level_max >= {} ORDER BY RAND() LIMIT 1", targetItemLevel, targetItemLevel);

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

    bool suppressNativeLoot = ShouldSuppressLoot(boss);
    boss->loot.clear();
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
        ? sConfigMgr->GetOption<uint32>("MythicPlus.FinalBossItems", 2)
        : sConfigMgr->GetOption<uint32>("MythicPlus.BossItems", 1);
    desiredCount = std::max<uint32>(1, std::min<uint32>(desiredCount, 5));
    uint32 itemsRequested = std::min<uint32>(desiredCount, shuffled.size());
    uint32 itemsGenerated = 0;

    LOG_INFO("mythic.loot", "Boss {} dropping {} spec-tailored items (M+{}, final: {}). Eligible players: {}",
             boss->GetName(), itemsRequested, state->keystoneLevel, isFinalBoss ? "yes" : "no", participants.size());

    for (Player* player : shuffled)
    {
        if (itemsGenerated >= itemsRequested)
            break;

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
            Acore::StringFormat("|cff00ff00[Mythic+]|r Final boss prepared loot tailored for you: |cff0070dd[{}]|r (ilvl {})",
                                 itemTemplate->Name1, targetItemLevel));
    }

    if (!itemsGenerated)
    {
        LOG_WARN("mythic.loot", "Final boss {} generated no loot for map {} instance {}", boss->GetName(), state->mapId, state->instanceId);
    }
}
