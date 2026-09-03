-- ---------------------------------------------------------------------------
-- 320  Tier 4 / Tier 5 are paid in Emberwood Sap -- and re-priced for it
-- ---------------------------------------------------------------------------
-- Companion to the C++ change that adds CURRENCY_FRONTIER_SAP. Apply BOTH or
-- NEITHER: this file alone re-prices tiers that would still charge the generic
-- token, and the C++ alone charges sap at token-scale prices, which is
-- unreachable (see below).
--
-- WHAT THE C++ SIDE DOES
--   ItemUpgradeManager.h    CurrencyType gains CURRENCY_FRONTIER_SAP = 3
--   ItemUpgradeManager.cpp  GetFrontierSapItemId()  (config ItemUpgrade.Currency.SapId)
--                           GetCurrencyItemId()     (replaces 3 copies of a ternary
--                                                    that would have silently
--                                                    charged ESSENCE for sap)
--                           GetTierCurrency()       T3 -> essence, T4/T5 -> sap,
--                                                   everything else -> token
--   ItemUpgradeAdvancedImpl.cpp  respec refunds resolve the currency from tier_id
--   dc_addon_upgrade.cpp    sends sap balance + per-tier currency to the UI
--   darkchaos-custom.conf.dist   ItemUpgrade.Currency.SapId = 400000
--
-- 🔴 THE COST COLUMN DOES NOT MOVE. T4/T5 stay priced in `token_cost`; only the
-- ITEM deducted changes. A `sap_cost` column would split one number across two
-- places and let the loader and the spend path disagree.
--
-- ---------------------------------------------------------------------------
-- WHY THE PRICES HAD TO CHANGE
-- ---------------------------------------------------------------------------
-- Sap and the Upgrade Token are economies of completely different size, and
-- swapping the currency without re-pricing would have made T4/T5 unreachable.
-- Measured live:
--
--   INCOME  sap drops from 550 map-750 creatures at 9.33% average for 1-3,
--           i.e. **~0.19 sap per kill**. NO quest pays sap (checked: zero
--           quest_template rows reward item 400000) -- it is a pure drop
--           currency, unlike the token, which quests pay 20-75 of and rares
--           20-150 of.
--   PRICES  the existing sap vendors are the honest yardstick for what sap is
--           worth, and they sell WHOLE GEAR PIECES:
--               ilvl 300 blue (ladder T1)   30 sap
--               ilvl 332 blue (ladder T2)   50 sap
--               ilvl 365 epic               30-50 sap
--
-- So one gear piece costs 30-50 sap, or roughly 160-260 kills. The old token
-- prices were 100-1000 per T4 step and 300-4500 per T5 step: a SINGLE T4 step
-- would have cost more than three complete gear pieces, and a full T5 path
-- (36,000) would have cost ~190,000 kills. Those numbers were calibrated
-- against token throughput and mean nothing in sap.
--
-- NEW PRICES, anchored on the vendor's own 30-50 sap per piece:
--
--   T4  3 x level ->  3, 6, 9 ... 30   total  165 sap  (~870 kills)
--       a full +50% stat / +30 ilvl path costs about five gear pieces
--   T5  5 x level ->  5,10,15 ... 75   total  600 sap  (~3,160 kills)
--       the endgame cap, about twelve to twenty gear pieces
--
-- That is 1/33 of the old T4 total and 1/60 of the old T5 total, which is the
-- ratio between the two economies rather than a number picked for feel.
--
-- 🔴 RETUNING: change @t4_step / @t5_step. Both are linear in the upgrade
-- level, so the totals are step x n(n+1)/2 -- 55x and 120x respectively.
--
-- ---------------------------------------------------------------------------
-- NOT DONE ON PURPOSE
-- ---------------------------------------------------------------------------
-- Emberwood Sap is deliberately NOT given BagFamily 0x2000 the way 254_ gave it
-- to the token and essence. That flag routes an item into the currency-token
-- slots, and Player::AddKnownCurrency then reads its `CurrencyTypes.dbc` row to
-- draw it in the Currency tab. Sap has NO CurrencyTypes row, so flagging it
-- would move it out of the bags without giving the client anywhere to show it.
-- If sap should live in the Currency tab, add the DBC row FIRST (and note 254_'s
-- warning that CurrencyTypesEntry.ItemId is the store's real index, so a second
-- row with the same ItemID collides), then set the flag.
--
-- Apply against acore_world. Idempotent. Needs `.upgrade prog reload` or a
-- worldserver restart -- costs are loaded once at startup.
-- ---------------------------------------------------------------------------

USE `acore_world`;

SET @t4_step := 3;
SET @t5_step := 5;

-- ---------------------------------------------------------------------------
-- Re-price T4 and T5 in sap
-- ---------------------------------------------------------------------------
-- essence_cost stays 0: essence is T3's currency and T4/T5 never touch it.
-- ilvl_increase and stat_increase_percent are unchanged -- this file moves
-- money only, not power.
UPDATE `dc_item_upgrade_costs`
SET `token_cost` = @t4_step * `upgrade_level`
WHERE `tier_id` = 4 AND `season` = 1;

UPDATE `dc_item_upgrade_costs`
SET `token_cost` = @t5_step * `upgrade_level`
WHERE `tier_id` = 5 AND `season` = 1;

-- Keep the tier summary column honest -- the addon shows `upgrade_cost_per_level`
-- in tier lists, and leaving it at the token-era 500/1000 would advertise a
-- price the spend path no longer charges.
UPDATE `dc_item_upgrade_tiers`
SET `upgrade_cost_per_level` = @t4_step,
    `description` = 'Hyjal Frontier leveling gear - 10 upgrades, +5% per level (+50% max), paid in Emberwood Sap'
WHERE `tier_id` = 4 AND `season` = 1;

UPDATE `dc_item_upgrade_tiers`
SET `upgrade_cost_per_level` = @t5_step,
    `description` = 'Hyjal Frontier endgame gear - 15 upgrades, +4% per level (+60% max), paid in Emberwood Sap'
WHERE `tier_id` = 5 AND `season` = 1;

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- New price curve (expect T4 3..30 total 165, T5 5..75 total 600):
-- SELECT tier_id, COUNT(*) levels, MIN(token_cost) first_step,
--        MAX(token_cost) last_step, SUM(token_cost) total, SUM(essence_cost) essence
-- FROM dc_item_upgrade_costs WHERE season = 1 GROUP BY tier_id ORDER BY tier_id;
--
-- Sanity against the vendor anchor -- a full T4 path in "gear pieces":
-- SELECT ROUND(165 / 30, 1) AS t4_paths_in_ilvl300_pieces,
--        ROUND(600 / 50, 1) AS t5_paths_in_ilvl332_pieces;
--
-- In-game, after `.upgrade prog reload` and a worldserver restart:
--   * open the upgrade UI with an ilvl 300-411 piece -> tier 4, cost shown in
--     Emberwood Sap, and the sap balance visible;
--   * upgrade once and confirm SAP is deducted and the token count is unchanged;
--   * respec that item and confirm the refund comes back as SAP, not tokens
--     (this is the case the tier_id lookup in RespecItem exists to protect);
--   * confirm an ilvl 213-299 piece still charges DC Item Upgrade Tokens.
-- ---------------------------------------------------------------------------
