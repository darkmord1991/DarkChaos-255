/*
 * Dark Chaos - Lightweight OnUpdate profiler
 * ==========================================
 *
 * Drop-in RAII timer for profiling periodic update work while chasing
 * world-tick spikes. Put one at the top of a scope:
 *
 *     void OnUpdate(uint32 diff) override
 *     {
 *         DarkChaos::ScopedUpdateProfiler _prof("MyWorldScript");
 *         ...
 *     }
 *
 * An optional numeric id distinguishes instances sharing a label (e.g. the
 * map id in Map::Update).
 *
 * It emits a LOG_WARN under category "dc.perf" only when the scope meets or
 * exceeds DC.UpdateProfiler.ThresholdMs (config; default 25ms, set 0 to
 * disable). The threshold is read once. Overhead is two steady_clock reads
 * per call, so it is safe to leave in place permanently.
 *
 * Lives in src/common so core (World.cpp, Map.cpp), scripts and modules can
 * all use it.
 *
 * UpdateBreakdown times each callee of one dispatch loop (ScriptMgr uses it
 * for every WorldScript::OnUpdate) and, when the whole loop reaches the
 * threshold, logs the slowest callees on one line. That names the cost even
 * when it is spread over callees that each stay under the threshold.
 */

#ifndef DC_UPDATE_PROFILER_H
#define DC_UPDATE_PROFILER_H

#include "Config.h"
#include "Define.h"
#include "Log.h"
#include "StringFormat.h"
#include <array>
#include <chrono>
#include <string>

namespace DarkChaos
{
    // DC.UpdateProfiler.ThresholdMs, read once; a restart to retune is fine. 0 disables every profiler.
    inline uint32 GetUpdateProfilerThresholdMs()
    {
        static uint32 const s_thresholdMs = sConfigMgr->GetOption<uint32>("DC.UpdateProfiler.ThresholdMs", 25);
        return s_thresholdMs;
    }

    class UpdateBreakdown
    {
    public:
        explicit UpdateBreakdown(char const* label)
            : _label(label), _thresholdMs(GetUpdateProfilerThresholdMs()), _start(Clock::now())
        {
        }

        // name must outlive this object (a script's GetName() does).
        template <typename Fn>
        void Time(std::string const& name, Fn&& fn)
        {
            if (!_thresholdMs)
            {
                fn();
                return;
            }

            Clock::time_point const start = Clock::now();
            fn();
            Add(name, Clock::now() - start);
        }

        ~UpdateBreakdown()
        {
            if (!_thresholdMs)
                return;

            long long const totalMs = ToMs(Clock::now() - _start);
            if (totalMs < static_cast<long long>(_thresholdMs))
                return;

            std::string top;
            for (Entry const& entry : _top)
            {
                if (!entry.name || ToMs(entry.elapsed) < 1)
                    break;

                if (!top.empty())
                    top += ", ";

                top += Acore::StringFormat("{} {}ms", *entry.name, ToMs(entry.elapsed));
            }

            if (top.empty())
                top = "no single callee took 1ms";

            LOG_WARN("dc.perf", "[UpdateProfiler] {} took {}ms over {} callees, slowest: {}",
                _label, totalMs, _count, top);
        }

        UpdateBreakdown(UpdateBreakdown const&) = delete;
        UpdateBreakdown& operator=(UpdateBreakdown const&) = delete;

    private:
        using Clock = std::chrono::steady_clock;
        static constexpr std::size_t TOP_COUNT = 4;

        struct Entry
        {
            std::string const* name = nullptr;
            Clock::duration elapsed = Clock::duration::zero();
        };

        static long long ToMs(Clock::duration d)
        {
            return std::chrono::duration_cast<std::chrono::milliseconds>(d).count();
        }

        // Keeps _top sorted, slowest first.
        void Add(std::string const& name, Clock::duration elapsed)
        {
            ++_count;
            for (std::size_t i = 0; i < TOP_COUNT; ++i)
            {
                if (_top[i].name && _top[i].elapsed >= elapsed)
                    continue;

                for (std::size_t j = TOP_COUNT - 1; j > i; --j)
                    _top[j] = _top[j - 1];

                _top[i] = { &name, elapsed };
                return;
            }
        }

        char const* _label;
        uint32 _thresholdMs;
        Clock::time_point _start;
        std::array<Entry, TOP_COUNT> _top{};
        uint32 _count = 0;
    };

    class ScopedUpdateProfiler
    {
    public:
        explicit ScopedUpdateProfiler(char const* label, uint32 id = NO_ID)
            : _label(label), _id(id), _start(std::chrono::steady_clock::now())
        {
        }

        ~ScopedUpdateProfiler()
        {
            uint32 const thresholdMs = GetUpdateProfilerThresholdMs();
            if (thresholdMs == 0)
                return;

            auto const elapsedMs =
                std::chrono::duration_cast<std::chrono::milliseconds>(
                    std::chrono::steady_clock::now() - _start).count();

            if (elapsedMs < static_cast<long long>(thresholdMs))
                return;

            if (_id != NO_ID)
                LOG_WARN("dc.perf", "[UpdateProfiler] {} [{}] took {}ms", _label, _id, elapsedMs);
            else
                LOG_WARN("dc.perf", "[UpdateProfiler] {} took {}ms", _label, elapsedMs);
        }

        ScopedUpdateProfiler(ScopedUpdateProfiler const&) = delete;
        ScopedUpdateProfiler& operator=(ScopedUpdateProfiler const&) = delete;

    private:
        static constexpr uint32 NO_ID = 0xFFFFFFFF;

        char const* _label;
        uint32 _id;
        std::chrono::steady_clock::time_point _start;
    };
}

#endif // DC_UPDATE_PROFILER_H
