/*
 * DarkChaos Cross-System Reward Helpers
 *
 * Single, lightweight API that game systems should use to award
 * Tokens / Essence (seasonal currencies) and related item rewards.
 *
 * Goal:
 * - Centralize token/essence awarding so weekly caps, logging, and
 *   player messaging are consistent.
 */

#pragma once

#include "Define.h"
#include "Player.h"

#include "DC/CrossSystem/RewardDistributor.h"
#include "DC/CrossSystem/SessionContext.h"
#include "DC/CrossSystem/DCSeasonHelper.h"

#include "DC/Seasons/SeasonalRewardSystem.h"

namespace DarkChaos
{
namespace CrossSystem
{
namespace Rewards
{
    inline bool AwardTokens(Player* player, uint32 amount, SystemId sourceSystem, EventType triggerEvent,
                            const std::string& sourceName, uint32 sourceId = 0)
    {
        if (!player || amount == 0)
            return false;

        // Prefer RewardDistributor path (so multipliers/transactions stay centralized).
        // Internally, RewardDistributor should forward to SeasonalRewardManager for actual delivery.
        if (RewardDistributor* distributor = RewardDistributor::instance())
        {
            RewardContext ctx;
            if (SessionContext* session = GetPlayerSession(player))
                ctx = session->BuildRewardContext(sourceSystem, triggerEvent, sourceId, sourceName);
            else
            {
                ctx.playerGuid = player->GetGUID();
                ctx.sourceSystem = sourceSystem;
                ctx.triggerEvent = triggerEvent;
                ctx.sourceId = sourceId;
                ctx.sourceName = sourceName;
                ctx.seasonId = DarkChaos::GetActiveSeasonId();
            }

            auto result = distributor->DistributeTokens(player, ctx, amount);
            return result.success;
        }

        // Fallback: SeasonalRewardManager direct.
        if (auto* mgr = DarkChaos::SeasonalRewards::SeasonalRewardManager::instance())
            return mgr->AwardTokens(player, amount, sourceName, sourceId);

        return false;
    }

    inline bool AwardEssence(Player* player, uint32 amount, SystemId sourceSystem, EventType triggerEvent,
                             const std::string& sourceName, uint32 sourceId = 0)
    {
        if (!player || amount == 0)
            return false;

        if (RewardDistributor* distributor = RewardDistributor::instance())
        {
            RewardContext ctx;
            if (SessionContext* session = GetPlayerSession(player))
                ctx = session->BuildRewardContext(sourceSystem, triggerEvent, sourceId, sourceName);
            else
            {
                ctx.playerGuid = player->GetGUID();
                ctx.sourceSystem = sourceSystem;
                ctx.triggerEvent = triggerEvent;
                ctx.sourceId = sourceId;
                ctx.sourceName = sourceName;
                ctx.seasonId = DarkChaos::GetActiveSeasonId();
            }

            auto result = distributor->DistributeEssence(player, ctx, amount);
            return result.success;
        }

        if (auto* mgr = DarkChaos::SeasonalRewards::SeasonalRewardManager::instance())
            return mgr->AwardEssence(player, amount, sourceName, sourceId);

        return false;
    }

    // Award an item. If the item is the configured Seasonal token/essence item,
    // route through the seasonal/cross-system pipeline.
    inline bool AwardItemOrSeasonalCurrency(Player* player, uint32 itemId, uint32 amount,
                                           SystemId sourceSystem, EventType triggerEvent,
                                           const std::string& sourceName, uint32 sourceId = 0)
    {
        if (!player || itemId == 0 || amount == 0)
            return false;

        if (auto* mgr = DarkChaos::SeasonalRewards::SeasonalRewardManager::instance())
        {
            auto const& cfg = mgr->GetConfig();
            if (itemId == cfg.tokenItemId)
                return AwardTokens(player, amount, sourceSystem, triggerEvent, sourceName, sourceId);
            if (itemId == cfg.essenceItemId)
                return AwardEssence(player, amount, sourceSystem, triggerEvent, sourceName, sourceId);
        }

        // Non-seasonal item: deliver directly.
        return player->AddItem(itemId, amount);
    }

} // namespace Rewards
} // namespace CrossSystem
} // namespace DarkChaos
