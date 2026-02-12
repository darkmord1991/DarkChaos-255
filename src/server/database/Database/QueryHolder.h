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

#ifndef _QUERYHOLDER_H
#define _QUERYHOLDER_H

#include "SQLOperation.h"
#include <vector>

class AC_DATABASE_API SQLQueryHolderBase
{
friend class SQLQueryHolderTask;

public:
    static constexpr uint32 HOLDER_MAGIC_ALIVE = 0xA11BEA11;
    static constexpr uint32 HOLDER_MAGIC_FREED = 0xFEEDFACE;

    SQLQueryHolderBase() = default;
    virtual ~SQLQueryHolderBase();
    void SetSize(std::size_t size);
    PreparedQueryResult GetPreparedResult(std::size_t index) const;
    void SetPreparedResult(std::size_t index, PreparedResultSet* result);

    [[nodiscard]] bool IsHolderAlive() const { return _holderMagic == HOLDER_MAGIC_ALIVE; }
    [[nodiscard]] uint32 GetHolderMagic() const { return _holderMagic; }

protected:
    bool SetPreparedQueryImpl(std::size_t index, PreparedStatementBase* stmt);

private:
    uint32 _holderMagic{HOLDER_MAGIC_ALIVE};
    std::vector<std::pair<PreparedStatementBase*, PreparedQueryResult>> m_queries;
};

template<typename T>
class SQLQueryHolder : public SQLQueryHolderBase
{
public:
    bool SetPreparedQuery(std::size_t index, PreparedStatement<T>* stmt)
    {
        return SetPreparedQueryImpl(index, stmt);
    }
};

class AC_DATABASE_API SQLQueryHolderTask : public SQLOperation
{
public:
    explicit SQLQueryHolderTask(std::shared_ptr<SQLQueryHolderBase> holder)
                : SQLOperation("SQLQueryHolderTask", &SQLQueryHolderTask::ExecuteThunk, &SQLQueryHolderTask::DestroyThunk),
                    m_holder(std::move(holder)) { }

    ~SQLQueryHolderTask();

    bool Execute();
    QueryResultHolderFuture GetFuture() { return m_result.get_future(); }

    static bool ExecuteThunk(SQLOperation* op) { return static_cast<SQLQueryHolderTask*>(op)->Execute(); }
    static void DestroyThunk(SQLOperation* op) { delete static_cast<SQLQueryHolderTask*>(op); }

private:
    std::shared_ptr<SQLQueryHolderBase> m_holder;
    QueryResultHolderPromise m_result;
};

class AC_DATABASE_API SQLQueryHolderCallback
{
public:
    SQLQueryHolderCallback(std::shared_ptr<SQLQueryHolderBase>&& holder, QueryResultHolderFuture&& future)
        : m_holder(std::move(holder)), m_future(std::move(future)) { }

    SQLQueryHolderCallback(SQLQueryHolderCallback&&) = default;
    SQLQueryHolderCallback& operator=(SQLQueryHolderCallback&&) = default;

    void AfterComplete(std::function<void(SQLQueryHolderBase const&)> callback) &
    {
        m_callback = std::move(callback);
    }

    bool InvokeIfReady();

    std::shared_ptr<SQLQueryHolderBase> m_holder;
    QueryResultHolderFuture m_future;
    std::function<void(SQLQueryHolderBase const&)> m_callback;
};

#endif
