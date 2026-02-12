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

#include "DatabaseWorker.h"
#include "PCQueue.h"
#include "Log.h"
#include "SQLOperation.h"
#include <cstdint>

DatabaseWorker::DatabaseWorker(ProducerConsumerQueue<SQLOperation*>* newQueue, MySQLConnection* connection)
{
    _connection = connection;
    _queue = newQueue;
    _workerThread = std::thread(&DatabaseWorker::WorkerThread, this);
}

DatabaseWorker::~DatabaseWorker()
{
    _workerThread.join();
}

void DatabaseWorker::WorkerThread()
{
    if (!_queue)
        return;

    for (;;)
    {
        SQLOperation* operation = nullptr;

        _queue->WaitAndPop(operation);

        if (!operation)
            return;

        std::uintptr_t const opAddr = reinterpret_cast<std::uintptr_t>(operation);
        if (opAddr < 0x10000u)
        {
            LOG_FATAL("sql.driver", "DatabaseWorker::WorkerThread: popped invalid SQLOperation* 0x{:X} - exiting worker thread to avoid crash", opAddr);
            return;
        }

        if (!operation->IsAlive())
        {
            LOG_ERROR("sql.driver", "DatabaseWorker::WorkerThread: SQLOperation '{}' at 0x{:X} is not alive (magic=0x{:08X}) - destroying without executing",
                operation->GetDebugName(), opAddr, operation->GetDebugMagic());
            operation->Destroy();
            continue;
        }

        operation->SetConnection(_connection);
        operation->call();
        operation->Destroy();
    }
}
