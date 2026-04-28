/*
 * Dark Chaos - Quality of Service (QoS) Addon Handler
 * ====================================================
 *
 * Server-side handler for the DC-QoS addon.
 * Provides QoL feature settings sync and extended item/NPC information.
 *
 * Features:
 * - Settings synchronization between client and server
 * - Extended item information (custom DB data)
 * - Extended NPC information (DB GUID, spawn info)
 * - Extended spell information (custom modifications)
 * - Server-side feature notifications
 *
 * Message Format:
 * - JSON format: QOS|OPCODE|J|{json}
 * - Simple format: QOS|OPCODE|DATA1|DATA2|...
 *
 * Opcodes:
 * - CMSG: 0x01 (SYNC_SETTINGS), 0x02 (UPDATE_SETTING), 0x03 (GET_ITEM_INFO),
 *         0x04 (GET_NPC_INFO), 0x05 (GET_SPELL_INFO), 0x06 (REQUEST_FEATURE),
 *         0x08 (REQUEST_SPELL_TOOLTIP_ENRICHMENT)
 * - SMSG: 0x10 (SETTINGS_SYNC), 0x11 (SETTING_UPDATED), 0x12 (ITEM_INFO),
 *         0x13 (NPC_INFO), 0x14 (SPELL_INFO), 0x15 (FEATURE_DATA), 0x16 (NOTIFICATION),
 *         0x17 (SPELL_TOOLTIP_ENRICHMENT)
 *
 * Copyright (C) 2025 Dark Chaos Development Team
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "WorldSession.h"
#include "Chat.h"
#include "WorldPacket.h"
#include "DatabaseEnv.h"
#include "dc_addon_namespace.h"
#include "Config.h"
#include "Log.h"
#include "Creature.h"
#include "GameObject.h"
#include "ObjectMgr.h"
#include "SpellMgr.h"
#include "SpellInfo.h"
#include "ItemTemplate.h"
#include "Group.h"
#include <string>
#include <sstream>
#include <iomanip>
#include <algorithm>
#include <cctype>
#include <cmath>
#include <set>
#include "Mail.h"

namespace DCQoS
{
    // Module identifier - must match client-side Protocol.lua
    constexpr const char* MODULE = "QOS";

    // Opcodes - must match client-side Protocol.lua
    namespace Opcode
    {
        // Client -> Server
        constexpr uint8 CMSG_SYNC_SETTINGS      = 0x01;  // Request full settings sync
        constexpr uint8 CMSG_UPDATE_SETTING     = 0x02;  // Update a single setting
        constexpr uint8 CMSG_GET_ITEM_INFO      = 0x03;  // Request custom item info
        constexpr uint8 CMSG_GET_NPC_INFO       = 0x04;  // Request custom NPC info (DB GUID)
        constexpr uint8 CMSG_GET_SPELL_INFO     = 0x05;  // Request custom spell info
        constexpr uint8 CMSG_REQUEST_FEATURE    = 0x06;  // Request specific feature data
        constexpr uint8 CMSG_COLLECT_ALL_MAIL   = 0x07;  // Request to collect all mail
        constexpr uint8 CMSG_REQUEST_SPELL_TOOLTIP_ENRICHMENT = 0x08;  // Request server-enriched spell tooltip line

        // Server -> Client
        constexpr uint8 SMSG_SETTINGS_SYNC      = 0x10;  // Full settings sync
        constexpr uint8 SMSG_SETTING_UPDATED    = 0x11;  // Confirmation of setting update
        constexpr uint8 SMSG_ITEM_INFO          = 0x12;  // Custom item information
        constexpr uint8 SMSG_NPC_INFO           = 0x13;  // Custom NPC information
        constexpr uint8 SMSG_SPELL_INFO         = 0x14;  // Custom spell information
        constexpr uint8 SMSG_FEATURE_DATA       = 0x15;  // Feature-specific data
        constexpr uint8 SMSG_NOTIFICATION       = 0x16;  // Server notification
        constexpr uint8 SMSG_SPELL_TOOLTIP_ENRICHMENT = 0x17;  // requestId|spellId|contextHash|status|line
    }

    // Bridge reference to the custom client packet opcodes used by WotLK-Extensions.
    // AddonProtocol transport stays MODULE+uint8 opcode based, but payload fields are aligned.
    namespace BridgeOpcode
    {
        enum : uint16
        {
            CMSG_REQUEST_SPELL_TOOLTIP_ENRICHMENT = 1313,
            SMSG_SPELL_TOOLTIP_ENRICHMENT = 1314,
        };
    }

    // Configuration keys
    namespace Config
    {
        constexpr const char* ENABLED = "DC.AddonProtocol.QoS.Enable";
    }

    // =======================================================================
    // Settings Storage
    // =======================================================================

    // Per-player QoS settings (stored in dc_player_qos_settings table)
    struct QoSSettings
    {
        // Tooltip settings
        bool tooltipsEnabled = true;
        bool showItemId = true;
        bool showItemLevel = true;
        bool showNpcId = true;
        bool showSpellId = true;
        bool showSpellFamilyMetadata = false;
        bool showGuildRank = true;
        bool showTarget = true;
        bool hideHealthBar = false;
        bool hideInCombat = false;
        float tooltipScale = 1.0f;

        // Automation settings
        bool automationEnabled = true;
        bool autoRepair = true;
        bool autoRepairGuild = false;
        bool autoSellJunk = true;
        bool autoDismount = false;
        bool autoAcceptSummon = false;
        bool autoAcceptResurrect = false;
        bool autoDeclineDuels = false;
        bool autoAcceptQuests = false;
        bool autoTurnInQuests = false;

        // Chat settings
        bool chatEnabled = true;
        bool hideChannelNames = false;
        bool stickyChannels = true;

        // Interface settings
        bool interfaceEnabled = true;
        bool combatPlates = false;
        bool questLevelText = true;
    };

    // =======================================================================
    // Helper Functions
    // =======================================================================

    static bool IsEnabled()
    {
        return sConfigMgr->GetOption<bool>(Config::ENABLED, true);
    }

    static std::string NormalizeRelayDistribution(std::string distribution, bool isRaidGroup)
    {
        std::transform(distribution.begin(), distribution.end(), distribution.begin(),
            [](unsigned char c) { return std::toupper(c); });

        if (distribution == "RAID")
            return isRaidGroup ? "RAID" : "PARTY";

        if (distribution == "PARTY")
            return "PARTY";

        // AUTO / GROUP / unknown fallback follows client logic:
        // raid if in raid, otherwise party.
        return isRaidGroup ? "RAID" : "PARTY";
    }

    static bool CollectRelayRecipients(Player* sender,
                                       const std::string& requestedDistribution,
                                       std::string& resolvedDistribution,
                                       std::vector<Player*>& recipients,
                                       std::string& error)
    {
        if (!sender)
        {
            error = "Invalid relay sender.";
            return false;
        }

        Group* group = sender->GetGroup();
        if (!group)
        {
            error = "You are not in a party or raid.";
            return false;
        }

        bool isRaidGroup = group->isRaidGroup();
        resolvedDistribution = NormalizeRelayDistribution(requestedDistribution, isRaidGroup);
        bool sameSubGroupOnly = isRaidGroup && resolvedDistribution == "PARTY";
        uint8 senderSubGroup = group->GetMemberGroup(sender->GetGUID());

        for (GroupReference* ref = group->GetFirstMember(); ref != nullptr; ref = ref->next())
        {
            Player* member = ref->GetSource();
            if (!member || !member->GetSession() || !member->IsInWorld())
                continue;

            if (member->GetGUID() == sender->GetGUID())
                continue;

            if (sameSubGroupOnly && group->GetMemberGroup(member->GetGUID()) != senderSubGroup)
                continue;

            recipients.push_back(member);
        }

        if (recipients.empty())
        {
            error = (resolvedDistribution == "RAID")
                ? "No other raid members available for relay."
                : "No other party members available for relay.";
            return false;
        }

        return true;
    }

    // =======================================================================
    // Settings Database Functions
    // =======================================================================

    QoSSettings LoadPlayerSettings(Player* player)
    {
        QoSSettings settings;

        if (!player)
            return settings;

        QueryResult result = CharacterDatabase.Query(
            "SELECT setting_key, setting_value FROM dc_player_qos_settings WHERE guid = {}",
            player->GetGUID().GetCounter()
        );

        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                std::string key = fields[0].Get<std::string>();
                std::string value = fields[1].Get<std::string>();

                // Parse settings
                if (key == "tooltips.enabled") settings.tooltipsEnabled = (value == "1");
                else if (key == "tooltips.showItemId") settings.showItemId = (value == "1");
                else if (key == "tooltips.showItemLevel") settings.showItemLevel = (value == "1");
                else if (key == "tooltips.showNpcId") settings.showNpcId = (value == "1");
                else if (key == "tooltips.showSpellId") settings.showSpellId = (value == "1");
                else if (key == "tooltips.showSpellFamilyMetadata") settings.showSpellFamilyMetadata = (value == "1");
                else if (key == "tooltips.showGuildRank") settings.showGuildRank = (value == "1");
                else if (key == "tooltips.showTarget") settings.showTarget = (value == "1");
                else if (key == "tooltips.hideHealthBar") settings.hideHealthBar = (value == "1");
                else if (key == "tooltips.hideInCombat") settings.hideInCombat = (value == "1");
                else if (key == "tooltips.scale") settings.tooltipScale = std::stof(value);
                else if (key == "automation.enabled") settings.automationEnabled = (value == "1");
                else if (key == "automation.autoRepair") settings.autoRepair = (value == "1");
                else if (key == "automation.autoRepairGuild") settings.autoRepairGuild = (value == "1");
                else if (key == "automation.autoSellJunk") settings.autoSellJunk = (value == "1");
                else if (key == "automation.autoDismount") settings.autoDismount = (value == "1");
                else if (key == "automation.autoAcceptSummon") settings.autoAcceptSummon = (value == "1");
                else if (key == "automation.autoAcceptResurrect") settings.autoAcceptResurrect = (value == "1");
                else if (key == "automation.autoDeclineDuels") settings.autoDeclineDuels = (value == "1");
                else if (key == "automation.autoAcceptQuests") settings.autoAcceptQuests = (value == "1");
                else if (key == "automation.autoTurnInQuests") settings.autoTurnInQuests = (value == "1");
                else if (key == "chat.enabled") settings.chatEnabled = (value == "1");
                else if (key == "chat.hideChannelNames") settings.hideChannelNames = (value == "1");
                else if (key == "chat.stickyChannels") settings.stickyChannels = (value == "1");
                else if (key == "interface.enabled") settings.interfaceEnabled = (value == "1");
                else if (key == "interface.combatPlates") settings.combatPlates = (value == "1");
                else if (key == "interface.questLevelText") settings.questLevelText = (value == "1");
            } while (result->NextRow());
        }

        return settings;
    }

    void SavePlayerSetting(Player* player, const std::string& key, const std::string& value)
    {
        if (!player)
            return;

        CharacterDatabase.Execute(
            "INSERT INTO dc_player_qos_settings (guid, setting_key, setting_value) "
            "VALUES ({}, '{}', '{}') "
            "ON DUPLICATE KEY UPDATE setting_value = '{}'",
            player->GetGUID().GetCounter(),
            key,
            value,
            value
        );
    }

    // =======================================================================
    // Send Functions
    // =======================================================================

    void SendSettingsSync(Player* player)
    {
        if (!player || !player->GetSession())
            return;

        QoSSettings settings = LoadPlayerSettings(player);

        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_SETTINGS_SYNC);

        // Tooltip settings
        msg.Set("tooltipsEnabled", settings.tooltipsEnabled);
        msg.Set("showItemId", settings.showItemId);
        msg.Set("showItemLevel", settings.showItemLevel);
        msg.Set("showNpcId", settings.showNpcId);
        msg.Set("showSpellId", settings.showSpellId);
        msg.Set("showSpellFamilyMetadata", settings.showSpellFamilyMetadata);
        msg.Set("showGuildRank", settings.showGuildRank);
        msg.Set("showTarget", settings.showTarget);
        msg.Set("hideHealthBar", settings.hideHealthBar);
        msg.Set("hideInCombat", settings.hideInCombat);
        msg.Set("tooltipScale", settings.tooltipScale);

        // Automation settings
        msg.Set("automationEnabled", settings.automationEnabled);
        msg.Set("autoRepair", settings.autoRepair);
        msg.Set("autoRepairGuild", settings.autoRepairGuild);
        msg.Set("autoSellJunk", settings.autoSellJunk);
        msg.Set("autoDismount", settings.autoDismount);
        msg.Set("autoAcceptSummon", settings.autoAcceptSummon);
        msg.Set("autoAcceptResurrect", settings.autoAcceptResurrect);
        msg.Set("autoDeclineDuels", settings.autoDeclineDuels);
        msg.Set("autoAcceptQuests", settings.autoAcceptQuests);
        msg.Set("autoTurnInQuests", settings.autoTurnInQuests);

        // Chat settings
        msg.Set("chatEnabled", settings.chatEnabled);
        msg.Set("hideChannelNames", settings.hideChannelNames);
        msg.Set("stickyChannels", settings.stickyChannels);

        // Interface settings
        msg.Set("interfaceEnabled", settings.interfaceEnabled);
        msg.Set("combatPlates", settings.combatPlates);
        msg.Set("questLevelText", settings.questLevelText);

        msg.Send(player);
    }

    void SendItemInfo(Player* player, uint32 itemId)
    {
        if (!player || !player->GetSession())
            return;

        const ItemTemplate* itemTemplate = sObjectMgr->GetItemTemplate(itemId);
        if (!itemTemplate)
        {
            // Item not found - send error
            DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_ITEM_INFO);
            msg.Set("itemId", itemId);
            msg.Set("error", "Item not found");
            msg.Send(player);
            return;
        }

        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_ITEM_INFO);
        msg.Set("itemId", itemId);
        msg.Set("name", itemTemplate->Name1);
        msg.Set("quality", itemTemplate->Quality);
        msg.Set("itemLevel", itemTemplate->ItemLevel);
        msg.Set("requiredLevel", itemTemplate->RequiredLevel);
        msg.Set("class", itemTemplate->Class);
        msg.Set("subclass", itemTemplate->SubClass);
        msg.Set("inventoryType", itemTemplate->InventoryType);
        msg.Set("maxStack", itemTemplate->GetMaxStackSize());
        msg.Set("sellPrice", itemTemplate->SellPrice);
        msg.Set("buyPrice", itemTemplate->BuyPrice);

        // Check for custom item data
        QueryResult customResult = WorldDatabase.Query(
            "SELECT custom_note, custom_source, is_custom FROM dc_item_custom_data WHERE item_id = {}",
            itemId
        );

        if (customResult)
        {
            Field* fields = customResult->Fetch();
            msg.Set("customNote", fields[0].Get<std::string>());
            msg.Set("customSource", fields[1].Get<std::string>());
            msg.Set("isCustom", fields[2].Get<bool>());
        }

        msg.Send(player);
    }

    // Send item upgrade/tier information for tooltip display
    void SendItemUpgradeInfo(Player* player, Item* item, uint8 bag, uint8 slot)
    {
        if (!player || !player->GetSession() || !item)
            return;

        ObjectGuid itemGuid = item->GetGUID();
        uint32 baseEntry = item->GetEntry();
        const ItemTemplate* itemTemplate = item->GetTemplate();

        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_ITEM_INFO);
        msg.Set("bag", static_cast<int32>(bag));
        msg.Set("slot", static_cast<int32>(slot));
        msg.Set("itemId", static_cast<int32>(baseEntry));
        msg.Set("guid", itemGuid.GetCounter());

        // Query upgrade data from dc_item_upgrades table
        QueryResult upgradeResult = CharacterDatabase.Query(
            "SELECT tier_id, upgrade_level FROM dc_item_upgrades WHERE item_guid = {}",
            itemGuid.GetCounter()
        );

        if (upgradeResult)
        {
            Field* fields = upgradeResult->Fetch();
            uint32 tierId = fields[0].Get<uint32>();
            uint32 upgradeLevel = fields[1].Get<uint32>();

            msg.Set("tier", static_cast<int32>(tierId));
            msg.Set("upgradeLevel", static_cast<int32>(upgradeLevel));

            // Get tier max level from dc_item_upgrade_tiers
            QueryResult tierResult = WorldDatabase.Query(
                "SELECT max_upgrade_level, stat_multiplier_max FROM dc_item_upgrade_tiers WHERE tier_id = {}",
                tierId
            );

            if (tierResult)
            {
                Field* tierFields = tierResult->Fetch();
                uint32 maxLevel = tierFields[0].Get<uint32>();
                float statMultiplierMax = tierFields[1].Get<float>();

                msg.Set("maxUpgrade", static_cast<int32>(maxLevel));

                // Calculate stat multiplier: 1.0 + (upgradeLevel * (statMultiplierMax - 1.0) / maxLevel)
                float statMultiplier = 1.0f;
                if (maxLevel > 0)
                {
                    statMultiplier = 1.0f + (static_cast<float>(upgradeLevel) * (statMultiplierMax - 1.0f) / static_cast<float>(maxLevel));
                }
                msg.Set("statMultiplier", statMultiplier);
            }
            else
            {
                // Default tier values
                msg.Set("maxUpgrade", 15);
                msg.Set("statMultiplier", 1.0f + (static_cast<float>(upgradeLevel) * 0.02f));
            }

            // Calculate effective item level
            if (itemTemplate)
            {
                uint32 baseIlvl = itemTemplate->ItemLevel;
                uint32 upgradedIlvl = baseIlvl + (upgradeLevel * 5);  // +5 ilvl per upgrade
                msg.Set("baseIlvl", static_cast<int32>(baseIlvl));
                msg.Set("upgradedIlvl", static_cast<int32>(upgradedIlvl));
            }

            // Check if item entry was changed (cloned for upgrade)
            uint32 currentEntry = item->GetEntry();
            if (currentEntry != baseEntry)
            {
                msg.Set("currentEntry", static_cast<int32>(currentEntry));
                msg.Set("baseEntry", static_cast<int32>(baseEntry));
            }
        }
        else
        {
            // No upgrade data - check if item is upgradeable
            msg.Set("upgradeLevel", 0);
            msg.Set("tier", 0);

            // Check if this item type can be upgraded
            if (itemTemplate)
            {
                bool canUpgrade = (itemTemplate->Class == ITEM_CLASS_WEAPON ||
                                   itemTemplate->Class == ITEM_CLASS_ARMOR) &&
                                  (itemTemplate->Quality >= ITEM_QUALITY_UNCOMMON);

                if (canUpgrade)
                {
                    msg.Set("maxUpgrade", 15);  // Default max upgrade
                    msg.Set("statMultiplier", 1.0f);
                }
                else
                {
                    msg.Set("maxUpgrade", 0);
                    msg.Set("statMultiplier", 1.0f);
                }
            }
        }

        msg.Send(player);
    }

    void SendNpcInfo(Player* player, const std::string& guidStr)
    {
        if (!player || !player->GetSession())
            return;

        // Parse GUID from the string
        // Format in WoW 3.3.5a is typically like: 0xF13000XXXXXX0000
        ObjectGuid guid;
        try
        {
            // Extract NPC entry ID from GUID (simplified parsing)
            // The actual GUID parsing may vary based on your implementation
            uint64 guidRaw = std::stoull(guidStr, nullptr, 16);
            guid = ObjectGuid(guidRaw);
        }
        catch (...)
        {
            // Invalid GUID format
            DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_NPC_INFO);
            msg.Set("guid", guidStr);
            msg.Set("error", "Invalid GUID format");
            msg.Send(player);
            return;
        }

        uint32 entry = guid.GetEntry();

        const CreatureTemplate* creatureTemplate = sObjectMgr->GetCreatureTemplate(entry);
        if (!creatureTemplate)
        {
            DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_NPC_INFO);
            msg.Set("guid", guidStr);
            msg.Set("error", "Creature template not found");
            msg.Send(player);
            return;
        }

        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_NPC_INFO);
        msg.Set("guid", guidStr);
        msg.Set("entry", entry);
        msg.Set("name", creatureTemplate->Name);
        msg.Set("subname", creatureTemplate->SubName);
        msg.Set("minLevel", creatureTemplate->minlevel);
        msg.Set("maxLevel", creatureTemplate->maxlevel);
        msg.Set("rank", creatureTemplate->rank);
        msg.Set("faction", creatureTemplate->faction);
        msg.Set("npcFlags", creatureTemplate->npcflag);
        msg.Set("unitClass", creatureTemplate->unit_class);
        msg.Set("type", creatureTemplate->type);

        // Get spawn information if available
        QueryResult spawnResult = WorldDatabase.Query(
            "SELECT guid, map, position_x, position_y, position_z, spawntimesecs "
            "FROM creature WHERE id1 = {} OR id2 = {} OR id3 = {} LIMIT 1",
            entry, entry, entry
        );

        // Try to get live spawn information from active creatures
        uint32 spawnId = 0;
        if (guid.IsCreatureOrVehicle())
        {
            if (Creature* creature = ObjectAccessor::GetCreature(*player, guid))
            {
                spawnId = creature->GetSpawnId();
            }
        }
        else if (guid.IsGameObject())
        {
            if (GameObject* go = ObjectAccessor::GetGameObject(*player, guid))
            {
                spawnId = go->GetSpawnId();
            }
        }

        // Include spawn ID if available (used by DC-Welcome addon for tooltips)
        if (spawnId > 0)
        {
            msg.Set("spawnId", static_cast<int32>(spawnId));
        }

        if (spawnResult)
        {
            Field* fields = spawnResult->Fetch();
            msg.Set("spawnGuid", static_cast<int32>(fields[0].Get<uint32>()));
            msg.Set("mapId", static_cast<int32>(fields[1].Get<uint16>()));
            msg.Set("spawnX", fields[2].Get<float>());
            msg.Set("spawnY", fields[3].Get<float>());
            msg.Set("spawnZ", fields[4].Get<float>());
            msg.Set("spawnTime", static_cast<int32>(fields[5].Get<uint32>()));
        }

        msg.Send(player);
    }

    void SendSpellInfo(Player* player, uint32 spellId)
    {
        if (!player || !player->GetSession())
            return;

        const SpellInfo* spellInfo = sSpellMgr->GetSpellInfo(spellId);
        if (!spellInfo)
        {
            DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_SPELL_INFO);
            msg.Set("spellId", spellId);
            msg.Set("error", "Spell not found");
            msg.Send(player);
            return;
        }

        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_SPELL_INFO);
        msg.Set("spellId", spellId);
        msg.Set("name", spellInfo->SpellName[0]);  // Assuming index 0 for English
        msg.Set("rank", spellInfo->Rank[0]);
        msg.Set("school", spellInfo->SchoolMask);
        msg.Set("powerType", spellInfo->PowerType);
        msg.Set("castTime", spellInfo->CastTimeEntry ? spellInfo->CastTimeEntry->CastTime : 0);
        msg.Set("cooldown", spellInfo->RecoveryTime);
        msg.Set("category", spellInfo->GetCategory());

        // Check for custom spell modifications
        QueryResult customResult = WorldDatabase.Query(
            "SELECT custom_note, modified_values FROM dc_spell_custom_data WHERE spell_id = {}",
            spellId
        );

        if (customResult)
        {
            Field* fields = customResult->Fetch();
            msg.Set("customNote", fields[0].Get<std::string>());
            msg.Set("modifiedValues", fields[1].Get<std::string>());
        }

        msg.Send(player);
    }

    static std::string FormatSpellSeconds(uint32 milliseconds)
    {
        std::ostringstream out;
        out << std::fixed << std::setprecision((milliseconds % 1000) != 0 ? 1 : 0)
            << (static_cast<double>(milliseconds) / 1000.0)
            << " sec";
        return out.str();
    }

    static std::string GetPowerTypeLabel(uint32 powerType)
    {
        switch (powerType)
        {
            case POWER_MANA: return "Mana";
            case POWER_RAGE: return "Rage";
            case POWER_FOCUS: return "Focus";
            case POWER_ENERGY: return "Energy";
            case POWER_HAPPINESS: return "Happiness";
            case POWER_RUNE: return "Rune";
            case POWER_RUNIC_POWER: return "Runic Power";
            case POWER_HEALTH: return "Health";
            default: return "Power";
        }
    }

    static void PushTooltipLine(DCAddon::JsonValue& lines,
                                std::string const& left,
                                std::string const& right = "",
                                double r = 0.8,
                                double g = 0.8,
                                double b = 0.8,
                                std::string const& kind = "")
    {
        DCAddon::JsonValue entry;
        entry.SetObject();
        entry.Set("left", left);
        if (!right.empty())
            entry.Set("right", right);
        entry.Set("r", r);
        entry.Set("g", g);
        entry.Set("b", b);
        if (!kind.empty())
            entry.Set("kind", kind);
        lines.Push(entry);
    }

    static std::vector<std::string> WrapTooltipText(std::string const& text, std::size_t maxWidth)
    {
        std::vector<std::string> wrapped;
        if (text.empty() || maxWidth < 8)
        {
            wrapped.push_back(text);
            return wrapped;
        }

        std::string remaining = text;
        while (remaining.size() > maxWidth)
        {
            std::size_t split = remaining.rfind(' ', maxWidth);
            if (split == std::string::npos || split < maxWidth / 2)
                split = maxWidth;

            wrapped.push_back(remaining.substr(0, split));

            if (split < remaining.size() && remaining[split] == ' ')
                ++split;
            remaining.erase(0, split);
        }

        if (!remaining.empty())
            wrapped.push_back(remaining);

        if (wrapped.empty())
            wrapped.push_back(text);

        return wrapped;
    }

    static void PushWrappedTooltipLine(DCAddon::JsonValue& lines,
                                       std::string const& left,
                                       double r,
                                       double g,
                                       double b,
                                       std::string const& kind,
                                       std::size_t maxWidth = 92)
    {
        for (std::string const& chunk : WrapTooltipText(left, maxWidth))
            PushTooltipLine(lines, chunk, "", r, g, b, kind);
    }

    static std::string GetSpellFamilyLabel(uint32 family)
    {
        switch (family)
        {
            case SPELLFAMILY_GENERIC: return "Generic";
            case SPELLFAMILY_UNK1: return "Event/Holiday";
            case SPELLFAMILY_MAGE: return "Mage";
            case SPELLFAMILY_WARRIOR: return "Warrior";
            case SPELLFAMILY_WARLOCK: return "Warlock";
            case SPELLFAMILY_PRIEST: return "Priest";
            case SPELLFAMILY_DRUID: return "Druid";
            case SPELLFAMILY_ROGUE: return "Rogue";
            case SPELLFAMILY_HUNTER: return "Hunter";
            case SPELLFAMILY_PALADIN: return "Paladin";
            case SPELLFAMILY_SHAMAN: return "Shaman";
            case SPELLFAMILY_UNK2: return "Unknown-12";
            case SPELLFAMILY_POTION: return "Potion";
            case SPELLFAMILY_DEATHKNIGHT: return "Death Knight";
            case SPELLFAMILY_PET: return "Pet";
            default: return "Unknown";
        }
    }

    static std::string FormatSpellFamilyInfo(SpellInfo const* spellInfo)
    {
        if (!spellInfo)
            return "";

        std::ostringstream out;
        out << "Spell Family: " << GetSpellFamilyLabel(spellInfo->SpellFamilyName)
            << " (" << spellInfo->SpellFamilyName << ")"
            << " | Flags "
            << "0x" << std::hex << std::uppercase << std::setw(8) << std::setfill('0') << spellInfo->SpellFamilyFlags[0]
            << ":0x" << std::hex << std::uppercase << std::setw(8) << std::setfill('0') << spellInfo->SpellFamilyFlags[1]
            << ":0x" << std::hex << std::uppercase << std::setw(8) << std::setfill('0') << spellInfo->SpellFamilyFlags[2];
        return out.str();
    }

    struct TooltipAmountRange
    {
        int32 Min = 0;
        int32 Max = 0;

        bool IsValid() const
        {
            return Min != 0 || Max != 0;
        }
    };

    static int32 GetTooltipBasePoints(Player* player,
                                      SpellInfo const* spellInfo,
                                      SpellEffectInfo const& effect)
    {
        if (!spellInfo)
            return effect.BasePoints;

        int32 basePoints = effect.BasePoints;

        if (player && effect.RealPointsPerLevel != 0.0f)
        {
            int32 level = int32(player->GetLevel());
            if (level > int32(spellInfo->MaxLevel) && spellInfo->MaxLevel > 0)
                level = int32(spellInfo->MaxLevel);
            else if (level < int32(spellInfo->BaseLevel))
                level = int32(spellInfo->BaseLevel);

            level -= int32(std::max(spellInfo->BaseLevel, spellInfo->SpellLevel));
            basePoints += int32(level * effect.RealPointsPerLevel);
        }

        return basePoints;
    }

    static TooltipAmountRange GetTooltipAmountRange(Player* player,
                                                    SpellInfo const* spellInfo,
                                                    SpellEffectInfo const& effect)
    {
        TooltipAmountRange range;
        int32 basePoints = GetTooltipBasePoints(player, spellInfo, effect);
        int32 dieSides = effect.DieSides;

        range.Min = basePoints;
        range.Max = basePoints;

        if (dieSides == 1)
        {
            range.Min += 1;
            range.Max += 1;
        }
        else if (dieSides > 1)
        {
            range.Min += 1;
            range.Max += dieSides;
        }
        else if (dieSides < 0)
        {
            range.Min += dieSides;
            range.Max += 1;
        }

        if (range.Min > range.Max)
            std::swap(range.Min, range.Max);

        return range;
    }

    static std::string FormatSignedAmountRange(TooltipAmountRange const& range, bool absolute = false)
    {
        int32 minValue = absolute ? std::abs(range.Min) : range.Min;
        int32 maxValue = absolute ? std::abs(range.Max) : range.Max;

        if (minValue > maxValue)
            std::swap(minValue, maxValue);

        std::ostringstream out;
        if (minValue == maxValue)
            out << minValue;
        else
            out << minValue << " to " << maxValue;
        return out.str();
    }

    static uint32 GetTooltipTickCount(SpellInfo const* spellInfo, SpellEffectInfo const& effect)
    {
        if (!spellInfo || effect.Amplitude == 0)
            return 0;

        int32 durationMs = spellInfo->GetMaxDuration();
        if (durationMs <= 0)
            return 0;

        return std::max<uint32>(1u, static_cast<uint32>(durationMs / int32(effect.Amplitude)));
    }

    static std::string FormatPeriodicTotalLine(Player* player,
                                               SpellInfo const* spellInfo,
                                               SpellEffectInfo const& effect,
                                               char const* singularVerb,
                                               char const* totalNoun)
    {
        TooltipAmountRange perTick = GetTooltipAmountRange(player, spellInfo, effect);
        uint32 tickCount = GetTooltipTickCount(spellInfo, effect);
        if (!perTick.IsValid() || tickCount == 0)
            return "";

        TooltipAmountRange total;
        total.Min = perTick.Min * int32(tickCount);
        total.Max = perTick.Max * int32(tickCount);

        std::ostringstream line;
        line << singularVerb << " " << FormatSignedAmountRange(total, true)
             << " " << totalNoun << " over "
             << FormatSpellSeconds(static_cast<uint32>(spellInfo->GetMaxDuration()));
        return line.str();
    }

    static std::string BuildSpellEffectTooltipLine(Player* player,
                                                   SpellInfo const* spellInfo,
                                                   SpellEffectInfo const& effect)
    {
        TooltipAmountRange amount = GetTooltipAmountRange(player, spellInfo, effect);

        if (effect.Effect == SPELL_EFFECT_WEAPON_DAMAGE
            || effect.Effect == SPELL_EFFECT_WEAPON_DAMAGE_NOSCHOOL
            || effect.Effect == SPELL_EFFECT_NORMALIZED_WEAPON_DMG)
        {
            if (amount.IsValid())
                return "Weapon damage plus " + FormatSignedAmountRange(amount, true) + ".";
            return "Deals weapon damage.";
        }

        if (effect.Effect == SPELL_EFFECT_WEAPON_PERCENT_DAMAGE)
        {
            if (amount.IsValid())
                return "Deals " + FormatSignedAmountRange(amount, true) + "% weapon damage.";
            return "Deals weapon damage based on a percentage modifier.";
        }

        if ((effect.Effect == SPELL_EFFECT_TRIGGER_SPELL
            || effect.Effect == SPELL_EFFECT_TRIGGER_SPELL_2
            || effect.Effect == SPELL_EFFECT_TRIGGER_SPELL_WITH_VALUE
            || effect.Effect == SPELL_EFFECT_TRIGGER_MISSILE
            || effect.Effect == SPELL_EFFECT_TRIGGER_MISSILE_SPELL_WITH_VALUE)
            && effect.TriggerSpell > 0)
        {
            SpellInfo const* triggered = sSpellMgr->GetSpellInfo(effect.TriggerSpell);
            if (triggered && triggered->SpellName[0] && *triggered->SpellName[0])
            {
                std::ostringstream out;
                out << "Triggers " << triggered->SpellName[0]
                    << " (Spell " << effect.TriggerSpell << ")";
                if (triggered->Rank[0] && *triggered->Rank[0])
                    out << ", " << triggered->Rank[0];
                out << ".";
                return out.str();
            }

            return "Triggers Spell " + std::to_string(effect.TriggerSpell) + ".";
        }

        switch (effect.Effect)
        {
            case SPELL_EFFECT_SCHOOL_DAMAGE:
            case SPELL_EFFECT_HEALTH_LEECH:
                if (amount.IsValid())
                    return "Causes " + FormatSignedAmountRange(amount, true) + " damage.";
                break;
            case SPELL_EFFECT_HEAL:
            case SPELL_EFFECT_HEAL_MECHANICAL:
                if (amount.IsValid())
                    return "Heals a friendly target for " + FormatSignedAmountRange(amount, true) + ".";
                break;
            case SPELL_EFFECT_ENERGIZE:
                if (amount.IsValid())
                    return "Restores " + FormatSignedAmountRange(amount, true) + " " + GetPowerTypeLabel(spellInfo->PowerType) + ".";
                break;
            default:
                break;
        }

        if (!effect.IsAura())
            return "";

        switch (effect.ApplyAuraName)
        {
            case SPELL_AURA_PERIODIC_DAMAGE:
            case SPELL_AURA_PERIODIC_LEECH:
            case SPELL_AURA_PERIODIC_DAMAGE_PERCENT:
                return FormatPeriodicTotalLine(player, spellInfo, effect, "Causes", "damage");
            case SPELL_AURA_PERIODIC_HEAL:
            case SPELL_AURA_PERIODIC_HEALTH_FUNNEL:
                return FormatPeriodicTotalLine(player, spellInfo, effect, "Heals", "health");
            case SPELL_AURA_PERIODIC_TRIGGER_SPELL:
                if (effect.TriggerSpell > 0)
                {
                    SpellInfo const* triggered = sSpellMgr->GetSpellInfo(effect.TriggerSpell);
                    if (triggered && triggered->SpellName[0] && *triggered->SpellName[0])
                    {
                        std::ostringstream out;
                        out << "Periodically triggers " << triggered->SpellName[0]
                            << " (Spell " << effect.TriggerSpell << ").";
                        return out.str();
                    }
                    return "Periodically triggers Spell " + std::to_string(effect.TriggerSpell) + ".";
                }
                break;
            case SPELL_AURA_SCHOOL_ABSORB:
            case SPELL_AURA_MANA_SHIELD:
                if (amount.IsValid())
                    return "Absorbs " + FormatSignedAmountRange(amount, true) + " damage.";
                break;
            case SPELL_AURA_MOD_STUN:
                return "Stuns the target.";
            case SPELL_AURA_MOD_ROOT:
                return "Roots the target in place.";
            case SPELL_AURA_MOD_FEAR:
                return "Causes the target to flee in fear.";
            case SPELL_AURA_MOD_CONFUSE:
                return "Disorients the target.";
            case SPELL_AURA_MOD_SILENCE:
                return "Silences the target.";
            case SPELL_AURA_MOD_INCREASE_SPEED:
                if (amount.IsValid())
                    return "Increases movement speed by " + FormatSignedAmountRange(amount, true) + "%.";
                break;
            case SPELL_AURA_MOD_DECREASE_SPEED:
                if (amount.IsValid())
                    return "Reduces movement speed by " + FormatSignedAmountRange(amount, true) + "%.";
                break;
            case SPELL_AURA_MOD_DAMAGE_DONE:
            case SPELL_AURA_MOD_DAMAGE_PERCENT_DONE:
                if (amount.IsValid())
                    return "Increases damage done by " + FormatSignedAmountRange(amount, true) + ".";
                break;
            case SPELL_AURA_MOD_HEALING:
                if (amount.IsValid())
                    return "Increases healing done by " + FormatSignedAmountRange(amount, true) + ".";
                break;
            case SPELL_AURA_MOD_STAT:
            case SPELL_AURA_MOD_PERCENT_STAT:
                if (amount.IsValid())
                    return "Modifies stats by " + FormatSignedAmountRange(amount, true) + ".";
                break;
            default:
                break;
        }

        return "";
    }

    static void AppendSpellDescriptionLines(Player* player,
                                            SpellInfo const* spellInfo,
                                            DCAddon::JsonValue& lines,
                                            bool includeFamilyMetadata)
    {
        if (!spellInfo)
            return;

        std::set<std::string> seen;

        std::string familyInfo = includeFamilyMetadata ? FormatSpellFamilyInfo(spellInfo) : "";
        if (!familyInfo.empty())
            PushWrappedTooltipLine(lines, familyInfo, 0.70, 0.92, 1.00, "meta");

        for (SpellEffectInfo const& effect : spellInfo->Effects)
        {
            if (!effect.IsEffect())
                continue;

            std::string description = BuildSpellEffectTooltipLine(player, spellInfo, effect);
            if (description.empty() || !seen.insert(description).second)
                continue;

            PushWrappedTooltipLine(lines, description, 0.95, 0.82, 0.55, "body");
        }
    }

    static DCAddon::JsonValue BuildSpellTooltipEnrichmentLines(Player* player,
                                                               uint32 /*spellId*/,
                                                               uint32 /*contextHash*/,
                                                               SpellInfo const* spellInfo,
                                                               std::string const& /*line*/,
                                                               bool includeFamilyMetadata)
    {
        DCAddon::JsonValue lines;
        lines.SetArray();

        if (!spellInfo)
            return lines;

        if (spellInfo->Rank[0] && *spellInfo->Rank[0])
            PushTooltipLine(lines, spellInfo->Rank[0]);

        uint32 castTimeMs = spellInfo->CalcCastTime(player);
        if (castTimeMs == 0)
            PushTooltipLine(lines, "Instant cast");
        else
            PushTooltipLine(lines, FormatSpellSeconds(castTimeMs) + " cast");

        float minRange = spellInfo->GetMinRange(false);
        float maxRange = spellInfo->GetMaxRange(false, player);
        if (maxRange > 0.0f)
        {
            std::ostringstream rangeLine;
            rangeLine << std::fixed << std::setprecision(0);
            if (minRange > 0.0f)
                rangeLine << minRange << "-" << maxRange << " yd range";
            else
                rangeLine << maxRange << " yd range";
            PushTooltipLine(lines, rangeLine.str());
        }

        int32 powerCost = player ? spellInfo->CalcPowerCost(player, spellInfo->GetSchoolMask()) : 0;
        if (powerCost > 0)
        {
            std::ostringstream costLine;
            costLine << powerCost << " " << GetPowerTypeLabel(spellInfo->PowerType);
            PushTooltipLine(lines, costLine.str());
        }

        uint32 cooldownMs = spellInfo->GetRecoveryTime();
        if (cooldownMs > 0)
            PushTooltipLine(lines, "Cooldown", FormatSpellSeconds(cooldownMs));

        int32 durationMs = spellInfo->GetMaxDuration();
        if (durationMs > 0)
            PushTooltipLine(lines, "Duration", FormatSpellSeconds(static_cast<uint32>(durationMs)));

        AppendSpellDescriptionLines(player, spellInfo, lines, includeFamilyMetadata);

        return lines;
    }

    // AddonProtocol skeleton for the mixed tooltip architecture:
    // request payload order: requestId, spellId, contextHash
    // JSON response fields: requestId, spellId, contextHash, status, line, lines[]
    void SendSpellTooltipEnrichment(Player* player,
                                    uint32 requestId,
                                    uint32 spellId,
                                    uint32 contextHash,
                                    uint8 status,
                                    std::string const& line,
                                    std::string const& protocolRequestId,
                                    SpellInfo const* spellInfo = nullptr,
                                    bool includeFamilyMetadata = false)
    {
        if (!player || !player->GetSession())
            return;

        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_SPELL_TOOLTIP_ENRICHMENT);
        if (!protocolRequestId.empty())
            msg.SetRequestId(protocolRequestId);

        msg.Set("requestId", requestId);
        msg.Set("spellId", spellId);
        msg.Set("contextHash", contextHash);
        msg.Set("status", static_cast<uint32>(status));
        msg.Set("line", line);

        if (status == 0 && spellInfo)
        {
            msg.Set("source", "server-v2");
            msg.Set("lines", BuildSpellTooltipEnrichmentLines(player, spellId, contextHash, spellInfo, line, includeFamilyMetadata));
        }

        msg.Send(player);
    }

    std::string BuildSpellTooltipEnrichmentLine(Player* player, uint32 spellId, uint32 contextHash, SpellInfo const* spellInfo)
    {
        if (!player || !spellInfo)
            return "";

        std::ostringstream line;
        line << "server-v1";
        line << " spell=" << spellId;
        line << " ctx=" << contextHash;

        uint32 castTime = spellInfo->CastTimeEntry ? static_cast<uint32>(std::max<int32>(0, spellInfo->CastTimeEntry->CastTime)) : 0u;
        if (castTime > 0)
            line << " cast=" << castTime << "ms";

        if (spellInfo->RecoveryTime > 0)
            line << " cd=" << spellInfo->RecoveryTime << "ms";

        // TODO: extend with dynamic player-context values (auras/spec/rating snapshots)
        // and custom DB overlays once server-side calculators are finalized.
        return line.str();
    }

    void SendNotification(Player* player, const std::string& type, const std::string& message)
    {
        if (!player || !player->GetSession())
            return;

        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_NOTIFICATION);
        msg.Set("type", type);
        msg.Set("message", message);
        msg.Send(player);
    }

    // =======================================================================
    // Message Handlers
    // =======================================================================

    void HandleSyncSettings(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        SendSettingsSync(player);
    }

    void HandleUpdateSetting(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player)
            return;

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        if (json.IsNull())
            return;

        std::string path = json["path"].AsString();
        std::string value;

        // Handle different value types
        if (json.HasKey("value"))
        {
            auto& val = json["value"];
            if (val.IsBool())
                value = val.AsBool() ? "1" : "0";
            else if (val.IsNumber())
                value = std::to_string(val.AsNumber());
            else
                value = val.AsString();
        }

        if (!path.empty())
        {
            SavePlayerSetting(player, path, value);

            // Send confirmation
            DCAddon::JsonMessage response(MODULE, Opcode::SMSG_SETTING_UPDATED);
            response.Set("path", path);
            response.Set("value", value);
            response.Set("success", true);
            response.Send(player);
        }
    }

    void HandleGetItemInfo(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player)
            return;

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);

        // Check if this is an upgrade info request (has bag/slot)
        if (!json.IsNull() && json.HasKey("bag") && json.HasKey("slot"))
        {
            uint8 bag = static_cast<uint8>(json["bag"].AsNumber());
            uint8 slot = static_cast<uint8>(json["slot"].AsNumber());

            // Get item from player's inventory
            Item* item = player->GetItemByPos(bag, slot);
            if (!item)
            {
                DCAddon::JsonMessage response(MODULE, Opcode::SMSG_ITEM_INFO);
                response.Set("bag", static_cast<int32>(bag));
                response.Set("slot", static_cast<int32>(slot));
                response.Set("error", "Item not found at location");
                response.Send(player);
                return;
            }

            SendItemUpgradeInfo(player, item, bag, slot);
            return;
        }

        // Try to get item ID from message data
        uint32 itemId = 0;

        if (!json.IsNull() && json.HasKey("itemId"))
        {
            itemId = static_cast<uint32>(json["itemId"].AsNumber());
        }
        else if (msg.GetDataCount() > 0)
        {
            // Simple format: QOS|0x03|itemId
            itemId = msg.GetUInt32(0);
        }

        if (itemId > 0)
        {
            SendItemInfo(player, itemId);
        }
    }

    void HandleGetNpcInfo(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player)
            return;

        std::string guidStr;

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        if (!json.IsNull() && json.HasKey("guid"))
        {
            guidStr = json["guid"].AsString();
        }
        else if (msg.GetDataCount() > 0)
        {
            guidStr = msg.GetString(0);
        }

        if (!guidStr.empty())
        {
            SendNpcInfo(player, guidStr);
        }
    }

    void HandleGetSpellInfo(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player)
            return;

        uint32 spellId = 0;

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        if (!json.IsNull() && json.HasKey("spellId"))
        {
            spellId = static_cast<uint32>(json["spellId"].AsNumber());
        }
        else if (msg.GetDataCount() > 0)
        {
            spellId = msg.GetUInt32(0);
        }

        if (spellId > 0)
        {
            SendSpellInfo(player, spellId);
        }
    }

    void HandleRequestSpellTooltipEnrichment(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player)
            return;

        uint32 requestId = 0;
        uint32 spellId = 0;
        uint32 contextHash = 0;

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        if (!json.IsNull() && json.HasKey("requestId") && json.HasKey("spellId") && json.HasKey("contextHash"))
        {
            requestId = static_cast<uint32>(json["requestId"].AsNumber());
            spellId = static_cast<uint32>(json["spellId"].AsNumber());
            contextHash = static_cast<uint32>(json["contextHash"].AsNumber());
        }
        else if (msg.GetDataCount() >= 3)
        {
            // Simple format: QOS|0x08|requestId|spellId|contextHash
            requestId = msg.GetUInt32(0);
            spellId = msg.GetUInt32(1);
            contextHash = msg.GetUInt32(2);
        }

        // Status map (matches client expectations):
        // 0 = success (line present)
        // 1 = spell not found
        // 2 = invalid request payload
        // 3 = no enrichment data available
        if (requestId == 0 || spellId == 0 || contextHash == 0)
        {
            SendSpellTooltipEnrichment(player, requestId, spellId, contextHash, 2, "invalid-request", msg.GetRequestId());
            return;
        }

        SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
        if (!spellInfo)
        {
            SendSpellTooltipEnrichment(player, requestId, spellId, contextHash, 1, "spell-not-found", msg.GetRequestId());
            return;
        }

        std::string line = BuildSpellTooltipEnrichmentLine(player, spellId, contextHash, spellInfo);
        if (line.empty())
        {
            SendSpellTooltipEnrichment(player, requestId, spellId, contextHash, 3, "no-enrichment-data", msg.GetRequestId());
            return;
        }

        QoSSettings settings = LoadPlayerSettings(player);
        bool includeFamilyMetadata = settings.showSpellFamilyMetadata;

        SendSpellTooltipEnrichment(player, requestId, spellId, contextHash, 0, line, msg.GetRequestId(), spellInfo, includeFamilyMetadata);
    }

    void HandleRequestFeature(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player)
            return;

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        if (json.IsNull())
            return;

        std::string feature = json["feature"].AsString();

        if (feature == "ping")
        {
            std::string action = json.HasKey("action") ? json["action"].AsString() : "";

            DCAddon::JsonMessage ack(MODULE, Opcode::SMSG_FEATURE_DATA);
            ack.Set("feature", "ping_relay_ack");

            if (action != "relay")
            {
                ack.Set("action", "relay_ack");
                ack.Set("ok", false);
                ack.Set("error", "Unsupported ping feature action.");
                ack.Send(player);
                return;
            }

            std::string payload = json.HasKey("payload") ? json["payload"].AsString() : "";
            if (payload.empty() && json.HasKey("syncPayload"))
                payload = json["syncPayload"].AsString();

            if (payload.empty())
            {
                ack.Set("action", "relay_ack");
                ack.Set("ok", false);
                ack.Set("error", "Missing ping relay payload.");
                ack.Send(player);
                return;
            }

            std::string requestedDistribution = json.HasKey("distribution") ? json["distribution"].AsString() : "AUTO";
            std::string resolvedDistribution;
            std::vector<Player*> recipients;
            std::string relayError;

            if (!CollectRelayRecipients(player, requestedDistribution, resolvedDistribution, recipients, relayError))
            {
                ack.Set("action", "relay_ack");
                ack.Set("ok", false);
                ack.Set("error", relayError);
                ack.Send(player);
                return;
            }

            DCAddon::JsonMessage relay(MODULE, Opcode::SMSG_FEATURE_DATA);
            relay.Set("feature", "ping");
            relay.Set("action", "relay");
            relay.Set("distribution", resolvedDistribution);
            relay.Set("payload", payload);
            relay.Set("syncPayload", payload);
            relay.Set("source", player->GetName());
            relay.Set("sourceGuid", static_cast<uint32>(player->GetGUID().GetCounter()));
            relay.Set("timestamp", static_cast<uint32>(time(nullptr)));
            for (Player* recipient : recipients)
            {
                if (!recipient || !recipient->GetSession())
                    continue;

                relay.Send(recipient);
            }

            ack.Set("action", "relay_ack");
            ack.Set("ok", true);
            ack.Set("distribution", resolvedDistribution);
            ack.Set("recipients", static_cast<uint32>(recipients.size()));
            ack.Send(player);
            return;
        }

        // Handle specific feature requests
        DCAddon::JsonMessage response(MODULE, Opcode::SMSG_FEATURE_DATA);
        response.Set("feature", feature);

        if (feature == "server_time")
        {
            response.Set("serverTime", static_cast<int32>(time(nullptr)));
        }
        else if (feature == "player_stats")
        {
            // Example: send some player stats
            response.Set("level", player->GetLevel());
            response.Set("maxLevel", sWorld->getIntConfig(CONFIG_MAX_PLAYER_LEVEL));
            response.Set("gold", static_cast<int32>(player->GetMoney()));
        }
        else
        {
            response.Set("error", "Unknown feature: " + feature);
        }

        response.Send(player);
    }

    void HandleCollectAllMail(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        if (!player || !player->GetSession())
            return;

        // Iterate over player's mail
        PlayerMails const& mailCache = player->GetMails();

        uint32 collectedGold = 0;

        // Transaction safety:
        // We will execute DB updates directly but we must be careful with in-memory state.
        // It's safer to process one by one in a loop that simulates standard taking.

        // Note: Direct manipulation of mail is risky. We should check if we can call "TakeMoney" and "TakeItem" methods.
        // But since we are inside a script, let's try to be respectful of core logic.

        // LIMITATION: Use a naive approach that just collects money and returns success message.
        // Implementing full item collection safely without access to core headers/methods for "AutoStoreMailItem" is hard.
        // However, we can try to implement the logic for Money at least, which is the most common use case.

        SQLTransaction trans = CharacterDatabase.BeginTransaction();
        bool changes = false;

        for (Mail* mail : mailCache)
        {
            uint32 mailId = mail->messageID;
            // Collect Money
            if (mail->money > 0)
            {
                // Give money
                player->ModifyMoney(mail->money);
                collectedGold += mail->money;

                // Update DB
                trans->Append("UPDATE mail SET money = 0 WHERE id = {}", mailId);

                // Update in-memory
                // const_cast is ugly but necessary here if we don't have a specific setter
                const_cast<Mail*>(mail)->money = 0;

                changes = true;
            }

            // Collect Items
            // This is complex because of bag space.
            // Simplified logic: If we have space, take it.

            // For now, let's stick to money and maybe simple items if we can access the item list securely.
            // Accessing items inside a Mail object depends on the core version.

            /*
            if (!mail->items.empty())
            {
               // ... item logic would go here ...
            }
            */

            // If mail is now empty (no items, no money, no COD, no text), mark for deletion?
            // Usually we don't delete automatically unless it's a temp mail.
        }

        if (changes)
        {
            CharacterDatabase.CommitTransaction(trans);

            // Send client update
            player->SendMailResult(0, MAIL_SEND, MAIL_OK);

            DCAddon::JsonMessage notification(MODULE, Opcode::SMSG_NOTIFICATION);
            notification.Set("type", "success");

            std::string msg = "Collected " + std::to_string(collectedGold / 10000) + "g";
            notification.Set("message", msg);
            notification.Send(player);
        }
    }

    // -----------------------------------------------------------------------
    // Login spell enrichment pre-push helpers
    // -----------------------------------------------------------------------

    // Mirrors the Lua FNV-1a-style hash used by BuildSpellTooltipContextHash.
    // Keep in sync with DC-QOS/Modules/Tooltips.lua constants:
    //   SEED  = 2166136261, PRIME = 16777619, MOD = 4294967296
    static uint32 MixSpellTooltipContext(uint32 hash, uint32 value)
    {
        uint64 h = (static_cast<uint64>(hash) + value) % 4294967296ULL;
        h = (h * 16777619ULL) % 4294967296ULL;
        return static_cast<uint32>(h);
    }

    // Replicates client-side BuildSpellTooltipContextHash(spellId) at login.
    // shapeshiftForm = 0 on login (no active form yet).
    // activeTalentGroup is 1-indexed on the client (GetActiveTalentGroup returns 1 or 2).
    static uint32 BuildSpellTooltipContextHashForPlayer(uint32 spellId, uint8 level, uint8 classId, uint8 activeTalentGroup)
    {
        uint32 hash = 2166136261U;
        hash = MixSpellTooltipContext(hash, spellId);
        hash = MixSpellTooltipContext(hash, level);
        hash = MixSpellTooltipContext(hash, classId);
        hash = MixSpellTooltipContext(hash, 0u); // shapeshiftForm = 0 at login
        hash = MixSpellTooltipContext(hash, activeTalentGroup);
        if (hash == 0) hash = 1;
        return hash;
    }

    // Push enrichment data for every active, non-passive spell the player knows.
    // Uses requestId=0 as the server-push sentinel (no pending client request to resolve).
    static void PushAllSpellEnrichments(Player* player)
    {
        if (!player || !player->IsInWorld())
            return;

        QoSSettings settings = LoadPlayerSettings(player);
        bool includeFamilyMetadata = settings.showSpellFamilyMetadata;

        uint8 level            = static_cast<uint8>(player->GetLevel());
        uint8 classId          = static_cast<uint8>(player->getClass());
        // Client GetActiveTalentGroup() is 1-indexed; server GetActiveSpec() is 0-indexed.
        uint8 activeTalentGroup = static_cast<uint8>(player->GetActiveSpec() + 1);

        uint32 pushed = 0;
        for (auto const& [spellId, spellState] : player->GetSpellMap())
        {
            if (!spellState || spellState->State == PLAYERSPELL_REMOVED || !spellState->Active)
                continue;

            SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
            if (!spellInfo || spellInfo->IsPassive())
                continue;

            uint32 contextHash = BuildSpellTooltipContextHashForPlayer(spellId, level, classId, activeTalentGroup);

            std::string line = BuildSpellTooltipEnrichmentLine(player, spellId, contextHash, spellInfo);
            if (line.empty())
                continue;

            // requestId=0 → server-initiated push; client caches without requiring a pending entry.
            SendSpellTooltipEnrichment(player, 0, spellId, contextHash, 0, line, "", spellInfo, includeFamilyMetadata);
            ++pushed;
        }

        LOG_DEBUG("module.dc", "DCQoS: Pre-pushed {} spell enrichments to player '{}'", pushed, player->GetName());
    }

}  // namespace DCQoS

// ============================================================================
// REGISTER HANDLERS
// ============================================================================

// Delayed event: fires 3 s after login to give the DC-QOS addon time to
// connect and register its protocol handlers before we flood it with data.
class DCQoS_SpellEnrichmentPushEvent : public BasicEvent
{
public:
    explicit DCQoS_SpellEnrichmentPushEvent(ObjectGuid guid) : _guid(guid) {}

    bool Execute(uint64 /*e_time*/, uint32 /*p_time*/) override
    {
        if (Player* player = ObjectAccessor::FindConnectedPlayer(_guid))
            DCQoS::PushAllSpellEnrichments(player);
        return true; // consumed – do not repeat
    }

private:
    ObjectGuid _guid;
};

class DCQoSPlayerScript : public PlayerScript
{
public:
    DCQoSPlayerScript() : PlayerScript("DCQoSPlayerScript") {}

    void OnPlayerLogin(Player* player) override
    {
        if (!DCQoS::IsEnabled() || !player)
            return;

        // Pre-push spell enrichment data so first-hover tooltips are instant.
        // Delayed 3 s to let the addon initialize and open its protocol channel.
        player->m_Events.AddEvent(
            new DCQoS_SpellEnrichmentPushEvent(player->GetGUID()),
            player->m_Events.CalculateTime(3000)
        );
    }
};

// Message handler registration - called from dc_addon_protocol.cpp
namespace DCAddon
{
    void RegisterQoSHandlers()
    {
        using namespace DCQoS;

        // Register module "QOS" handlers
        DCAddon::MessageRouter::Instance().RegisterHandler(MODULE, DCQoS::Opcode::CMSG_SYNC_SETTINGS, HandleSyncSettings);
        DCAddon::MessageRouter::Instance().RegisterHandler(MODULE, DCQoS::Opcode::CMSG_UPDATE_SETTING, HandleUpdateSetting);
        DCAddon::MessageRouter::Instance().RegisterHandler(MODULE, DCQoS::Opcode::CMSG_GET_ITEM_INFO, HandleGetItemInfo);
        DCAddon::MessageRouter::Instance().RegisterHandler(MODULE, DCQoS::Opcode::CMSG_GET_NPC_INFO, HandleGetNpcInfo);
        DCAddon::MessageRouter::Instance().RegisterHandler(MODULE, DCQoS::Opcode::CMSG_GET_SPELL_INFO, HandleGetSpellInfo);
        DCAddon::MessageRouter::Instance().RegisterHandler(MODULE, DCQoS::Opcode::CMSG_REQUEST_FEATURE, HandleRequestFeature);
        DCAddon::MessageRouter::Instance().RegisterHandler(MODULE, DCQoS::Opcode::CMSG_COLLECT_ALL_MAIL, HandleCollectAllMail);
        DCAddon::MessageRouter::Instance().RegisterHandler(MODULE, DCQoS::Opcode::CMSG_REQUEST_SPELL_TOOLTIP_ENRICHMENT, HandleRequestSpellTooltipEnrichment);
    }
}

void AddDCQoSScripts()
{
    DCAddon::RegisterQoSHandlers();

    auto& router = DCAddon::MessageRouter::Instance();
    bool hasTooltipHandler = router.HasHandler(DCQoS::MODULE, DCQoS::Opcode::CMSG_REQUEST_SPELL_TOOLTIP_ENRICHMENT);

    if (hasTooltipHandler)
    {
        LOG_INFO(
            "module.dc",
            "DCQoS handler registration verified (module={}, opcode=0x{:02X})",
            DCQoS::MODULE,
            DCQoS::Opcode::CMSG_REQUEST_SPELL_TOOLTIP_ENRICHMENT);
    }
    else
    {
        LOG_ERROR(
            "module.dc",
            "DCQoS handler registration missing (module={}, opcode=0x{:02X})",
            DCQoS::MODULE,
            DCQoS::Opcode::CMSG_REQUEST_SPELL_TOOLTIP_ENRICHMENT);
    }

    new DCQoSPlayerScript();
}
