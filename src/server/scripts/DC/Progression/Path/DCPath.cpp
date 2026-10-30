/*
 * DarkChaos Path of Chaos - catalog, account state, claims and Shop Points.
 * See DCPath.h for the design.
 */

#include "DCPath.h"

#include "Config.h"
#include "DatabaseEnv.h"
#include "GameTime.h"
#include "Log.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "QueryResult.h"
#include "StringFormat.h"
#include "Timer.h"
#include "WorldSession.h"
#include "WorldSessionMgr.h"
#include "DC/AddonExtension/dc_addon_namespace.h"
#include "DC/CollectionSystem/CollectionGrant.h"
#include "DC/CrossSystem/CrossSystemDbSchema.h"
#include "DC/CrossSystem/RewardDistributor.h"
#include "DC/GuildHousing/dc_guildhouse.h"
#include "DC/Progression/Prestige/dc_prestige_api.h"

#include <algorithm>

namespace DarkChaos
{
namespace Path
{
    namespace
    {
        constexpr uint32 COLLECTION_RECOUNT_INTERVAL_MS = 30 * IN_MILLISECONDS;

        constexpr char const* CONFIG_ENABLED = "DCPath.Enable";

        bool IsCollectionTypeValid(uint8 type)
        {
            return type >= uint8(DCCollection::CollectionType::MOUNT)
                && type <= uint8(DCCollection::CollectionType::TRANSMOG);
        }

        // Where the filter is a threshold rather than an id.
        bool HasMinimumFilter(ObjectiveType type)
        {
            switch (type)
            {
                case ObjectiveType::DungeonClear:
                case ObjectiveType::MythicPlusRun:
                case ObjectiveType::MythicPlusTimed:
                case ObjectiveType::ItemUpgrade:
                    return true;
                default:
                    return false;
            }
        }

        bool IsKnownObjective(uint32 type)
        {
            switch (static_cast<ObjectiveType>(type))
            {
                case ObjectiveType::Level:
                case ObjectiveType::Prestige:
                case ObjectiveType::ItemLevel:
                case ObjectiveType::Collection:
                case ObjectiveType::QuestTurnIn:
                case ObjectiveType::DailyQuest:
                case ObjectiveType::WeeklyQuest:
                case ObjectiveType::CreatureKill:
                case ObjectiveType::WorldBossKill:
                case ObjectiveType::RareKill:
                case ObjectiveType::DungeonClear:
                case ObjectiveType::Achievement:
                case ObjectiveType::MythicPlusRun:
                case ObjectiveType::MythicPlusTimed:
                case ObjectiveType::VaultClaim:
                case ObjectiveType::ItemUpgrade:
                case ObjectiveType::EnchantReroll:
                case ObjectiveType::Transmutation:
                case ObjectiveType::BattlegroundWin:
                case ObjectiveType::BattlegroundEnd:
                case ObjectiveType::ArenaWin:
                case ObjectiveType::DuelWin:
                case ObjectiveType::ZoneVisit:
                case ObjectiveType::MapVisit:
                case ObjectiveType::HotspotVisit:
                case ObjectiveType::GuildHouseVisit:
                case ObjectiveType::ShopPurchase:
                case ObjectiveType::Transmog:
                case ObjectiveType::GroupFinder:
                case ObjectiveType::PrestigeChallenge:
                case ObjectiveType::SeasonChest:
                case ObjectiveType::WorldforgedPickup:
                case ObjectiveType::Spectate:
                    return true;
                default:
                    return false;
            }
        }

        uint32 HashText(uint32 hash, std::string const& text)
        {
            for (unsigned char const c : text)
            {
                hash ^= c;
                hash *= 16777619u;
            }
            return hash;
        }

        uint32 HashNumber(uint32 hash, uint32 value)
        {
            for (uint32 shift = 0; shift < 32; shift += 8)
            {
                hash ^= (value >> shift) & 0xFF;
                hash *= 16777619u;
            }
            return hash;
        }

        // The revision the client caches the book by, so a changed row reaches every client
        // and an unchanged book costs one short exchange at login.
        uint32 ComputeRevision(Catalog const& catalog)
        {
            uint32 hash = 2166136261u;
            for (Category const& category : catalog.categories)
            {
                hash = HashNumber(hash, category.id);
                hash = HashNumber(hash, category.sortOrder);
                hash = HashText(hash, category.name);
                hash = HashText(hash, category.description);
                hash = HashText(hash, category.icon);
            }

            for (Task const& task : catalog.tasks)
            {
                hash = HashNumber(hash, task.id);
                hash = HashNumber(hash, task.categoryId);
                hash = HashNumber(hash, task.sortOrder);
                hash = HashText(hash, task.name);
                hash = HashText(hash, task.description);
                hash = HashText(hash, task.icon);
                hash = HashNumber(hash, uint32(task.objective));
                hash = HashNumber(hash, task.filter);
                hash = HashNumber(hash, task.target);
                hash = HashNumber(hash, task.prevTaskId);
                hash = HashNumber(hash, task.reward.points);
                hash = HashNumber(hash, task.reward.itemId);
                hash = HashNumber(hash, task.reward.itemCount);
                hash = HashNumber(hash, task.reward.collectionType);
                hash = HashNumber(hash, task.reward.collectionEntry);
            }

            // 0 is what a client with no cached book sends.
            return hash ? hash : 1;
        }

        bool ValidateTaskReward(Task& task)
        {
            TaskReward& reward = task.reward;
            if (reward.itemId)
            {
                if (!reward.itemCount || !sObjectMgr->GetItemTemplate(reward.itemId))
                {
                    LOG_ERROR("sql.sql", "Path of Chaos: task {} rewards item {} x{}, which does not exist.",
                        task.id, reward.itemId, reward.itemCount);
                    return false;
                }
            }

            if (reward.collectionType)
            {
                auto const type = static_cast<DCCollection::CollectionType>(reward.collectionType);
                reward.collectionEntry = IsCollectionTypeValid(reward.collectionType)
                    ? DCCollection::NormalizeCollectibleEntry(type, reward.collectionEntry) : 0;

                if (!reward.collectionEntry || !DCCollection::ValidateCollectibleEntry(type, reward.collectionEntry))
                {
                    LOG_ERROR("sql.sql", "Path of Chaos: task {} rewards collectible type {}, which does not resolve.",
                        task.id, reward.collectionType);
                    return false;
                }
            }

            return true;
        }

        // Prerequisites load after every row exists, and a cycle would lock its tasks forever.
        bool ChainReachesItself(Catalog const& catalog, Task const& start)
        {
            std::size_t steps = 0;
            for (Task const* step = catalog.Find(start.prevTaskId); step; step = catalog.Find(step->prevTaskId))
            {
                if (step->id == start.id || ++steps > catalog.tasks.size())
                    return true;
            }
            return false;
        }
    }

    Task const* Catalog::Find(uint32 taskId) const
    {
        auto const itr = taskIndex.find(taskId);
        return itr != taskIndex.end() ? &tasks[itr->second] : nullptr;
    }

    std::vector<uint32> const& Catalog::TasksFor(ObjectiveType type) const
    {
        return byObjective[static_cast<size_t>(type)];
    }

    PathMgr* PathMgr::instance()
    {
        static PathMgr instance;
        return &instance;
    }

    uint32 PathMgr::LoadCatalog()
    {
        uint32 const startMs = getMSTime();
        auto catalog = std::make_shared<Catalog>();

        bool const configured = sConfigMgr->GetOption<bool>(CONFIG_ENABLED, true);
        bool const hasWorldTables = DC::DbSchema::WorldTableExists("dc_path_categories")
            && DC::DbSchema::WorldTableExists("dc_path_tasks");
        bool const hasCharacterTables = DC::DbSchema::CharacterTableExists("dc_path_progress")
            && DC::DbSchema::CharacterTableExists("dc_path_points");

        if (configured && (!hasWorldTables || !hasCharacterTables))
            LOG_ERROR("server.loading", ">> Path of Chaos: its tables are missing - apply the pending SQL updates. "
                "Disabled.");

        if (!configured || !hasWorldTables || !hasCharacterTables)
        {
            std::lock_guard<std::mutex> lock(_lock);
            _catalog = catalog;
            _enabled = false;
            return 0;
        }

        if (QueryResult result = WorldDatabase.Query(
            "SELECT id, sort_order, name, description, icon FROM dc_path_categories "
            "WHERE enabled = 1 ORDER BY sort_order, id"))
        {
            do
            {
                Field* fields = result->Fetch();

                Category category;
                category.id = fields[0].Get<uint32>();
                category.sortOrder = fields[1].Get<uint32>();
                category.name = fields[2].Get<std::string>();
                category.description = fields[3].Get<std::string>();
                category.icon = fields[4].Get<std::string>();
                catalog->categories.push_back(std::move(category));
            } while (result->NextRow());
        }

        auto const hasCategory = [&catalog](uint32 categoryId)
        {
            return std::any_of(catalog->categories.begin(), catalog->categories.end(),
                [categoryId](Category const& category) { return category.id == categoryId; });
        };

        if (QueryResult result = WorldDatabase.Query(
            "SELECT id, category_id, sort_order, name, description, icon, objective_type, objective_filter, "
            "objective_target, prev_task_id, reward_points, reward_item_id, reward_item_count, "
            "reward_collection_type, reward_collection_entry "
            "FROM dc_path_tasks WHERE enabled = 1 ORDER BY category_id, sort_order, id"))
        {
            do
            {
                Field* fields = result->Fetch();

                Task task;
                task.id = fields[0].Get<uint32>();
                task.categoryId = fields[1].Get<uint32>();
                task.sortOrder = fields[2].Get<uint32>();
                task.name = fields[3].Get<std::string>();
                task.description = fields[4].Get<std::string>();
                task.icon = fields[5].Get<std::string>();

                uint32 const objective = fields[6].Get<uint32>();
                task.objective = static_cast<ObjectiveType>(objective);
                task.filter = fields[7].Get<uint32>();
                task.target = fields[8].Get<uint32>();
                task.prevTaskId = fields[9].Get<uint32>();
                task.reward.points = fields[10].Get<uint32>();
                task.reward.itemId = fields[11].Get<uint32>();
                task.reward.itemCount = fields[12].Get<uint32>();
                task.reward.collectionType = fields[13].Get<uint8>();
                task.reward.collectionEntry = fields[14].Get<uint32>();

                if (!hasCategory(task.categoryId))
                {
                    LOG_ERROR("sql.sql", "Path of Chaos: task {} is in unknown category {}.", task.id, task.categoryId);
                    continue;
                }

                if (!IsKnownObjective(objective) || !task.target)
                {
                    LOG_ERROR("sql.sql", "Path of Chaos: task {} has an unusable objective (type {}, target {}).",
                        task.id, objective, task.target);
                    continue;
                }

                if (!ValidateTaskReward(task))
                    continue;

                catalog->taskIndex.emplace(task.id, uint32(catalog->tasks.size()));
                catalog->tasks.push_back(std::move(task));
            } while (result->NextRow());
        }

        // A task with a broken prerequisite would stay locked forever and quietly hold its
        // whole chain back, so it opens instead and the log says why.
        std::vector<std::pair<uint32, uint32>> brokenChains;
        for (Task const& task : catalog->tasks)
        {
            if (!task.prevTaskId)
                continue;

            if (!catalog->Find(task.prevTaskId) || ChainReachesItself(*catalog, task))
                brokenChains.emplace_back(task.id, task.prevTaskId);
        }

        for (auto const& [taskId, prevTaskId] : brokenChains)
        {
            LOG_ERROR("sql.sql", "Path of Chaos: task {} requires task {}, which is missing or part of a cycle.",
                taskId, prevTaskId);
            catalog->tasks[catalog->taskIndex.at(taskId)].prevTaskId = 0;
        }

        for (uint32 index = 0; index < catalog->tasks.size(); ++index)
            catalog->byObjective[static_cast<size_t>(catalog->tasks[index].objective)].push_back(index);

        catalog->revision = ComputeRevision(*catalog);

        uint32 const taskCount = uint32(catalog->tasks.size());
        {
            std::lock_guard<std::mutex> lock(_lock);
            _catalog = catalog;
            _enabled = taskCount > 0;
        }

        LOG_INFO("server.loading", ">> Path of Chaos: loaded {} tasks in {} categories in {} ms (revision {}).",
            taskCount, catalog->categories.size(), GetMSTimeDiffToNow(startMs), catalog->revision);
        return taskCount;
    }

    bool PathMgr::IsEnabled() const
    {
        std::lock_guard<std::mutex> lock(_lock);
        return _enabled;
    }

    CatalogPtr PathMgr::Snapshot() const
    {
        std::lock_guard<std::mutex> lock(_lock);
        return _enabled ? _catalog : nullptr;
    }

    CatalogPtr PathMgr::GetCatalog() const
    {
        return Snapshot();
    }

    uint8 PathMgr::FlagsOf(TaskProgress const& state)
    {
        uint8 flags = 0;
        if (state.completedAt)
            flags |= TASK_FLAG_COMPLETED;
        if (state.claimedAt)
            flags |= TASK_FLAG_CLAIMED;
        return flags;
    }

    ProgressEntry PathMgr::ToEntry(uint32 taskId, TaskProgress const& state)
    {
        ProgressEntry entry;
        entry.taskId = taskId;
        entry.progress = state.progress;
        entry.flags = FlagsOf(state);
        return entry;
    }

    bool PathMgr::MatchesFilter(Task const& task, uint32 value)
    {
        if (!task.filter)
            return true;

        return HasMinimumFilter(task.objective) ? value >= task.filter : value == task.filter;
    }

    bool PathMgr::Advance(Task const& task, TaskProgress& state, uint32 progress, uint32 now)
    {
        if (state.completedAt)
            return false;

        uint32 const capped = std::min(progress, task.target);
        if (capped <= state.progress)
            return false;

        state.progress = capped;
        if (capped >= task.target)
            state.completedAt = now;

        return true;
    }

    void PathMgr::HandleLogin(Player* player)
    {
        if (!player || !player->GetSession() || player->GetSession()->IsBot())
            return;

        uint32 const accountId = player->GetSession()->GetAccountId();

        bool load = false;
        bool loaded = false;
        {
            std::lock_guard<std::mutex> lock(_lock);
            if (!_enabled)
                return;

            AccountData& account = _accounts[accountId];
            loaded = account.loaded;
            if (!account.loaded && !account.loading)
            {
                account.loading = true;
                load = true;
            }
        }

        if (load)
            BeginLoad(accountId);
        else if (loaded)
        {
            RefreshMilestones(player);
            RefreshCollection(player);
        }
    }

    void PathMgr::BeginLoad(uint32 accountId)
    {
        // Row 0 is the balance; task ids start at 1.
        std::string const sql = Acore::StringFormat(
            "SELECT task_id, progress, completed_at, claimed_at FROM dc_path_progress WHERE account_id = {} "
            "UNION ALL SELECT 0, balance, lifetime_earned, 0 FROM dc_path_points WHERE account_id = {}",
            accountId, accountId);

        DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(sql).WithCallback(
            [accountId](QueryResult result)
            {
                sPathMgr->FinishLoad(accountId, result.get());
            }));
    }

    void PathMgr::FinishLoad(uint32 accountId, ResultSet* rows)
    {
        bool answerClient = false;
        {
            std::lock_guard<std::mutex> lock(_lock);

            AccountData& account = _accounts[accountId];
            account.loaded = true;
            account.loading = false;
            answerClient = account.stateRequested;
            account.stateRequested = false;

            if (rows)
            {
                do
                {
                    Field* fields = rows->Fetch();
                    uint32 const taskId = fields[0].Get<uint32>();
                    if (!taskId)
                    {
                        account.points = fields[1].Get<uint32>();
                        account.earned = fields[2].Get<uint32>();
                        continue;
                    }

                    TaskProgress& state = account.tasks[taskId];
                    state.progress = fields[1].Get<uint32>();
                    state.completedAt = fields[2].Get<uint32>();
                    state.claimedAt = fields[3].Get<uint32>();
                } while (rows->NextRow());
            }
        }

        WorldSession* session = sWorldSessionMgr->FindSession(accountId);
        Player* player = session ? session->GetPlayer() : nullptr;
        if (!player || !player->IsInWorld())
            return;

        if (answerClient)
            SendState(player);

        RefreshMilestones(player);
        RefreshCollection(player);
    }

    void PathMgr::RefreshMilestones(Player* player)
    {
        if (!player || !player->GetSession() || player->GetSession()->IsBot())
            return;

        Raise(player, ObjectiveType::Level, player->GetLevel());
        Raise(player, ObjectiveType::Prestige, PrestigeAPI::GetPrestigeLevel(player));
        Raise(player, ObjectiveType::ItemLevel, uint32(player->GetAverageItemLevel()));
        RefreshLocation(player);

        if (CatalogPtr const catalog = Snapshot())
        {
            for (uint32 const index : catalog->TasksFor(ObjectiveType::Achievement))
            {
                uint32 const achievementId = catalog->tasks[index].filter;
                if (achievementId && player->HasAchieved(achievementId))
                    Raise(player, ObjectiveType::Achievement, 1, achievementId);
            }
        }
    }

    void PathMgr::RefreshLocation(Player* player)
    {
        if (!player)
            return;

        uint32 const mapId = player->GetMapId();
        Raise(player, ObjectiveType::MapVisit, 1, mapId);
        Raise(player, ObjectiveType::ZoneVisit, 1, player->GetZoneId());

        if (IsGuildHouseMap(mapId))
            Raise(player, ObjectiveType::GuildHouseVisit, 1);
    }

    void PathMgr::RefreshCollection(Player* player)
    {
        if (!player || !player->GetSession() || player->GetSession()->IsBot())
            return;

        uint32 const accountId = player->GetSession()->GetAccountId();

        {
            std::lock_guard<std::mutex> lock(_lock);
            if (!_enabled || !_catalog || _catalog->TasksFor(ObjectiveType::Collection).empty())
                return;

            auto const itr = _accounts.find(accountId);
            if (itr == _accounts.end() || !itr->second.loaded || itr->second.recountRunning)
                return;

            AccountData& account = itr->second;
            uint32 const nowMs = getMSTime();
            if (account.lastRecountMs && getMSTimeDiff(account.lastRecountMs, nowMs) < COLLECTION_RECOUNT_INTERVAL_MS)
                return;

            account.lastRecountMs = nowMs;
            account.recountRunning = true;
        }

        // Appearances live in the wardrobe table; everything else in dc_collection_items.
        std::string const sql = Acore::StringFormat(
            "SELECT collection_type, COUNT(*) FROM dc_collection_items "
            "WHERE account_id = {} AND unlocked = 1 AND collection_type <> {} GROUP BY collection_type "
            "UNION ALL SELECT {}, COUNT(*) FROM dc_transmog_collection WHERE account_id = {}",
            accountId, uint32(DCCollection::CollectionType::TRANSMOG),
            uint32(DCCollection::CollectionType::TRANSMOG), accountId);

        DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(sql).WithCallback(
            [accountId](QueryResult result)
            {
                sPathMgr->FinishRecount(accountId, result.get());
            }));
    }

    void PathMgr::FinishRecount(uint32 accountId, ResultSet* rows)
    {
        {
            std::lock_guard<std::mutex> lock(_lock);
            auto const itr = _accounts.find(accountId);
            if (itr != _accounts.end())
                itr->second.recountRunning = false;
        }

        WorldSession* session = sWorldSessionMgr->FindSession(accountId);
        Player* player = session ? session->GetPlayer() : nullptr;
        if (!player || !player->IsInWorld() || !rows)
            return;

        uint32 total = 0;
        do
        {
            Field* fields = rows->Fetch();
            uint32 const type = fields[0].Get<uint32>();
            uint32 const count = fields[1].Get<uint32>();
            total += count;
            Raise(player, ObjectiveType::Collection, count, type);
        } while (rows->NextRow());

        // A filter of 0 means the whole collection rather than any one type.
        Raise(player, ObjectiveType::Collection, total, 0);
    }

    void PathMgr::Record(Player* player, ObjectiveType type, uint32 value, uint32 amount)
    {
        if (!player || !amount || !player->GetSession() || player->GetSession()->IsBot())
            return;

        uint32 const accountId = player->GetSession()->GetAccountId();
        uint32 const now = uint32(GameTime::GetGameTime().count());

        std::vector<ProgressEntry> changed;
        uint32 points = 0;
        {
            std::lock_guard<std::mutex> lock(_lock);
            if (!_enabled || !_catalog)
                return;

            auto const accountItr = _accounts.find(accountId);
            if (accountItr == _accounts.end() || !accountItr->second.loaded)
                return;

            AccountData& account = accountItr->second;
            points = account.points;

            for (uint32 const index : _catalog->TasksFor(type))
            {
                Task const& task = _catalog->tasks[index];
                if (!MatchesFilter(task, value))
                    continue;

                TaskProgress& state = account.tasks[task.id];
                if (Advance(task, state, state.progress + amount, now))
                    changed.push_back(ToEntry(task.id, state));
            }
        }

        if (!changed.empty())
            Publish(player, changed, points);
    }

    void PathMgr::Raise(Player* player, ObjectiveType type, uint32 value, uint32 filterValue)
    {
        if (!player || !value || !player->GetSession() || player->GetSession()->IsBot())
            return;

        uint32 const accountId = player->GetSession()->GetAccountId();
        uint32 const now = uint32(GameTime::GetGameTime().count());

        std::vector<ProgressEntry> changed;
        uint32 points = 0;
        {
            std::lock_guard<std::mutex> lock(_lock);
            if (!_enabled || !_catalog)
                return;

            auto const accountItr = _accounts.find(accountId);
            if (accountItr == _accounts.end() || !accountItr->second.loaded)
                return;

            AccountData& account = accountItr->second;
            points = account.points;

            for (uint32 const index : _catalog->TasksFor(type))
            {
                Task const& task = _catalog->tasks[index];
                if (task.filter != filterValue)
                    continue;

                TaskProgress& state = account.tasks[task.id];
                if (Advance(task, state, value, now))
                    changed.push_back(ToEntry(task.id, state));
            }
        }

        if (!changed.empty())
            Publish(player, changed, points);
    }

    void PathMgr::Publish(Player* player, std::vector<ProgressEntry> const& changed, uint32 points)
    {
        uint32 const accountId = player->GetSession()->GetAccountId();

        // The queries may run out of order on the pool's workers, so each one can only move
        // a row forward.
        CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();
        uint32 const now = uint32(GameTime::GetGameTime().count());
        for (ProgressEntry const& entry : changed)
        {
            trans->Append(
                "INSERT INTO dc_path_progress (account_id, task_id, progress, completed_at) VALUES ({}, {}, {}, {}) "
                "ON DUPLICATE KEY UPDATE progress = GREATEST(progress, VALUES(progress)), "
                "completed_at = IF(completed_at = 0, VALUES(completed_at), completed_at)",
                accountId, entry.taskId, entry.progress, (entry.flags & TASK_FLAG_COMPLETED) ? now : 0);
        }
        CharacterDatabase.CommitTransaction(trans);

        SendTaskUpdates(player, changed, points);
    }

    void PathMgr::RequestState(Player* player)
    {
        if (!player || !player->GetSession())
            return;

        uint32 const accountId = player->GetSession()->GetAccountId();

        bool ready = false;
        bool load = false;
        bool enabled = false;
        {
            std::lock_guard<std::mutex> lock(_lock);
            enabled = _enabled;
            if (enabled)
            {
                AccountData& account = _accounts[accountId];
                ready = account.loaded;
                if (!ready)
                {
                    account.stateRequested = true;
                    load = !account.loading;
                    account.loading = true;
                }
            }
        }

        if (load)
            BeginLoad(accountId);

        if (ready || !enabled)
            SendState(player);

        // Opening the book is when a stale collection count would show, and the recount
        // answers with an ordinary update.
        if (ready)
            RefreshCollection(player);
    }

    AccountSnapshot PathMgr::GetSnapshot(uint32 accountId) const
    {
        AccountSnapshot snapshot;

        std::lock_guard<std::mutex> lock(_lock);
        auto const itr = _accounts.find(accountId);
        if (itr == _accounts.end() || !itr->second.loaded)
            return snapshot;

        AccountData const& account = itr->second;
        snapshot.loaded = true;
        snapshot.points = account.points;
        snapshot.earned = account.earned;
        snapshot.tasks.reserve(account.tasks.size());
        for (auto const& [taskId, state] : account.tasks)
            snapshot.tasks.push_back(ToEntry(taskId, state));

        return snapshot;
    }

    std::string PathMgr::ClaimRefusal(Catalog const& catalog, AccountData const& account, Task const& task)
    {
        auto const itr = account.tasks.find(task.id);
        if (itr == account.tasks.end() || !itr->second.completedAt)
            return "That task is not complete yet.";

        if (itr->second.claimedAt)
            return "That reward has already been collected.";

        // The same rule the book draws: a task opens once the one before it is complete.
        if (task.prevTaskId && catalog.Find(task.prevTaskId))
        {
            auto const prev = account.tasks.find(task.prevTaskId);
            if (prev == account.tasks.end() || !prev->second.completedAt)
                return "Complete the previous task first.";
        }

        return std::string();
    }

    ClaimOutcome PathMgr::Claim(Player* player, uint32 taskId)
    {
        ClaimOutcome outcome;
        if (!player || !player->GetSession())
            return outcome;

        uint32 const accountId = player->GetSession()->GetAccountId();
        uint32 const now = uint32(GameTime::GetGameTime().count());
        CatalogPtr catalog;

        {
            std::lock_guard<std::mutex> lock(_lock);
            auto const accountItr = _accounts.find(accountId);
            if (!_enabled || !_catalog || accountItr == _accounts.end() || !accountItr->second.loaded)
            {
                outcome.message = "The Path of Chaos is not available right now.";
                return outcome;
            }

            AccountData& account = accountItr->second;
            outcome.points = account.points;

            Task const* task = _catalog->Find(taskId);
            if (!task)
            {
                outcome.message = "That task no longer exists.";
                return outcome;
            }

            outcome.message = ClaimRefusal(*_catalog, account, *task);
            if (!outcome.message.empty())
                return outcome;

            // Recorded before anything is paid, so a repeated request finds it claimed.
            account.tasks[task->id].claimedAt = now;
            account.points += task->reward.points;
            account.earned += task->reward.points;
            outcome.ok = true;
            outcome.claimed.push_back(task->id);
            outcome.paid = task->reward.points;
            outcome.points = account.points;
            catalog = _catalog;
        }

        PayClaims(player, catalog, outcome.claimed);
        return outcome;
    }

    ClaimOutcome PathMgr::ClaimAll(Player* player)
    {
        ClaimOutcome outcome;
        if (!player || !player->GetSession())
            return outcome;

        uint32 const accountId = player->GetSession()->GetAccountId();
        uint32 const now = uint32(GameTime::GetGameTime().count());
        CatalogPtr catalog;

        {
            std::lock_guard<std::mutex> lock(_lock);
            auto const accountItr = _accounts.find(accountId);
            if (!_enabled || !_catalog || accountItr == _accounts.end() || !accountItr->second.loaded)
            {
                outcome.message = "The Path of Chaos is not available right now.";
                return outcome;
            }

            AccountData& account = accountItr->second;
            for (Task const& task : _catalog->tasks)
            {
                if (!ClaimRefusal(*_catalog, account, task).empty())
                    continue;

                account.tasks[task.id].claimedAt = now;
                account.points += task.reward.points;
                account.earned += task.reward.points;
                outcome.claimed.push_back(task.id);
                outcome.paid += task.reward.points;
            }

            outcome.points = account.points;
            outcome.ok = !outcome.claimed.empty();
            if (!outcome.ok)
                outcome.message = "There is nothing to collect.";

            catalog = _catalog;
        }

        if (outcome.ok)
            PayClaims(player, catalog, outcome.claimed);

        return outcome;
    }

    void PathMgr::PayClaims(Player* player, CatalogPtr const& catalog, std::vector<uint32> const& taskIds)
    {
        uint32 const accountId = player->GetSession()->GetAccountId();
        uint32 const guid = player->GetGUID().GetCounter();
        uint32 const now = uint32(GameTime::GetGameTime().count());

        bool itemsPaid = false;
        uint32 paid = 0;

        CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();
        for (uint32 const taskId : taskIds)
        {
            Task const* task = catalog->Find(taskId);
            if (!task)
                continue;

            paid += task->reward.points;

            trans->Append(
                "INSERT INTO dc_path_progress (account_id, task_id, progress, completed_at, claimed_at, claimed_guid) "
                "VALUES ({}, {}, {}, {}, {}, {}) "
                "ON DUPLICATE KEY UPDATE claimed_at = IF(claimed_at = 0, VALUES(claimed_at), claimed_at), "
                "claimed_guid = IF(claimed_guid = 0, VALUES(claimed_guid), claimed_guid)",
                accountId, task->id, task->target, now, now, guid);

            TaskReward const& reward = task->reward;
            if (reward.itemId)
            {
                // Mailed when the bags are full, so a full bag never costs the reward.
                if (CrossSystem::RewardDistributor::instance()->DistributeItem(player, reward.itemId, reward.itemCount,
                    CrossSystem::SystemId::None, "path_of_chaos"))
                    itemsPaid = true;
                else
                    LOG_ERROR("module.dc", "Path of Chaos: item {} x{} of task {} was not delivered to {}.",
                        reward.itemId, reward.itemCount, task->id, player->GetGUID().ToString());
            }

            if (reward.collectionType)
            {
                DCCollection::GrantOptions options;
                options.sourceType = "PATH";
                options.sourceId = task->id;
                options.sourceText = "Path of Chaos: " + task->name;

                DCCollection::GrantResult const result = DCCollection::GrantCollectible(player,
                    static_cast<DCCollection::CollectionType>(reward.collectionType), reward.collectionEntry, options);

                if (!DCCollection::OwnsAfterGrant(result))
                {
                    LOG_ERROR("module.dc", "Path of Chaos: collectible of task {} was not delivered to {}: {}.",
                        task->id, player->GetGUID().ToString(), DCCollection::GrantResultToString(result));
                }
            }
        }

        if (paid)
        {
            trans->Append(
                "INSERT INTO dc_path_points (account_id, balance, lifetime_earned) VALUES ({}, {}, {}) "
                "ON DUPLICATE KEY UPDATE balance = balance + VALUES(balance), "
                "lifetime_earned = lifetime_earned + VALUES(lifetime_earned)",
                accountId, paid, paid);
        }

        // One commit carries the claim, the points and the items, so a crash cannot pay a
        // reward twice or lose it.
        if (itemsPaid)
            player->SaveInventoryAndGoldToDB(trans);

        CharacterDatabase.CommitTransaction(trans);
    }

    uint32 PathMgr::GetPoints(uint32 accountId) const
    {
        std::lock_guard<std::mutex> lock(_lock);
        auto const itr = _accounts.find(accountId);
        return itr != _accounts.end() ? itr->second.points : 0;
    }

    bool PathMgr::TrySpendPoints(Player* player, uint32 amount)
    {
        if (!player || !player->GetSession())
            return false;

        uint32 const accountId = player->GetSession()->GetAccountId();
        uint32 balance = 0;
        {
            std::lock_guard<std::mutex> lock(_lock);
            auto const itr = _accounts.find(accountId);
            if (itr == _accounts.end() || !itr->second.loaded || itr->second.points < amount)
                return false;

            itr->second.points -= amount;
            balance = itr->second.points;
        }

        CharacterDatabase.Execute("UPDATE dc_path_points SET balance = balance - {} WHERE account_id = {}",
            amount, accountId);

        SendTaskUpdates(player, {}, balance);
        return true;
    }

    void PathMgr::RefundPoints(Player* player, uint32 amount)
    {
        if (!player || !player->GetSession() || !amount)
            return;

        uint32 const accountId = player->GetSession()->GetAccountId();
        uint32 balance = 0;
        {
            std::lock_guard<std::mutex> lock(_lock);
            auto const itr = _accounts.find(accountId);
            if (itr == _accounts.end())
                return;

            itr->second.points += amount;
            balance = itr->second.points;
        }

        CharacterDatabase.Execute("UPDATE dc_path_points SET balance = balance + {} WHERE account_id = {}",
            amount, accountId);

        SendTaskUpdates(player, {}, balance);
    }

    bool PathMgr::ForceComplete(Player* player, uint32 taskId)
    {
        if (!player || !player->GetSession())
            return false;

        uint32 const accountId = player->GetSession()->GetAccountId();
        uint32 const now = uint32(GameTime::GetGameTime().count());

        std::vector<ProgressEntry> changed;
        uint32 points = 0;
        {
            std::lock_guard<std::mutex> lock(_lock);
            if (!_catalog)
                return false;

            Task const* task = _catalog->Find(taskId);
            auto const itr = _accounts.find(accountId);
            if (!task || itr == _accounts.end() || !itr->second.loaded)
                return false;

            TaskProgress& state = itr->second.tasks[taskId];
            if (Advance(*task, state, task->target, now))
                changed.push_back(ToEntry(taskId, state));

            points = itr->second.points;
        }

        if (!changed.empty())
            Publish(player, changed, points);

        return true;
    }

    void PathMgr::GrantPoints(Player* player, uint32 amount)
    {
        if (!player || !player->GetSession() || !amount)
            return;

        uint32 const accountId = player->GetSession()->GetAccountId();
        uint32 balance = 0;
        {
            std::lock_guard<std::mutex> lock(_lock);
            auto const itr = _accounts.find(accountId);
            if (itr == _accounts.end())
                return;

            itr->second.points += amount;
            itr->second.earned += amount;
            balance = itr->second.points;
        }

        CharacterDatabase.Execute(
            "INSERT INTO dc_path_points (account_id, balance, lifetime_earned) VALUES ({}, {}, {}) "
            "ON DUPLICATE KEY UPDATE balance = balance + VALUES(balance), "
            "lifetime_earned = lifetime_earned + VALUES(lifetime_earned)",
            accountId, amount, amount);

        SendTaskUpdates(player, {}, balance);
    }

    void PathMgr::ResetAccount(Player* player)
    {
        if (!player || !player->GetSession())
            return;

        uint32 const accountId = player->GetSession()->GetAccountId();
        {
            std::lock_guard<std::mutex> lock(_lock);
            AccountData& account = _accounts[accountId];
            account.tasks.clear();
            account.points = 0;
            account.earned = 0;
        }

        CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();
        trans->Append("DELETE FROM dc_path_progress WHERE account_id = {}", accountId);
        trans->Append("DELETE FROM dc_path_points WHERE account_id = {}", accountId);
        CharacterDatabase.CommitTransaction(trans);

        SendState(player);
        RefreshMilestones(player);
    }
}
}
