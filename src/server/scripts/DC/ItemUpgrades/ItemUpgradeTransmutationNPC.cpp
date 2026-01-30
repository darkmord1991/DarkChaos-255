/*
 * Deprecated: Transmutation NPC renamed to Exchange (Jan 2026).
 * This file provides a compatibility wrapper to avoid stale build references.
 */

void AddSC_ItemUpgradeExchange();

void AddSC_ItemUpgradeTransmutation()
{
    AddSC_ItemUpgradeExchange();
}
