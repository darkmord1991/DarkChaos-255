// -----------------------------------------------------------------------------
// hlbg_queue_handlers.cpp
// -----------------------------------------------------------------------------
// Queue command handlers for the HLBG controller.
// (Renamed from OutdoorPvPHL_Commands.cpp to avoid confusion with CommandScripts.)
// -----------------------------------------------------------------------------
#include "hlbg.h"
#include "Player.h"
#include "Chat.h"
#include "ScriptMgr.h"
#include "Config.h"
#include "hlbg_constants.h"
#include "ObjectAccessor.h"
#include "Group.h"

// Player command handlers
void OutdoorPvPHL::HandleQueueJoinCommand(Player* player)
{
    if (!player)
        return;

    // Basic eligibility checks
    if (!IsMaxLevel(player))
    {
        ChatHandler(player->GetSession()).PSendSysMessage("HLBG Queue: You must be at least level {} to join.", _minLevel);
        return;
    }

    if (player->HasAura(HinterlandBGConstants::BG_DESERTER_SPELL)) // Deserter debuff
    {
        ChatHandler(player->GetSession()).PSendSysMessage("HLBG Queue: You cannot join while flagged as deserter.");
        return;
    }

    if (!player->IsAlive())
    {
        ChatHandler(player->GetSession()).PSendSysMessage("HLBG Queue: You must be alive to join the queue.");
        return;
    }

    if (player->IsInCombat())
    {
        ChatHandler(player->GetSession()).PSendSysMessage("HLBG Queue: You cannot join while in combat.");
        return;
    }

    // Check if queue is enabled
    if (!_queueEnabled)
    {
        ChatHandler(player->GetSession()).PSendSysMessage("HLBG Queue: Queue system is currently disabled.");
        return;
    }

    // Add player to queue
    AddPlayerToQueue(player);
}

void OutdoorPvPHL::HandleQueueLeaveCommand(Player* player)
{
    if (!player)
        return;

    RemovePlayerFromQueue(player);
}

void OutdoorPvPHL::HandleQueueStatusCommand(Player* player)
{
    if (!player)
        return;

    ShowQueueStatus(player);
}

void OutdoorPvPHL::HandleGroupQueueJoinCommand(Player* player)
{
    if (!player)
        return;

    // Basic eligibility checks first
    if (!IsMaxLevel(player))
    {
        ChatHandler(player->GetSession()).PSendSysMessage("HLBG Queue: You must be at least level {} to join.", _minLevel);
        return;
    }

    if (!_queueEnabled)
    {
        ChatHandler(player->GetSession()).PSendSysMessage("HLBG Queue: Queue system is currently disabled.");
        return;
    }

    AddGroupToQueue(player);
}

void OutdoorPvPHL::HandleGroupQueueLeaveCommand(Player* player)
{
    if (!player)
        return;

    RemoveGroupFromQueue(player);
}

// Admin command helpers
void OutdoorPvPHL::HandleAdminQueueClear(Player* admin)
{
    if (!admin)
        return;

    uint32 clearedCount = GetQueuedPlayerCount();
    ClearQueue();

    ChatHandler(admin->GetSession()).PSendSysMessage("HLBG Admin: Cleared {} players from queue.", clearedCount);
    LOG_INFO("bg.battleground", "HLBG: Admin {} cleared queue ({} players)", admin->GetName(), clearedCount);
}

void OutdoorPvPHL::HandleAdminQueueList(Player* admin)
{
    if (!admin)
        return;

    ChatHandler ch(admin->GetSession());
    ch.PSendSysMessage("=== HLBG Queue List (Admin) ===");

    if (GetQueuedPlayerCount() == 0)
    {
        ch.PSendSysMessage("Queue is empty.");
        return;
    }

    uint32 position = 1;
    for (const QueueEntry& entry : _queuedPlayers)
    {
        if (!entry.active)
            continue;

        Player* queuedPlayer = ObjectAccessor::FindConnectedPlayer(entry.playerGuid);
        std::string playerName = queuedPlayer ? queuedPlayer->GetName() : "Offline";
        std::string teamName = (entry.teamId == TEAM_ALLIANCE) ? "Alliance" : "Horde";
        uint32 waitTime = GameTime::GetGameTime().count() - entry.joinTime;

        ch.PSendSysMessage("{}. {} ({}) - {} seconds", position, playerName.c_str(), teamName.c_str(), waitTime);
        position++;
    }
}

void OutdoorPvPHL::HandleAdminForceWarmup(Player* admin)
{
    if (!admin)
        return;

    if (_bgState != BG_STATE_CLEANUP)
    {
    ChatHandler(admin->GetSession()).PSendSysMessage("HLBG Admin: Can only force warmup from cleanup state. Current state: {}", static_cast<uint32>(_bgState));
        return;
    }

    if (GetQueuedPlayerCount() == 0)
    {
        ChatHandler(admin->GetSession()).PSendSysMessage("HLBG Admin: No players in queue to start warmup with.");
        return;
    }

    StartWarmupPhase();
    ChatHandler(admin->GetSession()).PSendSysMessage("HLBG Admin: Forced warmup phase start with {} queued players.", GetQueuedPlayerCount());
    LOG_INFO("bg.battleground", "HLBG: Admin {} forced warmup start", admin->GetName());
}

void OutdoorPvPHL::HandleAdminQueueConfig(Player* admin, const char* setting, const char* value)
{
    if (!admin || !setting)
        return;

    ChatHandler ch(admin->GetSession());
    std::string settingStr = setting;

    if (settingStr == "enabled")
    {
        if (value)
        {
            bool newEnabled = (std::string(value) == "1" || std::string(value) == "true" || std::string(value) == "on");
            _queueEnabled = newEnabled;
            ch.PSendSysMessage("HLBG Admin: Queue enabled = {}", _queueEnabled ? "true" : "false");
        }
        else
        {
            ch.PSendSysMessage("HLBG Admin: Queue enabled = {}", _queueEnabled ? "true" : "false");
        }
    }
    else if (settingStr == "minplayers")
    {
        if (value)
        {
            uint32 newMin = static_cast<uint32>(std::strtoul(value, nullptr, 10));
            if (newMin > 0 && newMin <= 40)
            {
                    _minPlayersToStart = newMin;
                    ch.PSendSysMessage("HLBG Admin: Minimum players to start = {}", _minPlayersToStart);
            }
            else
            {
                ch.PSendSysMessage("HLBG Admin: Invalid value. Must be between 1 and 40.");
            }
        }
        else
        {
            ch.PSendSysMessage("HLBG Admin: Minimum players to start = {}", _minPlayersToStart);
        }
    }
    else if (settingStr == "maxgroupsize")
    {
        if (value)
        {
            uint32 newMax = static_cast<uint32>(std::strtoul(value, nullptr, 10));
            if (newMax > 0 && newMax <= 40)
            {
                    _maxGroupSize = newMax;
                    ch.PSendSysMessage("HLBG Admin: Maximum group size = {}", _maxGroupSize);
            }
            else
            {
                ch.PSendSysMessage("HLBG Admin: Invalid value. Must be between 1 and 40.");
            }
        }
        else
        {
            ch.PSendSysMessage("HLBG Admin: Maximum group size = {}", _maxGroupSize);
        }
    }
    else
    {
        ch.PSendSysMessage("HLBG Admin: Available settings: enabled, minplayers, maxgroupsize");
    }
}

// Integration with existing command system
bool OutdoorPvPHL::HandlePlayerCommand(Player* player, const std::string& command, const std::string& args)
{
    if (!player)
        return false;

    // Handle queue-related commands
    if (command == "queue")
    {
        if (args == "join")
        {
            HandleQueueJoinCommand(player);
            return true;
        }
        else if (args == "leave")
        {
            HandleQueueLeaveCommand(player);
            return true;
        }
        else if (args == "status" || args.empty())
        {
            HandleQueueStatusCommand(player);
            return true;
        }
        else if (args == "group_join")
        {
            HandleGroupQueueJoinCommand(player);
            return true;
        }
        else if (args == "group_leave")
        {
            HandleGroupQueueLeaveCommand(player);
            return true;
        }
    }

    return false; // Command not handled
}

bool OutdoorPvPHL::HandleAdminCommand(Player* admin, const std::string& command, const std::string& args)
{
    if (!admin)
        return false;

    // Handle admin queue commands
    if (command == "queue_admin")
    {
        if (args == "clear")
        {
            HandleAdminQueueClear(admin);
            return true;
        }
        else if (args == "list")
        {
            HandleAdminQueueList(admin);
            return true;
        }
        else if (args == "force_warmup")
        {
            HandleAdminForceWarmup(admin);
            return true;
        }
        else if (args.find("config") == 0)
        {
            // Parse config command: config <setting> [value]
            std::string configArgs = args.substr(6); // Remove "config"
            // Trim leading whitespace (args is usually "config <setting> [value]")
            configArgs.erase(0, configArgs.find_first_not_of(" \t"));
            if (configArgs.empty())
            {
                HandleAdminQueueConfig(admin, "", "");
                return true;
            }

            std::size_t spacePos = configArgs.find(' ');
            if (spacePos != std::string::npos)
            {
                std::string setting = configArgs.substr(0, spacePos);
                std::string value = configArgs.substr(spacePos + 1);
                value.erase(0, value.find_first_not_of(" \t"));
                HandleAdminQueueConfig(admin, setting.c_str(), value.c_str());
            }
            else
            {
                HandleAdminQueueConfig(admin, configArgs.c_str(), nullptr);
            }
            return true;
        }
    }

    return false; // Command not handled
}
