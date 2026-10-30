/*
 * Dark Chaos - Path of Chaos Addon Handler (PATH)
 * ===============================================
 *
 * The wire side of DC/Progression/Path: the DC-Path addon asks for the book and for this
 * account's state, and claims completed tasks. Progress is pushed as it happens.
 *
 * The book is static data: the client keeps it in saved variables and names the revision it
 * holds, so a login normally costs one short exchange. It is sent in pages because the chat
 * transport splits anything long into 245-byte whispers, and a page that small also leaves
 * the client something to show while the rest arrives.
 *
 * Copyright (C) 2026 Dark Chaos Development Team
 */

#include "dc_addon_namespace.h"
#include "DC/Progression/Path/DCPath.h"
#include "Log.h"
#include "Player.h"
#include "WorldSession.h"

#include <algorithm>
#include <string>
#include <vector>

namespace DCAddon
{
namespace Path
{
    using namespace DarkChaos::Path;

    static constexpr uint32 TASKS_PER_PAGE = 20;

    static JsonValue BuildCategory(Category const& category)
    {
        JsonValue json;
        json.SetObject();
        json.Set("i", JsonValue(category.id));
        json.Set("n", JsonValue(category.name));
        json.Set("d", JsonValue(category.description));
        json.Set("k", JsonValue(category.icon));
        return json;
    }

    static JsonValue BuildTask(Task const& task)
    {
        JsonValue json;
        json.SetObject();
        json.Set("i", JsonValue(task.id));
        json.Set("c", JsonValue(task.categoryId));
        json.Set("n", JsonValue(task.name));
        json.Set("d", JsonValue(task.description));
        json.Set("k", JsonValue(task.icon));
        json.Set("y", JsonValue(uint32(task.objective)));
        json.Set("g", JsonValue(task.target));
        json.Set("v", JsonValue(task.prevTaskId));
        json.Set("p", JsonValue(task.reward.points));

        if (task.reward.itemId)
        {
            json.Set("ri", JsonValue(task.reward.itemId));
            json.Set("rn", JsonValue(task.reward.itemCount));
        }

        if (task.reward.collectionType)
        {
            json.Set("ct", JsonValue(uint32(task.reward.collectionType)));
            json.Set("ce", JsonValue(task.reward.collectionEntry));
        }

        return json;
    }

    static void SendCatalog(Player* player, Catalog const& catalog)
    {
        uint32 const taskCount = uint32(catalog.tasks.size());
        uint32 const pages = std::max<uint32>(1, (taskCount + TASKS_PER_PAGE - 1) / TASKS_PER_PAGE);

        for (uint32 page = 0; page < pages; ++page)
        {
            uint32 const first = page * TASKS_PER_PAGE;
            uint32 const last = std::min(taskCount, first + TASKS_PER_PAGE);

            JsonValue tasks;
            tasks.SetArray(last - first);
            for (uint32 index = first; index < last; ++index)
                tasks.Push(BuildTask(catalog.tasks[index]));

            JsonMessage msg(Module::PATH, Opcode::Path::SMSG_CATALOG);
            msg.Set("rev", catalog.revision);
            msg.Set("page", page + 1);
            msg.Set("pages", pages);

            // Categories ride on the first page so the book never draws a task without one.
            if (!page)
            {
                JsonValue categories;
                categories.SetArray(catalog.categories.size());
                for (Category const& category : catalog.categories)
                    categories.Push(BuildCategory(category));
                msg.Set("c", std::move(categories));
            }

            msg.Set("t", std::move(tasks));
            msg.Send(player);
        }
    }

    static JsonValue BuildProgress(std::vector<ProgressEntry> const& entries)
    {
        JsonValue list;
        list.SetArray(entries.size());
        for (ProgressEntry const& entry : entries)
        {
            JsonValue row;
            row.SetArray(3);
            row.Push(JsonValue(entry.taskId));
            row.Push(JsonValue(entry.progress));
            row.Push(JsonValue(uint32(entry.flags)));
            list.Push(std::move(row));
        }
        return list;
    }

    static void SendClaimResult(Player* player, ClaimOutcome const& outcome)
    {
        JsonValue ids;
        ids.SetArray(outcome.claimed.size());
        for (uint32 const taskId : outcome.claimed)
            ids.Push(JsonValue(taskId));

        JsonMessage msg(Module::PATH, Opcode::Path::SMSG_CLAIM_RESULT);
        msg.Set("ok", outcome.ok);
        msg.Set("msg", outcome.message);
        msg.Set("points", outcome.points);
        msg.Set("paid", outcome.paid);
        msg.Set("ids", std::move(ids));
        msg.Send(player);

        if (outcome.ok)
            LOG_DEBUG("scripts.dc", "PATH: {} claimed {} task(s) for {} points (balance {})",
                player->GetGUID().ToString(), outcome.claimed.size(), outcome.paid, outcome.points);
    }

    // ------------------------------------------------------------------------
    // Inbound
    // ------------------------------------------------------------------------
    static void HandleGetCatalog(Player* player, ParsedMessage const& msg)
    {
        if (!player)
            return;

        CatalogPtr const catalog = sPathMgr->GetCatalog();
        if (!catalog)
        {
            SendState(player);
            return;
        }

        uint32 const held = GetJsonData(msg)["rev"].AsUInt32();
        if (held == catalog->revision)
        {
            JsonMessage current(Module::PATH, Opcode::Path::SMSG_CATALOG_CURRENT);
            current.Set("rev", catalog->revision);
            current.Send(player);
            return;
        }

        SendCatalog(player, *catalog);
    }

    static void HandleGetState(Player* player, ParsedMessage const& /*msg*/)
    {
        sPathMgr->RequestState(player);
    }

    static void HandleClaim(Player* player, ParsedMessage const& msg)
    {
        if (!player)
            return;

        SendClaimResult(player, sPathMgr->Claim(player, GetJsonData(msg)["id"].AsUInt32()));
    }

    static void HandleClaimAll(Player* player, ParsedMessage const& /*msg*/)
    {
        if (!player)
            return;

        SendClaimResult(player, sPathMgr->ClaimAll(player));
    }

    static void RegisterPathHandlers()
    {
        // Routed even with DCPath.Enable off, so the client hears enabled=false from the state
        // reply rather than the router's generic "module disabled" error.
        MessageRouter::Instance().SetModuleEnabled(Module::PATH, true);

        DC_REGISTER_HANDLER(Module::PATH, Opcode::Path::CMSG_GET_CATALOG, HandleGetCatalog);
        DC_REGISTER_HANDLER(Module::PATH, Opcode::Path::CMSG_GET_STATE, HandleGetState);
        DC_REGISTER_HANDLER(Module::PATH, Opcode::Path::CMSG_CLAIM, HandleClaim);
        DC_REGISTER_HANDLER(Module::PATH, Opcode::Path::CMSG_CLAIM_ALL, HandleClaimAll);
    }
} // namespace Path
} // namespace DCAddon

namespace DarkChaos
{
namespace Path
{
    void SendTaskUpdates(Player* player, std::vector<ProgressEntry> const& updates, uint32 points)
    {
        DCAddon::JsonMessage msg(DCAddon::Module::PATH, DCAddon::Opcode::Path::SMSG_TASK_UPDATE);
        msg.Set("points", points);
        msg.Set("u", DCAddon::Path::BuildProgress(updates));
        msg.Send(player);
    }

    void SendState(Player* player)
    {
        if (!player || !player->GetSession())
            return;

        AccountSnapshot const snapshot = sPathMgr->GetSnapshot(player->GetSession()->GetAccountId());

        DCAddon::JsonMessage msg(DCAddon::Module::PATH, DCAddon::Opcode::Path::SMSG_STATE);
        msg.Set("enabled", sPathMgr->IsEnabled());
        msg.Set("points", snapshot.points);
        msg.Set("earned", snapshot.earned);
        msg.Set("t", DCAddon::Path::BuildProgress(snapshot.tasks));
        msg.Send(player);
    }
}
}

void AddSC_dc_addon_path()
{
    DCAddon::Path::RegisterPathHandlers();
}
