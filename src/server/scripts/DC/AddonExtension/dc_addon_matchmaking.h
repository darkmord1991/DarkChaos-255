/*
 * Dark Chaos - Group Finder Auto-Matchmaking Queue
 * ================================================
 *
 * LFG-style automatic matchmaking for Mythic 0 dungeons and raids.
 * Players queue solo (or as a partial group) by role; the queue pools them and
 * forms a full group when role requirements are met, runs a ready-check, then
 * teleports the group into the instance at the requested difficulty and grants
 * the daily Group Finder reward.
 *
 * This is distinct from the listing/application system in dc_addon_groupfinder:
 * here there is no leader-driven listing, the server forms the group.
 *
 * Copyright (C) 2024-2025 Dark Chaos Development Team
 */

#ifndef DC_ADDON_MATCHMAKING_H
#define DC_ADDON_MATCHMAKING_H

#include "Common.h"
#include "ObjectGuid.h"
#include <vector>
#include <unordered_map>
#include <unordered_set>
#include <set>
#include <mutex>
#include <string>
#include <utility>
#include <algorithm>

class Player;
class Group;
class Map;
enum RemoveMethod : uint8;

namespace DCAddon
{
class JsonMessage;

namespace Matchmaking
{
    // ------------------------------------------------------------------------
    // Dynamic instance catalog, sourced from MapDifficulty.dbc + Map.dbc.
    // Mythic-capable dungeons = 5-man maps that have a Mythic (EPIC=2) entry;
    // raids carry the difficulties they actually have entries for. Built lazily
    // and cached so we never hardcode dungeon/raid lists.
    // ------------------------------------------------------------------------
    namespace InstanceCatalog
    {
        struct RaidEntry
        {
            uint32 mapId = 0;
            std::string name;
            uint32 expansion = 0;          // 0=Classic, 1=TBC, 2=WotLK
            std::vector<uint8> difficulties;  // raid difficulty ids that exist
            // Each queueable option: { difficultyId, raidSize }. Covers single-
            // difficulty Classic/TBC raids (size from Map.dbc maxPlayers) as well
            // as WotLK 10/25 N/H.
            std::vector<std::pair<uint8, uint32>> options;
        };

        // Difficulties a 5-man can be queued at: Normal / Heroic / Mythic(EPIC).
        static constexpr uint8 DUNGEON_DIFFICULTY_COUNT = 3;

        struct DungeonEntry
        {
            uint32 mapId = 0;
            std::string name;
            uint32 expansion = 0;
            uint32 level = 0;      // Normal min level (sorts the picker by tier)

            // Entry requirements per dungeon difficulty (index = Difficulty enum
            // 0/1/2), read from dungeon_access_template with LFGDungeons.dbc as
            // the fallback for maps that have no access row. 0 = no requirement.
            uint32 minLevel[DUNGEON_DIFFICULTY_COUNT] = { 0, 0, 0 };
            uint32 minItemLevel[DUNGEON_DIFFICULTY_COUNT] = { 0, 0, 0 };
            // Top of the level bracket (LFGDungeons.dbc MaxLevel, or the DB's
            // max_level when it sets one). 0 = no upper bound, which is what
            // custom DC instances with no LFG row get.
            uint32 maxLevel[DUNGEON_DIFFICULTY_COUNT] = { 0, 0, 0 };
        };

        // Lazily build (after DBCs are loaded) and return cached catalogs.
        std::vector<DungeonEntry> const& GetMythicDungeons();
        std::vector<RaidEntry> const& GetRaids();
        std::vector<uint32> const& GetMythicDungeonMapIds();
        bool MapSupportsDifficulty(uint32 mapId, uint8 difficulty);

        // Entry level / item level for a dungeon map at a difficulty. 0 when the
        // map is unknown or carries no requirement.
        uint32 GetDungeonMinLevel(uint32 mapId, uint8 difficulty);
        uint32 GetDungeonMinItemLevel(uint32 mapId, uint8 difficulty);
        uint32 GetDungeonMaxLevel(uint32 mapId, uint8 difficulty);
    }

    enum QueueCategory : uint8
    {
        QUEUE_CAT_DUNGEON = 1,  // 5-man Mythic 0 dungeon
        QUEUE_CAT_RAID    = 2   // raid (10/25)
    };

    enum QueueRoleFlag : uint8
    {
        QROLE_TANK   = 1,
        QROLE_HEALER = 2,
        QROLE_DPS    = 4
    };

    // ------------------------------------------------------------------------
    // Bot backfill provider.
    //
    // scripts.lib (this file) and modules.lib are sibling targets -- neither
    // links the other -- so the queue cannot call into mod-playerbots directly.
    // Instead the module registers these two function pointers at startup and
    // the queue calls back through them. With no provider registered (bots
    // disabled, or the module not built) every call site degrades to "no bots
    // available" and the queue behaves exactly as it did before.
    // ------------------------------------------------------------------------
    struct BotProvider
    {
        // True when this player is AI-controlled rather than a real client.
        bool (*IsBot)(Player* player) = nullptr;

        // Append up to `count` idle bots that can fill ANY role in `roleMask`
        // and whose level is within [minLevel, maxLevel] (maxLevel 0 = no cap).
        // Bots that are grouped, in combat, dead or inside an instance must not
        // be returned. Returns how many were appended to `out`.
        uint32 (*Recruit)(uint8 roleMask, uint8 minLevel, uint8 maxLevel,
                          uint32 count, std::vector<Player*>& out) = nullptr;
    };

    // Called once from the module's startup. Passing a default-constructed
    // provider clears it.
    void RegisterBotProvider(BotProvider const& provider);
    bool HasBotProvider();

    // Role counts a group still needs (tank / healer / dps).
    struct RoleNeed
    {
        uint8 tank = 0;
        uint8 healer = 0;
        uint8 dps = 0;

        [[nodiscard]] uint8 Total() const
        {
            return static_cast<uint8>(tank + healer + dps);
        }

        [[nodiscard]] bool Empty() const { return Total() == 0; }
    };

    // A single player's spot in the queue.
    struct QueueEntry
    {
        ObjectGuid guid;
        std::string name;
        uint8 category   = QUEUE_CAT_DUNGEON;
        uint8 roles      = QROLE_DPS;   // roles the player is willing to fill (bitmask)
        uint32 dungeonId = 0;           // raids: the map. Dungeons: legacy single pick,
                                        // kept in sync with dungeonIds (0 = random).
        // Blizzlike "Specific Dungeons": the player ticks any number of maps and
        // matches against the intersection with other queuers. EMPTY means the
        // random-dungeon queue (any catalog map), which is what earns the daily
        // reward -- exactly as stock treats LFG_TYPE_RANDOM.
        std::vector<uint32> dungeonIds;

        [[nodiscard]] bool IsRandom() const { return dungeonIds.empty(); }
        [[nodiscard]] bool Wants(uint32 mapId) const
        {
            if (dungeonIds.empty())
                return true;   // random: any map in the catalog will do
            return std::find(dungeonIds.begin(), dungeonIds.end(), mapId) != dungeonIds.end();
        }
        uint8 difficulty = 0;           // dungeon/raid difficulty enum value
        uint32 raidSize  = 0;           // 10 or 25 for raids, 0 for dungeons
        uint8 playerClass = 0;
        uint8 level       = 80;
        time_t joinedAt   = 0;
        bool inProposal   = false;      // pulled into an active proposal
        uint32 groupId    = 0;          // 0 = solo; else the party leader's guid
                                        // (all members of a queued party share it)
    };

    // A formed match awaiting ready-check confirmation.
    struct MatchProposal
    {
        uint32 id        = 0;
        uint8 category   = QUEUE_CAT_DUNGEON;
        uint32 dungeonId = 0;
        uint8 difficulty = 0;
        uint32 raidSize  = 0;
        std::vector<ObjectGuid> members;
        // guidLow -> response: -1 declined, 0 pending, 1 accepted
        std::unordered_map<uint32, int8> responses;
        // guidLow -> assigned role flag
        std::unordered_map<uint32, uint8> assignedRoles;
        // Members that were backfilled from the bot pool. They hold no queue
        // entry, are pre-accepted (nothing is there to click a ready-check) and
        // are simply dropped if the proposal dissolves.
        std::unordered_set<uint32> bots;
        // True when at least one real member queued for "any dungeon": stock
        // LFG only applies the random-dungeon cooldown / reward path to those.
        bool randomQueue = false;
        time_t createdAt = 0;

        [[nodiscard]] bool IsBotMember(uint32 guidLow) const
        {
            return bots.find(guidLow) != bots.end();
        }
    };

    // A group the queue formed, tracked from teleport-in until it disbands so
    // the stock LFG lifecycle rules can be applied to it: teleport-out on
    // leave, the deserter debuff, Luck of the Draw, and the completion reward.
    struct FormedGroup
    {
        uint32 mapId      = 0;
        uint8 difficulty  = 0;
        uint8 category    = QUEUE_CAT_DUNGEON;
        bool randomQueue  = false;
        bool completed    = false;
        time_t formedAt   = 0;
        std::set<uint32> members;   // guidLow, real players only
        std::set<uint32> bots;      // guidLow, backfilled bots
        uint8 strangerCount = 0;    // real players not from the same pre-made party
        uint8 kicksUsed = 0;        // successful vote kicks so far (stock: max 2)

        [[nodiscard]] bool IsBot(uint32 guidLow) const { return bots.count(guidLow) != 0; }
    };

    // Rolling average wait per role, fed each time a proposal forms. Drives the
    // per-role ETA the client shows (stock LFGQueue keeps the same statistic).
    struct WaitStats
    {
        uint32 samples = 0;
        uint32 avgSec  = 0;

        void Add(uint32 waitedSec)
        {
            // Bounded window so the estimate follows the current queue, not
            // the whole uptime.
            uint32 n = std::min<uint32>(samples, 50);
            avgSec = (avgSec * n + waitedSec) / (n + 1);
            if (samples < 50)
                ++samples;
        }
    };

    // An in-progress vote kick on a matchmade group. Rules mirror stock LFG:
    // 120s to vote, 3 agreeing votes kick / 3 refusing votes cancel, the kicker
    // auto-agrees and the victim auto-refuses, and each group only gets a
    // limited number of successful kicks (LFG.MaxKickCount).
    struct BootState
    {
        ObjectGuid victim;
        ObjectGuid kicker;
        std::string victimName;
        std::string reason;
        time_t cancelTime = 0;
        // guidLow -> -1 refused, 0 pending, 1 agreed
        std::unordered_map<uint32, int8> votes;

        [[nodiscard]] uint8 CountAgree() const
        {
            uint8 n = 0;
            for (auto const& [g, v] : votes)
                if (v == 1) ++n;
            return n;
        }
        [[nodiscard]] uint8 CountRefuse() const
        {
            uint8 n = 0;
            for (auto const& [g, v] : votes)
                if (v == -1) ++n;
            return n;
        }
    };

    class MatchmakingQueue
    {
    public:
        static MatchmakingQueue& Instance();

        // Why `player` cannot enter `mapId` at `difficulty`, in the wording the
        // client shows on the locked row. Empty when they can. Mirrors the
        // stock LFG lock statuses (level, gear, attunement quest/item/
        // achievement) and ends on Player::Satisfy so it can never disagree
        // with what MapMgr::PlayerCannotEnter enforces at the instance door.
        std::string GetEntryLockReason(Player* player, uint32 mapId, uint8 difficulty,
                                       bool isPartyLeader = true);

        // False when the player has out-levelled this dungeon's bracket. Kept
        // separate from GetEntryLockReason because the random roll must never
        // hand out trivial content even when the lock is switched off.
        bool IsWithinLevelBracket(Player* player, uint32 mapId, uint8 difficulty) const;

        // Bracket top in force for a dungeon: the DBC value, or one derived from
        // the entry level when the DBC has none. 0 means genuinely unbounded.
        uint32 EffectiveMaxLevel(uint32 mapId, uint8 difficulty) const;

        // Vote kick. StartBoot returns true when it took ownership of a leader
        // kick (Group::RemoveMember then skips the removal); it is also what the
        // addon's own "Vote to kick" button calls.
        bool StartBoot(Group* group, ObjectGuid kicker, ObjectGuid victim, std::string const& reason);
        void CastBootVote(Player* voter, bool agree);
        void SendBootState(Group* group);

        // Lifecycle hooks for groups this queue formed (called from scripts).
        void OnGroupMemberRemoved(Group* group, ObjectGuid guid, RemoveMethod method);
        void OnGroupDisband(Group* group);
        void OnPlayerMapChanged(Player* player);
        void OnEncounterComplete(Map* map, uint32 lfgDungeonId);

        void LoadConfig();
        void Update(uint32 diff);

        // Player-driven actions (called from message handlers)
        // `dungeonIds` is the blizzlike "Specific Dungeons" tick list; empty
        // means the random-dungeon queue. Raids pass exactly one map.
        void JoinQueue(Player* player, uint8 category, uint8 roles,
                       std::vector<uint32> dungeonIds, uint8 difficulty, uint32 raidSize);
        void LeaveQueue(Player* player, bool notify = true);
        void SendStatus(Player* player);
        void HandleProposalResponse(Player* player, uint32 proposalId, bool accept);

        // Cleanup
        void OnPlayerLogout(uint32 guidLow);

    private:
        MatchmakingQueue() = default;

        // Matching
        void TryFormMatches();
        bool TryFormDungeonMatch();
        bool TryFormRaidMatch();
        // Returns false when no proposal was formed (the picks are then left
        // untouched in the queue) -- the match loop relies on that to terminate.
        bool CreateProposal(std::vector<uint32> const& picksGuidLow,
                            std::unordered_map<uint32, uint8> const& roleAssign,
                            uint8 category, uint32 dungeonId, uint8 difficulty,
                            uint32 raidSize,
                            std::vector<std::pair<ObjectGuid, uint8>> const& botPicks = {});

        // Recruit bots to complete a group the queued players cannot fill on
        // their own. `need` is what is still missing after the human placement;
        // returns the (guid, role) pairs to add, empty when backfill is off, no
        // provider is registered, or not enough suitable bots exist.
        // (caller holds _mutex)
        std::vector<std::pair<ObjectGuid, uint8>> RecruitBotFillers(
            RoleNeed const& need, uint8 minLevel, uint32 dungeonId, uint8 difficulty);

        // True when the longest-waiting player in `guidLows` has waited past the
        // backfill delay. (caller holds _mutex)
        bool BackfillDelayElapsed(std::vector<uint32> const& guidLows) const;

        // Proposal lifecycle
        void CheckProposalTimeouts();
        void FinalizeProposal(uint32 proposalId);
        void DissolveProposal(uint32 proposalId, bool requeueAccepters,
                              char const* reason);
        void TeleportAndForm(MatchProposal const& proposal);

        // Helpers
        FormedGroup* FindFormedGroup(ObjectGuid groupGuid);
        void CheckBootTimeouts();
        // Drains _pendingBotEvictions. Must run outside any group hook: see the comment on that member.
        void ProcessPendingBotEvictions();
        // Resolve a finished vote. (caller must NOT hold _mutex)
        void ResolveBoot(ObjectGuid groupGuid, bool passed, char const* reason);
        void RecordWait(uint8 category, uint8 role, uint32 waitedSec);
        void AppendWaitEstimates(JsonMessage& msg, uint8 category) const;
        QueueEntry* FindEntry(uint32 guidLow);
        void RemoveEntry(uint32 guidLow);
        void BroadcastStatus(uint8 category);
        void SendProposalUpdate(MatchProposal const& proposal);

        std::vector<QueueEntry> _queue;
        std::unordered_map<uint32, MatchProposal> _proposals;
        std::unordered_map<ObjectGuid, FormedGroup> _formedGroups;
        std::unordered_map<ObjectGuid, BootState> _boots;
        // Bots to drop from a group whose last real player left. Removing a member from inside
        // GroupScript::OnRemoveMember re-enters Group::RemoveMember, and the last of those removals
        // disbands the group -- which deletes it while the outer Group::RemoveMember frame is still
        // running and about to call SendUpdate() on it. So the removals are queued here and carried out
        // from Update() instead, one world tick later.
        struct PendingBotEviction
        {
            ObjectGuid groupGuid;
            uint32 botLow = 0;
        };
        std::vector<PendingBotEviction> _pendingBotEvictions;
        uint32 _bootTimerMs = 0;
        // [category][role-index 0=tank 1=healer 2=dps]
        WaitStats _waitStats[3][3];
        uint32 _nextProposalId = 1;
        uint32 _matchTimerMs   = 0;
        uint32 _statusTimerMs  = 0;
        uint32 _proposalTimerMs = 0;

        // Config
        bool _enabled               = true;
        uint32 _proposalTimeoutSec  = 40;
        uint32 _matchIntervalMs     = 3000;
        uint32 _statusIntervalMs    = 5000;
        uint32 _maxQueuesPerPlayer  = 3;   // solo players may sit in N queues
        uint32 _debugMinPlayers     = 0;   // >0: dungeon pops at N (any roles) for testing

        // Bot backfill. Bots never queue on their own -- they are only pulled in
        // to complete a group that already has at least one real player waiting.
        bool _botsEnabled            = true;
        uint32 _botBackfillAfterSec  = 60;  // real players wait this long first
        uint32 _botsMaxPerGroup      = 4;   // hard ceiling; never an all-bot group
        bool _botsForRaids           = false;  // raids are opt-in, 10-24 bots is a lot
        uint32 _botLevelSlack        = 5;   // bot level band around the queued players

        // Stock Dungeon Finder lifecycle rules, each switchable.
        bool _applyRandomCooldown    = true;   // 71328 on random-queue match, 150s on decline
        bool _applyLuckOfTheDraw     = true;   // 72221 while inside the formed group's dungeon
        bool _rewardOnCompletion     = true;   // pay the daily reward on the final boss, not on pop
        uint8 _deserterMinGroupSize  = 3;      // stock: no deserter once the group is already broken

        // Vote kick (stock LFG values: LFG_TIME_BOOT / LFG_GROUP_KICK_VOTES_NEEDED
        // / LFG.MaxKickCount).
        // Out-levelled dungeons are locked, as stock does with
        // LFG_LOCKSTATUS_TOO_HIGH_LEVEL. The bracket cap keeps max-level
        // characters on this 255 server from falling off the top of the WotLK
        // data (Halls of Reflection Normal is Min 80 / Max 80).
        bool _maxLevelLock           = true;
        uint32 _levelBracketCap      = 80;
        // Bracket width assumed for a dungeon that has an entry level but no
        // LFGDungeons MaxLevel (Blackrock Spire is one). Without this such a
        // dungeon has no upper bound at all and the random roll can drop a
        // level 80 into level 45 content.
        uint32 _levelBracketWidth    = 15;

        bool _voteKickEnabled        = true;
        uint32 _bootDurationSec      = 120;
        uint8 _bootVotesNeeded       = 3;
        // -1 = inherit the stock finder's LFG.MaxKickCount. Resolved lazily in
        // MaxKicks(): LoadConfig() runs from ScriptMgr::Initialize, long before
        // sWorld's config cache is populated, and reading it there asserts.
        int32 _bootMaxKicks          = -1;

        [[nodiscard]] uint8 MaxKicks() const;

        std::mutex _mutex;
    };
}  // namespace Matchmaking

    #define sMatchmakingQueue DCAddon::Matchmaking::MatchmakingQueue::Instance()

}  // namespace DCAddon

#endif  // DC_ADDON_MATCHMAKING_H
