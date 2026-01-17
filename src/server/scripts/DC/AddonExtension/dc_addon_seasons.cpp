/*
 * Dark Chaos - Seasons Addon Module Handler
 *
 * This module handles seasonal progression and rewards addon communication.
 * Works alongside AIO for complex UI updates.
 *
 * Copyright (C) 2024 Dark Chaos Development Team
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Chat.h"
#include "Config.h"
#include "Log.h"
#include "DatabaseEnv.h"
#include "dc_addon_namespace.h"
#include "DC/ItemUpgrades/ItemUpgradeManager.h"
#include "DC/CrossSystem/DCSeasonHelper.h"
#include "../Seasons/SeasonalRewardSystem.h"
#include <algorithm>

namespace DCAddon
{
namespace Seasons
{
    // Additional Seasons-specific opcodes not in namespace header
    constexpr uint8 CMSG_CLAIM_REWARD       = 0x04;
    constexpr uint8 CMSG_GET_LEADERBOARD    = 0x05;
    constexpr uint8 CMSG_GET_CHALLENGES     = 0x06;

    constexpr uint8 SMSG_REWARD_CLAIMED     = 0x13;
    constexpr uint8 SMSG_LEADERBOARD        = 0x14;
    constexpr uint8 SMSG_CHALLENGES         = 0x15;
    constexpr uint8 SMSG_SEASON_START       = 0x17;
    constexpr uint8 SMSG_MILESTONE_REACHED  = 0x18;
    constexpr uint8 SMSG_DAILY_RESET        = 0x19;

    // Reward claim results
    enum RewardClaimResult : uint8
    {
        CLAIM_SUCCESS           = 0,
        CLAIM_ALREADY_CLAIMED   = 1,
        CLAIM_NOT_UNLOCKED      = 2,
        CLAIM_INVENTORY_FULL    = 3,
        CLAIM_ERROR             = 4,
    };

    // Configuration
    static bool s_enabled = true;

    void LoadConfig()
    {
        s_enabled = sConfigMgr->GetOption<bool>("DC.Addon.Seasons.Enable", true);
    }

    static uint32 GetSeasonIdFromMsg(const ParsedMessage& msg)
    {
        uint32 seasonId = 0;

        if (IsJsonMessage(msg))
        {
            JsonValue req = GetJsonData(msg);
            if (req.IsObject())
            {
                if (req.HasKey("seasonId") && req["seasonId"].IsNumber())
                    seasonId = req["seasonId"].AsUInt32();
                else if (req.HasKey("id") && req["id"].IsNumber())
                    seasonId = req["id"].AsUInt32();
                else if (req.HasKey("value") && req["value"].IsNumber())
                    seasonId = req["value"].AsUInt32();
            }
        }
        else if (msg.GetDataCount() > 0)
            seasonId = msg.GetUInt32(0);

        if (seasonId == 0)
            seasonId = DarkChaos::GetActiveSeasonId();

        return seasonId;
    }

    static uint32 GetWeeklyTokenCap()
    {
        uint32 cap = sConfigMgr->GetOption<uint32>("DarkChaos.Seasonal.WeeklyTokenCap", 0);
        if (cap == 0)
            cap = sConfigMgr->GetOption<uint32>("SeasonalRewards.MaxTokensPerWeek", 0);
        return cap > 0 ? cap : 1000;
    }

    static uint32 GetWeeklyEssenceCap()
    {
        uint32 cap = sConfigMgr->GetOption<uint32>("DarkChaos.Seasonal.WeeklyEssenceCap", 0);
        if (cap == 0)
            cap = sConfigMgr->GetOption<uint32>("SeasonalRewards.MaxEssencePerWeek", 0);
        return cap > 0 ? cap : 1000;
    }

    // Send current season information
    void SendSeasonInfo(Player* player, uint32 seasonId, const std::string& seasonName,
                        uint32 startTime, uint32 endTime, uint32 daysRemaining)
    {
        JsonMessage msg(Module::SEASONAL, Opcode::Season::SMSG_CURRENT_SEASON);
        msg.Set("seasonId", JsonValue(seasonId));
        msg.Set("name", JsonValue(seasonName));
        msg.Set("startTime", JsonValue(startTime));
        msg.Set("endTime", JsonValue(endTime));
        msg.Set("daysRemaining", JsonValue(daysRemaining));
        msg.Set("tokenCap", JsonValue(GetWeeklyTokenCap()));
        msg.Set("essenceCap", JsonValue(GetWeeklyEssenceCap()));
        msg.Send(player);
    }

    // Send player progress
    void SendProgress(Player* player, uint32 seasonId, uint32 seasonLevel,
                      uint32 currentXP, uint32 xpToNextLevel, uint32 totalPoints,
                      uint32 rank, uint32 tier)
    {
        Message msg(Module::SEASONAL, Opcode::Season::SMSG_PROGRESS);
        msg.Add(seasonId);
        msg.Add(seasonLevel);
        msg.Add(currentXP);
        msg.Add(xpToNextLevel);
        msg.Add(totalPoints);
        msg.Add(rank);
        msg.Add(tier);
        msg.Send(player);
    }

    // Send reward claim result
    void SendRewardClaimed(Player* player, uint32 rewardId, RewardClaimResult result,
                           uint32 itemId, uint32 itemCount)
    {
        JsonMessage msg(Module::SEASONAL, SMSG_REWARD_CLAIMED);
        msg.Set("rewardId", JsonValue(rewardId));
        msg.Set("result", JsonValue(static_cast<uint32>(result)));
        msg.Set("itemId", JsonValue(itemId));
        msg.Set("itemCount", JsonValue(itemCount));
        msg.Send(player);
    }

    // Send milestone notification
    void SendMilestoneReached(Player* player, uint32 milestoneId, const std::string& milestoneName,
                              uint32 rewardItemId, uint32 rewardCount)
    {
        Message msg(Module::SEASONAL, SMSG_MILESTONE_REACHED);
        msg.Add(milestoneId);
        msg.Add(milestoneName);
        msg.Add(rewardItemId);
        msg.Add(rewardCount);
        msg.Send(player);
    }

    // Send season end notification
    void SendSeasonEnd(Player* player, uint32 seasonId, uint32 finalLevel,
                       uint32 finalRank, uint32 bonusRewardItemId)
    {
        Message msg(Module::SEASONAL, Opcode::Season::SMSG_SEASON_END);
        msg.Add(seasonId);
        msg.Add(finalLevel);
        msg.Add(finalRank);
        msg.Add(bonusRewardItemId);
        msg.Send(player);
    }

    // Send new season notification
    void SendSeasonStart(Player* player, uint32 seasonId, const std::string& seasonName,
                         const std::string& theme, uint32 duration)
    {
        Message msg(Module::SEASONAL, SMSG_SEASON_START);
        msg.Add(seasonId);
        msg.Add(seasonName);
        msg.Add(theme);
        msg.Add(duration);
        msg.Send(player);
    }

    // Send daily reset notification
    void SendDailyReset(Player* player, uint32 newChallengeId1, uint32 newChallengeId2,
                        uint32 dailyBonusRemaining)
    {
        Message msg(Module::SEASONAL, SMSG_DAILY_RESET);
        msg.Add(newChallengeId1);
        msg.Add(newChallengeId2);
        msg.Add(dailyBonusRemaining);
        msg.Send(player);
    }

    // Handler implementations
    static void HandleGetCurrentSeason(Player* player, const ParsedMessage& /*msg*/)
    {
        uint32 seasonId = DarkChaos::GetActiveSeasonId();
        std::string seasonName = DarkChaos::GetActiveSeasonName();

        uint32 startTime = 0;
        uint32 endTime = 0;

        if (QueryResult result = CharacterDatabase.Query(
            "SELECT season_name, start_timestamp, end_timestamp FROM dc_seasons WHERE season_id = {}",
            seasonId))
        {
            Field* fields = result->Fetch();
            std::string dbName = fields[0].Get<std::string>();
            if (!dbName.empty())
                seasonName = dbName;
            startTime = fields[1].Get<uint64>();
            endTime = fields[2].Get<uint64>();
        }

        uint32 now = static_cast<uint32>(time(nullptr));
        uint32 daysRemaining = 0;
        if (endTime > now)
            daysRemaining = (endTime - now) / 86400;

        SendSeasonInfo(player, seasonId, seasonName, startTime, endTime, daysRemaining);
    }

    static void HandleGetProgress(Player* player, const ParsedMessage& msg)
    {
        uint32 seasonId = GetSeasonIdFromMsg(msg);

        uint32 tokenItemId = DarkChaos::ItemUpgrade::GetUpgradeTokenItemId();
        uint32 essenceItemId = DarkChaos::ItemUpgrade::GetArtifactEssenceItemId();

        if (sSeasonalRewards)
        {
            const auto& config = sSeasonalRewards->GetConfig();
            if (config.tokenItemId > 0)
                tokenItemId = config.tokenItemId;
            if (config.essenceItemId > 0)
                essenceItemId = config.essenceItemId;
        }

        uint32 currentTokens = player->GetItemCount(tokenItemId);
        uint32 currentEssence = player->GetItemCount(essenceItemId);

        uint32 weeklyTokenCap = GetWeeklyTokenCap();
        uint32 weeklyEssenceCap = GetWeeklyEssenceCap();

        uint32 weeklyTokensEarned = 0;
        uint32 weeklyEssenceEarned = 0;
        uint32 totalTokensEarned = 0;
        uint32 totalEssenceEarned = 0;
        uint32 questsCompleted = 0;
        uint32 bossesKilled = 0;

        if (QueryResult result = CharacterDatabase.Query(
            "SELECT total_tokens_earned, total_essence_earned, weekly_tokens_earned, weekly_essence_earned, "
            "quests_completed, (dungeon_bosses_killed + world_bosses_killed) "
            "FROM dc_player_seasonal_stats WHERE player_guid = {} AND season_id = {}",
            player->GetGUID().GetCounter(), seasonId))
        {
            Field* fields = result->Fetch();
            totalTokensEarned = fields[0].Get<uint32>();
            totalEssenceEarned = fields[1].Get<uint32>();
            weeklyTokensEarned = fields[2].Get<uint32>();
            weeklyEssenceEarned = fields[3].Get<uint32>();
            questsCompleted = fields[4].Get<uint32>();
            bossesKilled = fields[5].Get<uint32>();
        }

        DCAddon::JsonMessage response(Module::SEASONAL, Opcode::Season::SMSG_PROGRESS);
        response.Set("seasonId", static_cast<int32>(seasonId));
        response.Set("tokens", static_cast<int32>(currentTokens));
        response.Set("essence", static_cast<int32>(currentEssence));
        response.Set("tokenCap", static_cast<int32>(weeklyTokenCap));
        response.Set("essenceCap", static_cast<int32>(weeklyEssenceCap));
        response.Set("weeklyTokens", static_cast<int32>(weeklyTokensEarned));
        response.Set("weeklyEssence", static_cast<int32>(weeklyEssenceEarned));
        response.Set("totalTokens", static_cast<int32>(totalTokensEarned));
        response.Set("totalEssence", static_cast<int32>(totalEssenceEarned));
        response.Set("quests", static_cast<int32>(questsCompleted));
        response.Set("bosses", static_cast<int32>(bossesKilled));
        response.Send(player);
    }

    static void HandleGetRewards(Player* player, const ParsedMessage& msg)
    {
        uint32 seasonId = GetSeasonIdFromMsg(msg);

        JsonValue rewards;
        rewards.SetArray();

        if (QueryResult result = CharacterDatabase.Query(
            "SELECT id, week_timestamp, slot1_tokens, slot1_essence, slot2_tokens, slot2_essence, "
            "slot3_tokens, slot3_essence, slots_unlocked "
            "FROM dc_player_seasonal_chests WHERE player_guid = {} AND season_id = {} AND collected = 0 "
            "ORDER BY week_timestamp DESC",
            player->GetGUID().GetCounter(), seasonId))
        {
            do
            {
                Field* fields = result->Fetch();
                uint32 chestId = fields[0].Get<uint32>();
                uint64 weekTimestamp = fields[1].Get<uint64>();
                uint32 totalTokens = fields[2].Get<uint32>() + fields[4].Get<uint32>() + fields[6].Get<uint32>();
                uint32 totalEssence = fields[3].Get<uint32>() + fields[5].Get<uint32>() + fields[7].Get<uint32>();
                uint8 slotsUnlocked = fields[8].Get<uint8>();

                JsonValue reward;
                reward.SetObject();
                reward.Set("id", JsonValue(chestId));
                reward.Set("type", JsonValue("weekly_chest"));
                reward.Set("weekTimestamp", JsonValue(static_cast<double>(weekTimestamp)));
                reward.Set("tokens", JsonValue(totalTokens));
                reward.Set("essence", JsonValue(totalEssence));
                reward.Set("slotsUnlocked", JsonValue(slotsUnlocked));
                rewards.Push(reward);
            } while (result->NextRow());
        }

        JsonMessage response(Module::SEASONAL, Opcode::Season::SMSG_REWARDS);
        response.Set("seasonId", JsonValue(seasonId));
        response.Set("count", JsonValue(static_cast<uint32>(rewards.Size())));
        response.Set("rewards", rewards);
        response.Send(player);
    }

    static void HandleClaimReward(Player* player, const ParsedMessage& msg)
    {
        uint32 rewardId = 0;
        if (IsJsonMessage(msg))
        {
            JsonValue req = GetJsonData(msg);
            if (req.IsObject() && req.HasKey("rewardId") && req["rewardId"].IsNumber())
                rewardId = req["rewardId"].AsUInt32();
        }
        else
            rewardId = msg.GetUInt32(0);

        if (rewardId == 0)
        {
            SendRewardClaimed(player, rewardId, CLAIM_ERROR, 0, 0);
            return;
        }

        QueryResult result = CharacterDatabase.Query(
            "SELECT slot1_tokens, slot1_essence, slot2_tokens, slot2_essence, slot3_tokens, slot3_essence, collected "
            "FROM dc_player_seasonal_chests WHERE id = {} AND player_guid = {}",
            rewardId, player->GetGUID().GetCounter());

        if (!result)
        {
            SendRewardClaimed(player, rewardId, CLAIM_ERROR, 0, 0);
            return;
        }

        Field* fields = result->Fetch();
        if (fields[6].Get<uint8>() != 0)
        {
            SendRewardClaimed(player, rewardId, CLAIM_ALREADY_CLAIMED, 0, 0);
            return;
        }

        uint32 totalTokens = fields[0].Get<uint32>() + fields[2].Get<uint32>() + fields[4].Get<uint32>();
        uint32 totalEssence = fields[1].Get<uint32>() + fields[3].Get<uint32>() + fields[5].Get<uint32>();

        bool awarded = false;
        if (sSeasonalRewards)
            awarded = sSeasonalRewards->AwardBoth(player, totalTokens, totalEssence, "WeeklyChest", rewardId);

        if (!awarded && (totalTokens > 0 || totalEssence > 0))
        {
            SendRewardClaimed(player, rewardId, CLAIM_ERROR, 0, 0);
            return;
        }

        CharacterDatabase.Execute(
            "UPDATE dc_player_seasonal_chests SET collected = 1, collected_at = CURRENT_TIMESTAMP WHERE id = {}",
            rewardId);

        SendRewardClaimed(player, rewardId, CLAIM_SUCCESS, 0, 0);
    }

    static void HandleGetLeaderboard(Player* player, const ParsedMessage& msg)
    {
        uint32 seasonId = GetSeasonIdFromMsg(msg);
        uint32 page = 1;
        uint32 perPage = 10;

        if (IsJsonMessage(msg))
        {
            JsonValue req = GetJsonData(msg);
            if (req.IsObject())
            {
                if (req.HasKey("page") && req["page"].IsNumber())
                    page = std::max<uint32>(1, req["page"].AsUInt32());
                if (req.HasKey("perPage") && req["perPage"].IsNumber())
                    perPage = std::min<uint32>(50, std::max<uint32>(1, req["perPage"].AsUInt32()));
            }
        }
        else if (msg.GetDataCount() > 1)
        {
            page = std::max<uint32>(1, msg.GetUInt32(1));
        }

        uint32 totalEntries = 0;
        if (QueryResult countRes = CharacterDatabase.Query(
            "SELECT COUNT(*) FROM v_seasonal_leaderboard WHERE season_id = {}",
            seasonId))
        {
            totalEntries = countRes->Fetch()[0].Get<uint32>();
        }

        uint32 offset = (page - 1) * perPage;

        JsonValue entries;
        entries.SetArray();

        QueryResult result = CharacterDatabase.Query(
            "SELECT v.player_guid, c.name, v.total_tokens_earned, v.total_essence_earned, "
            "v.quests_completed, v.bosses_killed, v.chests_claimed, v.token_rank, v.boss_rank "
            "FROM v_seasonal_leaderboard v "
            "LEFT JOIN characters c ON c.guid = v.player_guid "
            "WHERE v.season_id = {} "
            "ORDER BY v.total_tokens_earned DESC "
            "LIMIT {}, {}",
            seasonId, offset, perPage);

        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                JsonValue entry;
                entry.SetObject();
                entry.Set("guid", JsonValue(fields[0].Get<uint32>()));
                entry.Set("name", JsonValue(fields[1].Get<std::string>()));
                entry.Set("tokens", JsonValue(fields[2].Get<uint32>()));
                entry.Set("essence", JsonValue(fields[3].Get<uint32>()));
                entry.Set("quests", JsonValue(fields[4].Get<uint32>()));
                entry.Set("bosses", JsonValue(fields[5].Get<uint32>()));
                entry.Set("chests", JsonValue(fields[6].Get<uint32>()));
                entry.Set("tokenRank", JsonValue(fields[7].Get<uint32>()));
                entry.Set("bossRank", JsonValue(fields[8].Get<uint32>()));
                entries.Push(entry);
            } while (result->NextRow());
        }

        JsonMessage response(Module::SEASONAL, SMSG_LEADERBOARD);
        response.Set("seasonId", JsonValue(seasonId));
        response.Set("page", JsonValue(page));
        response.Set("perPage", JsonValue(perPage));
        response.Set("total", JsonValue(totalEntries));
        response.Set("entries", entries);
        response.Send(player);
    }

    static void HandleGetChallenges(Player* player, const ParsedMessage& /*msg*/)
    {
        JsonMessage response(Module::SEASONAL, SMSG_CHALLENGES);
        response.Set("dailyChallenge1", JsonValue(0));
        response.Set("dailyChallenge2", JsonValue(0));
        response.Set("weeklyChallenge", JsonValue(0));
        response.Set("seasonProgress", JsonValue(0));
        response.Send(player);
    }

    // Register handlers with the router
    void RegisterHandlers()
    {
        DC_REGISTER_HANDLER(Module::SEASONAL, Opcode::Season::CMSG_GET_CURRENT, HandleGetCurrentSeason);
        DC_REGISTER_HANDLER(Module::SEASONAL, Opcode::Season::CMSG_GET_REWARDS, HandleGetRewards);
        DC_REGISTER_HANDLER(Module::SEASONAL, Opcode::Season::CMSG_GET_PROGRESS, HandleGetProgress);
        DC_REGISTER_HANDLER(Module::SEASONAL, CMSG_CLAIM_REWARD, HandleClaimReward);
        DC_REGISTER_HANDLER(Module::SEASONAL, CMSG_GET_LEADERBOARD, HandleGetLeaderboard);
        DC_REGISTER_HANDLER(Module::SEASONAL, CMSG_GET_CHALLENGES, HandleGetChallenges);

        LOG_INFO("dc.addon", "Seasons module handlers registered");
    }

}  // namespace Seasons
}  // namespace DCAddon

// Register the Seasons addon handler
void AddSC_dc_addon_seasons()
{
    DCAddon::Seasons::RegisterHandlers();
}
