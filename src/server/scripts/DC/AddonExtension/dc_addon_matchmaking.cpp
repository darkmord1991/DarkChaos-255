/*
 * Dark Chaos - Group Finder Auto-Matchmaking Queue
 * ================================================
 *
 * LFG-style automatic matchmaking for Mythic 0 dungeons and raids.
 * See dc_addon_matchmaking.h for the design overview.
 *
 * Copyright (C) 2024-2025 Dark Chaos Development Team
 */

#include "dc_addon_matchmaking.h"
#include "dc_addon_namespace.h"
#include "dc_addon_groupfinder_mgr.h"

#include "Common.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "Group.h"
#include "GroupMgr.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Map.h"
#include "GameTime.h"
#include "Config.h"
#include "Log.h"
#include "DBCEnums.h"
#include "DBCStores.h"
#include "Random.h"

#include <algorithm>
#include <array>
#include <map>
#include <set>
#include <tuple>

namespace DCAddon
{
namespace Matchmaking
{
    namespace
    {
        // Role counts required to form a group, per category/raid size.
        struct RoleNeed { uint8 tank; uint8 healer; uint8 dps; };

        RoleNeed GetDungeonNeed()
        {
            return { 1, 1, 3 };
        }

        RoleNeed GetRaidNeed(uint32 raidSize)
        {
            if (raidSize >= 40)
                return { 3, 8, 29 };  // 40-man (classic)
            if (raidSize >= 25)
                return { 2, 6, 17 };  // 25-man
            return { 2, 3, 5 };       // 10-man
        }

        bool ClassCanTank(uint8 c)
        {
            return c == CLASS_WARRIOR || c == CLASS_PALADIN
                || c == CLASS_DEATH_KNIGHT || c == CLASS_DRUID;
        }

        bool ClassCanHeal(uint8 c)
        {
            return c == CLASS_PRIEST || c == CLASS_PALADIN
                || c == CLASS_SHAMAN || c == CLASS_DRUID;
        }

        char const* RoleName(uint8 role)
        {
            switch (role)
            {
                case QROLE_TANK:   return "tank";
                case QROLE_HEALER: return "healer";
                default:           return "dps";
            }
        }
    }

    // ========================================================================
    // INSTANCE CATALOG (dynamic, from MapDifficulty.dbc + Map.dbc)
    // ========================================================================
    namespace InstanceCatalog
    {
        namespace
        {
            bool g_built = false;
            std::mutex g_buildMutex;
            std::vector<DungeonEntry> g_dungeons;
            std::vector<RaidEntry> g_raids;
            std::vector<uint32> g_dungeonMapIds;

            std::string MapName(MapEntry const* m)
            {
                if (m && m->name[0] && m->name[0][0])
                    return std::string(m->name[0]);
                return "Map " + std::to_string(m ? m->MapID : 0u);
            }

            // Lowest LFG MinLevel registered for a map (LFGDungeons.dbc), used to
            // order the dungeon picker by difficulty tier. 0 when the map has no
            // LFG entry (it then sorts first within its expansion, by name).
            uint32 LfgLevelForMap(uint32 mapId)
            {
                uint32 best = 0;
                for (uint32 i = 0; i < sLFGDungeonStore.GetNumRows(); ++i)
                {
                    LFGDungeonEntry const* e = sLFGDungeonStore.LookupEntry(i);
                    if (!e || e->MapID != mapId || !e->MinLevel)
                        continue;
                    if (best == 0 || e->MinLevel < best)
                        best = e->MinLevel;
                }
                return best;
            }

            void Build()
            {
                if (g_built)
                    return;

                std::lock_guard<std::mutex> lock(g_buildMutex);
                if (g_built)
                    return;

                for (uint32 i = 0; i < sMapStore.GetNumRows(); ++i)
                {
                    MapEntry const* m = sMapStore.LookupEntry(i);
                    if (!m)
                        continue;

                    if (m->IsNonRaidDungeon())
                    {
                        // Mythic-capable 5-man = has an EPIC (2) MapDifficulty row.
                        if (GetMapDifficultyData(m->MapID, DUNGEON_DIFFICULTY_EPIC))
                        {
                            DungeonEntry d;
                            d.mapId = m->MapID;
                            d.name = MapName(m);
                            d.expansion = m->Expansion();
                            d.level = LfgLevelForMap(m->MapID);
                            g_dungeons.push_back(d);
                            g_dungeonMapIds.push_back(m->MapID);
                        }
                    }
                    else if (m->IsRaid())
                    {
                        RaidEntry r;
                        r.mapId = m->MapID;
                        r.name = MapName(m);
                        r.expansion = m->Expansion();

                        // WotLK raids carry MapDifficulty rows (10/25 N/H). Classic
                        // and TBC raids have none, so fall back to Map.dbc maxPlayers
                        // as a single fixed-size option (covers 40/25/20/10-man).
                        for (uint8 d = 0; d <= 3; ++d)
                        {
                            if (GetMapDifficultyData(m->MapID, Difficulty(d)))
                            {
                                r.difficulties.push_back(d);
                                uint32 size = (d == 1 || d == 3) ? 25u : 10u;
                                r.options.emplace_back(d, size);
                            }
                        }

                        if (r.options.empty())
                        {
                            uint32 size = m->maxPlayers > 0 ? m->maxPlayers : 10u;
                            r.difficulties.push_back(0);
                            r.options.emplace_back(static_cast<uint8>(0), size);
                        }

                        g_raids.push_back(r);
                    }
                }

                // Order the dungeon picker by expansion, then difficulty tier
                // (LFG min level), then name so the long list reads top-down
                // Classic -> TBC -> WotLK and low -> high level within each.
                std::sort(g_dungeons.begin(), g_dungeons.end(),
                    [](DungeonEntry const& a, DungeonEntry const& b)
                    {
                        if (a.expansion != b.expansion) return a.expansion < b.expansion;
                        if (a.level != b.level) return a.level < b.level;
                        return a.name < b.name;
                    });
                std::sort(g_raids.begin(), g_raids.end(),
                    [](RaidEntry const& a, RaidEntry const& b)
                    {
                        if (a.expansion != b.expansion) return a.expansion < b.expansion;
                        return a.name < b.name;
                    });

                g_built = true;
                LOG_INFO("dc.groupfinder",
                    "Matchmaking catalog built from MapDifficulty: {} mythic dungeons, {} raids",
                    static_cast<uint32>(g_dungeons.size()),
                    static_cast<uint32>(g_raids.size()));
            }
        }

        std::vector<DungeonEntry> const& GetMythicDungeons() { Build(); return g_dungeons; }
        std::vector<RaidEntry> const& GetRaids() { Build(); return g_raids; }
        std::vector<uint32> const& GetMythicDungeonMapIds() { Build(); return g_dungeonMapIds; }

        bool MapSupportsDifficulty(uint32 mapId, uint8 difficulty)
        {
            return GetMapDifficultyData(mapId, Difficulty(difficulty)) != nullptr;
        }
    }

    MatchmakingQueue& MatchmakingQueue::Instance()
    {
        static MatchmakingQueue instance;
        return instance;
    }

    void MatchmakingQueue::LoadConfig()
    {
        _enabled            = sConfigMgr->GetOption<bool>("DC.GroupFinder.Queue.Enabled", true);
        _proposalTimeoutSec = sConfigMgr->GetOption<uint32>("DC.GroupFinder.Queue.ProposalTimeoutSec", 40);
        _matchIntervalMs    = sConfigMgr->GetOption<uint32>("DC.GroupFinder.Queue.MatchIntervalMs", 3000);
        _statusIntervalMs   = sConfigMgr->GetOption<uint32>("DC.GroupFinder.Queue.StatusIntervalMs", 5000);
        _maxQueuesPerPlayer = sConfigMgr->GetOption<uint32>("DC.GroupFinder.Queue.MaxPerPlayer", 3);
        if (_maxQueuesPerPlayer < 1)
            _maxQueuesPerPlayer = 1;
        _debugMinPlayers    = sConfigMgr->GetOption<uint32>("DC.GroupFinder.Queue.DebugMinPlayers", 0);
    }

    // ========================================================================
    // QUEUE ENTRY HELPERS
    // ========================================================================

    QueueEntry* MatchmakingQueue::FindEntry(uint32 guidLow)
    {
        for (QueueEntry& e : _queue)
            if (e.guid.GetCounter() == guidLow)
                return &e;
        return nullptr;
    }

    void MatchmakingQueue::RemoveEntry(uint32 guidLow)
    {
        _queue.erase(std::remove_if(_queue.begin(), _queue.end(),
            [guidLow](QueueEntry const& e) { return e.guid.GetCounter() == guidLow; }),
            _queue.end());
    }

    // ========================================================================
    // PLAYER ACTIONS
    // ========================================================================

    void MatchmakingQueue::JoinQueue(Player* player, uint8 category, uint8 roles,
        uint32 dungeonId, uint8 difficulty, uint32 raidSize)
    {
        if (!player)
            return;

        if (!_enabled)
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "The matchmaking queue is currently disabled.")
                .Send(player);
            return;
        }

        // Validate the solo role selection; party members use their full class
        // capability so the matcher has the most freedom to fill the group.
        uint8 cls = player->getClass();
        if ((roles & QROLE_TANK) && !ClassCanTank(cls))
            roles &= ~QROLE_TANK;
        if ((roles & QROLE_HEALER) && !ClassCanHeal(cls))
            roles &= ~QROLE_HEALER;
        if (roles == 0)
            roles = QROLE_DPS;

        if (category != QUEUE_CAT_DUNGEON && category != QUEUE_CAT_RAID)
            category = QUEUE_CAT_DUNGEON;

        if (category == QUEUE_CAT_RAID)
        {
            if (raidSize != 10 && raidSize != 25 && raidSize != 40)
                raidSize = 10;
            if (dungeonId == 0)
            {
                JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                    .Set("error", "Select a specific raid to queue for.")
                    .Send(player);
                return;
            }
        }
        else
        {
            raidSize = 0;
        }

        // Determine who is being queued: a solo player, or a whole party
        // (only the party leader may queue the group).
        uint32 totalSlots = (category == QUEUE_CAT_RAID) ? raidSize : 5;
        std::vector<Player*> members;
        uint32 groupId = 0;

        if (Group* group = player->GetGroup())
        {
            if (!group->IsLeader(player->GetGUID()))
            {
                JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                    .Set("error", "Only your group leader can queue the group.")
                    .Send(player);
                return;
            }

            groupId = player->GetGUID().GetCounter();
            for (GroupReference* itr = group->GetFirstMember(); itr != nullptr; itr = itr->next())
            {
                Player* m = itr->GetSource();
                if (m && m->IsInWorld())
                    members.push_back(m);
            }

            if (members.size() > totalSlots)
            {
                JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                    .Set("error", "Your group is too large for this content.")
                    .Send(player);
                return;
            }
        }
        else
        {
            members.push_back(player);
        }

        auto fullRoles = [](uint8 c) -> uint8
        {
            uint8 r = QROLE_DPS;
            if (ClassCanTank(c)) r |= QROLE_TANK;
            if (ClassCanHeal(c)) r |= QROLE_HEALER;
            return r;
        };

        bool hitLimit = false;
        {
            std::lock_guard<std::mutex> lock(_mutex);

            for (Player* m : members)
            {
                uint32 g = m->GetGUID().GetCounter();

                if (groupId != 0)
                {
                    // A queued party occupies a single queue slot: replace any
                    // existing entries for the member.
                    RemoveEntry(g);
                }
                else
                {
                    // Solo: refresh the same target, and cap distinct queues so a
                    // player can sit in a few at once (like retail) but not spam.
                    _queue.erase(std::remove_if(_queue.begin(), _queue.end(),
                        [&](QueueEntry const& q)
                        {
                            return q.guid.GetCounter() == g
                                && q.category == category
                                && q.dungeonId == dungeonId
                                && q.difficulty == difficulty
                                && q.raidSize == raidSize;
                        }), _queue.end());

                    uint32 count = 0;
                    for (QueueEntry const& q : _queue)
                        if (q.guid.GetCounter() == g)
                            ++count;
                    if (count >= _maxQueuesPerPlayer)
                    {
                        hitLimit = true;
                        continue;
                    }
                }

                QueueEntry entry;
                entry.guid        = m->GetGUID();
                entry.name        = m->GetName();
                entry.category    = category;
                entry.roles       = (groupId == 0) ? roles : fullRoles(m->getClass());
                entry.dungeonId   = dungeonId;
                entry.difficulty  = difficulty;
                entry.raidSize    = raidSize;
                entry.playerClass = m->getClass();
                entry.level       = m->GetLevel();
                entry.joinedAt    = GameTime::GetGameTime().count();
                entry.groupId     = groupId;
                _queue.push_back(entry);
            }
        }

        if (hitLimit)
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                .Set("error", "You are already in the maximum number of queues ("
                    + std::to_string(_maxQueuesPerPlayer) + ").")
                .Send(player);
            return;
        }

        JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_QUEUE_JOINED)
            .Set("category", static_cast<int32>(category))
            .Set("roles", static_cast<int32>(roles))
            .Set("dungeonId", static_cast<int32>(dungeonId))
            .Set("difficulty", static_cast<int32>(difficulty))
            .Set("raidSize", static_cast<int32>(raidSize))
            .Set("groupSize", static_cast<int32>(members.size()))
            .Send(player);

        LOG_DEBUG("dc.groupfinder", "Matchmaking: {} queued {} member(s) (cat {})",
            player->GetName(), static_cast<uint32>(members.size()), category);

        BroadcastStatus(category);
    }

    void MatchmakingQueue::LeaveQueue(Player* player, bool notify)
    {
        if (!player)
            return;

        uint32 guidLow = player->GetGUID().GetCounter();
        uint8 category = QUEUE_CAT_DUNGEON;
        bool removed = false;

        {
            std::lock_guard<std::mutex> lock(_mutex);
            if (QueueEntry* e = FindEntry(guidLow))
            {
                category = e->category;
                removed = true;

                // Leaving the queue pulls the whole party block, not just the
                // player who clicked (the leader leaves -> the group leaves).
                uint32 groupId = e->groupId;
                if (groupId != 0)
                {
                    _queue.erase(std::remove_if(_queue.begin(), _queue.end(),
                        [groupId](QueueEntry const& q) { return q.groupId == groupId; }),
                        _queue.end());
                }
                else
                {
                    RemoveEntry(guidLow);
                }
            }
        }

        if (notify)
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_QUEUE_LEFT)
                .Set("success", removed)
                .Send(player);
        }

        if (removed)
            BroadcastStatus(category);
    }

    void MatchmakingQueue::SendStatus(Player* player)
    {
        if (!player)
            return;

        uint32 guidLow = player->GetGUID().GetCounter();
        std::lock_guard<std::mutex> lock(_mutex);

        QueueEntry const* self = nullptr;
        for (QueueEntry const& e : _queue)
            if (e.guid.GetCounter() == guidLow)
            {
                self = &e;
                break;
            }

        if (!self)
        {
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_QUEUE_STATUS)
                .Set("queued", false)
                .Send(player);
            return;
        }

        // Count available roles in this player's category for an honest ETA.
        uint32 tanks = 0, healers = 0, dps = 0, total = 0;
        for (QueueEntry const& e : _queue)
        {
            if (e.category != self->category || e.inProposal)
                continue;
            ++total;
            if (e.roles & QROLE_TANK)   ++tanks;
            if (e.roles & QROLE_HEALER) ++healers;
            if (e.roles & QROLE_DPS)    ++dps;
        }

        time_t now = GameTime::GetGameTime().count();
        JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_QUEUE_STATUS)
            .Set("queued", true)
            .Set("category", static_cast<int32>(self->category))
            .Set("waitSeconds", static_cast<int32>(now - self->joinedAt))
            .Set("tanks", static_cast<int32>(tanks))
            .Set("healers", static_cast<int32>(healers))
            .Set("dps", static_cast<int32>(dps))
            .Set("total", static_cast<int32>(total))
            .Send(player);
    }

    void MatchmakingQueue::HandleProposalResponse(Player* player, uint32 proposalId, bool accept)
    {
        if (!player)
            return;

        uint32 guidLow = player->GetGUID().GetCounter();
        bool finalize = false;
        bool dissolve = false;

        {
            std::lock_guard<std::mutex> lock(_mutex);
            auto it = _proposals.find(proposalId);
            if (it == _proposals.end())
                return;

            MatchProposal& prop = it->second;
            auto rit = prop.responses.find(guidLow);
            if (rit == prop.responses.end())
                return;

            rit->second = accept ? 1 : -1;

            if (!accept)
            {
                dissolve = true;
            }
            else
            {
                // All accepted?
                finalize = true;
                for (auto const& [g, resp] : prop.responses)
                    if (resp != 1)
                    {
                        finalize = false;
                        break;
                    }
            }
        }

        if (dissolve)
            DissolveProposal(proposalId, true, "A player declined.");
        else
        {
            // Send progress to everyone in the proposal, then finalize if ready.
            {
                std::lock_guard<std::mutex> lock(_mutex);
                auto it = _proposals.find(proposalId);
                if (it != _proposals.end())
                    SendProposalUpdate(it->second);
            }
            if (finalize)
                FinalizeProposal(proposalId);
        }
    }

    void MatchmakingQueue::OnPlayerLogout(uint32 guidLow)
    {
        // Treat logout during a proposal as a decline; otherwise just dequeue.
        uint32 declineProposal = 0;
        {
            std::lock_guard<std::mutex> lock(_mutex);
            for (auto& [pid, prop] : _proposals)
            {
                if (prop.responses.find(guidLow) != prop.responses.end())
                {
                    prop.responses[guidLow] = -1;
                    declineProposal = pid;
                    break;
                }
            }
            RemoveEntry(guidLow);
        }

        if (declineProposal)
            DissolveProposal(declineProposal, true, "A player left.");
    }

    // ========================================================================
    // UPDATE LOOP
    // ========================================================================

    void MatchmakingQueue::Update(uint32 diff)
    {
        if (!_enabled)
            return;

        _matchTimerMs += diff;
        _statusTimerMs += diff;

        CheckProposalTimeouts();

        if (_matchTimerMs >= _matchIntervalMs)
        {
            _matchTimerMs = 0;
            TryFormMatches();
        }

        if (_statusTimerMs >= _statusIntervalMs)
        {
            _statusTimerMs = 0;
            BroadcastStatus(QUEUE_CAT_DUNGEON);
            BroadcastStatus(QUEUE_CAT_RAID);
        }
    }

    void MatchmakingQueue::TryFormMatches()
    {
        // Form as many matches as possible this tick.
        while (TryFormDungeonMatch()) {}
        while (TryFormRaidMatch()) {}
    }

    // ------------------------------------------------------------------------
    // Role assignment over a candidate set (guidLows) that keeps party members
    // (same groupId) together: a queued party is included all-or-nothing.
    // Returns true and fills `out` (guidLow -> assigned role) when satisfied.
    //
    // Strategy: try each queued party block as a "seed" (must be fully placed)
    // plus solo fillers; then fall back to a pure-solo group. One party block per
    // formed group (multi-party combining is intentionally out of scope).
    // ------------------------------------------------------------------------
    static bool AssembleGroup(std::vector<QueueEntry> const& queue,
        std::vector<uint32> const& candidates, RoleNeed need,
        std::unordered_map<uint32, uint8>& out)
    {
        auto entryFor = [&](uint32 g) -> QueueEntry const*
        {
            for (QueueEntry const& e : queue)
                if (e.guid.GetCounter() == g)
                    return &e;
            return nullptr;
        };

        uint8 totalNeed = need.tank + need.healer + need.dps;

        // Split candidates into party blocks (groupId != 0) and solos.
        std::unordered_map<uint32, std::vector<uint32>> parties;
        std::vector<uint32> solos;
        for (uint32 g : candidates)
        {
            QueueEntry const* e = entryFor(g);
            if (!e)
                continue;
            if (e->groupId != 0)
                parties[e->groupId].push_back(g);
            else
                solos.push_back(g);
        }

        // Place a fixed set of forced members, then fill from a solo pool, to
        // meet `need`. Scarce roles (tank/healer) are filled first per member.
        auto tryAssign = [&](std::vector<uint32> const& forced,
            std::vector<uint32> const& fillPool) -> bool
        {
            out.clear();
            RoleNeed rem = need;
            std::set<uint32> used;

            auto place = [&](uint32 g) -> bool
            {
                if (used.count(g))
                    return false;
                QueueEntry const* e = entryFor(g);
                if (!e)
                    return false;
                if (rem.tank > 0 && (e->roles & QROLE_TANK))
                { out[g] = QROLE_TANK; --rem.tank; used.insert(g); return true; }
                if (rem.healer > 0 && (e->roles & QROLE_HEALER))
                { out[g] = QROLE_HEALER; --rem.healer; used.insert(g); return true; }
                if (rem.dps > 0 && (e->roles & QROLE_DPS))
                { out[g] = QROLE_DPS; --rem.dps; used.insert(g); return true; }
                return false;
            };

            // Every forced (party) member must be placeable.
            for (uint32 g : forced)
                if (!place(g))
                    return false;

            for (uint32 g : fillPool)
            {
                if (rem.tank == 0 && rem.healer == 0 && rem.dps == 0)
                    break;
                place(g);
            }

            return rem.tank == 0 && rem.healer == 0 && rem.dps == 0
                && out.size() == totalNeed;
        };

        // Try the largest party first (so groups get pulled in promptly).
        std::vector<std::pair<uint32, std::vector<uint32>>> partyList(
            parties.begin(), parties.end());
        std::sort(partyList.begin(), partyList.end(),
            [](auto const& a, auto const& b) { return a.second.size() > b.second.size(); });

        for (auto const& kv : partyList)
        {
            if (kv.second.size() > totalNeed)
                continue;  // party larger than the content size
            if (tryAssign(kv.second, solos))
                return true;
        }

        // No party fit (or none queued): pure-solo group.
        static const std::vector<uint32> kNoForced;
        return tryAssign(kNoForced, solos);
    }

    bool MatchmakingQueue::TryFormDungeonMatch()
    {
        std::lock_guard<std::mutex> lock(_mutex);

        RoleNeed need = GetDungeonNeed();

        // Test aid: pop a dungeon at a smaller player count, ignoring the normal
        // 1T/1H/3D composition (everyone counts as DPS). Lets a GM verify the full
        // join -> ready-check -> teleport -> reward flow without 5 real players.
        if (_debugMinPlayers > 0)
            need = { 0, 0, static_cast<uint8>(_debugMinPlayers) };

        // Bucket eligible dungeon entries by specific dungeon; collect "any" pool.
        std::unordered_map<uint32, std::vector<uint32>> byDungeon;  // dungeonId -> guidLows
        std::vector<uint32> anyPool;
        std::set<uint8> difficulties;

        for (QueueEntry const& e : _queue)
        {
            if (e.category != QUEUE_CAT_DUNGEON || e.inProposal)
                continue;
            difficulties.insert(e.difficulty);
        }

        // Try each difficulty independently (players must share difficulty).
        for (uint8 diff : difficulties)
        {
            byDungeon.clear();
            anyPool.clear();

            for (QueueEntry const& e : _queue)
            {
                if (e.category != QUEUE_CAT_DUNGEON || e.inProposal || e.difficulty != diff)
                    continue;
                if (e.dungeonId == 0)
                    anyPool.push_back(e.guid.GetCounter());
                else
                    byDungeon[e.dungeonId].push_back(e.guid.GetCounter());
            }

            // 1) Try specific-dungeon buckets (specific queuers + any-fillers).
            for (auto const& [dungeonId, members] : byDungeon)
            {
                std::vector<uint32> pool = members;
                pool.insert(pool.end(), anyPool.begin(), anyPool.end());

                std::unordered_map<uint32, uint8> assign;
                if (AssembleGroup(_queue, pool, need, assign))
                {
                    std::vector<uint32> picks;
                    for (auto const& [g, r] : assign) picks.push_back(g);
                    CreateProposal(picks, assign, QUEUE_CAT_DUNGEON, dungeonId, diff, 0);
                    return true;
                }
            }

            // 2) Try a pure "any" group; pick a random mythic-capable dungeon
            //    from the dynamic MapDifficulty catalog that every matched
            //    player meets the level requirement for.
            std::unordered_map<uint32, uint8> assign;
            auto const& anyMaps = InstanceCatalog::GetMythicDungeonMapIds();
            if (!anyMaps.empty() && AssembleGroup(_queue, anyPool, need, assign))
            {
                // Lowest level among the matched players gates valid dungeons.
                uint8 minLevel = 255;
                for (auto const& kv : assign)
                    if (QueueEntry* e = FindEntry(kv.first))
                        minLevel = std::min<uint8>(minLevel, e->level);

                std::vector<uint32> eligible;
                for (uint32 mapId : anyMaps)
                {
                    DungeonProgressionRequirements const* req =
                        sObjectMgr->GetAccessRequirement(mapId, DUNGEON_DIFFICULTY_NORMAL);
                    uint8 reqLevel = req ? req->levelMin : 0;
                    if (minLevel >= reqLevel)
                        eligible.push_back(mapId);
                }
                if (eligible.empty())
                    eligible = anyMaps;  // fallback: never block on missing data

                uint32 randomMap = eligible[urand(0, static_cast<uint32>(eligible.size()) - 1)];
                std::vector<uint32> picks;
                for (auto const& [g, r] : assign) picks.push_back(g);
                CreateProposal(picks, assign, QUEUE_CAT_DUNGEON, randomMap, diff, 0);
                return true;
            }
        }

        return false;
    }

    bool MatchmakingQueue::TryFormRaidMatch()
    {
        std::lock_guard<std::mutex> lock(_mutex);

        // Raids must be specific; bucket by (dungeonId, raidSize, difficulty).
        std::map<std::tuple<uint32, uint32, uint8>, std::vector<uint32>> buckets;

        for (QueueEntry const& e : _queue)
        {
            if (e.category != QUEUE_CAT_RAID || e.inProposal || e.dungeonId == 0)
                continue;
            buckets[std::make_tuple(e.dungeonId, e.raidSize, e.difficulty)]
                .push_back(e.guid.GetCounter());
        }

        for (auto const& [key, members] : buckets)
        {
            uint32 map      = std::get<0>(key);
            uint32 raidSize = std::get<1>(key);
            uint8 diff      = std::get<2>(key);

            RoleNeed need = GetRaidNeed(raidSize);
            std::unordered_map<uint32, uint8> assign;
            if (AssembleGroup(_queue, members, need, assign))
            {
                std::vector<uint32> picks;
                for (auto const& [g, r] : assign) picks.push_back(g);
                CreateProposal(picks, assign, QUEUE_CAT_RAID, map, diff, raidSize);
                return true;
            }
        }

        return false;
    }

    void MatchmakingQueue::CreateProposal(std::vector<uint32> const& picksGuidLow,
        std::unordered_map<uint32, uint8> const& roleAssign, uint8 category,
        uint32 dungeonId, uint8 difficulty, uint32 raidSize)
    {
        // (caller holds _mutex)
        MatchProposal prop;
        prop.id         = _nextProposalId++;
        prop.category   = category;
        prop.dungeonId  = dungeonId;
        prop.difficulty = difficulty;
        prop.raidSize   = raidSize;
        prop.createdAt  = GameTime::GetGameTime().count();

        for (uint32 g : picksGuidLow)
        {
            // Mark ALL of this player's entries in-proposal so a multi-queued
            // player can't be pulled into a second proposal at the same time.
            ObjectGuid memberGuid;
            bool found = false;
            for (QueueEntry& e : _queue)
            {
                if (e.guid.GetCounter() == g)
                {
                    e.inProposal = true;
                    if (!found)
                    {
                        memberGuid = e.guid;
                        found = true;
                    }
                }
            }

            if (found)
            {
                prop.members.push_back(memberGuid);
                prop.responses[g] = 0;
                auto rit = roleAssign.find(g);
                prop.assignedRoles[g] = rit != roleAssign.end()
                    ? rit->second : static_cast<uint8>(QROLE_DPS);
            }
        }

        if (prop.members.size() < 2)
            return;  // safety

        uint32 pid = prop.id;
        _proposals[pid] = prop;

        // Notify each member with the ready-check.
        for (ObjectGuid guid : prop.members)
        {
            Player* p = ObjectAccessor::FindConnectedPlayer(guid);
            if (!p)
                continue;

            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_QUEUE_PROPOSAL)
                .Set("proposalId", static_cast<int32>(pid))
                .Set("category", static_cast<int32>(category))
                .Set("dungeonId", static_cast<int32>(dungeonId))
                .Set("difficulty", static_cast<int32>(difficulty))
                .Set("raidSize", static_cast<int32>(raidSize))
                .Set("role", RoleName(prop.assignedRoles[guid.GetCounter()]))
                .Set("size", static_cast<int32>(prop.members.size()))
                .Set("timeout", static_cast<int32>(_proposalTimeoutSec))
                .Send(p);
        }

        LOG_DEBUG("dc.groupfinder", "Matchmaking: proposal #{} formed ({} members)",
            pid, prop.members.size());
    }

    void MatchmakingQueue::SendProposalUpdate(MatchProposal const& proposal)
    {
        // (caller holds _mutex)
        uint32 accepted = 0;
        for (auto const& [g, r] : proposal.responses)
            if (r == 1) ++accepted;

        for (ObjectGuid guid : proposal.members)
        {
            Player* p = ObjectAccessor::FindConnectedPlayer(guid);
            if (!p)
                continue;

            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_QUEUE_PROPOSAL_UPDATE)
                .Set("proposalId", static_cast<int32>(proposal.id))
                .Set("accepted", static_cast<int32>(accepted))
                .Set("total", static_cast<int32>(proposal.members.size()))
                .Send(p);
        }
    }

    void MatchmakingQueue::CheckProposalTimeouts()
    {
        std::vector<uint32> timedOut;
        {
            std::lock_guard<std::mutex> lock(_mutex);
            time_t now = GameTime::GetGameTime().count();
            for (auto const& [pid, prop] : _proposals)
                if (now - prop.createdAt >= static_cast<time_t>(_proposalTimeoutSec))
                    timedOut.push_back(pid);
        }

        for (uint32 pid : timedOut)
            DissolveProposal(pid, true, "Ready check timed out.");
    }

    void MatchmakingQueue::DissolveProposal(uint32 proposalId, bool requeueAccepters,
        char const* reason)
    {
        std::vector<ObjectGuid> toNotify;
        std::set<uint32> requeue;     // accepters to keep in queue
        std::set<uint32> remove;      // decliners/timed-out to drop
        uint8 category = QUEUE_CAT_DUNGEON;

        {
            std::lock_guard<std::mutex> lock(_mutex);
            auto it = _proposals.find(proposalId);
            if (it == _proposals.end())
                return;

            MatchProposal& prop = it->second;
            category = prop.category;
            for (ObjectGuid guid : prop.members)
            {
                uint32 g = guid.GetCounter();
                toNotify.push_back(guid);
                int8 resp = prop.responses.count(g) ? prop.responses[g] : 0;
                if (requeueAccepters && resp == 1)
                    requeue.insert(g);
                else
                    remove.insert(g);
            }

            // Re-open accepters; drop the rest from the queue.
            for (QueueEntry& e : _queue)
                if (requeue.count(e.guid.GetCounter()))
                    e.inProposal = false;

            for (uint32 g : remove)
                RemoveEntry(g);

            _proposals.erase(it);
        }

        for (ObjectGuid guid : toNotify)
        {
            Player* p = ObjectAccessor::FindConnectedPlayer(guid);
            if (!p)
                continue;

            bool stillQueued = requeue.count(guid.GetCounter()) > 0;
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_QUEUE_PROPOSAL_FAILED)
                .Set("proposalId", static_cast<int32>(proposalId))
                .Set("reason", reason ? reason : "Match cancelled.")
                .Set("requeued", stillQueued)
                .Send(p);
        }

        BroadcastStatus(category);
    }

    void MatchmakingQueue::FinalizeProposal(uint32 proposalId)
    {
        MatchProposal prop;
        {
            std::lock_guard<std::mutex> lock(_mutex);
            auto it = _proposals.find(proposalId);
            if (it == _proposals.end())
                return;
            prop = it->second;

            // Remove the matched players from the queue and the proposal.
            for (ObjectGuid guid : prop.members)
                RemoveEntry(guid.GetCounter());
            _proposals.erase(it);
        }

        TeleportAndForm(prop);
    }

    void MatchmakingQueue::TeleportAndForm(MatchProposal const& proposal)
    {
        // Resolve all members; abort if anyone is gone.
        std::vector<Player*> players;
        for (ObjectGuid guid : proposal.members)
        {
            Player* p = ObjectAccessor::FindConnectedPlayer(guid);
            if (p && p->IsInWorld())
                players.push_back(p);
        }

        if (players.size() < proposal.members.size())
        {
            // Someone vanished after accepting; notify the rest.
            for (Player* p : players)
                JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_QUEUE_PROPOSAL_FAILED)
                    .Set("proposalId", static_cast<int32>(proposal.id))
                    .Set("reason", "A player became unavailable.")
                    .Set("requeued", false)
                    .Send(p);
            return;
        }

        // Dissolve any pre-existing party (a queued group) so we can form one
        // fresh group from the full matched roster.
        for (Player* p : players)
            if (p->GetGroup())
                p->RemoveFromGroup();

        // Create the group with the first member as leader.
        Player* leader = players.front();
        Group* group = new Group();
        if (!group->Create(leader))
        {
            delete group;
            return;
        }
        sGroupMgr->AddGroup(group);

        // Raids must be converted before adding past 5 members.
        if (proposal.category == QUEUE_CAT_RAID)
            group->ConvertToRaid();

        for (size_t i = 1; i < players.size(); ++i)
            group->AddMember(players[i]);

        // Apply difficulty.
        if (proposal.category == QUEUE_CAT_RAID)
            group->SetRaidDifficulty(Difficulty(proposal.difficulty));
        else
            group->SetDungeonDifficulty(Difficulty(proposal.difficulty));

        // Look up the instance entrance.
        AreaTriggerTeleport const* at = sObjectMgr->GetMapEntranceTrigger(proposal.dungeonId);

        for (Player* p : players)
        {
            // Set per-player loot/role nothing extra needed; teleport in.
            if (at)
                p->TeleportTo(at->target_mapId, at->target_X, at->target_Y,
                              at->target_Z, at->target_Orientation);

            // Grant the daily Group Finder reward (daily-limited server-side).
            if (sGroupFinderMgr.CanReceiveReward(p))
                sGroupFinderMgr.GiveReward(p);

            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_QUEUE_LEFT)
                .Set("success", true)
                .Set("matched", true)
                .Send(p);
        }

        if (!at)
        {
            for (Player* p : players)
                JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                    .Set("error", "Could not find the instance entrance; please use a summon or portal.")
                    .Send(p);
        }

        LOG_INFO("dc.groupfinder", "Matchmaking: formed group of {} for map {} (diff {})",
            players.size(), proposal.dungeonId, proposal.difficulty);
    }

    void MatchmakingQueue::BroadcastStatus(uint8 category)
    {
        std::vector<ObjectGuid> recipients;
        uint32 tanks = 0, healers = 0, dps = 0, total = 0;

        {
            std::lock_guard<std::mutex> lock(_mutex);
            for (QueueEntry const& e : _queue)
            {
                if (e.category != category)
                    continue;
                if (!e.inProposal)
                {
                    ++total;
                    if (e.roles & QROLE_TANK)   ++tanks;
                    if (e.roles & QROLE_HEALER) ++healers;
                    if (e.roles & QROLE_DPS)    ++dps;
                }
                recipients.push_back(e.guid);
            }
        }

        time_t now = GameTime::GetGameTime().count();
        for (ObjectGuid guid : recipients)
        {
            Player* p = ObjectAccessor::FindConnectedPlayer(guid);
            if (!p)
                continue;

            int32 wait = 0;
            {
                std::lock_guard<std::mutex> lock(_mutex);
                if (QueueEntry const* e = FindEntry(guid.GetCounter()))
                    wait = static_cast<int32>(now - e->joinedAt);
            }

            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_QUEUE_STATUS)
                .Set("queued", true)
                .Set("category", static_cast<int32>(category))
                .Set("waitSeconds", wait)
                .Set("tanks", static_cast<int32>(tanks))
                .Set("healers", static_cast<int32>(healers))
                .Set("dps", static_cast<int32>(dps))
                .Set("total", static_cast<int32>(total))
                .Send(p);
        }
    }

}  // namespace Matchmaking
}  // namespace DCAddon

// ============================================================================
// MESSAGE HANDLERS
// ============================================================================

namespace DCAddon
{
namespace Matchmaking
{
    static void HandleQueueJoin(Player* player, const ParsedMessage& msg)
    {
        JsonValue json = GetJsonData(msg);
        uint8 category   = static_cast<uint8>(json["category"].IsNumber() ? json["category"].AsInt32() : QUEUE_CAT_DUNGEON);
        uint8 roles      = static_cast<uint8>(json["roles"].IsNumber() ? json["roles"].AsInt32() : QROLE_DPS);
        uint32 dungeonId = static_cast<uint32>(json["dungeonId"].IsNumber() ? json["dungeonId"].AsInt32() : 0);
        uint8 difficulty = static_cast<uint8>(json["difficulty"].IsNumber() ? json["difficulty"].AsInt32() : 0);
        uint32 raidSize  = static_cast<uint32>(json["raidSize"].IsNumber() ? json["raidSize"].AsInt32() : 0);

        sMatchmakingQueue.JoinQueue(player, category, roles, dungeonId, difficulty, raidSize);
    }

    static void HandleQueueLeave(Player* player, const ParsedMessage& /*msg*/)
    {
        sMatchmakingQueue.LeaveQueue(player, true);
    }

    static void HandleQueueStatusRequest(Player* player, const ParsedMessage& /*msg*/)
    {
        sMatchmakingQueue.SendStatus(player);
    }

    static void HandleQueueProposalResponse(Player* player, const ParsedMessage& msg)
    {
        JsonValue json = GetJsonData(msg);
        uint32 proposalId = static_cast<uint32>(json["proposalId"].IsNumber() ? json["proposalId"].AsInt32() : 0);
        bool accept = json["accept"].IsBool() ? json["accept"].AsBool()
            : (json["accept"].IsNumber() ? json["accept"].AsInt32() != 0 : false);

        if (proposalId > 0)
            sMatchmakingQueue.HandleProposalResponse(player, proposalId, accept);
    }

    // Send the dynamic mythic dungeon + raid catalog (from MapDifficulty/Map.dbc)
    // so the client pickers can list every available instance, grouped by era.
    static void HandleGetQueueCatalog(Player* player, const ParsedMessage& /*msg*/)
    {
        JsonValue dungeons;
        dungeons.SetArray();
        for (auto const& d : InstanceCatalog::GetMythicDungeons())
        {
            JsonValue o;
            o.SetObject();
            o.Set("mapId", JsonValue(static_cast<int32>(d.mapId)));
            o.Set("name", JsonValue(d.name));
            o.Set("expansion", JsonValue(static_cast<int32>(d.expansion)));
            o.Set("level", JsonValue(static_cast<int32>(d.level)));
            dungeons.Push(o);
        }

        JsonValue raids;
        raids.SetArray();
        for (auto const& r : InstanceCatalog::GetRaids())
        {
            JsonValue o;
            o.SetObject();
            o.Set("mapId", JsonValue(static_cast<int32>(r.mapId)));
            o.Set("name", JsonValue(r.name));
            o.Set("expansion", JsonValue(static_cast<int32>(r.expansion)));

            JsonValue opts;
            opts.SetArray();
            for (auto const& pr : r.options)
            {
                JsonValue oo;
                oo.SetObject();
                oo.Set("d", JsonValue(static_cast<int32>(pr.first)));
                oo.Set("s", JsonValue(static_cast<int32>(pr.second)));
                opts.Push(oo);
            }
            o.Set("options", opts);
            raids.Push(o);
        }

        JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_QUEUE_CATALOG)
            .Set("dungeons", JsonValue(dungeons.Encode()))
            .Set("raids", JsonValue(raids.Encode()))
            .Send(player);
    }

    void RegisterMatchmakingHandlers()
    {
        sMatchmakingQueue.LoadConfig();
        DC_REGISTER_HANDLER(Module::GROUP_FINDER, Opcode::GroupFinder::CMSG_QUEUE_JOIN, HandleQueueJoin);
        DC_REGISTER_HANDLER(Module::GROUP_FINDER, Opcode::GroupFinder::CMSG_QUEUE_LEAVE, HandleQueueLeave);
        DC_REGISTER_HANDLER(Module::GROUP_FINDER, Opcode::GroupFinder::CMSG_QUEUE_STATUS_REQUEST, HandleQueueStatusRequest);
        DC_REGISTER_HANDLER(Module::GROUP_FINDER, Opcode::GroupFinder::CMSG_QUEUE_PROPOSAL_RESPONSE, HandleQueueProposalResponse);
        DC_REGISTER_HANDLER(Module::GROUP_FINDER, Opcode::GroupFinder::CMSG_GET_QUEUE_CATALOG, HandleGetQueueCatalog);
    }

}  // namespace Matchmaking
}  // namespace DCAddon

// ============================================================================
// SCRIPTS
// ============================================================================

class MatchmakingWorldScript : public WorldScript
{
public:
    MatchmakingWorldScript() : WorldScript("MatchmakingWorldScript") {}

    void OnUpdate(uint32 diff) override
    {
        // sMatchmakingQueue already expands to the fully-qualified Instance().
        sMatchmakingQueue.Update(diff);
    }
};

class MatchmakingPlayerScript : public PlayerScript
{
public:
    MatchmakingPlayerScript() : PlayerScript("MatchmakingPlayerScript") {}

    void OnPlayerLogout(Player* player) override
    {
        if (player)
            sMatchmakingQueue.OnPlayerLogout(player->GetGUID().GetCounter());
    }
};

void AddSC_dc_addon_matchmaking()
{
    DCAddon::Matchmaking::RegisterMatchmakingHandlers();
    new MatchmakingWorldScript();
    new MatchmakingPlayerScript();
}
