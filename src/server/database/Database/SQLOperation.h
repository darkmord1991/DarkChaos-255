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

#ifndef _SQLOPERATION_H
#define _SQLOPERATION_H

#include "DatabaseEnvFwd.h"
#include "Define.h"
#include "Errors.h"
#include <cstdint>
#include <variant>

//- Type specifier of our element data
enum SQLElementDataType
{
    SQL_ELEMENT_RAW,
    SQL_ELEMENT_PREPARED
};

//- The element
struct SQLElementData
{
    std::variant<PreparedStatementBase*, std::string> element;
    SQLElementDataType type;
};

class MySQLConnection;

class AC_DATABASE_API SQLOperation
{
public:
    using ExecuteFn = bool(*)(SQLOperation*);
    using DestroyFn = void(*)(SQLOperation*);

    static constexpr uint32 OP_MAGIC_ALIVE = 0x51A0C0DE;
    static constexpr uint32 OP_MAGIC_FREED = 0xDEADF00D;

    SQLOperation(char const* debugName, ExecuteFn executeFn, DestroyFn destroyFn)
        : _opMagic(OP_MAGIC_ALIVE), _debugName(debugName), _executeFn(executeFn), _destroyFn(destroyFn)
    {
        ASSERT(_executeFn);
        ASSERT(_destroyFn);
        (void)_debugName;
    }

    // Non-virtual by design: we must never delete via base pointer.
    ~SQLOperation() = default;

    [[nodiscard]] bool IsAlive() const { return _opMagic == OP_MAGIC_ALIVE; }
    [[nodiscard]] uint32 GetDebugMagic() const { return _opMagic; }
    [[nodiscard]] char const* GetDebugName() const { return _debugName ? _debugName : "(unknown)"; }

    int call()
    {
        if (!IsAlive())
            return -1;
        return _executeFn(this) ? 0 : -1;
    }

    void Destroy()
    {
        if (!IsAlive())
            return;

        // Mark first to reduce the chance of double-destroys doing real work.
        _opMagic = OP_MAGIC_FREED;
        _destroyFn(this);
    }

    void SetConnection(MySQLConnection* con) { m_conn = con; }

    MySQLConnection* m_conn{nullptr};

protected:
    void ResetDispatch(char const* debugName, ExecuteFn executeFn, DestroyFn destroyFn)
    {
        _debugName = debugName;
        _executeFn = executeFn;
        _destroyFn = destroyFn;
        ASSERT(_executeFn);
        ASSERT(_destroyFn);
    }

private:
    uint32 _opMagic;
    char const* _debugName;
    ExecuteFn _executeFn;
    DestroyFn _destroyFn;

    SQLOperation() = delete;
    SQLOperation(SQLOperation const& right) = delete;
    SQLOperation& operator=(SQLOperation const& right) = delete;
};

#endif
