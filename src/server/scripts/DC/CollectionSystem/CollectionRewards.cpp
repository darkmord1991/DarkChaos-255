/*
 * CollectionRewards.cpp - Data-driven collectible rewards
 *
 * Attaches mounts, pets, toys, heirlooms, titles and appearances to quests and
 * achievements as pure SQL, with no teaching item and no C++ per reward:
 *
 *   INSERT INTO dc_collection_rewards
 *     (source_type, source_id, collection_type, entry_id, team, comment)
 *   VALUES ('QUEST', 820056, 1, 48025, 0, 'Reins of the Crimson Drake');
 *
 * Everything actually handed out goes through DCCollection::GrantCollectible,
 * so the unlock, the spellbook entry and the client notification stay in sync.
 *
 * Reload after editing the table with: .collection reload
 */

#include "CollectionGrant.h"

#include "Chat.h"
#include "DBCStores.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "Player.h"
#include "QuestDef.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include "WorldSession.h"

#include <string>
#include <unordered_map>
#include <vector>

namespace DCCollection
{
    namespace
    {
        enum RewardTeam : uint8
        {
            REWARD_TEAM_BOTH     = 0,
            REWARD_TEAM_ALLIANCE = 1,
            REWARD_TEAM_HORDE    = 2
        };

        struct CollectionReward
        {
            CollectionType type = CollectionType::MOUNT;
            uint32 entryId = 0;
            uint8 team = REWARD_TEAM_BOTH;
        };

        using RewardMap = std::unordered_map<uint32, std::vector<CollectionReward>>;

        RewardMap sQuestRewards;
        RewardMap sAchievementRewards;
        bool sTableChecked = false;
        bool sTablePresent = false;

        bool MatchesTeam(Player const* player, uint8 team)
        {
            if (team == REWARD_TEAM_BOTH)
                return true;

            if (team == REWARD_TEAM_ALLIANCE)
                return player->GetTeamId() == TEAM_ALLIANCE;

            if (team == REWARD_TEAM_HORDE)
                return player->GetTeamId() == TEAM_HORDE;

            return true;
        }

        void GrantAll(Player* player, RewardMap const& rewards, uint32 sourceId,
            char const* sourceType, std::string const& sourceText)
        {
            if (!player || rewards.empty())
                return;

            auto it = rewards.find(sourceId);
            if (it == rewards.end())
                return;

            for (CollectionReward const& reward : it->second)
            {
                if (!MatchesTeam(player, reward.team))
                    continue;

                GrantOptions options;
                options.sourceType = sourceType;
                options.sourceId = sourceId;
                options.sourceText = sourceText;

                GrantResult const result = GrantCollectible(player, reward.type, reward.entryId, options);

                if (result != GrantResult::Granted && result != GrantResult::AlreadyOwned)
                {
                    LOG_ERROR("module.dc", "DC-Collection: reward {} {} for {} {} not delivered to player {}: {}.",
                        CollectionTypeToName(reward.type), reward.entryId, sourceType, sourceId,
                        player->GetGUID().ToString(), GrantResultToString(result));
                }
            }
        }

        uint32 LoadRewards()
        {
            sQuestRewards.clear();
            sAchievementRewards.clear();

            sTableChecked = true;
            sTablePresent = WorldTableExists("dc_collection_rewards");
            if (!sTablePresent)
            {
                LOG_INFO("server.loading", ">> DC-Collection: dc_collection_rewards not present - data-driven collectible rewards disabled.");
                return 0;
            }

            QueryResult result = WorldDatabase.Query(
                "SELECT source_type, source_id, collection_type, entry_id, team "
                "FROM dc_collection_rewards WHERE enabled = 1");

            if (!result)
            {
                LOG_INFO("server.loading", ">> DC-Collection: loaded 0 collectible rewards.");
                return 0;
            }

            uint32 loaded = 0;
            uint32 rejected = 0;

            do
            {
                Field* fields = result->Fetch();

                std::string const sourceType = fields[0].Get<std::string>();
                uint32 const sourceId = fields[1].Get<uint32>();
                uint8 const collectionType = fields[2].Get<uint8>();
                uint32 const rawEntryId = fields[3].Get<uint32>();
                uint8 const team = fields[4].Get<uint8>();

                CollectionReward reward;
                reward.type = static_cast<CollectionType>(collectionType);
                reward.team = team;

                // Normalise once at load time so every grant is a straight
                // lookup, and so a bad row is reported at startup rather than
                // silently failing the first time a player earns it.
                reward.entryId = NormalizeCollectibleEntry(reward.type, rawEntryId);
                if (!reward.entryId || !ValidateCollectibleEntry(reward.type, reward.entryId))
                {
                    LOG_ERROR("sql.sql", "DC-Collection: dc_collection_rewards row ({}, {}) has {} entry {} which does not resolve - skipped.",
                        sourceType, sourceId, CollectionTypeToName(reward.type), rawEntryId);
                    ++rejected;
                    continue;
                }

                if (sourceType == "QUEST")
                {
                    sQuestRewards[sourceId].push_back(reward);
                }
                else if (sourceType == "ACHIEVEMENT")
                {
                    sAchievementRewards[sourceId].push_back(reward);
                }
                else
                {
                    LOG_ERROR("sql.sql", "DC-Collection: dc_collection_rewards row {} has unknown source_type '{}' - skipped.",
                        sourceId, sourceType);
                    ++rejected;
                    continue;
                }

                ++loaded;
            } while (result->NextRow());

            LOG_INFO("server.loading", ">> DC-Collection: loaded {} collectible rewards ({} quest, {} achievement){}.",
                loaded, sQuestRewards.size(), sAchievementRewards.size(),
                rejected ? Acore::StringFormat(", {} rejected", rejected) : "");

            return loaded;
        }
    }

    uint32 ReloadCollectionRewards()
    {
        return LoadRewards();
    }

    bool CollectionRewardsTablePresent()
    {
        return sTableChecked && sTablePresent;
    }

    void GrantQuestCollectibles(Player* player, Quest const* quest)
    {
        if (!player || !quest || sQuestRewards.empty())
            return;

        GrantAll(player, sQuestRewards, quest->GetQuestId(), "QUEST",
            Acore::StringFormat("Quest: {}", quest->GetTitle()));
    }

    void GrantAchievementCollectibles(Player* player, AchievementEntry const* achievement)
    {
        if (!player || !achievement || sAchievementRewards.empty())
            return;

        uint8 const locale = player->GetSession() ? player->GetSession()->GetSessionDbcLocale() : 0;
        char const* name = achievement->name[locale] ? achievement->name[locale] : achievement->name[0];

        GrantAll(player, sAchievementRewards, achievement->ID, "ACHIEVEMENT",
            Acore::StringFormat("Achievement: {}", name ? name : "?"));
    }
}

// ===========================================================================
// Scripts
// ===========================================================================

class dc_collection_rewards_world : public WorldScript
{
public:
    dc_collection_rewards_world() : WorldScript("dc_collection_rewards_world") { }

    void OnStartup() override
    {
        DCCollection::ReloadCollectionRewards();
    }
};

class dc_collection_rewards_player : public PlayerScript
{
public:
    dc_collection_rewards_player() : PlayerScript("dc_collection_rewards_player",
    {
        PLAYERHOOK_ON_ACHI_COMPLETE, PLAYERHOOK_ON_PLAYER_COMPLETE_QUEST
    }) { }

    void OnPlayerCompleteQuest(Player* player, Quest const* quest) override
    {
        if (!player || !quest)
            return;

        DCCollection::GrantQuestCollectibles(player, quest);
    }

    void OnPlayerAchievementComplete(Player* player, AchievementEntry const* achievement) override
    {
        if (!player || !achievement)
            return;

        DCCollection::GrantAchievementCollectibles(player, achievement);
    }
};

void AddSC_dc_collection_rewards()
{
    new dc_collection_rewards_world();
    new dc_collection_rewards_player();
}
