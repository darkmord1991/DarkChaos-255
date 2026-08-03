-- ---------------------------------------------------------------------------
-- 244  Map 750 -- item-upgrade token integration for the 80-130 gear
-- ---------------------------------------------------------------------------
-- Upgrade-tier membership is purely ItemLevel-driven (ItemUpgradeManager.cpp
-- GetItemTier: overrides first, else the dc_item_upgrade_tiers ilvl windows,
-- highest tier_id wins). Current windows: T1 1-212, T2 213-226, T4 300-411,
-- T5 412+. Consequences for the leveling continent:
--
--   * the 400xxx ladder AND the 243_ themed sets (ilvl 300-398) are ALREADY
--     tier-4 token-upgradeable -- nothing to do;
--   * most re-banded Cata drop shells (ilvl <= 212) are already tier 1;
--   * but **ilvl 227-299 maps to NO tier** -- those items are invisible to
--     the upgrade UI (HandleListUpgradeable gates on tier > 0). 18 shells
--     sit at ilvl 292 today, and any future re-band into that window dies.
--
-- Fix 1: close the gap -- extend tier 2 (Heroic, 15 upgrade levels, Upgrade
-- Token) to ilvl 299. One row; per the "highest tier_id wins" rule this
-- changes nothing for 1-212 (T1) or 300+ (T4/T5).
--
-- Fix 2: put the Upgrade Token itself (item 300311 -- a physical inventory
-- item) into the zone's flow: rares and bosses on map 750 drop it. Regular
-- token income already comes from the systemic hooks (quest completion,
-- creature kills, PvP -- ItemUpgradeTokenHooks.cpp), which the QuestLevel=-1
-- quests feed automatically; this is the visible "rare = jackpot" layer.
--
-- AFTER APPLY: `.upgrade prog reload` (or worldserver restart) -- the tier
-- table is loaded once at startup.
-- Run AFTER 232_ (loot fork) and 233_ (ranks/bands). Idempotent.
-- ---------------------------------------------------------------------------

-- 1. close the ilvl 227-299 dead window (tier 2 -> 299)
UPDATE `dc_item_upgrade_tiers`
SET `max_ilvl` = 299
WHERE `tier_id` = 2 AND `season` = 1 AND `max_ilvl` = 226;

-- 2. Upgrade Token drops from rares and bosses on map 750
--    rank 2/3 (rare-elite/boss): 35% for 1; rank 4 (named rare): guaranteed 1-3.
DELETE clt FROM `creature_loot_template` clt
WHERE clt.`Item` = 300311 AND clt.`Reference` = 0
  AND clt.`Entry` BETWEEN 3600000 AND 3799999;

INSERT INTO `creature_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT DISTINCT ct.`lootid`, 300311, 0,
       IF(ct.`rank` = 4, 100, 35), 0, 1, 0, 1,
       IF(ct.`rank` = 4, 3, 1),
       'DC750 Upgrade Token'
FROM `creature_template` ct
JOIN `dc_map750_entryzone` ez ON ez.`entry` = ct.`entry`
JOIN `dc_map750_band` b ON b.`zone` = ez.`zone`
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`lootid` = ct.`entry`
  AND ct.`rank` >= 2
  AND ct.`type` NOT IN (8, 10)
  AND ct.`npcflag` = 0;

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- tier windows now contiguous 1..inf (expect T2 max_ilvl = 299):
-- SELECT tier_id, min_ilvl, max_ilvl FROM dc_item_upgrade_tiers
-- WHERE season = 1 AND is_artifact = 0 ORDER BY tier_id;
-- nothing on the leveling continent in a dead ilvl window (expect 0):
-- SELECT COUNT(*) FROM item_template it
-- WHERE it.entry BETWEEN 60000 AND 402024 AND it.class IN (2, 4)
--   AND it.InventoryType > 0 AND it.ItemLevel BETWEEN 227 AND 299
--   AND NOT EXISTS (SELECT 1 FROM dc_item_upgrade_tiers t WHERE t.season = 1
--                   AND t.is_artifact = 0 AND it.ItemLevel >= t.min_ilvl
--                   AND (t.max_ilvl = 0 OR it.ItemLevel <= t.max_ilvl));
-- token drop coverage:
-- SELECT ez.zone, COUNT(*) FROM creature_loot_template clt
-- JOIN dc_map750_entryzone ez ON ez.entry = clt.Entry
-- WHERE clt.Item = 300311 GROUP BY ez.zone;
-- In-game after `.upgrade prog reload`: open the DC-ItemUpgrade addon window
-- with a Tidewatcher's piece (tier 4 expected) and a re-banded Cata green
-- (tier 1/2 expected); kill a rare, confirm the token drop.
