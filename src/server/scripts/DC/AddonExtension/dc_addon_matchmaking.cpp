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
#include "dc_addon_utils.h"
#include "dc_addon_groupfinder_mgr.h"

#include "Common.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "Group.h"
#include "GroupMgr.h"
#include "ObjectAccessor.h"
#include "WorldSession.h"
#include "ObjectMgr.h"
#include "Map.h"
#include "GameTime.h"
#include "Config.h"
#include "Log.h"
#include "DBCEnums.h"
#include "DBCStores.h"
#include "Random.h"
#include "LFGMgr.h"
#include "World.h"
#include "Chat.h"
#include "SpellAuras.h"
#include "AchievementMgr.h"
#include "InstanceScript.h"

#include <algorithm>
#include <array>
#include <map>
#include <set>
#include <tuple>
#include "dc_update_profiler.h"

namespace DCAddon
{
namespace Matchmaking
{
    namespace
    {
        // Role counts required to form a group, per category/raid size.
        // (RoleNeed itself is declared in the header -- RecruitBotFillers takes one.)
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

        // Class->role CAPABILITY is centralized in DCAddon::Utils::ClassCanTank/
        // ClassCanHeal (static class-based; not the player's current spec role).

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

            // Lowest LFG MinLevel registered for a map+difficulty (LFGDungeons.dbc).
            // 0 when the map has no matching LFG entry -- custom DC instances have
            // none at all, so this is only ever a fallback for the DB access rows.
            uint32 LfgLevelForMap(uint32 mapId, uint32 difficulty)
            {
                uint32 best = 0;
                for (uint32 i = 0; i < sLFGDungeonStore.GetNumRows(); ++i)
                {
                    LFGDungeonEntry const* e = sLFGDungeonStore.LookupEntry(i);
                    if (!e || e->MapID != mapId || !e->MinLevel)
                        continue;
                    if (e->Difficulty != difficulty)
                        continue;
                    if (best == 0 || e->MinLevel < best)
                        best = e->MinLevel;
                }
                return best;
            }

            // Highest LFG MaxLevel registered for a map+difficulty. 0 when the
            // map has no LFG entry, which means "no upper bound".
            uint32 LfgMaxLevelForMap(uint32 mapId, uint32 difficulty)
            {
                uint32 best = 0;
                for (uint32 i = 0; i < sLFGDungeonStore.GetNumRows(); ++i)
                {
                    LFGDungeonEntry const* e = sLFGDungeonStore.LookupEntry(i);
                    if (!e || e->MapID != mapId || !e->MaxLevel)
                        continue;
                    if (e->Difficulty != difficulty)
                        continue;
                    if (e->MaxLevel > best)
                        best = e->MaxLevel;
                }
                return best;
            }

            // Entry requirements for one dungeon difficulty. dungeon_access_template
            // is authoritative (it is the table the core itself gates entry on, and
            // it covers the custom DC instances that have no LFGDungeons.dbc row);
            // the DBC only fills in maps the DB has not described.
            void FillDifficultyRequirement(uint32 mapId, uint8 difficulty,
                uint32& outLevel, uint32& outItemLevel, uint32& outMaxLevel)
            {
                outLevel = 0;
                outItemLevel = 0;
                outMaxLevel = 0;

                if (DungeonProgressionRequirements const* req =
                    sObjectMgr->GetAccessRequirement(mapId, Difficulty(difficulty)))
                {
                    outLevel = req->levelMin;
                    outItemLevel = req->reqItemLevel;
                    outMaxLevel = req->levelMax;
                }

                if (outLevel == 0)
                    outLevel = LfgLevelForMap(mapId, difficulty);
                // dungeon_access_template leaves max_level at 0 across the whole
                // table here, so in practice the bracket top always comes from
                // LFGDungeons.dbc.
                if (outMaxLevel == 0)
                    outMaxLevel = LfgMaxLevelForMap(mapId, difficulty);
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

                            for (uint8 diff = 0; diff < DUNGEON_DIFFICULTY_COUNT; ++diff)
                                FillDifficultyRequirement(m->MapID, diff,
                                    d.minLevel[diff], d.minItemLevel[diff], d.maxLevel[diff]);

                            // Heroic/Mythic inherit the Normal requirement when the
                            // DB describes only the base difficulty, so a dungeon is
                            // never silently ungated at the higher difficulties.
                            for (uint8 diff = 1; diff < DUNGEON_DIFFICULTY_COUNT; ++diff)
                                if (d.minLevel[diff] == 0)
                                    d.minLevel[diff] = d.minLevel[diff - 1];

                            d.level = d.minLevel[DUNGEON_DIFFICULTY_NORMAL];
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

        namespace
        {
            DungeonEntry const* FindDungeon(uint32 mapId)
            {
                Build();
                for (DungeonEntry const& d : g_dungeons)
                    if (d.mapId == mapId)
                        return &d;
                return nullptr;
            }
        }

        uint32 GetDungeonMinLevel(uint32 mapId, uint8 difficulty)
        {
            if (difficulty >= DUNGEON_DIFFICULTY_COUNT)
                return 0;
            DungeonEntry const* d = FindDungeon(mapId);
            return d ? d->minLevel[difficulty] : 0;
        }

        uint32 GetDungeonMinItemLevel(uint32 mapId, uint8 difficulty)
        {
            if (difficulty >= DUNGEON_DIFFICULTY_COUNT)
                return 0;
            DungeonEntry const* d = FindDungeon(mapId);
            return d ? d->minItemLevel[difficulty] : 0;
        }

        uint32 GetDungeonMaxLevel(uint32 mapId, uint8 difficulty)
        {
            if (difficulty >= DUNGEON_DIFFICULTY_COUNT)
                return 0;
            DungeonEntry const* d = FindDungeon(mapId);
            return d ? d->maxLevel[difficulty] : 0;
        }

        bool MapSupportsDifficulty(uint32 mapId, uint8 difficulty)
        {
            return GetMapDifficultyData(mapId, Difficulty(difficulty)) != nullptr;
        }
    }

    // ========================================================================
    // BOT PROVIDER REGISTRY
    // ========================================================================

    namespace
    {
        BotProvider g_botProvider;
    }

    void RegisterBotProvider(BotProvider const& provider)
    {
        g_botProvider = provider;
        LOG_INFO("dc.groupfinder", "Matchmaking: bot backfill provider {}",
            (provider.IsBot && provider.Recruit) ? "registered" : "cleared");
    }

    bool HasBotProvider()
    {
        return g_botProvider.IsBot != nullptr && g_botProvider.Recruit != nullptr;
    }

    namespace
    {
        bool PlayerIsBot(Player* player)
        {
            return player && g_botProvider.IsBot && g_botProvider.IsBot(player);
        }
    }

    MatchmakingQueue& MatchmakingQueue::Instance()
    {
        static MatchmakingQueue instance;
        return instance;
    }

    // Called once at script registration and again from every
    // World::LoadConfigSettings (startup and `.reload config`). The lock is
    // taken because Update()/JoinQueue read these fields, and a reload is
    // driven from a command rather than the match tick.
    //
    // Values are re-read live, so a shortened ProposalTimeoutSec can expire
    // proposals already pending. One exception: an in-progress vote kick keeps
    // the deadline it was opened with, since BootState::cancelTime is stamped
    // at StartBoot rather than recomputed.
    void MatchmakingQueue::LoadConfig()
    {
        std::lock_guard<std::mutex> lock(_mutex);

        _enabled            = sConfigMgr->GetOption<bool>("DC.GroupFinder.Queue.Enabled", true);
        _proposalTimeoutSec = sConfigMgr->GetOption<uint32>("DC.GroupFinder.Queue.ProposalTimeoutSec", 40);
        _matchIntervalMs    = sConfigMgr->GetOption<uint32>("DC.GroupFinder.Queue.MatchIntervalMs", 3000);
        _statusIntervalMs   = sConfigMgr->GetOption<uint32>("DC.GroupFinder.Queue.StatusIntervalMs", 5000);
        _maxQueuesPerPlayer = sConfigMgr->GetOption<uint32>("DC.GroupFinder.Queue.MaxPerPlayer", 3);
        if (_maxQueuesPerPlayer < 1)
            _maxQueuesPerPlayer = 1;
        _debugMinPlayers    = sConfigMgr->GetOption<uint32>("DC.GroupFinder.Queue.DebugMinPlayers", 0);

        _botsEnabled           = sConfigMgr->GetOption<bool>("DC.GroupFinder.Queue.Bots.Enabled", true);
        _botBackfillAfterSec   = sConfigMgr->GetOption<uint32>("DC.GroupFinder.Queue.Bots.BackfillAfterSec", 60);
        _botsMaxPerGroup       = sConfigMgr->GetOption<uint32>("DC.GroupFinder.Queue.Bots.MaxPerGroup", 4);
        _botsForRaids          = sConfigMgr->GetOption<bool>("DC.GroupFinder.Queue.Bots.AllowRaids", false);
        _botLevelSlack         = sConfigMgr->GetOption<uint32>("DC.GroupFinder.Queue.Bots.LevelSlack", 5);

        _applyRandomCooldown   = sConfigMgr->GetOption<bool>("DC.GroupFinder.Queue.RandomCooldown", true);
        _applyLuckOfTheDraw    = sConfigMgr->GetOption<bool>("DC.GroupFinder.Queue.LuckOfTheDraw", true);
        _rewardOnCompletion    = sConfigMgr->GetOption<bool>("DC.GroupFinder.Queue.RewardOnCompletion", true);
        _deserterMinGroupSize  = static_cast<uint8>(std::clamp<uint32>(
            sConfigMgr->GetOption<uint32>("DC.GroupFinder.Queue.DeserterMinGroupSize", 3), 1u, 40u));

        _maxLevelLock      = sConfigMgr->GetOption<bool>("DC.GroupFinder.Queue.MaxLevelLock", true);
        _levelBracketCap   = sConfigMgr->GetOption<uint32>("DC.GroupFinder.Queue.LevelBracketCap", 80);
        _levelBracketWidth = sConfigMgr->GetOption<uint32>("DC.GroupFinder.Queue.LevelBracketWidth", 15);

        _voteKickEnabled  = sConfigMgr->GetOption<bool>("DC.GroupFinder.Queue.VoteKick.Enabled", true);
        _bootDurationSec  = sConfigMgr->GetOption<uint32>("DC.GroupFinder.Queue.VoteKick.DurationSec", 120);
        _bootVotesNeeded  = static_cast<uint8>(std::clamp<uint32>(
            sConfigMgr->GetOption<uint32>("DC.GroupFinder.Queue.VoteKick.VotesNeeded", 3), 1u, 40u));
        // -1 (the default) means "inherit LFG.MaxKickCount". That stock value
        // CANNOT be read here: LoadConfig runs from ScriptMgr::Initialize,
        // before sWorld's ConfigValueCache is filled, and GetConfigValue
        // asserts on an unset entry. MaxKicks() resolves it at use time.
        _bootMaxKicks = std::clamp<int32>(
            sConfigMgr->GetOption<int32>("DC.GroupFinder.Queue.VoteKick.MaxKicks", -1), -1, 10);
    }

    // Resolved lazily -- see LoadConfig.
    uint8 MatchmakingQueue::MaxKicks() const
    {
        if (_bootMaxKicks >= 0)
            return static_cast<uint8>(_bootMaxKicks);
        return static_cast<uint8>(sWorld->getIntConfig(CONFIG_LFG_MAX_KICK_COUNT));
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

    // ------------------------------------------------------------------------
    // Entry eligibility, in the same terms the instance door uses.
    //
    // DungeonProgressionRequirements is the table MapMgr::PlayerCannotEnter
    // enforces through Player::Satisfy, so building the lock reason from it
    // (rather than from a parallel rule set) is what keeps the queue from ever
    // forming a group that the map then refuses. Each check maps onto one of
    // the stock LFG_LOCKSTATUS_* reasons.
    // ------------------------------------------------------------------------
    // A dungeon is "out-levelled" once the player is past the top of its
    // bracket. The player's level is first clamped to _levelBracketCap: the
    // WotLK bracket data stops at 80, so without the clamp every character
    // above 80 on this 255 server would out-level literally every dungeon.
    bool MatchmakingQueue::IsWithinLevelBracket(Player* player, uint32 mapId,
        uint8 difficulty) const
    {
        if (!player)
            return false;

        uint32 maxLevel = InstanceCatalog::GetDungeonMaxLevel(mapId, difficulty);
        if (maxLevel == 0)
        {
            // No LFGDungeons MaxLevel for this map. Treating that as "no upper
            // bound" is what let a level 80 be rolled into Blackrock Spire
            // (entry level 45, no LFG row), so derive a bracket top from the
            // entry level instead. Heroic/Mythic entry levels are already 70-80,
            // so a derived top of +15 leaves max-level content reachable.
            uint32 minLevel = InstanceCatalog::GetDungeonMinLevel(mapId, difficulty);
            if (minLevel == 0 || _levelBracketWidth == 0)
                return true;   // genuinely no data to reason from
            maxLevel = minLevel + _levelBracketWidth;
        }

        uint32 level = player->GetLevel();
        if (_levelBracketCap && level > _levelBracketCap)
            level = _levelBracketCap;

        return level <= maxLevel;
    }

    // The bracket top actually used for a dungeon, derived when the DBC has
    // none. Kept next to IsWithinLevelBracket so the lock text and the client
    // label never disagree with the check.
    uint32 MatchmakingQueue::EffectiveMaxLevel(uint32 mapId, uint8 difficulty) const
    {
        uint32 maxLevel = InstanceCatalog::GetDungeonMaxLevel(mapId, difficulty);
        if (maxLevel != 0)
            return maxLevel;

        uint32 minLevel = InstanceCatalog::GetDungeonMinLevel(mapId, difficulty);
        if (minLevel == 0 || _levelBracketWidth == 0)
            return 0;

        return minLevel + _levelBracketWidth;
    }

    std::string MatchmakingQueue::GetEntryLockReason(Player* player, uint32 mapId,
        uint8 difficulty, bool isPartyLeader)
    {
        if (!player)
            return "Player unavailable";

        if (player->HasAura(lfg::LFG_SPELL_DUNGEON_DESERTER))
            return "Dungeon Deserter";

        DungeonProgressionRequirements const* req =
            sObjectMgr->GetAccessRequirement(mapId, Difficulty(difficulty));
        if (!req)
        {
            // No access row at all -- fall back to the catalog's LFG level so a
            // stock dungeon with only DBC data still gets its bracket.
            uint32 lvl = InstanceCatalog::GetDungeonMinLevel(mapId, difficulty);
            if (lvl && player->GetLevel() < lvl)
                return "Requires level " + std::to_string(lvl);
            if (_maxLevelLock && !IsWithinLevelBracket(player, mapId, difficulty))
                return "You are too high level (bracket ends at "
                    + std::to_string(EffectiveMaxLevel(mapId, difficulty)) + ")";
            return "";
        }

        if (req->levelMin && player->GetLevel() < req->levelMin)
            return "Requires level " + std::to_string(req->levelMin);
        if (_maxLevelLock && !IsWithinLevelBracket(player, mapId, difficulty))
            return "You are too high level (bracket ends at "
                + std::to_string(EffectiveMaxLevel(mapId, difficulty)) + ")";
        if (req->reqItemLevel && player->GetAverageItemLevel() < req->reqItemLevel)
            return "Requires item level " + std::to_string(req->reqItemLevel);

        auto applies = [&](ProgressionRequirement const* r)
        {
            if (!r)
                return false;
            if (r->checkLeaderOnly && !isPartyLeader)
                return false;
            if (r->faction != TEAM_NEUTRAL && r->faction != player->GetTeamId())
                return false;
            return true;
        };

        for (ProgressionRequirement const* r : req->quests)
            if (applies(r) && !player->GetQuestRewardStatus(r->id))
                return r->note.empty() ? "Requires an attunement quest" : r->note;

        for (ProgressionRequirement const* r : req->items)
            if (applies(r) && !player->HasItemCount(r->id, 1, true))
                return r->note.empty() ? "Requires an attunement item" : r->note;

        for (ProgressionRequirement const* r : req->achievements)
            if (applies(r) && !player->HasAchieved(r->id))
                return r->note.empty() ? "Requires an achievement" : r->note;

        // Whatever the checks above missed, the door will not: let Satisfy have
        // the last word (report=false keeps it silent).
        if (!player->Satisfy(req, mapId, false))
            return "Requirements not met";

        return "";
    }

    void MatchmakingQueue::JoinQueue(Player* player, uint8 category, uint8 roles,
        std::vector<uint32> dungeonIds, uint8 difficulty, uint32 raidSize)
    {
        if (!player)
            return;

        // Normalise the tick list: drop duplicates, zeroes and anything not in
        // the catalog. An empty list is the random queue; raids keep a single
        // map in dungeonId as before.
        {
            std::vector<uint32> cleaned;
            for (uint32 id : dungeonIds)
            {
                if (!id || std::find(cleaned.begin(), cleaned.end(), id) != cleaned.end())
                    continue;
                if (category == QUEUE_CAT_DUNGEON
                    && !InstanceCatalog::MapSupportsDifficulty(id, DUNGEON_DIFFICULTY_EPIC))
                    continue;
                cleaned.push_back(id);
            }
            dungeonIds.swap(cleaned);
        }
        uint32 dungeonId = dungeonIds.size() == 1 ? dungeonIds[0] : 0u;

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
        if ((roles & QROLE_TANK) && !Utils::ClassCanTank(cls))
            roles &= ~QROLE_TANK;
        if ((roles & QROLE_HEALER) && !Utils::ClassCanHeal(cls))
            roles &= ~QROLE_HEALER;
        if (roles == 0)
            roles = QROLE_DPS;

        if (category != QUEUE_CAT_DUNGEON && category != QUEUE_CAT_RAID)
            category = QUEUE_CAT_DUNGEON;

        if (category == QUEUE_CAT_RAID)
        {
            if (raidSize != 10 && raidSize != 25 && raidSize != 40)
                raidSize = 10;
            // Raids are always one specific instance.
            if (dungeonId == 0 && !dungeonIds.empty())
                dungeonId = dungeonIds[0];
            if (dungeonId != 0)
                dungeonIds.assign(1, dungeonId);
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

        // Bots are backfill only: they are pulled into a group that real
        // players could not fill, never queued in their own right. Letting one
        // in here would let bot-only groups form and farm the daily reward.
        if (PlayerIsBot(player))
            return;

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

        // Entry requirements. The client greys locked rows out, but that is a
        // hint only -- the queue is the authority, otherwise a hand-crafted
        // packet (or a stale catalog after a level change) forms a group the
        // instance door then refuses. Same rule set as stock LFG: deserter and
        // random-cooldown gates first, then the per-map access requirements for
        // every member being queued.
        {
            auto reject = [&](std::string const& text)
            {
                JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                    .Set("error", text)
                    .Send(player);
            };

            for (Player* m : members)
            {
                if (m->HasAura(lfg::LFG_SPELL_DUNGEON_DESERTER))
                {
                    reject((members.size() > 1 ? m->GetName() + " has" : std::string("You have"))
                        + " the Dungeon Deserter debuff and cannot queue yet.");
                    return;
                }
                if (dungeonIds.empty() && _applyRandomCooldown)
                {
                    if (Aura* cd = m->GetAura(lfg::LFG_SPELL_DUNGEON_COOLDOWN))
                    {
                        // Say how long is left -- "wait it out" with no number
                        // reads like the queue is simply broken.
                        uint32 secondsLeft = static_cast<uint32>(
                            std::max<int32>(cd->GetDuration(), 0) / IN_MILLISECONDS);
                        std::string left = secondsLeft >= 60
                            ? std::to_string(secondsLeft / 60) + "m " + std::to_string(secondsLeft % 60) + "s"
                            : std::to_string(secondsLeft) + "s";

                        reject((members.size() > 1 ? m->GetName() + " is" : std::string("You are"))
                            + " on the random dungeon cooldown (" + left
                            + " left); pick a specific dungeon instead.");
                        return;
                    }
                }
            }

            auto lockFor = [&](Player* m, uint32 mapId) -> std::string
            {
                bool isLeader = (m == player);
                return GetEntryLockReason(m, mapId, difficulty, isLeader);
            };

            if (!dungeonIds.empty())
            {
                // Every ticked dungeon must be open to every member: stock greys
                // out the rest of the list rather than silently dropping picks.
                for (uint32 mapId : dungeonIds)
                    for (Player* m : members)
                    {
                        std::string reason = lockFor(m, mapId);
                        if (reason.empty())
                            continue;
                        MapEntry const* me = sMapStore.LookupEntry(mapId);
                        std::string mapName = (me && me->name[0] && me->name[0][0])
                            ? me->name[0] : ("Map " + std::to_string(mapId));
                        reject((members.size() > 1 ? m->GetName() + ": " : std::string())
                            + mapName + " - " + reason + ".");
                        return;
                    }
            }
            else
            {
                // "Any dungeon": at least one catalog dungeon must be open to
                // EVERY member, otherwise the random pick can never resolve.
                bool anyOpen = false;
                std::string firstReason;
                for (auto const& d : InstanceCatalog::GetMythicDungeons())
                {
                    bool openForAll = true;
                    for (Player* m : members)
                    {
                        std::string reason = lockFor(m, d.mapId);
                        if (!reason.empty())
                        {
                            if (firstReason.empty())
                                firstReason = (members.size() > 1 ? m->GetName() + ": " : std::string())
                                    + reason;
                            openForAll = false;
                            break;
                        }
                    }
                    if (openForAll)
                    {
                        anyOpen = true;
                        break;
                    }
                }

                if (!anyOpen && !InstanceCatalog::GetMythicDungeons().empty())
                {
                    reject("No random dungeon is available to your group yet"
                        + (firstReason.empty() ? std::string(".") : " (" + firstReason + ")."));
                    return;
                }
            }
        }

        auto fullRoles = [](uint8 c) -> uint8
        {
            uint8 r = QROLE_DPS;
            if (Utils::ClassCanTank(c)) r |= QROLE_TANK;
            if (Utils::ClassCanHeal(c)) r |= QROLE_HEALER;
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
                                && q.dungeonIds == dungeonIds
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
                entry.dungeonIds  = dungeonIds;
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
        JsonMessage msg(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_QUEUE_STATUS);
        msg.Set("queued", true)
            .Set("category", static_cast<int32>(self->category))
            .Set("waitSeconds", static_cast<int32>(now - self->joinedAt))
            .Set("tanks", static_cast<int32>(tanks))
            .Set("healers", static_cast<int32>(healers))
            .Set("dps", static_cast<int32>(dps))
            .Set("total", static_cast<int32>(total))
            // The counts above deliberately exclude anyone already pulled into
            // a proposal -- they are no longer waiting. That means a player who
            // IS in a proposal sees their own queue as empty, so flag the state
            // instead of letting the client render a misleading "0 / 0 / 0".
            .Set("proposalPending", self->inProposal);
        AppendWaitEstimates(msg, self->category);
        msg.Send(player);
    }

    // Per-role average wait (seconds, -1 = no data yet) -- the same "average
    // wait time" figures the stock Dungeon Finder shows under the eye.
    void MatchmakingQueue::AppendWaitEstimates(JsonMessage& msg, uint8 category) const
    {
        uint8 c = category < 3 ? category : 0;
        auto value = [&](uint8 roleIndex) -> int32
        {
            WaitStats const& w = _waitStats[c][roleIndex];
            return w.samples ? static_cast<int32>(w.avgSec) : -1;
        };
        int32 t = value(0), h = value(1), d = value(2);
        int32 known = 0, sum = 0;
        for (int32 v : { t, h, d })
            if (v >= 0) { sum += v; ++known; }

        msg.Set("waitTank", t)
            .Set("waitHealer", h)
            .Set("waitDps", d)
            .Set("waitAvg", known ? sum / known : -1);
    }

    void MatchmakingQueue::RecordWait(uint8 category, uint8 role, uint32 waitedSec)
    {
        uint8 c = category < 3 ? category : 0;
        uint8 r = (role & QROLE_TANK) ? 0 : (role & QROLE_HEALER) ? 1 : 2;
        _waitStats[c][r].Add(waitedSec);
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

                // Stock LFG: declining a ready-check puts a short (150s)
                // dungeon cooldown on the decliner so serial decliners cannot
                // keep burning everyone else's pops.
                if (_applyRandomCooldown)
                    if (Aura* aura = player->AddAura(lfg::LFG_SPELL_DUNGEON_COOLDOWN, player))
                        aura->SetDuration(150 * IN_MILLISECONDS);
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
        // Ahead of the enabled gate: bots queued for eviction must not be stranded in an instance by a
        // runtime disable of the queue.
        ProcessPendingBotEvictions();

        if (!_enabled)
            return;

        _matchTimerMs += diff;
        _statusTimerMs += diff;
        _proposalTimerMs += diff;

        // Proposal timeouts have one-second granularity; polling them at world
        // tick rate just took _mutex and walked _proposals 20x/sec for nothing.
        if (_proposalTimerMs >= 500)
        {
            _proposalTimerMs = 0;
            CheckProposalTimeouts();
        }

        _bootTimerMs += diff;
        if (_bootTimerMs >= 1000)
        {
            _bootTimerMs = 0;
            CheckBootTimeouts();
        }

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

    // ------------------------------------------------------------------------
    // Place as many candidates as possible into `need` WITHOUT requiring the
    // group to be completed, and report what is still missing. Same party rule
    // as AssembleGroup: a queued party goes in whole or not at all. Used only on
    // the bot-backfill pass, where the shortfall is filled from the bot pool.
    // ------------------------------------------------------------------------
    static RoleNeed PlaceGreedily(std::vector<QueueEntry> const& queue,
        std::vector<uint32> const& candidates, RoleNeed need,
        std::unordered_map<uint32, uint8>& out)
    {
        out.clear();

        auto entryFor = [&](uint32 g) -> QueueEntry const*
        {
            for (QueueEntry const& e : queue)
                if (e.guid.GetCounter() == g)
                    return &e;
            return nullptr;
        };

        std::set<uint32> used;
        auto place = [&](uint32 g, RoleNeed& rem) -> bool
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

        // Party blocks first (all-or-nothing), then solos.
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

        RoleNeed rem = need;
        for (auto const& kv : parties)
        {
            // Trial-place the whole block; roll back if any member does not fit.
            RoleNeed trial = rem;
            auto snapshot = out;
            auto usedSnapshot = used;
            bool ok = true;
            for (uint32 g : kv.second)
                if (!place(g, trial))
                {
                    ok = false;
                    break;
                }

            if (ok)
            {
                rem = trial;
            }
            else
            {
                out = snapshot;
                used = usedSnapshot;
            }
        }

        for (uint32 g : solos)
        {
            if (rem.Empty())
                break;
            place(g, rem);
        }

        return rem;
    }

    // Longest wait among these queued players, in seconds.
    bool MatchmakingQueue::BackfillDelayElapsed(std::vector<uint32> const& guidLows) const
    {
        if (_botBackfillAfterSec == 0)
            return true;

        time_t now = GameTime::GetGameTime().count();
        for (uint32 g : guidLows)
            for (QueueEntry const& e : _queue)
                if (e.guid.GetCounter() == g
                    && now - e.joinedAt >= static_cast<time_t>(_botBackfillAfterSec))
                    return true;

        return false;
    }

    // Ask the provider for bots to fill `need`. Bots already sitting in another
    // pending proposal are skipped here rather than in the module, which has no
    // view of the queue. Returns fewer pairs than requested when the pool is too
    // thin -- the caller then leaves the group unformed.
    //
    // The provider runs on the world thread (same as the match loop) and never
    // calls back into the queue, so holding _mutex across it introduces no lock
    // ordering of its own.
    std::vector<std::pair<ObjectGuid, uint8>> MatchmakingQueue::RecruitBotFillers(
        RoleNeed const& need, uint8 minLevel, uint32 dungeonId, uint8 difficulty)
    {
        std::vector<std::pair<ObjectGuid, uint8>> picks;
        if (!HasBotProvider() || need.Empty())
            return picks;

        // A bot must clear the same entry requirement the queue enforces on
        // players (see JoinQueue), plus stay within the party's level band.
        uint32 required = InstanceCatalog::GetDungeonMinLevel(dungeonId, difficulty);
        uint8 floorLevel = static_cast<uint8>(std::max<uint32>(required,
            minLevel > _botLevelSlack ? minLevel - _botLevelSlack : 1u));
        uint8 ceilLevel = _botLevelSlack == 0
            ? 0
            : static_cast<uint8>(std::min<uint32>(255u, minLevel + _botLevelSlack));
        if (ceilLevel != 0 && ceilLevel < floorLevel)
            ceilLevel = floorLevel;

        auto engaged = [&](ObjectGuid guid) -> bool
        {
            for (auto const& [pid, prop] : _proposals)
                for (ObjectGuid member : prop.members)
                    if (member == guid)
                        return true;
            return false;
        };

        struct Slot { uint8 role; uint8 count; };
        Slot const slots[] = {
            { QROLE_TANK,   need.tank   },
            { QROLE_HEALER, need.healer },
            { QROLE_DPS,    need.dps    },
        };

        std::set<ObjectGuid> taken;
        for (Slot const& slot : slots)
        {
            uint8 remaining = slot.count;
            if (remaining == 0)
                continue;

            // Over-request so the engaged/duplicate filter below still has
            // candidates left to work with.
            std::vector<Player*> candidates;
            g_botProvider.Recruit(slot.role, floorLevel, ceilLevel,
                static_cast<uint32>(remaining) + 4u, candidates);

            for (Player* bot : candidates)
            {
                if (remaining == 0)
                    break;
                if (!bot || !bot->IsInWorld())
                    continue;
                ObjectGuid guid = bot->GetGUID();
                if (taken.count(guid) || engaged(guid))
                    continue;
                if (!GetEntryLockReason(bot, dungeonId, difficulty, false).empty())
                    continue;

                taken.insert(guid);
                picks.emplace_back(guid, slot.role);
                --remaining;
            }

            if (remaining > 0)
                return {};  // cannot fill this role; abandon the whole attempt
        }

        return picks;
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

            // With blizzlike multi-select a player can tick several dungeons, so
            // a candidate group is formed PER DUNGEON out of everyone who ticked
            // it (plus the random queuers, who take anything). That is the
            // set-intersection rule stock LFGQueue uses, expressed as one pool
            // per possible destination.
            for (QueueEntry const& e : _queue)
            {
                if (e.category != QUEUE_CAT_DUNGEON || e.inProposal || e.difficulty != diff)
                    continue;
                if (e.IsRandom())
                    anyPool.push_back(e.guid.GetCounter());
                else
                    for (uint32 mapId : e.dungeonIds)
                        byDungeon[mapId].push_back(e.guid.GetCounter());
            }

            struct Bucket
            {
                uint32 dungeonId;               // 0 = pick a random eligible map
                std::vector<uint32> pool;
            };
            std::vector<Bucket> buckets;
            for (auto const& [dungeonId, members] : byDungeon)
            {
                Bucket bucket;
                bucket.dungeonId = dungeonId;
                bucket.pool = members;
                bucket.pool.insert(bucket.pool.end(), anyPool.begin(), anyPool.end());
                buckets.push_back(std::move(bucket));
            }
            // Most-wanted dungeon first, so the pick follows demand instead of
            // unordered_map iteration order.
            std::sort(buckets.begin(), buckets.end(),
                [](Bucket const& a, Bucket const& b) { return a.pool.size() > b.pool.size(); });
            if (!anyPool.empty())
                buckets.push_back(Bucket{ 0, anyPool });

            // Lowest level among an assignment, which gates which maps are legal.
            auto lowestLevelOf = [&](std::unordered_map<uint32, uint8> const& assign) -> uint8
            {
                uint8 lowest = 255;
                for (auto const& kv : assign)
                    if (QueueEntry* e = FindEntry(kv.first))
                        lowest = std::min<uint8>(lowest, e->level);
                return lowest;
            };

            // Eligibility is per queued difficulty: a level-70 group queueing
            // Normal may get a Northrend dungeon, but the Heroic/Mythic versions
            // of the same map are level-80 content. Returns 0 when the group can
            // enter nothing -- better to leave them queued than to teleport them
            // into content they are locked out of.
            auto pickRandomMap = [&](std::unordered_map<uint32, uint8> const& assign) -> uint32
            {
                auto const& anyMaps = InstanceCatalog::GetMythicDungeonMapIds();
                std::vector<uint32> eligible;
                for (uint32 mapId : anyMaps)
                {
                    bool openForAll = true;
                    for (auto const& kv : assign)
                    {
                        // Everyone in the match must both WANT this map (their
                        // tick list, or random) and be allowed through the door.
                        QueueEntry const* e = FindEntry(kv.first);
                        if (!e || !e->Wants(mapId))
                        {
                            openForAll = false;
                            break;
                        }
                        Player* p = ObjectAccessor::FindConnectedPlayer(ObjectGuid::Create<HighGuid::Player>(kv.first));
                        if (!p || !GetEntryLockReason(p, mapId, diff, true).empty())
                        {
                            openForAll = false;
                            break;
                        }
                        // Unconditional: a level 80 asking for a random dungeon
                        // must not be dropped into a level 21 one, whatever
                        // MaxLevelLock is set to.
                        if (!IsWithinLevelBracket(p, mapId, diff))
                        {
                            openForAll = false;
                            break;
                        }
                    }
                    if (openForAll)
                        eligible.push_back(mapId);
                }

                if (eligible.empty())
                    return 0;

                return eligible[urand(0, static_cast<uint32>(eligible.size()) - 1)];
            };

            // 1) Real players only. A group that forms without bots always
            //    wins -- backfill is a fallback, never a shortcut.
            for (Bucket const& bucket : buckets)
            {
                std::unordered_map<uint32, uint8> assign;
                if (!AssembleGroup(_queue, bucket.pool, need, assign))
                    continue;

                uint32 mapId = bucket.dungeonId != 0
                    ? bucket.dungeonId
                    : pickRandomMap(assign);
                if (mapId == 0)
                    continue;

                std::vector<uint32> picks;
                for (auto const& [g, r] : assign) picks.push_back(g);
                if (CreateProposal(picks, assign, QUEUE_CAT_DUNGEON, mapId, diff, 0))
                    return true;
            }

            // 2) Bot backfill: complete a group real players could not fill on
            //    their own, once they have waited out the backfill delay.
            if (!_botsEnabled || !HasBotProvider())
                continue;

            for (Bucket const& bucket : buckets)
            {
                if (!BackfillDelayElapsed(bucket.pool))
                    continue;

                std::unordered_map<uint32, uint8> assign;
                RoleNeed shortfall = PlaceGreedily(_queue, bucket.pool, need, assign);

                // At least one real player, and something actually missing
                // (a complete group would have formed in pass 1).
                if (assign.empty() || shortfall.Empty())
                    continue;
                if (shortfall.Total() > _botsMaxPerGroup)
                    continue;

                uint8 lowestLevel = lowestLevelOf(assign);
                uint32 mapId = bucket.dungeonId != 0
                    ? bucket.dungeonId
                    : pickRandomMap(assign);
                if (mapId == 0)
                    continue;

                auto botPicks = RecruitBotFillers(shortfall, lowestLevel, mapId, diff);
                if (botPicks.size() < shortfall.Total())
                    continue;

                std::vector<uint32> picks;
                for (auto const& [g, r] : assign) picks.push_back(g);
                if (CreateProposal(picks, assign, QUEUE_CAT_DUNGEON, mapId, diff, 0, botPicks))
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
                if (CreateProposal(picks, assign, QUEUE_CAT_RAID, map, diff, raidSize))
                    return true;
                continue;
            }

            // Raid backfill is opt-in: filling a 25-man means summoning 20+
            // bots, which is a very different thing from rounding out a 5-man.
            if (!_botsEnabled || !_botsForRaids || !HasBotProvider())
                continue;
            if (!BackfillDelayElapsed(members))
                continue;

            assign.clear();
            RoleNeed shortfall = PlaceGreedily(_queue, members, need, assign);
            if (assign.empty() || shortfall.Empty())
                continue;
            if (shortfall.Total() > _botsMaxPerGroup)
                continue;

            uint8 lowestLevel = 255;
            for (auto const& kv : assign)
                if (QueueEntry* e = FindEntry(kv.first))
                    lowestLevel = std::min<uint8>(lowestLevel, e->level);

            auto botPicks = RecruitBotFillers(shortfall, lowestLevel, map, diff);
            if (botPicks.size() < shortfall.Total())
                continue;

            std::vector<uint32> picks;
            for (auto const& [g, r] : assign) picks.push_back(g);
            if (CreateProposal(picks, assign, QUEUE_CAT_RAID, map, diff, raidSize, botPicks))
                return true;
        }

        return false;
    }

    bool MatchmakingQueue::CreateProposal(std::vector<uint32> const& picksGuidLow,
        std::unordered_map<uint32, uint8> const& roleAssign, uint8 category,
        uint32 dungeonId, uint8 difficulty, uint32 raidSize,
        std::vector<std::pair<ObjectGuid, uint8>> const& botPicks)
    {
        // (caller holds _mutex)
        MatchProposal prop;
        prop.id         = _nextProposalId++;
        prop.category   = category;
        prop.dungeonId  = dungeonId;
        prop.difficulty = difficulty;
        prop.raidSize   = raidSize;
        prop.createdAt  = GameTime::GetGameTime().count();

        time_t nowSec = prop.createdAt;
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
                    if (e.category == category && e.IsRandom())
                        prop.randomQueue = true;
                    if (!found)
                    {
                        // Feed the per-role ETA from this member's actual wait.
                        auto rit = roleAssign.find(g);
                        uint8 role = rit != roleAssign.end() ? rit->second : static_cast<uint8>(QROLE_DPS);
                        if (nowSec >= e.joinedAt)
                            RecordWait(category, role, static_cast<uint32>(nowSec - e.joinedAt));
                    }
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

        // Backfilled bots hold no queue entry, so they are added straight to
        // the roster and counted as accepted -- there is no client behind them
        // to answer the ready-check, and leaving them pending would time every
        // proposal out.
        for (auto const& [guid, role] : botPicks)
        {
            uint32 g = guid.GetCounter();
            if (prop.responses.find(g) != prop.responses.end())
                continue;

            prop.members.push_back(guid);
            prop.responses[g] = 1;
            prop.assignedRoles[g] = role;
            prop.bots.insert(g);
        }

        std::size_t minMembers = _debugMinPlayers == 1 ? 1u : 2u;
        if (prop.members.size() < minMembers)
        {
            // Safety: too small to be a group. Release the in-proposal marks we
            // just set -- leaving them set stranded the entries in the queue
            // forever (no proposal exists, so nothing ever times them out).
            for (ObjectGuid guid : prop.members)
                for (QueueEntry& e : _queue)
                    if (e.guid == guid)
                        e.inProposal = false;
            return false;
        }

        // A proposal made entirely of bots would mean no one asked for it.
        if (prop.bots.size() == prop.members.size())
        {
            for (ObjectGuid guid : prop.members)
                for (QueueEntry& e : _queue)
                    if (e.guid == guid)
                        e.inProposal = false;
            return false;
        }

        uint32 pid = prop.id;
        _proposals[pid] = prop;

        // Backfilled bots count as accepted from the start, so the ready-check
        // must ship the current tally -- otherwise the client draws every mark
        // as pending and they only ever flip on the LAST accept, which reads as
        // "the check marks never appear".
        uint8 alreadyAccepted = 0;
        for (auto const& [g, resp] : prop.responses)
            if (resp == 1)
                ++alreadyAccepted;

        // Notify each member with the ready-check (bots are already accepted).
        for (ObjectGuid guid : prop.members)
        {
            if (prop.IsBotMember(guid.GetCounter()))
                continue;

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
                .Set("accepted", static_cast<int32>(alreadyAccepted))
                .Set("timeout", static_cast<int32>(_proposalTimeoutSec))
                .Send(p);
        }

        LOG_DEBUG("dc.groupfinder",
            "Matchmaking: proposal #{} formed ({} members, {} backfilled bots)",
            pid, prop.members.size(), prop.bots.size());
        return true;
    }

    void MatchmakingQueue::SendProposalUpdate(MatchProposal const& proposal)
    {
        // (caller holds _mutex)
        uint32 accepted = 0;
        for (auto const& [g, r] : proposal.responses)
            if (r == 1) ++accepted;

        for (ObjectGuid guid : proposal.members)
        {
            if (proposal.IsBotMember(guid.GetCounter()))
                continue;

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

                // Bots simply go back to the pool: nothing to notify, and no
                // queue entry to requeue or remove.
                if (prop.IsBotMember(g))
                    continue;

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
                if (!proposal.IsBotMember(p->GetGUID().GetCounter()))
                    JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_QUEUE_PROPOSAL_FAILED)
                        .Set("proposalId", static_cast<int32>(proposal.id))
                        .Set("reason", "A player became unavailable.")
                        .Set("requeued", false)
                        .Send(p);
            return;
        }

        // Stock LFG lock statuses were checked at queue time, but a member may
        // have changed since (levelled, dropped an item, got saved elsewhere).
        // Re-run the door check now so nobody is teleported into a refusal.
        for (Player* p : players)
        {
            std::string reason = GetEntryLockReason(p, proposal.dungeonId, proposal.difficulty, true);
            if (reason.empty())
                continue;

            for (Player* other : players)
                if (!proposal.IsBotMember(other->GetGUID().GetCounter()))
                    JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_QUEUE_PROPOSAL_FAILED)
                        .Set("proposalId", static_cast<int32>(proposal.id))
                        .Set("reason", p->GetName() + " can no longer enter: " + reason + ".")
                        .Set("requeued", false)
                        .Send(other);
            return;
        }

        // Which pre-made party (if any) each real player came from: everyone
        // outside your own party is a "stranger" for Luck of the Draw and the
        // LFD grouping achievement, exactly as stock counts it.
        std::unordered_map<uint32, ObjectGuid> partyOf;
        for (Player* p : players)
            partyOf[p->GetGUID().GetCounter()] = p->GetGroup() ? p->GetGroup()->GetGUID() : ObjectGuid::Empty;

        // Remember where everyone came from, then dissolve any pre-existing
        // party so one fresh group forms from the full matched roster.
        for (Player* p : players)
        {
            p->SetEntryPoint();
            if (p->GetGroup())
                p->RemoveFromGroup();
        }

        // A real player leads: handing lead to a bot would leave the group
        // unable to set difficulty, convert to raid, or invite anyone else.
        std::stable_partition(players.begin(), players.end(),
            [&proposal](Player* p)
            {
                return !proposal.IsBotMember(p->GetGUID().GetCounter());
            });

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

        // Stock LFG groups roll Need Before Greed -- strangers do not get to
        // master-loot each other.
        group->SetLootMethod(NEED_BEFORE_GREED);
        group->SetLootThreshold(ITEM_QUALITY_UNCOMMON);

        // Apply difficulty.
        if (proposal.category == QUEUE_CAT_RAID)
            group->SetRaidDifficulty(Difficulty(proposal.difficulty));
        else
            group->SetDungeonDifficulty(Difficulty(proposal.difficulty));

        // Track the formed group for the rest of its LFG lifecycle.
        FormedGroup info;
        info.mapId       = proposal.dungeonId;
        info.difficulty  = proposal.difficulty;
        info.category    = proposal.category;
        info.randomQueue = proposal.randomQueue;
        info.formedAt    = GameTime::GetGameTime().count();
        {
            std::set<ObjectGuid> parties;
            uint32 realCount = 0;
            for (Player* p : players)
            {
                uint32 g = p->GetGUID().GetCounter();
                if (proposal.IsBotMember(g))
                {
                    info.bots.insert(g);
                    continue;
                }
                info.members.insert(g);
                ++realCount;
                parties.insert(partyOf[g]);
            }
            // Strangers = real players minus your own party's size; with more
            // than one party present treat everyone outside as strangers.
            info.strangerCount = realCount > 1 ? static_cast<uint8>(realCount - 1) : 0;
            if (parties.size() == 1 && !parties.count(ObjectGuid::Empty))
                info.strangerCount = 0;  // one intact pre-made party, no strangers
        }
        {
            std::lock_guard<std::mutex> lock(_mutex);
            _formedGroups[group->GetGUID()] = info;
        }

        // Look up the instance entrance.
        AreaTriggerTeleport const* at = sObjectMgr->GetMapEntranceTrigger(proposal.dungeonId);

        for (Player* p : players)
        {
            bool isBot = proposal.IsBotMember(p->GetGUID().GetCounter());

            // Stock: a random-dungeon match puts the dungeon cooldown on real
            // players (lifted again when the last boss falls). It is what stops
            // re-queueing for another random while this one is in progress.
            if (!isBot && info.randomQueue && _applyRandomCooldown
                && !p->HasAura(lfg::LFG_SPELL_DUNGEON_COOLDOWN))
                p->AddAura(lfg::LFG_SPELL_DUNGEON_COOLDOWN, p);

            if (at)
                p->TeleportTo(at->target_mapId, at->target_X, at->target_Y,
                              at->target_Z, at->target_Orientation);

            if (isBot)
                continue;

            // Legacy behaviour: pay on pop. Off by default -- stock pays on the
            // final boss (see OnEncounterComplete) so the reward cannot be
            // farmed by accepting and leaving.
            if (!_rewardOnCompletion && sGroupFinderMgr.CanReceiveReward(p))
                sGroupFinderMgr.GiveReward(p);

            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_QUEUE_LEFT)
                .Set("success", true)
                .Set("matched", true)
                .Send(p);
        }

        if (!at)
        {
            for (Player* p : players)
                if (!proposal.IsBotMember(p->GetGUID().GetCounter()))
                    JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_ERROR)
                        .Set("error", "Could not find the instance entrance; please use a summon or portal.")
                        .Send(p);
        }

        LOG_INFO("dc.groupfinder",
            "Matchmaking: formed group of {} ({} bots) for map {} (diff {}, random {})",
            players.size(), proposal.bots.size(), proposal.dungeonId, proposal.difficulty,
            info.randomQueue ? "yes" : "no");
    }

    // ========================================================================
    // FORMED-GROUP LIFECYCLE (stock LFGScripts equivalents)
    // ========================================================================

    FormedGroup* MatchmakingQueue::FindFormedGroup(ObjectGuid groupGuid)
    {
        auto it = _formedGroups.find(groupGuid);
        return it != _formedGroups.end() ? &it->second : nullptr;
    }

    // Mirrors LFGGroupScript::OnRemoveMember: teleport the leaver back to
    // where they queued from, and hand out the deserter debuff for walking out
    // on an unfinished dungeon while the group could still have used them.
    void MatchmakingQueue::OnGroupMemberRemoved(Group* group, ObjectGuid guid, RemoveMethod method)
    {
        if (!group)
            return;

        FormedGroup snapshot;
        bool tracked = false;
        bool stillHasMembers = true;
        {
            std::lock_guard<std::mutex> lock(_mutex);
            FormedGroup* info = FindFormedGroup(group->GetGUID());
            if (!info)
                return;
            tracked = true;
            uint32 g = guid.GetCounter();
            info->members.erase(g);
            info->bots.erase(g);
            snapshot = *info;
            stillHasMembers = !info->members.empty();
            if (!stillHasMembers)
                _formedGroups.erase(group->GetGUID());
        }
        if (!tracked)
            return;

        // Once the last real player leaves, the bots have no reason to stay. Queued rather than done here:
        // this runs inside Group::RemoveMember, which uses the group again after the hook returns, and the
        // removal that takes the group under two members disbands and deletes it -- the caller would then
        // walk a freed group in SendUpdate(). Ahead of the leaver lookup below, because a player who left
        // by logging out abandons the bots just the same.
        if (!stillHasMembers && !snapshot.bots.empty())
        {
            std::lock_guard<std::mutex> lock(_mutex);
            for (uint32 botLow : snapshot.bots)
                _pendingBotEvictions.push_back({group->GetGUID(), botLow});
        }

        Player* player = ObjectAccessor::FindConnectedPlayer(guid);
        if (!player)
            return;

        bool isBot = PlayerIsBot(player);

        // Deserter: only real players, only for an unfinished run, only when
        // enough of the group remains that the walk-out actually hurt them
        // (stock uses the kick-vote quorum), never for an LFG kick, and only
        // if the realm has deserter enabled for the stock finder too.
        if (!isBot && !snapshot.completed && method != GROUP_REMOVEMETHOD_KICK_LFG
            && player->HasAura(lfg::LFG_SPELL_DUNGEON_COOLDOWN)
            && group->GetMembersCount() >= _deserterMinGroupSize
            && sWorld->getBoolConfig(CONFIG_LFG_CAST_DESERTER))
        {
            player->AddAura(lfg::LFG_SPELL_DUNGEON_DESERTER, player);
        }

        player->RemoveAurasDueToSpell(lfg::LFG_SPELL_LUCK_OF_THE_DRAW);

        // Teleport out (bots too -- an abandoned bot would otherwise stand in
        // the instance forever). TeleportToEntryPoint falls back to homebind
        // when no entry point was recorded.
        if (player->GetMapId() == snapshot.mapId && player->GetMap() && player->GetMap()->IsDungeon()
            && !player->IsBeingTeleportedFar())
            player->TeleportToEntryPoint();

    }

    void MatchmakingQueue::ProcessPendingBotEvictions()
    {
        std::vector<PendingBotEviction> pending;
        {
            std::lock_guard<std::mutex> lock(_mutex);
            if (_pendingBotEvictions.empty())
                return;

            pending.swap(_pendingBotEvictions);
        }

        for (PendingBotEviction const& eviction : pending)
        {
            Player* bot = ObjectAccessor::FindConnectedPlayer(
                ObjectGuid::Create<HighGuid::Player>(eviction.botLow));
            if (!bot)
                continue;

            Group* group = bot->GetGroup();
            // Requeued into another group in the meantime: that run is not ours to end.
            if (group && group->GetGUID() != eviction.groupGuid)
                continue;

            if (group)
                bot->RemoveFromGroup();

            if (bot->GetMap() && bot->GetMap()->IsDungeon() && !bot->IsBeingTeleportedFar())
                bot->TeleportToEntryPoint();
        }
    }

    void MatchmakingQueue::OnGroupDisband(Group* group)
    {
        if (!group)
            return;
        std::lock_guard<std::mutex> lock(_mutex);
        _formedGroups.erase(group->GetGUID());
        _boots.erase(group->GetGUID());
    }

    // ========================================================================
    // VOTE KICK (stock LFG rules)
    // ========================================================================

    // Returns true when a vote was opened, which tells Group::RemoveMember to
    // leave the member in place. False means "not our business" and the kick
    // proceeds normally.
    bool MatchmakingQueue::StartBoot(Group* group, ObjectGuid kicker, ObjectGuid victim,
        std::string const& reason)
    {
        if (!group || !_voteKickEnabled || victim == kicker)
            return false;

        Player* victimPlayer = ObjectAccessor::FindConnectedPlayer(victim);
        Player* kickerPlayer = ObjectAccessor::FindConnectedPlayer(kicker);
        if (!victimPlayer || !kickerPlayer)
            return false;

        BootState boot;
        {
            std::lock_guard<std::mutex> lock(_mutex);
            FormedGroup* info = FindFormedGroup(group->GetGUID());
            if (!info)
                return false;   // not a matchmade group: normal kick rules apply

            if (_boots.count(group->GetGUID()))
            {
                ChatHandler(kickerPlayer->GetSession()).SendSysMessage(
                    "A vote to kick is already in progress.");
                return true;    // still ours -- do not let the kick through
            }

            uint8 maxKicks = MaxKicks();
            if (maxKicks && info->kicksUsed >= maxKicks)
            {
                ChatHandler(kickerPlayer->GetSession()).SendSysMessage(
                    "Your group has used all of its vote kicks.");
                return true;
            }

            // A backfilled bot has no client to defend itself; removing one is
            // not a social decision, so it needs no vote.
            if (info->IsBot(victim.GetCounter()))
                return false;

            boot.victim     = victim;
            boot.kicker     = kicker;
            boot.victimName = victimPlayer->GetName();
            boot.reason     = reason.empty() ? "No reason given" : reason;
            boot.cancelTime = GameTime::GetGameTime().count() + _bootDurationSec;

            // Everyone still in the group votes. Kicker auto-agrees, victim
            // auto-refuses, bots agree (nothing is there to click).
            for (GroupReference* itr = group->GetFirstMember(); itr != nullptr; itr = itr->next())
            {
                Player* m = itr->GetSource();
                if (!m)
                    continue;
                uint32 low = m->GetGUID().GetCounter();
                if (m->GetGUID() == victim)
                    boot.votes[low] = -1;
                else if (m->GetGUID() == kicker)
                    boot.votes[low] = 1;
                else if (info->IsBot(low))
                    boot.votes[low] = 1;
                else
                    boot.votes[low] = 0;
            }

            _boots[group->GetGUID()] = boot;
        }

        SendBootState(group);

        // Bots may already have carried it over the line.
        uint8 agree = boot.CountAgree();
        if (agree >= _bootVotesNeeded)
            ResolveBoot(group->GetGUID(), true, "Vote passed.");

        return true;
    }

    void MatchmakingQueue::CastBootVote(Player* voter, bool agree)
    {
        if (!voter)
            return;

        Group* group = voter->GetGroup();
        if (!group)
            return;

        bool passed = false, failed = false;
        {
            std::lock_guard<std::mutex> lock(_mutex);
            auto it = _boots.find(group->GetGUID());
            if (it == _boots.end())
                return;

            BootState& boot = it->second;
            uint32 low = voter->GetGUID().GetCounter();
            auto vote = boot.votes.find(low);
            if (vote == boot.votes.end() || vote->second != 0)
                return;   // not eligible, or already voted (stock: no re-votes)

            vote->second = agree ? 1 : -1;

            if (boot.CountAgree() >= _bootVotesNeeded)
                passed = true;
            else if (boot.CountRefuse() >= _bootVotesNeeded)
                failed = true;
        }

        SendBootState(group);

        if (passed)
            ResolveBoot(group->GetGUID(), true, "Vote passed.");
        else if (failed)
            ResolveBoot(group->GetGUID(), false, "Vote failed.");
    }

    void MatchmakingQueue::SendBootState(Group* group)
    {
        if (!group)
            return;

        BootState boot;
        {
            std::lock_guard<std::mutex> lock(_mutex);
            auto it = _boots.find(group->GetGUID());
            if (it == _boots.end())
                return;
            boot = it->second;
        }

        time_t now = GameTime::GetGameTime().count();
        int32 remaining = static_cast<int32>(boot.cancelTime > now ? boot.cancelTime - now : 0);

        for (GroupReference* itr = group->GetFirstMember(); itr != nullptr; itr = itr->next())
        {
            Player* m = itr->GetSource();
            if (!m || PlayerIsBot(m))
                continue;

            auto vote = boot.votes.find(m->GetGUID().GetCounter());
            JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_QUEUE_BOOT_UPDATE)
                .Set("active", true)
                .Set("victim", boot.victimName)
                .Set("reason", boot.reason)
                .Set("agree", static_cast<int32>(boot.CountAgree()))
                .Set("refuse", static_cast<int32>(boot.CountRefuse()))
                .Set("needed", static_cast<int32>(_bootVotesNeeded))
                .Set("total", static_cast<int32>(boot.votes.size()))
                .Set("timeLeft", remaining)
                .Set("myVote", static_cast<int32>(vote != boot.votes.end() ? vote->second : 0))
                .Set("isVictim", m->GetGUID() == boot.victim)
                .Send(m);
        }
    }

    void MatchmakingQueue::ResolveBoot(ObjectGuid groupGuid, bool passed, char const* reason)
    {
        BootState boot;
        {
            std::lock_guard<std::mutex> lock(_mutex);
            auto it = _boots.find(groupGuid);
            if (it == _boots.end())
                return;
            boot = it->second;
            _boots.erase(it);

            if (passed)
                if (FormedGroup* info = FindFormedGroup(groupGuid))
                    ++info->kicksUsed;
        }

        Group* group = sGroupMgr->GetGroupByGUID(groupGuid.GetCounter());

        if (group)
            for (GroupReference* itr = group->GetFirstMember(); itr != nullptr; itr = itr->next())
                if (Player* m = itr->GetSource())
                    if (!PlayerIsBot(m))
                        JsonMessage(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_QUEUE_BOOT_UPDATE)
                            .Set("active", false)
                            .Set("victim", boot.victimName)
                            .Set("passed", passed)
                            .Set("reason", reason ? reason : "")
                            .Send(m);

        if (!passed || !group)
            return;

        // GROUP_REMOVEMETHOD_KICK_LFG: a vote-kicked player is NOT given the
        // deserter debuff (see OnGroupMemberRemoved), same as stock.
        Player::RemoveFromGroup(group, boot.victim, GROUP_REMOVEMETHOD_KICK_LFG);

        LOG_INFO("dc.groupfinder", "Matchmaking: vote kick passed on {} in group {}",
            boot.victimName, groupGuid.ToString());
    }

    void MatchmakingQueue::CheckBootTimeouts()
    {
        std::vector<ObjectGuid> expired;
        {
            std::lock_guard<std::mutex> lock(_mutex);
            time_t now = GameTime::GetGameTime().count();
            for (auto const& [gguid, boot] : _boots)
                if (now >= boot.cancelTime)
                    expired.push_back(gguid);
        }

        // Stock: running out of time is a failed vote, not a kick.
        for (ObjectGuid gguid : expired)
            ResolveBoot(gguid, false, "Vote timed out.");
    }

    // Mirrors LFGPlayerScript::OnPlayerMapChanged: Luck of the Draw while you
    // are inside the dungeon the group was formed for, gone once you are out.
    void MatchmakingQueue::OnPlayerMapChanged(Player* player)
    {
        if (!player || !_applyLuckOfTheDraw)
            return;

        Group* group = player->GetGroup();
        FormedGroup snapshot;
        {
            std::lock_guard<std::mutex> lock(_mutex);
            FormedGroup* info = group ? FindFormedGroup(group->GetGUID()) : nullptr;
            if (!info)
            {
                if (player->HasAura(lfg::LFG_SPELL_LUCK_OF_THE_DRAW))
                    player->RemoveAurasDueToSpell(lfg::LFG_SPELL_LUCK_OF_THE_DRAW);
                return;
            }
            snapshot = *info;
        }

        bool inside = player->GetMapId() == snapshot.mapId
            && player->GetMap() && player->GetMap()->IsDungeon();
        bool isBot = snapshot.IsBot(player->GetGUID().GetCounter());

        // Push a name query for every group member. Bots never generate the
        // client-side lookup a real player does, so without this they render as
        // "Unknown" for the whole run. Stock LFG does exactly this on entering
        // an LFG dungeon (LFGPlayerScript::OnPlayerMapChanged).
        if (inside && !isBot && player->GetSession())
            if (Group* g = player->GetGroup())
                for (GroupReference* itr = g->GetFirstMember(); itr != nullptr; itr = itr->next())
                    if (Player* member = itr->GetSource())
                        player->GetSession()->SendNameQueryOpcode(member->GetGUID());

        if (inside && !isBot && snapshot.strangerCount > 0)
        {
            if (!player->HasAura(lfg::LFG_SPELL_LUCK_OF_THE_DRAW))
                player->CastSpell(player, lfg::LFG_SPELL_LUCK_OF_THE_DRAW, true);
            // One stack per stranger, capped by the spell's own stack limit
            // (3 on 3.3.5a) -- the buff scales with how random the group is.
            if (Aura* aura = player->GetAura(lfg::LFG_SPELL_LUCK_OF_THE_DRAW))
            {
                uint8 maxStack = aura->GetSpellInfo()->StackAmount ? aura->GetSpellInfo()->StackAmount : 1;
                aura->SetStackAmount(std::min<uint8>(snapshot.strangerCount, maxStack));
            }
        }
        else if (!inside)
        {
            player->RemoveAurasDueToSpell(lfg::LFG_SPELL_LUCK_OF_THE_DRAW);
        }
    }

    // Mirrors LFGMgr::FinishDungeon. Fired from the encounter-state hook with
    // the LFGDungeons id that instance_encounters marks as the final boss of
    // this map; DC-only instances without such a row get no completion event
    // (same limitation the stock finder has).
    void MatchmakingQueue::OnEncounterComplete(Map* map, uint32 lfgDungeonId)
    {
        if (!map || !lfgDungeonId)
            return;

        LFGDungeonEntry const* lfgEntry = sLFGDungeonStore.LookupEntry(lfgDungeonId);
        if (!lfgEntry || lfgEntry->MapID != map->GetId())
            return;

        // Collect every tracked group that is actually inside THIS instance.
        std::vector<std::pair<ObjectGuid, FormedGroup>> done;
        {
            std::lock_guard<std::mutex> lock(_mutex);
            for (auto& [gguid, info] : _formedGroups)
            {
                if (info.completed || info.mapId != map->GetId())
                    continue;

                bool onThisInstance = false;
                for (uint32 low : info.members)
                    if (Player* p = ObjectAccessor::FindConnectedPlayer(ObjectGuid::Create<HighGuid::Player>(low)))
                        if (p->FindMap() == map)
                        {
                            onThisInstance = true;
                            break;
                        }
                if (!onThisInstance)
                    continue;

                info.completed = true;
                done.emplace_back(gguid, info);
            }
        }

        for (auto const& [gguid, info] : done)
        {
            for (uint32 low : info.members)
            {
                Player* p = ObjectAccessor::FindConnectedPlayer(ObjectGuid::Create<HighGuid::Player>(low));
                if (!p || p->FindMap() != map)
                    continue;

                // Cooldown lifted on completion, as stock does.
                if (p->HasAura(lfg::LFG_SPELL_DUNGEON_COOLDOWN))
                    p->RemoveAurasDueToSpell(lfg::LFG_SPELL_DUNGEON_COOLDOWN);

                // Stock credits "grouped with N random players via LFD" on
                // Heroic completions.
                if (info.difficulty >= DUNGEON_DIFFICULTY_HEROIC && info.strangerCount > 0)
                    p->UpdateAchievementCriteria(ACHIEVEMENT_CRITERIA_TYPE_USE_LFD_TO_GROUP_WITH_PLAYERS,
                        info.strangerCount);

                if (_rewardOnCompletion && info.randomQueue && sGroupFinderMgr.CanReceiveReward(p))
                {
                    sGroupFinderMgr.GiveReward(p);
                    ChatHandler(p->GetSession()).SendSysMessage(
                        "|cff00ff00Dungeon complete!|r Your Group Finder reward has been granted.");
                }
                else if (_rewardOnCompletion && !info.randomQueue)
                {
                    ChatHandler(p->GetSession()).SendSysMessage(
                        "|cff00ff00Dungeon complete!|r (Random-dungeon queues earn the daily Group Finder reward.)");
                }
            }

            LOG_INFO("dc.groupfinder", "Matchmaking: group {} completed map {} (lfg dungeon {}, random {})",
                gguid.ToString(), map->GetId(), lfgDungeonId, info.randomQueue ? "yes" : "no");
        }
    }

    void MatchmakingQueue::BroadcastStatus(uint8 category)
    {
        // Capture guid AND joinedAt in the single locked pass. The old shape
        // re-took _mutex and linear-scanned _queue (FindEntry) once per
        // recipient - O(N^2) lock/scan per broadcast for a value that was
        // already in hand during the first pass.
        // (guid, joinedAt, inProposal) -- the last one is per recipient, so it
        // cannot be hoisted out of the loop like the role counts.
        std::vector<std::tuple<ObjectGuid, time_t, bool>> recipients;
        uint32 tanks = 0, healers = 0, dps = 0, total = 0;

        {
            std::lock_guard<std::mutex> lock(_mutex);
            recipients.reserve(_queue.size());
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
                recipients.emplace_back(e.guid, e.joinedAt, e.inProposal);
            }
        }

        time_t now = GameTime::GetGameTime().count();
        for (auto const& [guid, joinedAt, inProposal] : recipients)
        {
            Player* p = ObjectAccessor::FindConnectedPlayer(guid);
            if (!p)
                continue;

            JsonMessage msg(Module::GROUP_FINDER, Opcode::GroupFinder::SMSG_QUEUE_STATUS);
            msg.Set("queued", true)
                .Set("category", static_cast<int32>(category))
                .Set("waitSeconds", static_cast<int32>(now - joinedAt))
                .Set("tanks", static_cast<int32>(tanks))
                .Set("healers", static_cast<int32>(healers))
                .Set("dps", static_cast<int32>(dps))
                .Set("total", static_cast<int32>(total))
                .Set("proposalPending", inProposal);
            AppendWaitEstimates(msg, category);
            msg.Send(p);
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
    static void HandleQueueJoin(Player* player, ParsedMessage const& msg)
    {
        JsonValue json = GetJsonData(msg);
        uint8 category   = static_cast<uint8>(json["category"].IsNumber() ? json["category"].AsInt32() : QUEUE_CAT_DUNGEON);
        uint8 roles      = static_cast<uint8>(json["roles"].IsNumber() ? json["roles"].AsInt32() : QROLE_DPS);
        uint8 difficulty = static_cast<uint8>(json["difficulty"].IsNumber() ? json["difficulty"].AsInt32() : 0);
        uint32 raidSize  = static_cast<uint32>(json["raidSize"].IsNumber() ? json["raidSize"].AsInt32() : 0);

        // Blizzlike multi-select arrives as "dungeonIds"; "dungeonId" is still
        // accepted so an older client keeps working.
        std::vector<uint32> dungeonIds;
        JsonValue const& list = json["dungeonIds"];
        if (list.IsArray())
        {
            for (std::size_t i = 0; i < list.Size(); ++i)
                if (list[i].IsNumber())
                    if (int32 id = list[i].AsInt32(); id > 0)
                        dungeonIds.push_back(static_cast<uint32>(id));
        }
        else if (json["dungeonId"].IsNumber())
        {
            if (int32 id = json["dungeonId"].AsInt32(); id > 0)
                dungeonIds.push_back(static_cast<uint32>(id));
        }

        sMatchmakingQueue.JoinQueue(player, category, roles, std::move(dungeonIds), difficulty, raidSize);
    }

    static void HandleQueueBootStart(Player* player, ParsedMessage const& msg)
    {
        JsonValue json = GetJsonData(msg);
        std::string name = json["victim"].IsString() ? json["victim"].AsString() : "";
        std::string reason = json["reason"].IsString() ? json["reason"].AsString() : "";
        Group* group = player ? player->GetGroup() : nullptr;
        if (!group || name.empty())
            return;

        for (GroupReference* itr = group->GetFirstMember(); itr != nullptr; itr = itr->next())
            if (Player* m = itr->GetSource())
                if (m->GetName() == name)
                {
                    sMatchmakingQueue.StartBoot(group, player->GetGUID(), m->GetGUID(), reason);
                    return;
                }
    }

    static void HandleQueueBootVote(Player* player, ParsedMessage const& msg)
    {
        JsonValue json = GetJsonData(msg);
        bool agree = json["agree"].IsBool() ? json["agree"].AsBool()
            : (json["agree"].IsNumber() ? json["agree"].AsInt32() != 0 : false);
        sMatchmakingQueue.CastBootVote(player, agree);
    }

    static void HandleQueueLeave(Player* player, ParsedMessage const& /*msg*/)
    {
        sMatchmakingQueue.LeaveQueue(player, true);
    }

    static void HandleQueueStatusRequest(Player* player, ParsedMessage const& /*msg*/)
    {
        sMatchmakingQueue.SendStatus(player);
    }

    static void HandleQueueProposalResponse(Player* player, ParsedMessage const& msg)
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
    static void HandleGetQueueCatalog(Player* player, ParsedMessage const& /*msg*/)
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

            // Entry requirement per difficulty (0=Normal, 1=Heroic, 2=Mythic) so
            // the client picker can lock what the player cannot enter yet. Short
            // keys: the catalog is one payload covering every dungeon.
            JsonValue reqLevels;
            reqLevels.SetArray();
            JsonValue reqItemLevels;
            reqItemLevels.SetArray();
            JsonValue maxLevels;
            maxLevels.SetArray();
            for (uint8 diff = 0; diff < InstanceCatalog::DUNGEON_DIFFICULTY_COUNT; ++diff)
            {
                reqLevels.Push(JsonValue(static_cast<int32>(d.minLevel[diff])));
                reqItemLevels.Push(JsonValue(static_cast<int32>(d.minItemLevel[diff])));
                maxLevels.Push(JsonValue(static_cast<int32>(
                    sMatchmakingQueue.EffectiveMaxLevel(d.mapId, diff))));
            }
            o.Set("reqLevel", reqLevels);
            o.Set("reqItemLevel", reqItemLevels);
            o.Set("maxLevel", maxLevels);

            // Per-PLAYER lock reason per difficulty ("" = open). This is the
            // stock LfgLockMap: attunements, gear and saves differ per
            // character, so the catalog is personalised rather than cached.
            JsonValue locks;
            locks.SetArray();
            for (uint8 diff = 0; diff < InstanceCatalog::DUNGEON_DIFFICULTY_COUNT; ++diff)
                locks.Push(JsonValue(sMatchmakingQueue.GetEntryLockReason(player, d.mapId, diff, true)));
            o.Set("lock", locks);
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
        DC_REGISTER_HANDLER(Module::GROUP_FINDER, Opcode::GroupFinder::CMSG_QUEUE_BOOT_START, HandleQueueBootStart);
        DC_REGISTER_HANDLER(Module::GROUP_FINDER, Opcode::GroupFinder::CMSG_QUEUE_BOOT_VOTE, HandleQueueBootVote);
    }

}  // namespace Matchmaking
}  // namespace DCAddon

// ============================================================================
// SCRIPTS
// ============================================================================

class MatchmakingWorldScript : public WorldScript
{
public:
    // Explicit hook list. WorldScript's ctor expands an empty list to "all
    // hooks" so this is equivalent to the old form -- it is spelled out so the
    // registration reads the same as the other scripts below (AllCreatureScript
    // & co. have NO such fallback and go silently dead when the list is empty).
    MatchmakingWorldScript()
        : WorldScript("MatchmakingWorldScript",
            { WORLDHOOK_ON_UPDATE, WORLDHOOK_ON_AFTER_CONFIG_LOAD }) {}

    // Picks up `.reload config`. Also fires once at startup (World::
    // LoadConfigSettings runs after ScriptMgr::Initialize), which is the first
    // point at which sWorld's config cache is safe to read.
    void OnAfterConfigLoad(bool reload) override
    {
        sMatchmakingQueue.LoadConfig();
        if (reload)
            LOG_INFO("dc.groupfinder", "Matchmaking: queue configuration reloaded");
    }

    void OnUpdate(uint32 diff) override
    {
        DarkChaos::ScopedUpdateProfiler _prof("Matchmaking");
        // sMatchmakingQueue already expands to the fully-qualified Instance().
        sMatchmakingQueue.Update(diff);
    }
};

class MatchmakingPlayerScript : public PlayerScript
{
public:
    MatchmakingPlayerScript()
        : PlayerScript("MatchmakingPlayerScript", { PLAYERHOOK_ON_LOGOUT, PLAYERHOOK_ON_MAP_CHANGED }) {}

    void OnPlayerLogout(Player* player) override
    {
        if (player)
            sMatchmakingQueue.OnPlayerLogout(player->GetGUID().GetCounter());
    }

    void OnPlayerMapChanged(Player* player) override
    {
        sMatchmakingQueue.OnPlayerMapChanged(player);
    }
};

// Stock LFGGroupScript equivalent for groups this queue formed.
class MatchmakingGroupScript : public GroupScript
{
public:
    MatchmakingGroupScript()
        : GroupScript("MatchmakingGroupScript", { GROUPHOOK_ON_REMOVE_MEMBER, GROUPHOOK_ON_DISBAND }) {}

    void OnRemoveMember(Group* group, ObjectGuid guid, RemoveMethod method, ObjectGuid /*kicker*/,
        char const* /*reason*/) override
    {
        sMatchmakingQueue.OnGroupMemberRemoved(group, guid, method);
    }

    void OnDisband(Group* group) override
    {
        sMatchmakingQueue.OnGroupDisband(group);
    }
};

// Completion detection: the core raises this after every encounter update and
// passes the LFGDungeons id when the encounter was the instance's final boss.
class MatchmakingGlobalScript : public GlobalScript
{
public:
    MatchmakingGlobalScript()
        : GlobalScript("MatchmakingGlobalScript", { GLOBALHOOK_ON_AFTER_UPDATE_ENCOUNTER_STATE }) {}

    void OnAfterUpdateEncounterState(Map* map, EncounterCreditType /*type*/, uint32 /*creditEntry*/,
        Unit* /*source*/, Difficulty /*difficulty_fixed*/,
        std::list<DungeonEncounter const*> const* /*encounters*/, uint32 dungeonCompleted,
        bool /*updated*/) override
    {
        if (dungeonCompleted)
            sMatchmakingQueue.OnEncounterComplete(map, dungeonCompleted);
    }
};

// Routes a leader's party-menu kick on a matchmade group into a vote, the way
// stock does for LFG groups (Group::RemoveMember).
static bool DCGroupKickInterceptor(Group* group, ObjectGuid kicker, ObjectGuid victim,
    char const* reason)
{
    return sMatchmakingQueue.StartBoot(group, kicker, victim, reason ? reason : "");
}

void AddSC_dc_addon_matchmaking()
{
    DCAddon::Matchmaking::RegisterMatchmakingHandlers();
    SetGroupKickInterceptor(&DCGroupKickInterceptor);
    new MatchmakingWorldScript();
    new MatchmakingPlayerScript();
    new MatchmakingGroupScript();
    new MatchmakingGlobalScript();
}
