/*
 * DarkChaos-255 Account-Wide Reputation Pools
 *
 * Keeps reputation progress at the account level and synchronizes it across
 * characters on login.
 *
 * Pool rows are keyed (account, faction, team) and carry the base reputation
 * they were recorded under. Reputation standings are stored as absolutes that
 * include the character's base value, and that base is race/faction dependent:
 * an Alliance character's exalted Stormwind standing replayed onto a Horde alt
 * would make enemy-city guards friendly. The team key keeps the two contexts
 * apart, and the recorded base is verified before anything is applied.
 */

#include "Chat.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "Log.h"
#include "Player.h"
#include "ReputationMgr.h"
#include "ScriptMgr.h"
#include "SharedDefines.h"
#include "StringFormat.h"
#include "dc_accountwide_pool.h"

#include <algorithm>
#include <unordered_map>
#include <utility>
#include <vector>

namespace
{
    namespace ConfigKey
    {
        constexpr char const* ENABLE = "DCReputation.Accountwide.Enable";
        constexpr char const* SYNC_ON_LOGIN = "DCReputation.Accountwide.SyncOnLogin";
        constexpr char const* HIGHEST_WINS = "DCReputation.Accountwide.HighestWins";
        constexpr char const* SHARE_NEUTRAL = "DCReputation.Accountwide.ShareNeutralAcrossTeams";
        constexpr char const* ANNOUNCE_SYNC = "DCReputation.Accountwide.AnnounceSync";
        constexpr char const* DEBUG = "DCReputation.Accountwide.Debug";
    }

    constexpr char const* TABLE_NAME = "dc_account_reputation_pools";

    struct PooledStanding
    {
        int32 standing = 0;
        int32 baseStanding = 0;
    };

    // Key packs (factionId, teamId) so one flat map covers both teams.
    using PoolKey = uint64;
    using ReputationPool = std::unordered_map<PoolKey, PooledStanding>;

    constexpr PoolKey MakeKey(uint32 factionId, uint8 team)
    {
        return (static_cast<PoolKey>(factionId) << 8) | team;
    }

    constexpr uint32 FactionOfKey(PoolKey key) { return static_cast<uint32>(key >> 8); }
    constexpr uint8 TeamOfKey(PoolKey key) { return static_cast<uint8>(key & 0xFF); }

    DCAccountWide::PoolCache<ReputationPool> gPools;
    DCAccountWide::SyncGuardRegistry gSyncGuard;
    DCAccountWide::EvictionTimer gEvictionTimer;

    bool IsEnabled() { return sConfigMgr->GetOption<bool>(ConfigKey::ENABLE, true); }
    bool IsSyncOnLoginEnabled() { return sConfigMgr->GetOption<bool>(ConfigKey::SYNC_ON_LOGIN, true); }
    bool IsHighestWinsEnabled() { return sConfigMgr->GetOption<bool>(ConfigKey::HIGHEST_WINS, true); }
    bool IsShareNeutralEnabled() { return sConfigMgr->GetOption<bool>(ConfigKey::SHARE_NEUTRAL, true); }
    bool IsAnnounceSyncEnabled() { return sConfigMgr->GetOption<bool>(ConfigKey::ANNOUNCE_SYNC, false); }
    bool IsDebugEnabled() { return sConfigMgr->GetOption<bool>(ConfigKey::DEBUG, false); }

    struct SyncSettings
    {
        bool highestWins = true;
        bool shareNeutral = true;
        bool announce = false;
        bool debug = false;

        static SyncSettings Read()
        {
            SyncSettings settings;
            settings.highestWins = IsHighestWinsEnabled();
            settings.shareNeutral = IsShareNeutralEnabled();
            settings.announce = IsAnnounceSyncEnabled();
            settings.debug = IsDebugEnabled();
            return settings;
        }
    };

    int32 ClampStanding(int32 standing)
    {
        return std::clamp(standing, ReputationMgr::Reputation_Bottom, ReputationMgr::Reputation_Cap);
    }

    bool ShouldTrackFaction(FactionEntry const* factionEntry)
    {
        return factionEntry && factionEntry->CanHaveReputation() && factionEntry->reputationListID >= 0;
    }

    uint8 TeamOf(Player const* player)
    {
        return static_cast<uint8>(player->GetTeamId());
    }

    DCAccountWide::BatchUpsert MakeUpsert()
    {
        return DCAccountWide::BatchUpsert(
            TABLE_NAME,
            "`account_id`, `faction_id`, `team`, `standing`, `base_standing`",
            "`standing` = VALUES(`standing`), `base_standing` = VALUES(`base_standing`), "
            "`updated_at` = NOW()");
    }

    void ParsePool(ReputationPool& pool, QueryResult const& result)
    {
        if (!result)
            return;

        do
        {
            Field* fields = result->Fetch();

            uint32 factionId = fields[0].Get<uint32>();
            uint8 team = fields[1].Get<uint8>();

            PooledStanding entry;
            entry.standing = ClampStanding(fields[2].Get<int32>());
            entry.baseStanding = fields[3].Get<int32>();

            pool[MakeKey(factionId, team)] = entry;
        } while (result->NextRow());
    }

    std::string SelectSql(uint32 accountId)
    {
        return Acore::StringFormat(
            "SELECT `faction_id`, `team`, `standing`, `base_standing` FROM `{}` "
            "WHERE `account_id` = {}",
            TABLE_NAME, accountId);
    }

    std::string MakeRow(uint32 accountId, uint32 factionId, uint8 team, PooledStanding const& entry)
    {
        return Acore::StringFormat("({}, {}, {}, {}, {})",
            accountId, factionId, uint32(team), entry.standing, entry.baseStanding);
    }

    /**
     * Resolves which pooled row may be applied to this character.
     *
     * Own-team rows apply only when the recorded base matches the character's
     * own base, which also guards the rarer case of two races on the same team
     * having different base standings for a faction. Rows from the other team
     * are only ever considered for factions that are neutral to both sides
     * (base 0 on the row and on the character) - that is what makes shared
     * factions like Argent Dawn still cross the faction divide safely.
     */
    PooledStanding const* ResolveApplicable(ReputationPool const& pool, uint32 factionId,
                                            uint8 team, int32 myBase, bool shareNeutral)
    {
        auto own = pool.find(MakeKey(factionId, team));
        if (own != pool.end())
            return own->second.baseStanding == myBase ? &own->second : nullptr;

        if (!shareNeutral || myBase != 0)
            return nullptr;

        uint8 otherTeam = (team == TEAM_ALLIANCE) ? uint8(TEAM_HORDE) : uint8(TEAM_ALLIANCE);

        auto other = pool.find(MakeKey(factionId, otherTeam));
        if (other == pool.end() || other->second.baseStanding != 0)
            return nullptr;

        return &other->second;
    }

    /// Pools this character's changed standings. Never touches the character.
    void MergeCharacterIntoPool(Player* player, uint32 accountId, SyncSettings const& settings,
                                bool overwriteExisting, uint32& mergedCount)
    {
        if (!player)
            return;

        ReputationMgr const& reputationMgr = player->GetReputationMgr();
        ReputationPool& pool = gPools.Get(accountId);
        uint8 team = TeamOf(player);

        DCAccountWide::BatchUpsert upsert = MakeUpsert();

        for (auto const& [repListId, factionState] : reputationMgr.GetStateList())
        {
            (void)repListId;

            FactionEntry const* factionEntry = sFactionStore.LookupEntry(factionState.ID);
            if (!ShouldTrackFaction(factionEntry))
                continue;

            int32 currentStanding = ClampStanding(reputationMgr.GetReputation(factionEntry));
            int32 baseStanding = ClampStanding(reputationMgr.GetBaseReputation(factionEntry));

            // Only changed standings are worth pooling.
            if (currentStanding == baseStanding)
                continue;

            PoolKey key = MakeKey(factionEntry->ID, team);
            auto poolIt = pool.find(key);

            if (poolIt == pool.end())
            {
                PooledStanding entry{ currentStanding, baseStanding };
                pool[key] = entry;
                upsert.AddRow(MakeRow(accountId, factionEntry->ID, team, entry));
                ++mergedCount;
                continue;
            }

            if (!overwriteExisting)
                continue;

            // A stored row recorded under a different base belongs to another
            // race context on this team; the current character's is authoritative.
            bool sameContext = poolIt->second.baseStanding == baseStanding;

            int32 targetStanding = (settings.highestWins && sameContext)
                ? std::max(poolIt->second.standing, currentStanding)
                : currentStanding;

            if (sameContext && targetStanding == poolIt->second.standing)
                continue;

            poolIt->second.standing = targetStanding;
            poolIt->second.baseStanding = baseStanding;
            upsert.AddRow(MakeRow(accountId, factionEntry->ID, team, poolIt->second));
            ++mergedCount;

            if (settings.debug)
            {
                LOG_INFO("module.dc",
                    "[DCReputation] Merged faction {} (team {}) for account {} to {}",
                    factionEntry->ID, uint32(team), accountId, targetStanding);
            }
        }

        upsert.Execute();
    }

    void ApplyPoolToCharacter(Player* player, uint32 accountId, SyncSettings const& settings,
                              uint32& appliedCount, uint32& skippedCount)
    {
        if (!player)
            return;

        ReputationPool& pool = gPools.Get(accountId);
        if (pool.empty())
            return;

        uint8 team = TeamOf(player);
        ReputationMgr& reputationMgr = player->GetReputationMgr();

        DCAccountWide::SyncGuardRegistry::Scope guard(gSyncGuard, player);

        // Collect first: applying mutates reputation, and a deterministic order
        // keeps the outcome reproducible across runs (the pool is unordered).
        std::vector<std::pair<uint32, int32>> toApply;
        toApply.reserve(pool.size());

        for (auto const& [key, entry] : pool)
        {
            (void)entry;

            uint32 factionId = FactionOfKey(key);

            // Each faction is resolved once, from the character's own team.
            if (TeamOfKey(key) != team && pool.find(MakeKey(factionId, team)) != pool.end())
                continue;

            FactionEntry const* factionEntry = sFactionStore.LookupEntry(factionId);
            if (!ShouldTrackFaction(factionEntry))
            {
                ++skippedCount;
                continue;
            }

            int32 myBase = ClampStanding(reputationMgr.GetBaseReputation(factionEntry));

            PooledStanding const* applicable =
                ResolveApplicable(pool, factionId, team, myBase, settings.shareNeutral);

            if (!applicable)
            {
                ++skippedCount;
                continue;
            }

            if (ClampStanding(reputationMgr.GetReputation(factionEntry)) == applicable->standing)
                continue;

            toApply.emplace_back(factionId, applicable->standing);
        }

        std::sort(toApply.begin(), toApply.end());

        for (auto const& [factionId, standing] : toApply)
        {
            FactionEntry const* factionEntry = sFactionStore.LookupEntry(factionId);
            if (!factionEntry)
                continue;

            int32 before = ClampStanding(reputationMgr.GetReputation(factionEntry));

            // SetOneFactionReputation, not Player::SetReputation: the latter runs
            // the spillover pass, which SETS sister factions to standing * rate
            // and would silently drag unrelated standings down.
            reputationMgr.SetOneFactionReputation(factionEntry, static_cast<float>(standing), false);
            ++appliedCount;

            if (settings.debug)
            {
                LOG_INFO("module.dc",
                    "[DCReputation] Applied pooled faction {} for {}: {} -> {}",
                    factionId, player->GetName(), before, standing);
            }
        }

        if (appliedCount > 0)
            reputationMgr.SendStates();
    }

    void RunLoginSync(Player* player)
    {
        uint32 accountId = DCAccountWide::AccountIdOf(player);
        if (!accountId)
            return;

        SyncSettings settings = SyncSettings::Read();

        uint32 mergedCount = 0;
        uint32 appliedCount = 0;
        uint32 skippedCount = 0;

        if (settings.highestWins)
        {
            MergeCharacterIntoPool(player, accountId, settings, true, mergedCount);
            ApplyPoolToCharacter(player, accountId, settings, appliedCount, skippedCount);
        }
        else
        {
            // Strict pool mode: stored standings win, then seed anything the
            // pool does not know about yet without overwriting what it does.
            bool poolWasEmpty = gPools.Get(accountId).empty();

            ApplyPoolToCharacter(player, accountId, settings, appliedCount, skippedCount);
            MergeCharacterIntoPool(player, accountId, settings, poolWasEmpty, mergedCount);
        }

        if (settings.announce && (mergedCount > 0 || appliedCount > 0))
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cff00ccff[Reputation]|r Account-wide sync complete: {} pooled, {} applied.",
                mergedCount, appliedCount);
        }
    }

    class DCAccountWideReputationPlayerScript : public PlayerScript
    {
    public:
        DCAccountWideReputationPlayerScript() : PlayerScript("DCAccountWideReputationPlayerScript",
        {
            PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_LOGOUT, PLAYERHOOK_ON_REPUTATION_CHANGE
        }) { }

        void OnPlayerLogin(Player* player) override
        {
            if (!IsEnabled() || !IsSyncOnLoginEnabled() || !DCAccountWide::AccountIdOf(player))
                return;

            uint32 accountId = player->GetSession()->GetAccountId();

            gPools.EnsureLoaded(player, SelectSql(accountId), ParsePool, RunLoginSync);
        }

        bool OnPlayerReputationChange(Player* player, uint32 factionId, int32& standing,
                                      bool /*incremental*/) override
        {
            if (!IsEnabled() || gSyncGuard.IsSyncing(player))
                return true;

            uint32 accountId = DCAccountWide::AccountIdOf(player);
            if (!accountId)
                return true;

            FactionEntry const* factionEntry = sFactionStore.LookupEntry(factionId);
            if (!ShouldTrackFaction(factionEntry))
                return true;

            standing = ClampStanding(standing);

            // Never issue a blocking load from a gameplay hook; an uncached pool
            // is picked up by the next login merge.
            if (!gPools.IsLoaded(accountId))
                return true;

            SyncSettings settings = SyncSettings::Read();

            uint8 team = TeamOf(player);
            int32 baseStanding = ClampStanding(player->GetReputationMgr().GetBaseReputation(factionEntry));

            ReputationPool& pool = gPools.Get(accountId);
            PoolKey key = MakeKey(factionId, team);
            auto poolIt = pool.find(key);

            PooledStanding entry;
            entry.standing = standing;
            entry.baseStanding = baseStanding;

            if (poolIt != pool.end())
            {
                bool sameContext = poolIt->second.baseStanding == baseStanding;

                if (settings.highestWins && sameContext)
                    entry.standing = std::max(poolIt->second.standing, standing);

                if (sameContext && poolIt->second.standing == entry.standing)
                    return true;
            }

            pool[key] = entry;

            DCAccountWide::BatchUpsert upsert = MakeUpsert();
            upsert.AddRow(MakeRow(accountId, factionId, team, entry));
            upsert.Execute();

            if (settings.debug)
            {
                LOG_INFO("module.dc",
                    "[DCReputation] Stored pooled faction {} (team {}) for account {} = {}",
                    factionId, uint32(team), accountId, entry.standing);
            }

            return true;
        }

        void OnPlayerLogout(Player* player) override
        {
            if (uint32 accountId = DCAccountWide::AccountIdOf(player))
                gPools.Clear(accountId);
        }
    };

    class DCAccountWideReputationWorldScript : public WorldScript
    {
    public:
        DCAccountWideReputationWorldScript() : WorldScript("DCAccountWideReputationWorldScript") { }

        void OnAfterConfigLoad(bool /*reload*/) override
        {
            if (!IsEnabled())
                return;

            LOG_INFO("module.dc",
                "[DCReputation] Account-wide reputation pools enabled "
                "(SyncOnLogin={}, HighestWins={}, ShareNeutralAcrossTeams={})",
                IsSyncOnLoginEnabled() ? 1 : 0,
                IsHighestWinsEnabled() ? 1 : 0,
                IsShareNeutralEnabled() ? 1 : 0);
        }

        void OnUpdate(uint32 diff) override
        {
            if (gEvictionTimer.Tick(diff))
                gPools.EvictOfflineAccounts();
        }
    };
}

namespace DCAccountWideReputation
{
    void ClearCache(uint32 accountId) { gPools.Clear(accountId); }
    std::size_t CachedAccounts() { return gPools.CachedAccounts(); }
    bool IsAccountCached(uint32 accountId) { return gPools.IsLoaded(accountId); }
    std::size_t PoolSize(uint32 accountId)
    {
        return gPools.IsLoaded(accountId) ? gPools.Get(accountId).size() : 0;
    }
    void ForceSync(Player* player) { RunLoginSync(player); }
    char const* TableName() { return TABLE_NAME; }
}

void AddSC_dc_accountwide_reputation()
{
    new DCAccountWideReputationPlayerScript();
    new DCAccountWideReputationWorldScript();
}
