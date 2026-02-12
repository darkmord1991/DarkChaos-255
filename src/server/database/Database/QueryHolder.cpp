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

#include "QueryHolder.h"
#include "Errors.h"
#include "Log.h"
#include "MySQLConnection.h"
#include "PreparedStatement.h"
#include "QueryResult.h"

bool SQLQueryHolderBase::SetPreparedQueryImpl(std::size_t index, PreparedStatementBase* stmt)
{
    if (m_queries.size() <= index)
    {
        LOG_ERROR("sql.sql", "Query index ({}) out of range (size: {}) for prepared statement", uint32(index), (uint32)m_queries.size());
        return false;
    }

    m_queries[index].first = stmt;
    return true;
}

PreparedQueryResult SQLQueryHolderBase::GetPreparedResult(std::size_t index) const
{
    if (!IsHolderAlive())
    {
        LOG_ERROR("sql.driver", "SQLQueryHolderBase::GetPreparedResult: Holder at {} is corrupted (magic=0x{:08X}) - returning null for index {}",
            static_cast<void const*>(this), _holderMagic, index);
        return PreparedQueryResult(nullptr);
    }

    // Don't call to this function if the index is of a prepared statement
    ASSERT(index < m_queries.size(), "Query holder result index out of range, tried to access index {} but there are only {} results",
        index, m_queries.size());

    return m_queries[index].second;
}

void SQLQueryHolderBase::SetPreparedResult(std::size_t index, PreparedResultSet* result)
{
    if (result && !result->GetRowCount())
    {
        delete result;
        result = nullptr;
    }

    // Validate holder integrity before writing to the vector
    if (!IsHolderAlive())
    {
        LOG_ERROR("sql.driver", "SQLQueryHolderBase::SetPreparedResult: Holder at {} is corrupted (magic=0x{:08X}) - cannot write result for index {}",
            static_cast<void const*>(this), _holderMagic, index);
        // Avoid leaking the result - delete it since we can't store it
        if (result)
            delete result;
        return;
    }

    /// store the result in the holder
    if (index < m_queries.size())
        m_queries[index].second = PreparedQueryResult(result);
}

SQLQueryHolderBase::~SQLQueryHolderBase()
{
    for (std::pair<PreparedStatementBase*, PreparedQueryResult>& query : m_queries)
    {
        /// if the result was never used, free the resources
        /// results used already (getresult called) are expected to be deleted
        if (query.first)
        {
            if (query.first->IsAlive())
            {
                delete query.first;
            }
            else
            {
                LOG_ERROR("sql.driver", "SQLQueryHolderBase::~SQLQueryHolderBase: Statement at {} is corrupted or already freed (magic=0x{:08X}). Skipping delete.",
                    static_cast<void*>(query.first), query.first->GetDebugMagic());
            }
            query.first = nullptr;
        }
    }
    _holderMagic = HOLDER_MAGIC_FREED;
}

void SQLQueryHolderBase::SetSize(std::size_t size)
{
    /// to optimize push_back, reserve the number of queries about to be executed
    /// Initialize all query pointers to nullptr to prevent deleting garbage in destructor
    m_queries.resize(size, {nullptr, PreparedQueryResult()});
}

SQLQueryHolderTask::~SQLQueryHolderTask() = default;

bool SQLQueryHolderTask::Execute()
{
    // Validate holder integrity before accessing its query vector
    if (!m_holder || !m_holder->IsHolderAlive())
    {
        LOG_ERROR("sql.driver", "SQLQueryHolderTask::Execute: Holder is null or corrupted (magic=0x{:08X}) - aborting all queries",
            m_holder ? m_holder->GetHolderMagic() : 0);
        m_result.set_value();
        return false;
    }

    /// execute all queries in the holder and pass the results
    for (std::size_t i = 0; i < m_holder->m_queries.size(); ++i)
    {
        // Re-check holder integrity each iteration in case of concurrent heap corruption
        if (!m_holder->IsHolderAlive())
        {
            LOG_ERROR("sql.driver", "SQLQueryHolderTask::Execute: Holder became corrupted during execution at index {} (magic=0x{:08X}) - aborting remaining queries",
                i, m_holder->GetHolderMagic());
            break;
        }

        if (PreparedStatementBase* stmt = m_holder->m_queries[i].first)
        {
            if (!stmt->IsAlive())
            {
                LOG_ERROR("sql.driver", "SQLQueryHolderTask::Execute: Corrupted/freed prepared statement at index {} (magic=0x{:08X}) - "
                    "aborting ALL remaining queries (heap corruption likely)",
                    i, stmt->GetDebugMagic());
                // Don't continue - if one statement is corrupted, the holder's memory
                // region is likely corrupted. Continuing risks SEGFAULT in SetPreparedResult.
                break;
            }
            m_holder->SetPreparedResult(i, m_conn->Query(stmt));
        }
    }

    m_result.set_value();
    return true;
}

bool SQLQueryHolderCallback::InvokeIfReady()
{
    if (m_future.valid() && m_future.wait_for(std::chrono::seconds(0)) == std::future_status::ready)
    {
        if (m_callback)
        {
            if (!m_holder)
            {
                LOG_ERROR("sql.driver", "SQLQueryHolderCallback::InvokeIfReady: Holder shared_ptr is null - skipping callback");
                return true;
            }
            m_callback(*m_holder);
        }
        return true;
    }

    return false;
}
