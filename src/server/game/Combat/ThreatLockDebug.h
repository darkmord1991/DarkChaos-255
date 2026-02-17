/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef AC_THREAT_LOCK_DEBUG_H
#define AC_THREAT_LOCK_DEBUG_H

#include "Log.h"
#include <cstdint>
#include <mutex>
#include <unordered_map>
#include <vector>

namespace Acore
{
    enum class ThreatLockTag : uint8
    {
        ThreatMgr,
        HostileRefMgr
    };

    inline char const* ToString(ThreatLockTag tag)
    {
        switch (tag)
        {
            case ThreatLockTag::ThreatMgr:
                return "ThreatMgr";
            case ThreatLockTag::HostileRefMgr:
                return "HostileRefMgr";
        }

        return "Unknown";
    }

    class ThreatTrackedRecursiveMutex
    {
    public:
        ThreatTrackedRecursiveMutex(ThreatLockTag tag, char const* name)
            : _tag(tag), _name(name)
        {
        }

        void lock()
        {
#if defined(ACORE_DEBUG)
            bool const firstAcquire = IsFirstAcquire();
            bool const inversion = firstAcquire &&
                _tag == ThreatLockTag::ThreatMgr &&
                HoldsLock(ThreatLockTag::HostileRefMgr);
#endif

            _mutex.lock();

#if defined(ACORE_DEBUG)
            if (firstAcquire)
            {
                if (inversion)
                {
                    LOG_ERROR("combat.threat.lock",
                        "Potential lock inversion: acquiring {} ({}) while already holding HostileRefMgr lock",
                        ToString(_tag), _name ? _name : "unnamed");
                }

                GetHeldStack().push_back(_tag);
            }

            ++GetDepthMap()[this];
#endif
        }

        void unlock()
        {
#if defined(ACORE_DEBUG)
            auto& depthMap = GetDepthMap();
            auto it = depthMap.find(this);
            if (it == depthMap.end() || it->second == 0)
            {
                LOG_ERROR("combat.threat.lock",
                    "Lock tracking mismatch while unlocking {} ({})",
                    ToString(_tag), _name ? _name : "unnamed");
            }
            else
            {
                --it->second;
                if (it->second == 0)
                {
                    depthMap.erase(it);
                    auto& heldStack = GetHeldStack();
                    if (!heldStack.empty() && heldStack.back() == _tag)
                        heldStack.pop_back();
                    else
                        LOG_ERROR("combat.threat.lock",
                            "Lock order tracking stack mismatch on unlock for {} ({})",
                            ToString(_tag), _name ? _name : "unnamed");
                }
            }
#endif

            _mutex.unlock();
        }

        bool try_lock()
        {
#if defined(ACORE_DEBUG)
            bool const firstAcquire = IsFirstAcquire();
            bool const inversion = firstAcquire &&
                _tag == ThreatLockTag::ThreatMgr &&
                HoldsLock(ThreatLockTag::HostileRefMgr);
#endif

            if (!_mutex.try_lock())
                return false;

#if defined(ACORE_DEBUG)
            if (firstAcquire)
            {
                if (inversion)
                {
                    LOG_ERROR("combat.threat.lock",
                        "Potential lock inversion: try_lock acquired {} ({}) while already holding HostileRefMgr lock",
                        ToString(_tag), _name ? _name : "unnamed");
                }

                GetHeldStack().push_back(_tag);
            }

            ++GetDepthMap()[this];
#endif

            return true;
        }

    private:
#if defined(ACORE_DEBUG)
        static std::vector<ThreatLockTag>& GetHeldStack()
        {
            static thread_local std::vector<ThreatLockTag> heldStack;
            return heldStack;
        }

        static std::unordered_map<ThreatTrackedRecursiveMutex const*, uint32>& GetDepthMap()
        {
            static thread_local std::unordered_map<ThreatTrackedRecursiveMutex const*, uint32> depthMap;
            return depthMap;
        }

        bool IsFirstAcquire() const
        {
            auto& depthMap = GetDepthMap();
            auto it = depthMap.find(this);
            return it == depthMap.end() || it->second == 0;
        }

        static bool HoldsLock(ThreatLockTag tag)
        {
            auto const& heldStack = GetHeldStack();
            for (ThreatLockTag held : heldStack)
            {
                if (held == tag)
                    return true;
            }

            return false;
        }
#endif

        [[maybe_unused]] ThreatLockTag _tag;
        [[maybe_unused]] char const* _name;
        std::recursive_mutex _mutex;
    };
}

#endif // AC_THREAT_LOCK_DEBUG_H
