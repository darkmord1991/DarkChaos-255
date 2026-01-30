/*
 * DarkChaos AoE Loot System - Unified Implementation
 * Merged from ac_aoeloot.cpp and dc_aoeloot_extensions.cpp
 *
 * Features:
 * - Core AoE loot merging
 * - Quality filtering
 * - Profession integration (skinning, mining, herbing)
 * - Detailed statistics tracking
 * - Smart loot preferences
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Creature.h"
#include "Config.h"
#include "Chat.h"
#include "CommandScript.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "WorldPacket.h"
#include "Opcodes.h"
#include "GameTime.h"
#include "LootMgr.h"
#include "Group.h"
#include "CellImpl.h"
#include "Log.h"
#include "Mail.h"
#include "DatabaseEnv.h"
#include "Item.h"
#include "StringFormat.h"
#include "Spell.h"

#include <vector>
#include <list>
#include <unordered_map>
#include <unordered_set>
#include <algorithm>
#include <sstream>
#include <limits>

using namespace Acore::ChatCommands;

// =============================================================================
// Configuration
// =============================================================================

struct AoELootConfig
{
    // Core settings
    bool enabled = true;
    float range = 30.0f;
    uint32 maxCorpses = 10;
    uint8 maxMergeSlots = 15;
    bool autoCreditGold = true;
    uint8 autoLoot = 0;
    uint32 autoStoreWindowSeconds = 5;
    bool allowInGroup = true;
    bool showMessage = true;
    bool playersOnly = true;
    bool ignoreTapped = true;
    bool questItems = true;
    bool debugPerCorpse = false;

    // Extension settings
    bool qualityFilterEnabled = false;
    uint8 minQuality = 0;
    uint8 maxQuality = 6;
    bool autoVendorPoorItems = false;

    // Profession integration
    bool autoSkinEnabled = true;
    bool autoMineEnabled = true;
    bool autoHerbEnabled = true;
    float professionRange = 10.0f;

    // Smart loot
    bool preferCurrentSpec = true;
    bool preferEquippable = true;
    bool prioritizeUpgrades = true;

    // Mythic+ integration
    bool mythicPlusBonus = true;
    float mythicPlusRangeMultiplier = 1.5f;

    // Raid features
    bool raidModeEnabled = true;
    uint32 raidMaxCorpses = 25;

    // Statistics
    bool trackDetailedStats = true;

    void Load()
    {
        // Core settings
        enabled = sConfigMgr->GetOption<bool>("AoELoot.Enable", true);
        range = sConfigMgr->GetOption<float>("AoELoot.Range", 30.0f);
        maxCorpses = sConfigMgr->GetOption<uint32>("AoELoot.MaxCorpses", 10);
        autoLoot = sConfigMgr->GetOption<uint8>("AoELoot.AutoLoot", 0);
        allowInGroup = sConfigMgr->GetOption<bool>("AoELoot.AllowInGroup", true);
        showMessage = sConfigMgr->GetOption<bool>("AoELoot.ShowMessage", true);
        playersOnly = sConfigMgr->GetOption<bool>("AoELoot.PlayersOnly", true);
        ignoreTapped = sConfigMgr->GetOption<bool>("AoELoot.IgnoreTapped", true);
        questItems = sConfigMgr->GetOption<bool>("AoELoot.QuestItems", true);
        maxMergeSlots = sConfigMgr->GetOption<uint8>("AoELoot.MaxMergeSlots", 15u);
        debugPerCorpse = sConfigMgr->GetOption<bool>("AoELoot.DebugPerCorpse", false);
        autoCreditGold = sConfigMgr->GetOption<bool>("AoELoot.AutoCreditGold", true);
        autoStoreWindowSeconds = sConfigMgr->GetOption<uint32>("AoELoot.AutoStoreWindowSeconds", 5u);

        // Extension settings
        qualityFilterEnabled = sConfigMgr->GetOption<bool>("AoELoot.Extensions.QualityFilter.Enable", false);
        minQuality = sConfigMgr->GetOption<uint8>("AoELoot.Extensions.QualityFilter.MinQuality", 0);
        maxQuality = sConfigMgr->GetOption<uint8>("AoELoot.Extensions.QualityFilter.MaxQuality", 6);
        autoVendorPoorItems = sConfigMgr->GetOption<bool>("AoELoot.Extensions.QualityFilter.AutoVendorPoor", false);

        autoSkinEnabled = sConfigMgr->GetOption<bool>("AoELoot.Extensions.Profession.AutoSkin", true);
        autoMineEnabled = sConfigMgr->GetOption<bool>("AoELoot.Extensions.Profession.AutoMine", true);
        autoHerbEnabled = sConfigMgr->GetOption<bool>("AoELoot.Extensions.Profession.AutoHerb", true);
        professionRange = sConfigMgr->GetOption<float>("AoELoot.Extensions.Profession.Range", 10.0f);

        preferCurrentSpec = sConfigMgr->GetOption<bool>("AoELoot.Extensions.SmartLoot.PreferCurrentSpec", true);
        preferEquippable = sConfigMgr->GetOption<bool>("AoELoot.Extensions.SmartLoot.PreferEquippable", true);
        prioritizeUpgrades = sConfigMgr->GetOption<bool>("AoELoot.Extensions.SmartLoot.PrioritizeUpgrades", true);

        mythicPlusBonus = sConfigMgr->GetOption<bool>("AoELoot.Extensions.MythicPlus.Bonus", true);
        mythicPlusRangeMultiplier = sConfigMgr->GetOption<float>("AoELoot.Extensions.MythicPlus.RangeMultiplier", 1.5f);

        raidModeEnabled = sConfigMgr->GetOption<bool>("AoELoot.Extensions.Raid.Enable", true);
        raidMaxCorpses = sConfigMgr->GetOption<uint32>("AoELoot.Extensions.Raid.MaxCorpses", 25);

        trackDetailedStats = sConfigMgr->GetOption<bool>("AoELoot.Extensions.TrackDetailedStats", true);

        // Validate and clamp all numeric settings
        if (range < 5.0f) range = 5.0f;
        if (range > 100.0f) range = 100.0f;
        if (maxCorpses < 1) maxCorpses = 1;
        if (maxCorpses > 50) maxCorpses = 50;
        if (autoLoot > 2) autoLoot = 0;
        if (maxMergeSlots < 1) maxMergeSlots = 1;
        if (maxMergeSlots > 16) maxMergeSlots = 16;
        if (autoStoreWindowSeconds < 1) autoStoreWindowSeconds = 1;
        if (autoStoreWindowSeconds > 60) autoStoreWindowSeconds = 60;
        if (minQuality > 6) minQuality = 6;
        if (maxQuality > 6) maxQuality = 6;
        if (minQuality > maxQuality) minQuality = maxQuality;
        if (professionRange < 1.0f) professionRange = 1.0f;
        if (professionRange > 100.0f) professionRange = 100.0f;
        if (mythicPlusRangeMultiplier < 1.0f) mythicPlusRangeMultiplier = 1.0f;
        if (mythicPlusRangeMultiplier > 5.0f) mythicPlusRangeMultiplier = 5.0f;
        if (raidMaxCorpses < 1) raidMaxCorpses = 1;
        if (raidMaxCorpses > 100) raidMaxCorpses = 100;
    }
};

static AoELootConfig sConfig;

// =============================================================================
// Player Data Structures
// =============================================================================

struct PlayerLootPreferences
{
    bool aoeLootEnabled = true;
    bool showMessages = true;
    uint8 minQuality = 0;
    bool autoSkin = true;
    bool smartLootEnabled = true;
    bool autoVendorPoor = false;
    float lootRange = 45.0f;
    std::unordered_set<uint32> ignoredItemIds;
    uint8 activePreset = 0;  // 0 = custom
};

struct DetailedLootStats
{
    uint32 totalItemsLooted = 0;
    uint32 totalGoldLooted = 0;
    uint32 poorItemsVendored = 0;
    uint32 goldFromVendor = 0;
    uint32 skinnedCorpses = 0;
    uint32 minedNodes = 0;
    uint32 herbedNodes = 0;
    uint32 upgradesFound = 0;

    // Quality breakdown
    uint32 qualityPoor = 0;
    uint32 qualityCommon = 0;
    uint32 qualityUncommon = 0;
    uint32 qualityRare = 0;
    uint32 qualityEpic = 0;
    uint32 qualityLegendary = 0;

    // Filtered items by quality
    uint32 filteredPoor = 0;
    uint32 filteredCommon = 0;
    uint32 filteredUncommon = 0;
    uint32 filteredRare = 0;
    uint32 filteredEpic = 0;
    uint32 filteredLegendary = 0;

    uint32 mythicBonusItems = 0;
};

struct PlayerAoELootData
{
    uint64 lastAoELoot = 0;
    uint32 lootedThisSession = 0;
    uint64 lastCreditedGold = 0;
    uint64 accumulatedCreditedGold = 0;
};

static std::unordered_map<ObjectGuid, PlayerLootPreferences> sPlayerPrefs;
static std::unordered_map<ObjectGuid, DetailedLootStats> sDetailedStats;
static std::unordered_map<ObjectGuid, PlayerAoELootData> sPlayerLootData;
static std::unordered_map<ObjectGuid, uint64> sPlayerAutoStoreTimestamp;

// =============================================================================
// Loot Filter Presets - Quick switch between configurations
// =============================================================================

enum LootPreset : uint8
{
    LOOT_PRESET_EVERYTHING  = 0,  // All items (minQuality = 0)
    LOOT_PRESET_VENDOR_ONLY = 1,  // Common+ (minQuality = 1)
    LOOT_PRESET_ADVENTURER  = 2,  // Uncommon+ (minQuality = 2)
    LOOT_PRESET_RAIDER      = 3,  // Rare+ (minQuality = 3)
    LOOT_PRESET_COLLECTOR   = 4,  // Epic+ (minQuality = 4)
    LOOT_PRESET_CUSTOM      = 5   // User-defined
};

// Get minimum quality for a preset
inline uint8 GetPresetMinQuality(LootPreset preset)
{
    switch (preset)
    {
        case LOOT_PRESET_EVERYTHING:  return 0;
        case LOOT_PRESET_VENDOR_ONLY: return 1;
        case LOOT_PRESET_ADVENTURER:  return 2;
        case LOOT_PRESET_RAIDER:      return 3;
        case LOOT_PRESET_COLLECTOR:   return 4;
        case LOOT_PRESET_CUSTOM:
        default:                      return 0;
    }
}

// Get preset name for display
inline const char* GetPresetName(LootPreset preset)
{
    switch (preset)
    {
        case LOOT_PRESET_EVERYTHING:  return "Everything";
        case LOOT_PRESET_VENDOR_ONLY: return "Vendor Trash";
        case LOOT_PRESET_ADVENTURER:  return "Adventurer";
        case LOOT_PRESET_RAIDER:      return "Raider";
        case LOOT_PRESET_COLLECTOR:   return "Collector";
        case LOOT_PRESET_CUSTOM:      return "Custom";
        default:                      return "Unknown";
    }
}

// Set player's active preset
inline void SetPlayerLootPreset(ObjectGuid guid, LootPreset preset)
{
    PlayerLootPreferences& prefs = sPlayerPrefs[guid];
    prefs.activePreset = static_cast<uint8>(preset);
    prefs.minQuality = GetPresetMinQuality(preset);
}

// =============================================================================
// Smart Item Detection - Highlights upgrades and new collectibles
// =============================================================================

struct LootItemHighlight
{
    bool isUpgrade = false;       // Item is ilvl upgrade for player
    bool isTransmogNew = false;   // Appearance not yet collected
    bool isCollectionNew = false; // Mount/pet/toy not collected
    uint32 itemId = 0;
    int32 ilvlDelta = 0;          // How much of an upgrade (+5, +10, etc)
};

// Get full highlight info for an item (currently unused)
/*
static LootItemHighlight GetItemHighlight(Player* player, uint32 itemId)
{
    LootItemHighlight highlight;
    highlight.itemId = itemId;

    if (!player) return highlight;

    // Check if upgrade
    highlight.isUpgrade = IsItemUpgrade(player, itemId, highlight.ilvlDelta);

    // Note: isTransmogNew and isCollectionNew would require integration with
    // the CollectionSystem (dc_collection_*.cpp) - placeholder for now

    return highlight;
}
*/

// =============================================================================
// Helper Functions
// =============================================================================

static std::string FormatCoins(uint64_t copper)
{
    uint64_t g = copper / 10000;
    uint64_t s = (copper % 10000) / 100;
    uint64_t c = copper % 100;
    std::ostringstream ss;
    if (g > 0) ss << g << " Gold ";
    if (s > 0) ss << s << " Silver ";
    ss << c << " Copper";
    return ss.str();
}

static const char* GetQualityName(uint8 quality)
{
    static const char* names[] = { "Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Artifact" };
    return quality <= 6 ? names[quality] : "Unknown";
}

// =============================================================================
// Player Preference Functions (replaces try-catch cross-references)
// =============================================================================

bool GetPlayerShowMessages(ObjectGuid playerGuid)
{
    auto it = sPlayerPrefs.find(playerGuid);
    return it != sPlayerPrefs.end() ? it->second.showMessages : true;
}

void SetPlayerShowMessages(ObjectGuid playerGuid, bool value)
{
    sPlayerPrefs[playerGuid].showMessages = value;
}

// =============================================================================
// DCAoELootExt Namespace - External Interface Functions
// =============================================================================

namespace DCAoELootExt
{

bool IsPlayerAoELootEnabled(ObjectGuid playerGuid)
{
    auto it = sPlayerPrefs.find(playerGuid);
    return it != sPlayerPrefs.end() ? it->second.aoeLootEnabled : true;
}

void SetPlayerAoELootEnabled(ObjectGuid playerGuid, bool value)
{
    sPlayerPrefs[playerGuid].aoeLootEnabled = value;
}

uint8 GetPlayerMinQuality(ObjectGuid playerGuid)
{
    auto it = sPlayerPrefs.find(playerGuid);
    return it != sPlayerPrefs.end() ? it->second.minQuality : 0;
}

void SetPlayerMinQuality(ObjectGuid playerGuid, uint8 quality)
{
    if (quality > 6) quality = 6;
    sPlayerPrefs[playerGuid].minQuality = quality;
}

void GetDetailedStats(ObjectGuid playerGuid, uint32& itemsLooted, uint32& goldLooted, uint32& upgradesFound)
{
    auto it = sDetailedStats.find(playerGuid);
    if (it != sDetailedStats.end())
    {
        itemsLooted = it->second.totalItemsLooted;
        goldLooted = it->second.totalGoldLooted;
        upgradesFound = it->second.upgradesFound;
    }
    else
    {
        itemsLooted = 0;
        goldLooted = 0;
        upgradesFound = 0;
    }
}

void GetQualityStats(ObjectGuid playerGuid,
                     uint32& poor, uint32& common, uint32& uncommon,
                     uint32& rare, uint32& epic, uint32& legendary,
                     uint32& filtPoor, uint32& filtCommon, uint32& filtUncommon,
                     uint32& filtRare, uint32& filtEpic, uint32& filtLegendary)
{
    auto it = sDetailedStats.find(playerGuid);
    if (it != sDetailedStats.end())
    {
        poor = it->second.qualityPoor;
        common = it->second.qualityCommon;
        uncommon = it->second.qualityUncommon;
        rare = it->second.qualityRare;
        epic = it->second.qualityEpic;
        legendary = it->second.qualityLegendary;
        filtPoor = it->second.filteredPoor;
        filtCommon = it->second.filteredCommon;
        filtUncommon = it->second.filteredUncommon;
        filtRare = it->second.filteredRare;
        filtEpic = it->second.filteredEpic;
        filtLegendary = it->second.filteredLegendary;
    }
    else
    {
        poor = common = uncommon = rare = epic = legendary = 0;
        filtPoor = filtCommon = filtUncommon = filtRare = filtEpic = filtLegendary = 0;
    }
}

} // namespace DCAoELootExt

// =============================================================================
// Statistics Functions
// =============================================================================

void UpdateDetailedStats(ObjectGuid playerGuid, uint32 itemsLooted, uint32 goldLooted, uint32 upgradesFound)
{
    if (!sConfig.trackDetailedStats) return;
    DetailedLootStats& stats = sDetailedStats[playerGuid];
    stats.totalItemsLooted += itemsLooted;
    stats.totalGoldLooted += goldLooted;
    stats.upgradesFound += upgradesFound;
}

void UpdateQualityStats(ObjectGuid playerGuid, uint8 quality)
{
    if (!sConfig.trackDetailedStats) return;
    DetailedLootStats& stats = sDetailedStats[playerGuid];
    switch (quality)
    {
        case 0: stats.qualityPoor++; break;
        case 1: stats.qualityCommon++; break;
        case 2: stats.qualityUncommon++; break;
        case 3: stats.qualityRare++; break;
        case 4: stats.qualityEpic++; break;
        case 5:
        case 6: stats.qualityLegendary++; break;
        default: stats.qualityCommon++; break;
    }
}

void UpdateFilteredStats(ObjectGuid playerGuid, uint8 quality)
{
    if (!sConfig.trackDetailedStats) return;
    DetailedLootStats& stats = sDetailedStats[playerGuid];
    switch (quality)
    {
        case 0: stats.filteredPoor++; break;
        case 1: stats.filteredCommon++; break;
        case 2: stats.filteredUncommon++; break;
        case 3: stats.filteredRare++; break;
        case 4: stats.filteredEpic++; break;
        case 5:
        case 6: stats.filteredLegendary++; break;
        default: stats.filteredCommon++; break;
    }
}

// =============================================================================
// Core Loot Functions
// =============================================================================

// Using declarations for DCAoELootExt functions
using DCAoELootExt::IsPlayerAoELootEnabled;
using DCAoELootExt::GetPlayerMinQuality;

static bool ShouldShowMessage(Player* player)
{
    if (!sConfig.showMessage) return false;
    return GetPlayerShowMessages(player->GetGUID());
}

static uint8 GetPlayerMinQualityFilter(Player* player)
{
    if (!player) return 0;
    return GetPlayerMinQuality(player->GetGUID());
}

static bool ItemMeetsQualityFilter(uint32 itemId, uint8 minQuality)
{
    if (minQuality == 0) return true;
    ItemTemplate const* proto = sObjectMgr->GetItemTemplate(itemId);
    if (!proto) return false;
    return proto->Quality >= minQuality;
}

static bool CanPlayerLootCorpse(Player* player, Creature* creature)
{
    if (!player || !creature) return false;
    if (creature->loot.empty()) return false;
    if (sConfig.playersOnly && !player->IsPlayer()) return false;
    if (sConfig.ignoreTapped && creature->hasLootRecipient())
    {
        Player* recipient = creature->GetLootRecipient();
        if (!recipient) return false;
        if (recipient->GetGUID() != player->GetGUID())
        {
            if (Group* group = player->GetGroup())
            {
                if (!group->IsMember(recipient->GetGUID()))
                    return false;
            }
            else
                return false;
        }
    }
    if (!player->isAllowedToLoot(creature)) return false;
    return true;
}

static bool PerformAoELoot(Player* player, Creature* mainCreature)
{
    if (!player || !mainCreature) return false;
    if (!IsPlayerAoELootEnabled(player->GetGUID()))
    {
        LOG_DEBUG("scripts.dc", "AoELoot: player {} has AoE loot disabled", player->GetGUID().ToString());
        return false;
    }

    Loot* mainLoot = &mainCreature->loot;
    if (!mainLoot) return false;

    std::list<Creature*> nearby;
    player->GetDeadCreatureListInGrid(nearby, sConfig.range);

    LOG_DEBUG("scripts.dc", "AoELoot: found {} nearby dead creatures for player {}", nearby.size(), player->GetGUID().ToString());

    nearby.remove_if([&](Creature* c) -> bool {
        if (!c) return true;
        if (c->GetGUID() == mainCreature->GetGUID()) return true;
        if (!c->HasDynamicFlag(UNIT_DYNFLAG_LOOTABLE)) return true;
        if (c->loot.empty()) return true;
        if (!player->isAllowedToLoot(c)) return true;
        return false;
    });

    uint8 playerMinQuality = GetPlayerMinQualityFilter(player);

    auto shouldAutoLootForPlayer = [&](Player* p) -> bool {
        if (!p) return false;
        if (sConfig.autoLoot == 1) return true;
        if (sConfig.autoLoot == 2)
        {
            auto it = sPlayerAutoStoreTimestamp.find(p->GetGUID());
            if (it == sPlayerAutoStoreTimestamp.end()) return false;
            uint64 now = GameTime::GetGameTime().count();
            return (now - it->second) <= sConfig.autoStoreWindowSeconds;
        }
        return false;
    };

    if (nearby.empty())
    {
        // Apply quality filter to single corpse if active
        if (playerMinQuality > 0)
        {
            mainLoot->items.erase(
                std::remove_if(mainLoot->items.begin(), mainLoot->items.end(),
                    [playerMinQuality](const LootItem& item) {
                        ItemTemplate const* proto = sObjectMgr->GetItemTemplate(item.itemid);
                        return proto && proto->Quality < playerMinQuality;
                    }),
                mainLoot->items.end()
            );

            if (mainLoot->items.empty() && mainLoot->gold == 0)
                return false;

            if (shouldAutoLootForPlayer(player))
            {
                std::vector<std::pair<uint32, uint32>> mailItems;
                for (auto const& li : mainLoot->items)
                {
                    ItemPosCountVec dest;
                    InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, li.itemid, li.count);
                    if (msg == EQUIP_ERR_OK)
                    {
                        Item* newItem = player->StoreNewItem(dest, li.itemid, true, li.randomPropertyId);
                        if (newItem) player->SendNewItem(newItem, uint32(li.count), false, false, true);
                    }
                    else
                        mailItems.emplace_back(li.itemid, li.count);
                }
                if (mainLoot->gold > 0)
                {
                    player->ModifyMoney(mainLoot->gold);
                    player->UpdateAchievementCriteria(ACHIEVEMENT_CRITERIA_TYPE_LOOT_MONEY, mainLoot->gold);
                }
                if (!mailItems.empty())
                {
                    CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();
                    MailSender sender(mainCreature);
                    MailDraft draft("Recovered Items", "Some items could not fit in your bags.");
                    for (auto const& p : mailItems)
                    {
                        if (Item* mailItem = Item::CreateItem(p.first, p.second))
                        {
                            mailItem->SaveToDB(trans);
                            draft.AddItem(mailItem);
                        }
                    }
                    draft.SendMailTo(trans, MailReceiver(player), sender);
                    CharacterDatabase.CommitTransaction(trans);
                }
                mainLoot->clear();
                mainCreature->AllLootRemovedFromCorpse();
                mainCreature->RemoveDynamicFlag(UNIT_DYNFLAG_LOOTABLE);
                return true;
            }
            player->SendLoot(mainCreature->GetGUID(), LOOT_CORPSE);
            return true;
        }
        if (ShouldShowMessage(player))
            ChatHandler(player->GetSession()).PSendSysMessage("AoE Loot: no nearby corpses found");
        return false;
    }

    std::vector<Creature*> corpses;
    corpses.reserve(sConfig.maxCorpses);
    for (Creature* c : nearby)
    {
        if (corpses.size() >= sConfig.maxCorpses) break;
        corpses.push_back(c);
    }

    std::vector<LootItem> itemsToAdd;
    std::vector<LootItem> questItemsToAdd;
    uint32 totalGold = mainLoot->gold;
    const size_t MAX_MERGE_SLOTS = sConfig.maxMergeSlots;

    // Filter main loot
    if (playerMinQuality > 0)
    {
        mainLoot->items.erase(
            std::remove_if(mainLoot->items.begin(), mainLoot->items.end(),
                [playerMinQuality, player](const LootItem& item) {
                    ItemTemplate const* proto = sObjectMgr->GetItemTemplate(item.itemid);
                    bool shouldRemove = proto && proto->Quality < playerMinQuality;
                    if (shouldRemove && proto)
                        UpdateFilteredStats(player->GetGUID(), proto->Quality);
                    return shouldRemove;
                }),
            mainLoot->items.end()
        );
    }

    size_t processed = 0;
    for (Creature* corpse : corpses)
    {
        if (!corpse) continue;
        Loot* loot = &corpse->loot;
        if (!loot || loot->isLooted()) continue;

        if (loot->gold > 0 && totalGold < std::numeric_limits<uint32>::max() - loot->gold)
            totalGold += loot->gold;

        for (auto const& it : loot->items)
        {
            if (!it.AllowedForPlayer(player, corpse->GetGUID())) continue;
            if (!sConfig.questItems && it.needs_quest) continue;
            if (!ItemMeetsQualityFilter(it.itemid, playerMinQuality))
            {
                ItemTemplate const* proto = sObjectMgr->GetItemTemplate(it.itemid);
                if (proto) UpdateFilteredStats(player->GetGUID(), proto->Quality);
                continue;
            }
            size_t projected = mainLoot->items.size() + itemsToAdd.size() + mainLoot->quest_items.size() + questItemsToAdd.size();
            if (projected >= MAX_MERGE_SLOTS) break;
            itemsToAdd.push_back(it);
            ItemTemplate const* proto = sObjectMgr->GetItemTemplate(it.itemid);
            if (proto) UpdateQualityStats(player->GetGUID(), proto->Quality);
        }
        for (auto const& it : loot->quest_items)
        {
            if (!it.AllowedForPlayer(player, corpse->GetGUID())) continue;
            size_t projected = mainLoot->items.size() + itemsToAdd.size() + mainLoot->quest_items.size() + questItemsToAdd.size();
            if (projected >= MAX_MERGE_SLOTS) break;
            questItemsToAdd.push_back(it);
            UpdateQualityStats(player->GetGUID(), 1);
        }
        loot->clear();
        corpse->AllLootRemovedFromCorpse();
        corpse->RemoveDynamicFlag(UNIT_DYNFLAG_LOOTABLE);
        processed++;
    }

    if (processed == 0)
    {
        if (ShouldShowMessage(player))
            ChatHandler(player->GetSession()).PSendSysMessage("AoE Loot: found corpses but none eligible");
        return false;
    }

    for (auto const& it : itemsToAdd)
    {
        if (mainLoot->items.size() + mainLoot->quest_items.size() >= MAX_MERGE_SLOTS) break;
        mainLoot->items.push_back(it);
    }
    for (auto const& it : questItemsToAdd)
    {
        if (mainLoot->items.size() + mainLoot->quest_items.size() >= MAX_MERGE_SLOTS) break;
        mainLoot->quest_items.push_back(it);
    }

    mainLoot->gold = totalGold;
    uint32 mergedGold = totalGold;

    PlayerAoELootData& data = sPlayerLootData[player->GetGUID()];
    data.lastAoELoot = GameTime::GetGameTime().count();
    data.lootedThisSession += processed;

    if (Group* group = player->GetGroup())
    {
        LootMethod method = group->GetLootMethod();
        if (method == MASTER_LOOT)
        {
            group->MasterLoot(mainLoot, mainCreature);
            return true;
        }
        else if (method == NEED_BEFORE_GREED || method == GROUP_LOOT || method == FREE_FOR_ALL)
        {
            group->GroupLoot(mainLoot, mainCreature);
            return true;
        }
    }

    if (shouldAutoLootForPlayer(player))
    {
        std::vector<std::pair<uint32, uint32>> mailItems;
        auto storeOrMail = [&](LootItem const& li) {
            if (!ItemMeetsQualityFilter(li.itemid, playerMinQuality)) return;
            ItemPosCountVec dest;
            InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, li.itemid, li.count);
            if (msg == EQUIP_ERR_OK)
            {
                Item* newItem = player->StoreNewItem(dest, li.itemid, true, li.randomPropertyId);
                if (newItem) player->SendNewItem(newItem, uint32(li.count), false, false, true);
            }
            else
                mailItems.emplace_back(li.itemid, li.count);
        };
        for (auto const& it : mainLoot->items) storeOrMail(it);
        for (auto const& it : mainLoot->quest_items) storeOrMail(it);

        if (mainLoot->gold > 0)
        {
            player->ModifyMoney(mainLoot->gold);
            data.lastCreditedGold = mainLoot->gold;
            data.accumulatedCreditedGold += mainLoot->gold;
        }

        if (!mailItems.empty())
        {
            CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();
            MailSender sender(mainCreature);
            MailDraft draft("Recovered Items", "Items could not fit in your bags.");
            for (auto const& p : mailItems)
            {
                if (Item* mailItem = Item::CreateItem(p.first, p.second))
                {
                    mailItem->SaveToDB(trans);
                    draft.AddItem(mailItem);
                }
            }
            draft.SendMailTo(trans, MailReceiver(player), sender);
            CharacterDatabase.CommitTransaction(trans);
        }
        mainLoot->clear();
        mainCreature->AllLootRemovedFromCorpse();
        mainCreature->RemoveDynamicFlag(UNIT_DYNFLAG_LOOTABLE);
        return true;
    }

    // Auto-credit gold to solo looter
    if (mainLoot->gold > 0 && !player->GetGroup())
    {
        uint32 credited = mainLoot->gold;
        player->ModifyMoney(credited);
        mainLoot->gold = 0;
        data.lastCreditedGold = credited;
        data.accumulatedCreditedGold += credited;
    }

    player->SendLoot(mainCreature->GetGUID(), LOOT_CORPSE);

    if (processed > 0)
        UpdateDetailedStats(player->GetGUID(), static_cast<uint32>(itemsToAdd.size()), mergedGold, 0);

    if (ShouldShowMessage(player) && processed > 0)
    {
        std::ostringstream ss;
        ss << "|cFF00FF00[AoE Loot]|r Looted " << processed << " corpses. ";
        if (!itemsToAdd.empty()) ss << "Items: " << itemsToAdd.size() << ". ";
        if (mergedGold > 0) ss << "Gold: " << FormatCoins(mergedGold);
        ChatHandler(player->GetSession()).PSendSysMessage("%s", ss.str().c_str());
    }
    return true;
}

// =============================================================================
// Skinning Integration
// =============================================================================

// Can player skin creature (currently unused)
/*
static bool CanPlayerSkinCreature(Player* player, Creature* creature)
{
    if (!player || !creature) return false;
    if (!creature->HasFlag(UNIT_FIELD_FLAGS, UNIT_FLAG_SKINNABLE)) return false;
    uint32 requiredSkill = creature->GetCreatureTemplate()->GetRequiredLootSkill();
    uint32 playerSkill = 0;
    if (requiredSkill == SKILL_SKINNING) playerSkill = player->GetSkillValue(SKILL_SKINNING);
    else if (requiredSkill == SKILL_MINING) playerSkill = player->GetSkillValue(SKILL_MINING);
    else if (requiredSkill == SKILL_HERBALISM) playerSkill = player->GetSkillValue(SKILL_HERBALISM);
    else if (requiredSkill == SKILL_ENGINEERING) playerSkill = player->GetSkillValue(SKILL_ENGINEERING);
    if (playerSkill == 0) return false;
    uint32 targetLevel = creature->GetLevel();
    uint32 requiredLevel = targetLevel > 10 ? (targetLevel - 10) * 5 : 1;
    return playerSkill >= requiredLevel;
}
*/

// Auto-skin creature (currently unused - can be enabled in future)
/*
static void AutoSkinCreature(Player* player, Creature* creature)
{
    if (!sConfig.autoSkinEnabled || !CanPlayerSkinCreature(player, creature)) return;
    creature->loot.clear();
    creature->loot.FillLoot(creature->GetCreatureTemplate()->SkinLootId, LootTemplates_Skinning, player, true);
    if (creature->loot.empty()) return;

    for (auto const& item : creature->loot.items)
    {
        ItemPosCountVec dest;
        InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, item.itemid, item.count);
        if (msg == EQUIP_ERR_OK)
        {
            Item* newItem = player->StoreNewItem(dest, item.itemid, true);
            if (newItem) player->SendNewItem(newItem, item.count, false, false, true);
        }
    }
    if (sConfig.trackDetailedStats)
        sDetailedStats[player->GetGUID()].skinnedCorpses++;
    creature->loot.clear();
    creature->RemoveFlag(UNIT_FIELD_FLAGS, UNIT_FLAG_SKINNABLE);
}
*/

// =============================================================================
// Script Classes
// =============================================================================

class AoELootServerScript : public ServerScript
{
public:
    AoELootServerScript() : ServerScript("AoELootServerScript") { }

    bool CanPacketReceive(WorldSession* session, WorldPacket& packet) override
    {
        if (!sConfig.enabled || !session) return true;

        if (packet.GetOpcode() == CMSG_AUTOSTORE_LOOT_ITEM)
        {
            Player* player = session->GetPlayer();
            if (!player) return true;
            sPlayerAutoStoreTimestamp[player->GetGUID()] = GameTime::GetGameTime().count();

            uint8 playerMinQuality = GetPlayerMinQualityFilter(player);
            if (playerMinQuality > 0)
            {
                packet.rpos(0);
                uint8 lootSlot;
                packet >> lootSlot;
                packet.rpos(0);

                Loot* loot = nullptr;
                ObjectGuid lootGuid = player->GetLootGUID();
                if (lootGuid.IsCreatureOrVehicle())
                {
                    if (Creature* creature = player->GetMap()->GetCreature(lootGuid))
                        loot = &creature->loot;
                }
                else if (lootGuid.IsCorpse())
                {
                    if (Corpse* corpse = ObjectAccessor::GetCorpse(*player, lootGuid))
                        loot = &corpse->loot;
                }
                if (loot && lootSlot < loot->items.size())
                {
                    uint32 itemId = loot->items[lootSlot].itemid;
                    if (itemId > 0 && !ItemMeetsQualityFilter(itemId, playerMinQuality))
                        return false;
                }
            }
            return true;
        }

        if (packet.GetOpcode() != CMSG_LOOT) return true;

        Player* player = session->GetPlayer();
        if (!player) return true;

        packet.rpos(0);
        ObjectGuid guid;
        packet >> guid;
        packet.rpos(0);

        if (!guid || !guid.IsCreature()) return true;

        Creature* creature = ObjectAccessor::GetCreature(*player, guid);
        if (!creature) return true;

        if (!IsPlayerAoELootEnabled(player->GetGUID())) return true;
        if (!creature->HasDynamicFlag(UNIT_DYNFLAG_LOOTABLE)) return true;
        if (!CanPlayerLootCorpse(player, creature)) return true;
        if (player->GetGroup() && !sConfig.allowInGroup) return true;

        bool handled = PerformAoELoot(player, creature);
        return !handled;
    }
};

class AoELootPlayerScript : public PlayerScript
{
public:
    AoELootPlayerScript() : PlayerScript("AoELootPlayerScript") { }

    void OnPlayerLogin(Player* player) override
    {
        if (!player) return;

        // Initialize preferences
        PlayerLootPreferences& prefs = sPlayerPrefs[player->GetGUID()];
        prefs.aoeLootEnabled = true;
        prefs.showMessages = true;

        // Load from database
        QueryResult result = CharacterDatabase.Query(
            "SELECT aoe_enabled, min_quality, auto_skin, smart_loot, show_messages "
            "FROM dc_aoeloot_preferences WHERE player_guid = {}",
            player->GetGUID().GetCounter());

        if (result)
        {
            Field* f = result->Fetch();
            prefs.aoeLootEnabled = f[0].Get<bool>();
            prefs.minQuality = f[1].Get<uint8>();
            if (prefs.minQuality > 6) prefs.minQuality = 6;
            prefs.autoSkin = f[2].Get<bool>();
            prefs.smartLootEnabled = f[3].Get<bool>();
            prefs.showMessages = f[4].Get<bool>();
        }

        // Load detailed stats
        if (sConfig.trackDetailedStats)
        {
            QueryResult statsResult = CharacterDatabase.Query(
                "SELECT total_items, total_gold, poor_vendored, vendor_gold, skinned, mined, herbed, upgrades, "
                "quality_poor, quality_common, quality_uncommon, quality_rare, quality_epic, quality_legendary, "
                "filtered_poor, filtered_common, filtered_uncommon, filtered_rare, filtered_epic, filtered_legendary, "
                "mythic_bonus_items "
                "FROM dc_aoeloot_detailed_stats WHERE player_guid = {}",
                player->GetGUID().GetCounter());
            if (statsResult)
            {
                Field* f = statsResult->Fetch();
                DetailedLootStats& stats = sDetailedStats[player->GetGUID()];
                stats.totalItemsLooted = f[0].Get<uint32>();
                stats.totalGoldLooted = f[1].Get<uint32>();
                stats.poorItemsVendored = f[2].Get<uint32>();
                stats.goldFromVendor = f[3].Get<uint32>();
                stats.skinnedCorpses = f[4].Get<uint32>();
                stats.minedNodes = f[5].Get<uint32>();
                stats.herbedNodes = f[6].Get<uint32>();
                stats.upgradesFound = f[7].Get<uint32>();
                stats.qualityPoor = f[8].Get<uint32>();
                stats.qualityCommon = f[9].Get<uint32>();
                stats.qualityUncommon = f[10].Get<uint32>();
                stats.qualityRare = f[11].Get<uint32>();
                stats.qualityEpic = f[12].Get<uint32>();
                stats.qualityLegendary = f[13].Get<uint32>();
                stats.filteredPoor = f[14].Get<uint32>();
                stats.filteredCommon = f[15].Get<uint32>();
                stats.filteredUncommon = f[16].Get<uint32>();
                stats.filteredRare = f[17].Get<uint32>();
                stats.filteredEpic = f[18].Get<uint32>();
                stats.filteredLegendary = f[19].Get<uint32>();
                stats.mythicBonusItems = f[20].Get<uint32>();
            }
        }

        // Initialize session data
        PlayerAoELootData& data = sPlayerLootData[player->GetGUID()];
        data = PlayerAoELootData();

        if (ShouldShowMessage(player))
            ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00[AoE Loot]|r System enabled.");
    }

    void OnPlayerLogout(Player* player) override
    {
        if (!player) return;

        // Save preferences
        auto prefIt = sPlayerPrefs.find(player->GetGUID());
        if (prefIt != sPlayerPrefs.end())
        {
            PlayerLootPreferences& prefs = prefIt->second;
            CharacterDatabase.Execute(
                "REPLACE INTO dc_aoeloot_preferences "
                "(player_guid, aoe_enabled, min_quality, auto_skin, smart_loot, show_messages) "
                "VALUES ({}, {}, {}, {}, {}, {})",
                player->GetGUID().GetCounter(),
                prefs.aoeLootEnabled ? 1 : 0, prefs.minQuality,
                prefs.autoSkin ? 1 : 0, prefs.smartLootEnabled ? 1 : 0,
                prefs.showMessages ? 1 : 0);
            sPlayerPrefs.erase(prefIt);
        }

        // Save detailed stats
        if (sConfig.trackDetailedStats)
        {
            auto statsIt = sDetailedStats.find(player->GetGUID());
            if (statsIt != sDetailedStats.end())
            {
                DetailedLootStats& stats = statsIt->second;
                CharacterDatabase.Execute(
                    "REPLACE INTO dc_aoeloot_detailed_stats "
                    "(player_guid, total_items, total_gold, poor_vendored, vendor_gold, skinned, mined, herbed, upgrades, "
                    "quality_poor, quality_common, quality_uncommon, quality_rare, quality_epic, quality_legendary, "
                    "filtered_poor, filtered_common, filtered_uncommon, filtered_rare, filtered_epic, filtered_legendary, "
                    "mythic_bonus_items) "
                    "VALUES ({}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {})",
                    player->GetGUID().GetCounter(),
                    stats.totalItemsLooted, stats.totalGoldLooted, stats.poorItemsVendored,
                    stats.goldFromVendor, stats.skinnedCorpses, stats.minedNodes, stats.herbedNodes, stats.upgradesFound,
                    stats.qualityPoor, stats.qualityCommon, stats.qualityUncommon, stats.qualityRare,
                    stats.qualityEpic, stats.qualityLegendary, stats.filteredPoor, stats.filteredCommon,
                    stats.filteredUncommon, stats.filteredRare, stats.filteredEpic, stats.filteredLegendary,
                    stats.mythicBonusItems);
                sDetailedStats.erase(statsIt);
            }
        }

        sPlayerLootData.erase(player->GetGUID());
        sPlayerAutoStoreTimestamp.erase(player->GetGUID());
    }
};

class AoELootCommandScript : public CommandScript
{
public:
    AoELootCommandScript() : CommandScript("AoELootCommandScript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable aoelootTable =
        {
            { "toggle",   HandleToggle,   SEC_PLAYER,        Console::No },
            { "enable",   HandleEnable,   SEC_PLAYER,        Console::No },
            { "disable",  HandleDisable,  SEC_PLAYER,        Console::No },
            { "messages", HandleMessages, SEC_PLAYER,        Console::No },
            { "quality",  HandleQuality,  SEC_PLAYER,        Console::No },
            { "skin",     HandleSkin,     SEC_PLAYER,        Console::No },
            { "smart",    HandleSmart,    SEC_PLAYER,        Console::No },
            { "stats",    HandleStats,    SEC_PLAYER,        Console::No },
            { "info",     HandleInfo,     SEC_PLAYER,        Console::No },
            { "reload",   HandleReload,   SEC_ADMINISTRATOR, Console::No },
        };

        static ChatCommandTable commandTable =
        {
            { "aoeloot", aoelootTable },
            { "lp",      aoelootTable },  // Shortcut
        };

        return commandTable;
    }

    static bool HandleToggle(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!player) return true;
        PlayerLootPreferences& prefs = sPlayerPrefs[player->GetGUID()];
        prefs.aoeLootEnabled = !prefs.aoeLootEnabled;
        handler->PSendSysMessage("|cff00ff00[AoE Loot]|r %s", prefs.aoeLootEnabled ? "Enabled" : "Disabled");
        return true;
    }

    static bool HandleEnable(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!player) return true;
        sPlayerPrefs[player->GetGUID()].aoeLootEnabled = true;
        handler->PSendSysMessage("|cff00ff00[AoE Loot]|r Enabled");
        return true;
    }

    static bool HandleDisable(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!player) return true;
        sPlayerPrefs[player->GetGUID()].aoeLootEnabled = false;
        handler->PSendSysMessage("|cff00ff00[AoE Loot]|r Disabled");
        return true;
    }

    static bool HandleMessages(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!player) return true;
        PlayerLootPreferences& prefs = sPlayerPrefs[player->GetGUID()];
        prefs.showMessages = !prefs.showMessages;
        handler->PSendSysMessage("|cff00ff00[AoE Loot]|r Messages: %s", prefs.showMessages ? "On" : "Off");
        return true;
    }

    static bool HandleQuality(ChatHandler* handler, uint8 quality)
    {
        Player* player = handler->GetPlayer();
        if (!player) return true;
        if (quality > 6) quality = 6;
        sPlayerPrefs[player->GetGUID()].minQuality = quality;
        handler->PSendSysMessage("|cff00ff00[AoE Loot]|r Min quality: %s", GetQualityName(quality));
        return true;
    }

    static bool HandleSkin(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!player) return true;
        PlayerLootPreferences& prefs = sPlayerPrefs[player->GetGUID()];
        prefs.autoSkin = !prefs.autoSkin;
        handler->PSendSysMessage("|cff00ff00[AoE Loot]|r Auto-Skin: %s", prefs.autoSkin ? "On" : "Off");
        return true;
    }

    static bool HandleSmart(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!player) return true;
        PlayerLootPreferences& prefs = sPlayerPrefs[player->GetGUID()];
        prefs.smartLootEnabled = !prefs.smartLootEnabled;
        handler->PSendSysMessage("|cff00ff00[AoE Loot]|r Smart Loot: %s", prefs.smartLootEnabled ? "On" : "Off");
        return true;
    }

    static bool HandleStats(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!player) return true;

        PlayerLootPreferences& prefs = sPlayerPrefs[player->GetGUID()];
        handler->SendSysMessage("|cff00ff00========== AoE LOOT SETTINGS ==========|r");
        handler->PSendSysMessage("Enabled: %s", prefs.aoeLootEnabled ? "Yes" : "No");
        handler->PSendSysMessage("Messages: %s", prefs.showMessages ? "On" : "Off");
        handler->PSendSysMessage("Min Quality: %s", GetQualityName(prefs.minQuality));
        handler->PSendSysMessage("Auto-Skin: %s", prefs.autoSkin ? "On" : "Off");
        handler->PSendSysMessage("Smart Loot: %s", prefs.smartLootEnabled ? "On" : "Off");

        auto it = sDetailedStats.find(player->GetGUID());
        if (it != sDetailedStats.end())
        {
            DetailedLootStats& s = it->second;
            handler->SendSysMessage("|cff00ff00========== STATISTICS ==========|r");
            handler->PSendSysMessage("Items Looted: %u", s.totalItemsLooted);
            handler->PSendSysMessage("Gold Looted: %s", FormatCoins(s.totalGoldLooted).c_str());
            handler->PSendSysMessage("Skinned: %u", s.skinnedCorpses);
        }
        return true;
    }

    static bool HandleInfo(ChatHandler* handler)
    {
        handler->PSendSysMessage("AoE Loot: %s", sConfig.enabled ? "Enabled" : "Disabled");
        if (sConfig.enabled)
        {
            handler->PSendSysMessage("  Range: %.1f yards", sConfig.range);
            handler->PSendSysMessage("  Max Corpses: %u", sConfig.maxCorpses);
        }
        return true;
    }

    static bool HandleReload(ChatHandler* handler)
    {
        sConfig.Load();
        handler->SendSysMessage("AoE Loot configuration reloaded.");
        return true;
    }
};

class AoELootWorldScript : public WorldScript
{
public:
    AoELootWorldScript() : WorldScript("AoELootWorldScript") { }

    void OnStartup() override
    {
        sConfig.Load();
        LOG_INFO("scripts.dc", "DarkChaos AoE Loot Unified initialized (Enabled: {})", sConfig.enabled ? "Yes" : "No");
    }
};

void AddSC_dc_aoeloot_unified()
{
    sConfig.Load();
    new AoELootServerScript();
    new AoELootPlayerScript();
    new AoELootCommandScript();
    new AoELootWorldScript();
}
