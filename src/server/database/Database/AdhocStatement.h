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

#ifndef _ADHOCSTATEMENT_H
#define _ADHOCSTATEMENT_H

#include "DatabaseEnvFwd.h"
#include "Define.h"
#include "SQLOperation.h"

/*! Raw, ad-hoc query. */
class AC_DATABASE_API BasicStatementTask : public SQLOperation
{
public:
    BasicStatementTask(std::string_view sql, bool async = false);
    ~BasicStatementTask();

    bool Execute();
    QueryResultFuture GetFuture() const { return m_result->get_future(); }

    static bool ExecuteThunk(SQLOperation* op) { return static_cast<BasicStatementTask*>(op)->Execute(); }
    static void DestroyThunk(SQLOperation* op) { delete static_cast<BasicStatementTask*>(op); }

private:
    std::string m_sql; //- Raw query to be executed
    bool m_has_result;
    QueryResultPromise* m_result;
};

#endif
