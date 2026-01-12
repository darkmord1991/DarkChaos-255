/*
 * DC Performance Testing System (.stresstest)
 * 
 * Provides stress testing tools for SQL, Cache, and Subsystems.
 * COMMAND: .stresstest <subcommand>
 * PERMISSION: GM only (SEC_GAMEMASTER)
 */

#include "ScriptMgr.h"
#include "Chat.h"
#include "CommandScript.h"
#include "ChatCommand.h"
#include "Player.h"
#include "DatabaseEnv.h"
#include "World.h"
#include "ObjectMgr.h"
#include "Log.h"
#include "PathGenerator.h"
#include "Random.h"
#include "SpellMgr.h"
#include <chrono>
#include <vector>
#include <algorithm>
#include <numeric>
#include <sstream>
#include <cmath>
#include <thread>
#include <iomanip>
#include <fstream>
#include <filesystem>
#include <ctime>

namespace DCPerfTest
{
    // Timing utilities
    using Clock = std::chrono::high_resolution_clock;
    using Microseconds = std::chrono::microseconds;
    using Milliseconds = std::chrono::milliseconds;

    struct TimingResult
    {
        std::string testName;
        uint64 totalUs = 0;
        uint64 avgUs = 0;
        uint64 minUs = 0;
        uint64 maxUs = 0;
        uint64 p95Us = 0;
        uint64 p99Us = 0;
        uint32 iterations = 0;
        bool success = false;
        std::string error;
    };

    // Calculate percentile from sorted vector
    uint64 GetPercentile(const std::vector<uint64>& sortedTimes, float percentile)
    {
        if (sortedTimes.empty())
            return 0;

        // percentile is in [0..100]
        // Use the common definition based on (n-1) to avoid off-by-one skew.
        float p = std::max(0.0f, std::min(100.0f, percentile)) / 100.0f;
        size_t n = sortedTimes.size();
        size_t index = static_cast<size_t>(p * float(n - 1));
        return sortedTimes[index];
    }

    // Format microseconds as human-readable
    std::string FormatTime(uint64 us)
    {
        std::ostringstream out;
        if (us >= 1000000)
        {
            uint64 seconds = us / 1000000;
            uint64 ms = (us / 1000) % 1000;
            out << seconds << '.' << std::setw(3) << std::setfill('0') << ms << 's';
            return out.str();
        }
        if (us >= 1000)
        {
            uint64 ms = us / 1000;
            uint64 rem = us % 1000;
            out << ms << '.' << std::setw(3) << std::setfill('0') << rem << "ms";
            return out.str();
        }
        out << us << "us";
        return out.str();
    }

    static std::string JsonEscape(std::string const& in)
    {
        std::string out;
        out.reserve(in.size() + 8);

        for (unsigned char c : in)
        {
            switch (c)
            {
                case '\\': out += "\\\\"; break;
                case '"': out += "\\\""; break;
                case '\b': out += "\\b"; break;
                case '\f': out += "\\f"; break;
                case '\n': out += "\\n"; break;
                case '\r': out += "\\r"; break;
                case '\t': out += "\\t"; break;
                default:
                {
                    if (c < 0x20)
                    {
                        std::ostringstream oss;
                        oss << "\\u" << std::hex << std::setw(4) << std::setfill('0') << int(c);
                        out += oss.str();
                    }
                    else
                    {
                        out.push_back(static_cast<char>(c));
                    }
                    break;
                }
            }
        }
        return out;
    }

    static std::string CsvEscape(std::string const& in)
    {
        bool needsQuotes = false;
        for (char c : in)
        {
            if (c == ',' || c == '"' || c == '\n' || c == '\r')
            {
                needsQuotes = true;
                break;
            }
        }

        if (!needsQuotes)
            return in;

        std::string out;
        out.reserve(in.size() + 2);
        out.push_back('"');
        for (char c : in)
        {
            if (c == '"')
                out += "\"\"";
            else
                out.push_back(c);
        }
        out.push_back('"');
        return out;
    }

    static std::string MakeTimestampForFilename()
    {
        std::time_t t = std::time(nullptr);
        std::tm tmLocal{};
#if defined(_WIN32)
        localtime_s(&tmLocal, &t);
#else
        localtime_r(&t, &tmLocal);
#endif
        char buf[32];
        std::snprintf(buf, sizeof(buf), "%04d%02d%02d-%02d%02d%02d",
            tmLocal.tm_year + 1900,
            tmLocal.tm_mon + 1,
            tmLocal.tm_mday,
            tmLocal.tm_hour,
            tmLocal.tm_min,
            tmLocal.tm_sec);
        return std::string(buf);
    }

    static bool WriteReportJson(std::string const& filePath,
        std::string const& suite,
        uint32 topN,
        bool details,
        uint64 wallUs,
        std::vector<TimingResult> const& results,
        std::string& outError)
    {
        try
        {
            std::ofstream out(filePath, std::ios::out | std::ios::trunc);
            if (!out.is_open())
            {
                outError = "Failed to open file for writing";
                return false;
            }

            out << "{\n";
            out << "  \"suite\": \"" << JsonEscape(suite) << "\",\n";
            out << "  \"topN\": " << topN << ",\n";
            out << "  \"details\": " << (details ? "true" : "false") << ",\n";
            out << "  \"wall_us\": " << wallUs << ",\n";
            out << "  \"generated_at\": \"" << JsonEscape(MakeTimestampForFilename()) << "\",\n";
            out << "  \"results\": [\n";

            for (size_t i = 0; i < results.size(); ++i)
            {
                TimingResult const& r = results[i];
                out << "    {";
                out << "\"testName\":\"" << JsonEscape(r.testName) << "\",";
                out << "\"success\":" << (r.success ? "true" : "false") << ",";
                out << "\"iterations\":" << r.iterations << ",";
                out << "\"total_us\":" << r.totalUs << ",";
                out << "\"avg_us\":" << r.avgUs << ",";
                out << "\"min_us\":" << r.minUs << ",";
                out << "\"max_us\":" << r.maxUs << ",";
                out << "\"p95_us\":" << r.p95Us << ",";
                out << "\"p99_us\":" << r.p99Us << ",";
                out << "\"error\":\"" << JsonEscape(r.error) << "\"";
                out << "}";
                if (i + 1 < results.size())
                    out << ",";
                out << "\n";
            }

            out << "  ]\n";
            out << "}\n";
            return true;
        }
        catch (std::exception const& e)
        {
            outError = e.what();
            return false;
        }
    }

    static bool WriteReportCsv(std::string const& filePath,
        std::string const& suite,
        uint32 topN,
        bool details,
        uint64 wallUs,
        std::vector<TimingResult> const& results,
        std::string& outError)
    {
        try
        {
            std::ofstream out(filePath, std::ios::out | std::ios::trunc);
            if (!out.is_open())
            {
                outError = "Failed to open file for writing";
                return false;
            }

            out << "suite," << CsvEscape(suite) << "\n";
            out << "topN," << topN << "\n";
            out << "details," << (details ? 1 : 0) << "\n";
            out << "wall_us," << wallUs << "\n";
            out << "generated_at," << CsvEscape(MakeTimestampForFilename()) << "\n";
            out << "\n";
            out << "testName,success,iterations,total_us,avg_us,min_us,max_us,p95_us,p99_us,error\n";

            for (TimingResult const& r : results)
            {
                out << CsvEscape(r.testName) << ",";
                out << (r.success ? 1 : 0) << ",";
                out << r.iterations << ",";
                out << r.totalUs << ",";
                out << r.avgUs << ",";
                out << r.minUs << ",";
                out << r.maxUs << ",";
                out << r.p95Us << ",";
                out << r.p99Us << ",";
                out << CsvEscape(r.error) << "\n";
            }
            return true;
        }
        catch (std::exception const& e)
        {
            outError = e.what();
            return false;
        }
    }

    static std::string JoinPath(std::string const& dir, std::string const& file)
    {
        if (dir.empty())
            return file;
        if (dir.back() == '/' || dir.back() == '\\')
            return dir + file;
        return dir + '/' + file;
    }

    static bool WriteReportToLogsDir(std::string const& format,
        std::string const& suite,
        uint32 topN,
        bool details,
        uint64 wallUs,
        std::vector<TimingResult> const& results,
        std::string& outFullPath,
        std::string& outError)
    {
        std::string logsDir = sLog->GetLogsDir();
        std::string ts = MakeTimestampForFilename();
        std::string ext = (format == "csv") ? ".csv" : ".json";
        std::string filename = "stresstest-report-" + suite + "-" + ts + ext;
        outFullPath = JoinPath(logsDir, filename);

        if (!logsDir.empty())
        {
            try
            {
                std::filesystem::create_directories(std::filesystem::path(logsDir));
            }
            catch (...) { }
        }

        if (format == "csv")
            return WriteReportCsv(outFullPath, suite, topN, details, wallUs, results, outError);

        return WriteReportJson(outFullPath, suite, topN, details, wallUs, results, outError);
    }

    static std::string MakeLoopReportFilePath(std::string const& suite, std::string const& format)
    {
        std::string logsDir = sLog->GetLogsDir();
        std::string ts = MakeTimestampForFilename();
        std::string ext = (format == "csv") ? ".csv" : ".json";
        std::string filename = "stresstest-loopreport-" + suite + "-" + ts + ext;
        return JoinPath(logsDir, filename);
    }

    static void WriteLoopReportJsonHeader(std::ofstream& out,
        std::string const& suite,
        uint32 loops,
        bool infinite,
        uint32 sleepMs,
        uint32 topN,
        bool details,
        std::string const& format,
        std::string const& suiteArgs)
    {
        out << "{\n";
        out << "  \"suite\": \"" << JsonEscape(suite) << "\",\n";
        out << "  \"format\": \"" << JsonEscape(format) << "\",\n";
        out << "  \"loops\": " << loops << ",\n";
        out << "  \"infinite\": " << (infinite ? "true" : "false") << ",\n";
        out << "  \"sleep_ms\": " << sleepMs << ",\n";
        out << "  \"topN\": " << topN << ",\n";
        out << "  \"details\": " << (details ? "true" : "false") << ",\n";
        out << "  \"suite_args\": \"" << JsonEscape(suiteArgs) << "\",\n";
        out << "  \"generated_at\": \"" << JsonEscape(MakeTimestampForFilename()) << "\",\n";
        out << "  \"runs\": [\n";
    }

    static void WriteLoopReportJsonRun(std::ofstream& out,
        uint32 runIndex,
        uint64 wallUs,
        std::vector<TimingResult> const& results,
        bool first)
    {
        if (!first)
            out << ",\n";

        out << "    {\n";
        out << "      \"run_index\": " << runIndex << ",\n";
        out << "      \"wall_us\": " << wallUs << ",\n";
        out << "      \"results\": [\n";

        for (size_t i = 0; i < results.size(); ++i)
        {
            TimingResult const& r = results[i];
            out << "        {";
            out << "\"testName\":\"" << JsonEscape(r.testName) << "\",";
            out << "\"success\":" << (r.success ? "true" : "false") << ",";
            out << "\"iterations\":" << r.iterations << ",";
            out << "\"total_us\":" << r.totalUs << ",";
            out << "\"avg_us\":" << r.avgUs << ",";
            out << "\"min_us\":" << r.minUs << ",";
            out << "\"max_us\":" << r.maxUs << ",";
            out << "\"p95_us\":" << r.p95Us << ",";
            out << "\"p99_us\":" << r.p99Us << ",";
            out << "\"error\":\"" << JsonEscape(r.error) << "\"";
            out << "}";
            if (i + 1 < results.size())
                out << ",";
            out << "\n";
        }

        out << "      ]\n";
        out << "    }";
    }

    static void WriteLoopReportJsonFooter(std::ofstream& out)
    {
        out << "\n  ]\n";
        out << "}\n";
    }

    static void WriteLoopReportCsvHeader(std::ofstream& out,
        std::string const& suite,
        uint32 loops,
        bool infinite,
        uint32 sleepMs,
        uint32 topN,
        bool details,
        std::string const& format,
        std::string const& suiteArgs)
    {
        out << "suite," << CsvEscape(suite) << "\n";
        out << "format," << CsvEscape(format) << "\n";
        out << "loops," << loops << "\n";
        out << "infinite," << (infinite ? 1 : 0) << "\n";
        out << "sleep_ms," << sleepMs << "\n";
        out << "topN," << topN << "\n";
        out << "details," << (details ? 1 : 0) << "\n";
        out << "suite_args," << CsvEscape(suiteArgs) << "\n";
        out << "generated_at," << CsvEscape(MakeTimestampForFilename()) << "\n";
        out << "\n";
        out << "run_index,wall_us,testName,success,iterations,total_us,avg_us,min_us,max_us,p95_us,p99_us,error\n";
    }

    static void WriteLoopReportCsvRun(std::ofstream& out,
        uint32 runIndex,
        uint64 wallUs,
        std::vector<TimingResult> const& results)
    {
        for (TimingResult const& r : results)
        {
            out << runIndex << ",";
            out << wallUs << ",";
            out << CsvEscape(r.testName) << ",";
            out << (r.success ? 1 : 0) << ",";
            out << r.iterations << ",";
            out << r.totalUs << ",";
            out << r.avgUs << ",";
            out << r.minUs << ",";
            out << r.maxUs << ",";
            out << r.p95Us << ",";
            out << r.p99Us << ",";
            out << CsvEscape(r.error) << "\n";
        }
    }

    // Any SQL error causes a hard abort in AzerothCore's DB layer, so we must
    // avoid querying tables that may not exist on a given installation.
    bool CharacterTableExists(char const* tableName)
    {
        std::ostringstream sql;
        sql << "SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '" << tableName << "' LIMIT 1";
        return CharacterDatabase.Query(sql.str().c_str()) != nullptr;
    }

    bool CharacterColumnExists(char const* tableName, char const* columnName)
    {
        std::ostringstream sql;
        sql << "SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '" << tableName
            << "' AND COLUMN_NAME = '" << columnName << "' LIMIT 1";
        return CharacterDatabase.Query(sql.str().c_str()) != nullptr;
    }

    bool WorldTableExists(char const* tableName)
    {
        std::ostringstream sql;
        sql << "SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '" << tableName << "' LIMIT 1";
        return WorldDatabase.Query(sql.str().c_str()) != nullptr;
    }

    bool WorldColumnExists(char const* tableName, char const* columnName)
    {
        std::ostringstream sql;
        sql << "SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '" << tableName
            << "' AND COLUMN_NAME = '" << columnName << "' LIMIT 1";
        return WorldDatabase.Query(sql.str().c_str()) != nullptr;
    }

    // =========================================================================
    // SQL Stress Tests
    // =========================================================================

    TimingResult TestBulkSelect(uint32 rowCount)
    {
        TimingResult result;
        result.testName = "Bulk SELECT (" + std::to_string(rowCount) + " rows)";
        result.iterations = 1;
        result.success = true;

        auto start = Clock::now();

        try
        {
            // Query character data - common operation
            std::ostringstream sql;
            sql << "SELECT guid, name, level, class, race FROM characters LIMIT " << rowCount;
            QueryResult qr = CharacterDatabase.Query(sql.str().c_str());

            if (!qr)
            {
                // Try world database table if characters empty
                sql.str("");
                sql << "SELECT entry, name, subname, minlevel, maxlevel FROM creature_template LIMIT " << rowCount;
                qr = WorldDatabase.Query(sql.str().c_str());
            }

            uint32 fetchedRows = 0;
            if (qr)
            {
                do
                {
                    fetchedRows++;
                } while (qr->NextRow());
            }

            auto end = Clock::now();
            result.totalUs = std::chrono::duration_cast<Microseconds>(end - start).count();
            result.avgUs = fetchedRows > 0 ? result.totalUs / fetchedRows : result.totalUs;
            result.minUs = result.avgUs;
            result.maxUs = result.avgUs;
            result.p95Us = result.avgUs;
            result.p99Us = result.avgUs;

            if (fetchedRows < rowCount)
            {
                result.testName += " [actual: " + std::to_string(fetchedRows) + "]";
            }
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }

    TimingResult TestRepeatedQueries(uint32 iterations)
    {
        TimingResult result;
        result.testName = "Repeated SELECT (" + std::to_string(iterations) + " queries)";
        result.iterations = iterations;
        result.success = true;

        std::vector<uint64> times;
        times.reserve(iterations);

        try
        {
            for (uint32 i = 0; i < iterations; ++i)
            {
                auto start = Clock::now();
                
                // Simple query that should hit cache after first run
                QueryResult qr = WorldDatabase.Query("SELECT entry FROM creature_template WHERE entry = 1");
                
                auto end = Clock::now();
                times.push_back(std::chrono::duration_cast<Microseconds>(end - start).count());
            }

            std::sort(times.begin(), times.end());
            
            result.totalUs = std::accumulate(times.begin(), times.end(), 0ULL);
            result.avgUs = result.totalUs / iterations;
            result.minUs = times.front();
            result.maxUs = times.back();
            result.p95Us = GetPercentile(times, 95.0f);
            result.p99Us = GetPercentile(times, 99.0f);
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }

    TimingResult TestTransactionBatch(uint32 batchSize)
    {
        TimingResult result;
        result.testName = "Transaction Batch (" + std::to_string(batchSize) + " ops)";
        result.iterations = 1;
        result.success = true;

        auto start = Clock::now();

        try
        {
            // Use a temporary test table approach - just measure transaction overhead
            // We'll insert and immediately delete to avoid permanent data changes
            SQLTransaction trans = CharacterDatabase.BeginTransaction();

            // Use the existing log table with a very high fight_id range that should never overlap real data.
            // Table schema is stable in core: (fight_id, member_id, name, guid, team, account, ip, damage, heal, kblows)
            static constexpr uint32 FightIdBase = 4290000000U;
            static constexpr uint32 MemberIdMod = 200U; // <= 255 (tinyint)

            for (uint32 i = 0; i < batchSize; ++i)
            {
                std::ostringstream sql;
                uint32 fightId = FightIdBase + (i / MemberIdMod);
                uint32 memberId = (i % MemberIdMod);
                uint32 fakeGuid = 4000000000U - (i % 1000000U);
                sql << "REPLACE INTO log_arena_memberstats (fight_id, member_id, name, guid, team, account, ip, damage, heal, kblows) VALUES ("
                    << fightId << ", " << memberId << ", 'StressTest', " << fakeGuid
                    << ", 0, 0, '127.0.0.1', 0, 0, 0)";
                trans->Append(sql.str().c_str());
            }

            // Cleanup our test data
            trans->Append("DELETE FROM log_arena_memberstats WHERE fight_id >= 4290000000");
            
            CharacterDatabase.CommitTransaction(trans);

            auto end = Clock::now();
            result.totalUs = std::chrono::duration_cast<Microseconds>(end - start).count();
            result.avgUs = result.totalUs / batchSize;
            result.minUs = result.avgUs;
            result.maxUs = result.avgUs;
            result.p95Us = result.avgUs;
            result.p99Us = result.avgUs;
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }

    TimingResult TestDCTableQueries()
    {
        TimingResult result;
        result.testName = "DC Table Queries (core tables)";
        result.success = true;

        std::vector<uint64> times;
        
        // List of common DC tables to test (skip missing tables to avoid DB abort).
        const char* dcTables[] = {
            "dc_character_prestige",
            "dc_item_upgrades",
            "dc_mount_collection",
            "dc_pet_collection",
            "dc_heirloom_collection",
            "dc_transmog_collection",
            // legacy/alternate names
            "dc_collection_mounts",
            "dc_collection_pets",
            "dc_collection_heirlooms",
            "dc_collection_transmog",
            "dc_guild_house",
            "dc_guild_house_log"
        };

        uint32 skipped = 0;

        try
        {
            for (char const* table : dcTables)
            {
                if (!CharacterTableExists(table))
                {
                    ++skipped;
                    continue;
                }

                auto start = Clock::now();
                std::ostringstream sql;
                sql << "SELECT COUNT(*) FROM " << table;
                QueryResult qr = CharacterDatabase.Query(sql.str().c_str());
                auto end = Clock::now();

                if (qr)
                    times.push_back(std::chrono::duration_cast<Microseconds>(end - start).count());
            }

            if (!times.empty())
            {
                std::sort(times.begin(), times.end());
                result.iterations = times.size();
                result.totalUs = std::accumulate(times.begin(), times.end(), 0ULL);
                result.avgUs = result.totalUs / times.size();
                result.minUs = times.front();
                result.maxUs = times.back();
                result.p95Us = GetPercentile(times, 95.0f);
                result.p99Us = GetPercentile(times, 99.0f);
            }
            else
            {
                result.success = false;
                result.error = "No DC tables found (skipped " + std::to_string(skipped) + ")";
            }
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }

    // =========================================================================
    // Cache Performance Tests
    // =========================================================================

    TimingResult TestObjectMgrCache()
    {
        TimingResult result;
        result.testName = "ObjectMgr Cache (creature templates)";
        result.success = true;

        std::vector<uint64> times;
        const uint32 iterations = 10000;
        times.reserve(iterations);

        try
        {
            for (uint32 i = 0; i < iterations; ++i)
            {
                uint32 entry = (i % 1000) + 1; // Cycle through entries 1-1000
                
                auto start = Clock::now();
                sObjectMgr->GetCreatureTemplate(entry);
                auto end = Clock::now();
                
                times.push_back(std::chrono::duration_cast<Microseconds>(end - start).count());
            }

            std::sort(times.begin(), times.end());
            
            result.iterations = iterations;
            result.totalUs = std::accumulate(times.begin(), times.end(), 0ULL);
            result.avgUs = result.totalUs / iterations;
            result.minUs = times.front();
            result.maxUs = times.back();
            result.p95Us = GetPercentile(times, 95.0f);
            result.p99Us = GetPercentile(times, 99.0f);
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }

    TimingResult TestItemTemplateCache()
    {
        TimingResult result;
        result.testName = "ItemTemplate Cache (10k lookups)";
        result.success = true;

        std::vector<uint64> times;
        const uint32 iterations = 10000;
        times.reserve(iterations);

        try
        {
            for (uint32 i = 0; i < iterations; ++i)
            {
                uint32 entry = (i % 5000) + 1; // Cycle through item entries
                
                auto start = Clock::now();
                sObjectMgr->GetItemTemplate(entry);
                auto end = Clock::now();
                
                times.push_back(std::chrono::duration_cast<Microseconds>(end - start).count());
            }

            std::sort(times.begin(), times.end());
            
            result.iterations = iterations;
            result.totalUs = std::accumulate(times.begin(), times.end(), 0ULL);
            result.avgUs = result.totalUs / iterations;
            result.minUs = times.front();
            result.maxUs = times.back();
            result.p95Us = GetPercentile(times, 95.0f);
            result.p99Us = GetPercentile(times, 99.0f);
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }

    // =========================================================================
    // MySQL Status Query
    // =========================================================================

    void PrintMySQLStatus(ChatHandler* handler)
    {
        handler->SendSysMessage("|cff00ff00=== MySQL Status ===|r");

        // Query MySQL variables
        QueryResult qr = CharacterDatabase.Query("SHOW STATUS LIKE 'Threads_connected'");
        if (qr)
        {
            Field* f = qr->Fetch();
            handler->SendSysMessage(Acore::StringFormat("Threads Connected: {}", f[1].Get<std::string>()));
        }

        qr = CharacterDatabase.Query("SHOW STATUS LIKE 'Questions'");
        if (qr)
        {
            Field* f = qr->Fetch();
            handler->SendSysMessage(Acore::StringFormat("Total Queries: {}", f[1].Get<std::string>()));
        }

        qr = CharacterDatabase.Query("SHOW STATUS LIKE 'Slow_queries'");
        if (qr)
        {
            Field* f = qr->Fetch();
            handler->SendSysMessage(Acore::StringFormat("Slow Queries: {}", f[1].Get<std::string>()));
        }

        qr = CharacterDatabase.Query("SHOW STATUS LIKE 'Uptime'");
        if (qr)
        {
            Field* f = qr->Fetch();
            uint32 uptime = f[1].Get<uint32>();
            handler->SendSysMessage(Acore::StringFormat("Uptime: {}s", uptime));
        }

        qr = CharacterDatabase.Query("SHOW STATUS LIKE 'Innodb_buffer_pool_read_requests'");
        QueryResult qr2 = CharacterDatabase.Query("SHOW STATUS LIKE 'Innodb_buffer_pool_reads'");
        if (qr && qr2)
        {
             Field* f1 = qr->Fetch();
             Field* f2 = qr2->Fetch();
             uint64 reqs = f1[1].Get<uint64>();
             uint64 reads = f2[1].Get<uint64>();

             if (reqs > 0)
             {
                 double hitRate = 100.0 * (1.0 - (double)reads / (double)reqs);
                 handler->SendSysMessage(Acore::StringFormat("InnoDB Buffer Pool Hit Rate: {:.2f}%", hitRate));
             }
        }

        qr = CharacterDatabase.Query("SHOW STATUS LIKE 'Qcache_hits'");
        qr2 = CharacterDatabase.Query("SHOW STATUS LIKE 'Com_select'");
        if (qr && qr2)
        {
            Field* f1 = qr->Fetch();
            Field* f2 = qr2->Fetch();
            uint64 hits = f1[1].Get<uint64>(); // Query Cache Hits
            uint64 selects = f2[1].Get<uint64>(); // Total Selects (approx)

            if (selects + hits > 0)
            {
                 // Note: Qcache is deprecated in MySQL 8.0, so this might always be 0
                 // but checking just in case.
                  handler->SendSysMessage(Acore::StringFormat("Query Cache Hits: {}", hits));
            }
        }
    }

    // =========================================================================
    // Additional Stress Tests
    // =========================================================================

    TimingResult TestAsyncQueryBurst(uint32 totalQueries, uint32 concurrency)
    {
        TimingResult result;
        result.testName = "Async DB Query Burst (" + std::to_string(totalQueries) + " queries, conc=" + std::to_string(concurrency) + ")";
        result.iterations = totalQueries;
        result.success = true;

        if (totalQueries == 0 || concurrency == 0)
        {
            result.success = false;
            result.error = "Invalid arguments";
            return result;
        }

        // This burst targets a World DB table (creature_template). If run against the
        // characters DB, it will abort the server with "table doesn't exist".
        if (!WorldTableExists("creature_template"))
        {
            result.success = false;
            result.error = "Missing world table creature_template";
            return result;
        }

        std::vector<uint64> times;
        times.reserve(totalQueries);

        // Each slot holds one in-flight async query
        struct Slot
        {
            QueryCallback cb;
            Clock::time_point start;
        };

        auto MakeQuery = [](uint32 i)
        {
            // Keep query simple and deterministic; vary the entry to avoid identical query text.
            std::ostringstream sql;
            sql << "SELECT name FROM creature_template WHERE entry = " << (1 + (i % 5000));
            return sql.str();
        };

        auto overallStart = Clock::now();

        std::vector<Slot> slots;
        slots.reserve(concurrency);

        uint32 issued = 0;
        uint32 completed = 0;

        // Prime the pipeline
        for (uint32 s = 0; s < concurrency && issued < totalQueries; ++s)
        {
            std::string sql = MakeQuery(issued++);
            Slot slot{ WorldDatabase.AsyncQuery(sql).WithCallback([](QueryResult) {}), Clock::now() };
            slots.push_back(std::move(slot));
        }

        while (completed < totalQueries)
        {
            bool anyProgress = false;

            for (auto& slot : slots)
            {
                if (!slot.cb.InvokeIfReady())
                    continue;

                auto end = Clock::now();
                times.push_back(std::chrono::duration_cast<Microseconds>(end - slot.start).count());
                completed++;
                anyProgress = true;

                if (issued < totalQueries)
                {
                    std::string sql = MakeQuery(issued++);
                    slot.start = Clock::now();
                    slot.cb = WorldDatabase.AsyncQuery(sql).WithCallback([](QueryResult) {});
                }
                else
                {
                    // No more work to issue; leave slot idle.
                }
            }

            // Avoid busy spinning when DB worker threads are saturated.
            if (!anyProgress)
                std::this_thread::sleep_for(std::chrono::milliseconds(1));
        }

        auto overallEnd = Clock::now();
        result.totalUs = std::chrono::duration_cast<Microseconds>(overallEnd - overallStart).count();

        if (!times.empty())
        {
            std::sort(times.begin(), times.end());
            result.avgUs = result.totalUs / totalQueries;
            result.minUs = times.front();
            result.maxUs = times.back();
            result.p95Us = GetPercentile(times, 95.0f);
            result.p99Us = GetPercentile(times, 99.0f);
        }

        return result;
    }

    TimingResult TestPathfinding(Player* player, uint32 iterations)
    {
        TimingResult result;
        result.testName = "Pathfinding (" + std::to_string(iterations) + " paths)";
        result.iterations = iterations;
        result.success = true;

        if (!player)
        {
            result.success = false;
            result.error = "Player context required (in-game only)";
            return result;
        }

        if (iterations == 0)
        {
            result.success = false;
            result.error = "iterations must be > 0";
            return result;
        }

        std::vector<uint64> times;
        times.reserve(iterations);

        // Keep radius modest so dest points are usually on the same map chunk.
        float const radius = 60.0f;
        float const twoPi = 6.28318530718f;

        try
        {
            for (uint32 i = 0; i < iterations; ++i)
            {
                float ang = frand(0.0f, twoPi);
                float dist = frand(5.0f, radius);
                float destX = player->GetPositionX() + std::cos(ang) * dist;
                float destY = player->GetPositionY() + std::sin(ang) * dist;
                float destZ = player->GetPositionZ();

                auto start = Clock::now();

                PathGenerator path(player);
                path.CalculatePath(destX, destY, destZ, false);

                auto end = Clock::now();
                times.push_back(std::chrono::duration_cast<Microseconds>(end - start).count());
            }

            if (!times.empty())
            {
                std::sort(times.begin(), times.end());
                result.totalUs = std::accumulate(times.begin(), times.end(), 0ULL);
                result.avgUs = result.totalUs / iterations;
                result.minUs = times.front();
                result.maxUs = times.back();
                result.p95Us = GetPercentile(times, 95.0f);
                result.p99Us = GetPercentile(times, 99.0f);
            }
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }

    // =========================================================================
    // Report Printing
    // =========================================================================

    void PrintResult(ChatHandler* handler, const TimingResult& result)
    {
        if (!result.success)
        {
            handler->SendSysMessage(Acore::StringFormat("|cffff0000{}: FAILED - {}|r", result.testName, result.error));
            return;
        }

        handler->SendSysMessage(Acore::StringFormat("|cffffffff{}|r", result.testName));
        handler->SendSysMessage(Acore::StringFormat("  Total: {} | Avg: {} | Min: {} | Max: {}",
            FormatTime(result.totalUs),
            FormatTime(result.avgUs),
            FormatTime(result.minUs),
            FormatTime(result.maxUs)));
        
        if (result.iterations > 1)
        {
            handler->SendSysMessage(Acore::StringFormat("  P95: {} | P99: {} ({} iterations)",
                FormatTime(result.p95Us),
                FormatTime(result.p99Us),
                result.iterations));
        }
    }

    void PrintReportSummary(ChatHandler* handler, std::vector<TimingResult> const& results, uint32 topN)
    {
        if (!handler)
            return;

        uint32 okCount = 0;
        uint32 failCount = 0;
        uint64 okTotalUs = 0;

        for (TimingResult const& r : results)
        {
            if (r.success)
            {
                ++okCount;
                okTotalUs += r.totalUs;
            }
            else
            {
                ++failCount;
            }
        }

        handler->SendSysMessage("|cff00ff00=== StressTest Report Summary ===|r");
        handler->SendSysMessage(Acore::StringFormat("Tests: {} ok, {} failed | Total measured: {}",
            okCount, failCount, FormatTime(okTotalUs)));

        if (results.empty())
            return;

        std::vector<TimingResult const*> ok;
        ok.reserve(results.size());
        for (TimingResult const& r : results)
            if (r.success)
                ok.push_back(&r);

        if (ok.empty())
            return;

        auto byTotalDesc = [](TimingResult const* a, TimingResult const* b) { return a->totalUs > b->totalUs; };
        auto byAvgDesc = [](TimingResult const* a, TimingResult const* b) { return a->avgUs > b->avgUs; };

        std::sort(ok.begin(), ok.end(), byTotalDesc);
        if (topN == 0)
            topN = 10;
        if (topN > ok.size())
            topN = static_cast<uint32>(ok.size());

        handler->SendSysMessage(Acore::StringFormat("|cff00ff00Top {} (by total time)|r", topN));
        for (uint32 i = 0; i < topN; ++i)
        {
            TimingResult const& r = *ok[i];
            handler->SendSysMessage(Acore::StringFormat("#{} {} | total {} | avg {} | p95 {} | p99 {} | iters {}",
                i + 1,
                r.testName,
                FormatTime(r.totalUs),
                FormatTime(r.avgUs),
                FormatTime(r.p95Us),
                FormatTime(r.p99Us),
                r.iterations));
        }

        std::sort(ok.begin(), ok.end(), byAvgDesc);
        handler->SendSysMessage(Acore::StringFormat("|cff00ff00Top {} (by avg latency)|r", topN));
        for (uint32 i = 0; i < topN; ++i)
        {
            TimingResult const& r = *ok[i];
            handler->SendSysMessage(Acore::StringFormat("#{} {} | avg {} | p95 {} | p99 {} | total {} | iters {}",
                i + 1,
                r.testName,
                FormatTime(r.avgUs),
                FormatTime(r.p95Us),
                FormatTime(r.p99Us),
                FormatTime(r.totalUs),
                r.iterations));
        }

        if (failCount)
        {
            handler->SendSysMessage("|cffffaa00Failed tests|r");
            for (TimingResult const& r : results)
                if (!r.success)
                    handler->SendSysMessage(Acore::StringFormat("- {}: {}", r.testName, r.error));
        }
    }

    // =========================================================================
    // Extended Stress Tests
    // =========================================================================

    TimingResult TestItemUpgradeStateLookups(uint32 iterations)
    {
        TimingResult result;
        result.testName = "ItemUpgrade State Lookups (" + std::to_string(iterations) + " queries)";
        result.iterations = iterations;
        result.success = true;

        std::vector<uint64> times;
        times.reserve(iterations);

        if (!CharacterTableExists("dc_item_upgrades"))
        {
            result.success = false;
            result.error = "Missing table dc_item_upgrades";
            return result;
        }

        bool hasSeasonId = CharacterColumnExists("dc_item_upgrades", "season_id");
        bool hasSeason = CharacterColumnExists("dc_item_upgrades", "season");

        try
        {
            // Query dc_item_upgrades for random item GUIDs
            for (uint32 i = 0; i < iterations; ++i)
            {
                uint32 fakeItemGuid = 100000 + (i * 7) % 50000; // Spread across range
                
                auto start = Clock::now();
                std::ostringstream sql;
                sql << "SELECT item_guid, tier_id, upgrade_level";
                if (hasSeasonId)
                    sql << ", season_id";
                else if (hasSeason)
                    sql << ", season";
                sql << " FROM dc_item_upgrades WHERE item_guid = " << fakeItemGuid;
                QueryResult qr = CharacterDatabase.Query(sql.str().c_str());
                auto end = Clock::now();
                
                times.push_back(std::chrono::duration_cast<Microseconds>(end - start).count());
            }

            if (!times.empty())
            {
                std::sort(times.begin(), times.end());
                result.totalUs = std::accumulate(times.begin(), times.end(), 0ULL);
                result.avgUs = result.totalUs / iterations;
                result.minUs = times.front();
                result.maxUs = times.back();
                result.p95Us = GetPercentile(times, 95.0f);
                result.p99Us = GetPercentile(times, 99.0f);
            }
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }

    TimingResult TestCollectionTableQueries(uint32 iterations)
    {
        TimingResult result;
        result.testName = "Collection Table Queries (" + std::to_string(iterations) + " queries)";
        result.iterations = iterations;
        result.success = true;

        std::vector<uint64> times;
        times.reserve(iterations);

        // Cycle through different collection tables (support both current and legacy names).
        const char* tables[] = {
            "dc_mount_collection",
            "dc_pet_collection",
            "dc_heirloom_collection",
            "dc_transmog_collection",
            // legacy/alternate names
            "dc_collection_mounts",
            "dc_collection_pets",
            "dc_collection_heirlooms",
            "dc_collection_transmog"
        };

        std::vector<char const*> existingTables;
        existingTables.reserve(std::size(tables));
        for (char const* table : tables)
            if (CharacterTableExists(table))
                existingTables.push_back(table);

        if (existingTables.empty())
        {
            result.testName += " [SKIPPED: no collection tables present]";
            result.iterations = 0;
            result.totalUs = result.avgUs = result.minUs = result.maxUs = result.p95Us = result.p99Us = 0;
            return result;
        }

        try
        {
            for (uint32 i = 0; i < iterations; ++i)
            {
                uint32 fakeAccountId = 1000 + (i % 100); // Simulate different accounts
                char const* table = existingTables[i % existingTables.size()];
                
                auto start = Clock::now();
                std::ostringstream sql;
                sql << "SELECT COUNT(*) FROM " << table << " WHERE account_id = " << fakeAccountId;
                QueryResult qr = CharacterDatabase.Query(sql.str().c_str());
                auto end = Clock::now();
                
                times.push_back(std::chrono::duration_cast<Microseconds>(end - start).count());
            }

            if (!times.empty())
            {
                std::sort(times.begin(), times.end());
                result.totalUs = std::accumulate(times.begin(), times.end(), 0ULL);
                result.avgUs = result.totalUs / iterations;
                result.minUs = times.front();
                result.maxUs = times.back();
                result.p95Us = GetPercentile(times, 95.0f);
                result.p99Us = GetPercentile(times, 99.0f);
            }
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }

    TimingResult TestMassTransactionWrite(uint32 batchSize)
    {
        TimingResult result;
        result.testName = "Mass Transaction Write (" + std::to_string(batchSize) + " rows)";
        result.iterations = 1;
        result.success = true;

        auto start = Clock::now();

        try
        {
            SQLTransaction trans = CharacterDatabase.BeginTransaction();

            // Use the existing log table with a very high fight_id range that should never overlap real data.
            static constexpr uint32 FightIdBase = 4290100000U;
            static constexpr uint32 MemberIdMod = 200U; // <= 255 (tinyint)
            for (uint32 i = 0; i < batchSize; ++i)
            {
                std::ostringstream sql;
                uint32 fightId = FightIdBase + (i / MemberIdMod);
                uint32 memberId = (i % MemberIdMod);
                uint32 fakeGuid = 4001000000U - (i % 1000000U);
                sql << "REPLACE INTO log_arena_memberstats (fight_id, member_id, name, guid, team, account, ip, damage, heal, kblows) VALUES ("
                    << fightId << ", " << memberId << ", 'StressTest', " << fakeGuid
                    << ", 0, 0, '127.0.0.1', 0, 0, 0)";
                trans->Append(sql.str().c_str());
            }

            // Immediately clean up our test data
            trans->Append("DELETE FROM log_arena_memberstats WHERE fight_id >= 4290100000");
            
            CharacterDatabase.CommitTransaction(trans);

            auto end = Clock::now();
            result.totalUs = std::chrono::duration_cast<Microseconds>(end - start).count();
            result.avgUs = result.totalUs / batchSize;
            result.minUs = result.avgUs;
            result.maxUs = result.avgUs;
            result.p95Us = result.avgUs;
            result.p99Us = result.avgUs;
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }

    TimingResult TestLoginSimulation(uint32 playerCount)
    {
        TimingResult result;
        result.testName = "Login Simulation (" + std::to_string(playerCount) + " players)";
        result.iterations = playerCount;
        result.success = true;

        std::vector<uint64> times;
        times.reserve(playerCount);

        try
        {
            // Simulate the queries that happen during player login for DC systems
            for (uint32 i = 0; i < playerCount; ++i)
            {
                uint32 fakeGuid = 10000 + (i * 13) % 1000; // Spread across GUIDs
                uint32 fakeAccount = 1000 + (i % 50);
                
                auto start = Clock::now();

                // Query 1: Prestige data
                {
                    if (CharacterTableExists("dc_character_prestige"))
                    {
                        std::ostringstream sql;
                        sql << "SELECT prestige_level FROM dc_character_prestige WHERE guid = " << fakeGuid;
                        CharacterDatabase.Query(sql.str().c_str());
                    }
                }

                // Query 2: Item upgrades for equipped items (simulated)
                {
                    if (CharacterTableExists("dc_item_upgrades"))
                    {
                        char const* ownerColumn = nullptr;
                        if (CharacterColumnExists("dc_item_upgrades", "player_guid"))
                            ownerColumn = "player_guid";
                        else if (CharacterColumnExists("dc_item_upgrades", "owner_guid"))
                            ownerColumn = "owner_guid";

                        if (ownerColumn)
                        {
                            std::ostringstream sql;
                            sql << "SELECT item_guid, tier_id, upgrade_level FROM dc_item_upgrades WHERE " << ownerColumn
                                << " = " << fakeGuid << " LIMIT 20";
                            CharacterDatabase.Query(sql.str().c_str());
                        }
                    }
                }

                // Query 3: Collection sync (mounts)
                {
                    char const* table = nullptr;
                    char const* idColumn = nullptr;
                    if (CharacterTableExists("dc_mount_collection"))
                    {
                        table = "dc_mount_collection";
                        idColumn = "spell_id";
                    }
                    else if (CharacterTableExists("dc_collection_mounts"))
                    {
                        table = "dc_collection_mounts";
                        idColumn = "entry_id";
                    }

                    if (table && idColumn)
                    {
                        std::ostringstream sql;
                        sql << "SELECT " << idColumn << " FROM " << table << " WHERE account_id = " << fakeAccount;
                        CharacterDatabase.Query(sql.str().c_str());
                    }
                }

                // Query 4: Mythic+ data
                {
                    if (CharacterTableExists("dc_player_keystones"))
                    {
                        std::ostringstream sql;
                        sql << "SELECT current_keystone_level FROM dc_player_keystones WHERE player_guid = " << fakeGuid;
                        CharacterDatabase.Query(sql.str().c_str());
                    }
                }

                auto end = Clock::now();
                times.push_back(std::chrono::duration_cast<Microseconds>(end - start).count());
            }

            if (!times.empty())
            {
                std::sort(times.begin(), times.end());
                result.totalUs = std::accumulate(times.begin(), times.end(), 0ULL);
                result.avgUs = result.totalUs / playerCount;
                result.minUs = times.front();
                result.maxUs = times.back();
                result.p95Us = GetPercentile(times, 95.0f);
                result.p99Us = GetPercentile(times, 99.0f);
            }
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }

    TimingResult TestGuildHouseLoadSimulation(uint32 iterations)
    {
        TimingResult result;
        result.testName = "Guild House Load Simulation (" + std::to_string(iterations) + " guilds)";
        result.iterations = iterations;
        result.success = true;

        std::vector<uint64> times;
        times.reserve(iterations);

        try
        {
            bool hasGuildHouse = CharacterTableExists("dc_guild_house");
            bool hasGuildPerms = CharacterTableExists("dc_guild_house_permissions");
            bool hasGuildLog = CharacterTableExists("dc_guild_house_log");

            if (!hasGuildHouse && !hasGuildPerms && !hasGuildLog)
            {
                result.testName += " [SKIPPED: guild house tables missing]";
                result.iterations = 0;
                result.totalUs = result.avgUs = result.minUs = result.maxUs = result.p95Us = result.p99Us = 0;
                return result;
            }

            // Simulate queries for loading guild house data and checking their spawns
            for (uint32 i = 0; i < iterations; ++i)
            {
                uint32 fakeGuildId = 1 + (i % 100);
                // Guild phase logic usually (guildId + 10) or similar, we just simulate the query
                uint32 fakePhase = fakeGuildId + 10; 
                
                auto start = Clock::now();

                // 1. Fetch House Data
                {
                    if (hasGuildHouse)
                    {
                        std::ostringstream sql;
                        sql << "SELECT phase, map, positionX, positionY, positionZ, orientation "
                            << "FROM dc_guild_house WHERE guild = " << fakeGuildId;
                        CharacterDatabase.Query(sql.str().c_str());
                    }
                }

                // 2. Fetch Permissions
                {
                    if (hasGuildPerms)
                    {
                        std::ostringstream sql;
                        sql << "SELECT permission FROM dc_guild_house_permissions WHERE guildId = " << fakeGuildId;
                        CharacterDatabase.Query(sql.str().c_str());
                    }
                }

                // 3. Count Spawns (Simulate finding all objects for this house, which uses World DB)
                // This simulates the heavy "SELECT guid FROM creature WHERE phaseMask = X" used in cleanup/checks
                {
                    std::ostringstream sql;
                    sql << "SELECT COUNT(*) FROM creature WHERE phaseMask = " << fakePhase;
                    WorldDatabase.Query(sql.str().c_str());
                }

                 // 4. Log Check (Simulate 'Undo' readiness)
                {
                    if (hasGuildLog)
                    {
                        std::ostringstream sql;
                        sql << "SELECT id FROM dc_guild_house_log WHERE guildId = " << fakeGuildId << " ORDER BY id DESC LIMIT 10";
                        CharacterDatabase.Query(sql.str().c_str());
                    }
                }

                auto end = Clock::now();
                times.push_back(std::chrono::duration_cast<Microseconds>(end - start).count());
            }

            if (!times.empty())
            {
                std::sort(times.begin(), times.end());
                result.totalUs = std::accumulate(times.begin(), times.end(), 0ULL);
                result.avgUs = result.totalUs / iterations;
                result.minUs = times.front();
                result.maxUs = times.back();
                result.p95Us = GetPercentile(times, 95.0f);
                result.p99Us = GetPercentile(times, 99.0f);
            }
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }

    TimingResult TestMassMapEntityLoad(uint32 iterations)
    {
        TimingResult result;
        result.testName = "Mass Map Entity Load (" + std::to_string(iterations) + " maps)";
        result.iterations = iterations;
        result.success = true;

        std::vector<uint64> times;
        times.reserve(iterations);

        // List of maps to simulate loading (use common ones)
        const uint32 maps[] = { 0, 1, 530, 571 }; 

        try
        {
            for (uint32 i = 0; i < iterations; ++i)
            {
                uint32 mapId = maps[i % 4];
                
                auto start = Clock::now();

                // Simulate loading all creatures and GOs for a map (or large section of it)
                // This is a heavy World DB query
                {
                    std::ostringstream sql;
                    sql << "SELECT count(*) FROM creature WHERE map = " << mapId;
                    WorldDatabase.Query(sql.str().c_str());
                }
                {
                    std::ostringstream sql;
                    sql << "SELECT count(*) FROM gameobject WHERE map = " << mapId;
                    WorldDatabase.Query(sql.str().c_str());
                }
                {
                   std::ostringstream sql;
                     // Avoid LIMIT in subqueries (unsupported on some MySQL/MariaDB variants).
                     // This is intentionally a heavier query: it counts all creature_addon rows for a map.
                     sql << "SELECT COUNT(*) FROM creature_addon ca "
                         "JOIN creature c ON ca.guid = c.guid "
                         "WHERE c.map = " << mapId;
                   WorldDatabase.Query(sql.str().c_str());
                }

                auto end = Clock::now();
                times.push_back(std::chrono::duration_cast<Microseconds>(end - start).count());
            }

            if (!times.empty())
            {
                std::sort(times.begin(), times.end());
                result.totalUs = std::accumulate(times.begin(), times.end(), 0ULL);
                result.avgUs = result.totalUs / iterations;
                result.minUs = times.front();
                result.maxUs = times.back();
                result.p95Us = GetPercentile(times, 95.0f);
                result.p99Us = GetPercentile(times, 99.0f);
            }
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }
    TimingResult TestGreatVaultSimulation(uint32 playerCount)
    {
        TimingResult result;
        result.testName = "Great Vault Generation (" + std::to_string(playerCount) + " players)";
        result.iterations = playerCount;
        result.success = true;

        std::vector<uint64> times;
        times.reserve(playerCount);

        try
        {
            if (!CharacterTableExists("dc_mplus_runs"))
            {
                result.success = false;
                result.error = "Missing table dc_mplus_runs";
                return result;
            }

            bool mplusHasSeason = CharacterColumnExists("dc_mplus_runs", "season_id");

            bool hasVaultRewardPool = CharacterTableExists("dc_vault_reward_pool");
            bool vaultHasSeason = hasVaultRewardPool && CharacterColumnExists("dc_vault_reward_pool", "season_id");
            bool vaultHasWeekStart = hasVaultRewardPool && CharacterColumnExists("dc_vault_reward_pool", "week_start");
            bool vaultHasItemLevel = hasVaultRewardPool && CharacterColumnExists("dc_vault_reward_pool", "item_level");
            bool vaultHasSlotIndex = hasVaultRewardPool && CharacterColumnExists("dc_vault_reward_pool", "slot_index");
            bool vaultHasSlotId = hasVaultRewardPool && CharacterColumnExists("dc_vault_reward_pool", "slot_id");

            bool hasVaultLootTable = WorldTableExists("dc_vault_loot_table");
            bool vaultLootHasExpectedColumns = hasVaultLootTable
                && WorldColumnExists("dc_vault_loot_table", "item_id")
                && WorldColumnExists("dc_vault_loot_table", "item_level_min")
                && WorldColumnExists("dc_vault_loot_table", "item_level_max")
                && WorldColumnExists("dc_vault_loot_table", "class_mask")
                && WorldColumnExists("dc_vault_loot_table", "armor_type")
                && WorldColumnExists("dc_vault_loot_table", "role_mask");

            // Simulate the heavy DB load of generating vault options for players
            // 1. Check M+ history
            // 2. Check Raid history
            // 3. Check PvP history
            // 4. Query loot table for 3-9 items (World DB heavy query)
            // 5. Save results
            
            for (uint32 i = 0; i < playerCount; ++i)
            {
                uint32 fakeGuid = 10000 + (i * 13) % 1000; 
                uint32 seasonId = 1;
                uint32 weekStart = 1700000000; // Fake timestamp
                
                auto start = Clock::now();

                // 1. M+ Runs Query
                {
                    std::ostringstream sql;
                    sql << "SELECT keystone_level FROM dc_mplus_runs "
                        << "WHERE character_guid = " << fakeGuid;
                    if (mplusHasSeason)
                        sql << " AND season_id = " << seasonId;
                    sql << " ORDER BY keystone_level DESC LIMIT 8";
                    CharacterDatabase.Query(sql.str().c_str());
                }

                // 2. Raid Progress Query (approx)
                {
                    std::ostringstream sql;
                    sql << "SELECT i.map, i.completedEncounters FROM character_instance ci "
                        << "JOIN instance i ON i.id = ci.instance "
                        << "WHERE ci.guid = " << fakeGuid << " AND i.resettime >= " << weekStart;
                    CharacterDatabase.Query(sql.str().c_str());
                }

                // 3. PvP Wins Query
                {
                    std::ostringstream sql;
                    sql << "SELECT COUNT(*) FROM pvpstats_players p "
                        << "WHERE p.character_guid = " << fakeGuid << " AND p.winner = 1";
                    CharacterDatabase.Query(sql.str().c_str());
                }

                // 4. Loot Generation (The Heavy One - World DB)
                // Simulate fetching candidates for a Paladin/Plate/Retribution (common case)
                {
                    if (vaultLootHasExpectedColumns)
                    {
                        const char* sql = "SELECT item_id FROM dc_vault_loot_table "
                            "WHERE item_level_min <= 264 AND item_level_max >= 264 "
                            "AND ((class_mask & 2) OR class_mask = 0 OR class_mask = 1023) "
                            "AND (armor_type = 'Plate' OR armor_type = 'Misc') "
                            "AND ((role_mask & 4) OR role_mask = 7)"; // DPS role
                        WorldDatabase.Query(sql);
                    }
                    else
                    {
                        // Fallback to a safe core table if DC loot table isn't present.
                        WorldDatabase.Query("SELECT entry FROM item_template LIMIT 200");
                    }
                }

                // 5. Cleanup & Save (Simulated write)
                {
                    if (hasVaultRewardPool && vaultHasWeekStart)
                    {
                        SQLTransaction trans = CharacterDatabase.BeginTransaction();

                        // Cleanup old
                        std::ostringstream del;
                        del << "DELETE FROM dc_vault_reward_pool WHERE character_guid = " << fakeGuid;
                        if (vaultHasSeason)
                            del << " AND season_id = " << seasonId;
                        del << " AND week_start = " << weekStart;
                        trans->Append(del.str().c_str());

                        // Insert new (simulate 3 items)
                        for (int j = 0; j < 3; ++j)
                        {
                            uint32 itemId = (50000 + (j + 1) + (i % 100));
                            std::ostringstream ins;
                            ins << "INSERT INTO dc_vault_reward_pool (character_guid";
                            if (vaultHasSeason)
                                ins << ", season_id";
                            ins << ", week_start, item_id";
                            if (vaultHasItemLevel)
                                ins << ", item_level";
                            if (vaultHasSlotIndex)
                                ins << ", slot_index";
                            else if (vaultHasSlotId)
                                ins << ", slot_id";
                            ins << ") VALUES (" << fakeGuid;
                            if (vaultHasSeason)
                                ins << ", " << seasonId;
                            ins << ", " << weekStart << ", " << itemId;
                            if (vaultHasItemLevel)
                                ins << ", 264";
                            if (vaultHasSlotIndex || vaultHasSlotId)
                                ins << ", " << j;
                            ins << ")";
                            trans->Append(ins.str().c_str());
                        }
                        CharacterDatabase.CommitTransaction(trans);
                    }
                }

                auto end = Clock::now();
                times.push_back(std::chrono::duration_cast<Microseconds>(end - start).count());
            }

            if (!times.empty())
            {
                std::sort(times.begin(), times.end());
                result.totalUs = std::accumulate(times.begin(), times.end(), 0ULL);
                result.avgUs = result.totalUs / playerCount;
                result.minUs = times.front();
                result.maxUs = times.back();
                result.p95Us = GetPercentile(times, 95.0f);
                result.p99Us = GetPercentile(times, 99.0f);
            }
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }

    TimingResult TestConcurrentQueryPattern(uint32 iterations)
    {
        TimingResult result;
        result.testName = "Concurrent Query Pattern (" + std::to_string(iterations) + " ops)";
        result.iterations = iterations;
        result.success = true;

        std::vector<uint64> times;
        times.reserve(iterations);

        try
        {
            // Simulate random mixed operations hitting both DBs
            for (uint32 i = 0; i < iterations; ++i)
            {
                auto start = Clock::now();
                
                if (i % 2 == 0)
                {
                    // Even: Character DB lookup
                    uint32 fakeGuid = 10000 + (i % 500);
                    std::ostringstream sql;
                    sql << "SELECT name FROM characters WHERE guid = " << fakeGuid;
                    CharacterDatabase.Query(sql.str().c_str());
                }
                else
                {
                    // Odd: World DB lookup
                    uint32 fakeEntry = 30000 + (i % 5000);
                    std::ostringstream sql;
                    sql << "SELECT name FROM creature_template WHERE entry = " << fakeEntry;
                    WorldDatabase.Query(sql.str().c_str());
                }
                
                auto end = Clock::now();
                times.push_back(std::chrono::duration_cast<Microseconds>(end - start).count());
            }

            if (!times.empty())
            {
                std::sort(times.begin(), times.end());
                result.totalUs = std::accumulate(times.begin(), times.end(), 0ULL);
                result.avgUs = result.totalUs / iterations;
                result.minUs = times.front();
                result.maxUs = times.back();
                result.p95Us = GetPercentile(times, 95.0f);
                result.p99Us = GetPercentile(times, 99.0f);
            }
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }

    TimingResult TestSpellInfoCache(uint32 iterations)
    {
        TimingResult result;
        result.testName = "SpellMgr Cache (" + std::to_string(iterations) + " lookups)";
        result.iterations = iterations;
        result.success = true;

        if (iterations == 0)
        {
            result.success = false;
            result.error = "iterations must be > 0";
            return result;
        }

        std::vector<uint64> times;
        times.reserve(iterations);

        // Use a mix of common spell IDs and a wider range to simulate cache hits and misses.
        uint32 const commonSpells[] = { 116, 133, 403, 585, 17, 20484, 339, 172, 2061, 48668, 48660 };
        uint32 const commonCount = sizeof(commonSpells) / sizeof(commonSpells[0]);

        try
        {
            for (uint32 i = 0; i < iterations; ++i)
            {
                uint32 spellId;
                if ((i % 5) == 0)
                    spellId = commonSpells[i % commonCount];
                else
                    spellId = 1 + (i % 60000);

                auto start = Clock::now();
                (void)sSpellMgr->GetSpellInfo(spellId);
                auto end = Clock::now();
                times.push_back(std::chrono::duration_cast<Microseconds>(end - start).count());
            }

            std::sort(times.begin(), times.end());
            result.totalUs = std::accumulate(times.begin(), times.end(), 0ULL);
            result.avgUs = result.totalUs / iterations;
            result.minUs = times.front();
            result.maxUs = times.back();
            result.p95Us = GetPercentile(times, 95.0f);
            result.p99Us = GetPercentile(times, 99.0f);
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }
} // namespace DCPerfTest

using namespace DCPerfTest;

class dc_stresstest_commandscript : public CommandScript
{
public:
        static void AppendAndMaybePrint(ChatHandler* handler, bool printDetails, std::vector<DCPerfTest::TimingResult>& out, DCPerfTest::TimingResult const& r)
        {
            out.push_back(r);
            if (printDetails)
                DCPerfTest::PrintResult(handler, r);
        }

        static bool RunSuite(ChatHandler* handler, std::string const& suite, char const* args, bool printDetails, std::vector<DCPerfTest::TimingResult>& out)
        {
            if (suite == "sql")
            {
                if (printDetails)
                    handler->SendSysMessage("|cff00ff00=== DC Performance Test: SQL Stress ===|r");
                AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestBulkSelect(1000));
                AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestRepeatedQueries(100));
                AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestTransactionBatch(50));
                return true;
            }

            if (suite == "cache")
            {
                if (printDetails)
                    handler->SendSysMessage("|cff00ff00=== DC Performance Test: Cache ===|r");
                AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestObjectMgrCache());
                AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestItemTemplateCache());
                return true;
            }

            if (suite == "systems")
            {
                if (printDetails)
                    handler->SendSysMessage("|cff00ff00=== DC Performance Test: DC Systems ===|r");
                AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestDCTableQueries());
                return true;
            }

            if (suite == "dbasync")
            {
                if (printDetails)
                    handler->SendSysMessage("|cff00ff00=== DC Performance Test: Async DB Burst ===|r");

                uint32 totalQueries = 400;
                uint32 concurrency = 8;
                if (args && *args)
                {
                    std::istringstream iss(args);
                    iss >> totalQueries;
                    if (!(iss >> concurrency))
                        concurrency = 8;
                }

                if (totalQueries > 5000)
                    totalQueries = 5000;
                if (concurrency > 32)
                    concurrency = 32;
                if (totalQueries == 0)
                    totalQueries = 1;
                if (concurrency == 0)
                    concurrency = 1;

                AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestAsyncQueryBurst(totalQueries, concurrency));
                return true;
            }

            if (suite == "path")
            {
                // Must be run in-game.
                Player* player = handler->GetPlayer();
                if (!player)
                {
                    DCPerfTest::TimingResult r;
                    r.testName = "Pathfinding";
                    r.success = false;
                    r.error = "Player context required (in-game only)";
                    AppendAndMaybePrint(handler, printDetails, out, r);
                    return false;
                }

                uint32 iterations = 200;
                if (args && *args)
                {
                    uint32 val = atoi(args);
                    if (val > 0)
                        iterations = val;
                }
                if (iterations > 2000)
                    iterations = 2000;

                AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestPathfinding(player, iterations));
                return true;
            }

            if (suite == "stress" || suite == "big")
            {
                if (printDetails)
                {
                    handler->SendSysMessage("|cff00ff00=== DC Performance Test: STRESS SIMULATION ===|r");
                    handler->SendSysMessage("Running heavy load simulations. Server may hiccup...");
                }

                uint32 baseCount = 50;
                if (args && *args)
                {
                    uint32 val = atoi(args);
                    if (val > 0)
                        baseCount = val;
                }
                uint32 limitSafe = (baseCount > 500) ? 500 : baseCount;

                AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestItemUpgradeStateLookups(baseCount * 10));
                AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestCollectionTableQueries(baseCount * 8));
                AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestLoginSimulation(limitSafe));
                AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestConcurrentQueryPattern(baseCount * 4));
                AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestMassTransactionWrite(baseCount * 2));
                AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestGreatVaultSimulation(limitSafe * 2));
                AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestGuildHouseLoadSimulation(limitSafe));
                AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestMassMapEntityLoad((limitSafe > 2) ? (limitSafe * 4 / 10) : 1));
                return true;
            }

            if (suite == "mysql")
            {
                if (printDetails)
                    DCPerfTest::PrintMySQLStatus(handler);
                return true;
            }

            if (suite == "cpu")
            {
                // CPU suite currently has no TimingResult-returning tests here; keep existing behavior.
                // (If we add CPU TimingResults later, they will naturally flow into this report.)
                return HandlePerfTestCPU(handler, args);
            }

            if (suite == "full")
            {
                RunSuite(handler, "sql", "", printDetails, out);
                RunSuite(handler, "cache", "", printDetails, out);
                RunSuite(handler, "systems", "", printDetails, out);
                RunSuite(handler, "stress", "", printDetails, out);
                if (printDetails)
                    DCPerfTest::PrintMySQLStatus(handler);
                return true;
            }

            handler->SendSysMessage(Acore::StringFormat("|cffff0000Unknown suite '{}'|r", suite));
            return false;
        }

        static bool HandlePerfTestReport(ChatHandler* handler, char const* args)
        {
            // Usage:
            // .stresstest report [suite=full] [topN=10] [details=0|1] [format=chat|json|csv] [suiteArgs...]
            // Example: .stresstest report dbasync 10 0 2000 16
            std::string suite = "full";
            uint32 topN = 10;
            uint32 details = 0;
            std::string format = "chat";
            std::string suiteArgs;

            if (args && *args)
            {
                std::istringstream iss(args);
                iss >> suite;
                if (!(iss >> topN))
                    topN = 10;
                if (!(iss >> details))
                    details = 0;

                std::string maybeFormat;
                if (iss >> maybeFormat)
                {
                    if (maybeFormat == "chat" || maybeFormat == "json" || maybeFormat == "csv")
                    {
                        format = maybeFormat;
                        std::getline(iss, suiteArgs);
                    }
                    else
                    {
                        // Not a format token; treat it as the first suite arg.
                        std::string rest;
                        std::getline(iss, rest);
                        suiteArgs = maybeFormat + rest;
                    }
                }
                else
                {
                    suiteArgs.clear();
                }

                while (!suiteArgs.empty() && suiteArgs.front() == ' ')
                    suiteArgs.erase(suiteArgs.begin());
            }

            bool printDetails = details != 0;

            handler->SendSysMessage("|cff00ff00=== DC Performance Test: REPORT ===|r");
            handler->SendSysMessage(Acore::StringFormat("Suite: {} | TopN: {} | Details: {} | Format: {}",
                suite,
                topN,
                printDetails ? "yes" : "no",
                format));

            auto start = DCPerfTest::Clock::now();

            std::vector<DCPerfTest::TimingResult> results;
            results.reserve(32);
            RunSuite(handler, suite, suiteArgs.empty() ? "" : suiteArgs.c_str(), printDetails, results);

            auto end = DCPerfTest::Clock::now();
            uint64 wallUs = std::chrono::duration_cast<DCPerfTest::Microseconds>(end - start).count();

            handler->SendSysMessage(Acore::StringFormat("Wall time: {}", DCPerfTest::FormatTime(wallUs)));
            DCPerfTest::PrintReportSummary(handler, results, topN);

            if (format == "json" || format == "csv")
            {
                std::string fullPath;
                std::string writeError;
                bool ok = DCPerfTest::WriteReportToLogsDir(format, suite, topN, printDetails, wallUs, results, fullPath, writeError);

                if (ok)
                    handler->SendSysMessage(Acore::StringFormat("|cff00ff00Report written to: {}|r", fullPath));
                else
                    handler->SendSysMessage(Acore::StringFormat("|cffff0000Failed to write report: {}|r", writeError));
            }
            return true;
        }

    dc_stresstest_commandscript() : CommandScript("dc_stresstest_commandscript") { }

    static bool HandlePerfTestCPU(ChatHandler* handler, const char* args)
    {
        handler->SendSysMessage("|cff00ff00=== DC Performance Test: CPU/Hot-path ===|r");

        uint32 iterations = 50000;
        if (args && *args)
        {
            uint32 val = atoi(args);
            if (val > 0)
                iterations = val;
        }

        if (iterations > 500000)
            iterations = 500000;

        auto r1 = TestSpellInfoCache(iterations);
        PrintResult(handler, r1);

        handler->SendSysMessage("|cff00ff00=== Test Complete ===|r");
        return true;
    }

    static bool HandlePerfTestLoop(ChatHandler* handler, const char* args)
    {
        // Usage:
        // .stresstest loop <suite> [loops=10] [sleepMs=1000] [suiteArgs...]
        // Optional: prefix suiteArgs with "quiet" to only print the final summary.
        // suite: sql|cache|systems|stress|dbasync|path|cpu|mysql|full
        handler->SendSysMessage("|cff00ff00=== DC Performance Test: LOOP ===|r");

        std::string suite;
        uint32 loops = 10;
        uint32 sleepMs = 1000;
        std::string suiteArgs;
        bool quiet = false;

        if (args && *args)
        {
            std::istringstream iss(args);
            iss >> suite;
            if (!(iss >> loops))
                loops = 10;
            if (!(iss >> sleepMs))
                sleepMs = 1000;

            std::getline(iss, suiteArgs);
            while (!suiteArgs.empty() && suiteArgs.front() == ' ')
                suiteArgs.erase(suiteArgs.begin());
        }

        // Allow "quiet" as a first suite-arg: e.g. ".stresstest loop dbasync 40 250 quiet 2000 16"
        if (!suiteArgs.empty())
        {
            std::istringstream argss(suiteArgs);
            std::string first;
            argss >> first;
            if (first == "quiet" || first == "q")
            {
                quiet = true;
                std::string rest;
                std::getline(argss, rest);
                while (!rest.empty() && rest.front() == ' ')
                    rest.erase(rest.begin());
                suiteArgs = rest;
            }
        }

        if (suite.empty())
        {
            handler->SendSysMessage("Usage: .stresstest loop <suite> [loops] [sleepMs] [suiteArgs...]");
            return true;
        }

        bool infinite = (loops == 0);
        if (!infinite && loops > 10000)
            loops = 10000;

        std::vector<uint64> timesUs;
        timesUs.reserve(infinite ? 1024 : loops);

        uint32 i = 0;
        while (infinite || i < loops)
        {
            auto start = DCPerfTest::Clock::now();

            bool ok = true;
            char const* passArgs = suiteArgs.empty() ? "" : suiteArgs.c_str();

            if (suite == "sql")
                ok = HandlePerfTestSQL(handler, passArgs);
            else if (suite == "cache")
                ok = HandlePerfTestCache(handler, passArgs);
            else if (suite == "systems")
                ok = HandlePerfTestSystems(handler, passArgs);
            else if (suite == "stress" || suite == "big")
                ok = HandlePerfTestStress(handler, passArgs);
            else if (suite == "dbasync")
                ok = HandlePerfTestDBAsync(handler, passArgs);
            else if (suite == "path")
                ok = HandlePerfTestPath(handler, passArgs);
            else if (suite == "cpu")
                ok = HandlePerfTestCPU(handler, passArgs);
            else if (suite == "mysql")
                ok = PrintMySQLStatus(handler, passArgs);
            else if (suite == "full")
                ok = HandlePerfTestFull(handler, passArgs);
            else
            {
                handler->SendSysMessage(Acore::StringFormat("|cffff0000Unknown suite '{}'|r", suite));
                return true;
            }

            auto end = DCPerfTest::Clock::now();
            uint64 us = std::chrono::duration_cast<DCPerfTest::Microseconds>(end - start).count();
            timesUs.push_back(us);

            if (!quiet)
            {
                if (infinite)
                    handler->SendSysMessage(Acore::StringFormat("|cff32c4ffLoop {}|r: {}{}", i + 1, DCPerfTest::FormatTime(us), ok ? "" : " (errors)"));
                else
                    handler->SendSysMessage(Acore::StringFormat("|cff32c4ffLoop {}/{}|r: {}{}", i + 1, loops, DCPerfTest::FormatTime(us), ok ? "" : " (errors)"));
            }

            ++i;
            if (!infinite && i >= loops)
                break;

            if (sleepMs > 0)
                std::this_thread::sleep_for(std::chrono::milliseconds(sleepMs));
        }

        if (!timesUs.empty())
        {
            std::sort(timesUs.begin(), timesUs.end());
            uint64 totalUs = std::accumulate(timesUs.begin(), timesUs.end(), 0ULL);
            uint64 avgUs = totalUs / timesUs.size();
            uint64 minUs = timesUs.front();
            uint64 maxUs = timesUs.back();
            uint64 p95Us = DCPerfTest::GetPercentile(timesUs, 95.0f);
            uint64 p99Us = DCPerfTest::GetPercentile(timesUs, 99.0f);

            handler->SendSysMessage("|cff00ff00=== Loop Summary ===|r");
            handler->SendSysMessage(Acore::StringFormat("Total: {} | Avg: {} | Min: {} | Max: {}",
                DCPerfTest::FormatTime(totalUs),
                DCPerfTest::FormatTime(avgUs),
                DCPerfTest::FormatTime(minUs),
                DCPerfTest::FormatTime(maxUs)));
            handler->SendSysMessage(Acore::StringFormat("P95: {} | P99: {} ({} loops)",
                DCPerfTest::FormatTime(p95Us),
                DCPerfTest::FormatTime(p99Us),
                static_cast<uint32>(timesUs.size())));
        }

        return true;
    }

    static bool HandlePerfTestDBAsync(ChatHandler* handler, const char* args)
    {
        handler->SendSysMessage("|cff00ff00=== DC Performance Test: Async DB Burst ===|r");

        uint32 totalQueries = 400;
        uint32 concurrency = 8;
        if (args && *args)
        {
            // Accept: "<queries> <concurrency>" or just "<queries>"
            std::istringstream iss(args);
            iss >> totalQueries;
            if (!(iss >> concurrency))
                concurrency = 8;
        }

        // Safety caps
        if (totalQueries > 5000)
            totalQueries = 5000;
        if (concurrency > 32)
            concurrency = 32;
        if (totalQueries == 0)
            totalQueries = 1;
        if (concurrency == 0)
            concurrency = 1;

        auto r = TestAsyncQueryBurst(totalQueries, concurrency);
        PrintResult(handler, r);
        handler->SendSysMessage("|cff00ff00=== Test Complete ===|r");
        return true;
    }

    static bool HandlePerfTestLoopReport(ChatHandler* handler, const char* args)
    {
        // Usage:
        // .stresstest loopreport <suite> [loops=0] [sleepMs=1000] [topN=10] [details=0|1] [format=json|csv] [suiteArgs...]
        // loops=0 means infinite.
        handler->SendSysMessage("|cff00ff00=== DC Performance Test: LOOPREPORT ===|r");

        std::string suite;
        uint32 loops = 0;
        uint32 sleepMs = 1000;
        uint32 topN = 10;
        uint32 details = 0;
        std::string format = "json";
        std::string suiteArgs;

        if (args && *args)
        {
            std::istringstream iss(args);
            iss >> suite;
            if (!(iss >> loops))
                loops = 0;
            if (!(iss >> sleepMs))
                sleepMs = 1000;
            if (!(iss >> topN))
                topN = 10;
            if (!(iss >> details))
                details = 0;

            std::string maybeFormat;
            if (iss >> maybeFormat)
            {
                if (maybeFormat == "json" || maybeFormat == "csv")
                {
                    format = maybeFormat;
                    std::getline(iss, suiteArgs);
                }
                else
                {
                    std::string rest;
                    std::getline(iss, rest);
                    suiteArgs = maybeFormat + rest;
                }
            }
            else
            {
                suiteArgs.clear();
            }

            while (!suiteArgs.empty() && suiteArgs.front() == ' ')
                suiteArgs.erase(suiteArgs.begin());
        }

        if (suite.empty())
        {
            handler->SendSysMessage("Usage: .stresstest loopreport <suite> [loops] [sleepMs] [topN] [details] [format=json|csv] [suiteArgs...] (loops=0 is infinite)");
            return true;
        }

        bool printDetails = details != 0;
        bool infinite = (loops == 0);
        if (!infinite && loops > 10000)
            loops = 10000;

        handler->SendSysMessage(Acore::StringFormat("Suite: {} | Loops: {} | SleepMs: {} | TopN: {} | Details: {} | Format: {}",
            suite,
            infinite ? "infinite" : std::to_string(loops),
            sleepMs,
            topN,
            printDetails ? "yes" : "no",
            format));

        // Create one output file per command invocation.
        std::string logsDir = sLog->GetLogsDir();
        if (!logsDir.empty())
        {
            try
            {
                std::filesystem::create_directories(std::filesystem::path(logsDir));
            }
            catch (...) { }
        }

        std::string outPath = DCPerfTest::MakeLoopReportFilePath(suite, format);
        std::ofstream out(outPath, std::ios::out | std::ios::trunc);
        if (!out.is_open())
        {
            handler->SendSysMessage(Acore::StringFormat("|cffff0000Failed to open loop report file for writing: {}|r", outPath));
            return true;
        }

        handler->SendSysMessage(Acore::StringFormat("|cff00ff00Writing loop report to: {}|r", outPath));

        if (format == "csv")
            DCPerfTest::WriteLoopReportCsvHeader(out, suite, loops, infinite, sleepMs, topN, printDetails, format, suiteArgs);
        else
            DCPerfTest::WriteLoopReportJsonHeader(out, suite, loops, infinite, sleepMs, topN, printDetails, format, suiteArgs);

        uint32 iter = 0;
        bool firstJsonRun = true;
        while (infinite || iter < loops)
        {
            auto start = DCPerfTest::Clock::now();

            std::vector<DCPerfTest::TimingResult> results;
            results.reserve(32);
            RunSuite(handler, suite, suiteArgs.empty() ? "" : suiteArgs.c_str(), printDetails, results);

            auto end = DCPerfTest::Clock::now();
            uint64 wallUs = std::chrono::duration_cast<DCPerfTest::Microseconds>(end - start).count();

            ++iter;

            if (format == "csv")
            {
                DCPerfTest::WriteLoopReportCsvRun(out, iter, wallUs, results);
            }
            else
            {
                DCPerfTest::WriteLoopReportJsonRun(out, iter, wallUs, results, firstJsonRun);
                firstJsonRun = false;
            }
            out.flush();

            if (infinite)
                handler->SendSysMessage(Acore::StringFormat("|cff32c4ffLoop {}|r: wall {} | appended", iter, DCPerfTest::FormatTime(wallUs)));
            else
                handler->SendSysMessage(Acore::StringFormat("|cff32c4ffLoop {}/{}|r: wall {} | appended", iter, loops, DCPerfTest::FormatTime(wallUs)));

            if (!infinite && iter >= loops)
                break;

            if (sleepMs > 0)
                std::this_thread::sleep_for(std::chrono::milliseconds(sleepMs));
        }

        if (format != "csv")
            DCPerfTest::WriteLoopReportJsonFooter(out);

        handler->SendSysMessage("|cff00ff00=== LOOPREPORT Complete ===|r");
        return true;
    }

    static bool HandlePerfTestPath(ChatHandler* handler, const char* args)
    {
        handler->SendSysMessage("|cff00ff00=== DC Performance Test: Pathfinding ===|r");

        Player* player = handler->GetPlayer();
        if (!player)
        {
            handler->SendSysMessage("|cffff0000This test must be run in-game (no CLI).|r");
            return true;
        }

        uint32 iterations = 200;
        if (args && *args)
        {
            uint32 val = atoi(args);
            if (val > 0)
                iterations = val;
        }

        // Safety cap (pathfinding can be very expensive with mmaps)
        if (iterations > 2000)
            iterations = 2000;

        auto r = TestPathfinding(player, iterations);
        PrintResult(handler, r);
        handler->SendSysMessage("|cff00ff00=== Test Complete ===|r");
        return true;
    }

    Acore::ChatCommands::ChatCommandTable GetCommands() const override
    {
        using namespace Acore::ChatCommands;

        static ChatCommandTable stressTestTable =
        {
            // Allow running from worldserver console/RCON to avoid disconnecting admins during long tests.
            ChatCommandBuilder("sql",     HandlePerfTestSQL,     SEC_GAMEMASTER, Console::Yes),
            ChatCommandBuilder("cache",   HandlePerfTestCache,   SEC_GAMEMASTER, Console::Yes),
            ChatCommandBuilder("systems", HandlePerfTestSystems, SEC_GAMEMASTER, Console::Yes),
            ChatCommandBuilder("stress",  HandlePerfTestStress,  SEC_GAMEMASTER, Console::Yes),
            ChatCommandBuilder("dbasync", HandlePerfTestDBAsync, SEC_GAMEMASTER, Console::Yes),
            // path requires an in-game Player context.
            ChatCommandBuilder("path",    HandlePerfTestPath,    SEC_GAMEMASTER, Console::No),
            ChatCommandBuilder("cpu",     HandlePerfTestCPU,     SEC_GAMEMASTER, Console::Yes),
            ChatCommandBuilder("loop",    HandlePerfTestLoop,    SEC_GAMEMASTER, Console::Yes),
            ChatCommandBuilder("loopreport", HandlePerfTestLoopReport, SEC_GAMEMASTER, Console::Yes),
            ChatCommandBuilder("mysql",   PrintMySQLStatus,      SEC_GAMEMASTER, Console::Yes),
            ChatCommandBuilder("full",    HandlePerfTestFull,    SEC_GAMEMASTER, Console::Yes),
            ChatCommandBuilder("report",  HandlePerfTestReport,  SEC_GAMEMASTER, Console::Yes),
        };

        static ChatCommandTable commandTable =
        {
            ChatCommandBuilder("stresstest", stressTestTable)
        };

        return commandTable;
    }

    static bool HandlePerfTestSQL(ChatHandler* handler, const char* /*args*/)
    {
        handler->SendSysMessage("|cff00ff00=== DC Performance Test: SQL Stress ===|r");

        auto r1 = TestBulkSelect(1000);
        PrintResult(handler, r1);

        auto r2 = TestRepeatedQueries(100);
        PrintResult(handler, r2);

        auto r3 = TestTransactionBatch(50);
        PrintResult(handler, r3);

        handler->SendSysMessage("|cff00ff00=== Test Complete ===|r");
        return true;
    }

    static bool HandlePerfTestCache(ChatHandler* handler, const char* /*args*/)
    {
        handler->SendSysMessage("|cff00ff00=== DC Performance Test: Cache ===|r");

        auto r1 = TestObjectMgrCache();
        PrintResult(handler, r1);

        auto r2 = TestItemTemplateCache();
        PrintResult(handler, r2);

        handler->SendSysMessage("|cff00ff00=== Test Complete ===|r");
        return true;
    }

    static bool HandlePerfTestSystems(ChatHandler* handler, const char* /*args*/)
    {
        handler->SendSysMessage("|cff00ff00=== DC Performance Test: DC Systems ===|r");

        auto r1 = TestDCTableQueries();
        PrintResult(handler, r1);

        handler->SendSysMessage("|cff00ff00=== Test Complete ===|r");
        return true;
    }

    static bool HandlePerfTestStress(ChatHandler* handler, const char* args)
    {
        handler->SendSysMessage("|cff00ff00=== DC Performance Test: STRESS SIMULATION ===|r");
        handler->SendSysMessage("Running heavy load simulations. Server may hiccup...");

        uint32 baseCount = 50;
        if (args && *args)
        {
            uint32 val = atoi(args);
            if (val > 0) baseCount = val;
        }

        uint32 limitSafe = (baseCount > 500) ? 500 : baseCount; // Safety cap

        auto r1 = TestItemUpgradeStateLookups(baseCount * 10);
        PrintResult(handler, r1);

        auto r2 = TestCollectionTableQueries(baseCount * 8);
        PrintResult(handler, r2);

        auto r3 = TestLoginSimulation(limitSafe);
        PrintResult(handler, r3);

        auto r4 = TestConcurrentQueryPattern(baseCount * 4);
        PrintResult(handler, r4);

        auto r5 = TestMassTransactionWrite(baseCount * 2);
        PrintResult(handler, r5);

        auto r6 = TestGreatVaultSimulation(limitSafe * 2);
        PrintResult(handler, r6);

        auto r7 = TestGuildHouseLoadSimulation(limitSafe);
        PrintResult(handler, r7);

        auto r8 = TestMassMapEntityLoad((limitSafe > 2) ? (limitSafe * 4 / 10) : 1);
        PrintResult(handler, r8);

        handler->SendSysMessage("|cff00ff00=== Stress Test Complete ===|r");
        return true;
    }

    static bool PrintMySQLStatus(ChatHandler* handler, const char* /*args*/)
    {
        DCPerfTest::PrintMySQLStatus(handler);
        return true;
    }

    static bool HandlePerfTestFull(ChatHandler* handler, const char* /*args*/)
    {
        handler->SendSysMessage("|cff00ff00=== DC Full Performance Test Suite ===|r");
        auto overallStart = Clock::now();

        HandlePerfTestSQL(handler, "");
        HandlePerfTestCache(handler, "");
        HandlePerfTestSystems(handler, "");
        HandlePerfTestStress(handler, ""); 
        PrintMySQLStatus(handler, "");

        auto overallEnd = Clock::now();
        auto totalMs = std::chrono::duration_cast<Milliseconds>(overallEnd - overallStart).count();
        handler->SendSysMessage(Acore::StringFormat("|cff00ff00Total time: {} ms|r", totalMs));
        return true;
    }
};

void AddSC_dc_stresstest()
{
    new dc_stresstest_commandscript();
}
