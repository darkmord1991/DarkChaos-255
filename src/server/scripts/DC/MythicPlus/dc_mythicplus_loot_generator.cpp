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
#include "Containers.h"
#include "Random.h"
#include "SharedDefines.h"
#include "StringFormat.h"
#include <algorithm>
#include <array>
#include <atomic>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

#include "DC/CrossSystem/CrossSystemDbSchema.h"
#include "DC/CrossSystem/CrossSystemItemClassFilter.h"
#include "DC/CrossSystem/CrossSystemVaultUtils.h"
#include "dc_mythicplus_constants.h"

namespace
{
// Chat needs a real |Hitem:...|h link, not coloured plain text, or the player
// cannot shift-click, hover or link what they just won.
std::string BuildItemLink(ItemTemplate const* itemTemplate)
{
    if (!itemTemplate)
        return "[unknown item]";

    uint32 color = ItemQualityColors[std::min<uint32>(itemTemplate->Quality, MAX_ITEM_QUALITY - 1)];
    return Acore::StringFormat("|c{:08x}|Hitem:{}:0:0:0:0:0:0:0:0|h[{}]|h|r",
                               color, itemTemplate->ItemId, itemTemplate->Name1);
}

enum class LootDelivery : uint8
{
    Stored,     // landed in the bags
    Mailed,     // bags genuinely full, sent by mail
    Rejected    // cannot be delivered at all - caller should reroll
};

LootDelivery GivePersonalLoot(Player* player, uint32 itemId, uint32 count = 1)
{
    if (!player)
        return LootDelivery::Rejected;

    ItemPosCountVec dest;
    InventoryResult storeResult = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, itemId, count);
    if (storeResult == EQUIP_ERR_OK)
    {
        if (Item* item = player->StoreNewItem(dest, itemId, true))
        {
            player->SendNewItem(item, count, true, false);
            return LootDelivery::Stored;
        }

        return LootDelivery::Rejected;
    }

    // Only a genuinely full bag justifies the mail fallback. Every other
    // rejection (unique already owned, wrong faction, level requirement, ...)
    // would produce mail the player can never empty, so reroll instead of
    // reporting a reward that does not exist.
    if (storeResult != EQUIP_ERR_INVENTORY_FULL && storeResult != EQUIP_ERR_BAG_FULL)
    {
        LOG_DEBUG("mythic.loot", "Item {} rejected for player {} (InventoryResult {}); rerolling",
                  itemId, player->GetName(), static_cast<uint32>(storeResult));
        return LootDelivery::Rejected;
    }

    player->SendItemRetrievalMail(itemId, count);
    return LootDelivery::Mailed;
}

struct LootQueryStage
{
    bool filterClass;
    bool filterSpec;
    bool filterArmor;
    bool filterRole;
};

// In-memory copy of dc_vault_loot_table (JOIN-filtered against item_template
// at load). Loaded once at startup on the world thread and immutable after,
// so map-thread reads during boss kills need no locking. This replaces the
// old per-pick "ORDER BY RAND() LIMIT 1" queries: one end-of-run reward roll
// could issue up to ~400 synchronous randomized JOIN queries on the map
// thread, stalling the whole instance at the moment of completion.
struct LootTableRow
{
    uint32 itemId = 0;
    uint32 itemLevelMin = 0;
    uint32 itemLevelMax = 0;
    uint32 classMask = 0;
    uint8 roleMask = 0;
    // item_template.MaxCount, cached at load: > 0 means unique-limited, and a
    // player already holding that many can never be given another copy.
    int32 maxCount = 0;
    // Bit (classId - 1) set when the item belongs in that class's gear pool at
    // all - see CrossSystemItemClassFilter.h. Resolved once at load from the
    // item template rather than from the row's class_mask, which is "every
    // class" on most of the pool and cannot be trusted.
    uint16 classEligibility = 0;
    std::string specName;   // empty = all specs (NULL in the table)
    std::string armorType;  // "Misc" = universal
};

// Bit for classId in LootTableRow::classEligibility.
constexpr uint16 ClassEligibilityBit(uint8 classId)
{
    return static_cast<uint16>(1u << (classId - 1));
}

uint16 BuildClassEligibility(uint32 itemId)
{
    ItemTemplate const* proto = sObjectMgr->GetItemTemplate(itemId);
    if (!proto)
        return 0;

    uint16 eligibility = 0;
    for (uint8 classId = CLASS_WARRIOR; classId < MAX_CLASSES; ++classId)
    {
        // Only the ten playable classes get a bit. A class the filter has no
        // profile for is handled at selection time by skipping the gate
        // entirely, so it must not be encoded here as "fits everything".
        if (!DarkChaos::CrossSystem::ItemClassFilter::GetClassGearProfile(classId))
            continue;

        if (DarkChaos::CrossSystem::ItemClassFilter::IsItemForClass(classId, proto))
            eligibility |= ClassEligibilityBit(classId);
    }

    return eligibility;
}

// A MaxCount-limited item the player already owns can never be stored, and
// mailing it is a dead end too - the attachment simply cannot be taken out.
// Treat those as ineligible at selection time so the roll picks something else.
bool PlayerAlreadyAtUniqueLimit(Player* player, LootTableRow const& row)
{
    if (row.maxCount <= 0)
        return false;

    // inBankAlso = true: the unique cap counts bank copies too.
    return player->GetItemCount(row.itemId, true) >= static_cast<uint32>(row.maxCount);
}

// Draws taken while looking for an item the player does not already own.
// Testing every candidate would mean one full inventory scan per row - a
// filtered pool runs to a couple of hundred entries, and a run-end reward
// roll makes one pick per boss reward - so draw a handful of times instead.
// This cannot guarantee a new item, and must not: once a player has cleared
// out the pool for their spec they should still be paid something.
constexpr uint32 UNOWNED_DRAW_ATTEMPTS = 4;

uint32 PickPreferringUnowned(Player* player, std::vector<uint32> const& candidates)
{
    uint32 picked = candidates[urand(0, candidates.size() - 1)];
    if (candidates.size() == 1)
        return picked;

    for (uint32 draw = 1; draw < UNOWNED_DRAW_ATTEMPTS; ++draw)
    {
        // inBankAlso = true: a copy sitting in the bank is still a duplicate.
        if (player->GetItemCount(picked, true) == 0)
            break;

        picked = candidates[urand(0, candidates.size() - 1)];
    }

    return picked;
}

std::vector<LootTableRow> s_lootTable;
// item level -> rows valid at that level. Built once at load so a reward roll
// filters a few dozen candidates instead of rescanning the whole table five
// times (once per fallback stage) for every item it hands out.
std::unordered_map<uint32, std::vector<LootTableRow const*>> s_lootTableByLevel;
std::atomic<bool> s_lootTableLoaded{false};

std::vector<LootTableRow const*> const& GetLootRowsForLevel(uint32 itemLevel)
{
    static const std::vector<LootTableRow const*> empty;
    auto itr = s_lootTableByLevel.find(itemLevel);
    return itr != s_lootTableByLevel.end() ? itr->second : empty;
}

// exclude: item ids the caller has already handed out in this run. Passing
// them in rather than rerolling afterwards keeps the fallback stages honest -
// a stage whose every candidate is already spoken for correctly falls through
// to the next one instead of reporting a pick the caller has to throw away.
bool TrySelectLootItem(Player* player, uint32 targetItemLevel, uint32& outItemId,
                       std::unordered_set<uint32> const* exclude = nullptr)
{
    if (!player)
        return false;

    uint8 classId = player->getClass();
    if (classId == 0)
        return false;

    if (!s_lootTableLoaded.load(std::memory_order_acquire) || s_lootTable.empty())
        return false;

    std::vector<LootTableRow const*> const& levelRows = GetLootRowsForLevel(targetItemLevel);
    if (levelRows.empty())
        return false;

    uint32 classMask = DarkChaos::CrossSystem::VaultUtils::GetPlayerClassMask(player);
    if (classMask == 0) classMask = 1u << (classId - 1);

    // Convention bridge: VaultUtils returns the standard WoW druid bit (1024),
    // but the seed data was authored with the sequential convention where
    // druid occupies bit 512. Bit 512 is unused by any class in the standard
    // convention, so matching both is safe under either data set. (Without
    // this, druids never matched class-filtered rows and always fell through
    // to the unfiltered stage.)
    if (classMask & 1024)
        classMask |= 512;

    std::string spec = DarkChaos::CrossSystem::VaultUtils::GetPlayerSpec(player);
    std::string armor = DarkChaos::CrossSystem::VaultUtils::GetPlayerArmorType(player);
    uint8 roleMask = DarkChaos::CrossSystem::VaultUtils::GetPlayerRoleMask(player);

    static constexpr std::array<LootQueryStage, 5> stages = {{
        { true,  true,  true,  true  },
        { true,  false, true,  true  },
        { true,  false, false, true  },
        { true,  false, false, false },
        { false, false, false, false }
    }};

    // A class the filter has no gear profile for (a custom class) keeps the old
    // behaviour rather than ending up with an empty pool.
    bool const enforceClassGate =
        DarkChaos::CrossSystem::ItemClassFilter::GetClassGearProfile(classId) != nullptr;
    uint16 const classBit = ClassEligibilityBit(classId);

    std::vector<uint32> candidates;
    candidates.reserve(64);

    for (LootQueryStage const& stage : stages)
    {
        candidates.clear();

        for (LootTableRow const* rowPtr : levelRows)
        {
            LootTableRow const& row = *rowPtr;
            // Hard gate, outside the stage filters on purpose: an item that is
            // not this class's gear must not become reachable just because the
            // spec/armor/role stages relaxed, and the last stage relaxes all of
            // them. Without this a rogue reaches intellect leather, a warrior
            // reaches a wand, and a mage reaches a shield - every one of those
            // rows carries an "all classes" class_mask and an armor_type the
            // filters happily accept.
            if (enforceClassGate && !(row.classEligibility & classBit))
                continue;
            if (stage.filterClass && !(row.classMask & classMask) && row.classMask != 1023)
                continue;
            if (stage.filterSpec && !row.specName.empty() && row.specName != spec)
                continue;
            if (stage.filterArmor && row.armorType != armor && row.armorType != "Misc")
                continue;
            if (stage.filterRole && !(row.roleMask & roleMask) && row.roleMask != 7)
                continue;
            // Cheap set lookup before the unique-limit inventory scan below.
            if (exclude && exclude->find(row.itemId) != exclude->end())
                continue;
            if (PlayerAlreadyAtUniqueLimit(player, row))
                continue;

            candidates.push_back(row.itemId);
        }

        if (!candidates.empty())
        {
            outItemId = PickPreferringUnowned(player, candidates);
            return true;
        }
    }

    return false;
}
}

bool MythicPlusRunManager::SelectPooledItemForPlayer(Player* player, uint32 targetItemLevel, uint32& outItemId,
                                                     std::unordered_set<uint32> const* exclude) const
{
    return TrySelectLootItem(player, targetItemLevel, outItemId, exclude);
}

void MythicPlusRunManager::LoadLootTable()
{
    s_lootTable.clear();
    s_lootTableByLevel.clear();

    // Both pools, one engine. dc_vault_loot_table covers ilvl 226-470 for
    // Mythic+ and the Great Vault; dc_heroic_loot_pool covers 200-219 for
    // Heroic and plain Mythic on the Classic/TBC maps, which have no
    // heroic creature templates of their own and would otherwise drop
    // their stock level-20 greens. The bands are disjoint, so a row can
    // only ever be reached by the tier it was authored for.
    //
    // The two tables stay separate on purpose: the Great Vault reads
    // dc_vault_loot_table directly and must not start handing out ilvl
    // 200 gear.
    //
    // Deliberately TWO queries rather than one UNION.
    //
    // A UNION makes the two tables share a fate: anything that upsets it
    // returns no result at all, and the vault rows vanish along with the
    // heroic ones. That is not hypothetical - the first deploy of this
    // feature did exactly that. dc_heroic_loot_pool was created with a
    // bare "DEFAULT CHARSET=utf8mb4", which on MySQL 8 means
    // utf8mb4_0900_ai_ci, while every other table here is
    // utf8mb4_unicode_ci. Unioning spec_name/armor_type across the two
    // collations raises errno 1271 ("illegal mix of collations"), so the
    // statement returned nothing and the server logged
    // "loot table preloaded: 0 entries" - taking down Mythic+ rewards
    // that had worked fine before the heroic pool existed.
    //
    // Loading them independently means a broken or missing heroic pool
    // costs only heroic loot, which is the blast radius it should have.
    auto loadFrom = [](char const* sql, char const* label) -> uint32
    {
        QueryResult result = WorldDatabase.Query(sql);  // sql-ok: compile-time literal
        if (!result)
        {
            LOG_WARN("server.loading", ">> Loot pool '{}' returned no rows", label);
            return 0;
        }

        uint32 loaded = 0;
        uint32 unusable = 0;
        do
        {
            Field* fields = result->Fetch();
            LootTableRow row;
            row.itemId = fields[0].Get<uint32>();
            row.itemLevelMin = fields[1].Get<uint32>();
            row.itemLevelMax = fields[2].Get<uint32>();
            row.classMask = fields[3].Get<uint32>();
            row.roleMask = fields[4].Get<uint8>();
            row.specName = fields[5].IsNull() ? std::string() : fields[5].Get<std::string>();
            row.armorType = fields[6].Get<std::string>();
            row.maxCount = fields[7].Get<int32>();
            row.classEligibility = BuildClassEligibility(row.itemId);
            if (!row.classEligibility)
                ++unusable;

            s_lootTable.push_back(std::move(row));
            ++loaded;
        } while (result->NextRow());

        // Kept in the table rather than dropped: a class the filter has no
        // profile for bypasses the gate, and would lose these rows silently.
        // Worth reporting though - a row no playable class can equip is pool
        // data that will never pay out.
        if (unusable)
        {
            LOG_INFO("server.loading", ">> Loot pool '{}': {} of {} row{} match no playable class",
                     label, unusable, loaded, loaded == 1 ? "" : "s");
        }

        return loaded;
    };

    uint32 vaultRows = loadFrom(
        "SELECT v.item_id, v.item_level_min, v.item_level_max, v.class_mask, v.role_mask, v.spec_name, v.armor_type, it.MaxCount "
        "FROM dc_vault_loot_table v "
        "INNER JOIN item_template it ON it.entry = v.item_id "
        "WHERE it.Quality >= 2 AND it.name NOT LIKE 'NPC Equip %'",
        "dc_vault_loot_table");

    uint32 heroicRows = 0;
    if (DC::DbSchema::WorldTableExists("dc_heroic_loot_pool"))
    {
        heroicRows = loadFrom(
            "SELECT h.item_id, h.item_level_min, h.item_level_max, h.class_mask, h.role_mask, h.spec_name, h.armor_type, it.MaxCount "
            "FROM dc_heroic_loot_pool h "
            "INNER JOIN item_template it ON it.entry = h.item_id "
            "WHERE it.Quality >= 2 AND it.name NOT LIKE 'NPC Equip %'",
            "dc_heroic_loot_pool");
    }
    else
    {
        LOG_WARN("server.loading",
                 ">> dc_heroic_loot_pool is missing; Heroic and plain Mythic dungeons will award no gear. "
                 "Apply Custom/Custom feature SQLs/worlddb/Mythic+/dc_heroic_loot_pool.sql");
    }

    LOG_INFO("server.loading", ">> Loot pools: {} vault rows, {} heroic rows", vaultRows, heroicRows);

    // Index by the item levels the system can actually ask for - one per
    // keystone level, not every integer between the table's min and max.
    // Pointers are stable because s_lootTable is never mutated after this.
    std::vector<uint32> targetItemLevels;
    for (uint8 level = MythicPlusConstants::MIN_KEYSTONE_LEVEL;
         level <= MythicPlusConstants::MAX_KEYSTONE_LEVEL; ++level)
    {
        targetItemLevels.push_back(MythicPlusConstants::GetItemLevelForKeystoneLevel(level));
    }

    // Plus the Heroic band. Every integer in it, because the target comes
    // from dc_dungeon_mythic_profile.loot_ilvl, which is authored per
    // dungeon at odd values (202, 206, 217, ...) rather than off a curve.
    for (uint32 itemLevel = MythicPlusConstants::HEROIC_ITEM_LEVEL_MIN;
         itemLevel <= MythicPlusConstants::HEROIC_ITEM_LEVEL_MAX; ++itemLevel)
    {
        targetItemLevels.push_back(itemLevel);
    }

    for (uint32 targetItemLevel : targetItemLevels)
    {
        if (s_lootTableByLevel.find(targetItemLevel) != s_lootTableByLevel.end())
            continue;

        std::vector<LootTableRow const*>& bucket = s_lootTableByLevel[targetItemLevel];
        for (LootTableRow const& row : s_lootTable)
        {
            if (row.itemLevelMin <= targetItemLevel && row.itemLevelMax >= targetItemLevel)
                bucket.push_back(&row);
        }
    }

    s_lootTableLoaded.store(true, std::memory_order_release);
    LOG_INFO("server.loading", ">> Mythic+ loot table preloaded: {} entries across {} item-level buckets",
             s_lootTable.size(), s_lootTableByLevel.size());
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

    uint32 targetItemLevel = MythicPlusConstants::GetItemLevelForKeystoneLevel(state->keystoneLevel);

    // Randomize selection order so winners are unpredictable
    std::vector<Player*> shuffled = participants;
    Acore::Containers::RandomShuffle(shuffled);

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

        // Everything this player has already been handed on this run. Per
        // player, not per run: two plate wearers both winning the same boots
        // is fine, the same player winning them twice is not.
        std::unordered_set<uint32>& alreadyAwarded =
            state->awardedItemsByPlayer[player->GetGUID().GetCounter()];

        uint32 itemId = 0;
        if (!TrySelectLootItem(player, targetItemLevel, itemId, &alreadyAwarded))
        {
            LOG_WARN("mythic.loot", "No eligible items found for {} (class {}, ilvl {}, {} already awarded this run)",
                     player->GetName(), player->getClass(), targetItemLevel, alreadyAwarded.size());
            continue;
        }
        ItemTemplate const* itemTemplate = sObjectMgr->GetItemTemplate(itemId);
        if (!itemTemplate)
        {
            LOG_ERROR("mythic.loot", "Invalid item template {} referenced for Mythic+ loot", itemId);
            continue;
        }

        LootDelivery delivery = GivePersonalLoot(player, itemId);
        if (delivery == LootDelivery::Rejected)
        {
            LOG_WARN("mythic.loot", "Failed to deliver loot item {} to player {}", itemId, player->GetName());
            continue;
        }

        alreadyAwarded.insert(itemId);
        ++itemsGenerated;

        bool mailed = (delivery == LootDelivery::Mailed);

        LOG_INFO("mythic.loot", "Delivered loot item {} ({}) to player {} (ilvl {}, {})",
                 itemId, itemTemplate->Name1, player->GetName(), itemTemplate->ItemLevel,
                 mailed ? "mailed" : "bags");

        state->lootAwards.push_back({ player->GetGUID().GetCounter(), itemId,
                                      itemTemplate->ItemLevel,
                                      static_cast<uint8>(itemTemplate->Quality), mailed });

        // Addon users see the same list in the result frame, so only clients
        // without DC-MythicPlus get the chat line.
        if (!PlayerUsesRunSummaryAddon(player))
        {
            ChatHandler(player->GetSession()).SendSysMessage(
                Acore::StringFormat("|cff00ff00[Mythic+]|r Reward: {} (ilvl {}){}",
                                     BuildItemLink(itemTemplate), itemTemplate->ItemLevel,
                                     mailed ? " |cffffaa00- bags full, sent by mail|r" : ""));
        }
    }

    if (!itemsGenerated)
    {
        LOG_WARN("mythic.loot", "Mythic+ run generated no loot for map {} instance {}",
                 state->mapId, state->instanceId);
    }
}
