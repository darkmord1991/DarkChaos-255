/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Affero General Public License as published by the
 * Free Software Foundation; either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef _COMMAND_AUDIT_H
#define _COMMAND_AUDIT_H

#include <algorithm>
#include <cctype>
#include <string>
#include <string_view>
#include <vector>

namespace Acore::ChatCommands
{
    // The command text as it goes into the GM command log (commands.gm): the arguments of commands that carry a
    // password are replaced, so the audit trail never holds a secret. Command words may be abbreviated, so they are
    // matched as prefixes.
    inline std::string AuditCommandText(std::string_view command)
    {
        std::vector<std::string_view> words;
        std::size_t pos = 0;
        while (pos < command.size())
        {
            std::size_t const start = command.find_first_not_of(" \t", pos);
            if (start == std::string_view::npos)
                break;

            std::size_t const end = command.find_first_of(" \t", start);
            words.push_back(command.substr(start, end == std::string_view::npos ? std::string_view::npos : end - start));
            pos = end == std::string_view::npos ? command.size() : end;
        }

        auto isPrefixOf = [&words](std::size_t index, std::string_view full, std::size_t minLength)
        {
            if (index >= words.size())
                return false;

            std::string_view word = words[index];
            if (index == 0)
                while (!word.empty() && (word.front() == '.' || word.front() == '!'))
                    word.remove_prefix(1);

            if (word.size() < minLength || word.size() > full.size())
                return false;

            return std::equal(word.begin(), word.end(), full.begin(),
                [](char a, char b) { return std::tolower(static_cast<unsigned char>(a)) == b; });
        };

        std::size_t keep = words.size();
        if (isPrefixOf(0, "account", 3))
        {
            if (isPrefixOf(1, "create", 2))
                keep = 3;  // account create <name> <password>
            else if (isPrefixOf(1, "password", 2))
                keep = 2;  // account password <old> <new> <new>
            else if (isPrefixOf(1, "set", 2) && isPrefixOf(2, "password", 2))
                keep = 4;  // account set password <name> <password> <password>
        }

        if (keep >= words.size())
            return std::string(command);

        std::string audited;
        for (std::size_t index = 0; index < keep; ++index)
        {
            if (index)
                audited.push_back(' ');

            audited.append(words[index]);
        }

        audited.append(" <redacted>");
        return audited;
    }
}

#endif
