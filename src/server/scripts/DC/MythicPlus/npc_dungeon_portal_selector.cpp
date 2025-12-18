/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 * 
 * Dungeon Portal Difficulty Selector
 * Allows players to select Normal/Heroic/Mythic difficulty before entering dungeons
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "ScriptedGossip.h"
#include "MythicDifficultyScaling.h"
#include "WorldSession.h"
#include "Map.h"
#include "Log.h"
#include "Config.h"
#include "StringFormat.h"
#include "DC/DungeonQuests/DungeonQuestConstants.h"
#include "DC/AddonExtension/DCAddonNamespace.h"
#include "DC/CrossSystem/DCSeasonHelper.h"
#include "ObjectAccessor.h"
#include <algorithm>
#include <array>
#include <unordered_map>

namespace
{
struct DungeonTeleporterOption
{
    uint32 entryId;
    char const* label;
};

constexpr std::array<DungeonTeleporterOption, 11> kDungeonTeleporterOptions = {{
    {151, "Halls of Lightning"},
    {152, "Utgarde Tower"},
    {153, "Halls of Stone"},
    {155, "Violet Citadel"},
    {157, "AhnKahet"},
    {158, "Azjol Nerub"},
    {160, "Utgarde Keep"},
    {162, "Drak Tharon"},
    {163, "Culling of Stratholme"},
    {164, "Frozen Halls"},
    {165, "Trial of the Champion"}
}};

bool IsMythicDungeonTeleporter(uint32 entryId)
{
    return std::any_of(kDungeonTeleporterOptions.begin(), kDungeonTeleporterOptions.end(),
        [entryId](DungeonTeleporterOption const& option) { return option.entryId == entryId; });
}

float GetDungeonZOffset(uint32 dungeonMapId)
{
    switch (dungeonMapId)
    {
        case 599: // Halls of Stone
            return 3.0f;
        case 602: // Halls of Lightning
            return 4.0f;
        default:
            return 0.0f;
    }
}

constexpr uint32 GOSSIP_ACTION_OPEN_SEASONAL_UI = 9001;
constexpr uint32 PORTAL_UI_DISTANCE = 12; // yards
constexpr time_t PORTAL_UI_SESSION_SECONDS = 60;

struct PortalUiSession
{
    ObjectGuid creatureGuid;
    time_t expiresAt = 0;
};

static std::unordered_map<uint32, PortalUiSession> s_portalUiSessions;

static bool IsPortalSessionValid(Player* player, Creature** outCreature = nullptr)
{
    if (!player)
        return false;

    uint32 key = player->GetGUID().GetCounter();
    auto it = s_portalUiSessions.find(key);
    if (it == s_portalUiSessions.end())
        return false;

    time_t now = time(nullptr);
    if (now > it->second.expiresAt)
    {
        s_portalUiSessions.erase(it);
        return false;
    }

    Creature* creature = ObjectAccessor::GetCreature(*player, it->second.creatureGuid);
    if (!creature)
        return false;

    if (!player->IsWithinDistInMap(creature, float(PORTAL_UI_DISTANCE)))
        return false;

    if (outCreature)
        *outCreature = creature;
    return true;
}

static void TeleportToDungeonEntranceByDungeonMap(Player* player, uint32 dungeonMapId)
{
    if (!player)
        return;

    QueryResult result = WorldDatabase.Query(
        "SELECT entrance_map, entrance_x, entrance_y, entrance_z, entrance_o FROM dc_dungeon_entrances WHERE dungeon_map = {}",
        dungeonMapId);

    if (!result)
    {
        ChatHandler(player->GetSession()).SendSysMessage(
            "Error: Dungeon entrance coordinates not found in database.");
        LOG_ERROR("mythic.portal", "No dc_dungeon_entrances entry found for dungeon map {}", dungeonMapId);
        return;
    }

    Field* fields = result->Fetch();
    uint32 entranceMap = fields[0].Get<uint32>();
    float x = fields[1].Get<float>();
    float y = fields[2].Get<float>();
    float z = fields[3].Get<float>();
    float o = fields[4].Get<float>();

    // Preserve small map-specific z fixes
    z += GetDungeonZOffset(dungeonMapId);

    if (player->TeleportTo(entranceMap, x, y, z, o))
    {
        ChatHandler(player->GetSession()).SendSysMessage("|cff00ff00Teleporting to dungeon entrance...|r");
        LOG_INFO("mythic.portal", "Player {} teleported to seasonal dungeon {}", player->GetName(), dungeonMapId);
    }
    else
    {
        ChatHandler(player->GetSession()).SendSysMessage("Error: Failed to teleport to dungeon entrance.");
        LOG_ERROR("mythic.portal", "Failed to teleport player {} to seasonal dungeon {}", player->GetName(), dungeonMapId);
    }
}

static bool IsSeasonalDungeon(uint32 dungeonMapId, uint32 seasonId)
{
    QueryResult result = WorldDatabase.Query(
        "SELECT is_unlocked, mythic_plus_enabled, IFNULL(season_lock, 0) FROM dc_dungeon_setup WHERE map_id = {}",
        dungeonMapId);

    if (!result)
        return false;

    Field* fields = result->Fetch();
    bool isUnlocked = fields[0].Get<bool>();
    bool mplusEnabled = fields[1].Get<bool>();
    uint32 requiredSeason = fields[2].Get<uint32>();

    return isUnlocked && mplusEnabled && (requiredSeason == 0 || requiredSeason == seasonId);
}

static void SendSeasonalPortalOpen(Player* player)
{
    if (!player)
        return;

    uint32 seasonId = DarkChaos::GetActiveSeasonId();

    // Only include dungeons that have an entrance record.
    QueryResult result = WorldDatabase.Query(
        "SELECT s.map_id, s.dungeon_name "
        "FROM dc_dungeon_setup s "
        "INNER JOIN dc_dungeon_entrances e ON e.dungeon_map = s.map_id "
        "WHERE s.is_unlocked = 1 AND s.mythic_plus_enabled = 1 AND (IFNULL(s.season_lock, 0) = 0 OR s.season_lock = {}) "
        "ORDER BY s.dungeon_name ASC",
        seasonId);

    DCAddon::JsonMessage open(DCAddon::Module::MYTHIC_PLUS, DCAddon::Opcode::MPlus::SMSG_SEASONAL_PORTAL_OPEN);
    open.Set("seasonId", seasonId);

    DCAddon::JsonValue list;
    list.SetArray();

    if (result)
    {
        do
        {
            Field* fields = result->Fetch();
            uint32 mapId = fields[0].Get<uint32>();
            std::string name = fields[1].Get<std::string>();

            DCAddon::JsonValue obj;
            obj.SetObject();
            obj.Set("mapId", DCAddon::JsonValue(mapId));
            obj.Set("name", DCAddon::JsonValue(name));
            list.Push(obj);
        } while (result->NextRow());
    }

    open.Set("dungeons", list);
    open.Send(player);
}

static void SendSeasonalPortalResult(Player* player, bool success, std::string const& message)
{
    DCAddon::JsonMessage resp(DCAddon::Module::MYTHIC_PLUS, DCAddon::Opcode::MPlus::SMSG_SEASONAL_PORTAL_RESULT);
    resp.Set("success", success);
    resp.Set("message", message);
    resp.Send(player);
}

static void HandleSeasonalPortalTeleport(Player* player, DCAddon::ParsedMessage const& msg)
{
    if (!player)
        return;

    if (!IsPortalSessionValid(player))
    {
        SendSeasonalPortalResult(player, false, "Please use the portal again.");
        return;
    }

    uint32 dungeonMapId = 0;
    uint32 difficulty = 0;
    if (DCAddon::IsJsonMessage(msg))
    {
        DCAddon::JsonValue req = DCAddon::GetJsonData(msg);
        if (req.IsObject())
        {
            if (req.HasKey("mapId") && req["mapId"].IsNumber())
                dungeonMapId = req["mapId"].AsUInt32();
            if (req.HasKey("difficulty") && req["difficulty"].IsNumber())
                difficulty = req["difficulty"].AsUInt32();
        }
    }

    if (!dungeonMapId)
    {
        SendSeasonalPortalResult(player, false, "Invalid dungeon selection.");
        return;
    }

    uint32 seasonId = DarkChaos::GetActiveSeasonId();
    if (!IsSeasonalDungeon(dungeonMapId, seasonId))
    {
        SendSeasonalPortalResult(player, false, "That dungeon is not available this season.");
        return;
    }

    Difficulty selectedDifficulty = DUNGEON_DIFFICULTY_EPIC;
    char const* difficultyLabel = "Mythic";
    switch (difficulty)
    {
        case 1:
            selectedDifficulty = DUNGEON_DIFFICULTY_NORMAL;
            difficultyLabel = "Normal";
            break;
        case 2:
            selectedDifficulty = DUNGEON_DIFFICULTY_HEROIC;
            difficultyLabel = "Heroic";
            break;
        case 3:
        default:
            selectedDifficulty = DUNGEON_DIFFICULTY_EPIC;
            difficultyLabel = "Mythic";
            break;
    }

    player->SetDungeonDifficulty(selectedDifficulty);
    ChatHandler(player->GetSession()).SendSysMessage(
        Acore::StringFormat("|cff00ff00[Dungeon Portal]|r Teleporting to {} entrance...", difficultyLabel).c_str());

    TeleportToDungeonEntranceByDungeonMap(player, dungeonMapId);
    SendSeasonalPortalResult(player, true, "Teleporting...");
}
}

// Gossip menu actions
enum DifficultyGossipActions
{
    GOSSIP_ACTION_NORMAL  = 1,
    GOSSIP_ACTION_HEROIC  = 2,
    GOSSIP_ACTION_MYTHIC  = 3,
    GOSSIP_ACTION_INFO    = 4,
    GOSSIP_ACTION_CONFIRM_NORMAL = 5,
    GOSSIP_ACTION_CONFIRM_HEROIC = 6,
    GOSSIP_ACTION_CONFIRM_MYTHIC = 7
};

using namespace DungeonQuest;

// Level and item level requirements
struct DifficultyRequirements
{
    uint8 minLevel;
    uint32 minItemLevel;
};

// Get requirements based on expansion
DifficultyRequirements GetDifficultyRequirements(uint8 expansion, uint8 difficulty)
{
    DifficultyRequirements req;
    
    switch (expansion)
    {
        case EXPANSION_VANILLA:
            if (difficulty == DIFFICULTY_NORMAL)
            {
                req.minLevel = 55;
                req.minItemLevel = 0;
            }
            else if (difficulty == DIFFICULTY_HEROIC)
            {
                req.minLevel = 60;
                req.minItemLevel = 100;
            }
            else // Mythic
            {
                req.minLevel = 80;
                req.minItemLevel = 180;
            }
            break;
            
        case EXPANSION_TBC:
            if (difficulty == DIFFICULTY_NORMAL)
            {
                req.minLevel = 68;
                req.minItemLevel = 0;
            }
            else if (difficulty == DIFFICULTY_HEROIC)
            {
                req.minLevel = 70;
                req.minItemLevel = 120;
            }
            else // Mythic
            {
                req.minLevel = 80;
                req.minItemLevel = 180;
            }
            break;
            
        case EXPANSION_WOTLK:
            if (difficulty == DIFFICULTY_NORMAL)
            {
                req.minLevel = 78;
                req.minItemLevel = 0;
            }
            else if (difficulty == DIFFICULTY_HEROIC)
            {
                req.minLevel = 80;
                req.minItemLevel = 150;
            }
            else // Mythic
            {
                req.minLevel = 80;
                req.minItemLevel = 180;
            }
            break;
            
        default:
            req.minLevel = 1;
            req.minItemLevel = 0;
            break;
    }
    
    return req;
}

// Teleport player to dungeon using teleporter entry from eluna_teleporter table
void TeleportToDungeonEntrance(Player* player, uint32 teleporterEntryId)
{
    if (!player)
        return;
    
    // Query teleporter coordinates from eluna_teleporter table
    QueryResult result = WorldDatabase.Query(
        "SELECT map, x, y, z, o FROM eluna_teleporter WHERE id = {}", teleporterEntryId);

    if (!result)
    {
        ChatHandler(player->GetSession()).SendSysMessage(
            "Error: Teleporter coordinates not found in database.");
        LOG_ERROR("mythic.portal", "No teleporter entry found for ID {}", teleporterEntryId);
        return;
    }

    Field* fields = result->Fetch();
    uint32 mapId = fields[0].Get<uint32>();
    float x = fields[1].Get<float>();
    float y = fields[2].Get<float>();
    float z = fields[3].Get<float>();
    float o = fields[4].Get<float>();

    z += GetDungeonZOffset(mapId);

    // Teleport player to entrance
    if (player->TeleportTo(mapId, x, y, z, o))
    {
        ChatHandler(player->GetSession()).SendSysMessage(
            "|cff00ff00Teleporting to dungeon entrance...|r");
        LOG_INFO("mythic.portal", "Player {} teleported via teleporter entry {}",
            player->GetName(), teleporterEntryId);
    }
    else
    {
        ChatHandler(player->GetSession()).SendSysMessage(
            "Error: Failed to teleport to dungeon entrance.");
        LOG_ERROR("mythic.portal", "Failed to teleport player {} via entry {}",
            player->GetName(), teleporterEntryId);
    }
}

// Generic portal creature script for all dungeon entrances
class npc_dungeon_portal_selector : public CreatureScript
{
public:
    npc_dungeon_portal_selector() : CreatureScript("npc_dungeon_portal_selector") { }

    struct npc_dungeon_portal_selectorAI : public ScriptedAI
    {
        npc_dungeon_portal_selectorAI(Creature* creature) : ScriptedAI(creature) { }

        void Reset() override
        {
            // Ensure portal is always visible regardless of difficulty
            // Portals spawn in the world (not in dungeons) so they should always be visible
            me->SetPhaseMask(1, true);
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_dungeon_portal_selectorAI(creature);
    }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (!player || !creature)
            return false;

        bool protocolEnabled = sConfigMgr->GetOption<bool>("DC.AddonProtocol.MythicPlus.Enable", true);
        static bool didLogMissingAutoOpenConfigOnce = false;
        bool autoOpenUi = sConfigMgr->GetOption<int32>(
            "DC.MythicPlus.AddonUI.AutoOpen",
            1,
            !didLogMissingAutoOpenConfigOnce) != 0;
        didLogMissingAutoOpenConfigOnce = true;
        if (protocolEnabled && autoOpenUi)
        {
            PortalUiSession session;
            session.creatureGuid = creature->GetGUID();
            session.expiresAt = time(nullptr) + PORTAL_UI_SESSION_SECONDS;
            s_portalUiSessions[player->GetGUID().GetCounter()] = session;
            SendSeasonalPortalOpen(player);
            CloseGossipMenuFor(player);
            return true;
        }

        ClearGossipMenuFor(player);
        
        // Show dungeon selection menu - using teleporter entry IDs
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
            "|cffff8000=== Select Mythic+ Dungeon ===|r", 
            GOSSIP_SENDER_MAIN, 0);
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", 
            GOSSIP_SENDER_MAIN, 0);

        // Addon UI entry (recommended)
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff32c4ff[UI]|r Open Seasonal Dungeon Portal UI", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_OPEN_SEASONAL_UI);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", GOSSIP_SENDER_MAIN, 0);
        
        // WotLK Dungeons - use teleporter entry IDs from eluna_teleporter table
        for (auto const& option : kDungeonTeleporterOptions)
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, option.label, GOSSIP_SENDER_MAIN, option.entryId);
        
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
    {
        if (!player || !creature)
            return false;

        ClearGossipMenuFor(player);

        if (action == GOSSIP_ACTION_OPEN_SEASONAL_UI)
        {
            PortalUiSession session;
            session.creatureGuid = creature->GetGUID();
            session.expiresAt = time(nullptr) + PORTAL_UI_SESSION_SECONDS;
            s_portalUiSessions[player->GetGUID().GetCounter()] = session;
            SendSeasonalPortalOpen(player);
            CloseGossipMenuFor(player);
            return true;
        }

        // If action is 0, just close (was a header)
        if (action == 0)
        {
            CloseGossipMenuFor(player);
            return true;
        }

        // If sender is MAIN, this is dungeon selection - show difficulty menu
        if (sender == GOSSIP_SENDER_MAIN && IsMythicDungeonTeleporter(action))
        {
            // Store selected teleporter entry in sender for next step
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                "|cffff8000=== Select Difficulty ===|r", 
                action, 0);
            
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", action, 0);
            
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, 
                "|cffffffff[Normal]|r - Base difficulty", 
                action, GOSSIP_ACTION_NORMAL);
            
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, 
                "|cff0070ff[Heroic]|r - +15% HP/Damage", 
                action, GOSSIP_ACTION_HEROIC);
            
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, 
                "|cffff8000[Mythic]|r - Mythic+ difficulty", 
                action, GOSSIP_ACTION_MYTHIC);
            
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
            return true;
        }

        // Sender now contains the teleporter entry ID, action is the difficulty
        uint32 teleporterEntryId = sender;
        
        Difficulty selectedDifficulty = DUNGEON_DIFFICULTY_NORMAL;
        const char* difficultyLabel = "|cffffffffNormal|r";

        switch (action)
        {
            case GOSSIP_ACTION_NORMAL:
                selectedDifficulty = DUNGEON_DIFFICULTY_NORMAL;
                difficultyLabel = "|cffffffffNormal|r";
                break;
            case GOSSIP_ACTION_HEROIC:
                selectedDifficulty = DUNGEON_DIFFICULTY_HEROIC;
                difficultyLabel = "|cff0070ffHeroic|r";
                break;
            case GOSSIP_ACTION_MYTHIC:
                selectedDifficulty = DUNGEON_DIFFICULTY_EPIC;
                difficultyLabel = "|cffff8000Mythic|r";
                break;
            default:
                break;
        }

        player->SetDungeonDifficulty(selectedDifficulty);
        std::string message = "|cff00ff00[Dungeon Portal]|r Teleporting to " + std::string(difficultyLabel) + " entrance...";
        ChatHandler(player->GetSession()).SendSysMessage(message.c_str());
        
        // Teleport player after setting difficulty
        TeleportToDungeonEntrance(player, teleporterEntryId);
        
        CloseGossipMenuFor(player);
        return true;
    }
};

void AddSC_dungeon_portal_selector()
{
    new npc_dungeon_portal_selector();

    bool enabled = sConfigMgr->GetOption<bool>("DC.AddonProtocol.MythicPlus.Enable", true);
    if (enabled)
    {
        DCAddon::MessageRouter::Instance().RegisterHandler(DCAddon::Module::MYTHIC_PLUS, DCAddon::Opcode::MPlus::CMSG_SEASONAL_PORTAL_TELEPORT, HandleSeasonalPortalTeleport);
    }
}
