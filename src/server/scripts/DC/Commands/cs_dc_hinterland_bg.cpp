#include "ScriptMgr.h"
#include "BattlegroundMgr.h"
#include "Chat.h"
#include "CommandScript.h"
#include <string>
#include "ObjectAccessor.h"
#include "Player.h"
#include "../HinterlandBG/BattlegroundHLBG.h"
#include "../HinterlandBG/HLBGService.h"
#include "../HinterlandBG/dc_hlbg_spectator.h"
#include "../HinterlandBG/hlbg_constants.h"
#include <sstream>
#include <algorithm>
#include "DatabaseEnv.h"
#include <cmath>

/*
 * hlbg_commandscript
 * ------------------
 * Provides GM/admin commands to inspect and manage HLBG runtime state.
 *
 * Commands (quick reference):
 *   .hlbg status               Show timer/resources + player counts
 *   .hlbg get <alliance|horde> Show resources for a team
 *   .hlbg set <team> <amt>     Set resources for a team (GM-only); action is audited
 *   .hlbg reset                Force-reset the Hinterland match; action is audited
 *   .hlbg finish <winner>      Force-end an in-progress battleground match for testing
 *
 * Audit logging: administrative actions (.hlbg set/.hlbg reset/.hlbg finish) are logged to
 * the server log under the `admin.hlbg` category with the GM name and GUID.
 * Log format: "[ADMIN] <name> (GUID:<low>) <action>". This is intended for
 * lightweight operational audit trails; maintainers may redirect or persist
 * these messages to a centralized logging system if desired.
 *
 * Note: On timer expiry the battleground resolves through the BattlegroundHLBG
 * implementation.
 */

using namespace Acore::ChatCommands;

// Prototypes for addon/chat fallback handlers implemented in DC/AddonExtension/dc_addon_hlbg.cpp
bool HandleHLBGLive(ChatHandler* handler, char const* args);
bool HandleHLBGWarmup(ChatHandler* handler, char const* args);
bool HandleHLBGResults(ChatHandler* handler, char const* args);
bool HandleHLBGHistoryUI(ChatHandler* handler, char const* args);
bool HandleHLBGStatsUI(ChatHandler* handler, char const* args);
bool HandleHLBGQueueJoin(ChatHandler* handler, char const* args);
bool HandleHLBGQueueLeave(ChatHandler* handler, char const* args);
bool HandleHLBGQueueStatus(ChatHandler* handler, char const* args);

namespace
{
    BattlegroundHLBG* GetPlayerHLBGBattleground(Player* player)
    {
        if (!player)
            return nullptr;

        Battleground* battleground = player->GetBattleground();
        if (!battleground || battleground->GetBgTypeID() != BATTLEGROUND_HLBG)
            return nullptr;

        return dynamic_cast<BattlegroundHLBG*>(battleground);
    }

    BattlegroundHLBG* ResolveHLBGBattleground(ChatHandler* handler)
    {
        Player* player = handler && handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (BattlegroundHLBG* battleground = GetPlayerHLBGBattleground(player))
            return battleground;

        BattlegroundHLBG* selected = HLBGService::Instance().GetActiveBattleground(player);
        uint32 matches = 0;
        for (Battleground const* battleground : sBattlegroundMgr->GetActiveBattlegrounds())
            if (battleground && battleground->GetBgTypeID(true) == BATTLEGROUND_HLBG)
                ++matches;

        if (matches > 1 && handler && selected)
        {
            handler->PSendSysMessage(
                "Multiple active HLBG battlegrounds found. Using instance {}. Stand inside the battleground to target a specific one.",
                selected->GetInstanceID());
        }

        return selected;
    }

    bool TryParsePlayableTeam(std::string teamToken, TeamId& teamId)
    {
        std::transform(teamToken.begin(), teamToken.end(), teamToken.begin(), ::tolower);
        if (teamToken == "alliance" || teamToken == "a")
        {
            teamId = TEAM_ALLIANCE;
            return true;
        }

        if (teamToken == "horde" || teamToken == "h")
        {
            teamId = TEAM_HORDE;
            return true;
        }

        return false;
    }

    bool TryParseWinnerTeam(std::string teamToken, TeamId& teamId)
    {
        if (TryParsePlayableTeam(teamToken, teamId))
            return true;

        std::transform(teamToken.begin(), teamToken.end(), teamToken.begin(), ::tolower);
        if (teamToken == "draw" || teamToken == "neutral" || teamToken == "tie")
        {
            teamId = TEAM_NEUTRAL;
            return true;
        }

        return false;
    }

    char const* GetTeamLabel(TeamId teamId)
    {
        switch (teamId)
        {
            case TEAM_ALLIANCE:
                return "|cff1e90ffAlliance|r";
            case TEAM_HORDE:
                return "|cffff0000Horde|r";
            default:
                return "Draw";
        }
    }

    char const* GetBattlegroundStatusLabel(BattlegroundStatus status)
    {
        switch (status)
        {
            case STATUS_WAIT_JOIN:
                return "wait_join";
            case STATUS_IN_PROGRESS:
                return "in_progress";
            case STATUS_WAIT_LEAVE:
                return "wait_leave";
            case STATUS_WAIT_QUEUE:
                return "wait_queue";
            default:
                return "none";
        }
    }
}

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

        // Ensure nested subtables are stored in named static variables so
        // that ChatCommandBuilder's reference_wrapper does not point to a
        // temporary that will be destroyed. Using an inline temporary
        // std::vector here would create a dangling reference and crash
        // when the command map is initialized.
        static ChatCommandTable queueSubTable = {
            { "join",    HandleHLBGQueueJoin,    SEC_PLAYER, Console::No },
            { "leave",   HandleHLBGQueueLeave,   SEC_PLAYER, Console::No },
            { "status",  HandleHLBGQueueStatus,  SEC_PLAYER, Console::No },
            { "qstatus", HandleHLBGQueueStatus,  SEC_PLAYER, Console::No },
            { "list",    HandleHLBGQueueListCommand, SEC_GAMEMASTER, Console::No }
        };

        static ChatCommandTable hlbgCommandTable =
        {
            // Admin/GM commands
            { "status", HandleHLBGStatusCommand, SEC_GAMEMASTER, Console::No },
            { "qlist", HandleHLBGQueueListCommand, SEC_GAMEMASTER, Console::No },
            { "get",    HandleHLBGGetCommand,    SEC_GAMEMASTER, Console::No },
            { "set",    HandleHLBGSetCommand,    SEC_GAMEMASTER, Console::No },
            { "reset",  HandleHLBGResetCommand,  SEC_GAMEMASTER, Console::No },
            { "finish", HandleHLBGFinishCommand, SEC_GAMEMASTER, Console::No },
            { "end",    HandleHLBGFinishCommand, SEC_GAMEMASTER, Console::No },
            { "history",HandleHLBGHistoryCommand,SEC_GAMEMASTER, Console::No },
            { "statsmanual",HandleHLBGStatsManualCommand,SEC_GAMEMASTER, Console::No },
            { "affix",  HandleHLBGAffixCommand,  SEC_GAMEMASTER, Console::No },

            // Addon/UI fallback commands (exposed to players)
            { "live",    HandleHLBGLive,    SEC_PLAYER, Console::No },
            // historyui/statsui intentionally removed: use DC-Leaderboards (/leaderboard)
            { "warmup",  HandleHLBGWarmup,  SEC_GAMEMASTER, Console::No },
            { "results", HandleHLBGResults, SEC_GAMEMASTER, Console::No },
            { "spectate", HandleHLBGSpectateCommand, SEC_PLAYER, Console::No },

            // Nested 'queue' subtable for player queue actions
            { "queue", queueSubTable }
        };

        static ChatCommandTable commandTable =
        {
            { "hlbg", hlbgCommandTable },
            { "hlbgq", queueSubTable }
        };

        return commandTable;
    }
    static bool HandleHLBGSpectateCommand(ChatHandler* handler, char const* args)
    {
        // Usage: .hlbg spectate        -> join as spectator
        //        .hlbg spectate leave  -> stop spectating
        Player* player = handler->GetSession()
            ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
            return false;

        std::string arg = args ? args : "";
        std::transform(arg.begin(), arg.end(), arg.begin(), ::tolower);

        if (arg == "leave" || arg == "stop")
        {
            if (!DCHLBGSpectator::StopSpectating(player))
                handler->SendSysMessage(
                    "|cffff0000[HLBG Spectator]|r You are not spectating.");
            return true;
        }

        std::string error;
        if (!DCHLBGSpectator::StartSpectating(player, error))
            handler->PSendSysMessage(
                "|cffff0000[HLBG Spectator]|r {}", error);
        return true;
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
        HLBGService::Instance().SetStatsIncludeManualResets(set);
        handler->PSendSysMessage("Stats will {}include manual resets.", set ? "" : "not ");
        return true;
    }

    static bool HandleHLBGStatusCommand(ChatHandler* handler, char const* /*args*/)
    {
        // Show current match timer/resources and active player counts for both factions.
        // This command works from anywhere (no zone restriction).

    handler->PSendSysMessage("|cffffd700Hinterland BG status:|r");

        if (BattlegroundHLBG* bg = ResolveHLBGBattleground(handler))
        {
            Player* admin = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
            uint32 secs = bg->GetTimeRemainingSeconds();
            uint32 min = secs / 60u;
            uint32 sec = secs % 60u;
            handler->PSendSysMessage("  Mode: battleground");
            handler->PSendSysMessage("  Instance: {}  Status: {}  Map: {}", bg->GetInstanceID(), GetBattlegroundStatusLabel(bg->GetStatus()), bg->GetMapId());
            handler->PSendSysMessage("  Time remaining: {:02}:{:02}", min, sec);
            handler->PSendSysMessage("  Resources: {}={}, {}={}", GetTeamLabel(TEAM_ALLIANCE), bg->GetResources(TEAM_ALLIANCE), GetTeamLabel(TEAM_HORDE), bg->GetResources(TEAM_HORDE));
            handler->PSendSysMessage("  Players: {}={}, {}={}, Total={}", GetTeamLabel(TEAM_ALLIANCE), bg->GetPlayersCountByTeam(TEAM_ALLIANCE), GetTeamLabel(TEAM_HORDE), bg->GetPlayersCountByTeam(TEAM_HORDE), bg->GetPlayersSize());

            if (admin && GetPlayerHLBGBattleground(admin) == bg)
            {
                handler->PSendSysMessage(
                    "  You: afk={} contribution={} hkDelta={}",
                    bg->IsPlayerAfkFlagged(admin) ? "yes" : "no",
                    bg->GetPlayerContributionScore(admin->GetGUID()),
                    bg->GetPlayerHKDelta(admin));
            }

            return true;
        }

        BattlegroundQueue& queue = sBattlegroundMgr->GetBattlegroundQueue(BATTLEGROUND_QUEUE_HLBG);
        uint32 allianceQueued = 0;
        uint32 hordeQueued = 0;
        for (auto const& queuedPlayer : queue.m_QueuedPlayers)
        {
            GroupQueueInfo* info = queuedPlayer.second;
            if (!info || info->BgTypeId != BATTLEGROUND_HLBG)
                continue;

            if (info->RealTeamID == TEAM_ALLIANCE)
                ++allianceQueued;
            else if (info->RealTeamID == TEAM_HORDE)
                ++hordeQueued;
        }

        handler->PSendSysMessage("  Mode: no active battleground");
        handler->PSendSysMessage("  Queue: {}={}, {}={}, Total={}",
            GetTeamLabel(TEAM_ALLIANCE), allianceQueued,
            GetTeamLabel(TEAM_HORDE), hordeQueued,
            allianceQueued + hordeQueued);
        TeamId lastWinner = HLBGService::Instance().GetLastWinnerTeamId();
        handler->PSendSysMessage("  Last winner: {}", GetTeamLabel(lastWinner));
        return true;
    }

    static bool HandleHLBGQueueListCommand(ChatHandler* handler, char const* /*args*/)
    {
        if (!handler || !handler->GetSession())
            return false;

        Player* admin = handler->GetSession()->GetPlayer();
        if (!admin)
            return false;

        BattlegroundQueue& queue = sBattlegroundMgr->GetBattlegroundQueue(BATTLEGROUND_QUEUE_HLBG);
        handler->PSendSysMessage("HLBG queue:");

        uint32 count = 0;
        for (auto const& queuedPlayer : queue.m_QueuedPlayers)
        {
            GroupQueueInfo* info = queuedPlayer.second;
            if (!info || info->BgTypeId != BATTLEGROUND_HLBG)
                continue;

            ++count;
            Player* queued = ObjectAccessor::FindConnectedPlayer(queuedPlayer.first);
            char const* teamLabel = GetTeamLabel(info->RealTeamID);
            if (queued)
                handler->PSendSysMessage("  {} {} ({})", count, queued->GetName(), teamLabel);
            else
                handler->PSendSysMessage("  {} GUID:{} ({})", count, queuedPlayer.first.GetCounter(), teamLabel);
        }

        if (count == 0)
            handler->PSendSysMessage("  (empty)");

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
        TeamId tid = TEAM_NEUTRAL;
        if (!TryParsePlayableTeam(team, tid))
        {
            handler->PSendSysMessage("Usage: .hlbg get alliance|horde");
            return false;
        }

        BattlegroundHLBG* bg = ResolveHLBGBattleground(handler);
        if (!bg)
        {
            handler->PSendSysMessage("No active HLBG battleground instance found.");
            return false;
        }

        uint32 res = bg->GetResources(tid);

        handler->PSendSysMessage("{} resources: {}", GetTeamLabel(tid), res);
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
        // Outputs: sets the live battleground resource counter and emits an
        // audit log line under the `admin.hlbg` category.
        // Error modes: returns false / prints usage when args are missing.

        if (!args || !*args)
        {
            handler->PSendSysMessage("Usage: .hlbg set alliance|horde <amount>");
            return false;
        }
        std::string in(args);
        std::istringstream iss(in);
        std::string teamStr;
        uint32 amount = 0;
        iss >> teamStr >> amount;
        TeamId tid = TEAM_NEUTRAL;
        if (!iss || !TryParsePlayableTeam(teamStr, tid))
        {
            handler->PSendSysMessage("Usage: .hlbg set alliance|horde <amount>");
            return false;
        }

        uint32 prev = 0;
        if (BattlegroundHLBG* bg = ResolveHLBGBattleground(handler))
        {
            prev = bg->GetResources(tid);
            bg->AdminSetResources(tid, amount);
            if (Player* admin = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr)
            {
                LOG_INFO("admin.hlbg", "[ADMIN] {} (GUID:{}) set battleground instance {} {} resources from {} -> {}",
                    admin->GetName(), admin->GetGUID().GetCounter(), bg->GetInstanceID(), teamStr, prev, amount);
            }

            handler->PSendSysMessage("Set battleground instance {} {} resources to {}", bg->GetInstanceID(), GetTeamLabel(tid), amount);
            return true;
        }

        handler->PSendSysMessage("No active HLBG battleground instance found.");
        return false;
    }

    static bool HandleHLBGResetCommand(ChatHandler* handler, char const* /*args*/)
    {
        // Purpose: force the Hinterland match into its reset state. This is a
        // powerful operation and is therefore logged to `admin.hlbg`.
        //
        // Usage: .hlbg reset
        // Inputs: no args; acts on the active HLBG battleground instance.
        // Outputs: resets the live battleground instance and logs the action.

        if (BattlegroundHLBG* bg = ResolveHLBGBattleground(handler))
        {
            bg->AdminResetMatch();
            if (Player* admin = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr)
                LOG_INFO("admin.hlbg", "[ADMIN] {} (GUID:{}) forced HLBG battleground reset for instance {}", admin->GetName(), admin->GetGUID().GetCounter(), bg->GetInstanceID());
            handler->PSendSysMessage("HLBG battleground instance {} reset and players relocated.", bg->GetInstanceID());
            return true;
        }

        handler->PSendSysMessage("Hinterland BG instance not found.");
        return false;
    }

    static bool HandleHLBGFinishCommand(ChatHandler* handler, char const* args)
    {
        if (!args || !*args)
        {
            handler->PSendSysMessage("Usage: .hlbg finish alliance|horde|draw");
            return false;
        }

        TeamId winnerTeamId = TEAM_NEUTRAL;
        if (!TryParseWinnerTeam(args, winnerTeamId))
        {
            handler->PSendSysMessage("Usage: .hlbg finish alliance|horde|draw");
            return false;
        }

        BattlegroundHLBG* bg = ResolveHLBGBattleground(handler);
        if (!bg)
        {
            handler->PSendSysMessage("No active HLBG battleground instance found.");
            return false;
        }

        if (bg->GetStatus() != STATUS_IN_PROGRESS)
        {
            handler->PSendSysMessage("HLBG battleground instance {} is not in progress.", bg->GetInstanceID());
            return false;
        }

        bg->AdminFinishMatch(winnerTeamId);
        if (Player* admin = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr)
        {
            LOG_INFO("admin.hlbg", "[ADMIN] {} (GUID:{}) finished HLBG battleground instance {} with winner {}",
                admin->GetName(), admin->GetGUID().GetCounter(), bg->GetInstanceID(), args);
        }

        handler->PSendSysMessage("Finished HLBG battleground instance {} with result {}.", bg->GetInstanceID(), GetTeamLabel(winnerTeamId));
        return true;
    }

    static bool HandleHLBGHistoryCommand(ChatHandler* handler, char const* args)
    {
        // Usage: .hlbg history [count]
        // Default count = 10, max = 50
        uint32 count = 10;
        auto buildAffixDisplay = [](uint8 affixPrimary, uint8 affixSecondary, uint8 affixTertiary)
        {
            std::ostringstream out;
            bool first = true;

            for (uint8 affixCode : { affixPrimary, affixSecondary, affixTertiary })
            {
                if (!affixCode)
                    continue;

                if (!first)
                    out << ", ";

                first = false;
                out << HinterlandBGConstants::GetAffixName(affixCode);
            }

            return out.str();
        };

        if (args && *args)
        {
            uint32 v = Acore::StringTo<uint32>(args).value_or(10);
            count = std::max<uint32>(1, std::min<uint32>(50, v));
        }
        QueryResult res = CharacterDatabase.Query("SELECT occurred_at, winner_tid, score_alliance, score_horde, win_reason, affix, affix_secondary, affix_tertiary FROM dc_hlbg_winner_history ORDER BY id DESC LIMIT {}", count);
        if (!res)
        {
            handler->PSendSysMessage("No history found. Ensure the characters DB includes the dc_hlbg_winner_history HLBG schema.");
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
            std::string affixDisplay = buildAffixDisplay(
                f[5].Get<uint8>(), f[6].Get<uint8>(), f[7].Get<uint8>());
            if (!affixDisplay.empty())
                reason += ", affixes: " + affixDisplay;
            const char* name = (tid == TEAM_ALLIANCE ? "Alliance" : (tid == TEAM_HORDE ? "Horde" : "Draw"));
            handler->PSendSysMessage("  [{}] {}  A:{} H:{}  ({})", ts, name, a, h, reason);
        }
        while (res->NextRow());
        return true;
    }

    static bool HandleHLBGAffixCommand(ChatHandler* handler, char const* /*args*/)
    {
        BattlegroundHLBG* bg = ResolveHLBGBattleground(handler);
        if (!bg)
        {
            handler->PSendSysMessage("No active HLBG battleground instance found.");
            return false;
        }

        uint8 code = bg->GetActiveAffixCode();
        std::ostringstream affixStream;
        bool first = true;
        for (uint32 slot = 0; slot < 3u; ++slot)
        {
            uint8 affixCode = bg->GetActiveAffixCode(slot);
            if (!affixCode)
                continue;

            if (!first)
                affixStream << ", ";

            first = false;
            affixStream << HinterlandBGConstants::GetAffixName(affixCode)
                << " (" << static_cast<unsigned>(affixCode) << ")";
        }

        handler->PSendSysMessage("|cffffd700Hinterland BG affixes:|r {}",
            first ? "None" : affixStream.str());
        handler->PSendSysMessage("  Enabled: {}  Weather: {}  Worldstate: {}  Announce: {}",
            bg->IsAffixEnabled()?"on":"off",
            bg->IsAffixWeatherEnabled()?"on":"off",
            bg->IsAffixWorldstateEnabled()?"on":"off",
            bg->IsAffixAnnounceEnabled()?"on":"off");
        handler->PSendSysMessage("  Random on start: {}  Periodic rotation: {}s  Next change at epoch: {}",
            bg->IsAffixRandomOnStart()?"on":"off", (unsigned)bg->GetAffixPeriodSec(), (unsigned)bg->GetAffixNextChangeEpoch());
        // Show configured spells and weather for the current code
        if (code > 0)
        {
            uint32 pspell = bg->GetAffixPlayerSpell(code);
            uint32 nspell = bg->GetAffixNpcSpell(code);
            uint32 wtype  = bg->GetAffixWeatherType(code);
            float  wint   = bg->GetAffixWeatherIntensity(code);
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
};

void AddSC_dc_hinterland_bg_commandscript()
{
    new hlbg_commandscript();
}
