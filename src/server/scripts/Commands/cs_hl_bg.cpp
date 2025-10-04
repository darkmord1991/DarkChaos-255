#include "ScriptMgr.h"
#include "Chat.h"
#include "CommandScript.h"
#include <string>
#include "Group.h"
#include "GroupMgr.h"
#include "Player.h"
#include "OutdoorPvP/OutdoorPvPMgr.h"
#include "OutdoorPvP/OutdoorPvPHL.h"
#include <sstream>
#include <algorithm>
#include "DatabaseEnv.h"
#include <cmath>

/*
 * hlbg_commandscript
 * ------------------
 * Provides GM/admin commands to inspect and manage the Hinterland (zone 47)
 * outdoor battleground state.
 *
 * Commands (quick reference):
 *   .hlbg status               Show timer/resources + raid groups
 *   .hlbg get <alliance|horde> Show resources for a team
 *   .hlbg set <team> <amt>     Set resources for a team (GM-only); action is audited
 *   .hlbg reset                Force-reset the Hinterland match; action is audited
 *
 * Audit logging: administrative actions (.hlbg set/.hlbg reset) are logged to
 * the server log under the `admin.hlbg` category with the GM name and GUID.
 * Log format: "[ADMIN] <name> (GUID:<low>) <action>". This is intended for
 * lightweight operational audit trails; maintainers may redirect or persist
 * these messages to a centralized logging system if desired.
 *
 * Note: On timer expiry the match auto-resets (teleport to start GYs, then respawn and HUD refresh) and restarts. If you’d like a
 * tiebreaker or special rewards for equal resources at expiry, see
 * `OutdoorPvPHL.cpp` for where to inject that logic.
 */

using namespace Acore::ChatCommands;

class hlbg_commandscript : public CommandScript
{
public:
    hlbg_commandscript() : CommandScript("hlbg_commandscript") {}

    ChatCommandTable GetCommands() const override
    {
        // ChatCommandTable usage
        // ----------------------
        // A ChatCommandTable is a simple vector-of-entries that the command
        // dispatch system converts into a tree. Each entry below registers
        // a subcommand name, a handler function, the required security level
        // and whether the console may execute it. Help text may be provided
        // via other overloads; for these simple admin commands we rely on the
        // top-level help and the explicit usage strings in the handlers.

        // Notes for maintainers:
        // - The handler signatures in this file use the legacy
        //   `bool(ChatHandler*, char const*)` form which is compatible with
        //   the CommandInvoker wrapper. Newer commands may use typed
        //   argument parsing and different handler signatures.

        static ChatCommandTable hlbgCommandTable =
        {
            { "status", HandleHLBGStatusCommand, SEC_GAMEMASTER, Console::No },
            { "get",    HandleHLBGGetCommand,    SEC_GAMEMASTER, Console::No },
            { "set",    HandleHLBGSetCommand,    SEC_GAMEMASTER, Console::No },
            { "reset",  HandleHLBGResetCommand,  SEC_GAMEMASTER, Console::No },
            { "history",HandleHLBGHistoryCommand,SEC_GAMEMASTER, Console::No },
            { "statsmanual",HandleHLBGStatsManualCommand,SEC_GAMEMASTER, Console::No },
            { "affix",  HandleHLBGAffixCommand,  SEC_GAMEMASTER, Console::No },
            { "config", HandleHLBGConfigCommand, SEC_GAMEMASTER, Console::No },
            { "stats",  HandleHLBGStatsCommand,  SEC_GAMEMASTER, Console::No },
            { "season", HandleHLBGSeasonCommand, SEC_GAMEMASTER, Console::No },
            { "players",HandleHLBGPlayersCommand,SEC_GAMEMASTER, Console::No },
        };

        static ChatCommandTable commandTable =
        {
            { "hlbg", hlbgCommandTable }
        };

        return commandTable;
    }
    static bool HandleHLBGStatsManualCommand(ChatHandler* handler, char const* args)
    {
        // Usage: .hlbg statsmanual on|off
        bool set = true; // default on if unspecified
        if (args && *args)
        {
            std::string v(args);
            std::transform(v.begin(), v.end(), v.begin(), ::tolower);
            set = (v == "on" || v == "1" || v == "true");
        }
        if (OutdoorPvP* out = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(OutdoorPvPHLBuffZones[0]))
        {
            if (OutdoorPvPHL* hl = dynamic_cast<OutdoorPvPHL*>(out))
            {
                hl->SetStatsIncludeManualResets(set);
                handler->PSendSysMessage("Stats will %sinclude manual resets.", set ? "" : "not ");
                return true;
            }
        }
        handler->PSendSysMessage("Hinterland BG instance not found.");
        return false;
    }

    static bool HandleHLBGStatusCommand(ChatHandler* handler, char const* /*args*/)
    {
        // Show current match timer/resources and active raid groups for both factions.
        // This command works from anywhere (no zone restriction).

    handler->PSendSysMessage("|cffffd700Hinterland BG status:|r");

        // Fetch the HL controller
        OutdoorPvPHL* hl = nullptr;
        if (OutdoorPvP* out = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(OutdoorPvPHLBuffZones[0]))
            hl = dynamic_cast<OutdoorPvPHL*>(out);

        if (hl)
        {
            uint32 secs = hl->GetTimeRemainingSeconds();
            uint32 min = secs / 60u;
            uint32 sec = secs % 60u;
            uint32 a = hl->GetResources(TEAM_ALLIANCE);
            uint32 h = hl->GetResources(TEAM_HORDE);
            handler->PSendSysMessage("  Time remaining: {:02}:{:02}", min, sec);
            handler->PSendSysMessage("  Resources: |cff1e90ffAlliance|r={}, |cffff0000Horde|r={}", a, h);
            // Show current affix for clarity regardless of announcement toggles
            uint8 aff = hl->GetActiveAffixCode();
            if (aff > 0)
            {
                const char* aname = "None";
                switch (aff)
                {
                    case 1: aname = "Haste"; break;
                    case 2: aname = "Slow"; break;
                    case 3: aname = "Reduced Healing"; break;
                    case 4: aname = "Reduced Armor"; break;
                    case 5: aname = "Boss Enrage"; break;
                    default: aname = "None"; break;
                }
                handler->PSendSysMessage("  Affix: {}", aname);
            }
        }
        else
        {
            handler->PSendSysMessage("  (Hinterland controller not active)");
        }

        handler->PSendSysMessage("  Raid groups:");

        for (uint8 team = TEAM_ALLIANCE; team <= TEAM_HORDE; ++team)
        {
            std::string teamName = (team == TEAM_ALLIANCE) ? "|cff1e90ffAlliance|r" : "|cffff0000Horde|r";
            handler->PSendSysMessage("    Team: {}", teamName);

            // Query the OutdoorPvP manager for the Hinterland instance.
            // We look it up by the buff-zone constant exported from
            // `OutdoorPvPHL.h` (the script that implements Hinterland's logic).
            // The dynamic_cast ensures we only call HL-specific helpers when
            // the zone script is present and matches the expected type.
            std::vector<ObjectGuid> const* groupsPtr = nullptr;
            if (OutdoorPvP* out = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(OutdoorPvPHLBuffZones[0]))
            {
                if (OutdoorPvPHL* hl = dynamic_cast<OutdoorPvPHL*>(out))
                    groupsPtr = &hl->GetBattlegroundGroupGUIDs((TeamId)team);
            }

            if (!groupsPtr || groupsPtr->empty())
            {
                handler->PSendSysMessage("      (no battleground raid groups)");
                continue;
            }

            for (auto const& gid : *groupsPtr)
            {
                Group* g = sGroupMgr->GetGroupByGUID(gid.GetCounter());
                if (!g)
                {
                    handler->PSendSysMessage("      Group {}: (stale)", gid.GetCounter());
                    continue;
                }
                    handler->PSendSysMessage("      Group {}: members={}", g->GetGUID().GetCounter(), g->GetMembersCount());
            }
        }
        return true;
    }

    static bool HandleHLBGGetCommand(ChatHandler* handler, char const* args)
    {
        // Purpose: show the current resource counter for the requested team.
        //
        // Usage: .hlbg get alliance|horde
        // Inputs: `args` should contain the team name. Handler will respond
        // with a usage message if args are missing or malformed.
        // Outputs: PSysMessage showing the requested team's resources.

        if (!args || !*args)
        {
        handler->PSendSysMessage("Usage: .hlbg get alliance|horde");
            return false;
        }
        std::string team(args);
        std::transform(team.begin(), team.end(), team.begin(), ::tolower);
        TeamId tid = (team == "alliance") ? TEAM_ALLIANCE : TEAM_HORDE;
        uint32 res = 0;
            if (OutdoorPvP* out = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(OutdoorPvPHLBuffZones[0]))
        {
            if (OutdoorPvPHL* hl = dynamic_cast<OutdoorPvPHL*>(out))
                res = hl->GetResources(tid);
        }
        std::string colored = (tid == TEAM_ALLIANCE) ? "|cff1e90ffAlliance|r" : "|cffff0000Horde|r";
        handler->PSendSysMessage("{} resources: {}", colored, res);
        return true;
    }

    static bool HandleHLBGSetCommand(ChatHandler* handler, char const* args)
    {
        // Purpose: allow a GM to set a team's resource counter (audit-logged).
        //
        // Usage: .hlbg set alliance|horde <amount>
        // Inputs: `args` parsed into team and numeric amount. No further
        // validation is performed here (amount is taken as an unsigned 32-bit
        // value). Consider clamping or validating ranges if needed.
        // Outputs: sets the resource counter via the `OutdoorPvPHL` API and
        // emits an audit log line under the `admin.hlbg` category.
        // Error modes: returns false / prints usage when args are missing.

        if (!args || !*args)
        {
            handler->PSendSysMessage("Usage: .hlbg set alliance|horde <amount>");
            return false;
        }
        std::string in(args);
        std::istringstream iss(in);
        std::string teamStr;
        uint32 amount;
        iss >> teamStr >> amount;
        std::transform(teamStr.begin(), teamStr.end(), teamStr.begin(), ::tolower);
        TeamId tid = (teamStr == "alliance") ? TEAM_ALLIANCE : TEAM_HORDE;
        uint32 prev = 0;
    if (OutdoorPvP* out = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(OutdoorPvPHLBuffZones[0]))
        {
            if (OutdoorPvPHL* hl = dynamic_cast<OutdoorPvPHL*>(out))
            {
                // Capture previous value for audit trail, then set new amount.
                prev = hl->GetResources(tid);
                hl->SetResources(tid, amount);
            }
        }
        // Audit log with previous value
        // Record the administrative action to the server log. The category
        // `admin.hlbg` is used to make it easy to filter these entries for
        // operational auditing. The message includes the GM name and low GUID
        // as a compact identity marker.
        if (Player* admin = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr)
            LOG_INFO("admin.hlbg", "[ADMIN] {} (GUID:{}) set {} resources from {} -> {}", admin->GetName(), admin->GetGUID().GetCounter(), teamStr, prev, amount);
        std::string colored = (tid == TEAM_ALLIANCE) ? "|cff1e90ffAlliance|r" : "|cffff0000Horde|r";
        handler->PSendSysMessage("Set {} resources to {}", colored, amount);
        return true;
    }

    static bool HandleHLBGResetCommand(ChatHandler* handler, char const* /*args*/)
    {
        // Purpose: force the Hinterland match into its reset state. This is a
        // powerful operation and is therefore logged to `admin.hlbg`.
        //
        // Usage: .hlbg reset
        // Inputs: no args; acts on the Hinterland OutdoorPvP instance if present.
        // Outputs: calls `ForceReset()` on the HL instance and logs the action.

    if (OutdoorPvP* out = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(OutdoorPvPHLBuffZones[0]))
        {
            if (OutdoorPvPHL* hl = dynamic_cast<OutdoorPvPHL*>(out))
            {
                // Before resetting, persist a 'manual' reset entry (no winner, capture current scores)
                uint32 a = hl->GetResources(TEAM_ALLIANCE);
                uint32 h = hl->GetResources(TEAM_HORDE);
                uint32 mapId = 0;
                if (Player* admin = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr)
                    if (Map* m = admin->GetMap()) mapId = m->GetId();
                uint32 dur = hl->GetCurrentMatchDurationSeconds();
                uint32 season = hl->GetSeason();
                    // Column order: zone_id, map_id, season, winner_tid, score_alliance, score_horde, win_reason, affix, weather, weather_intensity, duration_seconds
                    // Ensure placeholders align so win_reason receives the quoted string 'manual'
                    CharacterDatabase.Execute(
                        "INSERT INTO hlbg_winner_history (zone_id, map_id, season, winner_tid, score_alliance, score_horde, win_reason, affix, weather, weather_intensity, duration_seconds) VALUES({}, {}, {}, {}, {}, {}, '{}', {}, {}, {}, {})",
                        OutdoorPvPHLBuffZones[0], mapId, season, uint8(TEAM_NEUTRAL), a, h, "manual", 0, 0, 0.0f, dur);

                hl->ForceReset();
                // Teleport players back to start positions configured in the OutdoorPvP script
                hl->TeleportPlayersToStart();
                // Audit log
                if (Player* admin = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr)
                    LOG_INFO("admin.hlbg", "[ADMIN] {} (GUID:{}) forced a Hinterland BG reset", admin->GetName(), admin->GetGUID().GetCounter());
                handler->PSendSysMessage("Hinterland BG forced reset executed.");
                return true;
            }
        }
        handler->PSendSysMessage("Hinterland BG instance not found.");
        return false;
    }

    static bool HandleHLBGHistoryCommand(ChatHandler* handler, char const* args)
    {
        // Usage: .hlbg history [count]
        // Default count = 10, max = 50
        uint32 count = 10;
        if (args && *args)
        {
            uint32 v = Acore::StringTo<uint32>(args).value_or(10);
            count = std::max<uint32>(1, std::min<uint32>(50, v));
        }
        QueryResult res = CharacterDatabase.Query("SELECT occurred_at, winner_tid, score_alliance, score_horde, win_reason FROM hlbg_winner_history ORDER BY id DESC LIMIT {}", count);
        if (!res)
        {
            handler->PSendSysMessage("No history found (apply Custom/Hinterland BG/CharDB/hlbg_winner_history.sql to the characters DB)");
            return true;
        }
        handler->PSendSysMessage("|cffffd700Hinterland BG recent results (latest {}):|r", count);
        do
        {
            Field* f = res->Fetch();
            std::string ts = f[0].Get<std::string>();
            uint8 tid = f[1].Get<uint8>();
            uint32 a = f[2].Get<uint32>();
            uint32 h = f[3].Get<uint32>();
            std::string reason = f[4].Get<std::string>();
            const char* name = (tid == TEAM_ALLIANCE ? "Alliance" : (tid == TEAM_HORDE ? "Horde" : "Draw"));
            handler->PSendSysMessage("  [{}] {}  A:{} H:{}  ({})", ts, name, a, h, reason);
        }
        while (res->NextRow());
        return true;
    }

    static bool HandleHLBGAffixCommand(ChatHandler* handler, char const* /*args*/)
    {
        OutdoorPvPHL* hl = nullptr;
        if (OutdoorPvP* out = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(OutdoorPvPHLBuffZones[0]))
            hl = dynamic_cast<OutdoorPvPHL*>(out);
        if (!hl)
        {
            handler->PSendSysMessage("Hinterland BG instance not found.");
            return false;
        }

        uint8 code = hl->GetActiveAffixCode();
        const char* name = "None";
        switch (code)
        {
            case 1: name = "Haste"; break;
            case 2: name = "Slow"; break;
            case 3: name = "Reduced Healing"; break;
            case 4: name = "Reduced Armor"; break;
            case 5: name = "Boss Enrage"; break;
            default: break;
        }
        handler->PSendSysMessage("|cffffd700Hinterland BG affix:|r {} ({})", name, (unsigned)code);
        handler->PSendSysMessage("  Enabled: {}  Weather: {}  Worldstate: {}  Announce: {}",
            hl->IsAffixEnabled()?"on":"off",
            hl->IsAffixWeatherEnabled()?"on":"off",
            hl->IsAffixWorldstateEnabled()?"on":"off",
            hl->IsAffixAnnounceEnabled()?"on":"off");
        handler->PSendSysMessage("  Random on start: {}  Periodic rotation: {}s  Next change at epoch: {}",
            hl->IsAffixRandomOnStart()?"on":"off", (unsigned)hl->GetAffixPeriodSec(), (unsigned)hl->GetAffixNextChangeEpoch());
        // Show configured spells and weather for the current code
        if (code > 0)
        {
            uint32 pspell = hl->GetAffixPlayerSpell(code);
            uint32 nspell = hl->GetAffixNpcSpell(code);
            uint32 wtype  = hl->GetAffixWeatherType(code);
            float  wint   = hl->GetAffixWeatherIntensity(code);
            // Friendly weather label (0 Fine, 1 Rain, 2 Snow, 3 Storm); default intensity 0.50 when unset
            const char* wname = "Fine";
            switch (wtype)
            {
                case 1: wname = "Rain"; break;
                case 2: wname = "Snow"; break;
                case 3: wname = "Storm"; break;
                default: wname = "Fine"; break;
            }
            if (wint <= 0.0f) wint = 0.50f;
            uint32 ipct = (uint32)std::lround(wint * 100.0f);
            handler->PSendSysMessage("  Player spell: {}  NPC spell: {}  Weather: {} ({}, {}%)",
                (unsigned)pspell, (unsigned)nspell, wname, (unsigned)wtype, (unsigned)ipct);
        }
        return true;
    }

    // Enhanced HLBG Configuration Command
    static bool HandleHLBGConfigCommand(ChatHandler* handler, char const* args)
    {
        if (!args || !*args)
        {
            // Display current configuration
            QueryResult result = WorldDatabase.Query("SELECT duration_minutes, max_players_per_side, min_level, max_level, affix_rotation_enabled, resource_cap, queue_type, is_active FROM hlbg_config ORDER BY id DESC LIMIT 1");
            
            if (result)
            {
                Field* fields = result->Fetch();
                handler->PSendSysMessage("=== HLBG Enhanced Configuration ===");
                handler->PSendSysMessage("Duration: {} minutes", fields[0].GetUInt32());
                handler->PSendSysMessage("Max Players Per Side: {}", fields[1].GetUInt32());
                handler->PSendSysMessage("Level Range: {}-{}", fields[2].GetUInt32(), fields[3].GetUInt32());
                handler->PSendSysMessage("Affix Rotation: {}", fields[4].GetBool() ? "Enabled" : "Disabled");
                handler->PSendSysMessage("Resource Cap: {}", fields[5].GetUInt32());
                handler->PSendSysMessage("Queue Type: {}", fields[6].GetString());
                handler->PSendSysMessage("Status: {}", fields[7].GetBool() ? "Active" : "Inactive");
            }
            else
            {
                handler->SendSysMessage("No enhanced HLBG configuration found! Run the database schema first.");
            }
            return true;
        }

        char* setting = strtok((char*)args, " ");
        char* value = strtok(nullptr, " ");

        if (!setting || !value)
        {
            handler->SendSysMessage("Usage: .hlbg config [duration|maxplayers|resources|affix|active] [value]");
            return false;
        }

        std::string settingStr = setting;
        std::string valueStr = value;
        std::transform(settingStr.begin(), settingStr.end(), settingStr.begin(), ::tolower);

        if (settingStr == "duration")
        {
            uint32 minutes = atoi(value);
            if (minutes < 5 || minutes > 120)
            {
                handler->SendSysMessage("Duration must be between 5 and 120 minutes");
                return false;
            }
            WorldDatabase.PExecute("UPDATE hlbg_config SET duration_minutes = {}, updated_by = '{}' ORDER BY id DESC LIMIT 1", minutes, handler->GetSession()->GetPlayer()->GetName());
            handler->PSendSysMessage("HLBG duration set to {} minutes", minutes);
        }
        else if (settingStr == "maxplayers")
        {
            uint32 players = atoi(value);
            if (players < 10 || players > 100)
            {
                handler->SendSysMessage("Max players must be between 10 and 100 per side");
                return false;
            }
            WorldDatabase.PExecute("UPDATE hlbg_config SET max_players_per_side = {}, updated_by = '{}' ORDER BY id DESC LIMIT 1", players, handler->GetSession()->GetPlayer()->GetName());
            handler->PSendSysMessage("HLBG max players per side set to {}", players);
        }
        else if (settingStr == "resources")
        {
            uint32 resources = atoi(value);
            if (resources < 100 || resources > 2000)
            {
                handler->SendSysMessage("Resource cap must be between 100 and 2000");
                return false;
            }
            WorldDatabase.PExecute("UPDATE hlbg_config SET resource_cap = {}, updated_by = '{}' ORDER BY id DESC LIMIT 1", resources, handler->GetSession()->GetPlayer()->GetName());
            handler->PSendSysMessage("HLBG resource cap set to {}", resources);
        }
        else if (settingStr == "affix")
        {
            bool enabled = (valueStr == "on" || valueStr == "true" || valueStr == "1");
            WorldDatabase.PExecute("UPDATE hlbg_config SET affix_rotation_enabled = {}, updated_by = '{}' ORDER BY id DESC LIMIT 1", enabled, handler->GetSession()->GetPlayer()->GetName());
            handler->PSendSysMessage("HLBG affix rotation {}", enabled ? "enabled" : "disabled");
        }
        else if (settingStr == "active")
        {
            bool active = (valueStr == "on" || valueStr == "true" || valueStr == "1");
            WorldDatabase.PExecute("UPDATE hlbg_config SET is_active = {}, updated_by = '{}' ORDER BY id DESC LIMIT 1", active, handler->GetSession()->GetPlayer()->GetName());
            handler->PSendSysMessage("HLBG {}", active ? "activated" : "deactivated");
        }
        else
        {
            handler->SendSysMessage("Unknown setting. Available: duration, maxplayers, resources, affix, active");
            return false;
        }

        return true;
    }

    // Enhanced HLBG Statistics Command
    static bool HandleHLBGStatsCommand(ChatHandler* handler, char const* args)
    {
        if (args && *args && strcmp(args, "reset") == 0)
        {
            // Reset all statistics
            WorldDatabase.PExecute("UPDATE hlbg_statistics SET total_runs = 0, alliance_wins = 0, horde_wins = 0, draws = 0, manual_resets = manual_resets + 1, current_streak_faction = 'None', current_streak_count = 0, avg_run_time_seconds = 0, shortest_run_seconds = 0, longest_run_seconds = 0, total_players_participated = 0, total_kills = 0, total_deaths = 0, last_reset_by_gm = NOW(), last_reset_gm_name = '{}' ORDER BY id DESC LIMIT 1", handler->GetSession()->GetPlayer()->GetName());
            
            handler->SendSysMessage("Enhanced HLBG statistics have been reset!");
            
            // Record in battle history
            WorldDatabase.PExecute("INSERT INTO hlbg_battle_history (battle_end, winner_faction, duration_seconds, ended_by_gm, gm_name, notes) VALUES (NOW(), 'Draw', 0, 1, '{}', 'Statistics reset by GM')", handler->GetSession()->GetPlayer()->GetName());
            
            return true;
        }

        // Display current enhanced statistics
        QueryResult result = WorldDatabase.Query("SELECT total_runs, alliance_wins, horde_wins, draws, manual_resets, current_streak_faction, current_streak_count, longest_streak_faction, longest_streak_count, avg_run_time_seconds, total_players_participated, total_kills, total_deaths, last_reset_gm_name, last_reset_by_gm FROM hlbg_statistics ORDER BY id DESC LIMIT 1");
        
        if (result)
        {
            Field* fields = result->Fetch();
            handler->PSendSysMessage("=== Enhanced HLBG Statistics ===");
            handler->PSendSysMessage("Total Battles: {}", fields[0].GetUInt32());
            handler->PSendSysMessage("Alliance Wins: {} | Horde Wins: {} | Draws: {}", fields[1].GetUInt32(), fields[2].GetUInt32(), fields[3].GetUInt32());
            handler->PSendSysMessage("Manual Resets: {}", fields[4].GetUInt32());
            handler->PSendSysMessage("Current Streak: {} ({})", fields[5].GetString(), fields[6].GetUInt32());
            handler->PSendSysMessage("Longest Streak: {} ({})", fields[7].GetString(), fields[8].GetUInt32());
            handler->PSendSysMessage("Avg Battle Time: {}s", fields[9].GetUInt32());
            handler->PSendSysMessage("Total Participants: {}", fields[10].GetUInt32());
            handler->PSendSysMessage("Total Kills/Deaths: {}/{}", fields[11].GetUInt32(), fields[12].GetUInt32());
            
            if (!fields[13].IsNull())
            {
                handler->PSendSysMessage("Last Reset: {} on {}", fields[13].GetString(), fields[14].GetString());
            }
        }
        else
        {
            handler->SendSysMessage("No enhanced HLBG statistics found! Apply the enhanced database schema.");
        }

        return true;
    }

    // Enhanced HLBG Season Management
    static bool HandleHLBGSeasonCommand(ChatHandler* handler, char const* args)
    {
        if (!args || !*args)
        {
            // Show current season
            QueryResult result = WorldDatabase.Query("SELECT name, start_date, end_date, description FROM hlbg_seasons WHERE is_active = 1 LIMIT 1");
            
            if (result)
            {
                Field* fields = result->Fetch();
                handler->PSendSysMessage("=== Current HLBG Season ===");
                handler->PSendSysMessage("Name: {}", fields[0].GetString());
                handler->PSendSysMessage("Period: {} to {}", fields[1].GetString(), fields[2].GetString());
                handler->PSendSysMessage("Description: {}", fields[3].GetString());
            }
            else
            {
                handler->SendSysMessage("No active HLBG season found!");
            }
            return true;
        }

        char* action = strtok((char*)args, " ");
        
        if (strcmp(action, "list") == 0)
        {
            QueryResult result = WorldDatabase.Query("SELECT id, name, start_date, end_date, is_active FROM hlbg_seasons ORDER BY id DESC LIMIT 10");
            
            if (result)
            {
                handler->PSendSysMessage("=== HLBG Seasons ===");
                do
                {
                    Field* fields = result->Fetch();
                    handler->PSendSysMessage("ID:{} {} ({} to {}) [{}]", 
                        fields[0].GetUInt32(), 
                        fields[1].GetString(), 
                        fields[2].GetString(), 
                        fields[3].GetString(),
                        fields[4].GetBool() ? "ACTIVE" : "inactive");
                } while (result->NextRow());
            }
            else
            {
                handler->SendSysMessage("No seasons found!");
            }
        }
        else if (strcmp(action, "activate") == 0)
        {
            char* seasonId = strtok(nullptr, " ");
            
            if (!seasonId)
            {
                handler->SendSysMessage("Usage: .hlbg season activate [season_id]");
                return false;
            }
            
            // Deactivate all seasons first
            WorldDatabase.Execute("UPDATE hlbg_seasons SET is_active = 0");
            
            // Activate specified season
            WorldDatabase.PExecute("UPDATE hlbg_seasons SET is_active = 1 WHERE id = {}", atoi(seasonId));
            
            handler->PSendSysMessage("Activated HLBG season ID: {}", seasonId);
        }

        return true;
    }

    // Enhanced HLBG Player Statistics
    static bool HandleHLBGPlayersCommand(ChatHandler* handler, char const* args)
    {
        if (!args || !*args || strcmp(args, "top") == 0)
        {
            // Show top players by battles won
            QueryResult result = WorldDatabase.Query("SELECT player_name, faction, battles_participated, battles_won, total_kills, total_deaths FROM hlbg_player_stats ORDER BY battles_won DESC LIMIT 10");
            
            if (result)
            {
                handler->PSendSysMessage("=== Top HLBG Players ===");
                handler->PSendSysMessage("Name | Faction | Battles | Wins | K/D");
                do
                {
                    Field* fields = result->Fetch();
                    float winRate = fields[2].GetUInt32() > 0 ? (float(fields[3].GetUInt32()) / fields[2].GetUInt32() * 100) : 0;
                    handler->PSendSysMessage("{} | {} | {} | {} ({:.1f}%) | {}/{}", 
                        fields[0].GetString(),   // player_name
                        fields[1].GetString(),   // faction
                        fields[2].GetUInt32(),   // battles_participated
                        fields[3].GetUInt32(),   // battles_won
                        winRate,
                        fields[4].GetUInt32(),   // total_kills
                        fields[5].GetUInt32()    // total_deaths
                    );
                } while (result->NextRow());
            }
            else
            {
                handler->SendSysMessage("No enhanced player statistics found! Apply the enhanced database schema.");
            }
        }

        return true;
    }
};

void AddSC_hlbg_commandscript()
{
    new hlbg_commandscript();
}
