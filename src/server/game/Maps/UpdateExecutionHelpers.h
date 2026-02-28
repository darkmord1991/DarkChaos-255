/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef ACORE_UPDATE_EXECUTION_HELPERS_H
#define ACORE_UPDATE_EXECUTION_HELPERS_H

class UpdatableMapObject;

/**
 * SFINAE helpers for guarding per-object update execution.
 *
 * Objects that expose TryBeginUpdateExecution() / EndUpdateExecution()
 * (e.g. UpdatableMapObject) will be locked before their Update() tick
 * and unlocked afterwards.  Objects that lack these methods fall through
 * to the no-op overloads so generic code can treat all map objects
 * uniformly.
 */

template <typename T>
auto TryBeginUpdateExecutionIfSupported(T* object, int) -> decltype(object->TryBeginUpdateExecution(), bool())
{
    return object->TryBeginUpdateExecution();
}

template <typename T>
bool TryBeginUpdateExecutionIfSupported(T*, long)
{
    return true;
}

template <typename T>
auto EndUpdateExecutionIfSupported(T* object, int) -> decltype(object->EndUpdateExecution(), void())
{
    object->EndUpdateExecution();
}

template <typename T>
void EndUpdateExecutionIfSupported(T*, long)
{
}

template <typename T>
auto WaitForUpdateExecutionToFinishIfSupported(T* object, int) -> decltype(object->TryBeginUpdateExecution(), void())
{
    if (!object)
        return;
    uint32 spinCount = 0;

    while (!object->TryBeginUpdateExecution())
    {
        ++spinCount;
        if ((spinCount & 0xFF) == 0)
            std::this_thread::yield();
    }

    object->EndUpdateExecution();
}

template <typename T>
void WaitForUpdateExecutionToFinishIfSupported(T*, long)
{
}

/**
 * RAII guard that calls EndUpdateExecutionIfSupported on destruction.
 * Used when a partition worker or the main map thread holds the per-object
 * execution lock for the duration of an Update() call.
 */
struct UpdateExecutionGuard
{
    explicit UpdateExecutionGuard(UpdatableMapObject* object) : _object(object) { }

    ~UpdateExecutionGuard()
    {
        if (_object)
            EndUpdateExecutionIfSupported(_object, 0);
    }

private:
    UpdatableMapObject* _object;
};

#endif // ACORE_UPDATE_EXECUTION_HELPERS_H
