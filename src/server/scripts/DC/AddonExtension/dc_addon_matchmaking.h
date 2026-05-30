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
#include <mutex>
#include <string>

class Player;

namespace DCAddon
{
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
        };

        struct DungeonEntry
        {
            uint32 mapId = 0;
            std::string name;
            uint32 expansion = 0;
        };

        // Lazily build (after DBCs are loaded) and return cached catalogs.
        std::vector<DungeonEntry> const& GetMythicDungeons();
        std::vector<RaidEntry> const& GetRaids();
        std::vector<uint32> const& GetMythicDungeonMapIds();
        bool MapSupportsDifficulty(uint32 mapId, uint8 difficulty);
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

    // A single player's spot in the queue.
    struct QueueEntry
    {
        ObjectGuid guid;
        std::string name;
        uint8 category   = QUEUE_CAT_DUNGEON;
        uint8 roles      = QROLE_DPS;   // roles the player is willing to fill (bitmask)
        uint32 dungeonId = 0;           // specific dungeon/raid map; 0 = any (dungeons)
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
        time_t createdAt = 0;
    };

    class MatchmakingQueue
    {
    public:
        static MatchmakingQueue& Instance();

        void LoadConfig();
        void Update(uint32 diff);

        // Player-driven actions (called from message handlers)
        void JoinQueue(Player* player, uint8 category, uint8 roles, uint32 dungeonId,
                       uint8 difficulty, uint32 raidSize);
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
        void CreateProposal(std::vector<uint32> const& picksGuidLow,
                            std::unordered_map<uint32, uint8> const& roleAssign,
                            uint8 category, uint32 dungeonId, uint8 difficulty,
                            uint32 raidSize);

        // Proposal lifecycle
        void CheckProposalTimeouts();
        void FinalizeProposal(uint32 proposalId);
        void DissolveProposal(uint32 proposalId, bool requeueAccepters,
                              char const* reason);
        void TeleportAndForm(MatchProposal const& proposal);

        // Helpers
        QueueEntry* FindEntry(uint32 guidLow);
        void RemoveEntry(uint32 guidLow);
        void BroadcastStatus(uint8 category);
        void SendProposalUpdate(MatchProposal const& proposal);

        std::vector<QueueEntry> _queue;
        std::unordered_map<uint32, MatchProposal> _proposals;
        uint32 _nextProposalId = 1;
        uint32 _matchTimerMs   = 0;
        uint32 _statusTimerMs  = 0;

        // Config
        bool _enabled               = true;
        uint32 _proposalTimeoutSec  = 40;
        uint32 _matchIntervalMs     = 3000;
        uint32 _statusIntervalMs    = 5000;

        std::mutex _mutex;
    };
}  // namespace Matchmaking

    #define sMatchmakingQueue DCAddon::Matchmaking::MatchmakingQueue::Instance()

}  // namespace DCAddon

#endif  // DC_ADDON_MATCHMAKING_H
