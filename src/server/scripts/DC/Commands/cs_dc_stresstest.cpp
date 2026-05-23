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
#include "CharacterCache.h"
#include "PathGenerator.h"
#include "Random.h"
#include "SpellMgr.h"
#include "DBCStores.h"
#include "DC/CrossSystem/CrossSystemWorldBossMgr.h"
#include "../AddonExtension/dc_addon_groupfinder_mgr.h"
#include "../AddonExtension/dc_addon_death_markers.h"
#include "../AddonExtension/dc_addon_namespace.h"
#include <chrono>
#include <array>
#include <charconv>
#include <memory>
#include <vector>
#include <algorithm>
#include <cctype>
#include <numeric>
#include <sstream>
#include <cmath>
#include <thread>
#include <iomanip>
#include <fstream>
#include <filesystem>
#include <ctime>
#include <limits>
#include <mutex>

extern uint32 GetHotspotXPBonusPercentage();

namespace DCPerfTest
{
    // Timing utilities
    using Clock = std::chrono::high_resolution_clock;
    using Microseconds = std::chrono::microseconds;
    using Nanoseconds = std::chrono::nanoseconds;
    using Milliseconds = std::chrono::milliseconds;

    constexpr std::time_t WELCOME_CONTENT_CACHE_TTL_SECS = 30;

    struct CachedFaqSurfacePayload
    {
        std::string entries = "[]";
        uint32 count = 0;
        std::time_t expiresAt = 0;
    };

    struct CachedWhatsNewSurfacePayload
    {
        std::string version = "1.0.0";
        std::string entries = "[]";
        uint32 count = 0;
        std::time_t expiresAt = 0;
    };

    constexpr uint64 HLBG_STRESS_CACHE_TTL_MS = 1000;
    constexpr uint64 WORLD_STRESS_CACHE_TTL_MS = 1000;

    struct CachedHLBGStressPayload
    {
        std::string payload;
        uint64 expiresAtMs = 0;
    };

    struct CachedWorldStressPayload
    {
        std::string snapshotPayload;
        std::vector<std::string> bossUpdatePayloads;
        uint64 expiresAtMs = 0;
    };

    std::mutex sWelcomeSurfaceCacheLock;
    CachedFaqSurfacePayload sCachedWelcomeFaqSurfacePayload;
    CachedWhatsNewSurfacePayload sCachedWelcomeWhatsNewSurfacePayload;
    std::mutex sHLBGStressCacheLock;
    CachedHLBGStressPayload sCachedHLBGSeasonalPayload;
    std::mutex sWorldStressCacheLock;
    CachedWorldStressPayload sCachedWorldStressPayload;
    std::unordered_map<uint32, CachedHLBGStressPayload>
        sCachedHLBGAllTimePayloads;

    uint64 GetStressNowMs()
    {
        return static_cast<uint64>(std::chrono::duration_cast<Milliseconds>(
            Clock::now().time_since_epoch()).count());
    }

    CachedFaqSurfacePayload GetCachedWelcomeFaqSurfacePayload()
    {
        std::time_t const now = std::time(nullptr);
        std::lock_guard<std::mutex> lock(sWelcomeSurfaceCacheLock);

        if (sCachedWelcomeFaqSurfacePayload.expiresAt > now)
            return sCachedWelcomeFaqSurfacePayload;

        CachedFaqSurfacePayload payload;
        if (QueryResult result = WorldDatabase.Query(
            "SELECT id, category, question, answer FROM dc_welcome_faq "
            "WHERE active = 1 ORDER BY category, priority DESC, id"))
        {
            DCAddon::JsonValue entriesArray;
            entriesArray.SetArray();

            do
            {
                Field* fields = result->Fetch();
                DCAddon::JsonValue entry;
                entry.SetObject();
                entry.Set("id", DCAddon::JsonValue(static_cast<int32>(fields[0].Get<uint32>())));
                entry.Set("category", DCAddon::JsonValue(fields[1].Get<std::string>()));
                entry.Set("question", DCAddon::JsonValue(fields[2].Get<std::string>()));
                entry.Set("answer", DCAddon::JsonValue(fields[3].Get<std::string>()));
                entriesArray.Push(entry);
                ++payload.count;
            } while (result->NextRow());

            payload.entries = entriesArray.Encode();
        }

        payload.expiresAt = now + WELCOME_CONTENT_CACHE_TTL_SECS;
        sCachedWelcomeFaqSurfacePayload = payload;
        return payload;
    }

    CachedWhatsNewSurfacePayload GetCachedWelcomeWhatsNewSurfacePayload()
    {
        std::time_t const now = std::time(nullptr);
        std::lock_guard<std::mutex> lock(sWelcomeSurfaceCacheLock);

        if (sCachedWelcomeWhatsNewSurfacePayload.expiresAt > now)
            return sCachedWelcomeWhatsNewSurfacePayload;

        CachedWhatsNewSurfacePayload payload;
        if (QueryResult result = WorldDatabase.Query(
            "SELECT id, version, title, content, icon, category FROM dc_welcome_whats_new "
            "WHERE active = 1 AND (expires_at IS NULL OR expires_at > NOW()) "
            "ORDER BY priority DESC, id DESC LIMIT 10"))
        {
            DCAddon::JsonValue entriesArray;
            entriesArray.SetArray();

            do
            {
                Field* fields = result->Fetch();
                DCAddon::JsonValue entry;
                entry.SetObject();
                entry.Set("id", DCAddon::JsonValue(static_cast<int32>(fields[0].Get<uint32>())));
                entry.Set("version", DCAddon::JsonValue(fields[1].Get<std::string>()));
                entry.Set("title", DCAddon::JsonValue(fields[2].Get<std::string>()));
                entry.Set("content", DCAddon::JsonValue(fields[3].Get<std::string>()));
                entry.Set("icon", DCAddon::JsonValue(fields[4].Get<std::string>()));
                entry.Set("category", DCAddon::JsonValue(fields[5].Get<std::string>()));
                entriesArray.Push(entry);
                ++payload.count;

                if (payload.version == "1.0.0")
                    payload.version = fields[1].Get<std::string>();
            } while (result->NextRow());

            payload.entries = entriesArray.Encode();
        }

        payload.expiresAt = now + WELCOME_CONTENT_CACHE_TTL_SECS;
        sCachedWelcomeWhatsNewSurfacePayload = payload;
        return payload;
    }

    struct TimingResult
    {
        std::string testName;
        uint64 totalUs = 0;
        uint64 avgUs = 0;
        uint64 minUs = 0;
        uint64 maxUs = 0;
        uint64 p95Us = 0;
        uint64 p99Us = 0;
        std::string totalDisplay;
        std::string avgDisplay;
        std::string minDisplay;
        std::string maxDisplay;
        std::string p95Display;
        std::string p99Display;
        uint64 avgSortNs = 0;
        uint32 iterations = 0;
        uint32 throughputCount = 0;
        bool success = false;
        std::string error;
    };

    TimingResult TestGreatVaultSimulation(uint32 playerCount);

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

    static std::string FormatPreciseScalar(double value, char const* unit)
    {
        std::ostringstream out;
        double rounded = std::round(value);
        if (std::fabs(value - rounded) < 0.0005)
        {
            out << static_cast<int64>(rounded);
        }
        else
        {
            int precision = 3;
            if (std::fabs(value) >= 100.0)
                precision = 1;
            else if (std::fabs(value) >= 10.0)
                precision = 2;

            out << std::fixed << std::setprecision(precision) << value;
            std::string text = out.str();
            while (!text.empty() && text.back() == '0')
                text.pop_back();
            if (!text.empty() && text.back() == '.')
                text.pop_back();
            out.str("");
            out.clear();
            out << text;
        }

        out << unit;
        return out.str();
    }

    static std::string FormatTimeFromNanoseconds(double nanoseconds)
    {
        if (nanoseconds >= 1000000000.0)
            return FormatPreciseScalar(nanoseconds / 1000000000.0, "s");
        if (nanoseconds >= 1000000.0)
            return FormatPreciseScalar(nanoseconds / 1000000.0, "ms");
        if (nanoseconds >= 1000.0)
            return FormatPreciseScalar(nanoseconds / 1000.0, "us");
        return FormatPreciseScalar(nanoseconds, "ns");
    }

    static void ClearTimingStats(TimingResult& result)
    {
        result.totalUs = 0;
        result.avgUs = 0;
        result.minUs = 0;
        result.maxUs = 0;
        result.p95Us = 0;
        result.p99Us = 0;
        result.avgSortNs = 0;
        result.totalDisplay.clear();
        result.avgDisplay.clear();
        result.minDisplay.clear();
        result.maxDisplay.clear();
        result.p95Display.clear();
        result.p99Display.clear();
    }

    static void FinalizeTimingSamples(TimingResult& result, std::vector<uint64>& times)
    {
        if (times.empty())
        {
            ClearTimingStats(result);
            result.iterations = 0;
            return;
        }

        std::sort(times.begin(), times.end());
        result.totalUs = std::accumulate(times.begin(), times.end(), 0ULL);

        uint32 divisor = result.iterations ? result.iterations : static_cast<uint32>(times.size());
        result.avgUs = divisor ? result.totalUs / divisor : 0;
        result.avgSortNs = divisor ? (result.totalUs * 1000ULL) / divisor : 0;
        result.minUs = times.front();
        result.maxUs = times.back();
        result.p95Us = GetPercentile(times, 95.0f);
        result.p99Us = GetPercentile(times, 99.0f);
    }

    static void FinalizeTimingSamplesNs(TimingResult& result,
        std::vector<uint64>& timesNs)
    {
        if (timesNs.empty())
        {
            ClearTimingStats(result);
            result.iterations = 0;
            return;
        }

        std::sort(timesNs.begin(), timesNs.end());
        uint64 totalNs = std::accumulate(timesNs.begin(), timesNs.end(), 0ULL);
        uint32 divisor = result.iterations ? result.iterations : static_cast<uint32>(timesNs.size());

        result.totalUs = totalNs / 1000;
        result.avgUs = divisor ? result.totalUs / divisor : 0;
        result.avgSortNs = divisor ? totalNs / divisor : 0;
        result.minUs = timesNs.front() / 1000;
        result.maxUs = timesNs.back() / 1000;
        result.p95Us = GetPercentile(timesNs, 95.0f) / 1000;
        result.p99Us = GetPercentile(timesNs, 99.0f) / 1000;

        result.totalDisplay = FormatTimeFromNanoseconds(static_cast<double>(totalNs));
        result.avgDisplay = divisor
            ? FormatTimeFromNanoseconds(static_cast<double>(totalNs) / divisor)
            : std::string("0ns");
        result.minDisplay = FormatTimeFromNanoseconds(static_cast<double>(timesNs.front()));
        result.maxDisplay = FormatTimeFromNanoseconds(static_cast<double>(timesNs.back()));
        result.p95Display = FormatTimeFromNanoseconds(static_cast<double>(GetPercentile(timesNs, 95.0f)));
        result.p99Display = FormatTimeFromNanoseconds(static_cast<double>(GetPercentile(timesNs, 99.0f)));
    }

    static TimingResult MakeSkippedTimingResult(std::string const& testName, std::string const& reason)
    {
        TimingResult result;
        result.testName = testName + " [SKIPPED: " + reason + "]";
        result.iterations = 0;
        result.throughputCount = 0;
        result.success = true;
        ClearTimingStats(result);
        return result;
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

    static uint32 GetThroughputCount(TimingResult const& result)
    {
        return result.throughputCount ? result.throughputCount : result.iterations;
    }

    static std::string GetDisplayedTime(TimingResult const& result,
        std::string TimingResult::*displayField,
        uint64 TimingResult::*valueField)
    {
        return (result.*displayField).empty()
            ? FormatTime(result.*valueField)
            : (result.*displayField);
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
                out << "\"throughput_count\":" << GetThroughputCount(r) << ",";
                out << "\"total_us\":" << r.totalUs << ",";
                out << "\"avg_us\":" << r.avgUs << ",";
                out << "\"min_us\":" << r.minUs << ",";
                out << "\"max_us\":" << r.maxUs << ",";
                out << "\"p95_us\":" << r.p95Us << ",";
                out << "\"p99_us\":" << r.p99Us << ",";
                out << "\"total_display\":\"" << JsonEscape(GetDisplayedTime(r, &TimingResult::totalDisplay, &TimingResult::totalUs)) << "\",";
                out << "\"avg_display\":\"" << JsonEscape(GetDisplayedTime(r, &TimingResult::avgDisplay, &TimingResult::avgUs)) << "\",";
                out << "\"min_display\":\"" << JsonEscape(GetDisplayedTime(r, &TimingResult::minDisplay, &TimingResult::minUs)) << "\",";
                out << "\"max_display\":\"" << JsonEscape(GetDisplayedTime(r, &TimingResult::maxDisplay, &TimingResult::maxUs)) << "\",";
                out << "\"p95_display\":\"" << JsonEscape(GetDisplayedTime(r, &TimingResult::p95Display, &TimingResult::p95Us)) << "\",";
                out << "\"p99_display\":\"" << JsonEscape(GetDisplayedTime(r, &TimingResult::p99Display, &TimingResult::p99Us)) << "\",";
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
            out << "testName,success,iterations,throughput_count,total_us,avg_us,min_us,max_us,p95_us,p99_us,total_display,avg_display,min_display,max_display,p95_display,p99_display,error\n";

            for (TimingResult const& r : results)
            {
                out << CsvEscape(r.testName) << ",";
                out << (r.success ? 1 : 0) << ",";
                out << r.iterations << ",";
                out << GetThroughputCount(r) << ",";
                out << r.totalUs << ",";
                out << r.avgUs << ",";
                out << r.minUs << ",";
                out << r.maxUs << ",";
                out << r.p95Us << ",";
                out << r.p99Us << ",";
                out << CsvEscape(GetDisplayedTime(r, &TimingResult::totalDisplay, &TimingResult::totalUs)) << ",";
                out << CsvEscape(GetDisplayedTime(r, &TimingResult::avgDisplay, &TimingResult::avgUs)) << ",";
                out << CsvEscape(GetDisplayedTime(r, &TimingResult::minDisplay, &TimingResult::minUs)) << ",";
                out << CsvEscape(GetDisplayedTime(r, &TimingResult::maxDisplay, &TimingResult::maxUs)) << ",";
                out << CsvEscape(GetDisplayedTime(r, &TimingResult::p95Display, &TimingResult::p95Us)) << ",";
                out << CsvEscape(GetDisplayedTime(r, &TimingResult::p99Display, &TimingResult::p99Us)) << ",";
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
            out << "\"throughput_count\":" << GetThroughputCount(r) << ",";
            out << "\"total_us\":" << r.totalUs << ",";
            out << "\"avg_us\":" << r.avgUs << ",";
            out << "\"min_us\":" << r.minUs << ",";
            out << "\"max_us\":" << r.maxUs << ",";
            out << "\"p95_us\":" << r.p95Us << ",";
            out << "\"p99_us\":" << r.p99Us << ",";
            out << "\"total_display\":\"" << JsonEscape(GetDisplayedTime(r, &TimingResult::totalDisplay, &TimingResult::totalUs)) << "\",";
            out << "\"avg_display\":\"" << JsonEscape(GetDisplayedTime(r, &TimingResult::avgDisplay, &TimingResult::avgUs)) << "\",";
            out << "\"min_display\":\"" << JsonEscape(GetDisplayedTime(r, &TimingResult::minDisplay, &TimingResult::minUs)) << "\",";
            out << "\"max_display\":\"" << JsonEscape(GetDisplayedTime(r, &TimingResult::maxDisplay, &TimingResult::maxUs)) << "\",";
            out << "\"p95_display\":\"" << JsonEscape(GetDisplayedTime(r, &TimingResult::p95Display, &TimingResult::p95Us)) << "\",";
            out << "\"p99_display\":\"" << JsonEscape(GetDisplayedTime(r, &TimingResult::p99Display, &TimingResult::p99Us)) << "\",";
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
        out << "run_index,wall_us,testName,success,iterations,throughput_count,total_us,avg_us,min_us,max_us,p95_us,p99_us,total_display,avg_display,min_display,max_display,p95_display,p99_display,error\n";
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
            out << GetThroughputCount(r) << ",";
            out << r.totalUs << ",";
            out << r.avgUs << ",";
            out << r.minUs << ",";
            out << r.maxUs << ",";
            out << r.p95Us << ",";
            out << r.p99Us << ",";
            out << CsvEscape(GetDisplayedTime(r, &TimingResult::totalDisplay, &TimingResult::totalUs)) << ",";
            out << CsvEscape(GetDisplayedTime(r, &TimingResult::avgDisplay, &TimingResult::avgUs)) << ",";
            out << CsvEscape(GetDisplayedTime(r, &TimingResult::minDisplay, &TimingResult::minUs)) << ",";
            out << CsvEscape(GetDisplayedTime(r, &TimingResult::maxDisplay, &TimingResult::maxUs)) << ",";
            out << CsvEscape(GetDisplayedTime(r, &TimingResult::p95Display, &TimingResult::p95Us)) << ",";
            out << CsvEscape(GetDisplayedTime(r, &TimingResult::p99Display, &TimingResult::p99Us)) << ",";
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
        result.throughputCount = rowCount;
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
            result.throughputCount = fetchedRows;

            if (fetchedRows > 0)
            {
                std::string avgDisplay = FormatTimeFromNanoseconds(
                    (static_cast<double>(result.totalUs) * 1000.0) / fetchedRows);
                result.avgDisplay = avgDisplay;
                result.minDisplay = avgDisplay;
                result.maxDisplay = avgDisplay;
                result.p95Display = avgDisplay;
                result.p99Display = avgDisplay;
                result.avgSortNs = (static_cast<uint64>(result.totalUs) * 1000ULL) / fetchedRows;
            }

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
        result.throughputCount = batchSize;
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

            CharacterDatabase.DirectCommitTransaction(trans);

            auto end = Clock::now();
            result.totalUs = std::chrono::duration_cast<Microseconds>(end - start).count();
            result.avgUs = result.totalUs / batchSize;
            result.minUs = result.avgUs;
            result.maxUs = result.avgUs;
            result.p95Us = result.avgUs;
            result.p99Us = result.avgUs;

            std::string avgDisplay = FormatTimeFromNanoseconds(
                (static_cast<double>(result.totalUs) * 1000.0) / batchSize);
            result.avgDisplay = avgDisplay;
            result.minDisplay = avgDisplay;
            result.maxDisplay = avgDisplay;
            result.p95Display = avgDisplay;
            result.p99Display = avgDisplay;
            result.avgSortNs = (static_cast<uint64>(result.totalUs) * 1000ULL) / batchSize;
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

    TimingResult TestCoreCharacterTableQueries(uint32 iterations)
    {
        TimingResult result;
        result.testName = "Core Character Table Queries (" + std::to_string(iterations) + " queries)";
        result.iterations = iterations;
        result.success = true;

        std::vector<uint64> times;
        times.reserve(iterations);

        const char* tables[] = {
            "characters",
            "character_inventory",
            "character_queststatus",
            "character_achievement",
            "mail",
            "guild_member",
            "group_member"
        };

        std::vector<char const*> existingTables;
        existingTables.reserve(std::size(tables));
        for (char const* table : tables)
            if (CharacterTableExists(table))
                existingTables.push_back(table);

        if (existingTables.empty())
        {
            result.testName += " [SKIPPED: no core character tables present]";
            result.iterations = 0;
            result.totalUs = result.avgUs = result.minUs = result.maxUs = result.p95Us = result.p99Us = 0;
            return result;
        }

        try
        {
            for (uint32 i = 0; i < iterations; ++i)
            {
                char const* table = existingTables[i % existingTables.size()];

                std::ostringstream sql;
                if (std::string(table) == "characters")
                    sql << "SELECT guid, name, level FROM characters WHERE guid = " << (1 + (i % 500000));
                else if (std::string(table) == "character_inventory")
                    sql << "SELECT guid, bag, slot, item FROM character_inventory WHERE guid = " << (1 + (i % 500000)) << " LIMIT 25";
                else if (std::string(table) == "character_queststatus")
                    sql << "SELECT guid, quest FROM character_queststatus WHERE guid = " << (1 + (i % 500000)) << " LIMIT 25";
                else if (std::string(table) == "character_achievement")
                    sql << "SELECT guid, achievement FROM character_achievement WHERE guid = " << (1 + (i % 500000)) << " LIMIT 25";
                else if (std::string(table) == "mail")
                    sql << "SELECT id, receiver, subject FROM mail WHERE receiver = " << (1 + (i % 500000)) << " LIMIT 25";
                else if (std::string(table) == "guild_member")
                    sql << "SELECT guildid, guid, `rank` FROM guild_member WHERE guildid = " << (1 + (i % 50000)) << " LIMIT 50";
                else if (std::string(table) == "group_member")
                    sql << "SELECT guid, memberGuid FROM group_member WHERE guid = " << (1 + (i % 50000)) << " LIMIT 50";
                else
                    sql << "SELECT 1 FROM " << table << " LIMIT 1";

                auto start = Clock::now();
                QueryResult qr = CharacterDatabase.Query(sql.str().c_str());
                (void)qr;
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

    TimingResult TestCoreWorldTableQueries(uint32 iterations)
    {
        TimingResult result;
        result.testName = "Core World Table Queries (" + std::to_string(iterations) + " queries)";
        result.iterations = iterations;
        result.success = true;

        std::vector<uint64> times;
        times.reserve(iterations);

        const char* tables[] = {
            "creature_template",
            "item_template",
            "quest_template",
            "gameobject_template",
            "npc_vendor",
            "creature_loot_template",
            "gameobject_loot_template"
        };

        std::vector<char const*> existingTables;
        existingTables.reserve(std::size(tables));
        for (char const* table : tables)
            if (WorldTableExists(table))
                existingTables.push_back(table);

        if (existingTables.empty())
        {
            result.testName += " [SKIPPED: no core world tables present]";
            result.iterations = 0;
            result.totalUs = result.avgUs = result.minUs = result.maxUs = result.p95Us = result.p99Us = 0;
            return result;
        }

        try
        {
            for (uint32 i = 0; i < iterations; ++i)
            {
                char const* table = existingTables[i % existingTables.size()];

                std::ostringstream sql;
                if (std::string(table) == "creature_template")
                    sql << "SELECT entry, name FROM creature_template WHERE entry = " << (1 + (i % 500000));
                else if (std::string(table) == "item_template")
                    sql << "SELECT entry, name FROM item_template WHERE entry = " << (1 + (i % 800000));
                else if (std::string(table) == "quest_template")
                    sql << "SELECT ID FROM quest_template WHERE ID = " << (1 + (i % 200000));
                else if (std::string(table) == "gameobject_template")
                    sql << "SELECT entry, name FROM gameobject_template WHERE entry = " << (1 + (i % 200000));
                else if (std::string(table) == "npc_vendor")
                    sql << "SELECT entry, item FROM npc_vendor WHERE entry = " << (1 + (i % 500000)) << " LIMIT 25";
                else if (std::string(table) == "creature_loot_template")
                    sql << "SELECT entry, item FROM creature_loot_template WHERE entry = " << (1 + (i % 500000)) << " LIMIT 25";
                else if (std::string(table) == "gameobject_loot_template")
                    sql << "SELECT entry, item FROM gameobject_loot_template WHERE entry = " << (1 + (i % 200000)) << " LIMIT 25";
                else
                    sql << "SELECT 1 FROM " << table << " LIMIT 1";

                auto start = Clock::now();
                QueryResult qr = WorldDatabase.Query(sql.str().c_str());
                (void)qr;
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
    // Cache Performance Tests
    // =========================================================================

    TimingResult TestObjectMgrCache()
    {
        TimingResult result;
        result.testName = "ObjectMgr Cache (creature templates)";
        result.success = true;
        result.iterations = 10000;

        std::vector<uint64> timesNs;
        const uint32 iterations = 10000;
        timesNs.reserve(iterations);

        try
        {
            uint64 digest = 0;

            for (uint32 i = 0; i < iterations; ++i)
            {
                uint32 entry = (i % 1000) + 1; // Cycle through entries 1-1000

                auto start = Clock::now();
                if (CreatureTemplate const* creatureTemplate = sObjectMgr->GetCreatureTemplate(entry))
                    digest += creatureTemplate->Entry;
                auto end = Clock::now();

                timesNs.push_back(std::chrono::duration_cast<Nanoseconds>(end - start).count());
            }

            if (digest == std::numeric_limits<uint64>::max())
                result.error.clear();

            FinalizeTimingSamplesNs(result, timesNs);
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
        result.iterations = 10000;

        std::vector<uint64> timesNs;
        const uint32 iterations = 10000;
        timesNs.reserve(iterations);

        try
        {
            uint64 digest = 0;

            for (uint32 i = 0; i < iterations; ++i)
            {
                uint32 entry = (i % 5000) + 1; // Cycle through item entries

                auto start = Clock::now();
                if (ItemTemplate const* itemTemplate = sObjectMgr->GetItemTemplate(entry))
                    digest += itemTemplate->ItemLevel;
                auto end = Clock::now();

                timesNs.push_back(std::chrono::duration_cast<Nanoseconds>(end - start).count());
            }

            if (digest == std::numeric_limits<uint64>::max())
                result.error.clear();

            FinalizeTimingSamplesNs(result, timesNs);
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

        auto formatField = [](std::string const& overrideText, uint64 us) -> std::string
        {
            return overrideText.empty() ? FormatTime(us) : overrideText;
        };

        handler->SendSysMessage(Acore::StringFormat("|cffffffff{}|r", result.testName));
        handler->SendSysMessage(Acore::StringFormat("  Total: {} | Avg: {} | Min: {} | Max: {}",
            formatField(result.totalDisplay, result.totalUs),
            formatField(result.avgDisplay, result.avgUs),
            formatField(result.minDisplay, result.minUs),
            formatField(result.maxDisplay, result.maxUs)));

        uint32 throughputCount = result.throughputCount ? result.throughputCount : result.iterations;
        if (throughputCount > 0 && result.totalUs > 0)
        {
            double secs = double(result.totalUs) / 1000000.0;
            double opsPerSec = secs > 0.0 ? (double(throughputCount) / secs) : 0.0;
            handler->SendSysMessage(Acore::StringFormat("  Ops/s: {:.2f}", opsPerSec));
        }

        if (result.iterations > 1)
        {
            handler->SendSysMessage(Acore::StringFormat("  P95: {} | P99: {} ({} iterations)",
                formatField(result.p95Display, result.p95Us),
                formatField(result.p99Display, result.p99Us),
                result.iterations));
        }
    }

    void PrintReportSummary(ChatHandler* handler, std::vector<TimingResult> const& results, uint32 topN)
    {
        if (!handler)
            return;

        auto formatField = [](TimingResult const& r,
            std::string TimingResult::*displayField,
            uint64 TimingResult::*valueField) -> std::string
        {
            return (r.*displayField).empty() ? FormatTime(r.*valueField) : (r.*displayField);
        };

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
        auto avgNs = [](TimingResult const* r) -> uint64
        {
            return r->avgSortNs ? r->avgSortNs : (r->avgUs * 1000ULL);
        };
        auto byAvgDesc = [avgNs](TimingResult const* a, TimingResult const* b)
        {
            return avgNs(a) > avgNs(b);
        };

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
                formatField(r, &TimingResult::totalDisplay, &TimingResult::totalUs),
                formatField(r, &TimingResult::avgDisplay, &TimingResult::avgUs),
                formatField(r, &TimingResult::p95Display, &TimingResult::p95Us),
                formatField(r, &TimingResult::p99Display, &TimingResult::p99Us),
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
                formatField(r, &TimingResult::avgDisplay, &TimingResult::avgUs),
                formatField(r, &TimingResult::p95Display, &TimingResult::p95Us),
                formatField(r, &TimingResult::p99Display, &TimingResult::p99Us),
                formatField(r, &TimingResult::totalDisplay, &TimingResult::totalUs),
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

    struct AddonStressAvailability
    {
        bool hasProtocolCaps = false;
        bool hasProtocolStats = false;
        bool hasProtocolErrors = false;
        bool hasProtocolLog = false;
        bool hasQosSettings = false;
        bool hasHotspots = false;
        bool hasWelcomeFaq = false;
        bool hasWelcomeWhatsNew = false;
        bool hasMplusRating = false;
        bool hasPrestige = false;
        bool hasSeasonalStats = false;
        bool hasMplusScores = false;
        bool hasMplusRuns = false;
        bool hasWeeklyVault = false;
        bool hasCharacters = false;
        bool hasGroupFinderListings = false;
        bool hasGroupFinderEvents = false;
        bool hasGroupFinderSignups = false;
        bool hasMplusKeys = false;
        bool hasMplusBestRuns = false;
        bool hasMplusDungeons = false;
        bool hasWardrobeOutfits = false;
        bool hasHLBGSeasonal = false;
        bool hasHLBGAllTime = false;
        bool hasHLBGParticipants = false;
        bool hasHLBGWinnerHistory = false;
        char const* transmogCollectionTable = nullptr;
        char const* hlbgAllTimeGamesColumn = nullptr;
        char const* hlbgAllTimeWinsColumn = nullptr;
        char const* hlbgAllTimeLossesColumn = nullptr;
        char const* hlbgAllTimeKillsColumn = nullptr;
        char const* hlbgAllTimeDeathsColumn = nullptr;
        char const* hlbgAllTimeKdRatioColumn = nullptr;
        char const* hlbgAllTimeAvgKillsColumn = nullptr;
        char const* hlbgAllTimeAvgDamageColumn = nullptr;

        bool HasProtocolSurface() const
        {
            return hasProtocolCaps || hasProtocolStats || hasProtocolErrors || hasProtocolLog;
        }

        bool HasLiveProtocolSurface() const
        {
            return hasProtocolCaps || hasProtocolErrors || hasProtocolLog;
        }

        bool HasWelcomeSurface() const
        {
            return hasWelcomeFaq || hasWelcomeWhatsNew || hasMplusRating || hasPrestige
                || hasMplusScores || hasMplusRuns || hasWeeklyVault;
        }

        bool HasGroupFinderSurface() const
        {
            return hasGroupFinderListings || hasGroupFinderEvents || hasGroupFinderSignups;
        }

        bool HasMythicPlusSurface() const
        {
            return hasMplusKeys || hasMplusBestRuns;
        }

        bool HasWardrobeSurface() const
        {
            return hasWardrobeOutfits || transmogCollectionTable != nullptr;
        }

        bool HasHLBGUnifiedTables() const
        {
            return hasHLBGParticipants && hasHLBGWinnerHistory;
        }

        bool HasHLBGSurface() const
        {
            return HasHLBGUnifiedTables() || hasHLBGSeasonal || (hasHLBGAllTime
                && hlbgAllTimeGamesColumn != nullptr
                && hlbgAllTimeWinsColumn != nullptr
                && hlbgAllTimeLossesColumn != nullptr
                && hlbgAllTimeKillsColumn != nullptr
                && hlbgAllTimeDeathsColumn != nullptr
                && hlbgAllTimeKdRatioColumn != nullptr
                && hlbgAllTimeAvgKillsColumn != nullptr
                && hlbgAllTimeAvgDamageColumn != nullptr);
        }

        bool HasAnySurface() const
        {
            return HasProtocolSurface() || hasQosSettings || hasHotspots || HasWelcomeSurface()
                || HasGroupFinderSurface() || HasMythicPlusSurface()
                || HasWardrobeSurface() || HasHLBGSurface();
        }
    };

    std::string const& BuildWelcomeProgressSnapshotStressQuery(
        bool useWeeklyVaultSummary,
        bool useSeasonalProgressSummary)
    {
        static std::array<std::string, 4> const queries = []
        {
            std::array<std::string, 4> builtQueries;
            auto buildQuery = [](bool useWeeklyVault, bool useSeasonalSummary)
            {
                std::string seasonPointsSelect;
                std::string seasonPointsJoin;
                if (useSeasonalSummary)
                {
                    seasonPointsSelect = "COALESCE(s.weekly_tokens_earned, 0)";
                    seasonPointsJoin =
                        "LEFT JOIN dc_player_seasonal_stats s "
                        "ON s.player_guid = {} AND s.season_id = {} ";
                }
                else
                {
                    seasonPointsSelect = "COALESCE(sp.season_points, 0)";
                    seasonPointsJoin =
                        "LEFT JOIN (SELECT COALESCE(SUM(best_score), 0) AS season_points "
                        "FROM dc_mplus_scores WHERE character_guid = {} AND season_id = {}) sp "
                        "ON 1 = 1 ";
                }

                std::string weeklyRunsSelect;
                std::string weeklyRunsJoin;
                if (useWeeklyVault)
                {
                    weeklyRunsSelect = "COALESCE(v.runs_completed, 0)";
                    weeklyRunsJoin =
                        "LEFT JOIN dc_weekly_vault v "
                        "ON v.character_guid = {} AND v.season_id = {} "
                        "AND v.week_start = {} ";
                }
                else
                {
                    weeklyRunsSelect = "COALESCE(wr.runs_completed, 0)";
                    weeklyRunsJoin =
                        "LEFT JOIN (SELECT COUNT(*) AS runs_completed FROM dc_mplus_runs "
                        "WHERE character_guid = {} AND season_id = {} AND success = 1 "
                        "AND completed_at >= FROM_UNIXTIME({}) "
                        "AND completed_at < FROM_UNIXTIME({})) wr ON 1 = 1 ";
                }

                return std::string(
                    "SELECT COALESCE(r.rating, 0), COALESCE(p.prestige_level, 0), ")
                    + seasonPointsSelect + ", " + weeklyRunsSelect + ", "
                    + "LEAST(5, COALESCE(alt.alt_count, 0)) "
                    + "FROM (SELECT 1) seed "
                    + "LEFT JOIN dc_mplus_player_ratings r "
                    + "ON r.player_guid = {} AND r.season_id = {} "
                    + "LEFT JOIN dc_character_prestige p ON p.guid = {} "
                    + seasonPointsJoin
                    + weeklyRunsJoin
                    + "LEFT JOIN (SELECT COUNT(*) AS alt_count FROM characters "
                    + "WHERE account = {} AND level >= {}) alt ON 1 = 1";
            };

            builtQueries[0] = buildQuery(false, false);
            builtQueries[1] = buildQuery(false, true);
            builtQueries[2] = buildQuery(true, false);
            builtQueries[3] = buildQuery(true, true);
            return builtQueries;
        }();

        std::size_t const queryIndex =
            (useWeeklyVaultSummary ? 2u : 0u)
            + (useSeasonalProgressSummary ? 1u : 0u);
        return queries[queryIndex];
    }

    enum class AddonSurface : uint8
    {
        Protocol,
        ProtocolClientCaps,
        ProtocolStats,
        ProtocolErrors,
        ProtocolLog,
        QoS,
        World,
        Welcome,
        WelcomeFaq,
        WelcomeWhatsNew,
        WelcomeProgress,
        WelcomeProgressRating,
        WelcomeProgressPrestige,
        WelcomeProgressSeasonPoints,
        WelcomeProgressWeeklyRuns,
        WelcomeProgressAltBonus,
        GroupFinder,
        GroupFinderListings,
        GroupFinderEvents,
        GroupFinderSignups,
        MythicPlus,
        MythicPlusKeyInfo,
        MythicPlusBestRuns,
        Wardrobe,
        WardrobeCommunity,
        WardrobeCollected,
        HLBG,
        HLBGSeasonal,
        HLBGAllTime,
    };

    char const* GetAddonSurfaceName(AddonSurface surface)
    {
        switch (surface)
        {
            case AddonSurface::Protocol:
                return "Protocol (live)";
            case AddonSurface::ProtocolClientCaps:
                return "Protocol Client Caps";
            case AddonSurface::ProtocolStats:
                return "Protocol Stats (benchmark-only)";
            case AddonSurface::ProtocolErrors:
                return "Protocol Errors";
            case AddonSurface::ProtocolLog:
                return "Protocol Log";
            case AddonSurface::QoS:
                return "QoS";
            case AddonSurface::World:
                return "World";
            case AddonSurface::Welcome:
                return "Welcome";
            case AddonSurface::WelcomeFaq:
                return "Welcome FAQ";
            case AddonSurface::WelcomeWhatsNew:
                return "Welcome What's New";
            case AddonSurface::WelcomeProgress:
                return "Welcome Progress";
            case AddonSurface::WelcomeProgressRating:
                return "Welcome Progress Rating";
            case AddonSurface::WelcomeProgressPrestige:
                return "Welcome Progress Prestige";
            case AddonSurface::WelcomeProgressSeasonPoints:
                return "Welcome Progress Season Points";
            case AddonSurface::WelcomeProgressWeeklyRuns:
                return "Welcome Progress Weekly Runs";
            case AddonSurface::WelcomeProgressAltBonus:
                return "Welcome Progress Alt Bonus";
            case AddonSurface::GroupFinder:
                return "GroupFinder";
            case AddonSurface::GroupFinderListings:
                return "GroupFinder Listings";
            case AddonSurface::GroupFinderEvents:
                return "GroupFinder Scheduled Events";
            case AddonSurface::GroupFinderSignups:
                return "GroupFinder My Signups";
            case AddonSurface::MythicPlus:
                return "MythicPlus";
            case AddonSurface::MythicPlusKeyInfo:
                return "MythicPlus Key Info";
            case AddonSurface::MythicPlusBestRuns:
                return "MythicPlus Best Runs";
            case AddonSurface::Wardrobe:
                return "Wardrobe";
            case AddonSurface::WardrobeCommunity:
                return "Wardrobe Community Outfits";
            case AddonSurface::WardrobeCollected:
                return "Wardrobe Collected Appearances";
            case AddonSurface::HLBG:
                return "HLBG";
            case AddonSurface::HLBGSeasonal:
                return "HLBG Seasonal";
            case AddonSurface::HLBGAllTime:
                return "HLBG All-Time";
        }

        return "Unknown";
    }

    std::vector<AddonSurface> CollectAddonStressSurfaces(
        AddonStressAvailability const& availability)
    {
        std::vector<AddonSurface> surfaces;
        surfaces.reserve(8);

        if (availability.HasLiveProtocolSurface())
            surfaces.push_back(AddonSurface::Protocol);
        if (availability.hasQosSettings)
            surfaces.push_back(AddonSurface::QoS);
        if (availability.hasHotspots)
            surfaces.push_back(AddonSurface::World);
        if (availability.HasWelcomeSurface())
            surfaces.push_back(AddonSurface::Welcome);
        if (availability.HasGroupFinderSurface())
            surfaces.push_back(AddonSurface::GroupFinder);
        if (availability.HasMythicPlusSurface())
            surfaces.push_back(AddonSurface::MythicPlus);
        if (availability.HasWardrobeSurface())
            surfaces.push_back(AddonSurface::Wardrobe);
        if (availability.HasHLBGSurface())
            surfaces.push_back(AddonSurface::HLBG);

        return surfaces;
    }

    std::vector<AddonSurface> CollectAddonProtocolSurfaceDetails(
        AddonStressAvailability const& availability)
    {
        std::vector<AddonSurface> surfaces;
        surfaces.reserve(4);

        if (availability.hasProtocolCaps)
            surfaces.push_back(AddonSurface::ProtocolClientCaps);
        if (availability.hasProtocolStats)
            surfaces.push_back(AddonSurface::ProtocolStats);
        if (availability.hasProtocolErrors)
            surfaces.push_back(AddonSurface::ProtocolErrors);
        if (availability.hasProtocolLog)
            surfaces.push_back(AddonSurface::ProtocolLog);

        return surfaces;
    }

    std::vector<AddonSurface> CollectAddonWelcomeSurfaceDetails(
        AddonStressAvailability const& availability)
    {
        std::vector<AddonSurface> surfaces;
        surfaces.reserve(3);

        if (availability.hasWelcomeFaq)
            surfaces.push_back(AddonSurface::WelcomeFaq);
        if (availability.hasWelcomeWhatsNew)
            surfaces.push_back(AddonSurface::WelcomeWhatsNew);
        if (availability.hasMplusScores || availability.hasMplusRating
            || availability.hasPrestige || availability.hasMplusRuns)
        {
            surfaces.push_back(AddonSurface::WelcomeProgress);
        }

        return surfaces;
    }

    std::vector<AddonSurface> CollectAddonWelcomeProgressSurfaceDetails(
        AddonStressAvailability const& availability)
    {
        std::vector<AddonSurface> surfaces;
        surfaces.reserve(5);

        if (availability.hasMplusRating)
            surfaces.push_back(AddonSurface::WelcomeProgressRating);
        if (availability.hasPrestige)
            surfaces.push_back(AddonSurface::WelcomeProgressPrestige);
        if (availability.hasMplusScores)
            surfaces.push_back(AddonSurface::WelcomeProgressSeasonPoints);
        if (availability.hasMplusRuns || availability.hasWeeklyVault)
            surfaces.push_back(AddonSurface::WelcomeProgressWeeklyRuns);
        if (availability.hasCharacters)
            surfaces.push_back(AddonSurface::WelcomeProgressAltBonus);

        return surfaces;
    }

    std::vector<AddonSurface> CollectAddonGroupFinderSurfaceDetails(
        AddonStressAvailability const& availability)
    {
        std::vector<AddonSurface> surfaces;
        surfaces.reserve(3);

        if (availability.hasGroupFinderListings)
            surfaces.push_back(AddonSurface::GroupFinderListings);
        if (availability.hasGroupFinderEvents)
            surfaces.push_back(AddonSurface::GroupFinderEvents);
        if (availability.hasGroupFinderEvents && availability.hasGroupFinderSignups)
            surfaces.push_back(AddonSurface::GroupFinderSignups);

        return surfaces;
    }

    std::vector<AddonSurface> CollectAddonMythicPlusSurfaceDetails(
        AddonStressAvailability const& availability)
    {
        std::vector<AddonSurface> surfaces;
        surfaces.reserve(2);

        if (availability.hasMplusKeys)
            surfaces.push_back(AddonSurface::MythicPlusKeyInfo);
        if (availability.hasMplusBestRuns)
            surfaces.push_back(AddonSurface::MythicPlusBestRuns);

        return surfaces;
    }

    std::vector<AddonSurface> CollectAddonWardrobeSurfaceDetails(
        AddonStressAvailability const& availability)
    {
        std::vector<AddonSurface> surfaces;
        surfaces.reserve(2);

        if (availability.hasWardrobeOutfits)
            surfaces.push_back(AddonSurface::WardrobeCommunity);
        if (availability.transmogCollectionTable)
            surfaces.push_back(AddonSurface::WardrobeCollected);

        return surfaces;
    }

    std::vector<AddonSurface> CollectAddonHLBGSurfaceDetails(
        AddonStressAvailability const& availability)
    {
        std::vector<AddonSurface> surfaces;
        surfaces.reserve(2);

        if (availability.HasHLBGUnifiedTables() || availability.hasHLBGSeasonal)
            surfaces.push_back(AddonSurface::HLBGSeasonal);
        if (availability.HasHLBGUnifiedTables() || (availability.hasHLBGAllTime
            && availability.hlbgAllTimeGamesColumn
            && availability.hlbgAllTimeWinsColumn
            && availability.hlbgAllTimeLossesColumn
            && availability.hlbgAllTimeKillsColumn
            && availability.hlbgAllTimeDeathsColumn
            && availability.hlbgAllTimeKdRatioColumn
            && availability.hlbgAllTimeAvgKillsColumn
            && availability.hlbgAllTimeAvgDamageColumn))
        {
            surfaces.push_back(AddonSurface::HLBGAllTime);
        }

        return surfaces;
    }

    bool IsAddonSurfaceAvailable(AddonStressAvailability const& availability,
        AddonSurface surface)
    {
        switch (surface)
        {
            case AddonSurface::Protocol:
                return availability.HasLiveProtocolSurface();
            case AddonSurface::ProtocolClientCaps:
                return availability.hasProtocolCaps;
            case AddonSurface::ProtocolStats:
                return availability.hasProtocolStats;
            case AddonSurface::ProtocolErrors:
                return availability.hasProtocolErrors;
            case AddonSurface::ProtocolLog:
                return availability.hasProtocolLog;
            case AddonSurface::QoS:
                return availability.hasQosSettings;
            case AddonSurface::World:
                return availability.hasHotspots;
            case AddonSurface::Welcome:
                return availability.HasWelcomeSurface();
            case AddonSurface::WelcomeFaq:
                return availability.hasWelcomeFaq;
            case AddonSurface::WelcomeWhatsNew:
                return availability.hasWelcomeWhatsNew;
            case AddonSurface::WelcomeProgress:
                return availability.hasMplusScores || availability.hasMplusRating
                    || availability.hasPrestige || availability.hasMplusRuns
                    || availability.hasWeeklyVault;
            case AddonSurface::WelcomeProgressRating:
                return availability.hasMplusRating;
            case AddonSurface::WelcomeProgressPrestige:
                return availability.hasPrestige;
            case AddonSurface::WelcomeProgressSeasonPoints:
                return availability.hasMplusScores;
            case AddonSurface::WelcomeProgressWeeklyRuns:
                return availability.hasMplusRuns || availability.hasWeeklyVault;
            case AddonSurface::WelcomeProgressAltBonus:
                return availability.hasCharacters;
            case AddonSurface::GroupFinder:
                return availability.HasGroupFinderSurface();
            case AddonSurface::GroupFinderListings:
                return availability.hasGroupFinderListings;
            case AddonSurface::GroupFinderEvents:
                return availability.hasGroupFinderEvents;
            case AddonSurface::GroupFinderSignups:
                return availability.hasGroupFinderEvents
                    && availability.hasGroupFinderSignups;
            case AddonSurface::MythicPlus:
                return availability.HasMythicPlusSurface();
            case AddonSurface::MythicPlusKeyInfo:
                return availability.hasMplusKeys;
            case AddonSurface::MythicPlusBestRuns:
                return availability.hasMplusBestRuns;
            case AddonSurface::Wardrobe:
                return availability.HasWardrobeSurface();
            case AddonSurface::WardrobeCommunity:
                return availability.hasWardrobeOutfits;
            case AddonSurface::WardrobeCollected:
                return availability.transmogCollectionTable != nullptr;
            case AddonSurface::HLBG:
                return availability.HasHLBGSurface();
            case AddonSurface::HLBGSeasonal:
                return availability.HasHLBGUnifiedTables()
                    || availability.hasHLBGSeasonal;
            case AddonSurface::HLBGAllTime:
                return availability.HasHLBGUnifiedTables()
                    || (availability.hasHLBGAllTime
                    && availability.hlbgAllTimeGamesColumn
                    && availability.hlbgAllTimeWinsColumn
                    && availability.hlbgAllTimeLossesColumn
                    && availability.hlbgAllTimeKillsColumn
                    && availability.hlbgAllTimeDeathsColumn
                    && availability.hlbgAllTimeKdRatioColumn
                    && availability.hlbgAllTimeAvgKillsColumn
                    && availability.hlbgAllTimeAvgDamageColumn);
        }

        return false;
    }

    static AddonStressAvailability DetectAddonStressAvailability()
    {
        AddonStressAvailability availability;

        availability.hasProtocolCaps = CharacterTableExists("dc_addon_client_caps");
        availability.hasProtocolStats = CharacterTableExists("dc_addon_protocol_stats");
        availability.hasProtocolErrors = CharacterTableExists("dc_addon_protocol_errors");
        availability.hasProtocolLog = CharacterTableExists("dc_addon_protocol_log");
        availability.hasQosSettings = CharacterTableExists("dc_player_qos_settings");
        availability.hasHotspots = WorldTableExists("dc_hotspots_active");
        availability.hasWelcomeFaq = WorldTableExists("dc_welcome_faq");
        availability.hasWelcomeWhatsNew = WorldTableExists("dc_welcome_whats_new");
        availability.hasMplusRating = CharacterTableExists("dc_mplus_player_ratings");
        availability.hasPrestige = CharacterTableExists("dc_character_prestige");
        availability.hasSeasonalStats = CharacterTableExists("dc_player_seasonal_stats");
        availability.hasMplusScores = CharacterTableExists("dc_mplus_scores");
        availability.hasMplusRuns = CharacterTableExists("dc_mplus_runs");
        availability.hasWeeklyVault = CharacterTableExists("dc_weekly_vault");
        availability.hasCharacters = CharacterTableExists("characters");
        availability.hasGroupFinderListings = CharacterTableExists("dc_group_finder_listings");
        availability.hasGroupFinderEvents = CharacterTableExists("dc_group_finder_scheduled_events");
        availability.hasGroupFinderSignups = CharacterTableExists("dc_group_finder_event_signups");
        availability.hasMplusKeys = CharacterTableExists("dc_mplus_keystones");
        availability.hasMplusBestRuns = CharacterTableExists("dc_mplus_best_runs");
        availability.hasMplusDungeons = CharacterTableExists("dc_mplus_dungeons");
        availability.hasWardrobeOutfits = CharacterTableExists("dc_collection_community_outfits");
        availability.hasHLBGSeasonal = CharacterTableExists("v_hlbg_player_seasonal_stats");
        availability.hasHLBGAllTime = CharacterTableExists("v_hlbg_player_alltime_stats");
        availability.hasHLBGParticipants = CharacterTableExists("dc_hlbg_match_participants");
        availability.hasHLBGWinnerHistory = CharacterTableExists("dc_hlbg_winner_history");

        if (availability.hasHLBGAllTime)
        {
            if (CharacterColumnExists("v_hlbg_player_alltime_stats", "total_matches"))
                availability.hlbgAllTimeGamesColumn = "total_matches";
            else if (CharacterColumnExists("v_hlbg_player_alltime_stats", "total_games_played"))
                availability.hlbgAllTimeGamesColumn = "total_games_played";

            if (CharacterColumnExists("v_hlbg_player_alltime_stats", "lifetime_wins"))
                availability.hlbgAllTimeWinsColumn = "lifetime_wins";
            else if (CharacterColumnExists("v_hlbg_player_alltime_stats", "total_wins"))
                availability.hlbgAllTimeWinsColumn = "total_wins";

            if (CharacterColumnExists("v_hlbg_player_alltime_stats", "lifetime_losses"))
                availability.hlbgAllTimeLossesColumn = "lifetime_losses";
            else if (CharacterColumnExists("v_hlbg_player_alltime_stats", "total_losses"))
                availability.hlbgAllTimeLossesColumn = "total_losses";

            if (CharacterColumnExists("v_hlbg_player_alltime_stats", "lifetime_kills"))
                availability.hlbgAllTimeKillsColumn = "lifetime_kills";
            else if (CharacterColumnExists("v_hlbg_player_alltime_stats", "total_kills"))
                availability.hlbgAllTimeKillsColumn = "total_kills";

            if (CharacterColumnExists("v_hlbg_player_alltime_stats", "lifetime_deaths"))
                availability.hlbgAllTimeDeathsColumn = "lifetime_deaths";
            else if (CharacterColumnExists("v_hlbg_player_alltime_stats", "total_deaths"))
                availability.hlbgAllTimeDeathsColumn = "total_deaths";

            if (CharacterColumnExists("v_hlbg_player_alltime_stats", "lifetime_kd_ratio"))
                availability.hlbgAllTimeKdRatioColumn = "lifetime_kd_ratio";
            else if (CharacterColumnExists("v_hlbg_player_alltime_stats", "overall_kd_ratio"))
                availability.hlbgAllTimeKdRatioColumn = "overall_kd_ratio";

            if (CharacterColumnExists("v_hlbg_player_alltime_stats", "avg_kills_career"))
                availability.hlbgAllTimeAvgKillsColumn = "avg_kills_career";
            else if (CharacterColumnExists("v_hlbg_player_alltime_stats", "avg_kills_per_game"))
                availability.hlbgAllTimeAvgKillsColumn = "avg_kills_per_game";

            if (CharacterColumnExists("v_hlbg_player_alltime_stats", "avg_damage_career"))
                availability.hlbgAllTimeAvgDamageColumn = "avg_damage_career";
            else if (CharacterColumnExists("v_hlbg_player_alltime_stats", "avg_damage_per_game"))
                availability.hlbgAllTimeAvgDamageColumn = "avg_damage_per_game";
        }

        if (CharacterTableExists("dc_transmog_collection"))
            availability.transmogCollectionTable = "dc_transmog_collection";
        else if (CharacterTableExists("dc_collection_transmog"))
            availability.transmogCollectionTable = "dc_collection_transmog";

        return availability;
    }

    std::string ToLowerForStress(std::string value)
    {
        std::transform(value.begin(), value.end(), value.begin(),
            [](unsigned char ch)
            {
                return static_cast<char>(std::tolower(ch));
            });

        return value;
    }

    uint32 ClampStressValue(uint32 value, uint32 fallback, uint32 minValue,
        uint32 maxValue)
    {
        if (value == 0)
            value = fallback;

        if (value < minValue)
            return minValue;

        if (value > maxValue)
            return maxValue;

        return value;
    }

    std::string MakeSizedStressText(std::string const& prefix,
        size_t targetLength, uint32 seed)
    {
        static char const alphabet[] =
            "abcdefghijklmnopqrstuvwxyz0123456789";

        std::string text = prefix;
        if (targetLength == 0)
            return text;

        while (text.size() < targetLength)
        {
            size_t const index =
                (seed + static_cast<uint32>(text.size()))
                % (sizeof(alphabet) - 1);
            text.push_back(alphabet[index]);
        }

        if (text.size() > targetLength)
            text.resize(targetLength);

        return text;
    }

    std::string GetLeaderboardClassNameForStress(uint8 classId)
    {
        switch (classId)
        {
            case 1:
                return "WARRIOR";
            case 2:
                return "PALADIN";
            case 3:
                return "HUNTER";
            case 4:
                return "ROGUE";
            case 5:
                return "PRIEST";
            case 6:
                return "DEATHKNIGHT";
            case 7:
                return "SHAMAN";
            case 8:
                return "MAGE";
            case 9:
                return "WARLOCK";
            case 11:
                return "DRUID";
            default:
                return "UNKNOWN";
        }
    }

    std::string BuildAoeItemsExtraForStress(uint32 qPoor, uint32 qCommon,
        uint32 qUncommon, uint32 qRare, uint32 qEpic, uint32 qLegendary)
    {
        std::ostringstream oss;
        if (qLegendary > 0)
            oss << "|cffff8000L:" << qLegendary << "|r ";
        if (qEpic > 0)
            oss << "|cffa335eeE:" << qEpic << "|r ";
        if (qRare > 0)
            oss << "|cff0070ddR:" << qRare << "|r ";
        if (qUncommon > 0)
            oss << "|cff1eff00U:" << qUncommon << "|r";

        std::string extra = oss.str();
        if (extra.empty())
            extra = std::to_string(qCommon + qPoor) + " common/poor";

        return extra;
    }

    std::string GetGroupFinderDifficultyNameForStress(uint32 listingType,
        uint32 difficulty)
    {
        if (listingType == 2)
        {
            switch (difficulty)
            {
                case 0:
                    return "10 Normal";
                case 1:
                    return "25 Normal";
                case 2:
                    return "10 Heroic";
                case 3:
                    return "25 Heroic";
                default:
                    return "Raid";
            }
        }

        switch (difficulty)
        {
            case 1:
                return "Heroic";
            case 2:
                return "Mythic";
            default:
                return "Normal";
        }
    }

    struct CollectionStressSample
    {
        uint32 mountCount = 72;
        uint32 petCount = 34;
        uint32 heirloomCount = 18;
        uint32 titleCount = 12;
        uint32 transmogCount = 220;
        uint32 mountTotal = 420;
        uint32 petTotal = 180;
        uint32 heirloomTotal = 64;
        uint32 titleTotal = 48;
        uint32 transmogTotal = 1800;
    };

    bool ApplyCollectionSampleValue(CollectionStressSample& sample,
        std::string const& rawKey, uint32 value, bool totals)
    {
        std::string const key = ToLowerForStress(rawKey);

        auto setValue = [&](uint32& countField, uint32& totalField)
        {
            if (totals)
                totalField = value;
            else
                countField = value;
        };

        if (key == "1" || key == "mount" || key == "mounts")
        {
            setValue(sample.mountCount, sample.mountTotal);
            return true;
        }

        if (key == "2" || key == "pet" || key == "pets"
            || key == "companion" || key == "companions")
        {
            setValue(sample.petCount, sample.petTotal);
            return true;
        }

        if (key == "4" || key == "heirloom" || key == "heirlooms")
        {
            setValue(sample.heirloomCount, sample.heirloomTotal);
            return true;
        }

        if (key == "5" || key == "title" || key == "titles")
        {
            setValue(sample.titleCount, sample.titleTotal);
            return true;
        }

        if (key == "6" || key == "transmog" || key == "transmogs"
            || key == "appearance" || key == "appearances")
        {
            setValue(sample.transmogCount, sample.transmogTotal);
            return true;
        }

        return false;
    }

    uint32 LoadTopAccountCountFromTable(char const* tableName)
    {
        if (!CharacterTableExists(tableName)
            || !CharacterColumnExists(tableName, "account_id"))
        {
            return 0;
        }

        std::ostringstream sql;
        sql << "SELECT COUNT(*) FROM " << tableName
            << " GROUP BY account_id ORDER BY COUNT(*) DESC LIMIT 1";
        QueryResult result = CharacterDatabase.Query(sql.str().c_str());
        return result ? result->Fetch()[0].Get<uint32>() : 0;
    }

    inline void AppendUnsignedJsonNumberForStress(std::string& out,
        uint32 value);

    uint32 LoadTopAccountIdFromTable(char const* tableName)
    {
        if (!CharacterTableExists(tableName)
            || !CharacterColumnExists(tableName, "account_id"))
        {
            return 0;
        }

        std::ostringstream sql;
        sql << "SELECT account_id FROM " << tableName
            << " GROUP BY account_id ORDER BY COUNT(*) DESC LIMIT 1";
        QueryResult result = CharacterDatabase.Query(sql.str().c_str());
        return result ? result->Fetch()[0].Get<uint32>() : 0;
    }

    struct WardrobeCollectedStressSample
    {
        uint32 accountId = 0;
        std::shared_ptr<std::string const> payload =
            std::make_shared<std::string>("{\"count\":0,\"appearances\":[]}");
    };

    WardrobeCollectedStressSample LoadWardrobeCollectedStressSample(
        AddonStressAvailability const& availability)
    {
        WardrobeCollectedStressSample sample;
        if (!availability.transmogCollectionTable)
            return sample;

        sample.accountId = LoadTopAccountIdFromTable(
            availability.transmogCollectionTable);
        if (!sample.accountId)
            return sample;

        std::ostringstream sql;
        sql << "SELECT display_id FROM " << availability.transmogCollectionTable
            << " WHERE account_id = " << sample.accountId;
        QueryResult result = CharacterDatabase.Query(sql.str().c_str());
        if (!result)
            return sample;

        std::vector<uint32> appearances;
        do
        {
            uint32 displayId = (*result)[0].Get<uint32>();
            if (displayId)
                appearances.push_back(displayId);
        } while (result->NextRow());

        std::sort(appearances.begin(), appearances.end());
        appearances.erase(std::unique(appearances.begin(), appearances.end()),
            appearances.end());

        auto payload = std::make_shared<std::string>();
        payload->reserve(32 + (appearances.size() * 8));
        payload->append("{\"count\":");
        AppendUnsignedJsonNumberForStress(*payload,
            static_cast<uint32>(appearances.size()));
        payload->append(",\"appearances\":[");
        for (std::size_t index = 0; index < appearances.size(); ++index)
        {
            if (index > 0)
                payload->push_back(',');

            AppendUnsignedJsonNumberForStress(*payload, appearances[index]);
        }
        payload->append("]}");
        sample.payload = payload;
        return sample;
    }

    WardrobeCollectedStressSample const& GetWardrobeCollectedStressSample(
        AddonStressAvailability const& availability)
    {
        static WardrobeCollectedStressSample const sample =
            LoadWardrobeCollectedStressSample(availability);
        return sample;
    }

    struct GroupFinderStressVariant;

    std::vector<GroupFinderStressVariant> const&
        GetGroupFinderStressVariants();
    static std::vector<uint32> const& GetHLBGParticipantSampleGuids();
    std::string GetCachedHLBGSeasonalPayloadForStress(
        AddonStressAvailability const& availability);

    void PrewarmAddonSurfaceBenchmarkState(
        AddonStressAvailability const& availability)
    {
        if (availability.transmogCollectionTable)
            (void)GetWardrobeCollectedStressSample(availability);

        if (availability.HasGroupFinderSurface())
            (void)GetGroupFinderStressVariants();

        if (availability.HasHLBGSurface())
        {
            (void)GetHLBGParticipantSampleGuids();
            if (availability.hasHLBGSeasonal || availability.HasHLBGUnifiedTables())
            {
                (void)GetCachedHLBGSeasonalPayloadForStress(availability);
            }
        }
    }

    CollectionStressSample LoadCollectionStressSample()
    {
        CollectionStressSample sample;
        AddonStressAvailability const availability =
            DetectAddonStressAvailability();

        if (CharacterTableExists("dc_collection_items")
            && CharacterColumnExists("dc_collection_items", "account_id")
            && CharacterColumnExists("dc_collection_items", "collection_type")
            && CharacterColumnExists("dc_collection_items", "unlocked"))
        {
            QueryResult result = CharacterDatabase.Query(
                "SELECT account_id, "
                "SUM(CASE WHEN LOWER(CAST(collection_type AS CHAR)) IN ('1', 'mount', 'mounts') THEN 1 ELSE 0 END) AS mounts, "
                "SUM(CASE WHEN LOWER(CAST(collection_type AS CHAR)) IN ('2', 'pet', 'pets', 'companion', 'companions') THEN 1 ELSE 0 END) AS pets, "
                "SUM(CASE WHEN LOWER(CAST(collection_type AS CHAR)) IN ('4', 'heirloom', 'heirlooms') THEN 1 ELSE 0 END) AS heirlooms, "
                "SUM(CASE WHEN LOWER(CAST(collection_type AS CHAR)) IN ('5', 'title', 'titles') THEN 1 ELSE 0 END) AS titles, "
                "SUM(CASE WHEN LOWER(CAST(collection_type AS CHAR)) IN ('6', 'transmog', 'transmogs', 'appearance', 'appearances') THEN 1 ELSE 0 END) AS transmog "
                "FROM dc_collection_items "
                "WHERE unlocked = 1 "
                "GROUP BY account_id "
                "ORDER BY mounts + pets + heirlooms + titles + transmog DESC "
                "LIMIT 1");

            if (result)
            {
                Field* fields = result->Fetch();
                uint32 const totalOwned = fields[1].Get<uint32>()
                    + fields[2].Get<uint32>() + fields[3].Get<uint32>()
                    + fields[4].Get<uint32>() + fields[5].Get<uint32>();

                if (totalOwned > 0)
                {
                    sample.mountCount = fields[1].Get<uint32>();
                    sample.petCount = fields[2].Get<uint32>();
                    sample.heirloomCount = fields[3].Get<uint32>();
                    sample.titleCount = fields[4].Get<uint32>();
                    sample.transmogCount = fields[5].Get<uint32>();
                }
            }
        }

        if (WorldTableExists("dc_collection_definitions")
            && WorldColumnExists("dc_collection_definitions", "collection_type"))
        {
            std::ostringstream sql;
            sql << "SELECT LOWER(CAST(collection_type AS CHAR)), COUNT(*) "
                << "FROM dc_collection_definitions";

            if (WorldColumnExists("dc_collection_definitions", "enabled"))
                sql << " WHERE enabled = 1";

            sql << " GROUP BY LOWER(CAST(collection_type AS CHAR))";

            QueryResult result = WorldDatabase.Query(sql.str().c_str());
            if (result)
            {
                do
                {
                    Field* fields = result->Fetch();
                    ApplyCollectionSampleValue(sample,
                        fields[0].Get<std::string>(),
                        fields[1].Get<uint32>(), true);
                } while (result->NextRow());
            }
        }

        if (WorldTableExists("dc_mount_definitions"))
        {
            QueryResult result = WorldDatabase.Query(
                "SELECT COUNT(*) FROM dc_mount_definitions");
            if (result)
                sample.mountTotal = result->Fetch()[0].Get<uint32>();
        }

        if (WorldTableExists("dc_pet_definitions"))
        {
            QueryResult result = WorldDatabase.Query(
                "SELECT COUNT(*) FROM dc_pet_definitions");
            if (result)
                sample.petTotal = result->Fetch()[0].Get<uint32>();
        }

        if (WorldTableExists("dc_heirloom_definitions"))
        {
            QueryResult result = WorldDatabase.Query(
                "SELECT COUNT(*) FROM dc_heirloom_definitions");
            if (result)
                sample.heirloomTotal = result->Fetch()[0].Get<uint32>();
        }

        uint32 legacyMountCount = LoadTopAccountCountFromTable(
            "dc_mount_collection");
        if (legacyMountCount == 0)
            legacyMountCount = LoadTopAccountCountFromTable(
                "dc_collection_mounts");
        if (legacyMountCount > 0)
            sample.mountCount = legacyMountCount;

        uint32 legacyPetCount = LoadTopAccountCountFromTable(
            "dc_pet_collection");
        if (legacyPetCount == 0)
            legacyPetCount = LoadTopAccountCountFromTable(
                "dc_collection_pets");
        if (legacyPetCount > 0)
            sample.petCount = legacyPetCount;

        uint32 legacyHeirloomCount = LoadTopAccountCountFromTable(
            "dc_heirloom_collection");
        if (legacyHeirloomCount == 0)
            legacyHeirloomCount = LoadTopAccountCountFromTable(
                "dc_collection_heirlooms");
        if (legacyHeirloomCount > 0)
            sample.heirloomCount = legacyHeirloomCount;

        if (availability.transmogCollectionTable)
        {
            uint32 const transmogCount = LoadTopAccountCountFromTable(
                availability.transmogCollectionTable);
            if (transmogCount > 0)
                sample.transmogCount = transmogCount;
        }

        sample.mountTotal = std::max(sample.mountTotal, sample.mountCount);
        sample.petTotal = std::max(sample.petTotal, sample.petCount);
        sample.heirloomTotal = std::max(sample.heirloomTotal,
            sample.heirloomCount);
        sample.titleTotal = std::max(sample.titleTotal, sample.titleCount);
        sample.transmogTotal = std::max(sample.transmogTotal,
            sample.transmogCount);

        return sample;
    }

    struct LeaderboardStressRowSample
    {
        std::string name = "Player";
        std::string className = "WARRIOR";
        uint32 score = 1;
        std::string extra = "detail";
        uint32 mapId = 0;
        bool hasWinsLosses = false;
        uint32 wins = 0;
        uint32 losses = 0;
        bool hasKD = false;
        uint32 kills = 0;
        uint32 deaths = 0;
        double kdRatio = 0.0;
        bool hasQuality = false;
        uint32 qPoor = 0;
        uint32 qCommon = 0;
        uint32 qUncommon = 0;
        uint32 qRare = 0;
        uint32 qEpic = 0;
        uint32 qLeg = 0;
    };

    struct LeaderboardStressVariant
    {
        std::string category;
        std::string subcategory;
        uint32 totalEntries = 0;
        uint32 scoreBase = 0;
        uint32 auxA = 0;
        uint32 auxB = 0;
        uint32 auxC = 0;
        uint32 auxD = 0;
        std::vector<LeaderboardStressRowSample> rowSamples;
    };

    std::vector<LeaderboardStressVariant> LoadLeaderboardStressVariants()
    {
        std::vector<LeaderboardStressVariant> variants;
        variants.reserve(4);

        LeaderboardStressVariant mplus;
        mplus.category = "mplus";
        mplus.subcategory = "mplus_key";
        mplus.totalEntries = 96;
        mplus.scoreBase = 18;
        mplus.auxA = 33;
        variants.push_back(mplus);

        LeaderboardStressVariant hlbg;
        hlbg.category = "hlbg";
        hlbg.subcategory = "hlbg_rating";
        hlbg.totalEntries = 64;
        hlbg.scoreBase = 2200;
        hlbg.auxA = 40;
        hlbg.auxB = 8;
        variants.push_back(hlbg);

        LeaderboardStressVariant duel;
        duel.category = "duel";
        duel.subcategory = "duel_wins";
        duel.totalEntries = 48;
        duel.scoreBase = 180;
        duel.auxA = 12;
        variants.push_back(duel);

        LeaderboardStressVariant aoe;
        aoe.category = "aoe";
        aoe.subcategory = "aoe_items";
        aoe.totalEntries = 64;
        aoe.scoreBase = 900;
        aoe.auxA = 90;
        aoe.auxB = 40;
        aoe.auxC = 20;
        aoe.auxD = 3;
        variants.push_back(aoe);

        if (CharacterTableExists("dc_mplus_scores"))
        {
            QueryResult result = CharacterDatabase.Query(
                "SELECT COUNT(DISTINCT character_guid), "
                "COALESCE(MAX(best_level), 0) "
                "FROM dc_mplus_scores");
            if (result)
            {
                Field* fields = result->Fetch();
                if (fields[0].Get<uint32>() > 0)
                    variants[0].totalEntries = fields[0].Get<uint32>();
                variants[0].scoreBase = std::max<uint32>(10,
                    fields[1].Get<uint32>());
            }

            if (CharacterTableExists("characters"))
            {
                result = CharacterDatabase.Query(
                    "SELECT c.name, c.class, MAX(s.best_level) AS best_level, "
                    "SUM(s.best_score) AS total_score, SUM(s.total_runs) AS total_runs, "
                    "COALESCE(MAX(s.map_id), 0) AS map_id "
                    "FROM dc_mplus_scores s "
                    "JOIN characters c ON s.character_guid = c.guid "
                    "GROUP BY s.character_guid, c.name, c.class "
                    "ORDER BY best_level DESC, total_score DESC "
                    "LIMIT 50");

                if (result)
                {
                    do
                    {
                        Field* fields = result->Fetch();
                        LeaderboardStressRowSample rowSample;
                        rowSample.name = fields[0].Get<std::string>();
                        rowSample.className = GetLeaderboardClassNameForStress(
                            fields[1].Get<uint8>());
                        rowSample.score = std::max<uint32>(1,
                            fields[2].Get<uint32>());
                        rowSample.mapId = fields[5].Get<uint32>();
                        rowSample.extra = std::to_string(fields[4].Get<uint32>())
                            + " runs";
                        variants[0].rowSamples.push_back(rowSample);
                    } while (result->NextRow());
                }
            }
        }

        if (CharacterTableExists("v_hlbg_player_seasonal_stats"))
        {
            QueryResult result = CharacterDatabase.Query(
                "SELECT COUNT(DISTINCT guid), COALESCE(MAX(current_rating), 0), "
                "COALESCE(ROUND(AVG(wins)), 0), COALESCE(ROUND(AVG(losses)), 0) "
                "FROM v_hlbg_player_seasonal_stats");
            if (result)
            {
                Field* fields = result->Fetch();
                variants[1].subcategory = "hlbg_rating";
                if (fields[0].Get<uint32>() > 0)
                    variants[1].totalEntries = fields[0].Get<uint32>();
                variants[1].scoreBase = std::max<uint32>(1000,
                    fields[1].Get<uint32>());
                variants[1].auxA = fields[2].Get<uint32>();
                variants[1].auxB = fields[3].Get<uint32>();
            }

            if (CharacterTableExists("characters"))
            {
                result = CharacterDatabase.Query(
                    "SELECT c.name, c.class, v.current_rating, v.wins, v.losses "
                    "FROM v_hlbg_player_seasonal_stats v "
                    "JOIN characters c ON v.guid = c.guid "
                    "ORDER BY v.current_rating DESC "
                    "LIMIT 50");

                if (result)
                {
                    do
                    {
                        Field* fields = result->Fetch();
                        LeaderboardStressRowSample rowSample;
                        uint32 wins = fields[3].Get<uint32>();
                        uint32 losses = fields[4].Get<uint32>();
                        rowSample.name = fields[0].Get<std::string>();
                        rowSample.className = GetLeaderboardClassNameForStress(
                            fields[1].Get<uint8>());
                        rowSample.score = std::max<uint32>(1,
                            fields[2].Get<uint32>());
                        rowSample.hasWinsLosses = true;
                        rowSample.wins = wins;
                        rowSample.losses = losses;
                        rowSample.extra = std::to_string(wins) + "W/"
                            + std::to_string(losses) + "L";
                        variants[1].rowSamples.push_back(rowSample);
                    } while (result->NextRow());
                }
            }
        }
        else if (CharacterTableExists("dc_hlbg_player_stats"))
        {
            QueryResult result = CharacterDatabase.Query(
                "SELECT COUNT(*), COALESCE(MAX(total_kills), 0), "
                "COALESCE(ROUND(AVG(battles_won)), 0), "
                "COALESCE(ROUND(AVG(total_deaths)), 0) "
                "FROM dc_hlbg_player_stats");
            if (result)
            {
                Field* fields = result->Fetch();
                variants[1].subcategory = "hlbg_kills";
                if (fields[0].Get<uint32>() > 0)
                    variants[1].totalEntries = fields[0].Get<uint32>();
                variants[1].scoreBase = std::max<uint32>(250,
                    fields[1].Get<uint32>());
                variants[1].auxA = fields[2].Get<uint32>();
                variants[1].auxB = fields[3].Get<uint32>();
            }

            if (CharacterTableExists("characters"))
            {
                result = CharacterDatabase.Query(
                    "SELECT c.name, c.class, h.total_kills, h.total_deaths, "
                    "h.battles_won, h.battles_participated "
                    "FROM dc_hlbg_player_stats h "
                    "JOIN characters c ON h.player_guid = c.guid "
                    "ORDER BY h.total_kills DESC "
                    "LIMIT 50");

                if (result)
                {
                    do
                    {
                        Field* fields = result->Fetch();
                        LeaderboardStressRowSample rowSample;
                        uint32 kills = fields[2].Get<uint32>();
                        uint32 deaths = fields[3].Get<uint32>();
                        double kdRatio = deaths > 0
                            ? (static_cast<double>(kills) / deaths)
                            : static_cast<double>(kills);
                        char kdBuffer[16];
                        std::snprintf(kdBuffer, sizeof(kdBuffer), "%.2f K/D",
                            kdRatio);

                        rowSample.name = fields[0].Get<std::string>();
                        rowSample.className = GetLeaderboardClassNameForStress(
                            fields[1].Get<uint8>());
                        rowSample.score = std::max<uint32>(1, kills);
                        rowSample.hasKD = true;
                        rowSample.kills = kills;
                        rowSample.deaths = deaths;
                        rowSample.kdRatio = kdRatio;
                        rowSample.extra = kdBuffer;
                        variants[1].rowSamples.push_back(rowSample);
                    } while (result->NextRow());
                }
            }
        }

        if (CharacterTableExists("dc_duel_statistics"))
        {
            QueryResult result = CharacterDatabase.Query(
                "SELECT COUNT(*), COALESCE(MAX(wins), 0), "
                "COALESCE(ROUND(AVG(losses)), 0) "
                "FROM dc_duel_statistics");
            if (result)
            {
                Field* fields = result->Fetch();
                if (fields[0].Get<uint32>() > 0)
                    variants[2].totalEntries = fields[0].Get<uint32>();
                variants[2].scoreBase = std::max<uint32>(50,
                    fields[1].Get<uint32>());
                variants[2].auxA = fields[2].Get<uint32>();
            }

            if (CharacterTableExists("characters"))
            {
                result = CharacterDatabase.Query(
                    "SELECT c.name, c.class, d.wins, d.losses "
                    "FROM dc_duel_statistics d "
                    "JOIN characters c ON d.player_guid = c.guid "
                    "ORDER BY d.wins DESC "
                    "LIMIT 50");

                if (result)
                {
                    do
                    {
                        Field* fields = result->Fetch();
                        LeaderboardStressRowSample rowSample;
                        rowSample.name = fields[0].Get<std::string>();
                        rowSample.className = GetLeaderboardClassNameForStress(
                            fields[1].Get<uint8>());
                        rowSample.score = std::max<uint32>(1,
                            fields[2].Get<uint32>());
                        rowSample.extra = std::to_string(fields[3].Get<uint32>())
                            + " losses";
                        variants[2].rowSamples.push_back(rowSample);
                    } while (result->NextRow());
                }
            }
        }

        if (CharacterTableExists("dc_aoeloot_detailed_stats"))
        {
            QueryResult result = CharacterDatabase.Query(
                "SELECT COUNT(*), COALESCE(MAX(total_items), 0), "
                "COALESCE(ROUND(AVG(quality_uncommon)), 0), "
                "COALESCE(ROUND(AVG(quality_rare)), 0), "
                "COALESCE(ROUND(AVG(quality_epic)), 0), "
                "COALESCE(ROUND(AVG(quality_legendary)), 0) "
                "FROM dc_aoeloot_detailed_stats");
            if (result)
            {
                Field* fields = result->Fetch();
                if (fields[0].Get<uint32>() > 0)
                    variants[3].totalEntries = fields[0].Get<uint32>();
                variants[3].scoreBase = std::max<uint32>(250,
                    fields[1].Get<uint32>());
                variants[3].auxA = fields[2].Get<uint32>();
                variants[3].auxB = fields[3].Get<uint32>();
                variants[3].auxC = fields[4].Get<uint32>();
                variants[3].auxD = fields[5].Get<uint32>();
            }

            if (CharacterTableExists("characters"))
            {
                result = CharacterDatabase.Query(
                    "SELECT c.name, c.class, a.total_items, "
                    "COALESCE(a.quality_poor, 0), COALESCE(a.quality_common, 0), "
                    "COALESCE(a.quality_uncommon, 0), COALESCE(a.quality_rare, 0), "
                    "COALESCE(a.quality_epic, 0), COALESCE(a.quality_legendary, 0) "
                    "FROM dc_aoeloot_detailed_stats a "
                    "JOIN characters c ON a.player_guid = c.guid "
                    "ORDER BY a.total_items DESC "
                    "LIMIT 50");

                if (result)
                {
                    do
                    {
                        Field* fields = result->Fetch();
                        LeaderboardStressRowSample rowSample;
                        rowSample.name = fields[0].Get<std::string>();
                        rowSample.className = GetLeaderboardClassNameForStress(
                            fields[1].Get<uint8>());
                        rowSample.score = std::max<uint32>(1,
                            fields[2].Get<uint32>());
                        rowSample.hasQuality = true;
                        rowSample.qPoor = fields[3].Get<uint32>();
                        rowSample.qCommon = fields[4].Get<uint32>();
                        rowSample.qUncommon = fields[5].Get<uint32>();
                        rowSample.qRare = fields[6].Get<uint32>();
                        rowSample.qEpic = fields[7].Get<uint32>();
                        rowSample.qLeg = fields[8].Get<uint32>();
                        rowSample.extra = BuildAoeItemsExtraForStress(
                            rowSample.qPoor, rowSample.qCommon,
                            rowSample.qUncommon, rowSample.qRare,
                            rowSample.qEpic, rowSample.qLeg);
                        variants[3].rowSamples.push_back(rowSample);
                    } while (result->NextRow());
                }
            }
        }

        for (LeaderboardStressVariant& variant : variants)
        {
            if (variant.totalEntries == 0 && !variant.rowSamples.empty())
                variant.totalEntries = static_cast<uint32>(
                    variant.rowSamples.size());

            if (variant.scoreBase == 0 && !variant.rowSamples.empty())
                variant.scoreBase = variant.rowSamples.front().score;
        }

        return variants;
    }

    struct GroupFinderStressRowSample
    {
        uint32 id = 1000;
        uint32 leaderGuid = 50000;
        uint32 listingType = 1;
        uint32 dungeonId = 33;
        std::string dungeonName = "Dungeon";
        uint32 difficulty = 2;
        uint32 keystoneLevel = 10;
        uint32 minIlvl = 260;
        uint32 currentTank = 0;
        uint32 currentHealer = 0;
        uint32 currentDps = 1;
        uint32 needTank = 1;
        uint32 needHealer = 1;
        uint32 needDps = 2;
        std::string note = "Need clean run";
        std::string leaderName = "Leader";
    };

    struct GroupFinderStressVariant
    {
        std::string category = "dungeon";
        uint32 listingType = 1;
        uint32 groupCount = 18;
        uint32 dungeonNameLength = 12;
        uint32 noteLength = 18;
        uint32 difficulty = 2;
        uint32 keystoneLevel = 10;
        uint32 minIlvl = 260;
        uint32 currentTank = 0;
        uint32 currentHealer = 0;
        uint32 currentDps = 1;
        uint32 needTank = 1;
        uint32 needHealer = 1;
        uint32 needDps = 2;
        bool sampled = false;
        std::vector<GroupFinderStressRowSample> rowSamples;
    };

    std::string GroupFinderCategoryFromType(uint32 listingType)
    {
        switch (listingType)
        {
            case 1:
                return "dungeon";
            case 2:
                return "raid";
            case 3:
                return "pvp";
            case 4:
                return "other";
            case 5:
                return "quest";
            default:
                return "other";
        }
    }

    GroupFinderStressVariant* FindGroupFinderStressVariant(
        std::vector<GroupFinderStressVariant>& variants,
        std::string const& category)
    {
        for (GroupFinderStressVariant& variant : variants)
            if (variant.category == category)
                return &variant;

        return nullptr;
    }

    std::vector<GroupFinderStressVariant> LoadGroupFinderStressVariants()
    {
        std::vector<GroupFinderStressVariant> variants;
        variants.reserve(3);

        variants.push_back(GroupFinderStressVariant{});

        GroupFinderStressVariant raid;
        raid.category = "raid";
        raid.listingType = 2;
        raid.groupCount = 12;
        raid.dungeonNameLength = 14;
        raid.noteLength = 24;
        raid.difficulty = 3;
        raid.keystoneLevel = 0;
        raid.minIlvl = 240;
        raid.currentTank = 1;
        raid.currentHealer = 1;
        raid.currentDps = 3;
        raid.needTank = 0;
        raid.needHealer = 0;
        raid.needDps = 2;
        variants.push_back(raid);

        GroupFinderStressVariant pvp;
        pvp.category = "pvp";
        pvp.listingType = 3;
        pvp.groupCount = 10;
        pvp.dungeonNameLength = 10;
        pvp.noteLength = 20;
        pvp.difficulty = 1;
        pvp.keystoneLevel = 0;
        pvp.minIlvl = 220;
        pvp.currentDps = 2;
        pvp.needDps = 1;
        variants.push_back(pvp);

        if (CharacterTableExists("dc_group_finder_listings"))
        {
            QueryResult result = CharacterDatabase.Query(
                "SELECT listing_type, COUNT(*), "
                "COALESCE(ROUND(AVG(CHAR_LENGTH(COALESCE(dungeon_name, '')))), 0), "
                "COALESCE(ROUND(AVG(CHAR_LENGTH(COALESCE(note, '')))), 0), "
                "COALESCE(ROUND(AVG(difficulty)), 0), "
                "COALESCE(ROUND(AVG(keystone_level)), 0), "
                "COALESCE(ROUND(AVG(min_ilvl)), 0), "
                "COALESCE(ROUND(AVG(current_tank)), 0), "
                "COALESCE(ROUND(AVG(current_healer)), 0), "
                "COALESCE(ROUND(AVG(current_dps)), 0), "
                "COALESCE(ROUND(AVG(need_tank)), 0), "
                "COALESCE(ROUND(AVG(need_healer)), 0), "
                "COALESCE(ROUND(AVG(need_dps)), 0) "
                "FROM dc_group_finder_listings "
                "WHERE status = 1 "
                "GROUP BY listing_type");

            if (result)
            {
                do
                {
                    Field* fields = result->Fetch();
                    uint32 const listingType = fields[0].Get<uint32>();
                    std::string const category =
                        GroupFinderCategoryFromType(listingType);
                    GroupFinderStressVariant* variant =
                        FindGroupFinderStressVariant(variants, category);

                    if (!variant)
                    {
                        variants.push_back(GroupFinderStressVariant{});
                        variant = &variants.back();
                        variant->category = category;
                        variant->listingType = listingType;
                    }

                    variant->groupCount = fields[1].Get<uint32>();
                    variant->dungeonNameLength = fields[2].Get<uint32>();
                    variant->noteLength = fields[3].Get<uint32>();
                    variant->difficulty = fields[4].Get<uint32>();
                    variant->keystoneLevel = fields[5].Get<uint32>();
                    variant->minIlvl = fields[6].Get<uint32>();
                    variant->currentTank = fields[7].Get<uint32>();
                    variant->currentHealer = fields[8].Get<uint32>();
                    variant->currentDps = fields[9].Get<uint32>();
                    variant->needTank = fields[10].Get<uint32>();
                    variant->needHealer = fields[11].Get<uint32>();
                    variant->needDps = fields[12].Get<uint32>();
                    variant->sampled = true;
                } while (result->NextRow());
            }

            if (CharacterTableExists("characters"))
            {
                result = CharacterDatabase.Query(
                    "SELECT l.id, l.leader_guid, l.listing_type, l.dungeon_id, "
                    "COALESCE(l.dungeon_name, ''), l.difficulty, l.keystone_level, "
                    "l.min_ilvl, l.current_tank, l.current_healer, l.current_dps, "
                    "l.need_tank, l.need_healer, l.need_dps, COALESCE(l.note, ''), "
                    "COALESCE(c.name, 'Unknown') "
                    "FROM dc_group_finder_listings l "
                    "LEFT JOIN characters c ON l.leader_guid = c.guid "
                    "WHERE l.status = 1 "
                    "ORDER BY l.id DESC "
                    "LIMIT 50");

                if (result)
                {
                    do
                    {
                        Field* fields = result->Fetch();
                        uint32 const listingType = fields[2].Get<uint32>();
                        std::string const category =
                            GroupFinderCategoryFromType(listingType);
                        GroupFinderStressVariant* variant =
                            FindGroupFinderStressVariant(variants, category);

                        if (!variant)
                        {
                            variants.push_back(GroupFinderStressVariant{});
                            variant = &variants.back();
                            variant->category = category;
                            variant->listingType = listingType;
                        }

                        GroupFinderStressRowSample rowSample;
                        rowSample.id = fields[0].Get<uint32>();
                        rowSample.leaderGuid = fields[1].Get<uint32>();
                        rowSample.listingType = listingType;
                        rowSample.dungeonId = fields[3].Get<uint32>();
                        rowSample.dungeonName = fields[4].Get<std::string>();
                        rowSample.difficulty = fields[5].Get<uint32>();
                        rowSample.keystoneLevel = fields[6].Get<uint32>();
                        rowSample.minIlvl = fields[7].Get<uint32>();
                        rowSample.currentTank = fields[8].Get<uint32>();
                        rowSample.currentHealer = fields[9].Get<uint32>();
                        rowSample.currentDps = fields[10].Get<uint32>();
                        rowSample.needTank = fields[11].Get<uint32>();
                        rowSample.needHealer = fields[12].Get<uint32>();
                        rowSample.needDps = fields[13].Get<uint32>();
                        rowSample.note = fields[14].Get<std::string>();
                        rowSample.leaderName = fields[15].Get<std::string>();
                        variant->rowSamples.push_back(rowSample);
                    } while (result->NextRow());
                }
            }
        }

        if (CharacterTableExists("dc_group_finder_scheduled_events"))
        {
            QueryResult result = CharacterDatabase.Query(
                "SELECT event_type, COUNT(*), "
                "COALESCE(ROUND(AVG(CHAR_LENGTH(COALESCE(dungeon_name, '')))), 0), "
                "COALESCE(ROUND(AVG(CHAR_LENGTH(COALESCE(note, '')))), 0), "
                "COALESCE(ROUND(AVG(keystone_level)), 0), "
                "COALESCE(ROUND(AVG(max_signups)), 0), "
                "COALESCE(ROUND(AVG(current_signups)), 0) "
                "FROM dc_group_finder_scheduled_events "
                "WHERE status IN (1, 2) "
                "GROUP BY event_type");

            if (result)
            {
                do
                {
                    Field* fields = result->Fetch();
                    uint32 const listingType = fields[0].Get<uint32>();
                    std::string const category =
                        GroupFinderCategoryFromType(listingType);
                    GroupFinderStressVariant* variant =
                        FindGroupFinderStressVariant(variants, category);

                    if (!variant)
                    {
                        variants.push_back(GroupFinderStressVariant{});
                        variant = &variants.back();
                        variant->category = category;
                        variant->listingType = listingType;
                    }

                    if (!variant->sampled)
                    {
                        uint32 const maxSignups = fields[5].Get<uint32>();
                        uint32 const currentSignups = fields[6].Get<uint32>();

                        variant->groupCount = fields[1].Get<uint32>();
                        variant->dungeonNameLength = fields[2].Get<uint32>();
                        variant->noteLength = fields[3].Get<uint32>();
                        variant->keystoneLevel = fields[4].Get<uint32>();
                        variant->currentDps = currentSignups;
                        variant->needDps = maxSignups > currentSignups
                            ? (maxSignups - currentSignups) : 1;
                        variant->sampled = true;
                    }
                } while (result->NextRow());
            }

            if (CharacterTableExists("characters"))
            {
                result = CharacterDatabase.Query(
                    "SELECT e.id, e.leader_guid, e.event_type, e.dungeon_id, "
                    "COALESCE(e.dungeon_name, ''), e.keystone_level, e.max_signups, "
                    "e.current_signups, COALESCE(e.note, ''), "
                    "COALESCE(c.name, 'Unknown') "
                    "FROM dc_group_finder_scheduled_events e "
                    "LEFT JOIN characters c ON e.leader_guid = c.guid "
                    "WHERE e.status IN (1, 2) "
                    "ORDER BY e.id DESC "
                    "LIMIT 50");

                if (result)
                {
                    do
                    {
                        Field* fields = result->Fetch();
                        uint32 const listingType = fields[2].Get<uint32>();
                        std::string const category =
                            GroupFinderCategoryFromType(listingType);
                        GroupFinderStressVariant* variant =
                            FindGroupFinderStressVariant(variants, category);

                        if (!variant)
                        {
                            variants.push_back(GroupFinderStressVariant{});
                            variant = &variants.back();
                            variant->category = category;
                            variant->listingType = listingType;
                        }

                        if (variant->rowSamples.empty())
                        {
                            GroupFinderStressRowSample rowSample;
                            uint32 maxSignups = fields[6].Get<uint32>();
                            uint32 currentSignups = fields[7].Get<uint32>();

                            rowSample.id = fields[0].Get<uint32>();
                            rowSample.leaderGuid = fields[1].Get<uint32>();
                            rowSample.listingType = listingType;
                            rowSample.dungeonId = fields[3].Get<uint32>();
                            rowSample.dungeonName = fields[4].Get<std::string>();
                            rowSample.difficulty = variant->difficulty;
                            rowSample.keystoneLevel = fields[5].Get<uint32>();
                            rowSample.minIlvl = variant->minIlvl;
                            rowSample.currentDps = currentSignups;
                            rowSample.needTank = variant->needTank;
                            rowSample.needHealer = variant->needHealer;
                            rowSample.needDps = maxSignups > currentSignups
                                ? (maxSignups - currentSignups) : 0;
                            rowSample.note = fields[8].Get<std::string>();
                            rowSample.leaderName = fields[9].Get<std::string>();
                            variant->rowSamples.push_back(rowSample);
                        }
                    } while (result->NextRow());
                }
            }
        }

        for (GroupFinderStressVariant& variant : variants)
            if (variant.groupCount == 0 && !variant.rowSamples.empty())
                variant.groupCount = static_cast<uint32>(
                    variant.rowSamples.size());

        return variants;
    }

    std::vector<GroupFinderStressVariant> const& GetGroupFinderStressVariants()
    {
        static std::vector<GroupFinderStressVariant> const variants =
            LoadGroupFinderStressVariants();
        return variants;
    }

    GroupFinderStressVariant const& GetGroupFinderStressVariantForSeed(
        uint32 seed)
    {
        std::vector<GroupFinderStressVariant> const& variants =
            GetGroupFinderStressVariants();
        return variants[seed % variants.size()];
    }

    uint32 GetGroupFinderStressRowCount(
        GroupFinderStressVariant const& variant)
    {
        return std::min<uint32>(50,
            std::max<uint32>(1, variant.groupCount));
    }

    std::string BuildGroupFinderListingsPayloadForStress(
        GroupFinderStressVariant const& variant, uint32 seed);

    std::string GetCachedGroupFinderListingsPayloadForStress(
        GroupFinderStressVariant const& variant, uint32 seed)
    {
        static constexpr uint64 GROUP_FINDER_STRESS_CACHE_TTL_MS = 1000;

        struct CacheEntry
        {
            uint64 expiresAtMs = 0;
            std::string payload;
        };

        static std::mutex cacheMutex;
        static std::unordered_map<std::string, CacheEntry> payloads;

        std::string const cacheKey = variant.category + ":"
            + std::to_string(variant.listingType);
        uint64 const nowMs = static_cast<uint64>(getMSTime());

        {
            std::lock_guard<std::mutex> lock(cacheMutex);
            auto itr = payloads.find(cacheKey);
            if (itr != payloads.end() && itr->second.expiresAtMs > nowMs)
                return itr->second.payload;
        }

        CacheEntry entry;
        entry.payload = BuildGroupFinderListingsPayloadForStress(
            variant, seed);
        entry.expiresAtMs = nowMs + GROUP_FINDER_STRESS_CACHE_TTL_MS;

        std::lock_guard<std::mutex> lock(cacheMutex);
        payloads[cacheKey] = entry;
        return entry.payload;
    }

    std::string BuildGroupFinderListingsPayloadForStress(
        GroupFinderStressVariant const& variant, uint32 seed)
    {
        uint32 groupCount = GetGroupFinderStressRowCount(variant);
        uint32 dungeonNameLength = ClampStressValue(
            variant.dungeonNameLength, 12, 8, 32);
        uint32 noteLength = ClampStressValue(variant.noteLength,
            20, 10, 72);
        uint32 difficulty = ClampStressValue(variant.difficulty,
            variant.listingType == 1 ? 2 : 1, 1, 4);
        uint32 keystoneLevel = variant.listingType == 1
            ? ClampStressValue(variant.keystoneLevel, 10, 2, 30) : 0;
        uint32 minIlvl = ClampStressValue(variant.minIlvl, 240,
            180, 400);
        uint32 currentTank = std::min<uint32>(1, variant.currentTank);
        uint32 currentHealer = std::min<uint32>(1, variant.currentHealer);
        uint32 currentDps = ClampStressValue(variant.currentDps, 1, 0, 5);
        uint32 needTank = std::min<uint32>(1, variant.needTank);
        uint32 needHealer = std::min<uint32>(1, variant.needHealer);
        uint32 needDps = ClampStressValue(variant.needDps, 2, 0, 5);

        DCAddon::JsonValue groupsArray;
        groupsArray.SetArray();

        for (uint32 groupIndex = 0; groupIndex < groupCount; ++groupIndex)
        {
            GroupFinderStressRowSample const* rowSample =
                variant.rowSamples.empty()
                ? nullptr
                : &variant.rowSamples[(groupIndex + seed)
                    % variant.rowSamples.size()];
            uint32 rowListingType = rowSample
                ? rowSample->listingType
                : variant.listingType;
            std::string rowCategory = GroupFinderCategoryFromType(
                rowListingType);
            std::string dungeonName = rowSample
                ? rowSample->dungeonName
                : MakeSizedStressText("Dungeon-", dungeonNameLength,
                    seed + groupIndex);
            std::string note = rowSample
                ? rowSample->note
                : MakeSizedStressText("Need ", noteLength,
                    (seed * 13u) + groupIndex);
            uint32 rowDifficulty = rowSample
                ? rowSample->difficulty
                : difficulty;
            uint32 rowKeystoneLevel = rowSample
                ? rowSample->keystoneLevel
                : keystoneLevel;
            uint32 rowMinIlvl = rowSample
                ? rowSample->minIlvl
                : minIlvl;
            uint32 rowCurrentTank = rowSample
                ? rowSample->currentTank
                : currentTank;
            uint32 rowCurrentHealer = rowSample
                ? rowSample->currentHealer
                : currentHealer;
            uint32 rowCurrentDps = rowSample
                ? rowSample->currentDps
                : currentDps;
            uint32 rowNeedTank = rowSample
                ? rowSample->needTank
                : needTank;
            uint32 rowNeedHealer = rowSample
                ? rowSample->needHealer
                : needHealer;
            uint32 rowNeedDps = rowSample
                ? rowSample->needDps
                : needDps;

            DCAddon::JsonValue group;
            group.SetObject();
            group.Set("id", static_cast<int32>(rowSample
                ? rowSample->id
                : (1000 + groupIndex + seed)));
            group.Set("leaderGuid", static_cast<int32>(rowSample
                ? rowSample->leaderGuid
                : (50000 + groupIndex + seed)));
            group.Set("dungeonId", static_cast<int32>(rowSample
                ? rowSample->dungeonId
                : (33 + (groupIndex % 12))));
            group.Set("dungeon", dungeonName);
            group.Set("dungeonName", dungeonName);
            group.Set("raid", dungeonName);
            group.Set("difficulty", static_cast<int32>(rowDifficulty));
            group.Set("difficultyName",
                GetGroupFinderDifficultyNameForStress(rowListingType,
                    rowDifficulty));
            group.Set("level", static_cast<int32>(rowKeystoneLevel));
            group.Set("keystoneLevel", static_cast<int32>(rowKeystoneLevel));
            group.Set("minIlvl", static_cast<int32>(rowMinIlvl));
            group.Set("tank", rowCurrentTank > 0);
            group.Set("healer", rowCurrentHealer > 0);
            group.Set("dps", static_cast<int32>(rowCurrentDps));
            group.Set("needTank", static_cast<int32>(rowNeedTank));
            group.Set("needHealer", static_cast<int32>(rowNeedHealer));
            group.Set("needDps", static_cast<int32>(rowNeedDps));
            group.Set("spots", static_cast<int32>(rowNeedTank
                + rowNeedHealer + rowNeedDps));
            group.Set("note", note);
            group.Set("progress", note);
            group.Set("type", static_cast<int32>(rowListingType));
            group.Set("category", rowCategory);
            group.Set("leader", rowSample
                ? rowSample->leaderName
                : MakeSizedStressText("Leader-", 12, groupIndex + seed));
            groupsArray.Push(group);
        }

        std::string groupsEncoded = groupsArray.Encode();
        DCAddon::JsonMessage response(DCAddon::Module::GROUP_FINDER,
            DCAddon::Opcode::GroupFinder::SMSG_SEARCH_RESULTS);
        response.Set("groups", groupsEncoded);
        response.Set("count", static_cast<int32>(groupCount));
        response.Set("category", variant.category);
        return response.Build();
    }

    std::string BuildGroupFinderEventsPayloadForStress(
        GroupFinderStressVariant const& variant, uint32 seed)
    {
        uint32 eventCount = GetGroupFinderStressRowCount(variant);
        uint32 dungeonNameLength = ClampStressValue(
            variant.dungeonNameLength, 12, 8, 32);
        uint32 noteLength = ClampStressValue(variant.noteLength,
            20, 10, 72);
        uint32 keystoneLevel = variant.listingType == 1
            ? ClampStressValue(variant.keystoneLevel, 10, 2, 30) : 0;
        uint32 baseTimestamp = static_cast<uint32>(std::time(nullptr));

        DCAddon::JsonValue eventsArray;
        eventsArray.SetArray();

        for (uint32 eventIndex = 0; eventIndex < eventCount; ++eventIndex)
        {
            GroupFinderStressRowSample const* rowSample =
                variant.rowSamples.empty()
                ? nullptr
                : &variant.rowSamples[(eventIndex + seed)
                    % variant.rowSamples.size()];
            std::string dungeonName = rowSample
                ? rowSample->dungeonName
                : MakeSizedStressText("Event-", dungeonNameLength,
                    seed + eventIndex);
            std::string note = rowSample
                ? rowSample->note
                : MakeSizedStressText("Schedule ", noteLength,
                    (seed * 11u) + eventIndex);
            uint32 rowKeystoneLevel = rowSample
                ? rowSample->keystoneLevel
                : keystoneLevel;
            uint32 rowCurrentSignups = rowSample
                ? std::min<uint32>(50, rowSample->currentDps)
                : ClampStressValue(variant.currentDps, 1, 0, 40);
            uint32 rowMaxSignups = std::max<uint32>(rowCurrentSignups + 1,
                rowCurrentSignups + (rowSample ? rowSample->needDps : 2u));

            DCAddon::JsonValue event;
            event.SetObject();
            event.Set("eventId", static_cast<int32>(rowSample
                ? rowSample->id
                : (2000 + eventIndex + seed)));
            event.Set("leaderGuid", static_cast<int32>(rowSample
                ? rowSample->leaderGuid
                : (60000 + eventIndex + seed)));
            event.Set("eventType", static_cast<int32>(rowSample
                ? rowSample->listingType
                : variant.listingType));
            event.Set("dungeonId", static_cast<int32>(rowSample
                ? rowSample->dungeonId
                : (33 + (eventIndex % 12))));
            event.Set("dungeonName", dungeonName);
            event.Set("keyLevel", static_cast<int32>(rowKeystoneLevel));
            event.Set("scheduledTime", static_cast<int32>(baseTimestamp
                + ((eventIndex + 1) * 900u)));
            event.Set("maxSignups", static_cast<int32>(rowMaxSignups));
            event.Set("currentSignups", static_cast<int32>(rowCurrentSignups));
            event.Set("note", note);
            event.Set("status", 1);
            event.Set("leaderName", rowSample
                ? rowSample->leaderName
                : MakeSizedStressText("Leader-", 12,
                    eventIndex + seed));
            eventsArray.Push(event);
        }

        std::string eventsEncoded = eventsArray.Encode();
        DCAddon::JsonMessage response(DCAddon::Module::GROUP_FINDER,
            DCAddon::Opcode::GroupFinder::SMSG_SCHEDULED_EVENTS);
        response.Set("events", eventsEncoded);
        response.Set("count", static_cast<int32>(eventCount));
        return response.Build();
    }

    std::string BuildGroupFinderSignupsPayloadForStress(
        GroupFinderStressVariant const& variant, uint32 seed)
    {
        uint32 signupCount = std::min<uint32>(12,
            GetGroupFinderStressRowCount(variant));
        uint32 dungeonNameLength = ClampStressValue(
            variant.dungeonNameLength, 12, 8, 32);
        uint32 keystoneLevel = variant.listingType == 1
            ? ClampStressValue(variant.keystoneLevel, 10, 2, 30) : 0;
        uint32 baseTimestamp = static_cast<uint32>(std::time(nullptr));

        DCAddon::JsonValue signupsArray;
        signupsArray.SetArray();

        for (uint32 signupIndex = 0; signupIndex < signupCount; ++signupIndex)
        {
            GroupFinderStressRowSample const* rowSample =
                variant.rowSamples.empty()
                ? nullptr
                : &variant.rowSamples[(signupIndex + seed)
                    % variant.rowSamples.size()];
            std::string dungeonName = rowSample
                ? rowSample->dungeonName
                : MakeSizedStressText("Signup-", dungeonNameLength,
                    seed + signupIndex);
            uint32 rowKeystoneLevel = rowSample
                ? rowSample->keystoneLevel
                : keystoneLevel;

            DCAddon::JsonValue signup;
            signup.SetObject();
            signup.Set("signupId", static_cast<int32>(3000 + signupIndex
                + seed));
            signup.Set("eventId", static_cast<int32>(rowSample
                ? rowSample->id
                : (2000 + signupIndex + seed)));
            signup.Set("role", static_cast<int32>((signupIndex % 3) + 1));
            signup.Set("status", 1);
            signup.Set("dungeonName", dungeonName);
            signup.Set("keyLevel", static_cast<int32>(rowKeystoneLevel));
            signup.Set("scheduledTime", static_cast<int32>(baseTimestamp
                + ((signupIndex + 1) * 900u)));
            signup.Set("leaderName", rowSample
                ? rowSample->leaderName
                : MakeSizedStressText("Leader-", 12,
                    signupIndex + seed));
            signupsArray.Push(signup);
        }

        std::string signupsEncoded = signupsArray.Encode();
        DCAddon::JsonMessage response(DCAddon::Module::GROUP_FINDER,
            DCAddon::Opcode::GroupFinder::SMSG_MY_SIGNUPS);
        response.Set("signups", signupsEncoded);
        response.Set("count", static_cast<int32>(signupCount));
        return response.Build();
    }

    static std::vector<uint32> LoadHLBGParticipantSampleGuids(uint32 limit)
    {
        std::vector<uint32> guids;

        QueryResult result;
        if (CharacterTableExists("dc_hlbg_match_participants"))
        {
            result = CharacterDatabase.Query(
                "SELECT guid FROM dc_hlbg_match_participants "
                "GROUP BY guid ORDER BY MAX(match_date) DESC LIMIT {}",
                limit);
        }
        else if (CharacterTableExists("v_hlbg_player_alltime_stats"))
        {
            result = CharacterDatabase.Query(
                "SELECT guid FROM v_hlbg_player_alltime_stats LIMIT {}",
                limit);
        }

        if (!result)
            return guids;

        do
            guids.push_back((*result)[0].Get<uint32>());
        while (result->NextRow());

        return guids;
    }

    static std::vector<uint32> const& GetHLBGParticipantSampleGuids()
    {
        static std::vector<uint32> const sampleGuids =
            LoadHLBGParticipantSampleGuids(64);
        return sampleGuids;
    }

    std::string BuildHLBGSeasonalPayloadForStress(
        AddonStressAvailability const& availability)
    {
        QueryResult result;

        if (availability.hasHLBGSeasonal)
        {
            result = CharacterDatabase.Query(
                "SELECT guid, player_name, current_rating, wins "
                "FROM v_hlbg_player_seasonal_stats "
                "WHERE season_id = {} ORDER BY current_rating DESC LIMIT 25",
                1u);
        }
        else if (availability.HasHLBGUnifiedTables())
        {
            result = CharacterDatabase.Query(
                "SELECT p.guid, MAX(p.player_name) AS player_name, "
                "GREATEST(0, COALESCE(SUM(p.rating_change), 0) + 1200) AS current_rating, "
                "SUM(CASE WHEN wh.winner_tid = p.team THEN 1 ELSE 0 END) AS wins "
                "FROM dc_hlbg_match_participants p "
                "LEFT JOIN dc_hlbg_winner_history wh ON p.match_id = wh.id "
                "WHERE p.season_id = {} "
                "GROUP BY p.guid "
                "ORDER BY current_rating DESC LIMIT 25",
                1u);
        }

        if (!result)
            return "{\"leaderboardType\":1,\"season\":1,\"entries\":[]}";

        std::string entriesJson = "[";
        uint32 rank = 1;
        do
        {
            if (rank > 1)
                entriesJson += ",";

            Field* fields = result->Fetch();
            entriesJson += Acore::StringFormat(
                "{\"rank\":%u,\"guid\":%u,\"name\":\"%s\",\"score\":%u,\"extra\":%u}",
                rank,
                fields[0].Get<uint32>(),
                fields[1].Get<std::string>().c_str(),
                fields[2].Get<uint32>(),
                fields[3].Get<uint32>());
            ++rank;
        } while (result->NextRow());
        entriesJson += "]";

        return Acore::StringFormat(
            "{\"leaderboardType\":1,\"season\":1,\"entries\":%s}",
            entriesJson.c_str());
    }

    std::string GetCachedHLBGSeasonalPayloadForStress(
        AddonStressAvailability const& availability)
    {
        uint64 nowMs = GetStressNowMs();
        {
            std::lock_guard<std::mutex> lock(sHLBGStressCacheLock);
            if (sCachedHLBGSeasonalPayload.expiresAtMs > nowMs)
                return sCachedHLBGSeasonalPayload.payload;
        }

        CachedHLBGStressPayload payload;
        payload.payload = BuildHLBGSeasonalPayloadForStress(availability);
        payload.expiresAtMs = nowMs + HLBG_STRESS_CACHE_TTL_MS;

        std::lock_guard<std::mutex> lock(sHLBGStressCacheLock);
        sCachedHLBGSeasonalPayload = payload;
        return payload.payload;
    }

    std::string BuildHLBGAllTimePayloadForStress(
        AddonStressAvailability const& availability, uint32 guid)
    {
        QueryResult result;

        if (availability.HasHLBGUnifiedTables())
        {
            result = CharacterDatabase.Query(
                "SELECT COUNT(*), "
                "COALESCE(SUM(CASE WHEN wh.winner_tid = p.team THEN 1 ELSE 0 END), 0), "
                "COALESCE(SUM(CASE WHEN wh.winner_tid <> p.team AND wh.winner_tid <> 0 THEN 1 ELSE 0 END), 0), "
                "COALESCE(SUM(p.kills), 0), "
                "COALESCE(SUM(p.deaths), 0), "
                "CASE WHEN COALESCE(SUM(p.deaths), 0) = 0 THEN 0 ELSE ROUND(COALESCE(SUM(p.kills), 0) / SUM(p.deaths), 2) END, "
                "CASE WHEN COUNT(*) = 0 THEN 0 ELSE ROUND(COALESCE(SUM(p.kills), 0) / COUNT(*), 2) END, "
                "CASE WHEN COUNT(*) = 0 THEN 0 ELSE ROUND(COALESCE(SUM(p.damage_done), 0) / COUNT(*), 0) END "
                "FROM dc_hlbg_match_participants p "
                "LEFT JOIN dc_hlbg_winner_history wh ON p.match_id = wh.id "
                "WHERE p.guid = {}",
                guid);
        }
        else if (availability.hasHLBGAllTime
            && availability.hlbgAllTimeGamesColumn
            && availability.hlbgAllTimeWinsColumn
            && availability.hlbgAllTimeLossesColumn
            && availability.hlbgAllTimeKillsColumn
            && availability.hlbgAllTimeDeathsColumn
            && availability.hlbgAllTimeKdRatioColumn
            && availability.hlbgAllTimeAvgKillsColumn
            && availability.hlbgAllTimeAvgDamageColumn)
        {
            std::ostringstream sql;
            sql << "SELECT IFNULL(" << availability.hlbgAllTimeGamesColumn
                << ", 0), IFNULL(" << availability.hlbgAllTimeWinsColumn
                << ", 0), IFNULL(" << availability.hlbgAllTimeLossesColumn
                << ", 0), IFNULL(" << availability.hlbgAllTimeKillsColumn
                << ", 0), IFNULL(" << availability.hlbgAllTimeDeathsColumn
                << ", 0), IFNULL(" << availability.hlbgAllTimeKdRatioColumn
                << ", 0), IFNULL(" << availability.hlbgAllTimeAvgKillsColumn
                << ", 0), IFNULL(" << availability.hlbgAllTimeAvgDamageColumn
                << ", 0) FROM v_hlbg_player_alltime_stats WHERE guid = "
                << guid;
            result = CharacterDatabase.Query(sql.str().c_str());
        }

        if (!result)
        {
            return "{\"totalMatches\":0,\"lifetimeWins\":0,\"lifetimeLosses\":0,\"lifetimeKills\":0,\"lifetimeDeaths\":0,\"kdRatio\":0,\"avgKills\":0,\"avgDamage\":0}";
        }

        Field* fields = result->Fetch();
        return Acore::StringFormat(
            "{\"totalMatches\":%u,\"lifetimeWins\":%u,\"lifetimeLosses\":%u,\"lifetimeKills\":%u,\"lifetimeDeaths\":%u,\"kdRatio\":%.2f,\"avgKills\":%.2f,\"avgDamage\":%.0f}",
            fields[0].Get<uint32>(),
            fields[1].Get<uint32>(),
            fields[2].Get<uint32>(),
            fields[3].Get<uint32>(),
            fields[4].Get<uint32>(),
            fields[5].Get<float>(),
            fields[6].Get<float>(),
            fields[7].Get<float>());
    }

    std::string GetCachedHLBGAllTimePayloadForStress(
        AddonStressAvailability const& availability, uint32 guid)
    {
        uint64 nowMs = GetStressNowMs();
        {
            std::lock_guard<std::mutex> lock(sHLBGStressCacheLock);
            auto itr = sCachedHLBGAllTimePayloads.find(guid);
            if (itr != sCachedHLBGAllTimePayloads.end()
                && itr->second.expiresAtMs > nowMs)
            {
                return itr->second.payload;
            }
        }

        CachedHLBGStressPayload payload;
        payload.payload = BuildHLBGAllTimePayloadForStress(availability,
            guid);
        payload.expiresAtMs = nowMs + HLBG_STRESS_CACHE_TTL_MS;

        std::lock_guard<std::mutex> lock(sHLBGStressCacheLock);
        sCachedHLBGAllTimePayloads[guid] = payload;
        return payload.payload;
    }

    static bool ExecuteAddonSurfaceQuery(AddonStressAvailability const& availability,
        AddonSurface surface, uint32 fakeGuid, uint32 fakeAccount, uint32 seed)
    {
        switch (surface)
        {
            case AddonSurface::Protocol:
            {
                if (availability.hasProtocolCaps
                    && ((seed % 3) == 0
                        || (!availability.hasProtocolErrors
                            && !availability.hasProtocolLog)))
                {
                    return ExecuteAddonSurfaceQuery(availability,
                        AddonSurface::ProtocolClientCaps, fakeGuid,
                        fakeAccount, seed);
                }

                if (availability.hasProtocolErrors
                    && ((seed % 3) == 1 || !availability.hasProtocolLog))
                {
                    return ExecuteAddonSurfaceQuery(availability,
                        AddonSurface::ProtocolErrors, fakeGuid,
                        fakeAccount, seed);
                }

                if (availability.hasProtocolLog)
                {
                    return ExecuteAddonSurfaceQuery(availability,
                        AddonSurface::ProtocolLog, fakeGuid,
                        fakeAccount, seed);
                }

                return false;
            }

            case AddonSurface::ProtocolClientCaps:
            {
                if (!availability.hasProtocolCaps)
                    return false;

                CharacterDatabase.Query(
                    "SELECT account_id, version_string, capabilities, negotiated_caps "
                    "FROM dc_addon_client_caps ORDER BY last_seen DESC LIMIT 50");
                return true;
            }

            case AddonSurface::ProtocolStats:
            {
                if (!availability.hasProtocolStats)
                    return false;

                CharacterDatabase.Query(
                    "SELECT guid, module, transport, total_requests, total_responses, avg_response_time_ms, max_response_time_ms "
                    "FROM dc_addon_protocol_stats ORDER BY last_request DESC LIMIT 50");
                return true;
            }

            case AddonSurface::ProtocolErrors:
            {
                if (!availability.hasProtocolErrors)
                    return false;

                CharacterDatabase.Query(
                    "SELECT guid, module, opcode, event_type "
                    "FROM dc_addon_protocol_errors ORDER BY id DESC LIMIT 25");
                return true;
            }

            case AddonSurface::ProtocolLog:
            {
                if (!availability.hasProtocolLog)
                    return false;

                CharacterDatabase.Query(
                    "SELECT guid, module, opcode, status "
                    "FROM dc_addon_protocol_log ORDER BY id DESC LIMIT 25");
                return true;
            }

            case AddonSurface::QoS:
            {
                if (!availability.hasQosSettings)
                    return false;

                CharacterDatabase.Query(
                    "SELECT setting_key, setting_value FROM dc_player_qos_settings WHERE guid = {}",
                    fakeGuid);
                return true;
            }

            case AddonSurface::World:
            {
                if (!availability.hasHotspots)
                    return false;

                auto buildWorldHotspotArrayForStress = []() -> DCAddon::JsonValue
                {
                    DCAddon::JsonValue arr;
                    arr.SetArray();

                    QueryResult result = WorldDatabase.Query(
                        "SELECT id, map_id, zone_id, x, y, z, (expire_time - UNIX_TIMESTAMP()) as dur "
                        "FROM dc_hotspots_active WHERE expire_time > UNIX_TIMESTAMP()");

                    uint32 xpBonus = GetHotspotXPBonusPercentage();
                    if (!result)
                        return arr;

                    do
                    {
                        uint32 id = (*result)[0].Get<uint32>();
                        uint32 mapId = (*result)[1].Get<uint32>();
                        uint32 zoneId = (*result)[2].Get<uint32>();
                        float x = (*result)[3].Get<float>();
                        float y = (*result)[4].Get<float>();
                        float z = (*result)[5].Get<float>();
                        int64 dur = (*result)[6].Get<int64>();

                        if (dur <= 0)
                            continue;

                        std::string zoneName = "Unknown Zone";
                        if (AreaTableEntry const* area = sAreaTableStore.LookupEntry(zoneId))
                        {
                            if (area->area_name[0] && area->area_name[0][0])
                                zoneName = area->area_name[0];
                        }

                        DCAddon::JsonValue hotspot;
                        hotspot.SetObject();
                        hotspot.Set("id", static_cast<int32>(id));
                        hotspot.Set("mapId", static_cast<int32>(mapId));
                        hotspot.Set("zoneId", static_cast<int32>(zoneId));
                        hotspot.Set("zoneName", zoneName);
                        hotspot.Set("x", x);
                        hotspot.Set("y", y);
                        hotspot.Set("z", z);
                        hotspot.Set("timeRemaining", static_cast<int32>(dur));
                        hotspot.Set("bonusPercent", static_cast<int32>(xpBonus));
                        hotspot.Set("name", "Hotspot");
                        arr.Push(hotspot);
                    } while (result->NextRow());

                    return arr;
                };

                auto getCachedWorldPayloadForStress = [&]() -> CachedWorldStressPayload
                {
                    uint64 const nowMs = static_cast<uint64>(getMSTime());

                    {
                        std::lock_guard<std::mutex> lock(sWorldStressCacheLock);
                        if (sCachedWorldStressPayload.expiresAtMs > nowMs)
                            return sCachedWorldStressPayload;
                    }

                    CachedWorldStressPayload payload;
                    DCAddon::JsonValue hotspots = buildWorldHotspotArrayForStress();
                    DCAddon::JsonValue bosses = sWorldBossMgr
                        ? sWorldBossMgr->BuildBossesContentArray()
                        : DCAddon::JsonValue();
                    if (!bosses.IsArray())
                        bosses.SetArray();
                    DCAddon::JsonValue events;
                    events.SetArray();
                    DCAddon::JsonValue deaths = DCAddon::DeathMarkers::BuildDeathMarkersArray();

                    DCAddon::JsonMessage response(DCAddon::Module::WORLD,
                        DCAddon::Opcode::World::SMSG_CONTENT);
                    response.Set("schemaVersion", 1);
                    response.Set("serverTime", static_cast<int32>(time(nullptr)));
                    response.Set("hotspots", hotspots);
                    response.Set("bosses", bosses);
                    response.Set("events", events);
                    response.Set("deaths", deaths);
                    payload.snapshotPayload = response.Build();

                    if (bosses.IsArray())
                    {
                        for (auto const& boss : bosses.AsArray())
                        {
                            DCAddon::JsonValue one;
                            one.SetArray();
                            one.Push(boss);

                            DCAddon::JsonMessage update(DCAddon::Module::WORLD,
                                DCAddon::Opcode::World::SMSG_UPDATE);
                            update.Set("bosses", one);
                            payload.bossUpdatePayloads.push_back(update.Build());
                        }
                    }

                    payload.expiresAtMs = nowMs + WORLD_STRESS_CACHE_TTL_MS;

                    std::lock_guard<std::mutex> lock(sWorldStressCacheLock);
                    sCachedWorldStressPayload = payload;
                    return payload;
                };

                CachedWorldStressPayload payload = getCachedWorldPayloadForStress();
                bool executed = !payload.snapshotPayload.empty();
                for (std::string const& bossUpdate : payload.bossUpdatePayloads)
                    executed = !bossUpdate.empty() || executed;
                return executed;
            }

            case AddonSurface::Welcome:
            {
                if (availability.hasWelcomeFaq
                    && ((seed % 3) == 0
                        || (!availability.hasWelcomeWhatsNew
                            && !(availability.hasMplusScores
                                || availability.hasMplusRating
                                || availability.hasPrestige
                                || availability.hasMplusRuns))))
                {
                    return ExecuteAddonSurfaceQuery(availability,
                        AddonSurface::WelcomeFaq, fakeGuid,
                        fakeAccount, seed);
                }

                if (availability.hasWelcomeWhatsNew
                    && ((seed % 3) == 1
                        || !(availability.hasMplusScores || availability.hasMplusRating
                            || availability.hasPrestige || availability.hasMplusRuns)))
                {
                    return ExecuteAddonSurfaceQuery(availability,
                        AddonSurface::WelcomeWhatsNew, fakeGuid,
                        fakeAccount, seed);
                }

                return ExecuteAddonSurfaceQuery(availability,
                    AddonSurface::WelcomeProgress, fakeGuid,
                    fakeAccount, seed);
            }

            case AddonSurface::WelcomeFaq:
            {
                if (!availability.hasWelcomeFaq)
                    return false;

                GetCachedWelcomeFaqSurfacePayload();
                return true;
            }

            case AddonSurface::WelcomeWhatsNew:
            {
                if (!availability.hasWelcomeWhatsNew)
                    return false;

                GetCachedWelcomeWhatsNewSurfacePayload();
                return true;
            }

            case AddonSurface::WelcomeProgress:
            {
                bool executed = false;
                constexpr uint32 fakeSeasonId = 1u;
                constexpr uint32 fakeWeekStart = 1700000000u;
                constexpr uint32 fakeWeekEnd = fakeWeekStart + (7u * 24u * 60u * 60u);
                bool const useWeeklyVaultSummary = availability.hasWeeklyVault
                    && sConfigMgr->GetOption<bool>("MythicPlus.Vault.Enabled", false);
                std::string const& query = BuildWelcomeProgressSnapshotStressQuery(
                    useWeeklyVaultSummary, availability.hasSeasonalStats);

                if (availability.hasMplusRating && availability.hasPrestige
                    && (availability.hasSeasonalStats || availability.hasMplusScores)
                    && (availability.hasMplusRuns || useWeeklyVaultSummary)
                    && availability.hasCharacters)
                {
                    if (useWeeklyVaultSummary)
                    {
                        CharacterDatabase.Query(
                            query,
                            fakeGuid,
                            fakeSeasonId,
                            fakeGuid,
                            fakeGuid, fakeSeasonId,
                            fakeGuid, fakeSeasonId, fakeWeekStart,
                            fakeAccount, 255u);
                    }
                    else
                    {
                        CharacterDatabase.Query(
                            query,
                            fakeGuid,
                            fakeSeasonId,
                            fakeGuid,
                            fakeGuid, fakeSeasonId,
                            fakeGuid, fakeSeasonId, fakeWeekStart, fakeWeekEnd,
                            fakeAccount, 255u);
                    }
                    return true;
                }

                if (availability.hasMplusRating)
                {
                    CharacterDatabase.Query(
                        "SELECT rating FROM dc_mplus_player_ratings "
                        "WHERE player_guid = {} AND season_id = {}",
                        fakeGuid, fakeSeasonId);
                    executed = true;
                }

                if (availability.hasPrestige)
                {
                    CharacterDatabase.Query(
                        "SELECT prestige_level FROM dc_character_prestige WHERE guid = {}",
                        fakeGuid);
                    executed = true;
                }

                if (availability.hasSeasonalStats)
                {
                    CharacterDatabase.Query(
                        "SELECT COALESCE(weekly_tokens_earned, 0) FROM dc_player_seasonal_stats "
                        "WHERE player_guid = {} AND season_id = {}",
                        fakeGuid, fakeSeasonId);
                    executed = true;
                }
                else if (availability.hasMplusScores)
                {
                    CharacterDatabase.Query(
                        "SELECT COALESCE(SUM(best_score), 0) FROM dc_mplus_scores "
                        "WHERE character_guid = {} AND season_id = {}",
                        fakeGuid, fakeSeasonId);
                    executed = true;
                }

                if (useWeeklyVaultSummary)
                {
                    CharacterDatabase.Query(
                        "SELECT runs_completed FROM dc_weekly_vault "
                        "WHERE character_guid = {} AND season_id = {} AND week_start = {}",
                        fakeGuid, fakeSeasonId, fakeWeekStart);
                    executed = true;
                }
                else if (availability.hasMplusRuns)
                {
                    CharacterDatabase.Query(
                        "SELECT COUNT(*) FROM dc_mplus_runs "
                        "WHERE character_guid = {} AND season_id = {} AND success = 1 "
                        "AND completed_at >= FROM_UNIXTIME({}) "
                        "AND completed_at < FROM_UNIXTIME({})",
                        fakeGuid, fakeSeasonId, fakeWeekStart, fakeWeekEnd);
                    executed = true;
                }

                if (availability.hasCharacters)
                {
                    CharacterDatabase.Query(
                        "SELECT COUNT(*) FROM characters WHERE account = {} AND level >= {}",
                        fakeAccount, 255u);
                    executed = true;
                }

                return executed;
            }

            case AddonSurface::WelcomeProgressRating:
            {
                if (!availability.hasMplusRating)
                    return false;

                constexpr uint32 fakeSeasonId = 1u;
                CharacterDatabase.Query(
                    "SELECT rating FROM dc_mplus_player_ratings "
                    "WHERE player_guid = {} AND season_id = {}",
                    fakeGuid, fakeSeasonId);
                return true;
            }

            case AddonSurface::WelcomeProgressPrestige:
            {
                if (!availability.hasPrestige)
                    return false;

                CharacterDatabase.Query(
                    "SELECT prestige_level FROM dc_character_prestige WHERE guid = {}",
                    fakeGuid);
                return true;
            }

            case AddonSurface::WelcomeProgressSeasonPoints:
            {
                constexpr uint32 fakeSeasonId = 1u;

                if (availability.hasSeasonalStats)
                {
                    CharacterDatabase.Query(
                        "SELECT COALESCE(weekly_tokens_earned, 0) FROM dc_player_seasonal_stats "
                        "WHERE player_guid = {} AND season_id = {}",
                        fakeGuid, fakeSeasonId);
                    return true;
                }

                if (!availability.hasMplusScores)
                    return false;

                CharacterDatabase.Query(
                    "SELECT COALESCE(SUM(best_score), 0) FROM dc_mplus_scores "
                    "WHERE character_guid = {} AND season_id = {}",
                    fakeGuid, fakeSeasonId);
                return true;
            }

            case AddonSurface::WelcomeProgressWeeklyRuns:
            {
                bool const useWeeklyVaultSummary = availability.hasWeeklyVault
                    && sConfigMgr->GetOption<bool>("MythicPlus.Vault.Enabled", false);

                if (!useWeeklyVaultSummary && !availability.hasMplusRuns)
                    return false;

                constexpr uint32 fakeSeasonId = 1u;
                constexpr uint32 fakeWeekStart = 1700000000u;
                constexpr uint32 fakeWeekEnd = fakeWeekStart + (7u * 24u * 60u * 60u);

                if (useWeeklyVaultSummary)
                {
                    CharacterDatabase.Query(
                        "SELECT runs_completed FROM dc_weekly_vault "
                        "WHERE character_guid = {} AND season_id = {} AND week_start = {}",
                        fakeGuid, fakeSeasonId, fakeWeekStart);
                }
                else
                {
                    CharacterDatabase.Query(
                        "SELECT COUNT(*) FROM dc_mplus_runs "
                        "WHERE character_guid = {} AND season_id = {} AND success = 1 "
                        "AND completed_at >= FROM_UNIXTIME({}) "
                        "AND completed_at < FROM_UNIXTIME({})",
                        fakeGuid, fakeSeasonId, fakeWeekStart, fakeWeekEnd);
                }
                return true;
            }

            case AddonSurface::WelcomeProgressAltBonus:
            {
                if (!availability.hasCharacters)
                    return false;

                CharacterDatabase.Query(
                    "SELECT COUNT(*) FROM characters WHERE account = {} AND level >= {}",
                    fakeAccount, 255u);
                return true;
            }

            case AddonSurface::GroupFinder:
            {
                if (availability.hasGroupFinderListings
                    && ((seed % 3) == 0 || (!availability.hasGroupFinderEvents && !availability.hasGroupFinderSignups)))
                {
                    return ExecuteAddonSurfaceQuery(availability,
                        AddonSurface::GroupFinderListings, fakeGuid,
                        fakeAccount, seed);
                }

                if (availability.hasGroupFinderEvents
                    && ((seed % 3) == 1 || !availability.hasGroupFinderSignups))
                {
                    return ExecuteAddonSurfaceQuery(availability,
                        AddonSurface::GroupFinderEvents, fakeGuid,
                        fakeAccount, seed);
                }

                if (availability.hasGroupFinderSignups && availability.hasGroupFinderEvents)
                {
                    return ExecuteAddonSurfaceQuery(availability,
                        AddonSurface::GroupFinderSignups, fakeGuid,
                        fakeAccount, seed);
                }

                return false;
            }

            case AddonSurface::GroupFinderListings:
            {
                if (!availability.hasGroupFinderListings)
                    return false;

                std::string payload = GetCachedGroupFinderListingsPayloadForStress(
                    GetGroupFinderStressVariantForSeed(seed), seed);
                return !payload.empty();
            }

            case AddonSurface::GroupFinderEvents:
            {
                if (!availability.hasGroupFinderEvents)
                    return false;

                std::string payload = BuildGroupFinderEventsPayloadForStress(
                    GetGroupFinderStressVariantForSeed(seed), seed);
                return !payload.empty();
            }

            case AddonSurface::GroupFinderSignups:
            {
                if (!availability.hasGroupFinderEvents || !availability.hasGroupFinderSignups)
                    return false;

                std::string payload = BuildGroupFinderSignupsPayloadForStress(
                    GetGroupFinderStressVariantForSeed(seed), seed);
                return !payload.empty();
            }

            case AddonSurface::MythicPlus:
            {
                if (availability.hasMplusKeys
                    && ((seed % 2) == 0 || !availability.hasMplusBestRuns))
                {
                    return ExecuteAddonSurfaceQuery(availability,
                        AddonSurface::MythicPlusKeyInfo, fakeGuid,
                        fakeAccount, seed);
                }

                if (availability.hasMplusBestRuns)
                {
                    return ExecuteAddonSurfaceQuery(availability,
                        AddonSurface::MythicPlusBestRuns, fakeGuid,
                        fakeAccount, seed);
                }

                return false;
            }

            case AddonSurface::MythicPlusKeyInfo:
            {
                if (!availability.hasMplusKeys)
                    return false;

                if (availability.hasMplusDungeons)
                {
                    CharacterDatabase.Query(
                        "SELECT k.map_id, k.level, COALESCE(d.dungeon_name, '') "
                        "FROM dc_mplus_keystones k "
                        "LEFT JOIN dc_mplus_dungeons d ON k.map_id = d.map_id "
                        "WHERE k.character_guid = {}",
                        fakeGuid);
                }
                else
                {
                    CharacterDatabase.Query(
                        "SELECT map_id, level FROM dc_mplus_keystones WHERE character_guid = {}",
                        fakeGuid);
                }

                return true;
            }

            case AddonSurface::MythicPlusBestRuns:
            {
                if (!availability.hasMplusBestRuns)
                    return false;

                QueryResult result = CharacterDatabase.Query(
                    "SELECT dungeon_id, level, completion_time, deaths, season "
                    "FROM dc_mplus_best_runs WHERE player_guid = {} ORDER BY level DESC LIMIT 10",
                    fakeGuid);

                std::string runList;
                if (result)
                {
                    bool first = true;
                    do
                    {
                        if (!first)
                            runList += ";";
                        first = false;

                        runList += std::to_string((*result)[0].Get<uint32>()) + ":"
                            + std::to_string((*result)[1].Get<uint32>()) + ":"
                            + std::to_string((*result)[2].Get<uint32>()) + ":"
                            + std::to_string((*result)[3].Get<uint32>()) + ":"
                            + std::to_string((*result)[4].Get<uint32>());
                    } while (result->NextRow());
                }

                DCAddon::Message response(DCAddon::Module::MYTHIC_PLUS,
                    DCAddon::Opcode::MPlus::SMSG_BEST_RUNS);
                std::string payload = response.Add(runList).Build();
                return !payload.empty();
            }

            case AddonSurface::Wardrobe:
            {
                if (availability.hasWardrobeOutfits
                    && ((seed % 2) == 0 || !availability.transmogCollectionTable))
                {
                    return ExecuteAddonSurfaceQuery(availability,
                        AddonSurface::WardrobeCommunity, fakeGuid,
                        fakeAccount, seed);
                }

                if (availability.transmogCollectionTable)
                {
                    return ExecuteAddonSurfaceQuery(availability,
                        AddonSurface::WardrobeCollected, fakeGuid,
                        fakeAccount, seed);
                }

                return false;
            }

            case AddonSurface::WardrobeCommunity:
            {
                if (!availability.hasWardrobeOutfits)
                    return false;

                CharacterDatabase.Query(
                    "SELECT o.id, o.name, o.author_name, o.items_string, o.upvotes, o.downvotes, o.downloads, o.views, o.tags "
                    "FROM dc_collection_community_outfits o "
                    "ORDER BY (o.upvotes - o.downvotes) DESC, o.downloads DESC LIMIT 25");
                return true;
            }

            case AddonSurface::WardrobeCollected:
            {
                if (!availability.transmogCollectionTable)
                    return false;

                WardrobeCollectedStressSample const& sample =
                    GetWardrobeCollectedStressSample(availability);

                DCAddon::JsonMessage response(DCAddon::Module::COLLECTION,
                    DCAddon::Opcode::Collection::SMSG_COLLECTED_APPEARANCES);
                response.SetPreEncodedJson(sample.payload
                    ? *sample.payload
                    : std::string("{\"count\":0,\"appearances\":[]}"));
                std::string payload = response.Build();
                if (payload.empty())
                    return false;
                return true;
            }

            case AddonSurface::HLBG:
            {
                if (availability.hasHLBGSeasonal
                    && ((seed % 2) == 0 || !availability.hasHLBGAllTime))
                {
                    return ExecuteAddonSurfaceQuery(availability,
                        AddonSurface::HLBGSeasonal, fakeGuid, fakeAccount,
                        seed);
                }

                if (availability.hasHLBGAllTime)
                {
                    return ExecuteAddonSurfaceQuery(availability,
                        AddonSurface::HLBGAllTime, fakeGuid, fakeAccount,
                        seed);
                }

                return false;
            }

            case AddonSurface::HLBGSeasonal:
            {
                if (!availability.hasHLBGSeasonal
                    && !availability.HasHLBGUnifiedTables())
                    return false;

                std::string payload = GetCachedHLBGSeasonalPayloadForStress(
                    availability);
                return !payload.empty();
            }

            case AddonSurface::HLBGAllTime:
            {
                if (availability.HasHLBGUnifiedTables())
                {
                    std::vector<uint32> const& sampleGuids =
                        GetHLBGParticipantSampleGuids();
                    uint32 guid = sampleGuids.empty()
                        ? fakeGuid
                        : sampleGuids[seed % sampleGuids.size()];
                    std::string payload = GetCachedHLBGAllTimePayloadForStress(
                        availability, guid);
                    return !payload.empty();
                }

                if (!availability.hasHLBGAllTime
                    || !availability.hlbgAllTimeGamesColumn
                    || !availability.hlbgAllTimeWinsColumn
                    || !availability.hlbgAllTimeLossesColumn
                    || !availability.hlbgAllTimeKillsColumn
                    || !availability.hlbgAllTimeDeathsColumn
                    || !availability.hlbgAllTimeKdRatioColumn
                    || !availability.hlbgAllTimeAvgKillsColumn
                    || !availability.hlbgAllTimeAvgDamageColumn)
                {
                    return false;
                }

                std::vector<uint32> const& sampleGuids =
                    GetHLBGParticipantSampleGuids();
                uint32 guid = sampleGuids.empty()
                    ? fakeGuid
                    : sampleGuids[seed % sampleGuids.size()];
                std::string payload = GetCachedHLBGAllTimePayloadForStress(
                    availability, guid);
                return !payload.empty();
            }
        }

        return false;
    }

    static std::vector<uint32> LoadWorldTemplateSampleEntries(char const* tableName,
        uint32 limit)
    {
        std::vector<uint32> entries;
        std::ostringstream sql;
        sql << "SELECT entry FROM " << tableName << " ORDER BY entry DESC LIMIT "
            << limit;

        QueryResult result = WorldDatabase.Query(sql.str().c_str());
        if (!result)
            return entries;

        do
        {
            entries.push_back((*result)[0].Get<uint32>());
        } while (result->NextRow());

        return entries;
    }

    struct CreatureTooltipSample
    {
        ObjectGuid::LowType spawnId = 0;
        uint32 entry = 0;
        uint16 mapId = 0;
        float posX = 0.0f;
        float posY = 0.0f;
        float posZ = 0.0f;
        uint32 spawnTimeSecs = 0;
    };

    static std::vector<CreatureTooltipSample> LoadCreatureTooltipSamples(uint32 limit)
    {
        std::vector<CreatureTooltipSample> candidates;
        candidates.reserve(sObjectMgr->GetAllCreatureData().size());

        for (auto const& pair : sObjectMgr->GetAllCreatureData())
        {
            CreatureData const& creatureData = pair.second;
            if (!creatureData.id1)
                continue;

            CreatureTooltipSample sample;
            sample.spawnId = pair.first;
            sample.entry = creatureData.id1;
            sample.mapId = creatureData.mapid;
            sample.posX = creatureData.posX;
            sample.posY = creatureData.posY;
            sample.posZ = creatureData.posZ;
            sample.spawnTimeSecs = creatureData.spawntimesecs;
            candidates.push_back(sample);
        }

        std::sort(candidates.begin(), candidates.end(), [](CreatureTooltipSample const& left, CreatureTooltipSample const& right)
        {
            if (left.entry != right.entry)
                return left.entry > right.entry;

            return left.spawnId > right.spawnId;
        });

        std::vector<CreatureTooltipSample> samples;
        samples.reserve(std::min<uint32>(limit, candidates.size()));

        uint32 lastEntry = 0;
        bool haveLastEntry = false;
        for (CreatureTooltipSample const& candidate : candidates)
        {
            if (haveLastEntry && candidate.entry == lastEntry)
                continue;

            samples.push_back(candidate);
            lastEntry = candidate.entry;
            haveLastEntry = true;

            if (samples.size() >= limit)
                break;
        }

        return samples;
    }

    static std::string BuildProtocolStressBlob(char fill, std::size_t length)
    {
        return std::string(length, fill);
    }

    namespace AddonTooltipStressOpcode
    {
        constexpr uint8 ItemInfo = 0x10;
        constexpr uint8 NpcInfo = 0x13;
        constexpr uint8 SpellInfo = 0x14;
    }

    static std::string BuildNpcGuidStringForStress(CreatureTooltipSample const& sample)
    {
        uint64 guidValue = (static_cast<uint64>(sample.entry) << 24)
            | static_cast<uint64>(sample.spawnId);

        std::ostringstream guid;
        guid << "0x" << std::uppercase << std::hex << std::setw(16)
            << std::setfill('0') << guidValue;
        return guid.str();
    }

    static std::string RoundTripChunkedPayloadForStress(std::string const& payload,
        char const* context)
    {
        std::vector<std::string> chunks = DCAddon::ChunkedMessage::Chunk(payload);
        DCAddon::ChunkedMessage reassembly;
        for (std::string const& chunk : chunks)
            reassembly.AddChunk(chunk);

        if (!reassembly.IsComplete())
            throw std::runtime_error(std::string("Failed to reassemble ") + context);

        return reassembly.GetCompleteMessage();
    }

    static std::string ValidateAndRoundTripJsonPayloadForStress(
        std::string const& payload, char const* context, uint8 expectedOpcode)
    {
        std::string roundTrip = RoundTripChunkedPayloadForStress(payload, context);
        DCAddon::ParsedMessage parsed(roundTrip);
        if (!parsed.IsValid() || parsed.GetOpcode() != expectedOpcode
            || parsed.GetDataCount() < 2)
        {
            throw std::runtime_error(std::string("Failed to parse ") + context);
        }

        if (parsed.GetString(0) != DCAddon::JSON_MARKER)
            throw std::runtime_error(std::string("Missing JSON marker for ") + context);

        DCAddon::JsonValue json = DCAddon::JsonParser::Parse(parsed.GetString(1));
        if (!json.IsObject())
            throw std::runtime_error(std::string("Failed to parse JSON object for ") + context);

        return roundTrip;
    }

    static std::string ValidateAndRoundTripPlainPayloadForStress(
        std::string const& payload, char const* context, uint8 expectedOpcode)
    {
        std::string roundTrip = RoundTripChunkedPayloadForStress(payload, context);
        DCAddon::ParsedMessage parsed(roundTrip);
        if (!parsed.IsValid() || parsed.GetOpcode() != expectedOpcode)
            throw std::runtime_error(std::string("Failed to parse ") + context);

        return roundTrip;
    }

    inline uint32 MixCollectionHashForStress(uint32 hash, uint32 item)
    {
        hash ^= (item * 2654435761u);
        return (hash << 13) | (hash >> 19);
    }

    inline void AppendUnsignedJsonNumberForStress(std::string& out,
        uint32 value)
    {
        char buffer[16];
        auto [ptr, ec] = std::to_chars(buffer, buffer + sizeof(buffer), value);
        if (ec != std::errc())
        {
            out += std::to_string(value);
            return;
        }

        out.append(buffer, static_cast<std::size_t>(ptr - buffer));
    }

    inline void AppendSignedJsonNumberForStress(std::string& out,
        int32 value)
    {
        char buffer[16];
        auto [ptr, ec] = std::to_chars(buffer, buffer + sizeof(buffer), value);
        if (ec != std::errc())
        {
            out += std::to_string(value);
            return;
        }

        out.append(buffer, static_cast<std::size_t>(ptr - buffer));
    }

    inline void AppendFloatingJsonNumberForStress(std::string& out,
        double value)
    {
        std::ostringstream stream;
        stream << std::setprecision(15) << value;
        out += stream.str();
    }

    inline void AppendJsonKeyForStress(std::string& out, char const* key)
    {
        out.push_back('"');
        out += key;
        out += "\":";
    }

    static void AppendSequentialJsonArrayForStress(std::string& out,
        uint32 start, uint32 count, uint32 step)
    {
        out.push_back('[');
        for (uint32 index = 0; index < count; ++index)
        {
            if (index > 0)
                out.push_back(',');

            AppendUnsignedJsonNumberForStress(out, start + (index * step));
        }
        out.push_back(']');
    }

    static void AppendCollectionStatsJsonForStress(std::string& out,
        uint32 owned, uint32 total)
    {
        out += "{\"owned\":";
        AppendUnsignedJsonNumberForStress(out, owned);
        out += ",\"percent\":";
        AppendFloatingJsonNumberForStress(out,
            total > 0 ? (static_cast<double>(owned) * 100.0) / total : 0.0);
        out += ",\"total\":";
        AppendUnsignedJsonNumberForStress(out, total);
        out.push_back('}');
    }

    static std::string BuildCollectionSyncDataJsonForStress(uint32 mountStart,
        uint32 mountCount, uint32 mountTotal, uint32 petStart, uint32 petCount,
        uint32 petTotal, uint32 heirloomStart, uint32 heirloomCount,
        uint32 heirloomTotal, uint32 titleStart, uint32 titleCount,
        uint32 titleTotal, uint32 transmogStart, uint32 transmogCount,
        uint32 transmogTotal, uint32 serverHash, uint32 timestamp)
    {
        uint32 const totalOwnedItems = mountCount + petCount + heirloomCount
            + titleCount + transmogCount;
        uint32 const nextThreshold = 100;
        int32 const mountsToNext = std::max<int32>(0,
            100 - static_cast<int32>(mountCount));

        std::string json;
        json.reserve(512 + (static_cast<std::size_t>(totalOwnedItems) * 8));

        json += "{\"bonuses\":{";
        json += "\"mountSpeedBonus\":";
        AppendSignedJsonNumberForStress(json,
            static_cast<int32>(std::min<uint32>(20, mountCount / 8)));
        json += ",\"mountsToNext\":";
        AppendSignedJsonNumberForStress(json, mountsToNext);
        json += ",\"nextThreshold\":";
        AppendUnsignedJsonNumberForStress(json, nextThreshold);
        json += "},\"collections\":{";

        AppendJsonKeyForStress(json, "heirlooms");
        AppendSequentialJsonArrayForStress(json, heirloomStart, heirloomCount, 1);
        json += ",";
        AppendJsonKeyForStress(json, "mounts");
        AppendSequentialJsonArrayForStress(json, mountStart, mountCount, 3);
        json += ",";
        AppendJsonKeyForStress(json, "pets");
        AppendSequentialJsonArrayForStress(json, petStart, petCount, 2);
        json += ",";
        AppendJsonKeyForStress(json, "titles");
        AppendSequentialJsonArrayForStress(json, titleStart, titleCount, 1);
        json += ",";
        AppendJsonKeyForStress(json, "transmog");
        AppendSequentialJsonArrayForStress(json, transmogStart, transmogCount, 1);

        json += "},\"hash\":";
        AppendUnsignedJsonNumberForStress(json, serverHash);
        json += ",\"stats\":{";

        AppendJsonKeyForStress(json, "heirlooms");
        AppendCollectionStatsJsonForStress(json, heirloomCount, heirloomTotal);
        json += ",";
        AppendJsonKeyForStress(json, "mounts");
        AppendCollectionStatsJsonForStress(json, mountCount, mountTotal);
        json += ",";
        AppendJsonKeyForStress(json, "pets");
        AppendCollectionStatsJsonForStress(json, petCount, petTotal);
        json += ",";
        AppendJsonKeyForStress(json, "titles");
        AppendCollectionStatsJsonForStress(json, titleCount, titleTotal);
        json += ",";
        AppendJsonKeyForStress(json, "transmog");
        AppendCollectionStatsJsonForStress(json, transmogCount, transmogTotal);

        json += "},\"timestamp\":";
        AppendUnsignedJsonNumberForStress(json, timestamp);
        json.push_back('}');
        return json;
    }

    struct CollectionStressHashStream
    {
        uint32 nextValue = 0;
        uint32 remaining = 0;
        uint32 step = 1;
    };

    static uint32 GenerateCollectionHashForStress(uint32 mountStart,
        uint32 mountCount, uint32 petStart, uint32 petCount,
        uint32 heirloomStart, uint32 heirloomCount, uint32 titleStart,
        uint32 titleCount, uint32 transmogStart, uint32 transmogCount)
    {
        std::array<CollectionStressHashStream, 5> streams = {{
            { mountStart, mountCount, 3 },
            { petStart, petCount, 2 },
            { heirloomStart, heirloomCount, 1 },
            { titleStart, titleCount, 1 },
            { transmogStart, transmogCount, 1 },
        }};

        uint32 hash = 0;
        bool hasAnyItems = false;

        for (;;)
        {
            uint32 nextItem = std::numeric_limits<uint32>::max();
            std::size_t nextStream = 0;
            bool found = false;

            for (std::size_t index = 0; index < streams.size(); ++index)
            {
                auto const& stream = streams[index];
                if (!stream.remaining)
                    continue;

                if (!found || stream.nextValue < nextItem)
                {
                    nextItem = stream.nextValue;
                    nextStream = index;
                    found = true;
                }
            }

            if (!found)
                return hasAnyItems ? hash : 0;

            hash = MixCollectionHashForStress(hash, nextItem);
            hasAnyItems = true;

            auto& chosen = streams[nextStream];
            --chosen.remaining;
            if (chosen.remaining)
                chosen.nextValue += chosen.step;
        }
    }

    struct CollectionSyncPayloadBuildResult
    {
        std::string payload;
        uint64 digestContribution = 0;
    };

    static CollectionSyncPayloadBuildResult BuildCollectionSyncPayloadForStress(
        CollectionStressSample const& sample, uint32 iteration)
    {
        uint32 mountCount = std::min(sample.mountTotal,
            sample.mountCount + (iteration % std::max<uint32>(1,
                std::min<uint32>(8, (sample.mountCount / 20) + 1))));
        uint32 petCount = std::min(sample.petTotal,
            sample.petCount + (iteration % std::max<uint32>(1,
                std::min<uint32>(6, (sample.petCount / 18) + 1))));
        uint32 heirloomCount = std::min(sample.heirloomTotal,
            sample.heirloomCount + (iteration % std::max<uint32>(1,
                std::min<uint32>(4, (sample.heirloomCount / 16) + 1))));
        uint32 titleCount = std::min(sample.titleTotal,
            sample.titleCount + (iteration % std::max<uint32>(1,
                std::min<uint32>(3, (sample.titleCount / 12) + 1))));
        uint32 transmogCount = std::min(sample.transmogTotal,
            sample.transmogCount + (iteration % std::max<uint32>(1,
                std::min<uint32>(16, (sample.transmogCount / 24) + 1))));

        uint32 serverHash = GenerateCollectionHashForStress(
            6000 + iteration, mountCount,
            9000 + iteration, petCount,
            300000 + iteration, heirloomCount,
            500 + iteration, titleCount,
            150000 + iteration, transmogCount);
        uint32 timestamp = static_cast<uint32>(std::time(nullptr)) + iteration;
        std::string rawData = BuildCollectionSyncDataJsonForStress(
            6000 + iteration, mountCount, sample.mountTotal,
            9000 + iteration, petCount, sample.petTotal,
            300000 + iteration, heirloomCount, sample.heirloomTotal,
            500 + iteration, titleCount, sample.titleTotal,
            150000 + iteration, transmogCount, sample.transmogTotal,
            serverHash, timestamp);

        DCAddon::JsonMessage msg(DCAddon::Module::COLLECTION,
            DCAddon::Opcode::Collection::SMSG_FULL_COLLECTION);
        msg.SetPreEncodedJson(std::move(rawData));

        CollectionSyncPayloadBuildResult result;
        result.payload = msg.Build();
        result.digestContribution = static_cast<uint64>(mountCount) + petCount
            + heirloomCount + titleCount + transmogCount + serverHash;
        return result;
    }

    TimingResult TestAddonProtocolClientCommunication(uint32 iterations)
    {
        TimingResult result;
        result.testName = "Addon Protocol Client Communication (" + std::to_string(iterations)
            + " cycles)";
        result.iterations = iterations;
        result.throughputCount = iterations * 5;
        result.success = true;

        if (iterations == 0)
        {
            result.success = false;
            result.error = "iterations must be > 0";
            return result;
        }

        static char const* const protocolModules[] = {
            DCAddon::Module::CORE,
            DCAddon::Module::AOE_LOOT,
            DCAddon::Module::SPECTATOR,
            DCAddon::Module::UPGRADE,
            DCAddon::Module::HINTERLAND,
            DCAddon::Module::PHASED_DUELS,
            DCAddon::Module::MYTHIC_PLUS,
            DCAddon::Module::PRESTIGE,
            DCAddon::Module::SEASONAL,
            DCAddon::Module::HOTSPOT,
            DCAddon::Module::LEADERBOARD,
            DCAddon::Module::WELCOME,
            DCAddon::Module::GROUP_FINDER,
            DCAddon::Module::GOMOVE,
            DCAddon::Module::NPCMOVE,
            DCAddon::Module::TELEPORTS,
            DCAddon::Module::EVENTS,
            DCAddon::Module::WORLD,
            DCAddon::Module::COLLECTION,
            DCAddon::Module::QOS,
        };

        std::vector<uint64> timesNs;
        timesNs.reserve(iterations);

        try
        {
            uint64 digest = 0;
            std::size_t const moduleCount = sizeof(protocolModules) / sizeof(protocolModules[0]);

            for (uint32 i = 0; i < iterations; ++i)
            {
                std::size_t moduleIndex = i % moduleCount;
                char const* module = protocolModules[moduleIndex];
                char const* nextModule = protocolModules[(moduleIndex + 1) % moduleCount];
                uint32 fakeGuid = 10000 + (i % 5000);
                uint32 fakeAccount = 1000 + (i % 200);
                std::string requestId = "stress-" + std::to_string(moduleIndex) + "-" + std::to_string(i);

                auto start = Clock::now();

                DCAddon::Message inbound(module, 0x01);
                inbound.SetRequestId(requestId)
                    .Add(fakeGuid)
                    .Add(fakeAccount)
                    .Add(static_cast<int32>(i % 17))
                    .Add(std::string(module));
                std::string inboundPayload = inbound.Build();
                DCAddon::ParsedMessage parsedInbound(inboundPayload);
                if (!parsedInbound.IsValid())
                    throw std::runtime_error("Failed to parse addon protocol inbound payload");

                digest += parsedInbound.GetOpcode();
                digest += parsedInbound.GetDataCount();
                digest += parsedInbound.GetRequestId().size();
                digest += parsedInbound.GetUInt32(0);
                digest += parsedInbound.GetUInt32(1);
                digest += parsedInbound.GetString(3).size();

                std::ostringstream batchRaw;
                batchRaw << DCAddon::Batch::MODULE << DCAddon::DELIMITER << 0
                    << DCAddon::DELIMITER << 2
                    << DCAddon::DELIMITER << module
                    << DCAddon::DELIMITER << 0x01
                    << DCAddon::DELIMITER << fakeGuid
                    << DCAddon::DELIMITER << (i % 9)
                    << DCAddon::DELIMITER << nextModule
                    << DCAddon::DELIMITER << 0x02
                    << DCAddon::DELIMITER << fakeAccount
                    << DCAddon::DELIMITER << (i % 13);
                DCAddon::ParsedMessage batchParsed(batchRaw.str());
                if (!batchParsed.IsValid())
                    throw std::runtime_error("Failed to parse addon protocol batch payload");

                std::vector<DCAddon::Batch::BatchEntry> batchEntries = DCAddon::Batch::ParseBatch(batchParsed);
                if (batchEntries.size() != 2)
                    throw std::runtime_error("Failed to parse expected addon protocol batch entries");

                digest += batchEntries[0].module.size();
                digest += batchEntries[1].module.size();
                digest += batchEntries[0].data.size();
                digest += batchEntries[1].data.size();

                DCAddon::Message outbound(module, 0x10);
                outbound.SetRequestId(requestId)
                    .Add(fakeGuid)
                    .Add(fakeAccount)
                    .Add(true)
                    .Add(std::string("ack:" + std::string(module)));
                std::string outboundPayload = outbound.Build();
                std::vector<std::string> outboundChunks = DCAddon::ChunkedMessage::Chunk(outboundPayload);
                DCAddon::ChunkedMessage outboundReassembly;
                for (std::string const& chunk : outboundChunks)
                    outboundReassembly.AddChunk(chunk);
                if (!outboundReassembly.IsComplete())
                    throw std::runtime_error("Failed to reassemble addon protocol plain message chunks");

                digest += outboundPayload.size();
                digest += outboundChunks.size();
                digest += outboundReassembly.GetCompleteMessage().size();

                std::string blob = BuildProtocolStressBlob(
                    static_cast<char>('A' + (i % 26)),
                    (i % 5) == 0 ? 320u : 72u);

                DCAddon::JsonMessage outboundJson(module, 0x11);
                outboundJson.SetRequestId(requestId)
                    .Set("guid", fakeGuid)
                    .Set("account", fakeAccount)
                    .Set("module", module)
                    .Set("status", static_cast<int32>(i % 4))
                    .Set("payload", blob);

                std::string jsonPayload = outboundJson.Build();
                DCAddon::ParsedMessage parsedJson(jsonPayload);
                if (!parsedJson.IsValid() || parsedJson.GetDataCount() < 2)
                    throw std::runtime_error("Failed to parse addon protocol JSON payload");

                if (parsedJson.GetString(0) != DCAddon::JSON_MARKER)
                    throw std::runtime_error("Addon protocol JSON payload missing JSON marker");

                DCAddon::JsonValue jsonValue = DCAddon::JsonParser::Parse(parsedJson.GetString(1));
                if (!jsonValue.IsObject())
                    throw std::runtime_error("Failed to parse addon protocol JSON object payload");

                std::vector<std::string> jsonChunks = DCAddon::ChunkedMessage::Chunk(jsonPayload);
                DCAddon::ChunkedMessage jsonReassembly;
                for (std::string const& chunk : jsonChunks)
                    jsonReassembly.AddChunk(chunk);
                if (!jsonReassembly.IsComplete())
                    throw std::runtime_error("Failed to reassemble addon protocol JSON message chunks");

                digest += jsonPayload.size();
                digest += jsonChunks.size();
                digest += jsonReassembly.GetCompleteMessage().size();
                digest += parsedJson.GetRequestId().size();

                auto end = Clock::now();
                if (digest == std::numeric_limits<uint64>::max())
                    result.error.clear();
                timesNs.push_back(std::chrono::duration_cast<Nanoseconds>(end - start).count());
            }

            result.iterations = static_cast<uint32>(timesNs.size());
            result.throughputCount = result.iterations * 5;
            FinalizeTimingSamplesNs(result, timesNs);
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }

    TimingResult TestAddonCollectionSyncBuildEncode(uint32 iterations)
    {
        TimingResult result;
        result.testName = "Addon Collection Sync Build+Encode ("
            + std::to_string(iterations) + " syncs)";
        result.iterations = iterations;
        result.success = true;

        if (iterations == 0)
        {
            result.success = false;
            result.error = "iterations must be > 0";
            return result;
        }

        std::vector<uint64> timesNs;
        timesNs.reserve(iterations);
        CollectionStressSample const sample = LoadCollectionStressSample();

        try
        {
            uint64 digest = 0;

            for (uint32 i = 0; i < iterations; ++i)
            {
                auto start = Clock::now();
                CollectionSyncPayloadBuildResult built =
                    BuildCollectionSyncPayloadForStress(sample, i);

                auto end = Clock::now();
                digest += built.payload.size() + built.digestContribution;
                if (digest == std::numeric_limits<uint64>::max())
                    result.error.clear();
                timesNs.push_back(std::chrono::duration_cast<Nanoseconds>(end - start).count());
            }

            result.iterations = static_cast<uint32>(timesNs.size());
            FinalizeTimingSamplesNs(result, timesNs);
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }

    TimingResult TestAddonCollectionSyncRoundTripParse(uint32 iterations)
    {
        TimingResult result;
        result.testName = "Addon Collection Sync Roundtrip+Parse ("
            + std::to_string(iterations) + " syncs)";
        result.iterations = iterations;
        result.success = true;

        if (iterations == 0)
        {
            result.success = false;
            result.error = "iterations must be > 0";
            return result;
        }

        std::vector<uint64> timesNs;
        timesNs.reserve(iterations);
        CollectionStressSample const sample = LoadCollectionStressSample();

        try
        {
            uint64 digest = 0;

            for (uint32 i = 0; i < iterations; ++i)
            {
                CollectionSyncPayloadBuildResult built =
                    BuildCollectionSyncPayloadForStress(sample, i);

                auto start = Clock::now();
                std::string roundTrip = ValidateAndRoundTripJsonPayloadForStress(
                    built.payload, "collection sync payload",
                    DCAddon::Opcode::Collection::SMSG_FULL_COLLECTION);
                auto end = Clock::now();

                digest += roundTrip.size() + built.digestContribution;
                if (digest == std::numeric_limits<uint64>::max())
                    result.error.clear();
                timesNs.push_back(std::chrono::duration_cast<Nanoseconds>(end - start).count());
            }

            result.iterations = static_cast<uint32>(timesNs.size());
            FinalizeTimingSamplesNs(result, timesNs);
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }

    TimingResult TestAddonCollectionSyncPayloads(uint32 iterations)
    {
        TimingResult result;
        result.testName = "Addon Collection Full Sync Total ("
            + std::to_string(iterations) + " syncs)";
        result.iterations = iterations;
        result.success = true;

        if (iterations == 0)
        {
            result.success = false;
            result.error = "iterations must be > 0";
            return result;
        }

        std::vector<uint64> timesNs;
        timesNs.reserve(iterations);
        CollectionStressSample const sample = LoadCollectionStressSample();

        try
        {
            uint64 digest = 0;

            for (uint32 i = 0; i < iterations; ++i)
            {
                auto start = Clock::now();
                CollectionSyncPayloadBuildResult built =
                    BuildCollectionSyncPayloadForStress(sample, i);
                std::string roundTrip = ValidateAndRoundTripJsonPayloadForStress(
                    built.payload, "collection sync payload",
                    DCAddon::Opcode::Collection::SMSG_FULL_COLLECTION);
                auto end = Clock::now();

                digest += roundTrip.size() + built.digestContribution;
                if (digest == std::numeric_limits<uint64>::max())
                    result.error.clear();
                timesNs.push_back(std::chrono::duration_cast<Nanoseconds>(end - start).count());
            }

            result.iterations = static_cast<uint32>(timesNs.size());
            FinalizeTimingSamplesNs(result, timesNs);
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }

    TimingResult TestAddonLeaderboardSyncPayloads(uint32 iterations)
    {
        TimingResult result;
        result.testName = "Addon Leaderboard Syncs (" + std::to_string(iterations)
            + " syncs)";
        result.iterations = iterations;
        result.success = true;

        if (iterations == 0)
        {
            result.success = false;
            result.error = "iterations must be > 0";
            return result;
        }

        std::vector<uint64> timesNs;
        timesNs.reserve(iterations);
        std::vector<LeaderboardStressVariant> const variants =
            LoadLeaderboardStressVariants();

        try
        {
            uint64 digest = 0;
            std::size_t const categoryCount = variants.size();

            for (uint32 i = 0; i < iterations; ++i)
            {
                auto start = Clock::now();

                LeaderboardStressVariant const& variant =
                    variants[i % categoryCount];
                std::string const& category = variant.category;
                std::string const& subcategory = variant.subcategory;
                uint32 entryCount = std::min<uint32>(50,
                    std::max<uint32>(1, variant.totalEntries));
                uint32 totalEntries = std::max<uint32>(entryCount,
                    variant.totalEntries);
                uint32 totalPages = std::max<uint32>(1,
                    (totalEntries + entryCount - 1) / entryCount);
                uint32 scoreBase = std::max<uint32>(1, variant.scoreBase);
                uint32 scoreStep = std::max<uint32>(1,
                    scoreBase / std::max<uint32>(entryCount * 2, 1));

                std::string entriesJson = "[";
                for (uint32 entryIndex = 0; entryIndex < entryCount; ++entryIndex)
                {
                    if (entryIndex > 0)
                        entriesJson += ",";

                    uint32 score = scoreBase > (entryIndex * scoreStep)
                        ? (scoreBase - (entryIndex * scoreStep))
                        : std::max<uint32>(1, scoreBase / 4);
                        LeaderboardStressRowSample const* rowSample =
                            variant.rowSamples.empty()
                            ? nullptr
                            : &variant.rowSamples[(entryIndex + i)
                                % variant.rowSamples.size()];
                        std::string playerName = rowSample
                            ? rowSample->name
                            : MakeSizedStressText("Player",
                                10 + ((entryIndex + i) % 4),
                                (i * 37u) + entryIndex);
                        std::string className = rowSample
                            ? rowSample->className
                            : "WARRIOR";
                        if (rowSample && rowSample->score > 0)
                            score = rowSample->score;
                        std::string entryExtra;

                    entriesJson += "{";
                    entriesJson += "\"rank\":" + std::to_string(entryIndex + 1) + ",";
                    entriesJson += "\"name\":\"" + JsonEscape(playerName)
                        + "\",";
                        entriesJson += "\"class\":\"" + JsonEscape(className)
                            + "\",";
                    entriesJson += "\"score\":" + std::to_string(score)
                        + ",";

                    if (category == "hlbg")
                    {
                            if (rowSample && rowSample->hasWinsLosses)
                            {
                                entriesJson += "\"wins\":"
                                    + std::to_string(rowSample->wins) + ",";
                                entriesJson += "\"losses\":"
                                    + std::to_string(rowSample->losses) + ",";
                                entryExtra = rowSample->extra;
                            }
                            else if (rowSample && rowSample->hasKD)
                            {
                                entriesJson += "\"kills\":"
                                    + std::to_string(rowSample->kills) + ",";
                                entriesJson += "\"deaths\":"
                                    + std::to_string(rowSample->deaths) + ",";
                                entriesJson += "\"kdRatio\":"
                                    + std::to_string(rowSample->kdRatio) + ",";
                                entryExtra = rowSample->extra;
                            }
                            else
                            {
                                uint32 wins = variant.auxA + (entryIndex % 5);
                                uint32 losses = variant.auxB + (entryIndex % 4);
                                entriesJson += "\"wins\":"
                                    + std::to_string(wins) + ",";
                                entriesJson += "\"losses\":"
                                    + std::to_string(losses) + ",";
                                entryExtra = std::to_string(wins) + "W/"
                                    + std::to_string(losses) + "L";
                            }
                    }
                    else if (category == "aoe")
                    {
                            uint32 qLeg = rowSample && rowSample->hasQuality
                                ? rowSample->qLeg
                                : (variant.auxD + (entryIndex % 2));
                            uint32 qEpic = rowSample && rowSample->hasQuality
                                ? rowSample->qEpic
                                : (variant.auxC + (entryIndex % 3));
                            uint32 qRare = rowSample && rowSample->hasQuality
                                ? rowSample->qRare
                                : (variant.auxB + (entryIndex % 5));
                            uint32 qUncommon = rowSample && rowSample->hasQuality
                                ? rowSample->qUncommon
                                : (variant.auxA + (entryIndex % 7));

                            entriesJson += "\"qLeg\":" + std::to_string(qLeg)
                                + ",";
                            entriesJson += "\"qEpic\":"
                                + std::to_string(qEpic) + ",";
                            entriesJson += "\"qRare\":"
                                + std::to_string(qRare) + ",";
                            entriesJson += "\"qUncommon\":"
                                + std::to_string(qUncommon) + ",";
                            entryExtra = rowSample && rowSample->hasQuality
                                ? rowSample->extra
                                : BuildAoeItemsExtraForStress(0, 0, qUncommon,
                                    qRare, qEpic, qLeg);
                    }
                    else if (category == "mplus")
                    {
                            entriesJson += "\"mapId\":"
                                + std::to_string(rowSample && rowSample->mapId > 0
                                    ? rowSample->mapId
                                    : (variant.auxA + (entryIndex % 10)))
                                + ",";
                            entryExtra = rowSample
                                ? rowSample->extra
                                : (std::string("best-key-")
                                    + std::to_string(score));
                    }
                    else if (category == "duel")
                    {
                            entryExtra = rowSample
                                ? rowSample->extra
                                : (std::to_string(variant.auxA + (entryIndex % 6))
                                    + " losses");
                    }
                    else
                    {
                            entryExtra = rowSample
                                ? rowSample->extra
                                : (std::string("detail-") + category + "-"
                                    + std::to_string(entryIndex));
                    }
                        entriesJson += "\"extra\":\"" + JsonEscape(entryExtra)
                            + "\"";
                    entriesJson += "}";
                }
                entriesJson += "]";

                std::string fullJson = "{";
                fullJson += "\"category\":\"" + JsonEscape(category) + "\",";
                fullJson += "\"subcategory\":\"" + JsonEscape(subcategory)
                    + "\",";
                fullJson += "\"page\":"
                    + std::to_string((i % totalPages) + 1) + ",";
                fullJson += "\"totalPages\":" + std::to_string(totalPages) + ",";
                fullJson += "\"totalEntries\":" + std::to_string(totalEntries) + ",";
                fullJson += "\"entries\":" + entriesJson;
                fullJson += "}";

                std::string payload = std::string(DCAddon::Module::LEADERBOARD)
                    + DCAddon::DELIMITER
                    + std::to_string(DCAddon::Opcode::Leaderboard::SMSG_LEADERBOARD_DATA)
                    + DCAddon::DELIMITER + DCAddon::JSON_MARKER
                    + DCAddon::DELIMITER + fullJson;

                std::string roundTrip = ValidateAndRoundTripJsonPayloadForStress(
                    payload, "leaderboard sync payload",
                    DCAddon::Opcode::Leaderboard::SMSG_LEADERBOARD_DATA);

                digest += roundTrip.size();
                digest += entryCount + totalEntries;

                auto end = Clock::now();
                if (digest == std::numeric_limits<uint64>::max())
                    result.error.clear();
                timesNs.push_back(std::chrono::duration_cast<Nanoseconds>(end - start).count());
            }

            result.iterations = static_cast<uint32>(timesNs.size());
            FinalizeTimingSamplesNs(result, timesNs);
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }

    TimingResult TestAddonGroupFinderSyncPayloads(uint32 iterations)
    {
        TimingResult result;
        result.testName = "Addon GroupFinder Search Sync (" + std::to_string(iterations)
            + " syncs)";
        result.iterations = iterations;
        result.success = true;

        if (iterations == 0)
        {
            result.success = false;
            result.error = "iterations must be > 0";
            return result;
        }

        std::vector<uint64> timesNs;
        timesNs.reserve(iterations);
        std::vector<GroupFinderStressVariant> const variants =
            LoadGroupFinderStressVariants();

        try
        {
            uint64 digest = 0;
            std::size_t const categoryCount = variants.size();

            for (uint32 i = 0; i < iterations; ++i)
            {
                auto start = Clock::now();

                GroupFinderStressVariant const& variant =
                    variants[i % categoryCount];
                std::string payload =
                    GetCachedGroupFinderListingsPayloadForStress(variant, i);
                std::string roundTrip = ValidateAndRoundTripJsonPayloadForStress(
                    payload, "groupfinder sync payload",
                    DCAddon::Opcode::GroupFinder::SMSG_SEARCH_RESULTS);

                digest += roundTrip.size();
                digest += payload.size() + variant.groupCount;

                auto end = Clock::now();
                if (digest == std::numeric_limits<uint64>::max())
                    result.error.clear();
                timesNs.push_back(std::chrono::duration_cast<Nanoseconds>(end - start).count());
            }

            result.iterations = static_cast<uint32>(timesNs.size());
            FinalizeTimingSamplesNs(result, timesNs);
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }

    TimingResult TestAddonHLBGHudSyncPayloads(uint32 iterations)
    {
        TimingResult result;
        result.testName = "Addon HLBG HUD Sync (" + std::to_string(iterations)
            + " updates / " + std::to_string(iterations * 5)
            + " messages)";
        result.iterations = iterations;
        result.throughputCount = iterations * 5;
        result.success = true;

        if (iterations == 0)
        {
            result.success = false;
            result.error = "iterations must be > 0";
            return result;
        }

        std::vector<uint64> timesNs;
        timesNs.reserve(iterations);

        try
        {
            uint64 digest = 0;

            for (uint32 i = 0; i < iterations; ++i)
            {
                auto start = Clock::now();
                uint32 elapsedMs = (i * 1000u) % 900000u;
                uint32 remainingMs = 900000u - elapsedMs;

                DCAddon::Message status(DCAddon::Module::HINTERLAND,
                    DCAddon::Opcode::HLBG::SMSG_STATUS);
                status.Add(static_cast<uint8>(1 + (i % 4)))
                    .Add(static_cast<uint32>(30))
                    .Add(remainingMs);

                DCAddon::Message resources(DCAddon::Module::HINTERLAND,
                    DCAddon::Opcode::HLBG::SMSG_RESOURCES);
                resources.Add(static_cast<uint32>(400 + (i % 150)))
                    .Add(static_cast<uint32>(380 + (i % 140)))
                    .Add(static_cast<uint32>(1 + (i % 3)))
                    .Add(static_cast<uint32>(1 + ((i + 1) % 3)));

                DCAddon::Message queue(DCAddon::Module::HINTERLAND,
                    DCAddon::Opcode::HLBG::SMSG_QUEUE_UPDATE);
                queue.Add(static_cast<uint8>(1))
                    .Add(static_cast<uint32>(1 + (i % 8)))
                    .Add(static_cast<uint32>(45000))
                    .Add(static_cast<uint32>(30 + (i % 10)))
                    .Add(static_cast<uint32>(15 + (i % 5)))
                    .Add(static_cast<uint32>(15 + ((i + 2) % 5)))
                    .Add(static_cast<uint32>(10))
                    .Add(static_cast<uint8>(2 + (i % 2)));

                DCAddon::Message timer(DCAddon::Module::HINTERLAND,
                    DCAddon::Opcode::HLBG::SMSG_TIMER_SYNC);
                timer.Add(elapsedMs)
                    .Add(static_cast<uint32>(900000));

                DCAddon::Message teamScore(DCAddon::Module::HINTERLAND,
                    DCAddon::Opcode::HLBG::SMSG_TEAM_SCORE);
                teamScore.Add(static_cast<uint32>(18 + (i % 12)))
                    .Add(static_cast<uint32>(14 + (i % 10)))
                    .Add(static_cast<uint32>(45 + (i % 18)))
                    .Add(static_cast<uint32>(39 + (i % 16)));

                std::string statusPayload = ValidateAndRoundTripPlainPayloadForStress(
                    status.Build(), "hlbg status payload",
                    DCAddon::Opcode::HLBG::SMSG_STATUS);
                std::string resourcesPayload = ValidateAndRoundTripPlainPayloadForStress(
                    resources.Build(), "hlbg resources payload",
                    DCAddon::Opcode::HLBG::SMSG_RESOURCES);
                std::string queuePayload = ValidateAndRoundTripPlainPayloadForStress(
                    queue.Build(), "hlbg queue payload",
                    DCAddon::Opcode::HLBG::SMSG_QUEUE_UPDATE);
                std::string timerPayload = ValidateAndRoundTripPlainPayloadForStress(
                    timer.Build(), "hlbg timer payload",
                    DCAddon::Opcode::HLBG::SMSG_TIMER_SYNC);
                std::string teamScorePayload = ValidateAndRoundTripPlainPayloadForStress(
                    teamScore.Build(), "hlbg team score payload",
                    DCAddon::Opcode::HLBG::SMSG_TEAM_SCORE);

                digest += statusPayload.size() + resourcesPayload.size()
                    + queuePayload.size() + timerPayload.size()
                    + teamScorePayload.size();

                auto end = Clock::now();
                if (digest == std::numeric_limits<uint64>::max())
                    result.error.clear();
                timesNs.push_back(std::chrono::duration_cast<Nanoseconds>(end - start).count());
            }

            result.iterations = static_cast<uint32>(timesNs.size());
            result.throughputCount = result.iterations * 5;
            FinalizeTimingSamplesNs(result, timesNs);
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }

    TimingResult TestAddonMythicHudSyncPayloads(uint32 iterations)
    {
        TimingResult result;
        result.testName = "Addon Mythic HUD Sync (" + std::to_string(iterations)
            + " updates)";
        result.iterations = iterations;
        result.success = true;

        if (iterations == 0)
        {
            result.success = false;
            result.error = "iterations must be > 0";
            return result;
        }

        std::vector<uint64> timesNs;
        timesNs.reserve(iterations);

        try
        {
            uint64 digest = 0;

            for (uint32 i = 0; i < iterations; ++i)
            {
                auto start = Clock::now();

                DCAddon::JsonMessage hudUpdate(DCAddon::Module::MYTHIC_PLUS,
                    DCAddon::Opcode::MPlus::SMSG_TIMER_UPDATE);
                hudUpdate.Set("runId", static_cast<int32>(9000 + i));
                hudUpdate.Set("elapsed", static_cast<int32>(i * 950));
                hudUpdate.Set("remaining", static_cast<int32>(1800000 - (i * 950)));
                hudUpdate.Set("deaths", static_cast<int32>(i % 9));
                hudUpdate.Set("bossesKilled", static_cast<int32>(i % 5));
                hudUpdate.Set("bossesTotal", 5);
                hudUpdate.Set("enemyCount", static_cast<int32>(35 + (i % 70)));
                hudUpdate.Set("enemyRequired", 100);
                hudUpdate.Set("failed", false);
                hudUpdate.Set("completed", false);

                std::string payload = hudUpdate.Build();
                std::string roundTrip = ValidateAndRoundTripJsonPayloadForStress(
                    payload, "mythic hud payload",
                    DCAddon::Opcode::MPlus::SMSG_TIMER_UPDATE);

                digest += roundTrip.size() + i;

                auto end = Clock::now();
                if (digest == std::numeric_limits<uint64>::max())
                    result.error.clear();
                timesNs.push_back(std::chrono::duration_cast<Nanoseconds>(end - start).count());
            }

            result.iterations = static_cast<uint32>(timesNs.size());
            FinalizeTimingSamplesNs(result, timesNs);
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }

    static std::string FormatSpellSecondsForStress(uint32 milliseconds)
    {
        std::ostringstream out;
        out << std::fixed << std::setprecision((milliseconds % 1000) != 0 ? 1 : 0)
            << (static_cast<double>(milliseconds) / 1000.0)
            << " sec";
        return out.str();
    }

    static char const* GetPowerTypeLabelForStress(uint32 powerType)
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

    static std::vector<std::string> WrapTooltipTextForStress(std::string const& text,
        std::size_t maxWidth = 92)
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

    static std::string LoadSpellDescriptionTemplateForStress(uint32 spellId)
    {
        SpellEntry const* spellEntry = sSpellStore.LookupEntry(spellId);
        if (!spellEntry)

        if (spellEntry->Description[0] && *spellEntry->Description[0])
            return spellEntry->Description[0];

        if (spellEntry->ToolTip[0] && *spellEntry->ToolTip[0])
            return spellEntry->ToolTip[0];

        return "";
    }

    static std::string FormatDurationTemplateForStress(uint32 milliseconds)
    {
        if (milliseconds == 0)
            return "0 sec";

        if (milliseconds % 60000 == 0)
            return std::to_string(milliseconds / 60000) + " min";

        if (milliseconds % 1000 == 0)
            return std::to_string(milliseconds / 1000) + " sec";

        return FormatSpellSecondsForStress(milliseconds);
    }

    static std::string TrimTemplateTextForStress(std::string value)
    {
        auto isSpace = [](unsigned char c) { return std::isspace(c) != 0; };

        while (!value.empty() && isSpace(static_cast<unsigned char>(value.front())))
            value.erase(value.begin());
        while (!value.empty() && isSpace(static_cast<unsigned char>(value.back())))
            value.pop_back();

        return value;
    }

    static bool TryParseStrictDoubleForStress(std::string const& text, double& out)
    {
        std::string trimmed = TrimTemplateTextForStress(text);
        if (trimmed.empty())
            return false;

        try
        {
            std::size_t index = 0;
            out = std::stod(trimmed, &index);
            return index == trimmed.size();
        }
        catch (...)
        {
            return false;
        }
    }

    static bool TryParseLeadingDoubleForStress(std::string const& text, double& out)
    {
        std::string trimmed = TrimTemplateTextForStress(text);
        if (trimmed.empty())
            return false;

        try
        {
            std::size_t index = 0;
            out = std::stod(trimmed, &index);
            return index > 0;
        }
        catch (...)
        {
            return false;
        }
    }

    static std::string FormatTemplateNumericValueForStress(double value)
    {
        double rounded = std::round(value);
        if (std::fabs(value - rounded) < 0.0001)
            return std::to_string(static_cast<int64>(rounded));

        std::ostringstream out;
        out << std::fixed << std::setprecision(2) << value;
        std::string text = out.str();
        while (!text.empty() && text.back() == '0')
            text.pop_back();
        if (!text.empty() && text.back() == '.')
            text.pop_back();
        return text.empty() ? "0" : text;
    }

    static std::string FormatSignedAmountForStress(int32 value)
    {
        return std::to_string(std::abs(value));
    }

    static bool GetTemplateEffectForStress(SpellInfo const* spellInfo,
        uint32 effectNumber, SpellEffectInfo const*& effect)
    {
        if (!spellInfo || effectNumber == 0 || effectNumber > MAX_SPELL_EFFECTS)
            return false;

        SpellEffectInfo const& candidate = spellInfo->Effects[effectNumber - 1];
        if (!candidate.IsEffect())
            return false;

        effect = &candidate;
        return true;
    }

    static std::string ReplaceNamedSpellTemplateTokenForStress(Player* player,
        SpellInfo const* spellInfo, std::string const& tokenName)
    {
        if (!player || !spellInfo)
            return "";

        if (tokenName == "AP")
            return std::to_string(std::max<int32>(0, player->GetTotalAttackPowerValue(BASE_ATTACK)));

        if (tokenName == "SP")
            return std::to_string(std::max<int32>(0, player->SpellBaseDamageBonusDone(spellInfo->GetSchoolMask())));

        return "";
    }

    static std::string ReplaceSpellTemplateTokenForStress(Player* player,
        SpellInfo const* spellInfo, char token, uint32 effectNumber)
    {
        if (!spellInfo)
            return "";

        if (token == 'n')
            return spellInfo->SpellName[0] ? spellInfo->SpellName[0] : "";

        if (token == 'r')
        {
            float maxRange = spellInfo->GetMaxRange(false, player);
            if (maxRange <= 0.0f)
                return "0";

            std::ostringstream out;
            out << std::fixed << std::setprecision(0) << maxRange;
            return out.str();
        }

        if (token == 'd')
        {
            int32 durationMs = spellInfo->GetMaxDuration();
            if (durationMs <= 0)
                return "0 sec";
            return FormatDurationTemplateForStress(static_cast<uint32>(durationMs));
        }

        if (effectNumber == 0)
            effectNumber = 1;

        SpellEffectInfo const* effect = nullptr;
        if (!GetTemplateEffectForStress(spellInfo, effectNumber, effect))
            return "";

        int32 baseValue = effect->CalcValue(player);
        switch (token)
        {
            case 's':
            case 'm':
            case 'M':
            case 'b':
                return FormatSignedAmountForStress(baseValue);
            case 'o':
            {
                int32 durationMs = spellInfo->GetMaxDuration();
                uint32 tickCount = (effect->Amplitude > 0 && durationMs > 0)
                    ? std::max<uint32>(1u, static_cast<uint32>(durationMs / int32(effect->Amplitude)))
                    : 1u;
                return FormatSignedAmountForStress(baseValue * int32(tickCount));
            }
            case 't':
                return effect->Amplitude > 0
                    ? FormatDurationTemplateForStress(effect->Amplitude)
                    : std::string("0 sec");
            case 'a':
            {
                float radius = effect->CalcRadius(player);
                if (radius <= 0.0f)
                    return "0";
                std::ostringstream out;
                out << std::fixed << std::setprecision(0) << radius;
                return out.str();
            }
            case 'u':
            {
                float combo = effect->PointsPerComboPoint;
                if (combo == 0.0f)
                    return "0";
                std::ostringstream out;
                out << std::fixed << std::setprecision(0) << std::abs(combo);
                return out.str();
            }
            default:
                break;
        }

        return "";
    }

    static bool TryEvaluateTemplateOperandForStress(Player* player,
        SpellInfo const* spellInfo, std::string const& operand, double& out)
    {
        std::string trimmed = TrimTemplateTextForStress(operand);
        if (trimmed.empty())
            return false;

        if (trimmed.front() != '$')
            return TryParseStrictDoubleForStress(trimmed, out);

        if (trimmed.size() >= 3
            && std::isalpha(static_cast<unsigned char>(trimmed[1]))
            && std::isalpha(static_cast<unsigned char>(trimmed[2])))
        {
            std::string namedToken;
            namedToken.push_back(trimmed[1]);
            namedToken.push_back(trimmed[2]);
            return TryParseLeadingDoubleForStress(
                ReplaceNamedSpellTemplateTokenForStress(player, spellInfo, namedToken), out);
        }

        char token = trimmed.size() > 1 ? trimmed[1] : '\0';
        uint32 effectNumber = 0;
        if (std::isdigit(static_cast<unsigned char>(token)))
        {
            token = 's';
            std::size_t indexEnd = 1;
            while (indexEnd < trimmed.size()
                && std::isdigit(static_cast<unsigned char>(trimmed[indexEnd])))
            {
                ++indexEnd;
            }

            effectNumber = static_cast<uint32>(std::stoul(trimmed.substr(1, indexEnd - 1)));
        }
        else if (trimmed.size() > 2)
        {
            std::size_t indexEnd = 2;
            while (indexEnd < trimmed.size()
                && std::isdigit(static_cast<unsigned char>(trimmed[indexEnd])))
            {
                ++indexEnd;
            }

            if (indexEnd > 2)
                effectNumber = static_cast<uint32>(std::stoul(trimmed.substr(2, indexEnd - 2)));
        }

        return TryParseLeadingDoubleForStress(
            ReplaceSpellTemplateTokenForStress(player, spellInfo, token, effectNumber), out);
    }

    static bool TryEvaluateSimpleTemplateExpressionForStress(Player* player,
        SpellInfo const* spellInfo, std::string const& expression, std::string& out)
    {
        std::string expr = TrimTemplateTextForStress(expression);
        if (expr.empty())
            return false;

        std::vector<std::string> operands;
        std::vector<char> operators;
        std::size_t tokenStart = 0;
        for (std::size_t i = 0; i < expr.size(); ++i)
        {
            char c = expr[i];
            bool isOperator = (c == '*' || c == '/' || c == '+' || c == '-');
            if (!isOperator || i == 0)
                continue;

            operands.push_back(expr.substr(tokenStart, i - tokenStart));
            operators.push_back(c);
            tokenStart = i + 1;
        }

        operands.push_back(expr.substr(tokenStart));
        if (operands.empty())
            return false;

        std::vector<double> values;
        values.reserve(operands.size());
        for (std::string const& operandText : operands)
        {
            double value = 0.0;
            if (!TryEvaluateTemplateOperandForStress(player, spellInfo, operandText, value))
                return false;
            values.push_back(value);
        }

        std::vector<double> reducedValues;
        std::vector<char> reducedOperators;
        reducedValues.push_back(values[0]);

        for (std::size_t opIndex = 0; opIndex < operators.size(); ++opIndex)
        {
            char op = operators[opIndex];
            double rhs = values[opIndex + 1];
            if (op == '*' || op == '/')
            {
                double lhs = reducedValues.back();
                if (op == '/')
                {
                    if (std::fabs(rhs) < 0.000001)
                        return false;
                    reducedValues.back() = lhs / rhs;
                }
                else
                {
                    reducedValues.back() = lhs * rhs;
                }
            }
            else
            {
                reducedOperators.push_back(op);
                reducedValues.push_back(rhs);
            }
        }

        double result = reducedValues[0];
        for (std::size_t opIndex = 0; opIndex < reducedOperators.size(); ++opIndex)
        {
            if (reducedOperators[opIndex] == '+')
                result += reducedValues[opIndex + 1];
            else if (reducedOperators[opIndex] == '-')
                result -= reducedValues[opIndex + 1];
            else
                return false;
        }

        out = FormatTemplateNumericValueForStress(result);
        return true;
    }

    static double ExtractLastTemplateQuantityForStress(std::string const& renderedText)
    {
        for (std::size_t pos = renderedText.size(); pos > 0; --pos)
        {
            if (!std::isdigit(static_cast<unsigned char>(renderedText[pos - 1])))
                continue;

            std::size_t end = pos;
            std::size_t start = pos - 1;
            while (start > 0)
            {
                char c = renderedText[start - 1];
                if (std::isdigit(static_cast<unsigned char>(c)) || c == '.' || c == '-' || c == '+')
                    --start;
                else
                    break;
            }

            double value = 0.0;
            if (TryParseStrictDoubleForStress(renderedText.substr(start, end - start), value))
                return value;
        }

        return 2.0;
    }

    static std::string RenderSpellDescriptionTemplateForStress(Player* player,
        SpellInfo const* spellInfo, std::string const& sourceTemplate)
    {
        if (!spellInfo || sourceTemplate.empty())
            return "";

        std::string rendered;
        rendered.reserve(sourceTemplate.size() + 32);

        std::size_t i = 0;
        while (i < sourceTemplate.size())
        {
            char ch = sourceTemplate[i];
            if (ch != '$')
            {
                rendered.push_back(ch);
                ++i;
                continue;
            }

            if (i + 1 >= sourceTemplate.size())
            {
                rendered.push_back(ch);
                ++i;
                continue;
            }

            char token = sourceTemplate[i + 1];
            if (token == '$')
            {
                rendered.push_back('$');
                i += 2;
                continue;
            }

            if (token == '{')
            {
                std::size_t closeBrace = sourceTemplate.find('}', i + 2);
                if (closeBrace != std::string::npos)
                {
                    std::string expression = sourceTemplate.substr(i + 2, closeBrace - (i + 2));
                    std::string expressionValue;
                    if (TryEvaluateSimpleTemplateExpressionForStress(player, spellInfo, expression, expressionValue))
                        rendered += expressionValue;
                    else
                        rendered.append(sourceTemplate, i, closeBrace - i + 1);

                    i = closeBrace + 1;
                    continue;
                }

                rendered.push_back('$');
                ++i;
                continue;
            }

            if (token == 'l')
            {
                std::size_t variantStart = i + 2;
                std::size_t colonPos = sourceTemplate.find(':', variantStart);
                std::size_t semiPos = sourceTemplate.find(';', variantStart);
                if (colonPos != std::string::npos && semiPos != std::string::npos && colonPos < semiPos)
                {
                    std::string singular = sourceTemplate.substr(variantStart, colonPos - variantStart);
                    std::string plural = sourceTemplate.substr(colonPos + 1, semiPos - (colonPos + 1));
                    double quantity = ExtractLastTemplateQuantityForStress(rendered);
                    rendered += (std::fabs(quantity - 1.0) < 0.0001) ? singular : plural;
                    i = semiPos + 1;
                    continue;
                }
            }

            if (std::isdigit(static_cast<unsigned char>(token)))
            {
                std::size_t indexEnd = i + 1;
                while (indexEnd < sourceTemplate.size()
                    && std::isdigit(static_cast<unsigned char>(sourceTemplate[indexEnd])))
                {
                    ++indexEnd;
                }

                uint32 effectNumber = static_cast<uint32>(std::stoul(sourceTemplate.substr(i + 1, indexEnd - (i + 1))));
                std::string replacement = ReplaceSpellTemplateTokenForStress(player, spellInfo, 's', effectNumber);
                if (!replacement.empty())
                {
                    rendered += replacement;
                    i = indexEnd;
                    continue;
                }
            }

            if (std::isalpha(static_cast<unsigned char>(token))
                && i + 2 < sourceTemplate.size()
                && std::isalpha(static_cast<unsigned char>(sourceTemplate[i + 2])))
            {
                std::string namedToken;
                namedToken.push_back(token);
                namedToken.push_back(sourceTemplate[i + 2]);
                std::string namedReplacement = ReplaceNamedSpellTemplateTokenForStress(player, spellInfo, namedToken);
                if (!namedReplacement.empty())
                {
                    rendered += namedReplacement;
                    i += 3;
                    continue;
                }
            }

            std::size_t indexStart = i + 2;
            std::size_t indexEnd = indexStart;
            while (indexEnd < sourceTemplate.size() && std::isdigit(static_cast<unsigned char>(sourceTemplate[indexEnd])))
                ++indexEnd;

            uint32 effectNumber = 0;
            if (indexEnd > indexStart)
                effectNumber = static_cast<uint32>(std::stoul(sourceTemplate.substr(indexStart, indexEnd - indexStart)));

            bool tokenSupported = (token == 'd') || (token == 'n') || (token == 'r')
                || (token == 's') || (token == 'm') || (token == 'M')
                || (token == 'b') || (token == 'o') || (token == 't')
                || (token == 'a') || (token == 'u');
            if (!tokenSupported)
            {
                rendered.push_back('$');
                ++i;
                continue;
            }

            std::string replacement = ReplaceSpellTemplateTokenForStress(player, spellInfo, token, effectNumber);
            if (replacement.empty())
                rendered.append(sourceTemplate, i, indexEnd - i);
            else
                rendered += replacement;

            i = indexEnd;
        }

        return rendered;
    }

    static bool HasUnresolvedTemplateTokensForStress(std::string const& text)
    {
        for (std::size_t i = 0; i + 1 < text.size(); ++i)
        {
            if (text[i] != '$')
                continue;

            char token = text[i + 1];
            if (token == '$')
            {
                ++i;
                continue;
            }

            if (token == '{' || token == 'l' || std::isdigit(static_cast<unsigned char>(token)))
                return true;

            if (std::isalpha(static_cast<unsigned char>(token)) && i + 2 < text.size())
            {
                char next = text[i + 2];
                if (std::isalpha(static_cast<unsigned char>(next)) || std::isdigit(static_cast<unsigned char>(next)))
                    return true;
            }
        }

        return false;
    }

    static std::string BuildSpellEffectTooltipLineForStress(Player* player,
        SpellInfo const* spellInfo, SpellEffectInfo const& effect)
    {
        int32 amount = effect.CalcValue(player);

        if ((effect.Effect == SPELL_EFFECT_TRIGGER_SPELL
            || effect.Effect == SPELL_EFFECT_TRIGGER_SPELL_2
            || effect.Effect == SPELL_EFFECT_TRIGGER_SPELL_WITH_VALUE
            || effect.Effect == SPELL_EFFECT_TRIGGER_MISSILE
            || effect.Effect == SPELL_EFFECT_TRIGGER_MISSILE_SPELL_WITH_VALUE)
            && effect.TriggerSpell > 0)
        {
            SpellInfo const* triggered = sSpellMgr->GetSpellInfo(effect.TriggerSpell);
            if (triggered && triggered->SpellName[0] && *triggered->SpellName[0])
                return std::string("Triggers ") + triggered->SpellName[0] + " (Spell "
                    + std::to_string(effect.TriggerSpell) + ").";

            return "Triggers Spell " + std::to_string(effect.TriggerSpell) + ".";
        }

        switch (effect.Effect)
        {
            case SPELL_EFFECT_SCHOOL_DAMAGE:
            case SPELL_EFFECT_HEALTH_LEECH:
                if (amount != 0)
                    return "Causes " + FormatSignedAmountForStress(amount) + " damage.";
                break;
            case SPELL_EFFECT_HEAL:
            case SPELL_EFFECT_HEAL_MECHANICAL:
                if (amount != 0)
                    return "Heals a friendly target for " + FormatSignedAmountForStress(amount) + ".";
                break;
            case SPELL_EFFECT_ENERGIZE:
                if (amount != 0)
                    return std::string("Restores ") + FormatSignedAmountForStress(amount) + " "
                        + GetPowerTypeLabelForStress(spellInfo ? spellInfo->PowerType : POWER_MANA) + ".";
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
            {
                int32 durationMs = spellInfo ? spellInfo->GetMaxDuration() : 0;
                uint32 tickCount = (effect.Amplitude > 0 && durationMs > 0)
                    ? std::max<uint32>(1u, static_cast<uint32>(durationMs / int32(effect.Amplitude)))
                    : 1u;
                return "Causes " + FormatSignedAmountForStress(amount * int32(tickCount))
                    + " damage over " + FormatSpellSecondsForStress(std::max<int32>(1, durationMs)) + ".";
            }
            case SPELL_AURA_PERIODIC_HEAL:
            case SPELL_AURA_PERIODIC_HEALTH_FUNNEL:
            {
                int32 durationMs = spellInfo ? spellInfo->GetMaxDuration() : 0;
                uint32 tickCount = (effect.Amplitude > 0 && durationMs > 0)
                    ? std::max<uint32>(1u, static_cast<uint32>(durationMs / int32(effect.Amplitude)))
                    : 1u;
                return "Heals " + FormatSignedAmountForStress(amount * int32(tickCount))
                    + " health over " + FormatSpellSecondsForStress(std::max<int32>(1, durationMs)) + ".";
            }
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
                if (amount != 0)
                    return "Increases movement speed by " + FormatSignedAmountForStress(amount) + "%.";
                break;
            case SPELL_AURA_MOD_DECREASE_SPEED:
                if (amount != 0)
                    return "Reduces movement speed by " + FormatSignedAmountForStress(amount) + "%.";
                break;
            case SPELL_AURA_MOD_DAMAGE_DONE:
            case SPELL_AURA_MOD_DAMAGE_PERCENT_DONE:
                if (amount != 0)
                    return "Increases damage done by " + FormatSignedAmountForStress(amount) + ".";
                break;
            case SPELL_AURA_MOD_HEALING:
                if (amount != 0)
                    return "Increases healing done by " + FormatSignedAmountForStress(amount) + ".";
                break;
            case SPELL_AURA_MOD_STAT:
            case SPELL_AURA_MOD_PERCENT_STAT:
                if (amount != 0)
                    return "Modifies stats by " + FormatSignedAmountForStress(amount) + ".";
                break;
            default:
                break;
        }

        std::ostringstream fallback;
        fallback << "Effect " << static_cast<uint32>(effect.Effect);
        if (amount != 0)
            fallback << " for " << FormatSignedAmountForStress(amount);
        if (effect.HasRadius())
            fallback << " in " << std::fixed << std::setprecision(0)
                << effect.CalcRadius(player) << " yd";
        fallback << '.';
        return fallback.str();
    }

    TimingResult TestAddonItemTooltipCalls(uint32 iterations)
    {
        TimingResult result;
        result.testName = "Addon Item Tooltip Calls (" + std::to_string(iterations)
            + " requests)";
        result.iterations = iterations;
        result.throughputCount = iterations;
        result.success = true;

        if (iterations == 0)
        {
            result.success = false;
            result.error = "iterations must be > 0";
            return result;
        }

        bool hasItemCustomData = WorldTableExists("dc_item_custom_data");
        std::vector<uint32> itemEntries = LoadWorldTemplateSampleEntries("item_template", 64);

        if (itemEntries.empty())
            return MakeSkippedTimingResult(result.testName,
                "missing item_template samples");

        std::vector<uint64> timesNs;
        timesNs.reserve(iterations);

        try
        {
            uint64 digest = 0;

            for (uint32 i = 0; i < iterations; ++i)
            {
                auto start = Clock::now();

                uint32 itemId = itemEntries[i % itemEntries.size()];
                if (ItemTemplate const* itemTemplate = sObjectMgr->GetItemTemplate(itemId))
                {
                    DCAddon::JsonMessage msg(DCAddon::Module::QOS,
                        AddonTooltipStressOpcode::ItemInfo);
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

                    if (hasItemCustomData)
                    {
                        QueryResult customResult = WorldDatabase.Query(
                            "SELECT custom_note, custom_source, is_custom "
                            "FROM dc_item_custom_data WHERE item_id = {}",
                            itemId);
                        if (customResult)
                        {
                            Field* fields = customResult->Fetch();
                            msg.Set("customNote", fields[0].Get<std::string>());
                            msg.Set("customSource", fields[1].Get<std::string>());
                            msg.Set("isCustom", fields[2].Get<bool>());
                        }
                    }

                    std::string payload = msg.Build();
                    digest += itemTemplate->Quality;
                    digest += itemTemplate->ItemLevel;
                    digest += itemTemplate->RequiredLevel;
                    digest += itemTemplate->InventoryType;
                    digest += itemTemplate->GetMaxStackSize();
                    digest += itemTemplate->Name1.size();
                    digest += payload.size();
                }

                auto end = Clock::now();
                if (digest == std::numeric_limits<uint64>::max())
                    result.error.clear();
                timesNs.push_back(std::chrono::duration_cast<Nanoseconds>(end - start).count());
            }

            result.iterations = static_cast<uint32>(timesNs.size());
            result.throughputCount = result.iterations;
            FinalizeTimingSamplesNs(result, timesNs);
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }

    TimingResult TestAddonNpcTooltipCalls(uint32 iterations)
    {
        TimingResult result;
        result.testName = "Addon NPC Tooltip Calls (" + std::to_string(iterations)
            + " requests)";
        result.iterations = iterations;
        result.throughputCount = iterations;
        result.success = true;

        if (iterations == 0)
        {
            result.success = false;
            result.error = "iterations must be > 0";
            return result;
        }

        std::vector<CreatureTooltipSample> creatureSamples = LoadCreatureTooltipSamples(64);
        if (creatureSamples.empty())
            return MakeSkippedTimingResult(result.testName,
                "missing cached creature spawn samples");

        std::vector<uint64> timesNs;
        timesNs.reserve(iterations);

        try
        {
            uint64 digest = 0;

            for (uint32 i = 0; i < iterations; ++i)
            {
                CreatureTooltipSample const& sample = creatureSamples[i % creatureSamples.size()];

                auto start = Clock::now();

                if (CreatureTemplate const* creatureTemplate = sObjectMgr->GetCreatureTemplate(sample.entry))
                {
                    std::string guidStr = BuildNpcGuidStringForStress(sample);
                    DCAddon::JsonMessage msg(DCAddon::Module::QOS,
                        AddonTooltipStressOpcode::NpcInfo);
                    msg.Set("guid", guidStr);
                    msg.Set("entry", sample.entry);
                    msg.Set("name", creatureTemplate->Name);
                    msg.Set("subname", creatureTemplate->SubName);
                    msg.Set("minLevel", creatureTemplate->minlevel);
                    msg.Set("maxLevel", creatureTemplate->maxlevel);
                    msg.Set("rank", creatureTemplate->rank);
                    msg.Set("faction", creatureTemplate->faction);
                    msg.Set("npcFlags", creatureTemplate->npcflag);
                    msg.Set("unitClass", creatureTemplate->unit_class);
                    msg.Set("type", creatureTemplate->type);

                    if (sample.spawnId > 0)
                        msg.Set("spawnId", static_cast<int32>(sample.spawnId));

                    msg.Set("dbGuid", static_cast<int32>(sample.spawnId));
                    msg.Set("spawnGuid", static_cast<int32>(sample.spawnId));
                    msg.Set("mapId", static_cast<int32>(sample.mapId));
                    msg.Set("spawnX", sample.posX);
                    msg.Set("spawnY", sample.posY);
                    msg.Set("spawnZ", sample.posZ);
                    msg.Set("spawnTime", static_cast<int32>(sample.spawnTimeSecs));

                    std::string payload = msg.Build();
                    digest += creatureTemplate->minlevel;
                    digest += creatureTemplate->maxlevel;
                    digest += creatureTemplate->rank;
                    digest += creatureTemplate->npcflag;
                    digest += creatureTemplate->type;
                    digest += creatureTemplate->Name.size();
                    digest += creatureTemplate->SubName.size();
                    digest += guidStr.size();
                    digest += sample.spawnId;
                    digest += sample.mapId;
                    digest += sample.spawnTimeSecs;
                    digest += payload.size();
                    digest += static_cast<uint64>(std::abs(sample.posX)
                        + std::abs(sample.posY) + std::abs(sample.posZ));
                }

                auto end = Clock::now();
                if (digest == std::numeric_limits<uint64>::max())
                    result.error.clear();
                timesNs.push_back(std::chrono::duration_cast<Nanoseconds>(end - start).count());
            }

            result.iterations = static_cast<uint32>(timesNs.size());
            result.throughputCount = result.iterations;
            FinalizeTimingSamplesNs(result, timesNs);
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }

    TimingResult TestAddonSpellInfoCalls(uint32 iterations)
    {
        TimingResult result;
        result.testName = "Addon Spell Info Calls (" + std::to_string(iterations)
            + " requests)";
        result.iterations = iterations;
        result.throughputCount = iterations;
        result.success = true;

        if (iterations == 0)
        {
            result.success = false;
            result.error = "iterations must be > 0";
            return result;
        }

        bool hasSpellCustomData = WorldTableExists("dc_spell_custom_data");
        uint32 const tooltipSpells[] = { 116, 133, 172, 339, 403, 585, 686, 774,
            2061, 30455, 49998, 5185, 20484 };
        uint32 const tooltipSpellCount = sizeof(tooltipSpells) / sizeof(tooltipSpells[0]);

        std::vector<uint64> timesNs;
        timesNs.reserve(iterations);

        try
        {
            uint64 digest = 0;

            for (uint32 i = 0; i < iterations; ++i)
            {
                auto start = Clock::now();

                uint32 spellId = tooltipSpells[i % tooltipSpellCount];
                if (SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId))
                {
                    DCAddon::JsonMessage msg(DCAddon::Module::QOS,
                        AddonTooltipStressOpcode::SpellInfo);
                    msg.Set("spellId", spellId);
                    msg.Set("name", spellInfo->SpellName[0] ? spellInfo->SpellName[0] : "");
                    msg.Set("rank", spellInfo->Rank[0] ? spellInfo->Rank[0] : "");
                    msg.Set("school", spellInfo->SchoolMask);
                    msg.Set("powerType", spellInfo->PowerType);
                    msg.Set("castTime", spellInfo->CastTimeEntry
                        ? spellInfo->CastTimeEntry->CastTime : 0);
                    msg.Set("cooldown", spellInfo->RecoveryTime);
                    msg.Set("category", spellInfo->GetCategory());

                    if (hasSpellCustomData)
                    {
                        QueryResult customResult = WorldDatabase.Query(
                            "SELECT custom_note, modified_values FROM dc_spell_custom_data "
                            "WHERE spell_id = {}",
                            spellId);
                        if (customResult)
                        {
                            Field* fields = customResult->Fetch();
                            msg.Set("customNote", fields[0].Get<std::string>());
                            msg.Set("modifiedValues", fields[1].Get<std::string>());
                        }
                    }

                    std::string payload = msg.Build();
                    digest += spellInfo->SchoolMask;
                    digest += spellInfo->PowerType;
                    digest += spellInfo->RecoveryTime;
                    digest += spellInfo->GetCategory();
                    if (spellInfo->SpellName[0])
                        digest += std::string(spellInfo->SpellName[0]).size();
                    digest += payload.size();
                }

                auto end = Clock::now();
                if (digest == std::numeric_limits<uint64>::max())
                    result.error.clear();
                timesNs.push_back(std::chrono::duration_cast<Nanoseconds>(end - start).count());
            }

            result.iterations = static_cast<uint32>(timesNs.size());
            result.throughputCount = result.iterations;
            FinalizeTimingSamplesNs(result, timesNs);
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }

    TimingResult TestAddonSpellTooltipEnrichment(uint32 iterations, Player* player)
    {
        TimingResult result;
        result.testName = player
            ? "Addon Dynamic Spell Tooltip Enrichment (" + std::to_string(iterations)
                + " calls)"
            : "Addon Spell Tooltip Enrichment (" + std::to_string(iterations)
                + " calls, console fallback)";
        result.iterations = iterations;
        result.success = true;

        if (iterations == 0)
        {
            result.success = false;
            result.error = "iterations must be > 0";
            return result;
        }

        uint32 const tooltipSpells[] = { 53, 116, 133, 172, 339, 403, 585, 686,
            774, 2061, 30455, 49998, 5185, 20484 };
        uint32 const tooltipSpellCount = sizeof(tooltipSpells) / sizeof(tooltipSpells[0]);

        std::vector<uint64> times;
        times.reserve(iterations);

        try
        {
            uint64 digest = 0;

            for (uint32 i = 0; i < iterations; ++i)
            {
                uint32 spellId = tooltipSpells[i % tooltipSpellCount];
                SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
                if (!spellInfo)
                    continue;

                auto start = Clock::now();

                std::vector<std::string> lines;
                lines.reserve(16);
                std::string legacyLine;

                std::ostringstream tooltip;
                if (spellInfo->SpellName[0])
                    tooltip << spellInfo->SpellName[0] << '|';
                if (spellInfo->Rank[0] && *spellInfo->Rank[0])
                {
                    tooltip << spellInfo->Rank[0] << '|';
                    lines.emplace_back(spellInfo->Rank[0]);
                }

                uint32 castTimeMs = player ? spellInfo->CalcCastTime(player)
                    : spellInfo->CalcCastTime();
                int32 powerCost = player
                    ? spellInfo->CalcPowerCost(player, spellInfo->GetSchoolMask())
                    : 0;
                float minRange = spellInfo->GetMinRange(false);
                float maxRange = spellInfo->GetMaxRange(false, player);
                int32 durationMs = spellInfo->GetMaxDuration();

                std::ostringstream topLine;
                if (powerCost > 0)
                    topLine << powerCost << ' ' << GetPowerTypeLabelForStress(spellInfo->PowerType);
                if (maxRange > 0.0f)
                {
                    if (topLine.tellp() > 0)
                        topLine << " | ";
                    topLine << std::fixed << std::setprecision(0);
                    if (minRange > 0.0f)
                        topLine << minRange << '-' << maxRange << " yd range";
                    else
                        topLine << maxRange << " yd range";
                }
                if (topLine.tellp() > 0)
                    lines.push_back(topLine.str());

                std::ostringstream timingLine;
                timingLine << ((castTimeMs == 0)
                    ? std::string("Instant cast")
                    : (FormatSpellSecondsForStress(castTimeMs) + " cast"));
                if (spellInfo->GetRecoveryTime() > 0)
                    timingLine << " | "
                        << FormatSpellSecondsForStress(spellInfo->GetRecoveryTime())
                        << " cooldown";
                lines.push_back(timingLine.str());

                if (durationMs > 0)
                    lines.push_back("Duration | " + FormatSpellSecondsForStress(static_cast<uint32>(durationMs)));

                tooltip << "cost=" << powerCost
                    << "|cast=" << castTimeMs
                    << "|cd=" << spellInfo->GetRecoveryTime()
                    << "|range=" << std::fixed << std::setprecision(0)
                    << minRange << '-' << maxRange;

                if (durationMs > 0)
                    tooltip << "|dur=" << durationMs;

                std::string descriptionTemplate = LoadSpellDescriptionTemplateForStress(spellId);
                if (!descriptionTemplate.empty())
                {
                    std::string renderedDescription =
                        RenderSpellDescriptionTemplateForStress(player, spellInfo, descriptionTemplate);
                    std::string const& bodySource = (!renderedDescription.empty()
                        && !HasUnresolvedTemplateTokensForStress(renderedDescription))
                        ? renderedDescription
                        : descriptionTemplate;
                    if (legacyLine.empty() && !renderedDescription.empty())
                        legacyLine = renderedDescription;
                    std::vector<std::string> wrapped = WrapTooltipTextForStress(bodySource);
                    lines.insert(lines.end(), wrapped.begin(), wrapped.end());
                }

                uint32 effectIndex = 0;
                for (SpellEffectInfo const& effect : spellInfo->Effects)
                {
                    if (!effect.IsEffect())
                    {
                        ++effectIndex;
                        continue;
                    }

                    tooltip << "|e" << effectIndex << '=' << effect.CalcValue(player);
                    std::string effectDescription =
                        BuildSpellEffectTooltipLineForStress(player, spellInfo, effect);
                    if (legacyLine.empty() && !effectDescription.empty())
                        legacyLine = effectDescription;
                    std::ostringstream effectLine;
                    effectLine << (!effectDescription.empty()
                        ? effectDescription
                        : (std::string("Effect ") + std::to_string(effectIndex)))
                        << " | opcode=" << static_cast<uint32>(effect.Effect)
                        << " | value=" << effect.CalcValue(player);
                    if (effect.HasRadius())
                    {
                        tooltip << '@' << std::fixed << std::setprecision(0)
                            << effect.CalcRadius(player);
                        effectLine << " | radius=" << std::fixed
                            << std::setprecision(0) << effect.CalcRadius(player)
                            << " yd";
                    }
                    if (effect.IsAura())
                    {
                        tooltip << ':' << static_cast<uint32>(effect.ApplyAuraName);
                        effectLine << " | aura=" << static_cast<uint32>(effect.ApplyAuraName);
                    }
                    if (effect.TriggerSpell)
                        effectLine << " | trigger=" << effect.TriggerSpell;

                    std::vector<std::string> wrappedEffect = WrapTooltipTextForStress(effectLine.str());
                    lines.insert(lines.end(), wrappedEffect.begin(), wrappedEffect.end());
                    ++effectIndex;
                }

                if (legacyLine.empty())
                {
                    if (!lines.empty())
                        legacyLine = lines.back();
                    else if (castTimeMs == 0)
                        legacyLine = "Instant cast.";
                    else
                        legacyLine = "Cast time: " + FormatSpellSecondsForStress(castTimeMs) + ".";
                }

                uint32 requestId = i + 1;
                uint32 contextHash = 0xA5A50000u ^ spellId ^ (i * 2654435761u);
                std::ostringstream payload;
                payload << '{'
                    << "\"requestId\":" << requestId
                    << ",\"spellId\":" << spellId
                    << ",\"contextHash\":" << contextHash
                    << ",\"status\":0"
                    << ",\"source\":\"server-v2\""
                    << ",\"line\":\"" << JsonEscape(legacyLine) << "\""
                    << ",\"lines\":[";

                for (std::size_t lineIndex = 0; lineIndex < lines.size(); ++lineIndex)
                {
                    payload << '{'
                        << "\"left\":\"" << JsonEscape(lines[lineIndex]) << "\""
                        << ",\"r\":0.95,\"g\":0.82,\"b\":0.55"
                        << ",\"kind\":\"body\"}";
                    if (lineIndex + 1 < lines.size())
                        payload << ',';
                }

                payload << "]}";

                std::string rendered = tooltip.str();
                digest += rendered.size();
                for (std::string const& line : lines)
                    digest += line.size();
                digest += lines.size();
                digest += payload.str().size();
                digest += castTimeMs;
                digest += static_cast<uint64>(std::max<int32>(0, durationMs));

                auto end = Clock::now();
                if (digest == std::numeric_limits<uint64>::max())
                    result.error.clear();
                times.push_back(std::chrono::duration_cast<Microseconds>(end - start).count());
            }

            if (times.empty())
                return MakeSkippedTimingResult(result.testName,
                    "no spell tooltip samples resolved");

            result.iterations = static_cast<uint32>(times.size());
            FinalizeTimingSamples(result, times);
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }

    static TimingResult RunAddonExtensionSurfaceQueryBenchmark(
        AddonStressAvailability const& availability,
        std::vector<AddonSurface> const& surfaces,
        uint32 iterations,
        std::string const& testName)
    {
        TimingResult result;
        result.testName = testName;
        result.iterations = iterations;
        result.success = true;

        if (iterations == 0)
        {
            result.success = false;
            result.error = "iterations must be > 0";
            return result;
        }

        if (surfaces.empty())
            return MakeSkippedTimingResult(result.testName,
                "no AddonExtension backing tables/views present");

        std::vector<uint64> times;
        times.reserve(iterations);

        try
        {
            PrewarmAddonSurfaceBenchmarkState(availability);

            for (uint32 i = 0; i < iterations; ++i)
            {
                uint32 fakeGuid = 10000 + (i % 5000);
                uint32 fakeAccount = 1000 + (i % 200);
                AddonSurface surface = surfaces[i % surfaces.size()];

                auto start = Clock::now();
                bool executed = ExecuteAddonSurfaceQuery(availability, surface, fakeGuid, fakeAccount, i);
                auto end = Clock::now();

                if (executed)
                    times.push_back(std::chrono::duration_cast<Microseconds>(end - start).count());
            }

            if (times.empty())
                return MakeSkippedTimingResult(result.testName, "no executable AddonExtension surfaces detected");

            result.iterations = static_cast<uint32>(times.size());
            FinalizeTimingSamples(result, times);
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }

    TimingResult TestAddonExtensionSurfaceQueries(uint32 iterations)
    {
        AddonStressAvailability availability = DetectAddonStressAvailability();
        std::vector<AddonSurface> surfaces =
            CollectAddonStressSurfaces(availability);

        return RunAddonExtensionSurfaceQueryBenchmark(availability, surfaces,
            iterations,
            "AddonExtension Surface Queries (" + std::to_string(iterations)
                + " calls)");
    }

    TimingResult TestAddonExtensionSurfaceQueryComponent(
        uint32 iterations, AddonSurface surface)
    {
        AddonStressAvailability availability = DetectAddonStressAvailability();
        if (!IsAddonSurfaceAvailable(availability, surface))
        {
            return MakeSkippedTimingResult(
                std::string("Addon Surface Query: ")
                    + GetAddonSurfaceName(surface),
                "surface unavailable");
        }

        return RunAddonExtensionSurfaceQueryBenchmark(availability,
            std::vector<AddonSurface>{ surface }, iterations,
            std::string("Addon Surface Query: ") + GetAddonSurfaceName(surface)
                + " (" + std::to_string(iterations) + " calls)");
    }

    TimingResult TestAddonExtensionHeavySimulation(uint32 playerCount)
    {
        TimingResult result;
        result.testName = "AddonExtension Heavy Call Simulation (" + std::to_string(playerCount) + " players)";
        result.iterations = playerCount;
        result.success = true;

        if (playerCount == 0)
        {
            result.success = false;
            result.error = "playerCount must be > 0";
            return result;
        }

        AddonStressAvailability availability = DetectAddonStressAvailability();
        if (!availability.HasAnySurface())
            return MakeSkippedTimingResult(result.testName, "no AddonExtension backing tables/views present");

        std::vector<AddonSurface> workload;
        workload.reserve(8);
        if (availability.hasQosSettings)
            workload.push_back(AddonSurface::QoS);
        if (availability.HasWelcomeSurface())
            workload.push_back(AddonSurface::Welcome);
        if (availability.hasHotspots)
            workload.push_back(AddonSurface::World);
        if (availability.HasMythicPlusSurface())
            workload.push_back(AddonSurface::MythicPlus);
        if (availability.HasGroupFinderSurface())
            workload.push_back(AddonSurface::GroupFinder);
        if (availability.HasWardrobeSurface())
            workload.push_back(AddonSurface::Wardrobe);
        if (availability.HasHLBGSurface())
            workload.push_back(AddonSurface::HLBG);
        if (availability.HasLiveProtocolSurface())
            workload.push_back(AddonSurface::Protocol);

        if (workload.empty())
            return MakeSkippedTimingResult(result.testName, "no executable AddonExtension workload available");

        std::vector<uint64> times;
        times.reserve(playerCount);

        try
        {
            PrewarmAddonSurfaceBenchmarkState(availability);

            for (uint32 i = 0; i < playerCount; ++i)
            {
                uint32 fakeGuid = 10000 + ((i * 13) % 5000);
                uint32 fakeAccount = 1000 + (i % 200);

                auto start = Clock::now();
                bool executedAny = false;

                for (size_t j = 0; j < workload.size(); ++j)
                {
                    executedAny = ExecuteAddonSurfaceQuery(availability, workload[j], fakeGuid,
                        fakeAccount, i + static_cast<uint32>(j)) || executedAny;
                }

                auto end = Clock::now();

                if (executedAny)
                    times.push_back(std::chrono::duration_cast<Microseconds>(end - start).count());
            }

            if (times.empty())
                return MakeSkippedTimingResult(result.testName, "workload produced no executable queries");

            result.iterations = static_cast<uint32>(times.size());
            FinalizeTimingSamples(result, times);
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
        result.throughputCount = batchSize;
        result.success = true;

        if (batchSize == 0)
        {
            result.success = false;
            result.error = "batchSize must be > 0";
            return result;
        }

        if (!CharacterTableExists("log_arena_memberstats"))
            return MakeSkippedTimingResult(result.testName, "log_arena_memberstats missing");

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

            CharacterDatabase.DirectCommitTransaction(trans);

            auto end = Clock::now();
            result.totalUs = std::chrono::duration_cast<Microseconds>(end - start).count();
            result.avgUs = result.totalUs / batchSize;
            result.minUs = result.avgUs;
            result.maxUs = result.avgUs;
            result.p95Us = result.avgUs;
            result.p99Us = result.avgUs;

            std::string avgDisplay = FormatTimeFromNanoseconds(
                (static_cast<double>(result.totalUs) * 1000.0) / batchSize);
            result.avgDisplay = avgDisplay;
            result.minDisplay = avgDisplay;
            result.maxDisplay = avgDisplay;
            result.p95Display = avgDisplay;
            result.p99Display = avgDisplay;
            result.avgSortNs = (static_cast<uint64>(result.totalUs) * 1000ULL) / batchSize;
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

        bool hasPrestige = CharacterTableExists("dc_character_prestige");
        bool hasItemUpgrades = CharacterTableExists("dc_item_upgrades");
        char const* keystoneTable = nullptr;
        char const* keystoneGuidColumn = nullptr;
        char const* keystoneSelectClause = nullptr;

        char const* itemUpgradeOwnerColumn = nullptr;
        if (hasItemUpgrades)
        {
            if (CharacterColumnExists("dc_item_upgrades", "player_guid"))
                itemUpgradeOwnerColumn = "player_guid";
            else if (CharacterColumnExists("dc_item_upgrades", "owner_guid"))
                itemUpgradeOwnerColumn = "owner_guid";
        }

        char const* mountCollectionTable = nullptr;
        char const* mountCollectionIdColumn = nullptr;
        if (CharacterTableExists("dc_mount_collection"))
        {
            mountCollectionTable = "dc_mount_collection";
            mountCollectionIdColumn = "spell_id";
        }
        else if (CharacterTableExists("dc_collection_mounts"))
        {
            mountCollectionTable = "dc_collection_mounts";
            mountCollectionIdColumn = "entry_id";
        }

        if (CharacterTableExists("dc_mplus_keystones"))
        {
            keystoneTable = "dc_mplus_keystones";
            keystoneGuidColumn = "character_guid";
            keystoneSelectClause = "map_id, level";
        }
        else if (CharacterTableExists("dc_player_keystones"))
        {
            keystoneTable = "dc_player_keystones";
            keystoneGuidColumn = "player_guid";
            keystoneSelectClause = "current_keystone_level";
        }

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
                    if (hasPrestige)
                    {
                        std::ostringstream sql;
                        sql << "SELECT prestige_level FROM dc_character_prestige WHERE guid = " << fakeGuid;
                        CharacterDatabase.Query(sql.str().c_str());
                    }
                }

                // Query 2: Item upgrades for equipped items (simulated)
                {
                    if (itemUpgradeOwnerColumn)
                    {
                        std::ostringstream sql;
                        sql << "SELECT item_guid, tier_id, upgrade_level FROM dc_item_upgrades WHERE "
                            << itemUpgradeOwnerColumn << " = " << fakeGuid << " LIMIT 20";
                        CharacterDatabase.Query(sql.str().c_str());
                    }
                }

                // Query 3: Collection sync (mounts)
                {
                    if (mountCollectionTable && mountCollectionIdColumn)
                    {
                        std::ostringstream sql;
                        sql << "SELECT " << mountCollectionIdColumn << " FROM " << mountCollectionTable
                            << " WHERE account_id = " << fakeAccount;
                        CharacterDatabase.Query(sql.str().c_str());
                    }
                }

                // Query 4: Mythic+ data
                {
                    if (keystoneTable && keystoneGuidColumn && keystoneSelectClause)
                    {
                        std::ostringstream sql;
                        sql << "SELECT " << keystoneSelectClause << " FROM " << keystoneTable
                            << " WHERE " << keystoneGuidColumn << " = " << fakeGuid;
                        CharacterDatabase.Query(sql.str().c_str());
                    }
                }

                auto end = Clock::now();
                times.push_back(std::chrono::duration_cast<Microseconds>(end - start).count());
            }

            result.iterations = static_cast<uint32>(times.size());
            FinalizeTimingSamples(result, times);
        }
        catch (const std::exception& e)
        {
            result.success = false;
            result.error = e.what();
        }

        return result;
    }

    TimingResult TestPlayerCountSimulation(uint32 playerCount, bool includeCore, bool includeVault)
    {
        TimingResult result;
        result.testName = "Player Count Simulation (" + std::to_string(playerCount) + " players)";
        result.iterations = playerCount;
        result.success = true;

        std::vector<uint64> times;
        times.reserve(playerCount);

        bool hasCharacters = CharacterTableExists("characters");
        bool hasCharInv = CharacterTableExists("character_inventory");
        bool hasCharQuest = CharacterTableExists("character_queststatus");
        bool hasMail = CharacterTableExists("mail");

        try
        {
            for (uint32 i = 0; i < playerCount; ++i)
            {
                auto start = Clock::now();

                uint32 fakeGuid = 10000 + (i % 500000);
                uint32 actionRoll = urand(0, 99);

                if (hasCharacters)
                {
                    std::ostringstream sql;
                    sql << "SELECT guid, name, level FROM characters WHERE guid = " << fakeGuid;
                    CharacterDatabase.Query(sql.str().c_str());
                }

                if (hasCharInv && actionRoll >= 10)
                {
                    std::ostringstream sql;
                    sql << "SELECT guid, bag, slot, item FROM character_inventory WHERE guid = " << fakeGuid << " LIMIT 25";
                    CharacterDatabase.Query(sql.str().c_str());
                }

                if (hasCharQuest && actionRoll >= 20)
                {
                    std::ostringstream sql;
                    sql << "SELECT guid, quest FROM character_queststatus WHERE guid = " << fakeGuid << " LIMIT 25";
                    CharacterDatabase.Query(sql.str().c_str());
                }

                if (hasMail && actionRoll >= 30)
                {
                    std::ostringstream sql;
                    sql << "SELECT id, receiver, subject FROM mail WHERE receiver = " << fakeGuid << " LIMIT 10";
                    CharacterDatabase.Query(sql.str().c_str());
                }

                if (includeCore)
                {
                    if (actionRoll % 2 == 0)
                        WorldDatabase.Query("SELECT entry FROM item_template LIMIT 50");
                    else
                        WorldDatabase.Query("SELECT entry FROM creature_template LIMIT 50");
                }

                if (includeVault && actionRoll >= 70)
                {
                    auto r = TestGreatVaultSimulation(1);
                    if (!r.success)
                    {
                        result.success = false;
                        result.error = r.error;
                        break;
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

        static void AppendAddonSurfaceBreakdownResults(ChatHandler* handler,
            bool printDetails,
            std::vector<DCPerfTest::TimingResult>& out,
            uint32 iterations,
            char const* label,
            std::vector<DCPerfTest::AddonSurface> const& surfaces)
        {
            if (surfaces.size() <= 1)
                return;

            if (printDetails)
                handler->SendSysMessage(label);

            for (DCPerfTest::AddonSurface surface : surfaces)
            {
                AppendAndMaybePrint(handler, printDetails, out,
                    DCPerfTest::TestAddonExtensionSurfaceQueryComponent(
                        iterations, surface));
            }
        }

        static void AddAddonSurfaceQueryResults(ChatHandler* handler,
            bool printDetails,
            std::vector<DCPerfTest::TimingResult>& out,
            uint32 iterations)
        {
            DCPerfTest::AddonStressAvailability const availability =
                DCPerfTest::DetectAddonStressAvailability();

            AppendAndMaybePrint(handler, printDetails, out,
                DCPerfTest::TestAddonExtensionSurfaceQueries(iterations));

            std::vector<DCPerfTest::AddonSurface> surfaces =
                DCPerfTest::CollectAddonStressSurfaces(availability);
            AppendAddonSurfaceBreakdownResults(handler, printDetails, out,
                iterations, "Breaking down AddonExtension surface families...",
                surfaces);
            AppendAddonSurfaceBreakdownResults(handler, printDetails, out,
                iterations, "Breaking down Protocol surface queries...",
                DCPerfTest::CollectAddonProtocolSurfaceDetails(availability));
            AppendAddonSurfaceBreakdownResults(handler, printDetails, out,
                iterations, "Breaking down Welcome surface queries...",
                DCPerfTest::CollectAddonWelcomeSurfaceDetails(availability));
            AppendAddonSurfaceBreakdownResults(handler, printDetails, out,
                iterations, "Breaking down Welcome Progress queries...",
                DCPerfTest::CollectAddonWelcomeProgressSurfaceDetails(availability));
            AppendAddonSurfaceBreakdownResults(handler, printDetails, out,
                iterations, "Breaking down GroupFinder surface queries...",
                DCPerfTest::CollectAddonGroupFinderSurfaceDetails(availability));
            AppendAddonSurfaceBreakdownResults(handler, printDetails, out,
                iterations, "Breaking down MythicPlus surface queries...",
                DCPerfTest::CollectAddonMythicPlusSurfaceDetails(availability));
            AppendAddonSurfaceBreakdownResults(handler, printDetails, out,
                iterations, "Breaking down Wardrobe surface queries...",
                DCPerfTest::CollectAddonWardrobeSurfaceDetails(availability));
            AppendAddonSurfaceBreakdownResults(handler, printDetails, out,
                iterations, "Breaking down HLBG surface queries...",
                DCPerfTest::CollectAddonHLBGSurfaceDetails(availability));
        }

        static void AddSystemsSuiteResults(ChatHandler* handler, bool printDetails, std::vector<DCPerfTest::TimingResult>& out, char const* args)
        {
            uint32 addonIterations = 200;
            if (args && *args)
            {
                uint32 val = atoi(args);
                if (val > 0)
                    addonIterations = val;
            }
            if (addonIterations > 5000)
                addonIterations = 5000;

            if (printDetails)
                handler->SendSysMessage("|cff00ff00=== DC Performance Test: DC Systems ===|r");

            AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestDCTableQueries());
            AddAddonSurfaceQueryResults(handler, printDetails, out, addonIterations);
            AddAddonTooltipResults(handler, printDetails, out, addonIterations);
            AddAddonSyncAndHudResults(handler, printDetails, out, addonIterations);
        }

        static void AddAddonTooltipResults(ChatHandler* handler, bool printDetails, std::vector<DCPerfTest::TimingResult>& out, uint32 baseIterations)
        {
            uint32 perTypeIterations = std::min<uint32>(std::max<uint32>(1, baseIterations), 2000);
            uint32 enrichmentIterations = std::min<uint32>(perTypeIterations * 3, 6000);
            uint32 protocolIterations = std::min<uint32>(std::max<uint32>(1, baseIterations), 4000);

            if (printDetails)
                handler->SendSysMessage("Running tooltip-heavy addon probes...");

            AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestAddonItemTooltipCalls(perTypeIterations));
            AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestAddonNpcTooltipCalls(perTypeIterations));
            AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestAddonSpellInfoCalls(perTypeIterations));
            AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestAddonSpellTooltipEnrichment(enrichmentIterations, handler->GetPlayer()));
            AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestAddonProtocolClientCommunication(protocolIterations));
        }

        static void AddAddonSyncAndHudResults(ChatHandler* handler, bool printDetails, std::vector<DCPerfTest::TimingResult>& out, uint32 baseIterations)
        {
            uint32 collectionIterations = std::min<uint32>(std::max<uint32>(1, baseIterations / 4), 200);
            uint32 leaderboardIterations = std::min<uint32>(std::max<uint32>(1, baseIterations / 3), 240);
            uint32 groupFinderIterations = std::min<uint32>(std::max<uint32>(1, baseIterations / 2), 320);
            uint32 hudIterations = std::min<uint32>(std::max<uint32>(1, baseIterations), 1000);

            if (printDetails)
                handler->SendSysMessage("Running addon sync/HUD probes...");

            AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestAddonCollectionSyncBuildEncode(collectionIterations));
            AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestAddonCollectionSyncRoundTripParse(collectionIterations));
            AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestAddonCollectionSyncPayloads(collectionIterations));
            AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestAddonLeaderboardSyncPayloads(leaderboardIterations));
            AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestAddonGroupFinderSyncPayloads(groupFinderIterations));
            AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestAddonHLBGHudSyncPayloads(hudIterations));
            AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestAddonMythicHudSyncPayloads(hudIterations));
        }

        static void AddAddonSuiteResults(ChatHandler* handler, bool printDetails, std::vector<DCPerfTest::TimingResult>& out, char const* args)
        {
            uint32 queryIterations = 240;
            uint32 burstPlayers = 80;

            if (args && *args)
            {
                std::istringstream iss(args);
                iss >> queryIterations;
                if (!(iss >> burstPlayers))
                    burstPlayers = std::max<uint32>(20, std::min<uint32>(250, queryIterations / 3));
            }

            if (queryIterations == 0)
                queryIterations = 1;
            if (burstPlayers == 0)
                burstPlayers = 1;
            if (queryIterations > 5000)
                queryIterations = 5000;
            if (burstPlayers > 500)
                burstPlayers = 500;

            if (printDetails)
                handler->SendSysMessage("|cff00ff00=== DC Performance Test: AddonExtension ===|r");

            AddAddonSurfaceQueryResults(handler, printDetails, out, queryIterations);
            AddAddonTooltipResults(handler, printDetails, out, queryIterations);
            AddAddonSyncAndHudResults(handler, printDetails, out, queryIterations);
            AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestAddonExtensionHeavySimulation(burstPlayers));
        }

        static void AddCpuSuiteResults(ChatHandler* handler, bool printDetails, std::vector<DCPerfTest::TimingResult>& out, char const* args)
        {
            uint32 iterations = 50000;
            if (args && *args)
            {
                uint32 val = atoi(args);
                if (val > 0)
                    iterations = val;
            }

            if (iterations > 500000)
                iterations = 500000;

            if (printDetails)
                handler->SendSysMessage("|cff00ff00=== DC Performance Test: CPU/Hot-path ===|r");

            AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestSpellInfoCache(iterations));
        }

        static void AddStressSuiteResults(ChatHandler* handler, bool printDetails, std::vector<DCPerfTest::TimingResult>& out, char const* args)
        {
            uint32 baseCount = 50;
            if (args && *args)
            {
                uint32 val = atoi(args);
                if (val > 0)
                    baseCount = val;
            }

            uint32 limitSafe = (baseCount > 500) ? 500 : baseCount;

            if (printDetails)
            {
                handler->SendSysMessage("|cff00ff00=== DC Performance Test: STRESS SIMULATION ===|r");
                handler->SendSysMessage("Running heavy load simulations. Server may hiccup...");
            }

            AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestItemUpgradeStateLookups(baseCount * 10));
            AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestCollectionTableQueries(baseCount * 8));
            AddAddonSurfaceQueryResults(handler, printDetails, out, std::min<uint32>(baseCount * 8, 4000));
            AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestLoginSimulation(limitSafe));
            AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestConcurrentQueryPattern(baseCount * 4));
            AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestMassTransactionWrite(baseCount * 2));
            AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestGreatVaultSimulation(limitSafe * 2));
            AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestGuildHouseLoadSimulation(limitSafe));
            AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestMassMapEntityLoad((limitSafe > 2) ? (limitSafe * 4 / 10) : 1));
            AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestCoreCharacterTableQueries(limitSafe * 4));
            AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestCoreWorldTableQueries(limitSafe * 4));
            AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestPlayerCountSimulation(limitSafe * 4, true, false));
            AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestAddonExtensionHeavySimulation(std::min<uint32>(limitSafe * 2, 400)));
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
                AddSystemsSuiteResults(handler, printDetails, out, args);
                return true;
            }

            if (suite == "addon")
            {
                AddAddonSuiteResults(handler, printDetails, out, args);
                return true;
            }

            if (suite == "coredb")
            {
                if (printDetails)
                    handler->SendSysMessage("|cff00ff00=== DC Performance Test: Core DB ===|r");

                uint32 iterations = 200;
                if (args && *args)
                {
                    uint32 val = atoi(args);
                    if (val > 0)
                        iterations = val;
                }
                if (iterations > 2000)
                    iterations = 2000;

                AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestCoreCharacterTableQueries(iterations));
                AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestCoreWorldTableQueries(iterations));
                return true;
            }

            if (suite == "playersim")
            {
                if (printDetails)
                    handler->SendSysMessage("|cff00ff00=== DC Performance Test: Player Count Simulation ===|r");

                uint32 playerCount = 200;
                uint32 includeCore = 1;
                uint32 includeVault = 0;

                if (args && *args)
                {
                    std::istringstream iss(args);
                    iss >> playerCount;
                    if (!(iss >> includeCore))
                        includeCore = 1;
                    if (!(iss >> includeVault))
                        includeVault = 0;
                }

                if (playerCount > 5000)
                    playerCount = 5000;

                AppendAndMaybePrint(handler, printDetails, out, DCPerfTest::TestPlayerCountSimulation(playerCount, includeCore != 0, includeVault != 0));
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
                AddStressSuiteResults(handler, printDetails, out, args);
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
                AddCpuSuiteResults(handler, printDetails, out, args);
                return true;
            }

            if (suite == "full")
            {
                RunSuite(handler, "sql", "", printDetails, out);
                RunSuite(handler, "cache", "", printDetails, out);
                RunSuite(handler, "systems", "", printDetails, out);
                RunSuite(handler, "coredb", "", printDetails, out);
                RunSuite(handler, "playersim", "", printDetails, out);
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
        std::vector<DCPerfTest::TimingResult> results;
        results.reserve(1);
        AddCpuSuiteResults(handler, true, results, args);

        handler->SendSysMessage("|cff00ff00=== Test Complete ===|r");
        return true;
    }

    static bool HandlePerfTestAddon(ChatHandler* handler, const char* args)
    {
        std::vector<DCPerfTest::TimingResult> results;
        results.reserve(4);
        AddAddonSuiteResults(handler, true, results, args);

        handler->SendSysMessage("|cff00ff00=== Test Complete ===|r");
        return true;
    }

    static bool HandlePerfTestLoop(ChatHandler* handler, const char* args)
    {
        // Usage:
        // .stresstest loop <suite> [loops=10] [sleepMs=1000] [suiteArgs...]
        // Optional: prefix suiteArgs with "quiet" to only print the final summary.
        // suite: sql|cache|systems|addon|coredb|playersim|stress|dbasync|path|cpu|mysql|full
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

            char const* passArgs = suiteArgs.empty() ? "" : suiteArgs.c_str();

            std::vector<DCPerfTest::TimingResult> results;
            results.reserve(32);
            bool ok = RunSuite(handler, suite, passArgs, !quiet, results);
            if (!ok && results.empty())
                return true;

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
            ChatCommandBuilder("addon",   HandlePerfTestAddon,   SEC_GAMEMASTER, Console::Yes),
            ChatCommandBuilder("coredb",  HandlePerfTestCoreDB,  SEC_GAMEMASTER, Console::Yes),
            ChatCommandBuilder("playersim", HandlePerfTestPlayerSim, SEC_GAMEMASTER, Console::Yes),
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

    static bool HandlePerfTestSystems(ChatHandler* handler, const char* args)
    {
        std::vector<DCPerfTest::TimingResult> results;
        results.reserve(4);
        AddSystemsSuiteResults(handler, true, results, args);

        handler->SendSysMessage("|cff00ff00=== Test Complete ===|r");
        return true;
    }

    static bool HandlePerfTestCoreDB(ChatHandler* handler, const char* args)
    {
        handler->SendSysMessage("|cff00ff00=== DC Performance Test: Core DB ===|r");

        uint32 iterations = 200;
        if (args && *args)
        {
            uint32 val = atoi(args);
            if (val > 0)
                iterations = val;
        }
        if (iterations > 2000)
            iterations = 2000;

        auto r1 = TestCoreCharacterTableQueries(iterations);
        PrintResult(handler, r1);

        auto r2 = TestCoreWorldTableQueries(iterations);
        PrintResult(handler, r2);

        handler->SendSysMessage("|cff00ff00=== Test Complete ===|r");
        return true;
    }

    static bool HandlePerfTestPlayerSim(ChatHandler* handler, const char* args)
    {
        handler->SendSysMessage("|cff00ff00=== DC Performance Test: Player Count Simulation ===|r");

        uint32 playerCount = 200;
        uint32 includeCore = 1;
        uint32 includeVault = 0;

        if (args && *args)
        {
            std::istringstream iss(args);
            iss >> playerCount;
            if (!(iss >> includeCore))
                includeCore = 1;
            if (!(iss >> includeVault))
                includeVault = 0;
        }

        if (playerCount > 5000)
            playerCount = 5000;

        auto r1 = TestPlayerCountSimulation(playerCount, includeCore != 0, includeVault != 0);
        PrintResult(handler, r1);

        handler->SendSysMessage("|cff00ff00=== Test Complete ===|r");
        return true;
    }

    static bool HandlePerfTestStress(ChatHandler* handler, const char* args)
    {
        std::vector<DCPerfTest::TimingResult> results;
        results.reserve(16);
        AddStressSuiteResults(handler, true, results, args);

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

        std::vector<DCPerfTest::TimingResult> results;
        results.reserve(32);
        RunSuite(handler, "full", "", true, results);

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
