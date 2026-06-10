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
 */

#ifndef DC_UPDATE_PROFILER_H
#define DC_UPDATE_PROFILER_H

#include "Config.h"
#include "Define.h"
#include "Log.h"
#include <chrono>

namespace DarkChaos
{
    class ScopedUpdateProfiler
    {
    public:
        explicit ScopedUpdateProfiler(char const* label, uint32 id = NO_ID)
            : _label(label), _id(id), _start(std::chrono::steady_clock::now())
        {
        }

        ~ScopedUpdateProfiler()
        {
            // Read once; this is a diagnostic, a restart to retune is fine.
            static uint32 const s_thresholdMs =
                sConfigMgr->GetOption<uint32>("DC.UpdateProfiler.ThresholdMs", 25);
            if (s_thresholdMs == 0)
                return;

            auto const elapsedMs =
                std::chrono::duration_cast<std::chrono::milliseconds>(
                    std::chrono::steady_clock::now() - _start).count();

            if (elapsedMs < static_cast<long long>(s_thresholdMs))
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
