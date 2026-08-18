-- ---------------------------------------------------------------------------
-- 293  Winterspring gets its own gear tier -- ilvl 385 / ReqLvl 108
-- ---------------------------------------------------------------------------
-- Winterspring (zone 4926, band 104-115) drops reference 750104, which resolved
-- to **ilvl 372 / ReqLvl 102 -- byte-identical in tier to Felwood's 750096**.
-- Eleven levels of a levelling continent with no gear step-up. Flagged in 288_
-- and 290_ as needing a balance decision; the decision is ilvl 385 / ReqLvl 108,
-- sitting evenly between Felwood's 372/102 and Hyjal's 398/115.
--
-- 🔴 THIS NEEDS NO NEW ITEMS AND NO CLIENT DEPLOY, WHICH IS NOT WHAT I FIRST
-- ESTIMATED. I scoped this as "a fifth 15-item tier: new item ids, a
-- gen_map750_themed_sets.py run, an Item.dbc + ItemDisplayInfo rebuild and a
-- client deploy". That was wrong on both counts:
--
--   1. Winterspring ALREADY has its own 15 items -- 400768-400782, the
--      "Frostsaber Stalker's" themed set from 243_. They are distinct ids from
--      Felwood's 400753-400767; 243_ simply generated both sets at the same
--      ilvl. So the tier exists, it was just never differentiated.
--   2. **Item.dbc carries no ItemLevel and no RequiredLevel.** Its eight fields
--      are Id, ClassID, SubclassID, SoundOverrideSubclassID, Material,
--      DisplayInfoID, InventoryType, SheatheType -- none of which change here.
--      ItemLevel, RequiredLevel, armour and stats are `item_template` only.
--
-- So this is one UPDATE against 15 rows. No ids allocated, no DBC touched, no
-- MPQ repack, no client restart.
--
-- SCOPE CHECKED BEFORE TOUCHING ANYTHING: items 400768-400782 are referenced by
-- **reference_loot_template only** (the 15 rows behind ref 750104) -- 0 vendor
-- rows, 0 quest reward slots, 0 direct creature_loot rows. Re-statting them
-- moves the Winterspring ladder drop and nothing else on the server.
--
-- UPGRADE TIERS ARE UNAFFECTED. `dc_item_upgrade_tiers` resolves highest
-- tier_id first, and tier 10 spans ilvl 1-500, so 372 and 385 both land in
-- tier 10 -- same 15 upgrade levels before and after. (Tier 4's 300-411 window
-- also still contains 385, so the fallback reading is stable too.)
--
-- ---------------------------------------------------------------------------
-- The multiplier, and where it comes from
-- ---------------------------------------------------------------------------
-- Rather than invent a stat budget, the scale factor is measured off the two
-- tiers this one sits between. Comparing the same archetype at 372 and 398
-- (Frostsaber Stalker's cloth vs Worldtree Arcanist cloth):
--     spell power  198 / 174 = 1.13793
--     stamina      141 / 124 = 1.13710
--     crit         123 / 108 = 1.13889
-- -- a consistent 1.1380 across a 26-ilvl gap. 385 is exactly half that gap, so
-- the factor is 1 + 0.1380/2 = **1.069**, applied to armour and to every stat
-- value. Interpolated rather than extrapolated, so the new tier cannot overtake
-- Hyjal's.
--
-- Worked examples (cloth wrist 400768 / plate wrist 400771):
--     armour   127 -> 136        1267 -> 1354
--     stats    174/124/124/108 -> 186/133/133/115
--              170/185/108/93  -> 182/198/115/99
--
-- All ten stat slots are scaled; unused slots hold 0 and ROUND(0 * 1.069) = 0,
-- so empty slots stay empty and StatsCount does not shift.
--
-- Quality is deliberately LEFT AT 3 (rare). Winterspring and Felwood being rare
-- while Hyjal's capstone set is epic is a coherent progression, and the decision
-- taken was about item level, not rarity.
--
-- SellPrice is left alone. It is already a flat 171,316 across all four ladder
-- tiers rather than ilvl-scaled, so bumping it here would make Winterspring the
-- only tier that breaks that pattern -- a separate, map-wide call.
--
-- Guarded on the exact pre-image (372/102), so applying twice is a no-op and
-- the stats cannot be scaled by 1.069 a second time.
-- Apply against acore_world, then restart worldserver.

UPDATE acore_world.`item_template`
SET `ItemLevel`     = 385,
    `RequiredLevel` = 108,
    `armor`         = ROUND(`armor` * 1.069),
    `stat_value1`   = ROUND(`stat_value1` * 1.069),
    `stat_value2`   = ROUND(`stat_value2` * 1.069),
    `stat_value3`   = ROUND(`stat_value3` * 1.069),
    `stat_value4`   = ROUND(`stat_value4` * 1.069),
    `stat_value5`   = ROUND(`stat_value5` * 1.069),
    `stat_value6`   = ROUND(`stat_value6` * 1.069),
    `stat_value7`   = ROUND(`stat_value7` * 1.069),
    `stat_value8`   = ROUND(`stat_value8` * 1.069),
    `stat_value9`   = ROUND(`stat_value9` * 1.069),
    `stat_value10`  = ROUND(`stat_value10` * 1.069)
WHERE `entry` BETWEEN 400768 AND 400782
  AND `ItemLevel` = 372
  AND `RequiredLevel` = 102;

-- ---------------------------------------------------------------------------
-- Verify after apply
-- ---------------------------------------------------------------------------
--   SELECT COUNT(*) FROM item_template
--    WHERE entry BETWEEN 400768 AND 400782
--      AND ItemLevel = 385 AND RequiredLevel = 108;                       -> 15
--
--   -- the ladder must now be strictly increasing across all six refs:
--   SELECT r.Entry, MIN(i.ItemLevel) ilvl, MIN(i.RequiredLevel) req
--     FROM reference_loot_template r JOIN item_template i ON i.entry = r.Item
--    WHERE r.Entry IN (750080,750081,750088,750096,750104,750113)
--    GROUP BY r.Entry ORDER BY ilvl;
--     -> 750080 300/82 · 750081 300/82 · 750088 332/92 · 750096 372/102
--        · 750104 385/108 · 750113 398/115
--
--   SELECT entry, armor, stat_value1 FROM item_template WHERE entry = 400768;
--     -> 136, 186
--   SELECT entry, armor, stat_value1 FROM item_template WHERE entry = 400771;
--     -> 1354, 182
--
--   -- nothing else should have moved:
--   SELECT COUNT(*) FROM item_template
--    WHERE entry BETWEEN 400753 AND 400767 AND ItemLevel = 372;           -> 15
--        (Felwood's set is untouched)
--
-- ⚠️ CLIENT-SIDE CAVEAT, and it is not a deploy: item stats are sent to the
-- client in SMSG_ITEM_QUERY_SINGLE_RESPONSE and cached in the player's WDB.
-- Anyone who has already inspected one of these 15 items will keep seeing the
-- old numbers until their cache expires or `Cache/WDB` is cleared -- the usual
-- [[client-wdb-cache-masks-template-changes]] behaviour. Nothing to deploy;
-- just do not read a stale tooltip as a failed apply.
--
-- REVERT
--   UPDATE item_template
--      SET ItemLevel = 372, RequiredLevel = 102,
--          armor = ROUND(armor / 1.069),
--          stat_value1 = ROUND(stat_value1 / 1.069), ... (all ten)
--    WHERE entry BETWEEN 400768 AND 400782
--      AND ItemLevel = 385 AND RequiredLevel = 108;
--   -- rounding makes this near-exact rather than exact; if you want the
--   -- originals byte-perfect, the pre-image is in this file's header and in
--   -- git history for 243_.
