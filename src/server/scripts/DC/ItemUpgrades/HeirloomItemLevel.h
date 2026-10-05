/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Released under GNU AGPL v3 License
 */

#pragma once

#include "DBCStores.h"
#include "ItemTemplate.h"

#include <algorithm>

/*
 * Item level of a level-scaling (heirloom) item, for display.
 *
 * A scaling item's item_template.ItemLevel is a placeholder -- 1 on every Blizzard
 * heirloom, 80 on the DC set -- while its stats follow the owner's level through
 * ScalingStatDistribution / ScalingStatValues. These helpers give the item level
 * those stats are worth: the level at which a rare (blue) item gets the same stat
 * budget, i.e. ScalingStatValues(level).PrimaryBudget inverted through the
 * RandPropPoints rare full-slot budget. Blizzard built the heirloom budgets that
 * way: the inversion sits on level + 5 from 10 to 57, gives 147 at 70 and exactly
 * 187 at 80. RandPropPoints carries no budget below item level 10 and both tables
 * round in whole steps, so the result never drops below level + 5; past the last
 * RandPropPoints row it continues at that row's step.
 *
 * Display only: upgrade tiers, costs and every other item-level rule keep reading
 * the template value. The client DLL draws the stock tooltip line with the same
 * definition (WotLKExtensions CGTooltip.cpp, GetScalingItemLevelForLevel) -- keep
 * the two in step.
 */
namespace DarkChaos::ItemUpgrade
{
    constexpr uint32 SCALING_ITEM_LEVEL_FLOOR_OFFSET = 5;

    inline bool IsLevelScalingItem(ItemTemplate const* proto)
    {
        return proto && proto->ScalingStatDistribution && proto->ScalingStatValue;
    }

    // The level a scaling item's stats are shown at for an owner of `ownerLevel`, as
    // the client computes it for the tooltip (0x61E740): clamped to RequiredLevel and
    // to the distribution's MaxLevel, never below 1.
    inline uint32 GetItemScalingLevel(ItemTemplate const* proto, uint32 ownerLevel)
    {
        uint32 level = ownerLevel;
        if (ScalingStatDistributionEntry const* ssd =
                sScalingStatDistributionStore.LookupEntry(proto->ScalingStatDistribution))
        {
            if (std::max(level, proto->RequiredLevel) >= ssd->MaxLevel)
                level = ssd->MaxLevel;
            else if (proto->RequiredLevel > level)
                level = proto->RequiredLevel;
        }

        return std::max<uint32>(level, 1);
    }

    // The ScalingStatValues row for `level`, falling back to the nearest lower row
    // the way Player::_ApplyItemBonuses does.
    inline ScalingStatValuesEntry const* GetScalingStatValuesForLevel(uint32 level)
    {
        if (ScalingStatValuesEntry const* ssv = sScalingStatValuesStore.LookupEntry(level))
            return ssv;

        uint32 const rowCount = sScalingStatValuesStore.GetNumRows();
        if (rowCount > 0 && level >= rowCount)
            level = rowCount - 1;

        for (; level > 0; --level)
            if (ScalingStatValuesEntry const* ssv = sScalingStatValuesStore.LookupEntry(level))
                return ssv;

        return nullptr;
    }

    // Lowest item level whose rare full-slot budget reaches `budget`; 0 when the
    // budget is below the first RandPropPoints row that carries one.
    inline uint32 GetRareItemLevelForBudget(uint32 budget)
    {
        uint32 lastItemLevel = 0;
        uint32 lastBudget = 0;
        uint32 previousBudget = 0;
        for (uint32 itemLevel = 0; itemLevel < sRandomPropertiesPointsStore.GetNumRows(); ++itemLevel)
        {
            RandomPropertiesPointsEntry const* points = sRandomPropertiesPointsStore.LookupEntry(itemLevel);
            if (!points || !points->RarePropertiesPoints[0])
                continue;

            uint32 const rowBudget = points->RarePropertiesPoints[0];
            if (!lastItemLevel && budget < rowBudget)
                return 0;

            if (rowBudget >= budget)
                return itemLevel;

            previousBudget = lastBudget;
            lastBudget = rowBudget;
            lastItemLevel = itemLevel;
        }

        if (!lastItemLevel)
            return 0;

        uint32 const step = lastBudget > previousBudget ? lastBudget - previousBudget : 1;
        return lastItemLevel + (budget - lastBudget + step - 1) / step;
    }

    // Item level a scaling item is worth at `scalingLevel` (see the top of this file).
    // ssdMultiplier2 is the PrimaryBudget column: the chest / two-hand budget.
    inline uint32 GetScalingItemLevelForLevel(uint32 scalingLevel)
    {
        ScalingStatValuesEntry const* ssv = GetScalingStatValuesForLevel(scalingLevel);
        uint32 const itemLevel = ssv ? GetRareItemLevelForBudget(ssv->ssdMultiplier2) : 0;
        return std::max(itemLevel, scalingLevel + SCALING_ITEM_LEVEL_FLOOR_OFFSET);
    }
}
