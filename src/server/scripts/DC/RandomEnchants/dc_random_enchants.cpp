/*
 * DarkChaos Random Enchants System
 *
 * Integration port of azerothcore/mod-random-enchants with DC naming,
 * stronger validation, safer enchant slot usage, and runtime data caching.
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Item.h"
#include "Chat.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "Log.h"
#include "Random.h"

#include <algorithm>
#include <array>
#include <cctype>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace
{

template <typename T>
T GetCompatOption(char const* dcKey, char const* legacyKey, T const& defaultValue)
{
    T const legacyValue = sConfigMgr->GetOption<T>(legacyKey, defaultValue, false);
    return sConfigMgr->GetOption<T>(dcKey, legacyValue, false);
}

struct RandomEnchantsConfig
{
    bool enabled = true;

    bool onLoot = true;
    bool onCreate = true;
    bool onQuestReward = true;
    bool onGroupRoll = true;

    float enchantChance1 = 70.0f;
    float enchantChance2 = 65.0f;
    float enchantChance3 = 60.0f;
    uint8 maxEnchantsPerItem = 3;

    bool allowWeapons = true;
    bool allowArmor = true;
    uint8 minQuality = ITEM_QUALITY_NORMAL;
    uint8 maxQuality = ITEM_QUALITY_LEGENDARY;

    bool skipIfRandomPropertyPresent = true;
    bool notifyOnApply = true;
    bool debug = false;

    void Load()
    {
        enabled = GetCompatOption<bool>(
            "DC.RandomEnchants.Enable",
            "RandomEnchants.Enable",
            true);

        onLoot = GetCompatOption<bool>(
            "DC.RandomEnchants.OnLoot",
            "RandomEnchants.OnLoot",
            true);
        onCreate = GetCompatOption<bool>(
            "DC.RandomEnchants.OnCreate",
            "RandomEnchants.OnCreate",
            true);
        onQuestReward = GetCompatOption<bool>(
            "DC.RandomEnchants.OnQuestReward",
            "RandomEnchants.OnQuestReward",
            true);
        onGroupRoll = GetCompatOption<bool>(
            "DC.RandomEnchants.OnGroupRoll",
            "RandomEnchants.OnGroupRoll",
            true);

        enchantChance1 = GetCompatOption<float>(
            "DC.RandomEnchants.EnchantChance1",
            "RandomEnchants.EnchantChance1",
            70.0f);
        enchantChance2 = GetCompatOption<float>(
            "DC.RandomEnchants.EnchantChance2",
            "RandomEnchants.EnchantChance2",
            65.0f);
        enchantChance3 = GetCompatOption<float>(
            "DC.RandomEnchants.EnchantChance3",
            "RandomEnchants.EnchantChance3",
            60.0f);
        maxEnchantsPerItem = GetCompatOption<uint8>(
            "DC.RandomEnchants.MaxEnchantsPerItem",
            "RandomEnchants.MaxEnchantsPerItem",
            3);

        allowWeapons = GetCompatOption<bool>(
            "DC.RandomEnchants.AllowWeapons",
            "RandomEnchants.AllowWeapons",
            true);
        allowArmor = GetCompatOption<bool>(
            "DC.RandomEnchants.AllowArmor",
            "RandomEnchants.AllowArmor",
            true);
        minQuality = GetCompatOption<uint8>(
            "DC.RandomEnchants.MinQuality",
            "RandomEnchants.MinQuality",
            ITEM_QUALITY_NORMAL);
        maxQuality = GetCompatOption<uint8>(
            "DC.RandomEnchants.MaxQuality",
            "RandomEnchants.MaxQuality",
            ITEM_QUALITY_LEGENDARY);

        skipIfRandomPropertyPresent = GetCompatOption<bool>(
            "DC.RandomEnchants.SkipIfRandomPropertyPresent",
            "RandomEnchants.SkipIfRandomPropertyPresent",
            true);
        notifyOnApply = GetCompatOption<bool>(
            "DC.RandomEnchants.NotifyOnApply",
            "RandomEnchants.NotifyOnApply",
            true);
        debug = GetCompatOption<bool>(
            "DC.RandomEnchants.Debug",
            "RandomEnchants.Debug",
            false);

        enchantChance1 = std::clamp(enchantChance1, 0.0f, 100.0f);
        enchantChance2 = std::clamp(enchantChance2, 0.0f, 100.0f);
        enchantChance3 = std::clamp(enchantChance3, 0.0f, 100.0f);
        maxEnchantsPerItem = std::clamp<uint8>(maxEnchantsPerItem, 1, 3);

        minQuality = std::min<uint8>(minQuality, ITEM_QUALITY_LEGENDARY);
        maxQuality = std::min<uint8>(maxQuality, ITEM_QUALITY_LEGENDARY);
        if (minQuality > maxQuality)
            minQuality = maxQuality;

        if (debug)
        {
            LOG_INFO(
                "scripts.dc",
                "DC-RandomEnchants: cfg enabled={}, loot={}, create={}, "
                "quest={}, roll={}, chances=[{:.1f},{:.1f},{:.1f}], "
                "maxEnchants={}, quality=[{},{}], allowWeapon={}, "
                "allowArmor={}, skipExisting={}, notify={}",
                enabled,
                onLoot,
                onCreate,
                onQuestReward,
                onGroupRoll,
                enchantChance1,
                enchantChance2,
                enchantChance3,
                maxEnchantsPerItem,
                minQuality,
                maxQuality,
                allowWeapons,
                allowArmor,
                skipIfRandomPropertyPresent,
                notifyOnApply);
        }
    }
};

struct TierPools
{
    std::vector<uint32> any;
    std::vector<uint32> weapon;
    std::vector<uint32> armor;
    std::unordered_map<uint32, std::vector<uint32>> weaponBySubClass;
    std::unordered_map<uint32, std::vector<uint32>> armorBySubClass;
};

struct EnchantPools
{
    std::array<TierPools, 6> byTier;
    bool loaded = false;
    uint32 loadedRows = 0;
    uint32 skippedRows = 0;

    void Clear()
    {
        for (TierPools& pools : byTier)
        {
            pools.any.clear();
            pools.weapon.clear();
            pools.armor.clear();
            pools.weaponBySubClass.clear();
            pools.armorBySubClass.clear();
        }

        loaded = false;
        loadedRows = 0;
        skippedRows = 0;
    }
};

RandomEnchantsConfig sConfig;
EnchantPools sPools;

void AppendCandidates(std::vector<uint32>& out, std::vector<uint32> const& in)
{
    out.insert(out.end(), in.begin(), in.end());
}

std::string ToUpper(std::string value)
{
    std::transform(value.begin(), value.end(), value.begin(), [](unsigned char ch)
    {
        return static_cast<char>(std::toupper(ch));
    });

    return value;
}

void LoadEnchantPools()
{
    sPools.Clear();

    if (!sConfig.enabled)
    {
        LOG_INFO("scripts.dc", "DC-RandomEnchants: disabled by config");
        return;
    }

    QueryResult result = WorldDatabase.Query(
        "SELECT enchantID, tier, class, exclusiveSubClass "
        "FROM dc_item_enchantment_random_tiers");

    if (!result)
    {
        LOG_WARN(
            "scripts.dc",
            "DC-RandomEnchants: Missing or empty table "
            "dc_item_enchantment_random_tiers; feature disabled");
        return;
    }

    do
    {
        Field* fields = result->Fetch();
        uint32 const enchantId = fields[0].Get<uint32>();
        uint8 const tier = fields[1].Get<uint8>();
        std::string const classToken = ToUpper(fields[2].Get<std::string>());
        int32 const subClass = fields[3].IsNull() ? -1 : fields[3].Get<int32>();

        if (tier < 1 || tier > 5)
        {
            ++sPools.skippedRows;
            continue;
        }

        if (!sSpellItemEnchantmentStore.LookupEntry(enchantId))
        {
            ++sPools.skippedRows;
            continue;
        }

        TierPools& tierPools = sPools.byTier[tier];

        if (classToken == "ANY")
        {
            tierPools.any.push_back(enchantId);
            ++sPools.loadedRows;
            continue;
        }

        if (classToken == "WEAPON")
        {
            if (subClass >= 0)
                tierPools.weaponBySubClass[static_cast<uint32>(subClass)].push_back(enchantId);
            else
                tierPools.weapon.push_back(enchantId);

            ++sPools.loadedRows;
            continue;
        }

        if (classToken == "ARMOR")
        {
            if (subClass >= 0)
                tierPools.armorBySubClass[static_cast<uint32>(subClass)].push_back(enchantId);
            else
                tierPools.armor.push_back(enchantId);

            ++sPools.loadedRows;
            continue;
        }

        ++sPools.skippedRows;
    }
    while (result->NextRow());

    sPools.loaded = (sPools.loadedRows > 0);

    if (!sPools.loaded)
    {
        LOG_WARN(
            "scripts.dc",
            "DC-RandomEnchants: No valid enchant rows found (skipped={})",
            sPools.skippedRows);
        return;
    }

    LOG_INFO(
        "scripts.dc",
        "DC-RandomEnchants: Loaded {} enchant rows (skipped={})",
        sPools.loadedRows,
        sPools.skippedRows);
}

bool IsEligibleItem(Item const* item)
{
    if (!item)
        return false;

    ItemTemplate const* proto = item->GetTemplate();
    if (!proto)
        return false;

    if (proto->Quality < sConfig.minQuality || proto->Quality > sConfig.maxQuality)
        return false;

    if (proto->Class == ITEM_CLASS_WEAPON)
        return sConfig.allowWeapons;

    if (proto->Class == ITEM_CLASS_ARMOR)
        return sConfig.allowArmor;

    return false;
}

bool HasExistingRandomEnchant(Item const* item)
{
    if (!item)
        return false;

    if (item->GetItemRandomPropertyId() != 0)
        return true;

    for (uint8 slot = PROP_ENCHANTMENT_SLOT_0; slot <= PROP_ENCHANTMENT_SLOT_4; ++slot)
    {
        if (item->GetEnchantmentId(EnchantmentSlot(slot)) != 0)
            return true;
    }

    return false;
}

uint8 RollTierForQuality(uint32 itemQuality)
{
    int32 rarityRoll = -1;
    float const roll = frand(0.0f, 1.0f);

    switch (itemQuality)
    {
        case ITEM_QUALITY_POOR:
            rarityRoll = static_cast<int32>(roll * 25.0f);
            break;
        case ITEM_QUALITY_NORMAL:
            rarityRoll = static_cast<int32>(roll * 50.0f);
            break;
        case ITEM_QUALITY_UNCOMMON:
            rarityRoll = 45 + static_cast<int32>(roll * 20.0f);
            break;
        case ITEM_QUALITY_RARE:
            rarityRoll = 65 + static_cast<int32>(roll * 15.0f);
            break;
        case ITEM_QUALITY_EPIC:
            rarityRoll = 80 + static_cast<int32>(roll * 14.0f);
            break;
        case ITEM_QUALITY_LEGENDARY:
            rarityRoll = 93 + static_cast<int32>(roll * 7.0f);
            break;
        default:
            return 0;
    }

    if (rarityRoll <= 44)
        return 1;
    if (rarityRoll <= 64)
        return 2;
    if (rarityRoll <= 79)
        return 3;
    if (rarityRoll <= 92)
        return 4;

    return 5;
}

uint32 PickRandomEnchantId(
    ItemTemplate const* proto,
    uint8 tier,
    std::unordered_set<uint32> const& blockedEnchantIds)
{
    if (!proto || tier < 1 || tier > 5 || !sPools.loaded)
        return 0;

    TierPools const& tierPools = sPools.byTier[tier];

    std::vector<uint32> candidates;
    candidates.reserve(
        tierPools.any.size() +
        tierPools.weapon.size() +
        tierPools.armor.size());

    AppendCandidates(candidates, tierPools.any);

    if (proto->Class == ITEM_CLASS_WEAPON)
    {
        AppendCandidates(candidates, tierPools.weapon);
        auto it = tierPools.weaponBySubClass.find(proto->SubClass);
        if (it != tierPools.weaponBySubClass.end())
            AppendCandidates(candidates, it->second);
    }
    else if (proto->Class == ITEM_CLASS_ARMOR)
    {
        AppendCandidates(candidates, tierPools.armor);
        auto it = tierPools.armorBySubClass.find(proto->SubClass);
        if (it != tierPools.armorBySubClass.end())
            AppendCandidates(candidates, it->second);
    }

    if (candidates.empty())
        return 0;

    for (uint8 i = 0; i < 12; ++i)
    {
        uint32 const enchantId = candidates[urand(0, static_cast<uint32>(candidates.size() - 1))];
        if (blockedEnchantIds.find(enchantId) == blockedEnchantIds.end())
            return enchantId;
    }

    for (uint32 enchantId : candidates)
    {
        if (blockedEnchantIds.find(enchantId) == blockedEnchantIds.end())
            return enchantId;
    }

    return 0;
}

void ApplyRandomEnchants(Player* player, Item* item, char const* source)
{
    if (!sConfig.enabled || !player || !item)
        return;

    if (!sPools.loaded)
        return;

    if (!IsEligibleItem(item))
        return;

    if (sConfig.skipIfRandomPropertyPresent && HasExistingRandomEnchant(item))
        return;

    ItemTemplate const* proto = item->GetTemplate();
    if (!proto)
        return;

    std::array<float, 3> const chances =
    {
        sConfig.enchantChance1,
        sConfig.enchantChance2,
        sConfig.enchantChance3
    };

    std::array<EnchantmentSlot, 3> const slots =
    {
        PROP_ENCHANTMENT_SLOT_0,
        PROP_ENCHANTMENT_SLOT_1,
        PROP_ENCHANTMENT_SLOT_2
    };

    uint8 appliedCount = 0;
    std::unordered_set<uint32> usedEnchantIds;

    for (uint8 i = 0; i < sConfig.maxEnchantsPerItem; ++i)
    {
        if (!roll_chance_f(chances[i]))
            break;

        uint8 const tier = RollTierForQuality(proto->Quality);
        if (!tier)
            break;

        uint32 const enchantId = PickRandomEnchantId(proto, tier, usedEnchantIds);
        if (!enchantId)
            break;

        if (!sSpellItemEnchantmentStore.LookupEntry(enchantId))
            continue;

        EnchantmentSlot const slot = slots[i];
        player->ApplyEnchantment(item, slot, false);
        item->SetEnchantment(slot, enchantId, 0, 0, player->GetGUID());
        player->ApplyEnchantment(item, slot, true);

        usedEnchantIds.insert(enchantId);
        ++appliedCount;
    }

    if (!appliedCount)
        return;

    if (sConfig.notifyOnApply)
    {
        if (WorldSession* session = player->GetSession())
        {
            std::string const& itemName = proto->Name1;
            ChatHandler(session).PSendSysMessage(
                "|cff00ff00[Random Enchants]|r {} received {} random enchant{}.",
                itemName,
                appliedCount,
                appliedCount == 1 ? "" : "s");
        }
    }

    if (sConfig.debug)
    {
        LOG_INFO(
            "scripts.dc",
            "DC-RandomEnchants: Applied {} enchant(s) to item {} ({}) via {}",
            appliedCount,
            proto->ItemId,
            proto->Name1,
            source);
    }
}

} // namespace

class DCRandomEnchantsPlayerScript : public PlayerScript
{
public:
    DCRandomEnchantsPlayerScript() : PlayerScript("DCRandomEnchantsPlayerScript") {}

    void OnPlayerLootItem(Player* player, Item* item, uint32 /*count*/, ObjectGuid /*lootguid*/) override
    {
        if (!sConfig.onLoot)
            return;

        ApplyRandomEnchants(player, item, "loot");
    }

    void OnPlayerCreateItem(Player* player, Item* item, uint32 /*count*/) override
    {
        if (!sConfig.onCreate)
            return;

        ApplyRandomEnchants(player, item, "create");
    }

    void OnPlayerQuestRewardItem(Player* player, Item* item, uint32 /*count*/) override
    {
        if (!sConfig.onQuestReward)
            return;

        ApplyRandomEnchants(player, item, "quest_reward");
    }

    void OnPlayerGroupRollRewardItem(
        Player* player,
        Item* item,
        uint32 /*count*/,
        RollVote /*voteType*/,
        Roll* /*roll*/) override
    {
        if (!sConfig.onGroupRoll)
            return;

        ApplyRandomEnchants(player, item, "group_roll");
    }
};

class DCRandomEnchantsWorldScript : public WorldScript
{
public:
    DCRandomEnchantsWorldScript() : WorldScript("DCRandomEnchantsWorldScript") {}

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        sConfig.Load();
        LoadEnchantPools();
    }
};

void AddSC_dc_random_enchants()
{
    new DCRandomEnchantsPlayerScript();
    new DCRandomEnchantsWorldScript();
}

