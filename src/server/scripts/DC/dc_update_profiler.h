/*
 * Dark Chaos - Lightweight OnUpdate profiler
 * ==========================================
 *
 * Drop-in RAII timer for profiling periodic WorldScript::OnUpdate work while
 * chasing world-tick spikes. Put one at the top of an OnUpdate body:
 *
 *     void OnUpdate(uint32 diff) override
 *     {
 *         DarkChaos::ScopedUpdateProfiler _prof("MyWorldScript");
 *         ...
 *     }
 *
 * It emits a LOG_WARN under category "dc.perf" only when the scope meets or
 * exceeds DC.UpdateProfiler.ThresholdMs (config; default 25ms, set 0 to
 * disable). The threshold is read once. Overhead is two steady_clock reads
 * per call, so it is safe to leave in place; remove the lines once the
 * culprit is identified.
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
        explicit ScopedUpdateProfiler(char const* label)
            : _label(label), _start(std::chrono::steady_clock::now())
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

            if (elapsedMs >= static_cast<long long>(s_thresholdMs))
                LOG_WARN("dc.perf", "[UpdateProfiler] {} took {}ms", _label, elapsedMs);
        }

        ScopedUpdateProfiler(ScopedUpdateProfiler const&) = delete;
        ScopedUpdateProfiler& operator=(ScopedUpdateProfiler const&) = delete;

    private:
        char const* _label;
        std::chrono::steady_clock::time_point _start;
    };
}

#endif // DC_UPDATE_PROFILER_H
