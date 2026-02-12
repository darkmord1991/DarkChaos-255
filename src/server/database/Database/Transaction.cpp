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

#include "Transaction.h"
#include "Errors.h"
#include "Log.h"
#include "MySQLConnection.h"
#include "PreparedStatement.h"
#include "Timer.h"
#include <cstdint>
#ifdef __linux__
#include <pthread.h>
#endif
#include <mysqld_error.h>
#include <functional>
#include <sstream>
#include <thread>

namespace
{
    uint64 GetThreadIdHash()
    {
        return static_cast<uint64>(std::hash<std::thread::id>{}(std::this_thread::get_id()));
    }

    bool IsPointerInCurrentStack(void const* ptr)
    {
#ifdef __linux__
        pthread_attr_t attr;
        if (pthread_getattr_np(pthread_self(), &attr) != 0)
            return false;

        void* stackBase = nullptr;
        size_t stackSize = 0;
        if (pthread_attr_getstack(&attr, &stackBase, &stackSize) != 0)
        {
            pthread_attr_destroy(&attr);
            return false;
        }

        pthread_attr_destroy(&attr);

        uintptr_t const addr = reinterpret_cast<uintptr_t>(ptr);
        uintptr_t const base = reinterpret_cast<uintptr_t>(stackBase);
        return addr >= base && addr < (base + stackSize);
#else
        (void)ptr;
        return false;
#endif
    }
}

std::mutex TransactionTask::_deadlockLock;

constexpr Milliseconds DEADLOCK_MAX_RETRY_TIME_MS = 1min;

//- Append a raw ad-hoc query to the transaction
void TransactionBase::Append(std::string_view sql)
{
    if (IsFrozen())
    {
        LOG_ERROR("sql.driver", "TransactionBase::Append: Attempted to append SQL to a frozen transaction - ignoring");
        return;
    }

    std::lock_guard<std::mutex> guard(_queriesMutex);
    uint64 currentThread = GetThreadIdHash();
    uint64 prevThread = _ownerThreadHash.load(std::memory_order_relaxed);
    if (prevThread == 0)
        _ownerThreadHash.store(currentThread, std::memory_order_relaxed);
    else if (prevThread != currentThread)
        LOG_ERROR("sql.driver", "TransactionBase::Append: Cross-thread mutation detected (prev=0x{:X}, now=0x{:X})", prevThread, currentThread);
    SQLElementData data = {};
    data.type = SQL_ELEMENT_RAW;
    data.element = std::string(sql);
    m_queries.emplace_back(data);
}

//- Append a prepared statement to the transaction
void TransactionBase::AppendPreparedStatement(PreparedStatementBase* stmt)
{
    if (IsFrozen())
    {
        LOG_ERROR("sql.driver", "TransactionBase::AppendPreparedStatement: Attempted to append to a frozen transaction - ignoring");
        return;
    }

    // Validate statement before appending to transaction
    if (!stmt)
    {
        LOG_ERROR("sql.driver", "AppendPreparedStatement: Attempted to append NULL prepared statement to transaction - ignoring");
        return;
    }

    std::lock_guard<std::mutex> guard(_queriesMutex);
    uint64 currentThread = GetThreadIdHash();
    uint64 prevThread = _ownerThreadHash.load(std::memory_order_relaxed);
    if (prevThread == 0)
        _ownerThreadHash.store(currentThread, std::memory_order_relaxed);
    else if (prevThread != currentThread)
        LOG_ERROR("sql.driver", "TransactionBase::AppendPreparedStatement: Cross-thread mutation detected (prev=0x{:X}, now=0x{:X})", prevThread, currentThread);
    SQLElementData data = {};
    data.type = SQL_ELEMENT_PREPARED;
    data.element = stmt;
    m_queries.emplace_back(data);
}

void TransactionBase::Cleanup()
{
    // This might be called by explicit calls to Cleanup or by the auto-destructor
    // Use atomic check first for performance
    if (_cleanedUp.load(std::memory_order_acquire))
        return;

    std::lock_guard<std::mutex> lock(_cleanupMutex);
    
    // Double-check after acquiring lock
    if (_cleanedUp.load(std::memory_order_relaxed))
        return;

    std::lock_guard<std::mutex> queriesGuard(_queriesMutex);

    for (SQLElementData& data : m_queries)
    {
        switch (data.type)
        {
            case SQL_ELEMENT_PREPARED:
            {
                if (!std::holds_alternative<PreparedStatementBase*>(data.element))
                {
                    LOG_ERROR("sql.sql", "> PreparedStatementBase not found in SQLElementData during cleanup.");
                    break;
                }

                PreparedStatementBase* stmt = std::get<PreparedStatementBase*>(data.element);
                if (!stmt)
                    break;

                if (IsPointerInCurrentStack(stmt))
                {
                    LOG_ERROR("sql.sql", "> PreparedStatement pointer {} looks like stack memory. Skipping delete.",
                        static_cast<void*>(stmt));
                    data.element = static_cast<PreparedStatementBase*>(nullptr);
                    break;
                }

                // Validate the statement hasn't been corrupted or already freed
                // After free, the allocator overwrites object memory, so _magic won't match
                if (!stmt->IsAlive())
                {
                    LOG_ERROR("sql.sql", "> PreparedStatement at {} is corrupted or already freed (magic=0x{:X}). "
                        "Possible use-after-free or heap corruption. Skipping delete.",
                        static_cast<void*>(stmt), stmt->_magic);
                    data.element = static_cast<PreparedStatementBase*>(nullptr);
                    break;
                }

                delete stmt;
                data.element = static_cast<PreparedStatementBase*>(nullptr);
            }
            break;
            case SQL_ELEMENT_RAW:
            {
                if (!std::holds_alternative<std::string>(data.element))
                {
                    LOG_ERROR("sql.sql", "> std::string not found in SQLElementData during cleanup.");
                    break;
                }

                std::get<std::string>(data.element).clear();
            }
            break;
        }
    }

    m_queries.clear();
    _cleanedUp.store(true, std::memory_order_release);
}

bool TransactionBase::IsCleanedUp() const
{
    return _cleanedUp.load(std::memory_order_acquire);
}

bool TransactionTask::Execute()
{
    int errorCode = TryExecute();

    if (!errorCode)
    {
        // Clean up PreparedStatements after successful execution
        CleanupTransaction();
        return true;
    }

    if (errorCode == ER_LOCK_DEADLOCK)
    {
        std::ostringstream threadIdStream;
        threadIdStream << std::this_thread::get_id();
        std::string threadId = threadIdStream.str();

        {
            // Make sure only 1 async thread retries a transaction so they don't keep dead-locking each other
            std::lock_guard<std::mutex> lock(_deadlockLock);

            for (Milliseconds loopDuration{}, startMSTime = GetTimeMS(); loopDuration <= DEADLOCK_MAX_RETRY_TIME_MS; loopDuration = GetMSTimeDiffToNow(startMSTime))
            {
                if (!TryExecute())
                {
                    // Clean up PreparedStatements after successful retry
                    CleanupTransaction();
                    return true;
                }

                LOG_WARN("sql.sql", "Deadlocked SQL Transaction, retrying. Loop timer: {} ms, Thread Id: {}", loopDuration.count(), threadId);
            }
        }

        LOG_ERROR("sql.sql", "Fatal deadlocked SQL Transaction, it will not be retried anymore. Thread Id: {}", threadId);
    }

    // Clean up now.
    CleanupTransaction();

    return false;
}

int TransactionTask::TryExecute()
{
    return m_conn->ExecuteTransaction(m_trans);
}

void TransactionTask::CleanupTransaction()
{
    m_trans->Cleanup();
}

bool TransactionWithResultTask::Execute()
{
    int errorCode = TryExecute();
    if (!errorCode)
    {
        // Clean up PreparedStatements after successful execution
        CleanupTransaction();
        m_result.set_value(true);
        return true;
    }

    if (errorCode == ER_LOCK_DEADLOCK)
    {
        std::ostringstream threadIdStream;
        threadIdStream << std::this_thread::get_id();
        std::string threadId = threadIdStream.str();

        {
            // Make sure only 1 async thread retries a transaction so they don't keep dead-locking each other
            std::lock_guard<std::mutex> lock(_deadlockLock);

            for (Milliseconds loopDuration{}, startMSTime = GetTimeMS(); loopDuration <= DEADLOCK_MAX_RETRY_TIME_MS; loopDuration = GetMSTimeDiffToNow(startMSTime))
            {
                if (!TryExecute())
                {
                    // Clean up PreparedStatements after successful retry
                    CleanupTransaction();
                    m_result.set_value(true);
                    return true;
                }

                LOG_WARN("sql.sql", "Deadlocked SQL Transaction, retrying. Loop timer: {} ms, Thread Id: {}", loopDuration.count(), threadId);
            }
        }

        LOG_ERROR("sql.sql", "Fatal deadlocked SQL Transaction, it will not be retried anymore. Thread Id: {}", threadId);
    }

    // Clean up now.
    CleanupTransaction();
    m_result.set_value(false);

    return false;
}

bool TransactionCallback::InvokeIfReady()
{
    if (m_future.valid() && m_future.wait_for(0s) == std::future_status::ready)
    {
        m_callback(m_future.get());
        return true;
    }

    return false;
}
