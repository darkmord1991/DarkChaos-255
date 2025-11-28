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
#include "DCAddonNamespace.h"

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

    // Send current season information
    void SendSeasonInfo(Player* player, uint32 seasonId, const std::string& seasonName,
                        uint32 startTime, uint32 endTime, uint32 daysRemaining)
    {
        Message msg(Module::SEASONAL, Opcode::Season::SMSG_CURRENT_SEASON);
        msg.Add(seasonId);
        msg.Add(seasonName);
        msg.Add(startTime);
        msg.Add(endTime);
        msg.Add(daysRemaining);
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
        Message msg(Module::SEASONAL, SMSG_REWARD_CLAIMED);
        msg.Add(rewardId);
        msg.Add(static_cast<uint8>(result));
        msg.Add(itemId);
        msg.Add(itemCount);
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
        // TODO: Query current season from database/config
        // For now send placeholder data

        uint32 seasonId = 1;
        std::string seasonName = "Season of Chaos";
        uint32 now = time(nullptr);
        uint32 startTime = now - (30 * 24 * 60 * 60); // 30 days ago
        uint32 endTime = now + (60 * 24 * 60 * 60);   // 60 days remaining
        uint32 daysRemaining = 60;

        SendSeasonInfo(player, seasonId, seasonName, startTime, endTime, daysRemaining);
    }

    static void HandleGetProgress(Player* player, const ParsedMessage& msg)
    {
        uint32 seasonId = msg.GetUInt32(0);

        // TODO: Query player's seasonal progress from character_dc_seasons table
        // For now send placeholder data

        SendProgress(player, seasonId, 1, 0, 1000, 0, 0, 0);
    }

    static void HandleGetRewards(Player* player, const ParsedMessage& msg)
    {
        uint32 seasonId = msg.GetUInt32(0);

        // TODO: Build reward list from dc_season_rewards table
        // This would typically be a multi-message response for large reward lists
        // Consider using AIO for complex reward displays

        Message response(Module::SEASONAL, Opcode::Season::SMSG_REWARDS);
        response.Add(seasonId);
        response.Add(0); // Reward count
        response.Send(player);
    }

    static void HandleClaimReward(Player* player, const ParsedMessage& msg)
    {
        uint32 rewardId = msg.GetUInt32(0);

        // TODO: Validate and process reward claim
        // 1. Check if player has unlocked this reward level
        // 2. Check if already claimed
        // 3. Check inventory space
        // 4. Grant reward

        // For now, always return error
        SendRewardClaimed(player, rewardId, CLAIM_ERROR, 0, 0);
    }

    static void HandleGetLeaderboard(Player* player, const ParsedMessage& msg)
    {
        uint32 seasonId = msg.GetUInt32(0);
        uint32 page = msg.GetUInt32(1);
        uint32 perPage = msg.GetDataCount() > 2 ? msg.GetUInt32(2) : 10;

        // TODO: Query leaderboard from database
        // This typically uses AIO for complex paginated display

        Message response(Module::SEASONAL, SMSG_LEADERBOARD);
        response.Add(seasonId);
        response.Add(page);
        response.Add(0); // Total entries
        response.Add(0); // Entries in this message
        response.Send(player);
    }

    static void HandleGetChallenges(Player* player, const ParsedMessage& /*msg*/)
    {
        // TODO: Query active challenges for player
        // This includes daily, weekly, and season-long challenges

        Message response(Module::SEASONAL, SMSG_CHALLENGES);
        response.Add(0); // Daily challenge 1
        response.Add(0); // Daily challenge 2
        response.Add(0); // Weekly challenge
        response.Add(0); // Season challenge progress
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
