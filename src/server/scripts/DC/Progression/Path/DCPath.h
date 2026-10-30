/*
 * DarkChaos Path of Chaos
 *
 * The long road through the DC systems, in the spirit of Ascension's Path to Ascension: a book
 * of one-time tasks and milestones, each paying Shop Points that the Collection shop takes.
 *
 * Where it differs from the original:
 *
 * - The book is data (world tables dc_path_categories / dc_path_tasks) sent to the client and
 *   cached by revision, not a client DBC. A task is one SQL row and `.path reload`.
 * - Progress is per account. Shop Points buy account-wide collectibles, and a per-character
 *   book would pay out again on every alt.
 * - A task has one objective. A multi-step goal is a chain through prev_task_id.
 *
 * Objectives come in two kinds:
 *
 * - Milestones raise progress to a value read from the game (level, prestige, item level,
 *   collection size). They are re-read at login, so they credit what the account has already
 *   done, and they never fall back: a prestige resets a level, not the path.
 * - Counted tasks add up events from the systems themselves, delivered by the CrossSystem bus
 *   or core hooks. Nothing from before this system existed counts.
 *
 * All of it is decided on the server. The client only ever asks to collect what the server has
 * already recorded as complete.
 *
 * Threading: kills, quests and encounters arrive on map threads while claims and the shop run
 * on the world thread, so the account table sits behind one mutex. The book is immutable once
 * published and is swapped whole by a reload. Nothing calls out to a Player, the database or
 * the network while holding the lock.
 */

#ifndef DC_PROGRESSION_PATH_H
#define DC_PROGRESSION_PATH_H

#include "Define.h"

#include <array>
#include <memory>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>

class Player;
class ResultSet;

namespace DarkChaos
{
namespace Path
{
    // Stored in dc_path_tasks.objective_type: values are permanent. Unless noted the filter is
    // an exact match on the id named here, and 0 matches anything.
    enum class ObjectiveType : uint8
    {
        None                = 0,

        // Milestones: progress follows a value read from the game.
        Level               = 1,    // Highest character level reached
        Prestige            = 2,    // Highest prestige level reached
        ItemLevel           = 3,    // Highest average equipped item level
        Collection          = 4,    // Collectibles owned. Filter: DCCollection::CollectionType

        // Counted tasks: progress adds up events.
        QuestTurnIn         = 10,   // Filter: quest id
        DailyQuest          = 11,
        WeeklyQuest         = 12,
        CreatureKill        = 13,   // Filter: creature entry. Credits every rewarded group member
        WorldBossKill       = 14,   // Filter: creature entry. Bosses WorldBossMgr knows
        RareKill            = 15,   // Filter: creature entry
        DungeonClear        = 16,   // Filter: minimum difficulty, 1 Normal, 2 Heroic, 3 Mythic.
                                    // Stock dungeons only: custom maps have no LFG entry, so the
                                    // core never calls them finished. Use CreatureKill on their
                                    // last boss
        Achievement         = 17,   // Filter: achievement id, never 0. Re-read at login like a
                                    // milestone, so one earned before the book existed counts

        MythicPlusRun       = 20,   // Filter: minimum keystone level
        MythicPlusTimed     = 21,   // Filter: minimum keystone level
        VaultClaim          = 22,

        ItemUpgrade         = 30,   // Filter: minimum upgrade level reached
        EnchantReroll       = 31,
        Transmutation       = 32,

        BattlegroundWin     = 40,   // Filter: BattlegroundTypeId (20 Hinterland, 120 Gilneas)
        BattlegroundEnd     = 41,   // Filter: BattlegroundTypeId
        ArenaWin            = 42,
        DuelWin             = 43,

        ZoneVisit           = 50,   // Filter: zone id. Custom maps report one baked zone: MapVisit
        MapVisit            = 51,   // Filter: map id
        HotspotVisit        = 52,
        GuildHouseVisit     = 53,

        ShopPurchase        = 60,
        Transmog            = 61,
        GroupFinder         = 62,
        PrestigeChallenge   = 63,   // Filter: challenge type (1 Iron, 2 Speed, 3 Solo)
        SeasonChest         = 64,
        WorldforgedPickup   = 65,
        Spectate            = 66,

        Max
    };

    enum TaskFlag : uint8
    {
        TASK_FLAG_COMPLETED = 0x01,
        TASK_FLAG_CLAIMED   = 0x02
    };

    struct TaskReward
    {
        uint32 points = 0;
        uint32 itemId = 0;
        uint32 itemCount = 0;
        uint8 collectionType = 0;       // DCCollection::CollectionType, 0 = none
        uint32 collectionEntry = 0;
    };

    struct Task
    {
        uint32 id = 0;
        uint32 categoryId = 0;
        uint32 sortOrder = 0;
        std::string name;
        std::string description;
        std::string icon;
        ObjectiveType objective = ObjectiveType::None;
        uint32 filter = 0;
        uint32 target = 1;
        uint32 prevTaskId = 0;
        TaskReward reward;
    };

    struct Category
    {
        uint32 id = 0;
        uint32 sortOrder = 0;
        std::string name;
        std::string description;
        std::string icon;
    };

    // The whole book, immutable once published.
    struct Catalog
    {
        std::vector<Category> categories;
        std::vector<Task> tasks;
        std::unordered_map<uint32, uint32> taskIndex;   // task id -> index into tasks
        uint32 revision = 0;

        // Indexes into tasks per objective, so an event only walks the tasks that want it.
        std::array<std::vector<uint32>, static_cast<size_t>(ObjectiveType::Max)> byObjective;

        Task const* Find(uint32 taskId) const;
        std::vector<uint32> const& TasksFor(ObjectiveType type) const;
    };

    using CatalogPtr = std::shared_ptr<Catalog const>;

    // One task's state as it travels to the client.
    struct ProgressEntry
    {
        uint32 taskId = 0;
        uint32 progress = 0;
        uint8 flags = 0;
    };

    struct AccountSnapshot
    {
        bool loaded = false;
        uint32 points = 0;
        uint32 earned = 0;
        std::vector<ProgressEntry> tasks;
    };

    struct ClaimOutcome
    {
        bool ok = false;
        std::string message;
        std::vector<uint32> claimed;
        uint32 paid = 0;        // Shop Points this claim paid out
        uint32 points = 0;      // Balance afterwards
    };

    class PathMgr
    {
    public:
        static PathMgr* instance();

        // Reads the book. Startup and `.path reload`. Returns the number of usable tasks.
        uint32 LoadCatalog();

        bool IsEnabled() const;
        CatalogPtr GetCatalog() const;

        // Login: reads the account once per uptime, then re-reads the milestones.
        void HandleLogin(Player* player);

        // Milestones from the character in hand. Cheap enough for level and equip changes.
        void RefreshMilestones(Player* player);

        // Recounts the account's collection (asynchronously, at most every 30 seconds).
        // Collectibles reach the account by many routes, so this reads the result of all of
        // them rather than hooking each one.
        void RefreshCollection(Player* player);

        // Adds `amount` to every counted task of this objective whose filter `value` meets.
        void Record(Player* player, ObjectiveType type, uint32 value = 0, uint32 amount = 1);

        // Raises every milestone of this objective to `value`.
        void Raise(Player* player, ObjectiveType type, uint32 value, uint32 filterValue = 0);

        // Where the player stands now. Called on arrival, and at login because a character
        // already on the map never arrives.
        void RefreshLocation(Player* player);

        // The client asked for its state. Answered at once, or when the account finishes
        // loading if the request beat it there.
        void RequestState(Player* player);

        AccountSnapshot GetSnapshot(uint32 accountId) const;

        ClaimOutcome Claim(Player* player, uint32 taskId);
        ClaimOutcome ClaimAll(Player* player);

        // Shop Points. The balance belongs to the account, so these are safe for any of its
        // characters; the Player is only who gets told.
        uint32 GetPoints(uint32 accountId) const;
        bool TrySpendPoints(Player* player, uint32 amount);
        void RefundPoints(Player* player, uint32 amount);

        // GM tools (`.path`). They act on loaded accounts, which any online account is.
        bool ForceComplete(Player* player, uint32 taskId);
        void GrantPoints(Player* player, uint32 amount);
        void ResetAccount(Player* player);

    private:
        PathMgr() = default;

        struct TaskProgress
        {
            uint32 progress = 0;
            uint32 completedAt = 0;
            uint32 claimedAt = 0;
        };

        struct AccountData
        {
            bool loaded = false;
            bool loading = false;
            bool stateRequested = false;    // The client asked before the account had loaded
            bool recountRunning = false;
            uint32 lastRecountMs = 0;
            uint32 points = 0;
            uint32 earned = 0;
            std::unordered_map<uint32, TaskProgress> tasks;
        };

        static ProgressEntry ToEntry(uint32 taskId, TaskProgress const& state);
        static uint8 FlagsOf(TaskProgress const& state);
        static bool MatchesFilter(Task const& task, uint32 value);

        // Caller holds _lock. True when the task moved.
        static bool Advance(Task const& task, TaskProgress& state, uint32 progress, uint32 now);

        // Caller holds _lock.
        static std::string ClaimRefusal(Catalog const& catalog, AccountData const& account, Task const& task);

        void BeginLoad(uint32 accountId);
        void FinishLoad(uint32 accountId, ResultSet* rows);
        void FinishRecount(uint32 accountId, ResultSet* rows);

        // Writes the changed rows and tells the client.
        void Publish(Player* player, std::vector<ProgressEntry> const& changed, uint32 points);
        void PayClaims(Player* player, CatalogPtr const& catalog, std::vector<uint32> const& taskIds);

        CatalogPtr Snapshot() const;

        mutable std::mutex _lock;
        CatalogPtr _catalog;
        bool _enabled = false;
        std::unordered_map<uint32, AccountData> _accounts;
    };

    // Client side of the state changes (dc_addon_path.cpp).
    void SendTaskUpdates(Player* player, std::vector<ProgressEntry> const& updates, uint32 points);
    void SendState(Player* player);
}
}

#define sPathMgr DarkChaos::Path::PathMgr::instance()

#endif // DC_PROGRESSION_PATH_H
