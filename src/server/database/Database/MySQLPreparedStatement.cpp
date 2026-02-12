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

#include "MySQLPreparedStatement.h"
#include "Errors.h"
#include "Log.h"
#include "MySQLHacks.h"
#include "PreparedStatement.h"

#include <cstdint>

namespace {
    /// Detect obviously-corrupted heap pointers (non-null but in the
    /// unmapped low-address range below 64 KB).  Calling delete/delete[]
    /// on such a pointer corrupts the jemalloc arena and cascades into
    /// a SIGSEGV somewhere else (often in a subsequent memcpy or new).
    inline bool IsSuspiciousPointer(const void* p)
    {
        if (!p) return false;  // nullptr is always safe for delete
        return reinterpret_cast<std::uintptr_t>(p) < 0x10000;
    }

    /// Safe replacement for  delete[] static_cast<char*>(buffer)  that
    /// detects corruption and zeros the field instead of crashing.
    inline void SafeDeleteCharArray(void*& buffer)
    {
        if (IsSuspiciousPointer(buffer))
        {
            LOG_ERROR("sql.sql", "MySQLPreparedStatement: corrupt buffer pointer "
                "0x{:X} - zeroing instead of freeing",
                reinterpret_cast<std::uintptr_t>(buffer));
            buffer = nullptr;
            return;
        }
        delete[] static_cast<char*>(buffer);
        buffer = nullptr;
    }

    /// Safe replacement for  delete length  (unsigned long*).
    inline void SafeDeleteLength(unsigned long*& length)
    {
        if (IsSuspiciousPointer(length))
        {
            LOG_ERROR("sql.sql", "MySQLPreparedStatement: corrupt length pointer "
                "0x{:X} - zeroing instead of freeing",
                reinterpret_cast<std::uintptr_t>(length));
            length = nullptr;
            return;
        }
        delete length;
        length = nullptr;
    }
} // anonymous namespace

template<typename T>
struct MySQLType { };

template<> struct MySQLType<uint8> : std::integral_constant<enum_field_types, MYSQL_TYPE_TINY> { };
template<> struct MySQLType<uint16> : std::integral_constant<enum_field_types, MYSQL_TYPE_SHORT> { };
template<> struct MySQLType<uint32> : std::integral_constant<enum_field_types, MYSQL_TYPE_LONG> { };
template<> struct MySQLType<uint64> : std::integral_constant<enum_field_types, MYSQL_TYPE_LONGLONG> { };
template<> struct MySQLType<int8> : std::integral_constant<enum_field_types, MYSQL_TYPE_TINY> { };
template<> struct MySQLType<int16> : std::integral_constant<enum_field_types, MYSQL_TYPE_SHORT> { };
template<> struct MySQLType<int32> : std::integral_constant<enum_field_types, MYSQL_TYPE_LONG> { };
template<> struct MySQLType<int64> : std::integral_constant<enum_field_types, MYSQL_TYPE_LONGLONG> { };
template<> struct MySQLType<float> : std::integral_constant<enum_field_types, MYSQL_TYPE_FLOAT> { };
template<> struct MySQLType<double> : std::integral_constant<enum_field_types, MYSQL_TYPE_DOUBLE> { };

MySQLPreparedStatement::MySQLPreparedStatement(MySQLStmt* stmt, std::string_view queryString) :
    m_stmt(nullptr),
    m_Mstmt(stmt),
    m_bind(nullptr),
    m_queryString(std::string(queryString))
{
    /// Initialize variable parameters
    m_paramCount = mysql_stmt_param_count(stmt);
    m_paramsSet.assign(m_paramCount, false);
    m_bind = new MySQLBind[m_paramCount];
    memset(m_bind, 0, sizeof(MySQLBind) * m_paramCount);

    /// "If set to 1, causes mysql_stmt_store_result() to update the metadata MYSQL_FIELD->max_length value."
    MySQLBool bool_tmp = MySQLBool(1);
    mysql_stmt_attr_set(stmt, STMT_ATTR_UPDATE_MAX_LENGTH, &bool_tmp);
}

MySQLPreparedStatement::~MySQLPreparedStatement()
{
    ClearParameters();
    if (m_Mstmt->bind_result_done)
    {
        delete[] m_Mstmt->bind->length;
        delete[] m_Mstmt->bind->is_null;
    }

    mysql_stmt_close(m_Mstmt);
    delete[] m_bind;
}

void MySQLPreparedStatement::BindParameters(PreparedStatementBase* stmt)
{
    if (!stmt || !stmt->IsAlive())
    {
        LOG_ERROR("sql.driver", "MySQLPreparedStatement::BindParameters: Invalid/corrupted statement (magic=0x{:08X}) - skipping bind",
            stmt ? stmt->GetDebugMagic() : 0);
        return;
    }

    // Guard: if the MYSQL_BIND array is null or at an impossible address
    // (heap corruption from data-race damage), skip binding entirely.
    if (!m_bind || IsSuspiciousPointer(m_bind))
    {
        LOG_ERROR("sql.driver", "MySQLPreparedStatement::BindParameters: m_bind is {} "
            "(0x{:X}) for statement {} - skipping bind to prevent crash",
            m_bind ? "corrupt" : "null",
            reinterpret_cast<std::uintptr_t>(m_bind),
            stmt->GetIndex());
        return;
    }

    m_stmt = stmt;     // Cross reference them for debug output

    uint8 pos = 0;
    for (PreparedStatementData const& data : stmt->GetParameters())
    {
        std::visit([&](auto&& param)
        {
            SetParameter(pos, param);
        }, data.data);

        ++pos;
    }

#ifdef _DEBUG
    if (pos < m_paramCount)
        LOG_WARN("sql.sql", "[WARNING]: BindParameters() for statement {} did not bind all allocated parameters", stmt->GetIndex());
#endif
}

void MySQLPreparedStatement::ClearParameters()
{
    for (uint32 i=0; i < m_paramCount; ++i)
    {
        SafeDeleteLength(m_bind[i].length);
        SafeDeleteCharArray(m_bind[i].buffer);
        m_paramsSet[i] = false;
    }
}

static bool ParamenterIndexAssertFail(uint32 stmtIndex, uint8 index, uint32 paramCount)
{
    LOG_ERROR("sql.driver", "Attempted to bind parameter {}{} on a PreparedStatement {} (statement has only {} parameters)",
        uint32(index) + 1, (index == 1 ? "st" : (index == 2 ? "nd" : (index == 3 ? "rd" : "nd"))), stmtIndex, paramCount);

    return false;
}

//- Bind on mysql level
void MySQLPreparedStatement::AssertValidIndex(uint8 index)
{
    ASSERT(index < m_paramCount || ParamenterIndexAssertFail(m_stmt->GetIndex(), index, m_paramCount));

    if (m_paramsSet[index])
        LOG_ERROR("sql.sql", "[ERROR] Prepared Statement (id: {}) trying to bind value on already bound index ({}).", m_stmt->GetIndex(), index);
}

template<typename T>
void MySQLPreparedStatement::SetParameter(const uint8 index, T value)
{
    AssertValidIndex(index);
    m_paramsSet[index] = true;
    MYSQL_BIND* param = &m_bind[index];
    uint32 len = uint32(sizeof(T));
    param->buffer_type = MySQLType<T>::value;
    SafeDeleteCharArray(param->buffer);
    param->buffer = new char[len];
    param->buffer_length = 0;
    param->is_null_value = 0;
    param->length = nullptr; // Only != NULL for strings
    param->is_unsigned = std::is_unsigned_v<T>;

    memcpy(param->buffer, &value, len);
}

void MySQLPreparedStatement::SetParameter(const uint8 index, bool value)
{
    SetParameter(index, uint8(value ? 1 : 0));
}

void MySQLPreparedStatement::SetParameter(const uint8 index, std::nullptr_t /*value*/)
{
    AssertValidIndex(index);
    m_paramsSet[index] = true;
    MYSQL_BIND* param = &m_bind[index];
    param->buffer_type = MYSQL_TYPE_NULL;
    SafeDeleteCharArray(param->buffer);
    param->buffer_length = 0;
    param->is_null_value = 1;
    SafeDeleteLength(param->length);
}

void MySQLPreparedStatement::SetParameter(uint8 index, std::string const& value)
{
    AssertValidIndex(index);
    m_paramsSet[index] = true;
    MYSQL_BIND* param = &m_bind[index];
    uint32 len = uint32(value.size());

    // Sanity-check: a single prepared-statement string parameter should
    // never exceed 64 KB.  A larger value means the std::string (or the
    // variant that holds it) has been heap-corrupted.
    if (len > 0xFFFF)
    {
        LOG_ERROR("sql.sql", "SetParameter(string): Suspicious length {} at index {} "
            "for statement {} - clamping to 0",
            len, index, m_stmt ? m_stmt->GetIndex() : 0u);
        len = 0;
    }

    param->buffer_type = MYSQL_TYPE_VAR_STRING;
    SafeDeleteCharArray(param->buffer);
    param->buffer = new char[len + 1]; // +1 avoids 0-byte alloc edge case
    param->buffer_length = len;
    param->is_null_value = 0;
    SafeDeleteLength(param->length);
    param->length = new unsigned long(len);

    if (len > 0)
    {
        const char* src = value.c_str();
        if (IsSuspiciousPointer(src))
        {
            LOG_ERROR("sql.sql", "SetParameter(string): Corrupt c_str() pointer "
                "0x{:X} at index {} - skipping memcpy to prevent SIGSEGV",
                reinterpret_cast<std::uintptr_t>(src), index);
        }
        else
        {
            memcpy(param->buffer, src, len);
        }
    }
}

void MySQLPreparedStatement::SetParameter(uint8 index, std::vector<uint8> const& value)
{
    AssertValidIndex(index);
    m_paramsSet[index] = true;
    MYSQL_BIND* param = &m_bind[index];
    uint32 len = uint32(value.size());

    if (len > 0xFFFFFF) // 16 MB sanity limit for BLOB params
    {
        LOG_ERROR("sql.sql", "SetParameter(blob): Suspicious length {} at index {} "
            "for statement {} - clamping to 0",
            len, index, m_stmt ? m_stmt->GetIndex() : 0u);
        len = 0;
    }

    param->buffer_type = MYSQL_TYPE_BLOB;
    SafeDeleteCharArray(param->buffer);
    param->buffer = new char[len + 1]; // +1 avoids 0-byte alloc edge case
    param->buffer_length = len;
    param->is_null_value = 0;
    SafeDeleteLength(param->length);
    param->length = new unsigned long(len);

    if (len > 0)
    {
        const uint8* src = value.data();
        if (IsSuspiciousPointer(src))
        {
            LOG_ERROR("sql.sql", "SetParameter(blob): Corrupt data() pointer "
                "0x{:X} at index {} - skipping memcpy",
                reinterpret_cast<std::uintptr_t>(src), index);
        }
        else
        {
            memcpy(param->buffer, src, len);
        }
    }
}

std::string MySQLPreparedStatement::getQueryString() const
{
    std::string queryString(m_queryString);

    std::size_t pos = 0;

    for (PreparedStatementData const& data : m_stmt->GetParameters())
    {
        pos = queryString.find('?', pos);

        std::string replaceStr = std::visit([&](auto&& data)
        {
            return PreparedStatementData::ToString(data);
        }, data.data);

        queryString.replace(pos, 1, replaceStr);
        pos += replaceStr.length();
    }

    return queryString;
}
