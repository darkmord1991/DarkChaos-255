/*
 * Dark Chaos - AOE Loot Addon Module Handler
 * ===========================================
 * 
 * Handles DC|AOE|... messages for AOE loot settings sync.
 * Integrates with dc_aoeloot_extensions.cpp
 * 
 * Copyright (C) 2024 Dark Chaos Development Team
 */

#include "DCAddonNamespace.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "DatabaseEnv.h"
#include "Config.h"
#include "Log.h"
#include "Chat.h"

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
        float lootRange = 30.0f;
    };
    
    static std::unordered_map<uint32, PlayerAOESettings> s_PlayerSettings;
    
    // Load settings from DB for player
    static void LoadPlayerSettings(Player* player)
    {
        uint32 guid = player->GetGUID().GetCounter();
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT enabled, show_messages, min_quality, auto_skin, smart_loot, loot_range "
            "FROM dc_aoe_loot_settings WHERE character_guid = {}", guid);
        
        PlayerAOESettings settings;
        if (result)
        {
            Field* fields = result->Fetch();
            settings.enabled = fields[0].Get<bool>();
            settings.showMessages = fields[1].Get<bool>();
            settings.minQuality = fields[2].Get<uint8>();
            settings.autoSkin = fields[3].Get<bool>();
            settings.smartLoot = fields[4].Get<bool>();
            settings.lootRange = fields[5].Get<float>();
        }
        
        s_PlayerSettings[guid] = settings;
    }
    
    // Save settings to DB
    static void SavePlayerSettings(Player* player)
    {
        uint32 guid = player->GetGUID().GetCounter();
        auto it = s_PlayerSettings.find(guid);
        if (it == s_PlayerSettings.end())
            return;
        
        const auto& s = it->second;
        CharacterDatabase.Execute(
            "REPLACE INTO dc_aoe_loot_settings "
            "(character_guid, enabled, show_messages, min_quality, auto_skin, smart_loot, loot_range) "
            "VALUES ({}, {}, {}, {}, {}, {}, {})",
            guid, s.enabled ? 1 : 0, s.showMessages ? 1 : 0, s.minQuality,
            s.autoSkin ? 1 : 0, s.smartLoot ? 1 : 0, s.lootRange);
    }
    
    // Get player stats from DB
    static void GetPlayerStats(Player* player, uint32& itemsLooted, uint32& goldLooted, uint32& skinned)
    {
        uint32 guid = player->GetGUID().GetCounter();
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT COALESCE(SUM(items_looted), 0), COALESCE(SUM(gold_looted), 0), "
            "COALESCE(SUM(creatures_skinned), 0) FROM dc_aoe_loot_stats WHERE character_guid = {}", guid);
        
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
        auto it = s_PlayerSettings.find(guid);
        if (it == s_PlayerSettings.end())
            LoadPlayerSettings(player);
        
        it = s_PlayerSettings.find(guid);
        if (it == s_PlayerSettings.end())
            return;
        
        const auto& s = it->second;
        
        Message(Module::AOE_LOOT, Opcode::AOE::SMSG_SETTINGS_SYNC)
            .Add(s.enabled)
            .Add(s.showMessages)
            .Add(s.minQuality)
            .Add(s.autoSkin)
            .Add(s.smartLoot)
            .Add(s.lootRange)
            .Send(player);
    }
    
    // Handler: Toggle AOE loot enabled
    static void HandleToggleEnabled(Player* player, const ParsedMessage& msg)
    {
        uint32 guid = player->GetGUID().GetCounter();
        bool enabled = msg.GetBool(0);
        
        s_PlayerSettings[guid].enabled = enabled;
        SavePlayerSettings(player);
        SendSettingsSync(player);
        
        LOG_DEBUG("dc.addon.aoe", "Player {} {} AOE loot", player->GetName(), enabled ? "enabled" : "disabled");
    }
    
    // Handler: Set quality filter
    static void HandleSetQuality(Player* player, const ParsedMessage& msg)
    {
        uint32 guid = player->GetGUID().GetCounter();
        uint8 quality = static_cast<uint8>(msg.GetUInt32(0));
        if (quality > 6) quality = 0;
        
        s_PlayerSettings[guid].minQuality = quality;
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
        bool enabled = msg.GetBool(0);
        
        s_PlayerSettings[guid].autoSkin = enabled;
        SavePlayerSettings(player);
        SendSettingsSync(player);
        
        LOG_DEBUG("dc.addon.aoe", "Player {} {} auto-skin", player->GetName(), enabled ? "enabled" : "disabled");
    }
    
    // Handler: Set loot range
    static void HandleSetRange(Player* player, const ParsedMessage& msg)
    {
        uint32 guid = player->GetGUID().GetCounter();
        float range = msg.GetFloat(0);
        if (range < 5.0f) range = 5.0f;
        if (range > 100.0f) range = 100.0f;
        
        s_PlayerSettings[guid].lootRange = range;
        SavePlayerSettings(player);
        SendSettingsSync(player);
        
        LOG_DEBUG("dc.addon.aoe", "Player {} set loot range to {}", player->GetName(), range);
    }
    
    // Handler: Get settings
    static void HandleGetSettings(Player* player, const ParsedMessage& /*msg*/)
    {
        SendSettingsSync(player);
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
        s_PlayerSettings.erase(guid);
    }
    
    // Public API for other scripts to query settings
    bool IsEnabledForPlayer(Player* player)
    {
        uint32 guid = player->GetGUID().GetCounter();
        auto it = s_PlayerSettings.find(guid);
        return (it != s_PlayerSettings.end()) ? it->second.enabled : true;
    }
    
    float GetLootRangeForPlayer(Player* player)
    {
        uint32 guid = player->GetGUID().GetCounter();
        auto it = s_PlayerSettings.find(guid);
        return (it != s_PlayerSettings.end()) ? it->second.lootRange : 30.0f;
    }
    
    uint8 GetMinQualityForPlayer(Player* player)
    {
        uint32 guid = player->GetGUID().GetCounter();
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
