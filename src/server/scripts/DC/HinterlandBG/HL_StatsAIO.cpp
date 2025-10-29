/*
 * Hinterland BG - Comprehensive Stats AIO Handler
 * Queries all statistics from hlbg_winner_history and sends to client
 * Matches functionality from HL_ScoreboardNPC.cpp but sends via AIO instead of gossip
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Chat.h"
#include "OutdoorPvP/OutdoorPvPHL.h"
#include "DatabaseEnv.h"
#include <sstream>
#include <iomanip>

// JSON-like string builder helper
class StatsPayload
{
public:
    std::ostringstream _ss;  // Made public for array building
    
private:
    bool _first = true;
    
public:
    StatsPayload() { _ss << "{"; }
    
    void AddInt(const char* key, int64 value)
    {
        if (!_first) _ss << ",";
        _ss << "\"" << key << "\":" << value;
        _first = false;
    }
    
    void AddDouble(const char* key, double value)
    {
        if (!_first) _ss << ",";
        _ss << "\"" << key << "\":" << std::fixed << std::setprecision(1) << value;
        _first = false;
    }
    
    void AddString(const char* key, const std::string& value)
    {
        if (!_first) _ss << ",";
        _ss << "\"" << key << "\":\"" << value << "\"";
        _first = false;
    }
    
    void BeginObject(const char* key)
    {
        if (!_first) _ss << ",";
        _ss << "\"" << key << "\":{";
        _first = true;
    }
    
    void EndObject()
    {
        _ss << "}";
        _first = false;
    }
    
    void BeginArray(const char* key)
    {
        if (!_first) _ss << ",";
        _ss << "\"" << key << "\":[";
        _first = true;
    }
    
    void EndArray()
    {
        _ss << "]";
        _first = false;
    }
    
    std::string Build()
    {
        _ss << "}";
        return _ss.str();
    }
};

class HL_StatsCommand : public CommandScript
{
public:
    HL_StatsCommand() : CommandScript("HL_StatsCommand") {}
    
    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable hlbgStatsCommandTable =
        {
            { "statsui", HandleHLBGStatsUICommand, SEC_PLAYER, Console::No },
        };
        
        static ChatCommandTable hlbgCommandTable =
        {
            { "hlbg", hlbgStatsCommandTable },
        };
        
        return hlbgCommandTable;
    }
    
private:
    static const char* AffixName(uint8 affix)
    {
        switch (affix)
        {
            case 0: return "None";
            case 1: return "Haste";
            case 2: return "Slow";
            case 3: return "Reduced Healing";
            case 4: return "Reduced Armor";
            case 5: return "Boss Enrage";
            default: return "Unknown";
        }
    }
    
    static bool HandleHLBGStatsUICommand(ChatHandler* handler, char const* args)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;
        
        // TODO: Parse season from args if provided
        // For now, query all-time stats
        std::string cond = "1=1";  // No filtering
        
        StatsPayload payload;
        
        // Basic counts
        if (QueryResult res = CharacterDatabase.Query(
            "SELECT COUNT(*), SUM(winner_tid=1), SUM(winner_tid=2), SUM(winner_tid=0) FROM hlbg_winner_history WHERE {}",
            cond))
        {
            Field* f = res->Fetch();
            uint64 total = f[0].Get<uint64>();
            uint64 aWins = f[1].Get<uint64>();
            uint64 hWins = f[2].Get<uint64>();
            uint64 draws = f[3].Get<uint64>();
            
            payload.AddInt("totalBattles", total);
            payload.AddInt("allianceWins", aWins);
            payload.AddInt("hordeWins", hWins);
            payload.AddInt("draws", draws);
        }
        
        // Win reasons
        if (QueryResult res = CharacterDatabase.Query(
            "SELECT SUM(win_reason='depletion'), SUM(win_reason='tiebreaker'), SUM(win_reason='manual') FROM hlbg_winner_history WHERE {}",
            cond))
        {
            Field* f = res->Fetch();
            payload.AddInt("depletionWins", f[0].Get<uint64>());
            payload.AddInt("tiebreakerWins", f[1].Get<uint64>());
            payload.AddInt("manualResets", f[2].Get<uint64>());
        }
        
        // Current streak (scan last 200 records)
        {
            QueryResult recent = CharacterDatabase.Query(
                "SELECT winner_tid FROM hlbg_winner_history WHERE {} ORDER BY id DESC LIMIT 200",
                cond);
            
            if (recent)
            {
                Field* f = recent->Fetch();
                uint8 lastTeam = f[0].Get<uint8>();
                uint32 streak = 1;
                
                while (recent->NextRow())
                {
                    f = recent->Fetch();
                    uint8 tid = f[0].Get<uint8>();
                    if (tid == lastTeam)
                        ++streak;
                    else
                        break;
                }
                
                payload.BeginObject("currentStreak");
                const char* teamName = (lastTeam == 1 ? "Alliance" : (lastTeam == 2 ? "Horde" : "None"));
                payload.AddString("team", teamName);
                payload.AddInt("count", streak);
                payload.EndObject();
            }
        }
        
        // Longest streak
        {
            QueryResult recent = CharacterDatabase.Query(
                "SELECT winner_tid FROM hlbg_winner_history WHERE {} ORDER BY id DESC LIMIT 200",
                cond);
            
            if (recent)
            {
                uint8 longestTeam = 0;
                uint32 longestStreak = 0;
                uint8 currentTeam = 0;
                uint32 currentStreak = 0;
                
                do
                {
                    Field* f = recent->Fetch();
                    uint8 tid = f[0].Get<uint8>();
                    
                    if (tid == currentTeam)
                    {
                        ++currentStreak;
                    }
                    else
                    {
                        if (currentStreak > longestStreak)
                        {
                            longestStreak = currentStreak;
                            longestTeam = currentTeam;
                        }
                        currentTeam = tid;
                        currentStreak = 1;
                    }
                } while (recent->NextRow());
                
                // Check last streak
                if (currentStreak > longestStreak)
                {
                    longestStreak = currentStreak;
                    longestTeam = currentTeam;
                }
                
                payload.BeginObject("longestStreak");
                const char* teamName = (longestTeam == 1 ? "Alliance" : (longestTeam == 2 ? "Horde" : "None"));
                payload.AddString("team", teamName);
                payload.AddInt("count", longestStreak);
                payload.EndObject();
            }
        }
        
        // Largest margin
        if (QueryResult res = CharacterDatabase.Query(
            "SELECT occurred_at, winner_tid, score_alliance, score_horde, ABS(score_alliance - score_horde) AS m FROM hlbg_winner_history WHERE {} ORDER BY m DESC LIMIT 1",
            cond))
        {
            Field* f = res->Fetch();
            std::string date = f[0].Get<std::string>();
            uint8 tid = f[1].Get<uint8>();
            uint32 scoreA = f[2].Get<uint32>();
            uint32 scoreH = f[3].Get<uint32>();
            uint32 margin = f[4].Get<uint32>();
            
            payload.BeginObject("largestMargin");
            const char* teamName = (tid == 1 ? "Alliance" : "Horde");
            payload.AddString("team", teamName);
            payload.AddInt("margin", margin);
            payload.AddInt("scoreA", scoreA);
            payload.AddInt("scoreH", scoreH);
            payload.AddString("date", date);
            payload.EndObject();
        }
        
        // Top winners by affix (top 5 affixes, show dominant team)
        payload.BeginArray("topWinnersByAffix");
        if (QueryResult res = CharacterDatabase.Query(
            "SELECT affix, SUM(winner_tid=1) AS a, SUM(winner_tid=2) AS h FROM hlbg_winner_history WHERE {} AND winner_tid IN (1,2) GROUP BY affix ORDER BY (a+h) DESC LIMIT 5",
            cond))
        {
            bool firstEntry = true;
            do
            {
                if (!firstEntry) payload._ss << ",";
                firstEntry = false;
                
                Field* f = res->Fetch();
                uint8 affix = f[0].Get<uint8>();
                uint64 aWins = f[1].Get<uint64>();
                uint64 hWins = f[2].Get<uint64>();
                
                payload._ss << "{";
                payload._ss << "\"affix\":" << (int)affix << ",";
                payload._ss << "\"team\":\"" << (aWins > hWins ? "Alliance" : "Horde") << "\",";
                payload._ss << "\"wins\":" << (aWins > hWins ? aWins : hWins);
                payload._ss << "}";
            } while (res->NextRow());
        }
        payload.EndArray();
        
        // Top affixes by match count
        payload.BeginArray("topAffixes");
        if (QueryResult res = CharacterDatabase.Query(
            "SELECT affix, COUNT(*) AS cnt FROM hlbg_winner_history WHERE {} GROUP BY affix ORDER BY cnt DESC LIMIT 5",
            cond))
        {
            bool firstEntry = true;
            do
            {
                if (!firstEntry) payload._ss << ",";
                firstEntry = false;
                
                Field* f = res->Fetch();
                uint8 affix = f[0].Get<uint8>();
                uint64 matches = f[1].Get<uint64>();
                
                payload._ss << "{\"affix\":" << (int)affix << ",\"matches\":" << matches << "}";
            } while (res->NextRow());
        }
        payload.EndArray();
        
        // Average scores per affix
        payload.BeginArray("avgScoresPerAffix");
        if (QueryResult res = CharacterDatabase.Query(
            "SELECT affix, AVG(score_alliance), AVG(score_horde), COUNT(*) FROM hlbg_winner_history WHERE {} GROUP BY affix ORDER BY affix",
            cond))
        {
            bool firstEntry = true;
            do
            {
                if (!firstEntry) payload._ss << ",";
                firstEntry = false;
                
                Field* f = res->Fetch();
                uint8 affix = f[0].Get<uint8>();
                double avgA = f[1].Get<double>();
                double avgH = f[2].Get<double>();
                uint64 cnt = f[3].Get<uint64>();
                
                payload._ss << "{\"affix\":" << (int)affix;
                payload._ss << ",\"avgAlliance\":" << std::fixed << std::setprecision(1) << avgA;
                payload._ss << ",\"avgHorde\":" << std::fixed << std::setprecision(1) << avgH;
                payload._ss << ",\"matches\":" << cnt << "}";
            } while (res->NextRow());
        }
        payload.EndArray();
        
        // Win rates per affix
        payload.BeginArray("winRatesPerAffix");
        if (QueryResult res = CharacterDatabase.Query(
            "SELECT affix, SUM(winner_tid=1), SUM(winner_tid=2), SUM(winner_tid=0), COUNT(*) FROM hlbg_winner_history WHERE {} GROUP BY affix ORDER BY affix",
            cond))
        {
            bool firstEntry = true;
            do
            {
                if (!firstEntry) payload._ss << ",";
                firstEntry = false;
                
                Field* f = res->Fetch();
                uint8 affix = f[0].Get<uint8>();
                uint64 aWins = f[1].Get<uint64>();
                uint64 hWins = f[2].Get<uint64>();
                uint64 draws = f[3].Get<uint64>();
                uint64 total = f[4].Get<uint64>();
                
                double aPct = total > 0 ? (aWins * 100.0 / total) : 0.0;
                double hPct = total > 0 ? (hWins * 100.0 / total) : 0.0;
                double dPct = total > 0 ? (draws * 100.0 / total) : 0.0;
                
                payload._ss << "{\"affix\":" << (int)affix;
                payload._ss << ",\"alliancePct\":" << std::fixed << std::setprecision(1) << aPct;
                payload._ss << ",\"hordePct\":" << std::fixed << std::setprecision(1) << hPct;
                payload._ss << ",\"drawPct\":" << std::fixed << std::setprecision(1) << dPct;
                payload._ss << ",\"matches\":" << total << "}";
            } while (res->NextRow());
        }
        payload.EndArray();
        
        // Average margin per affix
        payload.BeginArray("avgMarginPerAffix");
        if (QueryResult res = CharacterDatabase.Query(
            "SELECT affix, AVG(ABS(score_alliance - score_horde)), COUNT(*) FROM hlbg_winner_history WHERE {} GROUP BY affix ORDER BY affix",
            cond))
        {
            bool firstEntry = true;
            do
            {
                if (!firstEntry) payload._ss << ",";
                firstEntry = false;
                
                Field* f = res->Fetch();
                uint8 affix = f[0].Get<uint8>();
                double avgMargin = f[1].Get<double>();
                uint64 cnt = f[2].Get<uint64>();
                
                payload._ss << "{\"affix\":" << (int)affix;
                payload._ss << ",\"avgMargin\":" << std::fixed << std::setprecision(1) << avgMargin;
                payload._ss << ",\"matches\":" << cnt << "}";
            } while (res->NextRow());
        }
        payload.EndArray();
        
        // Reason breakdown per affix
        payload.BeginArray("reasonBreakdownPerAffix");
        if (QueryResult res = CharacterDatabase.Query(
            "SELECT affix, SUM(win_reason='depletion'), SUM(win_reason='tiebreaker'), COUNT(*) FROM hlbg_winner_history WHERE {} GROUP BY affix ORDER BY affix",
            cond))
        {
            bool firstEntry = true;
            do
            {
                if (!firstEntry) payload._ss << ",";
                firstEntry = false;
                
                Field* f = res->Fetch();
                uint8 affix = f[0].Get<uint8>();
                uint64 dep = f[1].Get<uint64>();
                uint64 tie = f[2].Get<uint64>();
                uint64 total = f[3].Get<uint64>();
                
                payload._ss << "{\"affix\":" << (int)affix;
                payload._ss << ",\"depletion\":" << dep;
                payload._ss << ",\"tiebreaker\":" << tie;
                payload._ss << ",\"total\":" << total << "}";
            } while (res->NextRow());
        }
        payload.EndArray();
        
        // Average duration per affix (if populated)
        payload.BeginArray("avgDurationPerAffix");
        if (QueryResult res = CharacterDatabase.Query(
            "SELECT affix, AVG(duration_seconds), COUNT(*) FROM hlbg_winner_history WHERE {} AND duration_seconds > 0 GROUP BY affix ORDER BY affix",
            cond))
        {
            bool firstEntry = true;
            do
            {
                if (!firstEntry) payload._ss << ",";
                firstEntry = false;
                
                Field* f = res->Fetch();
                uint8 affix = f[0].Get<uint8>();
                double avgDur = f[1].Get<double>();
                uint64 cnt = f[2].Get<uint64>();
                
                payload._ss << "{\"affix\":" << (int)affix;
                payload._ss << ",\"avgDuration\":" << std::fixed << std::setprecision(1) << avgDur;
                payload._ss << ",\"matches\":" << cnt << "}";
            } while (res->NextRow());
        }
        payload.EndArray();
        
        // Build final JSON and send
        std::string json = payload.Build();
        
        // Send via chat message with special marker (AIO handler will intercept)
        std::string msg = "[HLBG_STATS_JSON] " + json;
        ChatHandler(player->GetSession()).SendSysMessage(msg.c_str());
        
        return true;
    }
};

void AddSC_hl_stats_aio()
{
    new HL_StatsCommand();
}
