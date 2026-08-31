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
#include "PathGenerator.h"
#include "DC/CrossSystem/CrossSystemCommon.h"
#include "ObjectGuid.h"
#include "DC/dc_aoeloot_schema.h"
#include "DC/AddonExtension/dc_addon_namespace.h"
#include "DC/AddonExtension/dc_addon_utils.h"

#include <vector>
#include <list>
#include <mutex>
#include <unordered_map>
#include <unordered_set>
#include <algorithm>
#include <sstream>
#include <limits>
#include <cctype>

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

    // Looter pet pathfinding safety
    bool looterPetPathfindingEnable = true;
    bool looterPetPathAllowIncomplete = true;
    bool looterPetPathRejectShortcut = false;
    float looterPetPathMaxLength = 80.0f;
    uint32 looterPetPathMaxChecks = 12;

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

        looterPetPathfindingEnable = sConfigMgr->GetOption<bool>(
            "AoELoot.LooterPet.Pathfinding.Enable", true);
        looterPetPathAllowIncomplete = sConfigMgr->GetOption<bool>(
            "AoELoot.LooterPet.Pathfinding.AllowIncomplete", true);
        looterPetPathRejectShortcut = sConfigMgr->GetOption<bool>(
            "AoELoot.LooterPet.Pathfinding.RejectShortcut", false);
        looterPetPathMaxLength = sConfigMgr->GetOption<float>(
            "AoELoot.LooterPet.Pathfinding.MaxPathLength", 80.0f);
        looterPetPathMaxChecks = sConfigMgr->GetOption<uint32>(
            "AoELoot.LooterPet.Pathfinding.MaxChecks", 12u);

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
        if (looterPetPathMaxLength < 0.0f) looterPetPathMaxLength = 0.0f;
        if (looterPetPathMaxLength > 500.0f) looterPetPathMaxLength = 500.0f;
        if (looterPetPathMaxChecks < 1) looterPetPathMaxChecks = 1;
        if (looterPetPathMaxChecks > 50) looterPetPathMaxChecks = 50;
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
    bool goldOnly = false;
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

// The live realm runs MapUpdate.Threads = 8, so anything reached from
// Map::Update() - PerformAoELoot via the loot packet, and the looter-pet hook in
// dc_looter_pet.cpp, which reads IsPlayerAoELootEnabled() - runs on several
// threads at once, while commands, the addon handlers and the login/logout
// callbacks mutate these maps from the world thread. An operator[] insert on
// behalf of one player can rehash the whole table under a find() running for
// another, so all four maps share one lock. dc_looter_pet.cpp already guards its
// own per-player map this way.
//
// The lock is never held across a call into the engine or into another helper in
// this file (several of which lock themselves, and this mutex is not recursive).
// Long paths snapshot the fields they need, release, and write back.
static std::mutex sAoELootStateMutex;

// Preference-column schema now lives in DC/dc_aoeloot_schema.h, shared with
// the addon protocol path so the two can no longer drift apart.
using DCAoELoot::PreferenceSchemaInfo;

// Centralized in DCAddon::Utils::EscapeSql, which delegates to the driver's
// charset- and SQL-mode-aware mysql_real_escape_string.
static std::string EscapeSqlString(std::string const& input)
{
    return DCAddon::Utils::EscapeSql(input);
}

static std::string SerializeIgnoredItems(std::unordered_set<uint32> const& ignoredItemIds)
{
    if (ignoredItemIds.empty())
        return "";

    std::vector<uint32> sortedIds(ignoredItemIds.begin(), ignoredItemIds.end());
    std::sort(sortedIds.begin(), sortedIds.end());

    std::vector<std::string> tokens;
    tokens.reserve(sortedIds.size());
    for (uint32 id : sortedIds)
        tokens.push_back(std::to_string(id));

    return DCUtils::JoinStringList(tokens, ",");
}

static void ParseIgnoredItems(std::string const& csv, std::unordered_set<uint32>& ignoredItemIds)
{
    ignoredItemIds.clear();

    if (csv.empty())
        return;

    // DCUtils::ParseUInt32List keeps id 0; drop it here to match legacy CSV semantics.
    for (uint32 itemId : DCUtils::ParseUInt32List(csv))
    {
        if (itemId > 0)
            ignoredItemIds.insert(itemId);
    }
}

static PreferenceSchemaInfo const& GetPreferenceSchemaInfo()
{
    return DCAoELoot::GetPreferenceSchema();
}

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
inline char const* GetPresetName(LootPreset preset)
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
    std::lock_guard<std::mutex> lock(sAoELootStateMutex);
    PlayerLootPreferences& prefs = sPlayerPrefs[guid];
    prefs.activePreset = static_cast<uint8>(preset);
    prefs.minQuality = GetPresetMinQuality(preset);
}

// =============================================================================
// Smart Item Detection - NOT IMPLEMENTED
// =============================================================================
//
// A "highlight upgrades and new collectibles" pass over looted items was
// sketched here and never built. The sketch was removed (2026-08-30) because it
// was commented-out code calling IsItemUpgrade(), a function that does not exist
// anywhere in the tree, so it could not have compiled if uncommented.
//
// Building it for real needs three things that do not exist yet:
//   1. An ilvl-comparison helper (the missing IsItemUpgrade) that resolves the
//      player's currently equipped item for the loot item's InventoryType and
//      returns the delta. Must handle two-hand vs. dual-wield and bag slots.
//   2. Collectible lookups. DCCollection::GetPlayerCache(accountId) already
//      carries mounts (by spell_id), pets (by pet_entry), toys (by item_id) and
//      transmogDisplayIds -- see DC/CollectionSystem/CollectionCore.h. Only the
//      toy check is a direct item_id hit; mounts and pets need item -> taught
//      spell -> entry resolution, and the cache must be consulted ONLY when
//      IsCollectionCacheValid() is true, because looting is a hot path and
//      LoadPlayerCollectionToCache() hits the character DB synchronously.
//   3. A consumer. Nothing displays highlights today; the loot summary below is
//      the natural place, but that is a gameplay/UX decision, not a code gap.
//
// Do not restore the sketch without (1) and (3) -- an unused helper will not
// survive -Werror.

// =============================================================================
// Helper Functions
// =============================================================================

static bool IsItemIgnoredByPlayer(Player* player, uint32 itemId)
{
    if (!player || itemId == 0)
        return false;

    std::lock_guard<std::mutex> lock(sAoELootStateMutex);

    auto prefIt = sPlayerPrefs.find(player->GetGUID());
    if (prefIt == sPlayerPrefs.end())
        return false;

    return prefIt->second.ignoredItemIds.find(itemId) != prefIt->second.ignoredItemIds.end();
}

static uint32 GetAutoVendorCopper(uint32 itemId, uint8 itemCount)
{
    ItemTemplate const* proto = sObjectMgr->GetItemTemplate(itemId);
    if (!proto || proto->Quality != ITEM_QUALITY_POOR || proto->SellPrice == 0)
        return 0;

    uint64 totalCopper = uint64(proto->SellPrice) * uint64(itemCount);
    if (totalCopper > std::numeric_limits<uint32>::max())
        return std::numeric_limits<uint32>::max();

    return static_cast<uint32>(totalCopper);
}

static void CreditAutoVendorGold(Player* player, uint32 copper, uint32 vendoredItems)
{
    if (!player || copper == 0)
        return;

    uint32 credited = copper;
    if (credited > static_cast<uint32>(std::numeric_limits<int32>::max()))
        credited = static_cast<uint32>(std::numeric_limits<int32>::max());

    player->ModifyMoney(static_cast<int32>(credited));

    std::lock_guard<std::mutex> lock(sAoELootStateMutex);

    DetailedLootStats& stats = sDetailedStats[player->GetGUID()];
    if (credited > std::numeric_limits<uint32>::max() - stats.goldFromVendor)
        stats.goldFromVendor = std::numeric_limits<uint32>::max();
    else
        stats.goldFromVendor += credited;

    if (vendoredItems > std::numeric_limits<uint32>::max() - stats.poorItemsVendored)
        stats.poorItemsVendored = std::numeric_limits<uint32>::max();
    else
        stats.poorItemsVendored += vendoredItems;

    PlayerAoELootData& lootData = sPlayerLootData[player->GetGUID()];
    lootData.lastCreditedGold = credited;
    lootData.accumulatedCreditedGold += credited;
}

// =============================================================================
// Player Preference Functions (replaces try-catch cross-references)
// =============================================================================

bool GetPlayerShowMessages(ObjectGuid playerGuid)
{
    std::lock_guard<std::mutex> lock(sAoELootStateMutex);
    auto it = sPlayerPrefs.find(playerGuid);
    return it != sPlayerPrefs.end() ? it->second.showMessages : true;
}

void SetPlayerShowMessages(ObjectGuid playerGuid, bool value)
{
    std::lock_guard<std::mutex> lock(sAoELootStateMutex);
    sPlayerPrefs[playerGuid].showMessages = value;
}

// =============================================================================
// DCAoELootExt Namespace - External Interface Functions
// =============================================================================

namespace DCAoELootExt
{

bool IsPlayerAoELootEnabled(ObjectGuid playerGuid)
{
    std::lock_guard<std::mutex> lock(sAoELootStateMutex);
    auto it = sPlayerPrefs.find(playerGuid);
    return it != sPlayerPrefs.end() ? it->second.aoeLootEnabled : true;
}

bool GetPlayerShowMessages(ObjectGuid playerGuid)
{
    std::lock_guard<std::mutex> lock(sAoELootStateMutex);
    auto it = sPlayerPrefs.find(playerGuid);
    return it != sPlayerPrefs.end() ? it->second.showMessages : true;
}

void SetPlayerAoELootEnabled(ObjectGuid playerGuid, bool value)
{
    std::lock_guard<std::mutex> lock(sAoELootStateMutex);
    sPlayerPrefs[playerGuid].aoeLootEnabled = value;
}

void SetPlayerShowMessages(ObjectGuid playerGuid, bool value)
{
    std::lock_guard<std::mutex> lock(sAoELootStateMutex);
    sPlayerPrefs[playerGuid].showMessages = value;
}

uint8 GetPlayerMinQuality(ObjectGuid playerGuid)
{
    std::lock_guard<std::mutex> lock(sAoELootStateMutex);
    auto it = sPlayerPrefs.find(playerGuid);
    return it != sPlayerPrefs.end() ? it->second.minQuality : 0;
}

void SetPlayerMinQuality(ObjectGuid playerGuid, uint8 quality)
{
    if (quality > 6) quality = 6;
    std::lock_guard<std::mutex> lock(sAoELootStateMutex);
    sPlayerPrefs[playerGuid].minQuality = quality;
}

bool GetPlayerAutoSkin(ObjectGuid playerGuid)
{
    std::lock_guard<std::mutex> lock(sAoELootStateMutex);
    auto it = sPlayerPrefs.find(playerGuid);
    return it != sPlayerPrefs.end() ? it->second.autoSkin : true;
}

void SetPlayerAutoSkin(ObjectGuid playerGuid, bool value)
{
    std::lock_guard<std::mutex> lock(sAoELootStateMutex);
    sPlayerPrefs[playerGuid].autoSkin = value;
}

bool GetPlayerSmartLoot(ObjectGuid playerGuid)
{
    std::lock_guard<std::mutex> lock(sAoELootStateMutex);
    auto it = sPlayerPrefs.find(playerGuid);
    return it != sPlayerPrefs.end() ? it->second.smartLootEnabled : true;
}

void SetPlayerSmartLoot(ObjectGuid playerGuid, bool value)
{
    std::lock_guard<std::mutex> lock(sAoELootStateMutex);
    sPlayerPrefs[playerGuid].smartLootEnabled = value;
}

bool GetPlayerAutoVendorPoor(ObjectGuid playerGuid)
{
    std::lock_guard<std::mutex> lock(sAoELootStateMutex);
    auto it = sPlayerPrefs.find(playerGuid);
    return it != sPlayerPrefs.end() ? it->second.autoVendorPoor : false;
}

void SetPlayerAutoVendorPoor(ObjectGuid playerGuid, bool value)
{
    std::lock_guard<std::mutex> lock(sAoELootStateMutex);
    sPlayerPrefs[playerGuid].autoVendorPoor = value;
}

bool GetPlayerGoldOnly(ObjectGuid playerGuid)
{
    std::lock_guard<std::mutex> lock(sAoELootStateMutex);
    auto it = sPlayerPrefs.find(playerGuid);
    return it != sPlayerPrefs.end() ? it->second.goldOnly : false;
}

void SetPlayerGoldOnly(ObjectGuid playerGuid, bool value)
{
    std::lock_guard<std::mutex> lock(sAoELootStateMutex);
    sPlayerPrefs[playerGuid].goldOnly = value;
}

bool GetLooterPetPathfindingEnabled()
{
    return sConfig.looterPetPathfindingEnable;
}

void SetLooterPetPathfindingEnabled(bool value)
{
    sConfig.looterPetPathfindingEnable = value;
}

void ReloadAoELootConfig()
{
    sConfig.Load();
}

bool GetLooterPetPathAllowIncomplete()
{
    return sConfig.looterPetPathAllowIncomplete;
}

void SetLooterPetPathAllowIncomplete(bool value)
{
    sConfig.looterPetPathAllowIncomplete = value;
}

bool GetLooterPetPathRejectShortcut()
{
    return sConfig.looterPetPathRejectShortcut;
}

void SetLooterPetPathRejectShortcut(bool value)
{
    sConfig.looterPetPathRejectShortcut = value;
}

float GetLooterPetPathMaxLength()
{
    return sConfig.looterPetPathMaxLength;
}

uint32 GetLooterPetPathMaxChecks()
{
    return sConfig.looterPetPathMaxChecks;
}

float GetPlayerLootRange(ObjectGuid playerGuid)
{
    std::lock_guard<std::mutex> lock(sAoELootStateMutex);
    auto it = sPlayerPrefs.find(playerGuid);
    return it != sPlayerPrefs.end() ? it->second.lootRange : sConfig.range;
}

void SetPlayerLootRange(ObjectGuid playerGuid, float value)
{
    if (value < 5.0f)
        value = 5.0f;
    if (value > 100.0f)
        value = 100.0f;

    std::lock_guard<std::mutex> lock(sAoELootStateMutex);
    sPlayerPrefs[playerGuid].lootRange = value;
}

void TogglePlayerIgnoredItem(ObjectGuid playerGuid, uint32 itemId)
{
    if (!itemId)
        return;

    std::lock_guard<std::mutex> lock(sAoELootStateMutex);
    auto& ignored = sPlayerPrefs[playerGuid].ignoredItemIds;
    auto it = ignored.find(itemId);
    if (it == ignored.end())
        ignored.insert(itemId);
    else
        ignored.erase(it);
}

bool IsPlayerItemIgnored(ObjectGuid playerGuid, uint32 itemId)
{
    if (!itemId)
        return false;

    std::lock_guard<std::mutex> lock(sAoELootStateMutex);
    auto prefIt = sPlayerPrefs.find(playerGuid);
    if (prefIt == sPlayerPrefs.end())
        return false;

    return prefIt->second.ignoredItemIds.find(itemId) != prefIt->second.ignoredItemIds.end();
}

uint32 GetPlayerIgnoredCount(ObjectGuid playerGuid)
{
    std::lock_guard<std::mutex> lock(sAoELootStateMutex);
    auto prefIt = sPlayerPrefs.find(playerGuid);
    return prefIt != sPlayerPrefs.end() ? static_cast<uint32>(prefIt->second.ignoredItemIds.size()) : 0;
}

void GetDetailedStats(ObjectGuid playerGuid, uint32& itemsLooted, uint32& goldLooted, uint32& upgradesFound)
{
    std::lock_guard<std::mutex> lock(sAoELootStateMutex);
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
    std::lock_guard<std::mutex> lock(sAoELootStateMutex);
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

    std::lock_guard<std::mutex> lock(sAoELootStateMutex);
    DetailedLootStats& stats = sDetailedStats[playerGuid];
    stats.totalItemsLooted += itemsLooted;
    stats.totalGoldLooted += goldLooted;
    stats.upgradesFound += upgradesFound;
}

void UpdateQualityStats(ObjectGuid playerGuid, uint8 quality)
{
    if (!sConfig.trackDetailedStats) return;

    std::lock_guard<std::mutex> lock(sAoELootStateMutex);
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

    std::lock_guard<std::mutex> lock(sAoELootStateMutex);
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
    if (creature->loot.isLooted()) return false;
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

static bool PerformAoELoot(Player* player, Creature* mainCreature, bool forceAutoLoot = false)
{
    if (!player || !mainCreature) return false;
    if (!IsPlayerAoELootEnabled(player->GetGUID()))
    {
        LOG_DEBUG("scripts.dc", "AoELoot: player {} has AoE loot disabled", player->GetGUID().ToString());
        return false;
    }

    Loot* mainLoot = &mainCreature->loot;
    if (!mainLoot) return false;

    // Snapshot the preferences this call needs and drop the lock: everything
    // below walks the grid and manipulates loot, and must not hold a global lock
    // while doing so. Membership tests against the ignore list go through
    // IsItemIgnoredByPlayer(), which takes the lock itself.
    float lootRange;
    bool goldOnly;
    bool autoVendorPoor;
    bool hasIgnoredItems;
    {
        std::lock_guard<std::mutex> lock(sAoELootStateMutex);
        PlayerLootPreferences const& prefs = sPlayerPrefs[player->GetGUID()];
        lootRange = prefs.lootRange;
        goldOnly = prefs.goldOnly;
        autoVendorPoor = prefs.autoVendorPoor;
        hasIgnoredItems = !prefs.ignoredItemIds.empty();
    }

    if (lootRange < 5.0f || lootRange > 100.0f)
        lootRange = sConfig.range;

    std::list<Creature*> nearby;
    player->GetDeadCreatureListInGrid(nearby, lootRange);

    LOG_DEBUG("scripts.dc", "AoELoot: found {} nearby dead creatures for player {}", nearby.size(), player->GetGUID().ToString());

    nearby.remove_if([&](Creature* c) -> bool {
        if (!c) return true;
        if (c->GetGUID() == mainCreature->GetGUID()) return true;
        if (!c->HasDynamicFlag(UNIT_DYNFLAG_LOOTABLE)) return true;
        if (c->loot.empty()) return true;
        if (c->loot.isLooted()) return true;
        if (!player->isAllowedToLoot(c)) return true;
        return false;
    });

    uint8 playerMinQuality = GetPlayerMinQualityFilter(player);
    if (player->GetGroup())
        playerMinQuality = 0;

    uint32 autoVendoredItems = 0;
    uint32 autoVendoredCopper = 0;

    auto shouldSkipItem = [&](LootItem const& item, bool updateFilterStats) -> bool
    {
        if (item.needs_quest)
            return false;

        ItemTemplate const* proto = sObjectMgr->GetItemTemplate(item.itemid);

        if (goldOnly)
        {
            if (updateFilterStats && proto)
                UpdateFilteredStats(player->GetGUID(), proto->Quality);
            return true;
        }

        if (IsItemIgnoredByPlayer(player, item.itemid))
        {
            if (updateFilterStats && proto)
                UpdateFilteredStats(player->GetGUID(), proto->Quality);
            return true;
        }

        if (autoVendorPoor && proto && proto->Quality == ITEM_QUALITY_POOR && proto->SellPrice > 0)
        {
            uint32 itemCopper = GetAutoVendorCopper(item.itemid, item.count);
            if (itemCopper > std::numeric_limits<uint32>::max() - autoVendoredCopper)
                autoVendoredCopper = std::numeric_limits<uint32>::max();
            else
                autoVendoredCopper += itemCopper;

            if (item.count > std::numeric_limits<uint32>::max() - autoVendoredItems)
                autoVendoredItems = std::numeric_limits<uint32>::max();
            else
                autoVendoredItems += item.count;

            return true;
        }

        if (!ItemMeetsQualityFilter(item.itemid, playerMinQuality))
        {
            if (updateFilterStats && proto)
                UpdateFilteredStats(player->GetGUID(), proto->Quality);
            return true;
        }

        return false;
    };

    auto shouldAutoLootForPlayer = [&](Player* p) -> bool {
        if (!p) return false;
        if (forceAutoLoot && !p->GetGroup()) return true;
        if (sConfig.autoLoot == 1) return true;
        if (sConfig.autoLoot == 2)
        {
            std::lock_guard<std::mutex> lock(sAoELootStateMutex);
            auto it = sPlayerAutoStoreTimestamp.find(p->GetGUID());
            if (it == sPlayerAutoStoreTimestamp.end()) return false;
            uint64 now = GameTime::GetGameTime().count();
            return (now - it->second) <= sConfig.autoStoreWindowSeconds;
        }
        return false;
    };

    if (nearby.empty())
    {
        if (playerMinQuality > 0 || goldOnly || autoVendorPoor || hasIgnoredItems)
        {
            size_t initialItems = mainLoot->items.size();
            mainLoot->items.erase(
                std::remove_if(mainLoot->items.begin(), mainLoot->items.end(),
                    [&](LootItem const& item)
                    {
                        return shouldSkipItem(item, true);
                    }),
                mainLoot->items.end()
            );
            size_t const removedCount = initialItems - mainLoot->items.size();
            if (removedCount >= mainLoot->unlootedCount)
                mainLoot->unlootedCount = 0;
            else
                mainLoot->unlootedCount -= removedCount;

            if (mainLoot->items.empty() && mainLoot->quest_items.empty() && mainLoot->gold == 0)
            {
                mainLoot->clear();
                mainCreature->AllLootRemovedFromCorpse();
                mainCreature->RemoveDynamicFlag(UNIT_DYNFLAG_LOOTABLE);
                if (autoVendoredCopper > 0)
                    CreditAutoVendorGold(player, autoVendoredCopper, autoVendoredItems);
                return true;
            }
        }

        if (autoVendoredCopper > 0)
            CreditAutoVendorGold(player, autoVendoredCopper, autoVendoredItems);

        if (shouldAutoLootForPlayer(player))
        {
            std::vector<std::pair<uint32, uint32>> mailItems;
            auto storeOrMail = [&](LootItem& li) {
                if (li.is_blocked || li.is_looted) return;
                ItemPosCountVec dest;
                InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, li.itemid, li.count);
                if (msg == EQUIP_ERR_OK)
                {
                    Item* newItem = player->StoreNewItem(dest, li.itemid, true, li.randomPropertyId);
                    if (newItem) player->SendNewItem(newItem, uint32(li.count), false, false, true);
                }
                else
                    mailItems.emplace_back(li.itemid, uint32(li.count));

                li.is_looted = true;
                li.count = 0;
                if (mainLoot->unlootedCount > 0) --mainLoot->unlootedCount;
            };

            for (auto& li : mainLoot->items) storeOrMail(li);
            for (auto& li : mainLoot->quest_items) storeOrMail(li);

            if (mainLoot->gold > 0)
            {
                player->ModifyMoney(mainLoot->gold);
                player->UpdateAchievementCriteria(ACHIEVEMENT_CRITERIA_TYPE_LOOT_MONEY, mainLoot->gold);
                mainLoot->gold = 0;
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
            if (mainLoot->isLooted())
            {
                mainLoot->clear();
                mainCreature->AllLootRemovedFromCorpse();
                mainCreature->RemoveDynamicFlag(UNIT_DYNFLAG_LOOTABLE);
                return true;
            }
            player->SendLootRelease(mainCreature->GetGUID());
            return true;
        }
        player->SendLoot(mainCreature->GetGUID(), LOOT_CORPSE);
        return true;
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
    if (playerMinQuality > 0 || goldOnly || autoVendorPoor || hasIgnoredItems)
    {
        size_t initialItems = mainLoot->items.size();
        mainLoot->items.erase(
            std::remove_if(mainLoot->items.begin(), mainLoot->items.end(),
                [&](LootItem const& item)
                {
                    return shouldSkipItem(item, true);
                }),
            mainLoot->items.end()
        );
        size_t const removedCount = initialItems - mainLoot->items.size();
        if (removedCount >= mainLoot->unlootedCount)
            mainLoot->unlootedCount = 0;
        else
            mainLoot->unlootedCount -= removedCount;
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
            if (shouldSkipItem(it, true))
            {
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

    if (autoVendoredCopper > 0)
        CreditAutoVendorGold(player, autoVendoredCopper, autoVendoredItems);

    // Do not abort if no extra corpses were merged; main corpse loot should
    // still be processed (important for autonomous looter-pet pulses).

    for (auto const& it : itemsToAdd)
    {
        if (mainLoot->items.size() + mainLoot->quest_items.size() >= MAX_MERGE_SLOTS) break;
        mainLoot->items.push_back(it);
        mainLoot->unlootedCount++;
    }
    for (auto const& it : questItemsToAdd)
    {
        if (mainLoot->items.size() + mainLoot->quest_items.size() >= MAX_MERGE_SLOTS) break;
        mainLoot->quest_items.push_back(it);
        mainLoot->unlootedCount++;
    }

    mainLoot->gold = totalGold;
    uint32 mergedGold = totalGold;

    {
        std::lock_guard<std::mutex> lock(sAoELootStateMutex);
        PlayerAoELootData& data = sPlayerLootData[player->GetGUID()];
        data.lastAoELoot = GameTime::GetGameTime().count();
        data.lootedThisSession += processed;
    }

    // Taken freshly at each call site below rather than holding a reference for
    // the rest of the function: every one of them follows a ModifyMoney() call,
    // and the lock must not span that.
    auto recordCreditedGold = [player](uint32 credited)
    {
        std::lock_guard<std::mutex> lock(sAoELootStateMutex);
        PlayerAoELootData& data = sPlayerLootData[player->GetGUID()];
        data.lastCreditedGold = credited;
        data.accumulatedCreditedGold += credited;
    };

    if (Group* group = player->GetGroup())
    {
        LootMethod method = group->GetLootMethod();
        if (method == MASTER_LOOT)
        {
            group->MasterLoot(mainLoot, mainCreature);
        }
        else if (method == NEED_BEFORE_GREED || method == GROUP_LOOT || method == FREE_FOR_ALL)
        {
            group->GroupLoot(mainLoot, mainCreature);
        }
    }

    if (shouldAutoLootForPlayer(player))
    {
        std::vector<std::pair<uint32, uint32>> mailItems;
        auto storeOrMail = [&](LootItem& li) {
            if (li.is_blocked || li.is_looted) return;
            ItemPosCountVec dest;
            InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, li.itemid, li.count);
            if (msg == EQUIP_ERR_OK)
            {
                Item* newItem = player->StoreNewItem(dest, li.itemid, true, li.randomPropertyId);
                if (newItem) player->SendNewItem(newItem, uint32(li.count), false, false, true);
            }
            else
                mailItems.emplace_back(li.itemid, uint32(li.count));

            li.is_looted = true;
            li.count = 0;
            if (mainLoot->unlootedCount > 0) --mainLoot->unlootedCount;
        };
        for (auto& it : mainLoot->items) storeOrMail(it);
        for (auto& it : mainLoot->quest_items) storeOrMail(it);

        if (mainLoot->gold > 0)
        {
            uint32 const credited = mainLoot->gold;
            player->ModifyMoney(credited);
            recordCreditedGold(credited);
            mainLoot->gold = 0;
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
        if (mainLoot->isLooted())
        {
            mainLoot->clear();
            mainCreature->AllLootRemovedFromCorpse();
            mainCreature->RemoveDynamicFlag(UNIT_DYNFLAG_LOOTABLE);
            return true;
        }
    }

    // Auto-credit gold to solo looter
    if (mainLoot->gold > 0 && !player->GetGroup())
    {
        uint32 credited = mainLoot->gold;
        player->ModifyMoney(credited);
        mainLoot->gold = 0;
        recordCreditedGold(credited);
    }

    if (shouldAutoLootForPlayer(player))
        player->SendLootRelease(mainCreature->GetGUID());
    else
        player->SendLoot(mainCreature->GetGUID(), LOOT_CORPSE);

    if (processed > 0)
        UpdateDetailedStats(player->GetGUID(), static_cast<uint32>(itemsToAdd.size()), mergedGold, 0);

    if (ShouldShowMessage(player) && processed > 0)
    {
        std::ostringstream ss;
        ss << "|cFF00FF00[AoE Loot]|r Looted " << processed << " corpses. ";
        if (!itemsToAdd.empty()) ss << "Items: " << itemsToAdd.size() << ". ";
        if (mergedGold > 0) ss << "Gold: " << DCUtils::FormatCoinsVerbose(mergedGold);
        ChatHandler(player->GetSession()).PSendSysMessage("{}", ss.str());
    }
    return true;
}

namespace DCAoELootExt
{

static bool IsPathReachableForLooterPet(WorldObject const* searchAnchor, WorldObject const* target)
{
    if (!searchAnchor || !target)
        return false;

    if (searchAnchor->GetMap() != target->GetMap())
        return false;

    PathGenerator path(searchAnchor);
    path.SetUseStraightPath(false);
    bool const result = path.CalculatePath(
        target->GetPositionX(), target->GetPositionY(), target->GetPositionZ(), false);

    PathType const pathType = path.GetPathType();
    if (!result || (pathType & PATHFIND_NOPATH))
        return false;

    if (!sConfig.looterPetPathAllowIncomplete && (pathType & PATHFIND_INCOMPLETE))
        return false;

    if (sConfig.looterPetPathRejectShortcut && (pathType & PATHFIND_SHORTCUT))
        return false;

    if (sConfig.looterPetPathMaxLength > 0.0f &&
        path.getPathLength() > sConfig.looterPetPathMaxLength)
    {
        return false;
    }

    return true;
}

static void MoveCompanionTowardTarget(Player* player, WorldObject* searchAnchor, Creature* target)
{
    if (!player || !searchAnchor || !target)
        return;

    Unit* anchorUnit = searchAnchor->ToUnit();
    if (!anchorUnit)
        return;

    if (anchorUnit->GetGUID() == player->GetGUID())
        return;

    Creature* companion = anchorUnit->ToCreature();
    if (!companion || !companion->IsAlive())
        return;

    if (companion->GetDistance(target) <= 1.5f)
        return;

    companion->GetMotionMaster()->MovePoint(
        9001,
        target->GetPositionX(),
        target->GetPositionY(),
        target->GetPositionZ());
}

bool TriggerLooterPetLootPulse(Player* player, WorldObject* searchAnchor)
{
    if (!player || !player->IsAlive())
        return false;

    if (!IsPlayerAoELootEnabled(player->GetGUID()))
        return false;

    if (!searchAnchor)
        searchAnchor = player;

    if (!searchAnchor->IsInWorld())
        return false;

    float lootRange = GetPlayerLootRange(player->GetGUID());
    if (lootRange < 5.0f || lootRange > 100.0f)
        lootRange = sConfig.range;

    std::list<Creature*> nearby;
    searchAnchor->GetDeadCreatureListInGrid(nearby, lootRange);

    std::vector<std::pair<Creature*, float>> candidates;
    candidates.reserve(nearby.size());

    for (Creature* creature : nearby)
    {
        if (!creature)
            continue;
        if (!creature->HasDynamicFlag(UNIT_DYNFLAG_LOOTABLE))
            continue;
        if (!CanPlayerLootCorpse(player, creature))
            continue;
        if (player->GetGroup() && !sConfig.allowInGroup)
            continue;

        candidates.emplace_back(creature, searchAnchor->GetDistance(creature));
    }

    if (candidates.empty())
        return false;

    std::sort(candidates.begin(), candidates.end(),
        [](std::pair<Creature*, float> const& left, std::pair<Creature*, float> const& right)
        {
            return left.second < right.second;
        });

    Creature* target = nullptr;
    if (!sConfig.looterPetPathfindingEnable)
    {
        target = candidates.front().first;
    }
    else
    {
        uint32 const checks = std::min<uint32>(
            sConfig.looterPetPathMaxChecks,
            static_cast<uint32>(candidates.size()));

        for (uint32 i = 0; i < checks; ++i)
        {
            Creature* candidate = candidates[i].first;
            if (IsPathReachableForLooterPet(searchAnchor, candidate))
            {
                target = candidate;
                break;
            }
        }

        // Fail-open fallback: keep autonomous looting functional when
        // path data is unavailable or all candidates are rejected.
        if (!target)
            target = candidates.front().first;
    }

    if (!target)
        return false;

    MoveCompanionTowardTarget(player, searchAnchor, target);

    return PerformAoELoot(player, target, true);
}

bool TriggerLooterPetLootPulse(Player* player)
{
    return TriggerLooterPetLootPulse(player, player);
}

} // namespace DCAoELootExt

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

    bool CanPacketReceive(WorldSession* session, WorldPacket const& packet) override
    {
        if (!sConfig.enabled || !session) return true;

        if (packet.GetOpcode() == CMSG_AUTOSTORE_LOOT_ITEM)
        {
            Player* player = session->GetPlayer();
            if (!player) return true;
            bool goldOnly;
            bool hasIgnoredItems;
            {
                std::lock_guard<std::mutex> lock(sAoELootStateMutex);
                sPlayerAutoStoreTimestamp[player->GetGUID()] = GameTime::GetGameTime().count();

                PlayerLootPreferences const& prefs = sPlayerPrefs[player->GetGUID()];
                goldOnly = prefs.goldOnly;
                hasIgnoredItems = !prefs.ignoredItemIds.empty();
            }

            uint8 playerMinQuality = GetPlayerMinQualityFilter(player);
            if (playerMinQuality > 0 || goldOnly || hasIgnoredItems)
            {
                WorldPacket p(packet);
                p.rpos(0);
                uint8 lootSlot;
                p >> lootSlot;

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
                    LootItem const& lootItem = loot->items[lootSlot];
                    if (!lootItem.needs_quest)
                    {
                        uint32 itemId = lootItem.itemid;
                        if (goldOnly)
                            return false;
                        if (IsItemIgnoredByPlayer(player, itemId))
                            return false;
                        if (itemId > 0 && !ItemMeetsQualityFilter(itemId, playerMinQuality))
                            return false;
                    }
                }
            }
            return true;
        }

        if (packet.GetOpcode() != CMSG_LOOT) return true;

        Player* player = session->GetPlayer();
        if (!player) return true;

        WorldPacket p(packet);
        p.rpos(0);
        ObjectGuid guid;
        p >> guid;

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
    AoELootPlayerScript() : PlayerScript("AoELootPlayerScript", { PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_LOGOUT }) { }

    void OnPlayerLogin(Player* player) override
    {
        if (!player) return;

        // Initialize preferences
        {
            std::lock_guard<std::mutex> lock(sAoELootStateMutex);
            PlayerLootPreferences& prefs = sPlayerPrefs[player->GetGUID()];
            prefs.aoeLootEnabled = true;
            prefs.showMessages = true;
            prefs.minQuality = 0;
            prefs.autoSkin = sConfig.autoSkinEnabled;
            prefs.smartLootEnabled = true;
            prefs.autoVendorPoor = sConfig.autoVendorPoorItems;
            prefs.goldOnly = false;
            prefs.lootRange = sConfig.range;
            prefs.ignoredItemIds.clear();
            prefs.activePreset = 0;
        }

        PreferenceSchemaInfo const& schema = GetPreferenceSchemaInfo();

        std::vector<std::string> columns =
        {
            "aoe_enabled",
            "min_quality",
            "auto_skin",
            "smart_loot"
        };

        if (schema.hasShowMessages)
            columns.push_back("show_messages");
        if (schema.hasAutoVendorPoor)
            columns.push_back("auto_vendor_poor");
        if (schema.hasIgnoredItems)
            columns.push_back("ignored_items");
        if (schema.hasGoldOnly)
            columns.push_back("gold_only");
        if (schema.hasLootRange)
            columns.push_back("loot_range");
        if (schema.hasActivePreset)
            columns.push_back("active_preset");

        std::string query = Acore::StringFormat(
            "SELECT {} FROM dc_aoeloot_preferences WHERE player_guid = {}",
            DCUtils::JoinStringList(columns), player->GetGUID().GetCounter());

        // Initialize session data
        {
            std::lock_guard<std::mutex> lock(sAoELootStateMutex);
            sPlayerLootData[player->GetGUID()] = PlayerAoELootData();
        }

        // Defaults above are usable immediately; the saved preferences are
        // loaded asynchronously so a relog never blocks the world thread on
        // MySQL round-trips. The continuation runs on the world thread.
        ObjectGuid const guid = player->GetGUID();

        DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(query)
            .WithCallback([guid, schema](QueryResult result)
        {
            {
            std::lock_guard<std::mutex> lock(sAoELootStateMutex);

            auto prefIt = sPlayerPrefs.find(guid);
            if (prefIt == sPlayerPrefs.end())
                return; // logged out before the load finished

            PlayerLootPreferences& prefs = prefIt->second;

            if (result)
            {
                Field* f = result->Fetch();
                uint8 idx = 0;
                prefs.aoeLootEnabled = f[idx++].Get<bool>();
                prefs.minQuality = f[idx++].Get<uint8>();
                if (prefs.minQuality > 6) prefs.minQuality = 6;
                prefs.autoSkin = f[idx++].Get<bool>();
                prefs.smartLootEnabled = f[idx++].Get<bool>();

                if (schema.hasShowMessages)
                    prefs.showMessages = f[idx++].Get<bool>();

                if (schema.hasAutoVendorPoor)
                    prefs.autoVendorPoor = f[idx++].Get<bool>();

                if (schema.hasIgnoredItems)
                    ParseIgnoredItems(f[idx++].Get<std::string>(), prefs.ignoredItemIds);

                if (schema.hasGoldOnly)
                    prefs.goldOnly = f[idx++].Get<bool>();

                if (schema.hasLootRange)
                {
                    prefs.lootRange = f[idx++].Get<float>();
                    if (prefs.lootRange < 5.0f || prefs.lootRange > 100.0f)
                        prefs.lootRange = sConfig.range;
                }

                if (schema.hasActivePreset)
                {
                    prefs.activePreset = f[idx++].Get<uint8>();
                    if (prefs.activePreset > LOOT_PRESET_CUSTOM)
                        prefs.activePreset = 0;
                }
            }
            }   // lock released: ShouldShowMessage() locks for itself

            if (Player* player = ObjectAccessor::FindPlayer(guid))
                if (ShouldShowMessage(player))
                    ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00[AoE Loot]|r System enabled.");
        }));

        // Load detailed stats (async for the same reason).
        if (sConfig.trackDetailedStats)
        {
            std::string statsQuery = Acore::StringFormat(
                "SELECT total_items, total_gold, poor_vendored, vendor_gold, skinned, mined, herbed, upgrades, "
                "quality_poor, quality_common, quality_uncommon, quality_rare, quality_epic, quality_legendary, "
                "filtered_poor, filtered_common, filtered_uncommon, filtered_rare, filtered_epic, filtered_legendary, "
                "mythic_bonus_items "
                "FROM dc_aoeloot_detailed_stats WHERE player_guid = {}",
                guid.GetCounter());

            DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(statsQuery)
                .WithCallback([guid](QueryResult statsResult)
            {
                if (!statsResult)
                    return;

                std::lock_guard<std::mutex> lock(sAoELootStateMutex);

                if (sPlayerPrefs.find(guid) == sPlayerPrefs.end())
                    return; // logged out before the load finished

                Field* f = statsResult->Fetch();
                DetailedLootStats& stats = sDetailedStats[guid];
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
            }));
        }
    }

    void OnPlayerLogout(Player* player) override
    {
        if (!player) return;

        // Take the state out under the lock, then build and issue the SQL
        // outside it: string formatting and a database round-trip must not run
        // with a global lock held.
        PlayerLootPreferences prefs;
        DetailedLootStats stats;
        bool hasPrefs = false;
        bool hasStats = false;
        {
            std::lock_guard<std::mutex> lock(sAoELootStateMutex);

            auto prefIt = sPlayerPrefs.find(player->GetGUID());
            if (prefIt != sPlayerPrefs.end())
            {
                prefs = prefIt->second;
                hasPrefs = true;
                sPlayerPrefs.erase(prefIt);
            }

            if (sConfig.trackDetailedStats)
            {
                auto statsIt = sDetailedStats.find(player->GetGUID());
                if (statsIt != sDetailedStats.end())
                {
                    stats = statsIt->second;
                    hasStats = true;
                    sDetailedStats.erase(statsIt);
                }
            }

            sPlayerLootData.erase(player->GetGUID());
            sPlayerAutoStoreTimestamp.erase(player->GetGUID());
        }

        // Save preferences
        if (hasPrefs)
        {
            PreferenceSchemaInfo const& schema = GetPreferenceSchemaInfo();

            std::vector<std::string> columns =
            {
                "player_guid",
                "aoe_enabled",
                "min_quality",
                "auto_skin",
                "smart_loot"
            };

            std::vector<std::string> values =
            {
                std::to_string(player->GetGUID().GetCounter()),
                prefs.aoeLootEnabled ? "1" : "0",
                std::to_string(prefs.minQuality),
                prefs.autoSkin ? "1" : "0",
                prefs.smartLootEnabled ? "1" : "0"
            };

            std::vector<std::string> updates =
            {
                "aoe_enabled = VALUES(aoe_enabled)",
                "min_quality = VALUES(min_quality)",
                "auto_skin = VALUES(auto_skin)",
                "smart_loot = VALUES(smart_loot)"
            };

            if (schema.hasShowMessages)
            {
                columns.push_back("show_messages");
                values.push_back(prefs.showMessages ? "1" : "0");
                updates.push_back("show_messages = VALUES(show_messages)");
            }

            if (schema.hasAutoVendorPoor)
            {
                columns.push_back("auto_vendor_poor");
                values.push_back(prefs.autoVendorPoor ? "1" : "0");
                updates.push_back("auto_vendor_poor = VALUES(auto_vendor_poor)");
            }

            if (schema.hasIgnoredItems)
            {
                columns.push_back("ignored_items");
                values.push_back(Acore::StringFormat("'{}'", EscapeSqlString(SerializeIgnoredItems(prefs.ignoredItemIds))));
                updates.push_back("ignored_items = VALUES(ignored_items)");
            }

            if (schema.hasGoldOnly)
            {
                columns.push_back("gold_only");
                values.push_back(prefs.goldOnly ? "1" : "0");
                updates.push_back("gold_only = VALUES(gold_only)");
            }

            if (schema.hasLootRange)
            {
                float persistedRange = prefs.lootRange;
                if (persistedRange < 5.0f || persistedRange > 100.0f)
                    persistedRange = sConfig.range;

                columns.push_back("loot_range");
                values.push_back(Acore::StringFormat("{}", persistedRange));
                updates.push_back("loot_range = VALUES(loot_range)");
            }

            if (schema.hasActivePreset)
            {
                uint8 activePreset = prefs.activePreset;
                if (activePreset > LOOT_PRESET_CUSTOM)
                    activePreset = 0;

                columns.push_back("active_preset");
                values.push_back(std::to_string(activePreset));
                updates.push_back("active_preset = VALUES(active_preset)");
            }

            CharacterDatabase.Execute(Acore::StringFormat(
                "INSERT INTO dc_aoeloot_preferences ({}) VALUES ({}) ON DUPLICATE KEY UPDATE {}",
                DCUtils::JoinStringList(columns), DCUtils::JoinStringList(values), DCUtils::JoinStringList(updates)));
        }

        // Save detailed stats
        if (hasStats)
        {
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
        }
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
            { "msg",      HandleMessages, SEC_PLAYER,        Console::No },
            { "quality",  HandleQuality,  SEC_PLAYER,        Console::No },
            { "skin",     HandleSkin,     SEC_PLAYER,        Console::No },
            { "skinset",  HandleSkin,     SEC_PLAYER,        Console::No },
            { "smart",    HandleSmart,    SEC_PLAYER,        Console::No },
            { "smartset", HandleSmart,    SEC_PLAYER,        Console::No },
            { "goldonly", HandleGoldOnly, SEC_PLAYER,        Console::No },
            { "autovendor", HandleAutoVendor, SEC_PLAYER,    Console::No },
            { "ignore",   HandleIgnoreItem, SEC_PLAYER,      Console::No },
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

    static bool HandleToggle(ChatHandler* handler, Optional<bool> enabled = {})
    {
        Player* player = handler->GetPlayer();
        if (!player) return true;
        bool next;
        {
            std::lock_guard<std::mutex> lock(sAoELootStateMutex);
            PlayerLootPreferences& prefs = sPlayerPrefs[player->GetGUID()];
            prefs.aoeLootEnabled = enabled.value_or(!prefs.aoeLootEnabled);
            next = prefs.aoeLootEnabled;
        }

        handler->PSendSysMessage("|cff00ff00[AoE Loot]|r {}", next ? "Enabled" : "Disabled");
        return true;
    }

    static bool HandleEnable(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!player) return true;
        {
            std::lock_guard<std::mutex> lock(sAoELootStateMutex);
            sPlayerPrefs[player->GetGUID()].aoeLootEnabled = true;
        }

        handler->PSendSysMessage("|cff00ff00[AoE Loot]|r Enabled");
        return true;
    }

    static bool HandleDisable(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!player) return true;
        {
            std::lock_guard<std::mutex> lock(sAoELootStateMutex);
            sPlayerPrefs[player->GetGUID()].aoeLootEnabled = false;
        }

        handler->PSendSysMessage("|cff00ff00[AoE Loot]|r Disabled");
        return true;
    }

    static bool HandleMessages(ChatHandler* handler, Optional<bool> enabled = {})
    {
        Player* player = handler->GetPlayer();
        if (!player) return true;
        bool next;
        {
            std::lock_guard<std::mutex> lock(sAoELootStateMutex);
            PlayerLootPreferences& prefs = sPlayerPrefs[player->GetGUID()];
            prefs.showMessages = enabled.value_or(!prefs.showMessages);
            next = prefs.showMessages;
        }

        handler->PSendSysMessage("|cff00ff00[AoE Loot]|r Messages: {}", next ? "On" : "Off");
        return true;
    }

    static bool HandleQuality(ChatHandler* handler, uint8 quality)
    {
        Player* player = handler->GetPlayer();
        if (!player) return true;
        if (quality > 6) quality = 6;
        {
            std::lock_guard<std::mutex> lock(sAoELootStateMutex);
            sPlayerPrefs[player->GetGUID()].minQuality = quality;
        }

        handler->PSendSysMessage("|cff00ff00[AoE Loot]|r Min quality: {}", DCUtils::GetQualityName(quality));
        return true;
    }

    static bool HandleSkin(ChatHandler* handler, Optional<bool> enabled = {})
    {
        Player* player = handler->GetPlayer();
        if (!player) return true;
        bool next;
        {
            std::lock_guard<std::mutex> lock(sAoELootStateMutex);
            PlayerLootPreferences& prefs = sPlayerPrefs[player->GetGUID()];
            prefs.autoSkin = enabled.value_or(!prefs.autoSkin);
            next = prefs.autoSkin;
        }

        handler->PSendSysMessage("|cff00ff00[AoE Loot]|r Auto-Skin: {}", next ? "On" : "Off");
        return true;
    }

    static bool HandleSmart(ChatHandler* handler, Optional<bool> enabled = {})
    {
        Player* player = handler->GetPlayer();
        if (!player) return true;
        bool next;
        {
            std::lock_guard<std::mutex> lock(sAoELootStateMutex);
            PlayerLootPreferences& prefs = sPlayerPrefs[player->GetGUID()];
            prefs.smartLootEnabled = enabled.value_or(!prefs.smartLootEnabled);
            next = prefs.smartLootEnabled;
        }

        handler->PSendSysMessage("|cff00ff00[AoE Loot]|r Smart Loot: {}", next ? "On" : "Off");
        return true;
    }

    static bool HandleGoldOnly(ChatHandler* handler, Optional<bool> enabled = {})
    {
        Player* player = handler->GetPlayer();
        if (!player) return true;

        bool next;
        {
            std::lock_guard<std::mutex> lock(sAoELootStateMutex);
            PlayerLootPreferences& prefs = sPlayerPrefs[player->GetGUID()];
            prefs.goldOnly = enabled.value_or(!prefs.goldOnly);
            next = prefs.goldOnly;
        }

        handler->PSendSysMessage("|cff00ff00[AoE Loot]|r Gold-only mode: {}", next ? "On" : "Off");
        return true;
    }

    static bool HandleAutoVendor(ChatHandler* handler, Optional<bool> enabled = {})
    {
        Player* player = handler->GetPlayer();
        if (!player) return true;

        bool next;
        {
            std::lock_guard<std::mutex> lock(sAoELootStateMutex);
            PlayerLootPreferences& prefs = sPlayerPrefs[player->GetGUID()];
            prefs.autoVendorPoor = enabled.value_or(!prefs.autoVendorPoor);
            next = prefs.autoVendorPoor;
        }

        handler->PSendSysMessage("|cff00ff00[AoE Loot]|r Auto-vendor poor items: {}", next ? "On" : "Off");
        return true;
    }

    static bool HandleIgnoreItem(ChatHandler* handler, uint32 itemId)
    {
        Player* player = handler->GetPlayer();
        if (!player) return true;
        if (!itemId)
        {
            handler->SendSysMessage("|cffff0000[AoE Loot]|r Invalid item id.");
            return true;
        }

        bool added;
        {
            std::lock_guard<std::mutex> lock(sAoELootStateMutex);
            auto& ignored = sPlayerPrefs[player->GetGUID()].ignoredItemIds;
            auto it = ignored.find(itemId);
            if (it == ignored.end())
            {
                ignored.insert(itemId);
                added = true;
            }
            else
            {
                ignored.erase(it);
                added = false;
            }
        }

        if (added)
            handler->PSendSysMessage("|cff00ff00[AoE Loot]|r Item {} added to ignore list.", itemId);
        else
            handler->PSendSysMessage("|cff00ff00[AoE Loot]|r Item {} removed from ignore list.", itemId);
        return true;
    }

    static bool HandleStats(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!player) return true;

        // Copy both records, then print: PSendSysMessage builds and queues a
        // packet and must not run with the state lock held.
        PlayerLootPreferences prefs;
        DetailedLootStats stats;
        bool hasStats = false;
        {
            std::lock_guard<std::mutex> lock(sAoELootStateMutex);
            prefs = sPlayerPrefs[player->GetGUID()];

            auto it = sDetailedStats.find(player->GetGUID());
            if (it != sDetailedStats.end())
            {
                stats = it->second;
                hasStats = true;
            }
        }

        handler->SendSysMessage("|cff00ff00========== AoE LOOT SETTINGS ==========|r");
        handler->PSendSysMessage("Enabled: {}", prefs.aoeLootEnabled ? "Yes" : "No");
        handler->PSendSysMessage("Messages: {}", prefs.showMessages ? "On" : "Off");
        handler->PSendSysMessage("Min Quality: {}", DCUtils::GetQualityName(prefs.minQuality));
        handler->PSendSysMessage("Auto-Skin: {}", prefs.autoSkin ? "On" : "Off");
        handler->PSendSysMessage("Smart Loot: {}", prefs.smartLootEnabled ? "On" : "Off");
        handler->PSendSysMessage("Gold-Only: {}", prefs.goldOnly ? "On" : "Off");
        handler->PSendSysMessage("Auto-Vendor Poor: {}", prefs.autoVendorPoor ? "On" : "Off");
        handler->PSendSysMessage("Ignored Items: {}", static_cast<uint32>(prefs.ignoredItemIds.size()));

        if (hasStats)
        {
            handler->SendSysMessage("|cff00ff00========== STATISTICS ==========|r");
            handler->PSendSysMessage("Items Looted: {}", stats.totalItemsLooted);
            handler->PSendSysMessage("Gold Looted: {}", DCUtils::FormatCoinsVerbose(stats.totalGoldLooted));
            handler->PSendSysMessage("Skinned: {}", stats.skinnedCorpses);
        }
        return true;
    }

    static bool HandleInfo(ChatHandler* handler)
    {
        handler->PSendSysMessage("AoE Loot: {}", sConfig.enabled ? "Enabled" : "Disabled");
        if (sConfig.enabled)
        {
            handler->PSendSysMessage("  Range: {:.1f} yards", sConfig.range);
            handler->PSendSysMessage("  Max Corpses: {}", sConfig.maxCorpses);
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
