/*
 * Dark Chaos - AOE Loot Addon Module Handler
 * ===========================================
 *
 * Handles DC|AOE|... messages for AOE loot settings sync.
 * Integrates with dc_aoeloot_extensions.cpp
 *
 * Copyright (C) 2024 Dark Chaos Development Team
 */

#include "dc_addon_namespace.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "DatabaseEnv.h"
#include "Config.h"
#include "Log.h"
#include "Chat.h"
#include "StringFormat.h"
#include <algorithm>
#include <cctype>
#include <mutex>
#include <sstream>

// Forward declaration from dc_aoeloot_extensions.cpp to get live in-memory stats
namespace DCAoELootExt
{
    void GetDetailedStats(ObjectGuid playerGuid, uint32& itemsLooted, uint32& goldLooted, uint32& upgradesFound);
    bool GetPlayerShowMessages(ObjectGuid playerGuid);
    bool IsPlayerAoELootEnabled(ObjectGuid playerGuid);
    uint8 GetPlayerMinQuality(ObjectGuid playerGuid);
    bool GetPlayerAutoSkin(ObjectGuid playerGuid);
    bool GetPlayerSmartLoot(ObjectGuid playerGuid);
    bool GetPlayerAutoVendorPoor(ObjectGuid playerGuid);
    bool GetPlayerGoldOnly(ObjectGuid playerGuid);
    float GetPlayerLootRange(ObjectGuid playerGuid);
    uint32 GetPlayerIgnoredCount(ObjectGuid playerGuid);
    void GetQualityStats(ObjectGuid playerGuid,
                         uint32& poor, uint32& common, uint32& uncommon,
                         uint32& rare, uint32& epic, uint32& legendary,
                         uint32& filtPoor, uint32& filtCommon, uint32& filtUncommon,
                         uint32& filtRare, uint32& filtEpic, uint32& filtLegendary);

    // In-memory preference setters (for real-time updates)
    void SetPlayerMinQuality(ObjectGuid playerGuid, uint8 quality);
    void SetPlayerAoELootEnabled(ObjectGuid playerGuid, bool enabled);
    void SetPlayerShowMessages(ObjectGuid playerGuid, bool value);
    void SetPlayerAutoSkin(ObjectGuid playerGuid, bool value);
    void SetPlayerSmartLoot(ObjectGuid playerGuid, bool value);
    void SetPlayerAutoVendorPoor(ObjectGuid playerGuid, bool value);
    void SetPlayerGoldOnly(ObjectGuid playerGuid, bool value);
    void SetPlayerLootRange(ObjectGuid playerGuid, float value);
    void TogglePlayerIgnoredItem(ObjectGuid playerGuid, uint32 itemId);
}

namespace DCAddon
{
namespace AOELoot
{
    // Player settings storage (in-memory cache, synced to DB)
    struct PlayerAOESettings
    {
        bool enabled = true;
        bool showMessages = true;
        uint8 minQuality = 0;
        bool autoSkin = false;
        bool smartLoot = true;
        bool autoVendorPoor = false;
        bool goldOnly = false;
        float lootRange = 30.0f;
    };

    static std::unordered_map<uint32, PlayerAOESettings> s_PlayerSettings;
    static std::mutex s_SettingsMutex;  // Thread safety for settings access

    struct PreferenceSchemaInfo
    {
        bool initialized = false;
        bool hasShowMessages = false;
        bool hasAutoVendorPoor = false;
        bool hasGoldOnly = false;
        bool hasLootRange = false;
    };

    static PreferenceSchemaInfo s_PreferenceSchema;

    static std::string JoinStringList(std::vector<std::string> const& values, char const* separator = ", ")
    {
        std::ostringstream ss;
        for (size_t i = 0; i < values.size(); ++i)
        {
            if (i > 0)
                ss << separator;
            ss << values[i];
        }
        return ss.str();
    }

    static PreferenceSchemaInfo const& GetPreferenceSchemaInfo()
    {
        if (s_PreferenceSchema.initialized)
            return s_PreferenceSchema;

        s_PreferenceSchema.initialized = true;

        QueryResult result = CharacterDatabase.Query(
            "SELECT COLUMN_NAME FROM information_schema.COLUMNS "
            "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dc_aoeloot_preferences'");

        if (!result)
        {
            LOG_WARN("dc.addon.aoe", "Could not inspect dc_aoeloot_preferences schema. Using base-column fallback.");
            return s_PreferenceSchema;
        }

        do
        {
            std::string const column = (*result)[0].Get<std::string>();
            if (column == "show_messages")
                s_PreferenceSchema.hasShowMessages = true;
            else if (column == "auto_vendor_poor")
                s_PreferenceSchema.hasAutoVendorPoor = true;
            else if (column == "gold_only")
                s_PreferenceSchema.hasGoldOnly = true;
            else if (column == "loot_range")
                s_PreferenceSchema.hasLootRange = true;
        } while (result->NextRow());

        LOG_INFO("dc.addon.aoe", "AOE addon schema: show_messages={}, auto_vendor_poor={}, gold_only={}, loot_range={}",
            s_PreferenceSchema.hasShowMessages ? "yes" : "no",
            s_PreferenceSchema.hasAutoVendorPoor ? "yes" : "no",
            s_PreferenceSchema.hasGoldOnly ? "yes" : "no",
            s_PreferenceSchema.hasLootRange ? "yes" : "no");

        return s_PreferenceSchema;
    }

    static bool JsonGetBool(const JsonValue& json, const std::string& key, bool defaultValue = false)
    {
        JsonValue const& value = json[key];
        if (value.IsBool())
            return value.AsBool();
        if (value.IsNumber())
            return value.AsInt32() != 0;
        if (value.IsString())
        {
            std::string lower = value.AsString();
            std::transform(lower.begin(), lower.end(), lower.begin(),
                [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
            return lower == "1" || lower == "true" || lower == "yes" || lower == "on";
        }
        return defaultValue;
    }

    static uint32 JsonGetUInt(const JsonValue& json, const std::string& key, uint32 defaultValue = 0)
    {
        JsonValue const& value = json[key];
        if (value.IsNumber())
            return value.AsUInt32();
        if (value.IsString())
        {
            try
            {
                return static_cast<uint32>(std::stoul(value.AsString()));
            }
            catch (...)
            {
                return defaultValue;
            }
        }
        return defaultValue;
    }

    static float JsonGetFloat(const JsonValue& json, const std::string& key, float defaultValue = 0.0f)
    {
        JsonValue const& value = json[key];
        if (value.IsNumber())
            return static_cast<float>(value.AsNumber());
        if (value.IsString())
        {
            try
            {
                return std::stof(value.AsString());
            }
            catch (...)
            {
                return defaultValue;
            }
        }
        return defaultValue;
    }

    // Load settings from DB for player
    // Uses dc_aoeloot_preferences (same table as dc_aoeloot_extensions.cpp)
    static void LoadPlayerSettings(Player* player)
    {
        uint32 guid = player->GetGUID().GetCounter();

        PlayerAOESettings settings;
        settings.enabled = DCAoELootExt::IsPlayerAoELootEnabled(player->GetGUID());
        settings.showMessages = DCAoELootExt::GetPlayerShowMessages(player->GetGUID());
        settings.minQuality = DCAoELootExt::GetPlayerMinQuality(player->GetGUID());
        settings.autoSkin = DCAoELootExt::GetPlayerAutoSkin(player->GetGUID());
        settings.smartLoot = DCAoELootExt::GetPlayerSmartLoot(player->GetGUID());
        settings.autoVendorPoor = DCAoELootExt::GetPlayerAutoVendorPoor(player->GetGUID());
        settings.goldOnly = DCAoELootExt::GetPlayerGoldOnly(player->GetGUID());
        settings.lootRange = DCAoELootExt::GetPlayerLootRange(player->GetGUID());

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
        if (schema.hasGoldOnly)
            columns.push_back("gold_only");
        if (schema.hasLootRange)
            columns.push_back("loot_range");

        std::string query = Acore::StringFormat(
            "SELECT {} FROM dc_aoeloot_preferences WHERE player_guid = {}",
            JoinStringList(columns), guid);

        QueryResult result = CharacterDatabase.Query(query);
        if (result)
        {
            Field* fields = result->Fetch();
            uint8 idx = 0;
            settings.enabled = fields[idx++].Get<bool>();
            settings.minQuality = fields[idx++].Get<uint8>();
            settings.autoSkin = fields[idx++].Get<bool>();
            settings.smartLoot = fields[idx++].Get<bool>();

            if (schema.hasShowMessages)
                settings.showMessages = fields[idx++].Get<bool>();

            if (schema.hasAutoVendorPoor)
                settings.autoVendorPoor = fields[idx++].Get<bool>();

            if (schema.hasGoldOnly)
                settings.goldOnly = fields[idx++].Get<bool>();

            if (schema.hasLootRange)
            {
                settings.lootRange = fields[idx++].Get<float>();
                if (settings.lootRange < 5.0f || settings.lootRange > 100.0f)
                    settings.lootRange = DCAoELootExt::GetPlayerLootRange(player->GetGUID());
            }
        }

        DCAoELootExt::SetPlayerAoELootEnabled(player->GetGUID(), settings.enabled);
        DCAoELootExt::SetPlayerShowMessages(player->GetGUID(), settings.showMessages);
        DCAoELootExt::SetPlayerMinQuality(player->GetGUID(), settings.minQuality);
        DCAoELootExt::SetPlayerAutoSkin(player->GetGUID(), settings.autoSkin);
        DCAoELootExt::SetPlayerSmartLoot(player->GetGUID(), settings.smartLoot);
        DCAoELootExt::SetPlayerAutoVendorPoor(player->GetGUID(), settings.autoVendorPoor);
        DCAoELootExt::SetPlayerGoldOnly(player->GetGUID(), settings.goldOnly);
        DCAoELootExt::SetPlayerLootRange(player->GetGUID(), settings.lootRange);

        std::lock_guard<std::mutex> lock(s_SettingsMutex);
        s_PlayerSettings[guid] = settings;
    }

    // Save settings to DB
    // Uses dc_aoeloot_preferences (same table as dc_aoeloot_extensions.cpp)
    static void SavePlayerSettings(Player* player)
    {
        uint32 guid = player->GetGUID().GetCounter();
        PlayerAOESettings snapshot;
        {
            std::lock_guard<std::mutex> lock(s_SettingsMutex);
            auto it = s_PlayerSettings.find(guid);
            if (it == s_PlayerSettings.end())
                return;
            snapshot = it->second;
        }

        snapshot.enabled = DCAoELootExt::IsPlayerAoELootEnabled(player->GetGUID());
        snapshot.showMessages = DCAoELootExt::GetPlayerShowMessages(player->GetGUID());
        snapshot.minQuality = DCAoELootExt::GetPlayerMinQuality(player->GetGUID());
        snapshot.autoSkin = DCAoELootExt::GetPlayerAutoSkin(player->GetGUID());
        snapshot.smartLoot = DCAoELootExt::GetPlayerSmartLoot(player->GetGUID());
        snapshot.autoVendorPoor = DCAoELootExt::GetPlayerAutoVendorPoor(player->GetGUID());
        snapshot.goldOnly = DCAoELootExt::GetPlayerGoldOnly(player->GetGUID());
        snapshot.lootRange = DCAoELootExt::GetPlayerLootRange(player->GetGUID());

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
            std::to_string(guid),
            snapshot.enabled ? "1" : "0",
            std::to_string(snapshot.minQuality),
            snapshot.autoSkin ? "1" : "0",
            snapshot.smartLoot ? "1" : "0"
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
            values.push_back(snapshot.showMessages ? "1" : "0");
            updates.push_back("show_messages = VALUES(show_messages)");
        }

        if (schema.hasAutoVendorPoor)
        {
            columns.push_back("auto_vendor_poor");
            values.push_back(snapshot.autoVendorPoor ? "1" : "0");
            updates.push_back("auto_vendor_poor = VALUES(auto_vendor_poor)");
        }

        if (schema.hasGoldOnly)
        {
            columns.push_back("gold_only");
            values.push_back(snapshot.goldOnly ? "1" : "0");
            updates.push_back("gold_only = VALUES(gold_only)");
        }

        if (schema.hasLootRange)
        {
            float persistedRange = snapshot.lootRange;
            if (persistedRange < 5.0f || persistedRange > 100.0f)
                persistedRange = DCAoELootExt::GetPlayerLootRange(player->GetGUID());

            columns.push_back("loot_range");
            values.push_back(Acore::StringFormat("{}", persistedRange));
            updates.push_back("loot_range = VALUES(loot_range)");
        }

        CharacterDatabase.Execute(Acore::StringFormat(
            "INSERT INTO dc_aoeloot_preferences ({}) VALUES ({}) ON DUPLICATE KEY UPDATE {}",
            JoinStringList(columns), JoinStringList(values), JoinStringList(updates)));
    }

    // Get player stats - uses live in-memory stats from dc_aoeloot_extensions first,
    // falls back to DB for persisted data (e.g. from previous sessions)
    static void GetPlayerStats(Player* player, uint32& itemsLooted, uint32& goldLooted, uint32& skinned)
    {
        // First try to get live in-memory stats (updated in real-time by ac_aoeloot.cpp)
        uint32 memItems = 0, memGold = 0, memUpgrades = 0;
        DCAoELootExt::GetDetailedStats(player->GetGUID(), memItems, memGold, memUpgrades);

        // If we have in-memory stats, use them directly
        if (memItems > 0 || memGold > 0)
        {
            itemsLooted = memItems;
            goldLooted = memGold;
            skinned = memUpgrades; // upgradesFound maps to skinned in legacy schema
            return;
        }

        // Fall back to database for previous session data
        uint32 guid = player->GetGUID().GetCounter();
        QueryResult result = CharacterDatabase.Query(
            "SELECT COALESCE(total_items, 0), COALESCE(total_gold, 0), "
            "COALESCE(skinned, 0) FROM dc_aoeloot_detailed_stats WHERE player_guid = {}", guid);

        if (result)
        {
            Field* fields = result->Fetch();
            itemsLooted = fields[0].Get<uint32>();
            goldLooted = fields[1].Get<uint32>();
            skinned = fields[2].Get<uint32>();
        }
        else
        {
            itemsLooted = 0;
            goldLooted = 0;
            skinned = 0;
        }
    }

    // Send current settings to client
    static void SendSettingsSync(Player* player)
    {
        uint32 guid = player->GetGUID().GetCounter();
        PlayerAOESettings snapshot;
        bool needsLoad = false;
        {
            std::lock_guard<std::mutex> lock(s_SettingsMutex);
            auto it = s_PlayerSettings.find(guid);
            if (it == s_PlayerSettings.end())
                needsLoad = true;
            else
                snapshot = it->second;
        }

        if (needsLoad)
        {
            LoadPlayerSettings(player);
            std::lock_guard<std::mutex> lock(s_SettingsMutex);
            auto it = s_PlayerSettings.find(guid);
            if (it == s_PlayerSettings.end())
                return;
            snapshot = it->second;
        }

        snapshot.enabled = DCAoELootExt::IsPlayerAoELootEnabled(player->GetGUID());
        snapshot.showMessages = DCAoELootExt::GetPlayerShowMessages(player->GetGUID());
        snapshot.minQuality = DCAoELootExt::GetPlayerMinQuality(player->GetGUID());
        snapshot.autoSkin = DCAoELootExt::GetPlayerAutoSkin(player->GetGUID());
        snapshot.smartLoot = DCAoELootExt::GetPlayerSmartLoot(player->GetGUID());
        snapshot.autoVendorPoor = DCAoELootExt::GetPlayerAutoVendorPoor(player->GetGUID());
        snapshot.goldOnly = DCAoELootExt::GetPlayerGoldOnly(player->GetGUID());
        snapshot.lootRange = DCAoELootExt::GetPlayerLootRange(player->GetGUID());

        {
            std::lock_guard<std::mutex> lock(s_SettingsMutex);
            s_PlayerSettings[guid] = snapshot;
        }

        Message(Module::AOE_LOOT, Opcode::AOE::SMSG_SETTINGS_SYNC)
                .Add(snapshot.enabled)
                .Add(snapshot.showMessages)
                .Add(snapshot.minQuality)
                .Add(snapshot.autoSkin)
                .Add(snapshot.smartLoot)
                .Add(snapshot.autoVendorPoor)
                .Add(snapshot.goldOnly)
                .Add(snapshot.lootRange)
            .Send(player);
    }

    static bool GetRequestBool(const ParsedMessage& msg, const std::string& key, bool defaultValue = false)
    {
        if (IsJsonMessage(msg))
            return JsonGetBool(GetJsonData(msg), key, defaultValue);
        return msg.GetDataCount() > 0 ? msg.GetBool(0) : defaultValue;
    }

    static uint32 GetRequestUInt(const ParsedMessage& msg, const std::string& key, uint32 defaultValue = 0)
    {
        if (IsJsonMessage(msg))
            return JsonGetUInt(GetJsonData(msg), key, defaultValue);
        return msg.GetDataCount() > 0 ? msg.GetUInt32(0) : defaultValue;
    }

    static float GetRequestFloat(const ParsedMessage& msg, const std::string& key, float defaultValue = 0.0f)
    {
        if (IsJsonMessage(msg))
            return JsonGetFloat(GetJsonData(msg), key, defaultValue);
        return msg.GetDataCount() > 0 ? msg.GetFloat(0) : defaultValue;
    }

    // Handler: Toggle AOE loot enabled
    static void HandleToggleEnabled(Player* player, const ParsedMessage& msg)
    {
        uint32 guid = player->GetGUID().GetCounter();
        bool enabled = GetRequestBool(msg, "enabled", true);

        {
            std::lock_guard<std::mutex> lock(s_SettingsMutex);
            s_PlayerSettings[guid].enabled = enabled;
        }

        // Update in-memory prefs used by ac_aoeloot.cpp (critical for real-time effect)
        DCAoELootExt::SetPlayerAoELootEnabled(player->GetGUID(), enabled);

        SavePlayerSettings(player);
        SendSettingsSync(player);

        LOG_DEBUG("dc.addon.aoe", "Player {} {} AOE loot", player->GetName(), enabled ? "enabled" : "disabled");
    }

    // Handler: Set quality filter
    static void HandleSetQuality(Player* player, const ParsedMessage& msg)
    {
        uint32 guid = player->GetGUID().GetCounter();
        uint32 qualityValue = GetRequestUInt(msg, "quality", 0);
        if (IsJsonMessage(msg))
        {
            JsonValue json = GetJsonData(msg);
            if (!json["quality"].IsNumber())
                qualityValue = JsonGetUInt(json, "minQuality", qualityValue);
        }

        uint8 quality = static_cast<uint8>(qualityValue);
        if (quality > 6) quality = 0;

        {
            std::lock_guard<std::mutex> lock(s_SettingsMutex);
            s_PlayerSettings[guid].minQuality = quality;
        }

        // Update in-memory prefs used by ac_aoeloot.cpp (critical for real-time effect)
        DCAoELootExt::SetPlayerMinQuality(player->GetGUID(), quality);

        SavePlayerSettings(player);
        SendSettingsSync(player);

        LOG_DEBUG("dc.addon.aoe", "Player {} set min quality to {}", player->GetName(), quality);
    }

    // Handler: Get loot stats
    static void HandleGetStats(Player* player, const ParsedMessage& /*msg*/)
    {
        uint32 items, gold, skinned;
        GetPlayerStats(player, items, gold, skinned);

        Message(Module::AOE_LOOT, Opcode::AOE::SMSG_STATS)
            .Add(items)
            .Add(gold)
            .Add(skinned)
            .Send(player);
    }

    // Handler: Set auto-skin
    static void HandleSetAutoSkin(Player* player, const ParsedMessage& msg)
    {
        uint32 guid = player->GetGUID().GetCounter();
        bool enabled = GetRequestBool(msg, "enabled", false);

        {
            std::lock_guard<std::mutex> lock(s_SettingsMutex);
            s_PlayerSettings[guid].autoSkin = enabled;
        }

        DCAoELootExt::SetPlayerAutoSkin(player->GetGUID(), enabled);
        SavePlayerSettings(player);
        SendSettingsSync(player);

        LOG_DEBUG("dc.addon.aoe", "Player {} {} auto-skin", player->GetName(), enabled ? "enabled" : "disabled");
    }

    // Handler: Set loot range
    static void HandleSetRange(Player* player, const ParsedMessage& msg)
    {
        uint32 guid = player->GetGUID().GetCounter();
        float range = GetRequestFloat(msg, "range", 30.0f);
        if (range < 5.0f) range = 5.0f;
        if (range > 100.0f) range = 100.0f;

        {
            std::lock_guard<std::mutex> lock(s_SettingsMutex);
            s_PlayerSettings[guid].lootRange = range;
        }

        DCAoELootExt::SetPlayerLootRange(player->GetGUID(), range);
        SavePlayerSettings(player);
        SendSettingsSync(player);

        LOG_DEBUG("dc.addon.aoe", "Player {} set loot range to {}", player->GetName(), range);
    }

    // Handler: Toggle ignored item filter
    static void HandleIgnoreItem(Player* player, const ParsedMessage& msg)
    {
        uint32 itemId = GetRequestUInt(msg, "itemId", 0);
        if (itemId == 0)
        {
            LOG_DEBUG("dc.addon.aoe", "Player {} sent invalid ignore item id", player->GetName());
            return;
        }

        DCAoELootExt::TogglePlayerIgnoredItem(player->GetGUID(), itemId);
        SendSettingsSync(player);

        LOG_DEBUG("dc.addon.aoe", "Player {} toggled ignored item {}", player->GetName(), itemId);
    }

    // Handler: Get settings
    static void HandleGetSettings(Player* player, const ParsedMessage& /*msg*/)
    {
        SendSettingsSync(player);
    }

    // Handler: Get quality breakdown stats
    static void HandleGetQualityStats(Player* player, const ParsedMessage& /*msg*/)
    {
        uint32 poor, common, uncommon, rare, epic, legendary;
        uint32 filtPoor, filtCommon, filtUncommon, filtRare, filtEpic, filtLegendary;

        DCAoELootExt::GetQualityStats(player->GetGUID(),
            poor, common, uncommon, rare, epic, legendary,
            filtPoor, filtCommon, filtUncommon, filtRare, filtEpic, filtLegendary);

        // Send quality breakdown: looted counts then filtered counts
        Message(Module::AOE_LOOT, Opcode::AOE::SMSG_QUALITY_STATS)
            .Add(poor)
            .Add(common)
            .Add(uncommon)
            .Add(rare)
            .Add(epic)
            .Add(legendary)
            .Add(filtPoor)
            .Add(filtCommon)
            .Add(filtUncommon)
            .Add(filtRare)
            .Add(filtEpic)
            .Add(filtLegendary)
            .Send(player);

        LOG_DEBUG("dc.addon.aoe", "Player {} quality stats: Poor:{} Common:{} Uncommon:{} Rare:{} Epic:{} Legendary:{}",
            player->GetName(), poor, common, uncommon, rare, epic, legendary);
    }

    // Register all handlers
    void RegisterHandlers()
    {
        DC_REGISTER_HANDLER(Module::AOE_LOOT, Opcode::AOE::CMSG_TOGGLE_ENABLED, HandleToggleEnabled);
        DC_REGISTER_HANDLER(Module::AOE_LOOT, Opcode::AOE::CMSG_SET_QUALITY, HandleSetQuality);
        DC_REGISTER_HANDLER(Module::AOE_LOOT, Opcode::AOE::CMSG_GET_STATS, HandleGetStats);
        DC_REGISTER_HANDLER(Module::AOE_LOOT, Opcode::AOE::CMSG_SET_AUTO_SKIN, HandleSetAutoSkin);
        DC_REGISTER_HANDLER(Module::AOE_LOOT, Opcode::AOE::CMSG_SET_RANGE, HandleSetRange);
        DC_REGISTER_HANDLER(Module::AOE_LOOT, Opcode::AOE::CMSG_GET_SETTINGS, HandleGetSettings);
        DC_REGISTER_HANDLER(Module::AOE_LOOT, Opcode::AOE::CMSG_IGNORE_ITEM, HandleIgnoreItem);
        DC_REGISTER_HANDLER(Module::AOE_LOOT, Opcode::AOE::CMSG_GET_QUALITY_STATS, HandleGetQualityStats);

        LOG_INFO("dc.addon", "AOE Loot module handlers registered");
    }

    // Player login hook - load settings and send sync
    void OnPlayerLogin(Player* player)
    {
        if (!MessageRouter::Instance().IsModuleEnabled(Module::AOE_LOOT))
            return;

        LoadPlayerSettings(player);
        SendSettingsSync(player);
    }

    // Player logout hook - cleanup
    void OnPlayerLogout(Player* player)
    {
        uint32 guid = player->GetGUID().GetCounter();
        std::lock_guard<std::mutex> lock(s_SettingsMutex);
        s_PlayerSettings.erase(guid);
    }

    // Public API for other scripts to query settings
    bool IsEnabledForPlayer(Player* player)
    {
        uint32 guid = player->GetGUID().GetCounter();
        std::lock_guard<std::mutex> lock(s_SettingsMutex);
        auto it = s_PlayerSettings.find(guid);
        return (it != s_PlayerSettings.end()) ? it->second.enabled : true;
    }

    float GetLootRangeForPlayer(Player* player)
    {
        uint32 guid = player->GetGUID().GetCounter();
        std::lock_guard<std::mutex> lock(s_SettingsMutex);
        auto it = s_PlayerSettings.find(guid);
        return (it != s_PlayerSettings.end()) ? it->second.lootRange : 30.0f;
    }

    uint8 GetMinQualityForPlayer(Player* player)
    {
        uint32 guid = player->GetGUID().GetCounter();
        std::lock_guard<std::mutex> lock(s_SettingsMutex);
        auto it = s_PlayerSettings.find(guid);
        return (it != s_PlayerSettings.end()) ? it->second.minQuality : 0;
    }

}  // namespace AOELoot
}  // namespace DCAddon

// Script class for player hooks
class DCAddonAOELootScript : public PlayerScript
{
public:
    DCAddonAOELootScript() : PlayerScript("DCAddonAOELootScript") {}

    void OnPlayerLogin(Player* player) override
    {
        DCAddon::AOELoot::OnPlayerLogin(player);
    }

    void OnPlayerLogout(Player* player) override
    {
        DCAddon::AOELoot::OnPlayerLogout(player);
    }
};

void AddSC_dc_addon_aoeloot()
{
    DCAddon::AOELoot::RegisterHandlers();
    new DCAddonAOELootScript();
}
