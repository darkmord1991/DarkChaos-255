/*
 * DC Performance Testing System (.stresstest)
 * 
 * Provides stress testing tools for SQL, Cache, and Subsystems.
 * COMMAND: .stresstest <subcommand>
 * PERMISSION: GM only (SEC_GAMEMASTER)
 */

#include "ScriptMgr.h"
#include "Chat.h"
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

            for (uint32 i = 0; i < batchSize; ++i)
            {
                // Use a prepared-style insert to a log table that can be cleaned
                std::ostringstream sql;
                sql << "INSERT INTO log_arena_memberstats (guid, visibleRank) VALUES ("
                    << (2147483647 - i) << ", 0) ON DUPLICATE KEY UPDATE visibleRank = visibleRank";
                trans->Append(sql.str().c_str());
            }

            // Cleanup our test data
            trans->Append("DELETE FROM log_arena_memberstats WHERE guid >= 2147483547");
            
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
        
        // List of common DC tables to test
        const char* dcTables[] = {
            "SELECT COUNT(*) FROM dc_character_prestige",
            "SELECT COUNT(*) FROM dc_item_upgrades", 
            "SELECT COUNT(*) FROM dc_character_mythic_keystones",
            "SELECT COUNT(*) FROM dc_collection_mounts",
            "SELECT COUNT(*) FROM dc_collection_pets",
            "SELECT COUNT(*) FROM dc_guildhouses"
        };

        try
        {
            for (const char* sql : dcTables)
            {
                auto start = Clock::now();
                QueryResult qr = CharacterDatabase.Query(sql);
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
                result.testName += " [no DC tables found]";
                result.totalUs = 0;
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
            handler->PSendSysMessage("Threads Connected: %s", f[1].Get<std::string>().c_str());
        }

        qr = CharacterDatabase.Query("SHOW STATUS LIKE 'Questions'");
        if (qr)
        {
            Field* f = qr->Fetch();
            handler->PSendSysMessage("Total Queries: %s", f[1].Get<std::string>().c_str());
        }

        qr = CharacterDatabase.Query("SHOW STATUS LIKE 'Slow_queries'");
        if (qr)
        {
            Field* f = qr->Fetch();
            handler->PSendSysMessage("Slow Queries: %s", f[1].Get<std::string>().c_str());
        }

        qr = CharacterDatabase.Query("SHOW STATUS LIKE 'Uptime'");
        if (qr)
        {
            Field* f = qr->Fetch();
            uint32 uptime = f[1].Get<uint32>();
            handler->PSendSysMessage("Uptime: %us", uptime);
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
                 handler->PSendSysMessage("InnoDB Buffer Pool Hit Rate: %.2f%%", hitRate);
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
                 handler->PSendSysMessage("Query Cache Hits: %u", (uint32)hits);
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
            Slot slot{ CharacterDatabase.AsyncQuery(sql).WithCallback([](QueryResult) {}), Clock::now() };
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
                    slot.cb = CharacterDatabase.AsyncQuery(sql).WithCallback([](QueryResult) {});
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
            handler->PSendSysMessage("|cffff0000%s: FAILED - %s|r", result.testName.c_str(), result.error.c_str());
            return;
        }

        handler->PSendSysMessage("|cffffffff%s|r", result.testName.c_str());
        handler->PSendSysMessage("  Total: %s | Avg: %s | Min: %s | Max: %s",
            FormatTime(result.totalUs).c_str(),
            FormatTime(result.avgUs).c_str(),
            FormatTime(result.minUs).c_str(),
            FormatTime(result.maxUs).c_str());
        
        if (result.iterations > 1)
        {
            handler->PSendSysMessage("  P95: %s | P99: %s (%u iterations)",
                FormatTime(result.p95Us).c_str(),
                FormatTime(result.p99Us).c_str(),
                result.iterations);
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

        try
        {
            // Query dc_item_upgrades for random item GUIDs
            for (uint32 i = 0; i < iterations; ++i)
            {
                uint32 fakeItemGuid = 100000 + (i * 7) % 50000; // Spread across range
                
                auto start = Clock::now();
                std::ostringstream sql;
                sql << "SELECT item_guid, tier_id, upgrade_level, season_id FROM dc_item_upgrades WHERE item_guid = " << fakeItemGuid;
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

        // Cycle through different collection tables
        const char* tables[] = {
            "dc_collection_mounts",
            "dc_collection_pets",
            "dc_collection_heirlooms",
            "dc_collection_transmog"
        };

        try
        {
            for (uint32 i = 0; i < iterations; ++i)
            {
                uint32 fakeAccountId = 1000 + (i % 100); // Simulate different accounts
                const char* table = tables[i % 4];
                
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
            // Use a high GUID range that won't conflict with real data
            // Insert into dc_perftest_temp (if table doesn't exist, use fallback)
            SQLTransaction trans = CharacterDatabase.BeginTransaction();

            // First, try to create a temp table or use log table as fallback
            for (uint32 i = 0; i < batchSize; ++i)
            {
                std::ostringstream sql;
                // Use log_arena_memberstats with very high GUIDs as safe write target
                sql << "INSERT INTO log_arena_memberstats (guid, visibleRank) VALUES ("
                    << (2100000000 - i) << ", " << (i % 10) << ") "
                    << "ON DUPLICATE KEY UPDATE visibleRank = " << (i % 10);
                trans->Append(sql.str().c_str());
            }

            // Immediately clean up our test data
            trans->Append("DELETE FROM log_arena_memberstats WHERE guid >= 2099000000");
            
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
                    std::ostringstream sql;
                    sql << "SELECT prestige_level FROM dc_character_prestige WHERE guid = " << fakeGuid;
                    CharacterDatabase.Query(sql.str().c_str());
                }

                // Query 2: Item upgrades for equipped items (simulated)
                {
                    std::ostringstream sql;
                    sql << "SELECT item_guid, tier_id, upgrade_level FROM dc_item_upgrades WHERE owner_guid = " << fakeGuid << " LIMIT 20";
                    CharacterDatabase.Query(sql.str().c_str());
                }

                // Query 3: Collection sync (mounts)
                {
                    std::ostringstream sql;
                    sql << "SELECT entry_id FROM dc_collection_mounts WHERE account_id = " << fakeAccount;
                    CharacterDatabase.Query(sql.str().c_str());
                }

                // Query 4: Mythic+ data
                {
                    std::ostringstream sql;
                    sql << "SELECT dungeon_id, keystone_level FROM dc_character_mythic_keystones WHERE player_guid = " << fakeGuid;
                    CharacterDatabase.Query(sql.str().c_str());
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
            // Simulate queries for loading guild house data and checking their spawns
            for (uint32 i = 0; i < iterations; ++i)
            {
                uint32 fakeGuildId = 1 + (i % 100);
                // Guild phase logic usually (guildId + 10) or similar, we just simulate the query
                uint32 fakePhase = fakeGuildId + 10; 
                
                auto start = Clock::now();

                // 1. Fetch House Data
                {
                    std::ostringstream sql;
                    sql << "SELECT phase, map, positionX, positionY, positionZ, orientation "
                        << "FROM dc_guild_house WHERE guild = " << fakeGuildId;
                    CharacterDatabase.Query(sql.str().c_str());
                }

                // 2. Fetch Permissions
                {
                    std::ostringstream sql;
                    sql << "SELECT permission FROM dc_guild_house_permissions WHERE guildId = " << fakeGuildId;
                    CharacterDatabase.Query(sql.str().c_str());
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
                    std::ostringstream sql;
                    sql << "SELECT id FROM dc_guild_house_log WHERE guildId = " << fakeGuildId << " ORDER BY id DESC LIMIT 10";
                    CharacterDatabase.Query(sql.str().c_str());
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
                   sql << "SELECT count(*) FROM creature_addon WHERE guid IN (SELECT guid FROM creature WHERE map = " << mapId << " LIMIT 500)";
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
                        << "WHERE character_guid = " << fakeGuid << " AND season_id = " << seasonId 
                        << " ORDER BY keystone_level DESC LIMIT 8";
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
                    const char* sql = "SELECT item_id FROM dc_vault_loot_table "
                        "WHERE item_level_min <= 264 AND item_level_max >= 264 "
                        "AND ((class_mask & 2) OR class_mask = 1023) "
                        "AND (armor_type = 'Plate' OR armor_type = 'Misc') "
                        "AND ((role_mask & 4) OR role_mask = 7)"; // DPS role
                    WorldDatabase.Query(sql);
                }

                // 5. Cleanup & Save (Simulated write)
                {
                    SQLTransaction trans = CharacterDatabase.BeginTransaction();
                    // Cleanup old
                    std::ostringstream del;
                    del << "DELETE FROM dc_vault_reward_pool WHERE character_guid = " << fakeGuid << " AND week_start = " << weekStart;
                    trans->Append(del.str().c_str());
                    
                    // Insert new (simulate 3 items)
                    for (int j=1; j<=3; ++j) {
                        std::ostringstream ins;
                        ins << "INSERT INTO dc_vault_reward_pool (character_guid, week_start, slot_id, item_id) VALUES ("
                            << fakeGuid << ", " << weekStart << ", " << j << ", " << (50000 + j + (i % 100)) << ")";
                        trans->Append(ins.str().c_str());
                    }
                    CharacterDatabase.CommitTransaction(trans);
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
        // suite: sql|cache|systems|stress|dbasync|path|cpu|mysql|full
        handler->SendSysMessage("|cff00ff00=== DC Performance Test: LOOP ===|r");

        std::string suite;
        uint32 loops = 10;
        uint32 sleepMs = 1000;
        std::string suiteArgs;

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

        if (suite.empty())
        {
            handler->SendSysMessage("Usage: .stresstest loop <suite> [loops] [sleepMs] [suiteArgs...]");
            return true;
        }

        if (loops > 200)
            loops = 200;

        std::vector<uint64> timesUs;
        timesUs.reserve(loops);

        for (uint32 i = 0; i < loops; ++i)
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
                handler->PSendSysMessage("|cffff0000Unknown suite '%s'|r", suite.c_str());
                return true;
            }

            auto end = DCPerfTest::Clock::now();
            uint64 us = std::chrono::duration_cast<DCPerfTest::Microseconds>(end - start).count();
            timesUs.push_back(us);

            handler->PSendSysMessage("|cff32c4ffLoop %u/%u|r: %s%s", i + 1, loops, DCPerfTest::FormatTime(us).c_str(), ok ? "" : " (errors)");

            if (sleepMs > 0 && (i + 1) < loops)
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
            handler->PSendSysMessage("Total: %s | Avg: %s | Min: %s | Max: %s",
                DCPerfTest::FormatTime(totalUs).c_str(),
                DCPerfTest::FormatTime(avgUs).c_str(),
                DCPerfTest::FormatTime(minUs).c_str(),
                DCPerfTest::FormatTime(maxUs).c_str());
            handler->PSendSysMessage("P95: %s | P99: %s (%u loops)",
                DCPerfTest::FormatTime(p95Us).c_str(),
                DCPerfTest::FormatTime(p99Us).c_str(),
                loops);
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

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable stressTestTable =
        {
            { "sql",      HandlePerfTestSQL,      SEC_GAMEMASTER, Console::No },
            { "cache",    HandlePerfTestCache,    SEC_GAMEMASTER, Console::No },
            { "systems",  HandlePerfTestSystems,  SEC_GAMEMASTER, Console::No },
            { "stress",   HandlePerfTestStress,   SEC_GAMEMASTER, Console::No },
            { "dbasync",  HandlePerfTestDBAsync,  SEC_GAMEMASTER, Console::No },
            { "path",     HandlePerfTestPath,     SEC_GAMEMASTER, Console::No },
            { "cpu",      HandlePerfTestCPU,      SEC_GAMEMASTER, Console::No },
            { "loop",     HandlePerfTestLoop,     SEC_GAMEMASTER, Console::No },
            { "mysql",    PrintMySQLStatus,       SEC_GAMEMASTER, Console::No },
            { "full",     HandlePerfTestFull,     SEC_GAMEMASTER, Console::No },
        };

        static ChatCommandTable commandTable =
        {
            { "stresstest",  stressTestTable }
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
        handler->PSendSysMessage("|cff00ff00Total time: %llu ms|r", totalMs);
        return true;
    }
};

void AddSC_dc_stresstest()
{
    new dc_stresstest_commandscript();
}
