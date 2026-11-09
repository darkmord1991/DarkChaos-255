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

#include "AppenderFile.h"
#include "Log.h"
#include "LogMessage.h"
#include "StringConvert.h"
#include "Timer.h"
#include <algorithm>
#include <filesystem>
#include <system_error>

AppenderFile::AppenderFile(uint8 id, std::string const& name, LogLevel level, AppenderFlags flags, std::vector<std::string_view> const& args) :
    Appender(id, name, level, flags),
    logfile(nullptr),
    _logDir(sLog->GetLogsDir()),
    _maxFileSize(0),
    _maxBackups(0),
    _fileSize(0)
{
    if (args.size() < 4)
    {
        throw InvalidAppenderArgsException(Acore::StringFormat("Log::CreateAppenderFromConfig: Missing file name for appender {}", name));
    }

    _fileName.assign(args[3]);

    std::string mode = "a";
    if (4 < args.size())
    {
        mode.assign(args[4]);
    }

    if (flags & APPENDER_FLAGS_USE_TIMESTAMP)
    {
        std::size_t dot_pos = _fileName.find_last_of('.');
        if (dot_pos != std::string::npos)
        {
            _fileName.insert(dot_pos, sLog->GetLogsTimestamp());
        }
        else
        {
            _fileName += sLog->GetLogsTimestamp();
        }
    }

    // An empty size field means no limit, like 0 ("Server.log,w,0,20" also parses on binaries without MaxBackups).
    if (5 < args.size() && !args[5].empty())
    {
        if (Optional<uint32> size = Acore::StringTo<uint32>(args[5]))
        {
            _maxFileSize = *size;
        }
        else
        {
            throw InvalidAppenderArgsException(Acore::StringFormat("Log::CreateAppenderFromConfig: Invalid size '{}' for appender {}", args[5], name));
        }
    }

    // DarkChaos: optional MaxBackups. Keeps only the newest N backups made by flag 16 (or by the size limit).
    // 0 or absent keeps every backup, as before.
    if (6 < args.size() && !args[6].empty())
    {
        if (Optional<uint32> maxBackups = Acore::StringTo<uint32>(args[6]))
        {
            _maxBackups = *maxBackups;
        }
        else
        {
            throw InvalidAppenderArgsException(Acore::StringFormat(
                "Log::CreateAppenderFromConfig: Invalid backup count '{}' for appender {}", args[6], name));
        }
    }

    _dynamicName = std::string::npos != _fileName.find("%s");
    _backup = (flags & APPENDER_FLAGS_MAKE_FILE_BACKUP) != 0;

    if (!_dynamicName)
    {
        logfile = OpenFile(_fileName, mode, (mode == "w") && _backup);
    }
}

AppenderFile::~AppenderFile()
{
    CloseFile();
}

void AppenderFile::_write(LogMessage const* message)
{
    bool exceedMaxSize = _maxFileSize > 0 && (_fileSize.load() + message->Size()) > _maxFileSize;

    if (_dynamicName)
    {
        char namebuf[ACORE_PATH_MAX];
        snprintf(namebuf, ACORE_PATH_MAX, _fileName.c_str(), message->param1.c_str());

        // always use "a" with dynamic name otherwise it could delete the log we wrote in last _write() call
        FILE* file = OpenFile(namebuf, "a", _backup || exceedMaxSize);
        if (!file)
        {
            return;
        }

        fprintf(file, "%s%s\n", message->prefix.c_str(), message->text.c_str());
        fflush(file);
        _fileSize += uint64(message->Size());
        fclose(file);

        return;
    }
    else if (exceedMaxSize)
    {
        logfile = OpenFile(_fileName, "w", true);
    }

    if (!logfile)
    {
        return;
    }

    fprintf(logfile, "%s%s\n", message->prefix.c_str(), message->text.c_str());
    fflush(logfile);
    _fileSize += uint64(message->Size());
}

FILE* AppenderFile::OpenFile(std::string const& filename, std::string const& mode, bool backup)
{
    std::string fullName(_logDir + filename);
    if (backup)
    {
        CloseFile();
        std::string newName(fullName);
        newName.push_back('.');
        newName.append(LogMessage::getTimeStr(GetEpochTime()));
        std::replace(newName.begin(), newName.end(), ':', '-');
        rename(fullName.c_str(), newName.c_str()); // no error handling... if we couldn't make a backup, just ignore

        if (_maxBackups && !_dynamicName)
        {
            PruneBackups(fullName);
        }
    }

    if (FILE* ret = fopen(fullName.c_str(), mode.c_str()))
    {
        _fileSize = ftell(ret);
        return ret;
    }

    return nullptr;
}

// Deletes the oldest backups of fullName so that _maxBackups remain. A backup is "<file>.<YYYY-MM-DD HH-MM-SS>"
// (see OpenFile); the name sorts in time order. Anything else in the folder is left alone.
void AppenderFile::PruneBackups(std::string const& fullName) const
{
    namespace fs = std::filesystem;

    std::error_code ec;
    fs::path const current(fullName);
    fs::path dir = current.parent_path();
    if (dir.empty())
    {
        dir = ".";
    }

    std::string const prefix = current.filename().string() + '.';
    std::size_t constexpr STAMP_LENGTH = 19; // "2026-11-08 14-51-02"

    std::vector<fs::path> backups;
    for (fs::directory_iterator it(dir, ec), end; !ec && it != end; it.increment(ec))
    {
        std::string const file = it->path().filename().string();
        if (file.size() != prefix.size() + STAMP_LENGTH || file.compare(0, prefix.size(), prefix) != 0)
        {
            continue;
        }

        std::string_view const stamp = std::string_view(file).substr(prefix.size());
        bool const isStamp = std::all_of(stamp.begin(), stamp.end(), [](char c)
        {
            return (c >= '0' && c <= '9') || c == '-' || c == ' ';
        });

        if (isStamp && it->is_regular_file(ec))
        {
            backups.push_back(it->path());
        }
    }

    if (backups.size() <= _maxBackups)
    {
        return;
    }

    std::sort(backups.begin(), backups.end());
    std::size_t const excess = backups.size() - _maxBackups;
    for (std::size_t i = 0; i < excess; ++i)
    {
        fs::remove(backups[i], ec); // best effort, like the rename above
    }
}

void AppenderFile::CloseFile()
{
    if (logfile)
    {
        fclose(logfile);
        logfile = nullptr;
    }
}
