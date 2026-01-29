/*
 * Dark Chaos - Duel Statistics Addon Handler
 * ============================================
 *
 * Server-side handler for the DC-Duels addon module.
 * Provides duel statistics, leaderboard data, and spectator support via DCAddonProtocol.
 *
 * Features:
 * - Player duel statistics (wins, losses, draws, damage, timing)
 * - Top duelists leaderboard
 * - Active duel list for spectating
 * - Real-time duel start/end notifications
 *
 * Message Format:
 * - JSON format: DUEL|OPCODE|J|{json}
 *
 * Opcodes (from DCAddonNamespace.h):
 * - CMSG: 0x01 (GET_STATS), 0x02 (GET_LEADERBOARD), 0x03 (SPECTATE_DUEL)
 * - SMSG: 0x10 (STATS), 0x11 (LEADERBOARD), 0x12 (DUEL_START), 0x13 (DUEL_END), 0x14 (DUEL_UPDATE)
 *
 * Integrates with dc_phased_duels.cpp for statistics data.
 *
 * Copyright (C) 2025 DarkChaos Development Team
 */

#include "dc_addon_namespace.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "Config.h"
#include "ObjectMgr.h"
#include "ObjectAccessor.h"

namespace DCDuelAddon
{
    // Module identifier - must match client-side and DCAddonNamespace.h
    constexpr const char* MODULE = "DUEL";

    // Opcodes - match DCAddonNamespace.h Opcode::Duel
    namespace Opcode
    {
        // Client -> Server
        constexpr uint8 CMSG_GET_STATS         = 0x01;  // Request player's duel stats
        constexpr uint8 CMSG_GET_LEADERBOARD   = 0x02;  // Request top duelists
        constexpr uint8 CMSG_SPECTATE_DUEL     = 0x03;  // Request to spectate an active duel

        // Server -> Client
        constexpr uint8 SMSG_STATS             = 0x10;  // Player's duel statistics
        constexpr uint8 SMSG_LEADERBOARD       = 0x11;  // Top duelists list
        constexpr uint8 SMSG_DUEL_START        = 0x12;  // Notification: duel started
        constexpr uint8 SMSG_DUEL_END          = 0x13;  // Notification: duel ended
        constexpr uint8 SMSG_DUEL_UPDATE       = 0x14;  // Real-time duel update (damage, etc.)
    }

    // Configuration
    namespace Config
    {
        constexpr const char* ENABLED = "DCDuelAddon.Enable";
        // Note: LeaderboardLimit is currently unused but reserved for future config
        // constexpr const char* LEADERBOARD_LIMIT = "DCDuelAddon.LeaderboardLimit";
    }

    // =======================================================================
    // Handler Functions
    // =======================================================================

    /**
     * Send player's duel statistics
     * JSON Response:
     * {
     *   "wins": uint32,
     *   "losses": uint32,
     *   "draws": uint32,
     *   "winRate": float,
     *   "totalDamageDealt": uint32,
     *   "totalDamageTaken": uint32,
     *   "longestDuel": uint32 (seconds),
     *   "fastestWin": uint32 (seconds),
     *   "lastDuelTime": uint64 (unix timestamp),
     *   "lastOpponentName": string
     * }
     */
    void SendPlayerStats(Player* player, ObjectGuid targetGuid)
    {
        if (!player || !player->GetSession())
            return;

        // Query from database
        QueryResult result = CharacterDatabase.Query(
            "SELECT d.wins, d.losses, d.draws, d.total_damage_dealt, d.total_damage_taken, "
            "d.longest_duel_seconds, d.shortest_win_seconds, d.last_duel_time, d.last_opponent_guid, c.name "
            "FROM dc_duel_statistics d "
            "LEFT JOIN characters c ON c.guid = d.last_opponent_guid "
            "WHERE d.player_guid = {}",
            targetGuid.GetCounter());

        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_STATS);

        if (!result)
        {
            // No stats yet - send empty response
            msg.Set("wins", 0);
            msg.Set("losses", 0);
            msg.Set("draws", 0);
            msg.Set("winRate", 0.0);
            msg.Set("totalDamageDealt", 0);
            msg.Set("totalDamageTaken", 0);
            msg.Set("longestDuel", 0);
            msg.Set("fastestWin", 0);
            msg.Set("lastDuelTime", 0);
            msg.Set("lastOpponentName", "");
            msg.Set("hasStats", false);
        }
        else
        {
            Field* fields = result->Fetch();
            uint32 wins = fields[0].Get<uint32>();
            uint32 losses = fields[1].Get<uint32>();
            uint32 draws = fields[2].Get<uint32>();
            uint32 totalDamageDealt = fields[3].Get<uint32>();
            uint32 totalDamageTaken = fields[4].Get<uint32>();
            uint32 longestDuel = fields[5].Get<uint32>();
            uint32 fastestWin = fields[6].Get<uint32>();
            uint64 lastDuelTime = fields[7].Get<uint64>();
            std::string lastOpponentName = fields[9].IsNull() ? "" : fields[9].Get<std::string>();

            uint32 total = wins + losses + draws;
            double winRate = total > 0 ? (static_cast<double>(wins) / static_cast<double>(total)) * 100.0 : 0.0;

            msg.Set("wins", wins);
            msg.Set("losses", losses);
            msg.Set("draws", draws);
            msg.Set("winRate", winRate);
            msg.Set("totalDamageDealt", totalDamageDealt);
            msg.Set("totalDamageTaken", totalDamageTaken);
            msg.Set("longestDuel", longestDuel);
            msg.Set("fastestWin", fastestWin == UINT32_MAX ? 0 : fastestWin);
            msg.Set("lastDuelTime", static_cast<uint32>(lastDuelTime));  // Truncate to uint32 for JSON
            msg.Set("lastOpponentName", lastOpponentName);
            msg.Set("hasStats", true);
        }

        msg.Send(player);
    }

    /**
     * Send leaderboard of top duelists
     * Supports different sorting modes: wins, winrate, rating, streak
     * JSON Response:
     * {
     *   "entries": [
     *     { "rank": uint32, "name": string, "class": string, "wins": uint32,
     *       "losses": uint32, "winRate": float, "total": uint32 }
     *   ],
     *   "totalCount": uint32,
     *   "page": uint32,
     *   "sortBy": string
     * }
     */
    void SendLeaderboard(Player* player, const std::string& sortBy, uint32 page, uint32 limit)
    {
        if (!player || !player->GetSession())
            return;

        // Clamp limit
        if (limit == 0) limit = 25;
        if (limit > 100) limit = 100;

        uint32 offset = page * limit;

        // Build ORDER BY clause based on sortBy
        std::string orderBy = "d.wins DESC, (d.wins + d.losses + d.draws) DESC";  // Default: by wins

        if (sortBy == "winrate")
        {
            orderBy = "(d.wins * 100.0 / NULLIF(d.wins + d.losses + d.draws, 0)) DESC, d.wins DESC";
        }
        else if (sortBy == "total")
        {
            orderBy = "(d.wins + d.losses + d.draws) DESC, d.wins DESC";
        }
        else if (sortBy == "damage")
        {
            orderBy = "d.total_damage_dealt DESC, d.wins DESC";
        }

        // Get total count
        QueryResult countResult = CharacterDatabase.Query(
            "SELECT COUNT(*) FROM dc_duel_statistics WHERE wins > 0 OR losses > 0");
        uint32 totalCount = countResult ? countResult->Fetch()[0].Get<uint32>() : 0;

        // Get leaderboard entries
        QueryResult result = CharacterDatabase.Query(
            "SELECT c.name, c.class, d.wins, d.losses, d.draws, d.total_damage_dealt "
            "FROM dc_duel_statistics d "
            "INNER JOIN characters c ON c.guid = d.player_guid "
            "WHERE d.wins > 0 OR d.losses > 0 "
            "ORDER BY {} "
            "LIMIT {} OFFSET {}",
            orderBy, limit, offset);

        // Build JSON response
        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_LEADERBOARD);

        // Build entries array as JSON string
        std::string entriesJson = "[";
        uint32 rank = offset + 1;
        bool first = true;

        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                std::string name = fields[0].Get<std::string>();
                uint8 classId = fields[1].Get<uint8>();
                uint32 wins = fields[2].Get<uint32>();
                uint32 losses = fields[3].Get<uint32>();
                uint32 draws = fields[4].Get<uint32>();
                uint32 damageDealt = fields[5].Get<uint32>();

                uint32 total = wins + losses + draws;
                double winRate = total > 0 ? (static_cast<double>(wins) / static_cast<double>(total)) * 100.0 : 0.0;

                // Get class name
                std::string className;
                switch (classId)
                {
                    case 1: className = "WARRIOR"; break;
                    case 2: className = "PALADIN"; break;
                    case 3: className = "HUNTER"; break;
                    case 4: className = "ROGUE"; break;
                    case 5: className = "PRIEST"; break;
                    case 6: className = "DEATHKNIGHT"; break;
                    case 7: className = "SHAMAN"; break;
                    case 8: className = "MAGE"; break;
                    case 9: className = "WARLOCK"; break;
                    case 11: className = "DRUID"; break;
                    default: className = "UNKNOWN"; break;
                }

                if (!first)
                    entriesJson += ",";
                first = false;

                char entryBuf[512];
                std::snprintf(entryBuf, sizeof(entryBuf),
                    "{\"rank\":%u,\"name\":\"%s\",\"class\":\"%s\",\"wins\":%u,\"losses\":%u,"
                    "\"draws\":%u,\"winRate\":%.1f,\"total\":%u,\"damage\":%u}",
                    rank++, name.c_str(), className.c_str(), wins, losses, draws, winRate, total, damageDealt);
                entriesJson += entryBuf;

            } while (result->NextRow());
        }

        entriesJson += "]";

        msg.Set("entries", entriesJson);
        msg.Set("totalCount", totalCount);
        msg.Set("page", page);
        msg.Set("sortBy", sortBy);
        msg.Set("limit", limit);

        msg.Send(player);
    }

    /**
     * Handle spectate request for active duels
     * Returns list of active duels if no target specified
     * TODO: Full spectator integration with PhasedDuels system
     */
    void HandleSpectateRequest(Player* player, ObjectGuid targetGuid)
    {
        if (!player || !player->GetSession())
            return;

        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_DUEL_UPDATE);

        if (targetGuid.IsEmpty())
        {
            // Return list of active duels
            // For now, we query characters currently flagged as dueling
            // Full implementation would integrate with PhasedDuels sActiveDuels map
            msg.Set("action", "list");
            msg.Set("activeDuels", "[]");  // TODO: Query from PhasedDuels system
            msg.Set("message", "Duel spectating coming soon!");
        }
        else
        {
            // Request to spectate a specific duel
            // TODO: Implement phasing into duel phase for spectating
            msg.Set("action", "spectate");
            msg.Set("success", false);
            msg.Set("message", "Duel spectating is not yet implemented.");
        }

        msg.Send(player);
    }

    // =======================================================================
    // Message Handlers
    // =======================================================================

    void HandleGetStats(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player)
            return;

        // Check if requesting own stats or another player's
        ObjectGuid targetGuid = player->GetGUID();

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        if (!json.IsNull() && json.HasKey("targetGuid"))
        {
            uint64 rawGuid = static_cast<uint64>(json["targetGuid"].AsInt32());
            if (rawGuid > 0)
            {
                targetGuid = ObjectGuid::Create<HighGuid::Player>(static_cast<uint32>(rawGuid));
            }
        }

        SendPlayerStats(player, targetGuid);
    }

    void HandleGetLeaderboard(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player)
            return;

        std::string sortBy = "wins";  // Default sort
        uint32 page = 0;
        uint32 limit = 25;

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        if (!json.IsNull())
        {
            if (json.HasKey("sortBy"))
                sortBy = json["sortBy"].AsString();
            if (json.HasKey("page"))
                page = json["page"].AsUInt32();
            if (json.HasKey("limit"))
                limit = json["limit"].AsUInt32();
        }

        SendLeaderboard(player, sortBy, page, limit);
    }

    void HandleSpectateDuel(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player)
            return;

        ObjectGuid targetGuid;

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        if (!json.IsNull() && json.HasKey("targetGuid"))
        {
            uint64 rawGuid = static_cast<uint64>(json["targetGuid"].AsInt32());
            if (rawGuid > 0)
            {
                targetGuid = ObjectGuid::Create<HighGuid::Player>(static_cast<uint32>(rawGuid));
            }
        }

        HandleSpectateRequest(player, targetGuid);
    }

    // =======================================================================
    // Notification Helpers (called from PhasedDuels system)
    // =======================================================================

    /**
     * Notify addon clients about a duel starting
     * Called from DCPhasedDuelsPlayerScript::OnPlayerDuelStart
     */
    void NotifyDuelStart(Player* player1, Player* player2, uint32 phaseId)
    {
        if (!player1 || !player2)
            return;

        // Build notification for player1
        {
            DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_DUEL_START);
            msg.Set("opponent", player2->GetName());
            msg.Set("opponentClass", player2->getClass());
            msg.Set("opponentLevel", player2->GetLevel());
            msg.Set("phaseId", phaseId);
            msg.Send(player1);
        }

        // Build notification for player2
        {
            DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_DUEL_START);
            msg.Set("opponent", player1->GetName());
            msg.Set("opponentClass", player1->getClass());
            msg.Set("opponentLevel", player1->GetLevel());
            msg.Set("phaseId", phaseId);
            msg.Send(player2);
        }

        LOG_DEBUG("dc.addon", "DCDuelAddon: Sent duel start notifications for {} vs {}",
            player1->GetName(), player2->GetName());
    }

    /**
     * Notify addon clients about a duel ending
     * Called from DCPhasedDuelsPlayerScript::OnPlayerDuelEnd
     */
    void NotifyDuelEnd(Player* winner, Player* loser, uint32 durationSeconds)
    {
        if (!winner || !loser)
            return;

        // Notify winner
        {
            DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_DUEL_END);
            msg.Set("result", "win");
            msg.Set("opponent", loser->GetName());
            msg.Set("duration", durationSeconds);
            msg.Send(winner);
        }

        // Notify loser
        {
            DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_DUEL_END);
            msg.Set("result", "loss");
            msg.Set("opponent", winner->GetName());
            msg.Set("duration", durationSeconds);
            msg.Send(loser);
        }

        LOG_DEBUG("dc.addon", "DCDuelAddon: Sent duel end notifications ({} beat {})",
            winner->GetName(), loser->GetName());
    }

} // namespace DCDuelAddon

// =======================================================================
// Script Registration
// =======================================================================

class DCDuelAddonWorldScript : public WorldScript
{
public:
    DCDuelAddonWorldScript() : WorldScript("DCDuelAddonWorldScript") { }

    void OnStartup() override
    {
        bool enabled = sConfigMgr->GetOption<bool>(DCDuelAddon::Config::ENABLED, true);

        if (enabled)
        {
            // Register message handlers
            auto& router = DCAddon::MessageRouter::Instance();

            router.RegisterHandler(DCDuelAddon::MODULE, DCDuelAddon::Opcode::CMSG_GET_STATS,
                DCDuelAddon::HandleGetStats);

            router.RegisterHandler(DCDuelAddon::MODULE, DCDuelAddon::Opcode::CMSG_GET_LEADERBOARD,
                DCDuelAddon::HandleGetLeaderboard);

            router.RegisterHandler(DCDuelAddon::MODULE, DCDuelAddon::Opcode::CMSG_SPECTATE_DUEL,
                DCDuelAddon::HandleSpectateDuel);

            LOG_INFO("dc.addon", "DCDuelAddon: Duel addon handler initialized");
        }
        else
        {
            LOG_INFO("dc.addon", "DCDuelAddon: Duel addon handler disabled in config");
        }
    }
};

void AddSC_dc_addon_duels()
{
    new DCDuelAddonWorldScript();
}
