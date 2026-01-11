/*
 * DC Performance Testing Command
 * ===============================
 *
 * Provides `.dc perftest` commands for testing DC script performance
 * with heavy SQL stress testing to identify bottlenecks and validate
 * MySQL capacity.
 *
 * Commands:
 *   .dc perftest sql      - SQL stress tests (bulk queries, transactions)
 *   .dc perftest cache    - Cache performance tests
 *   .dc perftest systems  - Per-system performance tests
 *   .dc perftest full     - Run all tests with comprehensive report
 *   .dc perftest mysql    - MySQL connection stats and analysis
 *
 * Copyright (C) 2025-2026 Dark Chaos Development Team
 */

#include "ScriptMgr.h"
#include "Chat.h"
#include "Player.h"
#include "DatabaseEnv.h"
#include "World.h"
#include "ObjectMgr.h"
#include "Log.h"
#include <chrono>
#include <vector>
#include <algorithm>
#include <numeric>
#include <sstream>

using namespace Acore::ChatCommands;

namespace DCPerfTest
{
    // Timing utilities
    using Clock = std::chrono::high_resolution_clock;
    using Microseconds = std::chrono::microseconds;
    using Milliseconds = std::chrono::milliseconds;

    struct TimingResult
    {
        std::string testName;
        uint64 totalUs;
        uint64 avgUs;
        uint64 minUs;
        uint64 maxUs;
        uint64 p95Us;
        uint64 p99Us;
        uint32 iterations;
        bool success;
        std::string error;
    };

    // Calculate percentile from sorted vector
    uint64 GetPercentile(const std::vector<uint64>& sortedTimes, float percentile)
    {
        if (sortedTimes.empty())
            return 0;
        size_t index = static_cast<size_t>(percentile * sortedTimes.size() / 100.0f);
        if (index >= sortedTimes.size())
            index = sortedTimes.size() - 1;
        return sortedTimes[index];
    }

    // Format microseconds as human-readable
    std::string FormatTime(uint64 us)
    {
        if (us >= 1000000)
            return std::to_string(us / 1000000) + "." + std::to_string((us / 1000) % 1000) + "s";
        if (us >= 1000)
            return std::to_string(us / 1000) + "." + std::to_string(us % 1000) + "ms";
        return std::to_string(us) + "µs";
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
            handler->PSendSysMessage("Threads Connected: %s", f[1].GetCString());
        }

        qr = CharacterDatabase.Query("SHOW STATUS LIKE 'Questions'");
        if (qr)
        {
            Field* f = qr->Fetch();
            handler->PSendSysMessage("Total Queries: %s", f[1].GetCString());
        }

        qr = CharacterDatabase.Query("SHOW STATUS LIKE 'Slow_queries'");
        if (qr)
        {
            Field* f = qr->Fetch();
            handler->PSendSysMessage("Slow Queries: %s", f[1].GetCString());
        }

        qr = CharacterDatabase.Query("SHOW STATUS LIKE 'Uptime'");
        if (qr)
        {
            Field* f = qr->Fetch();
            uint32 uptime = f[1].GetUInt32();
            handler->PSendSysMessage("MySQL Uptime: %ud %uh %um", uptime / 86400, (uptime % 86400) / 3600, (uptime % 3600) / 60);
        }

        // InnoDB buffer pool stats
        qr = CharacterDatabase.Query("SHOW STATUS LIKE 'Innodb_buffer_pool_read_requests'");
        uint64 readRequests = 0;
        if (qr)
        {
            readRequests = qr->Fetch()[1].GetUInt64();
        }

        qr = CharacterDatabase.Query("SHOW STATUS LIKE 'Innodb_buffer_pool_reads'");
        uint64 diskReads = 0;
        if (qr)
        {
            diskReads = qr->Fetch()[1].GetUInt64();
        }

        if (readRequests > 0)
        {
            float hitRate = 100.0f * (1.0f - (float)diskReads / (float)readRequests);
            handler->PSendSysMessage("InnoDB Buffer Pool Hit Rate: %.2f%%", hitRate);
        }

        // Query cache (if available)
        qr = CharacterDatabase.Query("SHOW VARIABLES LIKE 'query_cache_type'");
        if (qr)
        {
            handler->PSendSysMessage("Query Cache: %s", qr->Fetch()[1].GetCString());
        }
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
                        // Use safe high GUID/Season to avoid messing real data if any exists
                        ins << "INSERT INTO dc_vault_reward_pool (character_guid, season_id, week_start, slot_index, item_id, item_level) "
                            << "VALUES (" << fakeGuid << ", 999, " << weekStart << ", " << j << ", 49623, 264)";
                        trans->Append(ins.str().c_str());
                    }
                    
                    // Immediately rollback/delete in same transaction to be safe
                    std::ostringstream cleanup;
                    cleanup << "DELETE FROM dc_vault_reward_pool WHERE season_id = 999 AND week_start = " << weekStart;
                    trans->Append(cleanup.str().c_str());
                    
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

} // namespace DCPerfTest

class dc_perftest_commandscript : public CommandScript
{
public:
    dc_perftest_commandscript() : CommandScript("dc_perftest_commandscript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable perftestTable =
        {
            { "sql",     HandlePerfTestSQL,     SEC_ADMINISTRATOR, Console::No },
            { "cache",   HandlePerfTestCache,   SEC_ADMINISTRATOR, Console::No },
            { "systems", HandlePerfTestSystems, SEC_ADMINISTRATOR, Console::No },
            { "stress",  HandlePerfTestStress,  SEC_ADMINISTRATOR, Console::No },
            { "full",    HandlePerfTestFull,    SEC_ADMINISTRATOR, Console::No },
            { "mysql",   HandlePerfTestMySQL,   SEC_ADMINISTRATOR, Console::No },
            { "",        HandlePerfTestHelp,    SEC_ADMINISTRATOR, Console::No }
        };

        static ChatCommandTable dcTable =
        {
            { "perftest", perftestTable }
        };

        return dcTable;
    }

    static bool HandlePerfTestHelp(ChatHandler* handler)
    {
        handler->SendSysMessage("|cff00ff00=== DC Performance Testing ===|r");
        handler->SendSysMessage("Usage: .dc perftest <subcommand>");
        handler->SendSysMessage("");
        handler->SendSysMessage("Subcommands:");
        handler->SendSysMessage("  |cffffffffsql|r     - SQL stress tests (bulk queries, transactions)");
        handler->SendSysMessage("  |cffffffffcache|r   - Cache performance tests");
        handler->SendSysMessage("  |cffffffffsystems|r - Per-system performance tests");
        handler->SendSysMessage("  |cffffffffstress|r  - Heavy stress tests (upgrades, collection, logins)");
        handler->SendSysMessage("  |cfffffffffull|r    - Run all tests including stress");
        handler->SendSysMessage("  |cffffffffmysql|r   - MySQL connection stats");
        return true;
    }

    static bool HandlePerfTestSQL(ChatHandler* handler)
    {
        handler->SendSysMessage("|cff00ff00=== DC Performance Test: SQL Stress ===|r");
        handler->SendSysMessage("|cffaaaaaa(Running tests, please wait...)|r");

        using namespace DCPerfTest;

        // Test 1: Bulk SELECT
        auto r1 = TestBulkSelect(1000);
        PrintResult(handler, r1);

        // Test 2: Repeated queries (cache behavior)
        auto r2 = TestRepeatedQueries(100);
        PrintResult(handler, r2);

        // Test 3: Transaction batch
        auto r3 = TestTransactionBatch(50);
        PrintResult(handler, r3);

        // Test 4: DC-specific table queries
        auto r4 = TestDCTableQueries();
        PrintResult(handler, r4);

        handler->SendSysMessage("|cff00ff00=== SQL Test Complete ===|r");
        return true;
    }

    static bool HandlePerfTestCache(ChatHandler* handler)
    {
        handler->SendSysMessage("|cff00ff00=== DC Performance Test: Cache ===|r");
        handler->SendSysMessage("|cffaaaaaa(Running tests, please wait...)|r");

        using namespace DCPerfTest;

        // Test 1: CreatureTemplate cache
        auto r1 = TestObjectMgrCache();
        PrintResult(handler, r1);

        // Test 2: ItemTemplate cache
        auto r2 = TestItemTemplateCache();
        PrintResult(handler, r2);

        handler->SendSysMessage("|cff00ff00=== Cache Test Complete ===|r");
        return true;
    }

    static bool HandlePerfTestSystems(ChatHandler* handler)
    {
        handler->SendSysMessage("|cff00ff00=== DC Performance Test: Systems ===|r");
        handler->SendSysMessage("|cffaaaaaa(Testing DC subsystems...)|r");

        using namespace DCPerfTest;

        // Test DC table access patterns
        auto r1 = TestDCTableQueries();
        PrintResult(handler, r1);

        // Could add more system-specific tests here:
        // - Collection system cache
        // - ItemUpgrade calculations
        // - Hotspot lookups
        // - HLBG player data

        handler->SendSysMessage("|cff00ff00=== Systems Test Complete ===|r");
        return true;
    }

    static bool HandlePerfTestFull(ChatHandler* handler)
    {
        handler->SendSysMessage("|cff00ff00========================================|r");
        handler->SendSysMessage("|cff00ff00  DC Full Performance Test Suite|r");
        handler->SendSysMessage("|cff00ff00========================================|r");
        handler->SendSysMessage("");

        auto overallStart = DCPerfTest::Clock::now();

        // Run all test suites
        HandlePerfTestSQL(handler);
        handler->SendSysMessage("");
        HandlePerfTestCache(handler);
        handler->SendSysMessage("");
        HandlePerfTestSystems(handler);
        handler->SendSysMessage("");
        HandlePerfTestStress(handler);
        handler->SendSysMessage("");
        HandlePerfTestMySQL(handler);

        auto overallEnd = DCPerfTest::Clock::now();
        auto totalMs = std::chrono::duration_cast<DCPerfTest::Milliseconds>(overallEnd - overallStart).count();

        handler->SendSysMessage("");
        handler->SendSysMessage("|cff00ff00========================================|r");
        handler->PSendSysMessage("|cff00ff00  Total test time: %llu ms|r", totalMs);
        handler->SendSysMessage("|cff00ff00========================================|r");

        return true;
    }

    static    bool HandlePerfTestStress(ChatHandler* handler, const char* args)
    {
        handler->SendSysMessage("|cff00ff00=== DC Performance Test: STRESS SIMULATION ===|r");
        handler->SendSysMessage("Running heavy load simulations. Server may hiccup...");

        // Default base count is 50, but allow user override: .dc perftest stress 100
        uint32 baseCount = 50;
        if (args && *args)
        {
             uint32 val = atoi(args);
             if (val > 0) baseCount = val;
        }
        
        uint32 limitSafe = (baseCount > 500) ? 500 : baseCount; // Safety cap for heavy tests

        // Scale tests relative to base count
        // 1. Item Upgrade Lookups (Fast, do 10x)
        auto r1 = TestItemUpgradeStateLookups(baseCount * 10);
        PrintResult(handler, r1);

        // 2. Collection Queries (Medium, do 8x)
        auto r2 = TestCollectionTableQueries(baseCount * 8);
        PrintResult(handler, r2);

        // 3. Login Simulation (Heavy, 1x)
        auto r3 = TestLoginSimulation(limitSafe);
        PrintResult(handler, r3);

        // 4. Concurrent Pattern (Fast, 4x)
        auto r4 = TestConcurrentQueryPattern(baseCount * 4);
        PrintResult(handler, r4);

        // 5. Mass transaction write (Medium, 2x)
        auto r5 = TestMassTransactionWrite(baseCount * 2);
        PrintResult(handler, r5);

        // 6. Great Vault Generation (Heavy, 2x)
        auto r6 = TestGreatVaultSimulation(limitSafe * 2);
        PrintResult(handler, r6);

        // 7. Guild House Load Simulation (Heavy, 1x)
        auto r7 = TestGuildHouseLoadSimulation(limitSafe);
        PrintResult(handler, r7);

        // 8. Mass Map Entity Load (Very Heavy, 0.4x)
        auto r8 = TestMassMapEntityLoad((limitSafe > 2) ? (limitSafe * 4 / 10) : 1);
        PrintResult(handler, r8);

        handler->SendSysMessage("|cff00ff00=== Stress Test Complete ===|r");
        return true;
    }

    static bool HandlePerfTestMySQL(ChatHandler* handler)
    {
        DCPerfTest::PrintMySQLStatus(handler);
        return true;
    }
};

void AddSC_dc_perftest()
{
    new dc_perftest_commandscript();
}
