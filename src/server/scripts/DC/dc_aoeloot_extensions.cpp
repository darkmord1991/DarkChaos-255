/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * DarkChaos AOE Loot Extensions
 * Enhances base ac_aoeloot with DC-specific features:
 * - Loot quality filtering
 * - Raid loot mode support
 * - Skinning/Mining/Herb integration
 * - Smart loot preferences
 * - Mythic+ integration
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Creature.h"
#include "Config.h"
#include "Chat.h"
#include "CommandScript.h"
#include "ObjectAccessor.h"
#include "WorldPacket.h"
#include "GameTime.h"
#include "LootMgr.h"
#include "Group.h"
#include "Log.h"
#include "Item.h"
#include "StringFormat.h"
#include "Spell.h"
#include "DatabaseEnv.h"

#include <unordered_map>
#include <unordered_set>
#include <sstream>

using namespace Acore::ChatCommands;

namespace DCAoELootExt
{
    // ============================================================
    // Extended Configuration
    // ============================================================
    struct AoELootExtConfig
    {
        bool enabled = true;
        
        // Quality Filtering
        bool qualityFilterEnabled = false;
        uint8 minQuality = 0;  // 0=Poor, 1=Common, 2=Uncommon, 3=Rare, 4=Epic, 5=Legendary
        uint8 maxQuality = 6;  // 6=Artifact
        bool autoVendorPoorItems = false;
        
        // Profession Integration
        bool autoSkinEnabled = true;
        bool autoMineEnabled = true;
        bool autoHerbEnabled = true;
        float professionRange = 10.0f;
        
        // Smart Loot Preferences
        bool preferCurrentSpec = true;
        bool preferEquippable = true;
        bool prioritizeUpgrades = true;
        
        // Mythic+ Integration
        bool mythicPlusBonus = true;
        float mythicPlusRangeMultiplier = 1.5f;
        
        // Raid Features
        bool raidModeEnabled = true;
        uint32 raidMaxCorpses = 25;
        
        // Statistics
        bool trackDetailedStats = true;

        void Load()
        {
            enabled = sConfigMgr->GetOption<bool>("AoELoot.Extensions.Enable", true);
            
            qualityFilterEnabled = sConfigMgr->GetOption<bool>("AoELoot.Extensions.QualityFilter.Enable", false);
            // Clamp minQuality to 0-6 range
            minQuality = sConfigMgr->GetOption<uint8>("AoELoot.Extensions.QualityFilter.MinQuality", 0);
            if (minQuality > 6) minQuality = 6;
            // Clamp maxQuality to 0-6 range
            maxQuality = sConfigMgr->GetOption<uint8>("AoELoot.Extensions.QualityFilter.MaxQuality", 6);
            if (maxQuality > 6) maxQuality = 6;
            // Ensure minQuality <= maxQuality
            if (minQuality > maxQuality) minQuality = maxQuality;
            autoVendorPoorItems = sConfigMgr->GetOption<bool>("AoELoot.Extensions.QualityFilter.AutoVendorPoor", false);
            
            autoSkinEnabled = sConfigMgr->GetOption<bool>("AoELoot.Extensions.Profession.AutoSkin", true);
            autoMineEnabled = sConfigMgr->GetOption<bool>("AoELoot.Extensions.Profession.AutoMine", true);
            autoHerbEnabled = sConfigMgr->GetOption<bool>("AoELoot.Extensions.Profession.AutoHerb", true);
            // Clamp profession range to 1-100 yards
            professionRange = sConfigMgr->GetOption<float>("AoELoot.Extensions.Profession.Range", 10.0f);
            if (professionRange < 1.0f) professionRange = 1.0f;
            if (professionRange > 100.0f) professionRange = 100.0f;
            
            preferCurrentSpec = sConfigMgr->GetOption<bool>("AoELoot.Extensions.SmartLoot.PreferCurrentSpec", true);
            preferEquippable = sConfigMgr->GetOption<bool>("AoELoot.Extensions.SmartLoot.PreferEquippable", true);
            prioritizeUpgrades = sConfigMgr->GetOption<bool>("AoELoot.Extensions.SmartLoot.PrioritizeUpgrades", true);
            
            mythicPlusBonus = sConfigMgr->GetOption<bool>("AoELoot.Extensions.MythicPlus.Bonus", true);
            // Clamp mythic+ range multiplier to 1.0-5.0
            mythicPlusRangeMultiplier = sConfigMgr->GetOption<float>("AoELoot.Extensions.MythicPlus.RangeMultiplier", 1.5f);
            if (mythicPlusRangeMultiplier < 1.0f) mythicPlusRangeMultiplier = 1.0f;
            if (mythicPlusRangeMultiplier > 5.0f) mythicPlusRangeMultiplier = 5.0f;
            
            raidModeEnabled = sConfigMgr->GetOption<bool>("AoELoot.Extensions.Raid.Enable", true);
            // Clamp raid max corpses to 1-100
            raidMaxCorpses = sConfigMgr->GetOption<uint32>("AoELoot.Extensions.Raid.MaxCorpses", 25);
            if (raidMaxCorpses < 1) raidMaxCorpses = 1;
            if (raidMaxCorpses > 100) raidMaxCorpses = 100;
            
            trackDetailedStats = sConfigMgr->GetOption<bool>("AoELoot.Extensions.TrackDetailedStats", true);
        }
    };

    static AoELootExtConfig sConfig;

    // ============================================================
    // Player Loot Preferences
    // ============================================================
    struct PlayerLootPreferences
    {
        bool aoeLootEnabled = true;
        bool showMessages = true;  // Toggle for debug/info messages
        uint8 minQuality = 0;
        bool autoSkin = true;
        bool smartLootEnabled = true;
        bool autoVendorPoor = false;
        float lootRange = 45.0f;
        std::unordered_set<uint32> ignoredItemIds;
    };

    static std::unordered_map<ObjectGuid, PlayerLootPreferences> sPlayerPrefs;

    // Exported function for ac_aoeloot.cpp to query showMessages preference
    bool GetPlayerShowMessages(ObjectGuid playerGuid)
    {
        auto it = sPlayerPrefs.find(playerGuid);
        if (it != sPlayerPrefs.end())
            return it->second.showMessages;
        return true; // default: show messages
    }

    // Exported function to set showMessages preference
    void SetPlayerShowMessages(ObjectGuid playerGuid, bool value)
    {
        sPlayerPrefs[playerGuid].showMessages = value;
    }

    // Exported function for ac_aoeloot.cpp to query if player has AoE loot enabled
    bool IsPlayerAoELootEnabled(ObjectGuid playerGuid)
    {
        auto it = sPlayerPrefs.find(playerGuid);
        if (it != sPlayerPrefs.end())
            return it->second.aoeLootEnabled;
        return true; // default: enabled
    }

    // Exported function to set player's AoE loot enabled preference
    void SetPlayerAoELootEnabled(ObjectGuid playerGuid, bool value)
    {
        sPlayerPrefs[playerGuid].aoeLootEnabled = value;
    }

    // Exported function for ac_aoeloot.cpp to query player's minimum quality filter
    uint8 GetPlayerMinQuality(ObjectGuid playerGuid)
    {
        auto it = sPlayerPrefs.find(playerGuid);
        if (it != sPlayerPrefs.end())
            return it->second.minQuality;
        return 0; // default: loot everything (Poor and above)
    }

    // Exported function to set player's minimum quality filter
    void SetPlayerMinQuality(ObjectGuid playerGuid, uint8 quality)
    {
        if (quality > 6) quality = 6;
        sPlayerPrefs[playerGuid].minQuality = quality;
    }

    // ============================================================
    // Detailed Statistics
    // ============================================================
    struct DetailedLootStats
    {
        uint32 totalItemsLooted = 0;
        uint32 totalGoldLooted = 0;
        uint32 poorItemsVendored = 0;
        uint32 goldFromVendor = 0;
        uint32 skinnedCorpses = 0;
        uint32 minedNodes = 0;
        uint32 herbedNodes = 0;
        std::unordered_map<uint8, uint32> itemsByQuality;  // quality -> count
        uint32 upgradesFound = 0;
    };

    static std::unordered_map<ObjectGuid, DetailedLootStats> sDetailedStats;

    // ============================================================
    // Helper Functions
    // ============================================================

    bool IsInMythicPlusDungeon(Player* player)
    {
        if (!player || !player->GetMap())
            return false;

        if (!player->GetMap()->IsDungeon())
            return false;

        // Check via config or MythicPlusRunManager if available
        // This is a simple check - could integrate with sMythicPlusRunManager
        return sConfigMgr->GetOption<bool>("MythicPlus.Enable", false);
    }

    bool IsItemUpgrade(Player* player, uint32 itemId)
    {
        ItemTemplate const* proto = sObjectMgr->GetItemTemplate(itemId);
        if (!proto)
            return false;

        // Check if it's equippable by the player
        if (proto->Class != ITEM_CLASS_ARMOR && proto->Class != ITEM_CLASS_WEAPON)
            return false;

        // Get currently equipped item in the same slot
        uint8 slot = 0;
        switch (proto->InventoryType)
        {
            case INVTYPE_HEAD: slot = EQUIPMENT_SLOT_HEAD; break;
            case INVTYPE_SHOULDERS: slot = EQUIPMENT_SLOT_SHOULDERS; break;
            case INVTYPE_CHEST:
            case INVTYPE_ROBE: slot = EQUIPMENT_SLOT_CHEST; break;
            case INVTYPE_WAIST: slot = EQUIPMENT_SLOT_WAIST; break;
            case INVTYPE_LEGS: slot = EQUIPMENT_SLOT_LEGS; break;
            case INVTYPE_FEET: slot = EQUIPMENT_SLOT_FEET; break;
            case INVTYPE_WRISTS: slot = EQUIPMENT_SLOT_WRISTS; break;
            case INVTYPE_HANDS: slot = EQUIPMENT_SLOT_HANDS; break;
            case INVTYPE_FINGER: slot = EQUIPMENT_SLOT_FINGER1; break;
            case INVTYPE_TRINKET: slot = EQUIPMENT_SLOT_TRINKET1; break;
            case INVTYPE_CLOAK: slot = EQUIPMENT_SLOT_BACK; break;
            case INVTYPE_WEAPON:
            case INVTYPE_WEAPONMAINHAND:
            case INVTYPE_2HWEAPON: slot = EQUIPMENT_SLOT_MAINHAND; break;
            case INVTYPE_SHIELD:
            case INVTYPE_HOLDABLE:
            case INVTYPE_WEAPONOFFHAND: slot = EQUIPMENT_SLOT_OFFHAND; break;
            case INVTYPE_RANGED:
            case INVTYPE_RANGEDRIGHT:
            case INVTYPE_THROWN: slot = EQUIPMENT_SLOT_RANGED; break;
            default: return false;
        }

        Item* equipped = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
        if (!equipped)
            return true;  // No item equipped = upgrade

        // Simple ilvl comparison
        return proto->ItemLevel > equipped->GetTemplate()->ItemLevel;
    }

    bool ShouldAutoVendorItem(Player* /*player*/, uint32 itemId)
    {
        if (!sConfig.autoVendorPoorItems)
            return false;

        ItemTemplate const* proto = sObjectMgr->GetItemTemplate(itemId);
        if (!proto)
            return false;

        return proto->Quality == ITEM_QUALITY_POOR;
    }

    uint32 GetVendorPrice(uint32 itemId)
    {
        ItemTemplate const* proto = sObjectMgr->GetItemTemplate(itemId);
        if (!proto)
            return 0;

        return proto->SellPrice;
    }

    bool CanPlayerSkinCreature(Player* player, Creature* creature)
    {
        if (!player || !creature)
            return false;

        // Check if creature is skinnable
        if (!creature->HasFlag(UNIT_FIELD_FLAGS, UNIT_FLAG_SKINNABLE))
            return false;

        // Check skinning skill
        uint32 requiredSkill = creature->GetCreatureTemplate()->GetRequiredLootSkill();
        uint32 playerSkill = 0;

        if (requiredSkill == SKILL_SKINNING)
            playerSkill = player->GetSkillValue(SKILL_SKINNING);
        else if (requiredSkill == SKILL_MINING)
            playerSkill = player->GetSkillValue(SKILL_MINING);
        else if (requiredSkill == SKILL_HERBALISM)
            playerSkill = player->GetSkillValue(SKILL_HERBALISM);
        else if (requiredSkill == SKILL_ENGINEERING)
            playerSkill = player->GetSkillValue(SKILL_ENGINEERING);

        if (playerSkill == 0)
            return false;

        // Simple level check - actual calculation is more complex
        uint32 targetLevel = creature->GetLevel();
        uint32 requiredLevel = targetLevel > 10 ? (targetLevel - 10) * 5 : 1;

        return playerSkill >= requiredLevel;
    }

    void AutoSkinCreature(Player* player, Creature* creature)
    {
        if (!sConfig.autoSkinEnabled || !CanPlayerSkinCreature(player, creature))
            return;

        // Generate skinning loot
        creature->loot.clear();
        creature->loot.FillLoot(creature->GetCreatureTemplate()->SkinLootId, LootTemplates_Skinning, player, true);

        if (creature->loot.empty())
            return;

        // Auto-loot the skinning results
        for (auto const& item : creature->loot.items)
        {
            ItemPosCountVec dest;
            InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, item.itemid, item.count);
            if (msg == EQUIP_ERR_OK)
            {
                Item* newItem = player->StoreNewItem(dest, item.itemid, true);
                if (newItem)
                    player->SendNewItem(newItem, item.count, false, false, true);
            }
        }

        // Update stats
        if (sConfig.trackDetailedStats)
        {
            DetailedLootStats& stats = sDetailedStats[player->GetGUID()];
            stats.skinnedCorpses++;
        }

        creature->loot.clear();
        creature->RemoveFlag(UNIT_FIELD_FLAGS, UNIT_FLAG_SKINNABLE);

        LOG_DEBUG("scripts", "DCAoELootExt: Auto-skinned creature {} for player {}", 
                  creature->GetEntry(), player->GetName());
    }

} // namespace DCAoELootExt

using namespace DCAoELootExt;

// ============================================================
// Player Script - Preference Management
// ============================================================
class DCAoELootExtPlayerScript : public PlayerScript
{
public:
    DCAoELootExtPlayerScript() : PlayerScript("DCAoELootExtPlayerScript") { }

    void OnPlayerLogin(Player* player) override
    {
        if (!player || !sConfig.enabled)
            return;

        // Load preferences from database
        QueryResult result = CharacterDatabase.Query(
            "SELECT aoe_enabled, min_quality, auto_skin, smart_loot, ignored_items, show_messages "
            "FROM dc_aoeloot_preferences WHERE player_guid = {}",
            player->GetGUID().GetCounter());

        PlayerLootPreferences prefs;
        if (result)
        {
            Field* fields = result->Fetch();
            prefs.aoeLootEnabled = fields[0].Get<bool>();
            // Clamp minQuality to valid range 0-6
            uint8 loadedQuality = fields[1].Get<uint8>();
            prefs.minQuality = loadedQuality > 6 ? 6 : loadedQuality;
            prefs.autoSkin = fields[2].Get<bool>();
            prefs.smartLootEnabled = fields[3].Get<bool>();
            
            std::string ignoredStr = fields[4].Get<std::string>();
            // Parse comma-separated item IDs
            std::istringstream ss(ignoredStr);
            std::string token;
            while (std::getline(ss, token, ','))
            {
                if (uint32 id = std::stoul(token))
                    prefs.ignoredItemIds.insert(id);
            }
            
            prefs.showMessages = fields[5].Get<bool>();
        }
        sPlayerPrefs[player->GetGUID()] = prefs;

        // Load detailed stats
        if (sConfig.trackDetailedStats)
        {
            QueryResult statsResult = CharacterDatabase.Query(
                "SELECT total_items, total_gold, poor_vendored, vendor_gold, skinned, mined, herbed, upgrades "
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
            }
        }
    }

    void OnPlayerLogout(Player* player) override
    {
        if (!player)
            return;

        // Save preferences
        auto prefIt = sPlayerPrefs.find(player->GetGUID());
        if (prefIt != sPlayerPrefs.end())
        {
            PlayerLootPreferences& prefs = prefIt->second;
            
            std::ostringstream ignoredSS;
            bool first = true;
            for (uint32 id : prefs.ignoredItemIds)
            {
                if (!first) ignoredSS << ",";
                ignoredSS << id;
                first = false;
            }

            CharacterDatabase.Execute(
                "REPLACE INTO dc_aoeloot_preferences "
                "(player_guid, aoe_enabled, min_quality, auto_skin, smart_loot, ignored_items, show_messages) "
                "VALUES ({}, {}, {}, {}, {}, '{}', {})",
                player->GetGUID().GetCounter(),
                prefs.aoeLootEnabled ? 1 : 0,
                prefs.minQuality,
                prefs.autoSkin ? 1 : 0,
                prefs.smartLootEnabled ? 1 : 0,
                ignoredSS.str(),
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
                    "(player_guid, total_items, total_gold, poor_vendored, vendor_gold, skinned, mined, herbed, upgrades) "
                    "VALUES ({}, {}, {}, {}, {}, {}, {}, {}, {})",
                    player->GetGUID().GetCounter(),
                    stats.totalItemsLooted, stats.totalGoldLooted, stats.poorItemsVendored,
                    stats.goldFromVendor, stats.skinnedCorpses, stats.minedNodes,
                    stats.herbedNodes, stats.upgradesFound);

                sDetailedStats.erase(statsIt);
            }
        }
    }

private:
    void SendAddonMessage(Player* player, std::string const& message)
    {
        if (!player || !player->GetSession())
            return;

        WorldPacket data(SMSG_MESSAGECHAT, 100);
        data << uint8(CHAT_MSG_WHISPER);
        data << uint32(LANG_ADDON);
        data << player->GetGUID();
        data << uint32(0);                          // custom chat size
        data << player->GetGUID();
        data << uint32(message.size() + 1);
        data << message;
        data << uint8(0);
        player->GetSession()->SendPacket(&data);
    }
};

// ============================================================
// Command Script - Loot Preferences
// ============================================================
class DCAoELootExtCommandScript : public CommandScript
{
public:
    DCAoELootExtCommandScript() : CommandScript("DCAoELootExtCommandScript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable lootPrefTable =
        {
            { "toggle",     HandleLootToggle,     SEC_PLAYER,        Console::No },
            { "enable",     HandleLootEnable,     SEC_PLAYER,        Console::No },
            { "disable",    HandleLootDisable,    SEC_PLAYER,        Console::No },
            { "messages",   HandleLootMessages,   SEC_PLAYER,        Console::No },
            { "msg",        HandleLootMsgSet,     SEC_PLAYER,        Console::No },
            { "quality",    HandleLootQuality,    SEC_PLAYER,        Console::No },
            { "skin",       HandleLootSkin,       SEC_PLAYER,        Console::No },
            { "skinset",    HandleLootSkinSet,    SEC_PLAYER,        Console::No },
            { "smart",      HandleLootSmart,      SEC_PLAYER,        Console::No },
            { "smartset",   HandleLootSmartSet,   SEC_PLAYER,        Console::No },
            { "ignore",     HandleLootIgnore,     SEC_PLAYER,        Console::No },
            { "unignore",   HandleLootUnignore,   SEC_PLAYER,        Console::No },
            { "stats",      HandleLootStats,      SEC_PLAYER,        Console::No },
            { "reload",     HandleLootReload,     SEC_ADMINISTRATOR, Console::No },
        };

        static ChatCommandTable commandTable =
        {
            { "lootpref", lootPrefTable },
            { "lp",       lootPrefTable },  // Shortcut
        };

        return commandTable;
    }

    static bool HandleLootToggle(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return true;

        PlayerLootPreferences& prefs = sPlayerPrefs[player->GetGUID()];
        prefs.aoeLootEnabled = !prefs.aoeLootEnabled;

        handler->PSendSysMessage("|cff00ff00[Loot Prefs]|r AoE Loot: %s",
                                  prefs.aoeLootEnabled ? "Enabled" : "Disabled");
        return true;
    }

    static bool HandleLootEnable(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return true;

        PlayerLootPreferences& prefs = sPlayerPrefs[player->GetGUID()];
        prefs.aoeLootEnabled = true;

        handler->PSendSysMessage("|cff00ff00[Loot Prefs]|r AoE Loot: Enabled");
        return true;
    }

    static bool HandleLootDisable(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return true;

        PlayerLootPreferences& prefs = sPlayerPrefs[player->GetGUID()];
        prefs.aoeLootEnabled = false;

        handler->PSendSysMessage("|cff00ff00[Loot Prefs]|r AoE Loot: Disabled");
        return true;
    }

    static bool HandleLootMessages(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return true;

        PlayerLootPreferences& prefs = sPlayerPrefs[player->GetGUID()];
        prefs.showMessages = !prefs.showMessages;

        handler->PSendSysMessage("|cff00ff00[Loot Prefs]|r Show Messages: %s",
                                  prefs.showMessages ? "Enabled" : "Disabled");
        return true;
    }

    static bool HandleLootMsgSet(ChatHandler* handler, bool enable)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return true;

        PlayerLootPreferences& prefs = sPlayerPrefs[player->GetGUID()];
        prefs.showMessages = enable;

        handler->PSendSysMessage("|cff00ff00[Loot Prefs]|r Show Messages: %s",
                                  prefs.showMessages ? "Enabled" : "Disabled");
        return true;
    }

    static bool HandleLootQuality(ChatHandler* handler, uint8 quality)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return true;

        // Clamp quality to valid range 0-6 (Poor to Artifact)
        if (quality > 6)
            quality = 6;

        PlayerLootPreferences& prefs = sPlayerPrefs[player->GetGUID()];
        prefs.minQuality = quality;

        const char* qualityNames[] = { "Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Artifact" };
        std::string msg = Acore::StringFormat("|cff00ff00[Loot Prefs]|r Minimum quality set to: {}", qualityNames[quality]);
        handler->SendSysMessage(msg.c_str());
        return true;
    }

    static bool HandleLootSkin(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return true;

        PlayerLootPreferences& prefs = sPlayerPrefs[player->GetGUID()];
        prefs.autoSkin = !prefs.autoSkin;

        handler->PSendSysMessage("|cff00ff00[Loot Prefs]|r Auto-Skin: %s",
                                  prefs.autoSkin ? "Enabled" : "Disabled");
        return true;
    }

    static bool HandleLootSkinSet(ChatHandler* handler, bool enable)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return true;

        PlayerLootPreferences& prefs = sPlayerPrefs[player->GetGUID()];
        prefs.autoSkin = enable;

        handler->PSendSysMessage("|cff00ff00[Loot Prefs]|r Auto-Skin: %s",
                                  prefs.autoSkin ? "Enabled" : "Disabled");
        return true;
    }

    static bool HandleLootSmart(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return true;

        PlayerLootPreferences& prefs = sPlayerPrefs[player->GetGUID()];
        prefs.smartLootEnabled = !prefs.smartLootEnabled;

        handler->PSendSysMessage("|cff00ff00[Loot Prefs]|r Smart Loot: %s",
                                  prefs.smartLootEnabled ? "Enabled" : "Disabled");
        return true;
    }

    static bool HandleLootSmartSet(ChatHandler* handler, bool enable)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return true;

        PlayerLootPreferences& prefs = sPlayerPrefs[player->GetGUID()];
        prefs.smartLootEnabled = enable;

        handler->PSendSysMessage("|cff00ff00[Loot Prefs]|r Smart Loot: %s",
                                  prefs.smartLootEnabled ? "Enabled" : "Disabled");
        return true;
    }

    static bool HandleLootIgnore(ChatHandler* handler, uint32 itemId)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return true;

        ItemTemplate const* proto = sObjectMgr->GetItemTemplate(itemId);
        if (!proto)
        {
            handler->SendSysMessage("Invalid item ID.");
            return true;
        }

        PlayerLootPreferences& prefs = sPlayerPrefs[player->GetGUID()];
        prefs.ignoredItemIds.insert(itemId);

        handler->PSendSysMessage("|cff00ff00[Loot Prefs]|r Now ignoring: [%s]", proto->Name1.c_str());
        return true;
    }

    static bool HandleLootUnignore(ChatHandler* handler, uint32 itemId)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return true;

        PlayerLootPreferences& prefs = sPlayerPrefs[player->GetGUID()];
        prefs.ignoredItemIds.erase(itemId);

        handler->PSendSysMessage("|cff00ff00[Loot Prefs]|r Removed from ignore list: %u", itemId);
        return true;
    }

    static bool HandleLootStats(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return true;

        // Always show current preferences
        PlayerLootPreferences& prefs = sPlayerPrefs[player->GetGUID()];
        const char* qualityNames[] = { "Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Artifact" };

        handler->SendSysMessage("|cff00ff00========== CURRENT SETTINGS ==========|r");
        handler->SendSysMessage(Acore::StringFormat("|cffffd700AoE Loot:|r {}", prefs.aoeLootEnabled ? "Enabled" : "Disabled").c_str());
        handler->SendSysMessage(Acore::StringFormat("|cffffd700Show Messages:|r {}", prefs.showMessages ? "Enabled" : "Disabled").c_str());
        handler->SendSysMessage(Acore::StringFormat("|cffffd700Minimum Quality:|r {}", qualityNames[prefs.minQuality]).c_str());
        handler->SendSysMessage(Acore::StringFormat("|cffffd700Auto-Skin:|r {}", prefs.autoSkin ? "Enabled" : "Disabled").c_str());
        handler->SendSysMessage(Acore::StringFormat("|cffffd700Smart Loot:|r {}", prefs.smartLootEnabled ? "Enabled" : "Disabled").c_str());
        handler->SendSysMessage("|cff00ff00======================================|r");

        auto it = sDetailedStats.find(player->GetGUID());
        if (it == sDetailedStats.end())
        {
            handler->SendSysMessage("|cffffd700[Loot Stats]|r No loot statistics recorded yet (start looting to track).");
            return true;
        }

        DetailedLootStats& stats = it->second;

        handler->SendSysMessage("|cff00ff00========== LOOT STATISTICS ==========|r");
        handler->SendSysMessage(Acore::StringFormat("|cffffd700Total Items Looted:|r {}", stats.totalItemsLooted).c_str());
        handler->SendSysMessage(Acore::StringFormat("|cffffd700Total Gold Looted:|r {}g {}s {}c",
                                  stats.totalGoldLooted / 10000,
                                  (stats.totalGoldLooted % 10000) / 100,
                                  stats.totalGoldLooted % 100).c_str());
        handler->SendSysMessage(Acore::StringFormat("|cffffd700Poor Items Vendored:|r {}", stats.poorItemsVendored).c_str());
        handler->SendSysMessage(Acore::StringFormat("|cffffd700Gold from Vendor:|r {}g {}s {}c",
                                  stats.goldFromVendor / 10000,
                                  (stats.goldFromVendor % 10000) / 100,
                                  stats.goldFromVendor % 100).c_str());
        handler->SendSysMessage(Acore::StringFormat("|cffffd700Corpses Skinned:|r {}", stats.skinnedCorpses).c_str());
        handler->SendSysMessage(Acore::StringFormat("|cffffd700Nodes Mined:|r {}", stats.minedNodes).c_str());
        handler->SendSysMessage(Acore::StringFormat("|cffffd700Nodes Herbed:|r {}", stats.herbedNodes).c_str());
        handler->SendSysMessage(Acore::StringFormat("|cffffd700Upgrades Found:|r {}", stats.upgradesFound).c_str());
        handler->SendSysMessage("|cff00ff00======================================|r");

        return true;
    }

    static bool HandleLootReload(ChatHandler* handler)
    {
        sConfig.Load();
        handler->SendSysMessage("AoE Loot Extensions configuration reloaded.");
        return true;
    }
};

// ============================================================
// World Script - Initialization
// ============================================================
class DCAoELootExtWorldScript : public WorldScript
{
public:
    DCAoELootExtWorldScript() : WorldScript("DCAoELootExtWorldScript") { }

    void OnStartup() override
    {
        sConfig.Load();
        LOG_INFO("scripts", "DarkChaos AoE Loot Extensions initialized (Enabled: {})", 
                 sConfig.enabled ? "Yes" : "No");
    }
};

void AddSC_dc_aoeloot_extensions()
{
    sConfig.Load();
    new DCAoELootExtPlayerScript();
    new DCAoELootExtCommandScript();
    new DCAoELootExtWorldScript();
}
