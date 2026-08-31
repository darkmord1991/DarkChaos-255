/*
 * DarkChaos-255 Shared Utilities (currency layer)
 * ==============================================
 *
 * Currency Management:
 * The CurrencyUtils namespace provides centralized functions for synchronizing
 * physical currency items (tokens/essence) with database records. This ensures
 * the DB remains the single source of truth while keeping the character currency
 * window up-to-date. All systems should use these utilities instead of
 * implementing their own sync logic.
 *
 * LAYERING: this header sits ABOVE the leaf layer -- it depends on Player and on
 * the ItemUpgrades subsystem, so including it creates an edge to ItemUpgrades.
 * The dependency-free string/format/parse helpers that used to live here now
 * live in CrossSystemCommon.h, which is included below so every existing
 * `DCUtils::` caller keeps compiling unchanged.
 *
 * >>> If you only need string/JSON/parse/format helpers, include
 * >>> "CrossSystemCommon.h" directly instead of this header. <<<
 *
 * Copyright (C) 2025 DarkChaos Development Team
 */

#ifndef DC_UTILITIES_H
#define DC_UTILITIES_H

// Leaf helpers (DCUtils::) -- kept included here for source compatibility with the
// existing call sites that reach them through this header.
#include "CrossSystemCommon.h"

// =========================================================================
// Currency Management Utilities
// =========================================================================

#include "Player.h"
#include "ObjectAccessor.h"
#include "ObjectGuid.h"
#include "DC/ItemUpgrades/ItemUpgradeManager.h"
#include "SeasonResolver.h"

// Forward declaration for SendCurrencyUpdate
namespace DCAddon { namespace Upgrade { void SendCurrencyUpdate(Player*); } }

namespace DarkChaos
{
namespace CrossSystem
{
namespace CurrencyUtils
{
    /**
     * Synchronize currency - AzerothCore Standard
     *
     * With the simplified item-based currency system, this function is now a no-op.
     * Inventory items ARE the currency - no database sync needed.
     *
     * Kept for API compatibility with existing callers.
     */
    inline bool SyncInventoryToDB(
        uint32 /*playerGuid*/,
        uint32 /*season*/ = 1,
        Player* /*player*/ = nullptr,
        DarkChaos::ItemUpgrade::CurrencyType /*specificCurrency*/ = DarkChaos::ItemUpgrade::CURRENCY_UPGRADE_TOKEN,
        uint32 /*dbAmount*/ = 0,
        bool /*syncBoth*/ = true)
    {
        // AzerothCore Standard: No DB sync needed - inventory items ARE the currency
        return true;
    }

    /**
     * Add currency - AzerothCore Standard
     *
     * Simple wrapper around UpgradeManager::AddCurrency which now directly adds items.
     * No DB sync needed since inventory items ARE the currency.
     */
    inline bool AddCurrencyAndSync(
        uint32 playerGuid,
        DarkChaos::ItemUpgrade::CurrencyType currency,
        uint32 amount,
        uint32 season = 1,
        Player* player = nullptr,
        bool /*autoSync*/ = true)
    {
        using namespace DarkChaos::ItemUpgrade;

        if (playerGuid == 0 || amount == 0)
            return false;

        // Cap at reasonable max to prevent exploits
        constexpr uint32 MAX_ADD_AMOUNT = 100000;
        if (amount > MAX_ADD_AMOUNT)
            amount = MAX_ADD_AMOUNT;

        auto* mgr = GetUpgradeManager();
        if (!mgr)
            return false;

        bool success = mgr->AddCurrency(playerGuid, currency, amount, season);

        // Send addon UI update if player is online
        if (success && player && player->GetSession())
            DCAddon::Upgrade::SendCurrencyUpdate(player);

        return success;
    }

    /**
     * Remove currency - AzerothCore Standard
     *
     * Simple wrapper around UpgradeManager::RemoveCurrency which now directly removes items.
     * No DB sync needed since inventory items ARE the currency.
     */
    inline bool RemoveCurrencyAndSync(
        uint32 playerGuid,
        DarkChaos::ItemUpgrade::CurrencyType currency,
        uint32 amount,
        uint32 season = 1,
        Player* player = nullptr,
        bool /*autoSync*/ = true)
    {
        using namespace DarkChaos::ItemUpgrade;

        if (playerGuid == 0 || amount == 0)
            return false;

        auto* mgr = GetUpgradeManager();
        if (!mgr)
            return false;

        bool success = mgr->RemoveCurrency(playerGuid, currency, amount, season);

        // Send addon UI update if player is online
        if (success && player && player->GetSession())
            DCAddon::Upgrade::SendCurrencyUpdate(player);

        return success;
    }

} // namespace CurrencyUtils
} // namespace CrossSystem
} // namespace DarkChaos

#endif // DC_UTILITIES_H
