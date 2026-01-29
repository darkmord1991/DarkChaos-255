/*
 * Dark Chaos - Prestige System Addon Handler
 * ============================================
 *
 * Server-side handler for the DC-Prestige addon module.
 * Provides prestige level information, stat bonuses, and progress data via DCAddonProtocol.
 *
 * Features:
 * - Player prestige level and progress info
 * - Stat bonus breakdown per prestige level
 * - Requirements to prestige
 * - Prestige level-up notifications
 *
 * Message Format:
 * - JSON format: PRES|OPCODE|J|{json}
 *
 * Opcodes (from DCAddonNamespace.h):
 * - CMSG: 0x01 (GET_INFO), 0x02 (GET_BONUSES)
 * - SMSG: 0x10 (INFO), 0x11 (BONUSES), 0x12 (LEVEL_UP)
 *
 * Integrates with dc_prestige_system.cpp for prestige data.
 *
 * Copyright (C) 2025 DarkChaos Development Team
 */

#include "dc_addon_namespace.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "Config.h"
#include "World.h"
#include "../Progression/Prestige/dc_prestige_api.h"

namespace DCPrestigeAddon
{
    // Module identifier - must match client-side and DCAddonNamespace.h
    constexpr const char* MODULE = "PRES";

    // Opcodes - match DCAddonNamespace.h Opcode::Prestige
    namespace Opcode
    {
        // Client -> Server
        constexpr uint8 CMSG_GET_INFO              = 0x01;  // Request prestige info
        constexpr uint8 CMSG_GET_BONUSES           = 0x02;  // Request stat bonuses breakdown

        // Server -> Client
        constexpr uint8 SMSG_INFO                  = 0x10;  // Prestige level info
        constexpr uint8 SMSG_BONUSES               = 0x11;  // Stat bonuses breakdown
        constexpr uint8 SMSG_LEVEL_UP              = 0x12;  // Notification: prestige level up
    }

    // Configuration
    namespace Config
    {
        constexpr const char* ENABLED = "DCPrestigeAddon.Enable";
    }

    // =======================================================================
    // Handler Functions
    // =======================================================================

    /**
     * Send player's prestige information
     * JSON Response:
     * {
     *   "enabled": bool,
     *   "prestigeLevel": uint32,
     *   "maxPrestigeLevel": uint32,
     *   "requiredLevel": uint32,
     *   "currentLevel": uint32,
     *   "canPrestige": bool,
     *   "statBonusPercent": uint32,
     *   "totalBonusPercent": uint32,
     *   "totalPrestiges": uint32,
     *   "lastPrestigeTime": uint32
     * }
     */
    void SendPrestigeInfo(Player* player)
    {
        if (!player || !player->GetSession())
            return;

        bool enabled = PrestigeAPI::IsEnabled();
        uint32 prestigeLevel = PrestigeAPI::GetPrestigeLevel(player);
        uint32 maxPrestigeLevel = PrestigeAPI::GetMaxPrestigeLevel();
        uint32 requiredLevel = PrestigeAPI::GetRequiredLevel();
        uint32 statBonusPercent = PrestigeAPI::GetStatBonusPercent();
        bool canPrestige = PrestigeAPI::CanPrestige(player);

        // Query additional info from database
        uint32 totalPrestiges = 0;
        uint64 lastPrestigeTime = 0;

        QueryResult result = CharacterDatabase.Query(
            "SELECT total_prestiges, last_prestige_time FROM dc_character_prestige WHERE guid = {}",
            player->GetGUID().GetCounter());

        if (result)
        {
            Field* fields = result->Fetch();
            totalPrestiges = fields[0].Get<uint32>();
            lastPrestigeTime = fields[1].Get<uint64>();
        }

        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_INFO);
        msg.Set("enabled", enabled);
        msg.Set("prestigeLevel", prestigeLevel);
        msg.Set("maxPrestigeLevel", maxPrestigeLevel);
        msg.Set("requiredLevel", requiredLevel);
        msg.Set("currentLevel", player->GetLevel());
        msg.Set("canPrestige", canPrestige);
        msg.Set("statBonusPercent", statBonusPercent);
        msg.Set("totalBonusPercent", prestigeLevel * statBonusPercent);
        msg.Set("totalPrestiges", totalPrestiges);
        msg.Set("lastPrestigeTime", static_cast<uint32>(lastPrestigeTime));

        msg.Send(player);
    }

    /**
     * Send stat bonuses breakdown
     * JSON Response:
     * {
     *   "prestigeLevel": uint32,
     *   "bonusPerLevel": uint32,
     *   "totalBonus": uint32,
     *   "bonuses": [
     *     { "level": 1, "bonus": 1, "cumulative": 1 },
     *     { "level": 2, "bonus": 1, "cumulative": 2 },
     *     ...
     *   ],
     *   "nextLevelBonus": uint32 (0 if at max)
     * }
     */
    void SendBonusesBreakdown(Player* player)
    {
        if (!player || !player->GetSession())
            return;

        uint32 prestigeLevel = PrestigeAPI::GetPrestigeLevel(player);
        uint32 maxPrestigeLevel = PrestigeAPI::GetMaxPrestigeLevel();
        uint32 bonusPerLevel = PrestigeAPI::GetStatBonusPercent();
        uint32 totalBonus = prestigeLevel * bonusPerLevel;

        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_BONUSES);
        msg.Set("prestigeLevel", prestigeLevel);
        msg.Set("bonusPerLevel", bonusPerLevel);
        msg.Set("totalBonus", totalBonus);

        // Build bonuses array
        std::string bonusesJson = "[";
        for (uint32 i = 1; i <= maxPrestigeLevel; ++i)
        {
            if (i > 1)
                bonusesJson += ",";

            char buf[128];
            std::snprintf(buf, sizeof(buf),
                "{\"level\":%u,\"bonus\":%u,\"cumulative\":%u,\"unlocked\":%s}",
                i, bonusPerLevel, i * bonusPerLevel, i <= prestigeLevel ? "true" : "false");
            bonusesJson += buf;
        }
        bonusesJson += "]";

        msg.Set("bonuses", bonusesJson);
        msg.Set("nextLevelBonus", prestigeLevel < maxPrestigeLevel ? (prestigeLevel + 1) * bonusPerLevel : 0);
        msg.Set("atMaxPrestige", prestigeLevel >= maxPrestigeLevel);

        msg.Send(player);
    }

    // =======================================================================
    // Message Handlers
    // =======================================================================

    void HandleGetInfo(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        if (!player)
            return;

        SendPrestigeInfo(player);
    }

    void HandleGetBonuses(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        if (!player)
            return;

        SendBonusesBreakdown(player);
    }

    // =======================================================================
    // Notification Helpers (can be called from prestige system)
    // =======================================================================

    /**
     * Notify addon client about a prestige level-up
     * Called from PrestigeSystem::PerformPrestige
     */
    void NotifyPrestigeLevelUp(Player* player, uint32 newLevel, uint32 totalBonus)
    {
        if (!player || !player->GetSession())
            return;

        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_LEVEL_UP);
        msg.Set("newLevel", newLevel);
        msg.Set("maxLevel", PrestigeAPI::GetMaxPrestigeLevel());
        msg.Set("totalBonus", totalBonus);
        msg.Set("bonusPerLevel", PrestigeAPI::GetStatBonusPercent());
        msg.Set("atMaxPrestige", newLevel >= PrestigeAPI::GetMaxPrestigeLevel());

        msg.Send(player);

        LOG_DEBUG("dc.addon", "DCPrestigeAddon: Sent prestige level-up notification to {} (level {})",
            player->GetName(), newLevel);
    }

} // namespace DCPrestigeAddon

// =======================================================================
// Script Registration
// =======================================================================

class DCPrestigeAddonWorldScript : public WorldScript
{
public:
    DCPrestigeAddonWorldScript() : WorldScript("DCPrestigeAddonWorldScript") { }

    void OnStartup() override
    {
        bool enabled = sConfigMgr->GetOption<bool>(DCPrestigeAddon::Config::ENABLED, true);

        if (enabled)
        {
            // Register message handlers
            auto& router = DCAddon::MessageRouter::Instance();

            router.RegisterHandler(DCPrestigeAddon::MODULE, DCPrestigeAddon::Opcode::CMSG_GET_INFO,
                DCPrestigeAddon::HandleGetInfo);

            router.RegisterHandler(DCPrestigeAddon::MODULE, DCPrestigeAddon::Opcode::CMSG_GET_BONUSES,
                DCPrestigeAddon::HandleGetBonuses);

            LOG_INFO("dc.addon", "DCPrestigeAddon: Prestige addon handler initialized");
        }
        else
        {
            LOG_INFO("dc.addon", "DCPrestigeAddon: Prestige addon handler disabled in config");
        }
    }
};

void AddSC_dc_addon_prestige()
{
    new DCPrestigeAddonWorldScript();
}
